import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qqmusic_ipod/business/entities/music.dart';
import 'package:qqmusic_ipod/features/player/views/widgets/playback_queue_panel.dart';

const _firstSong = QqMusicItem(
  id: 'song-1',
  title: 'First Song',
  subtitle: 'First Artist',
  imageUrl: '',
  type: QqMusicItemType.song,
);

const _secondSong = QqMusicItem(
  id: 'song-2',
  title: 'Second Song',
  subtitle: 'Second Artist',
  imageUrl: '',
  type: QqMusicItemType.song,
);

const _vipSong = QqMusicItem(
  id: 'vip-song',
  title: 'VIP Song',
  subtitle: 'VIP Artist',
  imageUrl: '',
  type: QqMusicItemType.song,
  requiresVip: true,
);

QqMusicItem _song(int number) {
  return QqMusicItem(
    id: 'song-$number',
    title: 'Song $number',
    subtitle: 'Artist $number',
    imageUrl: '',
    type: QqMusicItemType.song,
  );
}

void main() {
  testWidgets('exposes queue play, remove, and clear actions', (tester) async {
    int? playedIndex;
    int? removedIndex;
    var cleared = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            height: 420,
            child: PlaybackQueuePanel(
              queue: const [_firstSong, _secondSong],
              currentIndex: 0,
              selectedIndex: 0,
              isPlaying: true,
              onPlayIndex: (index) => playedIndex = index,
              onRemoveIndex: (index) => removedIndex = index,
              onClearUpcoming: () => cleared = true,
            ),
          ),
        ),
      ),
    );

    expect(find.text('播放队列'), findsOneWidget);
    expect(find.byKey(const ValueKey('queue-remove-0-song-1')), findsNothing);
    expect(find.byKey(const ValueKey('queue-remove-1-song-2')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('queue-item-1-song-2')));
    expect(playedIndex, 1);

    await tester.tap(find.byKey(const ValueKey('queue-remove-1-song-2')));
    expect(removedIndex, 1);

    await tester.tap(find.byKey(const ValueKey('queue-clear-upcoming')));
    expect(cleared, isTrue);
  });

  testWidgets('marks VIP songs and shows playback errors', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            height: 420,
            child: PlaybackQueuePanel(
              queue: const [_vipSong],
              currentIndex: -1,
              selectedIndex: 0,
              isPlaying: false,
              playbackError: '该歌曲需要 VIP 会员才能播放',
              onPlayIndex: (_) {},
              onRemoveIndex: (_) {},
              onClearUpcoming: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('VIP'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('queue-vip-badge-0-vip-song')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('queue-playback-error')), findsOneWidget);
    expect(find.text('该歌曲需要 VIP 会员才能播放'), findsOneWidget);
  });

  testWidgets('keeps the fifth queue row above the glass edge', (tester) async {
    final queue = List<QqMusicItem>.generate(5, (index) => _song(index + 1));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            height: 420,
            child: PlaybackQueuePanel(
              queue: queue,
              currentIndex: 0,
              selectedIndex: 4,
              isPlaying: true,
              onPlayIndex: (_) {},
              onRemoveIndex: (_) {},
              onClearUpcoming: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final list = tester.widget<ListView>(
      find.byKey(const ValueKey('playback-queue-list')),
    );
    final headerBounds = tester.getRect(
      find.byKey(const ValueKey('playback-queue-header')),
    );
    final panelBounds = tester.getRect(find.byType(PlaybackQueuePanel));
    final listBounds = tester.getRect(
      find.byKey(const ValueKey('playback-queue-list')),
    );
    final fifthRowBounds = tester.getRect(
      find.byKey(const ValueKey('queue-item-4-song-5')),
    );

    final fifthArtworkBounds = tester.getRect(
      find.byKey(const ValueKey('queue-artwork-4-song-5')),
    );

    expect(list.clipBehavior, Clip.hardEdge);
    expect(headerBounds.bottom, lessThan(listBounds.top));
    expect(fifthRowBounds.left - panelBounds.left, 12);
    expect(panelBounds.right - fifthRowBounds.right, 12);
    expect(list.itemExtent, 58);
    expect(fifthRowBounds.height, 52);
    expect(fifthArtworkBounds.size, const Size.square(38));
    expect(fifthRowBounds.bottom, lessThanOrEqualTo(listBounds.bottom - 4));
  });

  testWidgets('smoothly retargets rapid selection changes', (tester) async {
    final queue = List<QqMusicItem>.generate(10, (index) => _song(index + 1));

    late StateSetter updatePanel;
    var selectedIndex = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            height: 420,
            child: StatefulBuilder(
              builder: (context, setState) {
                updatePanel = setState;
                return PlaybackQueuePanel(
                  queue: queue,
                  currentIndex: 0,
                  selectedIndex: selectedIndex,
                  isPlaying: true,
                  onPlayIndex: (_) {},
                  onRemoveIndex: (_) {},
                  onClearUpcoming: () {},
                );
              },
            ),
          ),
        ),
      ),
    );

    void select(int index) {
      updatePanel(() => selectedIndex = index);
    }

    double scrollOffset() {
      return tester
          .state<ScrollableState>(
            find.descendant(
              of: find.byKey(const ValueKey('playback-queue-list')),
              matching: find.byType(Scrollable),
            ),
          )
          .position
          .pixels;
    }

    await tester.pumpAndSettle();
    select(4);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));
    final firstOffset = scrollOffset();
    select(5);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));
    final secondOffset = scrollOffset();
    select(6);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));
    final thirdOffset = scrollOffset();
    await tester.pumpAndSettle();

    final listBounds = tester.getRect(
      find.byKey(const ValueKey('playback-queue-list')),
    );
    final selectedRowBounds = tester.getRect(
      find.byKey(const ValueKey('queue-item-6-song-7')),
    );

    expect(firstOffset, greaterThan(0));
    expect(secondOffset, greaterThan(firstOffset));
    expect(thirdOffset, greaterThan(secondOffset));
    expect(selectedRowBounds.center.dy, closeTo(listBounds.center.dy, 0.5));
  });
}
