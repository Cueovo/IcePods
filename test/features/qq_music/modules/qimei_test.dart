import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:qqmusic_ipod/features/qq_music/models/device.dart';
import 'package:qqmusic_ipod/features/qq_music/modules/qimei.dart';

void main() {
  test('虚拟 Android 设备身份字段稳定且 IMEI 校验有效', () {
    final device = QqMusicDevice.random(Random(7));
    final restored = QqMusicDevice.fromJson(device.toJson());

    expect(device.hasValidIdentity, isTrue);
    expect(_isValidImei(device.imei), isTrue);
    expect(restored.toJson(), device.toJson());
  });

  test('QIMEI 请求包含完整额外指纹负载并解析双标识', () async {
    late http.Request captured;
    final transport = MockClient((request) async {
      captured = request;
      return http.Response(
        jsonEncode({
          'data': jsonEncode({
            'data': {'q16': 'qimei-16', 'q36': 'qimei-36'},
          }),
        }),
        200,
      );
    });
    final service = QqMusicQimeiService(
      client: transport,
      clock: () => 1700000000123,
      random: Random(11),
    );
    addTearDown(transport.close);

    final result = await service.request(QqMusicDevice.random(Random(9)));
    final body = jsonDecode(captured.body) as Map<String, dynamic>;
    final params = body['qimeiParams'] as Map<String, dynamic>;

    expect(captured.url.host, 'api.tencentmusic.com');
    expect(captured.headers['method'], 'GetQimei');
    expect(captured.headers['service'], contains('QimeiProxy'));
    expect(captured.headers['timestamp'], '1700000000');
    expect(params['time'], '1700000000');
    expect(params['nonce'], hasLength(16));
    expect(base64Decode(params['key'] as String), hasLength(128));
    expect(base64Decode(params['params'] as String).length % 16, 0);
    expect(params['sign'], hasLength(32));
    expect(result.q16, 'qimei-16');
    expect(result.q36, 'qimei-36');
  });
}

bool _isValidImei(String imei) {
  if (imei.length != 15) return false;
  var sum = 0;
  for (var index = 0; index < imei.length; index++) {
    var digit = int.parse(imei[index]);
    if (index.isOdd) {
      digit *= 2;
      if (digit > 9) digit -= 9;
    }
    sum += digit;
  }
  return sum % 10 == 0;
}
