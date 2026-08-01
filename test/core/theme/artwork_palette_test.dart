import 'dart:typed_data';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qqmusic_ipod/core/theme/artwork/artwork_palette.dart';

Uint8List _solid(int red, int green, int blue, {int alpha = 255}) {
  final pixels = Uint8List(4 * 64);
  for (var i = 0; i < pixels.length; i += 4) {
    pixels[i] = red;
    pixels[i + 1] = green;
    pixels[i + 2] = blue;
    pixels[i + 3] = alpha;
  }
  return pixels;
}

void main() {
  setUp(ArtworkPalettes.clear);

  test('derives a washed ambient color from vivid artwork', () {
    final palette = ArtworkPalette.fromRawRgba(_solid(0xE0, 0x30, 0x30));
    final primary = HSLColor.fromColor(palette.primary);

    expect(primary.hue, closeTo(0, 12));
    expect(primary.saturation, closeTo(0.58, 0.001));
    expect(primary.lightness, closeTo(0.42, 0.001));
    expect(palette.isLight, isFalse);
  });

  test('keeps monochrome artwork subtle instead of neon', () {
    final palette = ArtworkPalette.fromRawRgba(_solid(0x80, 0x80, 0x80));

    expect(HSLColor.fromColor(palette.primary).saturation, closeTo(0.12, 0.01));
  });

  test('strengthens the scrim for bright artwork', () {
    final bright = ArtworkPalette.fromRawRgba(_solid(0xFF, 0xFF, 0xFF));
    final dark = ArtworkPalette.fromRawRgba(_solid(0x0A, 0x0A, 0x0C));

    expect(bright.isLight, isTrue);
    expect(dark.isLight, isFalse);
    expect(bright.contrastScrim.a, greaterThan(dark.contrastScrim.a));
    expect(bright.contrastScrim.a, closeTo(0.66, 0.01));
    expect(dark.contrastScrim.a, closeTo(0.28, 0.01));
  });

  test('falls back to the neutral palette without opaque pixels', () {
    expect(
      ArtworkPalette.fromRawRgba(_solid(0xFF, 0x00, 0x00, alpha: 0)),
      ArtworkPalette.neutral,
    );
    expect(ArtworkPalette.fromRawRgba(Uint8List(0)), ArtworkPalette.neutral);
  });

  testWidgets('caches sampling results and survives decode failures', (
    tester,
  ) async {
    final palette = await ArtworkPalettes.resolve(
      'missing-artwork',
      const NetworkImage('https://example.invalid/cover.jpg'),
    );

    expect(palette, ArtworkPalette.neutral);
    expect(ArtworkPalettes.peek('missing-artwork'), ArtworkPalette.neutral);
    expect(ArtworkPalettes.peek('never-sampled'), isNull);
  });
}
