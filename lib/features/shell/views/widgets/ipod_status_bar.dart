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
    final mq = MediaQuery.of(context);
    // viewPadding keeps the cutout inset even when system chrome is immersive.
    final topInset = mq.viewPadding.top > 0
        ? mq.viewPadding.top
        : mq.padding.top;
    // Floor for desktop/simulators with no inset.
    final statusBand = topInset > 0 ? topInset : 24.0;
    final width = mq.size.width;

    // iPhone cutouts (approx logical points):
    // - Dynamic Island / large: ~54–62
    // - Notch: ~44–50
    // - Classic / SE: ~20
    final isDynamicIsland = statusBand >= 54;
    final isNotch = statusBand >= 40 && statusBand < 54;

    // Side margins sit in the “ears” beside notch/island; scale with width.
    final horizontal = isDynamicIsland
        ? (width * 0.052).clamp(18.0, 30.0)
        : isNotch
        ? (width * 0.048).clamp(16.0, 28.0)
        : (width * 0.042).clamp(14.0, 24.0);

    // System status glyphs are ~12–14pt; keep a fixed content row and center it
    // inside the status band (with a small optical bias for cutouts).
    const contentHeight = 18.0;
    final opticalBias = isDynamicIsland ? 1.5 : (isNotch ? 0.5 : 0.0);
    final topPad = ((statusBand - contentHeight) / 2 + opticalBias)
        .clamp(0.0, statusBand)
        .toDouble();

    // Space under the bar so menu content clears the status strip.
    final bottomGap = isDynamicIsland ? 10.0 : 12.0;
    final iconSize = isDynamicIsland ? 13.0 : 14.0;
    final timeSize = isDynamicIsland ? 12.0 : 12.5;

    return IgnorePointer(
      child: SizedBox(
        height: statusBand + bottomGap,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            horizontal,
            topPad,
            horizontal,
            bottomGap,
          ),
          child: SizedBox(
            height: contentHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  time,
                  style: TextStyle(
                    color: const Color(0xE6FFFFFF),
                    fontSize: timeSize,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
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
                  size: iconSize,
                ),
                SizedBox(width: isDynamicIsland ? 7 : 8),
                _HorizontalBattery(
                  level: _batteryLevel,
                  state: _batteryState,
                ),
              ],
            ),
          ),
        ),
      ),
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
