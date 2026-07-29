import 'dart:async';
import 'dart:math';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:qqmusic_ipod/features/shell/models/ipod_models.dart';
import 'package:qqmusic_ipod/core/audio/audio_output_service.dart';
import 'package:qqmusic_ipod/business/repositories/music_repository.dart';
import 'package:qqmusic_ipod/business/entities/account.dart';
import 'package:qqmusic_ipod/data/models/api_exception.dart';
import 'package:qqmusic_ipod/business/entities/auth.dart';
import 'package:qqmusic_ipod/business/entities/music.dart';
import 'package:qqmusic_ipod/core/audio/audio_handler.dart';
import 'package:qqmusic_ipod/core/storage/playback_state_store.dart';

class QqMusicPlaybackProgress {
  const QqMusicPlaybackProgress({
    this.position = Duration.zero,
    this.duration = Duration.zero,
  });

  final Duration position;
  final Duration duration;

  double get value {
    if (duration.inMilliseconds <= 0) {
      return 0;
    }
    return (position.inMilliseconds / duration.inMilliseconds).clamp(0, 1);
  }
}

class _PrefetchedPlayableUrl {
  const _PrefetchedPlayableUrl({required this.future, required this.createdAt});

  final Future<Uri?> future;
  final DateTime createdAt;
}

class QqMusicController extends ChangeNotifier {
  QqMusicController({
    required this.api,
    AudioPlayer? audioPlayer,
    QqMusicAudioHandler? audioHandler,
    Future<bool> Function(Uri uri)? externalUrlLauncher,
    Future<void> Function(QqMusicItem song, Uri uri)? audioSourceLoader,
    Future<void> Function()? audioPlaybackStarter,
    Future<void> Function(Duration position)? audioSeeker,
    Future<void> Function()? audioSessionConfigurator,
    Future<String> Function()? audioOutputNameLoader,
    Stream<PlayerState>? playerStateStream,
    Stream<Duration>? positionStream,
    Stream<Duration?>? durationStream,
    Stream<PlayerException>? playerErrorStream,
    DateTime Function()? clock,
    QqMusicPlaybackStateStore? playbackStateStore,
    this.prefetchedPlayableUrlMaxAge = const Duration(minutes: 5),
  }) : _clock = clock ?? DateTime.now,
       _audioHandler = audioHandler,
       _audioPlayer = audioPlayer ?? audioHandler?.player ?? AudioPlayer(),
       _ownsAudioPlayer = audioPlayer == null && audioHandler == null,
       _playbackStateStore = playbackStateStore ?? QqMusicPlaybackStateStore(),
       _externalUrlLauncher =
           externalUrlLauncher ??
           ((uri) => launchUrl(uri, mode: LaunchMode.externalApplication)) {
    _currentSong = _audioHandler?.currentSong;
    _audioSourceReady = _currentSong != null;
    _audioHandler?.setSkipHandler(playAdjacent);
    _audioSourceLoader =
        audioSourceLoader ??
        (song, uri) async {
          final handler = _audioHandler;
          if (handler != null) {
            await handler.load(song, uri);
          } else {
            await _audioPlayer.setAudioSource(AudioSource.uri(uri));
          }
        };
    _audioPlaybackStarter =
        audioPlaybackStarter ?? _audioHandler?.play ?? _audioPlayer.play;
    _audioSeeker =
        audioSeeker ??
        (position) async {
          final handler = _audioHandler;
          if (handler != null) {
            await handler.seek(position);
          } else {
            await _audioPlayer.seek(position);
          }
        };
    _audioSessionConfigurator =
        audioSessionConfigurator ?? _configureAudioSession;
    _audioOutputNameLoader =
        audioOutputNameLoader ?? const AudioOutputService().currentOutputName;
    _subscriptions.add(
      (playerStateStream ?? _audioPlayer.playerStateStream).listen((state) {
        if (state.playing || state.processingState != ProcessingState.idle) {
          _playbackRequested = state.playing;
        }
        final previousIsPlaying = _isPlaying;
        final previousIsBuffering = _isBuffering;
        final previousProcessingState = _lastProcessingState;
        _lastProcessingState = state.processingState;
        final isTerminal =
            state.processingState == ProcessingState.idle ||
            state.processingState == ProcessingState.completed;
        _isPlaying = state.playing && !isTerminal;
        _isBuffering =
            state.processingState == ProcessingState.loading ||
            state.processingState == ProcessingState.buffering;
        if (state.processingState == ProcessingState.completed &&
            previousProcessingState != ProcessingState.completed) {
          unawaited(_handlePlaybackCompleted());
        }
        if (_isPlaying != previousIsPlaying ||
            _isBuffering != previousIsBuffering) {
          notifyListeners();
        }
        if (previousIsPlaying && !_isPlaying) {
          _schedulePlaybackStateSave(immediate: true);
        }
      }),
    );
    _subscriptions.add(
      (positionStream ?? _audioPlayer.positionStream).listen((position) {
        _position = position;
        _publishPlaybackProgress();
        _schedulePlaybackStateSave();
      }),
    );
    _subscriptions.add(
      (durationStream ?? _audioPlayer.durationStream).listen((duration) {
        // Prefer the live player duration — home-feed songs often ship with
        // duration=0 in the card payload.
        final resolved = (duration != null && duration > Duration.zero)
            ? duration
            : (_audioPlayer.duration != null &&
                  _audioPlayer.duration! > Duration.zero)
            ? _audioPlayer.duration!
            : (_currentSong?.duration ?? Duration.zero);
        if (resolved > Duration.zero) {
          _duration = resolved;
          _audioHandler?.updateDuration(resolved);
        } else if (_duration <= Duration.zero) {
          _duration = Duration.zero;
        }
        _publishPlaybackProgress();
      }),
    );
    _subscriptions.add(
      (playerErrorStream ?? _audioPlayer.errorStream).listen(
        _handlePlayerError,
      ),
    );
  }

  final QqMusicApi api;
  final DateTime Function() _clock;
  final Duration prefetchedPlayableUrlMaxAge;
  final QqMusicAudioHandler? _audioHandler;
  final AudioPlayer _audioPlayer;
  final bool _ownsAudioPlayer;
  final QqMusicPlaybackStateStore _playbackStateStore;
  final Future<bool> Function(Uri uri) _externalUrlLauncher;
  late final Future<void> Function(QqMusicItem song, Uri uri)
  _audioSourceLoader;
  late final Future<void> Function() _audioPlaybackStarter;
  late final Future<void> Function(Duration position) _audioSeeker;
  late final Future<void> Function() _audioSessionConfigurator;
  late final Future<String> Function() _audioOutputNameLoader;
  final List<StreamSubscription<Object?>> _subscriptions = [];
  Timer? _statusClearTimer;
  Timer? _playbackErrorClearTimer;
  Timer? _playbackStateSaveTimer;
  Future<void> _playbackStateWrite = Future<void>.value();
  static const _statusMessageTtl = Duration(seconds: 2);
  static const _playbackErrorTtl = Duration(seconds: 4);
  final ValueNotifier<QqMusicPlaybackProgress> playbackProgress = ValueNotifier(
    const QqMusicPlaybackProgress(),
  );
  final List<QqMusicFeatureResult> _resultPath = [];
  final List<QqMusicItem?> _containerPath = [];
  final Map<QqMusicFeature, QqMusicFeatureResult> _featureCache = {};
  final Map<QqMusicFeature, int> _featurePages = {};
  final Map<String, int> _childrenPages = {};
  final Map<String, QqMusicFeatureResult> _childrenCache = {};
  final Map<String, _PrefetchedPlayableUrl> _prefetchedPlayableUrls = {};
  final Map<String, QqMusicLyrics> _lyricsCache = {};
  final Map<String, bool> _likedStatusCache = {};
  final Set<String> _unavailableSongKeys = {};
  List<QqMusicItem> _playbackQueue = const [];
  final Set<String> _favoritePlaylistIds = {};
  final Set<String> _unfavoritePlaylistIds = {};
  final Set<String> _dislikedItemIds = {};
  final Set<String> _undislikedItemIds = {};

  Timer? _qrPollTimer;
  bool _pollingQr = false;
  bool _loadingMore = false;
  bool _handlingPlaybackCompletion = false;
  bool _switchingTrack = false;
  bool _radarPlayPending = false;
  bool _loadingAudioSource = false;
  bool _recoveringSourceError = false;
  bool _restoringPlaybackState = false;
  bool _audioSourceReady = false;
  bool _playbackRequested = false;
  ProcessingState _lastProcessingState = ProcessingState.idle;
  bool _isLoading = false;
  bool _isPlaying = false;
  bool _isBuffering = false;
  bool _isLoadingLyrics = false;
  bool _currentSongFromLiked = false;
  bool? _currentSongLikedStatus;
  int _likedStatusRevision = 0;
  String _error = '';
  String _playbackError = '';
  String _statusMessage = '';
  String _qrLoginType = 'qq';
  int _selectedIndex = 0;
  MenuEntry? _entry;
  QqMusicQrCode? _qrCode;
  QqMusicQrStatus? _qrStatus;
  QqMusicUserProfile? _profile;
  QqMusicItem? _currentSong;
  QqMusicLyrics? _lyrics;
  QqMusicPlaybackMode _playbackMode = QqMusicPlaybackMode.sequential;
  String _audioOutputName =
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android ? '本机扬声器' : '';
  Uri? _lastExternalUri;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  int _playbackFileType = 13;
  double _volumeLimit = 1;

