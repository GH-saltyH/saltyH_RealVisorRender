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

## 30. Legacy prototype physics removal and canonical model consolidation — 2026-09-26

The persistent RainFX system has now been cleaned so the active implementation no longer contains the earlier artificial-force prototype models.

### 30.1 Removed prototype model families

The following are no longer part of the runtime physics or configuration:

- synthetic tangent-force injection used by the old Stage 1 state proof;
- the old global RAIN_FORCE_SCALE multiplier;
- the old finite-difference/camera-axis acceleration gains;
- the old acceleration-response smoothing multiplier;
- the old artificial RAIN_GRAVITY = 0.35 surface-force model;
- C2 controlled force/adhesion/gravity multiplier branches;
- C3 temporary speed, acceleration, drag and max-speed overrides;
- legacy arbitrary radius/mass state initialization;
- procedural curvature/slope force fields;
- procedural travel-distance/lifetime physics;
- the old persistent debug-origin displacement infrastructure;
- the old procedural render shader's independent force/travel simulation.

These values are not retained as compatibility physics. They must not be reintroduced into the canonical RainFX path.

### 30.2 Canonical external-force model

All active external sources are selected by one bitmask:

- bit 1: gravity;
- bit 2: vehicle inertia;
- bit 4: airflow.

The enabled sources are summed once in WORLD space and then passed through the same surface projection:

F_external = F_gravity + F_inertia + F_airflow

All source accelerations remain in SI m/s² until the established common RAIN_PHYSICS_ACCEL_SCALE conversion.

Vehicle inertia uses the verified car basis:

a_inertia_world = -(car.side * accelerationG.x + car.up * accelerationG.y + car.look * accelerationG.z) * 9.81

The Lua side no longer applies an additional temporal response multiplier to this acceleration. The current ac.getCar(0).acceleration value is passed directly.

### 30.3 Canonical droplet physical model

Droplet metadata now uses the physical UV diameter mapping for every persistent droplet.

Authoritative mapping:

- 1 mm diameter = 0.0029296875 UV;
- radius = diameter × 0.00146484375 UV;
- water density basis = 1000 kg/m³ in the aerodynamic mass calculation;
- aerodynamic drag coefficient = 0.47;
- air density = 1.20 kg/m³;
- aerodynamic area = πr²;
- spherical volume = 4/3 πr³.

The first nine droplets remain the fixed validation population:

- Light: 0.5 / 0.95 / 2.0 mm;
- Moderate: 0.5 / 1.5 / 4.0 mm;
- Heavy: 0.5 / 2.5 / 6.0 mm.

Production indices after the first nine use deterministic physical diameters in the same 0.5–6.0 mm range rather than the removed arbitrary normalized-radius generator.

The established normalized mass profile remains the project metadata domain for adhesion/max-speed response. It is not interpreted as kilograms.

### 30.4 Canonical motion response

After external-force projection:

1. surface adhesion threshold is evaluated from droplet mass;
2. only the force above adhesion contributes to flow acceleration;
3. the resulting velocity is damped by the established surface-flow drag;
4. the physical size-dependent speed cap is applied;
5. persistent UV position is integrated;
6. lifecycle mode handles surface exit/death/respawn without wrapping.

The physical max-speed law remains:

V_max(D) = V_1mm × D^0.67

with the current calibrated V_1mm = 0.016 UV/s.

This law is a visor-surface calibration. It is not a direct copy of free-fall terminal velocity.

### 30.5 Render-path consolidation

shaders/rainVisorScreen.hlsl is now display-only.

It no longer calculates gravity, vehicle acceleration, airflow drag, adhesion, procedural travel distance, or synthetic droplet trajectories. It reads txRainState, txRainStateMeta and txRainBoundaryMask.

The normal render path and Debug 51 therefore observe the same persistent physical state.

The canonical debug set is intentionally small:

- Debug 0: canonical persistent physical droplets;
- Debug 40: boundary mask;
- Debug 41: lifecycle state;
- Debug 51: physical persistent-state viewer.

The previous debug modes that represented obsolete prototype force models are no longer part of the active debug UI.

### 30.6 State modes after cleanup

Only the following state modes remain:

- 0: disabled;
- 1: initialize only;
- 3: canonical persistent RainFX physics;
- 4: canonical physical 3×3 diagnostic population;
- 6: canonical physical physics + lifecycle;
- 7: single persistent droplet position probe;
- 10: canonical nine-droplet physical validation.

Modes 2, 5, 8 and 9 are removed rather than retained as compatibility physics.

### 30.7 Validation rule

Future physical tuning must modify the canonical model only.

Do not introduce a new independent force multiplier, artificial gravity, synthetic tangent force, camera-space acceleration gain, temporary speed override, or legacy radius/mass model merely to make a diagnostic easier to observe.

If a diagnostic needs amplification, it should be a visualization-only operation and must not alter txRainState integration.


## 31. Final physical size model and debug taxonomy correction — 2026-09-26

### 31.1 Physical max speed calibration restored

`RAIN_GPU_STATE_PHYSICAL_MAX_SPEED_1MM = 0.016` is authoritative and must remain in the runtime configuration.

The persistent physics pipeline still calls the size-dependent max-speed function at the final motion stage. Removing the configuration without replacing that call was an error. The current model remains:

```
Vmax(D) = 0.016 × D^0.67 UV/s
```

where D is droplet diameter in millimeters, clamped to the supported 0.5–6.0 mm domain.

### 31.2 One physical size model for every state mode

The earlier split between the first nine physical droplets and later legacy droplets is removed.

Every persistent state texel now follows the same deterministic model:

```
diameterMM = lerp(0.5, 6.0, hash(index + 101))
radiusUV = diameterMM × 0.00146484375
massProfile = lerp(1, 9, normalized diameter³)
```

The same model is used at initialization and lifecycle respawn. There is no remaining arbitrary radius such as `lerp(0.032, 0.115, ...)`.

This is deliberately profile-neutral for the current development build. A future Light/Moderate/Heavy rain profile should replace only the diameter distribution parameters; the physical metadata, mass calculation, UV conversion, aerodynamic model and max-speed law remain shared.

### 31.3 Debug numbering

The active render debug taxonomy is now:

- **0 — RainFX:** canonical persistent RainFX renderer and all active effects.
- **1 — Local surface normal:** object-space normal texture rendered directly as RGB.
- **2 — World surface normal:** the same surface normal transformed into world space and encoded as RGB.
- **3 — Boundary mask:** authoritative persistent-state surface boundary.
- **4 — Predicted positions:** current droplet plus visualization-only predicted position from current persistent velocity.
- **5 — Force direction:** current enabled external-force sources projected onto the local surface and visualized as a direction arrow. The arrow amplification is visualization-only.
- **6 — Physical state viewer:** direct persistent-state inspection. It exists to separate a physics-state/storage problem from a final-render problem; it does not alter the state or apply a second physics model.

The former debug IDs 40, 41 and 51 are retired from the UI.

### 31.4 Debug 0 + State Mode 3

This combination is **not intentionally empty**. State Mode 3 is the canonical persistent physics mode and Debug 0 is its normal renderer.

If this combination produces no visible droplets, that is a runtime/render-path defect rather than an intended mode limitation. The physical droplets are deliberately small, so their visual coverage is much smaller than the old prototype droplets, but the state must still be observable—especially with the larger end of the 0.5–6.0 mm distribution.

Debug 6 exists specifically to determine whether the state exists while Debug 0 has a display-side problem.


## 32. Post-sign-fix validation, initial-motion source model, and renderer performance investigation — 2026-09-26

### 32.1 U-axis sign correction validation

The persistent force projection and Debug 5 force-arrow projection both previously applied an extra negative sign to the U component. The user corrected both locations and committed the change.

The established raw visor UV contract remains:

- U: left → right increases.
- V: top → bottom increases.
- Position integration adds the resulting UV velocity directly.

After removing the extra U-axis negation, visual trails and actual droplet movement became directionally plausible for combined gravity + vehicle inertia + airflow. The combined force model now produces a substantially more realistic motion direction.

No physical constants were changed as part of this sign correction.

### 32.2 Flow intensity tuning factor

A new multiplier was introduced:

`RAIN_FLOW_SPEED_SCALE = 1.0`

It multiplies the post-adhesion flow acceleration before the existing physical maximum-speed clamp. Therefore:

- 1.0 is the current calibration baseline.
- It is intended for later perceived-dynamics tuning after initial-impact motion is implemented.
- It must not bypass the absolute size-dependent max-speed limit.

The current maximum-speed law remains authoritative.

### 32.3 Initial-motion source model

Initial motion is intentionally not physically finalized yet. The implementation direction is established around four mutually meaningful spawn/source classes:

1. `NORMAL`
   - Ordinary rain droplet appearing on the visor.
   - No additional impact-derived initial velocity is assumed initially.

2. `SKY_IMPACT`
   - A droplet arriving from atmospheric rainfall and striking the visor.
   - Future implementation may preserve a limited component of pre-impact downward momentum as initial surface motion.

3. `SPLASH`
   - Secondary droplets generated by a water impact/splash event.
   - Future implementation may derive initial tangential motion from the impact event rather than from ordinary rain spawning.

4. `FRONT_CAR_SPRAY`
   - Water thrown from another vehicle reaches the visor.
   - Future implementation may provide a stronger, event-specific initial velocity distribution.

These are source/event categories, not final force equations. They should be kept separate from the continuous force pipeline so that spawn energy does not become a permanent artificial force.

A future implementation may require an additional event/source canvas or GPU buffer if multiple transient impact events must be spatially accumulated before becoming persistent droplets. This is an architectural possibility only; no canvas allocation is committed yet.

### 32.4 Physical size model unification

The persistent state initialization already used the deterministic hash-selected 0.5–6.0 mm model. The Meta initialization pass still contained an older nine-profile fixed-size table.

That legacy table has now been removed. Meta initialization uses the same canonical deterministic distribution:

`diameterMM = lerp(0.5, 6.0, rainStateHash(index + 101.0))`

Mass continues to derive from spherical volume over the same 0.5–6.0 mm domain.

This removes a remaining source of mismatch between persistent state physics and render radius.

### 32.5 Performance measurements

Measured with:

- `STATE_MODE=6`
- visor Z offset = `-0.1033` m (10.33 cm)

| Render mode | Observed FPS |
|---|---:|
| `RAIN_DEBUG=0` | 50–55 |
| `RAIN_DEBUG=5` | 29–31 |
| `RAIN_DEBUG=6` | 49–55 |

Interpretation:

- Debug 6 has essentially the same performance as the canonical renderer, so the physical-state diagnostic itself is not the main bottleneck.
- Debug 5 is substantially more expensive because it recomputes force/normal/airflow/arrow information for every persistent drop inside every covered screen fragment.
- Debug 0 remains playable but is materially slower than the same visor viewed at a smaller screen footprint (reported approximately 70–80 FPS). This supports prioritizing renderer optimization even though the current baseline is usable.

### 32.6 Renderer architecture investigation

The official CSP Lua SDK documents:

- `render.fullscreenPass()`
- `render.shaderedQuad()`
- `render.mesh()`
- custom shader parameters and texture bindings
- reusable parameter tables with `directValuesExchange`

The SDK documents custom 3D mesh rendering, and the scene library exposes dynamic mesh vertex/index buffers. However, the reviewed public SDK does not expose a documented arbitrary GPU-instancing or indirect-draw API.

Therefore the intended optimization target remains:

`DropPixels × DropCount`

instead of:

`ScreenPixels × DropCount`

but it cannot yet be implemented safely by assuming a nonexistent instancing API.

The next API-level investigation should determine whether CSP's internal `mesh.fx` template exposes a usable vertex-stage path (for example, a per-instance/per-vertex identifier that can index `txRainState`). If no such public or verified path exists, the fallback architecture should be evaluated rather than introducing undocumented calls.

The current fullscreen renderer remains the authoritative implementation until that path is verified.


## 33. Dynamic Mesh Renderer — Stage 1 static 256-quad test — 2026-09-26

This experiment is isolated on branch `feature-RainFXDynamicMeshRenderer`, created directly from `feature-RainFXPersistentGPU`. The PersistentGPU branch remains the protected baseline until the renderer experiment is judged complete.

### 33.1 Purpose

The current canonical renderer performs a fullscreen mesh pass and, for each covered fragment, searches the persistent GPU state for up to 256 droplets. The experimental renderer tests the alternative geometry-driven architecture:

```
256 small quads × actual rasterized footprint
```

instead of:

```
screen pixels × 256 state search
```

This Stage 1 test intentionally does NOT read back `rainStateA`/`rainStateMetaA`, and it does NOT call `alterVertices()`. It isolates the public `createMesh()` + `render.mesh()` rendering path.

### 33.2 Test geometry

Runtime configuration:

- `RAIN_DYNAMIC_MESH_TEST_GRID = 16`
- 16 × 16 = 256 quads
- 4 vertices per quad = 1024 vertices
- 6 indices per quad = 1536 indices
- quad size = 0.030 m
- grid spacing = 0.050 m
- local Z offset = -0.020 m

The mesh is created once and retained. Each quad has local UVs 0..1 and a minimal inline test pixel shader. The same visor world transform used by the canonical renderer is applied to the test mesh, so the test follows the visor transform without changing the existing physics coordinate system.

### 33.3 Public API verification

The CSP public SDK source was checked directly.

Verified APIs:

- `ac.MeshVertex.new(pos, normal, uv)`
- `ac.VertexBuffer(size)`
- `ac.IndicesBuffer(size)`
- `ac.SceneReference:createMesh(name, materialName, vertices, indices, keepAlive, moveData)`
- `ac.SceneReference:alterVertices(vertices)`
- `render.mesh({ mesh = ..., transform = ..., shader = ... })`

The SDK defines `ac.IndicesBuffer` as 16-bit indices, so 1024 vertices are comfortably inside the limit.

Stage 1 currently uses `createMesh()` and `render.mesh()` only. `alterVertices()` is intentionally deferred until the renderer path itself has been validated.

### 33.4 Runtime switch

```lua
RAIN_DYNAMIC_MESH_TEST_ENABLED = false
```

When enabled, the render callback:

1. updates the existing Persistent GPU physics state exactly as before;
2. initializes the static 256-quad mesh once;
3. renders that mesh with `render.mesh()`;
4. skips the canonical fullscreen RainFX renderer for that frame.

When disabled, the existing canonical renderer remains unchanged.

### 33.5 Interpretation boundary

A successful Stage 1 result does NOT yet prove that GPU persistent state can be efficiently driven through dynamic geometry.

It only establishes:

```
createMesh → render.mesh → 256 small quad rasterization
```

as a viable public-API rendering path.

The next stage, only if Stage 1 is visually and performance-wise useful, is:

```
rainStateA / rainStateMetaA
        ↓
ExtraCanvas accessData()
        ↓
CPU position/radius decode
        ↓
VertexBuffer update
        ↓
alterVertices()
        ↓
render.mesh()
```

That stage will separately measure readback latency, CPU update cost, dynamic vertex alteration cost, and the resulting visual latency.

### 33.6 Current decision

Do not merge this branch into `feature-RainFXPersistentGPU` yet. The branch is an isolated renderer research branch. Integration is considered only after the dynamic mesh renderer is validated against the canonical renderer for visual correctness, frame-time impact, latency, and lifecycle behavior.

## 34. Dynamic Mesh Renderer — Stage 1.1 visor hierarchy + curved surface — 2026-09-26

Stage 1 runtime measurement established that the static 256-quad geometry path is materially cheaper than the canonical fullscreen renderer. The next experiment therefore moves only the geometry placement; persistent GPU physics remains unchanged.

### 34.1 Stage 1 measurement

Under the same 4K visor/fullscreen conditions:

| Renderer | Observed FPS |
|---|---:|
| Canonical fullscreen RainFX, Debug 0 / State 6 | 56 |
| Dynamic mesh test, 256 quads | 77 |

This is a renderer-path comparison only. The dynamic test did not yet consume persistent GPU state.

### 34.2 Hierarchy correction

The first dynamic test created the mesh under ac.emptySceneReference(). The mesh was therefore independent of the RealVisor camera/visor hierarchy.

The test now creates:

cameraAnchor → cameraRoot → offsetNode → motionNode → scaleNode → axisPitchNode → axisYawNode → axisRollNode → rainDynamicMeshTestNode → dynamic mesh

This makes the experimental mesh inherit the same camera position, offset, motion, scale and profile axis corrections as the loaded visor.

The canonical RainFX renderer still uses rainTargetMesh:getWorldTransformationRaw() and is unchanged.

### 34.3 Curved geometry test

A flat test plane is no longer sufficient for the next visual check because the eventual droplet geometry must follow the three-dimensional visor surface. Stage 1.1 therefore replaces the flat quad grid with a simple two-axis curved surface:

z = baseZ + curvatureX * x² + curvatureY * y²

Current diagnostic defaults:

- CURVATURE_X = 0.90
- CURVATURE_Y = 0.35
- Z = -0.020

These curvature values are test geometry only. They are not claimed to reproduce the KN5 visor surface accurately.

### 34.4 Important API boundary

The repository currently contains no existing Lua implementation that extracts the vertex positions of rainTargetMesh and copies them into a custom ac.VertexBuffer. The reviewed public API confirms dynamic vertex-buffer creation and alterVertices(), but no existing project code provides a verified rainTargetMesh → VertexBuffer extraction path.

Therefore Stage 1.1 deliberately does not invent such an API. The next architectural question is whether an authoritative visor-surface position mapping can be obtained through a documented CSP API, or whether a separately generated calibrated surface representation is required.

### 34.5 What this experiment must establish

With the test enabled, verify:

1. The 256-quad mesh is visible.
2. It follows head/camera movement and profile pitch/yaw/roll exactly with the visor.
3. Its curvature is visibly three-dimensional rather than a flat screen plane.
4. The mesh can be placed near the visor surface without depending on fullscreen rasterization.
5. FPS remains comparable to the 77 FPS Stage 1 baseline.

Do not tune RainFX physics during this test.

### 34.6 Final geometry direction

If Stage 1.1 succeeds, the final renderer should not assume a single flat plane. Each droplet quad should be positioned on the visor surface and oriented from the local surface tangent/normal frame. The persistent state already provides visor UV position and physical radius; the remaining renderer-side problem is converting those UV positions into accurate local 3D surface positions.

This is a geometry-mapping problem, separate from the persistent GPU physics model.

## 35. Dynamic Mesh Renderer — Stage 2 actual KN5 surface mapping — 2026-09-26

Stage 1.1 successfully established the visor hierarchy and a curved diagnostic surface at approximately 75–80 FPS. The synthetic curvature is now replaced by the actual GLASS_EXT_DUMMY mesh geometry.

### 35.1 Double-sided geometry decision

The extracted visor surface is a **calculation source**, not the final droplet render surface. It does not need to be rendered from both sides.

The final droplet geometry is still expected to be a set of small 3D quads placed on the real visor surface. During diagnostics, droplet quads use render.CullMode.None deliberately so normal winding/camera-side orientation cannot hide a valid mapping result. Final culling policy is deferred until the inside-facing visor normal convention is validated.

### 35.2 Verified SDK path

The public CSP Lua SDK documents:

- ac.SceneReference:getVertices()
- ac.SceneReference:getIndices()
- ac.VertexBuffer:get(index)
- ac.IndicesBuffer
- ac.SceneReference:getParent()
- ac.SceneReference:createMesh()

getVertices() and getIndices() are called only once during Stage 2 initialization. The SDK explicitly notes that these calls copy mesh data and may be expensive per frame, while getVertices() is suitable for obtaining data once and later using alterVertices().

