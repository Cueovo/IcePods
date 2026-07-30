import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import 'package:qqmusic_ipod/business/entities/music.dart';
import 'package:qqmusic_ipod/core/utils/device_display_metrics.dart';

class _CrossfadeSource {
  const _CrossfadeSource({
    required this.song,
    required this.uri,
    required this.sequenceIndex,
  });

  final QqMusicItem song;
  final Uri uri;
  final int sequenceIndex;
}

/// Bridges [just_audio] into [audio_service] so iOS can treat this process as
/// a full Now Playing app (Lock Screen / Control Center / Dynamic Island).
///
/// Now Playing metadata/commands are owned exclusively by [audio_service].
/// Do not mutate [MPNowPlayingInfoCenter] from native side — that races the
/// plugin and can break SpringBoard's app association for Dynamic Island tap.
class QqMusicAudioHandler extends BaseAudioHandler with SeekHandler {
  static const Set<MediaAction> _systemActions = {
    MediaAction.play,
    MediaAction.pause,
    MediaAction.stop,
    MediaAction.seek,
    MediaAction.seekForward,
    MediaAction.seekBackward,
    MediaAction.skipToNext,
    MediaAction.skipToPrevious,
  };

  static const Duration crossfadeDuration = Duration(seconds: 5);
  static const Duration _crossfadeStep = Duration(milliseconds: 50);

  QqMusicAudioHandler({AudioPlayer? audioPlayer, AudioPlayer? crossfadePlayer})
    : _primaryPlayer = audioPlayer ?? AudioPlayer(),
      _secondaryPlayer = crossfadePlayer ?? AudioPlayer(),
      _ownsPrimaryPlayer = audioPlayer == null,
      _ownsSecondaryPlayer = crossfadePlayer == null {
    _activePlayer = _primaryPlayer;
    _standbyPlayer = _secondaryPlayer;
    _bindActivePlayer();
  }

  final AudioPlayer _primaryPlayer;
  final AudioPlayer _secondaryPlayer;
  final bool _ownsPrimaryPlayer;
  final bool _ownsSecondaryPlayer;
  late AudioPlayer _activePlayer;
  late AudioPlayer _standbyPlayer;
  final StreamController<PlayerState> _playerStateController =
      StreamController<PlayerState>.broadcast();
  final StreamController<Duration> _positionController =
      StreamController<Duration>.broadcast();
  final StreamController<Duration?> _durationController =
      StreamController<Duration?>.broadcast();
  final StreamController<PlayerException> _errorController =
      StreamController<PlayerException>.broadcast();
  final StreamController<int?> _sequenceIndexController =
      StreamController<int?>.broadcast();
  StreamSubscription<PlaybackEvent>? _playbackEventSubscription;
  StreamSubscription<PlayerState>? _playerStateSubscription;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration?>? _durationSubscription;
  StreamSubscription<PlayerException>? _errorSubscription;
  StreamSubscription<int?>? _currentIndexSubscription;
  Timer? _crossfadeTimer;
  AudioPlayer? _crossfadeOutgoingPlayer;
  _CrossfadeSource? _preparedCrossfadeSource;
  _CrossfadeSource? _pendingCrossfadeSource;
  DateTime? _crossfadeStartedAt;
  Duration _runningCrossfadeDuration = Duration.zero;
  Future<void> _crossfadeVolumeUpdate = Future<void>.value();
  bool _crossfadeEnabled = false;
  bool _usingCrossfadeSources = false;
  bool _crossfadeRunning = false;
  int _activeSequenceIndex = 0;
  double _volume = 1;

  AudioPlayer get player => _activePlayer;
  Stream<PlayerState> get playerStateStream => _playerStateController.stream;
  Stream<Duration> get positionStream => _positionController.stream;
  Stream<Duration?> get durationStream => _durationController.stream;
  Stream<PlayerException> get errorStream => _errorController.stream;
  Stream<int?> get currentIndexStream => _sequenceIndexController.stream;

  static ({double outgoing, double incoming}) crossfadeGains(
    double maximumVolume,
    double progress,
  ) {
    final normalized = progress.clamp(0.0, 1.0).toDouble();
    return (
      outgoing: maximumVolume * (1 - normalized),
      incoming: maximumVolume * normalized,
    );
  }

  final List<QqMusicItem> _sequenceSongs = [];

  QqMusicItem? currentSong;
  Future<void> Function(int direction)? _skipHandler;

  void setSkipHandler(Future<void> Function(int direction) handler) {
    _skipHandler = handler;
  }

  bool get playing => player.playing;
  ProcessingState get processingState => player.processingState;
  Duration? get duration => player.duration;

