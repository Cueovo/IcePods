import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:qqmusic_ipod/core/utils/sign.dart';
import 'package:qqmusic_ipod/business/entities/auth.dart';
import 'package:qqmusic_ipod/data/models/request.dart';
import 'package:qqmusic_ipod/data/datasources/qimei.dart';
import 'package:qqmusic_ipod/data/datasources/session.dart';
import 'package:qqmusic_ipod/core/storage/device_store.dart';
import 'package:qqmusic_ipod/data/datasources/android_context.dart';

/// QQ 音乐官方 CGI 返回的业务异常。
class QqMusicDirectException implements Exception {
  const QqMusicDirectException(
    this.message, {
    this.code,
    this.statusCode,
    this.data,
  });

  final String message;
  final int? code;
  final int? statusCode;
  final Object? data;

  bool get isUnauthorized =>
      statusCode == 401 || code == 1000 || code == 104400 || code == 104401;

  @override
  String toString() => message;
}

/// 直接连接 QQ 音乐官方 `musicu.fcg` 的轻量客户端。
///
/// 客户端复用一个 [http.Client] 连接池，并支持一次 POST 合并多个 CGI，
/// 避免旧代理层带来的额外网络跳转与 JSON 包装开销。
class QqMusicDirectClient {
  QqMusicDirectClient({
    http.Client? client,
    Uri? apiUri,
    Uri? signedApiUri,
    int Function()? timestampLoader,
    QqMusicAndroidContext? androidContext,
  }) : _client = client ?? http.Client(),
       _ownsClient = client == null,
       apiUri = apiUri ?? Uri.parse('https://u.y.qq.com/cgi-bin/musicu.fcg'),
       signedApiUri =
           signedApiUri ?? Uri.parse('https://u.y.qq.com/cgi-bin/musics.fcg'),
       _timestampLoader =
           timestampLoader ?? (() => DateTime.now().millisecondsSinceEpoch) {
    _androidContext =
        androidContext ??
        QqMusicAndroidContext(
          store: const SharedPreferencesQqMusicDeviceStore(),
          qimeiProvider: QqMusicQimeiService(client: _client),
          sessionProvider: QqMusicSessionService(
            client: _client,
            uri: this.apiUri,
          ),
        );
  }

  static const userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
      'AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/120.0.0.0 Safari/537.36';

  final http.Client _client;
  final bool _ownsClient;
  final Uri apiUri;
  final Uri signedApiUri;
  final int Function() _timestampLoader;
  late final QqMusicAndroidContext _androidContext;

  Future<String> androidGuid([QqMusicCredential? credential]) async {
    final device = await _androidContext.ensureDevice(credential);
    return device.openUdid;
  }

  /// 发送单个 CGI，并直接返回该 CGI 的 `data`。
  Future<Map<String, dynamic>> request(
    QqMusicCgiRequest request, {
    QqMusicCredential? credential,
    Map<String, Object?> comm = const {},
    bool overrideComm = false,
    bool sign = false,
    QqMusicRequestPlatform platform = QqMusicRequestPlatform.web,
    Set<int> allowedErrorCodes = const {},
  }) async {
    final responses = await requestBatch(
      [request],
      credential: credential,
      comm: comm,
      overrideComm: overrideComm,
      sign: sign,
      platform: platform,
      allowedErrorCodes: allowedErrorCodes,
    );
    return _map(responses.single['data']);
  }

