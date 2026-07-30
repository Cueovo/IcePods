import 'package:qqmusic_ipod/data/datasources/direct_client.dart';
import 'package:qqmusic_ipod/business/entities/auth.dart';
import 'package:qqmusic_ipod/business/entities/music.dart';
import 'package:qqmusic_ipod/data/models/request.dart';

class QqMusicPlaylistModule {
  const QqMusicPlaylistModule(this.client);

  final QqMusicDirectClient client;

  Future<Map<String, dynamic>> create(
    String name,
    QqMusicCredential credential,
  ) {
    return client.request(
      QqMusicCgiRequest(
        module: 'music.musicasset.PlaylistBaseWrite',
        method: 'AddPlaylist',
        param: {'dirName': name},
      ),
      credential: credential,
      platform: QqMusicRequestPlatform.android,
    );
  }

  Future<void> delete(String directoryId, QqMusicCredential credential) async {
    final data = await client.request(
      QqMusicCgiRequest(
        module: 'music.musicasset.PlaylistBaseWrite',
        method: 'DelPlaylist',
        param: {'dirId': int.tryParse(directoryId) ?? 0},
      ),
      credential: credential,
      platform: QqMusicRequestPlatform.android,
    );
    _ensureSuccess(data, '删除歌单失败');
  }

  Future<void> mutateSongs(
    String directoryId,
    List<QqMusicItem> songs, {
    required bool add,
    required QqMusicCredential credential,
  }) async {
    final valid = songs
        .where((song) => song.isSong && int.tryParse(song.id) != null)
        .toList(growable: false);
    if (valid.isEmpty) {
      throw StateError('没有可操作的歌曲');
    }
    // Match working DelSonglist clients (dirid=201 for 我喜欢):
    // param = { dirId, v_songInfo: [{ songId, songType: 0 }] }
    // No tid / bFmtUtf8; songType is fixed 0 for song rows.
    final data = await client.request(
      QqMusicCgiRequest(
        module: 'music.musicasset.PlaylistDetailWrite',
        method: add ? 'AddSonglist' : 'DelSonglist',
        param: {
          'dirId': int.tryParse(directoryId) ?? 0,
          'v_songInfo': [
            for (final song in valid)
              {'songId': int.parse(song.id), 'songType': 0},
          ],
        },
      ),
      credential: credential,
      comm: {
        'ct': '11',
        'cv': 13020508,
        'v': 13020508,
        'tmeAppID': 'qqmusic',
        'uid': credential.musicId,
        'qq': credential.musicId,
        'authst': credential.musicKey,
        'tmeLoginType': '${credential.effectiveLoginType}',
        'loginUin': credential.musicId,
      },
      platform: QqMusicRequestPlatform.web,
    );
    _ensureSuccess(data, add ? '添加歌曲失败' : '移除歌曲失败');
  }

  Future<void> setFavorite(
    String playlistId, {
    required bool favorite,
    required QqMusicCredential credential,
  }) async {
    final id = int.tryParse(playlistId);
    if (id == null) {
      throw StateError('歌单 ID 无效');
    }
    final data = await client.request(
      QqMusicCgiRequest(
        module: 'music.musicasset.PlaylistFavWrite',
        method: favorite ? 'FavPlaylist' : 'CancelFavPlaylist',
        param: {
          'uin': credential.encryptUin.isNotEmpty
              ? credential.encryptUin
              : credential.musicId,
          'v_playlistId': [id],
        },
      ),
      credential: credential,
      platform: QqMusicRequestPlatform.android,
    );
    final failed = _list(
      data['v_failedPlaylistId'],
    ).map((value) => int.tryParse('$value')).whereType<int>();
    if (_int(data['result']) != 0 || failed.contains(id)) {
      throw StateError(favorite ? '收藏歌单失败' : '取消收藏歌单失败');
    }
  }

  void _ensureSuccess(Map<String, dynamic> data, String message) {
    final code = data.containsKey('retCode')
        ? _int(data['retCode'])
        : _int(data['result']);
    if (code != 0) {
      throw StateError(message);
    }
  }
}

List<dynamic> _list(Object? value) => value is List ? value : const [];

int _int(Object? value) =>
    value is num ? value.toInt() : int.tryParse('$value') ?? 0;
