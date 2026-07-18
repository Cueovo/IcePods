import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'qq_music_models.dart';

abstract interface class QqMusicCredentialStore {
  Future<QqMusicCredential?> read();

  Future<void> write(QqMusicCredential credential);

  Future<void> clear();
}

class SecureQqMusicCredentialStore implements QqMusicCredentialStore {
  const SecureQqMusicCredentialStore([
    this._storage = const FlutterSecureStorage(),
  ]);

  final FlutterSecureStorage _storage;

  static const _keys = <String>{
    'musicid',
    'musickey',
    'openid',
    'refresh_token',
    'access_token',
    'expired_at',
    'unionid',
    'str_musicid',
    'refresh_key',
    'encrypt_uin',
    'encryptUin',
  };

  @override
  Future<QqMusicCredential?> read() async {
    final values = await _storage.readAll();
    final json = <String, dynamic>{
      for (final key in _keys)
        if (values[key] != null) key: values[key],
    };
    if (json['musicid'] == null || json['musickey'] == null) {
      return null;
    }
    final credential = QqMusicCredential.fromJson(json);
    return credential.isValid ? credential : null;
  }

  @override
  Future<void> write(QqMusicCredential credential) async {
    for (final entry in credential.toStorage().entries) {
      await _storage.write(key: entry.key, value: entry.value);
    }
  }

  @override
  Future<void> clear() async {
    for (final key in _keys) {
      await _storage.delete(key: key);
    }
  }
}

class MemoryQqMusicCredentialStore implements QqMusicCredentialStore {
  QqMusicCredential? credential;

  @override
  Future<void> clear() async {
    credential = null;
  }

  @override
  Future<QqMusicCredential?> read() async => credential;

  @override
  Future<void> write(QqMusicCredential value) async {
    credential = value;
  }
}
