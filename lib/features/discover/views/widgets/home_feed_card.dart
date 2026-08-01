import 'package:flutter/material.dart';

import 'package:qqmusic_ipod/business/entities/music.dart';
import 'package:qqmusic_ipod/core/theme/tokens/app_tokens.dart';
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
    return Semantics(
      button: true,
      selected: selected,
      label: [
        item.title,
        if (item.subtitle.isNotEmpty) item.subtitle,
        _badge,
      ].join('，'),
      onTap: onSelect,
      child: GestureDetector(
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
            color: selected
                ? AppColors.brandQq.withValues(alpha: .15)
                : AppColors.glassLow,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected
                  ? AppColors.brandQq.withValues(alpha: .5)
                  : AppColors.border,
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
                            color: AppColors.brandQq,
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
                        color: AppColors.brandQq.withValues(alpha: .2),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        _badge,
                        style: AppTextStyles.micro.copyWith(
                          color: AppColors.brandQq.withValues(alpha: .8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.label.copyWith(
                        color: selected
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.micro.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: selected ? AppColors.brandQq : AppColors.textMuted,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
