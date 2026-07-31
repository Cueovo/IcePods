# 004 — Make Album Artwork Drive the App Atmosphere

- **Status**: TODO
- **Commit**: 60c800d
- **Severity**: HIGH
- **Category**: Cohesion; Performance; Accessibility
- **Estimated scope**: 6 source files, medium implementation

## Problem

Ambient color is currently selected from URL or menu-entry code-unit seeds rather than the actual image content. `AmbientBackground` uses a fixed accent list, while `MenuArtwork` has a separate accent list. Custom backgrounds bypass the artwork treatment, and Now Playing, Cover Flow, and Queue do not share a common artwork stage.

Current evidence:

```dart
// lib/features/shell/views/widgets/ambient_background.dart:24-32
static const _accents = [
  Color(0xFF31C27C),
  Color(0xFF5A8DEE),
  Color(0xFFE15D8A),
  Color(0xFFF0A44B),
  Color(0xFF8B6BE8),
];

// lib/features/shell/views/widgets/ambient_background.dart:110-114
final seed = widget.imageUrl.codeUnits.fold<int>(
  0,
  (sum, value) => sum + value,
);
final accent = _accents[seed % _accents.length];
```

```dart
// lib/features/shell/views/widgets/ambient_background.dart:159-174
Image.file(
  File(customImagePath),
  fit: BoxFit.cover,
  ...
)
```

The mobile ambient layer also uses a full-screen sigma-44 blur and retains previous and incoming layers during switching:

```dart
// lib/features/shell/views/widgets/ambient_background.dart:148-196
ImageFilter.blur(sigmaX: 44, sigmaY: 44)
```

## Target

Introduce an app-only `ArtworkPalette` model containing:

```dart
class ArtworkPalette {
  const ArtworkPalette({
    required this.primary,
    required this.secondary,
    required this.contrastScrim,
    required this.isLight,
  });

  final Color primary;
  final Color secondary;
  final Color contrastScrim;
  final bool isLight;
}
```

For each displayed artwork/background:

- Decode a bounded thumbnail no larger than 32×32 for sampling.
- Compute average luminance and two weighted dominant colors.
- Clamp saturation and lightness so the result remains a dark ambient wash, not a neon fill.
- Choose a stronger local scrim for bright imagery.
- Cache by image URL/path and target palette version.
- Keep the existing previous-image-until-preloaded behavior.

Create an `ArtworkStage` or equivalent shared rendering helper used by Ambient, Now Playing, Cover Flow, and Queue. It must own the artwork corner radius, scrim, keyline, and transition identity. Do not duplicate four separate artwork treatments.

The mobile ambient result should use a low-resolution blurred source or a bounded filtered region rather than blurring a full-resolution display surface with sigma 44. Target mobile blur sigma: 18–24 on a reduced source surface. Preserve a 1.16–1.24 scale-up to hide blur edges.

## Repo conventions to follow

- Keep image loading in `lib/core/theme/widgets/artwork_image.dart` and preserve its decode-size behavior for list thumbnails.
- Keep mobile platform-specific background code in `lib/features/shell/views/widgets/ambient_background.dart`.
- Keep app visuals behind `RepaintBoundary` when the source image is stable.
- Reuse `AppRadii.artwork` and the semantic colors from plan 003.

## Steps

1. Add the `ArtworkPalette` data model and a bounded mobile palette sampler under `lib/core/theme/artwork/`. Use the existing image loading stack; do not add a web implementation.
2. Add a cache keyed by resolved image URL or custom image path. Ensure failed sampling returns a deterministic neutral palette and never blocks the first frame.
3. Update `AmbientBackground` to request the palette and use its colors instead of `_accents` and URL-seed selection.
4. Apply the calculated scrim to custom backgrounds as well as network artwork. Bright custom photos must not bypass contrast treatment.
5. Update `ArtworkImage`/`ArtworkStage` variants so the fallback icon scales with the available box instead of always using size 48.
6. Feed the same palette to Now Playing, Cover Flow, and Queue current-item treatment. The interaction accent remains separate and stable.
7. Replace the full-screen sigma-44 mobile blur with a reduced-source or bounded blur implementation and profile before/after raster time.

## Boundaries

- This plan targets native Android/iOS only.
- Do NOT modify `lib/features/shell/views/widgets/ambient_background_web.dart`.
- Do NOT add browser platform-view behavior or web CORS handling.
- Do NOT change playback state, queue semantics, or image URLs.
- Do NOT make the entire UI inherit the album hue; interaction, VIP, error, and brand colors remain semantic.

## Verification

- **Mechanical**: run `flutter analyze` and `flutter test`.
- **Visual**: test dark, bright, monochrome, red, yellow, and custom-photo backgrounds. The same track must produce the same ambient family in Player, Cover Flow, and Queue.
- **Contrast**: verify title/meta text over a bright custom photo and a white album cover.
- **Performance**: profile menu navigation and track changes in Flutter DevTools; no full-screen filter spike should exceed the existing frame budget on a representative Android device.
- **Done when**: ambient color is derived from image content, custom backgrounds receive the same scrim pipeline, and the app has one shared artwork treatment on native platforms.
