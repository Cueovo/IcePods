import 'package:flutter/widgets.dart';

/// Native composition modes for the iPod shell.
///
/// The shell is a physical object, so the layout is chosen from the real
/// viewport instead of stretching one portrait composition everywhere.
enum ShellLayoutMode {
  /// Short or narrow phones: same silhouette, tighter menu rail.
  compactPortrait,

  /// The reference composition: glass over wheel.
  standardPortrait,

  /// Tablets and large windows: more glass, bounded chassis.
  widePortrait,

  /// Glass and wheel sit side by side.
  landscape,
}

@immutable
class ShellLayoutMetrics {
  const ShellLayoutMetrics({
    required this.mode,
    required this.menuRailWidth,
    required this.maxWheelDiameter,
    required this.screenFlex,
    required this.wheelFlex,
    this.maxChassisWidth = double.infinity,
    this.maxChassisHeight = double.infinity,
  });

  /// Authored diameter of [ClickWheel]; also the standard portrait maximum.
  static const double referenceWheelDiameter = 300;

  final ShellLayoutMode mode;
  final double menuRailWidth;
  final double maxWheelDiameter;
  final int screenFlex;
  final int wheelFlex;
  final double maxChassisWidth;
  final double maxChassisHeight;

  bool get isLandscape => mode == ShellLayoutMode.landscape;

  static ShellLayoutMetrics resolve(MediaQueryData mq) {
    final size = mq.size;
    if (size.width > size.height) {
      // Width is the abundant axis: stand the wheel next to the glass.
      return const ShellLayoutMetrics(
        mode: ShellLayoutMode.landscape,
        menuRailWidth: 150,
        maxWheelDiameter: 260,
        screenFlex: 62,
        wheelFlex: 38,
        maxChassisHeight: 620,
      );
    }
    if (size.shortestSide >= 600) {
      return const ShellLayoutMetrics(
        mode: ShellLayoutMode.widePortrait,
        menuRailWidth: 190,
        maxWheelDiameter: 340,
        screenFlex: 60,
        wheelFlex: 40,
        maxChassisWidth: 720,
        maxChassisHeight: 1100,
      );
    }
    if (size.height < 700 || size.width < 360) {
      return const ShellLayoutMetrics(
        mode: ShellLayoutMode.compactPortrait,
        menuRailWidth: 136,
        maxWheelDiameter: 244,
        screenFlex: 56,
        wheelFlex: 44,
      );
    }
    return const ShellLayoutMetrics(
      mode: ShellLayoutMode.standardPortrait,
      menuRailWidth: 158,
      maxWheelDiameter: referenceWheelDiameter,
      screenFlex: 56,
      wheelFlex: 44,
    );
  }

  /// Largest wheel that fits [available] without crowding its band.
  double wheelDiameterFor(Size available) {
    final shortest = available.shortestSide;
    if (!shortest.isFinite || shortest <= 0) {
      return maxWheelDiameter;
    }
    final fitted = shortest * 0.92;
    return fitted < maxWheelDiameter ? fitted : maxWheelDiameter;
  }
}
