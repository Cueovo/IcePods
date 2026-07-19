import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'features/qq_music/core/api.dart';
import 'features/qq_music/modules/official_api.dart';
import 'features/qq_music/player/audio_handler.dart';
import 'features/qq_music/player/controller.dart';
import 'ipod_models.dart';
import 'menu_catalog.dart';
import 'services/click_sound_service.dart';
import 'widgets/ambient_background.dart'
    if (dart.library.js_interop) 'widgets/ambient_background_web.dart';
import 'widgets/click_wheel.dart';
import 'widgets/cover_flow_panel.dart';
import 'widgets/feature_panel.dart';
import 'widgets/home_panel.dart';
import 'widgets/now_playing_panel.dart';

class IpodScreen extends StatelessWidget {
  const IpodScreen({this.api, this.audioHandler, super.key});

  final QqMusicApi? api;
  final QqMusicAudioHandler? audioHandler;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF090A0F),
      extendBody: true,
      body: SizedBox.expand(
        child: _IpodDevice(api: api, audioHandler: audioHandler),
      ),
    );
  }
}

class _IpodDevice extends StatefulWidget {
  const _IpodDevice({this.api, this.audioHandler});

  final QqMusicApi? api;
  final QqMusicAudioHandler? audioHandler;

  @override
  State<_IpodDevice> createState() => _IpodDeviceState();
}

class _IpodDeviceState extends State<_IpodDevice> {
  final PageController _pageController = PageController();
  final ClickSoundService _clickSound = ClickSoundService();
  final ValueNotifier<QqMusicPlaybackProgress> _inactivePlaybackProgress =
      ValueNotifier(const QqMusicPlaybackProgress());
  late final QqMusicController _qqMusicController;

  PlayerMode _mode = PlayerMode.menu;
  PlayerMode _previousMode = PlayerMode.menu;
  final List<MenuSection> _menuPath = [MenuSection.root];
  final Map<MenuSection, int> _menuIndices = {MenuSection.root: 0};
  MenuEntry? _activeFeature;
  int _coverIndex = 0;
  double _progress = .3;
  double _accumulatedDelta = 0;
  double _playerRotationDelta = 0;
  double? _seekPreviewProgress;
  int _seekPreviewRevision = 0;
  bool _isPlaying = false;
  bool _lastControllerIsPlaying = false;
  bool _hasLocalSelection = false;
  Album _playingAlbum = coverFlowLibrary.first;

  @override
  void initState() {
    super.initState();
    _qqMusicController = QqMusicController(
      api: widget.api ?? QqMusicOfficialApi(),
      audioHandler: widget.audioHandler,
    )..addListener(_handleApiStateChange);
    _lastControllerIsPlaying = _qqMusicController.isPlaying;
    unawaited(_qqMusicController.initialize());
  }

  void _handleApiStateChange() {
    if (!mounted) {
      return;
    }
    final controllerIsPlaying = _qqMusicController.isPlaying;
    final playbackChanged = controllerIsPlaying != _lastControllerIsPlaying;
    _lastControllerIsPlaying = controllerIsPlaying;
    if (_mode == PlayerMode.feature && !playbackChanged) {
      return;
    }
    final albums = _qqMusicController.coverFlowAlbums;
    if (_coverIndex >= albums.length) {
      _coverIndex = albums.isEmpty ? 0 : albums.length - 1;
    }
    setState(() {});
  }

  @override
  void dispose() {
    _qqMusicController
      ..removeListener(_handleApiStateChange)
      ..dispose();
    unawaited(_clickSound.dispose());
    _inactivePlaybackProgress.dispose();
    _pageController.dispose();
    super.dispose();
  }

  MenuPage get _currentMenuPage => qqMusicMenuPages[_menuPath.last]!;

  int get _menuIndex => _menuIndices[_currentMenuPage.section] ?? 0;

  MenuEntry get _selectedMenuEntry => _currentMenuPage.entries[_menuIndex];

  List<Album> get _coverAlbums => _qqMusicController.coverFlowAlbums;

  int get _pageIndex => switch (_mode) {
    PlayerMode.menu => 0,
    PlayerMode.coverFlow => 1,
    PlayerMode.player => 2,
    PlayerMode.feature => 3,
  };

  Album get _displayAlbum {
    final song = _qqMusicController.currentSong;
    if (song == null) {
      return _hasLocalSelection
          ? _playingAlbum
          : const Album(title: '', artist: '', imageUrl: '');
    }
    return Album(
      title: song.title,
      artist: song.subtitle,
      imageUrl: song.imageUrl,
    );
  }

