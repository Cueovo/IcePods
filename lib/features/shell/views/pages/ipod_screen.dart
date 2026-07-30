import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import 'package:qqmusic_ipod/business/repositories/music_repository.dart';
import 'package:qqmusic_ipod/core/audio/audio_handler.dart';
import 'package:qqmusic_ipod/core/theme/tokens/app_tokens.dart';
import 'package:qqmusic_ipod/core/theme/tokens/ipod_shell_theme.dart';
import 'package:qqmusic_ipod/core/theme/widgets/click_wheel.dart';
import 'package:qqmusic_ipod/features/player/state/controller.dart';
import 'package:qqmusic_ipod/features/player/views/pages/now_playing_panel.dart';
import 'package:qqmusic_ipod/features/player/views/widgets/cover_flow_panel.dart';
import 'package:qqmusic_ipod/features/player/views/widgets/playback_queue_panel.dart';
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
        final backdrop = ChassisBackdropColors.fromChassis(_shell.chassisColor);
        return Scaffold(
          // Body / chassis color fills everything outside screen + wheel.
          backgroundColor: backdrop,
          extendBody: true,
          extendBodyBehindAppBar: true,
          body: SizedBox.expand(
            child: _IpodShellView(
              shell: _shell,
              theme: theme,
              backdrop: backdrop,
            ),
          ),
        );
      },
    );
  }
}

class _IpodShellView extends StatelessWidget {
  const _IpodShellView({
    required this.shell,
    required this.theme,
    required this.backdrop,
  });

