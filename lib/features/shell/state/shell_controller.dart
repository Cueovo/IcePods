import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:qqmusic_ipod/business/repositories/music_repository.dart';
import 'package:qqmusic_ipod/core/audio/audio_handler.dart';
import 'package:qqmusic_ipod/core/audio/click_sound_service.dart';
import 'package:qqmusic_ipod/core/storage/app_settings_store.dart';
import 'package:qqmusic_ipod/core/storage/chassis_color_store.dart';
import 'package:qqmusic_ipod/core/storage/custom_background_picker.dart';
import 'package:qqmusic_ipod/features/player/state/controller.dart';
import 'package:qqmusic_ipod/features/shell/models/ipod_models.dart';
import 'package:qqmusic_ipod/features/shell/models/menu_catalog.dart';

class ShellController extends ChangeNotifier {
  ShellController({
    required QqMusicApi api,
    QqMusicAudioHandler? audioHandler,
    ClickSoundService? clickSound,
    PageController? pageController,
    ChassisColorStore? chassisColorStore,
    AppSettingsStore? settingsStore,
    CustomBackgroundPicker? customBackgroundPicker,
  }) : music = QqMusicController(api: api, audioHandler: audioHandler),
       _clickSound = clickSound ?? ClickSoundService(),
       pageController = pageController ?? PageController(),
       _chassisColorStore = chassisColorStore ?? ChassisColorStore(),
       _settingsStore = settingsStore ?? AppSettingsStore(),
       _customBackgroundPicker =
           customBackgroundPicker ?? CustomBackgroundPicker(),
       inactivePlaybackProgress = ValueNotifier(
         const QqMusicPlaybackProgress(),
       ) {
    music.addListener(_handleMusicStateChange);
    _lastControllerIsPlaying = music.isPlaying;
    unawaited(_initialize());
    unawaited(_loadChassisColor());
  }

  final QqMusicController music;
  final ClickSoundService _clickSound;
  final PageController pageController;
  final ChassisColorStore _chassisColorStore;
  final AppSettingsStore _settingsStore;
  final CustomBackgroundPicker _customBackgroundPicker;
  final ValueNotifier<QqMusicPlaybackProgress> inactivePlaybackProgress;
  final Map<AppSetting, String> _settingFeedback = {};

  PlayerMode mode = PlayerMode.menu;
  PlayerMode previousMode = PlayerMode.menu;
  final List<MenuSection> menuPath = [MenuSection.root];
  final Map<MenuSection, int> menuIndices = {MenuSection.root: 0};
  MenuEntry? activeFeature;
  int coverIndex = 0;
  double progress = .3;
  double accumulatedDelta = 0;
  double playerRotationDelta = 0;
  double? seekPreviewProgress;
  int seekPreviewRevision = 0;
  int lyricsOpenRevision = 0;
  bool isPlayingLocally = false;
  bool _lastControllerIsPlaying = false;
  bool hasLocalSelection = false;
  Album playingAlbum = coverFlowLibrary.first;
  bool _disposed = false;
  Color chassisColor = ChassisColorStore.defaultColor;
  bool clickSoundEnabled = true;
  bool hapticsEnabled = true;
  PlaybackQuality playbackQuality = PlaybackQuality.standard;
  AppVolumeLimit volumeLimit = AppVolumeLimit.off;
  bool gaplessPlaybackEnabled = false;
  AppSleepTimer sleepTimer = AppSleepTimer.off;
  String? customBackgroundPath;

  MenuPage get currentMenuPage => qqMusicMenuPages[menuPath.last]!;

  int get menuIndex => menuIndices[currentMenuPage.section] ?? 0;

  MenuEntry get selectedMenuEntry => currentMenuPage.entries[menuIndex];

