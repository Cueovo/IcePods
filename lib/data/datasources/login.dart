import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import 'package:qqmusic_ipod/core/utils/sign.dart';
import 'package:qqmusic_ipod/data/datasources/direct_client.dart';
import 'package:qqmusic_ipod/business/entities/auth.dart';
import 'package:qqmusic_ipod/data/models/request.dart';
import 'package:qqmusic_ipod/core/storage/credential_store.dart';

class QqMusicLoginModule {
  QqMusicLoginModule({
    required this._client,
    http.Client? httpClient,
    QqMusicCredentialStore? credentialStore,
    DateTime Function()? now,
    Random? random,
    this.credentialRefreshInterval = const Duration(hours: 24),
  }) : assert(credentialRefreshInterval > Duration.zero),
       _httpClient = httpClient ?? http.Client(),
       _ownsHttpClient = httpClient == null,
       _credentialStore =
           credentialStore ?? const SecureQqMusicCredentialStore(),
       _now = now ?? DateTime.now,
       _random = random ?? Random.secure();

  static const _androidUserAgent = 'QQMusic 14090008(android 10)';

  final Duration credentialRefreshInterval;

  static const _loginErrorCodes = <int>{
    1000,
    104400,
    104401,
    20261,
    20271,
    20272,
    20274,
    20277,
    20278,
    20279,
    20450,
    104604,
  };

  final QqMusicDirectClient _client;
  final http.Client _httpClient;
  final bool _ownsHttpClient;
  final QqMusicCredentialStore _credentialStore;
  final DateTime Function() _now;
  final Random _random;

  QqMusicCredential? _credential;
  Future<QqMusicCredential>? _credentialRefreshInFlight;
  Timer? _credentialRefreshTimer;
  bool _scheduledRefreshRunning = false;
  bool _closed = false;

  QqMusicCredential? get credential => _credential;

  bool get isLoggedIn => _credential?.isValid ?? false;

  void useCredential(QqMusicCredential credential) {
    _credential = credential;
    _scheduleCredentialRefresh();
  }

  Future<void> restoreSession() async {
    final restored = await _credentialStore.read();
    if (restored == null) {
      return;
    }
    _credential = restored;
    try {
      if (_credentialRefreshDelay(restored) == Duration.zero ||
          await checkExpired(restored)) {
        await refreshCredential(restored);
      }
    } on QqMusicDirectException catch (error) {
      if (!error.isUnauthorized) {
        rethrow;
      }
      try {
        await refreshCredential(restored);
      } catch (_) {
        await logout();
      }
    } finally {
      if (isLoggedIn) {
        _scheduleCredentialRefresh();
      }
    }
  }

  Future<void> ensureFreshCredential() async {
    final active = _credential;
    if (_closed || active == null || !active.isValid) {
      return;
    }
    try {
      if (_credentialRefreshDelay(active) == Duration.zero ||
          await checkExpired(active)) {
        await refreshCredential(active);
      } else {
        _scheduleCredentialRefresh();
      }
    } on QqMusicDirectException catch (error) {
      if (!error.isUnauthorized) {
        rethrow;
      }
      await logout();
      rethrow;
    }
  }

  Future<QqMusicQrCode> createQrCode({String loginType = 'qq'}) async {
    final normalized = loginType.trim().toLowerCase();
    switch (normalized) {
      case 'qq':
        return _createQqQr();
      case 'wx':
      case 'wechat':
        return _createWxQr();
      case 'mobile':
        return _createMobileQr();
      default:
        throw QqMusicDirectException('不支持的二维码登录类型：$loginType');
    }
  }

  Future<QqMusicQrStatus> checkQrStatus(QqMusicQrCode qrCode) async {
    switch (qrCode.loginType.toLowerCase()) {
      case 'qq':
        return _checkQqQr(qrCode);
      case 'wx':
      case 'wechat':
        return _checkWxQr(qrCode);
      default:
        throw QqMusicDirectException('暂不支持该二维码登录状态检查');
    }
  }

  Future<QqMusicCredential> refreshCredential([QqMusicCredential? target]) {
    final pending = _credentialRefreshInFlight;
    if (pending != null) {
      return pending;
    }
    final refresh = _refreshCredential(target);
    _credentialRefreshInFlight = refresh;
    return refresh.whenComplete(() {
      if (identical(_credentialRefreshInFlight, refresh)) {
        _credentialRefreshInFlight = null;
      }
    });
  }

