# s282 background suspension

The product preview explicitly pauses when `ac.getSim().isWindowForeground` is
false. This addresses the reported sustained 2 FPS background throttle without
enlarging queues or changing the game's FPS settings. An unavailable foreground
flag retains the previous behavior.

New input capture and solver submission stop in `background_paused`. Already
submitted GPU work may finish; its callbacks remain retained. Active startup and
readback deadlines exclude the pause. The latest owned optical view remains
available. On return, `resuming` drains captured work before `repriming` captures
the current pose and resumes normal operation using the same water and GPU stock.
Partial fixed-step integrals remain retained. Material/calibration changes still
require reset. Each new CPU capture rechecks the 20 input asset hashes; resume
therefore has some file-read cost, but allocates no new solver GPU resources.

This is an explicit model pause: rain during background and pose preparation is
not simulated. The UI reports excluded input seconds/frames, pause wall time,
transition count and capture restarts. Excluded input seconds follow the engine's
reported delta time, which can differ from wall time under throttling. Previously
captured input is conserved and drained. Stop during background drains on return.

## Validation and limits

Seven local cases passed: background, repeated transitions, startup, Stop while
background, changed material, changed pose, and a partially accumulated interval.
They use the actual capture/typed-input/runtime code with mocked engine/GPU.
They check 128 reused resources, explicit excluded time and captured-time balance.
Existing product regression (13 groups including native optical shader checks)
and bounded-input recovery regression passed. Actual CSP background return and
the visual transition remain unverified; no additional user run was requested.

The foreground source conservation failures 64/288 remain unresolved. This
change does not alter physical tolerances, water quantities or source acceptance.
See [state investigation](RAINFX_S282_1732_STATE_MISMATCH.md). Further solver
optimization and merge/pool adoption remain behind that correctness blocker.
