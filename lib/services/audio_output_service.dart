import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class AudioOutputService {
  const AudioOutputService();

  static const _channel = MethodChannel('qqmusic_ipod/audio_output');

  Future<String> currentOutputName() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return '';
    }
    try {
      return await _channel.invokeMethod<String>('getCurrentOutputName') ?? '';
    } on PlatformException {
      return '';
    } on MissingPluginException {
      return '';
    }
  }
}
