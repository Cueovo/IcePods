import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:qqmusic_ipod/business/repositories/music_repository.dart';
import 'package:qqmusic_ipod/core/audio/audio_handler.dart';
import 'package:qqmusic_ipod/core/theme/tokens/app_tokens.dart';
import 'package:qqmusic_ipod/core/theme/tokens/ipod_shell_theme.dart';
import 'package:qqmusic_ipod/core/utils/device_display_metrics.dart';
import 'package:qqmusic_ipod/data/repositories_impl/official_api.dart';
import 'package:qqmusic_ipod/features/shell/views/pages/ipod_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // iOS: real continuous corner radius before first paint of the framed glass.
  await DeviceDisplayMetrics.warmUp();
  // Configure the audio session before AudioService.init so the system
  // recognises this as a music app from the moment the service starts.
  final session = await AudioSession.instance;
  await session.configure(const AudioSessionConfiguration.music());
  final audioHandler = await AudioService.init<QqMusicAudioHandler>(
    builder: QqMusicAudioHandler.new,
    config: const AudioServiceConfig(
      androidNotificationChannelId:
          'com.qqmusic.ipod.qqmusic_ipod.channel.audio.v3',
      androidNotificationChannelName: '音乐播放',
      androidNotificationChannelDescription: '显示正在播放的歌曲和媒体控制',
      androidNotificationIcon: 'drawable/ic_stat_music_note',
      androidNotificationOngoing: false,
      androidStopForegroundOnPause: false,
      artDownscaleWidth: 512,
      artDownscaleHeight: 512,
    ),
  );
  // Immersive sticky: draw under the status-bar band and keep OS icons hidden.
  // Swipe-to-reveal is transient; MainActivity also re-hides on Meizu/Flyme.
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
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
  runApp(
    MyApp(
      api: QqMusicOfficialApi(),
      audioHandler: audioHandler,
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({
    required this.api,
    this.audioHandler,
    super.key,
  });

  final QqMusicApi api;
  final QqMusicAudioHandler? audioHandler;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Ambient Player',
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        fontFamily: 'sans-serif',
        colorScheme: const ColorScheme.dark(
          primary: AppColors.accent,
          secondary: AppColors.accent,
          error: AppColors.error,
          surface: AppColors.surface,
        ),
        // Bolder defaults so Material widgets inherit weight without per-TextStyle.
        textTheme: Typography.whiteMountainView.copyWith(
          displayLarge: AppTextStyles.title.copyWith(fontSize: 57),
          displayMedium: AppTextStyles.title.copyWith(fontSize: 45),
          displaySmall: AppTextStyles.title.copyWith(fontSize: 36),
          headlineLarge: AppTextStyles.title.copyWith(fontSize: 32),
          headlineMedium: AppTextStyles.title.copyWith(fontSize: 28),
          headlineSmall: AppTextStyles.title.copyWith(fontSize: 24),
          titleLarge: AppTextStyles.title,
          titleMedium: AppTextStyles.body.copyWith(
            fontSize: 16,
            fontWeight: AppTextStyles.strong,
          ),
          titleSmall: AppTextStyles.body.copyWith(
            fontSize: 14,
            fontWeight: AppTextStyles.strong,
          ),
          bodyLarge: AppTextStyles.body.copyWith(fontSize: 15),
          bodyMedium: AppTextStyles.body,
          bodySmall: AppTextStyles.caption,
          labelLarge: AppTextStyles.body.copyWith(
            fontWeight: AppTextStyles.strong,
          ),
          labelMedium: AppTextStyles.caption.copyWith(fontSize: 12),
          labelSmall: AppTextStyles.caption,
        ),
        cardTheme: CardThemeData(
          color: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.card),
          ),
        ),
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
            TargetPlatform.iOS: FadeForwardsPageTransitionsBuilder(),
          },
        ),
        splashFactory: InkSparkle.splashFactory,
        scrollbarTheme: ScrollbarThemeData(
          thickness: const WidgetStatePropertyAll(2),
          radius: const Radius.circular(99),
          thumbColor: const WidgetStatePropertyAll(Color(0x2EFFFFFF)),
          trackVisibility: const WidgetStatePropertyAll(false),
          thumbVisibility: const WidgetStatePropertyAll(false),
          interactive: false,
          crossAxisMargin: 0,
          mainAxisMargin: 6,
          minThumbLength: 16,
        ),
        extensions: const <ThemeExtension<dynamic>>[
          IpodShellTheme.classic,
        ],
      ),
      home: IpodScreen(api: api, audioHandler: audioHandler),
    );
  }
}
