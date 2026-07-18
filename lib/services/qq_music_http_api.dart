import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../ipod_models.dart';
import 'qq_music_api.dart';
import 'qq_music_cache.dart';
import 'qq_music_models.dart';
import 'qq_music_parser.dart';
import 'qq_music_platform_client.dart'
    if (dart.library.js_interop) 'qq_music_platform_client_web.dart';
import 'qq_music_session.dart';

class QqMusicHttpApi implements QqMusicApi {
  QqMusicHttpApi({
    Uri? baseUri,
    http.Client? client,
    QqMusicCredentialStore? credentialStore,
    QqMusicCacheStore? cacheStore,
    this.parser = const QqMusicResponseParser(),
    this.likedSongsCacheMaxAge = const Duration(hours: 24),
    this.expandGuessRecommendations = false,
  }) : baseUri = baseUri ?? Uri.parse(defaultBaseUrl),
       _client = client ?? createQqMusicHttpClient(),
       _authenticatedClient = client ?? createQqMusicAuthenticatedHttpClient(),
       _credentialStore =
           credentialStore ?? const SecureQqMusicCredentialStore(),
       _cacheStore = cacheStore ?? const SharedPreferencesQqMusicCacheStore();

  static const configuredBaseUrl = String.fromEnvironment(
    'QQ_MUSIC_API_BASE_URL',
  );

  static String get defaultBaseUrl {
    if (configuredBaseUrl.isNotEmpty) {
      return configuredBaseUrl;
    }
    return 'https://music.tinukso.cn';
  }

  final Uri baseUri;
  final http.Client _client;
  final http.Client _authenticatedClient;
  final QqMusicCredentialStore _credentialStore;
  final QqMusicCacheStore _cacheStore;
  final QqMusicResponseParser parser;
  final Duration likedSongsCacheMaxAge;
  final bool expandGuessRecommendations;

  QqMusicCredential? _credential;

  @override
  QqMusicCredential? get credential => _credential;

  @override
  bool get isLoggedIn => _credential?.isValid ?? false;

  @override
  Future<void> restoreSession() async {
    final restored = await _credentialStore.read();
    if (restored == null) {
      return;
    }
    _syncBrowserCookies(restored);
    _credential = restored;
    try {
      await _get('/login/check_expired', authenticated: true);
    } on QqMusicApiException catch (error) {
      if (!error.isUnauthorized) {
        rethrow;
      }
      try {
        await refreshCredential();
      } catch (_) {
        await logout();
      }
    }
  }

  @override
  Future<QqMusicQrCode> createQrCode({String loginType = 'qq'}) async {
    final data = _data(await _get('/login/qrcode/$loginType'));
    final encoded = _string(data['data']);
    if (encoded.isEmpty) {
      throw const QqMusicApiException('服务没有返回二维码图片');
    }
    return QqMusicQrCode(
      loginType: _string(data['qr_type']).isEmpty
          ? loginType
          : _string(data['qr_type']),
      identifier: _string(data['identifier']),
      mimeType: _string(data['mimetype']),
      imageBytes: base64Decode(encoded),
    );
  }

  @override
  Future<QqMusicQrStatus> checkQrStatus(QqMusicQrCode qrCode) async {
    final data = _data(
      await _get(
        '/login/qrcode/${qrCode.loginType}/status',
        query: {'identifier': qrCode.identifier},
      ),
    );
    final rawCredential = data['credential'];
    final credential = rawCredential is Map
        ? QqMusicCredential.fromJson(Map<String, dynamic>.from(rawCredential))
        : null;
    if (credential?.isValid ?? false) {
      _syncBrowserCookies(credential!);
      _credential = credential;
      await _credentialStore.write(credential);
    }
    return QqMusicQrStatus(
      event: _int(data['event']),
      done: data['done'] == true,
      credential: credential,
      identifier: _string(data['identifier']),
      loginType: _string(data['login_type']),
    );
  }

  @override
  Future<QqMusicCredential> refreshCredential() async {
    final data = _data(
      await _get('/login/refresh_credential', authenticated: true),
    );
    final refreshed = QqMusicCredential.fromJson(data);
    if (!refreshed.isValid) {
      throw const QqMusicApiException('刷新登录凭据失败');
    }
    _syncBrowserCookies(refreshed);
    _credential = refreshed;
    await _credentialStore.write(refreshed);
    return refreshed;
  }

  @override
  Future<void> logout() async {
    _credential = null;
    try {
      if (canUseBrowserCredentials) {
        clearBrowserCredentialCookies(baseUri, const [
          'musicid',
          'musickey',
          'openid',
          'refresh_token',
          'access_token',
          'expired_at',
          'unionid',
          'str_musicid',
          'refresh_key',
        ]);
      }
    } finally {
      await _credentialStore.clear();
    }
  }

