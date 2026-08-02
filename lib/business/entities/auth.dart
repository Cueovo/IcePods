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
    this.loginType = 0,
    this.musicKeyCreatedAt = 0,
    this.keyExpiresIn = 0,
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
      loginType: _intValue(json['login_type'] ?? json['loginType']),
      musicKeyCreatedAt: _intValue(
        json['musickey_create_time'] ?? json['musickeyCreateTime'],
      ),
      keyExpiresIn: _intValue(json['key_expires_in'] ?? json['keyExpiresIn']),
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
  final int loginType;
  final int musicKeyCreatedAt;
  final int keyExpiresIn;

  bool get isValid => musicId.isNotEmpty && musicKey.isNotEmpty;
  int get effectiveLoginType {
    if (musicKey.startsWith('W_X')) {
      return 1;
    }
    if (musicKey.isNotEmpty) {
      return 2;
    }
    return loginType;
  }

  QqMusicCredential merge(QqMusicCredential fallback) {
    return QqMusicCredential(
      musicId: musicId.isEmpty ? fallback.musicId : musicId,
      musicKey: musicKey.isEmpty ? fallback.musicKey : musicKey,
      openId: openId.isEmpty ? fallback.openId : openId,
      refreshToken: refreshToken.isEmpty ? fallback.refreshToken : refreshToken,
      accessToken: accessToken.isEmpty ? fallback.accessToken : accessToken,
      expiredAt: expiredAt == 0 ? fallback.expiredAt : expiredAt,
      unionId: unionId.isEmpty ? fallback.unionId : unionId,
      stringMusicId: stringMusicId.isEmpty
          ? fallback.stringMusicId
          : stringMusicId,
      refreshKey: refreshKey.isEmpty ? fallback.refreshKey : refreshKey,
      encryptUin: encryptUin.isEmpty ? fallback.encryptUin : encryptUin,
      loginType: loginType == 0 ? fallback.loginType : loginType,
      musicKeyCreatedAt: musicKeyCreatedAt == 0
          ? fallback.musicKeyCreatedAt
          : musicKeyCreatedAt,
      keyExpiresIn: keyExpiresIn == 0 ? fallback.keyExpiresIn : keyExpiresIn,
    );
  }

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
      'login_type': loginType.toString(),
      'musickey_create_time': musicKeyCreatedAt.toString(),
      'key_expires_in': keyExpiresIn.toString(),
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

String _stringValue(Object? value) => value?.toString() ?? '';

int _intValue(Object? value) {
  if (value is int) {
    return value;
  }
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
