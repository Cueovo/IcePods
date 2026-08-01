import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qqmusic_ipod/core/theme/widgets/click_wheel.dart';

class _WheelLog {
  final List<String> events = [];
  double rotation = 0;
}

Widget _host(_WheelLog log, {bool reduceMotion = false}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion),
      child: Scaffold(
        body: Center(
          child: ClickWheel(
            onRotate: (delta) => log.rotation += delta,
            onRotationEnd: () => log.events.add('rotation-end'),
            onCenter: () => log.events.add('center'),
            onMenu: () => log.events.add('menu'),
            onPrevious: () => log.events.add('previous'),
            onNext: () => log.events.add('next'),
            onPlayPause: () => log.events.add('play-pause'),
            isPlaying: false,
          ),
        ),
      ),
    ),
  );
}

Finder _pressPill(Finder button) {
  return find.descendant(of: button, matching: find.byType(AnimatedContainer));
}

Finder _centerButton() {
  return find.byWidgetPredicate(
    (widget) =>
        widget is AnimatedContainer &&
        widget.decoration is BoxDecoration &&
        (widget.decoration! as BoxDecoration).shape == BoxShape.circle,
  );
}

double _scaleOf(WidgetTester tester, Finder button) {
  return tester
      .widget<AnimatedScale>(
        find.descendant(of: button, matching: find.byType(AnimatedScale)),
      )
      .scale;
}

void main() {
  testWidgets('each sector still reports its own action', (tester) async {
    final log = _WheelLog();
    await tester.pumpWidget(_host(log));
    final center = tester.getCenter(find.byType(ClickWheel));

    for (final (offset, expected) in <(Offset, String)>[
      (const Offset(0, -120), 'menu'),
      (const Offset(0, 120), 'play-pause'),
      (const Offset(-120, 0), 'previous'),
      (const Offset(120, 0), 'next'),
      (Offset.zero, 'center'),
    ]) {
      await tester.tapAt(center + offset);
      await tester.pump();
      expect(log.events.last, expected);
    }

    expect(log.events.length, 5);
  });

  testWidgets('holding a sector compresses only that button', (tester) async {
    final log = _WheelLog();
    await tester.pumpWidget(_host(log));
    final center = tester.getCenter(find.byType(ClickWheel));
    final menu = find.byKey(const ValueKey('menu-button'));
    final next = find.ancestor(
      of: find.byIcon(Icons.skip_next_rounded),
      matching: find.byType(SizedBox),
    );

    expect(_scaleOf(tester, menu), 1);

    final gesture = await tester.startGesture(center + const Offset(0, -120));
    await tester.pump();

    expect(_scaleOf(tester, menu), 0.96);
    expect(_scaleOf(tester, next.first), 1);
    expect(
      (tester.widget<AnimatedContainer>(_pressPill(menu)).decoration!
              as BoxDecoration)
          .color,
      isNot(Colors.transparent),
    );

    await gesture.up();
    await tester.pumpAndSettle();

    expect(_scaleOf(tester, menu), 1);
    expect(log.events, ['menu']);
  });

  testWidgets('pressing the center tightens its shadow', (tester) async {
    final log = _WheelLog();
    await tester.pumpWidget(_host(log));
    final center = tester.getCenter(find.byType(ClickWheel));

    BoxShadow shadow() {
      final decoration =
          tester.widget<AnimatedContainer>(_centerButton()).decoration!
              as BoxDecoration;
      return decoration.boxShadow!.single;
    }

    expect(shadow().blurRadius, 4);

    final gesture = await tester.startGesture(center);
    await tester.pump();
    expect(shadow().blurRadius, 2);

    await gesture.up();
    await tester.pumpAndSettle();
    expect(shadow().blurRadius, 4);
    expect(log.events, ['center']);
  });

  testWidgets('rotating releases the pressed sector without firing it', (
    tester,
  ) async {
    final log = _WheelLog();
    await tester.pumpWidget(_host(log));
    final center = tester.getCenter(find.byType(ClickWheel));
    final menu = find.byKey(const ValueKey('menu-button'));

    final gesture = await tester.startGesture(center + const Offset(0, -120));
    await tester.pump();
    expect(_scaleOf(tester, menu), 0.96);

    await gesture.moveBy(const Offset(40, 24));
    await tester.pump();
    expect(_scaleOf(tester, menu), 1);

    await gesture.up();
    await tester.pumpAndSettle();

    expect(log.rotation, isNot(0));
    expect(log.events, ['rotation-end']);
  });

  testWidgets('reduced motion keeps color feedback without scaling', (
    tester,
  ) async {
    final log = _WheelLog();
    await tester.pumpWidget(_host(log, reduceMotion: true));
    final center = tester.getCenter(find.byType(ClickWheel));
    final menu = find.byKey(const ValueKey('menu-button'));

    expect(find.byType(AnimatedScale), findsNothing);

    final gesture = await tester.startGesture(center + const Offset(0, -120));
    await tester.pump();

    expect(
      (tester.widget<AnimatedContainer>(_pressPill(menu)).decoration!
              as BoxDecoration)
          .color,
      isNot(Colors.transparent),
    );

    await gesture.up();
    await tester.pumpAndSettle();
    expect(log.events, ['menu']);
  });

  testWidgets('every wheel action keeps an accessible label', (tester) async {
    final log = _WheelLog();
    await tester.pumpWidget(_host(log));

    final labels = tester
        .widgetList<Semantics>(find.byType(Semantics))
        .map((widget) => widget.properties.label)
        .whereType<String>()
        .toSet();

    expect(labels, containsAll(['返回菜单', '上一首', '下一首', '播放', '确认']));
  });
}
