import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Platform-sourced display metrics (iOS continuous corner radius, etc.).
///
/// Call [warmUp] once at startup so the first frame can use a real value
/// instead of a short-side heuristic table.
class DeviceDisplayMetrics {
  DeviceDisplayMetrics._();

  static const MethodChannel _channel = MethodChannel('qqmusic_ipod/device');

  /// Cached `UIScreen` continuous corner radius in logical points, or null.
  static double? _displayCornerRadius;

  /// Override for tests.
  @visibleForTesting
  static void debugSetDisplayCornerRadius(double? value) {
    _displayCornerRadius = value;
  }

  static double? get displayCornerRadius => _displayCornerRadius;

  /// Load native metrics (no-op off iOS / when channel unavailable).
  static Future<void> warmUp() async {
    if (kIsWeb) {
      return;
    }
    try {
      if (!Platform.isIOS) {
        return;
      }
    } catch (_) {
      return;
    }
    try {
      final value = await _channel.invokeMethod<dynamic>('displayCornerRadius');
      if (value is num && value > 0) {
        _displayCornerRadius = value.toDouble();
      }
    } catch (_) {
      // Keep heuristic fallback in ScreenCornerRadius.
    }
  }

  /// Native scene/app lifecycle lines for Now Playing wake diagnosis.
  static Future<List<String>> readWakeDiag() async {
    if (kIsWeb) {
      return const [];
    }
    try {
      if (!Platform.isIOS) {
        return const [];
      }
      final value = await _channel.invokeMethod<dynamic>('readWakeDiag');
      if (value is List) {
        return value.map((e) => e.toString()).toList(growable: false);
      }
    } catch (_) {}
    return const [];
  }

  static Future<void> clearWakeDiag() async {
    if (kIsWeb) {
      return;
    }
    try {
      if (!Platform.isIOS) {
        return;
      }
      await _channel.invokeMethod<void>('clearWakeDiag');
    } catch (_) {}
  }

  static Future<void> markWakeDiag(String label) async {
    if (kIsWeb) {
      return;
    }
    try {
      if (!Platform.isIOS) {
        return;
      }
      await _channel.invokeMethod<void>('markWakeDiag', label);
    } catch (_) {}
  }

  /// Logs self PID vs MediaRemote now-playing app PID and returns full log.
  static Future<List<String>> probeWakeDiag([String reason = 'manual']) async {
    if (kIsWeb) {
      return const [];
    }
    try {
      if (!Platform.isIOS) {
        return const [];
      }
      final value = await _channel.invokeMethod<dynamic>('probeWakeDiag', reason);
      if (value is List) {
        return value.map((e) => e.toString()).toList(growable: false);
      }
    } catch (_) {}
    return readWakeDiag();
  }
}
