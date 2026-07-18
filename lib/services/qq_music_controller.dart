import 'dart:async';
import 'dart:math';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:url_launcher/url_launcher.dart';

import '../ipod_models.dart';
import 'audio_output_service.dart';
import 'qq_music_api.dart';
import 'qq_music_audio_handler.dart';
import 'qq_music_models.dart';

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
    this.prefetchedPlayableUrlMaxAge = const Duration(minutes: 5),
  }) : _clock = clock ?? DateTime.now,
       _audioHandler = audioHandler,
       _audioPlayer = audioPlayer ?? audioHandler?.player ?? AudioPlayer(),
       _ownsAudioPlayer = audioPlayer == null && audioHandler == null,
       _externalUrlLauncher =
           externalUrlLauncher ??
           ((uri) => launchUrl(uri, mode: LaunchMode.externalApplication)) {
    _currentSong = _audioHandler?.currentSong;
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
      }),
    );
    _subscriptions.add(
      (positionStream ?? _audioPlayer.positionStream).listen((position) {
        _position = position;
        _publishPlaybackProgress();
      }),
    );
    _subscriptions.add(
      (durationStream ?? _audioPlayer.durationStream).listen((duration) {
        _duration = duration ?? _currentSong?.duration ?? Duration.zero;
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
  final Future<bool> Function(Uri uri) _externalUrlLauncher;
  late final Future<void> Function(QqMusicItem song, Uri uri)
  _audioSourceLoader;
  late final Future<void> Function() _audioPlaybackStarter;
  late final Future<void> Function(Duration position) _audioSeeker;
  late final Future<void> Function() _audioSessionConfigurator;
  late final Future<String> Function() _audioOutputNameLoader;
  final List<StreamSubscription<Object?>> _subscriptions = [];
  final ValueNotifier<QqMusicPlaybackProgress> playbackProgress = ValueNotifier(
    const QqMusicPlaybackProgress(),
  );
  final List<QqMusicFeatureResult> _resultPath = [];
  final List<QqMusicItem?> _containerPath = [];
  final Map<QqMusicFeature, QqMusicFeatureResult> _featureCache = {};
  final Map<QqMusicFeature, int> _featurePages = {};
  final Map<String, QqMusicFeatureResult> _childrenCache = {};
  final Map<String, _PrefetchedPlayableUrl> _prefetchedPlayableUrls = {};
  final Map<String, QqMusicLyrics> _lyricsCache = {};
  final Set<String> _unavailableSongKeys = {};
  List<QqMusicItem> _playbackQueue = const [];
  final Set<String> _favoritePlaylistIds = {};
  final Set<String> _unfavoritePlaylistIds = {};
  final Set<String> _dislikedItemIds = {};
  final Set<String> _undislikedItemIds = {};

  Timer? _qrPollTimer;
  bool _audioSessionConfigured = false;
  bool _pollingQr = false;
  bool _handlingPlaybackCompletion = false;
  bool _switchingTrack = false;
  bool _loadingAudioSource = false;
  bool _recoveringSourceError = false;
  bool _playbackRequested = false;
  ProcessingState _lastProcessingState = ProcessingState.idle;
  bool _isLoading = false;
  bool _isPlaying = false;
  bool _isBuffering = false;
  bool _isLoadingLyrics = false;
  bool _currentSongFromLiked = false;
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
  String _audioOutputName = '';
  Uri? _lastExternalUri;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

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
  QqMusicLyrics? get lyrics => _lyrics;
  bool get isLoadingLyrics => _isLoadingLyrics;
  QqMusicPlaybackMode get playbackMode => _playbackMode;
  String get audioOutputName => _audioOutputName;
  bool get isCurrentSongLiked {
    final song = _currentSong;
    if (song == null) {
      return false;
    }
    final liked = _featureCache[QqMusicFeature.likedSongs];
    if (liked != null) {
      return liked.items.any((item) => _sameSong(item, song));
    }
    return _currentSongFromLiked;
  }

  Uri? get lastExternalUri => _lastExternalUri;
  Duration get position => _position;
  Duration get duration => _duration;
  double get progress => playbackProgress.value.value;

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
    return item.isSong && _unavailableSongKeys.contains(_songKey(item));
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
    notifyListeners();
  }

  Future<void> _prefetchCoverFlowSources() async {
    await _run(
      () => api.loadFeature(QqMusicFeature.likedSongs),
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
    _playbackError = '';
    _statusMessage = '';
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
        return;
      }
      await _run(
        () => api.loadFeature(feature),
        replaceResult: true,
        cacheFeature: feature,
      );
      _featurePages[feature] = 1;
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
    }
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
    if (_entry?.feature == QqMusicFeature.radar) {
      unawaited(_maybeLoadMoreRadar());
    }
  }

  bool canToggleMark(QqMusicItem item) {
    return item.type == QqMusicItemType.playlist ||
        item.type == QqMusicItemType.song ||
        (item.type == QqMusicItemType.singer && int.tryParse(item.id) != null);
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
          _statusMessage = '已取消收藏歌单';
        } else {
          _unfavoritePlaylistIds.remove(key);
          _favoritePlaylistIds.add(key);
          _statusMessage = '已收藏歌单';
        }
      } else {
        await api.setDislike(item, disliked: !marked);
        if (marked) {
          _dislikedItemIds.remove(key);
          _undislikedItemIds.add(key);
          _statusMessage = '已从不喜欢中移除';
        } else {
          _undislikedItemIds.remove(key);
          _dislikedItemIds.add(key);
          _statusMessage = '已加入不喜欢';
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
      _statusMessage = '已创建歌单「${playlist.title}」';
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
      _statusMessage = '已删除歌单「${playlist.title}」';
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
      _statusMessage = '已将「${song.title}」加入「${playlist.title}」';
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
      _statusMessage = '已从歌单移除「${song.title}」';
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
    final next = (_selectedIndex + direction).clamp(0, items.length - 1);
    if (next != _selectedIndex) {
      _selectedIndex = next;
      notifyListeners();
      if (_entry?.feature == QqMusicFeature.radar) {
        unawaited(_maybeLoadMoreRadar());
      }
    }
  }

  Future<void> _maybeLoadMoreRadar() async {
    final active = result;
    final feature = _entry?.feature;
    if (active == null ||
        feature != QqMusicFeature.radar ||
        !active.hasMore ||
        _isLoading ||
        _selectedIndex < items.length - 3) {
      return;
    }
    final nextPage = (_featurePages[feature] ?? 1) + 1;
    final keepIndex = _selectedIndex;
    try {
      final loaded = await api.loadFeature(
        QqMusicFeature.radar,
        page: nextPage,
      );
      if (loaded.items.isEmpty) {
        _featurePages[feature!] = nextPage;
        final exhausted = QqMusicFeatureResult(
          title: active.title,
          items: active.items,
          hasMore: false,
          message: active.message,
        );
        _resultPath
          ..clear()
          ..add(exhausted);
        _containerPath
          ..clear()
          ..add(null);
        _selectedIndex = keepIndex.clamp(0, exhausted.items.length - 1);
        _featureCache[feature] = exhausted;
        notifyListeners();
        return;
      }
      final merged = <QqMusicItem>[...active.items];
      final seen = <String>{
        for (final item in active.items)
          item.id.isNotEmpty ? item.id : item.mid,
      };
      for (final item in loaded.items) {
        final key = item.id.isNotEmpty ? item.id : item.mid;
        if (key.isEmpty || !seen.add(key)) {
          continue;
        }
        merged.add(item);
      }
      final updated = QqMusicFeatureResult(
        title: active.title,
        items: List.unmodifiable(merged),
        hasMore: loaded.hasMore,
        message: loaded.message,
      );
      _featurePages[feature!] = nextPage;
      _resultPath
        ..clear()
        ..add(updated);
      _containerPath
        ..clear()
        ..add(null);
      _selectedIndex = keepIndex.clamp(0, updated.items.length - 1);
      _featureCache[feature] = updated;
      notifyListeners();
      await _probePlayableUrls(loaded.items);
    } catch (error) {
      _error = _message(error);
      notifyListeners();
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
        _playbackError = '该歌曲需要 VIP 会员才能播放';
        notifyListeners();
        return false;
      }
      if (item.isCopyrightRestricted) {
        _playbackError = '歌曲暂无版权';
        notifyListeners();
        return false;
      }
      if (isUnavailable(item)) {
        _playbackError = '歌曲没有可用播放地址，可能需要会员或存在版权限制';
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
      await _probePlayableUrls(embedded.items);
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
        _statusMessage = '已打开 MV「${item.title}」';
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
    return true;
  }

  void leaveFeature() {
    _playbackError = '';
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

  Future<bool> play(
    QqMusicItem song, {
    bool preservePlaybackQueue = false,
    List<QqMusicItem>? queue,
  }) async {
    if (_sameSong(song, _currentSong)) {
      _playbackError = '';
      notifyListeners();
      return true;
    }
    if (_shouldBlockVipPlayback(song)) {
      _playbackError = '该歌曲需要 VIP 会员才能播放';
      notifyListeners();
      return false;
    }
    if (song.isCopyrightRestricted) {
      _playbackError = '歌曲暂无版权';
      notifyListeners();
      return false;
    }
    if (isUnavailable(song)) {
      _playbackError = '歌曲没有可用播放地址，可能需要会员或存在版权限制';
      notifyListeners();
      return false;
    }
    _playbackError = '';
    _isLoading = true;
    notifyListeners();
    var loaded = false;
    try {
      final prefetchedUrl = await _takePrefetchedPlayableUrl(song);
      if (prefetchedUrl == null && isUnavailable(song)) {
        throw const QqMusicApiException('歌曲没有可用播放地址，可能需要会员或存在版权限制');
      }
      final url = prefetchedUrl ?? await api.getPlayableUrl(song);
      _unavailableSongKeys.remove(_songKey(song));
      await _audioSessionConfigurator();
      await _loadAudioSourceWithRetry(song, url);
      _currentSong = song;
      if (!preservePlaybackQueue) {
        _currentSongFromLiked = _entry?.feature == QqMusicFeature.likedSongs;
      }
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
      _duration = song.duration;
      _position = Duration.zero;
      _publishPlaybackProgress();
      _prefetchAdjacentPlayableUrls(song);
      loaded = true;
      unawaited(_startPlayback());
    } catch (error) {
      if (_isUnavailablePlaybackError(error)) {
        _markUnavailable(song);
        _playbackError = '歌曲没有可用播放地址，可能需要会员或存在版权限制';
      } else {
        _playbackError = _message(error);
      }
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
    _lyrics = null;
    _currentSongFromLiked = false;
    _position = Duration.zero;
    _duration = Duration.zero;
    _publishPlaybackProgress();
    _isPlaying = false;
    _playbackRequested = false;
    _isBuffering = false;
    _error = '';
    _playbackError = '';
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
        if (!isUnavailable(nextSong)) {
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
        final refreshedUrl = await api.getPlayableUrl(song);
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
      _playbackError = _message(error);
      notifyListeners();
      return;
    }
    final song = _currentSong;
    if (song == null) {
      _playbackError = _message(error);
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
    _playbackError = '';
    _prefetchedPlayableUrls.remove(_songKey(song));
    notifyListeners();
    try {
      final refreshedUrl = await api.getPlayableUrl(song);
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
          _playbackError = '歌曲没有可用播放地址，可能需要会员或存在版权限制';
        } else {
          _playbackError = _message(error);
        }
      }
    } finally {
      _loadingAudioSource = false;
      _recoveringSourceError = false;
      _isBuffering = false;
      notifyListeners();
    }
  }

  Future<void> _startPlayback() async {
    _playbackRequested = true;
    try {
      await _audioPlaybackStarter();
    } catch (error) {
      if (error is PlayerException) {
        _handlePlayerError(error);
      } else {
        _playbackError = _message(error);
        notifyListeners();
      }
    }
  }

  Future<void> _seekTo(Duration position) => _audioSeeker(position);

  Future<Uri?> _tryGetPlayableUrl(QqMusicItem song) async {
    try {
      final url = await api.getPlayableUrl(song);
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

  bool _isUnavailablePlaybackError(Object error) {
    if (error is! QqMusicApiException) {
      return false;
    }
    final message = error.message;
    return message.contains('没有可用播放地址') ||
        message.contains('缺少 MID') ||
        message.contains('版权限制');
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
    notifyListeners();
  }

  Future<void> toggleCurrentSongLiked() async {
    final song = _currentSong;
    if (!api.isLoggedIn || song == null || _isLoading) {
      return;
    }
    final wasLiked = isCurrentSongLiked;
    final previous = _featureCache[QqMusicFeature.likedSongs];
    _setSongLikedInMemory(song, !wasLiked);
    _statusMessage = wasLiked ? '已取消喜欢' : '已添加到我喜欢';
    _error = '';
    _isLoading = true;
    notifyListeners();
    try {
      await api.setSongLiked(song, liked: !wasLiked);
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
      _currentSongFromLiked = wasLiked;
      _statusMessage = '';
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
      hasMore: previous?.hasMore ?? false,
      message: previous?.message ?? '',
    );
    _currentSongFromLiked = liked;
    if (_entry?.feature == QqMusicFeature.likedSongs &&
        currentContainer == null) {
      _setRootResult(_featureCache[QqMusicFeature.likedSongs]!);
    }
  }

  Future<void> refreshCurrentSongLikedStatus() async {
    if (!api.isLoggedIn || _currentSong == null) {
      return;
    }
    await _run(
      () => api.loadFeature(QqMusicFeature.likedSongs, forceRefresh: true),
      replaceResult: false,
      cacheFeature: QqMusicFeature.likedSongs,
      updateVisibleResult: false,
    );
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
    if (name != _audioOutputName) {
      _audioOutputName = name;
      notifyListeners();
    }
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
    _statusMessage = '';
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

  Future<void> logout() async {
    _stopQrPolling();
    await api.logout();
    _featureCache.clear();
    _featurePages.clear();
    _childrenCache.clear();
    _prefetchedPlayableUrls.clear();
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
    _statusMessage = '';
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
        await _probePlayableUrls(loaded.items);
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
    _statusMessage = '';
    notifyListeners();
    try {
      await operation();
    } catch (error) {
      _error = _message(error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _configureAudioSession() async {
    if (_audioSessionConfigured) {
      return;
    }
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
    _audioSessionConfigured = true;
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
      if (status.done && api.isLoggedIn) {
        _stopQrPolling();
        await _loadProfile();
      } else if (status.event == 3 || status.event == 4 || status.event == -1) {
        _stopQrPolling();
      }
    } catch (error) {
      _error = _message(error);
      _stopQrPolling();
    } finally {
      _pollingQr = false;
      notifyListeners();
    }
  }

  void _stopQrPolling() {
    _qrPollTimer?.cancel();
    _qrPollTimer = null;
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

  String _itemKey(QqMusicItem item) => '${item.type.name}:${item.id}';

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
