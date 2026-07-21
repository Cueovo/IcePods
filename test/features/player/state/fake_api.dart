import 'dart:convert';

import 'package:qqmusic_ipod/business/repositories/music_repository.dart';
import 'package:qqmusic_ipod/business/entities/account.dart';
import 'package:qqmusic_ipod/data/models/api_exception.dart';
import 'package:qqmusic_ipod/business/entities/auth.dart';
import 'package:qqmusic_ipod/business/entities/music.dart';

class FakeQqMusicApi implements QqMusicApi {
  QqMusicCredential? storedCredential;
  final List<String> createdQrLoginTypes = [];
  final Set<String> unavailableSongMids = {};
  Object? qrStatusError;
  final Map<QqMusicFeature, int> featureLoadCounts = {};
  final List<QqMusicFeature> forcedFeatureRefreshes = [];
  final List<({QqMusicItem song, bool liked})> songLikedChanges = [];
  final Map<String, int> childrenLoadCounts = {};
  final List<int> radarPagesLoaded = [];
  final List<int> likedSongPagesLoaded = [];
  final List<int> childrenPagesLoaded = [];
  bool paginateLikedSongs = false;
  bool paginateChildren = false;
  bool? profileIsVip = true;
  int qrStatusChecks = 0;

  static const songs = <QqMusicItem>[
    QqMusicItem(
      id: '1',
      mid: 'song-mid-1',
      mediaMid: 'media-mid-1',
      title: '测试歌曲一',
      subtitle: '测试歌手',
      imageUrl: 'https://example.com/cover-1.jpg',
      type: QqMusicItemType.song,
      duration: Duration(minutes: 3),
      songType: 1,
    ),
    QqMusicItem(
      id: '2',
      mid: 'song-mid-2',
      mediaMid: 'media-mid-2',
      title: '测试歌曲二',
      subtitle: '另一位歌手',
      imageUrl: 'https://example.com/cover-2.jpg',
      type: QqMusicItemType.song,
      duration: Duration(minutes: 4),
      songType: 1,
      requiresVip: true,
    ),
    QqMusicItem(
      id: '3',
      mid: 'song-mid-3',
      mediaMid: 'media-mid-3',
      title: '测试歌曲三',
      subtitle: '免费歌手',
      imageUrl: 'https://example.com/cover-3.jpg',
      type: QqMusicItemType.song,
      duration: Duration(minutes: 3),
      songType: 1,
    ),
  ];

  static const similarSongs = <QqMusicItem>[
    QqMusicItem(
      id: '11',
      mid: 'similar-mid-1',
      mediaMid: 'similar-media-1',
      title: '相似歌曲一',
      subtitle: '听测试歌手的也在听 · 相似歌手',
      imageUrl: 'https://example.com/similar-1.jpg',
      type: QqMusicItemType.song,
      duration: Duration(minutes: 3),
      songType: 1,
    ),
    QqMusicItem(
      id: '12',
      mid: 'similar-mid-2',
      mediaMid: 'similar-media-2',
      title: '相似歌曲二',
      subtitle: '听测试歌手的也在听 · 另一位歌手',
      imageUrl: 'https://example.com/similar-2.jpg',
      type: QqMusicItemType.song,
      duration: Duration(minutes: 4),
      songType: 1,
    ),
  ];

  static const homeFeedItems = <QqMusicItem>[
    QqMusicItem(
      id: '7971796071',
      directoryId: '202',
      title: '每日30首',
      subtitle: '今日个性推荐',
      imageUrl: 'https://example.com/home-daily.jpg',
      type: QqMusicItemType.playlist,
    ),
    QqMusicItem(
      id: '211111',
      title: '百万收藏',
      subtitle: '推荐歌单',
      imageUrl: 'https://example.com/million.jpg',
      type: QqMusicItemType.playlist,
    ),
    QqMusicItem(
      id: 'home-shelf-songs-207',
      title: '大家都在听',
      subtitle: '3 首推荐歌曲',
      imageUrl: 'https://example.com/home-song.jpg',
      type: QqMusicItemType.playlist,
      children: songs,
    ),
    QqMusicItem(
      id: '26',
      title: '热歌榜',
      subtitle: '排行榜',
      imageUrl: 'https://example.com/home-chart.jpg',
      type: QqMusicItemType.chart,
    ),
  ];

