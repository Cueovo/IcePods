import 'package:flutter/material.dart';

import 'package:qqmusic_ipod/business/entities/music.dart';
import 'package:qqmusic_ipod/core/theme/tokens/app_tokens.dart';
import 'package:qqmusic_ipod/core/theme/widgets/artwork_image.dart';

class MediaTile extends StatelessWidget {
  const MediaTile({
    required this.item,
    required this.selected,
    required this.current,
    required this.playing,
    required this.marked,
    required this.unavailable,
    required this.canToggleMark,
    required this.onSelect,
    required this.onToggleMark,
    super.key,
  });

  final QqMusicItem item;
  final bool selected;
  final bool current;
  final bool playing;
  final bool marked;
  final bool unavailable;
  final bool canToggleMark;
  final VoidCallback onSelect;
  final VoidCallback onToggleMark;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onSelect,
      child: AnimatedContainer(
        key: current
            ? ValueKey('current-song-${item.id}')
            : selected
            ? const ValueKey('api-feature-selection')
            : null,
        duration: const Duration(milliseconds: 180),
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: current
              ? AppColors.accentSoft
              : selected
              ? AppColors.surfaceSelected
              : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadii.tile),
          border: Border.all(
            color: current
                ? AppColors.accentBorder
                : selected
                ? AppColors.accentSoft
                : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: SizedBox.square(
                dimension: 38,
                child: item.imageUrl.isEmpty
                    ? const ColoredBox(
                        color: Color(0xFF303037),
                        child: Icon(
                          Icons.music_note_rounded,
                          color: Color(0x99FFFFFF),
                          size: 20,
                        ),
                      )
                    : ArtworkImage(
                        imageUrl: item.imageUrl,
                        cacheWidth: 38,
                        cacheHeight: 38,
                        fadeIn: false,
                        filterQuality: FilterQuality.low,
                      ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: item.isCopyrightRestricted || unavailable
                                ? const Color(0x70FFFFFF)
                                : current
                                ? AppColors.accent
                                : selected
                                ? Colors.white
                                : const Color(0xCCFFFFFF),
                            fontSize: 13,
                            fontWeight: selected || current
                                ? FontWeight.w700
                                : FontWeight.w600,
                          ),
                        ),
                      ),
                      if (item.isSong && item.isCopyrightRestricted) ...[
                        const SizedBox(width: 5),
                        Container(
                          key: ValueKey('copyright-badge-${item.id}'),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0x1FFFFFFF),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: const Color(0x55FFFFFF),
                              width: .7,
                            ),
                          ),
                          child: const Text(
                            '无版权',
                            style: TextStyle(
                              color: Color(0x99FFFFFF),
                              fontSize: 8,
                              fontWeight: FontWeight.w700,
                              height: 1.1,
                            ),
                          ),
                        ),
                      ] else if (item.isSong &&
                          unavailable &&
                          !item.requiresVip &&
                          !item.isCopyrightRestricted) ...[
                        const SizedBox(width: 5),
                        Container(
                          key: ValueKey('unavailable-badge-${item.id}'),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0x1FFFFFFF),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: const Color(0x55FFFFFF),
                              width: .7,
                            ),
                          ),
                          child: const Text(
                            '无音源',
                            style: TextStyle(
                              color: Color(0x99FFFFFF),
                              fontSize: 8,
                              fontWeight: FontWeight.w700,
                              height: 1.1,
                            ),
                          ),
                        ),
                      ] else if (item.isSong && item.requiresVip) ...[
                        const SizedBox(width: 5),
                        Container(
                          key: ValueKey('vip-badge-${item.id}'),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0x26F2C14E),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: const Color(0xBFF2C14E),
                              width: .7,
                            ),
                          ),
                          child: const Text(
                            'VIP',
                            style: TextStyle(
                              color: Color(0xFFF2C14E),
                              fontSize: 8,
                              fontWeight: FontWeight.w800,
                              height: 1.1,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (item.subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      item.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0x70FFFFFF),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (canToggleMark)
              IconButton(
                key: ValueKey('api-mark-${item.type.name}-${item.id}'),
                tooltip: marked ? '取消收藏歌单' : '收藏歌单',
                onPressed: onToggleMark,
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  marked
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color: marked ? AppColors.accent : AppColors.textMuted,
                  size: 17,
                ),
              ),
            Icon(
              current
                  ? playing
                        ? Icons.graphic_eq_rounded
                        : Icons.pause_circle_filled_rounded
                  : item.isSong
                  ? Icons.play_arrow_rounded
                  : Icons.chevron_right_rounded,
              key: current
                  ? ValueKey(
                      playing
                          ? 'current-song-playing-${item.id}'
                          : 'current-song-paused-${item.id}',
                    )
                  : null,
              color: item.isCopyrightRestricted
                  ? const Color(0x35FFFFFF)
                  : current
                  ? AppColors.accent
                  : selected
                  ? AppColors.accent
                  : const Color(0x55FFFFFF),
              size: current ? 20 : 19,
            ),
          ],
        ),
      ),
    );
  }
}
