# RainFX Persistent GPU Development Guide

## 1. Purpose
This document is the baseline for understanding the RealVisorRender RainFX system without relying on previous conversation history.
Current branch: feature-RainFXPersistentGPU
Core files: realvisor.lua, shaders/rainVisorScreen.hlsl
Core assets: texture/GLASS_EXT_RAINFX_surfaceNormal_objectSpace_2K.dds and texture/drops.dds

## 2. Final goal
The old procedural rainDropLayer() is a comparison/debug baseline, not the final architecture.
Final flow:
Persistent GPU State -> Physics Update -> Surface Normal/Tangent -> Gravity + Vehicle Acceleration + Airflow -> Mass/Adhesion -> Drag/Max Speed -> Position Integration -> Drop Rendering -> Merge -> Residue/Shrink

## 3. Current status
Already validated: persistent A/B GPU state, independent persistent drop state, position integration, object-space normal to world normal, tangent force projection, gravity, vehicle acceleration, adhesion threshold, radius-to-mass relationship, force-to-acceleration, linear drag, maximum speed, airflow diagnostics, combined force diagnostics, and the measured 3x3 size/mass/displacement test.
Not finalized: final surface movement/rendering, merge, residue/shrink, and final drop appearance. Persistent dead -> waiting -> respawn lifecycle is implemented; the next validation task is to verify it under the finalized signed coordinate contract.
Therefore the current task is NOT to redesign the physics from zero. It is to consolidate the already tested physics into one persistent simulation.

## 4. Persistent state
Lua creates rainStateA/rainStateB and rainStateMetaA/rainStateMetaB using ui.ExtraCanvas.
Base state RGBA: R=position.x, G=position.y, B=velocity.x, A=velocity.y.
Meta currently stores radius in R and mass in G, with additional channels used for auxiliary time/state information. Age/flags remain an evolving layout rather than a finalized ABI.
Each simulation frame uses A/B ping-pong: read A -> shader -> write B, then read B -> shader -> write A.
State texel identity is the droplet identity. It is not a screen fragment.

## 5. Persistent update path
updateRainGPUState(sim) initializes the canvases, prevents duplicate simulation-frame updates, clamps dt, selects read/write state, supplies physics uniforms, runs the state shader, runs the meta shader, then swaps ownership.
The transparent render callback calls updateRainGPUState(sim) before render.mesh().
Current source therefore verifies the intended use of ExtraCanvas, updateWithShader(), and render.mesh() in this project.

## 6. Physics model
External force is based on gravity plus world-space vehicle acceleration. Airflow/air drag is currently strongly represented in diagnostics and is being integrated carefully into production physics.
Object-space visor normal is decoded from the normal texture and transformed to world space.
Procedural rendering can reconstruct the actual UV tangent frame from ddx/ddy of mesh position and UV. Persistent physics cannot directly rely on fragment derivatives, so it uses the stored surface position plus the normal-derived tangent basis.
Force is projected onto the surface tangent plane before affecting drop motion.

## 7. Mass and adhesion
Radius is mapped to mass. Current test model maps radius to mass approximately from 1 to 9 using a squared normalized radius relationship.
Adhesion is approximately adhesionBase / sqrt(mass). Thus larger drops are easier to move once sufficient external force is applied.
Flow begins from excessForce = max(tangentForce - adhesion, 0).

## 8. Velocity, drag and speed limit
Flow acceleration is accumulated into velocity using dt.
Linear drag is applied with an exponential damping form.
Velocity is clamped to the configured maximum speed.
The procedural renderer also contains rainDropTravelDistance(), an analytic linear-drag travel function. This is a validated reference for the physics, but the persistent simulation should integrate stored velocity rather than simply recreating an analytic trajectory every frame.

## 9. Debug 36
RAIN_DEBUG=36 and RAIN_GPU_STATE_MODE=4 select the measured 3x3 test.
Layout is S M L / L S M / M L S.
Radius values are 0.032, 0.0735 and 0.115.
Mass is derived from normalized radius squared.
Observed result: center movement differences are subtle; edge positions show clearer size-dependent displacement; large drops move farther than medium, which move farther than small; total edge displacement can reach roughly 3.5 times the largest tested radius after sufficient accumulation.
This is evidence that surface orientation plus mass/adhesion plus persistent integration produces real differentiated motion. Do not simply increase speed to make the result more visually obvious.

## 10. Debug map
18 persistent state position/velocity
19 persistent independent drops
20 persistent velocity
21 persistent position
22 raw state
23 predicted motion
24 motion scale
25 accumulated displacement
26 velocity delta
27 surface force
28 adhesion
29 physical drop
30 force to velocity
31 air drag
32 airflow input
33 airflow normal projection
34 combined force
35 radius/mass/adhesion threshold
36 measured 3x3 L/M/S grid
39 lifecycle live/dead/respawn diagnostic
40 boundary mask sampled directly from pin.Tex
41 boundary crossing decision diagnostic

## 11. Existing procedural baseline
rainDropLayer() remains intentionally available.
It uses hash-based cell placement, random radius, radius-to-mass, candidate spawn normal/force/adhesion, analytic travel, drop rendering and trail rendering.
A previous major bug was that evaluating force from pin.Tex caused one procedural drop to receive different directions across its own pixels, producing a clock-hand/rotation-around-origin appearance. The current procedural code evaluates the trajectory from candidate spawn state instead.

## 12. Important historical fixes
Normal texture path problems were fixed by correcting the application path.
The normal texture is object-space and must be decoded and transformed.
Using saturate(pin.Tex) for the normal lookup caused invalid/black behavior for this visor UV arrangement and was removed.
Actual mesh UV tangent reconstruction was added for the procedural path.

## 13. Coordinate rules — FINAL CONTRACT

The project-wide canonical droplet coordinate system is the actual visor mesh UV exposed by `pin.Tex`. Persistent state coordinates, physics position/velocity, boundary sampling, normal sampling, rendering, diagnostics, spawn points and lifecycle decisions use this same coordinate system.

### 13.1 Signed visor UV contract

- **U / X:** `0.0` = left edge, `1.0` = right edge.
- **V / Y:** `-1.0` = top edge, `0.0` = bottom edge.
- Center reference: approximately `(0.5, -0.5)`.
- Typical measured/debug region: approximately `U=0.30..0.70`, `V=-0.70..-0.30`.
- There is **no hidden Y inversion**, no normalized-to-mesh remapping, and no old `lerp(min,max,state)` conversion in the production persistent-state path.

The persistent state texture ABI therefore remains:
- `R = position.U`
- `G = position.V` (signed, normally `-1..0`)
- `B = velocity.U`
- `A = velocity.V`

The state is an actual physical position, not a normalized index that must later be converted for rendering.

### 13.2 Experimental evidence that established the contract

The coordinate direction was established by direct shader sampling experiments on the real visor mesh:
1. Testing `pin.Tex.y < 0` versus `>= 0` proved that the rendered visor fragments have negative V values.
2. Testing `pin.Tex.x < 0` versus `>= 0` proved that the rendered visor fragments have positive U values.
3. Directly sampling the boundary mask with `pin.Tex` in Debug 40 produced the correct visible mask.
4. Direct normal-texture sampling with raw `pin.Tex` preserved the expected mapped result; applying `saturate(pin.Tex)` caused invalid/black behavior.
5. The measured Debug 36 points were already recorded in the signed coordinate system and continue to show the expected spatial ordering.

