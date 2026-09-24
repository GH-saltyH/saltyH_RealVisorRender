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
