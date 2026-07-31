import 'package:flutter/material.dart';

import 'package:qqmusic_ipod/business/entities/music.dart';
import 'package:qqmusic_ipod/core/theme/tokens/app_tokens.dart';
import 'package:qqmusic_ipod/core/theme/widgets/artwork_image.dart';
import 'package:qqmusic_ipod/core/theme/widgets/ipod_scrollbar.dart';
import 'package:qqmusic_ipod/features/shell/views/widgets/feature_message_state.dart';

class PlaybackQueuePanel extends StatefulWidget {
  const PlaybackQueuePanel({
    required this.queue,
    required this.currentIndex,
    required this.selectedIndex,
    required this.isPlaying,
    this.playbackError = '',
    required this.onPlayIndex,
    required this.onRemoveIndex,
    required this.onClearUpcoming,
    super.key,
  });

  final List<QqMusicItem> queue;
  final int currentIndex;
  final int selectedIndex;
  final bool isPlaying;
  final String playbackError;
  final ValueChanged<int> onPlayIndex;
  final ValueChanged<int> onRemoveIndex;
  final VoidCallback onClearUpcoming;

  @override
  State<PlaybackQueuePanel> createState() => _PlaybackQueuePanelState();
}

class _PlaybackQueuePanelState extends State<PlaybackQueuePanel> {
  static const _itemExtent = 52.0;
  static const _itemGap = 6.0;
  static const _rowExtent = _itemExtent + _itemGap;
  static const _listBottomPadding = 4.0;

  final ScrollController _scrollController = ScrollController();
  bool _selectionScrollScheduled = false;

  @override
  void initState() {
    super.initState();
    _scheduleScrollToSelection();
  }

