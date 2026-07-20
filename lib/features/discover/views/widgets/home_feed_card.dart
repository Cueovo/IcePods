import 'package:flutter/material.dart';

import 'package:qqmusic_ipod/business/entities/music.dart';
import 'package:qqmusic_ipod/core/theme/widgets/artwork_image.dart';

class HomeFeedCard extends StatelessWidget {
  const HomeFeedCard({
    required this.item,
    required this.selected,
    required this.onSelect,
    super.key,
  });

  final QqMusicItem item;
  final bool selected;
  final VoidCallback onSelect;

  String get _badge {
    if (item.directoryId == '202' || item.title.contains('每日30')) {
      return '今日推荐';
    }
    return switch (item.type) {
      QqMusicItemType.chart => '排行榜',
      QqMusicItemType.album => '专辑',
      QqMusicItemType.song => '歌曲',
      QqMusicItemType.playlist => item.hasEmbeddedChildren ? '歌曲合集' : '歌单',
      QqMusicItemType.singer => '歌手',
      QqMusicItemType.musicVideo => 'MV',
    };
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onSelect,
      child: AnimatedContainer(
        key: selected
            ? const ValueKey('home-feed-selection')
            : ValueKey('home-feed-card-${item.id}'),
        duration: const Duration(milliseconds: 180),
        height: 86,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: selected ? const Color(0x2631C27C) : const Color(0x14FFFFFF),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? const Color(0x8031C27C) : const Color(0x18FFFFFF),
          ),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox.square(
                dimension: 70,
                child: item.imageUrl.isEmpty
                    ? ColoredBox(
                        color: const Color(0xFF1A2A22),
                        child: Icon(
                          item.directoryId == '202' ||
                                  item.title.contains('每日30')
                              ? Icons.auto_awesome_rounded
                              : item.type == QqMusicItemType.chart
                              ? Icons.leaderboard_rounded
                              : Icons.queue_music_rounded,
                          color: const Color(0xFF31C27C),
                          size: 30,
                        ),
                      )
                    : ArtworkImage(
                        imageUrl: item.imageUrl,
                        cacheWidth: 70,
                        cacheHeight: 70,
                        fadeIn: false,
                        filterQuality: FilterQuality.low,
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0x3331C27C),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      _badge,
                      style: const TextStyle(
                        color: Color(0xFF8DE5B9),
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected ? Colors.white : const Color(0xEEFFFFFF),
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0x88FFFFFF),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: selected
                  ? const Color(0xFF31C27C)
                  : const Color(0x55FFFFFF),
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}
