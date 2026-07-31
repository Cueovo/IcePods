# 005 — Unify Native Scene Motion and Page Transitions

- **Status**: TODO
- **Commit**: 60c800d
- **Severity**: HIGH
- **Category**: Purpose & frequency; Easing & duration; Interruptibility; Accessibility
- **Estimated scope**: 5 source files, medium implementation

## Problem

`ShellController.switchMode` jumps whenever pages are more than one index apart, but animates adjacent pages for 550ms. This makes Menu → Player, Menu → Feature, Player → Queue, and Queue → Player teleport while less important transitions take longer than the UI budget.

```dart
// lib/features/shell/state/shell_controller.dart:204-231
if ((targetPage - currentPage).abs() > 1) {
  pageController.jumpToPage(targetPage);
  return;
}
await pageController.animateToPage(
  targetPage,
  duration: const Duration(milliseconds: 550),
  curve: const Cubic(.25, 1, .25, 1),
);
```

The primary page animation also has no reduced-motion branch. Other surfaces independently use different durations, so the app has no single motion grammar.

## Target

Define native motion tokens in `AppDurations` and `AppCurves`:

```dart
static const press = Duration(milliseconds: 120);
static const scene = Duration(milliseconds: 280);
static const reducedMotion = Duration(milliseconds: 120);
static const sceneEase = Cubic(0.23, 1, 0.32, 1);
static const movementEase = Cubic(0.77, 0, 0.175, 1);
```

Normal mode transitions:

- Every mode change uses one consistent 280ms scene transition; no non-adjacent `jumpToPage`.
- Incoming content enters quickly with `sceneEase`.
- Outgoing content exits early enough to avoid double exposure.
- Repeated input retargets the current animation instead of waiting for a prior future.
- Frequent menu selection remains 100–160ms and must not reuse the scene transition.

Reduced-motion mode:

- Use a 120ms opacity-only transition or direct page jump.
- Remove translation, scale, Cover Flow rotation, ambient parallax, and automatic scroll movement.
- Retain a small opacity/color change so state changes remain comprehensible.

## Steps

1. Add the exact native motion tokens to `lib/core/theme/tokens/app_tokens.dart`.
2. Add a `reducedMotion` state to `ShellController` with an idempotent setter. In `_IpodShellView`, update it from `MediaQuery.maybeOf(context)?.disableAnimations` before rendering.
3. Replace the distance-based branch in `switchMode` with one consistent native transition. In normal mode, animate all target pages using `AppDurations.scene` and `AppCurves.sceneEase`; in reduced mode, jump or use the 120ms opacity-only path.
4. Make `switchMode` cancellation-safe: a new destination must supersede the previous transition and no stale completion may reset `pageIndex` or mode.
5. Update `AmbientBackground`, `CoverFlowPanel`, `HomePanel`, and `NowPlayingPanel` to consume the same reduced-motion state and token values. Do not add separate hard-coded durations.
6. Keep the existing submenu directional transition but ensure it does not restart on rapid same-section selection changes.
7. Add widget tests for Menu → Player, Player → Queue, Queue → Player, and reduced-motion transitions.

## Boundaries

- Native Android/iOS app only.
- Do NOT modify `ambient_background_web.dart` or add Web-specific transitions.
- Do NOT redesign the content of Menu, Queue, or Now Playing in this plan.
- Do NOT use bounce or spring overshoot for page-level navigation.
- Do NOT leave a 550ms page transition or distance-based jump branch after implementation.

## Verification

- **Mechanical**: run `flutter analyze` and `flutter test`.
- **Feel check**: record Menu → Player → Queue → Player at normal speed and slow motion. Every destination must have a spatially understandable response; no route may teleport.
- **Interruptibility**: rapidly alternate Menu, Player, Queue, and Back. The current transition must retarget without ghost pages or waiting pauses.
- **Reduced motion**: enable Android Remove Animations and verify there is no translation, scale, 3D motion, or auto-scroll.
- **Performance**: confirm no transition exceeds 280ms and no frame drops during repeated navigation on a representative Android device.
- **Done when**: all native mode routes share a coherent transition grammar, reduced motion is honored globally, and no page-index distance determines whether a route animates.
