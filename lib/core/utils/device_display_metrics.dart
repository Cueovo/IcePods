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
}
