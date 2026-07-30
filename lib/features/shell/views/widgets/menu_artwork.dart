import 'package:flutter/material.dart';

import 'package:qqmusic_ipod/business/entities/music.dart';
import 'package:qqmusic_ipod/features/shell/models/ipod_models.dart';

class MenuArtwork extends StatelessWidget {
  const MenuArtwork({required this.entry, this.compact = false, super.key});

  final MenuEntry entry;
  final bool compact;

  static IconData iconFor(MenuEntry entry) {
    return switch (entry.feature) {
      QqMusicFeature.guessRecommendations => Icons.auto_awesome_rounded,
      QqMusicFeature.homeFeed => Icons.home_rounded,
      QqMusicFeature.radar => Icons.radar_rounded,
      QqMusicFeature.newSongs => Icons.fiber_new_rounded,
      QqMusicFeature.recommendedPlaylists => Icons.queue_music_rounded,
      QqMusicFeature.search => Icons.search_rounded,
      QqMusicFeature.account => Icons.person_rounded,
      QqMusicFeature.charts => Icons.leaderboard_rounded,
      QqMusicFeature.singers => Icons.mic_rounded,
      QqMusicFeature.likedSongs => Icons.favorite_rounded,
      QqMusicFeature.favoriteAlbums => Icons.album_rounded,
      QqMusicFeature.favoriteMusicVideos => Icons.smart_display_rounded,
      QqMusicFeature.favoriteSingers => Icons.person_pin_rounded,
      QqMusicFeature.createdPlaylists => Icons.playlist_add_rounded,
      QqMusicFeature.collectedPlaylists => Icons.library_music_rounded,
      QqMusicFeature.dislikes => Icons.thumb_down_rounded,
      null => switch (entry.id) {
        'now_playing' => Icons.play_circle_fill_rounded,
        'cover_flow' => Icons.view_carousel_rounded,
        'recommendations' => Icons.auto_awesome_rounded,
        'music_hall' => Icons.album_rounded,
        'my_music' => Icons.library_music_rounded,
        'playback_settings' => Icons.play_circle_outline_rounded,
        'control_settings' => Icons.tune_rounded,
        'appearance_settings' => Icons.palette_outlined,
        'system_settings' => Icons.storage_rounded,
        'click_sound' => Icons.touch_app_rounded,
        'equalizer' => Icons.equalizer_rounded,
        'audio_quality' => Icons.high_quality_rounded,
        'gapless_playback' => Icons.queue_play_next_rounded,
        'sleep_timer' => Icons.bedtime_outlined,
        'spatial_audio' => Icons.spatial_audio_rounded,
        'volume_limit' => Icons.volume_down_rounded,
        'haptics' => Icons.vibration_rounded,
        'cache' => Icons.cleaning_services_rounded,
        'about' => Icons.info_rounded,
        'settings' => Icons.settings_rounded,
        'chassis_color' => Icons.palette_rounded,
        'custom_background' => Icons.wallpaper_rounded,
        'restore_dynamic_background' => Icons.auto_awesome_rounded,
        _ => switch (entry.action) {
          MenuAction.coverFlow => Icons.view_carousel_rounded,
          MenuAction.player => Icons.play_circle_fill_rounded,
          MenuAction.submenu => Icons.folder_rounded,
          MenuAction.feature => Icons.music_note_rounded,
          MenuAction.info => Icons.tune_rounded,
          MenuAction.chassisColor => Icons.circle_rounded,
          MenuAction.setting => Icons.tune_rounded,
        },
      },
    };
  }

  static Color accentFor(MenuEntry entry) {
    final chassis = entry.chassisColorValue;
    if (chassis != null) {
      return Color(chassis);
    }
    final seed = entry.id.codeUnits.fold<int>(0, (sum, value) => sum + value);
    const accents = [
      Color(0xFF31C27C),
      Color(0xFF5A8DEE),
      Color(0xFFE15D8A),
      Color(0xFFF0A44B),
      Color(0xFF8B6BE8),
    ];
    return accents[seed % accents.length];
  }

  @override
  Widget build(BuildContext context) {
    final icon = iconFor(entry);
    final accent = accentFor(entry);
    final iconSize = compact ? 24.0 : 48.0;
    final badgeSize = compact ? 34.0 : 92.0;
    final watermarkSize = compact ? 58.0 : 155.0;
    return DecoratedBox(
      key: ValueKey('menu-artwork-${entry.id}${compact ? '-compact' : ''}'),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          // Keep some transparency so ambient behind the card can show through.
          colors: [
            accent.withValues(alpha: compact ? .9 : .72),
            const Color(0xCC111318),
          ],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            right: compact ? -10 : -28,
            top: compact ? -10 : -25,
            child: Icon(
              icon,
              size: watermarkSize,
              color: const Color(0x18FFFFFF),
            ),
          ),
          Center(
            child: Container(
              width: badgeSize,
              height: badgeSize,
              decoration: const BoxDecoration(
                color: Color(0x24FFFFFF),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: iconSize, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