  String? valueForMenuEntry(MenuEntry entry) {
    if (entry.action == MenuAction.chassisColor &&
        entry.chassisColorValue != null &&
        chassisColor == Color(entry.chassisColorValue!)) {
      return '当前';
    }
    return switch (entry.setting) {
      AppSetting.clickSound => clickSoundEnabled ? '开启' : '关闭',
      AppSetting.playbackQuality => playbackQuality.label,
      AppSetting.gaplessPlayback => gaplessPlaybackEnabled ? '开启' : '关闭',
      AppSetting.sleepTimer =>
        music.sleepTimerDeadline == null
            ? AppSleepTimer.off.label
            : sleepTimer.label,
      AppSetting.volumeLimit => volumeLimit.label,
      AppSetting.customBackground => hasCustomBackground ? '已设置' : '选择图片',
      AppSetting.clearCustomBackground => hasCustomBackground ? '按下恢复' : '动态背景',
      AppSetting.haptics => hapticsEnabled ? '开启' : '关闭',
      AppSetting.clearCache => '按下清理',
      AppSetting.about => 'v1.0.0',
      null => null,
    };
  }

  String descriptionForMenuEntry(MenuEntry entry) {
    final setting = entry.setting;
    return setting == null
        ? entry.description
        : _settingFeedback[setting] ?? entry.description;
  }

  List<Album> get coverAlbums => music.coverFlowAlbums;

  int get selectedQueueIndex {
    final queue = music.playbackQueue;
    if (queue.isEmpty) {
      return 0;
    }
    return queueIndex.clamp(0, queue.length - 1).toInt();
  }

  int queueIndex = 0;

  int get pageIndex => switch (mode) {
    PlayerMode.menu => 0,
    PlayerMode.coverFlow => 1,
    PlayerMode.player => 2,
    PlayerMode.feature => 3,
    PlayerMode.queue => 4,
  };

  Album get displayAlbum {
    final song = music.currentSong;
    if (song == null) {
      return hasLocalSelection
          ? playingAlbum
          : const Album(title: '', artist: '', imageUrl: '');
    }
    return Album(
      title: song.title,
      artist: song.subtitle,
      imageUrl: song.imageUrl,
    );
  }

  String get ambientImageUrl => switch (mode) {
    // Follow the highlighted menu entry so the blur updates while browsing.
    PlayerMode.menu =>
      selectedMenuEntry.imageUrl.isNotEmpty
          ? selectedMenuEntry.imageUrl
          : (music.currentSong?.imageUrl.isNotEmpty == true
                ? music.currentSong!.imageUrl
                : (coverAlbums.isNotEmpty
                      ? coverAlbums[coverIndex.clamp(0, coverAlbums.length - 1)]
                            .imageUrl
                      : '')),
    PlayerMode.coverFlow =>
      coverAlbums.isEmpty
          ? ''
          : coverAlbums[coverIndex.clamp(0, coverAlbums.length - 1)].imageUrl,
    PlayerMode.player => displayAlbum.imageUrl,
    PlayerMode.feature => activeFeature?.imageUrl ?? selectedMenuEntry.imageUrl,
    PlayerMode.queue => displayAlbum.imageUrl,
  };

  bool get hasCustomBackground => customBackgroundPath?.isNotEmpty == true;

  bool get wheelIsPlaying =>
      music.currentSong == null ? isPlayingLocally : music.isPlaying;

  ValueNotifier<QqMusicPlaybackProgress> get playbackProgressListenable =>
      mode == PlayerMode.player || mode == PlayerMode.queue
      ? music.playbackProgress
      : inactivePlaybackProgress;

  void _handleMusicStateChange() {
    if (_disposed) {
      return;
    }
    final controllerIsPlaying = music.isPlaying;
    if (sleepTimer != AppSleepTimer.off && music.sleepTimerDeadline == null) {
      sleepTimer = AppSleepTimer.off;
    }
    final playbackChanged = controllerIsPlaying != _lastControllerIsPlaying;
    _lastControllerIsPlaying = controllerIsPlaying;
    if (mode == PlayerMode.feature && !playbackChanged) {
      return;
    }
    final albums = coverAlbums;
    if (coverIndex >= albums.length) {
      coverIndex = albums.isEmpty ? 0 : albums.length - 1;
    }
    final queue = music.playbackQueue;
    if (queue.isEmpty) {
      queueIndex = 0;
    } else {
      queueIndex = queueIndex.clamp(0, queue.length - 1).toInt();
    }
    notifyListeners();
  }

