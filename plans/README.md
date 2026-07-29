# Animation Plans

| # | Plan | Severity | Status |
| --- | --- | --- | --- |
| 001 | [Polish and stabilize submenu transitions](001-polish-submenu-transition.md) | HIGH | IMPLEMENTED — DEVICE CHECK PENDING |
| 002 | [End the splash before the Lottie black tail](002-end-splash-before-lottie-black-tail.md) | HIGH | IMPLEMENTED — DEVICE CHECK PENDING |

## Recommended execution order

1. Plan 001 is implemented. Complete its physical-device and reduced-motion feel checks before marking it DONE.
2. Plan 002 is implemented. Complete its physical-device and reduced-motion feel checks before marking it DONE.

## Dependencies

- Plan 001 has no package or plan dependencies.
- Plan 002 has no package or plan dependencies and does not alter plan 001's submenu transition.
- Reassess the ambient-background crossfade only after plan 002 is executed and profiled on a physical device.