These are empirical project facts. Do not reintroduce a coordinate conversion unless a new experiment proves a specific texture/API requires one.

### 13.3 Boundary and texture validity

The boundary mask is the authoritative definition of the physical droplet surface.

The sampler uses CLAMP addressing, so the helper rejects positions outside the signed visor texture domain before sampling:
- `U < 0` or `U > 1` => invalid
- `V < -1` or `V > 0` => invalid

This is a texture-domain guard, not a calibration transform. The boundary mask itself decides whether an in-domain point is a valid visor surface.

### 13.4 Spawn / respawn coordinates

Initial and respawn candidates are generated directly in signed UV: `candidate = (hashU, -hashV)`.

Candidates are accepted only when the authoritative boundary mask reports a valid surface. This keeps random distribution independent of the old fixed test-point bounds.

`RAIN_GPU_STATE_MESH_U_MIN/MAX` and `RAIN_GPU_STATE_MESH_V_MIN/MAX` remain only for fixed diagnostic/test-point constraints such as Debug 36. They must never transform persistent state.

### 13.5 Lifecycle coordinate rule

Lifecycle never wraps position with `frac()` and never clamps the physical state back onto the edge.

A flowing droplet is integrated normally. If the current step crosses the authoritative boundary, its state becomes dead. The dead state remains hidden while waiting for its deterministic respawn gap. After the gap, the state becomes respawn-pending; the next state pass creates a new valid signed-UV position with zero velocity. This preserves droplet identity while preventing edge wrapping or teleport-like correction.

## 14. Do not mix physics and visualization
RAIN_GPU_STATE_DEBUG_DISPLACEMENT_SCALE and RAIN_GPU_STATE_DEBUG_VELOCITY_SCALE are visualization controls.
They must not be used as substitutes for actual physics parameters.
Debug amplification must never be used to hide an incorrect physics model.

## 15. Development order
Step A: consolidate the already validated normal, tangent, gravity, acceleration, airflow, mass, adhesion, drag, max-speed and integration logic into one persistent physics path.
Step B: render independent persistent drops from state position/radius.
Step C: make surface movement and coordinate/boundary handling robust.
Step D: validate lifecycle: spawn -> attached -> threshold -> flowing -> boundary exit/death -> respawn wait -> respawn pending -> new valid spawn.
Step E: implement merge and recompute radius/mass/velocity.
Step F: implement residue/shrink.

## 16. Success criteria for the next implementation
Each state texel keeps an independent droplet identity.
A/B ping-pong remains stable.
Radius and mass affect motion.
Surface normal changes force projection.
Below adhesion, drops remain attached.
Above adhesion, velocity accumulates.
Drag damps velocity.
Maximum speed is enforced.
Position is integrated from velocity.
Debug 35/36 behavior remains recognizable after consolidation.
The procedural rainDropLayer() remains available for comparison.
No visual scale multiplier is used to compensate for incorrect physics.

## 17. Key conclusion
The RainFX project is past the initial physics-prototyping stage. The important work now is architectural consolidation: preserve the validated experiments, remove temporary duplication only when equivalent behavior is retained, and connect the persistent physics state to a real visor droplet renderer.

## 19. Lifecycle writeback validation — 2026-09-24

### 19.1 Boundary decision is confirmed

The Debug 41 / mode 7 experiment confirmed that the authoritative boundary decision itself is correct:

- valid mask area remains white;
- when the mask transitions from 1 -> 0, the predicted lifecycle crossing is detected;
- the diagnostic reliably turns yellow/red at the crossing;
- no UV sign conversion or coordinate remapping is required.

Therefore the remaining C3 issue is not boundary sampling.

### 19.2 Debug 39 result

Debug 39 / mode 6 showed:

- droplets are created;
- flow direction is acceptable;
- signed UV position integration works;
- no wrapping or teleporting was observed;
- however, droplets can remain visibly alive after leaving the mask.

This isolates the remaining problem to lifecycle state writeback/consumption or render-state observation.

### 19.3 Next diagnostic: Debug 42

Debug 42 was added as a metadata-only lifecycle probe:

- cyan = Meta.A = 1 (alive)
- black/transparent = Meta.A = 0 (dead/waiting)
- yellow = Meta.A = 2 (respawn pending)

It deliberately does not infer lifecycle state from the boundary mask. Its purpose is to determine whether the Meta.A transition is actually committed to the persistent metadata texture.

### 19.4 Test procedure

Use the accelerated C3 lifecycle validation mode (mode 6) and Debug 42.

Observe one or more drops until they cross the mask boundary.

Expected sequence:

cyan/alive -> black/dead -> remain hidden for respawn gap -> yellow/pending briefly -> cyan at a new valid position

The critical first observation is whether cyan changes to black immediately after Debug 41 reports a boundary crossing.

If Debug 41 crosses but Debug 42 never reaches black, inspect the Meta ping-pong/writeback path before changing physics or coordinates.

## 18. Coordinate/lifecycle consolidation record — 2026-09-24

The signed `pin.Tex` coordinate discovery is now treated as a project-wide architectural decision, not a debug-only observation.

The old normalized `[0,1]` persistent-state V coordinate and the `lerp(-0.579,-0.362, state.y)` diagnostic/render conversions are removed from the canonical model. Persistent state is generated and integrated directly in signed visor UV.

The C3 lifecycle is likewise defined in that same coordinate system. It has three Meta.A states:
- `0.0` = dead / waiting for respawn
- `1.0` = alive
- `2.0` = respawn pending; consumed by the state pass

Meta.B is the age/wait timer. Boundary exit is detected using the current-step midpoint and predicted position against the authoritative boundary mask. No wrapping is permitted.

The respawn position is generated by deterministic rejection sampling directly in signed UV and must pass the boundary mask. Respawn resets velocity to zero; Meta state then becomes alive.

This lifecycle intentionally does not yet implement merge or residue/shrink. Those remain later stages after final persistent rendering is validated.


## 20. Gravity reference and C2 momentum validation — 2026-09-24

The persistent physics baseline now treats the car's acceleration vector and physical gravity as separate external-force inputs. The previously observed `ac.StateSim.gravity` value is used as the gravity reference instead of hardcoding a second physical gravity constant.

For the current C2 validation:

- `ac.StateSim.gravity` is read on the Lua side.
- Its magnitude is converted into the compact persistent-force domain by `RAIN_GPU_STATE_GRAVITY_GAIN`.
- `RAIN_GPU_STATE_GRAVITY_REFERENCE = 9.81` documents the expected reference magnitude.
- The default gain `0.03567788` maps `9.81 m/s²` to the existing compact gravity magnitude `0.35`, preserving the previous baseline at the usual AC gravity value.
- Mode 8 uses the C2 controlled path, so surface-normal projection, boundary handling, procedural rain, vehicle acceleration and airflow are excluded from the test.
- Mode 8 also disables drag and uses a high speed ceiling by default so the test observes gravity-derived acceleration and velocity accumulation directly.

Debug 47 remains the movement probe:
- left = small mass
- center = medium mass
- right = large mass
- white = actual persistent velocity is present
- black = effectively stationary