The SDK also states that KN5 vertex order can be changed by the built-in mesh optimizer. Stage 2 therefore never assumes original exporter vertex ordering; triangle lookup is based on the returned index/UV/position data.

### 35.3 UV → 3D mapping

The Stage 2 CPU lookup pipeline is:

~~~
GLASS_EXT_DUMMY
    ↓ getVertices()/getIndices() once
triangle list
    ↓ UV-space 32×32 buckets
candidate triangles
    ↓ barycentric UV containment
position + interpolated normal
    ↓ triangle UV derivatives
tangent U / tangent V
    ↓
3D droplet quad
~~~

For each candidate triangle, the three returned UVs are used to compute barycentric coordinates. The same barycentric weights interpolate vertex positions and normals.

The tangent frame is derived from the triangle's position/UV derivatives. The U tangent is orthogonalized against the interpolated normal. V is reconstructed from normal × tangentU and its sign is compared against the triangle's UV-derived V tangent so the established raw visor UV convention remains intact:

- U increases left → right.
- V increases top → bottom.

### 35.4 Diagnostic droplet geometry

Stage 2 currently generates 256 deterministic UV samples. It does **not** read rainStateA or rainStateMetaA yet.

Each successful UV sample becomes a 1.5 mm diagnostic droplet:

- physical diameter → UV diameter uses the existing authoritative 0.0029296875 UV/mm mapping;
- UV radius is converted into local 3D distance through the triangle's meters-per-UV scale;
- quad center uses interpolated surface position;
- quad orientation uses the local tangent U/V frame and interpolated surface normal;
- a small configurable surface offset (0.00005 m) is applied.

The dynamic test mesh is created under rainTargetMesh:getParent(). This is intentional: the extracted vertex positions remain in the mesh's local coordinate space while the parent retains the loaded visor's transform hierarchy.

### 35.5 Runtime switch

~~~
RAIN_DYNAMIC_SURFACE_TEST_ENABLED = false
~~~

When enabled, the render callback performs the existing persistent GPU physics update, then renders only the Stage 2 256-droplet diagnostic mesh. The canonical fullscreen RainFX renderer is skipped for that frame.

Stage 1 remains available independently through RAIN_DYNAMIC_MESH_TEST_ENABLED.

### 35.6 Validation target

The next in-game validation should check:

1. Console reports successful vertex/index extraction.
2. The mapped sample count is close to the requested 256. A lower count means the deterministic UV probes landed outside the actual GLASS_EXT_DUMMY UV island.
3. Droplets appear on the actual visor curvature rather than on the synthetic Stage 1.1 paraboloid.
4. Pitch/yaw/roll and head motion remain aligned because the dynamic mesh is attached to the extracted mesh's parent.
5. The droplet orientation follows local visor curvature rather than remaining screen-facing.
6. Performance remains near the Stage 1/1.1 75–80 FPS range.

### 35.7 Important limitation before Stage 3

The deterministic UV probes are only a geometry validation population. They are not the persistent droplet state.

If Stage 2 succeeds, the next experiment should replace the deterministic UV source with decoded persistent GPU state:

~~~
rainStateA/B
    ↓ accessData()
CPU decode of 256 UV positions/radii
    ↓
existing UV → 3D lookup
    ↓
VertexBuffer update
    ↓
alterVertices()
    ↓
render.mesh()
~~~

Only after this readback path is measured should we decide whether a separate compact KN5 surface mesh is necessary. The current getVertices()/getIndices() path already provides the authoritative source geometry, so a manually authored reduced surface is not required for correctness at this stage.

## 36. Dynamic Mesh Renderer — Stage 2 UV-domain correction — 2026-09-26

The first Stage 2 run extracted 14,510 vertices, 83,262 indices and 27,746 valid UV triangles, but all 256 deterministic UV probes missed the surface.

The immediate cause identified in the test code was an incorrect assumption that the extracted KN5 UV domain was 0..1. The established visor convention uses V = -1..0. The deterministic probe used frac(), which produces only 0..1, so its output could be entirely outside the actual visor UV island.

The fix is deliberately more general than simply changing V to -1 + frac():

1. Scan all extracted vertex UVs once and record actual minU, maxU, minV, maxV.
2. Build the UV bucket index using these actual bounds rather than assuming 0..1.
3. Continue using frac() only to generate a deterministic normalized sample in [0,1).
4. Convert that normalized sample into the actual mesh UV domain:
   U = minU + u01 * (maxU - minU)
   V = minV + v01 * (maxV - minV).
5. Log the extracted UV bounds for direct in-game verification.

This preserves the raw UV coordinate convention and avoids introducing another hard-coded coordinate conversion.

Commit: 0ed7deaa92d09fe8194131bcc13c05331dbdd918.

The next run must report the new Dynamic surface UV bounds line. The bounds themselves are now an important diagnostic datum before any further geometry or physics work.


### 37. Dynamic surface Stage 2 — UV bucket query normalization fix (2026-09-26)

Runtime after actual KN5 UV-bound sampling:
- extraction: 14510 vertices / 83262 indices / 27746 valid UV triangles
- UV bounds: U=-0.001407..0.999791, V=-0.670310..-0.003990
- result before this fix: 1/256 mapped, 255 outside surface
- performance remained about 75–80 FPS

Diagnosis:
- Stage 2 bucket construction had already been corrected to normalize triangle UVs against the extracted KN5 bounds:
  `(uv - minUV) / rangeUV`.
- `rainDynamicSurfaceFindTriangle()` still used the old normalized-0..1 assumption:
  `floor(uv.x * bucketCount)`, `floor(uv.y * bucketCount)`.
- Because the actual visor V domain is entirely negative, almost every V query was clamped to bucket row 0 while triangles had been inserted into rows normalized over the actual V range.
- Therefore the 1/256 result did not demonstrate a sparse visor UV island; it was primarily a build/query bucket-coordinate mismatch.

Correction:
- `rainDynamicSurfaceFindTriangle()` now computes:
  - `normalizedU = (uv.x - lookup.minU) / lookup.rangeU`
  - `normalizedV = (uv.y - lookup.minV) / lookup.rangeV`
- bucket X/Y are derived from those normalized values, matching `rainDynamicSurfaceBuildLookup()`.

Important conclusion:
- The extracted KN5 data independently confirms the visor uses a negative V domain.
- Do not replace bbox sampling or add UV-island heuristics until this corrected symmetric bucket mapping is runtime-tested.
- Next validation criterion: rerun Stage 2 and compare the mapped count against 1/256; visible quads are the secondary confirmation.


### 38. Dynamic surface Stage 2 — lookup accuracy gate (2026-09-26)

Observed after fixing UV bucket query normalization:
- deterministic bbox sampling: 88/256 mapped, 168 outside surface
- this is a large improvement over 1/256 and confirms the bucket-coordinate fix is active
- however, bbox samples alone cannot distinguish a sparse/non-rectangular visor UV island from residual lookup errors

Accuracy policy:
1. Do not tune the random/bbox sampler to artificially raise the hit count.
2. Validate the lookup independently using points that are mathematically guaranteed to be inside valid UV triangles.
3. Only after the lookup path is proven accurate should actual persistent rain-state UVs be connected.
4. Keep this validation initialization-only so steady-state renderer FPS is unaffected.

Implemented self-test:
- every valid UV triangle receives three deterministic interior barycentric probes:
  - centroid: (1/3, 1/3, 1/3)
  - biased interior: (0.60, 0.20, 0.20)
  - biased interior: (0.20, 0.60, 0.20)
- with 27,746 valid triangles this produces 83,238 guaranteed-inside lookup probes
- each probe is passed through the production `rainDynamicSurfaceFindTriangle()` path

Failure classification:
- `bucket-membership`: the source triangle was not present in the bucket selected for its guaranteed-inside probe
- `containment`: the source triangle was present in the selected bucket but the production lookup still returned no containing triangle

Expected diagnostic logs:
- `Dynamic surface lookup self-test: X/83238 guaranteed-inside probes mapped (...%), Y missed`
- if Y > 0:
  `Dynamic surface lookup self-test misses: A bucket-membership / B containment`

Decision gate:
- approximately 100% self-test success means the UV bucket + barycentric lookup is considered validated; the 88/256 bbox hit rate can then be interpreted as visor UV-island occupancy rather than lookup failure
- any measurable miss count must be resolved before persistent GPU state is connected


### 39. Dynamic surface Stage 2 — area-weighted surface sampling (2026-09-26)

Validated runtime result before this change:
- extraction: 14510 vertices / 83262 indices / 27746 valid UV triangles
- UV bounds: U=-0.001407..0.999791, V=-0.670310..-0.003990
- guaranteed-inside self-test: 83238/83238 mapped (100.000%), 0 missed
- bbox diagnostic sampling: 88/256 mapped, 168 outside surface
- visible mapped points followed the visor surface correctly but were sparse

Conclusion:
- UV -> triangle lookup is validated and is no longer the source of the 88/256 count.
- The 88/256 count measured rectangular UV-bbox occupancy, not lookup accuracy.
- A detached/seam UV island can expand the global bbox and create large empty UV regions between islands; this can lower bbox rejection-sampling hit rate even when lookup is perfect.
- Production persistent-state spawning is a separate path: it samples the signed visor domain and accepts candidates only when the boundary mask is valid. Therefore an auxiliary seam island matters to production spawning only if the boundary mask itself marks it as valid.

Stage 2 diagnostic policy change:
- Keep the 83,238 guaranteed-inside self-test as the accuracy gate.
- Stop using global bbox rejection sampling for the visible 256-quad geometry validation.
- Build cumulative UV triangle area while extracting the KN5 mesh.
- Select 256 triangles by stratifying the cumulative UV-area distribution.
- Generate a uniform barycentric point inside each selected triangle using the sqrt(r1) method.
- Feed every generated UV back through the production `rainDynamicSurfaceSample()` path.
- Expected visual diagnostic result is now 256/256 mapped if the already-validated lookup remains correct.

New diagnostic:
- log summed UV triangle area, bbox UV area and their ratio:
  `Dynamic surface UV area: triangles=... bbox=... summed-ratio=...%`
- this ratio is only a diagnostic because overlapping UV triangles can make summed triangle area differ from unique island coverage.

Decision:
- If 256/256 area-weighted samples map and visually follow the visor curvature, Stage 2 static UV->3D surface mapping is complete.
- Do not try to remove seam islands from the geometry lookup yet. Production-valid droplet positions are ultimately defined by persistent state + boundary mask, so filtering should be aligned with that authoritative domain rather than inferred from arbitrary UV island placement.


### 40. Dynamic surface Stage 2 completion + Stage 3 persistent-state readback (2026-09-26)

Runtime comparison after removing a detached/seam UV region from the KN5:
- previous bbox sampler, before area-weighted Stage 2 visualization:
  - UV bounds U=0.001805..0.999791
  - V=-0.670310..-0.392184
  - lookup self-test 18843/18843 (100.000%)
  - bbox samples 186/256 mapped, 70 outside surface
- latest area-weighted Stage 2:
  - summed triangle UV area = 0.203867
  - bbox UV area = 0.277566
  - summed area / bbox = 73.448%
  - lookup self-test 18843/18843 (100.000%)
  - 256/256 area-weighted surface samples mapped, 0 lookup misses
- visually, all 256 diagnostic points follow the visor surface with useful density.

Interpretation:
- the detached seam UV region materially enlarged the old global bbox and reduced bbox rejection hit rate.
- Stage 2 UV -> KN5 3D surface mapping is considered complete.
- the regular rows/gaps visible in the current 256-point diagnostic are not production spawn behavior; they come from the deterministic area-stratified diagnostic sampler and triangle ordering.
- production positions remain authoritative in the persistent GPU state and use boundary-mask rejection sampling.

Density reference:
- using summed visor UV triangle area A ~= 0.203867 and N=256, a simple characteristic area-cell scale is:
  `sqrt(A/N) ~= 0.02822 UV`
- using the calibrated `1 mm = 0.0029296875 UV`, this is about 9.63 mm equivalent spacing.
- this is only a density scale, not a hard minimum center distance; real droplets may overlap/merge and production should not be forced into a regular grid.

Stage 3 architecture implemented:
1. Persistent physics remains on the existing GPU state textures.
2. A 4N x 1 `R32FLOAT` staging canvas exports only renderer-required values:
   - segment 0: U
   - segment 1: signed V encoded as V+1 into 0..1
   - segment 2: physical radius UV
   - segment 3: alive flag
3. Staging texture is read asynchronously with `ui.ExtraCanvas:accessData()`.
4. CPU uses documented `ui.ExtraCanvasData:floatValue(x,y)` to read the R32FLOAT scalars.
5. Callback only stores scalars into reusable Lua arrays.
6. The render callback maps each live UV through the validated triangle lookup, rebuilds its four quad vertices, and calls `SceneReference:alterVertices()`.
7. Dead or unmappable states are collapsed to degenerate vertices.
8. The existing diagnostic quad shader is retained for this first integration so the test isolates state->geometry motion from final optical shading.

SDK reference validation:
- CSP public Lua SDK documents `ExtraCanvas:accessData(callback)` as asynchronous GPU->CPU download, typically around 0.15 ms.
- `ui.ExtraCanvasData:floatValue()` is the documented accessor for R32FLOAT textures.
- `render.TextureFormat.R32.Float` is present in the public render enum.
- `SceneReference:alterVertices(vertices)` is present in the public scene API.
- direct CPU reading of the existing R32G32B32A32.Float state texture was deliberately avoided because the documented `color()` accessor is for RGBA8888, not float4 textures.

Stage 3 runtime switch:
- `RAIN_DYNAMIC_SURFACE_STATE_ENABLED = false`
- enable it to render actual persistent state through the dynamic mesh path.
- keep `RAIN_DYNAMIC_SURFACE_TEST_ENABLED = false` while testing Stage 3.

Expected first logs:
- `Dynamic state readback initialized: 256 drops / 1024 R32FLOAT scalars`
- `Dynamic state first mesh update: X live drops mapped, Y surface lookup misses`

Stage 3 validation goals:
- visible diagnostic quads should match persistent GPU positions and physical radii.
- quads should move continuously with the already-validated persistent physics.
- surface lookup misses should normally be zero for boundary-mask-valid live positions.
- FPS and any visible one-frame readback latency should be measured before replacing the diagnostic shader with final droplet optics.


### 40. Dynamic surface Stage 3 — persistent state readback cadence validation (2026-09-26)

Observed runtime result:
- readback initialized: 256 drops / 1024 R32FLOAT scalars
- first dynamic mesh update: 255 live drops mapped, 1 surface lookup miss
- visible quad sizes follow the persistent physical droplet-size profile
- output is independent of Rain debug visualization mode as expected
- GPU state mode changes are reflected
- motion direction remains consistent with the earlier persistent-GPU tests
- AC remains smooth at roughly 70–80 FPS
- however, visible dynamic-mesh positions appear to update at a coarse cadence of about 330 ms while per-update displacement still scales plausibly with droplet speed/dt

Interpretation:
- physics integration itself is likely still running continuously because faster/slower drops preserve their relative displacement behavior
- the coarse visual stepping is therefore suspected in the GPU->CPU asynchronous readback / CPU->mesh delivery path rather than in the force integrator
- current Stage 3 serializes readback requests with `rainDynamicStateReadbackPending`; no second `accessData()` request is issued until the previous callback arrives
- CSP public SDK documents `ui.ExtraCanvas:accessData()` as asynchronous and says GPU->CPU transfer usually takes about 0.15 ms, so an observed ~330 ms visual cadence is not accepted as expected API cost without measurement

Cadence instrumentation added:
- record simulation frame at each readback request
- record callback frame and accumulate callback latency in frames
- record callback-to-callback interval
- record `alterVertices()` application interval
- emit aggregate logs once per 30 successful callbacks/applies to avoid per-frame logging overhead

Expected logs:
- `Dynamic state cadence callback: avgLatency=...f min=... max=... | avgInterval=...f min=... max=...`
- `Dynamic state cadence mesh: avgInterval=...f min=... max=...`

Decision rules:
1. If callback latency/interval is ~20–30 frames at 70–80 FPS, the serial pending gate directly explains the ~330 ms stepping; next experiment should pipeline multiple staging canvases/readbacks rather than alter physics dt.
2. If callback latency is only ~1–2 frames but mesh interval is large, inspect callback-to-ready/apply scheduling.
3. If callback and mesh intervals are both ~1–2 frames despite visible stepping, investigate `alterVertices()` visibility/synchronization or quantization in the staging/readback values.
4. Do not tune rain forces, speed constants, or integration dt until the cadence path is isolated.


### 40. Dynamic surface Stage 3 — fixed 10-frame accessData latency and pipelined readback (2026-09-26)

Observed cadence with the initial serial readback implementation:
- `Dynamic state cadence callback: avgLatency=10.00f min=10 max=10 | avgInterval=10.00f min=10 max=10`
- `Dynamic state cadence mesh: avgInterval=10.00f min=10 max=10`
- values remained exactly constant over repeated logs

Interpretation:
- The target CSP/runtime delivers `ExtraCanvas:accessData()` callbacks with a deterministic 10-frame latency in this workload.
- The initial Stage 3 implementation allowed only one pending readback at a time.
- Therefore the fixed 10-frame asynchronous latency was incorrectly converted into a fixed 10-frame update cadence:
  request -> wait 10 frames -> callback -> next request.
- Physics dt/integration itself remains valid; the visible stepping came from renderer-state delivery cadence.

SDK verification:
- public CSP Lua SDK documents `ExtraCanvas:accessData(callback)` as an asynchronous GPU->CPU download and routes its completion through the SDK asynchronous reply mechanism.
- `ExtraCanvasData:floatValue(x,y)` is the documented accessor for `R32FLOAT` staging data.
- The SDK does not promise a callback on the next frame, so renderer architecture must tolerate multi-frame latency.

Correction: asynchronous readback ring
- Replace the single staging canvas + global pending gate with a configurable ring of independent R32FLOAT staging canvases.
- Current default: `RAIN_DYNAMIC_STATE_READBACK_RING_SIZE = 16`.
- One free slot is submitted each render frame.
- Each slot stores its own:
  - staging canvas
  - shader parameter table
  - pending flag
  - request frame
- With the measured 10-frame latency and a 16-slot ring, the expected steady state is:
  - request frame N -> callback near N+10
  - request frame N+1 -> callback near N+11
  - therefore callback cadence can approach one per render frame even though absolute latency remains ~10 frames.
- If every ring slot is still pending, that frame is skipped rather than overwriting an in-flight canvas.
- Out-of-order callbacks are protected by request-frame ordering; an older late callback cannot replace a newer accepted state.

Next validation target:
- callback `avgLatency` may remain approximately 10 frames.
- callback `avgInterval` should fall from exactly 10 frames toward approximately 1 frame after pipeline warm-up.
- mesh `avgInterval` should similarly approach approximately 1 frame.
- visually, droplet translation should become continuous at the game render cadence while remaining delayed by the pipeline latency.
- record FPS because the new architecture intentionally trades several tiny in-flight readbacks for high update cadence.


### 40. Dynamic mesh Stage 3 cadence diagnosis and Stage 3.1 prediction smoothing (2026-09-26)

Runtime cadence validation:
- callback latency: exactly 10 frames
- callback interval: exactly 10 frames
- mesh update interval: exactly 10 frames
- measured log remained stable:
  - `Dynamic state cadence callback: avgLatency=10.00f min=10 max=10 | avgInterval=10.00f min=10 max=10`
  - `Dynamic state cadence mesh: avgInterval=10.00f min=10 max=10`

