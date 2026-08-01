# Animation and Experience Plans

These plans are for the native Android/iOS app only. Web layout, browser interaction, `ambient_background_web.dart`, Web platform views, and Web-specific responsive behavior are intentionally out of scope.

| # | Plan | Severity | Status |
| --- | --- | --- | --- |
| 003 | [Establish the app visual system](003-establish-app-visual-system.md) | HIGH | IMPLEMENTED |
| 004 | [Make album artwork drive the app atmosphere](004-album-driven-atmosphere.md) | HIGH | IMPLEMENTED |
| 005 | [Unify native scene motion and page transitions](005-unify-native-scene-motion.md) | HIGH | IMPLEMENTED |
| 006 | [Give the Click Wheel physical response](006-click-wheel-material-feedback.md) | HIGH | IMPLEMENTED |
| 007 | [Create native portrait and landscape compositions](007-native-responsive-composition.md) | HIGH | IMPLEMENTED |
| 008 | [Make Now Playing, Cover Flow, and Queue one artwork scene](008-unify-artwork-player-scenes.md) | HIGH | TODO |
| 009 | [Isolate native rebuilds and harden accessibility](009-native-performance-accessibility.md) | HIGH | TODO |

## Recommended execution order

1. **003 — Visual system**: establish semantic color and typography tokens first.
2. **004 — Album atmosphere**: make artwork the source of ambient color and contrast.
3. **005 — Scene motion**: unify native transitions and reduced-motion behavior.
4. **006 — Click Wheel**: add tactile feedback after motion tokens exist.
5. **007 — Native composition**: make portrait/landscape layouts intentional.
6. **008 — Artwork scenes**: connect Cover Flow, Now Playing, and Queue using the palette and motion foundations.
7. **009 — Performance/accessibility**: profile and harden the final visual system; this can begin with mechanical tests earlier but should be completed after 003–008 stabilize.

## Dependencies

- 004 depends on the semantic color roles from 003.
- 005 depends on the motion tokens from 003 and should be completed before 006 and 008.
- 007 should use the typography and hit-target rules from 003 and 009.
- 008 depends on the artwork identity/palette from 004 and transition grammar from 005.
- 009 is an ongoing verification gate for every other plan.

## Historical plans

Plans 001 and 002 existed in the repository history and were previously marked implemented with physical-device checks pending. They are not recreated here because the current worktree records them as deleted; the new plan sequence begins at 003 without restoring those user changes.
