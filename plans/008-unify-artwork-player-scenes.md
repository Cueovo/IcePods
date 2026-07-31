# 008 — Make Now Playing, Cover Flow, and Queue One Artwork Scene

- **Status**: TODO
- **Commit**: 60c800d
- **Severity**: HIGH
- **Category**: Missed opportunities; Cohesion; Physicality & origin
- **Estimated scope**: 6 source files, medium-to-large visual refactor

## Problem

Cover Flow is the most cinematic surface, Now Playing is information-dense, and Queue is a conventional media list. The current track does not travel between these surfaces as one object. Queue rows are 52px tiles, Now Playing artwork is capped at 220px, and Cover Flow uses an independent 140px 3D card with reflection.

Current evidence:

```dart
// lib/features/player/views/widgets/cover_flow_panel.dart:157-159
final scale = 1.15 - sideProgress * 0.25;

// lib/features/player/views/pages/now_playing_panel.dart:879-918
final size = available.isFinite
    ? available.clamp(72.0, 220.0)
    : 160.0;

// lib/features/player/views/widgets/playback_queue_panel.dart:35-39
static const _itemExtent = 52.0;
static const _itemGap = 6.0;
```

## Target

Define a shared native artwork identity and scene hierarchy:

- Cover Flow: selected artwork is the hero object with depth/reflection.
- Now Playing: selected artwork occupies 60–70% of the visual hierarchy; controls become secondary.
- Queue: current track becomes a pinned `NOW` row/card, next track gets a `NEXT` emphasis, remaining tracks recede.
- The same artwork key/palette/scrim is passed through all three surfaces.
- Menu → Cover Flow → Now Playing → Queue uses a directional shared-artwork transition where possible.

Now Playing target:

- Keep the existing lyrics choreography and word progress.
- Reduce fixed secondary action density; retain the current four actions functionally but visually subordinate them.
- Derive waveform/progress colors from the shared artwork palette.

Queue target:

- Keep VIP/error behavior and the current queue actions.
- Add clear current/next/upcoming hierarchy without changing queue order or playback behavior.
- Reveal destructive remove affordance only for the selected non-current row or through an explicit secondary action.

## Steps

1. Extract a shared `ArtworkIdentity` containing song key, artwork URL, palette, and transition namespace. Pass it from `ShellController` to Cover Flow, Now Playing, and Queue.
2. Update Cover Flow to expose the selected artwork identity and use it as the source for scene transitions.
3. Update Now Playing artwork and progress painter to use the identity palette and preserve the existing lyrics/artwork toggle behavior.
4. Update Queue header/current row to show `NOW`, `NEXT`, and `UPCOMING` hierarchy using existing semantic tokens. Preserve `playbackError`, VIP badge, selection semantics, and remove behavior.
5. Add an app-only shared transition layer in `ipod_screen.dart` for the selected artwork. If a true shared-element flight cannot be implemented without destabilizing PageView, use a coordinated opacity/scale flight with the exact same image key rather than duplicating unrelated artwork.
6. Add widget tests for identity continuity, current/next queue labels, VIP badge, and artwork/lyrics toggle.

## Boundaries

- Native Android/iOS only.
- Do NOT change web rendering or `ambient_background_web.dart`.
- Do NOT change playback order, queue persistence, VIP rules, or API behavior.
- Do NOT remove lyrics word timing or automatic centering without a separate performance plan.
- Do NOT turn the queue into a drag-reorder surface in this plan.

## Verification

- **Mechanical**: run `flutter analyze` and the player/queue/Cover Flow test suites.
- **Visual**: switch Cover Flow → Player → Queue with the same track. The artwork color, keyline, and identity must feel continuous.
- **Hierarchy**: current track is dominant, next track is discoverable, and upcoming tracks remain readable but visually quieter.
- **Interaction**: VIP badge and queue error remain visible after a blocked VIP selection.
- **Reduced motion**: shared artwork uses opacity-only replacement with no spatial flight.
- **Done when**: the three signature surfaces read as states of one music scene rather than separate feature widgets.