Interpretation:
- the persistent GPU physics itself is not running at 10-frame cadence; prior motion tests showed correct dt-dependent displacement and force direction
- the visible stepping is caused by the asynchronous GPU->CPU readback delivery cadence
- a multi-slot/ring-buffer readback path was already active during this measurement, so serial `pending` blocking is not the remaining cause
- therefore the renderer must not depend on fresh CPU readback arriving every render frame

Stage 3.1 renderer policy:
- treat each GPU readback as an authoritative snapshot, not as the per-frame rendered position
- keep the actual physics simulation on GPU
- extend the R32FLOAT staging ABI from 4 to 6 scalars per droplet:
  1. U
  2. encoded V
  3. encoded velocity U
  4. encoded velocity V
  5. radius
  6. alive flag
- for 256 drops the staging canvas is now 1536x1 R32FLOAT

Velocity encoding:
- signed state velocity is encoded around 0.5 because the documented `ExtraCanvasData:floatValue()` path is treated as a normalized scalar transport
- current encode range: +/-0.125 UV/s
- this is comfortably above the current physical max-speed model (including the 6 mm upper drop size)

Prediction:
- each readback slot records the local render-clock time when its GPU snapshot was requested
- when the snapshot eventually arrives, CPU stores U/V/velocity/radius/alive plus that original snapshot time
- every render frame:
  `predictedUV = snapshotUV + snapshotVelocity * elapsedTime`
- prediction elapsed time is capped by `RAIN_DYNAMIC_STATE_PREDICTION_MAX_SECONDS` (currently 0.35 s) so a stalled readback cannot extrapolate indefinitely
- `alterVertices()` is now called every render frame after the first valid snapshot, instead of only when a new callback arrives

Expected validation:
- callback cadence may remain exactly 10 frames; that is acceptable
- mesh cadence diagnostic should move from 10 frames toward 1 frame
- visually, droplets should move smoothly at render FPS rather than stepping every callback
- if force direction changes sharply between snapshots, the next authoritative GPU snapshot may still produce a small correction; evaluate that separately before adding any correction blending


### 40. Dynamic mesh Stage 3 — pipelined readback cadence validated (2026-09-26)

Runtime validation after persistent GPU state was connected to the dynamic visor mesh:

Observed cadence:
- readback callback latency: avg 10.00 frames, min 10, max 10
- callback delivery interval: avg 1.00 frame, min 1, max 1
- mesh update interval: avg 1.00 frame, min 1, max 1
- the same 1-frame callback/mesh cadence was confirmed in both the immediately previous test build and the current build
- no visible snapshot correction jump or compensation jump was observed in either test

Interpretation:
- one GPU -> CPU readback result arrives about 10 frames after its source state was submitted
- requests are successfully pipelined, so after pipeline fill a new delayed snapshot is delivered every frame
- therefore the renderer has a fixed state age of roughly 10 frames but does not have a 10-frame stepping cadence
- at the measured 70–80 FPS this corresponds to roughly 125–143 ms of state age while vertex positions themselves can still update every ~12.5–14.3 ms

Decision:
- Stage 3 cadence is considered validated
- do not add prediction/extrapolation yet: it would add correction complexity while the current fixed latency produced no visually identifiable snapping in repeated testing
- preserve the pipelined async readback architecture
- next renderer stage should focus on replacing the diagnostic square shader/appearance with the actual droplet visual path while preserving this cadence and rechecking FPS


### 40. Dynamic renderer cadence validation and Stage 4A canonical-profile migration (2026-09-26)

Validated Stage 3 runtime:
- async GPU readback latency: fixed 10 frames on the tested CSP build
- completed callback interval: 1 frame
- dynamic mesh update interval: 1 frame
- repeated testing found no visible snapshot correction jump or compensation pop
- therefore the important distinction is:
  - latency = snapshot age
  - cadence = delivery/update frequency
- current pipeline delivers one older snapshot every frame rather than updating only once every 10 frames

Observed behavior:
- physical movement direction remains consistent with the previous persistent renderer
- faster droplets move farther and slower droplets move less, confirming the physics dt integration remains authoritative
- initial Stage 3 mapping reported 255 live drops mapped and 1 surface lookup miss
- the isolated miss is non-blocking unless it becomes persistent/recurrent; prediction can briefly move a live state outside the current surface before lifecycle/boundary state catches up

Cadence decision:
- do not spend more development time reducing the measured 10-frame asynchronous latency before optical rendering exists
- ring-buffer readback with 16 slots is retained because it sustains one request/completion per frame
- velocity-based render prediction remains available to compensate snapshot age
- periodic cadence logs are now disabled by default with:
  `RAIN_DYNAMIC_STATE_CADENCE_DEBUG = false`
- cadence diagnostics can be re-enabled without changing the pipeline

Stage 4A priority:
- the existing `rainVisorScreen.hlsl` canonical renderer does not yet contain the final water-optics model; its production appearance is currently a simple radial smoothstep droplet mask
- therefore the next renderer milestone is not full refraction yet
- first reproduce that canonical radial profile in the dynamic-quad path so renderer architecture and performance can be compared without introducing a second major variable

New shader:
- `shaders/rainVisorDynamicDrop.hlsl`
- one mesh quad represents one persistent droplet
- local quad UV is remapped from [0,1] to [-1,1]
- radial distance is evaluated once per covered quad pixel
- transparent quad corners are clipped
- profile matches the canonical renderer:
  - inner smooth region: 0.30 × radius
  - outer edge: 1.00 × radius
  - color: (0.82, 0.90, 1.0)
  - alpha scale: 0.35
- there is no loop over 256 droplets in this shader

Stage 4A render path:
- `RAIN_DYNAMIC_SURFACE_STATE_ENABLED=true` now uses the file-backed `RAINFXDYNAMICDROP` shader instead of the rectangular Stage 2 diagnostic shader
- persistent GPU physics, async state readback, KN5 UV->surface mapping and dynamic vertex updates remain unchanged
- `RAIN_DYNAMIC_SURFACE_TEST_ENABLED` remains the static diagnostic path and still uses the old test shader

Next validation:
1. visually confirm dynamic droplets are circular rather than rectangular
2. confirm physical radius differences remain visible
3. confirm motion/lifecycle behavior remains unchanged
4. record FPS under the same camera/view condition used for the previous dynamic-mesh tests
5. if Stage 4A is stable, begin the actual optical model as a separate Stage 4B so its cost can be isolated from renderer-architecture cost


### 40. Dynamic mesh Stage 3 — physical-radius visual gate and size-response review (2026-09-26)

Observed runtime status:
- `RAIN_DYNAMIC_SURFACE_STATE_ENABLED=true` renders persistent droplets as moving quads on the extracted KN5 visor surface.
- state mode changes are reflected.
- lifecycle and motion direction are visually plausible.
- steady performance remains about 70–80 FPS.
- asynchronous readback cadence is now one completed snapshot and one mesh update per frame after the ring-buffer/prediction work; callback latency remains about 10 frames but no visible snapshot correction jumps were observed.
- current remaining ambiguity is physical-size response because square diagnostic footprints make radius comparison difficult.

Renderer diagnostic change:
- the Stage 2/3 transport primitive remains a quad.
- the diagnostic pixel shader now clips the visible footprint to a circle.
- quad world dimensions are still generated directly from Meta.R physical radius, so visible circle diameter is a direct radius diagnostic rather than an arbitrary marker size.
- this is still a geometry/physics validation shader, not the final optical rain surface.

Physics size-response review from current production code:
- Gravity and vehicle inertia enter the unified pipeline as accelerations in m/s^2 and therefore do not directly scale with droplet mass.
- Adhesion decreases with increasing normalized mass:
  `adhesion = adhesionBase / sqrt(mass)`.
  Therefore larger/heavier droplets should cross the adhesion threshold more easily, all else equal.
- Surface max speed increases with diameter:
  `Vmax(D) = 0.016 * D^0.67 UV/s`.
  Therefore larger droplets have the higher speed ceiling.
- Airflow is converted from aerodynamic force to acceleration using:
  `Fdrag ∝ area ∝ r^2`, `mass ∝ r^3`, so `a_air ∝ 1/r`.
  Therefore smaller droplets are expected to receive stronger airflow acceleration.
- Consequently, an observation that smaller droplets move faster under airflow can be physically consistent with the current model.
- An observation that smaller droplets systematically move faster under isolated gravity or isolated inertia would contradict the current intended size ordering and should be treated as a diagnostic target rather than accepted behavior.

Next validation priority:
1. use the new circular Stage 3 footprint to verify that visible size ordering matches Meta.R;
2. isolate force sources with the existing unified-force toggles;
3. for gravity-only and inertia-only tests, verify that larger droplets are not systematically slower because of an unintended renderer/readback radius association;
4. for airflow-only, expect a competing response: small drops receive larger aerodynamic acceleration, while large drops have lower adhesion and a higher max-speed ceiling;
5. do not tune optical appearance or physics constants until this radius-to-motion association is verified.


### 40. Dynamic renderer test path and size-response physics review (2026-09-26)

Validated Stage 3 cadence/runtime observations:
- asynchronous GPU readback latency is consistently about 10 render frames on the tested CSP build
- after ring-buffered readback, callback interval = 1 frame and mesh-update interval = 1 frame
- no visible snapshot correction jumps were observed in either the previous build or the current build
- dynamic renderer remains around 70–80 FPS in the current physical-only test
- persistent movement direction and lifecycle are visually plausible

Correct test-switch contract:
- `RAIN_DYNAMIC_SURFACE_STATE_ENABLED = true` is the production-oriented dynamic-state test path
- that path renders `rainDynamicSurfaceMesh` with `shaders/rainVisorDynamicDrop.hlsl` (`RAINFXDYNAMICDROP`)
- `RAIN_DYNAMIC_SURFACE_TEST_ENABLED = true` is only the static geometry/UV diagnostic path and uses the inline `RAIN_DYNAMIC_SURFACE_TEST_HLSL`
- therefore edits to `RAIN_DYNAMIC_SURFACE_TEST_HLSL` do not validate the persistent-state renderer
- for actual position/size/lifecycle/motion tests use STATE_ENABLED=true and TEST_ENABLED=false

Current size-response model review:
- gravity and vehicle inertia enter the state solver as accelerations; they are not multiplied by procedural mass
- adhesion threshold is `adhesionBase / sqrt(mass)`, so larger drops (larger mass profile) have lower depinning thresholds
- max speed is `0.016 * D^0.67 UV/s`, so larger drops have higher absolute speed caps
- aerodynamic acceleration is calculated from `F_drag / m`; with area ~ D^2 and water mass ~ D^3, its acceleration contribution scales approximately as 1/D before adhesion/drag/clamping
- therefore:
  - gravity/inertia alone should not systematically make smaller droplets faster; larger droplets should generally depin more readily and have higher caps
  - airflow can give smaller moving drops stronger instantaneous aerodynamic acceleration, although larger drops can still depin more readily because the retention threshold falls with size
- if smaller drops are visually faster under gravity/inertia-only tests, treat that as a model/debug discrepancy rather than an intended outcome

Calibration parameter:
- `RAIN_FLOW_SPEED_SCALE` multiplies post-adhesion acceleration only
- it does not raise `RAIN_GPU_STATE_PHYSICAL_MAX_SPEED_1MM` or the size-dependent max-speed curve
- increasing it only makes droplets approach their existing cap faster
- before changing it, determine whether observed slowness is acceleration-limited or max-speed-limited

Recommended next physics validation:
- use the dynamic-state renderer (`RAIN_DYNAMIC_SURFACE_STATE_ENABLED=true`)
- compare isolated gravity, isolated inertia and isolated airflow with physical-size visibility
- priority is not another broad directional test; it is determining whether small-vs-large ordering matches the equations above
- only after that distinction should `RAIN_FLOW_SPEED_SCALE` or the physical max-speed calibration be tuned


### 40. Dynamic renderer Stage 3 — diagnostic shader scope and size-dependent physics review (2026-09-26)

Renderer-path clarification:
- Stage 3 must be tested with `RAIN_DYNAMIC_SURFACE_STATE_ENABLED = true`.
- The live dynamic-mesh branch does not currently execute `shaders/rainVisorScreen.hlsl`.
- Stage 2 static mapping and Stage 3 live-state rendering intentionally share a lightweight inline pixel shader.
- That shader has been renamed from `RAIN_DYNAMIC_SURFACE_TEST_HLSL` to `RAIN_DYNAMIC_SURFACE_DIAGNOSTIC_HLSL` because it is not limited to Stage 2.
- The current circular clip is therefore a Stage 2/3 geometry/physical-radius diagnostic only, not the final water optics.
- Final dynamic-mesh optics should use a dedicated dynamic-drop HLSL stage/file rather than silently modifying the canonical fullscreen `rainVisorScreen.hlsl` path.

Validated readback/cadence state:
- async GPU->CPU latency: fixed ~10 frames on the tested CSP build
- ring-buffered callback interval: 1 frame
- mesh alterVertices interval: 1 frame
- no visible snapshot jumps or correction jumps were observed in testing
- Stage 3 live state/lifecycle/motion is therefore considered functionally validated for renderer architecture work

Size-dependent physics review:
- Physical diameter distribution remains 0.5–6.0 mm.
- Adhesion is currently:
  `adhesion = adhesionBase / sqrt(mass)`
  so larger/more massive drops have a lower motion threshold.
- Surface max speed remains:
  `Vmax(D) = Vmax_1mm * D^0.67`
  so larger drops have a higher permitted terminal surface speed.
- These two terms explain the previously validated gravity-only and inertia-only observation that larger drops begin moving more readily and can move faster.
- Airflow is currently derived from spherical-drop SI drag:
  `Fdrag = 0.5 * rho * v^2 * Cd * area * incidence`,
  followed by `a = Fdrag / mass`.
  With area ~ D^2 and mass ~ D^3, the airflow acceleration term scales approximately as 1/D before adhesion and max-speed effects.
- Therefore, once the airflow term dominates and multiple sizes have already crossed adhesion, smaller drops can receive larger instantaneous airflow acceleration even though larger drops still have lower adhesion and a higher speed ceiling.
- This explains the current observation that small drops can appear faster in combined-force driving while earlier gravity-only/inertia-only tests showed the opposite ordering.

Physical interpretation:
- The current airflow formulation is internally consistent with a free-body drag/mass acceleration model, but a sessile/sliding windshield droplet is not a free spherical particle.
- Real onset is strongly controlled by contact-line retention/contact-angle hysteresis. Aerodynamic forcing and retention scale differently with drop size, so the current 1/D airflow acceleration must not yet be treated as a final validated size law for attached visor droplets.
- Do not retune gravity or inertia based on the combined-force observation; those modes were independently validated.
- Do not change `RAIN_GPU_STATE_PHYSICAL_MAX_SPEED_1MM` or `RAIN_FLOW_SPEED_SCALE` yet. They remain calibration parameters pending dedicated airflow-size validation.

Next physics validation priority:
1. preserve validated gravity-only and inertia-only behavior,
2. isolate airflow-only using controlled equal-position/equal-normal test droplets of selected diameters,
3. measure both threshold-crossing order and post-threshold velocity growth,
4. decide whether attached-droplet airflow should remain force/mass based or use a retention-relative/effective surface-drive model,
5. only then tune `RAIN_FLOW_SPEED_SCALE` / 1 mm speed calibration.



### 40. Dynamic mesh Stage 4A — physical diagnostic silhouette correction (2026-09-26)

Clarified shader routing:
- `RAIN_DYNAMIC_SURFACE_STATE_ENABLED = true` renders with external `shaders/rainVisorDynamicDrop.hlsl`.
- `RAIN_DYNAMIC_SURFACE_TEST_ENABLED = true` renders with Lua-inline `RAIN_DYNAMIC_SURFACE_DIAGNOSTIC_HLSL`.
- Therefore production-like Stage 3/4 physical visualization changes must be made in `rainVisorDynamicDrop.hlsl`, not only in the Lua diagnostic shader.

Reason for change:
- User-observed Stage 3 output still appeared as square quads.
- Radius-profile validation is a prerequisite for reliable physics comparison, so this should not be deferred until optical rendering.
- The dynamic-drop shader already contained a radial mask, but its soft appearance was not visually decisive enough to separate a shader-routing/UV issue from a footprint-visibility issue.

Current diagnostic shader policy:
- retain quad geometry as transport primitive
- hard-clip pixels outside unit circle in local quad UV
- use high, near-uniform opacity inside the circle
- preserve a visible edge gradient only to make physical diameter easy to judge
- do not add refraction, optical normals, film effects or final rain appearance yet

Decision gate:
- Test with `RAIN_DYNAMIC_SURFACE_STATE_ENABLED = true`.
- If droplets now appear clearly circular, physical-radius visual validation can continue.
- If square silhouettes remain, stop physics tuning and debug shader selection / quad UV transport, because the hard radial clip should make a square impossible when the intended shader and UVs are actually active.


### 40. Dynamic surface Stage 3 — black quad root-cause isolation (2026-09-27)

Observed:
- `RAIN_DYNAMIC_SURFACE_STATE_ENABLED = true` correctly updates actual persistent drop positions, lifecycle and physical quad size.
- Despite `shaders/rainVisorDynamicDrop.hlsl` containing a circular `clip()` mask and blue diagnostic color, the visible result remained black square quads.
- Therefore the problem could not be explained by the radial mask alone: if that shader were the visible draw, failed clipping would still produce blue squares rather than black squares.

Source review:
- Stage 3 does use `RAINFXDYNAMICDROP` / `shaders/rainVisorDynamicDrop.hlsl`.
- `render.mesh()` accepts an HLSL shader string directly according to the CSP SDK.
- `createMesh()` attaches the new mesh to the scene hierarchy.
- CSP SDK documents `keepAlive=true` as a long-lasting scene node that can survive script reload.
- The Stage 2/3 dynamic surface mesh had been created with `keepAlive=true`.

Root-cause hypothesis:
- Old `RealVisor_DynamicSurfaceTest` meshes can survive Lua reloads and remain attached to the scene.
- Both stale and current attached meshes can be rendered by the normal scene/material pass using the fallback/null material, producing black square transport geometry.
- This automatic scene draw can obscure the separately issued `render.mesh()` custom-shader draw.

Correction:
1. Dynamic surface test mesh now uses `keepAlive=false`.
2. Before creating the current mesh, all child nodes named `RealVisor_DynamicSurfaceTest` under the target parent are found and disposed.
3. The newly created mesh is marked `setVisible(false, false)` so the normal scene/material pass does not render it.
4. Stage 3 continues to draw it explicitly with `render.mesh({ mesh=..., shader=rainDynamicDropShader.HLSL })`.
5. The first manual draw now logs:
   `Dynamic drop manual draw: result=... shaderBytes=...`

Expected validation:
- stale cleanup log may report one or more removed meshes on the first run after this change
- manual draw should report `result=true` and a nonzero shader byte count
- visible output should come only from the dynamic drop shader; with the current shader that means circular blue diagnostic droplets rather than black square quads
- if the hidden SceneReference is not drawable manually on the target CSP build, the result will be no visible dynamic drops; in that case switch to a detached/manual-only mesh path rather than re-enabling automatic scene rendering


### 40. Dynamic drop visibility regression — UV transport isolation (2026-09-27)

Resume point:
- Stage 3 persistent GPU state -> async readback -> dynamic mesh had already been validated:
  - first update example: 255 live drops mapped, 1 surface lookup miss
  - callback latency measured 10 frames, but callback interval and mesh update interval were both 1 frame after ring-buffering
  - no visible snapshot/prediction correction jumps were observed
