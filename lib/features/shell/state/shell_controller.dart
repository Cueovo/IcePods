import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:qqmusic_ipod/business/repositories/music_repository.dart';
import 'package:qqmusic_ipod/core/audio/audio_handler.dart';
import 'package:qqmusic_ipod/core/audio/click_sound_service.dart';
import 'package:qqmusic_ipod/core/storage/chassis_color_store.dart';
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
  }) : music = QqMusicController(api: api, audioHandler: audioHandler),
       _clickSound = clickSound ?? ClickSoundService(),
       pageController = pageController ?? PageController(),
       _chassisColorStore = chassisColorStore ?? ChassisColorStore(),
       inactivePlaybackProgress = ValueNotifier(const QqMusicPlaybackProgress()) {
    music.addListener(_handleMusicStateChange);
    _lastControllerIsPlaying = music.isPlaying;
    unawaited(music.initialize());
    unawaited(_loadChassisColor());
  }

  final QqMusicController music;
  final ClickSoundService _clickSound;
  final PageController pageController;
  final ChassisColorStore _chassisColorStore;
  final ValueNotifier<QqMusicPlaybackProgress> inactivePlaybackProgress;

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
  bool isPlayingLocally = false;
  bool _lastControllerIsPlaying = false;
  bool hasLocalSelection = false;
  Album playingAlbum = coverFlowLibrary.first;
  bool _disposed = false;
  Color chassisColor = ChassisColorStore.defaultColor;

  MenuPage get currentMenuPage => qqMusicMenuPages[menuPath.last]!;

  int get menuIndex => menuIndices[currentMenuPage.section] ?? 0;

  MenuEntry get selectedMenuEntry => currentMenuPage.entries[menuIndex];

  List<Album> get coverAlbums => music.coverFlowAlbums;

  int get pageIndex => switch (mode) {
    PlayerMode.menu => 0,
    PlayerMode.coverFlow => 1,
    PlayerMode.player => 2,
    PlayerMode.feature => 3,
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
    PlayerMode.menu => selectedMenuEntry.imageUrl.isNotEmpty
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
  };

  bool get wheelIsPlaying =>
      music.currentSong == null ? isPlayingLocally : music.isPlaying;

  ValueNotifier<QqMusicPlaybackProgress> get playbackProgressListenable =>
      mode == PlayerMode.player
      ? music.playbackProgress
      : inactivePlaybackProgress;

  void _handleMusicStateChange() {
    if (_disposed) {
      return;
    }
    final controllerIsPlaying = music.isPlaying;
    final playbackChanged = controllerIsPlaying != _lastControllerIsPlaying;
    _lastControllerIsPlaying = controllerIsPlaying;
    if (mode == PlayerMode.feature && !playbackChanged) {
      return;
    }
    final albums = coverAlbums;
    if (coverIndex >= albums.length) {
      coverIndex = albums.isEmpty ? 0 : albums.length - 1;
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
    unawaited(_clickSound.playTick());
  }

  void handleCenter() {
    HapticFeedback.mediumImpact();
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
      }
      return;
    }
    if (mode == PlayerMode.coverFlow) {
      unawaited(_activateCoverFlowSelection());
      return;
    }
    if (mode == PlayerMode.feature) {
      unawaited(_activateFeatureSelection());
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

  void handleMenu() {
    HapticFeedback.lightImpact();
    _tick();
    if (mode == PlayerMode.feature && music.back()) {
      return;
    }
    if (mode == PlayerMode.menu && menuPath.length > 1) {
      menuPath.removeLast();
      notifyListeners();
    } else if (mode == PlayerMode.player && previousMode == PlayerMode.feature) {
      unawaited(switchMode(PlayerMode.feature));
    } else if (mode == PlayerMode.player && previousMode == PlayerMode.coverFlow) {
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
      playerRotationDelta = (playerRotationDelta + delta * .35).clamp(-28.0, 28.0);
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
      HapticFeedback.selectionClick();
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
      HapticFeedback.selectionClick();
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
      HapticFeedback.selectionClick();
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
    HapticFeedback.selectionClick();
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
    HapticFeedback.lightImpact();
    _tick();
    if (music.currentSong != null || mode == PlayerMode.feature) {
      unawaited(music.togglePlayback());
      return;
    }
    isPlayingLocally = !isPlayingLocally;
    notifyListeners();
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
