import 'package:flutter/material.dart';

import 'package:qqmusic_ipod/business/entities/music.dart';
import 'package:qqmusic_ipod/core/theme/widgets/ipod_scrollbar.dart';
import 'package:qqmusic_ipod/features/player/state/controller.dart';
import 'package:qqmusic_ipod/features/shell/models/ipod_models.dart';
import 'package:qqmusic_ipod/features/library/views/widgets/account/account_view.dart';
import 'package:qqmusic_ipod/features/shell/views/widgets/feature_header.dart';
import 'package:qqmusic_ipod/features/shell/views/widgets/feature_list_skeleton.dart';
import 'package:qqmusic_ipod/features/shell/views/widgets/feature_message_state.dart';
import 'package:qqmusic_ipod/features/search/views/widgets/search_bar.dart';
import 'package:qqmusic_ipod/features/discover/views/widgets/home_feed_card.dart';
import 'package:qqmusic_ipod/features/library/views/widgets/media_tile.dart';
import 'package:qqmusic_ipod/features/library/views/widgets/playlist_actions.dart';
import 'package:qqmusic_ipod/features/discover/views/widgets/radar_station.dart';

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
      return AccountView(controller: widget.controller);
    }
    // Match HomePanel top inset (0) so feature pages sit under the status
    // bar the same distance as the menu — not an extra 12pt lower.
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FeatureHeader(
            entry: widget.entry,
            title: widget.controller.result?.title ?? widget.entry.title,
            isLoading: widget.controller.isLoading,
            cacheLabel: _cacheLabel(widget.controller.result),
            onRefresh: widget.controller.refresh,
          ),
          if (feature == QqMusicFeature.search) ...[
            const SizedBox(height: 10),
            FeatureSearchBar(
              controller: _searchController,
              onSearch: widget.controller.search,
            ),
          ],
          if (widget.controller.isCreatedPlaylistsRoot ||
              widget.controller.isInsideCreatedPlaylist) ...[
            const SizedBox(height: 8),
            PlaylistActions(
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
      return '缓存  刚刚更新';
    }
    if (age.inHours < 1) {
      return '缓存  ${age.inMinutes} 分钟前更新';
    }
    if (age.inDays < 1) {
      return '缓存  ${age.inHours} 小时前更新';
    }
    return '缓存  ${age.inDays} 天前更新';
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
      return FeatureMessageState(
        icon: Icons.cloud_off_rounded,
        title: controller.error,
        actionLabel: '重试',
        onAction: controller.refresh,
      );
    }
    if (controller.isLoading && controller.items.isEmpty) {
      return const FeatureListSkeleton();
    }
    if (controller.items.isEmpty) {
      final isSearch = widget.entry.feature == QqMusicFeature.search;
      return FeatureMessageState(
        icon: isSearch ? Icons.search_rounded : Icons.library_music_rounded,
        title: isSearch ? '输入关键词搜索 QQ 音乐' : '暂无内容',
        actionLabel: isSearch ? null : '刷新',
        onAction: isSearch ? null : controller.refresh,
      );
    }
    if (widget.entry.feature == QqMusicFeature.radar) {
      return RadarStation(controller: controller);
    }
    if (widget.entry.feature == QqMusicFeature.homeFeed &&
        controller.currentContainer == null) {
      return IpodScrollbar(
        controller: _listController,
        child: ListView.builder(
          key: const ValueKey('home-feed-card-list'),
          controller: _listController,
          padding: const EdgeInsets.only(right: 8),
          itemExtent: 94,
          itemCount: controller.items.length,
          itemBuilder: (context, index) {
            final item = controller.items[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: HomeFeedCard(
                item: item,
                selected: index == controller.selectedIndex,
                onSelect: () => controller.selectIndex(index),
              ),
            );
          },
        ),
      );
    }
    return IpodScrollbar(
      controller: _listController,
      child: ListView.builder(
        key: const ValueKey('api-feature-list'),
        controller: _listController,
        padding: const EdgeInsets.only(right: 8),
        itemExtent: 58,
        itemCount: controller.items.length,
        itemBuilder: (context, index) {
          final item = controller.items[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: MediaTile(
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
      ),
    );
  }
}
