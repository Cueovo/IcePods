import 'package:qqmusic_ipod/business/repositories/music_repository.dart';
import 'package:qqmusic_ipod/data/datasources/direct_client.dart';
import 'package:qqmusic_ipod/business/entities/account.dart';
import 'package:qqmusic_ipod/data/models/api_exception.dart';
import 'package:qqmusic_ipod/business/entities/auth.dart';
import 'package:qqmusic_ipod/business/entities/music.dart';
import 'package:qqmusic_ipod/data/models/response_parser.dart';
import 'package:qqmusic_ipod/data/datasources/catalog.dart';
import 'package:qqmusic_ipod/data/datasources/login.dart';
import 'package:qqmusic_ipod/data/datasources/playlist.dart';
import 'package:qqmusic_ipod/data/datasources/recommend.dart';
import 'package:qqmusic_ipod/data/datasources/search.dart';
import 'package:qqmusic_ipod/data/datasources/song.dart';
import 'package:qqmusic_ipod/data/datasources/user.dart';

class QqMusicOfficialApi implements QqMusicApi {
  QqMusicOfficialApi({
    QqMusicDirectClient? client,
    QqMusicLoginModule? login,
    this.parser = const QqMusicResponseParser(),
  }) : _client = client ?? QqMusicDirectClient() {
    _login = login ?? QqMusicLoginModule(client: _client);
    _recommend = QqMusicRecommendModule(_client);
    _catalog = QqMusicCatalogModule(_client);
    _search = QqMusicSearchModule(_client);
    _song = QqMusicSongModule(_client);
    _user = QqMusicUserModule(_client);
    _playlist = QqMusicPlaylistModule(_client);
  }

  final QqMusicDirectClient _client;
  final QqMusicResponseParser parser;
  late final QqMusicLoginModule _login;
  late final QqMusicRecommendModule _recommend;
  late final QqMusicCatalogModule _catalog;
  late final QqMusicSearchModule _search;
  late final QqMusicSongModule _song;
  late final QqMusicUserModule _user;
  late final QqMusicPlaylistModule _playlist;

  @override
  QqMusicCredential? get credential => _login.credential;

  @override
  bool get isLoggedIn => _login.isLoggedIn;

  @override
  Future<void> restoreSession() => _login.restoreSession();

  @override
  Future<QqMusicQrCode> createQrCode({String loginType = 'qq'}) {
    return _runDirect(() => _login.createQrCode(loginType: loginType));
  }

  @override
  Future<QqMusicQrStatus> checkQrStatus(QqMusicQrCode qrCode) {
    return _runDirect(() => _login.checkQrStatus(qrCode));
  }

  @override
  Future<QqMusicCredential> refreshCredential() {
    return _runDirect(() => _login.refreshCredential(credential));
  }

  @override
  Future<void> logout() {
    return _runDirect(_login.logout);
  }

  @override
  Future<QqMusicUserProfile> getUserProfile() {
    return _runDirect(() async {
      final active = _requireCredential();
      final homepage = await _user.homepage(active);
      Map<String, dynamic>? vip;
      try {
        vip = await _user.vipInfo(active);
      } on QqMusicDirectException {
        vip = null;
      }
      final info = _map(homepage['Info']);
      final baseInfo = _map(info['BaseInfo']);
      final identity = _map(vip?['identity']);
      const rootFlags = ['svip', 'star', 'ystar'];
      const identityFlags = [
        'vip',
        'HugeVip',
        'yearflag',
        'HugeYearFlag',
        'twelve',
        'ChildVip',
        'ExpVip',
        'GroupVipFlag',
        'CPLoverFlag',
        'AdVipFlag',
        'eight',
      ];
      return QqMusicUserProfile(
        id: active.musicId,
        nickname: _string(baseInfo['Name']).isEmpty
            ? 'QQ音乐用户'
            : _string(baseInfo['Name']),
        avatarUrl: _string(baseInfo['Avatar']),
        isVip: vip == null
            ? null
            : rootFlags.any((key) => _int(vip![key]) > 0) ||
                  identityFlags.any((key) => _int(identity[key]) > 0),
      );
    });
  }

