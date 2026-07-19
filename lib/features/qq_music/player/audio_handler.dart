import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

import '../models/music.dart';

class QqMusicAudioHandler extends BaseAudioHandler with SeekHandler {
  QqMusicAudioHandler({AudioPlayer? audioPlayer})
    : player = audioPlayer ?? AudioPlayer() {
    _subscriptions.add(player.playbackEventStream.listen(_broadcastState));
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
    mediaItem.add(_mediaItemFor(song));
  }

  @override
  Future<void> play() async {
    if (player.processingState == ProcessingState.completed) {
      await player.seek(Duration.zero);
    }
    _broadcastOptimisticState(true);
    unawaited(player.play());
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

  List<MediaControl> _controlsFor(bool isPlaying) {
    final playPauseControl = MediaControl(
      androidIcon: isPlaying
          ? 'drawable/audio_service_pause'
          : 'drawable/audio_service_play_arrow',
      label: isPlaying ? 'Pause' : 'Play',
      action: MediaAction.playPause,
    );
    return [
      MediaControl.skipToPrevious,
      playPauseControl,
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

  MediaItem _mediaItemFor(QqMusicItem song) {
    final artworkUrl = song.imageUrl.replaceFirst(
      RegExp(r'^http://y\.gtimg\.cn/'),
      'https://y.gtimg.cn/',
    );
    final artworkUri = Uri.tryParse(artworkUrl);
    return MediaItem(
      id: song.mid.isEmpty ? song.id : song.mid,
      album: 'QQ 音乐',
      title: song.title,
      artist: song.subtitle,
      duration: song.duration == Duration.zero ? null : song.duration,
      artUri: artworkUri?.hasScheme == true ? artworkUri : null,
    );
  }
}
