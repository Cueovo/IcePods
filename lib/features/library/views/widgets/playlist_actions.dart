import 'package:flutter/material.dart';

import 'package:qqmusic_ipod/business/entities/music.dart';
import 'package:qqmusic_ipod/features/player/state/controller.dart';

class PlaylistActions extends StatelessWidget {
  const PlaylistActions({
    required this.controller,
    required this.onCreate,
    super.key,
  });

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
