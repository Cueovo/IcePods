enum QqMusicItemType { song, playlist, chart, singer, album, musicVideo }

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

class QqMusicCredential {
  const QqMusicCredential({
    required this.musicId,
    required this.musicKey,
    this.openId = '',
    this.refreshToken = '',
    this.accessToken = '',
    this.expiredAt = 0,
    this.unionId = '',
    this.stringMusicId = '',
    this.refreshKey = '',
    this.encryptUin = '',
  });

  factory QqMusicCredential.fromJson(Map<String, dynamic> json) {
    return QqMusicCredential(
      musicId: _stringValue(json['musicid']),
      musicKey: _stringValue(json['musickey']),
      openId: _stringValue(json['openid']),
      refreshToken: _stringValue(json['refresh_token']),
      accessToken: _stringValue(json['access_token']),
      expiredAt: _intValue(json['expired_at']),
      unionId: _stringValue(json['unionid']),
      stringMusicId: _stringValue(json['str_musicid']),
      refreshKey: _stringValue(json['refresh_key']),
      encryptUin: _stringValue(json['encrypt_uin'] ?? json['encryptUin']),
    );
  }

  final String musicId;
  final String musicKey;
  final String openId;
  final String refreshToken;
  final String accessToken;
  final int expiredAt;
  final String unionId;
  final String stringMusicId;
  final String refreshKey;
  final String encryptUin;

  bool get isValid => musicId.isNotEmpty && musicKey.isNotEmpty;

  Map<String, String> toStorage() {
    return {
      'musicid': musicId,
      'musickey': musicKey,
      'openid': openId,
      'refresh_token': refreshToken,
      'access_token': accessToken,
      'expired_at': expiredAt.toString(),
      'unionid': unionId,
      'str_musicid': stringMusicId,
      'refresh_key': refreshKey,
      'encrypt_uin': encryptUin,
    };
  }

  Map<String, String> get cookieFields => <String, String>{
    'musicid': musicId,
    'musickey': musicKey,
    'openid': openId,
    'refresh_token': refreshToken,
    'access_token': accessToken,
    'expired_at': expiredAt.toString(),
    'unionid': unionId,
    'str_musicid': stringMusicId,
    'refresh_key': refreshKey,
  };

  String toCookie() {
    return cookieFields.entries
        .where((entry) => entry.value.isNotEmpty && entry.value != '0')
        .map((entry) => '${entry.key}=${entry.value}')
        .join('; ');
  }
}

class QqMusicQrCode {
  const QqMusicQrCode({
    required this.loginType,
    required this.identifier,
    required this.mimeType,
    required this.imageBytes,
  });

  final String loginType;
  final String identifier;
  final String mimeType;
  final List<int> imageBytes;
}

class QqMusicQrStatus {
  const QqMusicQrStatus({
    required this.event,
    required this.done,
    required this.identifier,
    required this.loginType,
    this.credential,
  });

  final int event;
  final bool done;
  final String identifier;
  final String loginType;
  final QqMusicCredential? credential;

  String get message => switch (event) {
    0 => '登录成功',
    1 => '等待扫码',
    2 => '已扫码，请在手机上确认',
    3 => '二维码已过期',
    4 => '登录已取消',
    _ => '登录状态异常',
  };
}

class QqMusicUserProfile {
  const QqMusicUserProfile({
    required this.id,
    required this.nickname,
    required this.avatarUrl,
    this.isVip,
  });

  final String id;
  final String nickname;
  final String avatarUrl;
  final bool? isVip;

  bool get hasConfirmedVipStatus => isVip != null;
}

class QqMusicApiException implements Exception {
  const QqMusicApiException(this.message, {this.statusCode, this.code});

  final String message;
  final int? statusCode;
  final int? code;

  bool get isUnauthorized => statusCode == 401;

  @override
  String toString() => message;
}

String _stringValue(Object? value) => value?.toString() ?? '';

int _intValue(Object? value) {
  if (value is int) {
    return value;
  }
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
