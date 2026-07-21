import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('iOS enables background audio without broad transport exceptions', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();

    expect(
      plist,
      contains(
        RegExp(
          r'<key>UIBackgroundModes</key>\s*<array>\s*<string>audio</string>\s*</array>',
        ),
      ),
    );
    expect(plist, isNot(contains('<key>NSAllowsArbitraryLoads</key>')));
  });
}