  Future<void> switchMode(PlayerMode nextMode) async {
    if (mode == nextMode) {
      return;
    }
    final targetPage = switch (nextMode) {
      PlayerMode.menu => 0,
      PlayerMode.coverFlow => 1,
      PlayerMode.player => 2,
      PlayerMode.feature => 3,
      PlayerMode.queue => 4,
    };
    final currentPage = pageController.hasClients
        ? (pageController.page ?? pageIndex.toDouble()).round()
        : pageIndex;
    if (nextMode != PlayerMode.player) {
      inactivePlaybackProgress.value = music.playbackProgress.value;
    }
    mode = nextMode;
    notifyListeners();
    if ((targetPage - currentPage).abs() > 1) {
      pageController.jumpToPage(targetPage);
      return;
    }
    await pageController.animateToPage(
      targetPage,
      duration: const Duration(milliseconds: 550),
      curve: const Cubic(.25, 1, .25, 1),
    );
  }

  void _tick() {
    if (clickSoundEnabled) {
      unawaited(_clickSound.playTick());
    }
  }

  void _mediumImpact() {
    if (hapticsEnabled) {
      unawaited(HapticFeedback.mediumImpact());
    }
  }

  void _lightImpact() {
    if (hapticsEnabled) {
      unawaited(HapticFeedback.lightImpact());
    }
  }

  void _selectionClick() {
    if (hapticsEnabled) {
      unawaited(HapticFeedback.selectionClick());
    }
  }

  void handleCenter() {
    _mediumImpact();
    _tick();
    if (mode == PlayerMode.menu) {
      final entry = selectedMenuEntry;
      switch (entry.action) {
        case MenuAction.submenu:
          final section = entry.section;
          if (section == null) {
            return;
          }
          menuPath.add(section);
          menuIndices.putIfAbsent(section, () => 0);
          notifyListeners();
        case MenuAction.feature:
          if (entry.feature == null) {
            return;
          }
          activeFeature = entry;
          previousMode = PlayerMode.menu;
          notifyListeners();
          unawaited(music.openFeature(entry));
          unawaited(switchMode(PlayerMode.feature));
        case MenuAction.coverFlow:
          previousMode = PlayerMode.menu;
          final albums = coverAlbums;
          if (coverIndex >= albums.length) {
            coverIndex = 0;
          }
          unawaited(switchMode(PlayerMode.coverFlow));
        case MenuAction.player:
          previousMode = PlayerMode.menu;
          unawaited(switchMode(PlayerMode.player));
        case MenuAction.info:
          // Preview-only settings entries stay on the menu.
          break;
        case MenuAction.chassisColor:
          final value = entry.chassisColorValue;
          if (value == null) {
            return;
          }
          unawaited(setChassisColor(Color(value)));
        case MenuAction.setting:
          final setting = entry.setting;
          if (setting == null) {
            return;
          }
          unawaited(_activateSetting(setting));
      }
      return;
    }
    if (mode == PlayerMode.coverFlow) {
      unawaited(_activateCoverFlowSelection());
      return;
    }
    if (mode == PlayerMode.feature) {
      unawaited(_activateFeatureSelection());
      return;
    }
    if (mode == PlayerMode.queue) {
      unawaited(_activateQueueSelection());
      return;
    }
    if (mode == PlayerMode.player) {
      openQueue();
    }
  }

  Future<void> _activateCoverFlowSelection() async {
    final albums = coverAlbums;
    if (albums.isEmpty) {
      return;
    }
    final index = coverIndex.clamp(0, albums.length - 1);
    final album = albums[index];
    previousMode = PlayerMode.coverFlow;
    playingAlbum = album;
    hasLocalSelection = true;
    await switchMode(PlayerMode.player);
    final played = await music.playCoverFlowIndex(index);
    if (_disposed) {
      return;
    }
    if (played) {
      hasLocalSelection = false;
      notifyListeners();
    } else {
      music.clearRemotePlayback();
      playingAlbum = album;
      hasLocalSelection = true;
      notifyListeners();
    }
  }

