import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:qqmusic_ipod/features/qq_music/core/android_context.dart';
import 'package:qqmusic_ipod/features/qq_music/models/auth.dart';
import 'package:qqmusic_ipod/features/qq_music/models/device.dart';
import 'package:qqmusic_ipod/features/qq_music/modules/qimei.dart';
import 'package:qqmusic_ipod/features/qq_music/modules/session.dart';
import 'package:qqmusic_ipod/features/qq_music/utils/device_store.dart';

void main() {
  const now = 1700000000;
  const credential = QqMusicCredential(
    musicId: '10001',
    musicKey: 'W_X-music-key',
  );

  test('设备上下文按 QIMEI、会话顺序初始化并持久化完整指纹', () async {
    final store = MemoryQqMusicDeviceStore(QqMusicDevice.random(Random(3)));
    final qimei = _FakeQimeiProvider();
    final session = _FakeSessionProvider();
    final context = QqMusicAndroidContext(
      store: store,
      qimeiProvider: qimei,
      sessionProvider: session,
      clock: () => now,
    );

    final device = await context.ensureDevice(credential);
    final comm = context.buildComm(device, credential);

    expect(qimei.callCount, 1);
    expect(session.callCount, 1);
    expect(session.qimeiSeen, 'q16');
    expect(store.writeCount, 2);
    expect(device.qimeiSavedAt, now);
    expect(device.sessionSavedAt, now);
    expect(comm['ct'], 11);
    expect(comm['cv'], 14090008);
    expect(comm['QIMEI'], 'q16');
    expect(comm['QIMEI36'], 'q36');
    expect(comm['uid'], 'session-uid');
    expect(comm['sid'], 'session-sid');
    expect(comm['aid'], device.androidId);
    expect(comm['OpenUDID'], device.openUdid);
    expect(comm['rom'], device.fingerprint);
    expect(comm['qq'], credential.musicId);
    expect(comm['authst'], credential.musicKey);
    expect(comm['tmeLoginType'], 1);
  });

  test('24 小时内复用设备 QIMEI 与会话且并发初始化只执行一次', () async {
    final device = QqMusicDevice.random(Random(4))
      ..qimei = 'cached-q16'
      ..qimei36 = 'cached-q36'
      ..qimeiSavedAt = now - 10
      ..sessionUid = 'cached-uid'
      ..sessionSid = 'cached-sid'
      ..sessionSavedAt = now - 10;
    final store = MemoryQqMusicDeviceStore(device);
    final qimei = _FakeQimeiProvider();
    final session = _FakeSessionProvider();
    final context = QqMusicAndroidContext(
      store: store,
      qimeiProvider: qimei,
      sessionProvider: session,
      clock: () => now,
    );

    final devices = await Future.wait([
      context.ensureDevice(credential),
      context.ensureDevice(credential),
    ]);

    expect(identical(devices.first, devices.last), isTrue);
    expect(qimei.callCount, 0);
    expect(session.callCount, 0);
    expect(store.readCount, 1);
    expect(store.writeCount, 0);

    await context.ensureDevice(credential);
    expect(store.readCount, 1);
  });
}

class _FakeQimeiProvider implements QqMusicQimeiProvider {
  int callCount = 0;

  @override
  Future<QqMusicQimeiResult> request(QqMusicDevice device) async {
    callCount++;
    return const QqMusicQimeiResult(q16: 'q16', q36: 'q36');
  }
}

class _FakeSessionProvider implements QqMusicSessionProvider {
  int callCount = 0;
  String qimeiSeen = '';

  @override
  Future<QqMusicDeviceSession> request({
    required QqMusicDevice device,
    required Map<String, Object?> comm,
  }) async {
    callCount++;
    qimeiSeen = '${comm['QIMEI']}';
    return const QqMusicDeviceSession(
      uid: 'session-uid',
      sid: 'session-sid',
      vkey: 'session-vkey',
    );
  }
}
