import 'dart:convert';

import 'package:crypto/crypto.dart';

int hash33(String value, [int seed = 0]) {
  var hash = seed;
  for (final unit in value.codeUnits) {
    hash += (hash << 5) + unit;
  }
  return hash & 0x7fffffff;
}

String createRequestSignature(String payload) {
  const part1Indexes = [23, 14, 6, 36, 16, 7, 19];
  const part2Indexes = [16, 1, 32, 12, 19, 27, 8, 5];
  const scrambleValues = [
    89,
    39,
    179,
    150,
    218,
    82,
    58,
    252,
    177,
    52,
    186,
    123,
    120,
    64,
    242,
    133,
    143,
    161,
    121,
    179,
  ];
  final digest = sha1.convert(utf8.encode(payload));
  final hashHex = digest.toString().toUpperCase();
  final part1 = part1Indexes.map((index) => hashHex[index]).join();
  final part2 = part2Indexes.map((index) => hashHex[index]).join();
  final scrambled = List<int>.generate(
    scrambleValues.length,
    (index) => scrambleValues[index] ^ digest.bytes[index],
    growable: false,
  );
  final encoded = base64Encode(scrambled).replaceAll(RegExp(r'[/+=\\]'), '');
  return 'zzc$part1$encoded$part2'.toLowerCase();
}