  static const playlists = <QqMusicItem>[
    QqMusicItem(
      id: 'playlist-id-1',
      directoryId: '88',
      title: '测试歌单',
      subtitle: '自建歌单',
      imageUrl: '',
      type: QqMusicItemType.playlist,
    ),
  ];

  @override
  QqMusicCredential? get credential => storedCredential;

  @override
  bool get isLoggedIn => storedCredential?.isValid ?? false;

  @override
  Future<QqMusicQrStatus> checkQrStatus(QqMusicQrCode qrCode) async {
    qrStatusChecks += 1;
    final injected = qrStatusError;
    if (injected != null) {
      throw injected;
    }
    return QqMusicQrStatus(
      event: 1,
      done: false,
      identifier: qrCode.identifier,
      loginType: qrCode.loginType,
    );
  }

  @override
  Future<QqMusicQrCode> createQrCode({String loginType = 'qq'}) async {
    createdQrLoginTypes.add(loginType);
    return QqMusicQrCode(
      loginType: loginType,
      identifier: 'test-identifier',
      mimeType: 'image/png',
      imageBytes: base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
      ),
    );
  }

  @override
  Future<QqMusicLyrics> getLyrics(QqMusicItem song) async {
    return const QqMusicLyrics(
      lines: [
        QqMusicLyricLine(time: Duration.zero, text: '测试歌词第一行'),
        QqMusicLyricLine(time: Duration(seconds: 10), text: '测试歌词第二行'),
      ],
    );
  }

  @override
  Future<Uri> getMusicVideoUrl(QqMusicItem musicVideo) async {
    return Uri.parse('https://example.com/test.mp4');
  }

  @override
  Future<Uri> getPlayableUrl(QqMusicItem song, {int fileType = 13}) async {
    if (unavailableSongMids.contains(song.mid)) {
      throw const QqMusicApiException(
        '歌曲没有可用播放地址',
        code: 104003,
      );
    }
    return Uri.parse('https://example.com/${song.mid}.mp3');
  }

  @override
  Future<Map<String, Uri?>> getPlayableUrls(
    List<QqMusicItem> songs, {
    int fileType = 13,
  }) async {
    return {
      for (final song in songs.where((song) => song.mid.isNotEmpty))
        song.mid: unavailableSongMids.contains(song.mid)
            ? null
            : Uri.parse('https://example.com/${song.mid}.mp3'),
    };
  }

  @override
  Future<QqMusicUserProfile> getUserProfile() async {
    return QqMusicUserProfile(
      id: '10001',
      nickname: '测试用户',
      avatarUrl: '',
      isVip: profileIsVip,
    );
  }

  @override
  Future<QqMusicFeatureResult> loadChildren(
    QqMusicItem item, {
    int page = 1,
    int pageSize = 25,
  }) async {
    childrenLoadCounts.update(item.id, (count) => count + 1, ifAbsent: () => 1);
    if (paginateChildren) {
      childrenPagesLoaded.add(page);
      final pageSongs = List<QqMusicItem>.generate(25, (index) {
        final id = ((page - 1) * 25) + index + 1;
        return QqMusicItem(
          id: 'child-$id',
          mid: 'child-mid-$id',
          mediaMid: 'child-media-$id',
          title: '歌单歌曲$id',
          subtitle: '歌单歌手',
          imageUrl: '',
          type: QqMusicItemType.song,
          duration: const Duration(minutes: 3),
          songType: 1,
        );
      });
      return QqMusicFeatureResult(
        title: item.title,
        items: pageSongs,
        hasMore: page < 2,
      );
    }
    if (item.hasEmbeddedChildren) {
      return QqMusicFeatureResult(title: item.title, items: item.children);
    }
    return QqMusicFeatureResult(title: item.title, items: songs);
  }

  @override
  Future<QqMusicFeatureResult> loadFeature(
    QqMusicFeature feature, {
    int page = 1,
    int pageSize = 25,
    bool forceRefresh = false,
  }) async {
    if (forceRefresh) {
      forcedFeatureRefreshes.add(feature);
    }
    featureLoadCounts.update(feature, (count) => count + 1, ifAbsent: () => 1);
    if (feature == QqMusicFeature.likedSongs && paginateLikedSongs) {
      likedSongPagesLoaded.add(page);
      final pageSongs = List<QqMusicItem>.generate(25, (index) {
        final id = ((page - 1) * 25) + index + 1;
        return QqMusicItem(
          id: 'liked-$id',
          mid: 'liked-mid-$id',
          mediaMid: 'liked-media-$id',
          title: '喜欢歌曲$id',
          subtitle: '喜欢歌手',
          imageUrl: '',
          type: QqMusicItemType.song,
          duration: const Duration(minutes: 3),
          songType: 1,
        );
      });
      return QqMusicFeatureResult(
        title: '我喜欢的音乐',
        items: pageSongs,
        hasMore: page < 3,
      );
    }
    if (feature == QqMusicFeature.radar) {
      radarPagesLoaded.add(page);
      final pageSongs = List<QqMusicItem>.generate(10, (index) {
        final id = ((page - 1) * 10) + index + 1;
        return QqMusicItem(
          id: 'radar-$id',
          mid: 'radar-mid-$id',
          mediaMid: 'radar-media-$id',
          title: '雷达歌曲$id',
          subtitle: '雷达歌手',
          imageUrl: 'https://example.com/radar-$id.jpg',
          type: QqMusicItemType.song,
          duration: const Duration(minutes: 3),
          songType: 1,
        );
      });
      return QqMusicFeatureResult(
        title: '雷达',
        items: pageSongs,
        hasMore: page < 3,
      );
    }
    return QqMusicFeatureResult(
      title: switch (feature) {
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
        QqMusicFeature.account => '账号',
      },
      items: switch (feature) {
        QqMusicFeature.createdPlaylists => playlists,
        QqMusicFeature.homeFeed => homeFeedItems,
        QqMusicFeature.guessRecommendations => [...songs, ...similarSongs],
        _ => songs,
      },
    );
  }

  @override
  Future<void> logout() async {
    storedCredential = null;
  }

  @override
  Future<QqMusicCredential> refreshCredential() async {
    final active = storedCredential;
    if (active == null) {
      throw const QqMusicApiException('没有凭据');
    }
    return active;
  }

  @override
  Future<void> restoreSession() async {}

  @override
  Future<QqMusicFeatureResult> search(
    String keyword, {
    int page = 1,
    int pageSize = 15,
  }) async {
    return QqMusicFeatureResult(title: '搜索：$keyword', items: songs);
  }

  @override
  void dispose() {}

  @override
  Future<QqMusicItem> createPlaylist(String name) async {
    return QqMusicItem(
      id: 'playlist-id',
      directoryId: '100',
      title: name,
      subtitle: '自建歌单',
      imageUrl: '',
      type: QqMusicItemType.playlist,
    );
  }

  @override
  Future<void> deletePlaylist(String directoryId) async {}

  @override
  Future<void> addSongsToPlaylist(
    String directoryId,
    List<QqMusicItem> songs,
  ) async {}

  @override
  Future<void> removeSongsFromPlaylist(
    String directoryId,
    List<QqMusicItem> songs,
  ) async {}

  @override
  Future<void> setSongLiked(QqMusicItem song, {required bool liked}) async {
    songLikedChanges.add((song: song, liked: liked));
  }

  @override
  Future<void> setDislike(QqMusicItem item, {required bool disliked}) async {}

  @override
  Future<void> setPlaylistFavorite(
    String playlistId, {
    required bool favorite,
  }) async {}
}
