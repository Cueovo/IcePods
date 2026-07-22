import 'package:flutter/material.dart';

import 'package:qqmusic_ipod/core/theme/widgets/artwork_image.dart';
import 'package:qqmusic_ipod/features/player/state/controller.dart';

/// Full-bleed radar station — soft glass card, no green glow ring.
class RadarStation extends StatelessWidget {
  const RadarStation({required this.controller, super.key});

  final QqMusicController controller;

  @override
  Widget build(BuildContext context) {
    final item = controller.selectedItem;
    if (item == null) {
      return const SizedBox.shrink();
    }
    final playing = controller.isCurrentSong(item) && controller.isPlaying;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Artwork with subtle depth, no colored halo.
            Container(
              key: const ValueKey('radar-station-card'),
              width: 196,
              height: 196,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x66000000),
                    blurRadius: 32,
                    offset: Offset(0, 16),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (item.imageUrl.isEmpty)
                      const ColoredBox(
                        color: Color(0xFF1A1C22),
                        child: Icon(
                          Icons.radar_rounded,
                          color: Color(0x66FFFFFF),
                          size: 64,
                        ),
                      )
                    else
                      ArtworkImage(
                        imageUrl: item.imageUrl,
                        cacheWidth: 196,
                        cacheHeight: 196,
                        fit: BoxFit.cover,
                      ),
                    // Soft bottom shade for the live pill.
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.center,
                          colors: [
                            Color(0x99000000),
                            Color(0x00000000),
                          ],
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
            const SizedBox(height: 22),
            Text(
              item.title,
              key: const ValueKey('radar-current-title'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                height: 1.15,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              item.subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0x99FFFFFF),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