  Future<QqMusicCredential> _refreshCredential(
    QqMusicCredential? target,
  ) async {
    final active = _requireCredential(target);
    final params = <String, Object?>{
      'openid': active.openId,
      'access_token': active.accessToken,
      'refresh_token': active.refreshToken,
      'expired_in': active.expiredAt,
      'str_musicid': active.stringMusicId.isEmpty
          ? active.musicId
          : active.stringMusicId,
      'musicid': int.tryParse(active.musicId) ?? 0,
      'musickey': active.musicKey,
      'unionid': active.unionId,
      'refresh_key': active.refreshKey,
      'loginMode': 2,
    };
    if (active.effectiveLoginType == 1) {
      params.remove('access_token');
      params.remove('expired_in');
      params.remove('musicid');
    } else if (active.effectiveLoginType == 2) {
      params.remove('str_musicid');
      params.remove('unionid');
    }
    final data = await _loginRequest(
      const QqMusicCgiRequest(
        module: 'music.login.LoginServer',
        method: 'Login',
      ).withParameters(params),
      credential: active,
      comm: {'tmeLoginType': active.effectiveLoginType},
    );
    final refreshed = QqMusicCredential.fromJson(data).merge(active);
    if (!refreshed.isValid) {
      throw const QqMusicDirectException('刷新登录凭据失败');
    }
    await _saveCredential(refreshed);
    return refreshed;
  }

  Future<void> logout() async {
    _credentialRefreshTimer?.cancel();
    _credentialRefreshTimer = null;
    final active = _credential;
    try {
      if (active?.isValid ?? false) {
        await _loginRequest(
          const QqMusicCgiRequest(
            module: 'music.login.LoginServer',
            method: 'Logout',
          ),
          credential: active,
          comm: {'tmeLoginType': active!.effectiveLoginType},
        );
      }
    } finally {
      _credential = null;
      await _credentialStore.clear();
    }
  }

  Future<bool> checkExpired([QqMusicCredential? target]) async {
    final active = _requireCredential(target);
    final responses = await _client.requestBatch(
      const [
        QqMusicCgiRequest(
          module: 'music.UserInfo.userInfoServer',
          method: 'GetLoginUserInfo',
        ),
      ],
      credential: active,
      allowedErrorCodes: {1000, 104400, 104401},
    );
    final response = responses.single;
    final itemCode = _int(response['code']);
    final dataCode = _int(_map(response['data'])['code']);
    return itemCode != 0 || dataCode != 0;
  }

  Future<QqMusicQrCode> _createQqQr() async {
    final uri = Uri.parse('https://ssl.ptlogin2.qq.com/ptqrshow').replace(
      queryParameters: {
        'appid': '716027609',
        'e': '2',
        'l': 'M',
        's': '3',
        'd': '72',
        'v': '4',
        't':
            '${_now().microsecondsSinceEpoch / Duration.microsecondsPerSecond}',
        'daid': '383',
        'pt_3rd_aid': '100497308',
      },
    );
    final response = await _rawRequest(
      'GET',
      uri,
      headers: {
        'Referer': 'https://xui.ptlogin2.qq.com/',
        'User-Agent': _androidUserAgent,
      },
    );
    final qrsig = _cookies(response)['qrsig'] ?? '';
    if (qrsig.isEmpty || response.bodyBytes.isEmpty) {
      throw const QqMusicDirectException('获取 QQ 二维码失败');
    }
    return QqMusicQrCode(
      loginType: 'qq',
      identifier: qrsig,
      mimeType: 'image/png',
      imageBytes: response.bodyBytes,
    );
  }

