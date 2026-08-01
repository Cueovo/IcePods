import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:qqmusic_ipod/core/audio/click_sound_service.dart';

void main() {
  testWidgets('rapid ticks are queued instead of dropped', (tester) async {
    var playCount = 0;
    final service = ClickSoundService(nativeTick: () async => playCount += 1);

    unawaited(service.playTick());
    unawaited(service.playTick());
    unawaited(service.playTick());

    expect(playCount, 1);
    await tester.pump(
      ClickSoundService.minInterval - const Duration(milliseconds: 1),
    );
    expect(playCount, 1);
    await tester.pump(const Duration(milliseconds: 1));
    expect(playCount, 2);
    await tester.pump(ClickSoundService.minInterval);
    expect(playCount, 3);
    await service.dispose();
  });

  testWidgets('ticks arriving during the gap keep their spacing', (
    tester,
  ) async {
    var playCount = 0;
    final service = ClickSoundService(nativeTick: () async => playCount += 1);

    unawaited(service.playTick());
    await tester.pump(const Duration(milliseconds: 5));
    unawaited(service.playTick());
    expect(playCount, 1);
    await tester.pump(ClickSoundService.minInterval);
    expect(playCount, 2);
    await service.dispose();
  });

  testWidgets('large bursts keep a bounded responsive backlog', (tester) async {
    var playCount = 0;
    final service = ClickSoundService(nativeTick: () async => playCount += 1);

    for (var index = 0; index < 100; index += 1) {
      unawaited(service.playTick());
    }
    await tester.pump(
      ClickSoundService.minInterval * ClickSoundService.maxPendingTicks,
    );

    expect(playCount, ClickSoundService.maxPendingTicks);
    await service.dispose();
  });

  testWidgets('clearing pending ticks keeps only in-flight feedback', (
    tester,
  ) async {
    var playCount = 0;
    final service = ClickSoundService(nativeTick: () async => playCount += 1);

    unawaited(service.playTick());
    unawaited(service.playTick());
    unawaited(service.playTick());
    service.clearPendingTicks();
    await tester.pump(ClickSoundService.minInterval * 3);

    expect(playCount, 1);
    await service.dispose();
  });

  testWidgets('disposing during a native call prevents queued feedback', (
    tester,
  ) async {
    final nativeCall = Completer<void>();
    var playCount = 0;
    final service = ClickSoundService(
      nativeTick: () {
        playCount += 1;
        return nativeCall.future;
      },
    );

    unawaited(service.playTick());
    unawaited(service.playTick());
    await service.dispose();
    nativeCall.completeError(StateError('native channel closed'));
    await tester.pump(ClickSoundService.minInterval * 3);

    expect(playCount, 1);
  });

  testWidgets('disposing clears queued ticks', (tester) async {
    var playCount = 0;
    final service = ClickSoundService(nativeTick: () async => playCount += 1);

    unawaited(service.playTick());
    unawaited(service.playTick());
    unawaited(service.playTick());
    expect(playCount, 1);

    await service.dispose();
    await tester.pump(ClickSoundService.minInterval * 3);
    expect(playCount, 1);
  });

  test('iOS haptic levels use distinct native feedback calls', () async {
    final methods = <String>[];
    final service = WheelHapticsService(
      nativeFeedback: (method) async => methods.add(method),
    );

    await service.selectionClick();
    await service.lightImpact();
    await service.mediumImpact();

    expect(methods, ['selectionChanged', 'lightImpact', 'mediumImpact']);
  });
}