  bool get isLoading => _isLoading;
  bool get isPlaying => _isPlaying;
  bool get isBuffering => _isBuffering;
  bool get isLoggedIn => api.isLoggedIn;
  String get error => _error;
  String get playbackError => _playbackError;
  String get statusMessage => _statusMessage;
  String get qrLoginType => _qrLoginType;
  int get selectedIndex => _selectedIndex;
  MenuEntry? get entry => _entry;
  QqMusicFeatureResult? get result =>
      _resultPath.isEmpty ? null : _resultPath.last;
  QqMusicItem? get currentContainer =>
      _containerPath.isEmpty ? null : _containerPath.last;
  QqMusicQrCode? get qrCode => _qrCode;
  QqMusicQrStatus? get qrStatus => _qrStatus;
  QqMusicUserProfile? get profile => _profile;
  QqMusicItem? get currentSong => _currentSong;
  List<QqMusicItem> get playbackQueue => _playbackQueue;
  int get currentPlaybackQueueIndex {
    final current = _currentSong;
    if (current == null) {
      return -1;
    }
    return _playbackQueue.indexWhere((item) => _sameSong(item, current));
  }

  bool isCurrentPlaybackQueueIndex(int index) {
    return index >= 0 &&
        index < _playbackQueue.length &&
        _sameSong(_playbackQueue[index], _currentSong);
  }

  QqMusicLyrics? get lyrics => _lyrics;
  bool get isLoadingLyrics => _isLoadingLyrics;
  QqMusicPlaybackMode get playbackMode => _playbackMode;
  String get audioOutputName => _audioOutputName;
  bool get isCurrentSongLiked {
    final song = _currentSong;
    if (song == null) {
      return false;
    }
    return _currentSongLikedStatus ??
        _likedStatusFromFeatureCache(song) ??
        _currentSongFromLiked;
  }

  bool? _likedStatusFromFeatureCache(QqMusicItem song) {
    final liked = _featureCache[QqMusicFeature.likedSongs];
    if (liked == null) {
      return null;
    }
    if (liked.items.any((item) => _sameSong(item, song))) {
      return true;
    }
    return liked.hasMore ? null : false;
  }

  Uri? get lastExternalUri => _lastExternalUri;
  Duration get position => _position;
  Duration get duration => _duration;
  double get progress => playbackProgress.value.value;
  int get playbackFileType => _playbackFileType;
  double get volumeLimit => _volumeLimit;

  void setPlaybackFileType(int fileType) {
    if (_playbackFileType == fileType) {
      return;
    }
    _playbackFileType = fileType;
    _prefetchedPlayableUrls.clear();
  }

  Future<void> setVolumeLimit(double gain) async {
    final next = gain.clamp(0.0, 1.0);
    if (_volumeLimit == next) {
      return;
    }
    _volumeLimit = next;
    await _audioPlayer.setVolume(next);
  }

  int clearMemoryCaches() {
    final count =
        _featureCache.length +
        _childrenCache.length +
        _prefetchedPlayableUrls.length +
        _lyricsCache.length +
        _unavailableSongKeys.length;
    _featureCache.clear();
    _featurePages.clear();
    _childrenCache.clear();
    _childrenPages.clear();
    _prefetchedPlayableUrls.clear();
    _lyricsCache.clear();
    _unavailableSongKeys.clear();
    _coverFlowCacheReady = false;
    notifyListeners();
    return count;
  }

  void _publishPlaybackProgress() {
    final previous = playbackProgress.value;
    if (previous.position == _position && previous.duration == _duration) {
      return;
    }
    playbackProgress.value = QqMusicPlaybackProgress(
      position: _position,
      duration: _duration,
    );
  }

  List<QqMusicItem> get items => result?.items ?? const [];

  List<QqMusicItem> _coverFlowSongs = const [];
  List<Album> _coverFlowAlbums = coverFlowLibrary;
  List<QqMusicItem>? _coverFlowPlaybackQueueSource;
  QqMusicFeatureResult? _coverFlowLikedSource;
  QqMusicFeatureResult? _coverFlowGuessSource;
  QqMusicFeatureResult? _coverFlowNewsSource;
  bool _coverFlowCacheReady = false;

  List<Album> get coverFlowAlbums {
    final liked = _featureCache[QqMusicFeature.likedSongs];
    final guess = _featureCache[QqMusicFeature.guessRecommendations];
    final news = _featureCache[QqMusicFeature.newSongs];
    if (_coverFlowCacheReady &&
        identical(_coverFlowPlaybackQueueSource, _playbackQueue) &&
        identical(_coverFlowLikedSource, liked) &&
        identical(_coverFlowGuessSource, guess) &&
        identical(_coverFlowNewsSource, news)) {
      return _coverFlowAlbums;
    }
    final albums = <Album>[];
    final songs = <QqMusicItem>[];
    final seen = <String>{};

    void addSong(QqMusicItem song) {
      if (!song.isSong) {
        return;
      }
      final key = song.imageUrl.isNotEmpty
          ? song.imageUrl
          : (song.mid.isNotEmpty ? song.mid : song.id);
      if (key.isEmpty || !seen.add(key)) {
        return;
      }
      songs.add(song);
      albums.add(
        Album(
          title: song.title,
          artist: song.subtitle,
          imageUrl: song.imageUrl,
          songId: song.id,
          songMid: song.mid,
        ),
      );
    }

    for (final song in _playbackQueue) {
      addSong(song);
    }
    if (liked != null) {
      for (final song in liked.items) {
        addSong(song);
      }
    }
    if (guess != null) {
      for (final song in guess.items) {
        addSong(song);
      }
    }
    if (news != null) {
      for (final song in news.items) {
        addSong(song);
      }
    }
    _coverFlowPlaybackQueueSource = _playbackQueue;
    _coverFlowLikedSource = liked;
    _coverFlowGuessSource = guess;
    _coverFlowNewsSource = news;
    _coverFlowCacheReady = true;
    _coverFlowSongs = List.unmodifiable(songs.take(24));
    _coverFlowAlbums = albums.isEmpty
        ? coverFlowLibrary
        : List.unmodifiable(albums.take(24));
    if (albums.isEmpty) {
      _coverFlowSongs = const [];
    }
    return _coverFlowAlbums;
  }

  Future<bool> playCoverFlowIndex(int index) async {
    final albums = coverFlowAlbums;
    if (index < 0 ||
        index >= albums.length ||
        index >= _coverFlowSongs.length) {
      return false;
    }
    final song = _coverFlowSongs[index];
    final queue = List<QqMusicItem>.from(_coverFlowSongs);
    return play(song, queue: queue);
  }

  bool isUnavailable(QqMusicItem item) {
    return item.isSong &&
        !item.requiresVip &&
        !item.isCopyrightRestricted &&
        _unavailableSongKeys.contains(_songKey(item));
  }

  bool isCurrentSong(QqMusicItem item) => _sameSong(item, _currentSong);

  QqMusicItem? get selectedItem {
    final activeItems = items;
    if (activeItems.isEmpty || _selectedIndex >= activeItems.length) {
      return null;
    }
    return activeItems[_selectedIndex];
  }

  Future<void> initialize() async {
    unawaited(_loadAudioOutputName());
    await _restorePlaybackState();
    try {
      await api.restoreSession();
      if (api.isLoggedIn) {
        await _loadProfile();
        await _prefetchCoverFlowSources();
      } else {
        await _prefetchPublicCoverFlowSources();
      }
    } catch (error) {
      _error = _message(error);
    }
    await _loadRememberedAudioSource(silent: true);
    final restoredSong = _currentSong;
    if (restoredSong != null) {
      _prepareCurrentSongLikedStatus(restoredSong);
      unawaited(_loadLyrics(restoredSong));
      unawaited(_loadAudioOutputName());
    }
    notifyListeners();
  }

  Future<void> _restorePlaybackState() async {
    final snapshot = await _playbackStateStore.load();
    final song = snapshot?.currentSong;
    if (snapshot == null || song == null || !song.isSong) {
      return;
    }
    final queue = snapshot.queue.where((item) => item.isSong).toList();
    _currentSong = song;
    _playbackQueue = List.unmodifiable(
      queue.any((item) => _sameSong(item, song)) ? queue : [song, ...queue],
    );
    _playbackMode = snapshot.playbackMode;
    _duration = snapshot.duration > Duration.zero
        ? snapshot.duration
        : song.duration;
    _position = _boundedRestoredPosition(snapshot.position, _duration);
    _publishPlaybackProgress();
    notifyListeners();
  }

