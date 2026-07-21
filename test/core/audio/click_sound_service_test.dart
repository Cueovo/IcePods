import 'package:flutter_test/flutter_test.dart';
import 'package:qqmusic_ipod/core/audio/click_sound_service.dart';

void main() {
  test('minInterval is short enough for multi-step wheel flicks', () {
    // ~45 ticks/sec max; classic iPod density is far below this.
    expect(ClickSoundService.minInterval.inMilliseconds, lessThan(40));
    expect(
      ClickSoundService.minInterval.inMilliseconds,
      greaterThanOrEqualTo(15),
    );
  });
}
