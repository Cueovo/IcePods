import 'package:qqmusic_ipod/data/datasources/direct_client.dart';
import 'package:qqmusic_ipod/business/entities/auth.dart';
import 'package:qqmusic_ipod/business/entities/music.dart';
import 'package:qqmusic_ipod/data/models/request.dart';

class QqMusicUserModule {
  const QqMusicUserModule(this.client);

  final QqMusicDirectClient client;

  Future<Map<String, dynamic>> homepage(QqMusicCredential credential) {
    return client.request(
      QqMusicCgiRequest(
        module: 'music.UnifiedHomepage.UnifiedHomepageSrv',
        method: 'GetHomepageHeader',
        param: {'uin': _encryptedUin(credential), 'IsQueryTabDetail': 1},
      ),
      credential: credential,
      platform: QqMusicRequestPlatform.android,
    );
  }

  Future<Map<String, dynamic>> vipInfo(QqMusicCredential credential) {
    return client.request(
      const QqMusicCgiRequest(
        module: 'VipLogin.VipLoginInter',
        method: 'vip_login_base',
      ),
      credential: credential,
      platform: QqMusicRequestPlatform.android,
    );
  }

  Future<Map<String, dynamic>> loadFeature(
    QqMusicFeature feature, {
    required int page,
    required int pageSize,
    required QqMusicCredential credential,
  }) async {
    if (feature == QqMusicFeature.dislikes) {
      return _loadDislikes(page, credential);
    }
    final euin = _encryptedUin(credential);
    final request = switch (feature) {
      QqMusicFeature.likedSongs => QqMusicCgiRequest(
        module: 'music.srfDissInfo.DissInfo',
        method: 'CgiGetDiss',
        param: {
          'disstid': 0,
          'dirid': 201,
          'tag': true,
          'song_begin': pageSize * (page - 1),
          'song_num': pageSize,
          'userinfo': true,
          'orderlist': true,
          'enc_host_uin': euin,
        },
      ),
      QqMusicFeature.favoriteAlbums => QqMusicCgiRequest(
        module: 'music.musicasset.AlbumFavRead',
        method: 'CgiGetAlbumFavInfo',
        param: {
          'euin': euin,
          'offset': pageSize * (page - 1),
          'size': pageSize,
        },
      ),
      QqMusicFeature.favoriteMusicVideos => QqMusicCgiRequest(
        module: 'music.musicasset.MVFavRead',
        method: 'getMyFavMV_v2',
        param: {'encuin': euin, 'pagesize': pageSize, 'num': page - 1},
      ),
      QqMusicFeature.favoriteSingers => QqMusicCgiRequest(
        module: 'music.concern.RelationList',
        method: 'GetFollowSingerList',
        param: {
          'HostUin': euin,
          'From': pageSize * (page - 1),
          'Size': pageSize,
        },
      ),
      QqMusicFeature.createdPlaylists => QqMusicCgiRequest(
        module: 'music.musicasset.PlaylistBaseRead',
        method: 'GetPlaylistByUin',
        param: {'uin': credential.musicId},
      ),
      QqMusicFeature.collectedPlaylists => QqMusicCgiRequest(
        module: 'music.musicasset.PlaylistFavRead',
        method: 'CgiGetPlaylistFavInfo',
        param: {'uin': euin, 'offset': pageSize * (page - 1), 'size': pageSize},
      ),
      _ => throw ArgumentError.value(feature, 'feature'),
    };
    final data = await client.request(
      request,
      credential: credential,
      platform: QqMusicRequestPlatform.android,
    );
    return _normalize(feature, data);
  }

  Future<Map<String, dynamic>> _loadDislikes(
    int page,
    QqMusicCredential credential,
  ) async {
    final responses = await client.requestBatch(
      [
        QqMusicCgiRequest(
          module: 'music.feedback.FeedbackBlack',
          method: 'GetDislikeList',
          param: {'Cmd': 3, 'Page': page},
        ),
        QqMusicCgiRequest(
          module: 'music.feedback.FeedbackBlack',
          method: 'GetDislikeList',
          param: {'Cmd': 2, 'Page': page},
        ),
      ],
      credential: credential,
      platform: QqMusicRequestPlatform.android,
      sign: true,
    );
    final songs = _map(responses[0]['data']);
    final singers = _map(responses[1]['data']);
    return {
      'songs': [
        for (final value in _list(songs['Songs'])) _normalizeDislike(value),
      ],
      'singers': [
        for (final value in _list(singers['Singers'])) _normalizeDislike(value),
      ],
      'msg': _string(songs['Msg']).isNotEmpty ? songs['Msg'] : singers['Msg'],
    };
  }