  final ShellController shell;
  final IpodShellTheme theme;
  final Color backdrop;

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
    // Single dark bezel with a softer inner glass edge.
    final frame = ChassisFrameColors.fromChassis(shell.chassisColor);
    const glassRimWidth = 1.0;
    final bezelPadding = chassisInsets.bezelPadding;
    // Corner radius follows side/bottom bezel only — never the tall top band
    // used to wrap a camera hole (that would collapse the glass clip).
    final glassRadius = _insetBorderRadius(
      outerRadius,
      chassisInsets.bezelRadiusInset,
    );
    // Glass already cleared part of the cutout via the top bezel; residual
    // top padding prevents the status bar from double-reserving safeTop.
    final residualTop = chassisInsets.residualTopInset();
    final glassMedia = media.copyWith(
      padding: media.padding.copyWith(top: residualTop),
      viewPadding: media.viewPadding.copyWith(top: residualTop),
    );
    final backdropBrightness = ThemeData.estimateBrightnessForColor(backdrop);
    final systemIconBrightness = backdropBrightness == Brightness.light
        ? Brightness.dark
        : Brightness.light;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: systemIconBrightness,
        statusBarBrightness: backdropBrightness,
        systemStatusBarContrastEnforced: false,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: systemIconBrightness,
        systemNavigationBarDividerColor: Colors.transparent,
        systemNavigationBarContrastEnforced: false,
      ),
      // Chassis fills the device; ambient lives only inside the screen.
      child: ColoredBox(
        key: const ValueKey('fullscreen-player'),
        color: backdrop,
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
                flex: 60,
                child: Padding(
                  // Inset on all sides so continuous corners + bezel sit on chassis.
                  // Top scales down on notch/island (status bar already tall inside).
                  padding: chassisInsets.screenFramePadding,
                  child: DecoratedBox(
                    key: const ValueKey('ipod-screen-frame'),
                    decoration: ShapeDecoration(
                      // Bezel fill stays darker than the chassis.
                      color: frame.bezel,
                      shape: RoundedSuperellipseBorder(
                        borderRadius: outerRadius,
                      ),
                    ),
                    child: Padding(
                      key: const ValueKey('ipod-screen-bezel-padding'),
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
                                if (!shell.hasCustomBackground &&
                                    (shell.mode == PlayerMode.feature ||
                                        shell.mode == PlayerMode.queue))
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
                                    customImagePath: shell.customBackgroundPath,
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
                                          _MenuPageTransition(
                                            page: shell.currentMenuPage,
                                            selectedIndex: shell.menuIndex,
                                            menuDepth: shell.menuPath.length,
                                            valueForEntry:
                                                shell.valueForMenuEntry,
                                            descriptionForEntry:
                                                shell.descriptionForMenuEntry,
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
                                              isActive:
                                                  shell.mode ==
                                                  PlayerMode.feature,
                                              onOpenLyrics:
                                                  shell.openPlayerLyrics,
                                              onOpenQueue: shell.openQueue,
                                            )
                                          else
                                            const SizedBox.shrink(),
                                          PlaybackQueuePanel(
                                            queue: shell.music.playbackQueue,
                                            currentIndex: shell
                                                .music
                                                .currentPlaybackQueueIndex,
                                            selectedIndex:
                                                shell.selectedQueueIndex,
                                            isPlaying: shell.music.isPlaying,
                                            onPlayIndex: (index) => unawaited(
                                              shell.playQueueIndex(index),
                                            ),
                                            onRemoveIndex:
                                                shell.removeQueueIndex,
                                            onClearUpcoming:
                                                shell.clearUpcomingQueue,
                                          ),
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
                  flex: 44,
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

class _MenuPageTransition extends StatefulWidget {
  const _MenuPageTransition({
    required this.page,
    required this.selectedIndex,
    required this.menuDepth,
    required this.valueForEntry,
    required this.descriptionForEntry,
  });

  final MenuPage page;
  final int selectedIndex;
  final int menuDepth;
  final String? Function(MenuEntry entry) valueForEntry;
  final String Function(MenuEntry entry) descriptionForEntry;

  @override
  State<_MenuPageTransition> createState() => _MenuPageTransitionState();
}

class _MenuPageTransitionState extends State<_MenuPageTransition> {
  late bool _isForward = true;

  @override
  void didUpdateWidget(_MenuPageTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.menuDepth != widget.menuDepth) {
      _isForward = widget.menuDepth > oldWidget.menuDepth;
    }
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final enteringOffset = reduceMotion
        ? Offset.zero
        : _isForward
        ? const Offset(.065, 0)
        : const Offset(-.065, 0);
    final exitingOffset = reduceMotion
        ? Offset.zero
        : _isForward
        ? const Offset(-.025, 0)
        : const Offset(.025, 0);
    final currentKey = ValueKey(widget.page.section);

    return ClipRect(
      child: AnimatedSwitcher(
        duration: reduceMotion
            ? AppDurations.reducedMotion
            : AppDurations.menuPage,
        layoutBuilder: (currentChild, previousChildren) {
          return Stack(
            fit: StackFit.expand,
            children: [
              if (previousChildren.isNotEmpty) previousChildren.last,
              ?currentChild,
            ],
          );
        },
        transitionBuilder: (child, animation) {
          final isIncoming = child.key == currentKey;
          final progress = isIncoming ? animation : ReverseAnimation(animation);
          final position =
              Tween<Offset>(
                begin: isIncoming ? enteringOffset : Offset.zero,
                end: isIncoming ? Offset.zero : exitingOffset,
              ).animate(
                CurvedAnimation(parent: progress, curve: AppCurves.menuPage),
              );
          final opacity =
              Tween<double>(
                begin: isIncoming ? 0 : 1,
                end: isIncoming ? 1 : 0,
              ).animate(
                CurvedAnimation(
                  parent: progress,
                  curve: Interval(
                    isIncoming ? .08 : 0,
                    isIncoming ? .72 : .38,
                    curve: AppCurves.strongEaseOut,
                  ),
                ),
              );
          return FadeTransition(
            opacity: opacity,
            child: SlideTransition(position: position, child: child),
          );
        },
        child: RepaintBoundary(
          key: currentKey,
          child: HomePanel(
            page: widget.page,
            selectedIndex: widget.selectedIndex,
            valueForEntry: widget.valueForEntry,
            descriptionForEntry: widget.descriptionForEntry,
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
          isPlaying: shell.mode == PlayerMode.player && shell.music.isPlaying,
          error: shell.music.playbackError,
          isEmpty: shell.music.currentSong == null && !shell.hasLocalSelection,
          lyrics: shell.music.lyrics,
          isLoadingLyrics: shell.music.isLoadingLyrics,
          audioOutputName: shell.music.audioOutputName,
          isLiked: shell.music.isCurrentSongLiked,
          isSeeking: preview != null,
          playbackMode: shell.music.playbackMode,
          queueLength: shell.music.playbackQueue.length,
          lyricsOpenRevision: shell.lyricsOpenRevision,
          onLikedPressed: () => unawaited(shell.music.toggleCurrentSongLiked()),
          onPlaybackModePressed: shell.music.cyclePlaybackMode,
          onQueuePressed: shell.openQueue,
        );
      },
    );
  }
}