  Future<bool> _loadRememberedAudioSource({bool silent = false}) async {
    if (_audioSourceReady) {
      return true;
    }
    final song = _currentSong;
    if (song == null || _restoringPlaybackState) {
      return false;
    }
    _restoringPlaybackState = true;
    final restoredPosition = _position;
    try {
      await _audioSessionConfigurator();
      final url = await _getPlayableUrl(song);
      await _loadAudioSourceWithRetry(song, url);
      if (!_sameSong(song, _currentSong)) {
        return false;
      }
      _audioSourceReady = true;
      final playerDuration = _audioHandler?.duration ?? _audioPlayer.duration;
      if (playerDuration != null && playerDuration > Duration.zero) {
        _duration = playerDuration;
        _audioHandler?.updateDuration(playerDuration);
      }
      final target = _boundedRestoredPosition(restoredPosition, _duration);
      if (target > Duration.zero) {
        await _seekTo(target);
      }
      _position = target;
      _publishPlaybackProgress();
      _clearPlaybackError();
      _prefetchAdjacentPlayableUrls(song);
      _schedulePlaybackStateSave(immediate: true);
      return true;
    } catch (error) {
      _audioSourceReady = false;
      if (!silent) {
        _setPlaybackError(_playbackFailureMessage(error, song: song));
      }
      return false;
    } finally {
      _restoringPlaybackState = false;
      notifyListeners();
    }
  }

  Duration _boundedRestoredPosition(Duration position, Duration duration) {
    if (position <= Duration.zero) {
      return Duration.zero;
    }
    if (duration <= Duration.zero || position < duration) {
      return position;
    }
    final beforeEnd = duration - const Duration(milliseconds: 500);
    return beforeEnd > Duration.zero ? beforeEnd : Duration.zero;
  }

  void _schedulePlaybackStateSave({bool immediate = false}) {
    if (_restoringPlaybackState ||
        _loadingAudioSource ||
        _currentSong == null) {
      return;
    }
    _playbackStateSaveTimer?.cancel();
    if (immediate) {
      unawaited(_savePlaybackState());
      return;
    }
    _playbackStateSaveTimer = Timer(
      const Duration(seconds: 2),
      () => unawaited(_savePlaybackState()),
    );
  }

  Future<void> _savePlaybackState() async {
    final song = _currentSong;
    if (song == null) {
      return;
    }
    final snapshot = QqMusicPlaybackSnapshot(
      currentSong: song,
      queue: List<QqMusicItem>.from(_playbackQueue),
      position: _position,
      duration: _duration,
      playbackMode: _playbackMode,
    );
    _playbackStateWrite = _playbackStateWrite
        .then((_) => _playbackStateStore.save(snapshot))
        .catchError((_) {});
    await _playbackStateWrite;
  }

  void _clearPersistedPlaybackState() {
    _playbackStateSaveTimer?.cancel();
    _playbackStateWrite = _playbackStateWrite
        .then((_) => _playbackStateStore.clear())
        .catchError((_) {});
    unawaited(_playbackStateWrite);
  }

  Future<void> _prefetchCoverFlowSources() async {
    await _run(
      () => api.loadFeature(QqMusicFeature.likedSongs, pageSize: 100),
      replaceResult: false,
      cacheFeature: QqMusicFeature.likedSongs,
      updateVisibleResult: false,
    );
    await _run(
      () => api.loadFeature(QqMusicFeature.guessRecommendations),
      replaceResult: false,
      cacheFeature: QqMusicFeature.guessRecommendations,
      updateVisibleResult: false,
    );
    await _prefetchPublicCoverFlowSources();
  }

  Future<void> _prefetchPublicCoverFlowSources() async {
    await _run(
      () => api.loadFeature(QqMusicFeature.newSongs),
      replaceResult: false,
      cacheFeature: QqMusicFeature.newSongs,
      updateVisibleResult: false,
    );
  }

  Future<void> openFeature(MenuEntry entry) async {
    _entry = entry;
    _selectedIndex = 0;
    _resultPath.clear();
    _containerPath.clear();
    _error = '';
    _clearPlaybackError();
    _clearStatusMessage(scheduleDismiss: false);
    _stopQrPolling();
    notifyListeners();
    if (entry.feature == QqMusicFeature.account) {
      if (api.isLoggedIn) {
        await _loadProfile();
      } else {
        await startQrLogin();
      }
      return;
    }
    if (entry.feature == QqMusicFeature.search) {
      return;
    }
    final feature = entry.feature;
    if (feature != null) {
      final cached = _featureCache[feature];
      if (cached != null) {
        _setRootResult(
          cached.withMetadata(
            updatedAt: cached.updatedAt ?? DateTime.now().toUtc(),
            isFromCache: true,
          ),
        );
        notifyListeners();
        if (feature == QqMusicFeature.radar && items.isNotEmpty) {
          await _startRadarPlayback();
        }
        return;
      }
      await _run(
        () => api.loadFeature(feature),
        replaceResult: true,
        cacheFeature: feature,
      );
      _featurePages[feature] = 1;
      if (feature == QqMusicFeature.radar && items.isNotEmpty) {
        await _startRadarPlayback();
      }
    }
  }

  Future<void> refresh() async {
    final active = _entry;
    if (active == null) {
      return;
    }
    if (active.feature == QqMusicFeature.account) {
      if (api.isLoggedIn) {
        await _loadProfile();
      } else {
        await startQrLogin();
      }
      return;
    }
    if (active.feature == QqMusicFeature.search) {
      return;
    }
    final feature = active.feature;
    if (feature != null) {
      await _run(
        () => api.loadFeature(feature, forceRefresh: true),
        replaceResult: true,
        cacheFeature: feature,
      );
      _featurePages[feature] = 1;
      if (feature == QqMusicFeature.radar && items.isNotEmpty) {
        await _startRadarPlayback();
      }
    }
  }

  Future<bool> _startRadarPlayback({int direction = 1}) async {
    if (_switchingTrack) {
      _radarPlayPending = true;
      return false;
    }
    if (items.isEmpty) {
      return false;
    }
    _switchingTrack = true;
    var played = false;
    try {
      do {
        _radarPlayPending = false;
        played = await _playRadarFromSelection(direction: direction);
      } while (_radarPlayPending);
      return played;
    } finally {
      _switchingTrack = false;
      if (_radarPlayPending) {
        _radarPlayPending = false;
        unawaited(_startRadarPlayback(direction: direction));
      }
    }
  }

  Future<bool> _playRadarFromSelection({int direction = 1}) async {
    final step = direction == 0 ? 1 : (direction > 0 ? 1 : -1);
    final wrap = direction == 0;
    var index = _selectedIndex.clamp(0, items.isEmpty ? 0 : items.length - 1);
    final visited = <int>{};

    while (items.isNotEmpty) {
      if (index < 0) {
        return false;
      }
      if (index >= items.length) {
        if (step < 0 || !await _loadMoreIfPossible()) {
          return false;
        }
        continue;
      }
      if (!visited.add(index)) {
        return false;
      }

      final song = items[index];
      if (_selectedIndex != index) {
        _selectedIndex = index;
        notifyListeners();
      }
      if (index >= items.length - 3) {
        unawaited(_maybeLoadMore());
      }

      if (!song.isSong ||
          _shouldBlockVipPlayback(song) ||
          song.isCopyrightRestricted ||
          isUnavailable(song)) {
        index += step;
        if (wrap && index >= items.length) {
          index = 0;
        }
        continue;
      }

      if (isCurrentSong(song)) {
        if (!isPlaying) {
          await _startPlayback();
        }
        return true;
      }

      final queue = List<QqMusicItem>.unmodifiable(
        items.where((item) => item.isSong),
      );
      if (await play(song, queue: queue)) {
        return true;
      }

      if (_shouldAutoSkipFailedSong(song)) {
        index += step;
        if (wrap && index >= items.length) {
          index = 0;
        }
        continue;
      }
      return false;
    }
    return false;
  }

  bool _shouldAutoSkipFailedSong(QqMusicItem song) {
    if (_shouldBlockVipPlayback(song) ||
        song.isCopyrightRestricted ||
        isUnavailable(song)) {
      return true;
    }
    // Known non-VIP: skip tracks marked VIP even before a play attempt fails.
    if (song.requiresVip && _profile?.isVip == false) {
      return true;
    }
    final message = _playbackError;
    return message.contains('VIP') ||
        message.contains('会员') ||
        message.contains('版权') ||
        message.contains('播放地址') ||
        message.contains('无音源');
  }

  Future<bool> _loadMoreIfPossible() async {
    final before = items.length;
    await _maybeLoadMore(forceNearEnd: true);
    return items.length > before;
  }

  Future<void> search(String keyword) async {
    await _run(() => api.search(keyword), replaceResult: true);
  }

  void selectIndex(int index) {
    if (index < 0 || index >= items.length || index == _selectedIndex) {
      return;
    }
    _selectedIndex = index;
    notifyListeners();
    unawaited(_maybeLoadMore());
  }

  bool canToggleMark(QqMusicItem item) {
    // Song/singer dislike controls were removed from list tiles.
    return item.type == QqMusicItemType.playlist;
  }

  bool isMarked(QqMusicItem item) {
    final key = _itemKey(item);
    if (item.type == QqMusicItemType.playlist) {
      final suppliedAsFavorite =
          _entry?.feature == QqMusicFeature.collectedPlaylists;
      return _favoritePlaylistIds.contains(key) ||
          (suppliedAsFavorite && !_unfavoritePlaylistIds.contains(key));
    }
    final suppliedAsDisliked = _entry?.feature == QqMusicFeature.dislikes;
    return _dislikedItemIds.contains(key) ||
        (suppliedAsDisliked && !_undislikedItemIds.contains(key));
  }