The first validation should not tune the physical result to a visually pleasing value. It should establish whether gravity-derived force produces a monotonic, stable velocity response after the adhesion threshold is exceeded.

Recommended initial test:
1. Mode 8 + Debug 47.
2. Keep adhesion base at `1.20`.
3. Start with the default gravity gain. At `9.81 m/s²`, this produces compact force `0.35`, which is below the large-drop controlled threshold (`0.40`), so all three may remain attached.
4. Increase `GRAVITY_GAIN` until the large drop is just above its threshold. A gain around `0.041` corresponds to compact force around `0.40`.
5. Increase the gain further and verify that movement grows continuously rather than appearing as a sudden jump.
6. Only after this is stable should drag, max speed, vehicle acceleration and normal projection be reintroduced.

### 20.1 Directional jitter / zig-zag concept

A future "zig-zag" behavior should not be implemented as independent random noise every frame. That would look like shader noise rather than a droplet's contact-line behavior.

The preferred model is low-frequency stick-slip:
- maintain a persistent lateral state for each droplet;
- generate a deterministic, temporally correlated lateral bias from droplet identity and local surface position;
- let surface tension suppress small lateral changes while attached;
- once flowing, allow the bias to slowly change sign/direction;
- scale the lateral component with flow state and surface/adhesion properties;
- keep the perturbation small relative to the main gravity/vehicle-force direction.

This should create a gently wandering flow path rather than high-frequency vibration. It also preserves deterministic GPU behavior and avoids introducing a new random decision every frame.

This effect is intentionally deferred until the gravity-to-velocity chain is measured in isolation.


## 21. Gravity C2 test result — 2026-09-24

Mode 8 gravity-derived C2 validation was observed. `ac.StateSim.gravity` is converted through `GRAVITY_GAIN` and fed into the isolated C2 force path.

Observed behavior:
- At the default gain, all three Debug 47 bands were black.
- When a band became white, it eventually returned to black; after another interval it became white again. Increasing `GRAVITY_GAIN` shortened this repetition period. This is consistent with the particle moving through the persistent lifecycle and being respawned, rather than proving that velocity itself periodically decays to zero.
- Experimental observations: `GRAVITY_GAIN = 0.05486` produced Left white; `0.09810` produced Right white; `0.16799` produced Center white; `0.4153` was observed all black at the observation point.
- These gain values must not be treated as exact adhesion thresholds because Debug 47 is a binary instantaneous-velocity probe and the droplet can leave the valid surface and enter the lifecycle before observation.
- Visual speed could not be judged from Debug 47 because it only shows velocity as black/white.

Therefore the gravity-to-motion chain has evidence of producing persistent movement, but the current output cannot establish the magnitude or continuity of the generated momentum. A direct velocity-magnitude diagnostic is required before tuning gravity gain or acceleration scale.

Debug 48 was added for this purpose. It displays the current persistent velocity magnitude as grayscale for the three C2 bands. The displayed value is visualization-only and does not modify state. The next test should use Debug 48, preferably with lifecycle disabled or otherwise preventing boundary respawn from obscuring the velocity measurement.


## Debug 49 — C2 six-panel movement + velocity observation — 2026-09-24

Debug 48 exposed a measurement limitation: persistent velocity grows gradually, so a grayscale-only display can make slow acceleration difficult to detect by eye.

Debug 49 separates the two observations spatially:

- Left half: movement state, white when persistent velocity is non-zero and black when effectively stationary.
- Right half: current persistent velocity magnitude as grayscale.
- Six vertical strips are used left-to-right: L movement, L velocity, M movement, M velocity, S movement, S velocity.
- The six-strip layout is a display-only mapping; the persistent state remains three texels.

This allows the test to answer two independent questions at once:
1. Has the droplet crossed the adhesion gate and actually started moving?
2. After movement begins, is its persistent velocity increasing?

The velocity visualization uses `gRainStateDebugVelocityScale` only for display. It does not modify the physical velocity or integration.

### Gravity gain correction

The previously reported `GRAVITY_GAIN = 0.4153` was a typo. The correct observed value was:

`GRAVITY_GAIN = 0.04153`

Therefore the 0.04153 observation remains part of the consistent gravity-gain test series and must not be treated as an anomalous 0.4153 case.

The gravity C2 test remains based on `|ac.StateSim.gravity|` as the physical gravity magnitude, with the configurable gain converting it into the compact persistent-force domain.

### Next observation

Run Mode 8 with Debug 49 and compare:
- whether each L/M/S left panel changes from black to white;
- the corresponding right-panel brightness over time;
- whether higher `GRAVITY_GAIN` increases the rate of velocity growth without changing the qualitative mass ordering.

Do not introduce the proposed resting zig-zag/stick-slip behavior until this gravity-to-velocity chain is characterized.

## 22. CSP physical 9-drop reference test — 2026-09-24

The next tuning stage uses direct persistent droplet rendering instead of relying only on binary/grayscale diagnostics.

### 22.1 Fixed CSP-style test population

Mode 9 / Debug 50 creates exactly nine fixed droplets, arranged as three profiles with three diameter samples each:

| Profile | Min | Representative Average/Median | Max |
|---|---:|---:|---:|
| Light Rain | 0.5 mm | 0.95 mm | 2.0 mm |
| Moderate Rain | 0.5 mm | 1.50 mm | 4.0 mm |
| Heavy Rain | 0.5 mm | 2.50 mm | 6.0 mm |

The representative values 0.95, 1.50 and 2.50 mm are the midpoints of the supplied Average/Median ranges (0.8–1.1, 1.2–1.8 and 2.0–3.0 mm).

The nine positions are fixed across the configured test U range and share the center V of the configured test V range. This intentionally removes spawn-position randomness from the physical comparison.

### 22.2 Diameter -> radius -> mass baseline

The direct test maps 0.5–6.0 mm diameter linearly onto the existing calibrated persistent radius range 0.032–0.115. This is a render-space calibration, not a claim that those UV radii are literal world-space millimetres.

Mass is based on droplet volume, proportional to diameter cubed, then normalized into the current persistent test mass range 1.0–9.0:

mass = lerp(1, 9, (d^3 - 0.5^3) / (6.0^3 - 0.5^3))

This is a deliberately simple physical foundation for tuning. It preserves monotonic mass growth with diameter while remaining compatible with the existing adhesion model. It is not the final real-world mass calibration.

### 22.3 Respawn determinism for this test

Normal production respawn remains randomized.

Mode 9 is different: after lifecycle death and the respawn wait, each of the nine reference droplets restores its own fixed diameter/radius/mass instead of receiving a random radius. Therefore repeated observations at the same gravity gain remain physically comparable across lifecycle cycles.

This was necessary because normal respawn previously randomized radius, which could change mass, adhesion and resulting velocity between repeated observations.

### 22.4 Debug 50 direct visual output

Debug 50 renders the actual persistent droplets directly:
- pink droplet marker, alpha 1.0;
- no trail;
- white background with alpha 0.5 if at least one test droplet has non-zero persistent velocity;
- fully transparent background when all test droplets are effectively stationary.

The marker uses Meta.R directly, with no diagnostic enlargement multiplier. This is intentionally different from earlier oversized Stage 2 markers.

The purpose is to tune the physical parameters by observing actual droplet size, relative motion, acceleration and lifecycle behavior together.

