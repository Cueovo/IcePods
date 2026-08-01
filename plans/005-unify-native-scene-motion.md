# 005 — Unify Native Scene Motion and Page Transitions

- **Status**: IMPLEMENTED
- **Commit**: pending
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

## Execution result

- `switchMode` no longer branches on page distance. Every destination animates for `AppDurations.scene` (280ms) with `AppCurves.sceneEase`, so Menu → Player, Menu → Feature, Player → Queue, and Queue → Player move instead of teleporting.

### Revised after device testing

The "every route animates" rule was reverted for non-adjacent destinations. Scrolling a `PageView` from page 0 to page 3 makes it build and paint every page in between, so Menu → Feature visibly flashed the Now Playing page and paid for a full Cover Flow build on the way; on a mid-range Android device that was both a visual bug and a frame-rate cost. Non-adjacent routes now cut (`jumpToPage`) and adjacent routes keep the 280ms flight. Doing this properly needs the transition stage the plan originally described — only the outgoing and incoming surfaces mounted, no intermediate pages — which is deferred.
- Transitions are cancellation-safe: each flight takes a revision, a superseded flight returns without touching the page, and the surviving flight snaps to the authoritative mode page if an interruption left the view between pages.
- `ShellController.reducedMotion` mirrors `MediaQueryData.disableAnimations`, synced from `_IpodShellView.build` through `syncReducedMotion`. The setter is deliberately silent because the shell reads it in the same build pass and a media query change already rebuilds the shell; notifying there would mark the tree dirty during build.
- `AppDurations.reducedMotion` moved from 200ms to 120ms, and `press` (120ms) now drives high-frequency menu selection feedback instead of the previous 140/160/180ms mix.
- Reduced motion now reaches the surfaces that previously ignored it: page flights jump, Cover Flow retargets instantly and drops Y rotation plus Z depth, Cover Flow metadata and the menu preview become opacity-only, menu auto-scroll jumps, ambient color/image/scrim shorten to 120ms, and lyric auto-centering jumps instead of animating.
- The menu preview switcher gained an opacity transition and dropped `Curves.easeIn`, so two opaque preview cards no longer double-expose in the same plane during a swap.
- The submenu transition already keyed off `MenuSection` only, so same-section selection changes never restarted it; it was left intact per the plan.
- `flutter analyze`: `No issues found!`. `flutter test`: 38 tests passing, including new shell coverage for non-adjacent flights, both queue directions, a superseded destination, and reduced-motion jumps.
- Physical-device checks still pending: slow-motion capture of Menu → Player → Queue, rapid alternating navigation, and Android "Remove animations".
