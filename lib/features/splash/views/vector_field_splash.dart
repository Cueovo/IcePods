import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const _kleinBlue = Color(0xFF002FA7);
const _warmWhite = Color(0xFFFFF8F0);

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
                duration: const Duration(milliseconds: 520),
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
    _controller.duration = Duration(milliseconds: reduced ? 1400 : 6200);
    _controller.forward().whenComplete(() {
      _holdTimer = Timer(
        Duration(milliseconds: reduced ? 80 : 280),
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

  static final List<_FlowSeed> _flow = _makeSeeds(1280, 481516);
  static final List<_FlowSeed> _dust = _makeSeeds(180, 815162);
  static final List<_FlowSeed> _edge = _makeSeeds(90, 151623);

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
    final t = animation.value;
    final unit = math.min(size.width, size.height * 9 / 16);

    final form = _smooth(0.04, 0.28, t);
    final flight = _easeInOutCubic(_smooth(0.28, 0.92, t));
    final settle = _smooth(0.88, 1.0, t);
    final peel = _easeOutCubic(_smooth(0.30, 0.94, t));

    final startY = size.height * 0.74;
    final endY = size.height * 0.07;
    final planeY = ui.lerpDouble(startY, endY, flight)!;
    final planeCenter = Offset(size.width / 2, planeY);

    // Starts closed; opens past half-width so blue fully recedes.
    final channelHalf = size.width * (0.015 + peel * peel * 0.56);

    _paintWarmChannel(canvas, size, planeY, channelHalf, peel, unit);
    _paintCurtain(canvas, size, planeY, channelHalf, peel, flight, unit, t);
    _paintDust(canvas, size, t, peel);
    _paintFlow(canvas, size, planeCenter, unit, t, form, peel, channelHalf);

    final markScale = ui.lerpDouble(1.0, 0.42, settle)!;
    if (form > 0 && settle < 0.98) {
      _paintSymbol(
        canvas,
        planeCenter,
        unit * markScale,
        form,
        1.0 - settle * settle * 0.55,
      );
    }
  }

  void _paintWarmChannel(
    Canvas canvas,
    Size size,
    double planeY,
    double half,
    double peel,
    double unit,
  ) {
    if (peel <= 0.001) {
      return;
    }

    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final cx = size.width / 2;

    final channel = Path()
      ..moveTo(cx - half, 0)
      ..lineTo(cx + half, 0)
      ..lineTo(cx + half * 0.92, planeY)
      ..lineTo(cx + half * 1.05, size.height)
      ..lineTo(cx - half * 1.05, size.height)
      ..lineTo(cx - half * 0.92, planeY)
      ..close();

    canvas.save();
    canvas.clipPath(channel);

    canvas.drawRect(
      rect,
      Paint()..color = _warmWhite.withValues(alpha: 0.92 * peel),
    );

    final glow = Paint()
      ..shader = ui.Gradient.radial(
        Offset(cx, planeY),
        size.height * 0.55,
        [
          const Color(0xFFFFFBF5).withValues(alpha: 0.95 * peel),
          const Color(0xFFFFF1E0).withValues(alpha: 0.55 * peel),
          const Color(0xFFFFE8D2).withValues(alpha: 0.0),
        ],
        const [0.0, 0.45, 1.0],
      );
    canvas.drawRect(rect, glow);

    final vertical = Paint()
      ..shader = ui.Gradient.linear(
        Offset(cx, 0),
        Offset(cx, size.height),
        [
          const Color(0xFFFFFCF8).withValues(alpha: 0.35 * peel),
          const Color(0xFFFFF6EC).withValues(alpha: 0.12 * peel),
          const Color(0xFFFFEBD8).withValues(alpha: 0.28 * peel),
        ],
        const [0.0, 0.5, 1.0],
      );
    canvas.drawRect(rect, vertical);

    final bloomW = half * 0.55 + unit * 0.08;
    for (final side in [-1.0, 1.0]) {
      final edgeX = cx + side * half * 0.85;
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset(edgeX, planeY),
          width: bloomW,
          height: size.height,
        ),
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(edgeX - side * bloomW * 0.5, 0),
            Offset(edgeX + side * bloomW * 0.5, 0),
            [
              Colors.transparent,
              const Color(0xFFFFF8F0).withValues(alpha: 0.22 * peel),
              Colors.transparent,
            ],
            const [0.0, 0.5, 1.0],
          )
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, unit * 0.04),
      );
    }

    canvas.restore();
  }

  void _paintCurtain(
    Canvas canvas,
    Size size,
    double planeY,
    double half,
    double peel,
    double flight,
    double unit,
    double t,
  ) {
    final cx = size.width / 2;
    final top = 0.0;
    final bottom = size.height;
    final roll = unit * (0.02 + peel * 0.055);

    Path leftPanel() {
      final p = Path()
        ..moveTo(0, top)
        ..lineTo(cx - half, top);
      const steps = 28;
      for (var i = 0; i <= steps; i++) {
        final yy = top + (bottom - top) * (i / steps);
        final lag = (yy - planeY).abs() / size.height;
        final wave =
            math.sin(yy / unit * 2.4 + t * 6.2) * roll * (0.35 + peel * 0.65);
        final flare = half * (0.04 + lag * 0.12) * peel;
        final x = cx - half - flare + wave;
        p.lineTo(x.clamp(0.0, cx), yy);
      }
      p
        ..lineTo(0, bottom)
        ..close();
      return p;
    }

    Path rightPanel() {
      final p = Path()
        ..moveTo(size.width, top)
        ..lineTo(cx + half, top);
      const steps = 28;
      for (var i = 0; i <= steps; i++) {
        final yy = top + (bottom - top) * (i / steps);
        final lag = (yy - planeY).abs() / size.height;
        final wave =
            math.sin(yy / unit * 2.4 + t * 6.2 + 1.1) *
            roll *
            (0.35 + peel * 0.65);
        final flare = half * (0.04 + lag * 0.12) * peel;
        final x = cx + half + flare + wave;
        p.lineTo(x.clamp(cx, size.width), yy);
      }
      p
        ..lineTo(size.width, bottom)
        ..close();
      return p;
    }

    final left = leftPanel();
    final right = rightPanel();
    final bluePaint = Paint()..color = _kleinBlue;
    canvas.drawPath(left, bluePaint);
    canvas.drawPath(right, bluePaint);

    if (peel > 0.02) {
      _paintRolledEdge(
        canvas,
        size,
        cx,
        half,
        planeY,
        peel,
        unit,
        t,
        left: true,
      );
      _paintRolledEdge(
        canvas,
        size,
        cx,
        half,
        planeY,
        peel,
        unit,
        t,
        left: false,
      );
    }

    if (flight > 0.85) {
      final recede = _smooth(0.85, 1.0, flight);
      final band = size.height * 0.08 * (1 - recede);
      if (band > 0.5) {
        canvas.drawRect(
          Rect.fromLTWH(0, 0, size.width, band),
          Paint()..color = _kleinBlue.withValues(alpha: 1 - recede * 0.35),
        );
        canvas.drawRect(
          Rect.fromLTWH(0, size.height - band, size.width, band),
          Paint()..color = _kleinBlue.withValues(alpha: 1 - recede * 0.35),
        );
      }
    }
  }

  void _paintRolledEdge(
    Canvas canvas,
    Size size,
    double cx,
    double half,
    double planeY,
    double peel,
    double unit,
    double t, {
    required bool left,
  }) {
    final side = left ? -1.0 : 1.0;
    final paths = List.generate(3, (_) => Path());
    for (final seed in _edge) {
      final yy = seed.y * size.height;
      final lag = ((yy - planeY) / size.height).abs();
      if (lag > 0.55) {
        continue;
      }
      final local = peel * (1 - lag * 1.4).clamp(0.0, 1.0);
      if (local < 0.05) {
        continue;
      }
      final wave =
          math.sin(yy / unit * 2.4 + t * 6.2 + (left ? 0 : 1.1)) *
          unit *
          0.03 *
          peel;
      final flare = half * (0.04 + lag * 0.12) * peel;
      final x = cx + side * (half + flare) + wave;
      final angle =
          side * (0.55 + seed.phase * 0.7) + math.sin(t * 4 + seed.phase) * 0.2;
      final len = unit * (0.018 + seed.length * 0.04) * local;
      final dir = Offset(math.cos(angle), math.sin(angle));
      final origin = Offset(x - side * unit * 0.01, yy);
      final bucket = (seed.opacity * 2.99).floor().clamp(0, 2);
      paths[bucket]
        ..moveTo(origin.dx, origin.dy)
        ..lineTo(origin.dx + dir.dx * len * side, origin.dy + dir.dy * len);
    }
    for (var i = 0; i < paths.length; i++) {
      canvas.drawPath(
        paths[i],
        Paint()
          ..color = Colors.white.withValues(alpha: (0.08 + i * 0.07) * peel)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.55 + i * 0.15
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  void _paintDust(Canvas canvas, Size size, double t, double peel) {
    final fade = (1 - _smooth(0.08, 0.32, t)) * (1 - peel * 0.85);
    if (fade <= 0.01) {
      return;
    }
    final points = <Offset>[];
    for (final seed in _dust) {
      final nx = (seed.x - 0.5).abs();
      if (peel > 0.2 && nx < 0.12 + peel * 0.2) {
        continue;
      }
      points.add(Offset(seed.x * size.width, seed.y * size.height));
    }
    if (points.isEmpty) {
      return;
    }
    canvas.drawPoints(
      ui.PointMode.points,
      points,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.03 + fade * 0.04)
        ..strokeWidth = 0.7
        ..strokeCap = StrokeCap.round,
    );
  }

  void _paintFlow(
    Canvas canvas,
    Size size,
    Offset plane,
    double unit,
    double t,
    double form,
    double peel,
    double channelHalf,
  ) {
    final reveal = _smooth(0.02, 0.26, t);
    if (reveal <= 0.01) {
      return;
    }

    final phase = math.pow(_smooth(0.02, 0.85, t), 1.35) * 4.6;
    final formPull = form;
    final paths = List.generate(5, (_) => Path());
    final cx = size.width / 2;

    for (var i = 0; i < _flow.length; i++) {
      final seed = _flow[i];
      var base = Offset(seed.x * size.width, seed.y * size.height);

      if (form < 1) {
        final by = ui.lerpDouble(base.dy, size.height * 0.74, formPull * 0.35)!;
        base = Offset(base.dx, by);
      }

      if (peel > 0.05) {
        final dx = (base.dx - cx).abs();
        final open =
            channelHalf *
            (0.9 + (base.dy - plane.dy).abs() / size.height * 0.25);
        if (dx < open) {
          continue;
        }
      }

      final delta = base - plane;
      final radius = delta.distance.clamp(0.001, double.infinity);
      final radiusUnit = (radius / (unit * 0.9)).clamp(0.0, 2.0);
      var angle =
          math.atan2(delta.dy, delta.dx) +
          phase * (0.2 + (1 - radiusUnit.clamp(0.0, 1.0)) * 0.5) +
          math.sin(seed.phase * math.pi * 2 + phase) * 0.07;

      if (form > 0 && form < 1 && radius < unit * 0.45) {
        final target = delta.dx >= 0 ? -0.95 : -math.pi + 0.95;
        angle = ui.lerpDouble(
          angle,
          target,
          form * (1 - radius / (unit * 0.45)),
        )!;
      }

      final wave =
          math.sin(radiusUnit * 11 - phase * 2.0 + seed.phase * 5) *
          unit *
          0.01 *
          reveal;
      var point =
          plane + Offset(math.cos(angle), math.sin(angle)) * (radius + wave);

      final clearR = unit * (0.12 + form * 0.1);
      final dPlane = (point - plane).distance;
      var pocket = 1.0;
      if (dPlane < clearR * 1.35) {
        pocket = _smooth(clearR * 0.55, clearR * 1.35, dPlane);
        final push = (1 - pocket) * unit * 0.04 * form;
        final dir = point == plane
            ? const Offset(0, -1)
            : (point - plane) / dPlane;
        point += dir * push;
      }

      final tangent = Offset(-math.sin(angle), math.cos(angle));
      final drift = Offset(
        math.cos(seed.phase * 8 + phase) * 0.22,
        -0.18 + math.sin(seed.phase * 6 - phase) * 0.1,
      );
      final vector = tangent + drift;
      final direction = vector / vector.distance;
      final length =
          unit * (0.005 + seed.length * 0.024) * (0.28 + reveal * 0.72);
      final residual = 1 - peel * 0.75;
      final alpha = reveal * pocket * residual * (0.18 + seed.opacity * 0.55);
      if (alpha < 0.015) {
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
          ..color = Colors.white.withValues(alpha: 0.1 + i * 0.11)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.5 + i * 0.12
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  void _paintSymbol(
    Canvas canvas,
    Offset center,
    double unit,
    double form,
    double alphaMul,
  ) {
    if (form <= 0.001) {
      return;
    }

    final top = center - Offset(0, unit * 0.17);
    final bottomY = center.dy + unit * 0.12;
    final wing = unit * 0.2;

    _paintWing(canvas, top, bottomY, wing, unit, form, false, alphaMul);
    _paintWing(canvas, top, bottomY, wing, unit, form, true, alphaMul);

    final seam = _easeOutCubic(form);
    canvas.drawLine(
      Offset(center.dx, top.dy + unit * 0.004),
      Offset(center.dx, center.dy + unit * 0.18 * seam),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.94 * seam * alphaMul)
        ..strokeWidth = unit * 0.004
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
    double alphaMul,
  ) {
    final side = right ? 1.0 : -1.0;
    final gap = unit * 0.012;
    final outer = Offset(apex.dx + side * wing, bottomY);
    final inner = Offset(apex.dx + side * gap, bottomY - unit * 0.016);
    final clip = Path()
      ..moveTo(apex.dx + side * gap * 0.45, apex.dy)
      ..lineTo(outer.dx, outer.dy)
      ..lineTo(inner.dx, inner.dy)
      ..close();
    final vector = outer - apex;
    final normal = right
        ? Offset(-vector.dy, vector.dx) / vector.distance
        : Offset(vector.dy, -vector.dx) / vector.distance;

    canvas.save();
    canvas.clipPath(clip);
    for (var i = 0; i < 12; i++) {
      final local = ((form - i * 0.016) / 0.78).clamp(0.0, 1.0);
      if (local <= 0) {
        continue;
      }
      final eased = _easeOutCubic(local);
      final base = apex + normal * (i * unit * 0.0135) - vector * 0.18;
      final orbit =
          Offset(
            math.cos(i * 1.71 + (right ? 0 : math.pi)),
            math.sin(i * 1.37),
          ) *
          unit *
          0.14 *
          (1 - eased);
      canvas.drawLine(
        base + orbit,
        base + vector * 1.38 + orbit,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.9 * eased * alphaMul)
          ..strokeWidth = unit * 0.0033
          ..strokeCap = StrokeCap.round,
      );
    }
    canvas.restore();
  }

  double _smooth(double start, double end, double value) {
    final x = ((value - start) / (end - start)).clamp(0.0, 1.0);
    return x * x * (3 - 2 * x);
  }

  double _easeOutCubic(double value) => 1 - math.pow(1 - value, 3).toDouble();

  double _easeInOutCubic(double value) {
    if (value < 0.5) {
      return 4 * value * value * value;
    }
    return 1 - math.pow(-2 * value + 2, 3).toDouble() / 2;
  }

  @override
  bool shouldRepaint(covariant _VectorFieldPainter oldDelegate) => false;
}

class _FlowSeed {
  const _FlowSeed(this.x, this.y, this.phase, this.length)
    : opacity = (x * 0.37 + y * 0.63 + phase) % 1;

  final double x;
  final double y;
  final double phase;
  final double length;
  final double opacity;
}