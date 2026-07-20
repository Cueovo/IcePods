import 'package:qqmusic_ipod/business/entities/auth.dart';
import 'package:qqmusic_ipod/data/models/device.dart';
import 'package:qqmusic_ipod/data/datasources/qimei.dart';
import 'package:qqmusic_ipod/data/datasources/session.dart';
import 'package:qqmusic_ipod/core/storage/device_store.dart';

class QqMusicAndroidContext {
  QqMusicAndroidContext({
    required this.store,
    required this.qimeiProvider,
    required this.sessionProvider,
    int Function()? clock,
  }) : _clock = clock ?? (() => DateTime.now().millisecondsSinceEpoch ~/ 1000);

  final QqMusicDeviceStore store;
  final QqMusicQimeiProvider qimeiProvider;
  final QqMusicSessionProvider sessionProvider;
  final int Function() _clock;
  QqMusicDevice? _device;
  Future<QqMusicDevice>? _initializing;

  Future<QqMusicDevice> ensureDevice(QqMusicCredential? credential) {
    final nowSeconds = _clock();
    final cached = _device;
    if (cached != null &&
        cached.hasFreshQimei(nowSeconds) &&
        cached.hasFreshSession(nowSeconds)) {
      return Future.value(cached);
    }
    final pending = _initializing;
    if (pending != null) {
      return pending;
    }
    final future = _ensureDevice(credential);
    _initializing = future;
    return future.whenComplete(() {
      if (identical(_initializing, future)) {
        _initializing = null;
      }
    });
  }

  Future<QqMusicDevice> _ensureDevice(QqMusicCredential? credential) async {
    final device = _device ?? await store.read();
    _device = device;
    final nowSeconds = _clock();
    if (!device.hasFreshQimei(nowSeconds)) {
      final qimei = await qimeiProvider.request(device);
      device.qimei = qimei.q16;
      device.qimei36 = qimei.q36;
      device.qimeiSavedAt = nowSeconds;
      await store.write(device);
    }
    if (!device.hasFreshSession(nowSeconds)) {
      final session = await sessionProvider.request(
        device: device,
        comm: buildComm(device, credential),
      );
      device.sessionUid = session.uid;
      device.sessionSid = session.sid;
      device.sessionVkey = session.vkey;
      device.sessionSavedAt = nowSeconds;
      await store.write(device);
    }
    return device;
  }

  Map<String, Object?> buildComm(
    QqMusicDevice device,
    QqMusicCredential? credential,
  ) => {
    'ct': 11,
    'cv': 14090008,
    'v': 14090008,
    'chid': '10003505',
    if (credential?.musicId.isNotEmpty == true) 'qq': credential!.musicId,
    if (credential?.musicKey.isNotEmpty == true) 'authst': credential!.musicKey,
    'tmeAppID': 'qqmusic',
    if (credential?.musicKey.isNotEmpty == true)
      'tmeLoginType': credential!.musicKey.startsWith('W_X') ? 1 : 2,
    'QIMEI': device.qimei,
    'QIMEI36': device.qimei36,
    'OpenUDID': device.openUdid,
    'guid': device.openUdid,
    'udid': device.openUdid,
    if (device.sessionUid.isNotEmpty) 'uid': device.sessionUid,
    'OpenUDID2': device.openUdid,
    if (device.sessionSid.isNotEmpty) 'sid': device.sessionSid,
    'aid': device.androidId,
    'os_ver': device.osRelease,
    'phonetype': device.model,
    'devicelevel': '${device.sdk}',
    'newdevicelevel': '${device.sdk}',
    'rom': device.fingerprint,
  };

  Map<String, String> buildHeaders(QqMusicDevice device) => {
    'Accept': 'application/json',
    'Content-Type': 'application/json; charset=utf-8',
    'User-Agent': 'QQMusic 14090008(android ${device.osRelease})',
  };
}
