import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../ipod_models.dart';
import '../services/qq_music_controller.dart';
import '../services/qq_music_models.dart';
import '../ui_tokens.dart';
import 'artwork_image.dart';
import 'menu_artwork.dart';

class FeaturePanel extends StatefulWidget {
  const FeaturePanel({
    required this.entry,
    required this.controller,
    super.key,
  });

  final MenuEntry entry;
  final QqMusicController controller;

  @override
  State<FeaturePanel> createState() => _FeaturePanelState();
}

class _FeaturePanelState extends State<FeaturePanel> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _listController = ScrollController();
  late int _lastSelectedIndex;
  bool _selectionRevealScheduled = false;

  @override
  void initState() {
    super.initState();
    _lastSelectedIndex = widget.controller.selectedIndex;
    widget.controller.addListener(_handleChange);
  }

  @override
  void didUpdateWidget(FeaturePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleChange);
      widget.controller.addListener(_handleChange);
    }
    _lastSelectedIndex = widget.controller.selectedIndex;
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleChange);
    _searchController.dispose();
    _listController.dispose();
    super.dispose();
  }

  void _handleChange() {
    if (!mounted) {
      return;
    }
    final selectedIndex = widget.controller.selectedIndex;
    final selectionChanged = selectedIndex != _lastSelectedIndex;
    _lastSelectedIndex = selectedIndex;
    setState(() {});
    if (selectionChanged && !_selectionRevealScheduled) {
      _selectionRevealScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        _selectionRevealScheduled = false;
        _revealSelection();
      });
    }
  }

  void _revealSelection() {
    if (!_listController.hasClients) {
      return;
    }
    final position = _listController.position;
    final isHomeFeedRoot =
        widget.entry.feature == QqMusicFeature.homeFeed &&
        widget.controller.currentContainer == null;
    final itemExtent = isHomeFeedRoot ? 94.0 : 58.0;
    final itemVisualExtent = isHomeFeedRoot ? 86.0 : 52.0;
    final viewportTop = position.pixels;
    final target =
        (widget.controller.selectedIndex * itemExtent +
                itemVisualExtent / 2 -
                position.viewportDimension / 2)
            .clamp(0.0, position.maxScrollExtent)
            .toDouble();
    if ((target - viewportTop).abs() < .5) {
      return;
    }
    _listController.animateTo(
      target,
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final feature = widget.entry.feature;
    if (feature == QqMusicFeature.account) {
      return _AccountView(controller: widget.controller);
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _FeatureHeader(
            entry: widget.entry,
            title: widget.controller.result?.title ?? widget.entry.title,
            isLoading: widget.controller.isLoading,
            cacheLabel: _cacheLabel(widget.controller.result),
            onRefresh: widget.controller.refresh,
          ),
          if (feature == QqMusicFeature.search) ...[
            const SizedBox(height: 10),
            _SearchBar(
              controller: _searchController,
              onSearch: widget.controller.search,
            ),
          ],
          if (widget.controller.isCreatedPlaylistsRoot ||
              widget.controller.isInsideCreatedPlaylist) ...[
            const SizedBox(height: 8),
            _PlaylistActions(
              controller: widget.controller,
              onCreate: _promptCreatePlaylist,
            ),
          ],
          const SizedBox(height: 10),
          Expanded(child: _buildBody()),
          if (widget.controller.playbackError.isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(
              widget.controller.playbackError,
              key: const ValueKey('playback-error'),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFFFFA8A8),
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (widget.controller.statusMessage.isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(
              widget.controller.statusMessage,
              key: const ValueKey('api-action-status'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF8DE5B9),
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 6),
          const Text(
            '滚轮选择 · 中心键打开 · MENU 返回',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0x70FFFFFF),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String? _cacheLabel(QqMusicFeatureResult? result) {
    final updatedAt = result?.updatedAt;
    if (result?.isFromCache != true || updatedAt == null) {
      return null;
    }
    final age = DateTime.now().toUtc().difference(updatedAt.toUtc());
    if (age.inMinutes < 1) {
      return '缓存 · 刚刚更新';
    }
    if (age.inHours < 1) {
      return '缓存 · ${age.inMinutes} 分钟前更新';
    }
    if (age.inDays < 1) {
      return '缓存 · ${age.inHours} 小时前更新';
    }
    return '缓存 · ${age.inDays} 天前更新';
  }

  Future<void> _promptCreatePlaylist() async {
    var playlistName = '';
    final name = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('新建歌单'),
          content: TextField(
            key: const ValueKey('playlist-name-field'),
            autofocus: true,
            maxLength: 40,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(hintText: '歌单名称'),
            onChanged: (value) => playlistName = value,
            onSubmitted: (value) => Navigator.pop(context, value),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, playlistName),
              child: const Text('创建'),
            ),
          ],
        );
      },
    );
    if (name?.trim().isNotEmpty ?? false) {
      await widget.controller.createPlaylist(name!);
    }
  }

  Widget _buildBody() {
    final controller = widget.controller;
    if (controller.error.isNotEmpty) {
      return _MessageState(
        icon: Icons.cloud_off_rounded,
        title: controller.error,
        actionLabel: '重试',
        onAction: controller.refresh,
      );
    }
    if (controller.isLoading && controller.items.isEmpty) {
      return const _FeatureListSkeleton();
    }
    if (controller.items.isEmpty) {
      final isSearch = widget.entry.feature == QqMusicFeature.search;
      return _MessageState(
        icon: isSearch ? Icons.search_rounded : Icons.library_music_rounded,
        title: isSearch ? '输入关键词搜索 QQ 音乐' : '暂无内容',
        actionLabel: isSearch ? null : '刷新',
        onAction: isSearch ? null : controller.refresh,
      );
    }
    if (widget.entry.feature == QqMusicFeature.radar) {
      return _RadarStation(controller: controller);
    }
    if (widget.entry.feature == QqMusicFeature.homeFeed &&
        controller.currentContainer == null) {
      return ListView.builder(
        key: const ValueKey('home-feed-card-list'),
        controller: _listController,
        padding: EdgeInsets.zero,
        itemExtent: 94,
        itemCount: controller.items.length,
        itemBuilder: (context, index) {
          final item = controller.items[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _HomeFeedCard(
              item: item,
              selected: index == controller.selectedIndex,
              onSelect: () => controller.selectIndex(index),
            ),
          );
        },
      );
    }
    return ListView.builder(
      key: const ValueKey('api-feature-list'),
      controller: _listController,
      padding: EdgeInsets.zero,
      itemExtent: 58,
      itemCount: controller.items.length,
      itemBuilder: (context, index) {
        final item = controller.items[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: _MediaTile(
            item: item,
            selected: index == controller.selectedIndex,
            current: controller.isCurrentSong(item),
            playing: controller.isCurrentSong(item) && controller.isPlaying,
            marked: controller.isMarked(item),
            unavailable: controller.isUnavailable(item),
            canToggleMark: controller.canToggleMark(item),
            onSelect: () => controller.selectIndex(index),
            onToggleMark: () => controller.toggleMark(item),
          ),
        );
      },
    );
  }
}

