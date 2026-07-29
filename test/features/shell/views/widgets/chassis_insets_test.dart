import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qqmusic_ipod/features/shell/views/widgets/chassis_insets.dart';

void main() {
  group('ChassisInsets iOS bezel', () {
    test('keeps a complete bezel on notch devices', () {
      final insets = ChassisInsets.resolve(
        const MediaQueryData(
          size: Size(390, 844),
          padding: EdgeInsets.only(top: 47, bottom: 34),
          viewPadding: EdgeInsets.only(top: 47, bottom: 34),
        ),
      );

      expect(insets.family, DeviceTopCutoutFamily.notch);
      expect(insets.bezelPadding, const EdgeInsets.all(5));
      expect(insets.screenFramePadding.bottom, 8);
    });

    test('keeps a complete bezel on Dynamic Island devices', () {
      final insets = ChassisInsets.resolve(
        const MediaQueryData(
          size: Size(393, 852),
          padding: EdgeInsets.only(top: 59, bottom: 34),
          viewPadding: EdgeInsets.only(top: 59, bottom: 34),
        ),
      );

      expect(insets.family, DeviceTopCutoutFamily.island);
      expect(insets.bezelPadding, const EdgeInsets.all(5));
      expect(insets.screenFramePadding.bottom, 8);
    });
  });
}
