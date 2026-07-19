import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/device.dart';

abstract interface class QqMusicDeviceStore {
  Future<QqMusicDevice> read();

  Future<void> write(QqMusicDevice device);
}

class SharedPreferencesQqMusicDeviceStore implements QqMusicDeviceStore {
  const SharedPreferencesQqMusicDeviceStore({
    this.storageKey = 'qq_music_direct_device.v1',
  });

  final String storageKey;

  @override
  Future<QqMusicDevice> read() async {
    final preferences = await SharedPreferences.getInstance();
    final encoded = preferences.getString(storageKey);
    if (encoded != null && encoded.isNotEmpty) {
      try {
        final decoded = jsonDecode(encoded);
        if (decoded is Map) {
          final device = QqMusicDevice.fromJson(
            Map<String, dynamic>.from(decoded),
          );
          if (device.hasValidIdentity) {
            return device;
          }
        }
      } catch (_) {}
    }
    final device = QqMusicDevice.random();
    await write(device);
    return device;
  }

  @override
  Future<void> write(QqMusicDevice device) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(storageKey, jsonEncode(device.toJson()));
  }
}

class MemoryQqMusicDeviceStore implements QqMusicDeviceStore {
  MemoryQqMusicDeviceStore([QqMusicDevice? device])
    : device = device ?? QqMusicDevice.random(Random(1));

  QqMusicDevice device;
  int readCount = 0;
  int writeCount = 0;

  @override
  Future<QqMusicDevice> read() async {
    readCount++;
    return device;
  }

  @override
  Future<void> write(QqMusicDevice value) async {
    device = value;
    writeCount++;
  }
}
