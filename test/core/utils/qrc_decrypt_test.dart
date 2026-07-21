import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:qqmusic_ipod/core/utils/qrc_decrypt.dart';
import 'package:qqmusic_ipod/data/models/response_parser.dart';

void main() {
  test('qrcDecrypt matches qqmusic-web fixture', () {
    final hex = File('tool/qrc_fixture.hex').readAsStringSync().trim();
    final plain = File('tool/qrc_fixture.plain')
        .readAsStringSync()
        .replaceAll('\r\n', '\n');
    expect(qrcDecrypt(hex), plain);
  });

  test('parses encrypted official lyric payload into word timeline', () {
    final hex = File('tool/qrc_fixture.hex').readAsStringSync().trim();
    const parser = QqMusicResponseParser();
    final lyrics = parser.parseLyrics({
      'crypt': 1,
      'lyric': hex,
    });
    expect(lyrics.lines, isNotEmpty);
    expect(lyrics.lines.first.hasWordTimeline, isTrue);
    expect(lyrics.lines.first.text, contains('hello'));
    expect(lyrics.lines.first.words, isNotEmpty);
  });
}
