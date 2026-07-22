import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'package:qqmusic_ipod/core/utils/device_display_metrics.dart';

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
        // Match horizontal frame inset so top corners stay concentric with
        // the physical display curve (uneven top/side margin warps the look).
        return ChassisInsets(
          family: family,
          rawTop: rawTop,
          topOuter: _frameHorizontal,
          screenFrameTop: 0,
          screenFrameHorizontal: _frameHorizontal,
          screenFrameBottom: 8,
          bezelTop: _defaultBezel,
          bezelHorizontal: _defaultBezel,
          bezelBottom: _defaultBezel,
        );

      case DeviceTopCutoutFamily.island:
        // Island sits a bit lower than a pure 8pt inset; keep top/side equal
        // so the superellipse stays concentric with the physical display curve.
        // Clearance for the island itself still comes from residual top in glass.
        const islandOuter = 6.0;
        return ChassisInsets(
          family: family,
          rawTop: rawTop,
          topOuter: islandOuter,
          screenFrameTop: 0,
          screenFrameHorizontal: islandOuter,
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

/// iOS display-corner matching for the simulated screen module.
///
/// On iPhone the physical display is a continuous (squircle) curve. The framed
/// glass sits inset from that edge; its outer radius should be concentric:
/// `deviceCorner − outerMargin`. Prefer the live [DeviceDisplayMetrics] value
/// from `UIScreen` when available. Android keeps the themed iPod radius.
class ScreenCornerRadius {
  const ScreenCornerRadius._();

  /// Outer [RoundedSuperellipseBorder] radius for the white-rim screen frame.
  static double outerFrame({
    required MediaQueryData mq,
    required ChassisInsets insets,
    required double fallback,
    TargetPlatform? platform,
  }) {
    final target = platform ?? defaultTargetPlatform;
    if (target != TargetPlatform.iOS) {
      return fallback;
    }
    final device = deviceDisplayCorner(mq: mq, family: insets.family);
    if (device <= 0) {
      // Classic flat-top SE: keep the designed iPod panel radius.
      return fallback;
    }
    // Use the larger of top/side outer margins so the superellipse stays inside
    // the physical curve when topOuter != horizontal (should match after equalize).
    final topMargin = insets.frameTopFromScreen;
    final sideMargin = insets.screenFrameHorizontal;
    final margin = topMargin > sideMargin ? topMargin : sideMargin;
    final concentric = device - margin;
    // Never inflate past the physical device curve; floor so the panel
    // still reads as rounded if margins were unusually large.
    return concentric.clamp(20.0, device);
  }

  /// Continuous display corner radius in logical points.
  ///
  /// Prefers [DeviceDisplayMetrics.displayCornerRadius] (native KVC). Falls
  /// back to a short-side + cutout-family table when the channel is cold.
  static double deviceDisplayCorner({
    required MediaQueryData mq,
    required DeviceTopCutoutFamily family,
  }) {
    final live = DeviceDisplayMetrics.displayCornerRadius;
    if (live != null && live > 0) {
      return live;
    }
    return _heuristicDeviceCorner(mq: mq, family: family);
  }

  /// Known iPhone display corner radii (logical points), by short side + family.
  ///
  /// Sources: community measurements of `UIScreen._displayCornerRadius` /
  /// public design references — used only when the platform channel is empty.
  static double _heuristicDeviceCorner({
    required MediaQueryData mq,
    required DeviceTopCutoutFamily family,
  }) {
    final w = mq.size.width;
    final h = mq.size.height;
    final short = w < h ? w : h;

    switch (family) {
      case DeviceTopCutoutFamily.classic:
        // Home-button SE / 8: square glass, no continuous device curve to match.
        return 0;

      case DeviceTopCutoutFamily.notch:
        // X / XS / 11 Pro ≈ 39; XR / 11 ≈ 41.5; 12–14 / mini ≈ 47.33;
        // 12–13 Pro Max / 14 Plus ≈ 53.33.
        if (short >= 428) return 53.33;
        if ((short - 414).abs() < 1) {
          // XR / 11 (414×896) ≈ 41.5; XS Max / 11 Pro Max ≈ 39.
          final long = w > h ? w : h;
          return long >= 890 ? 39.0 : 41.5;
        }
        if (short >= 390) return 47.33;
        // 375-wide: X / XS / 11 Pro / 12–13 mini.
        final rawTop =
            mq.viewPadding.top > 0 ? mq.viewPadding.top : mq.padding.top;
        // Pre-12 status band ~44; 12+ mini ~50.
        if (rawTop >= 47) return 47.33;
        return 39.0;

      case DeviceTopCutoutFamily.island:
        // 14 Pro / 15 / 16 standard island ≈ 55; 16 Pro family is slightly
        // larger (~62). Prefer the live channel when available.
        if (short >= 430) return 55.0; // 14/15/16 Pro Max class
        if (short >= 402) return 55.0; // 14/15/16 Pro
        return 55.0;

      case DeviceTopCutoutFamily.statusBar:
        // Not an iPhone cutout profile; no device match.
        return 0;
    }
  }
}
