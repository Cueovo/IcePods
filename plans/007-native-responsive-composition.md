# 007 — Create Native Portrait and Landscape Compositions

- **Status**: IMPLEMENTED
- **Commit**: pending
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

## Execution result

- `lib/core/utils/shell_layout_metrics.dart` resolves four modes from the viewport: compact portrait (`height < 700 || width < 360`, rail 136, wheel ≤ 244), standard portrait (rail 158, wheel ≤ 300), wide portrait (`shortestSide >= 600`, rail 190, wheel ≤ 340, chassis bounded to 720×1100), and landscape (rail 150, wheel ≤ 260, chassis height bounded to 620).
- The shell composition switches axis through a single `Flex` whose `direction` follows `metrics.isLandscape`, instead of duplicating the whole screen-module tree into a separate `Row`. Same result, far smaller diff, and `ChassisInsets`/cutout handling stays untouched.
- Landscape now also applies the left/right safe-area padding the vertical stack never needed, and centres the wheel instead of lowering it.
- `ClickWheel` accepts a `diameter`. The wheel stays authored at 300 and is scaled uniformly through `FittedBox`, so `_center`, `_ringHitMin`, the cardinal geometry, and hit testing all keep working in the authored space. The call site now derives the diameter from the wheel band with `wheelDiameterFor`, replacing the fixed `300 × 0.9`.
- `HomePanel` takes a `railWidth`, clamps it to 132–190, and additionally caps it at 56% of the available width so the preview never collapses on a narrow glass.
- `CoverFlowPanel` no longer uses the fixed 160/235 stage or 140px card. The stage is an `Expanded` region, the card is `min(stageHeight × .58, stageWidth × .42)` clamped to 72–168, and all 3D constants (105/25 translation, ±Z depth, 30px shadow) scale with the card. The reflection is clipped to a stage-relative floor plane, so it can no longer reach the metadata on a short viewport. Metadata width is `min(288, maxWidth - 24)`.
- Deviations, deliberate: the composition uses `Flex` rather than two separate trees, and tablet bounding is a `Center` + `ConstrainedBox` around the chassis content while the backdrop stays full-bleed, preserving the existing "chassis fills the device" behavior.
- `flutter analyze`: `No issues found!`. `flutter test`: 57 tests passing, including layout coverage at 320×568, 360×800, 390×844, 430×932, 844×390, 1.3× text scale, landscape/portrait wheel placement, short-stage Cover Flow, and card scaling.
- Physical-device checks still pending: landscape feel on a phone, tablet composition, and confirming the scaled wheel's semantic bounds with TalkBack.