  Future<void> _activateFeatureSelection() async {
    final selected = music.selectedItem;
    final activated = await music.activateSelected();
    if (_disposed || !activated || selected?.isSong != true) {
      return;
    }
    previousMode = PlayerMode.feature;
    hasLocalSelection = false;
    await switchMode(PlayerMode.player);
  }

  void openPlayerLyrics() {
    previousMode = mode;
    lyricsOpenRevision += 1;
    unawaited(switchMode(PlayerMode.player));
  }

  void openQueue() {
    if (mode == PlayerMode.queue) {
      return;
    }
    final queue = music.playbackQueue;
    final currentIndex = music.currentPlaybackQueueIndex;
    queueIndex = currentIndex >= 0
        ? currentIndex
        : (queue.isEmpty ? 0 : queueIndex.clamp(0, queue.length - 1).toInt());
    unawaited(switchMode(PlayerMode.queue));
  }

  Future<void> _activateQueueSelection() async {
    await playQueueIndex(selectedQueueIndex);
  }

  Future<void> playQueueIndex(int index) async {
    final queue = music.playbackQueue;
    if (index < 0 || index >= queue.length) {
      return;
    }
    queueIndex = index;
    notifyListeners();
    final played = await music.playQueueIndex(index);
    if (_disposed || !played) {
      return;
    }
    hasLocalSelection = false;
    if (mode == PlayerMode.queue) {
      await switchMode(PlayerMode.player);
    }
  }

  void removeQueueIndex(int index) {
    if (!music.removeQueueIndex(index)) {
      return;
    }
    final queue = music.playbackQueue;
    queueIndex = queue.isEmpty
        ? 0
        : queueIndex.clamp(0, queue.length - 1).toInt();
    notifyListeners();
  }

  void clearUpcomingQueue() {
    if (!music.clearUpcomingQueue()) {
      return;
    }
    final currentIndex = music.currentPlaybackQueueIndex;
    queueIndex = currentIndex < 0 ? 0 : currentIndex;
    notifyListeners();
  }

  void handleMenu() {
    _lightImpact();
    _tick();
    if (mode == PlayerMode.feature && music.back()) {
      return;
    }
    if (mode == PlayerMode.queue) {
      unawaited(switchMode(PlayerMode.player));
      return;
    }
    if (mode == PlayerMode.menu && menuPath.length > 1) {
      menuPath.removeLast();
      notifyListeners();
    } else if (mode == PlayerMode.player &&
        previousMode == PlayerMode.feature) {
      unawaited(switchMode(PlayerMode.feature));
    } else if (mode == PlayerMode.player &&
        previousMode == PlayerMode.coverFlow) {
      unawaited(switchMode(PlayerMode.coverFlow));
    } else if (mode != PlayerMode.menu) {
      if (mode == PlayerMode.feature) {
        music.leaveFeature();
      }
      unawaited(switchMode(PlayerMode.menu));
    }
  }

  void handleRotate(double delta) {
    if (mode == PlayerMode.player) {
      seekPreviewRevision += 1;
      playerRotationDelta = (playerRotationDelta + delta * .35).clamp(
        -28.0,
        28.0,
      );
      final currentProgress =
          seekPreviewProgress ??
          (music.currentSong == null ? progress : music.progress);
      seekPreviewProgress = (currentProgress + delta * .0015).clamp(0.0, 1.0);
      if (music.currentSong == null) {
        progress = seekPreviewProgress!;
      }
      notifyListeners();
      return;
    }

    accumulatedDelta += delta;
    // Smaller threshold = more steps per revolution (classic wheel density).
    final threshold = mode == PlayerMode.menu ? 14.0 : 18.0;
    if (accumulatedDelta.abs() < threshold) {
      return;
    }

    // Consume every full step in this move so a fast flick can skip several
    // items — each step gets its own click instead of one tick for the whole swipe.
    var moved = false;
    while (accumulatedDelta.abs() >= threshold) {
      final direction = accumulatedDelta.sign.toInt();
      accumulatedDelta -= direction * threshold;
      if (!_stepFromWheel(direction)) {
        // Hit list end — drop leftover so we don't keep firing at the edge.
        accumulatedDelta = 0;
        break;
      }
      moved = true;
    }
    if (moved) {
      notifyListeners();
    }
  }