  @override
  Future<QqMusicUserProfile> getUserProfile() async {
    final active = _requireCredential();
    final userId = active.encryptUin.isNotEmpty
        ? active.encryptUin
        : active.musicId;
    final homepage = _data(
      await _get('/user/$userId/homepage', authenticated: true),
    );
    final baseInfo = _map(homepage['base_info']);
    bool? isVip;
    try {
      final vip = _data(await _get('/user/get_vip_info', authenticated: true));
      final identity = _map(vip['identity']);
      const rootFlags = ['svip', 'star', 'ystar'];
      const identityFlags = [
        'vip',
        'huge_vip',
        'year_flag',
        'huge_year_flag',
        'twelve',
        'child_vip',
        'exp_vip',
        'group_vip_flag',
        'cp_lover_flag',
        'ad_vip_flag',
        'eight',
      ];
      final hasVipStatus =
          rootFlags.any(vip.containsKey) ||
          identityFlags.any(identity.containsKey);
      if (hasVipStatus) {
        isVip =
            rootFlags.any((key) => _int(vip[key]) > 0) ||
            identityFlags.any((key) => _int(identity[key]) > 0);
      }
    } on QqMusicApiException {
      isVip = null;
    }
    return QqMusicUserProfile(
      id: active.musicId,
      nickname: _string(baseInfo['name']).isEmpty
          ? 'QQ音乐用户'
          : _string(baseInfo['name']),
      avatarUrl: _string(baseInfo['avatar']),
      isVip: isVip,
    );
  }

  @override
  Future<QqMusicFeatureResult> loadFeature(
    QqMusicFeature feature, {
    int page = 1,
    int pageSize = 25,
    bool forceRefresh = false,
  }) async {
    if (feature == QqMusicFeature.likedSongs && page == 1) {
      return _loadLikedSongs(
        pageSize < 100 ? 100 : pageSize,
        forceRefresh: forceRefresh,
      );
    }
    return (await _loadFeaturePage(
      feature,
      page: page,
      pageSize: pageSize,
    )).withMetadata(updatedAt: DateTime.now().toUtc(), isFromCache: false);
  }

  Future<QqMusicFeatureResult> _loadLikedSongs(
    int pageSize, {
    required bool forceRefresh,
  }) async {
    final key = _likedSongsCacheKey;
    if (!forceRefresh && key.isNotEmpty) {
      final cached = await _cacheStore.read(key);
      if (cached != null &&
          cached.isFresh(likedSongsCacheMaxAge, DateTime.now().toUtc()) &&
          cached.value is Map) {
        try {
          return QqMusicFeatureResult.fromJson(
            Map<String, dynamic>.from(cached.value! as Map),
          ).withMetadata(updatedAt: cached.updatedAt, isFromCache: true);
        } catch (_) {
          await _cacheStore.remove(key);
        }
      }
    }
    final loaded = (await _loadAllLikedSongs(
      pageSize,
    )).withMetadata(updatedAt: DateTime.now().toUtc(), isFromCache: false);
    if (key.isNotEmpty) {
      await _cacheStore.write(key, loaded.toJson());
    }
    return loaded;
  }

  String get _likedSongsCacheKey {
    final active = _credential;
    final userId = active?.encryptUin.isNotEmpty == true
        ? active!.encryptUin
        : active?.musicId ?? '';
    return userId.isEmpty ? '' : 'feature.liked_songs.$userId';
  }

  Future<QqMusicFeatureResult> _loadFeaturePage(
    QqMusicFeature feature, {
    required int page,
    required int pageSize,
  }) async {
    final endpoint = _featureEndpoint(feature, page, pageSize);
    final response = await _get(
      endpoint.path,
      query: endpoint.query,
      authenticated: endpoint.authenticated,
    );
    final parsed = parser.parseFeature(
      feature,
      _nullableData(response),
      title: endpoint.title,
      limit: feature == QqMusicFeature.singers ? 100 : pageSize,
      page: page,
    );
    if (feature == QqMusicFeature.guessRecommendations &&
        expandGuessRecommendations) {
      return _expandGuessRecommendations(parsed);
    }
    return parsed;
  }

