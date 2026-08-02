import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qqmusic_ipod/business/entities/music.dart';
import 'package:qqmusic_ipod/business/entities/account.dart';
import 'package:qqmusic_ipod/business/entities/auth.dart';
import 'package:qqmusic_ipod/business/repositories/music_repository.dart';
import 'package:qqmusic_ipod/features/player/state/controller.dart';
import 'package:qqmusic_ipod/features/shell/models/ipod_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('sleep timer pauses playback and clears its deadline', () async {
    SharedPreferences.setMockInitialValues({});
    final player = AudioPlayer();
    var pauseCount = 0;
    final controller = _controller(
      api: _RadarApi(),
      player: player,
      audioPlaybackPauser: () async => pauseCount += 1,
    );
    addTearDown(() async {
      controller.dispose();
      await player.dispose();
    });

    controller.setSleepTimer(const Duration(milliseconds: 5));
    expect(controller.sleepTimerDeadline, isNotNull);
    final wait = Stopwatch()..start();
    while (controller.statusMessage.isEmpty &&
        wait.elapsed < const Duration(seconds: 1)) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }

    expect(pauseCount, 1);
    expect(controller.sleepTimerDeadline, isNull);
    expect(controller.statusMessage, '定时关闭已暂停播放');
  });

  test(
    'next waits for an in-flight radar page and plays its first song',
    () async {
      SharedPreferences.setMockInitialValues({});
      final api = _RadarApi();
      final player = AudioPlayer();
      final loadedSongs = <String>[];
      final controller = _controller(
        api: api,
        player: player,
        audioSourceLoader: (song, uri) async => loadedSongs.add(song.id),
      );
      addTearDown(() async {
        controller.dispose();
        await player.dispose();
      });

      await controller.openFeature(_radarEntry);
      while (!api.secondPageRequested) {
        await Future<void>.delayed(Duration.zero);
      }

      final next = controller.playAdjacent(1);
      api.releaseSecondPage();
      await next;

      expect(controller.currentSong?.id, 'radar-2');
      expect(controller.playbackQueue.map((song) => song.id), [
        'radar-1',
        'radar-2',
      ]);
      expect(loadedSongs, ['radar-1', 'radar-2']);
    },
  );

  test(
    'queue selection keeps the radar card aligned with the playing song',
    () async {
      SharedPreferences.setMockInitialValues({});
      final api = _RadarApi();
      final player = AudioPlayer();
      final controller = _controller(api: api, player: player);
      addTearDown(() async {
        controller.dispose();
        await player.dispose();
      });

      await controller.openFeature(_radarEntry);
      while (!api.secondPageRequested) {
        await Future<void>.delayed(Duration.zero);
      }
      api.releaseSecondPage();
      while (controller.playbackQueue.length < 2) {
        await Future<void>.delayed(Duration.zero);
      }

      expect(await controller.playQueueIndex(1), isTrue);

      expect(controller.currentSong?.id, 'radar-2');
      expect(controller.selectedItem?.id, 'radar-2');
      expect(controller.selectedIndex, 1);
    },
  );

  test('keeps VIP songs in the queue when playback is blocked', () async {
    SharedPreferences.setMockInitialValues({});
    final api = _RadarApi(loggedIn: true);
    final player = AudioPlayer();
    final controller = _controller(api: api, player: player);
    addTearDown(() async {
      controller.dispose();
      await player.dispose();
    });

    await controller.openFeature(_accountEntry);
    final vipSong = QqMusicItem(
      id: 'vip-song',
      mid: 'vip-song',
      title: 'VIP Song',
      subtitle: 'Artist',
      imageUrl: '',
      type: QqMusicItemType.song,
      requiresVip: true,
    );

    expect(
      await controller.play(vipSong, queue: [_song('free-song'), vipSong]),
      isFalse,
    );
    expect(controller.playbackQueue.map((song) => song.id), [
      'free-song',
      'vip-song',
    ]);
    expect(controller.playbackError, '该歌曲需要 VIP 会员才能播放');
  });

  test('account refresh renews credentials before reloading profile', () async {
    SharedPreferences.setMockInitialValues({});
    final api = _RadarApi(loggedIn: true);
    final player = AudioPlayer();
    final controller = _controller(api: api, player: player);
    addTearDown(() async {
      controller.dispose();
      await player.dispose();
    });

    await controller.openFeature(_accountEntry);
    api.calls.clear();
    await controller.refresh();

    expect(api.calls, ['refreshCredential', 'getUserProfile']);
    expect(controller.error, isEmpty);
  });

  test('account refresh does not reload profile after renewal fails', () async {
    SharedPreferences.setMockInitialValues({});
    final api = _RadarApi(loggedIn: true, refreshError: Exception('续期失败'));
    final player = AudioPlayer();
    final controller = _controller(api: api, player: player);
    addTearDown(() async {
      controller.dispose();
      await player.dispose();
    });

    await controller.openFeature(_accountEntry);
    api.calls.clear();
    await controller.refresh();

    expect(api.calls, ['refreshCredential']);
    expect(controller.error, '续期失败');
    expect(controller.isLoading, isFalse);
  });

  test('resume refresh exposes an invalidated session', () async {
    SharedPreferences.setMockInitialValues({});
    final api = _RadarApi(loggedIn: true, resumeError: Exception('登录已失效'));
    final player = AudioPlayer();
    final controller = _controller(api: api, player: player);
    addTearDown(() async {
      controller.dispose();
      await player.dispose();
    });

    controller.onAppResumed();
    while (controller.error.isEmpty) {
      await Future<void>.delayed(Duration.zero);
    }

    expect(controller.isLoggedIn, isFalse);
    expect(controller.error, '登录已失效');
  });

  test('resolves radar liked state before choosing add or remove', () async {
    SharedPreferences.setMockInitialValues({});
    final api = _RadarApi(loggedIn: true, radarSongLiked: true);
    final player = AudioPlayer();
    final controller = _controller(api: api, player: player);
    addTearDown(() async {
      controller.dispose();
      await player.dispose();
    });

    await controller.play(_song('radar-1'), queue: [_song('radar-1')]);
    await controller.toggleCurrentSongLiked();

    expect(api.lastSongLikedValue, isFalse);
  });
}