  Future<void> setDislike(
    QqMusicItem item, {
    required bool disliked,
    required QqMusicCredential credential,
  }) async {
    final idType = switch (item.type) {
      QqMusicItemType.song => 1,
      QqMusicItemType.singer => 2,
      _ => throw ArgumentError.value(item.type, 'item.type'),
    };
    final key = idType == 1 ? 'Songs' : 'Singers';
    final data = await client.request(
      QqMusicCgiRequest(
        module: 'music.feedback.FeedbackBlack',
        method: disliked ? 'AddDislike' : 'CancelDislike',
        param: {
          key: [
            {'ID': item.id, 'IdType': idType},
          ],
        },
      ),
      credential: credential,
      platform: QqMusicRequestPlatform.android,
    );
    if (_int(data['Retcode']) != 0) {
      throw StateError(
        _string(data['Msg']).isEmpty ? '不喜欢操作失败' : _string(data['Msg']),
      );
    }
  }

  Map<String, dynamic> _normalize(
    QqMusicFeature feature,
    Map<String, dynamic> data,
  ) {
    return switch (feature) {
      QqMusicFeature.likedSongs => {
        ...data,
        'songs': data['songlist'],
        'size': data['songlist_size'],
        'total': data['total_song_num'],
      },
      QqMusicFeature.favoriteAlbums => {
        ...data,
        'albums': [
          for (final value in _list(data['v_list'])) _normalizeAlbum(value),
        ],
      },
      QqMusicFeature.favoriteMusicVideos => {
        ...data,
        'mv_list': [
          for (final value in _list(data['mvlist'])) _normalizeMv(value),
        ],
      },
      QqMusicFeature.favoriteSingers => {
        ...data,
        'users': [
          for (final value in _list(data['List'])) _normalizeRelation(value),
        ],
        'total': data['Total'],
        'has_more': data['HasMore'],
        'msg': data['Msg'],
      },
      QqMusicFeature.createdPlaylists => {
        ...data,
        'playlists': [
          for (final value in _list(data['v_playlist']))
            _normalizePlaylist(value),
        ],
      },
      QqMusicFeature.collectedPlaylists => {
        ...data,
        'playlists': [
          for (final value in _list(data['v_list'])) _normalizePlaylist(value),
        ],
      },
      _ => data,
    };
  }

  Map<String, dynamic> _normalizeAlbum(Object? value) {
    final album = _map(value);
    return {
      ...album,
      'id': album['id'] ?? album['albumID'],
      'mid': album['mid'] ?? album['albumMid'],
      'title': album['title'] ?? album['name'] ?? album['albumName'],
      'pic': album['pic'] ?? album['logo'],
      'singers': album['singers'] ?? album['v_singer'] ?? const [],
    };
  }

  Map<String, dynamic> _normalizeMv(Object? value) {
    final mv = _map(value);
    return {
      ...mv,
      'id': mv['id'] ?? mv['mvid'],
      'title': mv['title'] ?? mv['name'] ?? mv['mvname'],
      'picurl': mv['picurl'] ?? mv['picUrl'],
      'singer_name': mv['singer_name'] ?? mv['singerName'],
    };
  }

  Map<String, dynamic> _normalizeRelation(Object? value) {
    final user = _map(value);
    return {
      ...user,
      'mid': user['mid'] ?? user['MID'],
      'enc_uin': user['enc_uin'] ?? user['EncUin'],
      'name': user['name'] ?? user['Name'],
      'desc': user['desc'] ?? user['Desc'],
      'avatar_url': user['avatar_url'] ?? user['AvatarUrl'],
    };
  }

  Map<String, dynamic> _normalizePlaylist(Object? value) {
    final playlist = _map(value);
    return {
      ...playlist,
      'id': playlist['id'] ?? playlist['tid'],
      'dirid': playlist['dirid'] ?? playlist['dirId'],
      'title': playlist['title'] ?? playlist['name'] ?? playlist['dirName'],
      'nickname': playlist['nickname'] ?? playlist['nick'],
      'picurl':
          playlist['picurl'] ??
          playlist['bigpicUrl'] ??
          playlist['albumPicUrl'],
    };
  }

  Map<String, dynamic> _normalizeDislike(Object? value) {
    final item = _map(value);
    return {
      'id': item['id'] ?? item['ID'],
      'name': item['name'] ?? item['Name'],
      'img': item['img'] ?? item['Img'],
    };
  }

  String _encryptedUin(QqMusicCredential credential) =>
      credential.encryptUin.isNotEmpty
      ? credential.encryptUin
      : credential.musicId;
}

Map<String, dynamic> _map(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : const {};

List<dynamic> _list(Object? value) => value is List ? value : const [];

String _string(Object? value) => value?.toString() ?? '';

int _int(Object? value) =>
    value is num ? value.toInt() : int.tryParse('$value') ?? 0;
