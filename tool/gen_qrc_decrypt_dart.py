"""Generate lib/core/utils/qrc_decrypt.dart from qqmusic-web tripledes."""

from __future__ import annotations

import importlib.util
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
WEB_TRIPLEDES = Path(r"E:\Code\qqmusic-web\qqmusic_api\algorithms\tripledes.py")
OUT = ROOT / "lib" / "core" / "utils" / "qrc_decrypt.dart"


def load_tripledes():
    spec = importlib.util.spec_from_file_location("tripledes", WEB_TRIPLEDES)
    mod = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(mod)
    return mod


def main() -> None:
    td = load_tripledes()
    key = b"!@#)(*$%123ZXC!@!@#)(NHL"
    plain = b"[0,1000]hello(0,500) world(500,500)\n "
    compressed = zlib.compress(plain)
    assert len(compressed) % 8 == 0, len(compressed)
    schedule = td.tripledes_key_setup(key, td.ENCRYPT)
    cipher = b"".join(
        bytes(td.tripledes_crypt(bytearray(compressed[i : i + 8]), schedule))
        for i in range(0, len(compressed), 8)
    )
    fixture_hex = cipher.hex()
    # Round-trip via python decrypt path
    schedule_d = td.tripledes_key_setup(key, td.DECRYPT)
    data = b"".join(
        bytes(td.tripledes_crypt(bytearray(cipher[i : i + 8]), schedule_d))
        for i in range(0, len(cipher), 8)
    )
    assert zlib.decompress(data) == plain

    sbox_dart = (
        "const List<List<int>> _sbox = [\n"
        + ",\n".join(
            "  [" + ", ".join(map(str, row)) + "]" for row in td.sbox
        )
        + "\n];\n"
    )

    dart = f'''// Port of qqmusic-web/qqmusic_api/algorithms (QRC 3DES + zlib).
// Custom 3DES variant for QQ Music lyrics — not standard Triple-DES.
// SPDX-FileCopyrightText: Copyright (c) 2024 沉默の金 <cmzj@cmzj.org>
// SPDX-License-Identifier: GPL-3.0-only

import 'dart:convert';
import 'dart:typed_data';

const int _kEncrypt = 1;
const int _kDecrypt = 0;

/// Fixed 24-byte key used by QQ Music QRC (same as qqmusic-web).
final List<int> _qrc3desKey = utf8.encode(r'!@#)(*$%123ZXC!@!@#)(NHL');

{sbox_dart}
int _sboxBit(int a) {{
  // Same bit mash as qqmusic-web tripledes.sbox_bit.
  return (a & 32) | ((a & 31) >> 1) | ((a & 1) << 4);
}}

List<int> _initialPermutation(List<int> inputData) {{
  final v0 = inputData[0] |
      (inputData[1] << 8) |
      (inputData[2] << 16) |
      (inputData[3] << 24);
  final v1 = inputData[4] |
      (inputData[5] << 8) |
      (inputData[6] << 16) |
      (inputData[7] << 24);

  final s0 = ((v1 >> 6) & 1) << 31 |
      ((v1 >> 14) & 1) << 30 |
      ((v1 >> 22) & 1) << 29 |
      ((v1 >> 30) & 1) << 28 |
      ((v0 >> 6) & 1) << 27 |
      ((v0 >> 14) & 1) << 26 |
      ((v0 >> 22) & 1) << 25 |
      ((v0 >> 30) & 1) << 24 |
      ((v1 >> 4) & 1) << 23 |
      ((v1 >> 12) & 1) << 22 |
      ((v1 >> 20) & 1) << 21 |
      ((v1 >> 28) & 1) << 20 |
      ((v0 >> 4) & 1) << 19 |
      ((v0 >> 12) & 1) << 18 |
      ((v0 >> 20) & 1) << 17 |
      ((v0 >> 28) & 1) << 16 |
      ((v1 >> 2) & 1) << 15 |
      ((v1 >> 10) & 1) << 14 |
      ((v1 >> 18) & 1) << 13 |
      ((v1 >> 26) & 1) << 12 |
      ((v0 >> 2) & 1) << 11 |
      ((v0 >> 10) & 1) << 10 |
      ((v0 >> 18) & 1) << 9 |
      ((v0 >> 26) & 1) << 8 |
      ((v1 >> 0) & 1) << 7 |
      ((v1 >> 8) & 1) << 6 |
      ((v1 >> 16) & 1) << 5 |
      ((v1 >> 24) & 1) << 4 |
      ((v0 >> 0) & 1) << 3 |
      ((v0 >> 8) & 1) << 2 |
      ((v0 >> 16) & 1) << 1 |
      ((v0 >> 24) & 1);

  final s1 = ((v1 >> 7) & 1) << 31 |
      ((v1 >> 15) & 1) << 30 |
      ((v1 >> 23) & 1) << 29 |
      ((v1 >> 31) & 1) << 28 |
      ((v0 >> 7) & 1) << 27 |
      ((v0 >> 15) & 1) << 26 |
      ((v0 >> 23) & 1) << 25 |
      ((v0 >> 31) & 1) << 24 |
      ((v1 >> 5) & 1) << 23 |
      ((v1 >> 13) & 1) << 22 |
      ((v1 >> 21) & 1) << 21 |
      ((v1 >> 29) & 1) << 20 |
      ((v0 >> 5) & 1) << 19 |
      ((v0 >> 13) & 1) << 18 |
      ((v0 >> 21) & 1) << 17 |
      ((v0 >> 29) & 1) << 16 |
      ((v1 >> 3) & 1) << 15 |
      ((v1 >> 11) & 1) << 14 |
      ((v1 >> 19) & 1) << 13 |
      ((v1 >> 27) & 1) << 12 |
      ((v0 >> 3) & 1) << 11 |
      ((v0 >> 11) & 1) << 10 |
      ((v0 >> 19) & 1) << 9 |
      ((v0 >> 27) & 1) << 8 |
      ((v1 >> 1) & 1) << 7 |
      ((v1 >> 9) & 1) << 6 |
      ((v1 >> 17) & 1) << 5 |
      ((v1 >> 25) & 1) << 4 |
      ((v0 >> 1) & 1) << 3 |
      ((v0 >> 9) & 1) << 2 |
      ((v0 >> 17) & 1) << 1 |
      ((v0 >> 25) & 1);

  return [s0, s1];
}}

List<int> _inversePermutation(int s0, int s1) {{
  final data = List<int>.filled(8, 0);
  data[3] = ((s1 >> 24) & 1) << 7 |
      ((s0 >> 24) & 1) << 6 |
      ((s1 >> 16) & 1) << 5 |
      ((s0 >> 16) & 1) << 4 |
      ((s1 >> 8) & 1) << 3 |
      ((s0 >> 8) & 1) << 2 |
      ((s1 >> 0) & 1) << 1 |
      ((s0 >> 0) & 1);
  data[2] = ((s1 >> 25) & 1) << 7 |
      ((s0 >> 25) & 1) << 6 |
      ((s1 >> 17) & 1) << 5 |
      ((s0 >> 17) & 1) << 4 |
      ((s1 >> 9) & 1) << 3 |
      ((s0 >> 9) & 1) << 2 |
      ((s1 >> 1) & 1) << 1 |
      ((s0 >> 1) & 1);
  data[1] = ((s1 >> 26) & 1) << 7 |
      ((s0 >> 26) & 1) << 6 |
      ((s1 >> 18) & 1) << 5 |
      ((s0 >> 18) & 1) << 4 |
      ((s1 >> 10) & 1) << 3 |
      ((s0 >> 10) & 1) << 2 |
      ((s1 >> 2) & 1) << 1 |
      ((s0 >> 2) & 1);
  data[0] = ((s1 >> 27) & 1) << 7 |
      ((s0 >> 27) & 1) << 6 |
      ((s1 >> 19) & 1) << 5 |
      ((s0 >> 19) & 1) << 4 |
      ((s1 >> 11) & 1) << 3 |
      ((s0 >> 11) & 1) << 2 |
      ((s1 >> 3) & 1) << 1 |
      ((s0 >> 3) & 1);
  data[7] = ((s1 >> 28) & 1) << 7 |
      ((s0 >> 28) & 1) << 6 |
      ((s1 >> 20) & 1) << 5 |
      ((s0 >> 20) & 1) << 4 |
      ((s1 >> 12) & 1) << 3 |
      ((s0 >> 12) & 1) << 2 |
      ((s1 >> 4) & 1) << 1 |
      ((s0 >> 4) & 1);
  data[6] = ((s1 >> 29) & 1) << 7 |
      ((s0 >> 29) & 1) << 6 |
      ((s1 >> 21) & 1) << 5 |
      ((s0 >> 21) & 1) << 4 |
      ((s1 >> 13) & 1) << 3 |
      ((s0 >> 13) & 1) << 2 |
      ((s1 >> 5) & 1) << 1 |
      ((s0 >> 5) & 1);
  data[5] = ((s1 >> 30) & 1) << 7 |
      ((s0 >> 30) & 1) << 6 |
      ((s1 >> 22) & 1) << 5 |
      ((s0 >> 22) & 1) << 4 |
      ((s1 >> 14) & 1) << 3 |
      ((s0 >> 14) & 1) << 2 |
      ((s1 >> 6) & 1) << 1 |
      ((s0 >> 6) & 1);
  data[4] = ((s1 >> 31) & 1) << 7 |
      ((s0 >> 31) & 1) << 6 |
      ((s1 >> 23) & 1) << 5 |
      ((s0 >> 23) & 1) << 4 |
      ((s1 >> 15) & 1) << 3 |
      ((s0 >> 15) & 1) << 2 |
      ((s1 >> 7) & 1) << 1 |
      ((s0 >> 7) & 1);
  return data;
}}

int _f(int state, List<int> key) {{
  final t1 = ((state & 1) << 31) |
      ((state & 0xF8000000) >> 1) |
      ((state & 0x1F800000) >> 3) |
      ((state & 0x01F80000) >> 5) |
      ((state & 0x001F8000) >> 7);
  final t2 = ((state & 0x0001F800) << 15) |
      ((state & 0x00001F80) << 13) |
      ((state & 0x000001F8) << 11) |
      ((state & 0x0000001F) << 9) |
      ((state & 0x80000000) >> 23);

  final k0 = ((t1 >> 24) & 0xFF) ^ key[0];
  final k1 = ((t1 >> 16) & 0xFF) ^ key[1];
  final k2 = ((t1 >> 8) & 0xFF) ^ key[2];
  final k3 = ((t2 >> 24) & 0xFF) ^ key[3];
  final k4 = ((t2 >> 16) & 0xFF) ^ key[4];
  final k5 = ((t2 >> 8) & 0xFF) ^ key[5];

  final out = (_sbox[0][_sboxBit(k0 >> 2)] << 28) |
      (_sbox[1][_sboxBit(((k0 & 0x03) << 4) | (k1 >> 4))] << 24) |
      (_sbox[2][_sboxBit(((k1 & 0x0F) << 2) | (k2 >> 6))] << 20) |
      (_sbox[3][_sboxBit(k2 & 0x3F)] << 16) |
      (_sbox[4][_sboxBit(k3 >> 2)] << 12) |
      (_sbox[5][_sboxBit(((k3 & 0x03) << 4) | (k4 >> 4))] << 8) |
      (_sbox[6][_sboxBit(((k4 & 0x0F) << 2) | (k5 >> 6))] << 4) |
      _sbox[7][_sboxBit(k5 & 0x3F)];

  return ((out >> 16) & 1) << 31 |
      ((out >> 25) & 1) << 30 |
      ((out >> 12) & 1) << 29 |
      ((out >> 11) & 1) << 28 |
      ((out >> 3) & 1) << 27 |
      ((out >> 20) & 1) << 26 |
      ((out >> 4) & 1) << 25 |
      ((out >> 15) & 1) << 24 |
      ((out >> 31) & 1) << 23 |
      ((out >> 17) & 1) << 22 |
      ((out >> 9) & 1) << 21 |
      ((out >> 6) & 1) << 20 |
      ((out >> 27) & 1) << 19 |
      ((out >> 14) & 1) << 18 |
      ((out >> 1) & 1) << 17 |
      ((out >> 22) & 1) << 16 |
      ((out >> 30) & 1) << 15 |
      ((out >> 24) & 1) << 14 |
      ((out >> 8) & 1) << 13 |
      ((out >> 18) & 1) << 12 |
      ((out >> 0) & 1) << 11 |
      ((out >> 5) & 1) << 10 |
      ((out >> 29) & 1) << 9 |
      ((out >> 23) & 1) << 8 |
      ((out >> 13) & 1) << 7 |
      ((out >> 19) & 1) << 6 |
      ((out >> 2) & 1) << 5 |
      ((out >> 26) & 1) << 4 |
      ((out >> 10) & 1) << 3 |
      ((out >> 21) & 1) << 2 |
      ((out >> 28) & 1) << 1 |
      ((out >> 7) & 1);
}}

List<int> _crypt(List<int> inputData, List<List<int>> key) {{
  final permuted = _initialPermutation(inputData);
  var s0 = permuted[0];
  var s1 = permuted[1];
  for (var idx = 0; idx < 15; idx++) {{
    final previousS1 = s1;
    s1 = _f(s1, key[idx]) ^ s0;
    s0 = previousS1;
  }}
  s0 = _f(s1, key[15]) ^ s0;
  return _inversePermutation(s0, s1);
}}

const List<int> _keyRndShift = [1, 1, 2, 2, 2, 2, 2, 2, 1, 2, 2, 2, 2, 2, 2, 1];
const List<int> _keyPermC = [
  56, 48, 40, 32, 24, 16, 8, 0, 57, 49, 41, 33, 25, 17, 9, 1, 58, 50, 42, 34,
  26, 18, 10, 2, 59, 51, 43, 35,
];
const List<int> _keyPermD = [
  62, 54, 46, 38, 30, 22, 14, 6, 61, 53, 45, 37, 29, 21, 13, 5, 60, 52, 44, 36,
  28, 20, 12, 4, 27, 19, 11, 3,
];
const List<int> _keyCompression = [
  13, 16, 10, 23, 0, 4, 2, 27, 14, 5, 20, 9, 22, 18, 11, 3, 25, 7, 15, 6, 26,
  19, 12, 1, 40, 51, 30, 36, 46, 54, 29, 39, 50, 44, 32, 47, 43, 48, 38, 55, 33,
  52, 45, 41, 49, 35, 28, 31,
];

List<List<int>> _keySchedule(List<int> key, int mode) {{
  final schedule = List.generate(16, (_) => List<int>.filled(6, 0));
  final v0 = key[0] | (key[1] << 8) | (key[2] << 16) | (key[3] << 24);
  final v1 = key[4] | (key[5] << 8) | (key[6] << 16) | (key[7] << 24);

  var c = 0;
  for (var i = 0; i < _keyPermC.length; i++) {{
    final b = _keyPermC[i];
    final bit = b < 32 ? ((v0 >> (31 - b)) & 1) : ((v1 >> (63 - b)) & 1);
    c |= bit << (31 - i);
  }}

  var d = 0;
  for (var i = 0; i < _keyPermD.length; i++) {{
    final b = _keyPermD[i];
    final bit = b < 32 ? ((v0 >> (31 - b)) & 1) : ((v1 >> (63 - b)) & 1);
    d |= bit << (31 - i);
  }}

  for (var i = 0; i < 16; i++) {{
    c = ((c << _keyRndShift[i]) | (c >> (28 - _keyRndShift[i]))) & 0xFFFFFFF0;
    d = ((d << _keyRndShift[i]) | (d >> (28 - _keyRndShift[i]))) & 0xFFFFFFF0;
    final togen = mode == _kDecrypt ? 15 - i : i;
    for (var j = 0; j < 6; j++) {{
      schedule[togen][j] = 0;
    }}
    for (var j = 0; j < 24; j++) {{
      final bit = (c >> (31 - _keyCompression[j])) & 1;
      schedule[togen][j ~/ 8] |= bit << (7 - (j % 8));
    }}
    for (var j = 24; j < 48; j++) {{
      final bit = (d >> (31 - (_keyCompression[j] - 27))) & 1;
      schedule[togen][j ~/ 8] |= bit << (7 - (j % 8));
    }}
  }}
  return schedule;
}}

List<List<List<int>>> _tripledesKeySetup(List<int> key, int mode) {{
  if (mode == _kEncrypt) {{
    return [
      _keySchedule(key.sublist(0, 8), _kEncrypt),
      _keySchedule(key.sublist(8, 16), _kDecrypt),
      _keySchedule(key.sublist(16, 24), _kEncrypt),
    ];
  }}
  return [
    _keySchedule(key.sublist(16, 24), _kDecrypt),
    _keySchedule(key.sublist(8, 16), _kEncrypt),
    _keySchedule(key.sublist(0, 8), _kDecrypt),
  ];
}}

List<int> _tripledesCrypt(List<int> data, List<List<List<int>>> key) {{
  var block = List<int>.from(data);
  for (var i = 0; i < 3; i++) {{
    block = _crypt(block, key[i]);
  }}
  return block;
}}

/// Decrypt QQ Music encrypted lyric / QRC payload.
///
/// Official responses use `crypt == 1` with a hex-encoded ciphertext that is
/// 3DES-decrypted (custom schedule) then zlib-inflated — same as qqmusic-web.
String qrcDecrypt(String encryptedQrc) {{
  if (encryptedQrc.isEmpty) {{
    return '';
  }}
  final encryptedBytes = _hexToBytes(encryptedQrc);
  final schedule = _tripledesKeySetup(_qrc3desKey, _kDecrypt);
  final decrypted = BytesBuilder(copy: false);
  for (var i = 0; i + 8 <= encryptedBytes.length; i += 8) {{
    decrypted.add(_tripledesCrypt(encryptedBytes.sublist(i, i + 8), schedule));
  }}
  final inflated = ZLibCodec().decode(decrypted.takeBytes());
  return utf8.decode(inflated);
}}

Uint8List _hexToBytes(String hex) {{
  final cleaned = hex.replaceAll(RegExp(r'\\s+'), '');
  if (cleaned.length.isOdd) {{
    throw const FormatException('QRC hex length is odd');
  }}
  final out = Uint8List(cleaned.length ~/ 2);
  for (var i = 0; i < out.length; i++) {{
    out[i] = int.parse(cleaned.substring(i * 2, i * 2 + 2), radix: 16);
  }}
  return out;
}}
'''

    OUT.write_text(dart, encoding="utf-8")
    (ROOT / "tool" / "qrc_fixture.hex").write_text(fixture_hex, encoding="utf-8")
    (ROOT / "tool" / "qrc_fixture.plain").write_text(
        plain.decode("utf-8"), encoding="utf-8"
    )
    print(f"wrote {OUT} ({OUT.stat().st_size} bytes)")
    print(f"fixture hex length={len(fixture_hex)}")


if __name__ == "__main__":
    main()