  void setCrossfadeEnabled(bool enabled) {
    if (_crossfadeEnabled == enabled) {
      return;
    }
    _crossfadeEnabled = enabled;
    if (!enabled && _crossfadeRunning) {
      unawaited(_cancelCrossfade());
    }
  }

  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0.0, 1.0).toDouble();
    if (_crossfadeRunning) {
      await _queueCrossfadeVolumes(_crossfadeProgress);
      return;
    }
    await _activePlayer.setVolume(_volume);
  }

  void _bindActivePlayer() {
    _cancelActivePlayerSubscriptions();
    _playbackEventSubscription = _activePlayer.playbackEventStream.listen(
      _broadcastState,
    );
    _playerStateSubscription = _activePlayer.playerStateStream.listen(
      _playerStateController.add,
    );
    _positionSubscription = _activePlayer.positionStream.listen((position) {
      _positionController.add(position);
      _maybeStartCrossfade(position);
    });
    _durationSubscription = _activePlayer.durationStream.listen((duration) {
      _durationController.add(duration);
      if (duration != null && duration > Duration.zero) {
        updateDuration(duration);
      }
    });
    _errorSubscription = _activePlayer.errorStream.listen(_errorController.add);
    _currentIndexSubscription = _activePlayer.currentIndexStream.listen((
      index,
    ) {
      if (_usingCrossfadeSources) {
        return;
      }
      _activeSequenceIndex = index ?? 0;
      _selectSequenceIndex(index);
      _sequenceIndexController.add(index);
    });
  }

  void _cancelActivePlayerSubscriptions() {
    final playback = _playbackEventSubscription;
    if (playback != null) {
      unawaited(playback.cancel());
    }
    final state = _playerStateSubscription;
    if (state != null) {
      unawaited(state.cancel());
    }
    final position = _positionSubscription;
    if (position != null) {
      unawaited(position.cancel());
    }
    final duration = _durationSubscription;
    if (duration != null) {
      unawaited(duration.cancel());
    }
    final error = _errorSubscription;
    if (error != null) {
      unawaited(error.cancel());
    }
    final index = _currentIndexSubscription;
    if (index != null) {
      unawaited(index.cancel());
    }
  }

  Future<void> load(
    QqMusicItem song,
    Uri uri, {
    QqMusicItem? nextSong,
    Uri? nextUri,
  }) async {
    await _cancelCrossfade();
    _sequenceSongs
      ..clear()
      ..add(song);
    if (nextSong != null && nextUri != null) {
      _sequenceSongs.add(nextSong);
    }
    queue.add(_sequenceSongs.map(_mediaItemFor).toList(growable: false));
    _activeSequenceIndex = 0;
    _preparedCrossfadeSource = null;
    _pendingCrossfadeSource = null;
    _usingCrossfadeSources = _crossfadeEnabled;
    await _standbyPlayer.stop();
    await _standbyPlayer.setVolume(0);
    await _activePlayer.setVolume(_volume);
    if (!_usingCrossfadeSources) {
      final sources = <AudioSource>[AudioSource.uri(uri)];
      if (nextSong != null && nextUri != null) {
        sources.add(AudioSource.uri(nextUri));
      }
      await _activePlayer.setAudioSources(
        sources,
        initialIndex: 0,
        initialPosition: Duration.zero,
      );
      _selectSequenceIndex(0);
      return;
    }
    await _activePlayer.setAudioSource(
      AudioSource.uri(uri),
      initialPosition: Duration.zero,
    );
    if (nextSong != null && nextUri != null) {
      await _prepareCrossfadeSource(
        _CrossfadeSource(song: nextSong, uri: nextUri, sequenceIndex: 1),
      );
    }
    _selectSequenceIndex(0);
  }

  Future<void> append(QqMusicItem song, Uri uri) async {
    if (_sequenceSongs.any((item) => _sameSong(item, song))) {
      return;
    }
    final source = _CrossfadeSource(
      song: song,
      uri: uri,
      sequenceIndex: _sequenceSongs.length,
    );
    _sequenceSongs.add(song);
    queue.add(_sequenceSongs.map(_mediaItemFor).toList(growable: false));
    if (!_usingCrossfadeSources) {
      await _activePlayer.addAudioSource(AudioSource.uri(uri));
      return;
    }
    if (_crossfadeRunning) {
      _pendingCrossfadeSource = source;
      return;
    }
    await _prepareCrossfadeSource(source);
  }

  Future<void> _prepareCrossfadeSource(_CrossfadeSource source) async {
    _preparedCrossfadeSource = source;
    try {
      await _standbyPlayer.stop();
      await _standbyPlayer.setVolume(0);
      await _standbyPlayer.setAudioSource(
        AudioSource.uri(source.uri),
        initialPosition: Duration.zero,
      );
    } catch (_) {
      if (identical(_preparedCrossfadeSource, source)) {
        _preparedCrossfadeSource = null;
      }
    }
  }

  void _maybeStartCrossfade(Duration position) {
    if (!_usingCrossfadeSources ||
        !_crossfadeEnabled ||
        _crossfadeRunning ||
        !_activePlayer.playing) {
      return;
    }
    final source = _preparedCrossfadeSource;
    if (source == null || source.sequenceIndex != _activeSequenceIndex + 1) {
      return;
    }
    final duration = _activePlayer.duration;
    if (duration == null || duration <= Duration.zero) {
      return;
    }
    final transitionDuration = _effectiveCrossfadeDuration(duration);
    if (transitionDuration == Duration.zero ||
        position < duration - transitionDuration) {
      return;
    }
    unawaited(_startCrossfade(source, transitionDuration));
  }

  Duration _effectiveCrossfadeDuration(Duration duration) {
    final milliseconds = duration.inMilliseconds;
    if (milliseconds < const Duration(seconds: 2).inMilliseconds) {
      return Duration.zero;
    }
    final half = Duration(milliseconds: milliseconds ~/ 2);
    return half < crossfadeDuration ? half : crossfadeDuration;
  }

  Future<void> _startCrossfade(
    _CrossfadeSource source,
    Duration transitionDuration,
  ) async {
    if (!_usingCrossfadeSources ||
        !_crossfadeEnabled ||
        _crossfadeRunning ||
        !identical(_preparedCrossfadeSource, source)) {
      return;
    }
    final outgoing = _activePlayer;
    final incoming = _standbyPlayer;
    _crossfadeRunning = true;
    _crossfadeOutgoingPlayer = outgoing;
    _preparedCrossfadeSource = null;
    _runningCrossfadeDuration = transitionDuration;
    _crossfadeStartedAt = DateTime.now();
    try {
      await incoming.setVolume(0);
      unawaited(incoming.play().catchError((Object _) {}));
      _activePlayer = incoming;
      _standbyPlayer = outgoing;
      _activeSequenceIndex = source.sequenceIndex;
      _bindActivePlayer();
      _selectSequenceIndex(source.sequenceIndex);
      _sequenceIndexController.add(source.sequenceIndex);
      _crossfadeTimer = Timer.periodic(_crossfadeStep, _handleCrossfadeTick);
      unawaited(_queueCrossfadeVolumes(0));
    } catch (_) {
      _crossfadeRunning = false;
      _crossfadeOutgoingPlayer = null;
      _crossfadeStartedAt = null;
      _runningCrossfadeDuration = Duration.zero;
      _activePlayer = outgoing;
      _standbyPlayer = incoming;
      _bindActivePlayer();
      try {
        await outgoing.setVolume(_volume);
        await incoming.pause();
        await incoming.setVolume(0);
      } catch (_) {}
    }
  }

  double get _crossfadeProgress {
    final startedAt = _crossfadeStartedAt;
    if (startedAt == null || _runningCrossfadeDuration <= Duration.zero) {
      return 1;
    }
    final elapsed = DateTime.now().difference(startedAt);
    return (elapsed.inMicroseconds / _runningCrossfadeDuration.inMicroseconds)
        .clamp(0.0, 1.0)
        .toDouble();
  }

  void _handleCrossfadeTick(Timer timer) {
    if (!_crossfadeRunning) {
      timer.cancel();
      return;
    }
    final progress = _crossfadeProgress;
    unawaited(_queueCrossfadeVolumes(progress));
    if (progress >= 1) {
      timer.cancel();
      _crossfadeTimer = null;
      unawaited(_finishCrossfade());
    }
  }

  Future<void> _queueCrossfadeVolumes(double progress) {
    final outgoing = _crossfadeOutgoingPlayer;
    final incoming = _activePlayer;
    if (outgoing == null) {
      return Future<void>.value();
    }
    final gains = crossfadeGains(_volume, progress);
    _crossfadeVolumeUpdate = _crossfadeVolumeUpdate.then((_) async {
      if (!_crossfadeRunning ||
          !identical(_crossfadeOutgoingPlayer, outgoing) ||
          !identical(_activePlayer, incoming)) {
        return;
      }
      try {
        await Future.wait([
          outgoing.setVolume(gains.outgoing),
          incoming.setVolume(gains.incoming),
        ]);
      } catch (_) {}
    });
    return _crossfadeVolumeUpdate;
  }

  Future<void> _finishCrossfade() async {
    if (!_crossfadeRunning) {
      return;
    }
    _crossfadeTimer?.cancel();
    _crossfadeTimer = null;
    await _queueCrossfadeVolumes(1);
    await _crossfadeVolumeUpdate;
    final outgoing = _crossfadeOutgoingPlayer;
    _crossfadeRunning = false;
    _crossfadeOutgoingPlayer = null;
    _crossfadeStartedAt = null;
    _runningCrossfadeDuration = Duration.zero;
    if (outgoing != null) {
      try {
        await outgoing.pause();
        await outgoing.seek(Duration.zero);
        await outgoing.setVolume(0);
      } catch (_) {}
    }
    try {
      await _activePlayer.setVolume(_volume);
    } catch (_) {}
    final pending = _pendingCrossfadeSource;
    _pendingCrossfadeSource = null;
    if (pending != null && _usingCrossfadeSources) {
      await _prepareCrossfadeSource(pending);
    }
  }

  Future<void> _cancelCrossfade() async {
    _crossfadeTimer?.cancel();
    _crossfadeTimer = null;
    final outgoing = _crossfadeOutgoingPlayer;
    _crossfadeRunning = false;
    _crossfadeOutgoingPlayer = null;
    _crossfadeStartedAt = null;
    _runningCrossfadeDuration = Duration.zero;
    _pendingCrossfadeSource = null;
    if (outgoing != null && !identical(outgoing, _activePlayer)) {
      try {
        await outgoing.pause();
        await outgoing.setVolume(0);
      } catch (_) {}
    }
    try {
      await _activePlayer.setVolume(_volume);
    } catch (_) {}
  }

  void _selectSequenceIndex(int? index) {
    if (index == null || index < 0 || index >= _sequenceSongs.length) {
      return;
    }
    final song = _sequenceSongs[index];
    if (_sameSong(song, currentSong) && mediaItem.value != null) {
      return;
    }
    currentSong = song;
    final resolvedDuration =
        player.duration ??
        (song.duration > Duration.zero ? song.duration : null);
    mediaItem.add(_mediaItemFor(song, durationOverride: resolvedDuration));
  }

  bool _sameSong(QqMusicItem left, QqMusicItem? right) {
    if (right == null) {
      return false;
    }
    if (left.mid.isNotEmpty && right.mid.isNotEmpty) {
      return left.mid == right.mid;
    }
    return left.id == right.id;
  }

  /// Push a known duration onto the current [MediaItem] (e.g. after the
  /// player reports length for a song that had duration=0 in the feed).
  void updateDuration(Duration duration) {
    final song = currentSong;
    final current = mediaItem.value;
    if (song == null || duration <= Duration.zero) {
      return;
    }
    if (current?.duration == duration) {
      return;
    }
    mediaItem.add(
      (current ?? _mediaItemFor(song)).copyWith(duration: duration),
    );
  }

  @override
  Future<void> play() async {
    if (player.processingState == ProcessingState.completed) {
      await player.seek(Duration.zero);
    }
    // Exclusive music session must be active before audio starts so SpringBoard
    // can bind Now Playing UI (and Dynamic Island tap) to this app's bundle.
    if (!await _ensureMusicSessionActive()) {
      return;
    }
    // Re-assert NP app eligibility when playback starts (TrollStore / SB open path).
    unawaited(DeviceDisplayMetrics.claimNowPlayingApp());
    _broadcastOptimisticState(true);
    await player.play();
  }

  @override
  Future<void> pause() async {
    _broadcastOptimisticState(false);
    await _cancelCrossfade();
    await player.pause();
  }

  @override
  Future<void> seek(Duration position) async {
    await _cancelCrossfade();
    await player.seek(position);
  }

  @override
  Future<void> click([MediaButton button = MediaButton.media]) async {
    switch (button) {
      case MediaButton.media:
        if (player.playing) {
          await pause();
        } else {
          await play();
        }
      case MediaButton.next:
        await skipToNext();
      case MediaButton.previous:
        await skipToPrevious();
    }
  }

  @override
  Future<void> skipToNext() async {
    final handler = _skipHandler;
    if (handler != null) {
      await handler(1);
    }
  }

  @override
  Future<void> skipToPrevious() async {
    final handler = _skipHandler;
    if (handler != null) {
      await handler(-1);
    }
  }

  @override
  Future<void> stop() async {
    await _cancelCrossfade();
    await Future.wait([_activePlayer.stop(), _standbyPlayer.stop()]);
    _usingCrossfadeSources = false;
    _preparedCrossfadeSource = null;
    _pendingCrossfadeSource = null;
    _sequenceSongs.clear();
    queue.add(const []);
    currentSong = null;
    mediaItem.add(null);
    playbackState.add(
      playbackState.value.copyWith(
        controls: const [],
        systemActions: const {},
        processingState: AudioProcessingState.idle,
        playing: false,
      ),
    );
    if (!kIsWeb) {
      try {
        final session = await AudioSession.instance;
        await session.setActive(false);
      } catch (_) {}
    }
  }

  @override
  Future<void> onTaskRemoved() => stop();

  /// Activate the already-configured music session before playback.
  ///
  /// Configuration happens once in main() (Bloomee-style). Re-calling
  /// configure(music()) here can clobber category options and confuse
  /// SpringBoard's Now Playing ownership.
  Future<bool> _ensureMusicSessionActive() async {
    if (kIsWeb) {
      return true;
    }
    try {
      final session = await AudioSession.instance;
      return await session.setActive(true);
    } catch (_) {
      return false;
    }
  }

  List<MediaControl> _controlsFor(bool isPlaying) {
    // Explicit play/pause (not playPause) so iOS enables MPRemoteCommandCenter
    // playCommand and pauseCommand  required for full Now Playing eligibility.
    return [
      MediaControl.skipToPrevious,
      if (isPlaying) MediaControl.pause else MediaControl.play,
      MediaControl.skipToNext,
    ];
  }

  AudioProcessingState _processingStateFor(ProcessingState state) {
    return switch (state) {
      ProcessingState.idle => AudioProcessingState.idle,
      ProcessingState.loading => AudioProcessingState.loading,
      ProcessingState.buffering => AudioProcessingState.buffering,
      ProcessingState.ready => AudioProcessingState.ready,
      ProcessingState.completed => AudioProcessingState.completed,
    };
  }

  void _broadcastOptimisticState(bool isPlaying) {
    playbackState.add(
      playbackState.value.copyWith(
        controls: _controlsFor(isPlaying),
        systemActions: _systemActions,
        androidCompactActionIndices: const [0, 1, 2],
        processingState: player.processingState == ProcessingState.idle
            ? AudioProcessingState.loading
            : _processingStateFor(player.processingState),
        playing: isPlaying,
        updatePosition: player.position,
        bufferedPosition: player.bufferedPosition,
        speed: isPlaying ? player.speed : 0.0,
      ),
    );
  }

  PlaybackState _stateFor(PlaybackEvent event) {
    final processingState = _processingStateFor(player.processingState);
    final isPlaying =
        player.playing &&
        player.processingState != ProcessingState.idle &&
        player.processingState != ProcessingState.completed;
    return PlaybackState(
      controls: _controlsFor(isPlaying),
      systemActions: _systemActions,
      androidCompactActionIndices: const [0, 1, 2],
      processingState: processingState,
      playing: isPlaying,
      updatePosition: player.position,
      bufferedPosition: player.bufferedPosition,
      speed: isPlaying ? player.speed : 0.0,
      queueIndex: _usingCrossfadeSources
          ? _activeSequenceIndex
          : event.currentIndex,
    );
  }

  void _broadcastState(PlaybackEvent event) {
    playbackState.add(_stateFor(event));
  }

  Future<void> close() async {
    await stop();
    _cancelActivePlayerSubscriptions();
    if (_ownsPrimaryPlayer) {
      await _primaryPlayer.dispose();
    }
    if (_ownsSecondaryPlayer) {
      await _secondaryPlayer.dispose();
    }
    await _playerStateController.close();
    await _positionController.close();
    await _durationController.close();
    await _errorController.close();
    await _sequenceIndexController.close();
  }

  MediaItem _mediaItemFor(QqMusicItem song, {Duration? durationOverride}) {
    final artworkUrl = song.imageUrl.replaceFirst(
      RegExp(r'^http://y\.gtimg\.cn/'),
      'https://y.gtimg.cn/',
    );
    final artworkUri = Uri.tryParse(artworkUrl);
    final duration =
        durationOverride ??
        (song.duration == Duration.zero ? null : song.duration);
    final title = song.title.trim().isEmpty ? '未知歌曲' : song.title.trim();
    final artist = song.subtitle.trim().isEmpty ? '未知艺人' : song.subtitle.trim();
    return MediaItem(
      id: song.mid.isEmpty ? song.id : song.mid,
      album: 'QQ 音乐',
      title: title,
      artist: artist,
      duration: duration,
      artUri: artworkUri?.hasScheme == true ? artworkUri : null,
      playable: true,
    );
  }
}