  Future<QqMusicFeatureResult> _expandGuessRecommendations(
    QqMusicFeatureResult seed,
  ) async {
    if (seed.items.isEmpty) {
      return seed;
    }
    final merged = <QqMusicItem>[...seed.items];
    final seen = <String>{
      for (final item in seed.items)
        if (item.id.isNotEmpty) item.id else item.mid,
    };
    for (final seedSong in seed.items.take(3)) {
      if (seedSong.id.isEmpty) {
        continue;
      }
      try {
        final response = await _get(
          '/song/${seedSong.id}/similar',
          authenticated: true,
        );
        final similar = parser.parseSimilarSongs(_nullableData(response));
        for (final item in similar) {
          final key = item.id.isNotEmpty ? item.id : item.mid;
          if (key.isEmpty || !seen.add(key)) {
            continue;
          }
          merged.add(item);
        }
      } catch (_) {
        // Keep the original guess list when similar expansion fails.
      }
      if (merged.length >= 40) {
        break;
      }
    }
    return QqMusicFeatureResult(
      title: seed.title,
      items: List.unmodifiable(merged.take(40)),
      hasMore: seed.hasMore,
      message: seed.message,
    );
  }

  Future<QqMusicFeatureResult> _loadAllLikedSongs(int pageSize) async {
    final loadedItems = <QqMusicItem>[];
    var page = 1;
    var hasMore = true;
    var message = '';
    while (hasMore && page <= 100) {
      final result = await _loadFeaturePage(
        QqMusicFeature.likedSongs,
        page: page,
        pageSize: pageSize,
      );
      for (final item in result.items) {
        if (!loadedItems.any((existing) => existing.id == item.id)) {
          loadedItems.add(item);
        }
      }
      message = result.message;
      hasMore = result.hasMore && result.items.isNotEmpty;
      page += 1;
    }
    return QqMusicFeatureResult(
      title: '我喜欢的音乐',
      items: List.unmodifiable(loadedItems),
      hasMore: hasMore,
      message: message,
    );
  }

  @override
  Future<QqMusicFeatureResult> search(
    String keyword, {
    int page = 1,
    int pageSize = 15,
  }) async {
    final normalized = keyword.trim();
    if (normalized.isEmpty) {
      return const QqMusicFeatureResult(title: '搜索', items: []);
    }
    final response = await _get(
      '/search/general_search',
      query: {
        'keyword': normalized,
        'page': '$page',
        'num': '$pageSize',
        'highlight': 'false',
      },
    );
    return parser.parseSearch(_nullableData(response), keyword: normalized);
  }

  @override
  Future<QqMusicFeatureResult> loadChildren(
    QqMusicItem item, {
    int page = 1,
    int pageSize = 25,
  }) async {
    if (item.hasEmbeddedChildren) {
      return QqMusicFeatureResult(title: item.title, items: item.children);
    }
    final path = switch (item.type) {
      QqMusicItemType.playlist =>
        '/songlist/${item.isDirectoryPlaylist ? '0' : item.id}/detail',
      QqMusicItemType.chart => '/top/${item.id}/detail',
      QqMusicItemType.singer => '/singer/${item.mid}/songs',
      QqMusicItemType.album =>
        '/album/${item.mid.isEmpty ? item.id : item.mid}/songs',
      QqMusicItemType.song || QqMusicItemType.musicVideo => '',
    };
    if (path.isEmpty) {
      return QqMusicFeatureResult(title: item.title, items: const []);
    }
    final query = <String, String>{'page': '$page', 'num': '$pageSize'};
    if (item.type == QqMusicItemType.playlist && item.directoryId.isNotEmpty) {
      query['dirid'] = item.directoryId;
    }
    final response = await _get(
      path,
      query: query,
      authenticated: item.type == QqMusicItemType.playlist && isLoggedIn,
    );
    return parser.parseChildren(item, _nullableData(response));
  }

