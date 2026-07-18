import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class QqMusicCacheEntry {
  const QqMusicCacheEntry({required this.value, required this.updatedAt});

  final Object? value;
  final DateTime updatedAt;

  bool isFresh(Duration maxAge, DateTime now) {
    return now.difference(updatedAt) <= maxAge;
  }
}

abstract interface class QqMusicCacheStore {
  Future<QqMusicCacheEntry?> read(String key);

  Future<void> write(String key, Object? value);

  Future<void> remove(String key);

  Future<void> clear();
}

class SharedPreferencesQqMusicCacheStore implements QqMusicCacheStore {
  const SharedPreferencesQqMusicCacheStore({this.namespace = 'qq_music_cache'});

  final String namespace;

  String _storageKey(String key) => '$namespace.$key';

  @override
  Future<QqMusicCacheEntry?> read(String key) async {
    final preferences = await SharedPreferences.getInstance();
    final encoded = preferences.getString(_storageKey(key));
    if (encoded == null || encoded.isEmpty) {
      return null;
    }
    try {
      final envelope = jsonDecode(encoded) as Map<String, dynamic>;
      final updatedAt = DateTime.tryParse(
        envelope['updated_at']?.toString() ?? '',
      );
      if (updatedAt == null || envelope['version'] != 1) {
        await remove(key);
        return null;
      }
      return QqMusicCacheEntry(
        value: envelope['value'],
        updatedAt: updatedAt.toUtc(),
      );
    } catch (_) {
      await remove(key);
      return null;
    }
  }

  @override
  Future<void> write(String key, Object? value) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _storageKey(key),
      jsonEncode({
        'version': 1,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
        'value': value,
      }),
    );
  }

  @override
  Future<void> remove(String key) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_storageKey(key));
  }

  @override
  Future<void> clear() async {
    final preferences = await SharedPreferences.getInstance();
    final prefix = '$namespace.';
    final keys = preferences.getKeys().where((key) => key.startsWith(prefix));
    for (final key in keys.toList(growable: false)) {
      await preferences.remove(key);
    }
  }
}

class MemoryQqMusicCacheStore implements QqMusicCacheStore {
  MemoryQqMusicCacheStore({DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;
  final Map<String, QqMusicCacheEntry> entries = {};

  @override
  Future<QqMusicCacheEntry?> read(String key) async => entries[key];

  @override
  Future<void> write(String key, Object? value) async {
    entries[key] = QqMusicCacheEntry(value: value, updatedAt: _clock().toUtc());
  }

  @override
  Future<void> remove(String key) async {
    entries.remove(key);
  }

  @override
  Future<void> clear() async {
    entries.clear();
  }
}