  /// 将同一鉴权上下文中的 CGI 合并为一次官方请求。
  Future<List<Map<String, dynamic>>> requestBatch(
    List<QqMusicCgiRequest> requests, {
    QqMusicCredential? credential,
    Map<String, Object?> comm = const {},
    bool overrideComm = false,
    bool sign = false,
    QqMusicRequestPlatform platform = QqMusicRequestPlatform.web,
    Set<int> allowedErrorCodes = const {},
  }) async {
    if (requests.isEmpty) {
      return const [];
    }
    final device = platform == QqMusicRequestPlatform.android
        ? await _androidContext.ensureDevice(credential)
        : null;
    final defaultComm = device == null
        ? _buildWebComm(credential)
        : _androidContext.buildComm(device, credential);
    final payload = <String, Object?>{
      'comm': overrideComm
          ? Map<String, Object?>.from(comm)
          : {...defaultComm, ...comm},
      for (var index = 0; index < requests.length; index++)
        'req_$index': {
          'module': requests[index].module,
          'method': requests[index].method,
          'param': requests[index].preserveBool
              ? requests[index].param
              : _encodeBooleans(requests[index].param),
        },
    };
    final encoded = jsonEncode(payload);
    final uri = sign
        ? signedApiUri.replace(
            queryParameters: {
              '_': '${_timestampLoader()}',
              'sign': createRequestSignature(encoded),
            },
          )
        : apiUri;
    final response = await _post(
      uri,
      encoded,
      credential,
      device == null ? const {} : _androidContext.buildHeaders(device),
    );
    final root = _decodeResponse(response);
    final globalCode = _int(root['code']);
    if (globalCode != 0) {
      throw QqMusicDirectException(
        'QQ 音乐请求失败',
        code: globalCode,
        statusCode: response.statusCode,
        data: root,
      );
    }

    return List<Map<String, dynamic>>.generate(requests.length, (index) {
      final item = _map(root['req_$index']);
      if (item.isEmpty) {
        throw QqMusicDirectException('QQ 音乐响应缺少 req_$index', data: root);
      }
      final code = _int(item['code']);
      if (code != 0 && !allowedErrorCodes.contains(code)) {
        throw QqMusicDirectException(
          _cgiErrorMessage(code),
          code: code,
          statusCode: response.statusCode,
          data: item['data'],
        );
      }
      return <String, dynamic>{'code': code, 'data': _map(item['data'])};
    }, growable: false);
  }

  Future<http.Response> _post(
    Uri uri,
    String encoded,
    QqMusicCredential? credential,
    Map<String, String> platformHeaders,
  ) async {
    try {
      return await _client.post(
        uri,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json; charset=utf-8',
          ...platformHeaders,
          if (platformHeaders.isEmpty) ...{
            'Origin': 'https://y.qq.com',
            'Referer': 'https://y.qq.com/',
            'User-Agent': userAgent,
          },
          if (platformHeaders.isEmpty && credential?.isValid == true)
            'Cookie': _credentialCookie(credential!),
        },
        body: encoded,
      );
    } on http.ClientException catch (error) {
      throw QqMusicDirectException('无法连接 QQ 音乐：${error.message}');
    }
  }

  Map<String, dynamic> _decodeResponse(http.Response response) {
    final body = utf8.decode(response.bodyBytes, allowMalformed: true);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw QqMusicDirectException(
        'QQ 音乐 HTTP 请求失败 (${response.statusCode})',
        statusCode: response.statusCode,
        data: body,
      );
    }
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } on FormatException {
      throw QqMusicDirectException(
        'QQ 音乐返回了无效 JSON',
        statusCode: response.statusCode,
        data: body,
      );
    }
    throw QqMusicDirectException(
      'QQ 音乐返回了无效数据',
      statusCode: response.statusCode,
      data: body,
    );
  }

  Map<String, Object?> _buildWebComm(QqMusicCredential? credential) {
    final musicId = int.tryParse(credential?.musicId ?? '') ?? 0;
    final token = hash33(credential?.musicKey ?? '', 5381);
    return {
      'ct': 24,
      'cv': 4747474,
      'platform': 'yqq.json',
      'chid': '0',
      'uin': musicId,
      'g_tk': token,
      'g_tk_new_20200303': token,
      'format': 'json',
      'inCharset': 'utf-8',
      'outCharset': 'utf-8',
      'notice': 0,
      'needNewCode': 1,
    };
  }

  String _credentialCookie(QqMusicCredential credential) {
    final musicId = credential.stringMusicId.isNotEmpty
        ? credential.stringMusicId
        : credential.musicId;
    return [
      'uin=$musicId',
      'qqmusic_uin=$musicId',
      'qm_keyst=${credential.musicKey}',
      'qqmusic_key=${credential.musicKey}',
    ].join('; ');
  }

  void close() {
    if (_ownsClient) {
      _client.close();
    }
  }
}

Object? _encodeBooleans(Object? value) {
  if (value is bool) {
    return value ? 1 : 0;
  }
  if (value is List) {
    return value.map(_encodeBooleans).toList(growable: false);
  }
  if (value is Map) {
    return {
      for (final entry in value.entries)
        entry.key.toString(): _encodeBooleans(entry.value),
    };
  }
  return value;
}

Map<String, dynamic> _map(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : const {};

int _int(Object? value) =>
    value is num ? value.toInt() : int.tryParse('$value') ?? 0;

String _cgiErrorMessage(int code) => switch (code) {
  1000 || 104400 || 104401 => 'QQ 音乐登录凭据已失效',
  2000 => 'QQ 音乐请求需要签名',
  2001 => 'QQ 音乐请求过于频繁',
  _ => 'QQ 音乐业务请求失败 ($code)',
};