  @override
  Future<Uri> getPlayableUrl(QqMusicItem song, {int fileType = 13}) async {
    if (!song.isSong) {
      throw const QqMusicApiException('当前项目不是可播放歌曲');
    }
    var playableSong = song;
    if (playableSong.mid.isEmpty && playableSong.id.isNotEmpty) {
      final detail = await _get('/song/${playableSong.id}/detail');
      playableSong = parser.parseSongDetail(_nullableData(detail));
    }
    if (playableSong.mid.isEmpty) {
      throw const QqMusicApiException('歌曲缺少 MID，无法获取播放地址');
    }
    _requireCredential();
    final response = await _get(
      '/song/${playableSong.mid}/url',
      query: {
        'file_type': '$fileType',
        if (playableSong.songType != null)
          'song_type': '${playableSong.songType}',
        if (playableSong.mediaMid.isNotEmpty)
          'media_mid': playableSong.mediaMid,
      },
      authenticated: true,
    );
    final data = _map(_nullableData(response));
    final urlEntries = _list(data['data']).map(_map).toList(growable: false);
    final successfulEntries = urlEntries.where(
      (entry) => !entry.containsKey('result') || _int(entry['result']) == 0,
    );
    final purl = successfulEntries
        .map((entry) => _string(entry['purl']))
        .firstWhere((value) => value.isNotEmpty, orElse: () => '');
    if (purl.isEmpty) {
      final result = urlEntries
          .where((entry) => entry.containsKey('result'))
          .map((entry) => _int(entry['result']))
          .firstWhere((value) => value != 0, orElse: () => 0);
      if (result == 104003) {
        throw const QqMusicApiException(
          '歌曲没有可用播放地址，可能需要会员或存在版权限制',
          code: 104003,
        );
      }
      if (result == 104004) {
        throw const QqMusicApiException('播放凭据获取失败，请稍后重试', code: 104004);
      }
      if (result == 104013) {
        throw const QqMusicApiException('当前播放设备受限，请稍后重试', code: 104013);
      }
      throw const QqMusicApiException('服务没有返回有效播放地址，请稍后重试');
    }
    final parsed = Uri.tryParse(purl);
    if (parsed != null && parsed.hasScheme) {
      return parsed;
    }
    final dispatch = _data(await _get('/song/get_cdn_dispatch'));
    final cdn = _list(dispatch['sip'])
        .map(_string)
        .where((value) => value.startsWith('https://'))
        .followedBy(
          _list(
            dispatch['sip'],
          ).map(_string).where((value) => value.startsWith('http://')),
        )
        .firstWhere((value) => value.isNotEmpty, orElse: () => '');
    if (cdn.isEmpty) {
      throw const QqMusicApiException('服务没有返回音乐 CDN 地址');
    }
    return Uri.parse(cdn).resolve(purl);
  }

  @override
  Future<Map<String, Uri?>> getPlayableUrls(
    List<QqMusicItem> songs, {
    int fileType = 13,
  }) async {
    final candidates = songs
        .where((song) => song.isSong && song.mid.isNotEmpty)
        .toList(growable: false);
    if (candidates.isEmpty) {
      return const {};
    }
    _requireCredential();
    final response = await _post(
      '/song/get_song_urls',
      body: {
        'file_info': [
          for (final song in candidates)
            {
              'mid': song.mid,
              if (song.songType != null) 'song_type': song.songType,
              if (song.mediaMid.isNotEmpty) 'media_mid': song.mediaMid,
            },
        ],
        'file_type': fileType,
      },
      authenticated: true,
    );
    final data = _map(_nullableData(response));
    final purls = <String, String>{};
    final unavailableMids = <String>{};
    for (final raw in _list(data['data'])) {
      final entry = _map(raw);
      final mid = _string(entry['mid']);
      if (mid.isEmpty) {
        continue;
      }
      final hasResult = entry.containsKey('result');
      final result = _int(entry['result']);
      final purl = _string(entry['purl']);
      if ((!hasResult || result == 0) && purl.isNotEmpty) {
        purls[mid] = purl;
      } else if (result == 104003) {
        unavailableMids.add(mid);
      }
    }
    final relativePurls = purls.values.where((purl) {
      final uri = Uri.tryParse(purl);
      return purl.isNotEmpty && (uri == null || !uri.hasScheme);
    });
    Uri? cdn;
    if (relativePurls.isNotEmpty) {
      final dispatch = _data(await _get('/song/get_cdn_dispatch'));
      final value = _list(dispatch['sip'])
          .map(_string)
          .where((value) => value.startsWith('https://'))
          .followedBy(
            _list(
              dispatch['sip'],
            ).map(_string).where((value) => value.startsWith('http://')),
          )
          .firstWhere((value) => value.isNotEmpty, orElse: () => '');
      if (value.isNotEmpty) {
        cdn = Uri.parse(value);
      }
    }
    final urls = <String, Uri?>{};
    for (final entry in purls.entries) {
      final url = _resolvePlayablePurl(entry.value, cdn);
      if (url != null) {
        urls[entry.key] = url;
      }
    }
    for (final mid in unavailableMids) {
      urls[mid] = null;
    }
    return urls;
  }

  Uri? _resolvePlayablePurl(String purl, Uri? cdn) {
    if (purl.isEmpty) {
      return null;
    }
    final parsed = Uri.tryParse(purl);
    if (parsed?.hasScheme == true) {
      return parsed;
    }
    return cdn?.resolve(purl);
  }