### 22.5 Measurement criteria

For the nine reference droplets, observe:
1. onset of motion relative to diameter/mass;
2. acceleration after the adhesion threshold;
3. relative travel distance over a fixed observation interval;
4. whether velocity continues increasing or reaches a stable regime;
5. whether the same reference droplet behaves consistently after respawn;
6. whether the visual size ordering remains credible;
7. whether profile differences remain plausible rather than being dominated by the test-position normal.

Debug 49 remains the internal state instrument and should be used alongside Debug 50 when a visual result needs to be correlated with persistent velocity.

### 22.6 Gravity-gain observations immediately preceding the direct test

Observed with the previous three-drop gravity diagnostic:
- GRAVITY_GAIN = 0.06443: Left white, velocity display very dark;
- GRAVITY_GAIN = 0.09564: Right white, velocity display almost black;
- GRAVITY_GAIN = 0.16217: Middle white, velocity display black.

Because the previous test could randomize radius during normal respawn, these observations should not be interpreted as exact threshold boundaries. The direct nine-drop test removes that confounder.


## 23. Mode 9 / Debug 50 observation and C2 isolation correction — 2026-09-25

### 23.1 Test 50 observation

Mode 9 / Debug 50 was observed with the fixed nine-drop physical reference population.

Observed:
- all nine droplets move in the same vertical direction;
- at the individual onset gain, movement is very slow; at the threshold level a droplet takes roughly 17 seconds to cross about half of the visor's vertical test area;
- increasing `GRAVITY_GAIN` increases the observed movement speed continuously;
- at the default `GRAVITY_GAIN = 0.03567788`, all droplets remain stationary;
- observed onset order, using 1-based particle indices:
  `9 (0.042) > 4 (0.11525) > 8 (0.11798) > 6 (0.12346) > 5 (0.12620) > 7 (0.14264) > 1 (0.14538) > 3 (0.15360) > 2 (0.18923)`.

The common vertical direction confirms that the gravity path is active visually, but the threshold ordering does not match the intended fixed-mass C2 model.

### 23.2 Root cause: Mode 9 lost C2 isolation after initialization

The nine-drop Meta values are deterministic and were confirmed from the physical-test branch to be:

| Index | Diameter | Mass |
|---:|---:|---:|
| 1 | 0.5 mm | 1.000 |
| 2 | 0.95 mm | 1.027 |
| 3 | 2.0 mm | 1.292 |
| 4 | 0.5 mm | 1.000 |
| 5 | 1.5 mm | 1.121 |
| 6 | 4.0 mm | 3.367 |
| 7 | 0.5 mm | 1.000 |
| 8 | 2.5 mm | 1.574 |
| 9 | 6.0 mm | 9.000 |

However, `initializeRainGPUState()` and `updateRainGPUState()` did not use the same Mode 9 C2 flags.

Initialization set Mode 9 as C2/gravity-isolated, but the per-frame update later assigned:
- `gRainStateC2Isolation = 1` only for Mode 5;
- `gRainStateC2UseGravity = 1` only for Mode 8.

Therefore Mode 9 entered the correct controlled path during initialization, then silently fell back to the normal persistent surface-physics path on subsequent frames.

The normal path calls `rainStateAdhesion(stateIndex, mass)`, whose base adhesion is randomized independently for every state index:

`adhesionBase = lerp(gRainStateAdhesionMin, gRainStateAdhesionMax, rainStateHash(stateIndex + 211))`

That random per-index adhesion explains why equal-size droplets 1/4/7 can have different observed onset gains. It also explains why the observed ordering cannot be attributed to the deterministic Mode 9 mass table alone.

This is a state/update-parameter mismatch, not evidence that the State and StateMeta texels are ping-ponging independently or losing their index identity.

### 23.3 Correction

Mode 9 now keeps the following flags active during every persistent-state update:
- `gRainStateTestGrid = 1`
- `gRainStateC2Isolation = 1`
- `gRainStateC2UseGravity = 1`
- `gRainStatePhysicalTest = 1`
- `gRainStateC2GravityMultiplier = 1`
- C2 test drag and max-speed settings remain the Mode 9 values.

The controlled physics path therefore uses exactly:

`force = (0, gRainStateGravity)`

`adhesion = 1.2 / sqrt(mass)`

with no random per-index adhesion and no normal-map-dependent force magnitude.

### 23.4 Predicted corrected threshold order

For `gRainStateGravity = 9.81 * GRAVITY_GAIN`, the controlled threshold is:

`GRAVITY_GAIN_threshold = (1.2 / sqrt(mass)) / 9.81`

Using the fixed Mode 9 mass table, the predicted onset gains are approximately:

| Index | Mass | Predicted onset gain |
|---:|---:|---:|
| 9 | 9.000 | 0.04077 |
| 6 | 3.367 | 0.06666 |
| 8 | 1.574 | 0.09750 |
| 3 | 1.292 | 0.10762 |
| 5 | 1.121 | 0.11553 |
| 2 | 1.027 | 0.12071 |
| 1 | 1.000 | 0.12232 |
| 4 | 1.000 | 0.12232 |
| 7 | 1.000 | 0.12232 |

Thus 1/4/7 must have the same threshold in the corrected C2 test, apart from numerical/texture sampling effects that are not expected to produce a large systematic separation.

The previous observation of index 9 at approximately 0.042 is notably close to the corrected controlled prediction of 0.04077, but that agreement was coincidental because the actual running path was the randomized adhesion path. It must not be used as validation of the old implementation.

### 23.5 Physical droplet UV-size calibration

The Mode 9 visual radius mapping was also corrected using the measured visor-UV reference supplied for this test:

- 2.0 mm diameter = 0.005859375 UV
- 4.0 mm diameter = 0.01171875 UV
- 6.0 mm diameter = 0.017578125 UV
- therefore 1.0 mm diameter = 0.0029296875 UV
- therefore 0.1 mm diameter = 0.00029296875 UV
- radius = diameter * 0.00146484375 UV

The previous Mode 9 mapping of radius `0.032..0.115` was a legacy diagnostic radius range and made the 6 mm reference droplet far too large relative to the actual measured visor UV. Mode 9 now uses the measured physical UV diameter relationship directly, including on deterministic respawn.

This calibration is a render/UV measurement contract for the visor mesh. It does not yet claim that UV distance itself is a world-space physical length.

### 23.6 Next validation

Re-run Mode 9 / Debug 50 after the correction. The purpose is now narrow:
1. verify that 1/4/7 have effectively identical onset gain;
2. verify the onset order follows mass monotonically, approximately 9 -> 6 -> 8 -> 3 -> 5 -> 2 -> 1/4/7;
3. verify the visual diameters match the measured UV ratios;
4. verify movement speed/acceleration can then be tuned without randomized adhesion or normal-position differences contaminating the result.

Debug 49 remains the persistent-state instrument and should be used only to correlate the direct visual test with State.B/A velocity; it is not the primary physical-size observation.


---

## 24. Stage 7C — size-dependent persistent max speed — 2026-09-25

### 24.1 Decision

Stage 7C is implemented as a separate velocity cap after adhesion-driven acceleration and before position integration.

~~~
external force
    ↓
surface tangent projection
    ↓
adhesion threshold
    ↓
flow acceleration
    ↓
drag
    ↓
