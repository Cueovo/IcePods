import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists the iPod body (chassis) color outside the screen and click wheel.
class ChassisColorStore {
  ChassisColorStore({this._preferences});

  static const _key = 'ipod.chassis_color';
  static const defaultColor = Color(0xFFC8C8C8);

  SharedPreferences? _preferences;

  Future<SharedPreferences> _prefs() async {
    return _preferences ??= await SharedPreferences.getInstance();
  }

  Future<Color> load() async {
    final raw = (await _prefs()).getInt(_key);
    if (raw == null) {
      return defaultColor;
    }
    return Color(raw);
  }

  Future<void> save(Color color) async {
    await (await _prefs()).setInt(_key, _toArgb(color));
  }

  static int _toArgb(Color color) {
    final a = (color.a * 255.0).round() & 0xff;
    final r = (color.r * 255.0).round() & 0xff;
    final g = (color.g * 255.0).round() & 0xff;
    final b = (color.b * 255.0).round() & 0xff;
    return (a << 24) | (r << 16) | (g << 8) | b;
  }
}