  @override
  Future<QqMusicFeatureResult> loadFeature(
    QqMusicFeature feature, {
    int page = 1,
    int pageSize = 25,
    bool forceRefresh = false,
  }) {
    if (_recommendFeatures.contains(feature)) {
      return _runDirect(() async {
        final data = await _recommend.load(
          feature,
          page: page,
          pageSize: pageSize,
          credential: credential,
        );
        return parser
            .parseFeature(
              feature,
              data,
              title: _featureTitle(feature),
              limit: pageSize,
              page: page,
            )
            .withMetadata(
              updatedAt: DateTime.now().toUtc(),
              isFromCache: false,
            );
      });
    }
    if (feature == QqMusicFeature.charts || feature == QqMusicFeature.singers) {
      return _runDirect(() async {
        final data = await _catalog.loadFeature(
          feature,
          page: page,
          pageSize: pageSize,
          credential: credential,
        );
        return parser
            .parseFeature(
              feature,
              data,
              title: _featureTitle(feature),
              limit: feature == QqMusicFeature.singers ? 100 : pageSize,
              page: page,
            )
            .withMetadata(
              updatedAt: DateTime.now().toUtc(),
              isFromCache: false,
            );
      });
    }
    if (_personalFeatures.contains(feature)) {
      return _runDirect(() async {
        final data = await _user.loadFeature(
          feature,
          page: page,
          pageSize: pageSize,
          credential: _requireCredential(),
        );
        return parser
            .parseFeature(
              feature,
              data,
              title: _featureTitle(feature),
              limit: pageSize,
              page: page,
            )
            .withMetadata(
              updatedAt: DateTime.now().toUtc(),
              isFromCache: false,
            );
      });
    }
    return Future.value(
      QqMusicFeatureResult(title: _featureTitle(feature), items: const []),
    );
  }

  @override
  Future<QqMusicFeatureResult> search(
    String keyword, {
    int page = 1,
    int pageSize = 15,
  }) {
    final normalized = keyword.trim();
    if (normalized.isEmpty) {
      return Future.value(const QqMusicFeatureResult(title: '搜索', items: []));
    }
    return _runDirect(() async {
      final data = await _search.search(
        normalized,
        page: page,
        pageSize: pageSize,
        credential: credential,
      );
      return parser.parseSearch(data, keyword: normalized);
    });
  }

  @override
  Future<QqMusicFeatureResult> loadChildren(
    QqMusicItem item, {
    int page = 1,
    int pageSize = 25,
  }) {
    if (item.hasEmbeddedChildren) {
      return Future.value(
        QqMusicFeatureResult(title: item.title, items: item.children),
      );
    }
    if (item.type == QqMusicItemType.song ||
        item.type == QqMusicItemType.musicVideo) {
      return Future.value(
        QqMusicFeatureResult(title: item.title, items: const []),
      );
    }
    return _runDirect(() async {
      final data = await _catalog.loadChildren(
        item,
        page: page,
        pageSize: pageSize,
        credential: credential,
      );
      return parser.parseChildren(item, data, limit: pageSize, page: page);
    });
  }

  @override
  Future<Uri> getPlayableUrl(QqMusicItem song, {int fileType = 13}) {
    return _runDirect(() async {
      if (!song.isSong) {
        throw const QqMusicApiException('当前项目不是可播放歌曲');
      }
      var resolved = song;
      if (resolved.mid.isEmpty && resolved.id.isNotEmpty) {
        resolved = parser.parseSongDetail(
          await _song.detail(resolved, credential: credential),
        );
      }
      if (resolved.mid.isEmpty) {
        throw const QqMusicApiException('歌曲缺少 MID，无法获取播放地址');
      }
      final urls = await _loadPlayableUrls([resolved], fileType: fileType);
      final url = urls[resolved.mid];
      if (url == null) {
        throw QqMusicApiException(
          _playableUrlUnavailableMessage(resolved),
          code: 104003,
        );
      }
      return url;
    });
  }

  @override
  Future<Map<String, Uri?>> getPlayableUrls(
    List<QqMusicItem> songs, {
    int fileType = 13,
  }) {
    return _runDirect(() => _loadPlayableUrls(songs, fileType: fileType));
  }