QqMusicController _controller({
  required _RadarApi api,
  required AudioPlayer player,
  Future<void> Function(QqMusicItem song, Uri uri)? audioSourceLoader,
  Future<void> Function()? audioPlaybackPauser,
}) {
  return QqMusicController(
    api: api,
    audioPlayer: player,
    audioSourceLoader: audioSourceLoader ?? (song, uri) async {},
    audioPlaybackStarter: () async {},
    audioPlaybackPauser: audioPlaybackPauser ?? () async {},
    audioSeeker: (position) async {},
    audioSessionConfigurator: () async {},
    playerStateStream: const Stream.empty(),
    positionStream: const Stream.empty(),
    durationStream: const Stream.empty(),
    playerErrorStream: const Stream.empty(),
  );
}

const _radarEntry = MenuEntry(
  id: 'radar',
  label: '雷达',
  action: MenuAction.feature,
  imageUrl: '',
  title: '音乐雷达',
  description: '',
  feature: QqMusicFeature.radar,
);

const _accountEntry = MenuEntry(
  id: 'account',
  label: '账号',
  action: MenuAction.feature,
  imageUrl: '',
  title: '账号',
  description: '',
  feature: QqMusicFeature.account,
);

QqMusicItem _song(String id) {
  return QqMusicItem(
    id: id,
    mid: id,
    title: id,
    subtitle: 'Artist',
    imageUrl: '',
    type: QqMusicItemType.song,
  );
}

class _RadarApi implements QqMusicApi {
  _RadarApi({
    this.loggedIn = false,
    this.radarSongLiked = false,
    this.refreshError,
    this.resumeError,
  });

  bool loggedIn;
  final bool radarSongLiked;
  final Object? refreshError;
  final Object? resumeError;
  final List<String> calls = [];
  final Completer<void> _secondPageGate = Completer<void>();
  bool secondPageRequested = false;
  bool? lastSongLikedValue;

  @override
  bool get isLoggedIn => loggedIn;

  void releaseSecondPage() {
    if (!_secondPageGate.isCompleted) {
      _secondPageGate.complete();
    }
  }

  @override
  Future<void> ensureSessionFresh() async {
    final error = resumeError;
    if (error != null) {
      loggedIn = false;
      throw error;
    }
  }

  @override
  Future<QqMusicCredential> refreshCredential() async {
    calls.add('refreshCredential');
    final error = refreshError;
    if (error != null) {
      throw error;
    }
    return const QqMusicCredential(
      musicId: 'user-1',
      musicKey: 'refreshed-key',
    );
  }

  @override
  Future<QqMusicUserProfile> getUserProfile() async {
    calls.add('getUserProfile');
    return const QqMusicUserProfile(
      id: 'user-1',
      nickname: 'Test User',
      avatarUrl: '',
      isVip: false,
    );
  }

  @override
  Future<QqMusicFeatureResult> loadFeature(
    QqMusicFeature feature, {
    int page = 1,
    int pageSize = 25,
    bool forceRefresh = false,
  }) async {
    if (feature == QqMusicFeature.likedSongs) {
      return QqMusicFeatureResult(
        title: '我喜欢',
        items: radarSongLiked ? [_song('radar-1')] : const [],
      );
    }
    if (page == 1) {
      return QqMusicFeatureResult(
        title: '雷达',
        items: [_song('radar-1')],
        hasMore: true,
      );
    }
    secondPageRequested = true;
    await _secondPageGate.future;
    return QqMusicFeatureResult(title: '雷达', items: [_song('radar-2')]);
  }

  @override
  Future<Uri> getPlayableUrl(QqMusicItem song, {int fileType = 13}) async {
    return Uri.parse('https://example.com/${song.id}.mp3');
  }

  @override
  Future<void> setSongLiked(QqMusicItem song, {required bool liked}) async {
    lastSongLikedValue = liked;
  }

  @override
  Future<QqMusicLyrics> getLyrics(QqMusicItem song) async {
    return const QqMusicLyrics(lines: []);
  }

  @override
  void dispose() {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
