import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qqmusic_ipod/features/shell/views/widgets/chassis_insets.dart';

void main() {
  MediaQueryData mq({
    required Size size,
    required double top,
  }) {
    return MediaQueryData(
      size: size,
      padding: EdgeInsets.only(top: top),
      viewPadding: EdgeInsets.only(top: top),
    );
  }

  group('ChassisInsets', () {
    test('classic SE-like flat top (rawTop ~20)', () {
      final insets = ChassisInsets.resolve(
        mq(size: const Size(375, 667), top: 20),
      );
      expect(insets.family, DeviceTopCutoutFamily.classic);
      expect(insets.topOuter, 8);
      expect(insets.screenFrameTop, 10);
      expect(insets.bezelTop, 5);
      expect(insets.bezelBottom, 5);
      expect(insets.frameTopFromScreen, 18);
      expect(insets.residualTopInset(), 0);
    });

    test('Android punch-hole: whole module shifts, uniform bezel', () {
      final insets = ChassisInsets.resolve(
        mq(size: const Size(390, 844), top: 28),
      );
      expect(insets.family, DeviceTopCutoutFamily.statusBar);
      // Outer white rim just above hole top (−2.5 so rim is not clipped).
      expect(insets.topOuter, closeTo(3.66, .01)); // 28*0.22 - 2.5
      expect(insets.screenFrameTop, 0);
      expect(insets.frameTopFromScreen, closeTo(3.66, .01));
      // Top bezel == bottom / sides — not a fat crop bar.
      expect(insets.bezelTop, 5);
      expect(insets.bezelBottom, 5);
      expect(insets.bezelHorizontal, 5);
      expect(insets.glassContentTop, 9);
      // No residual status padding inside glass (avoids double gap).
      expect(insets.residualTopInset(), 0);
    });

    test('Android punch-hole scales outer with taller status', () {
      final insets = ChassisInsets.resolve(
        mq(size: const Size(412, 915), top: 36),
      );
      expect(insets.family, DeviceTopCutoutFamily.statusBar);
      expect(insets.topOuter, closeTo(5.42, .01)); // 36*0.22 - 2.5
      expect(insets.bezelTop, 5);
      expect(insets.glassContentTop, 9);
      expect(insets.residualTopInset(), 0);
    });

    test('taller waterfall / notch band', () {
      final insets = ChassisInsets.resolve(
        mq(size: const Size(412, 915), top: 48),
      );
      expect(insets.family, DeviceTopCutoutFamily.notch);
      expect(insets.topOuter, 4);
      expect(insets.bezelTop, 5);
      expect(insets.residualTopInset(), greaterThan(0));
    });

    test('iPhone notch family', () {
      final insets = ChassisInsets.resolve(
        mq(size: const Size(390, 844), top: 47),
      );
      expect(insets.family, DeviceTopCutoutFamily.notch);
      expect(insets.topOuter, 4);
      expect(insets.bezelTop, 5);
    });

    test('Dynamic Island family', () {
      final insets = ChassisInsets.resolve(
        mq(size: const Size(393, 852), top: 59),
      );
      expect(insets.family, DeviceTopCutoutFamily.island);
      expect(insets.topOuter, 4);
      expect(insets.bezelTop, 5);
    });

    test('uses viewPadding when padding is zero (immersive)', () {
      const data = MediaQueryData(
        size: Size(393, 852),
        padding: EdgeInsets.zero,
        viewPadding: EdgeInsets.only(top: 59),
      );
      final insets = ChassisInsets.resolve(data);
      expect(insets.rawTop, 59);
      expect(insets.family, DeviceTopCutoutFamily.island);
      expect(insets.topOuter, 4);
    });

    test('landscape stays compact classic', () {
      final insets = ChassisInsets.resolve(
        mq(size: const Size(844, 390), top: 0),
      );
      expect(insets.family, DeviceTopCutoutFamily.classic);
      expect(insets.topOuter, 6);
    });
  });
}
