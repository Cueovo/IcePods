import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// Ambient colors derived from the pixels of a piece of artwork.
///
/// The palette is deliberately washed out: album art drives the ambient light
/// of the glass, but it never becomes a saturated full-screen fill.
@immutable
class ArtworkPalette {
  const ArtworkPalette({
    required this.primary,
    required this.secondary,
    required this.contrastScrim,
    required this.isLight,
  });

  /// Deterministic palette for missing artwork or failed sampling.
  static const neutral = ArtworkPalette(
    primary: Color(0xFF3C4557),
    secondary: Color(0xFF161A24),
    contrastScrim: Color(0x4D000000),
    isLight: false,
  );

  /// Largest sampled surface, in pixels, used for palette extraction.
  static const sampleExtent = 32;

  /// Derives a palette from raw RGBA pixels of a bounded artwork sample.
  ///
  /// Pixels are bucketed by hue and weighted towards vivid, mid-lightness
  /// content so a small colored subject still wins over a large flat
  /// background. Average luminance decides how strong the text scrim must be.
  factory ArtworkPalette.fromRawRgba(Uint8List rgba) {
    const buckets = 12;
    final weights = List<double>.filled(buckets, 0);
    final hues = List<double>.filled(buckets, 0);
    final saturations = List<double>.filled(buckets, 0);
    final lightnesses = List<double>.filled(buckets, 0);
    var luminanceSum = 0.0;
    var counted = 0;

    for (var i = 0; i + 3 < rgba.length; i += 4) {
      if (rgba[i + 3] < 8) {
        continue;
      }
      final red = rgba[i];
      final green = rgba[i + 1];
      final blue = rgba[i + 2];
      counted += 1;
      luminanceSum += (0.2126 * red + 0.7152 * green + 0.0722 * blue) / 255;
      final hsl = HSLColor.fromColor(Color.fromARGB(255, red, green, blue));
      // Vivid, mid-lightness pixels describe the artwork; the small constant
      // keeps monochrome covers from collapsing to an empty histogram.
      final vividness = (1 - (hsl.lightness - 0.5).abs() * 1.6).clamp(0.0, 1.0);
      final weight = hsl.saturation * vividness + 0.02;
      final bucket = (hsl.hue / 360 * buckets).floor() % buckets;
      weights[bucket] += weight;
      hues[bucket] += hsl.hue * weight;
      saturations[bucket] += hsl.saturation * weight;
      lightnesses[bucket] += hsl.lightness * weight;
    }

    if (counted == 0) {
      return neutral;
    }

    var best = 0;
    var runnerUp = 0;
    for (var bucket = 1; bucket < buckets; bucket += 1) {
      if (weights[bucket] > weights[best]) {
        runnerUp = best;
        best = bucket;
      } else if (weights[bucket] > weights[runnerUp]) {
        runnerUp = bucket;
      }
    }

    final averageLuminance = luminanceSum / counted;
    return ArtworkPalette(
      primary: _wash(
        weights: weights[best],
        hue: hues[best],
        saturation: saturations[best],
        lightness: lightnesses[best],
        targetLightness: 0.42,
        maxSaturation: 0.58,
      ),
      secondary: _wash(
        weights: weights[runnerUp],
        hue: hues[runnerUp],
        saturation: saturations[runnerUp],
        lightness: lightnesses[runnerUp],
        targetLightness: 0.2,
        maxSaturation: 0.5,
      ),
      // Bright artwork needs a heavier scrim to keep white text readable.
      contrastScrim: Color.fromRGBO(
        0,
        0,
        0,
        (0.22 + averageLuminance * 0.46).clamp(0.28, 0.66),
      ),
      isLight: averageLuminance > 0.6,
    );
  }

  final Color primary;
  final Color secondary;
  final Color contrastScrim;
  final bool isLight;

  static Color _wash({
    required double weights,
    required double hue,
    required double saturation,
    required double lightness,
    required double targetLightness,
    required double maxSaturation,
  }) {
    if (weights <= 0) {
      return targetLightness > 0.3 ? neutral.primary : neutral.secondary;
    }
    return HSLColor.fromAHSL(
      1,
      (hue / weights) % 360,
      (saturation / weights).clamp(0.12, maxSaturation),
      targetLightness,
    ).toColor();
  }

  @override
  bool operator ==(Object other) {
    return other is ArtworkPalette &&
        other.primary == primary &&
        other.secondary == secondary &&
        other.contrastScrim == contrastScrim &&
        other.isLight == isLight;
  }

  @override
  int get hashCode => Object.hash(primary, secondary, contrastScrim, isLight);
}

/// Bounded palette cache shared by every surface that renders artwork.
///
/// Sampling decodes at most [ArtworkPalette.sampleExtent] square pixels and
/// never blocks the first frame: callers read [peek] synchronously and repaint
/// once [resolve] completes.
abstract final class ArtworkPalettes {
  static const _maxEntries = 64;

  static final Map<String, ArtworkPalette> _cache = <String, ArtworkPalette>{};
  static final Map<String, Future<ArtworkPalette>> _pending =
      <String, Future<ArtworkPalette>>{};

  /// Returns an already sampled palette, or null when sampling has not run.
  static ArtworkPalette? peek(String key) => _cache[key];

  /// Samples [provider] once per [key] and caches the result.
  static Future<ArtworkPalette> resolve(String key, ImageProvider provider) {
    final cached = _cache[key];
    if (cached != null) {
      return SynchronousFuture(cached);
    }
    return _pending.putIfAbsent(key, () async {
      ArtworkPalette palette;
      try {
        palette = await _sample(provider);
      } on Object {
        palette = ArtworkPalette.neutral;
      }
      _pending.remove(key);
      _remember(key, palette);
      return palette;
    });
  }

  @visibleForTesting
  static void clear() {
    _cache.clear();
    _pending.clear();
  }

  static void _remember(String key, ArtworkPalette palette) {
    if (_cache.length >= _maxEntries) {
      _cache.remove(_cache.keys.first);
    }
    _cache[key] = palette;
  }

  static Future<ArtworkPalette> _sample(ImageProvider provider) async {
    final image = await _decode(
      ResizeImage.resizeIfNeeded(
        ArtworkPalette.sampleExtent,
        ArtworkPalette.sampleExtent,
        provider,
      ),
    );
    try {
      final pixels = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (pixels == null) {
        return ArtworkPalette.neutral;
      }
      return ArtworkPalette.fromRawRgba(pixels.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  }

  static Future<ui.Image> _decode(ImageProvider provider) {
    final completer = Completer<ui.Image>();
    final stream = provider.resolve(ImageConfiguration.empty);
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (info, synchronousCall) {
        stream.removeListener(listener);
        if (!completer.isCompleted) {
          completer.complete(info.image.clone());
        }
        info.dispose();
      },
      onError: (error, stackTrace) {
        stream.removeListener(listener);
        if (!completer.isCompleted) {
          completer.completeError(error, stackTrace);
        }
      },
    );
    stream.addListener(listener);
    return completer.future;
  }
}
