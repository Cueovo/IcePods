import 'package:flutter_test/flutter_test.dart';

import 'package:qqmusic_ipod/core/audio/audio_handler.dart';

void main() {
  test('crossfade gains overlap outgoing fade-out and incoming fade-in', () {
    final start = QqMusicAudioHandler.crossfadeGains(0.8, 0);
    final middle = QqMusicAudioHandler.crossfadeGains(0.8, .5);
    final end = QqMusicAudioHandler.crossfadeGains(0.8, 1);

    expect(start.outgoing, 0.8);
    expect(start.incoming, 0);
    expect(middle.outgoing, 0.4);
    expect(middle.incoming, 0.4);
    expect(end.outgoing, 0);
    expect(end.incoming, 0.8);
    expect(QqMusicAudioHandler.crossfadeDuration, const Duration(seconds: 5));
  });
}
