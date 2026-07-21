import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';

/// Classic iPod-style click for menu / wheel steps.
///
/// Uses a small [AudioPlayer] pool so rapid successive ticks can overlap
/// instead of being dropped by a single seek/play chain or a long debounce.
class ClickSoundService {
  ClickSoundService({List<AudioPlayer>? players})
    : _players = players ?? List.generate(_poolSize, (_) => AudioPlayer());

  static const int _poolSize = 3;

  /// Minimum gap between ticks — short enough for fast scroll, long enough
  /// to ignore accidental double-fires from the same frame.
  static const Duration minInterval = Duration(milliseconds: 22);

  final List<AudioPlayer> _players;
  int _next = 0;
  bool _ready = false;
  bool _loading = false;
  DateTime _lastPlay = DateTime.fromMillisecondsSinceEpoch(0);

  Future<void> playTick() async {
    final now = DateTime.now();
    if (now.difference(_lastPlay) < minInterval) {
      return;
    }
    _lastPlay = now;
    try {
      await _ensureReady();
      if (!_ready) {
        unawaited(SystemSound.play(SystemSoundType.click));
        return;
      }
      final player = _players[_next];
      _next = (_next + 1) % _players.length;
      // Fire-and-forget: do not await play so the next tick can start immediately
      // on another pool member while this one is still sounding.
      unawaited(_playOn(player));
    } catch (_) {
      unawaited(SystemSound.play(SystemSoundType.click));
    }
  }

  Future<void> _playOn(AudioPlayer player) async {
    try {
      await player.seek(Duration.zero);
      await player.play();
    } catch (_) {
      // Swallow per-player glitches; next tick uses another member.
    }
  }

  Future<void> _ensureReady() async {
    if (_ready || _loading || kIsWeb) {
      return;
    }
    _loading = true;
    try {
      for (final player in _players) {
        await player.setAsset('assets/sounds/click_tick.wav');
        await player.setVolume(0.42);
      }
      _ready = true;
    } catch (_) {
      _ready = false;
    } finally {
      _loading = false;
    }
  }

  Future<void> dispose() async {
    for (final player in _players) {
      await player.dispose();
    }
  }
}