  @override
  void didUpdateWidget(PlaybackQueuePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex ||
        oldWidget.queue.length != widget.queue.length) {
      _scheduleScrollToSelection();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scheduleScrollToSelection() {
    if (_selectionScrollScheduled) {
      return;
    }
    _selectionScrollScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _selectionScrollScheduled = false;
      if (!mounted || !_scrollController.hasClients || widget.queue.isEmpty) {
        return;
      }
      final position = _scrollController.position;
      final selected = widget.selectedIndex.clamp(0, widget.queue.length - 1);
      final target =
          (selected * _rowExtent +
                  _itemExtent / 2 -
                  position.viewportDimension / 2)
              .clamp(0.0, position.maxScrollExtent)
              .toDouble();
      final distance = (position.pixels - target).abs();
      if (distance < .5) {
        return;
      }
      final reduceMotion =
          MediaQuery.maybeOf(context)?.disableAnimations ?? false;
      if (reduceMotion) {
        _scrollController.jumpTo(target);
        return;
      }
      _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final canClear =
        widget.queue.length > 1 ||
        (widget.queue.isNotEmpty && widget.currentIndex < 0);
    final currentPosition = widget.currentIndex >= 0
        ? widget.currentIndex + 1
        : null;
    return Semantics(
      label: '播放队列',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              key: const ValueKey('playback-queue-header'),
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.interaction, AppColors.canvas],
                    ),
                    borderRadius: BorderRadius.circular(AppRadii.artwork),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x28000000),
                        blurRadius: 12,
                        offset: Offset(0, 5),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.queue_music_rounded,
                    size: 24,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '播放队列',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.title.copyWith(fontSize: 19),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.queue.isEmpty
                            ? '暂时没有待播放歌曲'
                            : currentPosition == null
                            ? '${widget.queue.length} 首歌曲'
                            : '${widget.queue.length} 首歌曲 · 当前第 $currentPosition 首',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.metadata,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  key: const ValueKey('queue-clear-upcoming'),
                  tooltip: '清空待播',
                  onPressed: canClear ? widget.onClearUpcoming : null,
                  constraints: const BoxConstraints.tightFor(
                    width: 44,
                    height: 44,
                  ),
                  icon: Icon(
                    Icons.playlist_remove_rounded,
                    color: canClear
                        ? AppColors.textSecondary
                        : AppColors.textMuted.withValues(alpha: .35),
                    size: 22,
                  ),
                ),
              ],
            ),
            if (widget.playbackError.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                key: const ValueKey('queue-playback-error'),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: .15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.danger.withValues(alpha: .4),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.lock_outline_rounded,
                      color: AppColors.danger,
                      size: 16,
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        widget.playbackError,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.micro.copyWith(
                          color: AppColors.danger,
                          fontWeight: AppTextStyles.strong,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 10),
            Expanded(
              child: widget.queue.isEmpty
                  ? const FeatureMessageState(
                      icon: Icons.queue_music_rounded,
                      title: '队列为空',
                      subtitle: '从音乐库选择歌曲后会显示在这里。',
                    )
                  : RepaintBoundary(
                      child: IpodScrollbar(
                        controller: _scrollController,
                        child: ListView.builder(
                          key: const ValueKey('playback-queue-list'),
                          controller: _scrollController,
                          itemExtent: _rowExtent,
                          padding: const EdgeInsets.only(
                            bottom: _listBottomPadding,
                          ),
                          clipBehavior: Clip.hardEdge,
                          physics: const ClampingScrollPhysics(),
                          itemCount: widget.queue.length,
                          itemBuilder: (context, index) {
                            final item = widget.queue[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: _itemGap),
                              child: _PlaybackQueueTile(
                                key: ValueKey('queue-item-$index-${item.id}'),
                                index: index,
                                item: item,
                                selected: index == widget.selectedIndex,
                                current: index == widget.currentIndex,
                                isPlaying: widget.isPlaying,
                                onTap: () => widget.onPlayIndex(index),
                                onRemove: index == widget.currentIndex
                                    ? null
                                    : () => widget.onRemoveIndex(index),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaybackQueueTile extends StatelessWidget {
  const _PlaybackQueueTile({
    required this.index,
    required this.item,
    required this.selected,
    required this.current,
    required this.isPlaying,
    required this.onTap,
    required this.onRemove,
    super.key,
  });

  final int index;
  final QqMusicItem item;
  final bool selected;
  final bool current;
  final bool isPlaying;
  final VoidCallback onTap;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final textColor = current
        ? AppColors.interaction
        : selected
        ? AppColors.textPrimary
        : AppColors.textSecondary;
    final stateLabel = current
        ? (isPlaying ? '正在播放' : '当前歌曲')
        : '队列第 ${index + 1} 首';
    return Semantics(
      button: true,
      selected: selected,
      label:
          '${item.title}，${item.subtitle}，${item.requiresVip ? 'VIP 歌曲，' : ''}$stateLabel',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadii.tile),
          child: AnimatedContainer(
            duration: reduceMotion
                ? AppDurations.reducedMotion
                : AppDurations.quick,
            curve: AppCurves.standard,
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: current
                  ? AppColors.interactionSoft
                  : selected
                  ? AppColors.surfaceSelected
                  : AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadii.tile),
              border: Border.all(
                color: current
                    ? AppColors.interactionBorder
                    : selected
                    ? AppColors.interactionSoft
                    : Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(9),
                  child: SizedBox.square(
                    key: ValueKey('queue-artwork-$index-${item.id}'),
                    dimension: 38,
                    child: item.imageUrl.isEmpty
                        ? const ColoredBox(
                            color: Color(0xFF303037),
                            child: Icon(
                              Icons.music_note_rounded,
                              color: AppColors.textSecondary,
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
                              style: AppTextStyles.body.copyWith(
                                color: textColor,
                                fontWeight: current || selected
                                    ? AppTextStyles.strong
                                    : AppTextStyles.regular,
                              ),
                            ),
                          ),
                          if (item.isSong && item.requiresVip) ...[
                            const SizedBox(width: 5),
                            Container(
                              key: ValueKey(
                                'queue-vip-badge-$index-${item.id}',
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.vip.withValues(alpha: .15),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: AppColors.vip.withValues(alpha: .75),
                                  width: .7,
                                ),
                              ),
                              child: const Text(
                                'VIP',
                                style: TextStyle(
                                  color: AppColors.vip,
                                  fontSize: 8,
                                  fontWeight: AppTextStyles.strong,
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
                          style: AppTextStyles.metadata.copyWith(
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (current)
                  Icon(
                    isPlaying
                        ? Icons.graphic_eq_rounded
                        : Icons.pause_circle_filled_rounded,
                    color: AppColors.interaction,
                    size: 20,
                  )
                else if (onRemove != null)
                  Semantics(
                    button: true,
                    label: '从队列移除 ${item.title}',
                    child: IconButton(
                      key: ValueKey('queue-remove-$index-${item.id}'),
                      tooltip: '从队列移除',
                      onPressed: onRemove,
                      constraints: const BoxConstraints.tightFor(
                        width: 40,
                        height: 40,
                      ),
                      padding: EdgeInsets.zero,
                      splashRadius: 18,
                      icon: Icon(
                        Icons.close_rounded,
                        color: selected
                            ? AppColors.interaction
                            : AppColors.textMuted,
                        size: 18,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