  Future<QqMusicQrCode> _createWxQr() async {
    final uri = Uri.parse('https://open.weixin.qq.com/connect/qrconnect').replace(
      queryParameters: {
        'appid': 'wx48db31d50e334801',
        'redirect_uri':
            'https://y.qq.com/portal/wx_redirect.html?login_type=2&surl=https://y.qq.com/',
        'response_type': 'code',
        'scope': 'snsapi_login',
        'state': 'STATE',
        'href':
            'https://y.qq.com/mediastyle/music_v17/src/css/popup_wechat.css#wechat_redirect',
      },
    );
    final response = await _rawRequest(
      'GET',
      uri,
      headers: {'Referer': 'https://open.weixin.qq.com/'},
    );
    final match = RegExp(r'uuid="?([^"&\s]+)"').firstMatch(response.body);
    final uuid = match?.group(1) ?? '';
    if (uuid.isEmpty) {
      throw const QqMusicDirectException('获取微信二维码 uuid 失败');
    }
    final image = await _rawRequest(
      'GET',
      Uri.parse('https://open.weixin.qq.com/connect/qrcode/$uuid'),
      headers: {'Referer': 'https://open.weixin.qq.com/connect/qrconnect'},
    );
    if (image.bodyBytes.isEmpty) {
      throw const QqMusicDirectException('获取微信二维码失败');
    }
    return QqMusicQrCode(
      loginType: 'wx',
      identifier: uuid,
      mimeType: 'image/jpeg',
      imageBytes: image.bodyBytes,
    );
  }

  Future<QqMusicQrCode> _createMobileQr() async {
    final data = await _loginRequest(
      const QqMusicCgiRequest(
        module: 'music.login.LoginServer',
        method: 'CreateQRCode',
        param: {'tmeAppID': 'qqmusic'},
      ),
      comm: const {'ct': 23, 'cv': 0},
      platform: QqMusicRequestPlatform.android,
    );
    final encoded = _string(data['qrcode']);
    final identifier = _string(data['qrcodeID']);
    if (encoded.isEmpty || identifier.isEmpty) {
      throw const QqMusicDirectException('获取手机客户端二维码失败');
    }
    try {
      return QqMusicQrCode(
        loginType: 'mobile',
        identifier: identifier,
        mimeType: 'image/png',
        imageBytes: base64Decode(encoded.split(',').last),
      );
    } on FormatException {
      throw const QqMusicDirectException('手机客户端二维码数据无效');
    }
  }

  Future<QqMusicQrStatus> _checkQqQr(QqMusicQrCode qrCode) async {
    final qrsig = qrCode.identifier;
    final uri = Uri.parse('https://ssl.ptlogin2.qq.com/ptqrlogin').replace(
      queryParameters: {
        'u1': 'https://graph.qq.com/oauth2.0/login_jump',
        'ptqrtoken': '${hash33(qrsig)}',
        'ptredirect': '0',
        'h': '1',
        't': '1',
        'g': '1',
        'from_ui': '1',
        'ptlang': '2052',
        'action': '0-0-${_now().millisecondsSinceEpoch}',
        'js_ver': '20102616',
        'js_type': '1',
        'pt_uistyle': '40',
        'aid': '716027609',
        'daid': '383',
        'pt_3rd_aid': '100497308',
        'has_onekey': '1',
      },
    );
    final response = await _rawRequest(
      'GET',
      uri,
      headers: {
        'Referer': 'https://xui.ptlogin2.qq.com/',
        'User-Agent': _androidUserAgent,
      },
      cookies: {'qrsig': qrsig},
    );
    final match = RegExp(
      r'ptuiCB\((.*?)\)',
      dotAll: true,
    ).firstMatch(response.body);
    if (match == null) {
      throw const QqMusicDirectException('获取 QQ 二维码状态失败');
    }
    final args = RegExp(r"'((?:\\.|[^'])*)'")
        .allMatches(match.group(1)!)
        .map((match) => match.group(1)!.replaceAll(r"\'", "'"))
        .toList(growable: false);
    if (args.isEmpty) {
      throw const QqMusicDirectException('获取 QQ 二维码状态失败');
    }
    final rawEvent = int.tryParse(args.first);
    if (rawEvent == null) {
      throw const QqMusicDirectException('QQ 二维码状态码无效');
    }
    final event = _qqEvent(rawEvent);
    if (event != 0) {
      return _qrStatus(qrCode, event);
    }
    if (args.length < 3) {
      throw const QqMusicDirectException('获取 QQ 登录凭据失败');
    }
    final sigx = RegExp(r'(?:\?|&)ptsigx=([^&]+)&s_url').firstMatch(args[2]);
    final uin = RegExp(r'(?:\?|&)uin=([^&]+)&service').firstMatch(args[2]);
    if (sigx == null || uin == null) {
      throw const QqMusicDirectException('解析 QQ 登录凭据失败');
    }
    final credential = await _authorizeQq(uin.group(1)!, sigx.group(1)!);
    await _saveCredential(credential);
    return _qrStatus(qrCode, 0, credential: credential);
  }

