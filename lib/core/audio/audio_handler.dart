import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import 'package:qqmusic_ipod/business/entities/music.dart';

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

  QqMusicAudioHandler({AudioPlayer? audioPlayer})
    : player = audioPlayer ?? AudioPlayer() {
    _subscriptions.add(player.playbackEventStream.listen(_broadcastState));
    _subscriptions.add(
      player.durationStream.listen((duration) {
        if (duration != null && duration > Duration.zero) {
          updateDuration(duration);
        }
      }),
    );
  }

  final AudioPlayer player;
  final List<StreamSubscription<Object?>> _subscriptions = [];

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
    // Exclusive music session must be active before audio starts so SpringBoard
    // can bind Now Playing UI (and Dynamic Island tap) to this app's bundle.
    if (!await _ensureMusicSessionActive()) {
      return;
    }
    _broadcastOptimisticState(true);
    await player.play();
  }

  @override
  Future<void> pause() async {
    _broadcastOptimisticState(false);
    await player.pause();
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
    await player.stop();
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
    final title = song.title.trim().isEmpty ? '未知歌曲' : song.title.trim();
    final artist =
        song.subtitle.trim().isEmpty ? '未知艺人' : song.subtitle.trim();
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
