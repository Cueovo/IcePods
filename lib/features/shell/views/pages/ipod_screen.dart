import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:qqmusic_ipod/business/repositories/music_repository.dart';
import 'package:qqmusic_ipod/core/audio/audio_handler.dart';
import 'package:qqmusic_ipod/core/theme/tokens/ipod_shell_theme.dart';
import 'package:qqmusic_ipod/core/theme/widgets/click_wheel.dart';
import 'package:qqmusic_ipod/features/player/state/controller.dart';
import 'package:qqmusic_ipod/features/player/views/pages/now_playing_panel.dart';
import 'package:qqmusic_ipod/features/player/views/widgets/cover_flow_panel.dart';
import 'package:qqmusic_ipod/features/shell/models/ipod_models.dart';
import 'package:qqmusic_ipod/features/shell/state/shell_controller.dart';
import 'package:qqmusic_ipod/features/shell/views/pages/feature_panel.dart';
import 'package:qqmusic_ipod/features/shell/views/widgets/ambient_background.dart'
    if (dart.library.js_interop) 'package:qqmusic_ipod/features/shell/views/widgets/ambient_background_web.dart';
import 'package:qqmusic_ipod/features/shell/views/widgets/home_panel.dart';
import 'package:qqmusic_ipod/features/shell/views/widgets/ipod_status_bar.dart';

class IpodScreen extends StatefulWidget {
  const IpodScreen({
    required this.api,
    this.audioHandler,
    super.key,
  });

  final QqMusicApi api;
  final QqMusicAudioHandler? audioHandler;

  @override
  State<IpodScreen> createState() => _IpodScreenState();
}

class _IpodScreenState extends State<IpodScreen> with WidgetsBindingObserver {
  late final ShellController _shell;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _shell = ShellController(
      api: widget.api,
      audioHandler: widget.audioHandler,
    );
    _hideSystemStatusBar();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _shell.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _hideSystemStatusBar();
    }
  }

  void _hideSystemStatusBar() {
    // Keep re-asserting immersive sticky — Meizu gesture often leaves the bar shown.
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemStatusBarContrastEnforced: false,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
        systemNavigationBarDividerColor: Colors.transparent,
        systemNavigationBarContrastEnforced: false,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = IpodShellTheme.of(context);
    return AnimatedBuilder(
      animation: _shell,
      builder: (context, child) {
        return Scaffold(
          // Body / chassis color fills everything outside screen + wheel.
          backgroundColor: _shell.chassisColor,
          extendBody: true,
          extendBodyBehindAppBar: true,
          body: SizedBox.expand(
            child: _IpodShellView(shell: _shell, theme: theme),
          ),
        );
      },
    );
  }
}

class _IpodShellView extends StatelessWidget {
  const _IpodShellView({required this.shell, required this.theme});

  final ShellController shell;
  final IpodShellTheme theme;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    // Flush to the top edge; keep bottom corners rounded.
    final radius = BorderRadius.only(
      topLeft: Radius.zero,
      topRight: Radius.zero,
      bottomLeft: Radius.circular(theme.screenRadius),
      bottomRight: Radius.circular(theme.screenRadius),
    );
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
      // Chassis fills the device; ambient lives only inside the screen.
      child: ColoredBox(
        key: const ValueKey('fullscreen-player'),
        color: shell.chassisColor,
        child: Padding(
          padding: EdgeInsets.only(
            top: 0,
            bottom: media.padding.bottom,
            left: 0,
            right: 0,
          ),
          child: Column(
            children: [
              Expanded(
                flex: 56,
                child: ClipRRect(
                  borderRadius: radius,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Ambient / glow only inside the screen.
                      if (shell.mode == PlayerMode.feature)
                        DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: RadialGradient(
                              center: const Alignment(-.55, -.7),
                              radius: 1.25,
                              colors: [
                                theme.featureGlow,
                                theme.scaffoldBackground,
                              ],
                            ),
                          ),
                        )
                      else
                        AmbientBackground(imageUrl: shell.ambientImageUrl),
                      // Continuous ambient wash — keep top nearly clear so status bar
                      // doesn't sit on a different color band.
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color(0x00000000),
                              Color(0x18000000),
                              Color(0x55000000),
                              Color(0x99000000),
                            ],
                            stops: [0, .28, .68, 1],
                          ),
                        ),
                      ),
                      Column(
                        children: [
                          const IpodStatusBar(),
                          Expanded(
                            child: PageView(
                              key: const ValueKey('display-section'),
                              controller: shell.pageController,
                              physics: const NeverScrollableScrollPhysics(),
                              children: [
                                HomePanel(
                                  page: shell.currentMenuPage,
                                  selectedIndex: shell.menuIndex,
                                ),
                                CoverFlowPanel(
                                  selectedIndex: shell.coverIndex,
                                  albums: shell.coverAlbums,
                                ),
                                _NowPlayingHost(shell: shell),
                                if (shell.activeFeature != null)
                                  FeaturePanel(
                                    entry: shell.activeFeature!,
                                    controller: shell.music,
                                  )
                                else
                                  const SizedBox.shrink(),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                flex: 48,
                child: Align(
                  // Lower the wheel a bit so the larger screen has breathing room.
                  alignment: const Alignment(0, -0.12),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: ClickWheel(
                      onRotate: shell.handleRotate,
                      onRotationEnd: () =>
                          unawaited(shell.handleRotationEnd()),
                      onCenter: shell.handleCenter,
                      onMenu: shell.handleMenu,
                      onPrevious: () => shell.stepSelection(-1),
                      onNext: () => shell.stepSelection(1),
                      onPlayPause: shell.togglePlayback,
                      isPlaying: shell.wheelIsPlaying,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NowPlayingHost extends StatelessWidget {
  const _NowPlayingHost({required this.shell});

  final ShellController shell;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<QqMusicPlaybackProgress>(
      valueListenable: shell.playbackProgressListenable,
      builder: (context, playbackProgress, child) {
        final preview = shell.seekPreviewProgress;
        final duration = shell.music.currentSong == null
            ? const Duration(seconds: 226)
            : playbackProgress.duration;
        final progress =
            preview ??
            (shell.music.currentSong == null
                ? shell.progress
                : playbackProgress.value);
        final position = preview == null
            ? playbackProgress.position
            : Duration(
                milliseconds: (duration.inMilliseconds * preview).round(),
              );
        return NowPlayingPanel(
          album: shell.displayAlbum,
          progress: progress,
          position: position,
          duration: duration,
          rotationDelta: shell.playerRotationDelta,
          isBuffering: shell.music.isBuffering,
          isPlaying:
              shell.mode == PlayerMode.player && shell.music.isPlaying,
          error: shell.music.playbackError,
          isEmpty:
              shell.music.currentSong == null && !shell.hasLocalSelection,
          lyrics: shell.music.lyrics,
          isLoadingLyrics: shell.music.isLoadingLyrics,
          audioOutputName: shell.music.audioOutputName,
          isLiked: shell.music.isCurrentSongLiked,
          isSeeking: preview != null,
          playbackMode: shell.music.playbackMode,
          onLikedPressed: () =>
              unawaited(shell.music.toggleCurrentSongLiked()),
          onPlaybackModePressed: shell.music.cyclePlaybackMode,
        );
      },
    );
  }
}
