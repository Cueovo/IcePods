import 'dart:math' as math;

import 'package:flutter/material.dart';

class ClickWheel extends StatefulWidget {
  const ClickWheel({
    required this.onRotate,
    required this.onRotationEnd,
    required this.onCenter,
    required this.onMenu,
    required this.onPrevious,
    required this.onNext,
    required this.onPlayPause,
    required this.isPlaying,
    super.key,
  });

  final ValueChanged<double> onRotate;
  final VoidCallback onRotationEnd;
  final VoidCallback onCenter;
  final VoidCallback onMenu;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onPlayPause;
  final bool isPlaying;

  @override
  State<ClickWheel> createState() => _ClickWheelState();
}

class _ClickWheelState extends State<ClickWheel> {
  int? _activePointer;
  Offset? _pointerDownPosition;
  double? _lastAngle;
  bool _ringPointer = false;
  bool _tapEligible = false;
  bool _rotating = false;

  double _angleFor(Offset position) {
    return math.atan2(position.dy - 140, position.dx - 140) * 180 / math.pi;
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (_activePointer != null) {
      return;
    }
    final offset = event.localPosition - const Offset(140, 140);
    final radius = offset.distance;
    if (radius > 140) {
      return;
    }
    _activePointer = event.pointer;
    _pointerDownPosition = event.localPosition;
    _ringPointer = radius >= 56;
    _tapEligible = true;
    _rotating = false;
    _lastAngle = _ringPointer ? _angleFor(event.localPosition) : null;
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (event.pointer != _activePointer || _pointerDownPosition == null) {
      return;
    }
    if ((event.localPosition - _pointerDownPosition!).distance > 8) {
      _tapEligible = false;
    }
    if (!_ringPointer || _lastAngle == null || _tapEligible) {
      return;
    }
    _rotating = true;
    final currentAngle = _angleFor(event.localPosition);
    var delta = currentAngle - _lastAngle!;
    if (delta > 180) {
      delta -= 360;
    } else if (delta < -180) {
      delta += 360;
    }
    widget.onRotate(delta);
    _lastAngle = currentAngle;
  }

  void _handleTap(Offset position) {
    final offset = position - const Offset(140, 140);
    final radius = offset.distance;
    if (radius > 140) {
      return;
    }
    if (radius < 56) {
      widget.onCenter();
      return;
    }
    if (offset.dy.abs() >= offset.dx.abs()) {
      if (offset.dy < 0) {
        widget.onMenu();
      } else {
        widget.onPlayPause();
      }
    } else if (offset.dx < 0) {
      widget.onPrevious();
    } else {
      widget.onNext();
    }
  }

  void _resetPointer() {
    _activePointer = null;
    _pointerDownPosition = null;
    _lastAngle = null;
    _ringPointer = false;
    _tapEligible = false;
    _rotating = false;
  }

  void _handlePointerUp(PointerUpEvent event) {
    if (event.pointer != _activePointer) {
      return;
    }
    final shouldTap = _tapEligible && !_rotating;
    final didRotate = _rotating;
    _resetPointer();
    if (didRotate) {
      widget.onRotationEnd();
    } else if (shouldTap) {
      _handleTap(event.localPosition);
    }
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    if (event.pointer != _activePointer) {
      return;
    }
    final didRotate = _rotating;
    _resetPointer();
    if (didRotate) {
      widget.onRotationEnd();
    }
  }

  @override
  Widget build(BuildContext context) {
    const iconColor = Color(0xE6FFFFFF);
    return Listener(
      key: const ValueKey('center-button'),
      behavior: HitTestBehavior.opaque,
      onPointerDown: _handlePointerDown,
      onPointerMove: _handlePointerMove,
      onPointerUp: _handlePointerUp,
      onPointerCancel: _handlePointerCancel,
      child: SizedBox(
        width: 280,
        height: 280,
        child: Stack(
          alignment: Alignment.center,
          children: [
            IgnorePointer(
              child: Container(
                width: 300,
                height: 300,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Color(0x33FFFFFF),
                      Color(0x14000000),
                      Color(0x00000000),
                    ],
                    stops: [0.42, 0.72, 1],
                  ),
                ),
              ),
            ),
            Container(
              key: const ValueKey('click-wheel'),
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const RadialGradient(
                  center: Alignment(-0.28, -0.32),
                  radius: 1.08,
                  colors: [
                    Color(0x66FFFFFF),
                    Color(0x3DFFFFFF),
                    Color(0x1AFFFFFF),
                  ],
                  stops: [0, 0.55, 1],
                ),
                border: Border.all(color: const Color(0xB3FFFFFF), width: 1.5),
              ),
              child: Container(
                margin: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0x33FFFFFF)),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0x38FFFFFF),
                      Color(0x12FFFFFF),
                      Color(0x08000000),
                    ],
                    stops: [0, 0.5, 1],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 8,
              child: _WheelButton(
                key: const ValueKey('menu-button'),
                label: '返回菜单',
                onTap: widget.onMenu,
                child: const Text(
                  'MENU',
                  style: TextStyle(
                    color: iconColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ),
            Positioned(
              left: 8,
              top: 108,
              child: _WheelButton(
                label: '上一首',
                onTap: widget.onPrevious,
                child: const Icon(
                  Icons.fast_rewind_rounded,
                  color: iconColor,
                  size: 22,
                ),
              ),
            ),
            Positioned(
              right: 8,
              top: 108,
              child: _WheelButton(
                label: '下一首',
                onTap: widget.onNext,
                child: const Icon(
                  Icons.fast_forward_rounded,
                  color: iconColor,
                  size: 22,
                ),
              ),
            ),
            Positioned(
              bottom: 8,
              child: _WheelButton(
                label: widget.isPlaying ? '暂停' : '播放',
                onTap: widget.onPlayPause,
                child: Icon(
                  widget.isPlaying
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  color: iconColor,
                  size: 22,
                ),
              ),
            ),
            Semantics(
              button: true,
              label: '确认',
              onTap: widget.onCenter,
              child: IgnorePointer(
                child: SizedBox(
                  width: 112,
                  height: 112,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 112,
                        height: 112,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            center: Alignment(0, 0.15),
                            radius: 0.72,
                            colors: [
                              Color(0x00000000),
                              Color(0x1A000000),
                              Color(0x33000000),
                              Color(0x00000000),
                            ],
                            stops: [0.52, 0.62, 0.78, 1],
                          ),
                        ),
                      ),
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const RadialGradient(
                            center: Alignment(-0.3, -0.35),
                            radius: 1.1,
                            colors: [
                              Color(0x8CFFFFFF),
                              Color(0x4DFFFFFF),
                              Color(0x26FFFFFF),
                            ],
                            stops: [0, 0.55, 1],
                          ),
                          border: Border.all(
                            color: const Color(0xCCFFFFFF),
                            width: 1.5,
                          ),
                        ),
                        child: const Center(
                          child: SizedBox(
                            width: 8,
                            height: 8,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: Color(0xE6FFFFFF),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WheelButton extends StatelessWidget {
  const _WheelButton({
    required this.label,
    required this.onTap,
    required this.child,
    super.key,
  });

  final String label;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      onTap: onTap,
      child: IgnorePointer(
        child: SizedBox(width: 72, height: 64, child: Center(child: child)),
      ),
    );
  }
}