  Future<void> toggleMark(QqMusicItem item) async {
    if (!canToggleMark(item)) {
      return;
    }
    final marked = isMarked(item);
    final key = _itemKey(item);
    await _runAction(() async {
      if (item.type == QqMusicItemType.playlist) {
        await api.setPlaylistFavorite(item.id, favorite: !marked);
        if (marked) {
          _favoritePlaylistIds.remove(key);
          _unfavoritePlaylistIds.add(key);
          _setStatusMessage('已取消收藏歌单');
        } else {
          _unfavoritePlaylistIds.remove(key);
          _favoritePlaylistIds.add(key);
          _setStatusMessage('已收藏歌单');
        }
      } else {
        await api.setDislike(item, disliked: !marked);
        if (marked) {
          _dislikedItemIds.remove(key);
          _undislikedItemIds.add(key);
          _setStatusMessage('已从不喜欢中移除');
        } else {
          _undislikedItemIds.remove(key);
          _dislikedItemIds.add(key);
          _setStatusMessage('已加入不喜欢');
        }
      }
    });
  }

  bool get isCreatedPlaylistsRoot =>
      _entry?.feature == QqMusicFeature.createdPlaylists &&
      currentContainer == null;

  bool get isInsideCreatedPlaylist =>
      _entry?.feature == QqMusicFeature.createdPlaylists &&
      currentContainer?.type == QqMusicItemType.playlist;

  Future<void> createPlaylist(String name) async {
    await _runAction(() async {
      final playlist = await api.createPlaylist(name);
      _replaceCurrentItems([...items, playlist]);
      _selectedIndex = items.length - 1;
      _setStatusMessage('已创建歌单「${playlist.title}」');
    });
  }

  Future<void> deleteSelectedPlaylist() async {
    final playlist = selectedItem;
    if (!isCreatedPlaylistsRoot ||
        playlist == null ||
        playlist.type != QqMusicItemType.playlist) {
      return;
    }
    final directoryId = _playlistDirectoryId(playlist);
    await _runAction(() async {
      await api.deletePlaylist(directoryId);
      _childrenCache.remove(_itemKey(playlist));
      _replaceCurrentItems(items.where((item) => item != playlist).toList());
      _selectedIndex = _selectedIndex.clamp(
        0,
        items.isEmpty ? 0 : items.length - 1,
      );
      _setStatusMessage('已删除歌单「${playlist.title}」');
    });
  }

  Future<void> addCurrentSongToSelectedPlaylist() async {
    final playlist = selectedItem;
    final song = currentSong;
    if (!isCreatedPlaylistsRoot ||
        playlist == null ||
        playlist.type != QqMusicItemType.playlist ||
        song == null) {
      return;
    }
    await _runAction(() async {
      await api.addSongsToPlaylist(_playlistDirectoryId(playlist), [song]);
      _childrenCache.remove(_itemKey(playlist));
      _setStatusMessage('已将「${song.title}」加入「${playlist.title}」');
    });
  }

  Future<void> removeSelectedSongFromCurrentPlaylist() async {
    final playlist = currentContainer;
    final song = selectedItem;
    if (!isInsideCreatedPlaylist || playlist == null || song?.isSong != true) {
      return;
    }
    await _runAction(() async {
      await api.removeSongsFromPlaylist(_playlistDirectoryId(playlist), [
        song!,
      ]);
      _replaceCurrentItems(items.where((item) => item != song).toList());
      _selectedIndex = _selectedIndex.clamp(
        0,
        items.isEmpty ? 0 : items.length - 1,
      );
      _setStatusMessage('已从歌单移除「${song.title}」');
    });
  }

  void _replaceCurrentItems(List<QqMusicItem> nextItems) {
    if (_resultPath.isEmpty) {
      return;
    }
    final active = _resultPath.last;
    final updated = QqMusicFeatureResult(
      title: active.title,
      items: List.unmodifiable(nextItems),
      hasMore: active.hasMore,
      message: active.message,
    );
    _resultPath[_resultPath.length - 1] = updated;
    final container = currentContainer;
    if (container != null) {
      _childrenCache[_itemKey(container)] = updated;
    } else {
      final feature = _entry?.feature;
      if (feature != null && feature != QqMusicFeature.search) {
        _featureCache[feature] = updated;
      }
    }
  }

  String _playlistDirectoryId(QqMusicItem playlist) {
    return playlist.directoryId.isEmpty ? playlist.id : playlist.directoryId;
  }

  void stepSelection(int direction) {
    if (items.isEmpty) {
      return;
    }
    if (_entry?.feature == QqMusicFeature.radar) {
      unawaited(_stepRadarSelection(direction));
      return;
    }
    final next = (_selectedIndex + direction).clamp(0, items.length - 1);
    if (next != _selectedIndex) {
      _selectedIndex = next;
      notifyListeners();
      unawaited(_maybeLoadMore());
    } else if (direction > 0) {
      unawaited(_maybeLoadMore());
    }
  }

  Future<void> _stepRadarSelection(int direction) async {
    if (items.isEmpty) {
      return;
    }
    final step = direction >= 0 ? 1 : -1;
    final currentInList = items.indexWhere(
      (item) => _sameSong(item, _currentSong),
    );
    final baseIndex = currentInList >= 0 ? currentInList : _selectedIndex;
    final next = baseIndex + step;
    if (next < 0) {
      return;
    }
    if (next >= items.length) {
      if (step > 0 && await _loadMoreIfPossible()) {
        _selectedIndex = next.clamp(0, items.length - 1);
        notifyListeners();
        await _startRadarPlayback(direction: step);
      }
      return;
    }
    _selectedIndex = next;
    notifyListeners();
    unawaited(_maybeLoadMore());
    await _startRadarPlayback(direction: step);
  }

  Future<void> _maybeLoadMore({bool forceNearEnd = false}) async {
    final active = result;
    final feature = _entry?.feature;
    final container = currentContainer;
    final nearEnd =
        forceNearEnd ||
        _selectedIndex >= items.length - 3 ||
        (feature == QqMusicFeature.radar && _selectedIndex >= items.length - 1);
    if (active == null ||
        !active.hasMore ||
        _loadingMore ||
        !nearEnd ||
        (container == null &&
            (feature == null ||
                feature == QqMusicFeature.search ||
                feature == QqMusicFeature.account))) {
      return;
    }
    final containerKey = container == null ? null : _itemKey(container);
    final nextPage = containerKey == null
        ? (_featurePages[feature] ?? 1) + 1
        : (_childrenPages[containerKey] ?? 1) + 1;
    _loadingMore = true;
    try {
      final loaded = container == null
          ? await api.loadFeature(feature!, page: nextPage)
          : await api.loadChildren(container, page: nextPage);
      if (!identical(result, active) || currentContainer != container) {
        return;
      }
      final merged = <QqMusicItem>[...active.items];
      final seen = <String>{
        for (final item in merged) _paginationItemKey(item),
      };
      final appended = <QqMusicItem>[];
      for (final item in loaded.items) {
        if (!seen.add(_paginationItemKey(item))) {
          continue;
        }
        merged.add(item);
        appended.add(item);
      }
      final updated = QqMusicFeatureResult(
        title: active.title,
        items: List.unmodifiable(merged),
        hasMore: appended.isNotEmpty && loaded.hasMore,
        message: loaded.message,
        updatedAt: DateTime.now().toUtc(),
        isFromCache: false,
      );
      _resultPath[_resultPath.length - 1] = updated;
      _selectedIndex = _selectedIndex.clamp(0, updated.items.length - 1);
      if (containerKey == null) {
        _featurePages[feature!] = nextPage;
        _featureCache[feature] = updated;
      } else {
        _childrenPages[containerKey] = nextPage;
        _childrenCache[containerKey] = updated;
      }
      if (_entry?.feature == QqMusicFeature.radar && appended.isNotEmpty) {
        final songs = updated.items.where((item) => item.isSong).toList();
        if (songs.isNotEmpty) {
          _playbackQueue = List.unmodifiable(songs);
          _schedulePlaybackStateSave(immediate: true);
        }
      }
      notifyListeners();
      if (appended.isNotEmpty) {
        unawaited(_probePlayableUrls(appended));
      }
    } catch (error) {
      _error = _message(error);
      notifyListeners();
    } finally {
      _loadingMore = false;
    }
  }

