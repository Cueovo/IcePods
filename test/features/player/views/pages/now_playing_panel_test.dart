import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qqmusic_ipod/business/entities/music.dart';
import 'package:qqmusic_ipod/features/player/views/pages/now_playing_panel.dart';
import 'package:qqmusic_ipod/features/shell/models/ipod_models.dart';

void main() {
  testWidgets('shows a live sleep timer countdown', (tester) async {
    final deadline = DateTime.now().add(const Duration(minutes: 1, seconds: 5));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 390,
            height: 280,
            child: _panel(0, sleepTimerDeadline: deadline),
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('player-sleep-timer')), findsOneWidget);
    expect(find.text('01:05'), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));

    expect(find.text('01:04'), findsOneWidget);
  });

  testWidgets('centers the first active lyric line', (tester) async {
    const lyrics = QqMusicLyrics(
      lines: [
        QqMusicLyricLine(time: Duration.zero, text: 'First line'),
        QqMusicLyricLine(time: Duration(seconds: 10), text: 'Second line'),
        QqMusicLyricLine(time: Duration(seconds: 20), text: 'Third line'),
      ],
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 390,
            height: 500,
            child: NowPlayingPanel(
              album: Album(title: 'Song', artist: 'Artist', imageUrl: ''),
              progress: 0,
              position: Duration.zero,
              duration: Duration(minutes: 2),
              rotationDelta: 0,
              isBuffering: false,
              error: '',
              lyrics: lyrics,
              lyricsOpenRevision: 1,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final listCenter = tester.getCenter(
      find.byKey(const ValueKey('lyrics-scroll-list')),
    );
    final activeLineCenter = tester.getCenter(
      find.byKey(const ValueKey('lyric-line-0')),
    );
    expect(activeLineCenter.dy, closeTo(listCenter.dy, 0.01));
  });

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

NowPlayingPanel _panel(int lyricsOpenRevision, {DateTime? sleepTimerDeadline}) {
  return NowPlayingPanel(
    album: const Album(title: 'Song', artist: 'Artist', imageUrl: ''),
    progress: .25,
    position: const Duration(seconds: 30),
    duration: const Duration(minutes: 2),
    rotationDelta: 0,
    isBuffering: false,
    error: '',
    lyricsOpenRevision: lyricsOpenRevision,
    sleepTimerDeadline: sleepTimerDeadline,
  );
}
