# RainFX Persistent GPU — Texel Identity / Lifecycle Writeback Test

## Purpose

This test isolates whether one persistent particle keeps the same State and Meta texel identity through update, ping-pong, lifecycle transition, and render observation.

The test intentionally reduces the persistent state count to **1 texel**. This removes every possible screen-space overlap between different persistent particles from the experiment.

## Identity contract

For `gRainStateCount = 1`:

- `index = 0`
- `stateUV = ((0 + 0.5) / 1, 0.5) = (0.5, 0.5)`
- State read: `txRainState.SampleLevel(..., float2(0.5, 0.5), 0)`
- Meta read: `txRainStateMeta.SampleLevel(..., float2(0.5, 0.5), 0)`

There is exactly one State texel and one Meta texel.

The ping-pong contract is:

- Frame N read: `StateA[0] + MetaA[0]`
- Frame N write: `StateB[0] + MetaB[0]`
- Frame N+1 read: `StateB[0] + MetaB[0]`
- Frame N+1 write: `StateA[0] + MetaA[0]`

The particle's screen position is irrelevant to its identity. Position is data stored in that fixed texel.

## Test configuration

Use:

- `RAIN_GPU_STATE_MODE = 6`
- `RAIN_GPU_STATE_COUNT = 1`
- `RAIN_GPU_STATE_LIFECYCLE = true`
- `RAIN_GPU_STATE_C3_TEST_SPEED = true`
- `RAIN_DEBUG = 42`

Do not change physics, coordinate mapping, boundary mask, or shader logic for this test.

Mode 6 is required because it keeps lifecycle enabled and uses the configured state count. Mode 7 must not be used for this test because the current Lua path intentionally disables lifecycle in mode 7.

## Expected lifecycle

The single texel must progress through:

`Meta.A = 1` -> particle flows -> predicted/midpoint position crosses boundary -> `Meta.A = 0` -> state velocity becomes zero on the following state read -> wait timer accumulates in `Meta.B` -> `Meta.A = 2` -> state pass consumes pending respawn and creates a new valid signed-UV position -> `Meta.A = 1`

Debug 42 currently maps these observations to:

- cyan: alive and currently inside boundary
- red: alive but current State position is outside boundary
- black: dead/waiting
- yellow: respawn pending

## What this test proves

If Debug 41 reports a boundary crossing and Debug 42 subsequently changes:

`cyan -> black -> yellow -> cyan`

with the single particle reappearing at a different valid position, then:

1. the boundary decision is being made from the expected State texel;
2. Meta.A is written to the corresponding Meta texel;
3. State/Meta A/B ping-pong remains index-aligned;
4. the renderer reads the newly selected read-side pair after the ping-pong swap.

If Debug 41 reports a crossing but Debug 42 remains cyan, the failure is no longer explainable by multiple particles overlapping on screen. The investigation must then focus on the actual GPU write/read lifecycle path.

## Important interpretation rule

This test is deliberately a **writeback/identity test**, not a physics-quality test.

Do not change flow speed, adhesion, mass, normal projection, drag, or boundary coordinates to make the result visually stronger. The only temporary configuration change is the state count reduction to one.

## After the test

Restore:

`RAIN_GPU_STATE_COUNT = 256`

before continuing multi-particle lifecycle/rendering work.


## Debug 43 — direct Meta.A texel probe

Debug 42 is intentionally not used as the primary writeback verdict for the single-texel experiment. It still computes a screen-space marker from State position and evaluates the boundary mask.

Debug 43 removes those variables completely.

It samples exactly:

`txRainStateMeta[(0 + 0.5) / gRainStateCount, 0.5]`

and fills the entire visor fragment with a color determined only by `Meta.A`.

Expected colors:

- **cyan** = `Meta.A = 1` (alive)
- **black** = `Meta.A = 0` (dead/waiting)
- **yellow** = `Meta.A = 2` (respawn pending)
- **red** = unexpected Meta.A value

Alpha is always 1.

### Required run

Set:

- `RAIN_GPU_STATE_MODE = 6`
- `RAIN_GPU_STATE_COUNT = 1`
- `RAIN_GPU_STATE_LIFECYCLE = true`
- `RAIN_GPU_STATE_C3_TEST_SPEED = true`
- `RAIN_DEBUG = 43`

The allocation must be recreated after changing the state count. Restart/reload the app if necessary so the persistent textures are allocated as 1×1.

### Interpretation

This is the primary binary test.

If Debug 43 changes:

`cyan -> black -> yellow -> cyan`

then Meta.A is demonstrably being written and read back through the persistent ping-pong path.

If Debug 41 detects the boundary transition but Debug 43 remains cyan, the failure is downstream/upstream of the boundary decision and cannot be attributed to screen-space marker overlap or boundary-color logic.

Do not tune physics parameters during this test.


## Debug 44 — full-area physical texel lifecycle map

Debug 43 is intentionally a **single-texel** probe. It fills the entire visor with the state of one texel. Therefore, if it is used with `RAIN_GPU_STATE_COUNT = 128`, a cyan full-screen result only means that **Meta[0] is alive**; it does not mean all 128 particles are alive. This was an important ambiguity in the 128-particle observation.

Debug 44 removes that ambiguity. The rendered visor is divided horizontally into `gRainStateCount` bands, and each band samples the corresponding physical State/Meta texel:

`screen band i -> Meta[i] -> UV((i + 0.5) / count, 0.5)`

For `count = 1`, the entire visor is one band, so the result is equivalent to the desired large-area single-particle probe. For `count = 128`, 128 independent vertical bands are visible.

Colors:

- cyan = `Meta.A = 1` alive
- black = `Meta.A = 0` dead/waiting
- yellow = `Meta.A = 2` respawn pending
- red = unexpected Meta.A

### Recommended test order

1. `COUNT = 1`, `DEBUG = 43`: observe the large-area lifecycle sequence directly. Expected: `cyan -> black -> yellow -> cyan`.
2. `COUNT = 1`, `DEBUG = 44`: confirms the same single physical texel through the band mapping.
3. `COUNT = 128`, `DEBUG = 44`: inspect whether individual Meta texels actually diverge. A uniform cyan screen here means the 128 Meta texels are all currently `Alive`; it is no longer a screen-position visibility artifact.

The Lua allocation path was verified: `ui.ExtraCanvas(vec2(count, 1), ...)` allocates the persistent State/Meta canvases at exactly `count x 1`. Therefore `COUNT = 1` really is a 1x1 physical canvas, while `COUNT = 128` is a 128x1 physical canvas.

Debug 43/44 use the same point-sampled texel identity convention as the update shaders, so this test does not introduce a separate coordinate mapping.