  Future<QqMusicQrStatus> _checkWxQr(QqMusicQrCode qrCode) async {
    final uri = Uri.parse('https://lp.open.weixin.qq.com/connect/l/qrconnect')
        .replace(
          queryParameters: {
            'uuid': qrCode.identifier,
            '_': '${(_now().millisecondsSinceEpoch ~/ 1000) * 1000}',
          },
        );
    late final http.Response response;
    try {
      response = await _rawRequest(
        'GET',
        uri,
        headers: {'Referer': 'https://open.weixin.qq.com/'},
      ).timeout(const Duration(seconds: 35));
    } on TimeoutException {
      return _qrStatus(qrCode, 1);
    }
    final match = RegExp(
      r"window\.wx_errcode=(\d+);window\.wx_code='([^']*)'",
    ).firstMatch(response.body);
    if (match == null) {
      throw const QqMusicDirectException('获取微信二维码状态失败');
    }
    final rawEvent = int.tryParse(match.group(1)!);
    if (rawEvent == null) {
      throw const QqMusicDirectException('微信二维码状态码无效');
    }
    final event = _wxEvent(rawEvent);
    if (event != 0) {
      return _qrStatus(qrCode, event);
    }
    final code = match.group(2) ?? '';
    if (code.isEmpty) {
      throw const QqMusicDirectException('获取微信登录 code 失败');
    }
    final credential = await _loginRequest(
      const QqMusicCgiRequest(
        module: 'music.login.LoginServer',
        method: 'Login',
        param: {'strAppid': 'wx48db31d50e334801'},
      ).withParameters({'code': code}),
      comm: const {'tmeLoginType': 1},
    );
    final parsed = QqMusicCredential.fromJson(credential);
    if (!parsed.isValid) {
      throw const QqMusicDirectException('微信登录未返回有效凭据');
    }
    await _saveCredential(parsed);
    return _qrStatus(qrCode, 0, credential: parsed);
  }

  Future<QqMusicCredential> _authorizeQq(String uin, String sigx) async {
    final checkSigUri = Uri.parse('https://ssl.ptlogin2.graph.qq.com/check_sig')
        .replace(
          queryParameters: {
            'uin': uin,
            'pttype': '1',
            'service': 'ptqrlogin',
            'nodirect': '0',
            'ptsigx': sigx,
            's_url': 'https://graph.qq.com/oauth2.0/login_jump',
            'ptlang': '2052',
            'ptredirect': '100',
            'aid': '716027609',
            'daid': '383',
            'j_later': '0',
            'low_login_hour': '0',
            'regmaster': '0',
            'pt_login_type': '3',
            'pt_aid': '0',
            'pt_aaid': '16',
            'pt_light': '0',
            'pt_3rd_aid': '100497308',
          },
        );
    final checkSigResponse = await _rawRequest(
      'GET',
      checkSigUri,
      headers: {
        'Referer': 'https://xui.ptlogin2.qq.com/',
        'User-Agent': _androidUserAgent,
      },
      followRedirects: false,
    );
    final cookies = _cookies(checkSigResponse);
    final pSkey = cookies['p_skey'] ?? '';
    if (pSkey.isEmpty) {
      final cookieNames = cookies.keys.join(', ');
      throw QqMusicDirectException(
        '获取 QQ p_skey 失败（check_sig ${checkSigResponse.statusCode}，'
        'Cookie: ${cookieNames.isEmpty ? '无' : cookieNames}）',
        statusCode: checkSigResponse.statusCode,
      );
    }
    final authorizeUri = Uri.parse('https://graph.qq.com/oauth2.0/authorize');
    final authorizeResponse = await _rawRequest(
      'POST',
      authorizeUri,
      headers: {'User-Agent': _androidUserAgent},
      cookies: cookies,
      form: {
        'response_type': 'code',
        'client_id': '100497308',
        'redirect_uri':
            'https://y.qq.com/portal/wx_redirect.html?login_type=1&surl=https://y.qq.com/',
        'scope': 'get_user_info,get_app_friends',
        'state': 'state',
        'switch': '',
        'from_ptlogin': '1',
        'src': '1',
        'update_auth': '1',
        'openapi': '1010_1030',
        'g_tk': '${hash33(pSkey, 5381)}',
        'auth_time': '${(_now().millisecondsSinceEpoch ~/ 1000) * 1000}',
        'ui': _uuidV4(),
      },
      followRedirects: false,
    );
    final location = authorizeResponse.headers['location'] ?? '';
    final code = _queryValue(location, 'code');
    if (code.isEmpty) {
      throw const QqMusicDirectException('获取 QQ 登录 code 失败');
    }
    final data = await _loginRequest(
      const QqMusicCgiRequest(
        module: 'QQConnectLogin.LoginServer',
        method: 'QQLogin',
      ).withParameters({'code': code}),
      comm: const {'tmeLoginType': 2},
    );
    final credential = QqMusicCredential.fromJson(data);
    if (!credential.isValid) {
      throw const QqMusicDirectException('QQ 登录未返回有效凭据');
    }
    return credential;
  }

