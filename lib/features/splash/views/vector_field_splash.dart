import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const _kleinBlue = Color(0xFF002FA7);

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
                duration: const Duration(milliseconds: 480),
                curve: Curves.easeOutCubic,
                onEnd: () {
                  if (_revealing && mounted) {
                    setState(() => _removed = true);
                  }
                },
                child: _VectorFieldSplash(onFinished: _reveal),
              ),
            ),
          ),
      ],
    );
  }
}

class _VectorFieldSplash extends StatefulWidget {
  const _VectorFieldSplash({required this.onFinished});

  final VoidCallback onFinished;

  @override
  State<_VectorFieldSplash> createState() => _VectorFieldSplashState();
}

class _VectorFieldSplashState extends State<_VectorFieldSplash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this);
  Timer? _holdTimer;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) {
      return;
    }
    _started = true;
    final reduced = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    _controller.duration = Duration(milliseconds: reduced ? 1600 : 6500);
    _controller.forward().whenComplete(() {
      _holdTimer = Timer(
        Duration(milliseconds: reduced ? 120 : 420),
        widget.onFinished,
      );
    });
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
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
      child: ColoredBox(
        color: _kleinBlue,
        child: RepaintBoundary(
          child: CustomPaint(
            painter: _VectorFieldPainter(_controller),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
  }
}

class _VectorFieldPainter extends CustomPainter {
  _VectorFieldPainter(this.animation) : super(repaint: animation);

  final Animation<double> animation;

  static final List<_FlowSeed> _flow = _makeSeeds(1400, 481516);
  static final List<_FlowSeed> _dust = _makeSeeds(220, 815162);
  static final List<_FlowSeed> _burst = _makeSeeds(110, 151623);

  static List<_FlowSeed> _makeSeeds(int count, int seed) {
    final random = math.Random(seed);
    return List.generate(
      count,
      (_) => _FlowSeed(
        random.nextDouble(),
        random.nextDouble(),
        random.nextDouble(),
        random.nextDouble(),
      ),
      growable: false,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawColor(_kleinBlue, BlendMode.src);
    final t = animation.value;
    final unit = math.min(size.width, size.height * 9 / 16);
    final center = Offset(size.width / 2, size.height * .49);
    _paintDust(canvas, size, t);
    _paintFlow(canvas, size, center, unit, t);
    _paintShadow(canvas, center, unit, t);
    _paintSymbol(canvas, center, unit, t);
    _paintBurst(canvas, center, unit, t);
  }

  void _paintDust(Canvas canvas, Size size, double t) {
    final fade = 1 - _smooth(.1, .3, t);
    if (fade <= 0) {
      return;
    }
    final points = <Offset>[];
    for (final seed in _dust) {
      points.add(Offset(seed.x * size.width, seed.y * size.height));
    }
    canvas.drawPoints(
      ui.PointMode.points,
      points,
      Paint()
        ..color = Colors.white.withValues(alpha: .035 + fade * .045)
        ..strokeWidth = .7
        ..strokeCap = StrokeCap.round,
    );
  }

  void _paintFlow(
    Canvas canvas,
    Size size,
    Offset center,
    double unit,
    double t,
  ) {
    final reveal = _smooth(.07, .38, t);
    if (reveal <= 0) {
      return;
    }
    final phase = math.pow(_smooth(.08, .9, t), 1.45) * 5.1;
    final eye = _smooth(.54, .77, t);
    final paths = List.generate(5, (_) => Path());
    for (var i = 0; i < _flow.length; i++) {
      final seed = _flow[i];
      final base = Offset(seed.x * size.width, seed.y * size.height);
      final delta = base - center;
      final radius = delta.distance;
      final radiusUnit = (radius / (unit * .78)).clamp(0.0, 1.8);
      final angle =
          math.atan2(delta.dy, delta.dx) +
          phase * (.24 + (1 - radiusUnit.clamp(0.0, 1.0)) * .55) +
          math.sin(seed.phase * math.pi * 2 + phase) * .08;
      final wave =
          math.sin(radiusUnit * 13 - phase * 2.2 + seed.phase * 6) *
          unit *
          .012 *
          reveal;
      final animatedRadius = radius + wave;
      var point =
          center + Offset(math.cos(angle), math.sin(angle)) * animatedRadius;
      final ex = (point.dx - center.dx) / (unit * .29);
      final ey = (point.dy - center.dy) / (unit * .17);
      final ellipse = math.sqrt(ex * ex + ey * ey);
      var eyeAlpha = 1.0;
      if (ellipse < 1.22) {
        eyeAlpha = 1 - eye * (1 - _smooth(.72, 1.22, ellipse));
        final push = eye * (1.22 - ellipse) * unit * .055;
        final direction = point == center
            ? const Offset(0, -1)
            : (point - center) / (point - center).distance;
        point += direction * push;
      }
      final tangent = Offset(-math.sin(angle), math.cos(angle));
      final drift = Offset(
        math.cos(seed.phase * 9 + phase) * .24,
        -0.2 + math.sin(seed.phase * 7 - phase) * .12,
      );
      final vector = tangent + drift;
      final direction = vector / vector.distance;
      final length = unit * (.006 + seed.length * .027) * (.3 + reveal * .7);
      final alpha = reveal * eyeAlpha * (.2 + seed.opacity * .56);
      if (alpha < .015) {
        continue;
      }
      final path = paths[(alpha * 4.99).floor().clamp(0, 4)];
      path
        ..moveTo(
          point.dx - direction.dx * length,
          point.dy - direction.dy * length,
        )
        ..lineTo(point.dx, point.dy);
    }
    for (var i = 0; i < paths.length; i++) {
      canvas.drawPath(
        paths[i],
        Paint()
          ..color = Colors.white.withValues(alpha: .12 + i * .115)
          ..style = PaintingStyle.stroke
          ..strokeWidth = .55 + i * .12
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  void _paintSymbol(Canvas canvas, Offset center, double unit, double t) {
    final form = _smooth(.34, .69, t);
    if (form <= 0) {
      final wake = _smooth(0, .12, t) * (1 - _smooth(.3, .45, t));
      final half = unit * .027 * wake;
      canvas.drawLine(
        center - Offset(0, half),
        center + Offset(0, half),
        Paint()
          ..color = Colors.white.withValues(alpha: .3 + wake * .5)
          ..strokeWidth = 1.1
          ..strokeCap = StrokeCap.round,
      );
      return;
    }
    final top = center - Offset(0, unit * .175);
    final bottomY = center.dy + unit * .13;
    final wing = unit * .21;
    _paintWing(canvas, top, bottomY, wing, unit, form, false);
    _paintWing(canvas, top, bottomY, wing, unit, form, true);
    final seam = _easeOut(form);
    canvas.drawLine(
      Offset(center.dx, top.dy + unit * .004),
      Offset(center.dx, center.dy + unit * .19 * seam),
      Paint()
        ..color = Colors.white.withValues(alpha: .94 * seam)
        ..strokeWidth = unit * .004
        ..strokeCap = StrokeCap.round,
    );
  }

  void _paintWing(
    Canvas canvas,
    Offset apex,
    double bottomY,
    double wing,
    double unit,
    double form,
    bool right,
  ) {
    final side = right ? 1.0 : -1.0;
    final gap = unit * .012;
    final outer = Offset(apex.dx + side * wing, bottomY);
    final inner = Offset(apex.dx + side * gap, bottomY - unit * .018);
    final clip = Path()
      ..moveTo(apex.dx + side * gap * .45, apex.dy)
      ..lineTo(outer.dx, outer.dy)
      ..lineTo(inner.dx, inner.dy)
      ..close();
    final vector = outer - apex;
    final normal = right
        ? Offset(-vector.dy, vector.dx) / vector.distance
        : Offset(vector.dy, -vector.dx) / vector.distance;
    canvas.save();
    canvas.clipPath(clip);
    for (var i = 0; i < 13; i++) {
      final local = ((form - i * .018) / .76).clamp(0.0, 1.0);
      if (local <= 0) {
        continue;
      }
      final eased = _easeOut(local);
      final base = apex + normal * (i * unit * .014) - vector * .2;
      final orbit =
          Offset(
            math.cos(i * 1.71 + (right ? 0 : math.pi)),
            math.sin(i * 1.37),
          ) *
          unit *
          .15 *
          (1 - eased);
      canvas.drawLine(
        base + orbit,
        base + vector * 1.4 + orbit,
        Paint()
          ..color = Colors.white.withValues(alpha: .9 * eased)
          ..strokeWidth = unit * .0034
          ..strokeCap = StrokeCap.round,
      );
    }
    canvas.restore();
  }

  void _paintShadow(Canvas canvas, Offset center, double unit, double t) {
    final opacity = _smooth(.55, .76, t) * .07;
    if (opacity <= 0) {
      return;
    }
    canvas.drawOval(
      Rect.fromCenter(
        center: center + Offset(0, unit * .205),
        width: unit * .2,
        height: unit * .018,
      ),
      Paint()
        ..color = Colors.white.withValues(alpha: opacity)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, unit * .018),
    );
  }

  void _paintBurst(Canvas canvas, Offset center, double unit, double t) {
    final burst = _smooth(.79, .96, t);
    if (burst <= 0) {
      return;
    }
    final apex = center - Offset(0, unit * .175);
    final paths = List.generate(4, (_) => Path());
    for (var i = 0; i < _burst.length; i++) {
      final seed = _burst[i];
      final angle = -math.pi / 2 + (seed.x - .5) * 1.18;
      final local = ((burst - seed.phase * .23) / .77).clamp(0.0, 1.0);
      final reach = _easeOut(local);
      final length = unit * (.15 + seed.length * .43) * reach;
      final start = unit * (.008 + seed.opacity * .045) * reach;
      final direction = Offset(math.cos(angle), math.sin(angle));
      final origin = apex + Offset((seed.opacity - .5) * unit * .025, 0);
      final path = paths[(seed.opacity * 3.99).floor().clamp(0, 3)];
      path
        ..moveTo(
          origin.dx + direction.dx * start,
          origin.dy + direction.dy * start,
        )
        ..lineTo(
          origin.dx + direction.dx * length,
          origin.dy + direction.dy * length,
        );
    }
    for (var i = 0; i < paths.length; i++) {
      canvas.drawPath(
        paths[i],
        Paint()
          ..color = Colors.white.withValues(alpha: .18 + i * .14)
          ..style = PaintingStyle.stroke
          ..strokeWidth = .65 + i * .18
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  double _smooth(double start, double end, double value) {
    final x = ((value - start) / (end - start)).clamp(0.0, 1.0);
    return x * x * (3 - 2 * x);
  }

  double _easeOut(double value) => 1 - math.pow(1 - value, 3).toDouble();

  @override
  bool shouldRepaint(covariant _VectorFieldPainter oldDelegate) => false;
}

class _FlowSeed {
  const _FlowSeed(this.x, this.y, this.phase, this.length)
    : opacity = (x * .37 + y * .63 + phase) % 1;

  final double x;
  final double y;
  final double phase;
  final double length;
  final double opacity;
}
