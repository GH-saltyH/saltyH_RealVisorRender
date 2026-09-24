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


## Debug 43/44 visibility enhancement — background + particle separation

The lifecycle diagnostics now separate the lifecycle field from the particle marker through alpha:

- background / lifecycle field: **alpha 0.5**
- particle position marker: **alpha 1.0**

Debug 43 still fills the entire visor with the selected texel's lifecycle color, but additionally samples that texel's State position and draws its particle marker at that position. This means the particle remains observable even when it moves outside the valid boundary, while the semi-transparent lifecycle field remains visible behind it.

Debug 44 applies the same principle per texel band: each band shows its Meta.A lifecycle color at alpha 0.5, while the corresponding State position is drawn with alpha 1.0. The lifecycle state and physical position can therefore be distinguished in the same output.


## Debug 45 — direct State RG + Boundary Mask diagnostic

The Mode 6 test was run with:

- `RAIN_GPU_STATE_MODE = 6`
- `RAIN_GPU_STATE_COUNT = 1`
- `RAIN_GPU_STATE_C3_TEST_SPEED = true`

The observed Debug 43 result was a persistent cyan field with no visible particle marker. Increasing the count to 128/256 did not make the marker generally visible; only sufficiently strong motion occasionally produced visible points.

Debug 43 alone cannot distinguish between:

1. `Meta.A` remaining alive;
2. `State.RG` being outside the rendered visor coordinate region;
3. the boundary mask evaluating the State position as invalid;
4. the marker simply being outside the visible fragment domain.

Debug 45 was added to remove the screen-space marker from the experiment.

For the selected physical texel (index 0 for the single-texel test), it reads:

- `Meta.A) from `txRainStateMeta`
- `State.RG) from `txRainState`
- `BoundaryMask(State.RG)) from `rainStateBoundaryMask()`

The output is split into two vertical UV regions:

- **Upper half (`V < -0.5`)**: lifecycle color
  - cyan = `Meta.A = 1`
  - black = `Meta.A = 0`
  - yellow = `Meta.A = 2`
  - red = unexpected value
- **Lower half (`V >= -0.5`)**:
  - R = State U encoded in 0..1
  - G = -State V encoded in 0..1
  - B = boundary validity (`1 = valid`, `0 = invalid`)

This is the next authoritative diagnostic. It should be run in Mode 6 with lifecycle enabled before changing boundary coordinates or physics parameters.

### Interpretation matrix

| Upper half | Lower-half B | Meaning |
|---|---:|---|
| cyan | 1 | State is alive and currently inside the boundary |
| cyan | 0 | State is alive but currently outside/invalid; lifecycle writeback is not yet committed at the observed frame, or the lifecycle update path is not seeing the same State |
| black | 0 | Dead/waiting state has been recorded in Meta.A |
| yellow | 1 or 0 | Respawn is pending; inspect the newly generated position on the next frame |
| red | any | Meta.A is not one of the expected lifecycle states |

The key observation is whether the lower-half B channel becomes 0 while the upper half remains cyan, and whether it subsequently becomes black/yellow. This isolates the exact point at which State position, mask evaluation, and Meta lifecycle diverge.

The Debug 45 entry is also added to the Lua `RAIN_DEBUG` UI list; new debug tests must update both HLSL dispatch and the visible Lua test selector.


## Debug 46 — Boundary Mask only

Debug 45 intentionally displays State.U, -State.V, and BoundaryMask(State.RG) together. The next test separates these values completely.

### Why this separation is required

The visor normal texture is only painted in the actual visor region. Outside that region its RGB value is (0,0,0). The normal reconstruction therefore produces an invalid/degenerate normal outside the painted region, and any physics that derives direction from that normal can generate an artificial direction.

That means an observed direction change must not be used by itself to decide whether the persistent State has crossed the valid surface region. First establish the boundary-mask result independently.

Debug 46 does not sample or reconstruct the normal at all.

### Output

Debug 46 selects the same physical State texel used by Debug 45:

stateUV = (0.5 / gRainStateCount, 0.5)

It reads only:

State.RG -> rainStateBoundaryMask(State.RG)

The entire rendered area is one scalar visualization:

- white = BoundaryMask(State.RG) is valid
- black = BoundaryMask(State.RG) is invalid
- intermediate gray = the mask texture's filtered value at the sampled State position

No State.U/V color is mixed into the result.

### Required run

Use:

- RAIN_GPU_STATE_MODE = 6
- RAIN_GPU_STATE_COUNT = 1
- RAIN_GPU_STATE_LIFECYCLE = true
- RAIN_GPU_STATE_C3_TEST_SPEED = true
- RAIN_DEBUG = 46

Do not change normal-map, force, adhesion, gravity, drag, or boundary-coordinate parameters during this run.

### Test procedure

1. Start/reload the persistent GPU state with the above configuration.
2. Observe Debug 46 immediately.
3. Drive straight and perform the same turns/acceleration/deceleration pattern used for Debug 45.
4. Watch specifically for a white -> black transition.
5. If the output changes, record approximately when it changes and whether Debug 45 at the same moment showed a corresponding change in its B channel.
6. If it remains white for the entire run, that is also a useful result: the selected State position is continuously considered valid by the boundary mask, regardless of what the normal-derived physics is doing.

### Interpretation

| Debug 46 | Meaning |
|---|---|
| White | rainStateBoundaryMask(State.RG) currently evaluates as valid |
| Black | rainStateBoundaryMask(State.RG) currently evaluates as invalid |
| Gray | The mask texture returns a filtered/intermediate value at State.RG |

This test does not determine whether State.U or State.V is correct. It answers only one question:

> Does the boundary mask consider the current persistent State position valid?

Once this is known, the next diagnostic can isolate State.U and State.V individually if necessary.

### Important limitation

A black normal texture outside the painted visor area is expected from the asset and must not be interpreted as a physical zero normal. Debug 46 deliberately bypasses normal reconstruction so that this asset characteristic cannot contaminate the boundary-mask observation.


## Lifecycle initialization fix — Meta init flag writeback

The C3 lifecycle test exposed an initialization-state bug in the Lua ping-pong setup.

`initializeRainGPUState()` initializes both State and Meta A/B canvases with `gRainStateInit = 1.0`. The State parameter block was correctly reset to `0.0` after the four initialization dispatches, but the Meta parameter block was not.

As a result, the Meta shader returned from its initialization branch on every subsequent frame:

- `Meta.A` was continuously rewritten to `1.0`;
- `Meta.B` was continuously rewritten to `0.0`;
- the lifecycle branch below the initialization return was unreachable;
- BoundaryMask crossing therefore could not transition the droplet into `DEAD` or `RESPAWN_PENDING`.

The required post-initialization state is now:

```lua
rainStateUpdateParams.values.gRainStateInit = 0.0
rainStateMetaUpdateParams.values.gRainStateInit = 0.0
```

After this change, the single-texel C3 run with `COUNT = 1` reproduced the complete expected sequence:

```
ALIVE
  -> boundary crossing
  -> DEAD / waiting
  -> RESPAWN_PENDING
  -> ALIVE at a new valid position
