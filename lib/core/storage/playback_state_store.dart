import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:qqmusic_ipod/business/entities/music.dart';

class QqMusicPlaybackSnapshot {
  const QqMusicPlaybackSnapshot({
    required this.currentSong,
    required this.queue,
    required this.position,
    required this.duration,
    required this.playbackMode,
  });

  factory QqMusicPlaybackSnapshot.fromJson(Map<String, dynamic> json) {
    final currentSongJson = json['current_song'];
    final queueJson = json['queue'];
    final modeName = json['playback_mode'];
    return QqMusicPlaybackSnapshot(
      currentSong: currentSongJson is Map
          ? QqMusicItem.fromJson(Map<String, dynamic>.from(currentSongJson))
          : null,
      queue: queueJson is List
          ? queueJson
                .whereType<Map>()
                .map(
                  (item) =>
                      QqMusicItem.fromJson(Map<String, dynamic>.from(item)),
                )
                .where((item) => item.isSong)
                .toList(growable: false)
          : const [],
      position: Duration(milliseconds: _nonNegativeInt(json['position_ms'])),
      duration: Duration(milliseconds: _nonNegativeInt(json['duration_ms'])),
      playbackMode: QqMusicPlaybackMode.values.firstWhere(
        (mode) => mode.name == modeName,
        orElse: () => QqMusicPlaybackMode.sequential,
      ),
    );
  }

  final QqMusicItem? currentSong;
  final List<QqMusicItem> queue;
  final Duration position;
  final Duration duration;
  final QqMusicPlaybackMode playbackMode;

  Map<String, dynamic> toJson() {
    return {
      'current_song': currentSong?.toJson(),
      'queue': queue.map((item) => item.toJson()).toList(growable: false),
      'position_ms': position.inMilliseconds,
      'duration_ms': duration.inMilliseconds,
      'playback_mode': playbackMode.name,
    };
  }

  static int _nonNegativeInt(Object? value) {
    if (value is int) {
      return value < 0 ? 0 : value;
    }
    if (value is num) {
      return value < 0 ? 0 : value.toInt();
    }
    return 0;
  }
}

class QqMusicPlaybackStateStore {
  QqMusicPlaybackStateStore({this._preferences});

  static const _key = 'qq_music.playback_state.v1';

  SharedPreferences? _preferences;

  Future<SharedPreferences> _prefs() async {
    return _preferences ??= await SharedPreferences.getInstance();
  }

  Future<QqMusicPlaybackSnapshot?> load() async {
    final encoded = (await _prefs()).getString(_key);
    if (encoded == null || encoded.isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! Map) {
        return null;
      }
      return QqMusicPlaybackSnapshot.fromJson(
        Map<String, dynamic>.from(decoded),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> save(QqMusicPlaybackSnapshot snapshot) async {
    await (await _prefs()).setString(_key, jsonEncode(snapshot.toJson()));
  }

  Future<void> clear() async {
    await (await _prefs()).remove(_key);
  }
}
