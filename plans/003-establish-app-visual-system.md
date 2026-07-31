# 003 — Establish the App Visual System

- **Status**: TODO
- **Commit**: 60c800d
- **Severity**: HIGH
- **Category**: Cohesion & tokens; Typography; Accessibility
- **Estimated scope**: 7 source files, 1 optional licensed font asset set, medium refactor

## Problem

The app has a strong device concept, but its visual language is split between lavender interaction states, QQ green, five pseudo-random menu accents, one-off queue gradients, and many direct `TextStyle`/`Color` literals. Typography also defines `regular` as `FontWeight.w700`, so titles, labels, and metadata have little hierarchy.

Current evidence:

```dart
// lib/core/theme/tokens/app_tokens.dart:3-16
static const accent = Color(0xFF9D86FF);
static const success = Color(0xFFC8B6FF);

// lib/core/theme/tokens/app_tokens.dart:46-70
static const FontWeight regular = FontWeight.w700;
static const FontWeight strong = FontWeight.w800;
static const FontWeight heavy = FontWeight.w900;
```

```dart
// lib/main.dart:109-113
fontFamily: 'sans-serif',
```

The following files bypass the small token system with local visual values and must be migrated in this plan: `lib/features/shell/views/widgets/home_panel.dart`, `lib/features/shell/views/widgets/menu_artwork.dart`, `lib/features/player/views/pages/now_playing_panel.dart`, `lib/features/player/views/widgets/playback_queue_panel.dart`, `lib/features/library/views/widgets/media_tile.dart`, and `lib/features/discover/views/widgets/home_feed_card.dart`.

## Target

Create a semantic app-only design system with these exact roles:

```dart
abstract final class AppColors {
  static const canvas = Color(0xFF090A0F);
  static const interaction = Color(0xFF9D86FF);
  static const interactionSoft = Color(0x339D86FF);
  static const interactionBorder = Color(0x809D86FF);
  static const brandQq = Color(0xFF31C27C);
  static const vip = Color(0xFFF2C14E);
  static const danger = Color(0xFFFFA8A8);
  static const textPrimary = Color(0xF2FFFFFF);
  static const textSecondary = Color(0xB3FFFFFF);
  static const textTertiary = Color(0x80FFFFFF);
  static const textMuted = Color(0x66FFFFFF);
  static const glassLow = Color(0x14FFFFFF);
  static const glassMid = Color(0x26FFFFFF);
  static const border = Color(0x24FFFFFF);
}
```

Use the following typography roles, with no global font weight below 400 or above 800 except display moments:

```dart
micro:   11 / 14, weight 500
meta:    12 / 16, weight 500
body:    14 / 19, weight 550 or 600
label:   15 / 18, weight 600
title:   20 / 24, weight 700
display: 28–36 / 32–40, weight 800
```

If a licensed CJK font is provided, register it under `assets/fonts/` and use the same family in `ThemeData` for Android and iOS. Do not add an unlicensed font or a new package. If no font asset is available, keep the platform fallback but still apply the semantic weights and sizes.

All selected/current states use `AppColors.interaction`; QQ green is reserved for QQ identity, online/service state, and explicit brand moments. VIP/error colors remain semantic and are not used as decorative accents.

## Repo conventions to follow

- Keep colors and text roles in `lib/core/theme/tokens/app_tokens.dart`.
- Keep `AppRadii`, `AppDurations`, and `AppCurves` in the same token file.
- Preserve the existing dark glass identity and the existing `IpodShellTheme` extension.
- Do not make every component purple; `interaction` is a state color, not a page background.

## Steps

1. Extend `AppColors` and `AppTextStyles` in `lib/core/theme/tokens/app_tokens.dart` with the exact roles above. Preserve compatibility aliases for `accent`, `accentSoft`, `accentBorder`, `error`, and `success` until all call sites migrate.
2. Update `ThemeData` in `lib/main.dart` to use the selected licensed font family when available, and map Material text roles to the semantic `AppTextStyles` roles without changing the app's dark `ColorScheme` behavior.
3. Migrate direct text styles in the six listed high-visibility widgets to semantic roles. Do not change layout geometry in this plan.
4. Replace pseudo-random menu accent colors in `menu_artwork.dart` with the interaction/brand/state roles. Keep chassis color swatches as actual chassis colors.
5. Replace queue, player, and menu literals that represent selection/current state with `AppColors.interaction` and its alpha variants.
6. Add tests that render the menu, player, queue, and media tile with the same token expectations and verify no overflow at text scales 1.0 and 1.3.

## Boundaries

- Do NOT redesign page composition or add web-specific behavior.
- Do NOT touch `lib/features/shell/views/widgets/ambient_background_web.dart`.
- Do NOT introduce a color-extraction dependency in this plan.
- Do NOT change playback behavior, queue logic, or API models.
- Do NOT use a font without a license supplied by the product owner.

## Verification

- **Mechanical**: run `dart format` on changed Dart files, `flutter analyze`, and `flutter test`.
- **Visual**: compare menu, Cover Flow, Now Playing, queue, and feature pages side by side; selected/current states must share one interaction hue.
- **Typography**: verify CJK and Latin baselines, title/meta contrast, and numeric time alignment on Android and iOS.
- **Accessibility**: test text scales 1.0, 1.3, and 2.0; no title/subtitle overlap or clipped text.
- **Done when**: the six high-visibility surfaces use semantic tokens, regular text no longer defaults to w700, and no visual state color is chosen by component-specific literals.
