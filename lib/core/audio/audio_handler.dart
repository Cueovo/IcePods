import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';

import 'package:qqmusic_ipod/business/entities/music.dart';

class QqMusicAudioHandler extends BaseAudioHandler with SeekHandler {
  QqMusicAudioHandler({AudioPlayer? audioPlayer})
    : player = audioPlayer ?? AudioPlayer() {
    _subscriptions.add(player.playbackEventStream.listen(_broadcastState));
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      _deviceChannel.setMethodCallHandler(_handleNativeRemoteCommand);
    }
  }

  static const MethodChannel _deviceChannel = MethodChannel(
    'qqmusic_ipod/device',
  );

  final AudioPlayer player;
  final List<StreamSubscription<Object?>> _subscriptions = [];
  Timer? _iosNowPlayingReclaimTimer;

  QqMusicItem? currentSong;
  Future<void> Function(int direction)? _skipHandler;

  void setSkipHandler(Future<void> Function(int direction) handler) {
    _skipHandler = handler;
  }

  Stream<PlayerState> get playerStateStream => player.playerStateStream;
  Stream<Duration> get positionStream => player.positionStream;
  Stream<Duration?> get durationStream => player.durationStream;
  bool get playing => player.playing;
  ProcessingState get processingState => player.processingState;
  Duration? get duration => player.duration;

  Future<void> load(QqMusicItem song, Uri uri) async {
    await player.setAudioSource(AudioSource.uri(uri));
    currentSong = song;
    // Prefer the duration the player resolved from the stream (home-feed
    // cards often omit interval / length metadata).
    final resolvedDuration =
        player.duration ??
        (song.duration > Duration.zero ? song.duration : null);
    mediaItem.add(_mediaItemFor(song, durationOverride: resolvedDuration));
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
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
      if (!await session.setActive(true)) {
        return;
      }
    }
    _broadcastOptimisticState(true);
    await player.play();
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      await _claimIosNowPlaying(playing: true);
      _broadcastOptimisticState(true);
      _scheduleIosNowPlayingReclaim();
    }
  }

  @override
  Future<void> pause() async {
    _iosNowPlayingReclaimTimer?.cancel();
    _broadcastOptimisticState(false);
    await player.pause();
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      await _claimIosNowPlaying(playing: false);
    }
  }

  @override
  Future<void> seek(Duration position) => player.seek(position);

  @override
  Future<void> click([MediaButton button = MediaButton.media]) async {
    switch (button) {
      case MediaButton.media:
        if (player.playing) {
          await pause();
        } else {
          unawaited(play());
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
      unawaited(handler(1));
    }
  }

  @override
  Future<void> skipToPrevious() async {
    final handler = _skipHandler;
    if (handler != null) {
      unawaited(handler(-1));
    }
  }

  @override
  Future<void> stop() async {
    await player.stop();
    currentSong = null;
    mediaItem.add(null);
    playbackState.add(
      playbackState.value.copyWith(
        controls: const [],
        processingState: AudioProcessingState.idle,
        playing: false,
      ),
    );
  }

  @override
  Future<void> onTaskRemoved() => stop();

  Future<void> _claimIosNowPlaying({required bool playing}) async {
    try {
      await _deviceChannel.invokeMethod<bool>('claimNowPlaying', {
        'playing': playing,
      });
    } on PlatformException {
      return;
    }
  }

  void _scheduleIosNowPlayingReclaim() {
    _iosNowPlayingReclaimTimer?.cancel();
    _iosNowPlayingReclaimTimer = Timer(const Duration(milliseconds: 900), () {
      if (player.playing) {
        unawaited(_claimIosNowPlaying(playing: true));
      }
    });
  }

  Future<dynamic> _handleNativeRemoteCommand(MethodCall call) async {
    switch (call.method) {
      case 'remotePlay':
        await play();
        return null;
      case 'remotePause':
        await pause();
        return null;
      case 'remoteToggle':
        if (player.playing) {
          await pause();
        } else {
          await play();
        }
        return null;
      case 'remoteNext':
        await skipToNext();
        return null;
      case 'remotePrevious':
        await skipToPrevious();
        return null;
      case 'remoteSeek':
        final args = call.arguments;
        final positionMs =
            args is Map ? (args['positionMs'] as num?)?.toInt() : null;
        if (positionMs != null) {
          await seek(Duration(milliseconds: positionMs));
        }
        return null;
      default:
        throw PlatformException(
          code: 'unimplemented',
          message: 'Unknown native remote command: ${call.method}',
        );
    }
  }

  List<MediaControl> _controlsFor(bool isPlaying) {
    final isIos = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
    return [
      MediaControl.skipToPrevious,
      if (isIos || !isPlaying) MediaControl.play,
      if (isIos || isPlaying) MediaControl.pause,
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
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        androidCompactActionIndices: const [0, 1, 2],
        processingState: player.processingState == ProcessingState.idle
            ? AudioProcessingState.loading
            : _processingStateFor(player.processingState),
        playing: isPlaying,
        updatePosition: player.position,
        bufferedPosition: player.bufferedPosition,
        speed: player.speed,
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
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: const [0, 1, 2],
      processingState: processingState,
      playing: isPlaying,
      updatePosition: player.position,
      bufferedPosition: player.bufferedPosition,
      speed: player.speed,
      queueIndex: event.currentIndex,
    );
  }

  void _broadcastState(PlaybackEvent event) {
    playbackState.add(_stateFor(event));
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
    return MediaItem(
      id: song.mid.isEmpty ? song.id : song.mid,
      album: 'QQ 音乐',
      title: song.title,
      artist: song.subtitle,
      duration: duration,
      artUri: artworkUri?.hasScheme == true ? artworkUri : null,
    );
  }
}