  Future<Map<String, Uri?>> _loadPlayableUrls(
    List<QqMusicItem> songs, {
    required int fileType,
  }) async {
    final candidates = songs
        .where((song) => song.isSong && song.mid.isNotEmpty)
        .toList(growable: false);
    if (candidates.isEmpty) {
      return const {};
    }
    final data = await _song.urls(
      candidates,
      fileType: fileType,
      credential: credential,
    );
    final entries = _list(data['midurlinfo'] ?? data['data']).map(_map);
    final purls = <String, String>{};
    final unavailable = <String>{};
    for (final entry in entries) {
      final mid = _string(entry['songmid'] ?? entry['mid']);
      final result = _int(entry['result']);
      final purl = _string(entry['purl']);
      if (mid.isEmpty) {
        continue;
      }
      if (result == 0 && purl.isNotEmpty) {
        purls[mid] = purl;
      } else if (result == 104003) {
        unavailable.add(mid);
      }
    }
    Uri? cdn;
    if (purls.values.any((value) => Uri.tryParse(value)?.hasScheme != true)) {
      final dispatch = await _song.cdn(credential: credential);
      final value = _list(dispatch['sip'])
          .map(_string)
          .where((item) => item.startsWith('https://'))
          .followedBy(
            _list(
              dispatch['sip'],
            ).map(_string).where((item) => item.startsWith('http://')),
          )
          .firstWhere((item) => item.isNotEmpty, orElse: () => '');
      if (value.isNotEmpty) {
        cdn = Uri.parse(value);
      }
    }
    final urls = <String, Uri?>{};
    for (final entry in purls.entries) {
      final parsed = Uri.tryParse(entry.value);
      final uri = parsed?.hasScheme == true
          ? parsed
          : cdn?.resolve(entry.value);
      if (uri != null) {
        urls[entry.key] = _secureUri(uri);
      }
    }
    for (final mid in unavailable) {
      urls[mid] = null;
    }
    return urls;
  }

  @override
  Future<QqMusicLyrics> getLyrics(QqMusicItem song) {
    return _runDirect(() async {
      if (song.mid.isEmpty && song.id.isEmpty) {
        throw const QqMusicApiException('歌曲缺少 MID');
      }
      return parser.parseLyrics(
        await _song.lyric(song, credential: credential),
      );
    });
  }

  @override
  Future<Uri> getMusicVideoUrl(QqMusicItem musicVideo) {
    return _runDirect(() {
      if (musicVideo.mid.isEmpty) {
        throw const QqMusicApiException('MV 缺少 VID');
      }
      return _song.musicVideoUrl(musicVideo, credential: credential);
    });
  }

  @override
  Future<void> setSongLiked(QqMusicItem song, {required bool liked}) {
    return _runDirect(
      () => _playlist.mutateSongs(
        '201',
        [song],
        add: liked,
        credential: _requireCredential(),
      ),
    );
  }

  @override
  Future<void> setPlaylistFavorite(
    String playlistId, {
    required bool favorite,
  }) {
    return _runDirect(
      () => _playlist.setFavorite(
        playlistId,
        favorite: favorite,
        credential: _requireCredential(),
      ),
    );
  }

  @override
  Future<void> setDislike(QqMusicItem item, {required bool disliked}) {
    return _runDirect(
      () => _user.setDislike(
        item,
        disliked: disliked,
        credential: _requireCredential(),
      ),
    );
  }

  @override
  Future<QqMusicItem> createPlaylist(String name) {
    final normalized = name.trim();
    if (normalized.isEmpty) {
      throw const QqMusicApiException('歌单名称不能为空');
    }
    return _runDirect(() async {
      final data = await _playlist.create(normalized, _requireCredential());
      final result = _map(data['result']);
      if (_int(data['retCode']) != 0) {
        throw const QqMusicApiException('创建歌单失败');
      }
      return QqMusicItem(
        id: _string(result['tid']),
        directoryId: _string(result['dirId']),
        title: _string(result['dirName']).isEmpty
            ? normalized
            : _string(result['dirName']),
        subtitle: '自建歌单',
        imageUrl: '',
        type: QqMusicItemType.playlist,
      );
    });
  }