- Physical/lifecycle motion remained plausible and performance stayed around the previous 70–80 FPS range.
- Stage 4A attempted to replace diagnostic square quads with circular droplet footprints.
- User observed: after the square disappeared, the replacement circular droplets were also invisible.
- Work was reverted to the incomplete-resume state and debugging restarted from this exact symptom.

Current hypothesis:
- The external `shaders/rainVisorDynamicDrop.hlsl` circular shader uses `pin.Tex` to compute radial distance and clips pixels outside the unit circle.
- If dynamic-mesh UV interpolation is broken or flat (for example all vertices reaching the pixel shader as UV=(0,0)), then every pixel has radius > 1 and the entire quad is clipped.
- CSP SDK verification:
  - `ac.MeshVertex` contains `pos`, `normal`, and `uv`.
  - `alterVertices(ac.VertexBuffer)` forwards the vertex buffer to the dynamic-mesh update path.
  - Therefore UV support exists in the public API; the remaining question is whether this specific createMesh/alterVertices/render.mesh path preserves and interpolates the intended quad UVs at runtime.

Diagnostic added:
- `RAIN_DYNAMIC_DROP_UV_DEBUG = true` by default for this temporary test.
- `RAIN_DYNAMIC_SURFACE_STATE_ENABLED = true` remains the correct render path.
- The external dynamic-drop shader now receives `gDynamicDropDebugUV`.
- When UV debug is enabled:
  - circular clipping is completely bypassed
  - output is `float4(pin.Tex.x, pin.Tex.y, 0.15, 1)`
  - expected successful result: every live quad is visible and contains a red/green 0..1 gradient
- Interpretation:
  - visible per-quad gradient => shader binding + UV transport are valid; investigate clip/depth/silhouette logic next
  - visible flat-color quads => dynamic mesh renders but UV transport/interpolation is wrong
  - still no quads => problem is not the circular clip; investigate external shader binding/render state/depth path

Commits:
- Lua UV-debug switch/render value: 0b2ada91f5698e3d3f45e82b193084a6934b3436
- Dynamic-drop shader UV visualization: c99fde1842d7730c33df84814a96c34076128e00


### 41. Dynamic mesh visibility regression confirmed + render-path discriminator (2026-09-27)

Observed runtime result:
- With `RAIN_DYNAMIC_SURFACE_STATE_ENABLED = true` and `RAIN_DYNAMIC_DROP_UV_DEBUG = true`, no dynamic droplets were visible while the dynamically created surface mesh was explicitly hidden with:
  `rainDynamicSurfaceMesh:setVisible(false, false)`.
- Re-enabling the same SceneReference with:
  `rainDynamicSurfaceMesh:setVisible(true, false)`
  immediately made the square transport droplets visible again.

Confirmed cause:
- On the target CSP build, `render.mesh({ mesh = <ac.SceneReference>, ... })` still respects the SceneReference visibility flag.
- Therefore the previous assumption that a hidden scene node could still be drawn manually with `render.mesh()` was wrong.
- `setVisible(false)` suppressed both the normal attached-scene draw and the explicit custom-shader draw.
- CSP Lua SDK confirms:
  - `createMesh()` creates and attaches an `ac.SceneReference` child mesh.
  - `setVisible()` changes SceneReference visibility.
  - `render.mesh()` accepts an `ac.SceneReference` and forwards that node reference to the custom-shader mesh renderer.

Correction:
1. Keep `rainDynamicSurfaceMesh` visible:
   `rainDynamicSurfaceMesh:setVisible(true, false)`.
2. Keep `keepAlive=false` and stale-node cleanup so script reloads do not accumulate old dynamic meshes.
3. Do not yet assume that a visible square proves the custom shader is the visible path. A visible attached mesh can also be drawn by the ordinary scene/material pass.
4. While `RAIN_DYNAMIC_DROP_UV_DEBUG=true`, force the explicit `render.mesh()` draw to use `render.DepthMode.Off` and the external shader's RG UV gradient.
   This deliberately makes the manual draw visually dominant over a same-depth fallback scene draw.

Stage 4A discriminator test:
- Settings:
  - `RAIN_DYNAMIC_SURFACE_STATE_ENABLED = true`
  - `RAIN_DYNAMIC_DROP_UV_DEBUG = true`
- Expected interpretation:
  - per-quad red/green UV gradient visible:
    explicit `render.mesh()` custom-shader path is executing and quad UV interpolation survives createMesh -> alterVertices -> render.mesh.
  - only black/flat fallback squares visible:
    attached scene geometry is alive, but the explicit custom-shader draw is not the visible path; investigate render callback/pass ordering or custom mesh draw state.
  - no geometry visible:
    visibility/geometry state regressed again before shader diagnosis.

Target mesh vs dynamic mesh architecture:
- `rainTargetMesh`:
  - existing KN5 visor surface mesh, currently `GLASS_EXT_DUMMY`.
  - authoritative source of visor topology, local-space positions, normals, UVs and triangle indices.
  - extracted once with `getVertices()` / `getIndices()`.
  - used to build the CPU UV -> 3D surface lookup.
  - it is NOT one quad per raindrop and is not altered every frame by the dynamic renderer.
  - the legacy/full-surface RainFX shader path can still render this mesh directly.

- `rainDynamicSurfaceMesh`:
  - runtime-generated transport mesh created by Lua.
  - contains `RAIN_GPU_STATE_COUNT * 4` vertices and `RAIN_GPU_STATE_COUNT * 6` indices: one quad per possible persistent droplet.
  - every live droplet gets four 3D vertices placed on the visor by sampling the target-mesh UV lookup.
  - every dead/unmapped droplet gets a collapsed zero-area quad.
  - updated with `alterVertices()` from asynchronous persistent-GPU-state readback.
  - this is the mesh intended to draw the actual individual droplet footprints in the dynamic renderer.

Data/geometry flow:
```
persistent GPU state textures
        |
        | async compact readback
        v
U, V, velocity, radius, alive
        |
        | prediction + UV lookup
        v
rainTargetMesh-derived surface lookup
        |
        | local 3D center / normal / tangents / meters-per-UV
        v
rainDynamicSurfaceMesh vertex buffer
        |
        | alterVertices()
        v
one quad per live droplet
        |
        | render.mesh() + rainVisorDynamicDrop.hlsl
        v
visible droplet footprint
```

Important separation:
- physics state is owned by the persistent GPU textures.
- surface shape/mapping information is owned by the original target visor mesh.
- per-droplet drawable geometry is owned by the dynamic mesh.
- final per-pixel silhouette/optics are owned by the dynamic-drop shader.
- changing the dynamic mesh does not change the original visor geometry; it only creates small drawable quads located on that geometry.

Commit:
- visibility correction + render-path discriminator: faf9658742c64c6fbbffa8eda806070c077c2208


### 42. Stage 4A — root transparent render-path test (2026-09-27)

User observation after restoring dynamic mesh visibility:
- square droplet transport geometry became visible again
- it was black
- it was visible only from the side opposite the mesh normal
- the earlier working diagnostic had been visible from both normal directions

Interpretation:
- the visible black square is consistent with the attached scene/material path, not the intended custom `render.mesh()` path
- the one-sided visibility indicates ordinary mesh winding/culling behavior
- this conflicts with the custom path settings (`render.CullMode.None`) and UV-debug RG shader, so the custom draw is not the final visible contribution
- `DepthMode.Off` in the previous track-transparent diagnostic still failed to make RG output visible, which points to render-pass ordering/overdraw rather than only depth rejection

Reference check:
- CSP's own debug tooling uses `render.on('main.root.transparent', ...)` together with `render.mesh()`, `render.CullMode.None`, and explicit depth modes for mesh diagnostics
- therefore `main.root.transparent` is a validated candidate for the final manual dynamic-mesh draw stage

Code change:
1. Keep the canonical full-surface RainFX renderer on `main.track.transparent`.
2. When `RAIN_DYNAMIC_SURFACE_STATE_ENABLED=true`, the track-transparent branch now exits before drawing the dynamic mesh.
3. A separate `main.root.transparent` callback now:
   - frame-guards/updates persistent GPU state
   - initializes the dynamic surface mesh if needed
   - issues async state readback
   - applies the latest snapshot through `alterVertices()`
   - renders `rainDynamicSurfaceMesh` with `rainVisorDynamicDrop.hlsl`
4. UV debug remains:
   - `CullMode.None`
   - `DepthMode.Off`
   - RG output from `pin.Tex`

Validation settings:
- `RAIN_DYNAMIC_SURFACE_STATE_ENABLED = true`
- `RAIN_DYNAMIC_DROP_UV_DEBUG = true`

Expected result:
- RG gradient square visible from both sides:
  root-transparent manual draw is now the final visible path; UV transport and interpolation are confirmed
- black square still only on the reverse-normal side:
  attached scene fallback still wins and the manual SceneReference draw is not surviving; next step must stop using an attached SceneReference as the final transport primitive
- RG plus black overlap/artifact:
  both paths are visible; solve scene-pass suppression separately after confirming custom draw
- no geometry:
  root-transparent SceneReference draw is also suppressed and the design should switch to a detached/manual mesh representation

Commit:
- root-transparent dynamic draw test: aa114078e2cff776ece7f98315ad2c2c690c9c7a

### 43. Stage 4A — reverse-face black quads after root transparent test (2026-09-27)

Runtime observation with both dynamic surface state and UV debug enabled:
- Only black squares are visible, and only from the side opposite the surface normal.
- Moving the explicit draw to `main.root.transparent` did not produce the expected red/green UV gradient.

The black squares are consistent with the attached scene mesh's fallback material, but this observation alone does not establish whether the explicit call failed shader compilation, used the wrong transform, or was otherwise not visible. In particular, moving callback stages did not fix the result; do not treat pass ordering as confirmed.

Two concrete problems in the explicit path were addressed for the next in-game test:
1. `rainVisorDynamicDrop.hlsl` declared `float gDynamicDropDebugUV;` even though `render.mesh({ values = { gDynamicDropDebugUV = ... } })` provides the value through the shader template. Remove the duplicate HLSL declaration. Future Lua `values` entries must likewise not be redeclared in HLSL.
2. Add `transform = 'original'` to the explicit `render.mesh()` call. The generated droplet vertices are in the target visor mesh's local coordinate system, and the CSP Lua SDK documents this option for using a scene mesh's original transform.

Next in-game check: keep `RAIN_DYNAMIC_SURFACE_STATE_ENABLED = true` and `RAIN_DYNAMIC_DROP_UV_DEBUG = true`. Red/green gradient quads on both sides indicate the explicit path is visible. Black quads on one side mean it is still unproven; capture the CSP shader error and the `Dynamic drop root draw` log before selecting another geometry API. `ac.SimpleMesh` in the public SDK describes predefined car/collider/track geometry and has no documented constructor for a custom vertex buffer, so it is not a verified replacement for `createMesh()`/`alterVertices()`.

### 44. Stage 4A — explicit dynamic draw confirmed and scene-fallback isolation test (2026-09-27)

Confirmed runtime result after removing the duplicate Lua-value declaration and adding `transform = 'original'`:
- each transport quad displays the expected red/green interpolated UV gradient
- the explicit draw is double-sided with `CullMode.None`
- `DepthMode.Off` makes the diagnostic visible through geometry in front of it, as intended for this diagnostic only

This confirms the complete dynamic rendering chain:
`GPU state -> async readback -> target-mesh UV lookup -> alterVertices() -> original scene transform -> render.mesh() -> custom HLSL -> pin.Tex`.

The two code corrections validated by this result are:
1. Values supplied through `render.mesh({ values = ... })` are injected by CSP's shader template and must not be declared again inside the supplied HLSL source.
2. The generated droplet vertices use the visor mesh's local coordinate space, so the attached `SceneReference` must be explicitly rendered with `transform = 'original'`.

Next isolation test:
- create the attached dynamic transport mesh hidden so the ordinary scene pass cannot draw its black fallback material
- in `main.root.transparent`, temporarily set it visible immediately before `render.mesh()`
- restore it to hidden immediately after the explicit draw call
- set `RAIN_DYNAMIC_SURFACE_STATE_ENABLED=true` and `RAIN_DYNAMIC_DROP_UV_DEBUG=false`
- the custom shader then clips the quad to its circular footprint, uses `CullMode.None`, and returns to `DepthMode.ReadOnly`; any surviving ordinary scene fallback remains an unclipped black square and is easy to distinguish

Expected interpretation:
- only double-sided circular blue diagnostic droplets remain: manual draw can be visibility-gated synchronously and the black scene fallback is removed; retain this ownership model
- nothing is visible: the native draw checks SceneReference visibility after the Lua call returns; temporary visibility cannot isolate the paths
- a one-sided black square remains around/without the circular custom output: ordinary scene traversal still sees the temporary visible state; another ownership/material strategy is required

Settings persistence added alongside this test:
- new `[MESH_VISIBILITY]` section follows `[PROFILE_2]`
- keys are the existing `MATERIAL_EDITORS[*].meshName` values and values are `1` (visible) or `0` (hidden)
- loading and saving each iterate the existing material-editor descriptors once; no per-frame name lookup is introduced
- loading applies the saved state immediately to each resolved `targetMesh`
- changing a KN5 visibility checkbox applies the state and saves `settings.ini` immediately

### 45. Stage 4A complete + Stage 4B.0 transparent optical-profile test (2026-09-27)

Confirmed runtime result with `RAIN_DYNAMIC_DROP_UV_DEBUG=false` and dynamic surface state enabled:
- the attached-scene black square fallback is gone
- only the custom shader's circular footprint remains
- foreground geometry correctly depth-occludes the droplets (`DepthMode.ReadOnly`)
- droplets remain visible from both surface-normal directions (`CullMode.None`)
- per-mesh visibility saving/loading also works correctly

This completes the Stage 4A renderer-ownership validation. Temporarily enabling the attached SceneReference only around the synchronous `render.mesh()` call is sufficient on the target CSP build; hiding it again after the call prevents ordinary scene traversal from drawing the fallback material.

The remaining very dark blue disc is not a geometry failure. The Stage 4A diagnostic shader used alpha `0.82..0.94`, so it deliberately replaced most of the background with a nearly opaque fixed color.

Stage 4B.0 change:
- UV debug keeps the existing opaque RG output with `AlphaBlend`
- the normal non-debug path switches to `BlendAccurate`
- replace the opaque filled disc with a hemisphere-derived optical profile
- center alpha is approximately `0.035`
- a Fresnel-like rim contributes up to `0.26`
- a compact directional highlight contributes up to `0.18`
- no scene-color texture or refraction is introduced yet, keeping blend/profile validation isolated from screen-space sampling

Expected result:
- background remains clearly visible through the droplet center
- the circular boundary is carried mostly by a pale blue/white rim
- a small brighter highlight appears toward one side
- foreground depth occlusion and double-sided rendering remain unchanged

If the footprint remains uniformly dark despite the low alpha, investigate render-stage color space/blend state before adding `dynamic::hdr` scene sampling. If the transparent rim/highlight profile is visible, proceed to Stage 4B.1 screen-UV and HDR scene-texture validation, then refraction.

### 46. Stage 4B.0 confirmed + Stage 4B.1 HDR copy alignment test (2026-09-27)

Confirmed Stage 4B.0 result:
- droplet center is almost transparent
- pale blue-white rim defines the footprint
- compact highlight appears at the upper-left
- foreground depth occlusion and double-sided rendering remain correct

This validates `BlendAccurate` and the low-alpha optical profile. Stage 4B.1 now isolates the two prerequisites for refraction: HDR scene-color binding and normalized screen coordinates.

Reference-confirmed shader inputs:
- CSP's public `shader-templates/mesh.fx` defines `PS_IN.ScreenPos` as normalized `0..1` screen position intended for screen/depth sampling
- CSP's Lua SDK defines `dynamic::hdr` as an HDR texture containing scene contents
- `render.mesh()` accepts the same image sources in its `textures` table

Implementation:
- bind `txDynamicScene = 'dynamic::hdr'`
- add `RAIN_DYNAMIC_DROP_HDR_COPY_DEBUG`, enabled for this test
- after circular clipping, sample `txDynamicScene` at `pin.ScreenPos` with no offset
- return sampled HDR color with alpha `1.0`
- texture and value names supplied by Lua are not redeclared in HLSL

Validation settings:
- `RAIN_DYNAMIC_SURFACE_STATE_ENABLED = true`
- `RAIN_DYNAMIC_DROP_UV_DEBUG = false`
- `RAIN_DYNAMIC_DROP_HDR_COPY_DEBUG = true`

Expected interpretation:
- droplet circles nearly disappear into the background with no offset, flip, scale error or brightness seam: HDR binding and screen UV are correct; proceed to controlled radial refraction
- content is recognizable but shifted, mirrored or scaled: diagnose screen-coordinate convention or render-target layout before refraction
- circles are black or a flat color: `dynamic::hdr` is unavailable or bound at an incompatible stage
- scene content aligns but brightness differs: investigate HDR color conversion/render-stage compatibility before introducing offsets

### 47. Stage 4B.1 confirmed + Stage 4B.2 controlled radial refraction (2026-09-27)

Confirmed Stage 4B.1 result:
- with HDR copy disabled, the validated transparent rim and upper-left highlight remain visible
- with HDR copy enabled after a full game restart, no distinguishable droplet footprint remains
- therefore `dynamic::hdr`, `pin.ScreenPos`, HDR brightness and screen orientation/scale all match at the selected render stage

Hot-reload caveat on the target CSP build:
- changing the HDR-copy toggle and reloading Lua alone produces a black-filled footprint
- the intended HDR-copy result appears only after a full game restart
- treat this as dynamic scene-texture resource/binding lifetime behavior during Lua hot reload, not as a screen-UV or droplet-geometry failure
- optical tests using `dynamic::hdr` must use a full game restart until a reliable hot-reload rebind mechanism is confirmed

Stage 4B.2 implementation:
- add `RAIN_DYNAMIC_DROP_REFRACTION_DEBUG`
- add an explicit diagnostic maximum of `RAIN_DYNAMIC_DROP_REFRACTION_PIXELS = 8.0`
- pass inverse current window size so the diagnostic strength remains measured in pixels instead of normalized UV
- reconstruct a hemisphere-like local droplet normal from quad UV
- offset `pin.ScreenPos` radially using the local normal
- suppress the offset at the exact clipped boundary to avoid a hard color discontinuity
- retain a weak version of the validated rim and upper-left highlight over the refracted HDR scene
- values/textures passed by Lua are not redeclared in HLSL

Validation settings, followed by a full game restart:
- `RAIN_DYNAMIC_SURFACE_STATE_ENABLED = true`
- `RAIN_DYNAMIC_DROP_UV_DEBUG = false`
- `RAIN_DYNAMIC_DROP_HDR_COPY_DEBUG = false`
- `RAIN_DYNAMIC_DROP_REFRACTION_DEBUG = true`
- `RAIN_DYNAMIC_DROP_REFRACTION_PIXELS = 8.0`

Expected result:
- background detail bends radially inside each circular droplet
- the exact center has little displacement, displacement grows toward the middle/outer region, and fades again at the boundary
- weak pale rim and upper-left highlight remain visible
- no global image shift, mirror, scale mismatch or brightness seam appears
- depth occlusion and double-sided visibility remain unchanged

### 48. Stage 4B.2 visibility inconclusive + Stage 4B.2A branch discriminator (2026-09-27)

Observed with HDR copy disabled, refraction debug enabled and an 8-pixel maximum offset:
- no distinguishable droplet footprint
- no observable refraction

