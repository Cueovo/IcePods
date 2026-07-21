import 'package:flutter/widgets.dart';

/// Top cutout / status chrome family for chassis layout.
///
/// Detection uses [MediaQueryData.viewPadding] (still set under immersive UI):
/// - **classic** — flat top (SE ≈20) — rawTop &lt; 24
/// - **statusBar** — Android punch-hole / short status — ≈24–39
/// - **notch** — iPhone X–14 / tall waterfall — ≈40–53
/// - **island** — Dynamic Island / Android island-like — ≈54+
enum DeviceTopCutoutFamily {
  classic,
  statusBar,
  notch,
  island,
}

/// Adaptive chassis / frame / bezel insets.
///
/// Android punch-hole: **shift the whole screen module** (outer white rim +
/// uniform bezel + glass + content) so the white rim's top edge sits at the
/// camera hole top. Bezel stays the same thickness as the other sides —
/// do not fatten the top edge or pad content separately (that looks cropped).
@immutable
class ChassisInsets {
  const ChassisInsets({
    required this.family,
    required this.rawTop,
    required this.topOuter,
    required this.screenFrameTop,
    required this.screenFrameHorizontal,
    required this.screenFrameBottom,
    required this.bezelTop,
    required this.bezelHorizontal,
    required this.bezelBottom,
    this.glassContentTop = 0,
  });

  final DeviceTopCutoutFamily family;

  /// Physical top inset from the OS (logical px).
  final double rawTop;

  /// Chassis band above the screen module. Moves the **entire** frame,
  /// including the outer white rim.
  final double topOuter;

  /// Extra padding outside the frame (between chassis and outer rim).
  final double screenFrameTop;
  final double screenFrameHorizontal;
  final double screenFrameBottom;

  /// Solid bezel band between outer rim and glass (prefer uniform sides).
  final double bezelTop;
  final double bezelHorizontal;
  final double bezelBottom;

  /// Breathing room inside glass between the top bezel and the custom status bar.
  final double glassContentTop;

  EdgeInsets get screenFramePadding => EdgeInsets.fromLTRB(
        screenFrameHorizontal,
        screenFrameTop,
        screenFrameHorizontal,
        screenFrameBottom,
      );

  EdgeInsets get bezelPadding => EdgeInsets.fromLTRB(
        bezelHorizontal,
        bezelTop,
        bezelHorizontal,
        bezelBottom,
      );

  /// Distance from physical top to the outer frame edge (white rim top).
  double get frameTopFromScreen => topOuter + screenFrameTop;

  /// Distance from physical top to the start of glass content.
  double get glassTopFromScreen => frameTopFromScreen + bezelTop;

  /// Top inset already consumed by chassis + frame + bezel.
  double get consumedTop => glassTopFromScreen;

  /// Remaining top safe inset for content **inside** the glass.
  ///
  /// Punch-hole: 0 — the whole module already shifted; re-applying residual
  /// would only thicken the empty band under the rim (looks cropped).
  /// Notch / island: residual so status chrome still clears the cutout.
  double residualTopInset() {
    if (family == DeviceTopCutoutFamily.statusBar ||
        family == DeviceTopCutoutFamily.classic) {
      return 0;
    }
    final left = rawTop - consumedTop;
    return left > 0 ? left : 0;
  }

  /// Bezel amount for concentric corner radius (side/bottom).
  double get bezelRadiusInset {
    final a = bezelHorizontal;
    final b = bezelBottom;
    return a > b ? a : b;
  }

  static const double _defaultBezel = 5;

  /// Chassis padding left/right of the screen module (was 12; tighter = wider glass).
  static const double _frameHorizontal = 8;

  static ChassisInsets resolve(MediaQueryData mq) {
    final rawTop = _rawTop(mq);
    final landscape = mq.size.width > mq.size.height;
    final family =
        landscape ? DeviceTopCutoutFamily.classic : _family(mq, rawTop);

    if (landscape) {
      return ChassisInsets(
        family: DeviceTopCutoutFamily.classic,
        rawTop: rawTop,
        topOuter: 6,
        screenFrameTop: 8,
        screenFrameHorizontal: _frameHorizontal,
        screenFrameBottom: 8,
        bezelTop: _defaultBezel,
        bezelHorizontal: _defaultBezel,
        bezelBottom: _defaultBezel,
      );
    }

    switch (family) {
      case DeviceTopCutoutFamily.classic:
        return ChassisInsets(
          family: family,
          rawTop: rawTop,
          topOuter: 8,
          screenFrameTop: 10,
          screenFrameHorizontal: _frameHorizontal,
          screenFrameBottom: 8,
          bezelTop: _defaultBezel,
          bezelHorizontal: _defaultBezel,
          bezelBottom: _defaultBezel,
        );

      case DeviceTopCutoutFamily.statusBar:
        // Punch-hole: move the whole module so the **outer white rim** sits
        // just above the hole top (hole falls into the bezel, not over the rim).
        //
        // hole top ≈ upper portion of the status strip (not mid-status).
        // Extra −2.5 lifts the module so the thin white rim is not clipped
        // by the camera hole (Meizu-style center/left punch).
        final holeTop =
            ((rawTop * 0.22).clamp(5.0, 10.0) - 2.5).clamp(2.5, 8.0);
        return ChassisInsets(
          family: family,
          rawTop: rawTop,
          topOuter: holeTop,
          screenFrameTop: 0,
          screenFrameHorizontal: _frameHorizontal,
          screenFrameBottom: 8,
          bezelTop: _defaultBezel,
          bezelHorizontal: _defaultBezel,
          bezelBottom: _defaultBezel,
          // Status chrome breathing room under the inner rim.
          glassContentTop: 9,
        );

      case DeviceTopCutoutFamily.notch:
        return ChassisInsets(
          family: family,
          rawTop: rawTop,
          topOuter: 4,
          screenFrameTop: 0,
          screenFrameHorizontal: _frameHorizontal,
          screenFrameBottom: 8,
          bezelTop: _defaultBezel,
          bezelHorizontal: _defaultBezel,
          bezelBottom: _defaultBezel,
        );

      case DeviceTopCutoutFamily.island:
        return ChassisInsets(
          family: family,
          rawTop: rawTop,
          topOuter: 4,
          screenFrameTop: 0,
          screenFrameHorizontal: _frameHorizontal,
          screenFrameBottom: 8,
          bezelTop: _defaultBezel,
          bezelHorizontal: _defaultBezel,
          bezelBottom: _defaultBezel,
        );
    }
  }

  static double _rawTop(MediaQueryData mq) {
    if (mq.viewPadding.top > 0) {
      return mq.viewPadding.top;
    }
    return mq.padding.top;
  }

  static DeviceTopCutoutFamily _family(MediaQueryData mq, double rawTop) {
    final width =
        mq.size.width < mq.size.height ? mq.size.width : mq.size.height;

    if (rawTop >= 54 || (rawTop >= 50 && _looksLikeIslandWidth(width))) {
      return DeviceTopCutoutFamily.island;
    }
    if (rawTop >= 40) {
      return DeviceTopCutoutFamily.notch;
    }
    if (rawTop >= 24) {
      return DeviceTopCutoutFamily.statusBar;
    }
    return DeviceTopCutoutFamily.classic;
  }

  static bool _looksLikeIslandWidth(double width) {
    return const [393, 402, 420, 430, 440]
        .any((candidate) => (width - candidate).abs() < 1);
  }
}
