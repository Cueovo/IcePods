import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/device.dart';
import '../models/device_exception.dart';

class QqMusicDeviceSession {
  const QqMusicDeviceSession({
    required this.uid,
    required this.sid,
    this.vkey = '',
  });

  final String uid;
  final String sid;
  final String vkey;
}

abstract interface class QqMusicSessionProvider {
  Future<QqMusicDeviceSession> request({
    required QqMusicDevice device,
    required Map<String, Object?> comm,
  });
}

class QqMusicSessionService implements QqMusicSessionProvider {
  QqMusicSessionService({required this.client, Uri? uri})
    : uri = uri ?? Uri.parse('https://u.y.qq.com/cgi-bin/musicu.fcg');

  final http.Client client;
  final Uri uri;

  @override
  Future<QqMusicDeviceSession> request({
    required QqMusicDevice device,
    required Map<String, Object?> comm,
  }) async {
    late http.Response response;
    try {
      response = await client.post(
        uri,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json; charset=utf-8',
          'User-Agent': 'QQMusic 14090008(android ${device.osRelease})',
        },
        body: jsonEncode({
          'comm': comm,
          'req_0': {
            'module': 'music.getSession.session',
            'method': 'GetSession',
            'param': {'uid': device.sessionUid, 'vkey': 0, 'caller': 0},
          },
        }),
      );
    } on http.ClientException catch (error) {
      throw QqMusicDeviceException('无法建立 QQ 音乐设备会话：${error.message}');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw QqMusicDeviceException(
        'QQ 音乐设备会话请求失败 (${response.statusCode})',
        statusCode: response.statusCode,
      );
    }
    try {
      final root = _map(jsonDecode(utf8.decode(response.bodyBytes)));
      final globalCode = _int(root['code']);
      final item = _map(root['req_0']);
      final code = _int(item['code']);
      final session = _map(_map(item['data'])['session']);
      final uid = _string(session['uid']);
      final sid = _string(session['sid']);
      if (globalCode != 0 || code != 0 || uid.isEmpty || sid.isEmpty) {
        throw const FormatException('设备会话字段无效');
      }
      return QqMusicDeviceSession(
        uid: uid,
        sid: sid,
        vkey: _string(session['vkey']),
      );
    } on FormatException {
      throw QqMusicDeviceException(
        'QQ 音乐设备会话响应无效',
        data: utf8.decode(response.bodyBytes, allowMalformed: true),
      );
    }
  }
}

Map<String, dynamic> _map(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : const {};

String _string(Object? value) => value?.toString() ?? '';

int _int(Object? value) =>
    value is num ? value.toInt() : int.tryParse('$value') ?? 0;
