import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';

class ClickSoundService {
  ClickSoundService({AudioPlayer? player}) : _player = player ?? AudioPlayer();

  final AudioPlayer _player;
  bool _ready = false;
  bool _loading = false;
  DateTime _lastPlay = DateTime.fromMillisecondsSinceEpoch(0);

  Future<void> playTick() async {
    final now = DateTime.now();
    if (now.difference(_lastPlay) < const Duration(milliseconds: 55)) {
      return;
    }
    _lastPlay = now;
    try {
      await _ensureReady();
      if (!_ready) {
        await SystemSound.play(SystemSoundType.click);
        return;
      }
      await _player.seek(Duration.zero);
      unawaited(_player.play());
    } catch (_) {
      await SystemSound.play(SystemSoundType.click);
    }
  }

  Future<void> _ensureReady() async {
    if (_ready || _loading || kIsWeb) {
      return;
    }
    _loading = true;
    try {
      await _player.setAsset('assets/sounds/click_tick.wav');
      await _player.setVolume(0.42);
      _ready = true;
    } catch (_) {
      _ready = false;
    } finally {
      _loading = false;
    }
  }

  Future<void> dispose() async {
    await _player.dispose();
  }
}
