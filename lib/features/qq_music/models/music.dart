enum QqMusicItemType { song, playlist, chart, singer, album, musicVideo }

enum QqMusicFeature {
  guessRecommendations,
  homeFeed,
  radar,
  newSongs,
  recommendedPlaylists,
  charts,
  singers,
  likedSongs,
  favoriteAlbums,
  favoriteMusicVideos,
  favoriteSingers,
  createdPlaylists,
  collectedPlaylists,
  dislikes,
  search,
  account,
}

enum QqMusicPlaybackMode { sequential, repeatOne, shuffle }

class QqMusicLyricWord {
  const QqMusicLyricWord({
    required this.text,
    required this.time,
    required this.duration,
  });

  final String text;
  final Duration time;
  final Duration duration;

  Duration get endTime => time + duration;
}

class QqMusicLyricLine {
  const QqMusicLyricLine({
    required this.time,
    required this.text,
    this.duration = Duration.zero,
    this.words = const [],
  });

  final Duration time;
  final Duration duration;
  final String text;
  final List<QqMusicLyricWord> words;

  Duration get endTime => time + duration;
  bool get hasWordTimeline => words.isNotEmpty;
}

class QqMusicLyrics {
  const QqMusicLyrics({required this.lines});

  final List<QqMusicLyricLine> lines;
}

class QqMusicItem {
  const QqMusicItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.type,
    this.mid = '',
    this.mediaMid = '',
    this.directoryId = '',
    this.duration = Duration.zero,
    this.songType,
    this.requiresVip = false,
    this.isCopyrightRestricted = false,
    this.children = const [],
  });

  factory QqMusicItem.fromJson(Map<String, dynamic> json) {
    final typeName = _stringValue(json['type']);
    return QqMusicItem(
      id: _stringValue(json['id']),
      mid: _stringValue(json['mid']),
      mediaMid: _stringValue(json['media_mid']),
      directoryId: _stringValue(json['directory_id']),
      title: _stringValue(json['title']),
      subtitle: _stringValue(json['subtitle']),
      imageUrl: _stringValue(json['image_url']),
      type: QqMusicItemType.values.firstWhere(
        (type) => type.name == typeName,
        orElse: () => QqMusicItemType.song,
      ),
      duration: Duration(milliseconds: _intValue(json['duration_ms'])),
      songType: json['song_type'] == null ? null : _intValue(json['song_type']),
      requiresVip: json['requires_vip'] == true,
      isCopyrightRestricted: json['copyright_restricted'] == true,
      children: (json['children'] as List? ?? const [])
          .whereType<Map>()
          .map(
            (child) => QqMusicItem.fromJson(Map<String, dynamic>.from(child)),
          )
          .toList(growable: false),
    );
  }

  final String id;
  final String mid;
  final String mediaMid;
  final String directoryId;
  final String title;
  final String subtitle;
  final String imageUrl;
  final QqMusicItemType type;
  final Duration duration;
  final int? songType;
  final bool requiresVip;
  final bool isCopyrightRestricted;
  final List<QqMusicItem> children;

  bool get isSong => type == QqMusicItemType.song;
  bool get hasEmbeddedChildren => children.isNotEmpty;
  bool get isDirectoryPlaylist =>
      directoryId.isNotEmpty && (id.isEmpty || id == '0');

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'mid': mid,
      'media_mid': mediaMid,
      'directory_id': directoryId,
      'title': title,
      'subtitle': subtitle,
      'image_url': imageUrl,
      'type': type.name,
      'duration_ms': duration.inMilliseconds,
      'song_type': songType,
      'requires_vip': requiresVip,
      'copyright_restricted': isCopyrightRestricted,
      'children': children.map((child) => child.toJson()).toList(),
    };
  }
}

class QqMusicFeatureResult {
  const QqMusicFeatureResult({
    required this.title,
    required this.items,
    this.hasMore = false,
    this.message = '',
    this.updatedAt,
    this.isFromCache = false,
  });

  factory QqMusicFeatureResult.fromJson(Map<String, dynamic> json) {
    return QqMusicFeatureResult(
      title: _stringValue(json['title']),
      items: (json['items'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => QqMusicItem.fromJson(Map<String, dynamic>.from(item)))
          .toList(growable: false),
      hasMore: json['has_more'] == true,
      message: _stringValue(json['message']),
    );
  }

  final String title;
  final List<QqMusicItem> items;
  final bool hasMore;
  final String message;
  final DateTime? updatedAt;
  final bool isFromCache;

  QqMusicFeatureResult withMetadata({
    required DateTime updatedAt,
    required bool isFromCache,
  }) {
    return QqMusicFeatureResult(
      title: title,
      items: items,
      hasMore: hasMore,
      message: message,
      updatedAt: updatedAt,
      isFromCache: isFromCache,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'items': items.map((item) => item.toJson()).toList(),
      'has_more': hasMore,
      'message': message,
    };
  }
}

String _stringValue(Object? value) => value?.toString() ?? '';

int _intValue(Object? value) {
  if (value is int) {
    return value;
  }
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
