import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qqmusic_ipod/features/player/views/pages/now_playing_panel.dart';
import 'package:qqmusic_ipod/features/shell/models/ipod_models.dart';

void main() {
  testWidgets('opens lyrics when an external request revision changes', (
    tester,
  ) async {
    var revision = 0;
    late StateSetter rebuild;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 390,
            height: 500,
            child: StatefulBuilder(
              builder: (context, setState) {
                rebuild = setState;
                return _panel(revision);
              },
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('player-artwork-view')), findsOneWidget);

    rebuild(() => revision += 1);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const ValueKey('player-lyrics')), findsOneWidget);
  });
}

NowPlayingPanel _panel(int lyricsOpenRevision) {
  return NowPlayingPanel(
    album: const Album(title: 'Song', artist: 'Artist', imageUrl: ''),
    progress: .25,
    position: const Duration(seconds: 30),
    duration: const Duration(minutes: 2),
    rotationDelta: 0,
    isBuffering: false,
    error: '',
    lyricsOpenRevision: lyricsOpenRevision,
  );
}
