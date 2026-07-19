import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qqmusic_ipod/features/qq_music/player/audio_handler.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('paused state keeps a stable playPause media action', () async {
    final handler = QqMusicAudioHandler();
    addTearDown(() async {
      await handler.stop();
      await handler.player.dispose();
    });

    await handler.pause();

    final state = handler.playbackState.value;
    expect(state.playing, isFalse);
    expect(state.controls.map((control) => control.action), [
      MediaAction.skipToPrevious,
      MediaAction.playPause,
      MediaAction.skipToNext,
    ]);
    expect(state.controls[1].androidIcon, 'drawable/audio_service_play_arrow');
    expect(state.androidCompactActionIndices, [0, 1, 2]);
  });
}
