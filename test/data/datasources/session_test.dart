import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:qqmusic_ipod/data/models/device.dart';
import 'package:qqmusic_ipod/data/datasources/session.dart';

void main() {
  test('设备会话请求携带预会话指纹并解析 uid、sid 与 vkey', () async {
    late http.Request captured;
    final transport = MockClient((request) async {
      captured = request;
      return http.Response(
        jsonEncode({
          'code': 0,
          'req_0': {
            'code': 0,
            'data': {
              'session': {'uid': 12345, 'sid': 'session-sid', 'vkey': 'vkey'},
            },
          },
        }),
        200,
      );
    });
    final service = QqMusicSessionService(client: transport);
    final device = QqMusicDevice.random(Random(2))
      ..qimei = 'q16'
      ..qimei36 = 'q36';
    addTearDown(transport.close);

    final result = await service.request(
      device: device,
      comm: {'ct': 11, 'QIMEI': device.qimei, 'QIMEI36': device.qimei36},
    );
    final payload = jsonDecode(captured.body) as Map<String, dynamic>;

    expect(captured.headers['user-agent'], startsWith('QQMusic 14090008'));
    expect(payload['comm']['QIMEI'], 'q16');
    expect(payload['comm']['QIMEI36'], 'q36');
    expect(payload['req_0']['module'], 'music.getSession.session');
    expect(payload['req_0']['method'], 'GetSession');
    expect(payload['req_0']['param'], {'uid': '', 'vkey': 0, 'caller': 0});
    expect(result.uid, '12345');
    expect(result.sid, 'session-sid');
    expect(result.vkey, 'vkey');
  });
}
