# 002 — End the splash before the Lottie black tail

- **Status**: IMPLEMENTED — DEVICE CHECK PENDING
- **Commit**: unavailable (the local Git command did not emit a revision)
- **Severity**: HIGH
- **Category**: Purpose & frequency; Easing & duration; Cohesion & tokens
- **Estimated scope**: 2 source files, about 12 changed lines

## Problem

The opening sequence is a rare, explanatory animation, but its selected `2200ms` playback cutoff still reaches the composition's visually empty/black tail before the app begins to appear. The splash then remains for a further `360ms` while the full-screen `AnimatedOpacity` exits. That makes the handoff feel slower than the visible content warrants.

`lib/features/splash/views/jitter_splash.dart:5` and `lib/features/splash/views/jitter_splash.dart:37-49` currently use a `2200ms` cutoff plus a hand-written `360ms` `Curves.easeOutCubic` exit:

```dart
const _splashPlaybackEnd = Duration(milliseconds: 2200);

AnimatedOpacity(
  opacity: _revealing ? 0 : 1,
  duration: const Duration(milliseconds: 360),
  curve: Curves.easeOutCubic,
  onEnd: () {
    if (_revealing && mounted) {
      setState(() => _removed = true);
    }
  },
  child: _JitterSplash(onFinished: _reveal),
)
```

`lib/features/splash/views/jitter_splash.dart:71-103` maps the cutoff to a target Lottie position and correctly keeps the source frame rate by animating to that fractional target over the same duration. Retain that mechanism; only advance the cutoff earlier.

```dart
final playbackDuration =
    compositionDuration.inMilliseconds <= _splashPlaybackEnd.inMilliseconds
    ? compositionDuration
    : _splashPlaybackEnd;
final target =
    playbackDuration.inMicroseconds / compositionDuration.inMicroseconds;
_controller.duration = compositionDuration;

_controller
    .animateTo(target, duration: playbackDuration, curve: Curves.linear)
    .whenComplete(() {
      if (mounted) {
        widget.onFinished();
      }
    });
```

## Target

- Play the Lottie at its original frame rate through exactly `1800ms` of composition time, then stop it before its black tail.
- Begin the full-screen splash exit immediately after that cutoff.
- Fade the entire splash, including Lottie and backdrop, for exactly `260ms` using `AppCurves.strongEaseOut` (`Cubic(0.23, 1, 0.32, 1)`).
- Do not add scale, translation, blur, or a second overlap phase. The composition is already full-screen; opacity-only exit prevents visual crop-edge movement on devices with different aspect ratios.
- Normal-motion total should be about `2060ms` (`1800ms` playback + `260ms` fade).
- Retain the existing reduced-motion branch: it must still skip playback and schedule the reveal on the next frame.

Add the shared duration token to `lib/core/theme/tokens/app_tokens.dart`:

```dart
abstract final class AppDurations {
  static const quick = Duration(milliseconds: 180);
  static const splashExit = Duration(milliseconds: 260);
  static const menuPage = Duration(milliseconds: 240);
  static const reducedMotion = Duration(milliseconds: 200);
  static const standard = Duration(milliseconds: 300);
  static const emphasized = Duration(milliseconds: 420);
  static const lyricLine = Duration(milliseconds: 480);
  static const lyricScroll = Duration(milliseconds: 560);
}
```

Update `lib/features/splash/views/jitter_splash.dart` to use:

```dart
const _splashPlaybackEnd = Duration(milliseconds: 1800);

AnimatedOpacity(
  opacity: _revealing ? 0 : 1,
  duration: AppDurations.splashExit,
  curve: AppCurves.strongEaseOut,
  onEnd: () {
    if (_revealing && mounted) {
      setState(() => _removed = true);
    }
  },
  child: _JitterSplash(onFinished: _reveal),
)
```

## Repo conventions to follow

- Motion tokens live in `lib/core/theme/tokens/app_tokens.dart:27-42`.
- Reuse `AppCurves.strongEaseOut`, which is exactly `Cubic(0.23, 1, 0.32, 1)`, rather than adding another exit curve.
- Import the existing token file at the top of `lib/features/splash/views/jitter_splash.dart`; do not duplicate its curve or duration values locally.
- Preserve the established `OpeningSequence` state structure: `_revealing` drives the visual exit and `_removed` removes the overlay after the exit callback.

## Steps

1. In `lib/core/theme/tokens/app_tokens.dart`, add `static const splashExit = Duration(milliseconds: 260);` to `AppDurations`, immediately after `quick`.
2. In `lib/features/splash/views/jitter_splash.dart`, add the import for `package:qqmusic_ipod/core/theme/tokens/app_tokens.dart` with the other package imports.
3. In `lib/features/splash/views/jitter_splash.dart`, change `_splashPlaybackEnd` from `Duration(milliseconds: 2200)` to `Duration(milliseconds: 1800)`. Do not change the fractional `target` calculation or `Curves.linear` playback curve; this preserves the exported Jitter timing up to the cutoff.
4. In `OpeningSequence.build`, replace the hard-coded `Duration(milliseconds: 360)` with `AppDurations.splashExit`, and replace `Curves.easeOutCubic` with `AppCurves.strongEaseOut`.
5. Do not modify the Lottie JSON, `BoxFit.cover`, Android/iOS launch backgrounds, or the reduced-motion branch.

## Boundaries

- Do NOT modify `assets/Scene.json` or any other generated/exported Lottie asset.
- Do NOT change `lib/features/splash/views/jitter_splash.dart` layout, full-screen crop strategy, system UI styling, or semantic/input blocking behavior.
- Do NOT add dependencies.
- Do NOT alter Android or iOS launch resources.
- If the current source no longer contains the quoted cutoff and exit structure, STOP and report the drift instead of improvising.

## Verification

- **Mechanical**:
  - Run `dart format lib/core/theme/tokens/app_tokens.dart lib/features/splash/views/jitter_splash.dart`.
  - Run `flutter analyze`; expect `No issues found!`.
  - Run `flutter build apk --debug`; expect a successful `app-debug.apk` build.
- **Feel check**:
  - On a physical Android device, cold-launch the app at least five times. The Lottie must retain normal pacing through `1.80s`, then the full screen must fade to the app in `260ms` without a black hold.
  - Record the launch at 60fps or use slow motion. Confirm the first app pixels appear at about `1.80s` and the splash is fully gone at about `2.06s`.
  - Verify that the background gradient and the Lottie disappear together; no independent dark layer may linger after the Lottie freezes.
  - Enable Android "Remove animations" or the platform reduced-motion setting. Confirm the splash does not play movement and still transitions cleanly to the app.
  - Test at least one tall Android device and one standard 16:9 simulator/device. The existing center-crop behavior must remain full-screen with no blue or black bars.
- **Done when**: The opening transition ends by approximately `2.06s`, shows no black-tail dwell, preserves the original Lottie speed before `1.80s`, and passes analysis and debug APK build.
