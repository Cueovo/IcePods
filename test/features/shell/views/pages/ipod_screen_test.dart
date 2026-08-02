import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qqmusic_ipod/business/entities/auth.dart';
import 'package:qqmusic_ipod/business/entities/music.dart';
import 'package:qqmusic_ipod/business/repositories/music_repository.dart';
import 'package:qqmusic_ipod/features/shell/views/pages/ipod_screen.dart';

void main() {
  testWidgets('keeps the bottom screen bezel on iOS', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });

    const media = MediaQueryData(
      size: Size(390, 844),
      padding: EdgeInsets.only(top: 47, bottom: 34),
      viewPadding: EdgeInsets.only(top: 47, bottom: 34),
    );
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: media,
          child: IpodScreen(api: _FakeApi()),
        ),
      ),
    );
    await tester.pump();

    final bezel = tester.widget<Padding>(
      find.byKey(const ValueKey('ipod-screen-bezel-padding')),
    );

    expect(bezel.padding, const EdgeInsets.all(5));
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