  Future<bool> activateSelected() async {
    final item = selectedItem;
    if (item == null) {
      if (_entry?.feature == QqMusicFeature.account && !api.isLoggedIn) {
        await startQrLogin();
        return true;
      }
      return false;
    }
    if (item.isSong) {
      if (_shouldBlockVipPlayback(item)) {
        _setPlaybackError('该歌曲需要 VIP 会员才能播放');
        notifyListeners();
        return false;
      }
      if (item.isCopyrightRestricted) {
        _setPlaybackError('歌曲暂无版权');
        notifyListeners();
        return false;
      }
      if (isUnavailable(item)) {
        _setPlaybackError(_unavailableSongMessage(item));
        notifyListeners();
        return false;
      }
      return play(item);
    }
    if (item.hasEmbeddedChildren) {
      final embedded = QqMusicFeatureResult(
        title: item.title,
        items: item.children,
      );
      final cacheKey = _itemKey(item);
      _childrenCache[cacheKey] = embedded;
      _resultPath.add(embedded);
      _containerPath.add(item);
      _selectedIndex = _selectionFor(embedded.items);
      notifyListeners();
      return true;
    }
    if (item.type == QqMusicItemType.musicVideo) {
      await _runAction(() async {
        final uri = await api.getMusicVideoUrl(item);
        _lastExternalUri = uri;
        final opened = await _externalUrlLauncher(uri);
        if (!opened) {
          throw const QqMusicApiException('无法打开 MV 播放地址');
        }
        _setStatusMessage('已打开 MV「${item.title}」');
      });
      return true;
    }
    final cacheKey = _itemKey(item);
    final cached = _childrenCache[cacheKey];
    if (cached != null) {
      _resultPath.add(cached);
      _containerPath.add(item);
      _selectedIndex = _selectionFor(cached.items);
      notifyListeners();
      return true;
    }
    await _run(
      () => api.loadChildren(item),
      parent: item,
      cacheChildrenKey: cacheKey,
    );
    _childrenPages[cacheKey] = 1;
    return true;
  }

  void leaveFeature() {
    _clearPlaybackError();
    _stopQrPolling();
  }

  bool back() {
    if (_resultPath.length <= 1) {
      return false;
    }
    _resultPath.removeLast();
    _containerPath.removeLast();
    _selectedIndex = 0;
    _error = '';
    notifyListeners();
    return true;
  }

  Future<bool> playQueueIndex(int index) async {
    if (index < 0 || index >= _playbackQueue.length) {
      return false;
    }
    return play(_playbackQueue[index], preservePlaybackQueue: true);
  }

  bool removeQueueIndex(int index) {
    if (index < 0 || index >= _playbackQueue.length) {
      return false;
    }
    if (index == currentPlaybackQueueIndex) {
      return false;
    }
    final nextQueue = List<QqMusicItem>.from(_playbackQueue);
    final removed = nextQueue.removeAt(index);
    _playbackQueue = List.unmodifiable(nextQueue);
    if (!nextQueue.any((item) => _sameSong(item, removed))) {
      _prefetchedPlayableUrls.remove(_songKey(removed));
    }
    _schedulePlaybackStateSave(immediate: true);
    notifyListeners();
    return true;
  }

  bool clearUpcomingQueue() {
    if (_playbackQueue.isEmpty) {
      return false;
    }
    final currentIndex = currentPlaybackQueueIndex;
    final current = _currentSong;
    final nextQueue = currentIndex >= 0
        ? <QqMusicItem>[_playbackQueue[currentIndex]]
        : current == null
        ? const <QqMusicItem>[]
        : <QqMusicItem>[current];
    if (nextQueue.length == _playbackQueue.length) {
      return false;
    }
    _playbackQueue = List.unmodifiable(nextQueue);
    _prefetchedPlayableUrls.clear();
    _schedulePlaybackStateSave(immediate: true);
    notifyListeners();
    return true;
  }