  Future<Map<String, dynamic>> _loginRequest(
    QqMusicCgiRequest request, {
    QqMusicCredential? credential,
    Map<String, Object?> comm = const {},
    QqMusicRequestPlatform platform = QqMusicRequestPlatform.web,
  }) async {
    final response = (await _client.requestBatch(
      [request],
      credential: credential,
      comm: comm,
      platform: platform,
      allowedErrorCodes: _loginErrorCodes,
    )).single;
    final code = _int(response['code']);
    if (code != 0) {
      throw QqMusicDirectException(
        _loginErrorMessage(code),
        code: code,
        data: response['data'],
      );
    }
    final payload = _map(response['data']);
    if (!payload.containsKey('code')) {
      return payload;
    }
    final businessCode = _int(payload['code']);
    if (businessCode != 0) {
      throw QqMusicDirectException(
        _loginErrorMessage(businessCode),
        code: businessCode,
        data: payload['data'],
      );
    }
    return _map(payload['data']);
  }

  Future<http.Response> _rawRequest(
    String method,
    Uri uri, {
    Map<String, String> headers = const {},
    Map<String, String> cookies = const {},
    Map<String, String> form = const {},
    bool followRedirects = true,
  }) async {
    final request = http.Request(method, uri)
      ..followRedirects = followRedirects
      ..headers.addAll({
        'Accept': '*/*',
        'User-Agent': QqMusicDirectClient.userAgent,
        ...headers,
        if (cookies.isNotEmpty) 'Cookie': _cookieHeader(cookies),
      });
    if (form.isNotEmpty) {
      request.headers['Content-Type'] =
          'application/x-www-form-urlencoded; charset=utf-8';
      request.body = form.entries
          .map(
            (entry) =>
                '${Uri.encodeQueryComponent(entry.key)}=${Uri.encodeQueryComponent(entry.value)}',
          )
          .join('&');
    }
    try {
      final streamed = await _httpClient.send(request);
      final response = await http.Response.fromStream(streamed);
      if (response.statusCode < 200 || response.statusCode >= 400) {
        throw QqMusicDirectException(
          'QQ 音乐登录 HTTP 请求失败 (${response.statusCode})',
          statusCode: response.statusCode,
        );
      }
      return response;
    } on QqMusicDirectException {
      rethrow;
    } on http.ClientException catch (error) {
      throw QqMusicDirectException('无法连接 QQ 音乐登录服务：${error.message}');
    }
  }

  Future<void> _saveCredential(QqMusicCredential credential) async {
    _credential = credential;
    await _credentialStore.write(credential);
    _scheduleCredentialRefresh(delay: credentialRefreshInterval);
  }

  void _scheduleCredentialRefresh({Duration? delay}) {
    _credentialRefreshTimer?.cancel();
    _credentialRefreshTimer = null;
    final active = _credential;
    if (_closed || active == null || !active.isValid) {
      return;
    }
    _credentialRefreshTimer = Timer(
      delay ?? _credentialRefreshDelay(active),
      () => unawaited(_refreshCredentialOnSchedule()),
    );
  }

  Duration _credentialRefreshDelay(QqMusicCredential credential) {
    final createdAt = credential.musicKeyCreatedAt;
    if (createdAt <= 0) {
      return credentialRefreshInterval;
    }
    final createdAtMilliseconds = createdAt < 100000000000
        ? createdAt * 1000
        : createdAt;
    final elapsedMilliseconds =
        _now().millisecondsSinceEpoch - createdAtMilliseconds;
    if (elapsedMilliseconds <= 0) {
      return credentialRefreshInterval;
    }
    final remaining =
        credentialRefreshInterval - Duration(milliseconds: elapsedMilliseconds);
    return remaining > Duration.zero ? remaining : Duration.zero;
  }

