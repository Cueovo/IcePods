import 'package:shared_preferences/shared_preferences.dart';

enum AppSetting {
  clickSound,
  playbackQuality,
  volumeLimit,
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

class AppSettingsSnapshot {
  const AppSettingsSnapshot({
    this.clickSoundEnabled = true,
    this.hapticsEnabled = true,
    this.playbackQuality = PlaybackQuality.standard,
    this.volumeLimit = AppVolumeLimit.off,
  });

  final bool clickSoundEnabled;
  final bool hapticsEnabled;
  final PlaybackQuality playbackQuality;
  final AppVolumeLimit volumeLimit;
}

class AppSettingsStore {
  AppSettingsStore([this._preferences]);

  static const _clickSoundKey = 'ipod.settings.click_sound';
  static const _hapticsKey = 'ipod.settings.haptics';
  static const _playbackQualityKey = 'ipod.settings.playback_quality';
  static const _volumeLimitKey = 'ipod.settings.volume_limit';

  SharedPreferences? _preferences;

  Future<SharedPreferences> _prefs() async {
    return _preferences ??= await SharedPreferences.getInstance();
  }

  Future<AppSettingsSnapshot> load() async {
    final preferences = await _prefs();
    return AppSettingsSnapshot(
      clickSoundEnabled: preferences.getBool(_clickSoundKey) ?? true,
      hapticsEnabled: preferences.getBool(_hapticsKey) ?? true,
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
