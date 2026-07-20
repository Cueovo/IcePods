import 'package:qqmusic_ipod/data/datasources/direct_client.dart';
import 'package:qqmusic_ipod/business/entities/auth.dart';
import 'package:qqmusic_ipod/business/entities/music.dart';
import 'package:qqmusic_ipod/data/models/request.dart';

class QqMusicRecommendModule {
  const QqMusicRecommendModule(this.client);

  final QqMusicDirectClient client;

  Future<Map<String, dynamic>> load(
    QqMusicFeature feature, {
    required int page,
    required int pageSize,
    QqMusicCredential? credential,
  }) {
    final request = switch (feature) {
      QqMusicFeature.guessRecommendations => const QqMusicCgiRequest(
        module: 'music.radioProxy.MbTrackRadioSvr',
        method: 'get_radio_track',
        param: {'id': 99, 'num': 5, 'from': 0, 'scene': 0, 'song_ids': []},
      ),
      QqMusicFeature.homeFeed => QqMusicCgiRequest(
        module: 'music.recommend.RecommendFeed',
        method: 'get_recommend_feed',
        param: {'direction': 0, 'page': page, 's_num': (page - 1) * pageSize},
      ),
      QqMusicFeature.radar => QqMusicCgiRequest(
        module: 'music.recommend.TrackRelationServer',
        method: 'GetRadarSong',
        param: {
          'Page': page,
          'ReqType': 0,
          'FavSongs': const [],
          'EntranceSongs': const [],
        },
      ),
      QqMusicFeature.newSongs => const QqMusicCgiRequest(
        module: 'newsong.NewSongServer',
        method: 'get_new_song_info',
        param: {'type': 5},
      ),
      QqMusicFeature.recommendedPlaylists => QqMusicCgiRequest(
        module: 'music.playlist.PlaylistSquare',
        method: 'GetRecommendFeed',
        param: {'From': pageSize * (page - 1), 'Size': pageSize},
      ),
      _ => throw ArgumentError.value(feature, 'feature'),
    };
    return client
        .request(
          request,
          credential: credential,
          platform: QqMusicRequestPlatform.android,
        )
        .then((data) => _normalize(feature, data));
  }

  Map<String, dynamic> _normalize(
    QqMusicFeature feature,
    Map<String, dynamic> data,
  ) {
    return switch (feature) {
      QqMusicFeature.guessRecommendations => {
        ...data,
        'songs': data['songs'] ?? data['tracks'],
      },
      QqMusicFeature.homeFeed => {
        ...data,
        'shelves': [
          for (final value in _list(data['shelves'] ?? data['v_shelf']))
            _homeShelf(value),
        ],
      },
      QqMusicFeature.radar => {
        ...data,
        'songs': [
          for (final value in _list(data['VecSongs']))
            if (_map(value)['Track'] != null) _map(value)['Track'],
        ],
        'has_more': data['HasMore'],
      },
      QqMusicFeature.newSongs => {
        ...data,
        'songs': data['songs'] ?? data['songlist'],
      },
      QqMusicFeature.recommendedPlaylists => {
        ...data,
        'songlists': [
          for (final value in _list(data['List'])) _playlistBasic(value),
        ],
        'has_more': data['HasMore'],
        'msg': data['Msg'],
      },
      _ => data,
    };
  }

  Map<String, dynamic> _homeShelf(Object? value) {
    final shelf = _map(value);
    return {
      ...shelf,
      'niches': [
        for (final raw in _list(shelf['niches'] ?? shelf['v_niche']))
          _homeNiche(raw),
      ],
    };
  }

  Map<String, dynamic> _homeNiche(Object? value) {
    final niche = _map(value);
    return {...niche, 'cards': niche['cards'] ?? niche['v_card'] ?? const []};
  }

  Map<String, dynamic> _playlistBasic(Object? value) {
    final playlist = _map(_map(value)['Playlist']);
    final basic = _map(playlist['basic']);
    final cover = _map(playlist['cover']);
    final creator = _map(playlist['creator']);
    return {
      ...basic,
      'picurl': basic['picurl'] ?? cover['default_url'],
      'creator_nick': basic['creator_nick'] ?? creator['nick'],
    };
  }
}

Map<String, dynamic> _map(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : const {};

List<dynamic> _list(Object? value) => value is List ? value : const [];
