import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:qqmusic_ipod/business/entities/auth.dart';
import 'package:qqmusic_ipod/data/datasources/android_context.dart';
import 'package:qqmusic_ipod/data/datasources/qimei.dart';
import 'package:qqmusic_ipod/data/datasources/session.dart';
import 'package:qqmusic_ipod/data/models/device.dart';
import 'package:qqmusic_ipod/core/storage/device_store.dart';
import 'package:qqmusic_ipod/data/datasources/direct_client.dart';
import 'package:qqmusic_ipod/data/models/request.dart';

void main() {
  test('authenticated web requests include QQ write-session cookies', () async {
    http.Request? captured;
    final httpClient = MockClient((request) async {
      captured = request;
      return http.Response(
        '{"code":0,"req_0":{"code":0,"data":{}}}',
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final client = QqMusicDirectClient(client: httpClient);
    addTearDown(client.close);

    await client.request(
      const QqMusicCgiRequest(
        module: 'music.musicasset.PlaylistDetailWrite',
        method: 'AddSonglist',
        param: {},
      ),
      credential: const QqMusicCredential(
        musicId: '10001',
        stringMusicId: 'wx-user',
        musicKey: 'W_X_test_key',
        loginType: 1,
      ),
      platform: QqMusicRequestPlatform.web,
    );

    final cookie = captured!.headers['cookie']!;
    expect(cookie, contains('tmeLoginType=1'));
    expect(cookie, contains('wxuin=wx-user'));
    expect(cookie, contains('qm_keyst=W_X_test_key'));
  });

  test('Android requests use the mobile QQ Music comm context', () async {
    const now = 1770000000;
    final device = QqMusicDevice.random(Random(2))
      ..qimei = 'qimei'
      ..qimei36 = 'qimei36'
      ..qimeiSavedAt = now;
    final context = QqMusicAndroidContext(
      store: MemoryQqMusicDeviceStore(device),
      qimeiProvider: _QimeiProvider(),
      sessionProvider: _SessionProvider(),
      clock: () => now,
    );
    http.Request? captured;
    final httpClient = MockClient((request) async {
      captured = request;
      return http.Response(
        '{"code":0,"req_0":{"code":0,"data":{}}}',
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final client = QqMusicDirectClient(
      client: httpClient,
      androidContext: context,
    );
    addTearDown(client.close);

    await client.request(
      const QqMusicCgiRequest(
        module: 'music.login.LoginServer',
        method: 'Login',
      ),
      credential: const QqMusicCredential(
        musicId: '10001',
        musicKey: 'Q_H_test_key',
        loginType: 1,
      ),
      platform: QqMusicRequestPlatform.android,
    );

    final body = jsonDecode(captured!.body) as Map<String, dynamic>;
    final comm = body['comm'] as Map<String, dynamic>;
    expect(comm['ct'], 11);
    expect(comm['cv'], 14090008);
    expect(comm['v'], 14090008);
    expect(comm['tmeAppID'], 'qqmusic');
    expect(comm['tmeLoginType'], 2);
    expect(comm['authst'], 'Q_H_test_key');
    expect(comm['QIMEI'], 'qimei');
    expect(comm['QIMEI36'], 'qimei36');
    expect(comm['uid'], 'uid-1');
    expect(comm['sid'], 'sid-1');
    expect(captured!.headers['user-agent'], startsWith('QQMusic 14090008'));
    expect(captured!.headers.containsKey('cookie'), isFalse);
  });

  test('Android sessions are rebuilt when the credential key changes', () async {
    const now = 1770000000;
    final device = QqMusicDevice.random(Random(1))
      ..qimei = 'qimei'
      ..qimei36 = 'qimei36'
      ..qimeiSavedAt = now;
    final sessions = _SessionProvider();
    final context = QqMusicAndroidContext(
      store: MemoryQqMusicDeviceStore(device),
      qimeiProvider: _QimeiProvider(),
      sessionProvider: sessions,
      clock: () => now,
    );

    await context.ensureDevice(_credential('old-key'));
    await context.ensureDevice(_credential('old-key'));
    await context.ensureDevice(_credential('new-key'));
    await context.invalidateSession();
    await context.ensureDevice(_credential('new-key'));

    expect(sessions.comms, hasLength(3));
    expect(sessions.comms.first['authst'], 'old-key');
    expect(sessions.comms[1]['authst'], 'new-key');
    expect(sessions.comms[1], isNot(contains('uid')));
    expect(sessions.comms[1], isNot(contains('sid')));
    expect(sessions.comms.last['authst'], 'new-key');
    expect(sessions.comms.last, isNot(contains('uid')));
    expect(sessions.comms.last, isNot(contains('sid')));
  });
}

QqMusicCredential _credential(String key) => QqMusicCredential(
  musicId: '10001',
  musicKey: key,
  loginType: 2,
);

class _QimeiProvider implements QqMusicQimeiProvider {
  @override
  Future<QqMusicQimeiResult> request(QqMusicDevice device) async =>
      const QqMusicQimeiResult(q16: 'qimei', q36: 'qimei36');
}

class _SessionProvider implements QqMusicSessionProvider {
  final List<Map<String, Object?>> comms = [];

  @override
  Future<QqMusicDeviceSession> request({
    required QqMusicDevice device,
    required Map<String, Object?> comm,
  }) async {
    comms.add(Map<String, Object?>.from(comm));
    final index = comms.length;
    return QqMusicDeviceSession(uid: 'uid-$index', sid: 'sid-$index');
  }
}