size-dependent max speed
    ↓
position integration
~~~

The max-speed stage only changes velocity magnitude. It does not choose or rotate the velocity direction.

### 24.2 Research basis

Atlas/Ulbrich's power-law fit for free-falling raindrop terminal speed is:

~~~
V(D) = 3.778 × D^0.67
~~~

where D is diameter in millimeters and V is free-fall speed in m/s. The fit is reported as a close approximation to Gunn–Kinzer measurements over approximately 0.5–5.0 mm.

This project does not use that m/s value directly because visor droplets are surface-bound rather than freely falling. Only the observed size dependence (D^0.67) is retained; absolute surface speed is calibrated independently in visor UV/s.

References:
- https://journals.ametsoc.org/view/journals/atsc/60/10/1520-0469_2003_60_1220_tmsoep_2.0.co_2.xml
- https://journals.ametsoc.org/view/journals/atsc/78/4/JAS-D-20-0161.1.xml

### 24.3 Exact visor size conversion

Debug 50 established:

~~~
1.0 mm diameter = 0.0029296875 UV
radius = diameter × 0.00146484375 UV
~~~

Therefore:

~~~
diameterMM =
    (radiusUV × 2)
    / 0.0029296875
~~~

The conversion is passed explicitly to the persistent shader as gRainStatePhysicalDiameterUVPerMM.

### 24.4 Implemented equation

For Mode 9 / Debug 50:

~~~
sizeFactor = diameterMM^0.67

maxSpeedUVPerSecond =
    gRainStatePhysicalMaxSpeed1MM
    × sizeFactor
~~~

Current starting calibration:

~~~
RAIN_GPU_STATE_PHYSICAL_MAX_SPEED_1MM = 0.004 UV/s
RAIN_GPU_STATE_PHYSICAL_MAX_SPEED_EXPONENT = 0.67
~~~

The 0.004 UV/s value is a visor calibration starting point, not a measured real-world surface-flow velocity.

Relative max-speed factors are approximately:

~~~
0.5 mm → 0.63
0.95 mm → 0.97
1.0 mm → 1.00
1.5 mm → 1.31
2.0 mm → 1.59
2.5 mm → 1.84
4.0 mm → 2.52
6.0 mm → 3.21
~~~

### 24.5 Separation of responsibilities

- Adhesion threshold determines whether external tangential force can initiate/continue flow.
- Flow acceleration determines how quickly velocity grows after threshold.
- Drag will later determine how quickly velocity responds to changing forces and how quickly old momentum decays.
- Max speed only caps velocity magnitude.
- Position integration consumes the final velocity.

This leaves the model ready for later vehicle acceleration, airflow drag, and other external forces without coupling max speed to their direction.

### 24.6 Validation target

Mode 9 uses gravity-derived C2 force with drag disabled, while the new size-dependent max-speed cap is active.

Observe whether each fixed reference droplet reaches a stable velocity plateau. Exact slider-threshold measurements are not required. The important checks are:

1. velocity grows before the cap,
2. velocity stops growing at the cap,
3. larger droplets have higher caps,
4. direction is unchanged by the cap,
5. changing the 1 mm calibration shifts all nine caps together without changing their relative size curve.

### 24.7 Scope

The physical-reference max-speed branch is intentionally isolated to Mode 9. General persistent RainFX droplets retain the existing global max-speed parameter until their visual size representation is put on the same physical UV/mm calibration.

The external shaders/rainVisorScreen.hlsl validation pass is not modified. The active persistent physics implementation is the shader string embedded in realvisor.lua; changing only the unused validation copy would create divergence.

---

## 25. Combined-force validation Stage Gate — 2026-09-25

### 25.1 Motivation

Size/mass/adhesion (Sections 22-24, Mode 9 / Debug 50) and the underlying surface-normal + gravity + vehicle-acceleration force model (Sections 5-6, validated individually via Debug 15/27/30/32/33) had never been combined and observed together in the actual production physics path (`RAIN_GPU_STATE_MODE = 3`, non-C2-isolated).

Mode 9 / Debug 50 is a **controlled/isolated** calibration test: it bypasses surface-normal projection entirely (`gRainStateC2Isolation = 1`, constant compact-space force) so that size-dependent adhesion/max-speed could be measured without normal-projection noise. It is therefore not a validation of the real, curvature-driven force path, and must not be treated as a substitute for it.

Per Section 19 (Stage gate rule): do not change multiple physical concepts at once. This section defines the two-stage combined-force test that isolates surface-normal+gravity first, then reintroduces vehicle acceleration, using the same production path (Mode 3) that Mode 9 deliberately bypasses.

### 25.2 Isolation switch added: `RAIN_TEST_ACCEL_ENABLED`

A new `cfg.RUNTIME` flag was added specifically for this test:

```lua
RAIN_TEST_ACCEL_ENABLED = true,  -- default: production behavior unchanged
```

Implementation (`updateRainFlow(dt)`):

```lua
local targetAcceleration =
    vec3(
        rawAcceleration.x * cfg.RUNTIME.RAIN_ACCEL_GAIN,
        rawAcceleration.y * cfg.RUNTIME.RAIN_ACCEL_GAIN,
        rawAcceleration.z * cfg.RUNTIME.RAIN_ACCEL_GAIN
    )

if not cfg.RUNTIME.RAIN_TEST_ACCEL_ENABLED then
    targetAcceleration:set(0, 0, 0)
end
```

