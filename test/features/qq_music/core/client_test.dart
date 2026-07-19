import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:qqmusic_ipod/features/qq_music/core/android_context.dart';
import 'package:qqmusic_ipod/features/qq_music/core/client.dart';
import 'package:qqmusic_ipod/features/qq_music/models/auth.dart';
import 'package:qqmusic_ipod/features/qq_music/models/device.dart';
import 'package:qqmusic_ipod/features/qq_music/models/request.dart';
import 'package:qqmusic_ipod/features/qq_music/modules/qimei.dart';
import 'package:qqmusic_ipod/features/qq_music/modules/session.dart';
import 'package:qqmusic_ipod/features/qq_music/utils/device_store.dart';

void main() {
  test('官方 CGI 请求复用单次 POST 并携带登录上下文', () async {
    late http.Request captured;
    final transport = MockClient((request) async {
      captured = request;
      return http.Response(
        jsonEncode({
          'code': 0,
          'req_0': {
            'code': 0,
            'data': {'value': 1},
          },
          'req_1': {
            'code': 0,
            'data': {'value': 2},
          },
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final client = QqMusicDirectClient(client: transport);
    addTearDown(transport.close);

    final result = await client.requestBatch(
      const [
        QqMusicCgiRequest(
          module: 'first.module',
          method: 'FirstMethod',
          param: {'enabled': true},
        ),
        QqMusicCgiRequest(
          module: 'second.module',
          method: 'SecondMethod',
          param: {'enabled': false},
          preserveBool: true,
        ),
      ],
      credential: const QqMusicCredential(
        musicId: '10001',
        musicKey: 'music-key',
      ),
    );

    final payload = jsonDecode(captured.body) as Map<String, dynamic>;
    expect(captured.method, 'POST');
    expect(captured.url.host, 'u.y.qq.com');
    expect(captured.headers['cookie'], contains('qqmusic_uin=10001'));
    expect(captured.headers['cookie'], contains('qm_keyst=music-key'));
    expect(payload['comm']['ct'], 24);
    expect(payload['comm']['platform'], 'yqq.json');
    expect(payload['req_0']['param']['enabled'], 1);
    expect(payload['req_1']['param']['enabled'], isFalse);
    expect(result, [
      {
        'code': 0,
        'data': {'value': 1},
      },
      {
        'code': 0,
        'data': {'value': 2},
      },
    ]);
  });

  test('Android CGI 注入持久设备、QIMEI、设备会话与 App 请求头', () async {
    late http.Request captured;
    final transport = MockClient((request) async {
      captured = request;
      return http.Response(
        jsonEncode({
          'code': 0,
          'req_0': {
            'code': 0,
            'data': {'value': 1},
          },
        }),
        200,
      );
    });
    final device = QqMusicDevice.random(Random(6))
      ..qimei = 'qimei16'
      ..qimei36 = 'qimei36'
      ..qimeiSavedAt = 1700000000
      ..sessionUid = 'session-uid'
      ..sessionSid = 'session-sid'
      ..sessionSavedAt = 1700000000;
    final client = QqMusicDirectClient(
      client: transport,
      androidContext: QqMusicAndroidContext(
        store: MemoryQqMusicDeviceStore(device),
        qimeiProvider: _UnexpectedQimeiProvider(),
        sessionProvider: _UnexpectedSessionProvider(),
        clock: () => 1700000010,
      ),
    );
    addTearDown(transport.close);

    await client.request(
      const QqMusicCgiRequest(module: 'test', method: 'android'),
      credential: const QqMusicCredential(
        musicId: '10001',
        musicKey: 'music-key',
      ),
      platform: QqMusicRequestPlatform.android,
    );
    final payload = jsonDecode(captured.body) as Map<String, dynamic>;
    final comm = payload['comm'] as Map<String, dynamic>;

    expect(captured.headers['user-agent'], startsWith('QQMusic 14090008'));
    expect(captured.headers.containsKey('origin'), isFalse);
    expect(captured.headers.containsKey('cookie'), isFalse);
    expect(comm['ct'], 11);
    expect(comm['cv'], 14090008);
    expect(comm['QIMEI'], 'qimei16');
    expect(comm['QIMEI36'], 'qimei36');
    expect(comm['uid'], 'session-uid');
    expect(comm['sid'], 'session-sid');
    expect(comm['aid'], device.androidId);
    expect(comm['OpenUDID'], device.openUdid);
    expect(comm['rom'], device.fingerprint);
  });

  test('签名接口使用本地签名且映射鉴权错误', () async {
    late http.Request captured;
    final transport = MockClient((request) async {
      captured = request;
      return http.Response(
        jsonEncode({
          'code': 0,
          'req_0': {
            'code': 104401,
            'data': {'reason': 'expired'},
          },
        }),
        200,
      );
    });
    final client = QqMusicDirectClient(
      client: transport,
      timestampLoader: () => 123456789,
    );
    addTearDown(transport.close);

    await expectLater(
      client.request(
        const QqMusicCgiRequest(module: 'test', method: 'write'),
        sign: true,
      ),
      throwsA(
        isA<QqMusicDirectException>()
            .having((error) => error.code, 'code', 104401)
            .having((error) => error.isUnauthorized, 'isUnauthorized', isTrue),
      ),
    );
    expect(captured.url.path, '/cgi-bin/musics.fcg');
    expect(captured.url.queryParameters['_'], '123456789');
    expect(captured.url.queryParameters['sign'], startsWith('zzc'));
  });
}

class _UnexpectedQimeiProvider implements QqMusicQimeiProvider {
  @override
  Future<QqMusicQimeiResult> request(QqMusicDevice device) {
    throw StateError('不应刷新有效 QIMEI');
  }
}

class _UnexpectedSessionProvider implements QqMusicSessionProvider {
  @override
  Future<QqMusicDeviceSession> request({
    required QqMusicDevice device,
    required Map<String, Object?> comm,
  }) {
    throw StateError('不应刷新有效设备会话');
  }
}