This does not yet prove the refraction branch failed. The branch replaces the footprint with the sampled HDR scene at alpha `1.0`; at a high output resolution, an 8-pixel radial displacement over smooth background detail can remain visually indistinguishable. The previous low-alpha optical profile is intentionally bypassed in this branch, and its weak accent was not sufficient as a branch marker.

Stage 4B.2A discriminator:
- increase the diagnostic maximum displacement from `8` to `48` pixels
- add a strong cyan annular marker only inside the refraction branch
- retain a stronger upper-left highlight as an orientation marker
- preserve radial offset falloff at the center and exact footprint boundary

Validation settings, followed by a full game restart:
- `RAIN_DYNAMIC_SURFACE_STATE_ENABLED = true`
- `RAIN_DYNAMIC_DROP_UV_DEBUG = false`
- `RAIN_DYNAMIC_DROP_HDR_COPY_DEBUG = false`
- `RAIN_DYNAMIC_DROP_REFRACTION_DEBUG = true`
- `RAIN_DYNAMIC_DROP_REFRACTION_PIXELS = 48.0`

Interpretation:
- cyan rings visible and background inside them strongly bends: refraction value binding, branch execution and HDR offset sampling all work
- cyan rings visible but background remains unchanged: branch/value binding works; investigate offset scale or scene sampling
- no cyan rings: refraction branch/value binding is not active, independent of scene texture visibility
- black-filled circles after Lua reload: repeat after a full game restart because the confirmed `dynamic::hdr` hot-reload binding caveat still applies

### 49. Stage 4B.2A runtime mode selection failure + compile-time mode isolation (2026-09-27)

Observed after a full restart with refraction debug enabled and the diagnostic increased to 48 pixels:
- no cyan branch-marker ring
- no identifiable footprint

Because the fallback Stage 4B.0 optical profile also did not appear, the visible output remains consistent with the unshifted HDR-copy branch. The runtime scalar values used to choose mutually exclusive shader paths are therefore not a reliable mode-selection mechanism on the target path/build.

Correction:
- compute one `dynamicDropShaderMode` in Lua with explicit priority: local UV = 1, HDR copy = 2, refraction = 3, optical profile = 0
- pass it using `render.mesh().defines` as `RAIN_DYNAMIC_DROP_MODE`
- use HLSL preprocessor branches (`#if`) so only the selected diagnostic path is compiled
- remove the three runtime scalar mode values from the injected cbuffer
- retain only genuinely numerical runtime inputs in `values`: inverse screen size and refraction pixels
- continue to avoid redeclaring Lua-provided textures/values in HLSL

This makes mode exclusivity structural: when mode 3 is compiled, the unshifted HDR-copy return statement is absent from the compiled path.

Validation settings remain the Stage 4B.2A settings and require a full game restart. Expected interpretation remains:
- cyan ring visible: compile-time refraction path is selected
- cyan ring plus bent background: screen-space refraction is working
- no cyan ring: investigate define compilation/caching or whether a different shader/file is being executed; runtime scalar ambiguity has been removed

### 50. Stage 4B.2A define result absent + Stage 4B.2B absolute shader-source discriminator (2026-09-27)

Observed after full restart with mode-3 settings:
- still no cyan ring or identifiable footprint

The test is reduced further to remove all remaining optical dependencies:
- stop passing the mode through `render.mesh().defines`
- prepend `#define RAIN_DYNAMIC_DROP_MODE <mode>` directly to the external HLSL text, making the mode part of the actual shader source/cache string
- mode 3 no longer samples `dynamic::hdr`
- mode 3 no longer uses inverse screen size or refraction pixels
- mode 3 returns only opaque magenta after circular clipping
- mode 3 temporarily uses `AlphaBlend` and `DepthMode.Off` for maximum visibility
- the one-time `Dynamic drop root draw` log now includes the Lua-selected mode and final shader-source byte count

With the existing test settings, an opaque double-sided magenta circle is mandatory if the current dynamic mesh and mode-3 shader source are being executed. Interpretation:
- magenta circles visible: shader-source mode selection works; restore the HDR refraction math inside this proven branch
- no magenta circles but log reports `mode=3` and `result=true`: investigate CSP shader-source caching or a different visible/draw pass
- log reports a mode other than 3: configuration selection is wrong before shader compilation
- `result=false` or missing root-draw log: investigate callback/shader readiness/draw execution rather than refraction

### 51. Stage 4B.2B draw-return log absent + Stage 4B.2C callback/draw isolation (2026-09-27)

Observed after full restart with mode-3 settings:
- no visible shape
- the one-time `Dynamic drop root draw` line is absent from the log

The missing post-draw line means the previous test did not establish that
`render.mesh()` returned. Stage 4B.2C therefore adds three ordered checkpoints
and makes mode 3 independent from every external shader input:
- `Dynamic drop root callback entered: mode=3` is emitted before dynamic-mesh initialization
- `Dynamic drop pre-draw: mode=3 inline=true ...` is emitted immediately before `render.mesh()`
- the existing `Dynamic drop root draw: result=...` line is emitted only after `render.mesh()` returns
- mode 3 uses a minimal Lua-inline shader which clips by `pin.Tex` and returns opaque magenta
- mode 3 does not load or concatenate `rainVisorDynamicDrop.hlsl`
- mode 3 does not bind `dynamic::hdr`, pass Lua values, or use shader defines
- `AlphaBlend`, `DepthMode.Off`, `CullMode.None` and the validated `original` transform remain unchanged

With the existing mode-3 settings and a full game restart, interpretation is now:
- all three lines plus magenta circles: callback, mesh initialization, shader compilation and draw all work
- callback line only: initialization or the state-update path exits before drawing
- callback and pre-draw lines, but no root-draw line: `render.mesh()` fails or stops execution while compiling/drawing the minimal inline shader
- all three lines but no magenta circles: draw submission returns, so investigate mesh visibility/geometry rather than shader inputs
- no callback line: the root-transparent callback is not running with the two required runtime flags enabled

### 52. Stage 4B.2C absent + exact Stage 4B.0 regression baseline (2026-09-27)

Observed with the isolated inline-magenta mode:
- no visible output

The important difference from the last confirmed optical result is not the
refraction formula. The confirmed Stage 4B.0 path submitted the external HLSL
unchanged and passed only CSP-injected `gDynamicDropDebugUV`. Later tests
changed the shader submission contract by adding HDR bindings, compile-time
mode source composition, and finally an inline shader. The previously absent
post-draw log also leaves failure during shader submission/compilation as the
leading explanation for the completely absent output.

Regression baseline:
- restore `rainVisorDynamicDrop.hlsl` exactly to the confirmed Stage 4B.0 profile
- restore the confirmed `render.mesh()` table: mesh, `original` transform,
  CSP-injected `gDynamicDropDebugUV`, and unchanged external shader text
- retain callback-entry, pre-draw and post-draw checkpoints with `baseline` in
  their names
- deliberately ignore HDR-copy/refraction controls for this one test
- continue to avoid redeclaring the Lua-provided value inside HLSL

Expected with UV debug disabled after a full restart: the confirmed nearly
transparent center, pale blue-white rim and upper-left highlight should return.
If it does, geometry, visibility gating, state readback and vertex updates are
still valid; HDR sampling can then be reintroduced as the only new variable.

### 53. Startup timing clue + original Stage 4B.2 restoration (2026-09-27)

New observation:
- the restored Stage 4B.0 profile remains absent after an ordinary game start
- removing the Lua file and restoring it, thereby forcing a later Lua reload,
  makes the profile appear

This is strong evidence that the earlier optical/refraction implementations
were not necessarily invalid. The result depends on script initialization or
render-resource readiness timing. Likely boundaries now include root callback
registration, dynamic SceneReference readiness, and external shader/HDR target
availability during the initial game load.

For a controlled confirmation, restore the original Stage 4B.2 implementation
from commit `ee73bea` without the later cyan marker, compile-time modes, shader
source concatenation, or inline discriminator. Preset its required source
flags in the same commit:
- dynamic mesh test: disabled
- deterministic surface test: disabled
- dynamic surface state: enabled
- UV debug: disabled
- HDR-copy debug: disabled
- refraction debug: enabled
- refraction displacement: 8 pixels

Test this revision using the proven remove-and-restore Lua reload procedure.
If the original radial refraction appears only after that later reload, the
next change should address initialization timing rather than optical math.

### 54. Late-reload black footprint + scene-source discriminator (2026-09-27)

Observed with the original Stage 4B.2 implementation after forcing the known
working late Lua reload:
- the circular droplet geometry appears
- its interior is filled with black

This proves that the callback, SceneReference visibility gate, dynamic mesh,
quad UV, circular clip and refraction branch are executing after the late
reload. Black is therefore treated as meaningful sampled output, not as a
generic reload artifact. It strongly suggests that `dynamic::hdr` returns
zero in this pass or that `pin.ScreenPos` samples an invalid region. The prior
invisible HDR-copy result is no longer proof of correct scene alignment because
the newly discovered startup-timing failure could have prevented that draw.

Stage 4B.2D presets the following diagnostic instead of refraction:
- dynamic surface state enabled
- UV, HDR-copy and refraction debug disabled
- scene-source debug enabled

Each clipped circle is split into four texture tests:
- upper-left: HDR sampled at `pin.ScreenPos`
- upper-right: LDR `dynamic::screen` sampled at `pin.ScreenPos`
- lower-left: HDR sampled at fixed UV `(0.5, 0.5)`
- lower-right: LDR sampled at fixed UV `(0.5, 0.5)`
- a thin yellow cross identifies the footprint even if every sample is black

Interpretation after the late Lua reload:
- only fixed-coordinate quadrants show scene color: `pin.ScreenPos` is invalid
- LDR quadrants work but HDR quadrants are black: use `dynamic::screen` or move
  the HDR sampling to a compatible render stage
- all quadrants black around a yellow cross: neither dynamic scene texture is
  available to this callback/path
- all quadrants show scene content: restore refraction and focus on coordinate
  offset math or texture/shader cache timing

### 55. HDR is live but unstable + offscreen-copy hazard test (2026-09-27)

Observed after the late reload with the four-quadrant source discriminator:
- the footprint is predominantly black or dark gray
- quadrants remain distinct and change color rapidly while driving
- the HDR quadrants on the left change frequently
- LDR quadrants on the right change only occasionally
- occasional dark blue and dark yellow values appear

Conclusions:
- `dynamic::hdr` is bound and contains changing data; it is not a permanently
  zero texture
- `dynamic::screen` is stale or unsuitable at this render stage
- fixed-center HDR changing with the scene is expected, but the dark, unstable
  tiled appearance is consistent with sampling a render target while it is
  simultaneously being written
- brightness compensation is therefore premature; first remove the possible
  read/write hazard

Stage 4B.2E uses `ui.ExtraCanvas:updateSceneWithShader()`, which the SDK marks
as suitable for use during scene rendering and for preparing an offscreen
buffer. While that canvas is the active target, it copies `dynamic::hdr` into a
half-resolution `R16G16B16A16.Float` texture. The mesh diagnostic then compares:
- upper-left: direct HDR at `pin.ScreenPos`
- upper-right: copied HDR at `pin.ScreenPos`
- lower-left: direct HDR at fixed center UV
- lower-right: copied HDR at fixed center UV

The source flags are preset with scene-copy debug enabled and the previous
source/refraction diagnostics disabled. A yellow cross remains as the geometry
marker. If the right side becomes stable and scene-like while the left remains
dark or erratic, refraction must sample the offscreen copy rather than
`dynamic::hdr` directly.

### 56. LuaJIT top-level local limit correction (2026-09-27)

The first Stage 4B.2E revision could not load:
- `main function has more than 200 local variables`

LuaJIT compiles the complete script chunk as a function, and this file was
already close to its 200-local limit. The offscreen-copy revision added four
resource-state locals, one shader-source local and one helper-function local.

Correction:
- remove all six newly added top-level locals
- keep canvas, dimensions and log state in one script-global state table
- move temporary dimensions and the copy call into the root-render callback,
  whose locals are counted independently
- inline the small copy shader at its only call site
- retain the Stage 4B.2E behavior and preset flags unchanged

### 57. Offscreen copy black + ScreenPos scale discriminator (2026-09-27)

The Stage 4B.2E screenshot and motion test show:
- upper-left direct HDR changes with scene content but displays a very narrow
  central region across the whole quadrant
- lower-left is a flat central-screen color, as expected from deliberately
  sampling only fixed UV `(0.5, 0.5)`
- both right-side offscreen-copy quadrants remain black
- circles are currently viewed from the visor-normal back side; `CullMode.None`
  intentionally keeps both sides visible and is unrelated to screen UV scale

The copy experiment is removed from the draw path. The black copy could mean
that `dynamic::hdr` is unavailable in the ExtraCanvas pass or that the copy
shader returned black; the observation alone does not establish which.

Stage 4B.2F binds only direct HDR and compares four ScreenPos interpretations:
- upper-left: raw `pin.ScreenPos.xy`
- upper-right: pixel-coordinate interpretation multiplied by inverse viewport
- lower-left: NDC mapped with `raw * 0.5 + 0.5`
- lower-right: NDC mapped to DirectX UV with vertical inversion

The correct quadrant should reproduce the background behind each circle at the
same location and scale. All other optical/source diagnostics are preset off;
ScreenPos UV debug is preset on.

### 58. All four ScreenPos candidates black (2026-09-27)

The user reported all quadrants black after removing the ExtraCanvas prepass.
This does not distinguish unavailable HDR from a missing diagnostic branch.
The preceding frame showed nonblack direct HDR only when the ExtraCanvas copy
call ran before the mesh draw, so the prepass is restored for a controlled
comparison. The mesh still samples `dynamic::hdr` directly in all quadrants;
the copy output is not used as input. ScreenPos UV debug and the prepass are
enabled in the committed configuration.

Every quadrant now has a colored outer rim independent of HDR: upper-left red,
upper-right green, lower-left blue and lower-right magenta. A yellow cross
marks the center. If these colors are absent, investigate shader execution or
the Lua value binding before interpreting black as a texture result. If colors
are present but all four interiors remain black, HDR sampling fails at these
coordinates despite the restored prepass. If the left side regains the previous
scene colors, the prepass changed resource availability or render state and
the earlier coordinate-only test was not controlled.

### 59. Diagnostic executes, all HDR coordinate samples black (2026-09-27)

The user confirmed the yellow cross and red/green/blue/magenta quadrant rims
appear exactly as coded, while all four sampled interiors are black. Thus the
mesh, UVs and diagnostic shader branch work. The next version keeps the same
HDR copy prepass, draw stage and preset flags and changes only the four
interiors:
- upper-left: `dynamic::hdr` sampled at raw `pin.ScreenPos`
- upper-right: a CSP solid red texture sampled at a fixed center UV
- lower-left: `dynamic::hdr` sampled at fixed center UV
- lower-right: raw `ScreenPos.xy` encoded as red/green at 4× gain, with a
  constant blue channel so this quadrant cannot be entirely black

The colored rims remain independent branch markers. Red control texture
visible with both HDR samples black means texture bindings in general work,
while this HDR source is black or inaccessible in the draw. A black control
interior with a visible rim means even a known solid texture failed to bind;
examine the `render.mesh()` texture-injection path. The coordinate quadrant
shows whether ScreenPos itself varies independently of either texture.

### 60. Normal-side reversal and file-texture control (2026-09-27)

The user viewed the diagnostic from the opposite side of the visor normal.
The screenshot confirms that shader-local right appears on the image's left:
- image upper-left, green rim: shader upper-right, `txDynamicControl`
- image upper-right, red rim: shader upper-left, raw HDR
- image lower-left, magenta rim: shader lower-right, `ScreenPos` channels
- image lower-right, blue rim: shader lower-left, fixed-center HDR

The green-rim control interior was black with `color::ff3333`. This does not
yet prove general texture binding is broken because that special texture name
may not resolve as expected for this shader. The magenta-rim interior was
yellowish, confirming nonzero `ScreenPos.xy` values. Both HDR interiors were
black in this capture.

Replace the single control texture source with the project's existing
`GLASS_EXT_RAINFX_surfaceNormal_objectSpace_2K.dds`, already used by the GPU
physics update. Its decoded center pixel is RGBA `(129, 8, 172, 255)`, so the
green-rim interior (image upper-left) should show a distinctly purple/blue
color if ordinary file-texture sampling works in the dynamic mesh draw. Keep
the prepass, all other sources and preset flags unchanged.

### 61. File-texture control passed; compare the draw stage (2026-09-27)

The user observed purple inside the green rim. The static normal-map control
therefore samples correctly in the same `render.mesh()` draw. Both HDR samples
were black at the root transparent stage; this result narrows the issue to the
HDR input or the stage at which it is sampled, without establishing either
cause on its own.

Preset `RAIN_DYNAMIC_DROP_DRAW_AT_TRACK=true` and register the existing manual
draw callback on `main.track.transparent`. Keep the prepass, diagnostic shader,
texture bindings, all other flags, and quadrant colors unchanged. The canonical
track callback still returns when dynamic surface state is enabled. The draw
logs its chosen stage. After a late Lua reload, check whether the image's
upper-right red-rim and lower-right blue-rim interiors gain scene color; the
upper-left green-rim control should remain purple. The image is horizontally
reversed because the observer is looking at the back of the visor normal.

### 62. Track-stage HDR visible, but enlarged (2026-09-27)

The user reports that the green-rim control remains purple and the opposing
HDR sample now contains the forward scene, enlarged like a magnifying glass.
The accompanying image shows scene colors within the circular diagnostic
footprints. This establishes that direct `dynamic::hdr` can be sampled in the
track transparent draw with the current prepass. It does not yet establish
that `pin.ScreenPos` addresses the same projected screen pixel or that the
prepass is needed at this stage.

Keep the track draw, prepass, flags and control unchanged. Replace the blue-rim
fixed-center sample with `saturate((pin.ScreenPos.xy - 0.5) * 8 + 0.5)`.
The red-rim sample remains unscaled. In the user's reverse-side view, compare
the red upper-right and blue lower-right interiors while moving the camera:
whether the blue region shows a wider piece of the scene, becomes smaller in
scale, or clamps to edge colors will constrain the coordinate scale. The
green upper-left still tests the ordinary file texture.

### 63. Expanded scene sample includes other droplets (2026-09-27)

The next screenshot shows a broader scene region within the blue-rim
quadrants; the letter `D` in the track-side banner is visibly smaller than
with the raw sample. The user also observes other droplet images inside the
sampled scene. This confirms that an 8x UV expansion changes the magnification
in the expected direction, but does not prove the right factor or screen
center. The nested droplets suggest that the sampled HDR might include an
earlier dynamic-drop draw; the capture timing needs a separate test.

Preset `RAIN_DYNAMIC_DROP_SCREEN_UV_PREPASS=false`, leaving track-stage draw,
raw-vs-8x comparison, texture controls, and all other flags unchanged. After
late Lua reload, compare whether either HDR quadrant still contains scene
color, and whether nested droplets remain. If the HDR becomes black, the
prepass is necessary for that source at this stage; if color remains, the
prepass can be removed from this diagnostic path.

### 64. HDR available without prepass; compare LDR content (2026-09-27)

The user confirmed that both HDR quadrants still show scene colors and nested
droplets with the prepass disabled. The ExtraCanvas update therefore is not
required for HDR visibility at `main.track.transparent` and does not explain
the nested droplets. A live/current-frame scene source, a previous-frame
source, or another renderer contribution remains possible.

