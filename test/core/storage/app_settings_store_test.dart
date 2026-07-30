import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qqmusic_ipod/core/storage/app_settings_store.dart';
import 'package:qqmusic_ipod/features/shell/models/ipod_models.dart';
import 'package:qqmusic_ipod/features/shell/models/menu_catalog.dart';
import 'package:qqmusic_ipod/features/shell/views/widgets/menu_artwork.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('persists gapless playback preference', () async {
    SharedPreferences.setMockInitialValues({});
    final store = AppSettingsStore();

    await store.save(const AppSettingsSnapshot(gaplessPlaybackEnabled: true));
    final loaded = await store.load();

    expect(loaded.gaplessPlaybackEnabled, isTrue);
  });

  test('persists and clears custom background paths', () async {
    SharedPreferences.setMockInitialValues({});
    final store = AppSettingsStore();

    await store.save(
      const AppSettingsSnapshot(
        customBackgroundPath: '/data/user/0/app/backgrounds/background.jpg',
      ),
    );
    expect(
      (await store.load()).customBackgroundPath,
      '/data/user/0/app/backgrounds/background.jpg',
    );

    await store.save(const AppSettingsSnapshot());
    expect((await store.load()).customBackgroundPath, isNull);
  });

  test('settings root contains focused categories', () {
    final settings = qqMusicMenuPages[MenuSection.settings]!;
    final playback = qqMusicMenuPages[MenuSection.playbackSettings]!;
    final appearance = qqMusicMenuPages[MenuSection.appearanceSettings]!;

    expect(settings.entries.map((entry) => entry.section), [
      MenuSection.playbackSettings,
      MenuSection.controlSettings,
      MenuSection.appearanceSettings,
      MenuSection.systemSettings,
    ]);
    expect(playback.entries.map((entry) => entry.setting), [
      AppSetting.playbackQuality,
      AppSetting.gaplessPlayback,
      AppSetting.sleepTimer,
      AppSetting.volumeLimit,
    ]);
    expect(appearance.entries.map((entry) => entry.setting), [
      null,
      AppSetting.customBackground,
      AppSetting.clearCustomBackground,
    ]);
  });

  test('settings categories and playback items use distinct icons', () {
    final categories = qqMusicMenuPages[MenuSection.settings]!.entries;
    final playback = qqMusicMenuPages[MenuSection.playbackSettings]!.entries;

    expect(categories.map(MenuArtwork.iconFor).toSet(), hasLength(4));
    expect(playback.map(MenuArtwork.iconFor).toSet(), hasLength(4));
    expect(
      MenuArtwork.iconFor(categories[0]),
      Icons.play_circle_outline_rounded,
    );
    expect(MenuArtwork.iconFor(categories[1]), Icons.tune_rounded);
  });

  test('sleep timer cycles through supported durations', () {
    expect(AppSleepTimer.off.next, AppSleepTimer.minutes15);
    expect(AppSleepTimer.minutes15.duration, const Duration(minutes: 15));
    expect(AppSleepTimer.minutes90.next, AppSleepTimer.off);
  });
}