  @override
  Future<QqMusicLyrics> getLyrics(QqMusicItem song) async {
    final value = song.mid.isNotEmpty ? song.mid : song.id;
    if (value.isEmpty) {
      throw const QqMusicApiException('歌曲缺少 MID');
    }
    final response = await _get(
      '/song/${Uri.encodeComponent(value)}/lyric',
      query: const {'qrc': 'true', 'trans': 'false', 'roma': 'false'},
    );
    final data = _map(_nullableData(response));
    var raw = _string(data['lyric']);
    if (raw.isEmpty) {
      raw = _string(data['qrc']);
    }
    if (raw.isEmpty) {
      raw = _string(data['lrc']);
    }
    raw = _decodeLyric(raw);
    final qrcLines = _parseQrcLyrics(raw);
    if (qrcLines.isNotEmpty) {
      return QqMusicLyrics(lines: List.unmodifiable(qrcLines));
    }
    return QqMusicLyrics(lines: List.unmodifiable(_parseLrcLyrics(raw)));
  }

  String _decodeLyric(String raw) {
    var decoded = raw;
    if (decoded.isNotEmpty &&
        !decoded.contains('[') &&
        !decoded.contains('<Lyric_1')) {
      try {
        decoded = utf8.decode(base64Decode(decoded));
      } catch (_) {}
    }
    final content = RegExp(
      'LyricContent="([\\s\\S]*?)"',
    ).firstMatch(decoded)?.group(1);
    return _decodeXmlEntities(content ?? decoded);
  }

  String _decodeXmlEntities(String value) {
    return value
        .replaceAll('&#10;', '\n')
        .replaceAll('&#13;', '\r')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&amp;', '&');
  }

  List<QqMusicLyricLine> _parseQrcLyrics(String raw) {
    final lines = <QqMusicLyricLine>[];
    final linePattern = RegExp(r'^\[(\d+),(\d+)\](.*)$');
    final wordPattern = RegExp(r'([^()]*)\((\d+),(\d+)\)');
    for (final sourceLine in const LineSplitter().convert(raw)) {
      final lineMatch = linePattern.firstMatch(sourceLine.trim());
      if (lineMatch == null) {
        continue;
      }
      final lineStart = int.parse(lineMatch.group(1)!);
      final lineDuration = int.parse(lineMatch.group(2)!);
      final words = <QqMusicLyricWord>[];
      for (final match in wordPattern.allMatches(lineMatch.group(3)!)) {
        final text = match.group(1) ?? '';
        if (text.isEmpty || text == '\r') {
          continue;
        }
        words.add(
          QqMusicLyricWord(
            text: text,
            time: Duration(milliseconds: int.parse(match.group(2)!)),
            duration: Duration(milliseconds: int.parse(match.group(3)!)),
          ),
        );
      }
      if (words.isEmpty) {
        continue;
      }
      lines.add(
        QqMusicLyricLine(
          time: Duration(milliseconds: lineStart),
          duration: Duration(milliseconds: lineDuration),
          text: words.map((word) => word.text).join(),
          words: List.unmodifiable(words),
        ),
      );
    }
    lines.sort((left, right) => left.time.compareTo(right.time));
    return lines;
  }

  List<QqMusicLyricLine> _parseLrcLyrics(String raw) {
    final lines = <QqMusicLyricLine>[];
    final timestamp = RegExp(r'\[(\d{1,3}):(\d{2})(?:[.:](\d{1,3}))?\]');
    for (final sourceLine in const LineSplitter().convert(raw)) {
      final matches = timestamp.allMatches(sourceLine).toList(growable: false);
      final text = sourceLine.replaceAll(timestamp, '').trim();
      if (matches.isEmpty || text.isEmpty) {
        continue;
      }
      for (final match in matches) {
        final minutes = int.parse(match.group(1)!);
        final seconds = int.parse(match.group(2)!);
        final fraction = match.group(3) ?? '';
        final milliseconds = fraction.isEmpty
            ? 0
            : int.parse(fraction.padRight(3, '0').substring(0, 3));
        lines.add(
          QqMusicLyricLine(
            time: Duration(
              minutes: minutes,
              seconds: seconds,
              milliseconds: milliseconds,
            ),
            text: text,
          ),
        );
      }
    }
    lines.sort((left, right) => left.time.compareTo(right.time));
    return lines;
  }

