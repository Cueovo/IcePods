import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qqmusic_ipod/business/entities/music.dart';
import 'package:qqmusic_ipod/features/library/views/widgets/media_tile.dart';
import 'package:qqmusic_ipod/features/player/views/pages/now_playing_panel.dart';
import 'package:qqmusic_ipod/features/player/views/widgets/playback_queue_panel.dart';
import 'package:qqmusic_ipod/features/shell/models/ipod_models.dart';
import 'package:qqmusic_ipod/features/shell/models/menu_catalog.dart';
import 'package:qqmusic_ipod/features/shell/views/widgets/feature_list_skeleton.dart';
import 'package:qqmusic_ipod/features/shell/views/widgets/home_panel.dart';

Iterable<SemanticsProperties> _semanticProperties(WidgetTester tester) {
  return tester
      .widgetList<Semantics>(find.byType(Semantics))
      .map((widget) => widget.properties);
}

Widget _wrap(Widget child, {double textScale = 1, bool reduceMotion = false}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(
        textScaler: TextScaler.linear(textScale),
        disableAnimations: reduceMotion,
      ),
      child: Scaffold(body: SizedBox(width: 390, height: 520, child: child)),
    ),
  );
}

QqMusicItem _song({bool vip = false}) {
  return QqMusicItem(
    id: 'song-1',
    title: '歌曲一',
    subtitle: '歌手一',
    imageUrl: '',
    type: QqMusicItemType.song,
    requiresVip: vip,
  );
}

void main() {
  testWidgets('menu rows are buttons with position and selection', (
    tester,
  ) async {
    var activated = -1;
    final page = qqMusicMenuPages[MenuSection.root]!;

    await tester.pumpWidget(
      _wrap(
        HomePanel(
          page: page,
          selectedIndex: 1,
          onSelectIndex: (index) => activated = index,
        ),
      ),
    );
    await tester.pump();

    final rows = _semanticProperties(
      tester,
    ).where((properties) => properties.button ?? false).toList();

    expect(rows, isNotEmpty);
    expect(rows.where((row) => row.selected ?? false), hasLength(1));
    expect(rows.first.label, contains('共 ${page.entries.length} 项'));

    await tester.tap(find.text(page.entries.first.label));
    expect(activated, 0);
  });

  testWidgets('media rows announce playback and VIP state', (tester) async {
    await tester.pumpWidget(
      _wrap(
        MediaTile(
          item: _song(vip: true),
          selected: true,
          current: true,
          playing: true,
          marked: false,
          unavailable: false,
          canToggleMark: false,
          onSelect: () {},
          onToggleMark: () {},
        ),
      ),
    );
    await tester.pump();

    final label = _semanticProperties(
      tester,
    ).firstWhere((properties) => properties.button ?? false).label;

    expect(label, contains('歌曲一'));
    expect(label, contains('正在播放'));
    expect(label, contains('VIP 歌曲'));
  });

  testWidgets('playback progress exposes accessible seek actions', (
    tester,
  ) async {
    var seeked = -1.0;

    await tester.pumpWidget(
      _wrap(
        NowPlayingPanel(
          album: const Album(title: '歌曲', artist: '歌手', imageUrl: ''),
          progress: .5,
          position: const Duration(seconds: 60),
          duration: const Duration(minutes: 2),
          rotationDelta: 0,
          isBuffering: false,
          error: '',
          onSeekTo: (value) => seeked = value,
        ),
      ),
    );
    await tester.pump();

    final progress = _semanticProperties(
      tester,
    ).firstWhere((properties) => properties.label == '播放进度');

    expect(progress.value, '50%');
    expect(progress.increasedValue, '55%');
    expect(progress.decreasedValue, '45%');
    expect(progress.onIncrease, isNotNull);

    progress.onIncrease!();
    expect(seeked, closeTo(.55, 0.0001));
  });

  testWidgets('queue rows grow with the text scale', (tester) async {
    Future<double> extentAt(double scale) async {
      await tester.pumpWidget(
        _wrap(
          PlaybackQueuePanel(
            queue: [_song()],
            currentIndex: 0,
            selectedIndex: 0,
            isPlaying: false,
            onPlayIndex: (_) {},
            onRemoveIndex: (_) {},
            onClearUpcoming: () {},
          ),
          textScale: scale,
        ),
      );
      await tester.pump();
      return tester
              .widget<ListView>(
                find.byKey(const ValueKey('playback-queue-list')),
              )
              .itemExtent ??
          0;
    }

    final normal = await extentAt(1);
    final large = await extentAt(2);

    expect(normal, 58);
    expect(large, greaterThan(normal));
  });

  testWidgets('the loading skeleton stops shimmering under reduced motion', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const FeatureListSkeleton()));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.hasRunningAnimations, isTrue);

    await tester.pumpWidget(
      _wrap(const FeatureListSkeleton(), reduceMotion: true),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('the queue stays a labelled container for traversal', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        PlaybackQueuePanel(
          queue: [_song()],
          currentIndex: 0,
          selectedIndex: 0,
          isPlaying: true,
          onPlayIndex: (_) {},
          onRemoveIndex: (_) {},
          onClearUpcoming: () {},
        ),
      ),
    );
    await tester.pump();

    // The queue itself stays a labelled container for assistive traversal.
    expect(
      _semanticProperties(
        tester,
      ).any((properties) => properties.label == '播放队列'),
      isTrue,
    );
  });
}
