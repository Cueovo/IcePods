import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';

const MethodChannel _systemFeedbackChannel = MethodChannel(
  'qqmusic_ipod/system_feedback',
);

/// Classic iPod-style click for menu / wheel steps.
///
/// Uses a small [AudioPlayer] pool so rapid successive ticks can overlap
/// instead of being dropped by a single seek/play chain or a long debounce.
class ClickSoundService {
  ClickSoundService({
    List<AudioPlayer>? players,
    Future<void> Function()? nativeTick,
    bool? useNativeFeedback,
  }) : _nativeTick = nativeTick,
       _useNativeFeedback =
           useNativeFeedback ??
           nativeTick != null ||
               defaultTargetPlatform == TargetPlatform.android ||
               defaultTargetPlatform == TargetPlatform.iOS {
    _players = players;
  }

  static const int _poolSize = 3;
  static const int maxPendingTicks = 12;

  /// Minimum gap between ticks — short enough for fast scroll, long enough
  /// to ignore accidental double-fires from the same frame.
  static const Duration minInterval = Duration(milliseconds: 22);

  List<AudioPlayer>? _players;
  final Future<void> Function()? _nativeTick;
  final bool _useNativeFeedback;
  int _next = 0;
  bool _ready = false;
  bool _draining = false;
  bool _disposed = false;
  int _pendingTicks = 0;
  Timer? _drainTimer;

  Future<void> playTick() async {
    if (_disposed) {
      return;
    }
    if (_pendingTicks < maxPendingTicks) {
      _pendingTicks += 1;
    }
    _drain();
  }

  void _drain() {
    if (_disposed || _draining || _drainTimer != null || _pendingTicks == 0) {
      return;
    }
    _draining = true;
    unawaited(_playNext());
  }

  Future<void> _playNext() async {
    try {
      await _playOne();
    } catch (_) {}
    if (_disposed) {
      return;
    }
    _pendingTicks -= 1;
    _draining = false;
    _drainTimer = Timer(minInterval, () {
      _drainTimer = null;
      _drain();
    });
  }

  Future<void> _playOne() async {
    if (_useNativeFeedback && await _playNativeTick()) {
      return;
    }
    if (_disposed) {
      return;
    }
    try {
      await _ensureReady();
      if (_disposed) {
        return;
      }
      if (!_ready) {
        unawaited(SystemSound.play(SystemSoundType.click));
        return;
      }
      final players = _players!;
      final player = players[_next];
      _next = (_next + 1) % players.length;
      // Fire-and-forget: do not await play so the next tick can start immediately
      // on another pool member while this one is still sounding.
      unawaited(_playOn(player));
    } catch (_) {
      if (!_disposed) {
        unawaited(SystemSound.play(SystemSoundType.click));
      }
    }
  }

  Future<bool> _playNativeTick() async {
    try {
      final nativeTick = _nativeTick;
      if (nativeTick != null) {
        await nativeTick();
      } else {
        await _systemFeedbackChannel.invokeMethod<void>('playClick');
      }
      return true;
    } catch (_) {
      return false;
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
    if (_disposed || _ready || kIsWeb) {
      return;
    }
    final players = _players ??= List.generate(_poolSize, (_) => AudioPlayer());
    try {
      for (final player in players) {
        await player.setAsset('assets/sounds/click_tick.wav');
        await player.setVolume(0.42);
      }
      if (!_disposed) {
        _ready = true;
      }
    } catch (_) {
      _ready = false;
    }
  }

  void clearPendingTicks() {
    _pendingTicks = _draining ? 1 : 0;
    _drainTimer?.cancel();
    _drainTimer = null;
  }

  Future<void> dispose() async {
    _disposed = true;
    _pendingTicks = 0;
    _drainTimer?.cancel();
    final players = _players;
    if (players == null) {
      return;
    }
    for (final player in players) {
      await player.dispose();
    }
  }
}

class WheelHapticsService {
  WheelHapticsService({
    Future<void> Function(String method)? nativeFeedback,
    bool? useNativeFeedback,
  }) : _nativeFeedback = nativeFeedback,
       _useNativeFeedback =
           useNativeFeedback ??
           nativeFeedback != null ||
               defaultTargetPlatform == TargetPlatform.iOS;

  final Future<void> Function(String method)? _nativeFeedback;
  final bool _useNativeFeedback;

  Future<void> mediumImpact() =>
      _emit('mediumImpact', HapticFeedback.mediumImpact);

  Future<void> lightImpact() =>
      _emit('lightImpact', HapticFeedback.lightImpact);

  Future<void> selectionClick() =>
      _emit('selectionChanged', HapticFeedback.selectionClick);

  Future<void> _emit(String method, Future<void> Function() fallback) async {
    if (_useNativeFeedback) {
      try {
        final nativeFeedback = _nativeFeedback;
        if (nativeFeedback != null) {
          await nativeFeedback(method);
        } else {
          await _systemFeedbackChannel.invokeMethod<void>(method);
        }
        return;
      } catch (_) {}
    }
    await fallback();
  }
}
