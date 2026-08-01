import 'dart:math' as math;
import 'package:flutter/material.dart';

import 'package:qqmusic_ipod/core/theme/tokens/app_tokens.dart';

/// Release snaps back faster than the press settles, like a real dome switch.
const Duration _releaseDuration = Duration(milliseconds: 80);

/// The sector currently held down, used only for visual feedback.
enum _WheelPress { none, menu, previous, next, playPause, center }

/// 带有拟物化质感，且底部按钮支持播放/暂停动态切换的 Click Wheel。
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
  static const double _size = 300;
  static const double _center = _size / 2;
  static const double _centerRadius = 50;
  static const double _ringHitMin = 52;

  int? _activePointer;
  Offset? _pointerDownPosition;
  double? _lastAngle;
  bool _ringPointer = false;
  bool _tapEligible = false;
  bool _rotating = false;
  _WheelPress _pressed = _WheelPress.none;

  double _angleFor(Offset position) {
    return math.atan2(position.dy - _center, position.dx - _center) *
        180 /
        math.pi;
  }

  /// Resolves the sector under [position] using the same geometry as the tap
  /// dispatcher, so pressed feedback can never disagree with the action.
  _WheelPress _sectorFor(Offset position) {
    final offset = position - const Offset(_center, _center);
    final radius = offset.distance;
    if (radius > _center) {
      return _WheelPress.none;
    }
    if (radius < _ringHitMin) {
      return _WheelPress.center;
    }
    if (offset.dy.abs() >= offset.dx.abs()) {
      return offset.dy < 0 ? _WheelPress.menu : _WheelPress.playPause;
    }
    return offset.dx < 0 ? _WheelPress.previous : _WheelPress.next;
  }

  void _setPressed(_WheelPress next) {
    if (_pressed == next) {
      return;
    }
    setState(() => _pressed = next);
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (_activePointer != null) {
      return;
    }
    final offset = event.localPosition - const Offset(_center, _center);
    final radius = offset.distance;
    if (radius > _center) {
      return;
    }
    _activePointer = event.pointer;
    _pointerDownPosition = event.localPosition;
    _ringPointer = radius >= _ringHitMin;
    _tapEligible = true;
    _rotating = false;
    _lastAngle = _ringPointer ? _angleFor(event.localPosition) : null;
    _setPressed(_sectorFor(event.localPosition));
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (event.pointer != _activePointer || _pointerDownPosition == null) {
      return;
    }
    if ((event.localPosition - _pointerDownPosition!).distance > 8) {
      _tapEligible = false;
      // The gesture is a rotation or a slide, not a press.
      _setPressed(_WheelPress.none);
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
    switch (_sectorFor(position)) {
      case _WheelPress.none:
        return;
      case _WheelPress.center:
        widget.onCenter();
      case _WheelPress.menu:
        widget.onMenu();
      case _WheelPress.playPause:
        widget.onPlayPause();
      case _WheelPress.previous:
        widget.onPrevious();
      case _WheelPress.next:
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
    _setPressed(_WheelPress.none);
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
    // 经典的 iPod 按键暗灰色丝印颜色
    const labelColor = Color(0xFF6B6B73);
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    return Listener(
      key: const ValueKey('center-button'),
      behavior: HitTestBehavior.opaque,
      onPointerDown: _handlePointerDown,
      onPointerMove: _handlePointerMove,
      onPointerUp: _handlePointerUp,
      onPointerCancel: _handlePointerCancel,
      child: SizedBox(
        width: _size,
        height: _size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 1. 底层：灰色塑料触摸环 (The Wheel)
            IgnorePointer(
              child: Container(
                key: const ValueKey('click-wheel'),
                width: _size,
                height: _size,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFE5E5EA),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFFEBEBF0), // 柔和受光面
                      Color(0xFFE0E0E6), // 亚光基础色
                      Color(0xFFD4D4DA), // 柔和背光面
                    ],
                  ),
                  boxShadow: [
                    // 模拟面板与机身的缝隙（内陷的边缘阴影）
                    BoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 4,
                      spreadRadius: 0.5,
                      offset: Offset(0, 1),
                    ),
                    // 左上角的高光反光
                    BoxShadow(
                      color: Color(0x80FFFFFF),
                      blurRadius: 6,
                      spreadRadius: -2,
                      offset: Offset(-2, -2),
                    ),
                  ],
                ),
              ),
            ),

            // 2. 丝印图标与文字层
            // MENU
            Positioned(
              top: 14,
              child: _WheelButton(
                key: const ValueKey('menu-button'),
                label: '返回菜单',
                onTap: widget.onMenu,
                pressed: _pressed == _WheelPress.menu,
                reduceMotion: reduceMotion,
                child: const Text(
                  'MENU',
                  style: TextStyle(
                    color: labelColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.0,
                    height: 1,
                  ),
                ),
              ),
            ),
            // Previous (|<<)
            Positioned(
              left: 14,
              top: (_size - 64) / 2, // 垂直居中
              child: _WheelButton(
                label: '上一首',
                onTap: widget.onPrevious,
                pressed: _pressed == _WheelPress.previous,
                reduceMotion: reduceMotion,
                child: const Icon(
                  Icons.skip_previous_rounded,
                  color: labelColor,
                  size: 28,
                ),
              ),
            ),
            // Next (>>|)
            Positioned(
              right: 14,
              top: (_size - 64) / 2, // 垂直居中
              child: _WheelButton(
                label: '下一首',
                onTap: widget.onNext,
                pressed: _pressed == _WheelPress.next,
                reduceMotion: reduceMotion,
                child: const Icon(
                  Icons.skip_next_rounded,
                  color: labelColor,
                  size: 28,
                ),
              ),
            ),
            // Play / Pause (动态切换)
            Positioned(
              bottom: 14,
              child: _WheelButton(
                label: widget.isPlaying ? '暂停' : '播放',
                onTap: widget.onPlayPause,
                pressed: _pressed == _WheelPress.playPause,
                reduceMotion: reduceMotion,
                child: Icon(
                  widget.isPlaying
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  color: labelColor,
                  size: 32, // 稍微放大一点，视觉上与上/下首图标平衡
                ),
              ),
            ),

            // 3. 顶层：中心确认键 (Center Button)
            Semantics(
              button: true,
              label: '确认',
              onTap: widget.onCenter,
              child: IgnorePointer(
                child: _PressFeedback(
                  pressed: _pressed == _WheelPress.center,
                  reduceMotion: reduceMotion,
                  child: AnimatedContainer(
                    duration: _pressed == _WheelPress.center
                        ? AppDurations.press
                        : _releaseDuration,
                    curve: AppCurves.strongEaseOut,
                    width: _centerRadius * 2,
                    height: _centerRadius * 2,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFF9F9FB),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: _pressed == _WheelPress.center
                            ? const [
                                Color(0xFFF4F4F8),
                                Color(0xFFEBEBF1),
                                Color(0xFFDEDEE6),
                              ]
                            : const [
                                Color(0xFFFFFFFF),
                                Color(0xFFF4F4F8),
                                Color(0xFFE8E8EE),
                              ],
                      ),
                      // 模拟中心按键与转盘之间的物理间隙
                      border: Border.all(
                        color: const Color(0x1F000000),
                        width: 1.2,
                      ),
                      // Pressed domes sit closer to the panel: tighter shadow.
                      boxShadow: _pressed == _WheelPress.center
                          ? const [
                              BoxShadow(
                                color: Color(0x2E000000),
                                blurRadius: 2,
                                offset: Offset(0, 0.5),
                              ),
                            ]
                          : const [
                              BoxShadow(
                                color: Color(0x22000000),
                                blurRadius: 4,
                                offset: Offset(0, 1),
                              ),
                            ],
                    ),
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

/// Transform-only press response. Reduced motion keeps the color and shadow
/// change from the child but drops the scale.
class _PressFeedback extends StatelessWidget {
  const _PressFeedback({
    required this.pressed,
    required this.reduceMotion,
    required this.child,
  });

  final bool pressed;
  final bool reduceMotion;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (reduceMotion) {
      return child;
    }
    return AnimatedScale(
      scale: pressed ? 0.96 : 1,
      duration: pressed ? AppDurations.press : _releaseDuration,
      curve: AppCurves.strongEaseOut,
      child: child,
    );
  }
}

class _WheelButton extends StatelessWidget {
  const _WheelButton({
    required this.label,
    required this.onTap,
    required this.pressed,
    required this.reduceMotion,
    required this.child,
    super.key,
  });

  final String label;
  final VoidCallback onTap;
  final bool pressed;
  final bool reduceMotion;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      onTap: onTap,
      child: IgnorePointer(
        // Hit and semantic bounds stay 72x64 regardless of press feedback.
        child: SizedBox(
          width: 72,
          height: 64,
          child: Center(
            child: _PressFeedback(
              pressed: pressed,
              reduceMotion: reduceMotion,
              child: AnimatedContainer(
                duration: pressed ? AppDurations.press : _releaseDuration,
                curve: AppCurves.strongEaseOut,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: pressed ? const Color(0x14000000) : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                ),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
