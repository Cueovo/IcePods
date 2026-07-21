import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';

import 'package:qqmusic_ipod/main.dart';
import 'package:qqmusic_ipod/business/entities/music.dart';
import 'package:qqmusic_ipod/features/player/state/controller.dart';
import 'package:qqmusic_ipod/features/shell/models/ipod_models.dart';
import 'package:qqmusic_ipod/features/shell/models/menu_catalog.dart';
import 'package:qqmusic_ipod/core/theme/widgets/click_wheel.dart';
import 'package:qqmusic_ipod/features/player/views/widgets/cover_flow_panel.dart';
import 'package:qqmusic_ipod/features/shell/views/pages/feature_panel.dart';
import 'package:qqmusic_ipod/features/shell/views/widgets/ipod_status_bar.dart';
import 'package:qqmusic_ipod/features/player/views/pages/now_playing_panel.dart';

import '../player/state/fake_api.dart';

void main() {
  test('every feature menu has API integration metadata', () {
    final entries = qqMusicMenuPages.values.expand((page) => page.entries);
    final features = entries.where(
      (entry) => entry.action == MenuAction.feature,
    );

    expect(features, isNotEmpty);
    for (final entry in features) {
      expect(entry.feature, isNotNull, reason: entry.id);
      expect(entry.apiOperation, isNotEmpty, reason: entry.id);
      expect(
        qqMusicApiOperations,
        contains(entry.apiOperation),
        reason: entry.id,
      );
      expect(entry.capabilities, isNotEmpty, reason: entry.id);
    }
  });

  Future<void> tapWheelSector(
    WidgetTester tester,
    Offset Function(Rect wheelRect) position,
  ) async {
    final wheelRect = tester.getRect(
      find.byKey(const ValueKey('center-button')),
    );
    await tester.tapAt(position(wheelRect));
    await tester.pumpAndSettle();
  }

  Future<void> tapNext(WidgetTester tester) {
    return tapWheelSector(
      tester,
      (rect) => rect.center + Offset(rect.width * .32, rect.height * .1),
    );
  }

  Future<void> tapMenu(WidgetTester tester) {
    return tapWheelSector(
      tester,
      (rect) => rect.center + Offset(rect.width * .1, -rect.height * .32),
    );
  }

  testWidgets('song list marks the current song playback state', (
    WidgetTester tester,
  ) async {
    final playerStates = StreamController<PlayerState>.broadcast(sync: true);
    final controller = QqMusicController(
      api: FakeQqMusicApi(),
      audioSessionConfigurator: () async {},
      audioSourceLoader: (song, uri) async {},
      audioPlaybackStarter: () async {},
      playerStateStream: playerStates.stream,
    );
    addTearDown(() async {
      controller.dispose();
      await playerStates.close();
    });
    const entry = MenuEntry(
      id: 'liked-songs-widget-test',
      label: '我喜欢',
      action: MenuAction.feature,
      imageUrl: '',
      title: '我喜欢',
      description: '',
      feature: QqMusicFeature.likedSongs,
    );
    await controller.openFeature(entry);
    expect(await controller.activateSelected(), isTrue);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FeaturePanel(entry: entry, controller: controller),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('current-song-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('current-song-paused-1')), findsOneWidget);

    playerStates.add(PlayerState(true, ProcessingState.ready));
    await tester.pump();

    expect(
      find.byKey(const ValueKey('current-song-playing-1')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('current-song-paused-1')), findsNothing);
  });

  testWidgets(
    'keeps the song list visible when a VIP song has no playable URL',
    (WidgetTester tester) async {
      final api = FakeQqMusicApi()..unavailableSongMids.add('song-mid-1');
      await tester.pumpWidget(MyApp(api: api));
      final wheel = find.byKey(const ValueKey('center-button'));

      // Root: 正在播放, 封面流, 推荐 — open 推荐 > 猜你喜欢.
      for (var index = 0; index < 2; index++) {
        await tapNext(tester);
      }
      await tester.tap(wheel);
      await tester.pumpAndSettle();
      await tester.tap(wheel);
      await tester.pumpAndSettle();
      await tester.tap(wheel);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));

      expect(find.byKey(const ValueKey('api-feature-list')), findsOneWidget);
      expect(find.text('测试歌曲一'), findsOneWidget);
      expect(find.text('当前未登录，该歌曲暂无游客播放地址'), findsOneWidget);
      // Guest play failures only toast; do not stamp the list as 无音源.
      expect(find.byKey(const ValueKey('unavailable-badge-1')), findsNothing);
      expect(find.text('无音源'), findsNothing);
      expect(find.byKey(const ValueKey('player-artwork')), findsNothing);
    },
  );

  testWidgets('non-adjacent feature navigation never flashes the player page', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(MyApp(api: FakeQqMusicApi()));
    final wheel = find.byKey(const ValueKey('center-button'));

    // Root index 4 = 资料库 (was 我的音乐 at index 2).
    for (var index = 0; index < 4; index++) {
      await tapNext(tester);
    }
    await tester.tap(wheel);
    await tester.pumpAndSettle();
    expect(find.text('我喜欢'), findsOneWidget);

    await tester.tap(wheel);
    for (final duration in const [
      Duration.zero,
      Duration(milliseconds: 100),
      Duration(milliseconds: 300),
      Duration(milliseconds: 600),
    ]) {
      await tester.pump(duration);
      expect(find.byKey(const ValueKey('player-artwork')), findsNothing);
    }
    expect(find.byKey(const ValueKey('api-feature-list')), findsOneWidget);

    final wheelRect = tester.getRect(
      find.byKey(const ValueKey('center-button')),
    );
    await tester.tapAt(
      wheelRect.center + Offset(wheelRect.width * .1, -wheelRect.height * .32),
    );
    for (final duration in const [
      Duration.zero,
      Duration(milliseconds: 100),
      Duration(milliseconds: 300),
      Duration(milliseconds: 600),
    ]) {
      await tester.pump(duration);
      expect(find.byKey(const ValueKey('player-artwork')), findsNothing);
    }
    // Back one level in feature: 资料库 submenu (我喜欢 etc.).
    expect(find.text('我喜欢'), findsOneWidget);
    expect(find.byKey(const ValueKey('player-artwork')), findsNothing);
  });

  testWidgets('uses one glowing wave track while buffering during seek', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 390,
            height: 600,
            child: NowPlayingPanel(
              album: Album(title: 'Song', artist: 'Artist', imageUrl: ''),
              progress: .5,
              position: Duration(minutes: 1),
              duration: Duration(minutes: 3),
              rotationDelta: 2,
              isBuffering: true,
              isSeeking: true,
              error: '',
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('player-progress')), findsOneWidget);
    expect(find.byKey(const ValueKey('player-progress-paint')), findsOneWidget);
    expect(find.byKey(const ValueKey('seek-preview-time')), findsOneWidget);
    expect(find.text('01:00 / 03:00'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.byType(CustomPaint), findsWidgets);
    expect(find.byType(Image), findsNothing);
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('now playing actions and swipe show real playback state', (
    WidgetTester tester,
  ) async {
    var modeChanges = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 390,
            height: 600,
            child: NowPlayingPanel(
              album: const Album(title: 'Song', artist: 'Artist', imageUrl: ''),
              progress: .25,
              position: const Duration(seconds: 12),
              duration: const Duration(minutes: 3),
              rotationDelta: 0,
              isBuffering: false,
              error: '',
              lyrics: const QqMusicLyrics(
                lines: [
                  QqMusicLyricLine(time: Duration.zero, text: '第一行歌词'),
                  QqMusicLyricLine(time: Duration(seconds: 10), text: '当前歌词'),
                ],
              ),
              audioOutputName: 'MEIZU Buds',
              isLiked: true,
              onPlaybackModePressed: () => modeChanges += 1,
            ),
          ),
        ),
      ),
    );

    expect(find.text('MEIZU Buds'), findsOneWidget);
    expect(find.byKey(const ValueKey('player-liked-button')), findsOneWidget);
    expect(find.byKey(const ValueKey('player-mode-button')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('player-mode-button')));
    expect(modeChanges, 1);

    await tester.drag(
      find.byKey(const ValueKey('now-playing-swipe-area')),
      const Offset(-120, 0),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('player-lyrics')), findsOneWidget);
    expect(find.text('当前歌词'), findsOneWidget);
    expect(find.byKey(const ValueKey('active-lyric-line')), findsOneWidget);
    expect(find.byKey(const ValueKey('player-artwork')), findsNothing);
  });

  testWidgets('plain lyrics settle while playback remains active', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 390,
            height: 600,
            child: NowPlayingPanel(
              album: Album(title: 'Song', artist: 'Artist', imageUrl: ''),
              progress: .25,
              position: Duration(seconds: 12),
              duration: Duration(minutes: 3),
              rotationDelta: 0,
              isBuffering: false,
              isPlaying: true,
              error: '',
              lyrics: QqMusicLyrics(
                lines: [
                  QqMusicLyricLine(time: Duration.zero, text: '第一行歌词'),
                  QqMusicLyricLine(time: Duration(seconds: 10), text: '当前歌词'),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('player-lyrics-button')));
    await tester.pumpAndSettle(const Duration(milliseconds: 16));

    expect(find.text('当前歌词'), findsOneWidget);
    expect(find.byKey(const ValueKey('active-lyric-line')), findsOneWidget);
  });

  testWidgets('word-timed lyrics render a progressive highlight layer', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 390,
            height: 600,
            child: NowPlayingPanel(
              album: const Album(title: 'Song', artist: 'Artist', imageUrl: ''),
              progress: .25,
              position: const Duration(milliseconds: 1750),
              duration: const Duration(minutes: 3),
              rotationDelta: 0,
              isBuffering: false,
              error: '',
              lyrics: const QqMusicLyrics(
                lines: [
                  QqMusicLyricLine(
                    time: Duration(milliseconds: 1000),
                    duration: Duration(milliseconds: 2000),
                    text: '你好世界',
                    words: [
                      QqMusicLyricWord(
                        text: '你',
                        time: Duration(milliseconds: 1000),
                        duration: Duration(milliseconds: 500),
                      ),
                      QqMusicLyricWord(
                        text: '好',
                        time: Duration(milliseconds: 1500),
                        duration: Duration(milliseconds: 500),
                      ),
                      QqMusicLyricWord(
                        text: '世界',
                        time: Duration(milliseconds: 2000),
                        duration: Duration(milliseconds: 1000),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('player-lyrics-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('active-lyric-line')), findsOneWidget);
    expect(find.byKey(const ValueKey('active-lyric-progress')), findsOneWidget);
    expect(find.text('你好世界'), findsNWidgets(2));
  });

  testWidgets('word highlight waits for the new line transition to begin', (
    WidgetTester tester,
  ) async {
    var position = const Duration(milliseconds: 900);
    late StateSetter updatePanel;
    const lyrics = QqMusicLyrics(
      lines: [
        QqMusicLyricLine(
          time: Duration.zero,
          duration: Duration(milliseconds: 1000),
          text: '上一句',
          words: [
            QqMusicLyricWord(
              text: '上一句',
              time: Duration.zero,
              duration: Duration(milliseconds: 1000),
            ),
          ],
        ),
        QqMusicLyricLine(
          time: Duration(milliseconds: 1000),
          duration: Duration(milliseconds: 1000),
          text: '下一句',
          words: [
            QqMusicLyricWord(
              text: '下一句',
              time: Duration(milliseconds: 1000),
              duration: Duration(milliseconds: 1000),
            ),
          ],
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              updatePanel = setState;
              return NowPlayingPanel(
                album: const Album(
                  title: 'Song',
                  artist: 'Artist',
                  imageUrl: '',
                ),
                progress: position.inMilliseconds / 2000,
                position: position,
                duration: const Duration(seconds: 2),
                rotationDelta: 0,
                isBuffering: false,
                error: '',
                lyrics: lyrics,
              );
            },
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('player-lyrics-button')));
    await tester.pumpAndSettle();

    updatePanel(() => position = const Duration(milliseconds: 1000));
    await tester.pump();
    final revealFinder = find.byKey(
      const ValueKey('active-lyric-highlight-reveal'),
    );
    expect(revealFinder, findsOneWidget);
    expect(tester.widget<Opacity>(revealFinder).opacity, 0);
    final previousHighlight = find.descendant(
      of: find.byKey(const ValueKey('lyric-line-0')),
      matching: find.byType(ShaderMask),
    );
    expect(previousHighlight, findsOneWidget);

    await tester.pump(const Duration(milliseconds: 120));
    final reveal = tester.widget<Opacity>(revealFinder).opacity;
    expect(reveal, greaterThan(0));
    expect(reveal, lessThan(1));
  });

  testWidgets('lyrics show more lines and scroll with playback progress', (
    WidgetTester tester,
  ) async {
    var position = Duration.zero;
    late StateSetter updatePanel;
    final lyrics = QqMusicLyrics(
      lines: List.generate(
        20,
        (index) => QqMusicLyricLine(
          time: Duration(seconds: index * 10),
          text: '歌词第${index + 1}行',
        ),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 390,
            height: 600,
            child: StatefulBuilder(
              builder: (context, setState) {
                updatePanel = setState;
                return NowPlayingPanel(
                  album: const Album(
                    title: 'Song',
                    artist: 'Artist',
                    imageUrl: '',
                  ),
                  progress: position.inSeconds / 200,
                  position: position,
                  duration: const Duration(seconds: 200),
                  rotationDelta: 0,
                  isBuffering: false,
                  error: '',
                  lyrics: lyrics,
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('player-lyrics-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('lyrics-scroll-list')), findsOneWidget);
    expect(find.textContaining('歌词第'), findsAtLeastNWidgets(6));
    final scrollable = tester.state<ScrollableState>(
      find.descendant(
        of: find.byKey(const ValueKey('lyrics-scroll-list')),
        matching: find.byType(Scrollable),
      ),
    );
    expect(scrollable.position.pixels, 0);

    updatePanel(() => position = const Duration(seconds: 10));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));

    final previousLine = find.byKey(const ValueKey('lyric-line-0'));
    final nextLine = find.byKey(const ValueKey('lyric-line-1'));
    expect(find.byKey(const ValueKey('active-lyric-line')), findsOneWidget);
    expect(
      find.descendant(
        of: previousLine,
        matching: find.byType(FractionalTranslation),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: previousLine, matching: find.byType(Transform)),
      findsWidgets,
    );
    expect(
      find.descendant(of: nextLine, matching: find.byType(Opacity)),
      findsAtLeastNWidgets(1),
    );

    await tester.pumpAndSettle();
    expect(find.text('歌词第2行'), findsOneWidget);

    updatePanel(() => position = const Duration(seconds: 160));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(scrollable.position.pixels, greaterThan(0));
    expect(find.text('歌词第17行'), findsOneWidget);
    expect(find.byKey(const ValueKey('active-lyric-line')), findsOneWidget);
  });

  testWidgets('lyrics follow seek preview without scroll animation', (
    WidgetTester tester,
  ) async {
    var position = Duration.zero;
    var isSeeking = false;
    late StateSetter updatePanel;
    final lyrics = QqMusicLyrics(
      lines: List.generate(
        20,
        (index) => QqMusicLyricLine(
          time: Duration(seconds: index * 10),
          text: '定位歌词第${index + 1}行',
        ),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 390,
            height: 600,
            child: StatefulBuilder(
              builder: (context, setState) {
                updatePanel = setState;
                return NowPlayingPanel(
                  album: const Album(
                    title: 'Song',
                    artist: 'Artist',
                    imageUrl: '',
                  ),
                  progress: position.inSeconds / 200,
                  position: position,
                  duration: const Duration(seconds: 200),
                  rotationDelta: 0,
                  isBuffering: false,
                  isSeeking: isSeeking,
                  error: '',
                  lyrics: lyrics,
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('player-lyrics-button')));
    await tester.pumpAndSettle();
    final scrollable = tester.state<ScrollableState>(
      find.descendant(
        of: find.byKey(const ValueKey('lyrics-scroll-list')),
        matching: find.byType(Scrollable),
      ),
    );

    updatePanel(() {
      position = const Duration(seconds: 160);
      isSeeking = true;
    });
    await tester.pump();
    await tester.pump();

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('lyric-line-16')),
        matching: find.byKey(const ValueKey('active-lyric-line')),
      ),
      findsOneWidget,
    );
    expect(scrollable.position.pixels, greaterThan(0));
  });

  testWidgets('empty player does not show a placeholder song', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(MyApp(api: FakeQqMusicApi()));
    // Root index 0 is already 正在播放.
    await tester.tap(find.byKey(const ValueKey('center-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('empty-now-playing')), findsOneWidget);
    expect(find.text('暂无正在播放'), findsOneWidget);
    expect(find.text('Lover Boy 88'), findsNothing);
    expect(find.byKey(const ValueKey('player-artwork')), findsNothing);
  });

  testWidgets('radar uses a station card instead of a song list', (
    WidgetTester tester,
  ) async {
    const entry = MenuEntry(
      id: 'radar-widget-test',
      label: '雷达',
      action: MenuAction.feature,
      imageUrl: '',
      title: '音乐雷达',
      description: '',
      feature: QqMusicFeature.radar,
    );
    final controller = QqMusicController(api: FakeQqMusicApi());
    addTearDown(controller.dispose);
    await controller.openFeature(entry);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FeaturePanel(entry: entry, controller: controller),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('radar-station-card')), findsOneWidget);
    expect(find.byKey(const ValueKey('api-feature-list')), findsNothing);
    expect(find.text('雷达歌曲1'), findsOneWidget);

    controller.stepSelection(1);
    await tester.pump();
    expect(find.text('雷达歌曲2'), findsOneWidget);
  });

  testWidgets('menu preview uses semantic artwork for every entry', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(MyApp(api: FakeQqMusicApi()));

    // Default selection is 正在播放; advance to 推荐 then 音乐馆.
    for (var index = 0; index < 2; index++) {
      await tapNext(tester);
    }
    expect(
      find.byKey(const ValueKey('menu-artwork-recommendations')),
      findsOneWidget,
    );
    await tapNext(tester);
    expect(
      find.byKey(const ValueKey('menu-artwork-music_hall')),
      findsOneWidget,
    );
  });

  testWidgets('renders the player shell', (WidgetTester tester) async {
    await tester.pumpWidget(MyApp(api: FakeQqMusicApi()));
    await tester.pump();

    expect(find.text('正在播放'), findsWidgets);
    expect(find.text('封面流'), findsOneWidget);
    expect(find.text('推荐'), findsOneWidget);
    expect(find.text('音乐馆'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('menu-selection-indicator')),
      findsOneWidget,
    );
  });

  testWidgets('lays out the custom iOS status bar by device family', (
    WidgetTester tester,
  ) async {
    Future<void> pumpStatusBar({
      required Size size,
      required double safeTop,
    }) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      tester.view.viewPadding = FakeViewPadding(top: safeTop);
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Align(alignment: Alignment.topCenter, child: IpodStatusBar()),
          ),
        ),
      );
      await tester.pump();
    }

    addTearDown(tester.view.reset);

    await pumpStatusBar(size: const Size(375, 667), safeTop: 20);
    final classicTime = tester.getRect(
      find.byKey(const ValueKey('ipod-status-time')),
    );
    final classicStatus = tester.getRect(
      find.byKey(const ValueKey('ipod-status-items')),
    );
    // Classic / Android fallback: time leading-left, status trailing-right.
    expect(classicTime.left, closeTo(18, 1));
    expect(classicTime.center.dy, closeTo(10, .01));
    expect(classicStatus.right, closeTo(359.25, 1));
    expect(classicStatus.center.dy, closeTo(10, .01));
    expect(classicTime.center.dx, lessThan(classicStatus.center.dx));

    // Typical Android status inset (24–32) must not center the clock.
    await pumpStatusBar(size: const Size(390, 844), safeTop: 28);
    final androidTime = tester.getRect(
      find.byKey(const ValueKey('ipod-status-time')),
    );
    final androidBar = tester.getRect(
      find.byKey(const ValueKey('ipod-status-bar')),
    );
    expect(androidTime.left, closeTo(18.72, 1.5));
    expect(androidTime.center.dx, lessThan(androidBar.center.dx - 40));

    await pumpStatusBar(size: const Size(390, 844), safeTop: 47);
    final notchTimeSlot = tester.getRect(
      find.byKey(const ValueKey('ipod-status-leading-slot')),
    );
    final notchStatusSlot = tester.getRect(
      find.byKey(const ValueKey('ipod-status-trailing-slot')),
    );
    final notchTime = tester.getRect(
      find.byKey(const ValueKey('ipod-status-time')),
    );
    final notchStatus = tester.getRect(
      find.byKey(const ValueKey('ipod-status-items')),
    );
    expect(notchTimeSlot.left, closeTo(23.985, .01));
    expect(notchTimeSlot.right, closeTo(119.535, .01));
    expect(notchStatusSlot.left, closeTo(270.465, .01));
    expect(notchStatusSlot.right, closeTo(366.015, .01));
    expect(notchTime.left, closeTo(26.52, 1));
    expect(notchStatus.right, closeTo(366.015, 1));
    expect(notchTime.center.dy, closeTo(23.5, .01));
    expect(notchStatus.center.dy, closeTo(23.5, .01));

    await pumpStatusBar(size: const Size(393, 852), safeTop: 59);
    final proTimeSlot = tester.getRect(
      find.byKey(const ValueKey('ipod-status-leading-slot')),
    );
    final proStatusSlot = tester.getRect(
      find.byKey(const ValueKey('ipod-status-trailing-slot')),
    );
    final proTime = tester.getRect(
      find.byKey(const ValueKey('ipod-status-time')),
    );
    final proStatus = tester.getRect(
      find.byKey(const ValueKey('ipod-status-items')),
    );
    expect(proTimeSlot.left, closeTo(30.261, .01));
    expect(proTimeSlot.right, closeTo(102.966, .01));
    expect(proStatusSlot.left, closeTo(290.034, .01));
    expect(proStatusSlot.right, closeTo(362.739, .01));
    expect(proTime.left, closeTo(51.5, 1));
    expect(proStatus.right, closeTo(362.739, 1));
    expect(proTime.center.dy, closeTo(29.5, .01));
    expect(proStatus.center.dy, closeTo(29.5, .01));

    await pumpStatusBar(size: const Size(430, 932), safeTop: 59);
    final proMaxTimeSlot = tester.getRect(
      find.byKey(const ValueKey('ipod-status-leading-slot')),
    );
    final proMaxStatusSlot = tester.getRect(
      find.byKey(const ValueKey('ipod-status-trailing-slot')),
    );
    final proMaxTime = tester.getRect(
      find.byKey(const ValueKey('ipod-status-time')),
    );
    final proMaxStatus = tester.getRect(
      find.byKey(const ValueKey('ipod-status-items')),
    );
    expect(proMaxTimeSlot.left, closeTo(33.11, .01));
    expect(proMaxTimeSlot.right, closeTo(112.66, .01));
    expect(proMaxStatusSlot.left, closeTo(317.34, .01));
    expect(proMaxStatusSlot.right, closeTo(396.89, .01));
    expect(proMaxTime.left, closeTo(56.33, 1));
    expect(proMaxStatus.right, closeTo(396.89, 1));
    expect(proMaxTime.right, lessThanOrEqualTo(152));
    expect(proMaxStatus.left, greaterThanOrEqualTo(278));
    expect(proMaxTime.center.dy, closeTo(29.5, .01));
    expect(proMaxStatus.center.dy, closeTo(29.5, .01));

    await pumpStatusBar(size: const Size(402, 874), safeTop: 59);
    final newProTime = tester.getRect(
      find.byKey(const ValueKey('ipod-status-time')),
    );
    expect(newProTime.left, closeTo(52.75, 1));
    expect(newProTime.center.dy, closeTo(32.5, .01));

    await pumpStatusBar(size: const Size(440, 956), safeTop: 62);
    final newProMaxTime = tester.getRect(
      find.byKey(const ValueKey('ipod-status-time')),
    );
    expect(newProMaxTime.left, closeTo(56.5, 1));
    expect(newProMaxTime.center.dy, closeTo(32.5, .01));
  });

  testWidgets('fills the phone viewport', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MyApp(api: FakeQqMusicApi()));
    await tester.pump();

    expect(
      tester.getSize(find.byKey(const ValueKey('fullscreen-player'))),
      const Size(390, 844),
    );
  });

  testWidgets('adapts chassis top margin for cutout families', (
    WidgetTester tester,
  ) async {
    Future<double> frameTop(double safeTop) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      tester.view.viewPadding = FakeViewPadding(top: safeTop);
      tester.view.padding = FakeViewPadding(top: safeTop);
      await tester.pumpWidget(MyApp(api: FakeQqMusicApi()));
      await tester.pump();
      final shell = tester.getRect(
        find.byKey(const ValueKey('fullscreen-player')),
      );
      final frame = tester.getRect(
        find.byKey(const ValueKey('ipod-screen-frame')),
      );
      return frame.top - shell.top;
    }

    addTearDown(tester.view.reset);

    // classic SE-like (rawTop 20) → outer 8 + frame 10
    expect(await frameTop(20), closeTo(18, 1));
    // Android punch-hole: whole module shifts (white rim just above hole)
    expect(await frameTop(28), closeTo(3.66, 1));
    // notch / island: small chassis lip
    expect(await frameTop(47), closeTo(4, 1));
    tester.view.physicalSize = const Size(393, 852);
    expect(await frameTop(59), closeTo(4, 1));
  });

  testWidgets('uses the full-size wheel on a tall phone', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MyApp(api: FakeQqMusicApi()));
    await tester.pump();

    final wheelRect = tester.getRect(find.byKey(const ValueKey('click-wheel')));
    expect(wheelRect.width, closeTo(280, .01));
    expect(wheelRect.height, closeTo(280, .01));
  });

  testWidgets('keeps media panels overflow-free on a short phone', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 2100);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MyApp(api: FakeQqMusicApi()));
    final wheel = find.byKey(const ValueKey('center-button'));
    // Open 推荐 (index 2).
    for (var index = 0; index < 2; index++) {
      await tapNext(tester);
    }
    await tester.tap(wheel);
    await tester.pumpAndSettle();
    expect(find.text('猜你喜欢'), findsWidgets);

    await tester.tap(wheel);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('api-feature-list')), findsOneWidget);
    expect(find.text('测试歌曲一'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tapMenu(tester);
    await tapMenu(tester);
    // Back on root at 推荐 (index 2). Step previous to 封面流 (index 1).
    final wheelRect = tester.getRect(wheel);
    await tester.tapAt(wheelRect.center + Offset(-wheelRect.width * .32, 0));
    await tester.pumpAndSettle();
    await tester.tap(wheel);
    await tester.pumpAndSettle();
    expect(find.text('测试歌曲一'), findsOneWidget);

    await tester.tap(wheel);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('player-artwork')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('navigates QQ Music menus and feature placeholders', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(MyApp(api: FakeQqMusicApi()));
    final wheel = find.byKey(const ValueKey('center-button'));

    // Open 推荐.
    for (var index = 0; index < 2; index++) {
      await tapNext(tester);
    }
    await tester.tap(wheel);
    await tester.pumpAndSettle();
    expect(find.text('猜你喜欢'), findsWidgets);
    expect(find.text('首页推荐'), findsOneWidget);
    expect(find.text('私人电台'), findsNothing);

    await tester.tap(wheel);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('api-feature-list')), findsOneWidget);
    expect(
      find.text('music.radioProxy.MbTrackRadioSvr.get_radio_track'),
      findsNothing,
    );
    expect(find.text('测试歌曲一'), findsOneWidget);
    expect(find.byKey(const ValueKey('vip-badge-1')), findsNothing);
    expect(find.byKey(const ValueKey('vip-badge-2')), findsOneWidget);
    expect(find.text('VIP'), findsOneWidget);
    expect(find.text('新碟推荐'), findsNothing);
    expect(find.text('本地歌曲'), findsNothing);
    expect(find.text('均衡器'), findsNothing);

    await tapMenu(tester);
    expect(find.text('猜你喜欢'), findsWidgets);
    await tapMenu(tester);
    expect(find.text('推荐'), findsOneWidget);
    expect(find.text('音乐馆'), findsOneWidget);
  });

  testWidgets('settings menu scrolls when selection moves past the viewport', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 2100);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MyApp(api: FakeQqMusicApi()));
    final wheel = find.byKey(const ValueKey('center-button'));

    // Root index 7 = 设置 (still last).
    for (var index = 0; index < 7; index++) {
      await tapNext(tester);
    }
    expect(find.text('设置'), findsWidgets);
    await tester.tap(wheel);
    await tester.pumpAndSettle();

    expect(find.text('机身颜色'), findsWidgets);
    expect(find.text('点击音效'), findsOneWidget);
    expect(find.byKey(const ValueKey('menu-list-settings')), findsOneWidget);

    final list = find.byKey(const ValueKey('menu-list-settings'));
    final scrollable = tester.state<ScrollableState>(
      find.descendant(of: list, matching: find.byType(Scrollable)),
    );
    expect(scrollable.position.maxScrollExtent, greaterThan(0));

    for (var index = 0; index < 8; index++) {
      await tapNext(tester);
    }
    await tester.pumpAndSettle();

    expect(find.text('关于'), findsOneWidget);
    expect(find.text('关于本机'), findsOneWidget);
    expect(scrollable.position.pixels, greaterThan(0));
  });

  testWidgets(
    'switches between QQ and WeChat QR login and stops polling on exit',
    (WidgetTester tester) async {
      final api = FakeQqMusicApi();
      await tester.pumpWidget(MyApp(api: api));
      final wheel = find.byKey(const ValueKey('center-button'));

      // Root index 6 = 账号 (was index 4).
      for (var index = 0; index < 6; index++) {
        await tapNext(tester);
      }
      await tester.tap(wheel);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));

      expect(find.byKey(const ValueKey('qqmusic-qr-code')), findsOneWidget);
      expect(find.byKey(const ValueKey('qq-qr-login')), findsOneWidget);
      expect(find.byKey(const ValueKey('wx-qr-login')), findsOneWidget);
      expect(api.createdQrLoginTypes, ['qq']);

      await tester.tap(find.byKey(const ValueKey('wx-qr-login')));
      await tester.pump(const Duration(milliseconds: 200));
      expect(api.createdQrLoginTypes, ['qq', 'wx']);
      expect(find.text('使用微信扫码并确认登录'), findsOneWidget);

      await tester.pump(const Duration(seconds: 2));
      expect(api.qrStatusChecks, greaterThan(0));
      await tapMenu(tester);
      final checksAfterExit = api.qrStatusChecks;
      await tester.pump(const Duration(seconds: 3));
      expect(api.qrStatusChecks, checksAfterExit);
    },
  );

  testWidgets('manages created playlists through documented API controls', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(MyApp(api: FakeQqMusicApi()));
    final wheel = find.byKey(const ValueKey('center-button'));

    // Root index 4 = 资料库.
    for (var index = 0; index < 4; index++) {
      await tapNext(tester);
    }
    await tester.tap(wheel);
    await tester.pumpAndSettle();
    for (var index = 0; index < 4; index++) {
      await tapNext(tester);
    }
    await tester.tap(wheel);
    await tester.pumpAndSettle();

    expect(find.text('测试歌单'), findsOneWidget);
    expect(find.byKey(const ValueKey('create-playlist')), findsOneWidget);
    expect(find.byKey(const ValueKey('delete-playlist')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('add-current-song-to-playlist')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('create-playlist')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('playlist-name-field')),
      '新测试歌单',
    );
    await tester.tap(find.widgetWithText(FilledButton, '创建'));
    await tester.pumpAndSettle();

    expect(find.text('新测试歌单'), findsOneWidget);
    expect(find.textContaining('已创建歌单'), findsOneWidget);
  });

  testWidgets('opens Cover Flow with real recommendation covers', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(MyApp(api: FakeQqMusicApi()));
    await tester.pumpAndSettle();
    // Root index 1 = 封面流.
    await tapNext(tester);
    await tester.tap(find.byKey(const ValueKey('center-button')));
    await tester.pumpAndSettle();

    expect(find.text('测试歌曲一'), findsOneWidget);
    expect(find.text('测试歌手'), findsOneWidget);
    expect(find.text('Lover Boy 88'), findsNothing);
  });

  testWidgets('Cover Flow only builds covers near the selected album', (
    WidgetTester tester,
  ) async {
    final albums = List.generate(
      30,
      (index) =>
          Album(title: 'Album $index', artist: 'Artist $index', imageUrl: ''),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: CoverFlowPanel(selectedIndex: 15, albums: albums)),
      ),
    );

    expect(find.byKey(const ValueKey('cover-15')), findsOneWidget);
    expect(find.byKey(const ValueKey('cover-11')), findsOneWidget);
    expect(find.byKey(const ValueKey('cover-19')), findsOneWidget);
    expect(find.byKey(const ValueKey('cover-10')), findsNothing);
    expect(find.byKey(const ValueKey('cover-20')), findsNothing);
  });

  testWidgets('song list keeps the wheel selection centered while moving', (
    WidgetTester tester,
  ) async {
    const entry = MenuEntry(
      id: 'long-song-list-test',
      label: '歌曲列表',
      action: MenuAction.feature,
      imageUrl: '',
      title: '歌曲列表',
      description: '',
      feature: QqMusicFeature.likedSongs,
    );
    final controller = QqMusicController(api: _LongSongListApi());
    addTearDown(controller.dispose);
    await controller.openFeature(entry);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 390,
            height: 600,
            child: FeaturePanel(entry: entry, controller: controller),
          ),
        ),
      ),
    );
    await tester.pump();

    controller.selectIndex(10);
    await tester.pumpAndSettle();

    final listRect = tester.getRect(
      find.byKey(const ValueKey('api-feature-list')),
    );
    final selectionRect = tester.getRect(
      find.byKey(const ValueKey('api-feature-selection')),
    );
    expect(selectionRect.center.dy, closeTo(listRect.center.dy, 1));
  });

  testWidgets('feature header uses semantic menu artwork', (
    WidgetTester tester,
  ) async {
    const entry = MenuEntry(
      id: 'guess',
      label: '猜你喜欢',
      action: MenuAction.feature,
      imageUrl: 'https://example.com/stale.jpg',
      title: '猜你喜欢',
      description: '',
      feature: QqMusicFeature.guessRecommendations,
    );
    final controller = QqMusicController(api: FakeQqMusicApi());
    addTearDown(controller.dispose);
    await controller.openFeature(entry);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FeaturePanel(entry: entry, controller: controller),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('menu-artwork-guess-compact')),
      findsOneWidget,
    );
  });

  testWidgets('maps an empty top annular point to MENU', (
    WidgetTester tester,
  ) async {
    var action = '';
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: ClickWheel(
            onRotate: (_) => action = 'rotate',
            onRotationEnd: () {},
            onCenter: () => action = 'center',
            onMenu: () => action = 'menu',
            onPrevious: () => action = 'previous',
            onNext: () => action = 'next',
            onPlayPause: () => action = 'playPause',
            isPlaying: false,
          ),
        ),
      ),
    );

    final wheel = find.byKey(const ValueKey('center-button'));
    final wheelRect = tester.getRect(wheel);
    await tester.tapAt(wheelRect.center + const Offset(45, -90));

    expect(action, 'menu');
  });

  testWidgets('handles taps across the entire MENU sector', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(MyApp(api: FakeQqMusicApi()));
    final wheel = find.byKey(const ValueKey('center-button'));
    await tester.tap(wheel);
    await tester.pumpAndSettle();

    final wheelRect = tester.getRect(wheel);
    await tester.tapAt(
      wheelRect.center + Offset(wheelRect.width * .16, -wheelRect.height * .32),
    );
    await tester.pumpAndSettle();

    // MENU from a submenu returns to root; root labels changed.
    expect(find.text('推荐'), findsOneWidget);
    expect(find.text('音乐馆'), findsOneWidget);
    expect(find.byKey(const ValueKey('menu-list-root')), findsOneWidget);
  });
}

class _LongSongListApi extends FakeQqMusicApi {
  @override
  Future<QqMusicFeatureResult> loadFeature(
    QqMusicFeature feature, {
    int page = 1,
    int pageSize = 25,
    bool forceRefresh = false,
  }) async {
    return QqMusicFeatureResult(
      title: '歌曲列表',
      items: List.generate(
        30,
        (index) => QqMusicItem(
          id: 'long-song-$index',
          mid: 'long-song-mid-$index',
          mediaMid: 'long-song-media-$index',
          title: '歌曲 ${index + 1}',
          subtitle: '测试歌手',
          imageUrl: '',
          type: QqMusicItemType.song,
          duration: const Duration(minutes: 3),
        ),
      ),
    );
  }
}