  @override
  Future<Uri> getMusicVideoUrl(QqMusicItem musicVideo) async {
    if (musicVideo.mid.isEmpty) {
      throw const QqMusicApiException('MV 缺少 VID');
    }
    final response = await _get('/mv/${musicVideo.mid}/url');
    final urls = <String>[];
    void collect(Object? value) {
      if (value is List) {
        for (final item in value) {
          collect(item);
        }
      } else if (value is Map) {
        for (final entry in value.entries) {
          if (entry.key == 'url' ||
              entry.key == 'freeflow_url' ||
              entry.key == 'comm_url') {
            collect(entry.value);
          } else {
            collect(entry.value);
          }
        }
      } else if (value is String && value.startsWith('http')) {
        urls.add(value);
      }
    }

    collect(_nullableData(response));
    if (urls.isEmpty) {
      throw const QqMusicApiException('MV 没有可用播放地址');
    }
    return Uri.parse(urls.first);
  }

  @override
  Future<void> setSongLiked(QqMusicItem song, {required bool liked}) async {
    if (liked) {
      await addSongsToPlaylist('201', [song]);
    } else {
      await removeSongsFromPlaylist('201', [song]);
    }
    final key = _likedSongsCacheKey;
    if (key.isEmpty) {
      return;
    }
    try {
      final cached = await _cacheStore.read(key);
      if (cached?.value is! Map) {
        return;
      }
      final result = QqMusicFeatureResult.fromJson(
        Map<String, dynamic>.from(cached!.value! as Map),
      );
      final contains = result.items.any((item) => _sameSong(item, song));
      final items = liked
          ? (contains ? result.items : [song, ...result.items])
          : result.items.where((item) => !_sameSong(item, song)).toList();
      await _cacheStore.write(
        key,
        QqMusicFeatureResult(
          title: result.title,
          items: List.unmodifiable(items),
          hasMore: result.hasMore,
          message: result.message,
        ).toJson(),
      );
    } catch (_) {
      try {
        await _cacheStore.remove(key);
      } catch (_) {}
    }
  }

  bool _sameSong(QqMusicItem first, QqMusicItem second) {
    if (first.mid.isNotEmpty && second.mid.isNotEmpty) {
      return first.mid == second.mid;
    }
    return first.id == second.id;
  }

  @override
  Future<void> setPlaylistFavorite(
    String playlistId, {
    required bool favorite,
  }) async {
    _requireCredential();
    if (favorite) {
      await _post(
        '/user/fav/songlists',
        query: {'songlist_id': playlistId},
        authenticated: true,
      );
    } else {
      await _delete('/user/fav/songlists/$playlistId', authenticated: true);
    }
  }

  @override
  Future<void> setDislike(QqMusicItem item, {required bool disliked}) async {
    _requireCredential();
    final idType = switch (item.type) {
      QqMusicItemType.song => 1,
      QqMusicItemType.singer => 2,
      _ => throw const QqMusicApiException('该类型不能加入不喜欢列表'),
    };
    final query = {'id_type': '$idType', 'values': item.id};
    if (disliked) {
      await _post('/user/dislikes', query: query, authenticated: true);
    } else {
      await _delete('/user/dislikes', query: query, authenticated: true);
    }
  }

  @override
  Future<QqMusicItem> createPlaylist(String name) async {
    _requireCredential();
    final normalized = name.trim();
    if (normalized.isEmpty) {
      throw const QqMusicApiException('歌单名称不能为空');
    }
    final data = _data(
      await _get(
        '/songlist/create',
        query: {'dirname': normalized},
        authenticated: true,
      ),
    );
    return QqMusicItem(
      id: _string(data['id']),
      directoryId: _string(data['dirid']),
      title: _string(data['name']).isEmpty ? normalized : _string(data['name']),
      subtitle: '自建歌单',
      imageUrl: '',
      type: QqMusicItemType.playlist,
    );
  }

  @override
  Future<void> deletePlaylist(String directoryId) async {
    _requireCredential();
    await _get(
      '/songlist/delete',
      query: {'dirid': directoryId},
      authenticated: true,
    );
  }

  @override
  Future<void> addSongsToPlaylist(String directoryId, List<QqMusicItem> songs) {
    return _changePlaylistSongs('/songlist/add_songs', directoryId, songs);
  }

  @override
  Future<void> removeSongsFromPlaylist(
    String directoryId,
    List<QqMusicItem> songs,
  ) {
    return _changePlaylistSongs('/songlist/del_songs', directoryId, songs);
  }

  Future<void> _changePlaylistSongs(
    String path,
    String directoryId,
    List<QqMusicItem> songs,
  ) async {
    _requireCredential();
    final validSongs = songs
        .where((song) => song.isSong && int.tryParse(song.id) != null)
        .toList(growable: false);
    if (validSongs.isEmpty) {
      throw const QqMusicApiException('没有可操作的歌曲');
    }
    await _post(
      path,
      queryLists: {
        'dirid': [directoryId],
        'song_id': validSongs.map((song) => song.id).toList(),
        'song_type': validSongs.map((song) => '${song.songType ?? 0}').toList(),
        'tid': ['0'],
      },
      authenticated: true,
    );
  }

