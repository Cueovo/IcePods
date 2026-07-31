# 007 — Create Native Portrait and Landscape Compositions

- **Status**: TODO
- **Commit**: 60c800d
- **Severity**: HIGH
- **Category**: Responsive composition; Accessibility; Performance
- **Estimated scope**: 5 source files, medium layout refactor

## Problem

The native shell is authored as a fixed vertical object: screen flex 56, wheel flex 44, wheel design size 300, HomePanel rail 158, and Cover Flow card/stage sizes that assume portrait height.

```dart
// lib/features/shell/views/pages/ipod_screen.dart:183-190
Expanded(flex: 56, child: ...)

// lib/core/theme/widgets/click_wheel.dart:31-36
static const double _size = 300;

// lib/features/shell/views/widgets/home_panel.dart:8-10
const double _menuTileHeight = 48;
const double _menuTileGap = 5;
```

Landscape is supported by platform configuration, but the main composition remains vertical and the only shell test is a 390×844 portrait surface.

## Target

Implement native-only composition modes based on `MediaQuery.sizeOf(context)`, safe insets, and text scale:

- **Compact portrait**: height < 700 or width < 360. Preserve the device silhouette, reduce the menu rail to 132–144 logical pixels, and keep primary buttons at least 48×48.
- **Standard portrait**: current menu/screen/wheel hierarchy, with wheel diameter derived from available height rather than fixed 300×0.9.
- **Landscape phone**: place the glass screen and wheel side-by-side; the glass receives the larger horizontal allocation and the wheel receives a bounded square region.
- **Tablet/native desktop window**: center a bounded chassis with maximum width/height instead of stretching every child indefinitely.

Cover Flow must derive stage height, card size, reflection length, and side translation from constraints. Never allow reflection to overlap metadata. HomePanel must derive rail width from available width and clamp it to 132–190.

## Steps

1. Add an app-only `ShellLayoutMetrics` resolver under `lib/core/utils/` with the four layout modes and exact values above.
2. Update `_IpodShellView` to use a `Row` for landscape and the existing `Column` for portrait. Keep safe-area/cutout handling from `ChassisInsets`.
3. Pass a resolved wheel size to `ClickWheel` instead of always using `_size = 300`; preserve the existing hit-test coordinate system by scaling the complete wheel widget uniformly.
4. Update `HomePanel` to accept a constrained rail width and use proportional preview width.
5. Update `CoverFlowPanel` to compute its card/stage/reflection geometry from `LayoutBuilder` constraints and expose a reduced-height fallback that keeps metadata visible.
6. Add native widget tests at 320×568, 360×800, 390×844, 430×932, and 844×390. Include 1.3× text scale.

## Boundaries

- This plan is for Android/iOS app layouts only.
- Do NOT modify Web behavior, browser breakpoints, `ambient_background_web.dart`, or web platform views.
- Do NOT change the product's iPod silhouette in standard portrait mode.
- Do NOT reduce primary touch/semantic targets below 48×48.
- Do NOT redesign individual feature data or playback logic.

## Verification

- **Mechanical**: run `flutter analyze` and all widget tests.
- **Layout**: no RenderFlex overflow at every listed size and at text scales 1.0, 1.3, and 2.0.
- **Feel check**: portrait remains recognizably iPod-like; landscape feels intentionally composed rather than vertically compressed.
- **Cover Flow**: reflection ends before metadata and cards remain centered at all tested heights.
- **Accessibility**: primary buttons retain at least 48×48 semantic bounds after any visual scaling.
- **Done when**: native portrait and landscape are deliberate compositions, not the same portrait layout squeezed into a different aspect ratio.
