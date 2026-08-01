import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qqmusic_ipod/core/theme/tokens/app_tokens.dart';

void main() {
  test('defines semantic native app visual tokens', () {
    expect(AppColors.interaction, const Color(0xFF9D86FF));
    expect(AppColors.brandQq, const Color(0xFF31C27C));
    expect(AppColors.vip, const Color(0xFFF2C14E));
    expect(AppTextStyles.regular, FontWeight.w500);
    expect(AppTextStyles.strong, FontWeight.w700);
    expect(AppTextStyles.heavy, FontWeight.w800);
    expect(AppDurations.press, const Duration(milliseconds: 120));
    expect(AppDurations.scene, const Duration(milliseconds: 280));
    expect(AppDurations.reducedMotion, const Duration(milliseconds: 120));
    expect(AppCurves.sceneEase, const Cubic(0.23, 1, 0.32, 1));
    expect(AppCurves.movementEase, const Cubic(0.77, 0, 0.175, 1));
  });

  testWidgets('semantic text roles remain readable at larger text scale', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(1.3)),
        child: MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                Text('歌曲标题', style: AppTextStyles.title),
                Text('歌手与专辑信息', style: AppTextStyles.metadata),
              ],
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('歌曲标题'), findsOneWidget);
    expect(find.text('歌手与专辑信息'), findsOneWidget);
  });
}
