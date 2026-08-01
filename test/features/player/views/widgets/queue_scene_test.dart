import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qqmusic_ipod/business/entities/music.dart';
import 'package:qqmusic_ipod/core/theme/artwork/artwork_identity.dart';
import 'package:qqmusic_ipod/features/player/views/widgets/playback_queue_panel.dart';
import 'package:qqmusic_ipod/features/shell/models/ipod_models.dart';

QqMusicItem _song(int index) {
  return QqMusicItem(
    id: 'song-$index',
    title: '歌曲 $index',
    subtitle: '歌手 $index',
    imageUrl: 'https://example.com/cover-$index.jpg',
    type: QqMusicItemType.song,
  );
}

Widget _host({
  required int currentIndex,
  ArtworkIdentity identity = ArtworkIdentity.empty,
}) {
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: 360,
        height: 460,
        child: PlaybackQueuePanel(
          queue: List<QqMusicItem>.generate(4, (index) => _song(index + 1)),
          currentIndex: currentIndex,
          selectedIndex: currentIndex,
          isPlaying: true,
          identity: identity,
          onPlayIndex: (_) {},
          onRemoveIndex: (_) {},
          onClearUpcoming: () {},
        ),
      ),
    ),
  );
}

void main() {
  test('artwork identity is stable across surfaces', () {
    const album = Album(
      title: '专辑',
      artist: '歌手',
      imageUrl: 'http://y.gtimg.cn/cover.jpg',
    );
    final fromAlbum = ArtworkIdentity.album(album);
    final again = ArtworkIdentity.album(album);

    expect(fromAlbum, again);
    expect(fromAlbum.paletteKey, 'https://y.gtimg.cn/cover.jpg');
    expect(fromAlbum.isEmpty, isFalse);
    expect(ArtworkIdentity.empty.isEmpty, isTrue);
  });

  testWidgets('queue marks the playing track and the one after it', (
    tester,
  ) async {
    await tester.pumpWidget(_host(currentIndex: 1));
    await tester.pump();

    expect(find.text('NOW'), findsOneWidget);
    expect(find.text('NEXT'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('queue-now-badge-song-2')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('queue-next-badge-song-3')),
      findsOneWidget,
    );
  });

  testWidgets('played tracks recede behind the current one', (tester) async {
    await tester.pumpWidget(_host(currentIndex: 2));
    await tester.pumpAndSettle();

    final played = tester
        .widget<AnimatedOpacity>(
          find.descendant(
            of: find.byKey(const ValueKey('queue-item-0-song-1')),
            matching: find.byType(AnimatedOpacity),
          ),
        )
        .opacity;
    final upcoming = tester
        .widget<AnimatedOpacity>(
          find.descendant(
            of: find.byKey(const ValueKey('queue-item-3-song-4')),
            matching: find.byType(AnimatedOpacity),
          ),
        )
        .opacity;

    expect(played, lessThan(upcoming));
    expect(upcoming, 1);
  });

  testWidgets('queue header shows the playing artwork', (tester) async {
    await tester.pumpWidget(
      _host(
        currentIndex: 0,
        identity: const ArtworkIdentity(
          key: 'song:song-1',
          imageUrl: 'https://example.com/cover-1.jpg',
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('queue-header-artwork')), findsOneWidget);
    expect(find.byIcon(Icons.queue_music_rounded), findsNothing);
  });

  testWidgets('queue header falls back to its icon without artwork', (
    tester,
  ) async {
    await tester.pumpWidget(_host(currentIndex: 0));
    await tester.pump();

    expect(find.byIcon(Icons.queue_music_rounded), findsOneWidget);
  });
}
