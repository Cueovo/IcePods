# 001 — Polish and stabilize submenu transitions

- **Status**: IMPLEMENTED — DEVICE CHECK PENDING
- **Commit**: a5f8a19
- **Severity**: HIGH
- **Category**: Easing & duration; Performance; Accessibility
- **Estimated scope**: 2 source files, about 55 changed lines

## Problem

The menu section transition feels visually muddy and can stutter because the complete transparent outgoing and incoming `HomePanel` trees overlap for the full transition. Each tree contains a preview card with a `BackdropFilter`, so rapid center/MENU input can leave multiple expensive outgoing children alive.

`lib/features/shell/views/pages/ipod_screen.dart:364-402` currently uses a large asymmetric translation, a full-duration symmetric crossfade, and retains every outgoing child:

```dart
final enteringOffset = _isForward
    ? const Offset(.14, 0)
    : const Offset(-.14, 0);
final exitingOffset = _isForward
    ? const Offset(-.06, 0)
    : const Offset(.06, 0);
final currentKey = ValueKey(widget.page.section);

return AnimatedSwitcher(
  duration: const Duration(milliseconds: 280),
  switchInCurve: Curves.easeOutCubic,
  switchOutCurve: Curves.easeInCubic,
  layoutBuilder: (currentChild, previousChildren) {
    return Stack(
      fit: StackFit.expand,
      children: [...previousChildren, ?currentChild],
    );
  },
  transitionBuilder: (child, animation) {
    final isIncoming = child.key == currentKey;
    final offset = isIncoming ? enteringOffset : exitingOffset;
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(begin: offset, end: Offset.zero).animate(
          animation,
        ),
        child: child,
      ),
    );
  },
  child: HomePanel(
    key: currentKey,
    page: widget.page,
    selectedIndex: widget.selectedIndex,
  ),
);
```

`lib/features/shell/views/widgets/home_panel.dart:115-135` confirms that each duplicated page owns a preview card tree, while `lib/features/shell/views/widgets/home_panel.dart:267-275` contains its `BackdropFilter`. Painting several outgoing menu pages at once is unnecessary.

There is also no reduced-motion branch. A user with `MediaQueryData.disableAnimations == true` still gets the same horizontal movement.

## Target

Make the transition crisp, directional, bounded, and cheap:

- Normal duration: exactly `240ms`, under the 300ms UI-animation budget.
- Normal motion curve: exactly `Cubic(0.32, 0.72, 0, 1)`, the iOS-like drawer curve.
- Opacity curve: exactly `Cubic(0.23, 1, 0.32, 1)`, the strong UI ease-out.
- Entering page travel: `6.5%` of its width (`Offset(0.065, 0)` forward, `Offset(-0.065, 0)` backward).
- Outgoing page travel: `2.5%` of its width in the opposite direction.
- Outgoing opacity reaches zero during progress `0.0–0.38`; incoming opacity begins at progress `0.08` and reaches one by `0.72`. This limits text/artwork double exposure instead of crossfading both full-strength panels for 280ms.
- Keep at most one outgoing page plus the current page in the transition stack.
- Wrap each `HomePanel` in `RepaintBoundary` and the transition stack in `ClipRect`.
- Reduced motion: exactly `200ms`, opacity only, with both slide offsets set to `Offset.zero`.
- Preserve first-render behavior: the initial menu must appear without an entrance animation.
- Do not animate menu selection changes within the same `MenuSection`; only a changed `ValueKey(MenuSection)` triggers this transition.

Add shared tokens to `lib/core/theme/tokens/app_tokens.dart`:

```dart
abstract final class AppDurations {
  static const quick = Duration(milliseconds: 180);
  static const menuPage = Duration(milliseconds: 240);
  static const reducedMotion = Duration(milliseconds: 200);
  static const standard = Duration(milliseconds: 300);
  static const emphasized = Duration(milliseconds: 420);
  static const lyricLine = Duration(milliseconds: 480);
  static const lyricScroll = Duration(milliseconds: 560);
}

abstract final class AppCurves {
  static const standard = Curves.easeOutCubic;
  static const strongEaseOut = Cubic(0.23, 1, 0.32, 1);
  static const menuPage = Cubic(0.32, 0.72, 0, 1);
  static const lyricLine = Curves.easeOutQuart;
  static const lyricScroll = Curves.easeInOutCubic;
}
```

The executor should normalize both incoming and outgoing transitions to a forward `0→1` progress before applying curves. `AnimatedSwitcher` supplies incoming animation as `0→1`, but outgoing animation as `1→0`; use `ReverseAnimation(animation)` for the outgoing branch.

Target transition structure in `lib/features/shell/views/pages/ipod_screen.dart`:

