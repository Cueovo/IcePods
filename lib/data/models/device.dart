import 'dart:math';

class QqMusicDevice {
  QqMusicDevice({
    required this.display,
    required this.fingerprint,
    required this.bootId,
    required this.procVersion,
    required this.imei,
    required this.androidId,
    required this.openUdid,
    this.qimei = '',
    this.qimei36 = '',
    this.qimeiSavedAt = 0,
    this.sessionUid = '',
    this.sessionSid = '',
    this.sessionVkey = '',
    this.sessionSavedAt = 0,
    this.product = 'iarim',
    this.device = 'sagit',
    this.board = 'eomam',
    this.model = 'MI 6',
    this.brand = 'Xiaomi',
    this.osRelease = '10',
    this.sdk = 29,
  });

  factory QqMusicDevice.random([Random? random]) {
    final source = random ?? Random.secure();
    return QqMusicDevice(
      display: 'QMAPI.${_randomDigits(source, 6)}.001',
      fingerprint:
          'xiaomi/iarim/sagit:10/eomam.200122.001/'
          '${_randomDigits(source, 7)}:user/release-keys',
      bootId: _uuid(source),
      procVersion:
          'Linux 5.4.0-54-generic-${_randomText(source, 8)} '
          '(android-build@google.com)',
      imei: _randomImei(source),
      androidId: randomDeviceHex(source, 16),
      openUdid: randomDeviceHex(source, 32),
    );
  }

  factory QqMusicDevice.fromJson(Map<String, dynamic> json) {
    final version = _map(json['version']);
    return QqMusicDevice(
      display: _string(json['display']),
      fingerprint: _string(json['fingerprint']),
      bootId: _string(json['boot_id']),
      procVersion: _string(json['proc_version']),
      imei: _string(json['imei']),
      androidId: _string(json['android_id']),
      openUdid: _string(json['open_udid']),
      qimei: _string(json['qimei']),
      qimei36: _string(json['qimei36']),
      qimeiSavedAt: _int(json['qimei_save_time']),
      sessionUid: _string(json['session_uid']),
      sessionSid: _string(json['session_sid']),
      sessionVkey: _string(json['session_vkey']),
      sessionSavedAt: _int(json['session_save_time']),
      product: _string(json['product'], 'iarim'),
      device: _string(json['device'], 'sagit'),
      board: _string(json['board'], 'eomam'),
      model: _string(json['model'], 'MI 6'),
      brand: _string(json['brand'], 'Xiaomi'),
      osRelease: _string(version['release'], '10'),
      sdk: _int(version['sdk'], 29),
    );
  }

  final String display;
  final String product;
  final String device;
  final String board;
  final String model;
  final String fingerprint;
  final String bootId;
  final String procVersion;
  final String imei;
  final String brand;
  final String androidId;
  final String osRelease;
  final int sdk;
  final String openUdid;
  String qimei;
  String qimei36;
  int qimeiSavedAt;
  String sessionUid;
  String sessionSid;
  String sessionVkey;
  int sessionSavedAt;

  bool get hasValidIdentity =>
      display.isNotEmpty &&
      fingerprint.isNotEmpty &&
      procVersion.isNotEmpty &&
      imei.length == 15 &&
      androidId.length == 16 &&
      openUdid.length == 32;

  bool hasFreshQimei(int nowSeconds) =>
      qimei.isNotEmpty &&
      qimei36.isNotEmpty &&
      nowSeconds - qimeiSavedAt < const Duration(days: 1).inSeconds;

  bool hasFreshSession(int nowSeconds) =>
      sessionUid.isNotEmpty &&
      sessionSid.isNotEmpty &&
      nowSeconds - sessionSavedAt < const Duration(days: 1).inSeconds;

  Map<String, dynamic> toJson() => {
    'display': display,
    'product': product,
    'device': device,
    'board': board,
    'model': model,
    'fingerprint': fingerprint,
    'boot_id': bootId,
    'proc_version': procVersion,
    'imei': imei,
    'brand': brand,
    'android_id': androidId,
    'version': {'release': osRelease, 'sdk': sdk},
    'qimei': qimei,
    'qimei36': qimei36,
    'qimei_save_time': qimeiSavedAt,
    'session_uid': sessionUid,
    'session_sid': sessionSid,
    'session_vkey': sessionVkey,
    'session_save_time': sessionSavedAt,
    'open_udid': openUdid,
  };
}

String randomDeviceHex(Random random, int length, {bool excludeZero = false}) {
  const chars = '0123456789abcdef';
  final start = excludeZero ? 1 : 0;
  return List.generate(
    length,
    (_) => chars[start + random.nextInt(chars.length - start)],
    growable: false,
  ).join();
}

String _randomText(Random random, int length) {
  const chars =
      'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  return List.generate(
    length,
    (_) => chars[random.nextInt(chars.length)],
    growable: false,
  ).join();
}

String _randomDigits(Random random, int length) =>
    List.generate(length, (_) => random.nextInt(10), growable: false).join();

String _randomImei(Random random) {
  final digits = List<int>.generate(14, (_) => random.nextInt(10));
  var sum = 0;
  for (var index = 0; index < digits.length; index++) {
    var digit = digits[index];
    if (index.isOdd) {
      digit *= 2;
      if (digit > 9) digit -= 9;
    }
    sum += digit;
  }
  digits.add((10 - sum % 10) % 10);
  return digits.join();
}

String _uuid(Random random) {
  final hex = randomDeviceHex(random, 32).split('');
  hex[12] = '4';
  final variant = int.parse(hex[16], radix: 16);
  hex[16] = (8 | (variant & 3)).toRadixString(16);
  return '${hex.take(8).join()}-${hex.skip(8).take(4).join()}-'
      '${hex.skip(12).take(4).join()}-${hex.skip(16).take(4).join()}-'
      '${hex.skip(20).join()}';
}

Map<String, dynamic> _map(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : const {};

String _string(Object? value, [String fallback = '']) {
  final result = value?.toString() ?? '';
  return result.isEmpty ? fallback : result;
}

int _int(Object? value, [int fallback = 0]) =>
    value is num ? value.toInt() : int.tryParse('$value') ?? fallback;
