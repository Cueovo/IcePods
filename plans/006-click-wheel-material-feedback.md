# 006 — Give the Click Wheel Physical Response

- **Status**: TODO
- **Commit**: 60c800d
- **Severity**: HIGH
- **Category**: Physicality & origin; Purpose & frequency; Accessibility
- **Estimated scope**: 2 source files, focused implementation

## Problem

The Click Wheel has careful hit testing and haptic/audio feedback, but the visual object does not change on pointer-down. Its ring, cardinal buttons, and center button are static even while the user interacts.

```dart
// lib/core/theme/widgets/click_wheel.dart:37-43
bool _ringPointer = false;
bool _tapEligible = false;
bool _rotating = false;
```

Pointer callbacks currently reset interaction state without exposing a pressed visual state:

```dart
// lib/core/theme/widgets/click_wheel.dart:121-143
final shouldTap = _tapEligible && !_rotating;
final didRotate = _rotating;
_resetPointer();
```

## Target

Add a private pressed-sector state with these values:

```dart
enum _WheelPress { none, menu, previous, next, playPause, center }
```

On pointer-down inside a tappable sector:

- Set the pressed sector immediately.
- Apply visible scale `0.97` to the pressed button only.
- Tighten its shadow/highlight subtly; do not move the whole wheel.
- Use `AppDurations.press` = 120ms and `AppCurves.strongEaseOut`.

On pointer-up/cancel:

- Clear the pressed sector before invoking the action.
- Release in 80ms or the existing quick token, whichever matches the established token scale.
- Preserve current rotation behavior and do not show press feedback while the ring is actively rotating.

Under reduced motion, retain a color/shadow response but remove scale.

## Steps

1. Add `_WheelPress` and `_pressed` state to `ClickWheel`.
2. Add a helper that resolves the sector from local pointer position using the existing radius and cardinal-direction rules.
3. Set `_pressed` during pointer-down for tap-eligible sectors and call `setState` only when the state changes.
4. Clear `_pressed` on pointer-up and pointer-cancel before invoking callbacks. Ensure an interrupted pointer cannot leave a pressed sector stuck.
5. Update `_WheelButton` to accept `pressed` and `reduceMotion`, using `AnimatedScale` or a direct transform with 0.97 scale and a 120ms ease-out. Preserve the existing semantic labels and hit areas.
6. Add center-button pressed visual treatment without changing its semantic action or pointer routing.
7. Add widget tests for each cardinal button, center button, rotation cancellation, and reduced-motion behavior.

## Boundaries

- Native Android/iOS only.
- Do NOT change the Click Wheel hit regions, action callbacks, haptic behavior, or rotation math.
- Do NOT rotate the physical wheel graphic as decoration.
- Do NOT reduce semantic/hit target bounds below 48×48 logical pixels.
- Do NOT modify web-specific background code.

## Verification

- **Mechanical**: run `flutter analyze` and the Click Wheel/widget test suite.
- **Feel check**: press Menu, Previous, Next, Play/Pause, and Center slowly and rapidly. The pressed sector must respond immediately and release without a bounce.
- **Rotation check**: drag around the ring; no cardinal button should remain visually pressed after rotation or pointer cancellation.
- **Reduced motion**: verify scale is absent while non-motion color/shadow feedback remains.
- **Accessibility**: TalkBack/VoiceOver must still expose all five actions with their existing labels.
- **Done when**: the wheel visibly behaves like a physical control without changing its established interaction contract.
