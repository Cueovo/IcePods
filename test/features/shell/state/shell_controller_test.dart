import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qqmusic_ipod/business/entities/auth.dart';
import 'package:qqmusic_ipod/business/entities/music.dart';
import 'package:qqmusic_ipod/business/repositories/music_repository.dart';
import 'package:qqmusic_ipod/core/storage/chassis_color_store.dart';
import 'package:qqmusic_ipod/features/shell/models/ipod_models.dart';
import 'package:qqmusic_ipod/features/shell/state/shell_controller.dart';

Widget _host(ShellController shell) {
  return MaterialApp(
    home: Scaffold(
      body: PageView(
        controller: shell.pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: List<Widget>.generate(
          5,
          (index) => Center(child: Text('page-$index')),
        ),
      ),
    ),
  );
}

Future<ShellController> _pumpShell(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final shell = ShellController(api: const _FakeApi());
  addTearDown(shell.dispose);
  await tester.pumpWidget(_host(shell));
  await tester.pump();
  return shell;
}

void main() {
  testWidgets('fresh installs use the classic silver chassis', (tester) async {
    final shell = await _pumpShell(tester);

    expect(ChassisColorStore.defaultColor, const Color(0xFFC8C8C8));
    expect(shell.chassisColor, ChassisColorStore.defaultColor);
  });

  testWidgets('non-adjacent modes cut instead of scrolling through pages', (
    tester,
  ) async {
    final shell = await _pumpShell(tester);

    // Menu (page 0) to player (page 2) must not scroll through Cover Flow:
    // the PageView would build and flash every page in between.
    final flight = shell.switchMode(PlayerMode.player);
    await tester.pump();

    expect(shell.pageController.page, closeTo(2, 0.001));

    await tester.pumpAndSettle();
    await flight;

    expect(shell.mode, PlayerMode.player);
  });

  testWidgets('adjacent modes animate between their pages', (tester) async {
    final shell = await _pumpShell(tester);

    // Menu (0) to Cover Flow (1) is adjacent, so it moves.
    final flight = shell.switchMode(PlayerMode.coverFlow);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 140));

    final midFlight = shell.pageController.page!;
    expect(midFlight, greaterThan(0.0));
    expect(midFlight, lessThan(1.0));

    await tester.pumpAndSettle();
    await flight;

    expect(shell.pageController.page, closeTo(1, 0.001));
    expect(shell.mode, PlayerMode.coverFlow);
  });

  testWidgets('queue and player transitions land on their pages', (
    tester,
  ) async {
    final shell = await _pumpShell(tester);

    // The flight future only resolves while the tester pumps frames, so keep
    // it and await it after settling.
    final toPlayer = shell.switchMode(PlayerMode.player);
    await tester.pumpAndSettle();
    await toPlayer;

    final toQueue = shell.switchMode(PlayerMode.queue);
    await tester.pumpAndSettle();
    await toQueue;
    expect(shell.pageController.page, closeTo(4, 0.001));

    final backToPlayer = shell.switchMode(PlayerMode.player);
    await tester.pumpAndSettle();
    await backToPlayer;
    expect(shell.pageController.page, closeTo(2, 0.001));
    expect(shell.mode, PlayerMode.player);
  });

  testWidgets('queue returns to the radar feature that opened it', (
    tester,
  ) async {
    final shell = await _pumpShell(tester);

    final toFeature = shell.switchMode(PlayerMode.feature);
    await tester.pumpAndSettle();
    await toFeature;

    shell.openQueue();
    await tester.pumpAndSettle();
    expect(shell.mode, PlayerMode.queue);

    shell.handleMenu();
    await tester.pumpAndSettle();

    expect(shell.mode, PlayerMode.feature);
    expect(shell.pageController.page, closeTo(3, 0.001));
  });

  testWidgets('a superseded destination retargets without ghost pages', (
    tester,
  ) async {
    final shell = await _pumpShell(tester);

    // Cover Flow is adjacent to the menu, so this one is a real flight that
    // gets interrupted mid-air.
    final superseded = shell.switchMode(PlayerMode.coverFlow);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    final retargeted = shell.switchMode(PlayerMode.queue);

    await tester.pumpAndSettle();
    await superseded;
    await retargeted;

    expect(shell.mode, PlayerMode.queue);
    expect(shell.pageController.page, closeTo(4, 0.001));
  });

  testWidgets('reduced motion jumps to the destination page', (tester) async {
    final shell = await _pumpShell(tester);
    shell.syncReducedMotion(true);

    final flight = shell.switchMode(PlayerMode.queue);
    await tester.pump();

    expect(shell.pageController.page, closeTo(4, 0.001));
    await flight;
    expect(shell.mode, PlayerMode.queue);
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
