import 'package:flutter/material.dart';

import 'package:qqmusic_ipod/core/theme/tokens/app_tokens.dart';
import 'package:qqmusic_ipod/features/shell/models/ipod_models.dart';
import 'package:qqmusic_ipod/features/shell/views/widgets/menu_artwork.dart';

class FeatureHeader extends StatelessWidget {
  const FeatureHeader({
    required this.entry,
    required this.title,
    required this.isLoading,
    required this.cacheLabel,
    required this.onRefresh,
    super.key,
  });

  final MenuEntry entry;
  final String title;
  final bool isLoading;
  final String? cacheLabel;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox.square(
            dimension: 48,
            child: MenuArtwork(entry: entry, compact: true),
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.title.copyWith(fontSize: 19),
              ),
              if (cacheLabel != null) ...[
                const SizedBox(height: 2),
                Text(
                  cacheLabel!,
                  key: const ValueKey('feature-cache-time'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.metadata,
                ),
              ],
            ],
          ),
        ),
        IconButton(
          key: const ValueKey('api-refresh'),
          tooltip: '刷新',
          onPressed: isLoading ? null : onRefresh,
          icon: isLoading
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF31C27C),
                  ),
                )
              : const Icon(
                  Icons.refresh_rounded,
                  color: Color(0xBFFFFFFF),
                  size: 22,
                ),
        ),
      ],
    );
  }
}
