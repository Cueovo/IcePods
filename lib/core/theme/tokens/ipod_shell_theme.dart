import 'package:flutter/material.dart';

@immutable
class IpodShellTheme extends ThemeExtension<IpodShellTheme> {
  const IpodShellTheme({
    required this.scaffoldBackground,
    required this.featureGlow,
    required this.screenFill,
    required this.screenRadius,
    required this.screenBottomRadius,
  });

  final Color scaffoldBackground;
  final Color featureGlow;
  final Color screenFill;
  final double screenRadius;

  /// Larger bottom corners so the glass panel reads clearly on the chassis.
  final double screenBottomRadius;

  static const classic = IpodShellTheme(
    scaffoldBackground: Color(0xFF090A0F),
    featureGlow: Color(0xFF173127),
    // Kept for secondary surfaces; the main screen is transparent + border.
    screenFill: Color(0xFF2C2C2E),
    // Uniform continuous corners — soft without reading as a full pill.
    screenRadius: 36,
    screenBottomRadius: 36,
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
    double? screenBottomRadius,
  }) {
    return IpodShellTheme(
      scaffoldBackground: scaffoldBackground ?? this.scaffoldBackground,
      featureGlow: featureGlow ?? this.featureGlow,
      screenFill: screenFill ?? this.screenFill,
      screenRadius: screenRadius ?? this.screenRadius,
      screenBottomRadius: screenBottomRadius ?? this.screenBottomRadius,
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
      screenBottomRadius:
          screenBottomRadius +
          (other.screenBottomRadius - screenBottomRadius) * t,
    );
  }
}

abstract final class ChassisBackdropColors {
  static Color fromChassis(Color chassis) {
    return switch (chassis.toARGB32()) {
      0xFF1A1A1A => const Color(0xFFFFF8EE),
      0xFFC8C8C8 => const Color(0xFF24272D),
      _ => chassis,
    };
  }
}

/// Screen-frame colors derived from [chassis] — related, never identical.
///
/// The solid bezel sits darker while the inner rim softly separates the glass.
@immutable
class ChassisFrameColors {
  const ChassisFrameColors({required this.bezel, required this.innerRim});

  /// Darker bezel surrounding the glass.
  final Color bezel;

  /// Softer inner glass edge.
  final Color innerRim;

  factory ChassisFrameColors.fromChassis(Color chassis) {
    final hsl = HSLColor.fromColor(chassis);
    final light = hsl.lightness;
    final sat = hsl.saturation;

    // Bezel tracks chassis hue/sat closely — only a modest shade so colorful
    // shells (blue/pink/red/green/gold) stay vivid, not charcoal-gray.
    // Near-black chassis gets a hair darker; pale silver steps down gently.
    final double bezelLight;
    if (light < 0.18) {
      bezelLight = (light * 0.55).clamp(0.04, 0.12);
    } else if (light > 0.55) {
      // Light aluminum: step down but stay in the same color family.
      bezelLight = (light - 0.22).clamp(0.32, 0.62);
    } else {
      bezelLight = (light - 0.14).clamp(0.12, 0.48);
    }
    // Preserve (or slightly boost) saturation so tinted bezels never wash gray.
    final bezelSat = sat < 0.08
        ? sat
        : (sat * 1.05).clamp(0.0, 1.0);
    final bezel = hsl.withLightness(bezelLight).withSaturation(bezelSat).toColor();

    // Inner rim: quieter glass edge, still chassis-tinted.
    final innerLight = (light + 0.24).clamp(0.52, 0.88);
    final innerRim = hsl
        .withLightness(innerLight)
        .withSaturation((sat * 0.5).clamp(0.0, 0.6))
        .toColor()
        .withValues(alpha: 0.62);

    return ChassisFrameColors(bezel: bezel, innerRim: innerRim);
  }
}
