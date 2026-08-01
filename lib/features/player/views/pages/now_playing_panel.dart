import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'package:qqmusic_ipod/business/entities/music.dart';
import 'package:qqmusic_ipod/core/theme/artwork/artwork_palette_builder.dart';
import 'package:qqmusic_ipod/core/theme/tokens/app_tokens.dart';
import 'package:qqmusic_ipod/core/theme/widgets/artwork_image.dart';
import 'package:qqmusic_ipod/features/shell/models/ipod_models.dart';
import 'package:qqmusic_ipod/features/shell/views/widgets/feature_message_state.dart';

class NowPlayingPanel extends StatefulWidget {
  const NowPlayingPanel({
    required this.album,
    required this.progress,
    required this.position,
    required this.duration,
    required this.rotationDelta,
    required this.isBuffering,
    required this.error,
    this.isPlaying = false,
    this.isSeeking = false,
    this.isEmpty = false,
    this.lyrics,
    this.isLoadingLyrics = false,
    this.isLiked = false,
    this.playbackMode = QqMusicPlaybackMode.sequential,
    this.queueLength = 0,
    this.lyricsOpenRevision = 0,
    this.sleepTimerDeadline,
    this.onLikedPressed,
    this.onLyricsPressed,
    this.onPlaybackModePressed,
    this.onQueuePressed,
    this.onSeekTo,
    super.key,
  });

  final Album album;
  final double progress;
  final Duration position;
  final Duration duration;
  final double rotationDelta;
  final bool isBuffering;
  final bool isPlaying;
  final bool isSeeking;
  final String error;
  final bool isEmpty;
  final QqMusicLyrics? lyrics;
  final bool isLoadingLyrics;
  final bool isLiked;
  final QqMusicPlaybackMode playbackMode;
  final int queueLength;
  final int lyricsOpenRevision;
  final DateTime? sleepTimerDeadline;
  final VoidCallback? onLikedPressed;
  final VoidCallback? onLyricsPressed;
  final VoidCallback? onPlaybackModePressed;
  final VoidCallback? onQueuePressed;

  /// Absolute seek (0–1) used by accessible progress adjustment.
  final ValueChanged<double>? onSeekTo;

  @override
  State<NowPlayingPanel> createState() => _NowPlayingPanelState();
}

class _NowPlayingPanelState extends State<NowPlayingPanel> {
  late bool _showLyrics;
  double _horizontalDrag = 0;
  int _contentDirection = 1;

  @override
  void initState() {
    super.initState();
    _showLyrics = widget.lyricsOpenRevision > 0;
  }

