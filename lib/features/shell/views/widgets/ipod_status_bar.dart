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
    // Occupy the system status-bar strip (edge-to-edge content starts at y=0).
    // Prefer viewPadding.top (cutout); fall back to padding.top; then a floor.
    final mq = MediaQuery.of(context);
    final topInset = mq.viewPadding.top > 0
        ? mq.viewPadding.top
        : mq.padding.top;
    final statusBand = topInset > 0 ? topInset : 36.0;
    // Extra space below icons so menu/player content sits clear of the bar.
    const bottomGap = 12.0;
    return IgnorePointer(
      child: SizedBox(
        height: statusBand + bottomGap,
        child: Padding(
          padding: EdgeInsets.fromLTRB(28, 0, 26, bottomGap),
          child: Align(
            // Sit near the lower edge of the system inset, above bottomGap.
            alignment: const Alignment(0, 0.55),
            child: Row(
              children: [
                Text(
                  time,
                  style: const TextStyle(
                    color: Color(0xE6FFFFFF),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                    height: 1,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                const Spacer(),
                Icon(
                  _networkIcon,
                  color: _networkConnected
                      ? const Color(0xE6FFFFFF)
                      : const Color(0x66FFFFFF),
                  size: 14,
                ),
                const SizedBox(width: 8),
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
      width: 28,
      height: 13,
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