  String get _ambientImageUrl => switch (_mode) {
    PlayerMode.menu =>
      _qqMusicController.currentSong?.imageUrl.isNotEmpty == true
          ? _qqMusicController.currentSong!.imageUrl
          : (_coverAlbums.isNotEmpty
                ? _coverAlbums[_coverIndex.clamp(0, _coverAlbums.length - 1)]
                      .imageUrl
                : _selectedMenuEntry.imageUrl),
    PlayerMode.coverFlow =>
      _coverAlbums.isEmpty
          ? ''
          : _coverAlbums[_coverIndex.clamp(0, _coverAlbums.length - 1)]
                .imageUrl,
    PlayerMode.player => _displayAlbum.imageUrl,
    PlayerMode.feature =>
      _activeFeature?.imageUrl ?? _selectedMenuEntry.imageUrl,
  };

  Future<void> _switchMode(PlayerMode mode) async {
    if (_mode == mode) {
      return;
    }
    final targetPage = switch (mode) {
      PlayerMode.menu => 0,
      PlayerMode.coverFlow => 1,
      PlayerMode.player => 2,
      PlayerMode.feature => 3,
    };
    final currentPage = _pageController.hasClients
        ? (_pageController.page ?? _pageIndex.toDouble()).round()
        : _pageIndex;
    if (mode != PlayerMode.player) {
      _inactivePlaybackProgress.value =
          _qqMusicController.playbackProgress.value;
    }
    setState(() => _mode = mode);
    if ((targetPage - currentPage).abs() > 1) {
      _pageController.jumpToPage(targetPage);
      return;
    }
    await _pageController.animateToPage(
      targetPage,
      duration: const Duration(milliseconds: 550),
      curve: const Cubic(.25, 1, .25, 1),
    );
  }

  void _tick() {
    unawaited(_clickSound.playTick());
  }

  void _handleCenter() {
    HapticFeedback.mediumImpact();
    _tick();
    if (_mode == PlayerMode.menu) {
      final entry = _selectedMenuEntry;
      switch (entry.action) {
        case MenuAction.submenu:
          final section = entry.section;
          if (section == null) {
            return;
          }
          setState(() {
            _menuPath.add(section);
            _menuIndices.putIfAbsent(section, () => 0);
          });
        case MenuAction.feature:
          if (entry.feature == null) {
            return;
          }
          setState(() => _activeFeature = entry);
          _previousMode = PlayerMode.menu;
          unawaited(_qqMusicController.openFeature(entry));
          unawaited(_switchMode(PlayerMode.feature));
        case MenuAction.coverFlow:
          _previousMode = PlayerMode.menu;
          final albums = _coverAlbums;
          if (_coverIndex >= albums.length) {
            _coverIndex = 0;
          }
          _switchMode(PlayerMode.coverFlow);
        case MenuAction.player:
          _previousMode = PlayerMode.menu;
          _switchMode(PlayerMode.player);
      }
      return;
    }
    if (_mode == PlayerMode.coverFlow) {
      unawaited(_activateCoverFlowSelection());
      return;
    }
    if (_mode == PlayerMode.feature) {
      unawaited(_activateFeatureSelection());
    }
  }

  Future<void> _activateCoverFlowSelection() async {
    final albums = _coverAlbums;
    if (albums.isEmpty) {
      return;
    }
    final index = _coverIndex.clamp(0, albums.length - 1);
    final album = albums[index];
    _previousMode = PlayerMode.coverFlow;
    _playingAlbum = album;
    _hasLocalSelection = true;
    await _switchMode(PlayerMode.player);
    final played = await _qqMusicController.playCoverFlowIndex(index);
    if (!mounted) {
      return;
    }
    if (played) {
      setState(() => _hasLocalSelection = false);
    } else {
      _qqMusicController.clearRemotePlayback();
      setState(() {
        _playingAlbum = album;
        _hasLocalSelection = true;
      });
    }
  }

  Future<void> _activateFeatureSelection() async {
    final selected = _qqMusicController.selectedItem;
    final activated = await _qqMusicController.activateSelected();
    if (!mounted || !activated || selected?.isSong != true) {
      return;
    }
    _previousMode = PlayerMode.feature;
    _hasLocalSelection = false;
    await _switchMode(PlayerMode.player);
  }