  @override
  void didUpdateWidget(NowPlayingPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lyricsOpenRevision != widget.lyricsOpenRevision &&
        !_showLyrics) {
      setState(() {
        _contentDirection = 1;
        _showLyrics = true;
      });
    }
  }

  void _toggleLyrics({int? direction}) {
    setState(() {
      final nextShowLyrics = !_showLyrics;
      _contentDirection = direction ?? (nextShowLyrics ? 1 : -1);
      _showLyrics = nextShowLyrics;
    });
    widget.onLyricsPressed?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isEmpty) {
      return const _EmptyNowPlaying();
    }
    final currentTime = _formatDuration(widget.position);
    final totalTime = _formatDuration(widget.duration);
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return GestureDetector(
      key: const ValueKey('now-playing-swipe-area'),
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: (_) => _horizontalDrag = 0,
      onHorizontalDragUpdate: (details) => _horizontalDrag += details.delta.dx,
      onHorizontalDragCancel: () => _horizontalDrag = 0,
      onHorizontalDragEnd: (_) {
        final drag = _horizontalDrag;
        _horizontalDrag = 0;
        if (drag.abs() > 45) {
          _toggleLyrics(direction: drag < 0 ? 1 : -1);
        }
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxHeight < 380;
          final tight = constraints.maxHeight < 300;
          final topPad = tight
              ? 8.0
              : compact
              ? 12.0
              : 24.0;
          final bottomPad = tight
              ? 4.0
              : compact
              ? 6.0
              : 14.0;
          final titleGap = tight
              ? 4.0
              : compact
              ? 6.0
              : 10.0;
          final progressGap = tight
              ? 4.0
              : compact
              ? 6.0
              : 12.0;
          final actionGap = tight
              ? 2.0
              : compact
              ? 4.0
              : 8.0;
          final titleSize = tight
              ? 16.0
              : compact
              ? 18.0
              : 22.0;
          final artistSize = tight ? 12.0 : 14.0;
          final actionSize = tight ? 36.0 : 44.0;
          return Padding(
            padding: EdgeInsets.fromLTRB(24, topPad, 24, bottomPad),
            child: Column(
              children: [
                Expanded(
                  child: ClipRect(
                    child: AnimatedSwitcher(
                      duration: reduceMotion
                          ? AppDurations.reducedMotion
                          : AppDurations.standard,
                      layoutBuilder: (currentChild, previousChildren) {
                        return Stack(
                          fit: StackFit.expand,
                          children: [
                            if (previousChildren.isNotEmpty)
                              previousChildren.last,
                            ?currentChild,
                          ],
                        );
                      },
                      transitionBuilder: (child, animation) {
                        final currentKey = ValueKey(
                          _showLyrics ? 'player-lyrics' : 'player-artwork-view',
                        );
                        final isIncoming = child.key == currentKey;
                        final progress = isIncoming
                            ? animation
                            : ReverseAnimation(animation);
                        final direction = reduceMotion
                            ? 0.0
                            : _contentDirection.toDouble();
                        final position =
                            Tween<Offset>(
                              begin: isIncoming
                                  ? Offset(.065 * direction, 0)
                                  : Offset.zero,
                              end: isIncoming
                                  ? Offset.zero
                                  : Offset(-.032 * direction, 0),
                            ).animate(
                              CurvedAnimation(
                                parent: progress,
                                curve: AppCurves.menuPage,
                              ),
                            );
                        final opacity =
                            Tween<double>(
                              begin: isIncoming ? 0 : 1,
                              end: isIncoming ? 1 : 0,
                            ).animate(
                              CurvedAnimation(
                                parent: progress,
                                curve: Interval(
                                  isIncoming ? .12 : 0,
                                  isIncoming ? .82 : .42,
                                  curve: AppCurves.strongEaseOut,
                                ),
                              ),
                            );
                        final scale =
                            Tween<double>(
                              begin: reduceMotion
                                  ? 1
                                  : isIncoming
                                  ? .985
                                  : 1,
                              end: reduceMotion
                                  ? 1
                                  : isIncoming
                                  ? 1
                                  : .97,
                            ).animate(
                              CurvedAnimation(
                                parent: progress,
                                curve: AppCurves.menuPage,
                              ),
                            );
                        return FadeTransition(
                          opacity: opacity,
                          child: SlideTransition(
                            position: position,
                            child: ScaleTransition(scale: scale, child: child),
                          ),
                        );
                      },
                      child: _showLyrics
                          ? _LyricsView(
                              key: const ValueKey('player-lyrics'),
                              lyrics: widget.lyrics,
                              position: widget.position,
                              isLoading: widget.isLoadingLyrics,
                              isSeeking: widget.isSeeking,
                              isPlaying:
                                  widget.isPlaying &&
                                  !widget.isBuffering &&
                                  !widget.isSeeking,
                            )
                          : _ArtworkView(
                              key: const ValueKey('player-artwork-view'),
                              album: widget.album,
                              rotationDelta: widget.rotationDelta,
                            ),
                    ),
                  ),
                ),
                SizedBox(height: titleGap),
                if (_showLyrics)
                  _LyricsTrackMetadata(
                    title: widget.album.title,
                    artist: widget.album.artist,
                  )
                else ...[
                  Text(
                    widget.album.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.title.copyWith(fontSize: titleSize),
                  ),
                  SizedBox(height: tight ? 1 : 3),
                  Text(
                    widget.album.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: artistSize,
                    ),
                  ),
                ],
                SizedBox(height: progressGap),
                _PlayerProgressBar(
                  progress: widget.progress,
                  animationPhase: widget.position.inMilliseconds / 4000,
                  isPlaying: widget.isPlaying,
                  isBuffering: widget.isBuffering,
                  isSeeking: widget.isSeeking,
                  imageUrl: widget.album.imageUrl,
                  onSeekTo: widget.onSeekTo,
                  height: tight ? 22 : (compact ? 26 : 30),
                ),
                if (widget.error.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    widget.error,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.micro.copyWith(
                      color: AppColors.danger,
                      fontWeight: AppTextStyles.strong,
                    ),
                  ),
                ],
                SizedBox(height: tight ? 2 : 6),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 160),
                  child: widget.isSeeking
                      ? Text(
                          '$currentTime / $totalTime',
                          key: const ValueKey('seek-preview-time'),
                          style: AppTextStyles.metadata.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: AppTextStyles.strong,
                          ),
                        )
                      : Row(
                          key: const ValueKey('playback-time-row'),
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(currentTime, style: _timeStyle),
                            if (widget.sleepTimerDeadline case final deadline?)
                              _SleepTimerIndicator(deadline: deadline),
                            Text(totalTime, style: _timeStyle),
                          ],
                        ),
                ),
                SizedBox(height: actionGap),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _ActionButton(
                      key: const ValueKey('player-liked-button'),
                      icon: widget.isLiked
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      tooltip: widget.isLiked ? '我喜欢' : '未喜欢',
                      active: widget.isLiked,
                      activeColor: AppColors.danger,
                      dimension: actionSize,
                      onPressed: widget.onLikedPressed,
                    ),
                    _ActionButton(
                      key: const ValueKey('player-lyrics-button'),
                      icon: Icons.lyrics_rounded,
                      tooltip: _showLyrics ? '封面' : '歌词',
                      active: _showLyrics,
                      activeColor: AppColors.interaction,
                      dimension: actionSize,
                      onPressed: () => _toggleLyrics(),
                    ),
                    _ActionButton(
                      key: const ValueKey('player-mode-button'),
                      icon: switch (widget.playbackMode) {
                        QqMusicPlaybackMode.sequential => Icons.repeat_rounded,
                        QqMusicPlaybackMode.repeatOne =>
                          Icons.repeat_one_rounded,
                        QqMusicPlaybackMode.shuffle => Icons.shuffle_rounded,
                      },
                      tooltip: switch (widget.playbackMode) {
                        QqMusicPlaybackMode.sequential => '顺序播放',
                        QqMusicPlaybackMode.repeatOne => '单曲循环',
                        QqMusicPlaybackMode.shuffle => '随机播放',
                      },
                      active: false,
                      dimension: actionSize,
                      onPressed: widget.onPlaybackModePressed,
                    ),
                    _ActionButton(
                      key: const ValueKey('player-queue-button'),
                      icon: Icons.queue_music_rounded,
                      tooltip: widget.queueLength == 0
                          ? '播放队列'
                          : '播放队列，${widget.queueLength} 首',
                      active: false,
                      dimension: actionSize,
                      onPressed: widget.onQueuePressed,
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SleepTimerIndicator extends StatefulWidget {
  const _SleepTimerIndicator({required this.deadline});

  final DateTime deadline;

  @override
  State<_SleepTimerIndicator> createState() => _SleepTimerIndicatorState();
}

class _SleepTimerIndicatorState extends State<_SleepTimerIndicator> {
  Timer? _timer;
  late int _remainingSeconds;

  @override
  void initState() {
    super.initState();
    _restartTimer();
  }

  @override
  void didUpdateWidget(_SleepTimerIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.deadline != widget.deadline) {
      _restartTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _restartTimer() {
    _timer?.cancel();
    _remainingSeconds = _secondsUntil(widget.deadline);
    if (_remainingSeconds <= 0) {
      return;
    }
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final deadlineRemaining = _secondsUntil(widget.deadline);
      final remaining = math.min(
        math.max(0, _remainingSeconds - 1),
        deadlineRemaining,
      );
      if (remaining == _remainingSeconds) {
        return;
      }
      if (remaining <= 0) {
        _timer?.cancel();
      }
      if (mounted) {
        setState(() => _remainingSeconds = remaining);
      }
    });
  }

  int _secondsUntil(DateTime deadline) {
    final milliseconds = deadline.difference(DateTime.now()).inMilliseconds;
    return milliseconds <= 0 ? 0 : (milliseconds / 1000).ceil();
  }

  @override
  Widget build(BuildContext context) {
    final countdown = _formatCountdown(_remainingSeconds);
    return Semantics(
      label: '定时关闭',
      value: '剩余 $countdown',
      child: RepaintBoundary(
        child: DecoratedBox(
          key: const ValueKey('player-sleep-timer'),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0x38C8B7FF), Color(0x246A5BE7)],
            ),
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: const Color(0x36FFFFFF)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x28000000),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.bedtime_rounded,
                  size: 12,
                  color: Color(0xFFD9CFFF),
                ),
                const SizedBox(width: 5),
                Text(
                  countdown,
                  key: const ValueKey('player-sleep-timer-countdown'),
                  style: const TextStyle(
                    color: Color(0xF2FFFFFF),
                    fontSize: 11,
                    height: 1,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .25,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _formatCountdown(int totalSeconds) {
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = totalSeconds % 60;
  final minuteText = minutes.toString().padLeft(2, '0');
  final secondText = seconds.toString().padLeft(2, '0');
  if (hours == 0) {
    return '$minuteText:$secondText';
  }
  return '${hours.toString().padLeft(2, '0')}:$minuteText:$secondText';
}

class _PlayerProgressBar extends StatelessWidget {
  const _PlayerProgressBar({
    required this.progress,
    required this.animationPhase,
    required this.isPlaying,
    required this.isBuffering,
    required this.isSeeking,
    required this.imageUrl,
    required this.onSeekTo,
    this.height = 30,
  });

  /// Accessible seek step, matching a comfortable wheel nudge.
  static const double _seekStep = .05;

  final double progress;
  final double animationPhase;
  final bool isPlaying;
  final bool isBuffering;
  final bool isSeeking;

  /// Artwork the progress light borrows its colors from.
  final String imageUrl;

  /// Absolute seek used by assistive increase/decrease actions.
  final ValueChanged<double>? onSeekTo;
  final double height;

  /// Lifts an ambient color into a light trace that stays legible on glass.
  static Color _trace(
    Color base, {
    required double lightness,
    double hueShift = 0,
    double saturation = .55,
  }) {
    final hsl = HSLColor.fromColor(base);
    return hsl
        .withHue((hsl.hue + hueShift) % 360)
        .withSaturation(saturation.clamp(0.0, 1.0))
        .withLightness(lightness)
        .toColor();
  }

  @override
  Widget build(BuildContext context) {
    final value = progress.isFinite ? progress.clamp(0.0, 1.0) : 0.0;
    final phase = animationPhase.isFinite ? animationPhase : 0.0;
    return Semantics(
      label: '播放进度',
      value: '${(value * 100).round()}%',
      increasedValue: '${((value + _seekStep) * 100).clamp(0, 100).round()}%',
      decreasedValue: '${((value - _seekStep) * 100).clamp(0, 100).round()}%',
      // Screen-reader users get seek controls without the simulated wheel.
      onIncrease: onSeekTo == null
          ? null
          : () => onSeekTo!((value + _seekStep).clamp(0.0, 1.0)),
      onDecrease: onSeekTo == null
          ? null
          : () => onSeekTo!((value - _seekStep).clamp(0.0, 1.0)),
      child: RepaintBoundary(
        key: const ValueKey('player-progress'),
        child: SizedBox(
          height: height,
          width: double.infinity,
          child: ArtworkPaletteBuilder(
            imageUrl: imageUrl,
            builder: (context, palette) {
              // The trace is the album's light, not a fixed violet signature.
              final primary = _trace(palette.primary, lightness: .62);
              final secondary = _trace(
                palette.primary,
                lightness: .66,
                hueShift: 28,
                saturation: .5,
              );
              final pearl = _trace(
                palette.primary,
                lightness: .88,
                saturation: .32,
              );
              return TweenAnimationBuilder<Offset>(
                tween: Tween<Offset>(
                  begin: Offset(value, phase),
                  end: Offset(value, phase),
                ),
                duration: isSeeking
                    ? AppDurations.quick
                    : AppDurations.standard,
                // Playback progress is a continuously advancing value: easing
                // every incoming sample would make its velocity uneven.
                curve: isSeeking ? AppCurves.strongEaseOut : Curves.linear,
                builder: (context, visualState, child) {
                  return CustomPaint(
                    key: const ValueKey('player-progress-paint'),
                    painter: _PlayerProgressPainter(
                      progress: visualState.dx,
                      animationPhase: visualState.dy,
                      isPlaying: isPlaying,
                      isBuffering: isBuffering,
                      isSeeking: isSeeking,
                      primary: primary,
                      secondary: secondary,
                      pearl: pearl,
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class _PlayerProgressPainter extends CustomPainter {
  const _PlayerProgressPainter({
    required this.progress,
    required this.animationPhase,
    required this.isPlaying,
    required this.isBuffering,
    required this.isSeeking,
    required this.primary,
    required this.secondary,
    required this.pearl,
  });

  final double progress;
  final double animationPhase;
  final bool isPlaying;
  final bool isBuffering;
  final bool isSeeking;
  final Color primary;
  final Color secondary;
  final Color pearl;

  /// Wave only on the unplayed side of [progressX]. Amplitude is 0 at the
  /// playhead and ramps up after it, so the curve looks sucked into the dot.
  Path _unplayedWavePath(
    Rect bounds, {
    required double progressX,
    required double amplitude,
    required double frequency,
    required double phase,
    required double bandEnergy,
    required double spectrumOffset,
  }) {
    final path = Path();
    final startX = progressX.clamp(bounds.left, bounds.right);
    final remaining = bounds.right - startX;
    if (remaining <= 0.5) {
      return path;
    }

    final absorb = (bounds.width * 0.07).clamp(10.0, 22.0);
    const segments = 48;
    var started = false;
    for (var index = 0; index <= segments; index++) {
      final t = index / segments;
      final x = startX + remaining * t;
      final distFromHead = x - startX;
      final absorbEnvelope = (distFromHead / absorb).clamp(0.0, 1.0);
      final softAbsorb =
          absorbEnvelope * absorbEnvelope * (3 - 2 * absorbEnvelope);
      final rightFade = math.sin(math.pi * t * 0.5).clamp(0.0, 1.0);
      final spectralEnvelope =
          .72 +
          math.sin(t * math.pi * 5.2 + phase * .46 + spectrumOffset) * .16 +
          math.sin(t * math.pi * 9.6 - phase * .31 - spectrumOffset) * .1;
      final primary = math.sin(t * math.pi * 2 * frequency + phase);
      final detail = math.sin(t * math.pi * 4.4 - phase * .62) * .22;
      final energy = bandEnergy * spectralEnvelope.clamp(.42, 1.18);
      final y =
          bounds.center.dy +
          (primary + detail) *
              amplitude *
              energy *
              softAbsorb *
              (.45 + rightFade * .55);
      if (!started) {
        path.moveTo(x, y);
        started = true;
      } else {
        path.lineTo(x, y);
      }
    }
    return path;
  }

  double _bandEnergy(
    double phase, {
    required double speed,
    required double offset,
  }) {
    final fundamental = math.sin(phase * speed + offset);
    final harmonic = math.sin(phase * (speed * 2.37) - offset * .7);
    final transient = math.pow(
      math.max(0.0, math.sin(phase * (speed * .54) + offset * 1.8)),
      3,
    );
    return (.7 + fundamental * .16 + harmonic * .08 + transient * .2).clamp(
      .48,
      1.12,
    );
  }

  void _drawUnplayedWave(
    Canvas canvas,
    Path path, {
    required Color color,
    required double strokeWidth,
    required double baseOpacity,
  }) {
    if (path.getBounds().width <= 0) {
      return;
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color.withValues(alpha: baseOpacity * 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.4),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = color.withValues(alpha: baseOpacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  void _drawPlayedSegment(
    Canvas canvas, {
    required Rect bounds,
    required double progressX,
    required bool emphasized,
  }) {
    final endX = progressX.clamp(bounds.left, bounds.right);
    if (endX - bounds.left <= 0.5) {
      return;
    }
    final y = bounds.center.dy;
    // Flat played track — no vertical motion so the head never looks offset.
    final glow = Paint()
      ..shader = LinearGradient(
        colors: [
          primary.withValues(alpha: .4),
          secondary.withValues(alpha: .6),
          pearl.withValues(alpha: .7),
        ],
      ).createShader(Rect.fromLTRB(bounds.left, y - 4, endX, y + 4))
      ..strokeWidth = emphasized ? 4.2 : 3.4
      ..strokeCap = StrokeCap.round
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, emphasized ? 4.5 : 3.2);
    canvas.drawLine(Offset(bounds.left, y), Offset(endX, y), glow);

    final core = Paint()
      ..shader = LinearGradient(
        colors: [primary, secondary, pearl],
      ).createShader(Rect.fromLTRB(bounds.left, y - 2, endX, y + 2))
      ..strokeWidth = emphasized ? 2.6 : 2.15
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(bounds.left, y), Offset(endX, y), core);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 14 || size.height <= 0) {
      return;
    }
    final emphasized = isBuffering || isSeeking;
    final value = progress.clamp(0.0, 1.0);
    final bounds = Rect.fromLTRB(7, 2, size.width - 7, size.height - 2);
    final phase = animationPhase * math.pi * 2;
    final activity = emphasized ? 1.18 : (isPlaying ? 1.0 : .55);
    final lowEnergy = _bandEnergy(phase, speed: .72, offset: .2);
    final midEnergy = _bandEnergy(phase, speed: 1.08, offset: 2.1);
    final highEnergy = _bandEnergy(phase, speed: 1.56, offset: 4.35);
    final progressX = bounds.left + bounds.width * value;

    // Quiet baseline under the whole bar.
    canvas.drawLine(
      Offset(bounds.left, bounds.center.dy),
      Offset(bounds.right, bounds.center.dy),
      Paint()
        ..color = const Color(0x1AFFFFFF)
        ..strokeWidth = .75,
    );

    // Played: flat gradient line into the head (no wave → no head offset).
    _drawPlayedSegment(
      canvas,
      bounds: bounds,
      progressX: progressX,
      emphasized: emphasized,
    );

    // Unplayed: waves that start at 0 amplitude on the head and bloom after.
    final purplePath = _unplayedWavePath(
      bounds,
      progressX: progressX,
      amplitude: 5.5 * activity,
      frequency: 1.08,
      phase: phase * .42,
      bandEnergy: lowEnergy,
      spectrumOffset: .2,
    );
    final bluePath = _unplayedWavePath(
      bounds,
      progressX: progressX,
      amplitude: 6.2 * activity,
      frequency: 1.55,
      phase: math.pi * .72 - phase * .32,
      bandEnergy: midEnergy,
      spectrumOffset: 2.1,
    );
    final pearlPath = _unplayedWavePath(
      bounds,
      progressX: progressX,
      amplitude: 4.4 * activity,
      frequency: 2.05,
      phase: math.pi * 1.24 + phase * .24,
      bandEnergy: highEnergy,
      spectrumOffset: 4.35,
    );

    _drawUnplayedWave(
      canvas,
      purplePath,
      color: primary,
      strokeWidth: 2,
      baseOpacity: .38,
    );
    _drawUnplayedWave(
      canvas,
      bluePath,
      color: secondary,
      strokeWidth: 1.55,
      baseOpacity: .32,
    );
    _drawUnplayedWave(
      canvas,
      pearlPath,
      color: pearl,
      strokeWidth: 1.1,
      baseOpacity: .46,
    );

    final head = Offset(progressX, bounds.center.dy);
    final headRadius = emphasized ? 5.25 : 4.5;
    canvas.drawCircle(
      head,
      emphasized ? 7.5 : 6.25,
      Paint()
        ..color = const Color(0xB3FFFFFF)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, emphasized ? 6 : 4.5),
    );
    canvas.drawCircle(head, headRadius, Paint()..color = Colors.white);
    canvas.drawCircle(
      head,
      headRadius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = .65
        ..color = const Color(0xD9FFFFFF),
    );
  }

  @override
  bool shouldRepaint(covariant _PlayerProgressPainter oldDelegate) {
    return progress != oldDelegate.progress ||
        animationPhase != oldDelegate.animationPhase ||
        isPlaying != oldDelegate.isPlaying ||
        isBuffering != oldDelegate.isBuffering ||
        isSeeking != oldDelegate.isSeeking ||
        primary != oldDelegate.primary ||
        secondary != oldDelegate.secondary ||
        pearl != oldDelegate.pearl;
  }
}

class _EmptyNowPlaying extends StatelessWidget {
  const _EmptyNowPlaying();

  @override
  Widget build(BuildContext context) {
    return const FeatureMessageState(
      key: ValueKey('empty-now-playing'),
      icon: Icons.music_off_rounded,
      title: '暂无正在播放',
      subtitle: '从“我喜欢”、推荐或歌单中选择一首歌曲',
    );
  }
}

class _ArtworkView extends StatelessWidget {
  const _ArtworkView({
    required this.album,
    required this.rotationDelta,
    super.key,
  });

  final Album album;
  final double rotationDelta;

  @override
  Widget build(BuildContext context) {
    final tilt = rotationDelta == 0 ? 0.0 : rotationDelta.sign * math.pi / 60;
    final matrix = Matrix4.identity()
      ..setEntry(3, 2, .001)
      ..rotateX(tilt)
      ..rotateY(-tilt)
      ..scaleByDouble(
        rotationDelta == 0 ? 1 : .95,
        rotationDelta == 0 ? 1 : .95,
        1,
        1,
      );
    return LayoutBuilder(
      builder: (context, constraints) {
        final available = math.min(
          constraints.maxWidth * .72,
          constraints.maxHeight * .88,
        );
        final size = available.isFinite ? available.clamp(72.0, 220.0) : 160.0;
        return Align(
          alignment: const Alignment(0, .28),
          child: AnimatedContainer(
            key: const ValueKey('player-artwork'),
            duration: const Duration(milliseconds: 100),
            width: size,
            height: size,
            transform: matrix,
            transformAlignment: Alignment.center,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(24)),
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: ArtworkImage(
                    imageUrl: album.imageUrl,
                    cacheWidth: 220,
                    cacheHeight: 220,
                  ),
                ),
                IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0x24FFFFFF)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _LyricsView extends StatefulWidget {
  const _LyricsView({
    required this.lyrics,
    required this.position,
    required this.isLoading,
    required this.isPlaying,
    required this.isSeeking,
    super.key,
  });

  final QqMusicLyrics? lyrics;
  final Duration position;
  final bool isLoading;
  final bool isPlaying;
  final bool isSeeking;

  @override
  State<_LyricsView> createState() => _LyricsViewState();
}

class _LyricsViewState extends State<_LyricsView>
    with SingleTickerProviderStateMixin {
  static const _baseItemExtent = 38.0;
  static const _maxClockDrift = Duration(milliseconds: 320);
  final ScrollController _scrollController = ScrollController();
  late final Ticker _ticker;
  int _activeIndex = 0;
  int _previousActiveIndex = 0;
  Duration _displayPosition = Duration.zero;
  Duration _positionAnchor = Duration.zero;
  Duration _tickerAnchor = Duration.zero;
  Duration _lastTickElapsed = Duration.zero;
  Duration? _lineTransitionStartedAt;
  late bool _lyricsHaveWordTimeline;

  bool get _requiresContinuousTicker =>
      widget.isPlaying && _lyricsHaveWordTimeline;

  @override
  void initState() {
    super.initState();
    _displayPosition = widget.position;
    _positionAnchor = widget.position;
    _ticker = createTicker(_handleTick);
    _lyricsHaveWordTimeline =
        widget.lyrics?.lines.any((line) => line.hasWordTimeline) ?? false;
    _activeIndex = _activeLineIndex(_displayPosition);
    _previousActiveIndex = _activeIndex;
    if (_requiresContinuousTicker) {
      _ensureTicker();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _centerActive(false));
  }

  @override
  void didUpdateWidget(_LyricsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final lyricsChanged = oldWidget.lyrics != widget.lyrics;
    if (lyricsChanged) {
      _lyricsHaveWordTimeline =
          widget.lyrics?.lines.any((line) => line.hasWordTimeline) ?? false;
    }
    final playbackChanged = oldWidget.isPlaying != widget.isPlaying;
    final seekingChanged = oldWidget.isSeeking != widget.isSeeking;
    final drift = (widget.position - _displayPosition).abs();
    final shouldCalibrate =
        lyricsChanged ||
        playbackChanged ||
        seekingChanged ||
        widget.isSeeking ||
        !_requiresContinuousTicker ||
        drift > _maxClockDrift;
    if (shouldCalibrate) {
      _setClockAnchor(widget.position);
    }
    if (_requiresContinuousTicker) {
      _ensureTicker();
    }
    _updateActiveLine(lyricsChanged: lyricsChanged);
    _stopTickerIfIdle();
  }

  void _setClockAnchor(Duration position) {
    _positionAnchor = position;
    _displayPosition = position;
    _tickerAnchor = _lastTickElapsed;
  }

  void _ensureTicker() {
    if (_ticker.isActive) {
      return;
    }
    _lastTickElapsed = Duration.zero;
    _tickerAnchor = Duration.zero;
    _positionAnchor = _displayPosition;
    _ticker.start();
  }

  double get _lineTransitionProgress {
    final startedAt = _lineTransitionStartedAt;
    if (startedAt == null) {
      return 1;
    }
    final elapsed = _lastTickElapsed - startedAt;
    return (elapsed.inMicroseconds / AppDurations.lyricLine.inMicroseconds)
        .clamp(0.0, 1.0);
  }

  void _stopTickerIfIdle() {
    if (_requiresContinuousTicker || _lineTransitionProgress < 1) {
      return;
    }
    _lineTransitionStartedAt = null;
    if (_ticker.isActive) {
      _ticker.stop();
    }
  }

  void _handleTick(Duration elapsed) {
    if (!mounted) {
      return;
    }
    _lastTickElapsed = elapsed;
    setState(() {
      if (_requiresContinuousTicker) {
        _displayPosition = _positionAnchor + elapsed - _tickerAnchor;
      }
      _updateActiveLine();
    });
    _stopTickerIfIdle();
  }

  void _updateActiveLine({bool lyricsChanged = false}) {
    final nextIndex = _activeLineIndex(_displayPosition);
    if (lyricsChanged) {
      _previousActiveIndex = nextIndex;
      _activeIndex = nextIndex;
      _lineTransitionStartedAt = null;
      WidgetsBinding.instance.addPostFrameCallback((_) => _centerActive(false));
      return;
    }
    if (nextIndex == _activeIndex) {
      return;
    }
    final adjacent = !widget.isSeeking && (nextIndex - _activeIndex).abs() == 1;
    _previousActiveIndex = adjacent ? _activeIndex : nextIndex;
    _activeIndex = nextIndex;
    if (adjacent) {
      _ensureTicker();
      _lineTransitionStartedAt = _lastTickElapsed;
    } else {
      _lineTransitionStartedAt = null;
    }
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _centerActive(!widget.isSeeking),
    );
  }

  int _activeLineIndex(Duration position) {
    final lines = widget.lyrics?.lines ?? const <QqMusicLyricLine>[];
    if (lines.isEmpty) {
      return 0;
    }
    // Walk from the last known line instead of rescanning the whole lyric on
    // every ticker frame; seeking walks backwards from the same anchor.
    var active = _activeIndex.clamp(0, lines.length - 1);
    if (lines[active].time > position) {
      while (active > 0 && lines[active].time > position) {
        active -= 1;
      }
      return active;
    }
    while (active + 1 < lines.length && lines[active + 1].time <= position) {
      active += 1;
    }
    return active;
  }

  /// Lyric rows grow with the text scale: a scaled two-line lyric must not be
  /// clipped by a fixed 38px extent.
  double _itemExtent(BuildContext context) {
    final scaled = MediaQuery.textScalerOf(context).scale(_baseItemExtent);
    return scaled.clamp(_baseItemExtent, _baseItemExtent * 2.2);
  }

  void _centerActive(bool animate) {
    if (!_scrollController.hasClients) {
      return;
    }
    final position = _scrollController.position;
    final target = (_activeIndex * _itemExtent(context))
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (animate && !reduceMotion) {
      final adjacent = (_activeIndex - _previousActiveIndex).abs() <= 1;
      _scrollController.animateTo(
        target,
        duration: adjacent ? AppDurations.lyricScroll : AppDurations.emphasized,
        curve: adjacent ? AppCurves.lyricScroll : AppCurves.movementEase,
      );
    } else {
      _scrollController.jumpTo(target);
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: AppColors.interaction,
          strokeWidth: 2,
        ),
      );
    }
    final lines = widget.lyrics?.lines ?? const <QqMusicLyricLine>[];
    if (lines.isEmpty) {
      return const Center(
        child: Text(
          '暂无歌词',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
            height: 19 / 14,
            fontWeight: AppTextStyles.regular,
          ),
        ),
      );
    }
    return ShaderMask(
      shaderCallback: (bounds) => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0x00FFFFFF),
          Color(0xFFFFFFFF),
          Color(0xFFFFFFFF),
          Color(0x00FFFFFF),
        ],
        stops: [0, .14, .86, 1],
      ).createShader(bounds),
      blendMode: BlendMode.dstIn,
      // No side scrollbar on lyrics — only the vertical fade mask above.
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final itemExtent = _itemExtent(context);
            final centerPadding = math.max(
              0.0,
              (constraints.maxHeight - itemExtent) / 2,
            );
            return ListView.builder(
              key: const ValueKey('lyrics-scroll-list'),
              controller: _scrollController,
              itemExtent: itemExtent,
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.symmetric(vertical: centerPadding),
              itemCount: lines.length,
              itemBuilder: (context, index) {
                final active = index == _activeIndex;
                final previous = index == _previousActiveIndex && !active;
                final lineTransition = _lineTransitionProgress;
                return _LyricLineText(
                  key: ValueKey('lyric-line-$index'),
                  line: lines[index],
                  position: _displayPosition,
                  active: active,
                  previous: previous,
                  relativeIndex: index - _activeIndex,
                  lineTransition: lineTransition,
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _LyricsTrackMetadata extends StatelessWidget {
  const _LyricsTrackMetadata({required this.title, required this.artist});

  final String title;
  final String artist;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Flexible(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: AppTextStyles.label.copyWith(fontSize: 18, height: 1.1),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 7),
              child: Text(
                '·',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 15,
                  height: 15 / 11,
                  fontWeight: AppTextStyles.regular,
                ),
              ),
            ),
            Flexible(
              child: Text(
                artist,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.left,
                style: AppTextStyles.body.copyWith(height: 1.1),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.tooltip,
    required this.active,
    this.activeColor = AppColors.interaction,
    this.dimension = 44,
    this.onPressed,
    super.key,
  });

  final IconData icon;
  final String tooltip;
  final bool active;
  final Color activeColor;
  final double dimension;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final color = active ? activeColor : AppColors.textSecondary;
    final iconSize = dimension <= 36 ? 18.0 : 22.0;
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        child: InkResponse(
          onTap: onPressed,
          radius: dimension * .64,
          child: SizedBox.square(
            dimension: dimension,
            child: Center(
              child: Icon(icon, color: color, size: iconSize),
            ),
          ),
        ),
      ),
    );
  }
}

String _formatDuration(Duration value) {
  final safe = value.isNegative ? Duration.zero : value;
  final minutes = safe.inMinutes;
  final seconds = safe.inSeconds.remainder(60);
  return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
}

class _LyricLineText extends StatelessWidget {
  const _LyricLineText({
    required this.line,
    required this.position,
    required this.active,
    required this.previous,
    required this.relativeIndex,
    required this.lineTransition,
    super.key,
  });

  final QqMusicLyricLine line;
  final Duration position;
  final bool active;
  final bool previous;
  final int relativeIndex;
  final double lineTransition;

  /// First-commit (df3d87e) word progress: runes + intra-word linear fill.
  double get _wordProgress {
    if (!line.hasWordTimeline) {
      return 0;
    }
    if (previous) {
      return 1;
    }
    if (!active) {
      return 0;
    }
    final totalLength = line.words.fold<int>(
      0,
      (length, word) => length + word.text.runes.length,
    );
    if (totalLength == 0) {
      return 0;
    }
    var completedLength = 0.0;
    for (final word in line.words) {
      final wordLength = word.text.runes.length;
      if (position >= word.endTime) {
        completedLength += wordLength;
        continue;
      }
      if (position > word.time && word.duration.inMilliseconds > 0) {
        final elapsed = position - word.time;
        final progress = elapsed.inMilliseconds / word.duration.inMilliseconds;
        completedLength += wordLength * progress.clamp(0.0, 1.0);
      }
      break;
    }
    return (completedLength / totalLength).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final transition = AppCurves.lyricLine.transform(lineTransition);
    final entering = active ? transition : 1.0;
    final leaving = previous ? transition : 1.0;
    final distance = relativeIndex.abs();
    final scale = active
        ? .76 + .24 * entering
        : previous
        ? 1.0 - .24 * leaving
        : .76;
    final opacity = active
        ? .72 + .28 * entering
        : previous
        ? 1.0 - .52 * leaving
        : distance == 1
        ? .48
        : .34;
    final offset = active
        ? Offset(0, .1 * (1 - entering))
        : previous
        ? Offset(0, -.1 * leaving)
        : Offset(0, relativeIndex < 0 ? -.1 : .1);
    final style = TextStyle(
      color: line.hasWordTimeline && (active || previous)
          ? const Color(0x66FFFFFF)
          : Colors.white,
      fontSize: 17,
      fontWeight: FontWeight.w800,
      height: 1.15,
      letterSpacing: .15,
    );
    Widget lyricText(
      TextStyle resolvedStyle, {
      double? highlightProgress,
      Key? highlightKey,
    }) {
      return _LyricTextLayer(
        text: line.text,
        style: resolvedStyle,
        highlightProgress: highlightProgress,
        highlightKey: highlightKey,
      );
    }

    // First-commit delayed reveal during line enter.
    final highlightReveal = active
        ? ((lineTransition - .18) / .37).clamp(0.0, 1.0)
        : previous
        ? 1 - transition
        : 0.0;
    return FractionalTranslation(
      translation: offset,
      child: Opacity(
        opacity: opacity,
        child: Transform.scale(
          scale: scale,
          child: DefaultTextStyle(
            style: style,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (active)
                      const SizedBox.shrink(key: ValueKey('active-lyric-line')),
                    lyricText(const TextStyle()),
                    if ((active || previous) && line.hasWordTimeline)
                      Opacity(
                        key: active
                            ? const ValueKey('active-lyric-highlight-reveal')
                            : null,
                        opacity: highlightReveal,
                        child: lyricText(
                          style.copyWith(color: Colors.white),
                          highlightProgress: _wordProgress,
                          highlightKey: active
                              ? const ValueKey('active-lyric-progress')
                              : null,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LyricTextLayer extends StatelessWidget {
  const _LyricTextLayer({
    required this.text,
    required this.style,
    this.highlightProgress,
    this.highlightKey,
  });

  final String text;
  final TextStyle style;
  final double? highlightProgress;
  final Key? highlightKey;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final resolvedStyle = DefaultTextStyle.of(context).style.merge(style);
        final ranges = _resolveLineRanges(
          text: text,
          style: resolvedStyle,
          maxWidth: constraints.maxWidth,
          textScaler: MediaQuery.textScalerOf(context),
          textDirection: Directionality.of(context),
        );
        final totalLength = text.runes.length;
        final progress = highlightProgress?.clamp(0.0, 1.0).toDouble();
        var rangeIndex = 0;
        final children = <Widget>[];
        for (final range in ranges) {
          final lineText = text.substring(range.start, range.end);
          final lineLength = lineText.runes.length;
          final lineStart = text.substring(0, range.start).runes.length;
          final lineProgress = totalLength == 0 || lineLength == 0
              ? 0.0
              : ((progress ?? 0) * totalLength - lineStart) / lineLength;
          Widget child = Text(
            lineText,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
            style: style,
          );
          if (progress != null) {
            child = ShaderMask(
              key: rangeIndex == 0 ? highlightKey : null,
              blendMode: BlendMode.dstIn,
              shaderCallback: (bounds) =>
                  _lyricProgressShader(bounds, lineProgress),
              child: child,
            );
          }
          children.add(child);
          rangeIndex++;
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: children,
        );
      },
    );
  }
}

/// Lyric line breaking is stable for a given text, style, width and text
/// scale, so it is measured once instead of on every ticker frame.
final Map<_LyricLayoutKey, List<TextRange>> _lyricRangeCache =
    <_LyricLayoutKey, List<TextRange>>{};
const int _lyricRangeCacheLimit = 240;

@immutable
class _LyricLayoutKey {
  const _LyricLayoutKey({
    required this.text,
    required this.style,
    required this.maxWidth,
    required this.textScale,
  });

  final String text;
  final TextStyle style;
  final double maxWidth;
  final double textScale;

  @override
  bool operator ==(Object other) {
    return other is _LyricLayoutKey &&
        other.text == text &&
        other.style == style &&
        other.maxWidth == maxWidth &&
        other.textScale == textScale;
  }

  @override
  int get hashCode => Object.hash(text, style, maxWidth, textScale);
}

List<TextRange> _resolveLineRanges({
  required String text,
  required TextStyle style,
  required double maxWidth,
  required TextScaler textScaler,
  required TextDirection textDirection,
}) {
  final key = _LyricLayoutKey(
    text: text,
    style: style,
    maxWidth: maxWidth.roundToDouble(),
    textScale: textScaler.scale(100),
  );
  final cached = _lyricRangeCache[key];
  if (cached != null) {
    return cached;
  }
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textAlign: TextAlign.center,
    textDirection: textDirection,
    textScaler: textScaler,
    maxLines: 2,
    ellipsis: '…',
  )..layout(maxWidth: maxWidth);
  final ranges = _visualLineRanges(painter, text);
  painter.dispose();
  if (_lyricRangeCache.length >= _lyricRangeCacheLimit) {
    _lyricRangeCache.remove(_lyricRangeCache.keys.first);
  }
  _lyricRangeCache[key] = ranges;
  return ranges;
}

List<TextRange> _visualLineRanges(TextPainter painter, String text) {
  final ranges = <TextRange>[];
  var offset = 0;
  for (final _ in painter.computeLineMetrics()) {
    if (offset >= text.length) {
      break;
    }
    final boundary = painter.getLineBoundary(TextPosition(offset: offset));
    final boundaryEnd = boundary.end.clamp(offset + 1, text.length).toInt();
    var lineEnd = boundaryEnd;
    while (lineEnd > offset &&
        (text.codeUnitAt(lineEnd - 1) == 10 ||
            text.codeUnitAt(lineEnd - 1) == 13)) {
      lineEnd--;
    }
    if (lineEnd > offset) {
      ranges.add(TextRange(start: offset, end: lineEnd));
    }
    offset = boundaryEnd;
  }
  if (ranges.isEmpty && text.isNotEmpty) {
    ranges.add(TextRange(start: 0, end: text.length));
  }
  return ranges;
}

Shader _lyricProgressShader(Rect bounds, double progress) {
  final value = progress.clamp(0.0, 1.0);
  if (value <= 0) {
    return const LinearGradient(
      colors: [Colors.transparent, Colors.transparent],
    ).createShader(bounds);
  }
  if (value >= 1) {
    return const LinearGradient(
      colors: [Colors.white, Colors.white],
    ).createShader(bounds);
  }
  final softStart = (value - .055).clamp(0.0, 1.0);
  final softEnd = (value + .018).clamp(0.0, 1.0);
  return LinearGradient(
    colors: const [
      Colors.white,
      Colors.white,
      Color(0x00FFFFFF),
      Color(0x00FFFFFF),
    ],
    stops: [0, softStart, softEnd, 1],
  ).createShader(bounds);
}

const _timeStyle = TextStyle(
  color: Color(0x80FFFFFF),
  fontSize: 12,
  fontWeight: FontWeight.w700,
);