Keep the red-rim raw HDR, blue-rim 8x HDR, and green-rim normal-map control.
Replace the magenta-rim ScreenPos-channel visualization with
`dynamic::screen` sampled using the same 8x UV formula as the HDR blue-rim
quadrant. In the user's back-side view, blue is at lower-right and magenta at
lower-left. Compare whether scene and nested droplets also appear in the
magenta LDR quadrant. The two quadrants sample neighboring pixels of the same
UV transform, so compare the presence and relative scale, not pixel equality.

### 65. Nested drop offset and sparse-frame source test (2026-09-27)

The user reports that nested droplets remain visible and marks an offset
between a source droplet and its smaller image in the captured scene. The
sample can therefore contain another rendered drop at an incorrect screen
location. The reported result alone does not determine whether the source
was produced earlier in the current frame or retained from a previous frame;
it also does not establish that HDR and LDR behave identically.

Preset `RAIN_DYNAMIC_DROP_SPARSE_FRAME_DEBUG=true`: update state as usual, but
draw the dynamic mesh only when `sim.frame % 4 == 0`. The three intervening
frames contain no draws from this callback. Keep track stage, disabled prepass,
the raw/8x HDR quadrants, the 8x LDR quadrant, and the normal-map control.
Visible flicker is expected. On a frame with visible quadrants, inspect
whether either the blue HDR or magenta LDR region still contains a smaller
droplet. If nested images disappear after empty frames, recent rendered
frames contributed to the scene source; if they remain, the diagnostic must
also consider a current-frame contribution or longer retention.

### 66. Empty frames remove nested images; direct HDR snapshot test (2026-09-27)

The user confirmed that a visible droplet after three consecutive frames
without a dynamic mesh draw no longer contains a smaller drop image. Recent
draws therefore feed the scene source. This result is consistent with
previous-frame feedback, but does not establish an exact one-frame delay.

The next test restores continuous drawing
(`RAIN_DYNAMIC_DROP_SPARSE_FRAME_DEBUG=false`). At the track transparent
callback, before `render.mesh()`, copy `dynamic::hdr` directly into a
full-window `ui.ExtraCanvas` using `copyFrom('dynamic::hdr')` and bind that
canvas as `txDynamicSnapshot`. The earlier `updateSceneWithShader()` prepass
remains disabled. Preset `RAIN_DYNAMIC_DROP_HDR_SNAPSHOT_DEBUG=true`; the
back-side-view upper-right red rim samples live HDR at the same 8x UV as the
lower-right blue rim samples the copied HDR. The upper-left green rim remains
the known normal-map control; the lower-left magenta rim remains 8x LDR.
Compare live and copy for background content and nested drop images. This
tests whether an explicit pre-draw snapshot avoids live texture feedback.
If both retain nested drops, the snapshot itself already contains earlier
draws, so stage timing or a clean source must be addressed separately.

### 67. Transparent-stage copy already contains prior drops (2026-09-27)

The user reports nested droplets in both the direct HDR sample and the
snapshot taken immediately before the mesh draw within the track transparent
callback. A direct copy at that point therefore does not isolate a clean
background. Keep continuous drawing and all four source quadrants, but move
the `ui.ExtraCanvas:copyFrom('dynamic::hdr')` call into a separate
`main.track.opaque` callback. Continue drawing and sampling the canvas on
`main.track.transparent`. Log both the capture frame and draw frame in the
existing first-draw log to confirm the earlier callback fired.

If the blue-rim canvas is black while red-rim live HDR has scene colors, the
opaque stage did not expose usable HDR. If the canvas contains scene color
without nested droplets, this earlier capture is a usable clean source. If
both still contain nested droplets, the opaque HDR input already retains
previous draws and another clean-source strategy is needed.

### 68. Opaque-stage HDR still contains shifted self-image (2026-09-27)

The user observes self-images in both the live HDR and the `main.track.opaque`
capture: each droplet shows an offset image of its own lower-left quadrant
along with the surrounding scene. Since the capture precedes transparent
draws in the current frame, a simple stage change did not remove the recent
drop content. The earlier sparse-frame test remains the evidence that recent
draws feed into the input, without specifying the exact retention interval.

For the next test disable the opaque HDR snapshot and enable
`RAIN_DYNAMIC_DROP_GEOMETRY_SHOT_DEBUG=true`. Use an `ac.GeometryShot` at half
window resolution over `ac.findNodes('sceneRoot:yes')`, updated with current
camera position, forward/up vectors, FOV and clip planes. The transport mesh
remains hidden during the independent capture. Feed this shot into the blue
quadrant with the same 8x UV transform as the red live HDR; green normal-map
and magenta LDR controls stay unchanged. Check whether the blue quadrant
contains track scene and whether it has nested droplet images. This is a
diagnostic with an additional scene render every frame; visual alignment and
GPU cost must be measured before considering it as an optical source.

### 69. Independent shot avoids observed nested drops; expose its scene (2026-09-27)

The user reports unchanged performance at about 81 FPS. The independent
blue-rim shot is too dark for easy inspection, but no nested droplet image
was found even after increasing the count to 512. This supports the shot as
a clean source in the tested scene and does not yet establish that its camera
projection or brightness matches the main render.

Preset `RAIN_GPU_STATE_COUNT=512` to reproduce the denser observation.
Keep the independent `GeometryShot` and brighten only its diagnostic samples
by 8x. The blue-rim shader lower-left quadrant uses the shot at the expanded
8x `ScreenPos` coordinates; the magenta-rim shader lower-right quadrant uses
the same shot at raw `ScreenPos`. The red-rim direct HDR and green-rim normal
map remain as controls. In the user's back-side view, compare blue at image
lower-right and magenta at lower-left. Check which shows a wider section of
the same track feature and whether the geometry matches the location behind
each circle. This factor of eight is diagnostic brightness only, not a final
exposure or refraction setting.

### 70. Estimate geometry-shot screen UV scale (2026-09-27)

The user reports that the 8x geometry-shot sample is closer to real size than
the unscaled sample, but objects on screen are about 40% of the size shown
in the 8x quadrant. To reduce the sampled object's apparent size by roughly
2.5x, the first estimate is `8 * 2.5 = 20x` screen UV expansion. This is a
scale estimate only; its center and image orientation still need validation.

Preset two candidates while retaining the 512-drop count, clean independent
shot, 8x brightness adjustment, and other diagnostic flags:
- shader lower-left blue rim (image lower-right): 20x scene UV
- shader lower-right magenta rim (image lower-left): 24x scene UV
- shader upper-left red rim (image upper-right): previous 8x live HDR reference
- shader upper-right green rim (image upper-left): static normal-map control

Inspect a recognizable stationary track feature in both scene-shot
quadrants. Compare its apparent size and whether its position agrees with
the background behind the same droplet. If the feature collapses to a
uniform edge color, the expanded UV is clamping; this test alone does not
establish an exact mapping.

### 71. Geometry-shot 20x projection nearly aligned (2026-09-27)

The attached image and user observation show that the 20x blue-rim scene
sample is close to the background's apparent size. It is still slightly
larger; the offset grows along a recognizable red/yellow trackside graphic.
This suggests a residual scale mismatch. A center offset is not established
from this image alone, so keep the center at `(0.5, 0.5)` for a controlled
scale comparison.

Preset `RAIN_DYNAMIC_DROP_GEOMETRY_UV_SCALE_A=20.5` (image lower-right,
blue rim) and `RAIN_DYNAMIC_DROP_GEOMETRY_UV_SCALE_B=21.0` (image lower-left,
magenta rim). Keep the independent shot, diagnostic 8x brightness, 512
droplets, and the other diagnostic flags unchanged. Compare the red/yellow
graphic's size and how its edge diverges from the actual background; select
the closest scale before assessing any residual constant screen offset.

### 72. Use peripheral landmarks to tune screen expansion (2026-09-27)

The user reports that both candidate scales diverge more near the image edges,
while droplets near viewport center are too similar to distinguish. This is
expected for a center-anchored scale test: `sampleUV = 0.5 + (raw - 0.5) * s`,
so changing `s` has almost no effect where `raw ≈ 0.5` and produces its
largest displacement near viewport boundaries.

For the next comparison, retain candidate A at 20.5x and widen candidate B to
22x. Judge a recognizable fixed feature near the left or right edge and
another near the top or bottom edge. Check whether both sides of each axis
move toward alignment; this helps distinguish a scale error from a constant
center offset. Keep the center-only droplets as a sanity check, not the main
scale criterion. The render remains a screen-scene mapping diagnostic, with
no droplet-surface refraction applied yet.

### 73. Compare empirical scale with actual raster pixel UV (2026-09-27)

The user notes that peripheral droplets rotate with visor curvature, making
their content harder to compare directly, and that even central droplets are
not perfectly camera-aligned. The `GeometryShot` also has limits: its output
is dark and lacks some current post-processing/foliage effects. Do not treat
it as the final optical source.

The internal CSP `mesh.fx` template available in the workspace defines
`PS_IN.ScreenPos` as `float2`, so it has no homogeneous `w` component. The
first projective-division attempt failed shader compilation with X3018 and was
removed before further testing. The template defines `PS_IN.PosH` as
`float4 : SV_POSITION`, which contains the pixel-shader raster position.

Use the raster pixel position and actual HDR texture dimensions to construct
`pixelUV = PosH.xy / float2(hdrWidth, hdrHeight)`. The shader compares this
direct HDR pixel sample in the magenta-rim quadrant against the blue-rim
20.5x independent-shot sample. Red remains the prior live HDR scale test and
green remains the file-texture control. This does not solve the current-HDR
self-image issue, but isolates whether viewport-to-texture resolution caused
the edge-dependent alignment error. The GeometryShot still lacks some live
post-processing and foliage appearance.

### 74. Pixel-addressed HDR has final foliage but a large offset (2026-09-27)

The user confirms the direct pixel-addressed sample includes foliage and
appears to preserve the final scene image without brightness adjustment. The
sample is close in size, slightly enlarged, but its content is substantially
offset even for a droplet near viewport center. This means the simple
`PosH.xy * inverse window size` mapping is not aligned to the source texture;
screen/window dimensions and the HDR texture's own dimensions can differ.

The next shader revision computes pixel UV from `PosH.xy` divided by the
dimensions returned by `txDynamicScene.GetDimensions()`, rather than using
`sim.windowWidth/Height`. Keep the no-brightness direct-HDR pixel candidate
and the 20.5x GeometryShot candidate side by side. Compare a center droplet
over a stationary background landmark first, then one near an edge. If the
large center offset remains, inspect the source's viewport subrect or texture
origin; dimensions alone are not sufficient.

### 75. HDR allocation-size UV reads blank; use active target dimensions (2026-09-27)

With `PosH.xy / txDynamicScene.GetDimensions()`, the user sees the magenta
marker blending toward the yellow quadrant separator but little identifiable
scene content. The debug shader still executes, while the resource-size UV
apparently addresses a mostly empty or dark part of `dynamic::hdr`. Do not
assume the texture's allocation size equals the displayed viewport size.

The CSP Lua SDK also exposes `render.getRenderTargetSize()`. Read it within
the draw callback and pass its inverse as a Lua shader value. The magenta
sample now uses `PosH.xy * gDynamicDropInvRenderTargetSize` for the current
pixel. On the first draw, log the active render target size, window size and
`ui.imageSize('dynamic::hdr')`; this distinguishes common size mismatches
without adding more shader assumptions. The direct HDR sample has no
brightness multiplier. If magenta still shows an offset, the next candidate
is a viewport origin/subrect or source timing difference, not a constant
droplet UV scale.

### 76. Compare live HDR and opaque-stage copy at identical pixel UV (2026-09-27)

The render target and HDR texture are both 2161x1249, while the window is
3240x1872. Their matching dimensions rule out a target-to-texture size
mismatch as the explanation for the nearly black, smeared magenta sample.
Read/write feedback or capture timing remains a hypothesis.

Preset the opaque-stage HDR snapshot and disable GeometryShot. Size the copy
canvas to `ui.imageSize('dynamic::hdr')`, falling back to the target size.
Viewed from behind the visor, image upper-right (red rim) reads live HDR at
`PosH / renderTargetSize`; image lower-right (blue rim) reads the earlier copy
at the identical UV. Image lower-left (magenta rim) reads live HDR at the
previous `PosH / windowSize` UV, which previously showed offset scene detail.
Image upper-left (green rim) remains a known file-texture control. Log copy
size and capture frame; test after the late Lua file reload.

### 77. Account for DLSS raster coordinates in HDR UV comparison (2026-09-27)

The user observes that the earlier opaque snapshot and live HDR, both sampled
with `PosH / targetSize`, are dark and smeared. The live HDR sampled with
`PosH / windowSize` shows recognizable scene color in the same droplet.
The snapshot capture frame equals the draw frame and its dimensions match the
HDR (2161x1249), while the DLSS-upscaled window is 3240x1872. This strongly
suggests `PosH` is measured in upscaled window pixels in this callback;
normalizing it by the smaller render target addresses the wrong UV region.
The scene still has a previously observed positional offset, which this
measurement does not explain.

Preset both the direct live HDR (red rim) and opaque-stage snapshot (blue rim)
with `PosH / sim.windowSize`, using per-frame window dimensions supplied by
Lua so the ratio adapts to resolution and upscaling changes. Keep the old
`PosH / renderTargetSize` live sample (magenta rim) as a dark-UV control and
the normal map (green rim) as a texture control. Viewed through the visor's
back face, red appears upper-right, blue lower-right, magenta lower-left, and
green upper-left. Compare red and blue for scene detail and feedback artifacts.

### 78. Compare a postprocessing screen source for DLSS alignment (2026-09-27)

The user observes a displacement that grows toward the bottom-right. A screen
pixel at half the 3240-wide output, 1620, normalized by the window width is
0.5 and reads texel 1080 of a 2161-wide HDR input. This is the precise
pre-upscale coordinate implied by the user's hypothesis. Changing that UV to
`1620 / 2161` gives 0.75, but the earlier target-size test produced dark,
smeared samples; applying the inverse DLSS ratio to the existing HDR UV does
not fix a source whose content belongs to a different rendering stage.

For the next test, keep red (live HDR) and blue (opaque-stage HDR copy) using
`PosH / windowSize`, keep magenta as the previous target-size control, and
replace the green file-texture control with `dynamic::screen` at the same
window UV. On the back-facing visor, green is the upper-left image quadrant.
Check whether green shows post-upscale scene detail, and compare its apparent
landmark positions against both HDR quadrants near the top-left and
bottom-right. If it is black or stale at this draw stage, investigate capture
at a later stage before modifying the production optical path. The selected
screen and window dimensions remain dynamic across resolutions.

### 79. Test the measured upscaling ratio on the processed screen source (2026-09-27)

The user reports that `dynamic::screen` at `PosH / windowSize` is dark but
contains the same size and position as the live and copied HDR samples. Test
the user's top-left anchored correction directly on this source: the green
quadrant now reads `dynamic::screen` at
`PosH / renderTargetSize = (PosH / windowSize) * (windowSize / renderTargetSize)`.
Both dimensions come from the active sim and render target on every draw, so
it adapts to DLSS quality modes and other resolutions. Multiply the debug
screen RGB by 8 to reveal detail; this is diagnostic brightness only. Keep
red and blue on the previous `PosH / windowSize` HDR UVs, and magenta on the
old target-size HDR UV as controls. Viewed from the back, green appears
upper-left; compare its background landmarks with the actual scene there and
at the lower-right. Samples beyond UV 1 clamp to the edge, so expect the
corrected candidate to lose detail at the far bottom/right if the processed
screen texture does not contain a full-resolution image at this stage.

### 80. Compare three coordinates against the same screen scene (2026-09-27)

The user reports that the `dynamic::screen` sample at
`PosH / renderTargetSize` smears, while `PosH / windowSize` remains
recognizable but offset. Do not apply the scaling as a production fix.

The Stage 4B diagnostic rasterizes the physical drop quads with `render.mesh`.
Each pixel receives interpolated drop-local UV (`pin.Tex`), projected screen
UV (`pin.ScreenPos`) and raster position (`pin.PosH`); the shader clips pixels
outside the unit circle and reads one scene texture at a selected UV. There
is no camera pass for each droplet. The circular diagnostic divides each
single droplet into quadrants and outputs sampled RGB with colored border and
cross. Depth testing is read-only so foreground geometry can occlude it.

Next compare one `dynamic::screen` source using three coordinate definitions,
with identical 8x diagnostic RGB gain: shader upper-right green uses
`PosH / renderTargetSize` (the known smeared ratio candidate), shader
lower-left blue uses CSP's interpolated `pin.ScreenPos` (projection
candidate), shader lower-right magenta uses `PosH / windowSize` (recognizable
but offset reference). Shader upper-left red retains the HDR window-UV
reference without gain. From behind the visor these appear image upper-left,
lower-right, lower-left, and upper-right respectively. Observe the same
background landmark within a centered droplet and one near a screen edge.
The test isolates coordinate mapping because the three candidate samples use
the same texture, shader, gain and draw stage. If none align, inspect the
screen scene's capture/projection stage rather than multiplying UV again.

### 81. Restore last running shader after Stage 80 crash (2026-09-27)

The user reports a game crash on Stage 80. The shader already had a single
return at the end of the screen-UV diagnostic branch and an earlier UV-debug
return; the Stage 80 change did not add an early return. It introduced a new
`dynamic::screen` sample at `pin.ScreenPos` in the blue quadrant and a second
screen sample at `PosH / windowSize` in the magenta quadrant. The crash cause
is unknown without a game or GPU crash log. Restore those two quadrants to
their Stage 79 behavior while retaining the previously running green screen
sample at `PosH / renderTargetSize`, so the next run can confirm the regression
was limited to the latest shader changes. Do not infer a `return` compiler
problem from this crash. Investigate crash logs before reintroducing the
projected-UV screen read.

### 82. Isolate the projected screen sample after confirmed recovery (2026-09-27)

The user confirms Stage 81 no longer crashes. Stage 80 had changed two
samples: the blue quadrant to `dynamic::screen` at `pin.ScreenPos`, and the
magenta quadrant to `dynamic::screen` at `PosH / windowSize`. Test only the
first change now. Keep all settings, other quadrants, texture bindings, and
shader returns as in the working Stage 81 revision. With the back-facing
visor, the isolated projected screen sample appears in the image lower-right
blue-rim quadrant, multiplied by 8 for visibility. If this single change
crashes, do not reintroduce this sample; if it runs, the remaining magenta
change or the combination needs separate testing. HLSL crashes do not yield
engine logs in the user's environment, so single-variable revisions are the
only available diagnostic here.

### 83. Isolate the other changed screen read (2026-09-27)

The user confirms Stage 82 with only the new blue `dynamic::screen` sample at
`pin.ScreenPos` does not crash. Restore the previously running blue snapshot
sample. Now change only magenta to read `dynamic::screen` at
`PosH / windowSize`, multiplying RGB by 8, with all other quadrants and
shader returns unchanged. On the visor back face, magenta appears image
lower-left. If this revision crashes, the second read is sufficient to
trigger the regression. If it runs, the combination or original shader
branch arrangement caused the crash and must be tested independently.

### 84. Reproduce the two-sample combination (2026-09-27)

Stage 82 (only the projected screen sample) and Stage 83 (only the window-UV
screen sample) both run without a crash. Reintroduce the projected sample in
the blue quadrant while preserving the window-UV sample in magenta, matching
the two new reads from Stage 80. Leave the first/green quadrants, bindings,
flags and `return` placement unchanged. A crash here narrows the trigger to
the combined compiled shader path rather than either read alone. If this
runs, the original crash might have depended on branch layout or transient
shader compilation/caching; collect the visible quadrants before proceeding.

### 85. Merge the screen reads into one shader sampling site (2026-09-27)