  void _handleMenu() {
    HapticFeedback.lightImpact();
    _tick();
    if (_mode == PlayerMode.feature && _qqMusicController.back()) {
      return;
    }
    if (_mode == PlayerMode.menu && _menuPath.length > 1) {
      setState(() => _menuPath.removeLast());
    } else if (_mode == PlayerMode.player &&
        _previousMode == PlayerMode.feature) {
      _switchMode(PlayerMode.feature);
    } else if (_mode == PlayerMode.player &&
        _previousMode == PlayerMode.coverFlow) {
      _switchMode(PlayerMode.coverFlow);
    } else if (_mode != PlayerMode.menu) {
      if (_mode == PlayerMode.feature) {
        _qqMusicController.leaveFeature();
      }
      _switchMode(PlayerMode.menu);
    }
  }

  void _handleRotate(double delta) {
    if (_mode == PlayerMode.player) {
      _seekPreviewRevision += 1;
      setState(() {
        _playerRotationDelta = (_playerRotationDelta + delta * .35).clamp(
          -28.0,
          28.0,
        );
        final currentProgress =
            _seekPreviewProgress ??
            (_qqMusicController.currentSong == null
                ? _progress
                : _qqMusicController.progress);
        _seekPreviewProgress = (currentProgress + delta * .0015).clamp(
          0.0,
          1.0,
        );
        if (_qqMusicController.currentSong == null) {
          _progress = _seekPreviewProgress!;
        }
      });
      return;
    }

    _accumulatedDelta += delta;
    final threshold = _mode == PlayerMode.menu ? 18.0 : 22.0;
    if (_accumulatedDelta.abs() <= threshold) {
      return;
    }
    final direction = _accumulatedDelta.sign.toInt();
    _accumulatedDelta = 0;
    if (_mode == PlayerMode.menu) {
      final entries = _currentMenuPage.entries;
      final next = (_menuIndex + direction).clamp(0, entries.length - 1);
      if (next != _menuIndex) {
        HapticFeedback.selectionClick();
        _tick();
        setState(() => _menuIndices[_currentMenuPage.section] = next);
      }
    } else if (_mode == PlayerMode.coverFlow) {
      final albums = _coverAlbums;
      if (albums.isEmpty) {
        return;
      }
      final next = (_coverIndex + direction).clamp(0, albums.length - 1);
      if (next != _coverIndex) {
        HapticFeedback.selectionClick();
        _tick();
        setState(() => _coverIndex = next);
      }
    } else if (_mode == PlayerMode.feature) {
      final previous = _qqMusicController.selectedIndex;
      _qqMusicController.stepSelection(direction);
      if (_qqMusicController.selectedIndex != previous) {
        HapticFeedback.selectionClick();
        _tick();
      }
    }
  }

  Future<void> _handleRotationEnd() async {
    _accumulatedDelta = 0;
    final revision = _seekPreviewRevision;
    final seekTarget = _seekPreviewProgress;
    if (seekTarget != null && _qqMusicController.currentSong != null) {
      await _qqMusicController.seekToProgress(
        seekTarget,
        avoidPlaybackCompletion: true,
      );
    }
    if (!mounted || revision != _seekPreviewRevision) {
      return;
    }
    if (_playerRotationDelta != 0 || _seekPreviewProgress != null) {
      setState(() {
        _playerRotationDelta = 0;
        _seekPreviewProgress = null;
      });
    }
  }

  void _stepSelection(int direction) {
    HapticFeedback.selectionClick();
    _tick();
    if (_mode == PlayerMode.menu) {
      final entries = _currentMenuPage.entries;
      setState(() {
        _menuIndices[_currentMenuPage.section] = (_menuIndex + direction).clamp(
          0,
          entries.length - 1,
        );
      });
      return;
    }
    if (_mode == PlayerMode.feature) {
      _qqMusicController.stepSelection(direction);
      return;
    }
    if (_mode == PlayerMode.player && _qqMusicController.currentSong != null) {
      unawaited(_qqMusicController.playAdjacent(direction));
      return;
    }

    final albums = _coverAlbums;
    if (albums.isEmpty) {
      return;
    }
    final next =
        (_mode == PlayerMode.coverFlow
            ? _coverIndex
            : albums.indexWhere(
                (album) => album.imageUrl == _playingAlbum.imageUrl,
              )) +
        direction;
    final bounded = next.clamp(0, albums.length - 1);
    setState(() {
      _coverIndex = bounded;
      if (_mode == PlayerMode.player) {
        _playingAlbum = albums[bounded];
      }
    });
  }

