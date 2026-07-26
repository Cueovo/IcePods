import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
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
import 'package:qqmusic_ipod/features/shell/views/widgets/chassis_insets.dart';
import 'package:qqmusic_ipod/features/shell/views/widgets/home_panel.dart';
import 'package:qqmusic_ipod/features/shell/views/widgets/ipod_status_bar.dart';

class IpodScreen extends StatefulWidget {
  const IpodScreen({required this.api, this.audioHandler, super.key});

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
      _shell.music.onAppResumed();
      // The Flutter rendering surface may be stale after background audio.
      // Schedule two consecutive frames: the first rebuilds the widget tree,
      // the second ensures the GPU surface has flushed a real drawable.
      SchedulerBinding.instance.scheduleFrame();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        SchedulerBinding.instance.scheduleFrame();
      });
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
    // Outer / bezel adapt so punch-holes sit inside the top bezel band.
    final chassisInsets = ChassisInsets.resolve(media);
    final keyboardVisible = media.viewInsets.bottom > 0;
    // Framed display with continuous-corner (superellipse) curvature.
    // iOS: match physical device corner (concentric with phone bezel).
    // Android / other: keep themed iPod panel radius.
    final r = ScreenCornerRadius.outerFrame(
      mq: media,
      insets: chassisInsets,
      fallback: theme.screenBottomRadius,
    );
    final outerRadius = BorderRadius.circular(r);
    // Dual frame: thin highlight strokes + a wider bezel band between them
    // (the gap is what reads as "thicker border", not the stroke width).
    final frame = ChassisFrameColors.fromChassis(shell.chassisColor);
    const outerRimWidth = 1.0;
    const glassRimWidth = 1.0;
    final bezelPadding = chassisInsets.bezelPadding;
    // Corner radius follows side/bottom bezel only — never the tall top band
    // used to wrap a camera hole (that would collapse the glass clip).
    final glassRadius = _insetBorderRadius(
      outerRadius,
      outerRimWidth + chassisInsets.bezelRadiusInset,
    );
    // Glass already cleared part of the cutout via the top bezel; residual
    // top padding prevents the status bar from double-reserving safeTop.
    final residualTop = chassisInsets.residualTopInset();
    final glassMedia = media.copyWith(
      padding: media.padding.copyWith(top: residualTop),
      viewPadding: media.viewPadding.copyWith(top: residualTop),
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
          // Bottom keeps home-indicator safe area; top is cutout-aware.
          padding: EdgeInsets.only(
            top: chassisInsets.topOuter,
            bottom: media.padding.bottom,
            left: 0,
            right: 0,
          ),
          child: Column(
            children: [
              Expanded(
                flex: 56,
                child: Padding(
                  // Inset on all sides so continuous corners + dual bezel sit on chassis.
                  // Top scales down on notch/island (status bar already tall inside).
                  padding: chassisInsets.screenFramePadding,
                  child: DecoratedBox(
                    key: const ValueKey('ipod-screen-frame'),
                    decoration: ShapeDecoration(
                      // Bezel fill darker than chassis; outer rim is a highlight.
                      color: frame.bezel,
                      shape: RoundedSuperellipseBorder(
                        borderRadius: outerRadius,
                        side: BorderSide(
                          color: frame.outerRim,
                          width: outerRimWidth,
                        ),
                      ),
                    ),
                    child: Padding(
                      // Thicker top bezel only when insets request it; sides stay even.
                      padding: bezelPadding,
                      child: DecoratedBox(
                        key: const ValueKey('ipod-screen-glass'),
                        decoration: ShapeDecoration(
                          shape: RoundedSuperellipseBorder(
                            borderRadius: glassRadius,
                            side: BorderSide(
                              color: frame.innerRim,
                              width: glassRimWidth,
                            ),
                          ),
                        ),
                        child: ClipRSuperellipse(
                          borderRadius: glassRadius,
                          child: MediaQuery(
                            data: glassMedia,
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
                                  AmbientBackground(
                                    imageUrl: shell.ambientImageUrl,
                                  ),
                                // Soft mid-screen dim only — fade out before the
                                // bottom so the frame edge stays crisp.
                                const DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Color(0x00000000),
                                        Color(0x14000000),
                                        Color(0x2E000000),
                                        Color(0x00000000),
                                      ],
                                      stops: [0, .32, .62, 1],
                                    ),
                                  ),
                                ),
                                Column(
                                  children: [
                                    if (chassisInsets.glassContentTop > 0)
                                      SizedBox(
                                        height: chassisInsets.glassContentTop,
                                      ),
                                    const IpodStatusBar(),
                                    Expanded(
                                      child: PageView(
                                        key: const ValueKey('display-section'),
                                        controller: shell.pageController,
                                        physics:
                                            const NeverScrollableScrollPhysics(),
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
                      ),
                    ),
                  ),
                ),
              ),
              if (!keyboardVisible)
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

/// Shrinks each corner of [radius] by [inset] for concentric nested frames.
BorderRadius _insetBorderRadius(BorderRadius radius, double inset) {
  Radius shrink(Radius r) {
    final x = (r.x - inset).clamp(0.0, r.x);
    final y = (r.y - inset).clamp(0.0, r.y);
    return Radius.circular(x < y ? x : y);
  }

  return BorderRadius.only(
    topLeft: shrink(radius.topLeft),
    topRight: shrink(radius.topRight),
    bottomLeft: shrink(radius.bottomLeft),
    bottomRight: shrink(radius.bottomRight),
  );
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
          isPlaying: shell.mode == PlayerMode.player && shell.music.isPlaying,
          error: shell.music.playbackError,
          isEmpty: shell.music.currentSong == null && !shell.hasLocalSelection,
          lyrics: shell.music.lyrics,
          isLoadingLyrics: shell.music.isLoadingLyrics,
          audioOutputName: shell.music.audioOutputName,
          isLiked: shell.music.isCurrentSongLiked,
          isSeeking: preview != null,
          playbackMode: shell.music.playbackMode,
          onLikedPressed: () => unawaited(shell.music.toggleCurrentSongLiked()),
          onPlaybackModePressed: shell.music.cyclePlaybackMode,
        );
      },
    );
  }
}