The user confirms Stage 84 crashes when the projected and window-UV screen
samples coexist, although each individually ran in Stages 82 and 83. The
pattern implicates the combined compiled HLSL path; without crash logs, it
does not prove whether the root cause is the shader compiler, texture
hazard, or resource limits. Avoid adding more separate `SampleLevel` calls on
`dynamic::screen` in the diagnostic path.

In snapshot comparison mode, select one UV based on droplet quadrant first:
green uses `PosH / renderTargetSize`, blue uses `pin.ScreenPos`, and magenta
uses `PosH / windowSize`. Then call `txDynamicScreen.SampleLevel` once from
one shared branch and apply the same 8x RGB gain. Red remains live HDR at the
window UV. Preserve the original noncomparison diagnostic path and the
existing shader returns. This attempts to preserve all three coordinate
candidates while limiting the active screen texture sampling code to one
site. Check crash status before interpreting the visual result.

### 86. Calibrate the uniform screen offset at two measured resolution ratios (2026-09-27)

The user confirms the single-screen-sample diagnostic no longer crashes.
The window-normalized magenta scene appears about 8.8 units wide where the
real object is 7.7, while the `pin.ScreenPos` blue scene is several times
larger. The apparent offset follows the same pattern across droplet positions.
This suggests testing a proportional correction anchored at screen UV zero;
it does not yet prove the HDR or screen source covers the full target UV range.

Continue using a single screen texture sample instruction per fragment. The
magenta quadrant retains `PosH / windowSize` as the recognizable baseline.
The blue quadrant uses 28% of the measured per-axis window/target ratio,
which produces an approximate 1.14x UV scale for a measured ratio near 1.5.
The green quadrant uses 55%, around 1.275x UV scale. Both factors adapt to
current window and render target dimensions, so this tests geometry rather
than assuming a particular DLSS quality setting. The red HDR baseline is
unchanged. Viewed from behind the visor, blue is image lower-right, green
upper-left, magenta lower-left, red upper-right. Compare landmark size and
position against the real scene at a central and edge droplet; note any
clamped/smeared region. These fractional calibration values are diagnostic,
not yet a production optical correction.

### 87. Narrow the calibration interval using measured landmark sizes (2026-09-27)

The user measures original 1.6 versus blue 2.0 at 28% correction (1.25x),
and original 1.56 versus green 1.78 at 55% correction (approximately 1.14x).
Neither candidate smears. The two baselines are similar but not identical;
compare a matching stationary landmark to avoid attributing differences in
object/depth to UV scale. Move the magenta quadrant to the previously tested
55% candidate, blue to 70%, and green to 85% of the per-axis measured
window/target resolution ratio. Preserve the same screen source, single
screen sample instruction, 8x debug gain and red HDR reference. If size
converges but positional offset does not, size and offset need separate
calibration rather than one scalar. Near UV=1, clipping may return a constant
edge color; report that separately from normal scene image.

### 88. Compare near-full resolution correction (2026-09-27)

With the same 1.55 cm original landmark, the user measures blue at 1.70 cm
for 70% correction (about 9.7% large) and green at 1.63 cm for 85% correction
(about 5.2% large). Measurement is approximate. The trend is toward correct
size near a full window/target correction. Test 85% in the magenta quadrant
as a reference, 92% in blue, and 98% in green. Continue one screen sampling
site with the same 8x diagnostic brightness; read the per-axis resolution
ratio from current Lua values. Compare a stationary landmark's size and
position separately. Near-full correction may clamp UV at a screen edge and
smear; record which quadrant and where. The earlier full correction smearing
is not disproved by an acceptable central measurement.

### 89. Compare live screen feedback against an earlier screen snapshot (2026-09-27)

The user's image shows repeated, nested droplet outlines inside the drops.
As the corrected sample UV approaches the on-screen drop position, the
repeated boundary fills its interior; farther from the upper-left, the
calibration error separates the recursive copies. This supports a feedback
explanation for the formerly smeared full-position UV. It does not prove
that an opaque-stage screen capture is free from previous-frame droplets.

For the next controlled test copy `dynamic::screen` at
`main.track.opaque` into a canvas sized to the screen texture (fall back to
render target size). Continue drawing at `main.track.transparent`. In the
screen-UV diagnostic, the green quadrant reads this earlier screen copy at
98% of the dynamically measured window/target ratio; blue reads the live
screen at exactly the same 98% UV. Both multiply RGB by 8. Magenta keeps the
live screen at 85% as a deliberately offset reference; red keeps live HDR at
window-normalized UV. From the back of the visor green appears image
upper-left and blue lower-right. Observe whether the green interior loses
nested outlines while blue retains them, and compare scene detail/brightness.
Log captureFrame, drawFrame and snapshotSize already emitted at first draw.
If both contain recursion, the earlier screen stage is not a clean source;
then use a truly independent capture or change render timing.

### 90. Compare a clean independent scene shot with recursive screen color (2026-09-27)

The user reports that both the opaque-stage `dynamic::screen` copy and the
live screen contain repeated images of the droplet itself at the corrected
coordinates. Thus the screen copy is not an independent clean scene source;
its capture timing does not solve feedback. The user previously observed no
nested drops in the independent `ac.GeometryShot` source, though that shot
was dark and omitted some foliage and final effects.

Enable the independent GeometryShot, disable the opaque screen snapshot, and
preserve the single live `dynamic::screen` sample path. Configure the shot
with `render.AntialiasingMode.YEBIS`, `setBestSceneShotQuality()`,
`setShadersType(render.ShadersType.Main)`, dedicated grass and area shadows,
following CSP's local OBS integration example. It uses the current camera
position, look direction, up direction, FOV and clipping planes. Image
upper-left green reads this independent scene shot at 98% correction; image
lower-right blue reads the live screen at exactly the same UV; image
lower-left magenta reads live screen at 85%; image upper-right red retains
live HDR. The 8x gain on the independent shot is only for debugging.

Inspect whether green remains free of recursive circles, and whether foliage,
brightness and projection better match the main screen. Measure FPS because
YEBIS and dedicated grass can make the extra scene shot expensive. If green
still differs, diagnose capture quality separately from UV alignment before
using it for the final optical shader.

### 91. Restore the visible independent shot before trying postprocessing (2026-09-27)

The user reports that the entire droplet disappears when Stage 90 enables
YEBIS and additional shot quality methods. The repository's `lib.lua`
GeometryShot constructor documentation says antialiasing expects the default
texture format, while that revision used `render.AntialiasingMode.YEBIS`
with `render.TextureFormat.R16G16B16A16.Float`. A Lua callback error or
incompatible shot resource could prevent the later mesh draw; the exact
cause is unconfirmed without an error log.

Restore the previously used `AntialiasingMode.None` with the float texture,
and remove the new best-quality, Main shader, dedicated grass and shadow
calls. Keep GeometryShot enabled and keep green on the independent 98% shot,
blue on live screen at the identical UV, and magenta on live screen at 85%.
First confirm the circles render and whether green avoids recursive drops.
Then add processing features back one at a time, using the default texture
format when antialiasing is enabled, per the bundled `lib.lua` API contract.

### 92. Restore sky in the clean scene shot without changing rendering mode (2026-09-27)

The user confirms the independent GeometryShot draws the correct scene at
nearly the right position, with no repeated drops even at the screen edges.
The remaining edge offset is small. The shot is low-quality and excludes sky,
but runs at about 72 FPS with 512 drops, compared with an earlier YEBIS
attempt at about 50 FPS and no visible droplets.

The bundled `lib.lua` API explicitly states that GeometryShot sky is disabled
by default and provides `shot:setSky(true)`. Add that one option when the shot
is created. Keep `AntialiasingMode.None`, the existing float texture format,
the same camera, 98% diagnostic UV and 8x diagnostic gain. Check whether the
sky now appears in green while live-screen blue still shows recursion, and
compare FPS. If the sky remains absent, CSP's alternative sky may not be
included by the GeometryShot sky pass. Future quality work can test original
lighting and Main shaders separately; do not enable YEBIS until texture
format compatibility and draw behavior are established.

### 93. Remove sky call that suppresses droplet draw (2026-09-27)

The user reports the entire droplet disappears again when `shot:setSky(true)`
is added to the previously working float-format, no-antialiasing GeometryShot.
Although `lib.lua` declares that method, this test shows that calling it at
this capture stage prevents the current diagnostic draw. The root cause is
not known from a missing image alone; avoid calling it in the active path.

Remove only the sky call to restore the previously observed clean scene shot.
Add first-draw logs immediately before GeometryShot setup and after `update()`
so a future missing-output test can distinguish an interrupted shot setup
from a later shader/draw problem; the existing pre-draw and mesh-result logs
cover the remaining steps. Keep the source, UV, and diagnostic flags from the
known-running revision. Sky and other effects remain an independent capture
quality question, separate from the now well-supported feedback diagnosis.

### 94. CSP public RainFX reference: scene source, sky, and capture timing (2026-09-27)

Inspected the public acc-shaders GitLab repository at revision
`4f05cc0ba26f7c363886ebb406b35f67157139d0` (read-only checkout outside
this project). Relevant paths:

- `custom/rain/accRainDrops_ps.fx`: the fast color-buffer path samples the
  engine-provided `txPrevFrame` at `pin.PosH.xy * extScreenSize.zw`, with an
  alpha-dependent MIP bias. Without the color buffer it samples the
  environment (`sampleEnv`). The detailed water path combines reflected and
  refracted environment colors and optionally calls `calculateRefraction`.
- `custom_objects/common/refraction.hlsl`: the refraction UV is built from
  raster position (`posH.xy * extScreenSize.zw`) and a view/normal-dependent
  offset. The final color also samples `txPrevFrame`, selecting a MIP level.
- `custom_objects/common/rainUtils.hlsl`: `sampleEnv` reads the engine's
  reflection/environment path (`SAMPLE_REFLECTION_FN`), which can provide a
  sky response independently of direct scene-color sampling.
- `custom/rain/accRainScreen_combine_ps.fx`: a screen-overlay composition
  path reads a blurred scene texture (`txBlurred`) and a distinct water mask
  (`txMask`), perturbs UV using mask gradients and outputs alpha. The public
  pixel shader does not expose the engine-side capture order for `txBlurred`.

These files show that CSP's rain uses engine-owned previous-frame/blurred
color and environment inputs, not simply `dynamic::screen` fetched inside a
transparent mesh draw. The public shader alone does not establish whether
RainFX “Drops on Screen” specifically uses each listed variant or when its
inputs are copied. The project's bundled `lib.lua` lists
`dynamic::screen`, `dynamic::hdr` and `dynamic::depth` as the exposed Lua
textures; it does not expose the rain shader's `txPrevFrame` by that name.
In this project both live and opaque-stage `dynamic::screen` contained nested
visor drops, while an independent GeometryShot did not.

Next concrete options: capture a clean scene in a render stage before the
visor effect using a documented engine surface, if Lua exposes one; or
improve the independent GeometryShot by applying rendering options one at a
time. The `lib.lua` documentation recommends `render.onSceneReady()` for
scene-dependent GeometryShot updates, before main rendering; try moving the
shot update there before re-testing sky/lighting options. Keep the working
independent-shot variant as a fallback until the new capture is verified.

### 95. Move the unchanged independent shot to scene-ready timing (2026-09-27)

The user authorizes the first step of the proposed `render.onSceneReady()`
route, with performance monitoring. `lib.lua` explicitly recommends this
callback for scene-dependent GeometryShot rendering, after shadow/reflection
updates and before main rendering. Move creation, clipping-plane setup and
`update()` from `main.track.transparent` to that callback. Preserve shot
resolution (half window), one mip, `AntialiasingMode.None`, float texture,
normal lighting defaults, and the current debug shader. The transparent
callback consumes the latest shot but never re-renders it; it logs shotFrame
alongside drawFrame and skips the draw if the shot does not yet exist. No new
chunk-level Lua locals are introduced.

Compare whether all drops still draw, whether the clean green scene changes,
and FPS relative to the previous roughly 72 FPS at 512 drops. Do not enable
`setSky`, YEBIS, original lighting, Main shaders, transparency or mipmaps
until this timing-only test succeeds. The same camera parameters do not, on
their own, prove that `pin.ScreenPos` is numerically identical between the
shot and the DLSS-scaled main viewport; keep the empirical 98% candidate
until alignment is remeasured. The current screen copy feedback suggests
shared stale composited content, but public Lua API documentation does not
guarantee that `dynamic::screen` is exactly a previous-frame final image in
all stages.

### 96. Test original scene lighting in the working scene-ready shot (2026-09-27)

The user confirms that moving GeometryShot updates to `render.onSceneReady()`
retains all drops and the nearly aligned, low-resolution clean scene. At the
chosen reference camera view FPS is 75. First shot update and transparent
mesh draw both occurred at frame 498630; the scene-ready shot is 1620x936,
the window is 3240x1872, and the main render target is 2161x1249.

The bundled `lib.lua` says GeometryShot uses neutral lighting by default;
`setOriginalLighting(true)` enables original scene lighting. Set this one
option when creating the independent shot. Keep sky disabled, no YEBIS, the
same float format, shot resolution, camera, 98% scene UV, and shader debug
brightness. Compare the green quadrant against the previous baseline for
brightness, color, visibility, continued absence of recursive drops and FPS
at the same reference view. A changed result does not by itself demonstrate
HDR-to-LDR tonemapping; `AntialiasingMode.None` remains in effect. If drops
vanish, check for `scene-ready shot: starting/updated` and first pre-draw
logs to localize the failing shot operation.

### 97. Inspect independently lit scene without debug gain (2026-09-27)

With `setOriginalLighting(true)` on the scene-ready GeometryShot, the user
reports brighter green scene color, visible drops, no recursive self-image,
and FPS in roughly the same range as the 75 FPS reference. Remove only the
8x RGB multiplier from the green quadrant's independent shot so its true
color and exposure can be evaluated. Blue and magenta live-screen diagnostics
retain 8x gain as comparative references, and no shot quality, sky,
resolution or UV settings change. With antialiasing still set to None, this
is a direct independent scene-color read without YEBIS tonemapping. Compare
green brightness, sky, foliage, and visible detail at the reference camera;
report FPS and whether the drop remains visible.

### 98. Test Main shader type for independent-shot material and shadow fidelity (2026-09-27)

After removing the debug 8x gain from the green independent scene, the user
reports scene lighting close to the original at most positions and similar
FPS. Some shadows, notably track surface shadows, remain absent. The sky is
still dark, and CSP-added grass/particles are missing. `lib.lua` describes
`render.ShadersType.Main` as the full shader set with lighting; it separately
documents sky, grass, particles and alternative shadows options.

Change only `GeometryShot:setShadersType(render.ShadersType.Main)` in the
scene-ready shot setup. Keep `setOriginalLighting(true)`, antialiasing None,
float texture, one-mip half-window capture, clean 98% UV and the unchanged
transparent draw. Check whether the drop still renders, whether the track
material and its shadow are closer to the main view, whether the sky and
CSP grass remain absent, and FPS at the reference camera. Main shaders may
cost more; this test isolates shader selection from sky/grass/tonemapping.

### 99. Add default GrassFX geometry to the clean Main-shader shot (2026-09-27)

With original lighting and `render.ShadersType.Main` on the scene-ready shot,
the user confirms drops remain visible and shadows now appear. Sky and added
grass are still absent. At the reference camera FPS is about 67–69, compared
with approximately 75 before switching to Main shaders (roughly 6–8 FPS
below that reference, depending on measurement variation).

`lib.lua` says GeometryShot omits grass by default and supports
`shot:setGrass(true)` to enable it around the camera. Enable only this
regular mode when constructing the shot. Do not use `'dedicated'`, which the
API describes as an expensive alternative Grass FX spawn area. Keep Main
shaders, original lighting, one-mip float format, no YEBIS, unchanged sky
setting and scene-ready timing. Verify that drops continue to draw, whether
CSP grass becomes visible in the green quadrant, and FPS at the same view.
If grass remains absent, a separate Grass FX spawn area may be required;
assess its cost before selecting it.

### 100. Retest the sky pass at scene-ready timing (2026-09-27)

The user confirms ordinary `GeometryShot:setGrass(true)` includes CSP grass,
retains the Main-shader shadows, and runs at roughly 69–71 FPS at the same
camera. The 67–69 FPS preceding observation overlaps ordinary scene/perf
variation; do not attribute a precise FPS change to one option.

Sky remains the major missing feature. `shot:setSky(true)` previously caused
the drops to disappear when the shot was updated inside
`main.track.transparent`, before it was moved to the API-recommended
`render.onSceneReady()` stage. Add only `setSky(true)` during scene-ready shot
creation now; preserve Main shaders, original lighting, regular grass, half
window shot, float format and antialiasing None. Check first whether the drop
still draws and whether `scene-ready shot: updated` and `pre-draw` logs
appear, then inspect sky in the green quadrant and FPS. If the drop
vanishes again, the trigger is not solely the mid-frame capture timing;
restore the previous working shot before further changes.

### 101. Measure scene-shot detail and cost at active render-target size (2026-09-27)

The user confirms that the scene-ready independent GeometryShot now shows
sky, shadows, Grass FX and no recursive drops after enabling original
lighting, Main shaders, regular grass and sky individually. The update frame
and transparent draw frame both equal 626617; FPS did not measurably change
when the sky was enabled. The shot is still 1620x936, half the 3240x1872
window, so fine scene details remain visibly low resolution.

Change only the shot allocation size to `render.getRenderTargetSize()` during
`onSceneReady`, falling back to half-window size if no active target size is
reported. At the measured DLSS mode the main target was 2161x1249, roughly
1.78 times as many pixels as the old shot. Preserve the original camera,
quality and diagnostic shader including sky, grass and shadows. Log the shot
size and compare fine scene detail, UV alignment, no-recursion behavior and
FPS at the reference view. This is a deliberate cost test; revert to the
half-window source if the quality gain does not justify its frame cost.

### 102. Cache main-pass target size instead of scene-ready auxiliary target (2026-09-27)

The user reports a tiny, unusable scene shot after Stage 101; the logs show
`scene-ready shot: updated 64x64` while the later transparent pass reports
`targetSize=2161x1249` and `windowSize=3240x1872`. At scene-ready timing,
`render.getRenderTargetSize()` refers to a 64x64 auxiliary target, not the
main render target. No inference about the correct shot size can be drawn
from it at that callback.

Read `render.getRenderTargetSize()` in the known main track transparent draw,
where the previous diagnostics measured 2161x1249, and cache width/height in
the existing scene-copy state for the next scene-ready shot. Until the first
main draw, initialize at the previously working half-window resolution
(1620x936). Reallocate the shot when the cached main target dimensions
change; log shot update on resize even if the first draw has already been
logged. Guard against tiny non-main targets before caching. Keep all shot
features, UVs and shader unchanged. After the second rendered frame the
expected logged shot size is 2161x1249, allowing an actual quality and FPS
comparison against the half-window baseline.

### 103. Compare independent-shot refraction at two pixel offsets (2026-09-27)

The user confirms the scene-ready GeometryShot switches from 1620x936 on the
first frame to 2161x1249 on the next frame, remains free of recursion, has
sufficient image quality for a scene source, and causes no clearly measurable
FPS change. Do not increase the shot resolution further.

