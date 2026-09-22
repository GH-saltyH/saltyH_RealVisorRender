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
Not finalized: one consolidated production physics update path, final surface movement/rendering, lifecycle, merge, residue/shrink, boundary handling, and final drop appearance.
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

## 11. Existing procedural baseline
rainDropLayer() remains intentionally available.
It uses hash-based cell placement, random radius, radius-to-mass, candidate spawn normal/force/adhesion, analytic travel, drop rendering and trail rendering.
A previous major bug was that evaluating force from pin.Tex caused one procedural drop to receive different directions across its own pixels, producing a clock-hand/rotation-around-origin appearance. The current procedural code evaluates the trajectory from candidate spawn state instead.

## 12. Important historical fixes
Normal texture path problems were fixed by correcting the application path.
The normal texture is object-space and must be decoded and transformed.
Using saturate(pin.Tex) for the normal lookup caused invalid/black behavior for this visor UV arrangement and was removed.
Actual mesh UV tangent reconstruction was added for the procedural path.

## 13. Coordinate rules
Persistent state position is not directly identical to pin.Tex. State coordinates are normalized and converted to the calibrated visor UV range at render time.
Current calibration is represented by RAIN_GPU_STATE_MESH_U_MIN/U_MAX and MESH_V_MIN/V_MAX.
Changing these values requires checking Debug 4 UV coverage and the measured state grid together.

## 14. Do not mix physics and visualization
RAIN_GPU_STATE_DEBUG_DISPLACEMENT_SCALE and RAIN_GPU_STATE_DEBUG_VELOCITY_SCALE are visualization controls.
They must not be used as substitutes for actual physics parameters.
Debug amplification must never be used to hide an incorrect physics model.

## 15. Development order
Step A: consolidate the already validated normal, tangent, gravity, acceleration, airflow, mass, adhesion, drag, max-speed and integration logic into one persistent physics path.
Step B: render independent persistent drops from state position/radius.
Step C: make surface movement and coordinate/boundary handling robust.
Step D: implement lifecycle: spawn -> attached -> threshold -> flowing -> exit/death -> respawn.
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