```

Debug 46 independently reproduced the valid/invalid BoundaryMask transition, while Debug 43 showed the corresponding Meta.A lifecycle transition. This establishes that the boundary and lifecycle state machine are functioning through the State/Meta A/B ping-pong path.

This fix is a lifecycle-state initialization correction. It does not alter the physical force, adhesion, drag, or speed model.

## Debug 47 — Stage 6 adhesion threshold / actual movement

Stage 6 now validates the central adhesion rule:

> A droplet should remain attached while effective tangential force is below its adhesion threshold, and should begin accelerating only after the threshold is exceeded.

Mode 5 already provides the required controlled experiment. It creates exactly three persistent droplets at the same physical spawn position and applies the same controlled tangent force and adhesion base to all three. Only radius/mass differs:

| Texel | Radius | Mass | Adhesion at base 1.20 |
|---|---:|---:|---:|
| 0 / small | 0.032 | 1 | 1.200 |
| 1 / medium | 0.0735 | 3 | 0.693 |
| 2 / large | 0.115 | 9 | 0.400 |

The current controlled adhesion implementation is:

```
adhesion = C2_ADHESION_BASE / sqrt(mass)
```

Therefore the test can use one force sweep without changing any other physical parameter.

### Debug 47 output

Debug 47 divides the visor into three screen bands:

- left = small / mass 1
- center = medium / mass 3
- right = large / mass 9

The shader reads only the actual persistent State velocity (`State.BA`).

- **White** = actual persistent velocity is non-zero.
- **Black** = actual persistent velocity is effectively zero.

The diagnostic intentionally does **not** sample:

- surface normal;
- BoundaryMask;
- procedural rain;
- screen-space droplet generation.

This keeps the observation focused on whether the persistent physics gate actually permits motion.

### Required run

Use:

- `RAIN_GPU_STATE_MODE = 5`
- `RAIN_GPU_STATE_COUNT` is forced to `3` by Mode 5
- `RAIN_DEBUG = 47`
- `RAIN_GPU_STATE_C2_ADHESION_BASE = 1.20`
- start from a fresh persistent-state allocation so all three velocities begin at zero

Use the existing `C2_FORCE_X` control and keep `C2_FORCE_Y = 0`.

Recommended force sweep:

1. **C2_FORCE_X = 0.50**
   - small: stationary
   - medium: stationary
   - large: moving

2. **C2_FORCE_X = 0.80**
   - small: stationary
   - medium: moving
   - large: moving

3. **C2_FORCE_X = 1.30**
   - small: moving
   - medium: moving
   - large: moving

These three points bracket the calculated thresholds:

```
0.50 < 0.693 < 0.80 < 1.20 < 1.30
```

### Pass criteria

The important result is not the absolute speed. It is the **membership of each droplet in the stationary/moving set**.

Expected transition:

```
Force 0.50 :  S -  M -  L +
Force 0.80 :  S -  M +  L +
Force 1.30 :  S +  M +  L +
```

where `-` means effectively stationary and `+` means persistent velocity is present.

If this sequence is reproduced, the Stage 6 adhesion gate has been demonstrated for three different masses under the same applied force.

### Important interpretation rules

This is a threshold test, not a speed-quality test.

Do not tune:

- `RAIN_FLOW_ACCELERATION`
- `RAIN_FLOW_DRAG`
- `RAIN_FLOW_MAX_SPEED`
- gravity
- normal projection
- boundary mask

while judging this test.

A large droplet moving farther than a small droplet is not by itself the pass condition. The first question is whether each mass crosses the adhesion threshold at the expected force.

Once the threshold gate is confirmed, Stage 7 can separately validate acceleration response, drag, and terminal-speed limiting.

### Asset-specific normal-map caveat

The custom visor normal texture is black outside its painted visor region. Debug 47 does not sample it, so the Stage 6 verdict must not be contaminated by the invalid `(0,0,0)` normal representation outside the painted region.