  /// Advances selection by one wheel step. Returns false when already at a bound.
  bool _stepFromWheel(int direction) {
    if (mode == PlayerMode.menu) {
      final entries = currentMenuPage.entries;
      if (entries.isEmpty) {
        return false;
      }
      final next = (menuIndex + direction).clamp(0, entries.length - 1);
      if (next == menuIndex) {
        return false;
      }
      _selectionClick();
      _tick();
      menuIndices[currentMenuPage.section] = next;
      return true;
    }
    if (mode == PlayerMode.coverFlow) {
      final albums = coverAlbums;
      if (albums.isEmpty) {
        return false;
      }
      final next = (coverIndex + direction).clamp(0, albums.length - 1);
      if (next == coverIndex) {
        return false;
      }
      _selectionClick();
      _tick();
      coverIndex = next;
      return true;
    }
    if (mode == PlayerMode.feature) {
      final previous = music.selectedIndex;
      music.stepSelection(direction);
      if (music.selectedIndex == previous) {
        return false;
      }
      _selectionClick();
      _tick();
      return true;
    }
    if (mode == PlayerMode.queue) {
      final queue = music.playbackQueue;
      if (queue.isEmpty) {
        return false;
      }
      final next = (selectedQueueIndex + direction)
          .clamp(0, queue.length - 1)
          .toInt();
      if (next == selectedQueueIndex) {
        return false;
      }
      queueIndex = next;
      _selectionClick();
      _tick();
      return true;
    }
    return false;
  }

  Future<void> handleRotationEnd() async {
    accumulatedDelta = 0;
    final revision = seekPreviewRevision;
    final seekTarget = seekPreviewProgress;
    if (seekTarget != null && music.currentSong != null) {
      await music.seekToProgress(seekTarget, avoidPlaybackCompletion: true);
    }
    if (_disposed || revision != seekPreviewRevision) {
      return;
    }
    if (playerRotationDelta != 0 || seekPreviewProgress != null) {
      playerRotationDelta = 0;
      seekPreviewProgress = null;
      notifyListeners();
    }
  }

  void stepSelection(int direction) {
    _selectionClick();
    _tick();
    if (mode == PlayerMode.menu) {
      final entries = currentMenuPage.entries;
      menuIndices[currentMenuPage.section] = (menuIndex + direction).clamp(
        0,
        entries.length - 1,
      );
      notifyListeners();
      return;
    }
    if (mode == PlayerMode.feature) {
      music.stepSelection(direction);
      return;
    }
    if (mode == PlayerMode.queue) {
      final queue = music.playbackQueue;
      if (queue.isNotEmpty) {
        queueIndex = (selectedQueueIndex + direction)
            .clamp(0, queue.length - 1)
            .toInt();
        notifyListeners();
      }
      return;
    }
    if (mode == PlayerMode.player && music.currentSong != null) {
      unawaited(music.playAdjacent(direction));
      return;
    }

    final albums = coverAlbums;
    if (albums.isEmpty) {
      return;
    }
    final next =
        (mode == PlayerMode.coverFlow
            ? coverIndex
            : albums.indexWhere(
                (album) => album.imageUrl == playingAlbum.imageUrl,
              )) +
        direction;
    final bounded = next.clamp(0, albums.length - 1);
    coverIndex = bounded;
    if (mode == PlayerMode.player) {
      playingAlbum = albums[bounded];
    }
    notifyListeners();
  }

  void togglePlayback() {
    _lightImpact();
    _tick();
    if (music.currentSong != null || mode == PlayerMode.feature) {
      unawaited(music.togglePlayback());
      return;
    }
    isPlayingLocally = !isPlayingLocally;
    notifyListeners();
  }