class _HomeFeedCard extends StatelessWidget {
  const _HomeFeedCard({
    required this.item,
    required this.selected,
    required this.onSelect,
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

class _RadarStation extends StatelessWidget {
  const _RadarStation({required this.controller});

  final QqMusicController controller;

  @override
  Widget build(BuildContext context) {
    final item = controller.selectedItem;
    if (item == null) {
      return const SizedBox.shrink();
    }
    final index = controller.selectedIndex + 1;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 310),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              key: const ValueKey('radar-station-card'),
              width: 210,
              height: 210,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const RadialGradient(
                  colors: [
                    Color(0xFF3FDB91),
                    Color(0xFF163A2C),
                    Color(0xFF080B0D),
                  ],
                  stops: [0, .58, 1],
                ),
                border: Border.all(color: const Color(0x8031C27C), width: 2),
                boxShadow: const [
                  BoxShadow(color: Color(0x6031C27C), blurRadius: 36),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: ClipOval(
                  child: item.imageUrl.isEmpty
                      ? const ColoredBox(
                          color: Color(0xFF18231E),
                          child: Icon(
                            Icons.radar_rounded,
                            color: Color(0xFF31C27C),
                            size: 76,
                          ),
                        )
                      : ArtworkImage(
                          imageUrl: item.imageUrl,
                          cacheWidth: 174,
                          cacheHeight: 174,
                        ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              item.title,
              key: const ValueKey('radar-current-title'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 21,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              item.subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0x99FFFFFF), fontSize: 12),
            ),
            const SizedBox(height: 12),
            Text(
              controller.result?.hasMore == true
                  ? '频道 $index/${controller.items.length}+  ·  滚轮换台  ·  接近末尾自动续播'
                  : '频道 $index/${controller.items.length}  ·  滚轮换台  ·  中心键播放',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xB331C27C),
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaylistActions extends StatelessWidget {
  const _PlaylistActions({required this.controller, required this.onCreate});

  final QqMusicController controller;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    if (controller.isInsideCreatedPlaylist) {
      return Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton.icon(
          key: const ValueKey('remove-song-from-playlist'),
          onPressed:
              controller.selectedItem?.isSong == true && !controller.isLoading
              ? controller.removeSelectedSongFromCurrentPlaylist
              : null,
          icon: const Icon(Icons.playlist_remove_rounded, size: 16),
          label: const Text('移除选中歌曲'),
        ),
      );
    }
    final selectedPlaylist =
        controller.selectedItem?.type == QqMusicItemType.playlist;
    return Wrap(
      spacing: 7,
      runSpacing: 5,
      children: [
        OutlinedButton.icon(
          key: const ValueKey('create-playlist'),
          onPressed: controller.isLoading ? null : onCreate,
          icon: const Icon(Icons.playlist_add_rounded, size: 16),
          label: const Text('新建'),
        ),
        OutlinedButton.icon(
          key: const ValueKey('add-current-song-to-playlist'),
          onPressed:
              selectedPlaylist &&
                  controller.currentSong != null &&
                  !controller.isLoading
              ? controller.addCurrentSongToSelectedPlaylist
              : null,
          icon: const Icon(Icons.add_rounded, size: 16),
          label: const Text('加入当前歌曲'),
        ),
        OutlinedButton.icon(
          key: const ValueKey('delete-playlist'),
          onPressed: selectedPlaylist && !controller.isLoading
              ? controller.deleteSelectedPlaylist
              : null,
          icon: const Icon(Icons.delete_outline_rounded, size: 16),
          label: const Text('删除'),
        ),
      ],
    );
  }
}

class _FeatureListSkeleton extends StatefulWidget {
  const _FeatureListSkeleton();

  @override
  State<_FeatureListSkeleton> createState() => _FeatureListSkeletonState();
}

class _FeatureListSkeletonState extends State<_FeatureListSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return ShaderMask(
          key: const ValueKey('feature-list-skeleton'),
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) => LinearGradient(
            begin: Alignment(-1.8 + _animation.value * 3.6, 0),
            end: Alignment(-.8 + _animation.value * 3.6, 0),
            colors: const [
              AppColors.skeletonBase,
              AppColors.skeletonHighlight,
              AppColors.skeletonBase,
            ],
          ).createShader(bounds),
          child: child,
        );
      },
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 6,
        separatorBuilder: (context, index) => const SizedBox(height: 6),
        itemBuilder: (context, index) {
          return Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadii.tile),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.skeletonBase,
                    borderRadius: BorderRadius.circular(9),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FractionallySizedBox(
                        widthFactor: index.isEven ? .62 : .76,
                        child: Container(
                          height: 10,
                          decoration: BoxDecoration(
                            color: AppColors.skeletonBase,
                            borderRadius: BorderRadius.circular(AppRadii.pill),
                          ),
                        ),
                      ),
                      const SizedBox(height: 7),
                      FractionallySizedBox(
                        widthFactor: index.isEven ? .38 : .48,
                        child: Container(
                          height: 7,
                          decoration: BoxDecoration(
                            color: AppColors.skeletonBase,
                            borderRadius: BorderRadius.circular(AppRadii.pill),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _FeatureHeader extends StatelessWidget {
  const _FeatureHeader({
    required this.entry,
    required this.title,
    required this.isLoading,
    required this.cacheLabel,
    required this.onRefresh,
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

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.controller, required this.onSearch});

  final TextEditingController controller;
  final ValueChanged<String> onSearch;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: TextField(
        key: const ValueKey('qqmusic-search-field'),
        controller: controller,
        textInputAction: TextInputAction.search,
        onSubmitted: onSearch,
        style: const TextStyle(color: Colors.white, fontSize: 13),
        decoration: InputDecoration(
          hintText: '歌曲、歌手、专辑、歌单、MV',
          hintStyle: const TextStyle(color: Color(0x66FFFFFF)),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: Color(0x99FFFFFF),
            size: 19,
          ),
          suffixIcon: IconButton(
            tooltip: '搜索',
            onPressed: () => onSearch(controller.text),
            icon: const Icon(
              Icons.arrow_forward_rounded,
              color: Color(0xFF31C27C),
              size: 19,
            ),
          ),
          filled: true,
          fillColor: const Color(0x1AFFFFFF),
          contentPadding: EdgeInsets.zero,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}

class _MediaTile extends StatelessWidget {
  const _MediaTile({
    required this.item,
    required this.selected,
    required this.current,
    required this.playing,
    required this.marked,
    required this.unavailable,
    required this.canToggleMark,
    required this.onSelect,
    required this.onToggleMark,
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
                      ] else if (item.isSong && unavailable) ...[
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
                tooltip: item.type == QqMusicItemType.playlist
                    ? marked
                          ? '取消收藏歌单'
                          : '收藏歌单'
                    : marked
                    ? '取消不喜欢'
                    : '不喜欢',
                onPressed: onToggleMark,
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  item.type == QqMusicItemType.playlist
                      ? marked
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded
                      : marked
                      ? Icons.thumb_down_rounded
                      : Icons.thumb_down_outlined,
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

class _AccountView extends StatelessWidget {
  const _AccountView({required this.controller});

  final QqMusicController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'QQ账号',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(child: _accountBody()),
          const SizedBox(height: 8),
          const Text(
            '按 MENU 返回',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0x70FFFFFF), fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _accountBody() {
    if (controller.error.isNotEmpty) {
      return _MessageState(
        icon: Icons.error_outline_rounded,
        title: controller.error,
        actionLabel: '重新获取二维码',
        onAction: controller.startQrLogin,
      );
    }
    final profile = controller.profile;
    if (controller.isLoggedIn && profile != null) {
      return _ProfileCard(profile: profile, onLogout: controller.logout);
    }
    final qrCode = controller.qrCode;
    if (controller.isLoading || qrCode == null) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF31C27C)),
      );
    }
    final status = controller.qrStatus;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ChoiceChip(
              key: const ValueKey('qq-qr-login'),
              label: const Text('QQ 扫码'),
              selected: controller.qrLoginType == 'qq',
              onSelected: controller.isLoading
                  ? null
                  : (_) => controller.startQrLogin(loginType: 'qq'),
            ),
            const SizedBox(width: 8),
            ChoiceChip(
              key: const ValueKey('wx-qr-login'),
              label: const Text('微信扫码'),
              selected: controller.qrLoginType == 'wx',
              onSelected: controller.isLoading
                  ? null
                  : (_) => controller.startQrLogin(loginType: 'wx'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          key: const ValueKey('qqmusic-qr-code'),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Image.memory(
            Uint8List.fromList(qrCode.imageBytes),
            width: 142,
            height: 142,
            gaplessPlayback: true,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          status?.message ?? '等待扫码',
          key: const ValueKey('qqmusic-qr-status'),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          controller.qrLoginType == 'wx' ? '使用微信扫码并确认登录' : '使用手机 QQ 扫码并确认登录',
          style: const TextStyle(color: Color(0x80FFFFFF), fontSize: 11),
        ),
        if (status?.event == 3 || status?.event == 4) ...[
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () =>
                controller.startQrLogin(loginType: controller.qrLoginType),
            child: const Text('刷新二维码'),
          ),
        ],
      ],
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.profile, required this.onLogout});

  final QqMusicUserProfile profile;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 330),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0x1AFFFFFF),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0x26FFFFFF)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipOval(
              child: SizedBox.square(
                dimension: 82,
                child: profile.avatarUrl.isEmpty
                    ? const ColoredBox(
                        color: Color(0xFF303037),
                        child: Icon(Icons.person_rounded, size: 42),
                      )
                    : ArtworkImage(
                        imageUrl: profile.avatarUrl,
                        cacheWidth: 82,
                        cacheHeight: 82,
                      ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              profile.nickname,
              key: const ValueKey('qqmusic-profile-name'),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              profile.isVip == true
                  ? 'QQ音乐 VIP'
                  : profile.isVip == false
                  ? 'QQ音乐用户'
                  : '会员状态待确认',
              style: const TextStyle(
                color: Color(0xFF8DE5B9),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onLogout, child: const Text('退出登录')),
          ],
        ),
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.icon,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: const Color(0x80FFFFFF), size: 38),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xCCFFFFFF),
                fontSize: 13,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 12),
              OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