Keep the preset `RAIN_DYNAMIC_DROP_SCREEN_UV_DEBUG=true`,
`RAIN_DYNAMIC_DROP_GEOMETRY_SHOT_DEBUG=true`,
`RAIN_DYNAMIC_DROP_HDR_SNAPSHOT_DEBUG=false`,
`RAIN_DYNAMIC_DROP_REFRACTION_DEBUG=false`, and
`RAIN_DYNAMIC_DROP_REFRACTION_PIXELS=8.0`. Change only the screen-UV debug
shader: image upper-left green shows independent shot without displacement;
image lower-right blue uses a radial displacement up to 8 shot pixels; image
lower-left magenta uses 24 shot pixels. Image upper-right red retains the
live-HDR reference. All three independent-shot quadrants share the measured
98% source UV correction, a single texture sample instruction and no
brightness multiplier. Offset fades at the drop center and clipped edge.
The inverse target size supplied by Lua converts shot-pixel offsets to UV;
after the first frame the shot allocation matches the main target size.
Observe whether blue/magenta bend stationary background features in the
expected direction without introducing self-images, clipped edges or
unexpected black areas. Measure FPS at the reference camera before selecting
an optical strength. The green quarter is the exact undistorted control;
other optical properties are intentionally unchanged for this test.

### 104. Compare 8px and 16px displacement against CSP refraction model (2026-09-27)

The user sees a gentle bend at 8 pixels and a rough, strong bend at 24
pixels. There is no recursive droplet image and no measurable FPS change. A
supplied close-up shows the hard edge distortion in the stronger quadrant.
The CSP public `custom_objects/common/refraction.hlsl` does not prescribe a
fixed pixel offset for a rain drop: its `calculateRefractionOffset()`
projects a normal onto camera directions and scales by incidence, screen
aspect, camera tangent and inverse view-space distance; the shader then
samples engine-owned previous-frame color. That is a useful structural
reference, not an empirical 8px or 24px target for this visor geometry.

Keep green undistorted and blue at 8 shot pixels; change only magenta from
24 to 16 shot pixels. Retain the clean full-resolution scene shot, single
sample site and all preset debug flags. Compare the same straight background
edge in the two refracted quadrants, especially at the drop center and rim;
look for a smooth transition, acceptable bending and no hard kink. Check
FPS in the reference view. After choosing a visual range, express the
strength relative to projected droplet size/camera geometry rather than
assuming that a fixed pixel count is valid across resolutions and sizes.

### 105. Test the full droplet optical profile with the clean 16px scene (2026-09-27)

The user finds 16 shot pixels in the magenta quadrant more plausible than
the gentler 8px or harsh 24px candidate; neither refraction comparison
reintroduced nested droplets or measurable FPS cost. Preset
`RAIN_DYNAMIC_DROP_SCREEN_UV_DEBUG=false`,
`RAIN_DYNAMIC_DROP_REFRACTION_DEBUG=true`,
`RAIN_DYNAMIC_DROP_REFRACTION_PIXELS=16.0`, and keep the independent
GeometryShot enabled. This selects the full circular footprint, existing
low-strength blue-white rim/highlight, and a clean scene sample shifted by
the same radial profile that was validated in the quadrant experiment.

For the shot path, start with the measured `PosH / windowSize` UV at 98% of
the dynamic window/target ratio, then add the local drop normal times a
16-shot-pixel offset converted by inverse target dimensions. Sample the
independent `txDynamicSnapshot` once and return its RGB plus the accent at
full alpha; the original live-HDR refraction branch remains available when
the independent shot flag is off. No Lua-injected HLSL texture/value is
redeclared. This remains an optical diagnostic: the exact independent-shot
alignment at edges, full-alpha replacement and fixed pixel strength need
assessment across sizes and DLSS modes before production integration.

Test entire drops for plausible background bending and placement, rim and
highlight strength, sky/grass/shadow fidelity, clipping/occlusion, absence
of recursive imagery, and FPS at the same reference camera. If the apparent
refraction changes disproportionately between small and large drops, next
scale the displacement by the projected droplet radius rather than hardcoding
16 pixels for every drop.

### 106. Compare full replacement against translucent refracted composition (2026-09-27)

The user accepts the 16-shot-pixel refraction strength without noticeable
extra cost, and asks to include force-driven internal waves and trail/merge
visuals in the optical work. Preserve the clean GeometryShot, 16px offset,
existing blue-white rim and directional highlight. Split each full circular
drop with a thin yellow vertical seam: on the back-facing visor the image
right half replaces the background with refracted shot color at alpha 1,
while the image left half alpha-blends the same color over the current
framebuffer. The translucent candidate starts at alpha 0.12 in the center,
increases with Fresnel-like rim, highlight and the outer radial band, and
can approach 0.7 near the edge. Both sides use the same single clean scene
sample. No settings or other sources change. Inspect center clarity,
refraction visibility, edge/sky color discontinuity, seam, foreground depth
and FPS across dark and bright backgrounds. Then choose or adjust a unified
compositing profile; the split is diagnostic only.

Follow-on motion work, after the compositing choice:

1. Drive a small decaying oscillation of the local normal/refraction offset
   when the visor force or droplet velocity changes. Start with a uniform
   force pulse to validate amplitude, damping and direction. For realistic
   per-drop response, provide the corresponding acceleration/velocity data
   to the pixel shader explicitly; currently `ac.MeshVertex` exposes only
   position, normal and local UV and the visible shader does not receive
   per-drop velocity. Do not claim per-drop force response from a global
   value alone.
2. Represent trails as surface-aligned geometry or a separate persistent
   mask that carries radius, thickness, alpha and a normal/flow profile.
   Reuse the clean scene shot for their refraction and draw them after the
   main scene with visor depth testing. Match the parent droplet's motion
   direction and damp trail contrast downstream.
3. Define a merge rule on the persistent state: conserve approximate water
   area/volume when drops or trails overlap, update the surviving drop's
   position and velocity, and remove stale trail segments smoothly. Verify
   the visuals at speed reversals and intersections, then measure the
   separate geometry/mask update cost and GPU draw cost at 512 drops.

These are design directions, not implementations delivered by this commit.

### 107. Compare a stronger translucent drop against the preferred opaque reference (2026-09-27)

The user reports that the fully replaced image-right half clearly reads as
a convex sphere reflecting/distorting the environment, with strong
refraction and good droplet visibility. The previously blended image-left
half shows a difference mainly at its outline; its interior is too close to
the unmodified scene to identify as a water drop. Keep the preferred opaque
right half as the reference while raising only the left half's alpha from
0.12 at the center to 0.55. Reduce the extra Fresnel, highlight and outer
rim alpha contributions so the left half remains below full opacity (about
0.9–0.98 at strongly lit edges). Preserve the 16px scene displacement,
scene source, rim/highlight RGB, depth, separator and camera setup.

Compare the two halves over the same textured and flat backgrounds: does the
new left interior show enough curvature without the right half's strong orb
appearance? Check seam, edge/sky color differences and FPS. If opacity alone
cannot produce the intended natural refractive shape, adjust the displacement
profile next, rather than hiding it with low alpha. Motion-driven ripple
strength and trail compositing will be built on the chosen whole-drop profile.

### 108. Adopt the preferred translucent optical profile for the whole drop (2026-09-27)

The user confirms the left test half with center alpha 0.55 still conveys a
convex lens, and appears a little more natural than the full-alpha right
half. Remove the yellow separator and opaque candidate. Apply the same
center-to-rim alpha profile to the entire drop, leaving 16px clean-shot
refraction, optical accent, depth behavior, scene-ready shot and runtime
flags unchanged. Judge the whole circular shape under movement and on
bright/dark backgrounds before modifying force-dependent refraction.

The bundled `lib.lua` exposes `ac.getCar(0).acceleration` in car-relative
axes, but a global vehicle force alone cannot assign unique phase and
amplitude to each drop. The persistent GPU/CPU state already tracks per-drop
velocity; a follow-on force-wave stage must transport appropriate per-drop
motion/acceleration information to the optical shader, or explicitly label
a shared-force ripple as an initial prototype. Trails also require geometry
or a mask and compositing rules. Keep these motion stages separate from this
approved full-drop blend so their visual and FPS costs are measurable.

### 109. Prototype decaying force-driven ripple against stable refraction (2026-09-27)

The user accepts the unified translucent 16px refraction as a natural curve.
The next motion effect is an interior ripple when the car receives force;
trails and merging still require a separate geometry/mask stage.

Use `ac.getCar(0).acceleration` (the bundled `lib.lua` declares G units,
car-relative X lateral and Z longitudinal) in the transparent draw callback.
Ignore the vertical component. Store a wave envelope/phase and previous
force in the existing scene-copy state table, with no new chunk-level Lua
locals. Raise the envelope when planar acceleration exceeds 0.25 G or grows
suddenly; decay it at approximately four inverse seconds, advancing phase
using bounded `sim.dt`. Pass the normalized planar direction, envelope and
phase as Lua shader values. Do not redeclare those uniforms inside HLSL.

In the geometry-shot refraction branch, add at most 2.5 shot pixels of
sinusoidal displacement along that direction, tapered toward both center
and outer edge. Only the back-facing visor's image-right half receives the
wave; image-left keeps the approved refraction and alpha. Both halves share
the clean scene sample and one sampling instruction. Inspect during a
stationary car, braking, acceleration, direction changes and sustained
cornering. The pattern currently responds to *vehicle-wide* force, not each
droplet's own acceleration; its orientation is a provisional mapping from
car X/Z to the droplet's local UV and needs visual validation. Measure FPS
at the reference camera with 512 drops. A later iteration should encode
per-drop motion or force into data accessible by the optical shader before
claiming individually responsive ripples.

### 110. Drive the diagnostic wave from the existing inertial force (2026-09-27)

The first ripple prototype read car acceleration independently, so disabling
the drop physics inertia force did not stop the ripple. Use the same
`rainAccelerationCurrent` world acceleration and `RAIN_PHYSICS_ACCEL_SCALE`
as the drop physics, projected onto the car side and forward directions.
Gate it with `RAIN_FORCE_INERTIA_ENABLED`; disabling inertia immediately
clears the envelope and permits a fresh trigger log when reenabled.
For this visibility test, the image-right wave reaches at most six shot
pixels. The image-left half remains the approved optical reference.
Compare acceleration and braking against a stationary car, then toggle
inertia off and back on and check the single trigger log and FPS. This
prototype still shares one force signal across all drops.

### 111. Add shared airflow to the diagnostic wave (2026-09-27)

Enable `RAIN_FORCE_AIRFLOW_ENABLED` for the next in-game comparison. Use
the existing car world velocity, air density, drag coefficient and physics
acceleration scale to estimate aerodynamic acceleration for a representative
drop with `RAIN_DYNAMIC_SURFACE_TEST_DROPLET_DIAMETER_MM`. Use the car forward
axis as a visor-front normal for the same one-sided incidence rule as the
physics shader. Add the projected world airflow vector to the existing
inertial wave force before calculating envelope, phase and direction. Turning
off one force source preserves the other; turning both off clears the wave.
Reset the one-time trigger log and force history when either source toggle
changes, and log the estimated airflow magnitude to aid comparisons.

This optical prototype is a common wave for all drops. The GPU physics
evaluates airflow per drop using the sampled actual surface normal and its
own radius; a shared car-forward estimate can therefore differ in incidence
and strength. Compare stationary versus steady speed, acceleration and
braking, with inertia-only, airflow-only and both sources enabled. Check
FPS at 512 drops. Keep the existing left optical half as the reference.

### 112. Pause ripple tuning and compare an irregular silhouette (2026-09-27)

The user can discern the six-pixel wave but cannot assess it in isolation
before flow and merging are in place. Set `RAIN_DYNAMIC_DROP_WAVE_ENABLED=false`
and pass a zero envelope to the existing HLSL code, retaining it for later.
Restore `RAIN_FORCE_AIRFLOW_ENABLED=false` as the physics baseline for this
optical comparison. Leave the approved clean-scene refraction unchanged.

Enable `RAIN_DYNAMIC_DROP_SHAPE_DEBUG=true`. Keep the image-left circular
half as the optical reference. Indent the image-right contour by at most
approximately 11% using two smooth angular harmonics; fade deformation
across the center so the halves meet. Apply the adjusted normalized radius
to clipping, lens normal, boundary fade, rim and alpha. No extra scene shot,
sample or geometry is added. Compare whether the irregular right half reads
as a water drop on bright and dark backgrounds, whether the center seam is
visible, and FPS at 512 drops. This is a shared fixed shape preview, not
individual droplet deformation, trailing or merging yet.

### 113. Skip disabled wave computation (2026-09-27)

The zero envelope from stage 112 disabled visible wave displacement but
still ran vehicle force, airflow, envelope and direction calculations in
Lua, plus the HLSL sinusoid. When `RAIN_DYNAMIC_DROP_WAVE_ENABLED=false`,
send zero direction, envelope and phase without entering the Lua wave
calculation. In the optical shader, enter the wave profile and sinusoid
only for a nonzero envelope on the affected half. Keep the clean-shot
refraction sample and existing circular/irregular shape comparison intact.
The screenshot with trackside objects also shows only a subtle difference
between contour halves, so do not treat this silhouette preview as chosen.

### 114. Make the silhouette comparison readable (2026-09-28)

The second screenshot contains trackside detail, yet the first 11% contour
indent is still hard to distinguish. Keep the left half circular and the
right half angularly indented, but raise the maximum right indentation to
24%. Expose `RAIN_DYNAMIC_DROP_SHAPE_STRENGTH` (default 1.0) as a Lua shader
value to tune this visual test later; HLSL consumes the injected value
without declaring it again. Raise the same pale rim contribution from
0.08 to 0.16 on both halves, so contour comparison has equal rim treatment.
Keep refraction at 16 shot pixels and leave the force-wave default off.
Check whether the right outline reads clearly against clouds, trackside
detail and dark surfaces, whether the seam is noticeable, and FPS. This
tests silhouette visibility before attaching per-drop velocity or trails.

### 115. Vary silhouettes and attach first optical trails (2026-09-28)

The user confirms that the stronger contour is visible, but every drop has
the same shape. Their CSP windscreen reference combines varied standing
drops with refractive, elongated water behind flowing drops. Preserve the
approved 16-pixel clean-scene refraction and disabled wave.

Encode a stable shape seed in even Tex.x bands of each drop quad; decode it
before local UV clipping in HLSL. Vary the angular phases and indentation
amplitudes per seed. Retain circular image-left halves as references for
this first variability check. Do not add a new texture, draw call or
per-drop shader uniform; shader values from Lua remain injected without
redeclaring them. Apply the varied contour to the complete drop now that
the side-by-side indentation has been visually confirmed. Turning
`RAIN_DYNAMIC_DROP_SHAPE_DEBUG` off restores circles for comparison.

Reserve one more quad per drop in the same transport mesh. Use the
asynchronously read GPU velocity and predicted position to place a narrow
strip from the present drop back along its current travel direction, with
a short length clamped to 0.45..5 drop radii and width tapered at its tail.
`RAIN_DYNAMIC_DROP_TRAIL_ENABLED=true` and `RAIN_DYNAMIC_DROP_TRAIL_SECONDS=0.25`
are the first test settings. Hide the strip for stationary, dead, or
unmappable drops. The pixel shader uses the same independent scene shot
with one additional refracted sample only where the strip covers pixels;
the main drop's optical path stays separate. Measure the real FPS at 512
drops against the prior build as well as the trail toggle off (the latter
still reserves the extra vertices). Check the trail direction, seam and taper,
especially at the visor edges. The current strip follows instantaneous
velocity rather than storing deposited water, so it does not persist after
a stop or turn. Persistent trails, merge/split events and conservation of
drop mass need a subsequent GPU state pass and should be tested separately.

Follow-up order after this visual/FPS gate: retain a sparse surface wetness
history for deposited water, allowing turns and stops to leave a fading
track; add neighbor lookup with fixed visor-UV cells before implementing
merge/split (all-pairs checks would grow quadratically at 512 drops);
then transfer water volume between merged drops and trail deposits. Keep
the clean-scene shot shared and measure each new GPU pass separately.

### 116. Expose trails outside large bodies and plan rain-fed lifecycle (2026-09-28)

The first in-game test shows a short trail on small drops, apparently
emerging from their center, and no clear trail on larger drops. The initial
strip starts at the drop center, is submitted *after* the body and could
be only 0.45 body radii long. Render strip triangles before body triangles
within the same mesh, so the body covers the connecting tip. Measure strip
length from the drop center as its body radius plus at least 1.2 extra
radii, capped at six radii; continue suppressing stationary strips. Fade
the optical trail before it reaches the center. The per-drop 0.25-second
velocity term and no-extra-scene-shot contract remain unchanged. Verify
that trails are actually visible outside bodies of different sizes and
measure FPS at 512 drops.

The user's dark screenshot shows an objectionable pale outline. The rim is
currently an additive fixed pale color, so future shape/lifecycle changes
will not remove it. Attenuate both main-drop and trail additive rim from
their sampled clean-scene luminance, keeping a weak contribution in dark
scenes. Check bright/dark backgrounds separately: very bright sampled
refraction can still create a line despite reduced artificial accent.

The current production mode is `RAIN_GPU_STATE_MODE=3`, while the existing
exit/wait/respawn meta shader is gated on mode 6. Even mode 6 only kills
drops at the visor boundary; stationary drops cannot cycle. Next lifecycle
experiment should run the already implemented mode-6 boundary behavior
in isolation and verify that it does not hide or freeze the mesh. Then add
bounded age and probabilistic rain-driven turnover using the existing
Meta.B timer, with staggered, deterministic per-slot timing. The bundled
`lib.lua` declares `ac.getConditionsSet().rainIntensity`; feed a clamped
rain rate into GPU meta updates. Age out a small subset of stationary drops
and reuse their slots after the existing wait gap; preserve the visor mask,
the current physical diameter distribution and a configurable maximum
creation rate. Guard debug modes and ensure no new drops are emitted when
rain intensity is zero. A fixed-rate diagnostic override can test this
separately from actual weather.

Impact splash is feasible as a later, gated birth event: only sufficiently
large, newly spawned drops can split some of their volume into a few
short-lived radial fragments with stronger initial surface velocity.
Count fragments against the same 512 state slots, check the surface mask,
conserve an approximate volume budget and cap the event rate. First prove
age-based stationary replenishment; then test single impact, fragment
directions, lifetime and GPU/FPS costs before enabling many splashes.

### 117. Isolate and reduce the first trail FPS regression (2026-09-28)

The user sees trails on large and small drops and reports 50 FPS; the
previous reference ranged around 69–75 FPS but was not a controlled paired
measurement at exactly the same camera/time. Keep the verified trail
visibility and improved dark-scene edge. The extra per-drop
`rainDynamicSurfaceSample()` reads three vertices and rebuilds a tangent
frame for the tail, on top of the body lookup and doubled vertex updates.

Default `RAIN_DYNAMIC_DROP_TRAIL_FAST_SURFACE=true` projects the tail from
the body's already-sampled tangent frame, reusing its normal and tangent
vectors; check the signed visor-UV domain first. Setting it false restores
the exact second surface lookup for an image/FPS comparison. A long strip
near a curved visor edge or mask hole can float or cross the border in
fast mode, so inspect visor edges before adopting this approximation.

Default `RAIN_DYNAMIC_DROP_TRAIL_PIXEL_ENABLED=true` can be set false to
keep the same trail CPU lookup, geometry and vertex upload while discarding
trail fragments in the shader. For a paired test at one camera and weather:
record FPS (A) both true, (B) fast true/pixel false, (C) trail false, then
(D) fast false/pixel true only if visual curvature needs comparison. Each
case still reserves two quads per drop. The differences indicate whether
fragment work, CPU trail work or the shared geometry allocation is the
largest factor; the main clean scene shot remains the same. Do not
interpret an unpaired 50 vs 69 FPS observation as an isolated GPU cost.