  _FeatureEndpoint _featureEndpoint(
    QqMusicFeature feature,
    int page,
    int pageSize,
  ) {
    final active = _credential;
    final userId = active?.encryptUin.isNotEmpty == true
        ? active!.encryptUin
        : active?.musicId ?? '';
    return switch (feature) {
      QqMusicFeature.guessRecommendations => const _FeatureEndpoint(
        '/recommend/get_guess_recommend',
        '猜你喜欢',
        authenticated: true,
      ),
      QqMusicFeature.homeFeed => _FeatureEndpoint(
        '/recommend/get_home_feed',
        '首页推荐',
        query: {
          'page': '$page',
          'direction': '0',
          's_num': '${(page - 1) * pageSize}',
        },
        authenticated: true,
      ),
      QqMusicFeature.radar => _FeatureEndpoint(
        '/recommend/get_radar_recommend',
        '雷达',
        query: {'page': '$page'},
        authenticated: true,
      ),
      QqMusicFeature.newSongs => const _FeatureEndpoint(
        '/recommend/get_recommend_newsong',
        '新歌推荐',
        query: {'type': '5'},
      ),
      QqMusicFeature.recommendedPlaylists => _FeatureEndpoint(
        '/recommend/get_recommend_songlist',
        '推荐歌单',
        query: {'page': '$page', 'num': '$pageSize'},
      ),
      QqMusicFeature.charts => const _FeatureEndpoint(
        '/top/get_category',
        '排行榜',
      ),
      QqMusicFeature.singers => const _FeatureEndpoint(
        '/singer/get_singer_list',
        '歌手',
      ),
      QqMusicFeature.likedSongs => _protectedEndpoint(
        '/user/$userId/fav/songs',
        '我喜欢的音乐',
        page,
        pageSize,
      ),
      QqMusicFeature.favoriteAlbums => _protectedEndpoint(
        '/user/$userId/fav/albums',
        '收藏专辑',
        page,
        pageSize,
      ),
      QqMusicFeature.favoriteMusicVideos => _protectedEndpoint(
        '/user/$userId/fav/mvs',
        '收藏 MV',
        page,
        pageSize,
      ),
      QqMusicFeature.favoriteSingers => _protectedEndpoint(
        '/user/$userId/follow/singers',
        '关注歌手',
        page,
        pageSize,
      ),
      QqMusicFeature.createdPlaylists => _FeatureEndpoint(
        '/user/${active?.musicId ?? ''}/created_songlists',
        '自建歌单',
        authenticated: true,
      ),
      QqMusicFeature.collectedPlaylists => _protectedEndpoint(
        '/user/$userId/fav/songlists',
        '收藏歌单',
        page,
        pageSize,
      ),
      QqMusicFeature.dislikes => _FeatureEndpoint(
        '/user/dislikes',
        '不喜欢',
        query: {'cmd': '3', 'page': '$page'},
        authenticated: true,
      ),
      QqMusicFeature.search ||
      QqMusicFeature.account => throw const QqMusicApiException('该功能使用独立接口'),
    };
  }

  _FeatureEndpoint _protectedEndpoint(
    String path,
    String title,
    int page,
    int pageSize,
  ) {
    _requireCredential();
    return _FeatureEndpoint(
      path,
      title,
      query: {'page': '$page', 'num': '$pageSize'},
      authenticated: true,
    );
  }

  QqMusicCredential _requireCredential() {
    final active = _credential;
    if (active == null || !active.isValid) {
      throw const QqMusicApiException('请先扫码登录 QQ 音乐', statusCode: 401);
    }
    return active;
  }

  Future<Map<String, dynamic>> _get(
    String path, {
    Map<String, String> query = const {},
    bool authenticated = false,
  }) {
    return _request('GET', path, query: query, authenticated: authenticated);
  }

  Future<Map<String, dynamic>> _post(
    String path, {
    Map<String, String> query = const {},
    Map<String, List<String>> queryLists = const {},
    Map<String, dynamic>? body,
    bool authenticated = false,
  }) {
    return _request(
      'POST',
      path,
      query: query,
      queryLists: queryLists,
      jsonBody: body,
      authenticated: authenticated,
    );
  }

