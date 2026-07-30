import 'package:shared_preferences/shared_preferences.dart';

enum AppSetting {
  clickSound,
  playbackQuality,
  gaplessPlayback,
  sleepTimer,
  volumeLimit,
  customBackground,
  clearCustomBackground,
  haptics,
  clearCache,
  about,
}

enum PlaybackQuality {
  standard('标准', 13),
  high('高品', 4),
  lossless('无损', 5);

  const PlaybackQuality(this.label, this.fileType);

  final String label;
  final int fileType;

  PlaybackQuality get next =>
      PlaybackQuality.values[(index + 1) % PlaybackQuality.values.length];
}

enum AppVolumeLimit {
  off('关闭', 1),
  safe('85%', .85),
  low('70%', .7);

  const AppVolumeLimit(this.label, this.gain);

  final String label;
  final double gain;

  AppVolumeLimit get next =>
      AppVolumeLimit.values[(index + 1) % AppVolumeLimit.values.length];
}

enum AppSleepTimer {
  off('关闭', null),
  minutes15('15 分钟', Duration(minutes: 15)),
  minutes30('30 分钟', Duration(minutes: 30)),
  minutes60('60 分钟', Duration(minutes: 60)),
  minutes90('90 分钟', Duration(minutes: 90));

  const AppSleepTimer(this.label, this.duration);

  final String label;
  final Duration? duration;

  AppSleepTimer get next =>
      AppSleepTimer.values[(index + 1) % AppSleepTimer.values.length];
}

class AppSettingsSnapshot {
  const AppSettingsSnapshot({
    this.clickSoundEnabled = true,
    this.hapticsEnabled = true,
    this.gaplessPlaybackEnabled = false,
    this.playbackQuality = PlaybackQuality.standard,
    this.volumeLimit = AppVolumeLimit.off,
    this.customBackgroundPath,
  });

  final bool clickSoundEnabled;
  final bool hapticsEnabled;
  final bool gaplessPlaybackEnabled;
  final PlaybackQuality playbackQuality;
  final AppVolumeLimit volumeLimit;
  final String? customBackgroundPath;
}

class AppSettingsStore {
  AppSettingsStore([this._preferences]);

  static const _clickSoundKey = 'ipod.settings.click_sound';
  static const _hapticsKey = 'ipod.settings.haptics';
  static const _gaplessPlaybackKey = 'ipod.settings.gapless_playback';
  static const _playbackQualityKey = 'ipod.settings.playback_quality';
  static const _volumeLimitKey = 'ipod.settings.volume_limit';
  static const _customBackgroundPathKey =
      'ipod.settings.custom_background_path';

  SharedPreferences? _preferences;

  Future<SharedPreferences> _prefs() async {
    return _preferences ??= await SharedPreferences.getInstance();
  }

  Future<AppSettingsSnapshot> load() async {
    final preferences = await _prefs();
    return AppSettingsSnapshot(
      clickSoundEnabled: preferences.getBool(_clickSoundKey) ?? true,
      hapticsEnabled: preferences.getBool(_hapticsKey) ?? true,
      gaplessPlaybackEnabled: preferences.getBool(_gaplessPlaybackKey) ?? false,
      customBackgroundPath: preferences.getString(_customBackgroundPathKey),
      playbackQuality: _enumByName(
        PlaybackQuality.values,
        preferences.getString(_playbackQualityKey),
        PlaybackQuality.standard,
      ),
      volumeLimit: _enumByName(
        AppVolumeLimit.values,
        preferences.getString(_volumeLimitKey),
        AppVolumeLimit.off,
      ),
    );
  }

  Future<void> save(AppSettingsSnapshot settings) async {
    final preferences = await _prefs();
    await preferences.setBool(_clickSoundKey, settings.clickSoundEnabled);
    await preferences.setBool(_hapticsKey, settings.hapticsEnabled);
    await preferences.setBool(
      _gaplessPlaybackKey,
      settings.gaplessPlaybackEnabled,
    );
    final customBackgroundPath = settings.customBackgroundPath;
    if (customBackgroundPath == null || customBackgroundPath.isEmpty) {
      await preferences.remove(_customBackgroundPathKey);
    } else {
      await preferences.setString(
        _customBackgroundPathKey,
        customBackgroundPath,
      );
    }
    await preferences.setString(
      _playbackQualityKey,
      settings.playbackQuality.name,
    );
    await preferences.setString(_volumeLimitKey, settings.volumeLimit.name);
  }

  T _enumByName<T extends Enum>(List<T> values, String? name, T fallback) {
    for (final value in values) {
      if (value.name == name) {
        return value;
      }
    }
    return fallback;
  }
}
