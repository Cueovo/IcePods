import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qqmusic_ipod/business/entities/auth.dart';
import 'package:qqmusic_ipod/business/entities/music.dart';
import 'package:qqmusic_ipod/business/repositories/music_repository.dart';
import 'package:qqmusic_ipod/core/theme/widgets/click_wheel.dart';
import 'package:qqmusic_ipod/core/utils/shell_layout_metrics.dart';
import 'package:qqmusic_ipod/features/shell/views/pages/ipod_screen.dart';

Future<void> _pumpShell(
  WidgetTester tester,
  Size size, {
  double textScale = 1,
}) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(() {
    tester.view.resetDevicePixelRatio();
    tester.view.resetPhysicalSize();
  });

  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: size,
          textScaler: TextScaler.linear(textScale),
          padding: const EdgeInsets.only(top: 24, bottom: 16),
          viewPadding: const EdgeInsets.only(top: 24, bottom: 16),
        ),
        child: IpodScreen(api: const _FakeApi()),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('ShellLayoutMetrics', () {
    test('chooses a composition from the viewport', () {
      ShellLayoutMode modeFor(Size size) =>
          ShellLayoutMetrics.resolve(MediaQueryData(size: size)).mode;

      expect(modeFor(const Size(320, 568)), ShellLayoutMode.compactPortrait);
      expect(modeFor(const Size(340, 800)), ShellLayoutMode.compactPortrait);
      expect(modeFor(const Size(390, 844)), ShellLayoutMode.standardPortrait);
      expect(modeFor(const Size(430, 932)), ShellLayoutMode.standardPortrait);
      expect(modeFor(const Size(834, 1194)), ShellLayoutMode.widePortrait);
      expect(modeFor(const Size(844, 390)), ShellLayoutMode.landscape);
    });

    test('keeps the menu rail inside the documented range', () {
      for (final size in const [
        Size(320, 568),
        Size(390, 844),
        Size(834, 1194),
        Size(844, 390),
      ]) {
        final metrics = ShellLayoutMetrics.resolve(MediaQueryData(size: size));
        expect(metrics.menuRailWidth, greaterThanOrEqualTo(132));
        expect(metrics.menuRailWidth, lessThanOrEqualTo(190));
      }
    });

    test('sizes the wheel from its band, never above the maximum', () {
      final metrics = ShellLayoutMetrics.resolve(
        const MediaQueryData(size: Size(390, 844)),
      );

      expect(metrics.wheelDiameterFor(const Size(390, 200)), closeTo(184, 0.1));
      expect(
        metrics.wheelDiameterFor(const Size(600, 600)),
        ShellLayoutMetrics.referenceWheelDiameter,
      );
    });
  });

  group('IpodScreen composition', () {
    for (final size in const [
      Size(320, 568),
      Size(360, 800),
      Size(390, 844),
      Size(430, 932),
      Size(844, 390),
    ]) {
      testWidgets('lays out without overflow at ${size.width}x${size.height}', (
        tester,
      ) async {
        await _pumpShell(tester, size);
        expect(tester.takeException(), isNull);
        expect(find.byType(ClickWheel), findsOneWidget);
      });
    }

    testWidgets('lays out without overflow at 1.3x text scale', (tester) async {
      await _pumpShell(tester, const Size(390, 844), textScale: 1.3);
      expect(tester.takeException(), isNull);
    });

    testWidgets('landscape stands the wheel beside the glass', (tester) async {
      await _pumpShell(tester, const Size(844, 390));

      final glass = tester.getRect(
        find.byKey(const ValueKey('ipod-screen-glass')),
      );
      final wheel = tester.getRect(find.byType(ClickWheel));

      expect(wheel.left, greaterThanOrEqualTo(glass.right - 1));
      expect(wheel.top, lessThan(glass.bottom));
    });

    testWidgets('portrait keeps the wheel under the glass', (tester) async {
      await _pumpShell(tester, const Size(390, 844));

      final glass = tester.getRect(
        find.byKey(const ValueKey('ipod-screen-glass')),
      );
      final wheel = tester.getRect(find.byType(ClickWheel));

      expect(wheel.top, greaterThanOrEqualTo(glass.bottom - 1));
      expect(wheel.width, lessThanOrEqualTo(390));
    });
  });
}

class _FakeApi implements QqMusicApi {
  const _FakeApi();

  @override
  QqMusicCredential? get credential => null;

  @override
  bool get isLoggedIn => false;

  @override
  Future<void> restoreSession() async {}

  @override
  Future<void> ensureSessionFresh() async {}

  @override
  Future<QqMusicFeatureResult> loadFeature(
    QqMusicFeature feature, {
    int page = 1,
    int pageSize = 25,
    bool forceRefresh = false,
  }) async {
    return const QqMusicFeatureResult(title: '', items: []);
  }

  @override
  void dispose() {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