  void _togglePlayback() {
    HapticFeedback.lightImpact();
    _tick();
    if (_qqMusicController.currentSong != null || _mode == PlayerMode.feature) {
      unawaited(_qqMusicController.togglePlayback());
      return;
    }
    setState(() => _isPlaying = !_isPlaying);
  }

  Widget _buildNowPlayingPanel(QqMusicPlaybackProgress playbackProgress) {
    final preview = _seekPreviewProgress;
    final duration = _qqMusicController.currentSong == null
        ? const Duration(seconds: 226)
        : playbackProgress.duration;
    final progress =
        preview ??
        (_qqMusicController.currentSong == null
            ? _progress
            : playbackProgress.value);
    final position = preview == null
        ? playbackProgress.position
        : Duration(milliseconds: (duration.inMilliseconds * preview).round());
    return NowPlayingPanel(
      album: _displayAlbum,
      progress: progress,
      position: position,
      duration: duration,
      rotationDelta: _playerRotationDelta,
      isBuffering: _qqMusicController.isBuffering,
      isPlaying: _mode == PlayerMode.player && _qqMusicController.isPlaying,
      error: _qqMusicController.playbackError,
      isEmpty: _qqMusicController.currentSong == null && !_hasLocalSelection,
      lyrics: _qqMusicController.lyrics,
      isLoadingLyrics: _qqMusicController.isLoadingLyrics,
      audioOutputName: _qqMusicController.audioOutputName,
      isLiked: _qqMusicController.isCurrentSongLiked,
      isSeeking: preview != null,
      playbackMode: _qqMusicController.playbackMode,
      onLikedPressed: () =>
          unawaited(_qqMusicController.toggleCurrentSongLiked()),
      onPlaybackModePressed: _qqMusicController.cyclePlaybackMode,
    );
  }

  @override
  Widget build(BuildContext context) {
    final coverAlbums = _coverAlbums;
    final media = MediaQuery.of(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemStatusBarContrastEnforced: false,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
        systemNavigationBarDividerColor: Colors.transparent,
        systemNavigationBarContrastEnforced: false,
      ),
      child: Stack(
        key: const ValueKey('fullscreen-player'),
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: Color(0xFF090A0F)),
          if (_mode == PlayerMode.feature)
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(-.55, -.7),
                  radius: 1.25,
                  colors: [Color(0xFF173127), Color(0xFF090A0F)],
                ),
              ),
            )
          else
            AmbientBackground(imageUrl: _ambientImageUrl),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x14000000),
                  Color(0x7007080D),
                  Color(0xB50A0B10),
                  Color(0xD914151B),
                ],
                stops: [0, .44, .7, 1],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.only(
              top: media.padding.top,
              bottom: media.padding.bottom,
            ),
            child: Column(
              children: [
                Expanded(
                  flex: 62,
                  child: PageView(
                    key: const ValueKey('display-section'),
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      HomePanel(
                        page: _currentMenuPage,
                        selectedIndex: _menuIndex,
                      ),
                      CoverFlowPanel(
                        selectedIndex: _coverIndex,
                        albums: coverAlbums,
                      ),
                      ValueListenableBuilder<QqMusicPlaybackProgress>(
                        valueListenable: _mode == PlayerMode.player
                            ? _qqMusicController.playbackProgress
                            : _inactivePlaybackProgress,
                        builder: (context, playbackProgress, child) {
                          return _buildNowPlayingPanel(playbackProgress);
                        },
                      ),
                      if (_activeFeature != null)
                        FeaturePanel(
                          entry: _activeFeature!,
                          controller: _qqMusicController,
                        )
                      else
                        const SizedBox.shrink(),
                    ],
                  ),
                ),
                Expanded(
                  flex: 38,
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: ClickWheel(
                        onRotate: _handleRotate,
                        onRotationEnd: () => unawaited(_handleRotationEnd()),
                        onCenter: _handleCenter,
                        onMenu: _handleMenu,
                        onPrevious: () => _stepSelection(-1),
                        onNext: () => _stepSelection(1),
                        onPlayPause: _togglePlayback,
                        isPlaying: _qqMusicController.currentSong == null
                            ? _isPlaying
                            : _qqMusicController.isPlaying,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
