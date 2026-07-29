import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';

import 'package:qqmusic_ipod/core/theme/tokens/app_tokens.dart';

const _splashPlaybackEnd = Duration(milliseconds: 1800);

class OpeningSequence extends StatefulWidget {
  const OpeningSequence({required this.child, super.key});

  final Widget child;

  @override
  State<OpeningSequence> createState() => _OpeningSequenceState();
}

class _OpeningSequenceState extends State<OpeningSequence> {
  bool _revealing = false;
  bool _removed = false;

  void _reveal() {
    if (!mounted || _revealing) {
      return;
    }
    setState(() => _revealing = true);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ExcludeSemantics(
          excluding: !_removed,
          child: IgnorePointer(ignoring: !_removed, child: widget.child),
        ),
        if (!_removed)
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedOpacity(
                opacity: _revealing ? 0 : 1,
                duration: AppDurations.splashExit,
                curve: AppCurves.strongEaseOut,
                onEnd: () {
                  if (_revealing && mounted) {
                    setState(() => _removed = true);
                  }
                },
                child: _JitterSplash(onFinished: _reveal),
              ),
            ),
          ),
      ],
    );
  }
}

class _JitterSplash extends StatefulWidget {
  const _JitterSplash({required this.onFinished});

  final VoidCallback onFinished;

  @override
  State<_JitterSplash> createState() => _JitterSplashState();
}

class _JitterSplashState extends State<_JitterSplash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this);
  bool _started = false;

  void _start(LottieComposition composition) {
    if (_started) {
      return;
    }
    _started = true;
    final reduced = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final compositionDuration = composition.duration;
    final playbackDuration =
        compositionDuration.inMilliseconds <= _splashPlaybackEnd.inMilliseconds
        ? compositionDuration
        : _splashPlaybackEnd;
    final target =
        playbackDuration.inMicroseconds / compositionDuration.inMicroseconds;
    _controller.duration = compositionDuration;

    if (reduced) {
      _controller.value = target;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          widget.onFinished();
        }
      });
      return;
    }

    _controller
        .animateTo(target, duration: playbackDuration, curve: Curves.linear)
        .whenComplete(() {
          if (mounted) {
            widget.onFinished();
          }
        });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemStatusBarContrastEnforced: false,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
        systemNavigationBarDividerColor: Colors.transparent,
        systemNavigationBarContrastEnforced: false,
      ),
      child: RepaintBoundary(
        child: Stack(
          fit: StackFit.expand,
          children: [
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0, -.12),
                  radius: 1.15,
                  colors: [
                    Color(0xFF2A2630),
                    Color(0xFF1A171C),
                    Color(0xFF08070A),
                  ],
                  stops: [0, .56, 1],
                ),
              ),
            ),
            SizedBox.expand(
              child: Lottie.asset(
                'assets/Scene.json',
                controller: _controller,
                animate: false,
                repeat: false,
                fit: BoxFit.cover,
                alignment: Alignment.center,
                onLoaded: _start,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
