import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

const qimeiRsaModulus =
    'c4231830a2eb5fc2827170641e79d80fec51bda9a22e4b4ab37d1f205a4ae44d928cda25879f66a3429051663312a127faf8a246bdaaf63918417e90d7c95b5908aa6a2d0f852e4a6770294a548ac1c2fe8f1f252fb826f4ac86ab9a00e7ce47d002a56e7c4b51eb889acc60ca6adbc9f72e81f4d31b1dd7464805264530ab1d';

Uint8List encryptQimeiAes(List<int> keyBytes, List<int> content) {
  final key = Uint8List.fromList(keyBytes);
  final cipher =
      PaddedBlockCipherImpl(PKCS7Padding(), CBCBlockCipher(AESEngine()))..init(
        true,
        PaddedBlockCipherParameters<ParametersWithIV<KeyParameter>, Null>(
          ParametersWithIV<KeyParameter>(KeyParameter(key), key),
          null,
        ),
      );
  return cipher.process(Uint8List.fromList(content));
}

Uint8List encryptQimeiRsa(List<int> content, Random random) {
  const blockLength = 128;
  if (content.length > blockLength - 11) {
    throw ArgumentError.value(content.length, 'content', 'QIMEI RSA 原文过长');
  }
  final paddingLength = blockLength - content.length - 3;
  final block = Uint8List(blockLength)
    ..[0] = 0
    ..[1] = 2;
  for (var index = 0; index < paddingLength; index++) {
    block[index + 2] = 1 + random.nextInt(255);
  }
  block[paddingLength + 2] = 0;
  block.setRange(paddingLength + 3, blockLength, content);
  final encrypted = _bytesToBigInt(
    block,
  ).modPow(BigInt.from(65537), BigInt.parse(qimeiRsaModulus, radix: 16));
  return _bigIntToBytes(encrypted, blockLength);
}

BigInt _bytesToBigInt(List<int> bytes) {
  var result = BigInt.zero;
  for (final byte in bytes) {
    result = (result << 8) | BigInt.from(byte);
  }
  return result;
}

Uint8List _bigIntToBytes(BigInt value, int length) {
  final result = Uint8List(length);
  var current = value;
  for (var index = length - 1; index >= 0; index--) {
    result[index] = (current & BigInt.from(0xff)).toInt();
    current >>= 8;
  }
  return result;
}
