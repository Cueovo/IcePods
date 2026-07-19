import 'package:flutter_test/flutter_test.dart';
import 'package:qqmusic_ipod/features/qq_music/algorithms/sign.dart';

void main() {
  test('hash33 使用 QQ 二维码 token 默认种子', () {
    expect(hash33('qr-signature'), 1876578754);
    expect(hash33('abc'), 108966);
    expect(hash33('abc', 5381), 193485963);
  });

  test('zzc 签名与 Python SDK 固定向量一致', () {
    const payload =
        '{"comm":{"ct":24},"req_0":{"module":"test","method":"run","param":{"enabled":1}}}';

    expect(
      createRequestSignature(payload),
      'zzcc7d2fd1qvpisdgeoxaxayhncb3fcyxvukf0441031',
    );
  });
}
