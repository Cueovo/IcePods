import 'dart:async';

import 'package:battery_plus/battery_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

class IpodStatusBar extends StatefulWidget {
  const IpodStatusBar({super.key});

  @override
  State<IpodStatusBar> createState() => _IpodStatusBarState();
}

class _IpodStatusBarState extends State<IpodStatusBar>
    with WidgetsBindingObserver {
  final Battery _battery = Battery();
  final Connectivity _connectivity = Connectivity();

  late DateTime _now;
  Timer? _clockTimer;
  Timer? _batteryPollTimer;
  StreamSubscription<BatteryState>? _batteryStateSub;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  int _batteryLevel = 100;
  BatteryState _batteryState = BatteryState.unknown;
  List<ConnectivityResult> _networkResults = const [ConnectivityResult.none];

  /// iOS/Android do not push battery *percentage* changes; only charge state
  /// changes. Poll periodically so the icon stays in sync while discharging.
  static const _batteryPollInterval = Duration(seconds: 30);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _now = DateTime.now();
    // Clock is HH:mm only — no need to rebuild every second.
    _scheduleMinuteClock();
    unawaited(_loadSystemStatus());
    _batteryPollTimer = Timer.periodic(_batteryPollInterval, (_) {
      unawaited(_refreshBatteryLevel());
      unawaited(_refreshBatteryState());
    });
    _batteryStateSub = _battery.onBatteryStateChanged.listen((state) {
      if (!mounted) {
        return;
      }
      setState(() => _batteryState = state);
      unawaited(_refreshBatteryLevel());
    });
    _connectivitySub = _connectivity.onConnectivityChanged.listen((results) {
      if (!mounted) {
        return;
      }
      setState(() => _networkResults = results);
    });
  }

  /// Align updates to the next wall-clock minute, then tick once per minute.
  void _scheduleMinuteClock() {
    _clockTimer?.cancel();
    final now = DateTime.now();
    final nextMinute = DateTime(
      now.year,
      now.month,
      now.day,
      now.hour,
      now.minute,
    ).add(const Duration(minutes: 1));
    final delay = nextMinute.difference(now);
    _clockTimer = Timer(delay, () {
      if (!mounted) {
        return;
      }
      setState(() => _now = DateTime.now());
      _clockTimer = Timer.periodic(const Duration(minutes: 1), (_) {
        if (mounted) {
          setState(() => _now = DateTime.now());
        }
      });
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (mounted) {
        setState(() => _now = DateTime.now());
      }
      // Reschedule so we stay aligned after background suspension.
      _scheduleMinuteClock();
      unawaited(_loadSystemStatus());
    }
  }

  Future<void> _loadSystemStatus() async {
    await Future.wait([
      _refreshBatteryLevel(),
      _refreshBatteryState(),
      _refreshConnectivity(),
    ]);
  }

  Future<void> _refreshBatteryLevel() async {
    try {
      final level = await _battery.batteryLevel;
      if (!mounted) {
        return;
      }
      setState(() => _batteryLevel = level.clamp(0, 100));
    } catch (_) {
      // Keep the last known level when the platform call fails.
    }
  }

  Future<void> _refreshBatteryState() async {
    try {
      final state = await _battery.batteryState;
      if (!mounted) {
        return;
      }
      setState(() => _batteryState = state);
    } catch (_) {
      // Keep the last known state when the platform call fails.
    }
  }

  Future<void> _refreshConnectivity() async {
    try {
      final results = await _connectivity.checkConnectivity();
      if (!mounted) {
        return;
      }
      setState(() => _networkResults = results);
    } catch (_) {
      // Keep the last known network state when the platform call fails.
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clockTimer?.cancel();
    _batteryPollTimer?.cancel();
    unawaited(_batteryStateSub?.cancel() ?? Future<void>.value());
    unawaited(_connectivitySub?.cancel() ?? Future<void>.value());
    super.dispose();
  }

  bool get _networkConnected =>
      _networkResults.any((result) => result != ConnectivityResult.none);

  IconData get _networkIcon {
    if (_networkResults.contains(ConnectivityResult.wifi)) {
      return Icons.wifi_rounded;
    }
    if (_networkResults.contains(ConnectivityResult.mobile)) {
      return Icons.signal_cellular_alt_rounded;
    }
    if (_networkResults.contains(ConnectivityResult.ethernet)) {
      return Icons.settings_ethernet_rounded;
    }
    if (_networkResults.contains(ConnectivityResult.vpn)) {
      return Icons.vpn_key_rounded;
    }
    if (_networkResults.contains(ConnectivityResult.bluetooth)) {
      return Icons.bluetooth_rounded;
    }
    if (_networkResults.contains(ConnectivityResult.other)) {
      return Icons.network_check_rounded;
    }
    return Icons.signal_wifi_off_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final time =
        '${_now.hour.toString().padLeft(2, '0')}:${_now.minute.toString().padLeft(2, '0')}';

    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final metrics = _IosStatusBarMetrics.resolve(
            MediaQuery.of(context),
            constraints.maxWidth,
          );
          // Bold clock so it holds against ambient / glass gradients.
          final timeWidget = Text(
            time,
            key: const ValueKey('ipod-status-time'),
            style: TextStyle(
              color: const Color(0xF2FFFFFF),
              fontSize: metrics.timeSize,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
              height: 1,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          );
          final statusWidget = Row(
            key: const ValueKey('ipod-status-items'),
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _networkIcon,
                color: _networkConnected
                    ? const Color(0xF2FFFFFF)
                    : const Color(0x66FFFFFF),
                size: metrics.iconSize,
              ),
              SizedBox(width: metrics.itemSpacing),
              _HorizontalBattery(
                level: _batteryLevel,
                state: _batteryState,
                width: metrics.batteryWidth,
                height: metrics.batteryHeight,
              ),
            ],
          );

          final slotHeight = metrics.totalHeight;
          final leadingContentWidth =
              (metrics.leadingSlotLeft + metrics.leadingSlotWidth) -
              metrics.leadingContentLeft;
          final trailingContentWidth =
              metrics.trailingContentRight - metrics.trailingSlotLeft;

          return SizedBox(
            key: const ValueKey('ipod-status-bar'),
            height: slotHeight,
            child: Stack(
              children: [
                Positioned(
                  left: metrics.leadingSlotLeft,
                  top: 0,
                  width: metrics.leadingSlotWidth,
                  height: slotHeight,
                  child: SizedBox(
                    key: const ValueKey('ipod-status-leading-slot'),
                  ),
                ),
                Positioned(
                  left: metrics.trailingSlotLeft,
                  top: 0,
                  width: metrics.trailingSlotWidth,
                  height: slotHeight,
                  child: SizedBox(
                    key: const ValueKey('ipod-status-trailing-slot'),
                  ),
                ),
                // All device families (classic / notch / Dynamic Island / Android
                // fallback) keep time leading-left and status trailing-right —
                // never centered. Classic SE used a centered clock historically,
                // but this shell always mimics modern iPhone status chrome.
                Positioned(
                  top: metrics.contentTop,
                  left: metrics.leadingContentLeft,
                  width: leadingContentWidth,
                  height: metrics.contentHeight,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: timeWidget,
                  ),
                ),
                Positioned(
                  top: metrics.contentTop,
                  left: metrics.trailingSlotLeft,
                  width: trailingContentWidth,
                  height: metrics.contentHeight,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: statusWidget,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Portrait status-bar layout matching Apple UIStatusBar / safe-area metrics.
///
/// Sources (logical points, portrait):
/// - Classic / SE: status bar 20, safe top 20
/// - Notch (X–14 non-Pro): status bar 47 (early X family often 44),
///   safe top equals status bar height
/// - Dynamic Island (14 Pro / 15 / 16…): status bar 54,
///   safe top 59 (most) or 62 (16 Pro / Pro Max)
///
/// Glyphs are centered in the **status bar frame**, not the full safe area.
/// On Dynamic Island devices the safe area is taller so content clears the
/// island; system glyphs remain on a separate hardware-aligned center line.
class _IosStatusBarMetrics {
  const _IosStatusBarMetrics({
    required this.family,
    required this.safeTop,
    required this.statusBarHeight,
    required this.leadingSlotLeft,
    required this.leadingSlotWidth,
    required this.trailingSlotLeft,
    required this.trailingSlotWidth,
    required this.leadingContentLeft,
    required this.trailingContentRight,
    required this.contentCenterY,
    required this.contentHeight,
    required this.iconSize,
    required this.timeSize,
    required this.batteryWidth,
    required this.batteryHeight,
    required this.itemSpacing,
    required this.bottomGap,
  });

  final _IosStatusBarFamily family;
  final double safeTop;
  final double statusBarHeight;
  final double leadingSlotLeft;
  final double leadingSlotWidth;
  final double trailingSlotLeft;
  final double trailingSlotWidth;
  final double leadingContentLeft;
  final double trailingContentRight;
  final double contentCenterY;
  final double contentHeight;
  final double iconSize;
  final double timeSize;
  final double batteryWidth;
  final double batteryHeight;
  final double itemSpacing;
  final double bottomGap;

  double get contentTop =>
      (contentCenterY - contentHeight / 2).clamp(0.0, statusBarHeight);

  double get totalHeight => safeTop + bottomGap;

  static _IosStatusBarMetrics resolve(MediaQueryData mq, double width) {
    final rawTop = mq.viewPadding.top > 0 ? mq.viewPadding.top : mq.padding.top;
    final portrait = mq.size.height >= mq.size.width;
    final effectiveWidth = width.isFinite && width > 0 ? width : mq.size.width;

    // Landscape: compact leading/trailing layout (no top cutout hardware).
    if (!portrait) {
      return _classic(effectiveWidth, safeTop: rawTop > 0 ? rawTop : 20);
    }

    final family = _resolveFamily(mq, effectiveWidth, rawTop);
    switch (family) {
      case _IosStatusBarFamily.classic:
        return _classic(effectiveWidth, safeTop: rawTop > 0 ? rawTop : 20);
      case _IosStatusBarFamily.notch:
        return _sideLayout(
          family: family,
          width: effectiveWidth,
          safeTop: rawTop,
          statusBarHeight: rawTop >= 46 ? 47 : rawTop.clamp(40.0, 50.0),
          sideInset: _notchSideInset(effectiveWidth),
          slotWidth: _notchSlotWidth(effectiveWidth),
          leadingContentLeft: _notchTimeLeft(effectiveWidth),
          trailingContentRight:
              effectiveWidth - _notchRightInset(effectiveWidth),
          contentCenterY: _notchCenterY(rawTop),
          contentHeight: 20,
          // Material glyphs have internal padding — size ≈ battery height
          // so signal/wifi reads the same visual weight as the capsule.
          iconSize: 18,
          timeSize: 16,
          batteryWidth: 32,
          batteryHeight: 15,
          itemSpacing: 7,
          bottomGap: 14,
        );
      case _IosStatusBarFamily.dynamicIsland:
        final isNewPro = _isNewProSize(mq.size);
        return _sideLayout(
          family: family,
          width: effectiveWidth,
          safeTop: rawTop,
          statusBarHeight: isNewPro ? 58 : 54,
          sideInset: _dynamicIslandSideInset(effectiveWidth),
          slotWidth: _dynamicIslandSlotWidth(effectiveWidth),
          leadingContentLeft: _dynamicIslandTimeLeft(effectiveWidth),
          trailingContentRight:
              effectiveWidth - _dynamicIslandRightInset(effectiveWidth),
          contentCenterY: isNewPro ? 32.5 : 29.5,
          contentHeight: 20,
          iconSize: 18,
          timeSize: 16,
          batteryWidth: 32,
          batteryHeight: 15,
          itemSpacing: 7,
          bottomGap: 14,
        );
    }
  }

  static _IosStatusBarMetrics _classic(
    double width, {
    required double safeTop,
  }) {
    // Android / SE / landscape fallback. Time stays left-aligned so it never
    // looks "stuck in the middle" on non-iOS viewports (common Android tops
    // are 24–32 logical px and used to hit this path).
    final bar = safeTop > 0 ? safeTop.clamp(20.0, 36.0) : 24.0;
    final timeLeft = (width * 0.048).clamp(16.0, 22.0);
    final rightInset = (width * 0.042).clamp(14.0, 18.0);
    final slotWidth = (width * 0.28).clamp(96.0, 130.0);
    final sideInset = timeLeft;
    return _IosStatusBarMetrics(
      family: _IosStatusBarFamily.classic,
      safeTop: safeTop > 0 ? safeTop : bar,
      statusBarHeight: bar,
      leadingSlotLeft: sideInset,
      leadingSlotWidth: slotWidth,
      trailingSlotLeft: width - sideInset - slotWidth,
      trailingSlotWidth: slotWidth,
      leadingContentLeft: timeLeft,
      trailingContentRight: width - rightInset,
      contentCenterY: bar / 2,
      contentHeight: (bar * 0.72).clamp(14.0, 18.0),
      iconSize: 17,
      timeSize: 15,
      batteryWidth: 30,
      batteryHeight: 14,
      itemSpacing: 6,
      bottomGap: 12,
    );
  }

  static _IosStatusBarMetrics _sideLayout({
    required _IosStatusBarFamily family,
    required double width,
    required double safeTop,
    required double statusBarHeight,
    required double sideInset,
    required double slotWidth,
    required double leadingContentLeft,
    required double trailingContentRight,
    required double contentCenterY,
    required double contentHeight,
    required double iconSize,
    required double timeSize,
    required double batteryWidth,
    required double batteryHeight,
    required double itemSpacing,
    required double bottomGap,
  }) {
    return _IosStatusBarMetrics(
      family: family,
      safeTop: safeTop,
      statusBarHeight: statusBarHeight,
      leadingSlotLeft: sideInset,
      leadingSlotWidth: slotWidth,
      trailingSlotLeft: width - sideInset - slotWidth,
      trailingSlotWidth: slotWidth,
      leadingContentLeft: leadingContentLeft,
      trailingContentRight: trailingContentRight,
      contentCenterY: contentCenterY,
      contentHeight: contentHeight,
      iconSize: iconSize,
      timeSize: timeSize,
      batteryWidth: batteryWidth,
      batteryHeight: batteryHeight,
      itemSpacing: itemSpacing,
      bottomGap: bottomGap,
    );
  }

  static _IosStatusBarFamily _resolveFamily(
    MediaQueryData mq,
    double width,
    double rawTop,
  ) {
    final size = mq.size;
    if (rawTop >= 54 &&
        (_isDynamicIslandSize(size) || rawTop >= 59 || width >= 390)) {
      return _IosStatusBarFamily.dynamicIsland;
    }
    if (rawTop >= 40 && (width >= 350 || size.height >= 700)) {
      return _IosStatusBarFamily.notch;
    }
    return _IosStatusBarFamily.classic;
  }

  static bool _isDynamicIslandSize(Size size) {
    final width = size.width < size.height ? size.width : size.height;
    return const [
      393,
      402,
      420,
      430,
      440,
    ].any((candidate) => (width - candidate).abs() < 1);
  }

  static bool _isNewProSize(Size size) {
    final width = size.width < size.height ? size.width : size.height;
    return (width - 402).abs() < 1 || (width - 440).abs() < 1;
  }

  static double _notchSideInset(double width) =>
      (width * 0.0615).clamp(23.0, 27.0);

  static double _notchTimeLeft(double width) =>
      (width * 0.068).clamp(25.0, 29.0);

  static double _notchRightInset(double width) =>
      (width * 0.0615).clamp(23.0, 27.0);

  static double _notchCenterY(double rawTop) =>
      rawTop >= 46 ? 23.5 : rawTop / 2;

  static double _notchSlotWidth(double width) =>
      (width * 0.245).clamp(84.0, 108.0);

  static double _dynamicIslandSideInset(double width) =>
      (width * 0.077).clamp(29.0, 35.0);

  static double _dynamicIslandTimeLeft(double width) =>
      (width * 0.131).clamp(51.5, 56.5);

  static double _dynamicIslandRightInset(double width) =>
      (width * 0.077).clamp(29.0, 35.0);

  static double _dynamicIslandSlotWidth(double width) =>
      (width * 0.185).clamp(72.0, 84.0);
}

enum _IosStatusBarFamily { classic, notch, dynamicIsland }

class _HorizontalBattery extends StatelessWidget {
  const _HorizontalBattery({
    required this.level,
    required this.state,
    required this.width,
    required this.height,
  });

  final int level;
  final BatteryState state;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    // Only active charging is green. Full/discharging stay white (or red if low).
    final charging = state == BatteryState.charging;
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        painter: _BatteryPainter(level: level, charging: charging),
      ),
    );
  }
}

/// iOS-style battery: filled body + gray remainder + cutout percentage, no bolt.
class _BatteryPainter extends CustomPainter {
  _BatteryPainter({required this.level, required this.charging});

  final int level;
  final bool charging;

  @override
  void paint(Canvas canvas, Size size) {
    final fillRatio = (level.clamp(0, 100) / 100).toDouble();

    // Dark status bar: white fill / green when charging / red when low.
    final fillColor = charging
        ? const Color(0xFF34C759)
        : (level <= 20 ? const Color(0xFFFF3B30) : const Color(0xFFFFFFFF));
    const trackColor = Color(0x59FFFFFF);
    const nubColor = Color(0x59FFFFFF);

    // Geometry matches iOS Dynamic Island battery proportions.
    final nubWidth = size.height * 0.14;
    final gap = size.height * 0.07;
    final bodyWidth = size.width - nubWidth - gap;
    final bodyHeight = size.height;
    // Rounded rect like the reference (not a full pill).
    final bodyRadius = bodyHeight * 0.32;
    final nubHeight = bodyHeight * 0.38;
    final nubRadius = nubHeight * 0.45;

    canvas.saveLayer(Offset.zero & size, Paint());

    final bodyRect = RRect.fromLTRBR(
      0,
      0,
      bodyWidth,
      bodyHeight,
      Radius.circular(bodyRadius),
    );

    // Unfilled track.
    canvas.drawRRect(bodyRect, Paint()..color = trackColor);

    // Filled portion clipped to body.
    if (fillRatio > 0) {
      canvas.save();
      canvas.clipRRect(bodyRect);
      canvas.drawRect(
        Rect.fromLTRB(0, 0, bodyWidth * fillRatio, bodyHeight),
        Paint()..color = fillColor,
      );
      canvas.restore();
    }

    // Right terminal nub.
    final nubRect = RRect.fromLTRBR(
      bodyWidth + gap,
      (bodyHeight - nubHeight) / 2,
      size.width,
      (bodyHeight + nubHeight) / 2,
      Radius.circular(nubRadius),
    );
    canvas.drawRRect(nubRect, Paint()..color = nubColor);

    // Cut-out percentage (reveals status-bar background).
    final textPainter = TextPainter(
      text: TextSpan(
        text: '$level',
        style: TextStyle(
          foreground: Paint()..blendMode = BlendMode.dstOut,
          fontSize: bodyHeight * 0.72,
          fontWeight: FontWeight.w800,
          height: 1,
          letterSpacing: -0.4,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      Offset(
        (bodyWidth - textPainter.width) / 2,
        (bodyHeight - textPainter.height) / 2 + 0.4,
      ),
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _BatteryPainter oldDelegate) {
    return oldDelegate.level != level || oldDelegate.charging != charging;
  }
}