```dart
final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
final enteringOffset = reduceMotion
    ? Offset.zero
    : _isForward
    ? const Offset(.065, 0)
    : const Offset(-.065, 0);
final exitingOffset = reduceMotion
    ? Offset.zero
    : _isForward
    ? const Offset(-.025, 0)
    : const Offset(.025, 0);
final currentKey = ValueKey(widget.page.section);

return ClipRect(
  child: AnimatedSwitcher(
    duration: reduceMotion
        ? AppDurations.reducedMotion
        : AppDurations.menuPage,
    layoutBuilder: (currentChild, previousChildren) {
      return Stack(
        fit: StackFit.expand,
        children: [
          if (previousChildren.isNotEmpty) previousChildren.last,
          ?currentChild,
        ],
      );
    },
    transitionBuilder: (child, animation) {
      final isIncoming = child.key == currentKey;
      final progress = isIncoming ? animation : ReverseAnimation(animation);
      final position = Tween<Offset>(
        begin: isIncoming ? enteringOffset : Offset.zero,
        end: isIncoming ? Offset.zero : exitingOffset,
      ).animate(
        CurvedAnimation(parent: progress, curve: AppCurves.menuPage),
      );
      final opacity = Tween<double>(
        begin: isIncoming ? 0 : 1,
        end: isIncoming ? 1 : 0,
      ).animate(
        CurvedAnimation(
          parent: progress,
          curve: Interval(
            isIncoming ? 0.08 : 0,
            isIncoming ? 0.72 : 0.38,
            curve: AppCurves.strongEaseOut,
          ),
        ),
      );
      return FadeTransition(
        opacity: opacity,
        child: SlideTransition(position: position, child: child),
      );
    },
    child: RepaintBoundary(
      key: currentKey,
      child: HomePanel(
        page: widget.page,
        selectedIndex: widget.selectedIndex,
      ),
    ),
  ),
);
```

If Flutter reports that the `RepaintBoundary` key is hidden from `AnimatedSwitcher` identity detection, keep the key on the direct child exactly as shown and do not also key the nested `HomePanel`.

## Repo conventions to follow

- Motion tokens already live in `lib/core/theme/tokens/app_tokens.dart:27-39` as `AppDurations` and `AppCurves`; extend these classes instead of leaving hand-typed values in `ipod_screen.dart`.
- `lib/features/shell/views/widgets/ambient_background.dart:15-45` already uses `ClipRect`, `AnimatedSwitcher`, a stack with the current child on top, and `RepaintBoundary`. Follow that layer ordering.
- `lib/features/shell/views/pages/ipod_screen.dart:261-265` already keys transitions by menu section indirectly through `_MenuPageTransition`; preserve that call site and public constructor.
- This is a tactile consumer music UI. Keep the response immediate and directional, with no bounce and no decorative scale.

## Steps

1. In `lib/core/theme/tokens/app_tokens.dart`, add `AppDurations.menuPage`, `AppDurations.reducedMotion`, `AppCurves.strongEaseOut`, and `AppCurves.menuPage` with the exact values shown above. Do not alter existing token values.
2. In `lib/features/shell/views/pages/ipod_screen.dart`, import `package:qqmusic_ipod/core/theme/tokens/app_tokens.dart` with the other theme-token imports.
3. In `_MenuPageTransitionState.build`, add the `MediaQueryData.disableAnimations` check and replace `.14/.06` offsets with the exact `.065/.025` offsets; use zero offsets for reduced motion.
4. Replace the current `AnimatedSwitcher` timing and transition builder with the normalized-progress implementation shown in Target. Do not set `switchInCurve` or `switchOutCurve`; the child animations apply the exact curves explicitly.
5. Change `layoutBuilder` so it retains only `previousChildren.last` and `currentChild`, preventing rapid input from stacking more than two full `HomePanel` trees.
6. Wrap the `AnimatedSwitcher` with `ClipRect` and its keyed child with `RepaintBoundary` exactly as shown.
7. Run mechanical checks, then test both center-button entry and MENU-button return on a physical Android device. Test rapid alternating input as well as a single deliberate navigation.

## Boundaries

- Do NOT change `ShellController.menuPath`, `handleCenter`, or `handleMenu` behavior.
- Do NOT change `HomePanel` layout, menu tile styling, preview card styling, or scroll behavior.
- Do NOT change `AmbientBackground` or its existing 750ms image transition in this plan; judge that separately only if the polished menu transition still drops frames.
- Do NOT change the outer `PageView` transitions used for Cover Flow, Now Playing, or feature pages.
- Do NOT add dependencies.
- Do NOT add bounce, scale, blur, or animated layout properties.
- Animate only opacity and transform.
- If any target excerpt no longer matches commit `a5f8a19`, STOP and report drift instead of improvising.

## Verification

- **Mechanical**: run `flutter analyze`; expected output is `No issues found!`.
- **Mechanical**: run `flutter test`; all existing tests must pass.
- **Performance**: in Flutter DevTools Performance view, enable frame rendering stats and perform ten rapid enter/back operations. No UI frame should exceed the device's frame budget, and no more than two `HomePanel` trees should appear in the widget tree during a transition.
- **Feel check**: on a physical Android device, enter Recommendations, Music Hall, My Music, and Settings from the root menu and confirm:
  - The destination starts moving immediately after the center-button haptic/tick.
  - The page shift is subtle (`6.5%`), not a floating full-screen sweep.
  - Old labels disappear early enough that old and new menu text do not remain visibly doubled.
  - The preview artwork and list move as one spatially coherent page.
  - Pressing MENU reverses the direction.
  - Repeated center/MENU input retargets without accumulating ghost pages or visible pauses.
- **Reduced-motion feel check**: with Android “Remove animations” enabled, repeat entry and return. Confirm that opacity still communicates the content replacement for `200ms`, but there is no horizontal movement.
- **Slow-motion check**: record at 120/240 fps or use Flutter DevTools slow animations. At 10% playback, confirm the old page is gone by 38% progress, the new page begins at 8%, reaches full opacity by 72%, and neither page escapes the glass-screen clip.
- **Done when**: analyzer/tests pass, normal and reduced-motion directions behave as specified, only two menu page trees coexist, and ten rapid enter/back operations produce no ghost layers or over-budget frames on the test device.

## Execution result

- Implemented against commit `a5f8a19`.
- `flutter analyze`: passed with `No issues found!`.
- `flutter test`: unavailable because this repository has no `test/` directory.
- Physical-device normal/reduced-motion feel checks remain pending.