  Future<void> _refreshCredentialOnSchedule() async {
    if (_scheduledRefreshRunning || _closed) {
      return;
    }
    final active = _credential;
    if (active == null || !active.isValid) {
      return;
    }
    _scheduledRefreshRunning = true;
    try {
      await refreshCredential(active);
    } catch (_) {
      _scheduleCredentialRefresh(delay: credentialRefreshInterval);
    } finally {
      _scheduledRefreshRunning = false;
    }
  }

  QqMusicCredential _requireCredential(QqMusicCredential? target) {
    final active = target ?? _credential;
    if (active == null || !active.isValid) {
      throw const QqMusicDirectException('请先扫码登录 QQ 音乐', statusCode: 401);
    }
    return active;
  }

  QqMusicQrStatus _qrStatus(
    QqMusicQrCode qrCode,
    int event, {
    QqMusicCredential? credential,
  }) {
    return QqMusicQrStatus(
      event: event,
      done: event == 0,
      identifier: qrCode.identifier,
      loginType: qrCode.loginType,
      credential: credential,
    );
  }

  Map<String, String> _cookies(http.Response response) {
    final value = response.headers['set-cookie'];
    if (value == null || value.isEmpty) {
      return const {};
    }
    final result = <String, String>{};
    for (final match in RegExp(
      r'(?:^|,\s*)([^=;,\s]+)=([^;]*)',
    ).allMatches(value)) {
      final name = match.group(1)!;
      final cookieValue = match.group(2)!;
      if (cookieValue.isNotEmpty || !result.containsKey(name)) {
        result[name] = cookieValue;
      }
    }
    return result;
  }

  String _cookieHeader(Map<String, String> cookies) => cookies.entries
      .where((entry) => entry.value.isNotEmpty)
      .map((entry) => '${entry.key}=${entry.value}')
      .join('; ');

  String _queryValue(String location, String name) {
    final uri = Uri.tryParse(location);
    final parsed = uri?.queryParameters[name];
    if (parsed != null && parsed.isNotEmpty) {
      return parsed;
    }
    final match = RegExp('${RegExp.escape(name)}=([^&]+)').firstMatch(location);
    return match == null ? '' : Uri.decodeComponent(match.group(1)!);
  }

  String _uuidV4() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final value = bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${value.substring(0, 8)}-'
        '${value.substring(8, 12)}-'
        '${value.substring(12, 16)}-'
        '${value.substring(16, 20)}-'
        '${value.substring(20)}';
  }

  int _qqEvent(int code) => switch (code) {
    0 => 0,
    66 => 1,
    67 => 2,
    65 => 3,
    68 => 4,
    _ => throw QqMusicDirectException('未知的 QQ 二维码状态码：$code'),
  };

  int _wxEvent(int code) => switch (code) {
    0 || 405 => 0,
    408 => 1,
    404 => 2,
    402 => 3,
    403 => 4,
    _ => throw QqMusicDirectException('未知的微信二维码状态码：$code'),
  };

  int _int(Object? value) =>
      value is num ? value.toInt() : int.tryParse('$value') ?? 0;

  String _string(Object? value) => value?.toString() ?? '';

  Map<String, dynamic> _map(Object? value) =>
      value is Map ? Map<String, dynamic>.from(value) : const {};

  String _loginErrorMessage(int code) => switch (code) {
    1000 || 104400 || 104401 => 'QQ 音乐登录凭据已失效',
    20277 || 20278 || 20450 => 'QQ 音乐账号受限',
    20279 => 'QQ 音乐登录设备数量超限',
    104604 => 'QQ 音乐登录操作过于频繁',
    _ => 'QQ 音乐登录失败 ($code)',
  };

  void close() {
    _closed = true;
    _credentialRefreshTimer?.cancel();
    _credentialRefreshTimer = null;
    if (_ownsHttpClient) {
      _httpClient.close();
    }
  }
}

extension on QqMusicCgiRequest {
  QqMusicCgiRequest withParameters(Map<String, Object?> parameters) {
    return QqMusicCgiRequest(
      module: module,
      method: method,
      param: {...param, ...parameters},
      preserveBool: preserveBool,
    );
  }
}