  Future<void> _initialize() async {
    await _loadSettings();
    if (!_disposed) {
      await music.initialize();
    }
  }

  Future<void> _loadSettings() async {
    try {
      final settings = await _settingsStore.load();
      if (_disposed) {
        return;
      }
      clickSoundEnabled = settings.clickSoundEnabled;
      hapticsEnabled = settings.hapticsEnabled;
      playbackQuality = settings.playbackQuality;
      volumeLimit = settings.volumeLimit;
      gaplessPlaybackEnabled = settings.gaplessPlaybackEnabled;
      final savedCustomBackgroundPath = settings.customBackgroundPath;
      customBackgroundPath =
          savedCustomBackgroundPath != null &&
              await _customBackgroundPicker.exists(savedCustomBackgroundPath)
          ? savedCustomBackgroundPath
          : null;
      if (_disposed) {
        return;
      }
      music.setPlaybackFileType(playbackQuality.fileType);
      music.setGaplessPlaybackEnabled(gaplessPlaybackEnabled);
      try {
        await music.setVolumeLimit(volumeLimit.gain);
      } catch (_) {}
      if (!_disposed) {
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> _saveSettings() async {
    try {
      await _settingsStore.save(
        AppSettingsSnapshot(
          clickSoundEnabled: clickSoundEnabled,
          hapticsEnabled: hapticsEnabled,
          playbackQuality: playbackQuality,
          volumeLimit: volumeLimit,
          gaplessPlaybackEnabled: gaplessPlaybackEnabled,
          customBackgroundPath: customBackgroundPath,
        ),
      );
    } catch (_) {}
  }

  Future<void> _chooseCustomBackground() async {
    if (!_customBackgroundPicker.isSupported) {
      _settingFeedback[AppSetting.customBackground] = '当前平台暂不支持从图库选择自定义背景。';
      notifyListeners();
      return;
    }
    try {
      final selectedPath = await _customBackgroundPicker.pickImage();
      if (_disposed) {
        if (selectedPath != null) {
          try {
            await _customBackgroundPicker.deleteImage(selectedPath);
          } catch (_) {}
        }
        return;
      }
      if (selectedPath == null) {
        _settingFeedback[AppSetting.customBackground] = '未选择新的背景图片，当前背景保持不变。';
        notifyListeners();
        return;
      }
      final previousPath = customBackgroundPath;
      customBackgroundPath = selectedPath;
      _settingFeedback[AppSetting.customBackground] = '已应用自定义背景，图片会保存在应用内。';
      _settingFeedback.remove(AppSetting.clearCustomBackground);
      notifyListeners();
      await _saveSettings();
      if (previousPath != null && previousPath != selectedPath) {
        try {
          await _customBackgroundPicker.deleteImage(previousPath);
        } catch (_) {}
      }
    } catch (_) {
      if (_disposed) {
        return;
      }
      _settingFeedback[AppSetting.customBackground] = '无法选择背景图片，请稍后重试。';
      notifyListeners();
    }
  }

  Future<void> _clearCustomBackground() async {
    final previousPath = customBackgroundPath;
    if (previousPath == null) {
      _settingFeedback[AppSetting.clearCustomBackground] =
          '当前已使用随页面和歌曲变化的动态背景。';
      notifyListeners();
      return;
    }
    customBackgroundPath = null;
    _settingFeedback[AppSetting.clearCustomBackground] = '已恢复随页面和歌曲变化的动态背景。';
    _settingFeedback.remove(AppSetting.customBackground);
    notifyListeners();
    await _saveSettings();
    try {
      await _customBackgroundPicker.deleteImage(previousPath);
    } catch (_) {}
  }

  Future<void> _activateSetting(AppSetting setting) async {
    switch (setting) {
      case AppSetting.clickSound:
        clickSoundEnabled = !clickSoundEnabled;
        _settingFeedback[setting] = clickSoundEnabled
            ? '点击音效已开启，滚轮与按键会播放机械反馈声。'
            : '点击音效已关闭，滚轮与按键将保持安静。';
        notifyListeners();
        if (clickSoundEnabled) {
          await _clickSound.playTick();
        }
        await _saveSettings();
      case AppSetting.playbackQuality:
        playbackQuality = playbackQuality.next;
        music.setPlaybackFileType(playbackQuality.fileType);
        _settingFeedback[setting] =
            '已选择${playbackQuality.label}音质，将从下一首开始；不支持时回退标准。';
        notifyListeners();
        await _saveSettings();
      case AppSetting.gaplessPlayback:
        gaplessPlaybackEnabled = !gaplessPlaybackEnabled;
        music.setGaplessPlaybackEnabled(gaplessPlaybackEnabled);
        _settingFeedback[setting] = gaplessPlaybackEnabled
            ? '无缝切换已开启，当前歌曲结束前将与下一首交叉淡入淡出。'
            : '无缝切换已关闭，将恢复逐首加载。';
        notifyListeners();
        await _saveSettings();
      case AppSetting.sleepTimer:
        sleepTimer = sleepTimer.next;
        music.setSleepTimer(sleepTimer.duration);
        _settingFeedback[setting] = sleepTimer == AppSleepTimer.off
            ? '定时关闭已取消。'
            : '将在 ${sleepTimer.label}后自动暂停播放。';
        notifyListeners();
      case AppSetting.volumeLimit:
        volumeLimit = volumeLimit.next;
        _settingFeedback[setting] = volumeLimit == AppVolumeLimit.off
            ? '播放器音量限制已关闭。'
            : '播放器最大增益已限制为 ${volumeLimit.label}。';
        notifyListeners();
        try {
          await music.setVolumeLimit(volumeLimit.gain);
          await _saveSettings();
        } catch (_) {
          _settingFeedback[setting] = '应用音量限制失败，请稍后重试。';
          notifyListeners();
        }
      case AppSetting.customBackground:
        await _chooseCustomBackground();
      case AppSetting.clearCustomBackground:
        await _clearCustomBackground();
      case AppSetting.haptics:
        hapticsEnabled = !hapticsEnabled;
        _settingFeedback[setting] = hapticsEnabled ? '触感反馈已开启。' : '触感反馈已关闭。';
        notifyListeners();
        if (hapticsEnabled) {
          await HapticFeedback.mediumImpact();
        }
        await _saveSettings();
      case AppSetting.clearCache:
        final imageCache = PaintingBinding.instance.imageCache;
        final imageCount = imageCache.currentSize + imageCache.liveImageCount;
        final dataCount = music.clearMemoryCaches();
        imageCache
          ..clear()
          ..clearLiveImages();
        final count = dataCount + imageCount;
        _settingFeedback[setting] = count == 0
            ? '缓存已经是空的。'
            : '已清理 $count 项列表、歌词、播放地址和封面缓存。';
        notifyListeners();
      case AppSetting.about:
        final uri = Uri.parse('https://github.com/Cueovo/IcePods');
        try {
          final opened = await launchUrl(
            uri,
            mode: LaunchMode.externalApplication,
          );
          _settingFeedback[setting] = opened
              ? '已打开 IcePods 项目主页。'
              : '无法打开项目主页。';
        } catch (_) {
          _settingFeedback[setting] = '无法打开项目主页。';
        }
        notifyListeners();
    }
  }

  Future<void> _loadChassisColor() async {
    try {
      final color = await _chassisColorStore.load();
      if (_disposed) {
        return;
      }
      chassisColor = color;
      notifyListeners();
    } catch (_) {
      // Keep the default chassis color when persistence is unavailable.
    }
  }

  Future<void> setChassisColor(Color color) async {
    if (chassisColor == color) {
      return;
    }
    chassisColor = color;
    notifyListeners();
    try {
      await _chassisColorStore.save(color);
    } catch (_) {
      // Keep the in-memory selection even if persistence fails.
    }
  }

  @override
  void dispose() {
    _disposed = true;
    music
      ..removeListener(_handleMusicStateChange)
      ..dispose();
    unawaited(_clickSound.dispose());
    inactivePlaybackProgress.dispose();
    pageController.dispose();
    super.dispose();
  }
}
