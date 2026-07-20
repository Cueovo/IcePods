import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import 'package:qqmusic_ipod/core/utils/qimei_crypto.dart';

import 'package:qqmusic_ipod/data/models/device.dart';
import 'package:qqmusic_ipod/data/models/device_exception.dart';

class QqMusicQimeiResult {
  const QqMusicQimeiResult({required this.q16, required this.q36});

  final String q16;
  final String q36;
}

abstract interface class QqMusicQimeiProvider {
  Future<QqMusicQimeiResult> request(QqMusicDevice device);
}

class QqMusicQimeiService implements QqMusicQimeiProvider {
  QqMusicQimeiService({
    required this.client,
    Uri? uri,
    int Function()? clock,
    Random? random,
  }) : uri = uri ?? Uri.parse('https://api.tencentmusic.com/tme/trpc/proxy'),
       _clock = clock ?? (() => DateTime.now().millisecondsSinceEpoch),
       _random = random ?? Random.secure();

  static const appKey = '0AND0HD6FE4HY80F';
  static const appVersion = '14.9.0.8';
  static const sdkVersion = '1.2.13.6';
  static const _secret = 'ZdJqM15EeO2zWc08';
  static const _serviceSecret =
      'qimei_qq_androidpzAuCmaFAaFaHrdakPjLIEqKrGnSOOvH';
  final http.Client client;
  final Uri uri;
  final int Function() _clock;
  final Random _random;

  @override
  Future<QqMusicQimeiResult> request(QqMusicDevice device) async {
    final request = buildRequest(device);
    late http.Response response;
    try {
      response = await client.post(
        uri,
        headers: request.headers,
        body: jsonEncode(request.body),
      );
    } on http.ClientException catch (error) {
      throw QqMusicDeviceException('无法获取 QQ 音乐设备指纹：${error.message}');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw QqMusicDeviceException(
        'QQ 音乐设备指纹请求失败 (${response.statusCode})',
        statusCode: response.statusCode,
      );
    }
    try {
      final root = _map(jsonDecode(utf8.decode(response.bodyBytes)));
      final outerData = root['data'];
      final decodedData = outerData is String
          ? jsonDecode(outerData)
          : outerData;
      final data = _map(_map(decodedData)['data']);
      final q16 = _string(data['q16']);
      final q36 = _string(data['q36']);
      if (q16.isEmpty || q36.isEmpty) {
        throw const FormatException('缺少 QIMEI 字段');
      }
      return QqMusicQimeiResult(q16: q16, q36: q36);
    } on FormatException {
      throw const QqMusicDeviceException('QQ 音乐设备指纹响应无效');
    }
  }

  QqMusicFingerprintRequest buildRequest(QqMusicDevice device) {
    final nowMilliseconds = _clock();
    final nowSeconds = nowMilliseconds ~/ 1000;
    final signatureMilliseconds = nowSeconds * 1000;
    final cryptKey = randomDeviceHex(_random, 16);
    final nonce = randomDeviceHex(_random, 16);
    final payload = _buildPayload(device, nowMilliseconds);
    final key = base64Encode(encryptQimeiRsa(utf8.encode(cryptKey), _random));
    final params = base64Encode(
      encryptQimeiAes(utf8.encode(cryptKey), utf8.encode(jsonEncode(payload))),
    );
    const extra = '{"appKey":"$appKey"}';
    return QqMusicFingerprintRequest(
      headers: {
        'Content-Type': 'application/json; charset=utf-8',
        'method': 'GetQimei',
        'service': 'trpc.tme_datasvr.qimeiproxy.QimeiProxy',
        'appid': 'qimei_qq_android',
        'sign': _md5Text('$_serviceSecret$nowSeconds'),
        'user-agent': 'QQMusic',
        'timestamp': '$nowSeconds',
      },
      body: {
        'app': 0,
        'os': 1,
        'qimeiParams': {
          'key': key,
          'params': params,
          'time': '$nowSeconds',
          'nonce': nonce,
          'sign': _md5Text(
            '$key$params$signatureMilliseconds$nonce$_secret$extra',
          ),
          'extra': extra,
        },
      },
    );
  }

  Map<String, Object?> _buildPayload(
    QqMusicDevice device,
    int nowMilliseconds,
  ) {
    final now = DateTime.fromMillisecondsSinceEpoch(
      nowMilliseconds,
      isUtc: true,
    );
    final startup = now.subtract(Duration(seconds: _random.nextInt(14401)));
    final reserved = {
      'harmony': '0',
      'clone': '0',
      'containe': '',
      'oz': 'UhYmelwouA+V2nPWbOvLTgN2/m8jwGB+yUB5v9tysQg=',
      'oo': 'Xecjt+9S1+f8Pz2VLSxgpw==',
      'kelong': '0',
      'uptimes': _dateTime(startup),
      'multiUser': '0',
      'bod': device.brand,
      'dv': device.device,
      'firstLevel': '',
      'manufact': device.brand,
      'name': device.model,
      'host': 'se.infra',
      'kernel': device.procVersion,
    };
    return {
      'androidId': device.androidId,
      'platformId': 1,
      'appKey': appKey,
      'appVersion': appVersion,
      'beaconIdSrc': _randomBeaconId(now),
      'brand': device.brand,
      'channelId': '10003505',
      'cid': '',
      'imei': device.imei,
      'imsi': '',
      'mac': '',
      'model': device.model,
      'networkType': 'unknown',
      'oaid': '',
      'osVersion': 'Android ${device.osRelease},level ${device.sdk}',
      'qimei': '',
      'qimei36': '',
      'sdkVersion': sdkVersion,
      'targetSdkVersion': '33',
      'audit': '',
      'userId': '{}',
      'packageId': 'com.tencent.qqmusic',
      'deviceType': 'Phone',
      'sdkName': '',
      'reserved': jsonEncode(reserved),
    };
  }

  String _randomBeaconId(DateTime now) {
    final month =
        '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-01';
    final rand1 = 100000 + _random.nextInt(900000);
    final rand2 = 100000000 + _random.nextInt(900000000);
    final buffer = StringBuffer();
    const dated = {
      1,
      2,
      13,
      14,
      17,
      18,
      21,
      22,
      25,
      26,
      29,
      30,
      33,
      34,
      37,
      38,
    };
    for (var index = 1; index <= 40; index++) {
      if (dated.contains(index)) {
        buffer.write('k$index:$month$rand1.$rand2');
      } else if (index == 3) {
        buffer.write('k3:0000000000000000');
      } else if (index == 4) {
        buffer.write('k4:${randomDeviceHex(_random, 16, excludeZero: true)}');
      } else {
        buffer.write('k$index:${_random.nextInt(10000)}');
      }
      buffer.write(';');
    }
    return buffer.toString();
  }
}

class QqMusicFingerprintRequest {
  const QqMusicFingerprintRequest({required this.headers, required this.body});

  final Map<String, String> headers;
  final Map<String, Object?> body;
}

String _md5Text(String value) => md5.convert(utf8.encode(value)).toString();

String _dateTime(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')} '
    '${value.hour.toString().padLeft(2, '0')}:'
    '${value.minute.toString().padLeft(2, '0')}:'
    '${value.second.toString().padLeft(2, '0')}';

Map<String, dynamic> _map(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : const {};

String _string(Object? value) => value?.toString() ?? '';
