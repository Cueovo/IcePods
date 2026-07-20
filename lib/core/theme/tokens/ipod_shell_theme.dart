import 'package:flutter/material.dart';

@immutable
class IpodShellTheme extends ThemeExtension<IpodShellTheme> {
  const IpodShellTheme({
    required this.scaffoldBackground,
    required this.featureGlow,
    required this.screenFill,
    required this.screenRadius,
  });

  final Color scaffoldBackground;
  final Color featureGlow;
  final Color screenFill;
  final double screenRadius;

  static const classic = IpodShellTheme(
    scaffoldBackground: Color(0xFF090A0F),
    featureGlow: Color(0xFF173127),
    // Kept for secondary surfaces; the main screen is transparent + border.
    screenFill: Color(0xFF2C2C2E),
    screenRadius: 15,
  );

  static IpodShellTheme of(BuildContext context) {
    return Theme.of(context).extension<IpodShellTheme>() ?? classic;
  }

  @override
  IpodShellTheme copyWith({
    Color? scaffoldBackground,
    Color? featureGlow,
    Color? screenFill,
    double? screenRadius,
  }) {
    return IpodShellTheme(
      scaffoldBackground: scaffoldBackground ?? this.scaffoldBackground,
      featureGlow: featureGlow ?? this.featureGlow,
      screenFill: screenFill ?? this.screenFill,
      screenRadius: screenRadius ?? this.screenRadius,
    );
  }

  @override
  IpodShellTheme lerp(ThemeExtension<IpodShellTheme>? other, double t) {
    if (other is! IpodShellTheme) {
      return this;
    }
    return IpodShellTheme(
      scaffoldBackground:
          Color.lerp(scaffoldBackground, other.scaffoldBackground, t)!,
      featureGlow: Color.lerp(featureGlow, other.featureGlow, t)!,
      screenFill: Color.lerp(screenFill, other.screenFill, t)!,
      screenRadius: screenRadius + (other.screenRadius - screenRadius) * t,
    );
  }
}