  Future<bool> play(
    QqMusicItem song, {
    bool preservePlaybackQueue = false,
    List<QqMusicItem>? queue,
  }) async {
    if (_sameSong(song, _currentSong)) {
      _clearPlaybackError();
      if (_currentSongLikedStatus == null) {
        _prepareCurrentSongLikedStatus(song);
      }
      notifyListeners();
      return true;
    }
    if (_shouldBlockVipPlayback(song)) {
      _setPlaybackError('该歌曲需要 VIP 会员才能播放');
      notifyListeners();
      return false;
    }
    if (song.isCopyrightRestricted) {
      _setPlaybackError('歌曲暂无版权');
      notifyListeners();
      return false;
    }
    if (isUnavailable(song)) {
      _setPlaybackError(_unavailableSongMessage(song));
      notifyListeners();
      return false;
    }
    _clearPlaybackError();
    _isLoading = true;
    notifyListeners();
    var loaded = false;
    try {
      final prefetchedUrl = await _takePrefetchedPlayableUrl(song);
      if (prefetchedUrl == null && isUnavailable(song)) {
        throw QqMusicApiException(_unavailableSongMessage(song), code: 104003);
      }
      final url = prefetchedUrl ?? await _getPlayableUrl(song);
      _unavailableSongKeys.remove(_songKey(song));
      await _audioSessionConfigurator();
      _audioSourceReady = false;
      await _loadAudioSourceWithRetry(song, url);
      _audioSourceReady = true;
      _currentSong = song;
      _prepareCurrentSongLikedStatus(song);
      unawaited(_loadLyrics(song));
      unawaited(_loadAudioOutputName());
      if (!preservePlaybackQueue) {
        if (queue != null && queue.isNotEmpty) {
          _playbackQueue = List.unmodifiable(queue);
        } else {
          final sourceSongs = items.where((item) => item.isSong).toList();
          _playbackQueue = sourceSongs.any((item) => _sameSong(item, song))
              ? List.unmodifiable(sourceSongs)
              : List.unmodifiable([song]);
        }
      }
      // Never clobber a good player-reported duration with a zero metadata field
      // (home feed cards often omit interval).
      final playerDuration = _audioHandler?.duration ?? _audioPlayer.duration;
      if (song.duration > Duration.zero) {
        _duration = song.duration;
      } else if (playerDuration != null && playerDuration > Duration.zero) {
        _duration = playerDuration;
        _audioHandler?.updateDuration(playerDuration);
      } else {
        _duration = Duration.zero;
      }
      _position = Duration.zero;
      _publishPlaybackProgress();
      _prefetchAdjacentPlayableUrls(song);
      loaded = true;
      _schedulePlaybackStateSave(immediate: true);
      unawaited(_startPlayback());
    } catch (error) {
      if (_isUnavailablePlaybackError(error)) {
        _markUnavailable(song);
      }
      _setPlaybackError(_playbackFailureMessage(error, song: song));
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    return loaded;
  }

  Future<void> togglePlayback() async {
    if (_currentSong == null) {
      final item = selectedItem;
      if (item?.isSong ?? false) {
        await play(item!);
      }
      return;
    }
    if (!_audioSourceReady) {
      final restored = await _loadRememberedAudioSource();
      if (!restored) {
        return;
      }
    }
    final handler = _audioHandler;
    if (handler != null) {
      if (handler.processingState == ProcessingState.completed) {
        await handler.seek(Duration.zero);
        unawaited(_startPlayback());
      } else if (handler.playing) {
        _playbackRequested = false;
        await handler.pause();
      } else {
        unawaited(_startPlayback());
      }
    } else if (_audioPlayer.processingState == ProcessingState.completed) {
      await _audioPlayer.seek(Duration.zero);
      unawaited(_startPlayback());
    } else if (_audioPlayer.playing) {
      _playbackRequested = false;
      await _audioPlayer.pause();
    } else {
      unawaited(_startPlayback());
    }
  }

  void clearRemotePlayback() {
    final handler = _audioHandler;
    unawaited(handler?.stop() ?? _audioPlayer.stop());
    _currentSong = null;
    _playbackQueue = const [];
    _audioSourceReady = false;
    _lyrics = null;
    _currentSongFromLiked = false;
    _currentSongLikedStatus = null;
    _likedStatusRevision++;
    _position = Duration.zero;
    _duration = Duration.zero;
    _publishPlaybackProgress();
    _isPlaying = false;
    _playbackRequested = false;
    _isBuffering = false;
    _error = '';
    _clearPlaybackError();
    _clearPersistedPlaybackState();
    notifyListeners();
  }

  Future<void> playAdjacent(int direction) async {
    if (_playbackMode == QqMusicPlaybackMode.shuffle) {
      await _playRandomSong();
      return;
    }
    if (_switchingTrack) {
      return;
    }
    _switchingTrack = true;
    try {
      final activeItems = _playbackQueue.isNotEmpty
          ? _playbackQueue
          : items.where((item) => item.isSong).toList();
      if (activeItems.isEmpty) {
        return;
      }
      var currentIndex = activeItems.indexWhere(
        (item) => _sameSong(item, _currentSong),
      );
      if (currentIndex < 0) {
        final selected = selectedItem;
        currentIndex = activeItems.indexWhere(
          (item) => _sameSong(item, selected),
        );
      }
      while (true) {
        final next = _adjacentPlayableIndex(
          activeItems,
          currentIndex,
          direction,
        );
        if (next == null) {
          return;
        }
        final nextSong = activeItems[next];
        final switched = await play(nextSong, preservePlaybackQueue: true);
        if (switched) {
          final visibleIndex = items.indexWhere(
            (item) => _sameSong(item, nextSong),
          );
          if (visibleIndex >= 0) {
            _selectedIndex = visibleIndex;
          }
          return;
        }
        // Keep walking past VIP / unplayable songs instead of stopping.
        if (!_shouldAutoSkipFailedSong(nextSong)) {
          return;
        }
        currentIndex = next;
      }
    } finally {
      _switchingTrack = false;
    }
  }

  int? _adjacentPlayableIndex(
    List<QqMusicItem> activeItems,
    int currentIndex,
    int direction,
  ) {
    var next = currentIndex + direction;
    while (next >= 0 && next < activeItems.length) {
      final candidate = activeItems[next];
      final canPlay =
          !candidate.isCopyrightRestricted &&
          !isUnavailable(candidate) &&
          !_shouldBlockVipPlayback(candidate);
      if (canPlay) {
        return next;
      }
      next += direction;
    }
    return null;
  }

  void _prefetchAdjacentPlayableUrls(QqMusicItem song) {
    final currentIndex = _playbackQueue.indexWhere(
      (item) => _sameSong(item, song),
    );
    if (currentIndex < 0) {
      return;
    }
    for (final direction in const [-1, 1]) {
      final index = _adjacentPlayableIndex(
        _playbackQueue,
        currentIndex,
        direction,
      );
      if (index == null) {
        continue;
      }
      final candidate = _playbackQueue[index];
      final key = _songKey(candidate);
      final existing = _prefetchedPlayableUrls[key];
      if (existing != null && _isPrefetchedPlayableUrlFresh(existing)) {
        continue;
      }
      _prefetchedPlayableUrls[key] = _PrefetchedPlayableUrl(
        future: _tryGetPlayableUrl(candidate),
        createdAt: _clock(),
      );
    }
  }

  bool _isPrefetchedPlayableUrlFresh(_PrefetchedPlayableUrl entry) {
    final age = _clock().difference(entry.createdAt);
    return !age.isNegative && age <= prefetchedPlayableUrlMaxAge;
  }

  Future<Uri?> _takePrefetchedPlayableUrl(QqMusicItem song) async {
    final entry = _prefetchedPlayableUrls.remove(_songKey(song));
    if (entry == null || !_isPrefetchedPlayableUrlFresh(entry)) {
      return null;
    }
    return entry.future;
  }

  Future<void> _loadAudioSourceWithRetry(
    QqMusicItem song,
    Uri initialUrl,
  ) async {
    _loadingAudioSource = true;
    try {
      try {
        await _audioSourceLoader(song, initialUrl);
      } catch (error) {
        if (!_isSourcePlaybackError(error)) {
          rethrow;
        }
        final refreshedUrl = await _getPlayableUrl(song);
        _unavailableSongKeys.remove(_songKey(song));
        await _audioSourceLoader(song, refreshedUrl);
      }
    } finally {
      _loadingAudioSource = false;
    }
  }

  bool _isSourcePlaybackError(Object error) =>
      error is PlayerException && error.code == 0;

  void _handlePlayerError(PlayerException error) {
    if (_loadingAudioSource || _recoveringSourceError) {
      return;
    }
    if (!_isSourcePlaybackError(error)) {
      _setPlaybackError(_message(error));
      notifyListeners();
      return;
    }
    final song = _currentSong;
    if (song == null) {
      _setPlaybackError(_message(error));
      notifyListeners();
      return;
    }
    final position = _position;
    final shouldResume = _playbackRequested;
    unawaited(_recoverFromSourceError(song, position, shouldResume));
  }

  Future<void> _recoverFromSourceError(
    QqMusicItem song,
    Duration position,
    bool shouldResume,
  ) async {
    if (_recoveringSourceError) {
      return;
    }
    _recoveringSourceError = true;
    _isBuffering = true;
    _clearPlaybackError();
    _prefetchedPlayableUrls.remove(_songKey(song));
    notifyListeners();
    try {
      final refreshedUrl = await _getPlayableUrl(song);
      if (!_sameSong(song, _currentSong)) {
        return;
      }
      _loadingAudioSource = true;
      try {
        await _audioSourceLoader(song, refreshedUrl);
      } finally {
        _loadingAudioSource = false;
      }
      if (!_sameSong(song, _currentSong)) {
        return;
      }
      _unavailableSongKeys.remove(_songKey(song));
      if (position > Duration.zero) {
        await _seekTo(position);
      }
      if (shouldResume) {
        unawaited(_startPlayback());
      }
    } catch (error) {
      if (_sameSong(song, _currentSong)) {
        if (_isUnavailablePlaybackError(error)) {
          _markUnavailable(song);
        }
        _setPlaybackError(_playbackFailureMessage(error, song: song));
      }
    } finally {
      _loadingAudioSource = false;
      _recoveringSourceError = false;
      _isBuffering = false;
      notifyListeners();
    }
  }

  Future<void> _startPlayback() async {
    if (!_audioSourceReady && !await _loadRememberedAudioSource()) {
      return;
    }
    _playbackRequested = true;
    try {
      await _audioPlaybackStarter();
    } catch (error) {
      if (error is PlayerException) {
        _handlePlayerError(error);
      } else {
        _setPlaybackError(_message(error));
        notifyListeners();
      }
    }
  }

  Future<void> _seekTo(Duration position) => _audioSeeker(position);

  Future<Uri> _getPlayableUrl(QqMusicItem song) async {
    try {
      return await api.getPlayableUrl(song, fileType: _playbackFileType);
    } catch (_) {
      if (_playbackFileType == 13) {
        rethrow;
      }
      return api.getPlayableUrl(song);
    }
  }

  Future<Uri?> _tryGetPlayableUrl(QqMusicItem song) async {
    try {
      final url = await _getPlayableUrl(song);
      _unavailableSongKeys.remove(_songKey(song));
      return url;
    } catch (_) {
      return null;
    }
  }

  void _markUnavailable(QqMusicItem song) {
    if (_unavailableSongKeys.add(_songKey(song))) {
      notifyListeners();
    }
  }

  /// Prefer specific reasons when a probe already marked the song unplayable.
  String _unavailableSongMessage(QqMusicItem song) {
    if (song.requiresVip) {
      return '该歌曲需要 VIP 会员才能播放';
    }
    if (song.isCopyrightRestricted) {
      return '歌曲暂无版权';
    }
    if (!api.isLoggedIn) {
      return '当前未登录，该歌曲暂无游客播放地址';
    }
    return '歌曲没有可用播放地址，可能需要会员或存在版权限制';
  }

  bool _isUnavailablePlaybackError(Object error) {
    if (error is! QqMusicApiException) {
      return false;
    }
    // Guest failures are often temporary (login may unlock the song).
    // Only mark "无音源" after a confirmed logged-in probe/play path.
    if (!api.isLoggedIn) {
      return false;
    }
    // Session expiry is temporary; user can re-login.
    if (error.isUnauthorized) {
      return false;
    }
    if (error.code == 104003) {
      return true;
    }
    final message = error.message;
    return message.contains('没有可用播放地址') ||
        message.contains('缺少 MID') ||
        message.contains('暂无版权') ||
        message.contains('VIP 会员') ||
        message.contains('版权限制');
  }

  /// Map API / playback failures to distinct user-facing copy.
  String _playbackFailureMessage(Object error, {QqMusicItem? song}) {
    if (error is QqMusicApiException) {
      // Only treat auth codes as "session expired" when we actually had a login.
      // Guest requests can also get 1000/104401; that is not a local login bug.
      if (error.isUnauthorized && api.isLoggedIn) {
        return 'QQ 音乐登录已失效，请重新扫码登录';
      }
      if (error.isUnauthorized ||
          error.code == 104003 ||
          error.message.contains('没有可用播放地址') ||
          error.message.contains('游客播放地址')) {
        if (song?.requiresVip == true || error.message.contains('VIP')) {
          return '该歌曲需要 VIP 会员才能播放';
        }
        if (song?.isCopyrightRestricted == true ||
            error.message.contains('暂无版权')) {
          return '歌曲暂无版权';
        }
        if (!api.isLoggedIn) {
          return '当前未登录，该歌曲暂无游客播放地址';
        }
        return '歌曲没有可用播放地址，可能需要会员或存在版权限制';
      }
      // Keep specific API messages (VIP / copyright / login prompts) as-is.
      return error.message;
    }
    return _message(error);
  }

  Future<void> _handlePlaybackCompleted() async {
    if (_handlingPlaybackCompletion) {
      return;
    }
    _handlingPlaybackCompletion = true;
    try {
      if (_playbackMode == QqMusicPlaybackMode.repeatOne) {
        final handler = _audioHandler;
        if (handler != null) {
          await handler.seek(Duration.zero);
          unawaited(_startPlayback());
        } else {
          await _audioPlayer.seek(Duration.zero);
          unawaited(_startPlayback());
        }
      } else if (_playbackMode == QqMusicPlaybackMode.shuffle) {
        await _playRandomSong();
      } else {
        await playAdjacent(1);
      }
    } finally {
      _handlingPlaybackCompletion = false;
    }
  }

  Future<void> _playRandomSong() async {
    if (_switchingTrack) {
      return;
    }
    _switchingTrack = true;
    try {
      final candidates = _playbackQueue
          .where(
            (song) =>
                !_sameSong(song, _currentSong) &&
                !song.isCopyrightRestricted &&
                !isUnavailable(song) &&
                !_shouldBlockVipPlayback(song),
          )
          .toList(growable: false);
      if (candidates.isEmpty) {
        return;
      }
      await play(
        candidates[Random().nextInt(candidates.length)],
        preservePlaybackQueue: true,
      );
    } finally {
      _switchingTrack = false;
    }
  }

  void cyclePlaybackMode() {
    _playbackMode = switch (_playbackMode) {
      QqMusicPlaybackMode.sequential => QqMusicPlaybackMode.repeatOne,
      QqMusicPlaybackMode.repeatOne => QqMusicPlaybackMode.shuffle,
      QqMusicPlaybackMode.shuffle => QqMusicPlaybackMode.sequential,
    };
    _schedulePlaybackStateSave(immediate: true);
    notifyListeners();
  }

  Future<void> toggleCurrentSongLiked() async {
    final song = _currentSong;
    if (!api.isLoggedIn || song == null || _isLoading) {
      return;
    }
    final wasLiked = isCurrentSongLiked;
    final previous = _featureCache[QqMusicFeature.likedSongs];
    // Prefer 我喜欢 row for songId when present; songType for songs is always
    // entity kind 1 (1=歌曲 / 2=歌手 / 3=风格) — not track media Song.type.
    var apiSong = song;
    if (wasLiked) {
      for (final item in previous?.items ?? const <QqMusicItem>[]) {
        if (_sameSong(item, song)) {
          apiSong = item;
          break;
        }
      }
    }
    _setSongLikedInMemory(song, !wasLiked);
    _setStatusMessage(wasLiked ? '已取消喜欢' : '已添加到我喜欢');
    _error = '';
    _isLoading = true;
    notifyListeners();
    try {
      await api.setSongLiked(apiSong, liked: !wasLiked);
    } catch (error) {
      if (previous == null) {
        _featureCache.remove(QqMusicFeature.likedSongs);
      } else {
        _featureCache[QqMusicFeature.likedSongs] = previous;
        if (_entry?.feature == QqMusicFeature.likedSongs &&
            currentContainer == null) {
          _setRootResult(previous);
        }
      }
      _likedStatusCache[_songKey(song)] = wasLiked;
      if (_sameSong(song, _currentSong)) {
        _likedStatusRevision++;
        _currentSongLikedStatus = wasLiked;
        _currentSongFromLiked = wasLiked;
      }
      _clearStatusMessage(scheduleDismiss: false);
      _error = _message(error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _setSongLikedInMemory(QqMusicItem song, bool liked) {
    final previous = _featureCache[QqMusicFeature.likedSongs];
    final items = previous?.items ?? const <QqMusicItem>[];
    final contains = items.any((item) => _sameSong(item, song));
    final updatedItems = liked
        ? (contains ? items : [song, ...items])
        : items.where((item) => !_sameSong(item, song)).toList();
    _featureCache[QqMusicFeature.likedSongs] = QqMusicFeatureResult(
      title: previous?.title ?? '我喜欢的音乐',
      items: List.unmodifiable(updatedItems),
      hasMore: previous?.hasMore ?? true,
      message: previous?.message ?? '',
    );
    _likedStatusRevision++;
    _likedStatusCache[_songKey(song)] = liked;
    _currentSongLikedStatus = liked;
    _currentSongFromLiked = liked;
    if (_entry?.feature == QqMusicFeature.likedSongs &&
        currentContainer == null) {
      _setRootResult(_featureCache[QqMusicFeature.likedSongs]!);
    }
  }

  void _prepareCurrentSongLikedStatus(QqMusicItem song) {
    final revision = ++_likedStatusRevision;
    if (!api.isLoggedIn) {
      _currentSongLikedStatus = false;
      _currentSongFromLiked = false;
      return;
    }
    final key = _songKey(song);
    final cached = _likedStatusCache[key] ?? _likedStatusFromFeatureCache(song);
    _currentSongLikedStatus = cached;
    _currentSongFromLiked = cached == true;
    if (cached == null) {
      unawaited(_querySongLikedStatus(song, revision));
    }
  }

  Future<void> refreshCurrentSongLikedStatus() async {
    final song = _currentSong;
    if (!api.isLoggedIn || song == null) {
      return;
    }
    final revision = ++_likedStatusRevision;
    await _querySongLikedStatus(song, revision);
  }

  Future<void> _querySongLikedStatus(QqMusicItem song, int revision) async {
    const pageSize = 100;
    const maxPages = 100;
    try {
      for (var page = 1; page <= maxPages; page++) {
        final result = await api.loadFeature(
          QqMusicFeature.likedSongs,
          page: page,
          pageSize: pageSize,
          forceRefresh: page == 1,
        );
        if (revision != _likedStatusRevision ||
            !_sameSong(song, _currentSong)) {
          return;
        }
        if (result.items.any((item) => _sameSong(item, song))) {
          _applyCurrentSongLikedStatus(song, revision, true);
          return;
        }
        if (!result.hasMore) {
          _applyCurrentSongLikedStatus(song, revision, false);
          return;
        }
      }
    } catch (_) {}
  }

  void _applyCurrentSongLikedStatus(
    QqMusicItem song,
    int revision,
    bool liked,
  ) {
    if (revision != _likedStatusRevision || !_sameSong(song, _currentSong)) {
      return;
    }
    _likedStatusCache[_songKey(song)] = liked;
    _currentSongLikedStatus = liked;
    _currentSongFromLiked = liked;
    notifyListeners();
  }

  Future<void> _loadLyrics(QqMusicItem song) async {
    final key = _songKey(song);
    final cached = _lyricsCache[key];
    if (cached != null) {
      _lyrics = cached;
      notifyListeners();
      return;
    }
    _isLoadingLyrics = true;
    _lyrics = null;
    notifyListeners();
    try {
      final loaded = await api.getLyrics(song);
      if (!_sameSong(song, _currentSong)) {
        return;
      }
      _lyricsCache[key] = loaded;
      _lyrics = loaded;
    } catch (_) {
      if (_sameSong(song, _currentSong)) {
        _lyrics = const QqMusicLyrics(lines: []);
      }
    } finally {
      if (_sameSong(song, _currentSong)) {
        _isLoadingLyrics = false;
        notifyListeners();
      }
    }
  }

  Future<void> _loadAudioOutputName() async {
    final name = await _audioOutputNameLoader();
    if (name.isEmpty || name == _audioOutputName) {
      return;
    }
    _audioOutputName = name;
    notifyListeners();
  }

  Future<void> seekToProgress(
    double value, {
    bool avoidPlaybackCompletion = false,
  }) async {
    final handler = _audioHandler;
    final activeDuration =
        handler?.duration ?? _audioPlayer.duration ?? _duration;
    if (activeDuration.inMilliseconds <= 0) {
      return;
    }
    var targetMilliseconds = (activeDuration.inMilliseconds * value.clamp(0, 1))
        .round();
    if (avoidPlaybackCompletion &&
        activeDuration > const Duration(seconds: 1)) {
      targetMilliseconds = min(
        targetMilliseconds,
        activeDuration.inMilliseconds - 500,
      );
    }
    await _seekTo(Duration(milliseconds: targetMilliseconds));
  }

  Future<void> startQrLogin({String loginType = 'qq'}) async {
    _stopQrPolling();
    _qrLoginType = loginType;
    _error = '';
    _clearStatusMessage(scheduleDismiss: false);
    _qrCode = null;
    _qrStatus = null;
    _isLoading = true;
    notifyListeners();
    try {
      _qrCode = await api.createQrCode(loginType: loginType);
      _qrStatus = QqMusicQrStatus(
        event: 1,
        done: false,
        identifier: _qrCode!.identifier,
        loginType: _qrCode!.loginType,
      );
      _startQrPolling();
    } catch (error) {
      _error = _message(error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Call when the app returns to foreground so QR login can finish after scan.
  void onAppResumed() {
    final activeQr = _qrCode;
    if (activeQr == null || api.isLoggedIn) {
      return;
    }
    final status = _qrStatus;
    if (status != null &&
        (status.done ||
            status.event == 3 ||
            status.event == 4 ||
            status.event == -1)) {
      return;
    }
    // Leaving the app (to scan in QQ) often produces a one-shot DNS failure;
    // recover the login UI and keep polling instead of stranding on _error.
    var changed = false;
    if (_error.isNotEmpty && _isTransientQrNetworkError(_error)) {
      _error = '';
      changed = true;
    }
    if (_statusMessage.contains('网络暂时') ||
        _statusMessage.contains('Failed host lookup') ||
        _statusMessage.contains('failed host lookup')) {
      // Sticky QR-login hint — do not auto-dismiss until next poll success.
      _statusClearTimer?.cancel();
      _statusMessage = '已回到应用，正在继续检测登录…';
      changed = true;
    }
    if (_qrPollTimer == null) {
      _startQrPolling();
    }
    if (changed) {
      notifyListeners();
    }
    unawaited(_pollQr());
  }

  Future<void> logout() async {
    _stopQrPolling();
    await api.logout();
    _featureCache.clear();
    _featurePages.clear();
    _childrenPages.clear();
    _childrenCache.clear();
    _prefetchedPlayableUrls.clear();
    _likedStatusCache.clear();
    _likedStatusRevision++;
    _currentSongLikedStatus = false;
    _currentSongFromLiked = false;
    _unavailableSongKeys.clear();
    _profile = null;
    _qrCode = null;
    _qrStatus = null;
    notifyListeners();
    await startQrLogin();
  }

  Future<void> _loadProfile() async {
    _isLoading = true;
    _error = '';
    notifyListeners();
    try {
      final loaded = await api.getUserProfile();
      final previousVip = _profile?.isVip;
      _profile = loaded.isVip == null && previousVip == true
          ? QqMusicUserProfile(
              id: loaded.id,
              nickname: loaded.nickname,
              avatarUrl: loaded.avatarUrl,
              isVip: true,
            )
          : loaded;
      if (_profile?.isVip == true && previousVip != true) {
        _unavailableSongKeys.clear();
      }
    } catch (error) {
      _error = _message(error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _run(
    Future<QqMusicFeatureResult> Function() operation, {
    bool replaceResult = false,
    QqMusicItem? parent,
    QqMusicFeature? cacheFeature,
    String? cacheChildrenKey,
    bool updateVisibleResult = true,
  }) async {
    _isLoading = true;
    _error = '';
    _clearStatusMessage(scheduleDismiss: false);
    notifyListeners();
    try {
      final response = await operation();
      final loaded = response.updatedAt == null
          ? response.withMetadata(
              updatedAt: DateTime.now().toUtc(),
              isFromCache: false,
            )
          : response;
      if (cacheFeature != null) {
        _featureCache[cacheFeature] = loaded;
      }
      if (cacheChildrenKey != null) {
        _childrenCache[cacheChildrenKey] = loaded;
      }
      if (updateVisibleResult) {
        if (replaceResult) {
          _setRootResult(loaded);
        } else {
          _resultPath.add(loaded);
          _containerPath.add(parent);
          _selectedIndex = _selectionFor(loaded.items);
        }
      }
      notifyListeners();
      if (cacheFeature != QqMusicFeature.guessRecommendations) {
        unawaited(_probePlayableUrls(loaded.items));
      }
    } catch (error) {
      _error = _message(error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _setRootResult(QqMusicFeatureResult loaded) {
    _resultPath
      ..clear()
      ..add(loaded);
    _containerPath
      ..clear()
      ..add(null);
    _selectedIndex = _selectionFor(loaded.items);
  }

  int _selectionFor(List<QqMusicItem> loadedItems) {
    final currentIndex = loadedItems.indexWhere(isCurrentSong);
    return currentIndex < 0 ? 0 : currentIndex;
  }

  Future<void> _probePlayableUrls(List<QqMusicItem> loadedItems) async {
    if (!api.isLoggedIn) {
      return;
    }
    final candidates = loadedItems
        .where(
          (item) =>
              item.isSong &&
              item.mid.isNotEmpty &&
              !item.requiresVip &&
              !item.isCopyrightRestricted &&
              !_shouldBlockVipPlayback(item),
        )
        .toList(growable: false);
    var changed = false;
    for (var start = 0; start < candidates.length; start += 50) {
      final end = (start + 50).clamp(0, candidates.length);
      final batch = candidates.sublist(start, end);
      try {
        final urls = await api.getPlayableUrls(batch);
        for (final song in batch) {
          final key = _songKey(song);
          if (!urls.containsKey(song.mid)) {
            continue;
          }
          if (urls[song.mid] == null) {
            changed = _unavailableSongKeys.add(key) || changed;
          } else {
            changed = _unavailableSongKeys.remove(key) || changed;
          }
        }
      } catch (_) {}
    }
    if (changed) {
      notifyListeners();
    }
  }

  Future<void> _runAction(Future<void> Function() operation) async {
    _isLoading = true;
    _error = '';
    _clearStatusMessage(scheduleDismiss: false);
    notifyListeners();
    try {
      await operation();
      _scheduleStatusDismiss();
    } catch (error) {
      _error = _message(error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _setStatusMessage(String message) {
    _statusClearTimer?.cancel();
    _statusMessage = message;
    if (message.isNotEmpty) {
      _scheduleStatusDismiss();
    }
  }

  void _clearStatusMessage({bool scheduleDismiss = true}) {
    _statusClearTimer?.cancel();
    _statusClearTimer = null;
    _statusMessage = '';
  }

  void _scheduleStatusDismiss() {
    _statusClearTimer?.cancel();
    if (_statusMessage.isEmpty) {
      return;
    }
    _statusClearTimer = Timer(_statusMessageTtl, () {
      if (_statusMessage.isEmpty) {
        return;
      }
      _statusMessage = '';
      notifyListeners();
    });
  }

  void _setPlaybackError(String message) {
    _playbackErrorClearTimer?.cancel();
    _playbackError = message;
    if (message.isNotEmpty) {
      _playbackErrorClearTimer = Timer(_playbackErrorTtl, () {
        if (_playbackError.isEmpty) {
          return;
        }
        _clearPlaybackError();
        notifyListeners();
      });
    }
  }

  void _clearPlaybackError() {
    _playbackErrorClearTimer?.cancel();
    _playbackErrorClearTimer = null;
    _playbackError = '';
  }

  Future<void> _configureAudioSession() async {
    // Session is configured once in main() (Bloomee-style). Only re-activate.
    final session = await AudioSession.instance;
    await session.setActive(true);
  }

  void _startQrPolling() {
    _qrPollTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => unawaited(_pollQr()),
    );
  }

  Future<void> _pollQr() async {
    final activeQr = _qrCode;
    if (activeQr == null || _pollingQr) {
      return;
    }
    _pollingQr = true;
    try {
      final status = await api.checkQrStatus(activeQr);
      _qrStatus = status;
      // A successful poll means the login network is fine again.
      if (_error.isNotEmpty && _isTransientQrNetworkError(_error)) {
        _error = '';
      }
      if (_statusMessage.contains('网络暂时') || _statusMessage.contains('已回到应用')) {
        _clearStatusMessage(scheduleDismiss: false);
      }
      if (status.done && api.isLoggedIn) {
        _stopQrPolling();
        await _loadProfile();
        await _prefetchCoverFlowSources();
        final song = _currentSong;
        if (song != null) {
          _prepareCurrentSongLikedStatus(song);
        }
      } else if (status.event == 3 || status.event == 4 || status.event == -1) {
        _stopQrPolling();
      }
    } catch (error) {
      final message = _message(error);
      if (_isTransientQrNetworkError(message)) {
        // Background / app-switch DNS blips are expected while the user is in QQ.
        // Keep the QR session and timer; do not push a fatal error that replaces
        // the login UI. Sticky until a successful poll.
        _statusClearTimer?.cancel();
        _statusMessage = '网络暂时不可用，返回应用后将自动继续检测登录';
      } else {
        _error = message;
        _stopQrPolling();
      }
    } finally {
      _pollingQr = false;
      notifyListeners();
    }
  }

  void _stopQrPolling() {
    _qrPollTimer?.cancel();
    _qrPollTimer = null;
  }

  bool _isTransientQrNetworkError(Object error) {
    final message = error is String ? error : _message(error);
    final lower = message.toLowerCase();
    return lower.contains('failed host lookup') ||
        lower.contains('socketexception') ||
        lower.contains('connection refused') ||
        lower.contains('connection reset') ||
        lower.contains('connection closed') ||
        lower.contains('network is unreachable') ||
        lower.contains('software caused connection abort') ||
        lower.contains('timed out') ||
        lower.contains('timeout') ||
        message.contains('无法连接 QQ 音乐登录服务') ||
        message.contains('无法连接 QQ 音乐');
  }

  bool _shouldBlockVipPlayback(QqMusicItem song) =>
      song.requiresVip && _profile?.isVip == false;

  String _songKey(QqMusicItem item) => item.mid.isEmpty ? item.id : item.mid;

  bool _sameSong(QqMusicItem item, QqMusicItem? other) {
    if (other == null || !item.isSong || !other.isSong) {
      return false;
    }
    if (item.mid.isNotEmpty && other.mid.isNotEmpty) {
      return item.mid == other.mid;
    }
    return item.id == other.id;
  }

  String _itemKey(QqMusicItem item) {
    final identity = item.id.isNotEmpty && item.id != '0'
        ? item.id
        : item.directoryId.isNotEmpty
        ? item.directoryId
        : item.mid.isNotEmpty
        ? item.mid
        : '${item.title}:${item.subtitle}';
    return '${item.type.name}:$identity';
  }

  String _paginationItemKey(QqMusicItem item) {
    final identity = item.mid.isNotEmpty
        ? item.mid
        : item.id.isNotEmpty
        ? item.id
        : item.directoryId.isNotEmpty
        ? item.directoryId
        : '${item.title}:${item.subtitle}';
    return '${item.type.name}:$identity';
  }

  String _message(Object error) {
    if (error is QqMusicApiException) {
      return error.message;
    }
    if (_isSourcePlaybackError(error)) {
      return '播放源暂时不可用，请检查网络后重试';
    }
    return error.toString().replaceFirst('Exception: ', '');
  }

  @override
  void dispose() {
    _statusClearTimer?.cancel();
    _playbackErrorClearTimer?.cancel();
    _playbackStateSaveTimer?.cancel();
    if (_currentSong != null) {
      unawaited(_savePlaybackState());
    }
    _stopQrPolling();
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    if (_ownsAudioPlayer) {
      unawaited(_audioPlayer.dispose());
    }
    playbackProgress.dispose();
    api.dispose();
    super.dispose();
  }
}
