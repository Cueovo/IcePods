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
    test('classifies cutout families', () {
      expect(
        ChassisInsets.resolve(mq(size: const Size(375, 667), top: 20)).family,
        DeviceTopCutoutFamily.classic,
      );
      expect(
        ChassisInsets.resolve(mq(size: const Size(390, 844), top: 28)).family,
        DeviceTopCutoutFamily.statusBar,
      );
      expect(
        ChassisInsets.resolve(mq(size: const Size(390, 844), top: 47)).family,
        DeviceTopCutoutFamily.notch,
      );
      expect(
        ChassisInsets.resolve(mq(size: const Size(393, 852), top: 59)).family,
        DeviceTopCutoutFamily.island,
      );
    });

    test('punch-hole keeps uniform bezel and no residual glass padding', () {
      final insets = ChassisInsets.resolve(
        mq(size: const Size(390, 844), top: 28),
      );
      expect(insets.bezelTop, insets.bezelBottom);
      expect(insets.bezelTop, insets.bezelHorizontal);
      expect(insets.residualTopInset(), 0);
      expect(insets.topOuter, greaterThan(0));
      expect(insets.topOuter, lessThan(insets.rawTop));
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
    });

    test('landscape stays classic', () {
      final insets = ChassisInsets.resolve(
        mq(size: const Size(844, 390), top: 0),
      );
      expect(insets.family, DeviceTopCutoutFamily.classic);
    });
  });

  group('ScreenCornerRadius', () {
    test('iOS matches device curve; Android keeps themed fallback', () {
      final media = mq(size: const Size(393, 852), top: 59);
      final insets = ChassisInsets.resolve(media);

      expect(
        ScreenCornerRadius.outerFrame(
          mq: media,
          insets: insets,
          fallback: 36,
          platform: TargetPlatform.android,
        ),
        36,
      );

      final ios = ScreenCornerRadius.outerFrame(
        mq: media,
        insets: insets,
        fallback: 36,
        platform: TargetPlatform.iOS,
      );
      expect(ios, isNot(36));
      expect(ios, lessThan(55));
      expect(ios, greaterThan(20));
    });

    test('iOS classic SE keeps themed radius', () {
      final media = mq(size: const Size(375, 667), top: 20);
      final insets = ChassisInsets.resolve(media);
      expect(
        ScreenCornerRadius.outerFrame(
          mq: media,
          insets: insets,
          fallback: 36,
          platform: TargetPlatform.iOS,
        ),
        36,
      );
    });
  });
}