Design constraints honored:
- This zeroes only the **input** to the existing exponential smoothing (`rainAccelerationCurrent`). It does not touch `gRainAcceleration`, gravity, normal decoding, tangent projection, adhesion, drag, or max-speed. No physics term other than the vehicle-acceleration contribution is affected.
- Because the smoothing target simply becomes `(0,0,0)`, toggling the flag mid-session decays/rises smoothly (`RAIN_FLOW_RESPONSE`-controlled), matching the existing "smooth acceleration itself, not drop position" rule — no position or velocity discontinuity is introduced by the flag itself.
- Airflow remains independently gated by `RAIN_GPU_STATE_USE_AIR_DRAG` (default `false`) and is unaffected by this flag; airflow/air-drag integration is explicitly out of scope for this stage (see Engineering Rule #5, Section 14 of the companion document `RainFXPersistentGPU.md`).
- A matching UI checkbox was added to the RainFX tab, directly below `STATE_MODE`, with inline stage-state text so the active stage is visible without checking the ini file.

### 25.3 Stage 1 — Surface normal + gravity only

Purpose: verify that projected gravity alone produces curvature-consistent flow across the visor surface, using the real per-drop/per-fragment surface normal (not a synthetic/controlled tangent as in Mode 5/8/9).

Required configuration:

| Setting | Value |
|---|---|
| `RAIN_GPU_STATE_MODE` | 3 (persistent RainFX physics, full path, not C2-isolated) |
| `RAIN_TEST_ACCEL_ENABLED` | **false** |
| `RAIN_GPU_STATE_USE_AIR_DRAG` | false (default, unchanged) |
| `RAIN_GPU_STATE_COUNT` | 256 (default) or lower for visual clarity |

Recommended Debug sequence:
1. `RAIN_DEBUG = 27` (`rainPersistentSurfaceForceDebugOutput`) — shows the projected tangent-force direction field evaluated at the actual rendered surface. This isolates the force *field* itself (normal + gravity only, since `RAIN_TEST_ACCEL_ENABLED = false` zeroes the other term of `rainStateExternalForceWorld()`) from drop/adhesion behavior.
2. `RAIN_DEBUG = 19` or `29` — persistent drop positions/markers, to confirm drops actually follow the field direction shown by Debug 27.
3. `RAIN_DEBUG = 0` (actual render) — final visual sanity check.

Pass criteria:
- The Debug 27 force-direction field varies continuously with visor curvature (not uniform/flat across the surface), consistent with the already-validated Debug 33 projection behavior.
- Direction is plausible relative to the surface curvature parameters (`RAIN_SURFACE_CURVATURE_X/Y`, `RAIN_SURFACE_SLOPE_Y`): lateral curvature should visibly bend flow sideways near the visor edges; the downward slope bias should dominate near the vertical center.
- No sudden direction flips or NaN/black regions while the car is stationary (this would indicate a Section 5 tangent-basis or normal-decoding regression, not a new bug — those paths are already validated, so a failure here should first be treated as a *test-configuration* error, e.g. a leftover C2/physical-test flag, before touching normal/tangent code).
- Drops in Debug 19/29 visibly move toward lower visor regions / laterally near curved edges, without needing vehicle motion.

### 25.4 Stage 2 — + vehicle acceleration

Purpose: confirm vehicle acceleration combines with the already-validated Stage 1 curvature response without contaminating direction or producing implausible magnitude, using the same Mode 3 path.

Required configuration change from Stage 1: only `RAIN_TEST_ACCEL_ENABLED = true` (everything else unchanged).

Recommended Debug sequence:
1. `RAIN_DEBUG = 1` (force magnitude/components) or `6` (movement direction/strength) — both read `effectiveForce = gravityForce + gRainAcceleration * gRainForceScale` with **no airflow term**, making them the correct diagnostics for this stage (Debug 34's combined-force diagnostic intentionally always includes airflow for its own purposes and should not be used here).
2. `RAIN_DEBUG = 30` (`rainPersistentForceVelocityDebugOutput`) — compares the current tangent-force direction against the persistent drop's actual stored velocity direction, useful for judging whether the drag/acceleration response lags or overshoots implausibly under braking/cornering.
3. `RAIN_DEBUG = 0` — final visual check under acceleration, braking and cornering.

Pass criteria:
- Force direction/magnitude in Debug 1/6 responds sensibly to acceleration, braking, and cornering (already spot-checked in isolation via Debug 32 for the analogous airflow-input path; this stage performs the equivalent check for the vehicle-acceleration term actually used by production physics).
- Debug 30's force-vs-velocity comparison shows the velocity direction trending toward the force direction with plausible lag (governed by `RAIN_FLOW_DRAG`), not instant snapping or unbounded divergence.
- Re-toggling `RAIN_TEST_ACCEL_ENABLED` on/off during a drive shows a smooth transition (per Section 25.2), not a jump.

### 25.5 Relationship to Mode 9 / Debug 50

Stage 1/2 (this section) and Mode 9/Debug 50 (Sections 22-24) validate different, complementary aspects and are not a sequential replacement of one another:

| | Stage 1/2 (Mode 3) | Mode 9 (Debug 50) |
|---|---|---|
| Force path | Real surface-normal projection | Controlled compact-space force, normal projection bypassed |
| Purpose | Qualitative directional plausibility (does flow follow curvature + vehicle motion) | Quantitative size/mass/adhesion/max-speed calibration under a controlled, uniform force |
| Adhesion | Per-index hashed (production) unless manually narrowed for a cleaner signal | Deterministic, mass-derived, no hashing |
| Status | New (this section) | Sections 22-24, C2-isolation bug already fixed |

Recommended order going forward: Stage 1 -> Stage 2 -> re-confirm Mode 9/Debug 50 still holds under the corrected combined model, before any airflow/drag integration work begins (Engineering Rule #5).

### 25.6 Optional: reducing adhesion threshold noise for Stage 1

Stage 1's per-index hashed adhesion (`rainStateAdhesion()`, `RAIN_ADHESION_MIN/MAX = 0.65..2.20`) is production-realistic but adds threshold-crossing noise on top of the pure curvature signal being tested. `RAIN_ADHESION_MIN/MAX` are not currently exposed as UI sliders; if the Stage 1 force field (Debug 27) looks curvature-consistent but drop motion (Debug 19) looks inconsistent or sparse, temporarily lowering both values (e.g. to `~0.05-0.15`) via `settings.ini` removes the threshold gate as a confound. Revert to `0.65/2.20` before Stage 2 or any adhesion-related conclusion.

### 25.7 Result log (fill in after each test run)

| Date | Stage | STATE_MODE | RAIN_DEBUG | Observation | Verdict |
|---|---|---|---|---|---|
| _pending_ | 1 | 3 | 27 -> 19 -> 0 | | |
| _pending_ | 2 | 3 | 1/6 -> 30 -> 0 | | |


## 26. Persistent tangent-V orientation correction — 2026-09-25

Mode 9 / Debug 50 was the signed-V direction reference and moved downward. The corresponding Mode 10 / Debug 50 test moved upward. Because Mode 10 uses the world-gravity -> normal-derived tangent path while Mode 9 directly injects +V gravity, this isolates the discrepancy to the tangent-frame orientation rather than gravity sign, adhesion, max-speed, or position integration.

The persistent shader constructs U by projecting object-space +X onto the surface tangent plane and derives V with a cross product. That construction is mathematically right-handed but does not, by itself, guarantee that V has the same orientation as the actual mesh UV V. The project contract requires increasing V to mean moving downward, and the observed Mode 10 result demonstrated that the derived V was reversed for the active visor configuration.

The correction keeps U unchanged and orients the derived V against canonical object-space -Y:

```
V = normalize(cross(normal, U))
if (dot(V, float3(0,-1,0)) < 0) V = -V
```

This is intentionally limited to the persistent surface-force projection path. It does not modify gravity magnitude, droplet mass/radius, adhesion thresholds, flow acceleration, drag, max-speed, State/Meta texel layout, or signed UV coordinates.

### Next validation

Re-run the exact previous comparison with no parameter changes:
- Mode 9 / Debug 50: reference;
- Mode 10 / Debug 50;
- stationary vehicle;
- `RAIN_TEST_ACCEL_ENABLED = false`;
- `RAIN_GPU_STATE_SURFACE_GRAVITY_TEST_DRAG = 0`.

Acceptance target: Mode 9 remains downward and Mode 10 changes from upward to downward. Only after this direction gate passes should curvature-dependent differences and the Stage 7B vehicle-acceleration gate be evaluated.

## 27. Phase A — unified external-force pipeline — 2026-09-25

### 27.1 Design decision

The persistent RainFX physics path now treats all external influences as one world-space force pipeline:

~~~text
source selection (UI bitmask)
        ↓
gravity / vehicle inertia / airflow
        ↓
WORLD-space SI acceleration
        ↓
shared acceleration → compact surface-force conversion
        ↓
single surface-normal / tangent projection
        ↓
adhesion threshold
        ↓
flow acceleration
        ↓
surface drag
        ↓
size-dependent max speed
        ↓
position integration
~~~

The important rule is that no external source chooses its own tangent frame or directly edits UV velocity. Source-specific logic ends before the common surface projection.

### 27.2 Force-source bitmask

The Lua UI exposes three independent checkboxes:

- Gravity = bit 1
- Vehicle Inertia = bit 2
- Airflow = bit 4

The selected sources are packed into gRainForceMask.

| Enabled sources | Mask |
|---|---:|
| none | 0 |
| gravity | 1 |
| inertia | 2 |
| gravity + inertia | 3 |
| airflow | 4 |
| gravity + airflow | 5 |
| inertia + airflow | 6 |
| all | 7 |

This is a source-selection mechanism, not three independent physics pipelines.

### 27.3 Vehicle inertia input

ac.getCar(0).acceleration is now the authoritative vehicle-acceleration input.

The API is treated as car-local G acceleration:

- X = side
- Y = up
- Z = look / forward

Lua converts it to world space:

~~~lua
accelerationWorld =
    car.side * accelerationG.x
    + car.up * accelerationG.y
    + car.look * accelerationG.z
~~~

The visor droplet receives inertial force in the opposite direction:

~~~text
a_inertia_world = -accelerationWorld × 9.81
~~~

Therefore the shader receives this source in SI m/s².

The previous finite-difference velocity path has been removed from RainFX physics. RAIN_ACCEL_GAIN remains only as a compatibility setting.

### 27.4 Common acceleration unit

All three external sources use the same physical acceleration domain before projection:

- gravity: m/s²
- vehicle inertia: m/s²
- airflow: m/s²

A single RAIN_PHYSICS_ACCEL_SCALE = 0.03567788 converts SI acceleration to the compact persistent surface-force domain.

The current value preserves the previously validated gravity calibration:

~~~text
9.81 m/s² × 0.03567788 ≈ 0.35 compact force
~~~

This is a project calibration constant, not an SI interpretation of compact UV-space force.

### 27.5 Gravity

Gravity remains the existing validated world-down source.

ac.getSim().gravity supplies the magnitude. The persistent source is explicitly:

~~~text
F_gravity = (0, -|g|, 0)
~~~

It is then converted with the same common acceleration scale and projected onto the local visor surface.

The signed-V contract remains:

- V = -1 at the visor top
- V = 0 at the visor bottom
- increasing V = physically downward

The tangent-V canonical orientation correction from Section 26 remains unchanged.

### 27.6 Airflow model

Phase A airflow uses the current relative-air approximation:

~~~text
V_air_relative = -car.velocity
~~~

Simulation wind is intentionally not included yet.

For each persistent drop, aerodynamic acceleration is calculated in SI units:

~~~text
F_drag =
    0.5 × rho_air × |V_rel|² × Cd × A × incidence
~~~

with:

- rho_air = 1.20 kg/m³
- Cd = 0.47
- A = pi r²
- water density = 1000 kg/m³
- m = volume × 1000
- volume = 4/3 × pi r³

The current visor calibration converts persistent UV radius to diameter in millimeters:

~~~text
diameterMM =
    (radiusUV × 2) / 0.0029296875
~~~

### 27.7 One-sided surface incidence

Airflow does not apply simply because air speed is non-zero.

The current incidence term is:

~~~text
incidence = saturate(-dot(airDirection, surfaceNormal))
~~~

Therefore:

- air travelling into the surface normal side produces aerodynamic pressure;
- air travelling away from the surface produces zero aerodynamic source force;
- the rigid visor removes the normal component during the final tangent projection;
- only the resulting tangent component can drive surface motion.

This is intentionally different from abs(dot(...)); the shielded side should not generate pressure.

The sign convention must be revalidated in-game against the active visor normal orientation before airflow becomes default-on.

### 27.8 Phase A test protocol

Use:

~~~text
STATE_MODE = 3
RAIN_DEBUG = 27 → 30/1/6 → 0
~~~

and change only the source checkboxes.

#### A1 — Gravity only

- Gravity: ON
- Vehicle Inertia: OFF
- Airflow: OFF
- Stationary car
- RAIN_GPU_STATE_SURFACE_GRAVITY_TEST_DRAG = 0

Expected:
- same curvature-driven direction accepted in Mode 10 / Debug 50;
- no dependency on car acceleration;
- no sudden direction reversal.

#### A2 — Vehicle inertia only

- Gravity: OFF
- Vehicle Inertia: ON
- Airflow: OFF

Perform:
1. straight acceleration,
2. straight braking,
3. left/right cornering,
4. combined braking + cornering.

Expected:
- droplets move opposite vehicle acceleration;
- longitudinal input follows car look after world conversion;
- lateral input follows car side after world conversion;
- no camera-space dependence.

This is the primary regression test for the previous Test 23 / Mode 3 vertical sign discrepancy.

#### A3 — Gravity + vehicle inertia

- Gravity: ON
- Vehicle Inertia: ON
- Airflow: OFF

Keep all other parameters identical to A1/A2.

Expected:
- total direction is the vector sum of both sources;
- gravity remains present when the car is stationary;
- inertia changes total direction smoothly rather than replacing gravity.

#### A4 — Airflow only

- Gravity: OFF
- Vehicle Inertia: OFF
- Airflow: ON

Test several vehicle speeds and visor orientations.

Expected:
- no airflow effect at zero relative speed;
- stronger response with increasing speed;
- no force when airflow is on the shielded side according to the signed incidence test;
- tangent motion follows projected airflow direction;
- larger drops respond differently because area/mass changes.

### 27.9 Phase A acceptance rule

Do not retune adhesion, flow acceleration, drag, or max-speed while validating source direction.

First establish:

1. each source has the correct sign;
2. each source reaches the shader in WORLD space;
3. all enabled sources are summed once;
4. one tangent projection handles the combined result;
5. the UI mask changes only source inclusion.

Only after these pass should physical magnitude calibration proceed.

### 27.10 API reference

The CSP Lua SDK is the external API reference for ac.getCar(0) state access. The project additionally relies on the installed CSP build's EmmyLua definitions and the in-game verified up, look, side, and acceleration fields.

Reference:
https://github.com/ac-custom-shaders-patch/acc-lua-sdk

### 27.11 Compatibility notes

- RAIN_TEST_ACCEL_ENABLED is no longer part of the active force-selection path. The Phase A Vehicle Inertia checkbox replaces it as the authoritative isolation control.
- RAIN_GPU_STATE_USE_AIR_DRAG is retained for compatibility but the active source gate is now RAIN_FORCE_AIRFLOW_ENABLED.
- RAIN_ACCEL_GAIN and RAIN_ACCEL_GAIN_X/Y/Z remain as legacy settings for compatibility and historical comparison; they are not used by the new SI inertia path.
- C2 Mode 5/8/9 controlled paths remain calibration instruments. They do not replace the unified Mode 3 production force path.

## 28. Physical droplet profile reuse and Phase A test environment — 2026-09-26

### 28.1 Problem identified

Debug 50 established the first project-approved droplet size/profile reference, but earlier state modes still initialized their Meta texels with arbitrary legacy radii and normalized masses.

Those older tests therefore cannot be used as physical-force tests merely by enabling the new unified force pipeline. A force test is only meaningful when radius, mass, size-dependent max speed, and profile assignment are the same physical model.

### 28.2 Shared Debug 50 profile

The Debug 50 profile is now implemented once in the persistent Meta shader:

```text
Light:     0.5 / 0.95 / 2.0 mm
Moderate:  0.5 / 1.5  / 4.0 mm
Heavy:     0.5 / 2.5  / 6.0 mm
```

The existing measured conversion remains authoritative:

```text
1 mm diameter = 0.0029296875 UV diameter
1 mm radius   = 0.00146484375 UV radius
```

The mass profile is centralized without changing the established Debug 50 model:

```text
volume is proportional to diameter^3
massProfile = lerp(1, 9, saturate((diameter^3 - 0.5^3) / (6.0^3 - 0.5^3)))
```

The values 1..9 are the project's established normalized Meta mass domain. They are not being silently reinterpreted as kilograms.

### 28.3 Reusable profile switch

The UI now exposes:

```text
Droplet Size Model
    [0] Legacy debug radius/mass
    [1] Debug 50 physical profile
```

When [1] is selected, legacy state modes reuse the same Debug 50 radius/mass profile for their Meta texels.

This is deliberately separate from the force-source mask. It allows testing the same physics with different force sources while keeping the same physical droplet population.

Changing the size model invalidates the persistent state textures so all droplets are regenerated under the selected profile.

### 28.4 Phase A Debug 51

A new state mode is provided:

```text
[51] Physical 9-drop unified-force state
```

Debug 51 always uses the Debug 50 physical profile and allocates exactly nine persistent droplets.

The nine droplets are:

```text
L: 0.5 / 0.95 / 2.0 mm
M: 0.5 / 1.5  / 4.0 mm
H: 0.5 / 2.5  / 6.0 mm
```

Debug 51 uses the unified external-force pipeline documented in Section 27.

### 28.5 Why Debug 51 is preferred

The old modes retain their historical meaning and remain useful for debugging earlier stages.

Debug 51 is a clean physical test environment with a fixed nine-drop population, the Debug 50 radius mapping, the Debug 50 normalized mass profile, the current size-dependent max-speed law, the unified force bitmask, world-space inertia conversion, and the current surface-normal/tangent projection.

This prevents a physical-force result from being ambiguous because an older diagnostic mode quietly changed the droplet model.

### 28.6 Phase A test matrix

With Debug 51 selected, use only the force checkboxes to isolate sources:

| Test | Gravity | Inertia | Airflow |
|---|---:|---:|---:|
| A1 | ON | OFF | OFF |
| A2 | OFF | ON | OFF |
| A3 | ON | ON | OFF |
| A4 | OFF | OFF | ON |

For A1/A2/A3, keep `RAIN_GPU_STATE_SURFACE_GRAVITY_TEST_DRAG = 0` and do not change adhesion, flow acceleration, surface drag, or max-speed parameters while judging force direction.

### 28.7 Acceptance priority

First establish: correct force sign; correct local-car to world conversion; correct inertial inversion; correct one-sided airflow incidence; correct source summation; one common tangent projection. Only then tune magnitude and response.

### 28.8 Legacy-mode compatibility

The default size-model selector remains [0] Legacy so historical debug modes do not silently change behavior.

Selecting [1] Debug 50 physical profile explicitly upgrades the Meta size/mass population of applicable legacy modes.

Debug 51 does not depend on that UI selection: it always forces the physical profile.

This provides both historical reproducibility and a clean physical validation mode.
## 29. Correction: physical validation belongs to Debug 51, not State Mode 51 — 2026-09-26

The previous implementation incorrectly introduced `STATE_MODE = 51` for the Phase A physical viewer. This mixed two independent concepts:

- `RAIN_GPU_STATE_MODE` selects state/update behavior.
- `RAIN_DEBUG` selects visualization.

The correction is now applied:

```text
STATE_MODE = 10
DEBUG = 51
Droplet Size Model = Debug 50 physical profile
```

State Mode 10 remains the established physical surface-normal + gravity validation path and is now the Phase A physical unified-force state-update path.

Debug 51 is the new visualization path. It reads the actual persistent State + Meta textures produced by the physics pass and does not create a separate physics model.

Debug 50 remains the historical CSP physical reference visualization. It is not the Phase A unified-force viewer.

### 29.1 Why the previous Mode 51 could hide the real problem

The project has several independent switches:

```text
State Mode -> controls GPU state initialization/update behavior
Droplet Size Model -> controls Meta radius/mass profile
Rain Debug -> controls final pixel visualization
```

The normal render path (`RAIN_DEBUG = 0`) does not render persistent GPU state. It renders the procedural `rainDropLayer()` result. Therefore a physically moving persistent state can exist correctly in the GPU textures while being invisible in the normal rain image.

Each debug output in `shaders/rainVisorScreen.hlsl` is also an independent diagnostic renderer. Selecting a debug mode does not automatically mean that its output represents the complete unified physics pipeline.

This explains why a force can be correctly integrated yet appear visually absent or inconsistent between tests.

### 29.2 Phase A visual contract

For physical-force testing, use:

```text
STATE_MODE = 10
RAIN_DEBUG = 51
Droplet Size Model = [1] Debug 50 physical profile
```

Debug 51 samples `txRainState` and `txRainStateMeta` directly and visualizes the resulting persistent positions and physical radii.

The debug renderer does not independently calculate gravity, inertia, airflow, adhesion, drag, or max speed. The physics shader has already produced the State texel that Debug 51 displays.

```text
External forces
    ↓
unified force
    ↓
surface projection
    ↓
adhesion
    ↓
flow acceleration
    ↓
surface drag
    ↓
max speed
    ↓
position integration
    ↓
txRainState
    ↓
Debug 51
```

### 29.3 Why old Debug 19/29/etc. are not sufficient for Phase A

Those diagnostics were created for earlier stages and intentionally contain their own visualization assumptions, such as artificial marker-radius remapping, legacy L/M/S assumptions, stage-specific color/strength encoding, diagnostic-only force calculations, or outputs that visualize a field rather than the integrated state.

They remain useful for their original purposes, but they cannot all be considered interchangeable views of the unified physical engine.

Debug 51 is therefore the canonical Phase A integrated-state viewer.

### 29.4 Combination matrix

| State Mode | Size Model | Debug | Meaning |
|---|---|---|---|
| 10 | Legacy | 19/29/etc. | historical physical/state diagnostics |
| 10 | Physical | 50 | historical Debug 50 reference visualization |
| 10 | Physical | 51 | **Phase A canonical integrated-state visualization** |
| 3 | Physical | 51 | unified-force state visualization on normal persistent physics |
| 3 | Legacy | 51 | useful only for comparing physical vs legacy Meta behavior |

The key rule is that Debug 51 is a viewer, not a physics mode.

### 29.5 Phase A test sequence

Do not change State Mode between A1-A4.

Keep:

```text
STATE_MODE = 10
Droplet Size Model = Debug 50 physical profile
DEBUG = 51
```

Then change only the Gravity / Vehicle Inertia / Airflow checkboxes.

This makes the visual result comparable across all four force-isolation tests.

### 29.6 Established continuity

The state-mode sequence is restored to:

```text
0 → 1 → 2 → 3 → 4 → 5 → 6 → 7 → 8 → 9 → 10
```

No State Mode 51 exists.
The number 51 is reserved for the new visual diagnostic so the historical state-mode progression remains intact.