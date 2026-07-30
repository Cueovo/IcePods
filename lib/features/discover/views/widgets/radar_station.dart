import 'dart:async';

import 'package:flutter/material.dart';

import 'package:qqmusic_ipod/core/theme/widgets/artwork_image.dart';
import 'package:qqmusic_ipod/features/player/state/controller.dart';

/// Full-bleed radar station — soft glass card, no green glow ring.
class RadarStation extends StatelessWidget {
  const RadarStation({
    required this.controller,
    required this.onOpenLyrics,
    required this.onOpenQueue,
    super.key,
  });

  final QqMusicController controller;
  final VoidCallback onOpenLyrics;
  final VoidCallback onOpenQueue;

  @override
  Widget build(BuildContext context) {
    final item = controller.selectedItem;
    if (item == null) {
      return const SizedBox.shrink();
    }
    final current = controller.isCurrentSong(item);
    final playing = current && controller.isPlaying;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 350;
        final artworkSize = compact ? 148.0 : 176.0;
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  key: const ValueKey('radar-station-card'),
                  width: artworkSize,
                  height: artworkSize,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(26),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x52000000),
                        blurRadius: 26,
                        offset: Offset(0, 12),
                      ),
                      BoxShadow(
                        color: Color(0x22000000),
                        blurRadius: 8,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(26),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (item.imageUrl.isEmpty)
                          const ColoredBox(
                            color: Color(0xFF1A1C22),
                            child: Icon(
                              Icons.radar_rounded,
                              color: Color(0x66FFFFFF),
                              size: 58,
                            ),
                          )
                        else
                          ArtworkImage(
                            imageUrl: item.imageUrl,
                            cacheWidth: artworkSize,
                            cacheHeight: artworkSize,
                            fit: BoxFit.cover,
                          ),
                        const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.center,
                              colors: [Color(0x99000000), Color(0x00000000)],
                            ),
                          ),
                        ),
                        Positioned(
                          left: 12,
                          bottom: 12,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: playing
                                  ? const Color(0xE6FFFFFF)
                                  : const Color(0x66FFFFFF),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    playing
                                        ? Icons.equalizer_rounded
                                        : Icons.play_arrow_rounded,
                                    size: 14,
                                    color: playing
                                        ? const Color(0xFF111318)
                                        : Colors.white,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    playing ? 'LIVE' : 'READY',
                                    style: TextStyle(
                                      color: playing
                                          ? const Color(0xFF111318)
                                          : Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: compact ? 12 : 16),
                Text(
                  item.title,
                  key: const ValueKey('radar-current-title'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: compact ? 17 : 19,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0x99FFFFFF),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: compact ? 8 : 12),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0x16FFFFFF),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x24000000),
                        blurRadius: 12,
                        offset: Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _RadarAction(
                          key: const ValueKey('radar-liked-button'),
                          icon: controller.isCurrentSongLiked
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          label: controller.isCurrentSongLiked ? '我喜欢' : '喜欢',
                          active: controller.isCurrentSongLiked,
                          activeColor: const Color(0xFFFF6578),
                          onPressed: current && controller.isLoggedIn
                              ? () => unawaited(
                                  controller.toggleCurrentSongLiked(),
                                )
                              : null,
                        ),
                        _RadarAction(
                          key: const ValueKey('radar-lyrics-button'),
                          icon: Icons.lyrics_rounded,
                          label: '歌词',
                          onPressed: current ? onOpenLyrics : null,
                        ),
                        _RadarAction(
                          key: const ValueKey('radar-playback-button'),
                          icon: playing
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          label: playing ? '暂停' : '播放',
                          onPressed: () => unawaited(
                            current
                                ? controller.togglePlayback()
                                : controller.activateSelected(),
                          ),
                        ),
                        _RadarAction(
                          key: const ValueKey('radar-queue-button'),
                          icon: Icons.queue_music_rounded,
                          label: '队列',
                          onPressed: controller.playbackQueue.isEmpty
                              ? null
                              : onOpenQueue,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _RadarAction extends StatelessWidget {
  const _RadarAction({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.active = false,
    this.activeColor = const Color(0xFFB9A0FF),
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool active;
  final Color activeColor;

  @override
  Widget build(BuildContext context) {
    final color = active ? activeColor : const Color(0xD9FFFFFF);
    return Semantics(
      button: true,
      label: label,
      child: InkResponse(
        onTap: onPressed,
        radius: 24,
        child: SizedBox.square(
          dimension: 44,
          child: Icon(
            icon,
            size: 20,
            color: onPressed == null ? const Color(0x42FFFFFF) : color,
          ),
        ),
      ),
    );
  }
}