  Future<Map<String, dynamic>> _delete(
    String path, {
    Map<String, String> query = const {},
    bool authenticated = false,
  }) {
    return _request('DELETE', path, query: query, authenticated: authenticated);
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, String> query = const {},
    Map<String, List<String>> queryLists = const {},
    Map<String, dynamic>? jsonBody,
    bool authenticated = false,
  }) async {
    final uri = _resolve(path, query, queryLists);
    final headers = <String, String>{
      'Accept': 'application/json',
      if (jsonBody != null) 'Content-Type': 'application/json',
      if (authenticated && !canUseBrowserCredentials)
        'Cookie': _requireCredential().toCookie(),
    };
    late http.Response response;
    final requestClient = authenticated ? _authenticatedClient : _client;
    try {
      response = switch (method) {
        'GET' => await requestClient.get(uri, headers: headers),
        'POST' => await requestClient.post(
          uri,
          headers: headers,
          body: jsonBody == null ? null : jsonEncode(jsonBody),
        ),
        'DELETE' => await requestClient.delete(uri, headers: headers),
        _ => throw QqMusicApiException('不支持的请求方法：$method'),
      };
    } on TimeoutException {
      throw const QqMusicApiException('QQ 音乐服务请求超时');
    } on http.ClientException catch (error) {
      if (authenticated && canUseBrowserCredentials) {
        throw QqMusicApiException(
          '浏览器未能携带登录 Cookie。请让 API 与页面使用相同主机，并将服务端 CORS 配置为精确页面 Origin 且开启 allow_credentials；${error.message}',
        );
      }
      throw QqMusicApiException('无法连接 QQ 音乐服务：${error.message}');
    }
    final body = utf8.decode(response.bodyBytes, allowMalformed: true);
    Map<String, dynamic> json;
    try {
      final decoded = body.isEmpty
          ? const <String, dynamic>{}
          : jsonDecode(body);
      json = decoded is Map
          ? Map<String, dynamic>.from(decoded)
          : const <String, dynamic>{};
    } on FormatException {
      throw QqMusicApiException(
        'QQ 音乐服务返回了无效数据',
        statusCode: response.statusCode,
      );
    }
    final code = _nullableInt(json['code']);
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        (code != null && code != 0)) {
      throw QqMusicApiException(
        _string(json['msg']).isEmpty
            ? 'QQ 音乐请求失败 (${response.statusCode})'
            : _string(json['msg']),
        statusCode: response.statusCode,
        code: code,
      );
    }
    return json;
  }

  void _syncBrowserCookies(QqMusicCredential credential) {
    if (!canUseBrowserCredentials) {
      return;
    }
    syncBrowserCredentialCookies(baseUri, credential.cookieFields);
  }

  Uri _resolve(
    String path,
    Map<String, String> query,
    Map<String, List<String>> queryLists,
  ) {
    final normalizedBase = baseUri.path.endsWith('/')
        ? baseUri
        : baseUri.replace(path: '${baseUri.path}/');
    final resolved = normalizedBase.resolve(
      path.replaceFirst(RegExp('^/'), ''),
    );
    final entries = <MapEntry<String, String>>[
      ...query.entries,
      for (final entry in queryLists.entries)
        for (final value in entry.value) MapEntry(entry.key, value),
    ];
    if (entries.isEmpty) {
      return resolved;
    }
    final encoded = entries
        .map(
          (entry) =>
              '${Uri.encodeQueryComponent(entry.key)}=${Uri.encodeQueryComponent(entry.value)}',
        )
        .join('&');
    return resolved.replace(query: encoded);
  }

  @override
  void dispose() {
    _client.close();
    if (!identical(_authenticatedClient, _client)) {
      _authenticatedClient.close();
    }
  }
}

class _FeatureEndpoint {
  const _FeatureEndpoint(
    this.path,
    this.title, {
    this.query = const {},
    this.authenticated = false,
  });

  final String path;
  final String title;
  final Map<String, String> query;
  final bool authenticated;
}

Map<String, dynamic> _map(Object? value) {
  return value is Map ? Map<String, dynamic>.from(value) : const {};
}

List<dynamic> _list(Object? value) => value is List ? value : const [];

String _string(Object? value) => value?.toString() ?? '';

int _int(Object? value) =>
    value is num ? value.toInt() : int.tryParse(_string(value)) ?? 0;

int? _nullableInt(Object? value) {
  if (value == null) {
    return null;
  }
  return _int(value);
}

Map<String, dynamic> _data(Map<String, dynamic> response) {
  final data = response['data'];
  if (data is Map) {
    return Map<String, dynamic>.from(data);
  }
  throw QqMusicApiException(
    _string(response['msg']).isEmpty ? '服务没有返回数据' : _string(response['msg']),
  );
}

Object? _nullableData(Map<String, dynamic> response) => response['data'];
