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
