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
