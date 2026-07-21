import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:qqmusic_ipod/data/models/api_exception.dart';
import 'package:qqmusic_ipod/business/entities/auth.dart';
import 'package:qqmusic_ipod/business/entities/music.dart';
import 'package:qqmusic_ipod/features/player/state/controller.dart';
import 'package:qqmusic_ipod/features/shell/models/ipod_models.dart';

import 'fake_api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const likedSongsEntry = MenuEntry(
    id: 'liked-songs-test',
    label: '我喜欢',
    action: MenuAction.feature,
    imageUrl: '',
    title: '我喜欢',
    description: '',
    feature: QqMusicFeature.likedSongs,
  );

  late _PlaybackFakeApi api;
  late QqMusicController controller;
  late List<QqMusicItem> loadedSongs;
  late List<Uri> loadedUris;
  late List<Duration> seekPositions;
  late StreamController<PlayerState> playerStates;
  late StreamController<Duration> positions;
  late StreamController<PlayerException> playerErrors;
  late DateTime now;
  late int playbackStarts;

  setUp(() {
    api = _PlaybackFakeApi();
    loadedSongs = [];
    loadedUris = [];
    seekPositions = [];
    playbackStarts = 0;
    now = DateTime.utc(2026, 7, 18, 12);
    playerStates = StreamController<PlayerState>.broadcast(sync: true);
    positions = StreamController<Duration>.broadcast(sync: true);
    playerErrors = StreamController<PlayerException>.broadcast(sync: true);
    controller = QqMusicController(
      api: api,
      audioSessionConfigurator: () async {},
      audioSourceLoader: (song, uri) async {
        loadedSongs.add(song);
        loadedUris.add(uri);
      },
      audioPlaybackStarter: () async {
        playbackStarts += 1;
      },
      audioSeeker: (position) async => seekPositions.add(position),
      audioOutputNameLoader: () async => 'MEIZU Buds',
      playerStateStream: playerStates.stream,
      positionStream: positions.stream,
      playerErrorStream: playerErrors.stream,
      clock: () => now,
    );
  });

  tearDown(() async {
    controller.dispose();
    await playerStates.close();
    await positions.close();
    await playerErrors.close();
  });

  test(
    'current song heart toggles liked state without reloading the list',
    () async {
      api.storedCredential = const QqMusicCredential(
        musicId: '10001',
        musicKey: 'music-key',
      );
      await controller.openFeature(likedSongsEntry);
      expect(await controller.activateSelected(), isTrue);
      expect(controller.isCurrentSongLiked, isTrue);

      await controller.toggleCurrentSongLiked();

      expect(controller.isCurrentSongLiked, isFalse);
      expect(api.songLikedChanges.single, (
        song: FakeQqMusicApi.songs.first,
        liked: false,
      ));
      expect(controller.statusMessage, '已取消喜欢');

      await controller.toggleCurrentSongLiked();

      expect(controller.isCurrentSongLiked, isTrue);
      expect(api.songLikedChanges.last.liked, isTrue);
      expect(controller.statusMessage, '已添加到我喜欢');
    },
  );

  test('playback progress notifies only its dedicated listenable', () async {
    final positions = StreamController<Duration>.broadcast(sync: true);
    final durations = StreamController<Duration?>.broadcast(sync: true);
    final progressController = QqMusicController(
      api: _PlaybackFakeApi(),
      audioSessionConfigurator: () async {},
      audioSourceLoader: (song, uri) async {},
      audioPlaybackStarter: () async {},
      playerStateStream: const Stream.empty(),
      positionStream: positions.stream,
      durationStream: durations.stream,
    );
    addTearDown(() async {
      progressController.dispose();
      await positions.close();
      await durations.close();
    });
    var controllerNotifications = 0;
    var progressNotifications = 0;
    progressController.addListener(() => controllerNotifications += 1);
    progressController.playbackProgress.addListener(
      () => progressNotifications += 1,
    );

    durations.add(const Duration(minutes: 4));
    durations.add(const Duration(minutes: 4));
    positions.add(const Duration(minutes: 1));
    positions.add(const Duration(minutes: 1));

    expect(controllerNotifications, 0);
    expect(progressNotifications, 2);
    expect(progressController.playbackProgress.value.value, .25);
  });

  test('duplicate player states do not notify controller listeners', () {
    var notifications = 0;
    controller.addListener(() => notifications += 1);

    playerStates.add(PlayerState(true, ProcessingState.ready));
    playerStates.add(PlayerState(true, ProcessingState.ready));
    playerStates.add(PlayerState(true, ProcessingState.buffering));
    playerStates.add(PlayerState(true, ProcessingState.buffering));

    expect(notifications, 2);
  });

  test(
    'cover flow albums reuse their derived result until sources change',
    () async {
      final initial = controller.coverFlowAlbums;
      expect(identical(controller.coverFlowAlbums, initial), isTrue);

      await controller.openFeature(likedSongsEntry);

      final loaded = controller.coverFlowAlbums;
      expect(identical(loaded, initial), isFalse);
      expect(identical(controller.coverFlowAlbums, loaded), isTrue);
    },
  );

  test('activating the current song reuses its loaded source', () async {
    await controller.openFeature(likedSongsEntry);
    expect(await controller.activateSelected(), isTrue);
    expect(
      api.playableUrlRequestMids.where((mid) => mid == 'song-mid-1'),
      hasLength(1),
    );
    expect(loadedSongs, [FakeQqMusicApi.songs.first]);

    expect(await controller.activateSelected(), isTrue);

    expect(controller.currentSong, FakeQqMusicApi.songs.first);
    expect(
      api.playableUrlRequestMids.where((mid) => mid == 'song-mid-1'),
      hasLength(1),
    );
    expect(loadedSongs, [FakeQqMusicApi.songs.first]);
  });

  test(
    'unplayable song keeps its source list and does not become current',
    () async {
      await controller.openFeature(likedSongsEntry);
      api.unavailableMids.add(FakeQqMusicApi.songs.first.mid);

      final activated = await controller.activateSelected();

      expect(activated, isFalse);
      expect(controller.currentSong, isNull);
      expect(controller.items, FakeQqMusicApi.songs);
      expect(controller.error, isEmpty);
      expect(controller.playbackError, '当前未登录，该歌曲暂无游客播放地址');
      expect(loadedSongs, isEmpty);
    },
  );

  test('bulk probe marks no-source songs and next skips them', () async {
    api.storedCredential = const QqMusicCredential(
      musicId: '10001',
      musicKey: 'music-key',
    );
    api.unavailableSongMids.add(FakeQqMusicApi.songs[2].mid);
    await controller.initialize();
    await controller.openFeature(likedSongsEntry);

    expect(controller.result?.title, '我喜欢的音乐');
    expect(controller.isUnavailable(FakeQqMusicApi.songs[2]), isTrue);
    expect(await controller.activateSelected(), isTrue);

    await controller.playAdjacent(1);

    expect(controller.currentSong, FakeQqMusicApi.songs[1]);
    expect(loadedSongs, [FakeQqMusicApi.songs.first, FakeQqMusicApi.songs[1]]);
  });

  test(
    'bulk probe skips VIP songs and keeps authorization on demand',
    () async {
      api.storedCredential = const QqMusicCredential(
        musicId: '10001',
        musicKey: 'music-key',
      );
      api.unavailableSongMids.add(FakeQqMusicApi.songs[1].mid);
      await controller.initialize();
      await controller.openFeature(likedSongsEntry);

      expect(
        api.playableUrlProbeBatches.expand((batch) => batch),
        isNot(contains(FakeQqMusicApi.songs[1].mid)),
      );
      expect(controller.isUnavailable(FakeQqMusicApi.songs[1]), isFalse);

      controller.selectIndex(1);
      api.unavailableMids.add(FakeQqMusicApi.songs[1].mid);
      expect(await controller.activateSelected(), isFalse);

      expect(api.playableUrlRequestMids, contains(FakeQqMusicApi.songs[1].mid));
      expect(controller.isUnavailable(FakeQqMusicApi.songs[1]), isTrue);
    },
  );

  test('completed playback advances to a server-authorized VIP song', () async {
    await controller.openFeature(likedSongsEntry);
    expect(await controller.activateSelected(), isTrue);

    playerStates.add(PlayerState(true, ProcessingState.ready));
    expect(controller.isPlaying, isTrue);

    playerStates.add(PlayerState(true, ProcessingState.completed));
    playerStates.add(PlayerState(true, ProcessingState.completed));
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(controller.isPlaying, isFalse);
    expect(controller.currentSong, FakeQqMusicApi.songs[1]);
    expect(loadedSongs, [FakeQqMusicApi.songs.first, FakeQqMusicApi.songs[1]]);
  });

  test('reopening a feature uses cache while refresh reloads it', () async {
    await controller.openFeature(likedSongsEntry);
    expect(api.featureLoadCounts[QqMusicFeature.likedSongs], 1);

    controller.selectIndex(2);
    expect(await controller.activateSelected(), isTrue);
    expect(controller.currentSong, FakeQqMusicApi.songs.last);

    await controller.openFeature(likedSongsEntry);

    expect(api.featureLoadCounts[QqMusicFeature.likedSongs], 1);
    expect(controller.selectedIndex, 2);
    expect(controller.isCurrentSong(FakeQqMusicApi.songs.last), isTrue);
    expect(controller.playbackQueue, FakeQqMusicApi.songs);

    await controller.refresh();

    expect(api.featureLoadCounts[QqMusicFeature.likedSongs], 2);
    expect(api.forcedFeatureRefreshes, contains(QqMusicFeature.likedSongs));
    expect(controller.selectedIndex, 2);
    expect(controller.playbackQueue, FakeQqMusicApi.songs);
  });

  test('playlist children are cached and restore the current song', () async {
    const playlistsEntry = MenuEntry(
      id: 'created-playlists-test',
      label: '自建歌单',
      action: MenuAction.feature,
      imageUrl: '',
      title: '自建歌单',
      description: '',
      feature: QqMusicFeature.createdPlaylists,
    );
    await controller.openFeature(playlistsEntry);
    expect(await controller.activateSelected(), isTrue);
    expect(api.childrenLoadCounts[FakeQqMusicApi.playlists.first.id], 1);

    controller.selectIndex(2);
    expect(await controller.activateSelected(), isTrue);
    expect(controller.back(), isTrue);
    expect(await controller.activateSelected(), isTrue);

    expect(api.childrenLoadCounts[FakeQqMusicApi.playlists.first.id], 1);
    expect(controller.selectedIndex, 2);
    expect(controller.isCurrentSong(FakeQqMusicApi.songs.last), isTrue);
  });

  test('play loads lyrics, output device and liked source state', () async {
    await controller.openFeature(likedSongsEntry);

    expect(await controller.activateSelected(), isTrue);
    await Future<void>.delayed(Duration.zero);

    expect(controller.isCurrentSongLiked, isTrue);
    expect(controller.audioOutputName, 'MEIZU Buds');
    expect(controller.lyrics?.lines.first.text, '测试歌词第一行');
  });

  test('cycles sequential, repeat-one and shuffle playback modes', () {
    expect(controller.playbackMode, QqMusicPlaybackMode.sequential);

    controller.cyclePlaybackMode();
    expect(controller.playbackMode, QqMusicPlaybackMode.repeatOne);

    controller.cyclePlaybackMode();
    expect(controller.playbackMode, QqMusicPlaybackMode.shuffle);

    controller.cyclePlaybackMode();
    expect(controller.playbackMode, QqMusicPlaybackMode.sequential);
  });

  test('confirmed non-VIP membership blocks VIP playback locally', () async {
    api.storedCredential = const QqMusicCredential(
      musicId: '10001',
      musicKey: 'music-key',
    );
    api.profileIsVip = false;
    await controller.initialize();
    await controller.openFeature(likedSongsEntry);
    controller.selectIndex(1);
    final requestsBeforePlayback = api.playableUrlRequestMids.length;

    expect(await controller.activateSelected(), isFalse);

    expect(controller.playbackError, '该歌曲需要 VIP 会员才能播放');
    expect(api.playableUrlRequestMids, hasLength(requestsBeforePlayback));
    expect(loadedSongs, isEmpty);
  });

  test('unknown membership does not falsely block VIP playback', () async {
    api.storedCredential = const QqMusicCredential(
      musicId: '10001',
      musicKey: 'music-key',
    );
    api.profileIsVip = null;
    await controller.initialize();
    await controller.openFeature(likedSongsEntry);
    controller.selectIndex(1);

    expect(await controller.activateSelected(), isTrue);

    expect(controller.profile?.isVip, isNull);
    expect(controller.playbackError, isEmpty);
    expect(api.playableUrlRequestMids, contains(FakeQqMusicApi.songs[1].mid));
  });

  test('source error while loading refreshes the playback URL once', () async {
    final sourceAttempts = <Uri>[];
    var failFirstLoad = true;
    final retryController = QqMusicController(
      api: api,
      audioSessionConfigurator: () async {},
      audioSourceLoader: (song, uri) async {
        sourceAttempts.add(uri);
        if (failFirstLoad) {
          failFirstLoad = false;
          throw PlayerException(0, 'Source error', 0);
        }
      },
      audioPlaybackStarter: () async {},
      playerStateStream: const Stream.empty(),
      playerErrorStream: const Stream.empty(),
    );
    addTearDown(retryController.dispose);
    await retryController.openFeature(likedSongsEntry);

    expect(await retryController.activateSelected(), isTrue);

    expect(sourceAttempts, hasLength(2));
    expect(
      api.playableUrlRequestMids.where((mid) => mid == 'song-mid-1'),
      hasLength(2),
    );
    expect(retryController.playbackError, isEmpty);
  });

  test('expired prefetched URL is replaced before loading', () async {
    await controller.openFeature(likedSongsEntry);
    expect(await controller.activateSelected(), isTrue);
    await Future<void>.delayed(Duration.zero);
    final requestsAfterPrefetch = api.playableUrlRequestMids
        .where((mid) => mid == 'song-mid-2')
        .length;
    expect(requestsAfterPrefetch, 1);
    now = now.add(const Duration(minutes: 6));
    controller.selectIndex(1);

    expect(await controller.activateSelected(), isTrue);

    expect(
      api.playableUrlRequestMids.where((mid) => mid == 'song-mid-2'),
      hasLength(2),
    );
    expect(loadedUris.last.toString(), contains('song-mid-2'));
  });

  test('failed prefetch is retried when the song is selected', () async {
    await controller.openFeature(likedSongsEntry);
    api.unavailableMids.add(FakeQqMusicApi.songs[1].mid);
    expect(await controller.activateSelected(), isTrue);
    await Future<void>.delayed(Duration.zero);
    expect(
      api.playableUrlRequestMids.where((mid) => mid == 'song-mid-2'),
      hasLength(1),
    );
    expect(controller.isUnavailable(FakeQqMusicApi.songs[1]), isFalse);
    api.unavailableMids.remove(FakeQqMusicApi.songs[1].mid);
    controller.selectIndex(1);

    expect(await controller.activateSelected(), isTrue);

    expect(
      api.playableUrlRequestMids.where((mid) => mid == 'song-mid-2'),
      hasLength(2),
    );
    expect(controller.currentSong, FakeQqMusicApi.songs[1]);
  });

  test('seek preview avoids the playback completion boundary', () async {
    await controller.openFeature(likedSongsEntry);
    expect(await controller.activateSelected(), isTrue);

    await controller.seekToProgress(1);
    await controller.seekToProgress(1, avoidPlaybackCompletion: true);

    expect(seekPositions, [
      const Duration(minutes: 3),
      const Duration(minutes: 3) - const Duration(milliseconds: 500),
    ]);
  });

  test(
    'runtime source error refreshes URL, restores position and resumes',
    () async {
      await controller.openFeature(likedSongsEntry);
      expect(await controller.activateSelected(), isTrue);
      await Future<void>.delayed(Duration.zero);
      positions.add(const Duration(seconds: 42));
      playerStates.add(PlayerState(true, ProcessingState.ready));
      final initialLoads = loadedUris.length;
      final initialStarts = playbackStarts;
      final initialRequests = api.playableUrlRequestMids
          .where((mid) => mid == 'song-mid-1')
          .length;

      playerErrors.add(PlayerException(0, 'Source error', 0));
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(loadedUris, hasLength(initialLoads + 1));
      expect(seekPositions, [const Duration(seconds: 42)]);
      expect(playbackStarts, initialStarts + 1);
      expect(
        api.playableUrlRequestMids.where((mid) => mid == 'song-mid-1'),
        hasLength(initialRequests + 1),
      );
      expect(controller.playbackError, isEmpty);
    },
  );

  test(
    'guess recommendations defer playback authorization until selection',
    () async {
      const guessEntry = MenuEntry(
        id: 'guess-test',
        label: '猜你喜欢',
        action: MenuAction.feature,
        imageUrl: '',
        title: '猜你喜欢',
        description: '',
        feature: QqMusicFeature.guessRecommendations,
      );
      api.storedCredential = const QqMusicCredential(
        musicId: '10001',
        musicKey: 'music-key',
      );

      await controller.openFeature(guessEntry);

      expect(api.playableUrlProbeBatches, isEmpty);
      expect(api.playableUrlRequestMids, isEmpty);

      expect(await controller.activateSelected(), isTrue);

      expect(
        api.playableUrlRequestMids,
        contains(FakeQqMusicApi.songs.first.mid),
      );
    },
  );

  test(
    'VIP marker does not block playback while membership state is unknown',
    () async {
      await controller.openFeature(likedSongsEntry);
      controller.selectIndex(1);
      expect(controller.profile, isNull);

      expect(await controller.activateSelected(), isTrue);

      expect(controller.currentSong, FakeQqMusicApi.songs[1]);
      expect(controller.playbackError, isEmpty);
      expect(api.playableUrlRequestMids, contains(FakeQqMusicApi.songs[1].mid));
      expect(loadedSongs, [FakeQqMusicApi.songs[1]]);
    },
  );

  test('VIP playback denial comes from the playable URL endpoint', () async {
    await controller.openFeature(likedSongsEntry);
    controller.selectIndex(1);
    api.unavailableMids.add(FakeQqMusicApi.songs[1].mid);

    expect(await controller.activateSelected(), isFalse);

    expect(controller.currentSong, isNull);
    expect(controller.playbackError, '该歌曲需要 VIP 会员才能播放');
    expect(api.playableUrlRequestMids, contains(FakeQqMusicApi.songs[1].mid));
    expect(loadedSongs, isEmpty);
  });

  test(
    'guest auth-style URL errors are not shown as login state anomalies',
    () async {
      await controller.openFeature(likedSongsEntry);
      api.unauthorizedMids.add(FakeQqMusicApi.songs.first.mid);

      expect(await controller.activateSelected(), isFalse);

      expect(controller.isLoggedIn, isFalse);
      expect(controller.currentSong, isNull);
      expect(controller.playbackError, '当前未登录，该歌曲暂无游客播放地址');
      expect(controller.playbackError, isNot(contains('登录状态异常')));
      expect(controller.isUnavailable(FakeQqMusicApi.songs.first), isFalse);
      expect(loadedSongs, isEmpty);
    },
  );

  test('guest missing playable URL does not mark the song as 无音源', () async {
    await controller.openFeature(likedSongsEntry);
    api.unavailableMids.add(FakeQqMusicApi.songs.first.mid);

    expect(await controller.activateSelected(), isFalse);

    expect(controller.isLoggedIn, isFalse);
    expect(controller.playbackError, '当前未登录，该歌曲暂无游客播放地址');
    expect(controller.isUnavailable(FakeQqMusicApi.songs.first), isFalse);
    expect(loadedSongs, isEmpty);
  });

  test(
    'logged-in session expiry keeps a re-login message on play failure',
    () async {
      api.storedCredential = const QqMusicCredential(
        musicId: '10001',
        musicKey: 'music-key',
      );
      await controller.initialize();
      await controller.openFeature(likedSongsEntry);
      api.unauthorizedMids.add(FakeQqMusicApi.songs.first.mid);

      expect(await controller.activateSelected(), isFalse);

      expect(controller.isLoggedIn, isTrue);
      expect(controller.playbackError, 'QQ 音乐登录已失效，请重新扫码登录');
      expect(loadedSongs, isEmpty);
    },
  );

  test('onAppResumed rechecks QR status after returning from scan', () async {
    await controller.startQrLogin(loginType: 'qq');
    final checksBefore = api.qrStatusChecks;

    controller.onAppResumed();
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(api.qrStatusChecks, greaterThan(checksBefore));
  });

  test(
    'transient QR network errors while away from app do not kill the session',
    () async {
      await controller.startQrLogin(loginType: 'qq');
      api.qrStatusError = const QqMusicApiException(
        '无法连接 QQ 音乐登录服务：Failed host lookup: ssl.ptlogin2.qq.com',
      );

      controller.onAppResumed();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(controller.error, isEmpty);
      expect(controller.qrCode, isNotNull);
      expect(controller.statusMessage, contains('网络暂时'));

      api.qrStatusError = null;
      controller.onAppResumed();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(controller.error, isEmpty);
      expect(controller.qrStatus?.event, 1);
    },
  );

  test('song containers append the next page near the end', () async {
    const playlistsEntry = MenuEntry(
      id: 'created-playlists-test',
      label: '自建歌单',
      action: MenuAction.feature,
      imageUrl: '',
      title: '自建歌单',
      description: '',
      feature: QqMusicFeature.createdPlaylists,
    );
    api.paginateChildren = true;

    await controller.openFeature(playlistsEntry);
    expect(await controller.activateSelected(), isTrue);
    expect(api.childrenPagesLoaded, [1]);
    expect(controller.items, hasLength(25));

    controller.selectIndex(23);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(api.childrenPagesLoaded, [1, 2]);
    expect(controller.items, hasLength(50));
    expect(controller.selectedIndex, 23);
    expect(controller.result?.hasMore, isFalse);
    expect(controller.items.last.title, '歌单歌曲50');
  });

  test(
    'liked songs append every page near the end without moving selection',
    () async {
      api.paginateLikedSongs = true;

      await controller.openFeature(likedSongsEntry);
      expect(api.likedSongPagesLoaded, [1]);
      expect(controller.items, hasLength(25));
      expect(controller.result?.hasMore, isTrue);

      controller.selectIndex(23);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(api.likedSongPagesLoaded, [1, 2]);
      expect(controller.items, hasLength(50));
      expect(controller.selectedIndex, 23);

      controller.selectIndex(48);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(api.likedSongPagesLoaded, [1, 2, 3]);
      expect(controller.items, hasLength(75));
      expect(controller.selectedIndex, 48);
      expect(controller.result?.hasMore, isFalse);
      expect(controller.items.last.title, '喜欢歌曲75');
    },
  );

  test(
    'radar loads the next page near the end of the current stations',
    () async {
      const radarEntry = MenuEntry(
        id: 'radar-test',
        label: '雷达',
        action: MenuAction.feature,
        imageUrl: '',
        title: '雷达',
        description: '',
        feature: QqMusicFeature.radar,
      );

      await controller.openFeature(radarEntry);
      expect(controller.items, hasLength(10));
      expect(controller.result?.hasMore, isTrue);
      expect(api.radarPagesLoaded, [1]);

      controller.selectIndex(8);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(api.radarPagesLoaded, [1, 2]);
      expect(controller.items, hasLength(20));
      expect(controller.selectedIndex, 8);
      expect(controller.items.last.title, '雷达歌曲20');
    },
  );

  test('home feed opens daily playlist and embedded song shelves', () async {
    const homeEntry = MenuEntry(
      id: 'home-feed-test',
      label: '首页推荐',
      action: MenuAction.feature,
      imageUrl: '',
      title: '首页推荐',
      description: '',
      feature: QqMusicFeature.homeFeed,
    );

    await controller.openFeature(homeEntry);
    expect(controller.items.map((item) => item.title), [
      '每日30首',
      '百万收藏',
      '大家都在听',
      '热歌榜',
    ]);
    expect(controller.items.first.id, '7971796071');
    expect(controller.items.first.directoryId, '202');
    expect(controller.items.first.isDirectoryPlaylist, isFalse);

    expect(await controller.activateSelected(), isTrue);
    expect(controller.result?.title, '每日30首');
    expect(controller.items, FakeQqMusicApi.songs);
    expect(api.childrenLoadCounts['7971796071'], 1);

    expect(controller.back(), isTrue);
    controller.selectIndex(2);
    expect(await controller.activateSelected(), isTrue);
    expect(controller.result?.title, '大家都在听');
    expect(controller.items, FakeQqMusicApi.songs);
  });
}

class _PlaybackFakeApi extends FakeQqMusicApi {
  final Set<String> unavailableMids = {};
  final Set<String> unauthorizedMids = {};
  final List<String> playableUrlRequestMids = [];
  final List<List<String>> playableUrlProbeBatches = [];

  @override
  Future<Map<String, Uri?>> getPlayableUrls(
    List<QqMusicItem> songs, {
    int fileType = 13,
  }) async {
    playableUrlProbeBatches.add(
      songs.map((song) => song.mid).toList(growable: false),
    );
    return super.getPlayableUrls(songs, fileType: fileType);
  }

  @override
  Future<Uri> getPlayableUrl(QqMusicItem song, {int fileType = 13}) async {
    playableUrlRequestMids.add(song.mid);
    if (unauthorizedMids.contains(song.mid)) {
      throw const QqMusicApiException(
        'QQ 音乐登录已失效，请重新扫码登录',
        code: 104401,
      );
    }
    if (unavailableMids.contains(song.mid)) {
      throw const QqMusicApiException('歌曲没有可用播放地址', code: 104003);
    }
    return Uri.parse('https://example.com/${song.mid}.mp3');
  }
}