  @override
  Future<void> deletePlaylist(String directoryId) {
    return _runDirect(
      () => _playlist.delete(directoryId, _requireCredential()),
    );
  }

  @override
  Future<void> addSongsToPlaylist(String directoryId, List<QqMusicItem> songs) {
    return _runDirect(
      () => _playlist.mutateSongs(
        directoryId,
        songs,
        add: true,
        credential: _requireCredential(),
      ),
    );
  }

  @override
  Future<void> removeSongsFromPlaylist(
    String directoryId,
    List<QqMusicItem> songs,
  ) {
    return _runDirect(
      () => _playlist.mutateSongs(
        directoryId,
        songs,
        add: false,
        credential: _requireCredential(),
      ),
    );
  }

  QqMusicCredential _requireCredential() {
    final active = credential;
    if (active == null || !active.isValid) {
      throw const QqMusicApiException('请先扫码登录 QQ 音乐', statusCode: 401);
    }
    return active;
  }

  /// Prefer specific playback reasons over a single generic “no URL” string.
  String _playableUrlUnavailableMessage(QqMusicItem song) {
    if (song.requiresVip) {
      return '该歌曲需要 VIP 会员才能播放';
    }
    if (song.isCopyrightRestricted) {
      return '歌曲暂无版权';
    }
    final active = credential;
    if (active == null || !active.isValid) {
      return '当前未登录，该歌曲暂无游客播放地址';
    }
    return '歌曲没有可用播放地址，可能需要会员或存在版权限制';
  }

  Future<T> _runDirect<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } on QqMusicApiException {
      rethrow;
    } on QqMusicDirectException catch (error) {
      throw QqMusicApiException(
        error.message,
        statusCode: error.statusCode,
        code: error.code,
      );
    } on StateError catch (error) {
      throw QqMusicApiException(error.message);
    }
  }

  Uri _secureUri(Uri uri) =>
      uri.scheme.toLowerCase() == 'http' ? uri.replace(scheme: 'https') : uri;

  @override
  void dispose() {
    _client.close();
    _login.close();
  }
}

const _recommendFeatures = {
  QqMusicFeature.guessRecommendations,
  QqMusicFeature.homeFeed,
  QqMusicFeature.radar,
  QqMusicFeature.newSongs,
  QqMusicFeature.recommendedPlaylists,
};

const _personalFeatures = {
  QqMusicFeature.likedSongs,
  QqMusicFeature.favoriteAlbums,
  QqMusicFeature.favoriteMusicVideos,
  QqMusicFeature.favoriteSingers,
  QqMusicFeature.createdPlaylists,
  QqMusicFeature.collectedPlaylists,
  QqMusicFeature.dislikes,
};

String _featureTitle(QqMusicFeature feature) => switch (feature) {
  QqMusicFeature.guessRecommendations => '猜你喜欢',
  QqMusicFeature.homeFeed => '首页推荐',
  QqMusicFeature.radar => '雷达',
  QqMusicFeature.newSongs => '新歌推荐',
  QqMusicFeature.recommendedPlaylists => '推荐歌单',
  QqMusicFeature.charts => '排行榜',
  QqMusicFeature.singers => '歌手',
  QqMusicFeature.likedSongs => '我喜欢的音乐',
  QqMusicFeature.favoriteAlbums => '收藏专辑',
  QqMusicFeature.favoriteMusicVideos => '收藏 MV',
  QqMusicFeature.favoriteSingers => '关注歌手',
  QqMusicFeature.createdPlaylists => '自建歌单',
  QqMusicFeature.collectedPlaylists => '收藏歌单',
  QqMusicFeature.dislikes => '不喜欢',
  QqMusicFeature.search => '搜索',
  QqMusicFeature.account => '账号与会员',
};

Map<String, dynamic> _map(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : const {};

List<dynamic> _list(Object? value) => value is List ? value : const [];

String _string(Object? value) => value?.toString() ?? '';

int _int(Object? value) =>
    value is num ? value.toInt() : int.tryParse('$value') ?? 0;
