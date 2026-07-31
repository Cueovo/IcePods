# 009 — Isolate Native Rebuilds and Harden Accessibility

- **Status**: TODO
- **Commit**: 60c800d
- **Severity**: HIGH
- **Category**: Performance; Accessibility; Interruptibility
- **Estimated scope**: 8 source/test files, medium-to-large refactor

## Problem

The shell is below one broad `AnimatedBuilder` and the custom player progress/lyrics work can trigger frequent rebuild and paint activity. Several prominent animations ignore reduced motion. Fixed rows and small targets also make large text and assistive navigation fragile.

Relevant evidence:

```dart
// lib/features/shell/views/pages/ipod_screen.dart:88-109
return AnimatedBuilder(
  animation: _shell,
  builder: (context, child) {
    return Scaffold(...);
  },
);
```

```dart
// lib/features/player/views/pages/now_playing_panel.dart:545-579
TweenAnimationBuilder<Offset>(
  ...
  duration: isSeeking ? AppDurations.quick : AppDurations.standard,
)
```

Menu rows are visual `AnimatedContainer`s without explicit selection/button semantics, while queue rows are better and should be used as the semantic exemplar:

```dart
// lib/features/player/views/widgets/playback_queue_panel.dart:305-310
Semantics(
  button: true,
  selected: selected,
  label: ...,
)
```

## Target

Performance:

- Chassis, status bar, ambient background, wheel, page content, and playback progress have separate listenable boundaries.
- Continuous playback progress repaints only the progress painter and time display; it does not rebuild static artwork, actions, or queue.
- Word-timed lyrics cache text layout and advances the active lyric index from the previous index rather than scanning all lines every frame.
- Ambient and Cover Flow filters are isolated and profiled.

Accessibility:

- Menu/media rows expose `button`, `selected`, position, playing/paused, VIP, unavailable, and liked state.
- Playback progress exposes adjustable increase/decrease semantics.
- Important login/error/status updates are announced as live regions without announcing every timer tick.
- Primary hit regions remain at least 48×48 logical pixels.
- Large text uses content-driven or measured row heights instead of clipping fixed 38–52px rows.
- Reduced motion disables continuous shimmer, 3D motion, auto-scroll, and decorative tilt.

## Steps

1. Split `_IpodShellView` into narrow `ListenableBuilder`/`ValueListenableBuilder` consumers. Pass static chassis/wheel/status subtrees through `AnimatedBuilder.child` where possible.
2. Move seek preview and wheel rotation deltas into dedicated notifiers so pointer movement does not rebuild unrelated pages.
3. Replace per-event progress tween retargeting with a retained visual clock or a painter/listenable that samples the audio position without starting a new 300ms tween every event.
4. Cache lyric `TextPainter` layout by line/style/width/text scale, advance active-line lookup monotonically, and suspend automatic centering while the user scrolls.
5. Add `Semantics` to menu rows, `MediaTile`, `HomeFeedCard`, progress, and custom status summaries. Use queue-row semantics as the pattern.
6. Replace fixed lyric extent and fixed media/queue title areas with measured or adaptive layout when text scale exceeds 1.0. Preserve compact visual density only when it does not clip content.
7. Add reduced-motion widget tests and semantics tests using `SemanticsTester`, `MediaQueryData(disableAnimations: true)`, and text scales 1.0, 1.3, and 2.0.
8. Profile native Android/iOS in profile mode for rapid wheel input, seeking, lyrics, Cover Flow, and Ambient changes before and after the refactor.

## Boundaries

- Native Android/iOS app only.
- Do NOT modify web image strategy, web layout, or `ambient_background_web.dart`.
- Do NOT change audio playback behavior or network/API code.
- Do NOT remove visual richness solely to hide performance problems; isolate, cache, and reduce only during active motion.
- Do NOT announce continuous playback progress every frame or sleep countdown every second.

## Verification

- **Mechanical**: run `flutter analyze` and `flutter test`.
- **Performance**: use Flutter DevTools frame chart and rebuild tracking on a representative Android device and iOS device. Rapid wheel movement and seeking must stay within the device frame budget.
- **Accessibility**: run TalkBack and VoiceOver traversal; menu selection and current playback state must be understandable without the simulated wheel.
- **Large text**: no RenderFlex overflow or clipped lyrics at 1.3× and 2.0×.
- **Reduced motion**: no repeating ticker, Cover Flow 3D movement, lyric auto-scroll, shimmer, or artwork tilt remains active.
- **Done when**: the highest-frequency interactions rebuild only their necessary subtrees and every primary playback/menu state has an accessible semantic equivalent.
