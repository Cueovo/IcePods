import 'dart:async';

import 'package:battery_plus/battery_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

class IpodStatusBar extends StatefulWidget {
  const IpodStatusBar({super.key});

  @override
  State<IpodStatusBar> createState() => _IpodStatusBarState();
}

class _IpodStatusBarState extends State<IpodStatusBar> {
  final Battery _battery = Battery();
  final Connectivity _connectivity = Connectivity();

  late DateTime _now;
  Timer? _clockTimer;
  StreamSubscription<BatteryState>? _batteryStateSub;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  int _batteryLevel = 100;
  BatteryState _batteryState = BatteryState.unknown;
  List<ConnectivityResult> _networkResults = const [ConnectivityResult.none];

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _now = DateTime.now());
      }
    });
    unawaited(_loadSystemStatus());
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
    _clockTimer?.cancel();
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
    final metrics = _IosStatusBarMetrics.resolve(MediaQuery.of(context));

    return IgnorePointer(
      child: SizedBox(
        height: metrics.totalHeight,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            metrics.horizontalPadding,
            metrics.contentTop,
            metrics.horizontalPadding,
            0,
          ),
          child: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              height: metrics.contentHeight,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    time,
                    style: TextStyle(
                      color: const Color(0xE6FFFFFF),
                      fontSize: metrics.timeSize,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                      height: 1,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    _networkIcon,
                    color: _networkConnected
                        ? const Color(0xE6FFFFFF)
                        : const Color(0x66FFFFFF),
                    size: metrics.iconSize,
                  ),
                  const SizedBox(width: 6),
                  _HorizontalBattery(
                    level: _batteryLevel,
                    state: _batteryState,
                  ),
                ],
              ),
            ),
          ),
        ),
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
/// island; system time/battery still live in the 54pt status-bar band.
class _IosStatusBarMetrics {
  const _IosStatusBarMetrics({
    required this.safeTop,
    required this.statusBarHeight,
    required this.horizontalPadding,
    required this.contentHeight,
    required this.iconSize,
    required this.timeSize,
    required this.bottomGap,
  });

  final double safeTop;
  final double statusBarHeight;
  final double horizontalPadding;
  final double contentHeight;
  final double iconSize;
  final double timeSize;
  final double bottomGap;

  /// Top padding so content is vertically centered in [statusBarHeight].
  double get contentTop =>
      ((statusBarHeight - contentHeight) / 2).clamp(0.0, statusBarHeight);

  /// Full reserved height: clear the cutout, then a little air under the bar.
  double get totalHeight => safeTop + bottomGap;

  static _IosStatusBarMetrics resolve(MediaQueryData mq) {
    // viewPadding keeps the cutout inset when system UI is immersive/hidden.
    final rawTop = mq.viewPadding.top > 0
        ? mq.viewPadding.top
        : mq.padding.top;

    // Desktop / web / simulators without a real inset.
    if (rawTop <= 0) {
      return const _IosStatusBarMetrics(
        safeTop: 20,
        statusBarHeight: 20,
        horizontalPadding: 16,
        contentHeight: 14,
        iconSize: 12,
        timeSize: 12,
        bottomGap: 6,
      );
    }

    // Dynamic Island: safe top ≥ 54 (typically 59 or 62).
    // Status bar frame is always 54pt; extra safe inset clears the island.
    if (rawTop >= 54) {
      return _IosStatusBarMetrics(
        safeTop: rawTop,
        statusBarHeight: 54,
        // System status items sit in the side “ears”, ~16pt from the edge.
        horizontalPadding: 16,
        contentHeight: 17,
        iconSize: 13,
        timeSize: 12,
        bottomGap: 8,
      );
    }

    // Notch family: safe top is the status bar (44 on early X, 47 on 12–14).
    // Center glyphs in that full band.
    if (rawTop >= 40) {
      return _IosStatusBarMetrics(
        safeTop: rawTop,
        statusBarHeight: rawTop >= 46 ? 47 : rawTop,
        horizontalPadding: 16,
        contentHeight: 17,
        iconSize: 13,
        timeSize: 12,
        bottomGap: 8,
      );
    }

    // Classic / SE / Android status strip (~20–32).
    // Status bar height equals the reported top inset.
    final bar = rawTop.clamp(20.0, 32.0);
    return _IosStatusBarMetrics(
      safeTop: rawTop,
      statusBarHeight: bar,
      horizontalPadding: 16,
      contentHeight: (bar * 0.7).clamp(12.0, 16.0),
      iconSize: 12,
      timeSize: 12,
      bottomGap: 6,
    );
  }
}

class _HorizontalBattery extends StatelessWidget {
  const _HorizontalBattery({
    required this.level,
    required this.state,
  });

  final int level;
  final BatteryState state;

  @override
  Widget build(BuildContext context) {
    // Only active charging is green. Full/discharging stay white (or red if low).
    final charging = state == BatteryState.charging;
    return SizedBox(
      width: 26,
      height: 12,
      child: CustomPaint(
        painter: _BatteryPainter(
          level: level,
          charging: charging,
        ),
      ),
    );
  }
}

/// iOS-style battery: filled body + gray remainder + cutout percentage, no bolt.
class _BatteryPainter extends CustomPainter {
  _BatteryPainter({
    required this.level,
    required this.charging,
  });

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
          fontSize: bodyHeight * 0.78,
          fontWeight: FontWeight.w800,
          height: 1,
          letterSpacing: -0.6,
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
