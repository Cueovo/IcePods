import 'package:qqmusic_ipod/data/datasources/direct_client.dart';
import 'package:qqmusic_ipod/business/entities/auth.dart';
import 'package:qqmusic_ipod/business/entities/music.dart';
import 'package:qqmusic_ipod/data/models/request.dart';

class QqMusicCatalogModule {
  const QqMusicCatalogModule(this.client);

  final QqMusicDirectClient client;

  Future<Map<String, dynamic>> loadFeature(
    QqMusicFeature feature, {
    required int page,
    required int pageSize,
    QqMusicCredential? credential,
  }) {
    final request = switch (feature) {
      QqMusicFeature.charts => const QqMusicCgiRequest(
        module: 'music.musicToplist.Toplist',
        method: 'GetAll',
      ),
      QqMusicFeature.singers => QqMusicCgiRequest(
        module: 'music.musichallSinger.SingerList',
        method: 'GetSingerListIndex',
        param: {
          'area': -100,
          'sex': -100,
          'genre': -100,
          'index': -100,
          'sin': (page - 1) * pageSize,
          'cur_page': page,
        },
      ),
      _ => throw ArgumentError.value(feature, 'feature'),
    };
    return client
        .request(
          request,
          credential: credential,
          platform: QqMusicRequestPlatform.android,
        )
        .then((data) => _normalizeFeature(feature, data));
  }

  Future<Map<String, dynamic>> loadChildren(
    QqMusicItem item, {
    required int page,
    required int pageSize,
    QqMusicCredential? credential,
  }) {
    final request = switch (item.type) {
      QqMusicItemType.playlist => QqMusicCgiRequest(
        module: 'music.srfDissInfo.DissInfo',
        method: 'CgiGetDiss',
        param: {
          'disstid': int.tryParse(item.id) ?? 0,
          'dirid': int.tryParse(item.directoryId) ?? 0,
          'tag': true,
          'song_begin': pageSize * (page - 1),
          'song_num': pageSize,
          'userinfo': true,
          'orderlist': true,
          'onlysonglist': false,
        },
        preserveBool: true,
      ),
      QqMusicItemType.chart => QqMusicCgiRequest(
        module: 'music.musicToplist.Toplist',
        method: 'GetDetail',
        param: {
          'topId': int.tryParse(item.id) ?? 0,
          'offset': pageSize * (page - 1),
          'num': pageSize,
          'withTags': true,
        },
        preserveBool: true,
      ),
      QqMusicItemType.singer => QqMusicCgiRequest(
        module: 'musichall.song_list_server',
        method: 'GetSingerSongList',
        param: {
          'singerMid': item.mid,
          'order': 1,
          'number': pageSize,
          'begin': pageSize * (page - 1),
        },
      ),
      QqMusicItemType.album => QqMusicCgiRequest(
        module: 'music.musichallAlbum.AlbumSongList',
        method: 'GetAlbumSongList',
        param: {
          'begin': pageSize * (page - 1),
          'num': pageSize,
          if (item.mid.isNotEmpty)
            'albumMid': item.mid
          else
            'albumId': int.tryParse(item.id) ?? 0,
        },
      ),
      QqMusicItemType.song || QqMusicItemType.musicVideo =>
        throw ArgumentError.value(item.type, 'item.type'),
    };
    return client
        .request(
          request,
          credential: credential,
          platform: QqMusicRequestPlatform.android,
        )
        .then((data) => _normalizeChildren(item, data));
  }

  Map<String, dynamic> _normalizeFeature(
    QqMusicFeature feature,
    Map<String, dynamic> data,
  ) {
    return switch (feature) {
      QqMusicFeature.charts => {
        ...data,
        'group': [
          for (final value in _list(data['group'])) _normalizeChartGroup(value),
        ],
      },
      QqMusicFeature.singers => {
        ...data,
        'singerlist': [
          for (final value in _list(data['singerlist']))
            _normalizeSinger(value),
        ],
      },
      _ => data,
    };
  }

  Map<String, dynamic> _normalizeChildren(
    QqMusicItem item,
    Map<String, dynamic> data,
  ) {
    return switch (item.type) {
      QqMusicItemType.playlist => {
        ...data,
        'songs': data['songlist'],
        'total': data['total_song_num'],
      },
      QqMusicItemType.chart => {
        ...data,
        'songs': data['songInfoList'],
        'total': _map(data['data'])['totalNum'],
      },
      QqMusicItemType.singer || QqMusicItemType.album => {
        ...data,
        'songs': [
          for (final value in _list(data['songList']))
            _map(value)['songInfo'] ?? value,
        ],
        'total': data['totalNum'],
      },
      _ => data,
    };
  }

  Map<String, dynamic> _normalizeChartGroup(Object? value) {
    final group = _map(value);
    return {
      ...group,
      'toplist': [
        for (final raw in _list(group['toplist'])) _normalizeChart(raw),
      ],
    };
  }

  Map<String, dynamic> _normalizeChart(Object? value) {
    final chart = _map(value);
    return {
      ...chart,
      'id': chart['id'] ?? chart['topId'],
      'name': chart['name'] ?? chart['title'],
      'title_detail': chart['title_detail'] ?? chart['titleDetail'],
      'update_time': chart['update_time'] ?? chart['updateTime'],
      'front_pic_url': chart['front_pic_url'] ?? chart['frontPicUrl'],
      'head_pic_url': chart['head_pic_url'] ?? chart['headPicUrl'],
    };
  }

  Map<String, dynamic> _normalizeSinger(Object? value) {
    final singer = _map(value);
    return {
      ...singer,
      'id': singer['id'] ?? singer['singer_id'] ?? singer['singerId'],
      'mid': singer['mid'] ?? singer['singer_mid'] ?? singer['singerMid'],
      'name': singer['name'] ?? singer['singer_name'] ?? singer['singerName'],
      'pic': singer['pic'] ?? singer['singer_pic'] ?? singer['singerPic'],
    };
  }
}

Map<String, dynamic> _map(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : const {};

List<dynamic> _list(Object? value) => value is List ? value : const [];
