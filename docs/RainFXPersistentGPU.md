# RainFX Persistent GPU Droplet Simulation\n\n## 1. Project goal\n\nRainFX is not intended to be a research-grade fluid simulation.\n\nThe target is a performance-friendly, visually convincing visor droplet simulation whose motion follows the important physical cues of real droplets:\n- droplets spawn at varied positions and sizes;\n- droplets have mass;\n- surface adhesion/tension resists motion;\n- external force must exceed adhesion before sustained flow begins;\n- motion follows the visor surface rather than a screen-space vector;\n- acceleration changes velocity over time;\n- drag damps motion;\n- maximum speed prevents runaway motion;\n- droplets may eventually merge and change mass/radius;\n- flowing droplets may leave residue and shrink;\n- lifecycle is persistent rather than a purely per-fragment animation.\n\nThe acceptance criterion is plausible visible droplet behavior, not exact fluid-mechanics reconstruction.\nDo not introduce mathematically elaborate models when a simpler model produces the required visual behavior reliably and cheaply.\n\n## 2. Physics model agreed during planning\n\nA droplet is an object with state, not a decoration attached to the currently rendered fragment.\n\nConceptual state:\n- normalized surface position;\n- surface velocity;\n- radius;\n- mass;\n- adhesion threshold;\n- lifecycle state;\n- eventually: history/residue information.\n\nCore behavior:\n1. External forces include vehicle acceleration/deceleration and gravity.\n2. The force is projected onto the visor surface.\n3. A droplet remains attached while effective tangential force is below its adhesion threshold.\n4. Once the threshold is exceeded, only the excess force drives flow acceleration.\n5. Velocity accumulates over time.\n6. Drag damps velocity.\n7. Velocity is capped by a maximum speed.\n8. Position is integrated from velocity.\n9. Surface normal changes the resulting movement direction.\n10. Larger/heavier droplets have lower effective adhesion and therefore flow more readily.\n11. Overlap/merge will later increase radius and mass.\n12. Flow may later leave residue and reduce radius.\n\nThe model intentionally emphasizes acceleration and external force rather than simply assigning a constant travel speed.\n\n## 3. Architecture\n\nThe persistent GPU simulation uses ping-pong state textures.\nEach state texel represents one independent droplet.\n\nState texture:\n- R/G: normalized persistent position\n- B/A: normalized surface velocity\n\nMeta texture:\n- R: radius\n- G: mass\n- B: reserved/lifecycle time during current implementation\n- A: validity/auxiliary state\n\nTwo A/B pairs are alternated every update.\nState A -> physics -> State B -> physics -> State A ...\n\nThe renderer reads the persistent state rather than generating a new trajectory per screen fragment.\nThe procedural rainDropLayer() remains in the shader as a comparison/baseline path and must not be removed merely because the persistent path exists.\n\n## 4. Coordinate rules\n## 4.1 Visor boundary mask\n\nThe persistent lifecycle now reserves a dedicated binary visor boundary mask texture:\n\n- Lua path: `texture/GLASS_EXT_RAINFX_boundaryMask_2K.dds`\n- Intended channel: red channel only\n- Value 1: valid droplet surface\n- Value 0: outside/invalid area\n- UV space: must match `GLASS_EXT_RAINFX_surfaceNormal_objectSpace_2K.dds`\n\nThe mask is deliberately separate from the surface-normal texture. The normal texture describes force direction; the boundary mask describes where a droplet is allowed to exist. The persistent state and meta passes both sample this mask. Initial and respawn positions use deterministic rejection sampling so new droplets are placed inside the valid region. Lifecycle exit checks the midpoint and predicted position against the mask to reduce tunnelling through a narrow boundary.\n\nThe Lua render/update bindings are wired to `txRainBoundaryMask`. The authoritative lifecycle/death test should use this mask instead of assuming that the visor is a rectangular normalized region.\n\nFor the first supplied mask, keep it binary (0/1) and use the same DDS resolution/UV layout as the normal map. Do not add antialiased edge values yet.\n\n\nPersistent state position is not directly equal to pin.Tex.\nState position is normalized and converted to the calibrated visor mesh UV range at render/normal lookup time.\n\nCurrent calibration:\n- RAIN_GPU_STATE_MESH_U_MIN = 0.30\n- RAIN_GPU_STATE_MESH_U_MAX = 0.70\n- RAIN_GPU_STATE_MESH_V_MIN = -0.713\n- RAIN_GPU_STATE_MESH_V_MAX = -0.302\n\nThe equivalent shader mapping is:\n- meshU = lerp(U_MIN, U_MAX, statePosition.x)\n- meshV = lerp(V_MIN, V_MAX, statePosition.y)\n\nChanging calibration values requires checking both Debug 4 UV coverage and the measured state grid.\nNever assume normalized state coordinates and mesh UV coordinates are interchangeable.\n\n## 5. Surface normal and movement direction\n\nThe supplied visor normal texture is object-space.\nDecode: encoded = normal * 0.5 + 0.5; decoded = encoded * 2 - 1.\nThen transform object-space normal into world space.\n\nImportant historical finding:\nUsing saturate(pin.Tex) for this normal lookup caused invalid/black behavior for this visor UV arrangement. The saturate operation was removed and must not be reintroduced.\n\nThe persistent physics currently constructs a local tangent frame by projecting object-space X onto the decoded surface normal and deriving the second axis with a cross product.\nThis is not guaranteed to be the exact mesh UV tangent frame.\n\nDebug 37 demonstrated that the persistent tangent and actual mesh UV tangent can diverge, especially near visor edges and under Pitch/Yaw changes.\n\nHowever, the actual non-debug droplet trail currently shows plausible, curvature-aware movement. Debug 33 also demonstrated correct curvature-dependent force projection. Therefore:\n\n> UV tangent equality is not itself a success criterion.\n\nThe project's success criterion is believable surface flow.\nDo not replace the current tangent construction solely to make Debug 37 overlap if doing so risks degrading the observed real droplet motion.\n\nA separate tangent/bitangent source remains an optional future architecture only if real rendered droplet behavior demonstrates a directional problem.\n\n## 6. Validated observations\n\n### Normal / force\n- The object-space normal texture is being sampled successfully.\n- Texture path issues were fixed by correcting the texture path separator.\n- The normal texture itself is not the fundamental cause of the persistent directional behavior.\n- Debug 33 showed force projection responding to visor curvature.\n- Debug 32 showed airflow input responding as expected to forward acceleration, speed, and lateral/turn motion.\n\n### Persistent state\n- A/B ping-pong remains stable.\n- No sudden state jumps were observed during long testing.\n- Independent state entries preserve distinct positions.\n- Debug 36 showed large > medium > small displacement; measurable position-dependent differences; edge differences somewhat larger than center differences; and no sudden position jumps after extended testing.\n\n### Radius / mass / adhesion\nThe 3x3 L/M/S test grid uses approximately:\n- L radius: 0.115\n- M radius: 0.0735\n- S radius: 0.032\n\nMass is currently approximated from normalized radius:\nmass = lerp(1, 9, radius01^2)\n\nAdhesion is approximately:\nadhesion = adhesionBase / sqrt(mass)\n\nDebug 28 and Debug 36 demonstrated behavior consistent with the intended model: larger/heavier drops move more readily because their effective adhesion threshold is lower.\n\n### Actual renderer\nDebug 19 renders independent persistent drops from state position/radius. Its observed direction is consistent with Debug 36.\n\nThe non-debug trail is especially important: despite the very small absolute displacement, the visible trail direction changes in a visually plausible way with the visor surface and vehicle motion.\n\nThis observation is currently treated as stronger evidence for project success than exact agreement with an abstract tangent-frame diagnostic.\n\n## 7. Visualization is not physics\n\nThese are visualization-only controls:\n- RAIN_GPU_STATE_DEBUG_DISPLACEMENT_SCALE\n- RAIN_GPU_STATE_DEBUG_VELOCITY_SCALE\n\nThey must never be used to compensate for an incorrect physical model.\nLikewise, trail length must not be artificially increased to hide insufficient physical displacement.\nIf physical movement is too small, fix the physical integration/model or its unit conversion. Do not multiply the rendered result merely to make it look fast.\n\n## 8. Current physics parameters\n\nCurrent baseline values:\n- RAIN_FLOW_ACCELERATION = 0.020\n- RAIN_FLOW_DRAG = 7.0\n- RAIN_FLOW_MAX_SPEED = 0.035\n- RAIN_AIR_DRAG_SCALE = 0.000050\n- RAIN_ACCEL_GAIN = 0.000024\n- RAIN_ADHESION_MIN = 0.65\n- RAIN_ADHESION_MAX = 2.20\n- RAIN_GRAVITY = 0.35\n- RAIN_FORCE_SCALE = 100000.0\n- RAIN_GPU_STATE_COUNT = 256\n- RAIN_GPU_STATE_UV_SCALE = 18.0\n- persistent air drag is currently disabled.\n\nAir drag must remain disabled until a correct relative-velocity model is integrated. Airflow input is not itself a drag force.\n\n## 9. Debug history that must not be misinterpreted\n\nDebug 25 is not a currently trusted restored test. It had previously been removed/renamed while Debug 36 was created. Do not treat the current Debug 25 as equivalent to the historical accumulated-displacement diagnostic without independently restoring and validating it.\n\nDebug 32 = airflow input.\nDebug 33 = airflow/force projection respecting surface normal.\nDebug 36 = measured persistent 3x3 L/M/S state grid.\nDebug 37 = comparison between actual mesh UV tangent reconstruction and the current persistent tangent construction.\n\nDebug 37 is a diagnostic of tangent-frame equivalence, not a direct verdict on whether the final droplet flow looks physically plausible.\n\n## 10. Development order\n\n### A. Physics consolidation — completed\nValidated normal, tangent, gravity, acceleration, mass, adhesion, drag, maximum-speed and integration logic were consolidated into one persistent physics path.\n\n### B. Persistent droplet rendering — completed\nDebug 19 renders independent persistent droplets from state position and radius.\n\n### C. Surface movement and coordinate/boundary robustness — current

First C-stage correction: persistent position integration no longer uses `frac(position)`. Wraparound would teleport a droplet from one visor edge to the opposite edge. The current pre-lifecycle behavior clamps normalized position to [0, 1]. Final edge exit/death behavior belongs to the lifecycle stage.\nGoals:\n- keep normalized state position and calibrated mesh UV mapping consistent;\n- ensure position integration is stable;\n- define robust surface/boundary behavior;\n- remove temporary wraparound behavior when lifecycle handling replaces it;\n- preserve the currently observed plausible surface direction.\n\n### D. Lifecycle — next\nImplement:\nspawn -> attached -> threshold -> flowing -> exit/death -> respawn\n\nA droplet should have a real persistent identity and should not remain indefinitely pinned to an invalid/out-of-surface coordinate.\n\n### E. Merge\nWhen droplets overlap:\n- combine mass;\n- increase radius;\n- recompute adhesion;\n- combine/recompute velocity in a stable way;\n- allow the resulting larger drop to cross its flow threshold more readily.\n\n### F. Residue / shrink\nA flowing droplet may lose a small amount of material over time and leave a visually plausible residue.\nThis is explicitly lower priority than correct persistent movement and lifecycle.\n\n## 11. Current critical problem\n\nThe most clearly observed remaining problem is not direction.\n\nThe current physical displacement is extremely small.\n\nObserved behavior:\n- actual point movement is barely visible;\n- large/medium/small ordering remains measurable;\n- trails can appear much longer than the actual physical displacement;\n- therefore trail presentation must not be used to infer physical speed.\n\nThe next engineering focus is to make persistent physical position/velocity behavior correct and inspectable before tuning visual trail presentation. The first physics correction in this stage is complete: flow acceleration is no longer divided by the procedural `RAIN_GPU_STATE_UV_SCALE`. That scale controls pattern density, not physical state coordinates. Coupling them artificially made a denser procedural pattern produce slower physical droplets.\nDo not solve this by blindly multiplying visual displacement.\n\n## 12. C-stage physics correction: coordinate-domain separation

The persistent state uses normalized surface coordinates. `RAIN_GPU_STATE_UV_SCALE` is a procedural pattern-density value and must not be used as a conversion factor for physical state acceleration.

The flow acceleration term is therefore now:

`acceleration = excessForce * RAIN_FLOW_ACCELERATION`

rather than dividing by `RAIN_GPU_STATE_UV_SCALE`.

This is a physics correction, not a visualization multiplier. It removes an architectural coupling that could make the same physics behave differently solely because the procedural rain pattern density changed.

This change should be validated in-game for displacement, radius/mass ordering, adhesion behavior, and stability before any further parameter tuning.

## 13. What does not need further investigation right now\n\nDo not repeatedly pursue large-scale artificial experiments merely to prove exact tangent equivalence.\nA theoretical experiment requiring an effectively flat, enormous reference surface and hundreds of repeated identical turns is not an efficient validation method for this project's actual goal.\n\nThe project does not require research-lab fluid dynamics.\n\nThe acceptance criterion is:\n\n> Does the droplet move, accelerate, adhere, bend with the visor surface, respond to vehicle motion, and eventually flow in a way that looks physically believable at game-view scale?\n\nIf the answer is yes, preserve the model unless a concrete visual/physical failure is observed.\n\n## 14. Engineering rules\n\n1. Preserve validated behavior when refactoring.\n2. Do not mix visualization scale with physics.\n3. Do not silently change coordinate conventions.\n4. Do not reintroduce saturate(pin.Tex) for the visor normal lookup.\n5. Do not enable air drag before relative droplet/air velocity is modeled.\n6. Do not replace the current tangent solely because a diagnostic frame differs from mesh UV tangent.\n7. Keep the procedural rainDropLayer() comparison path available.\n8. Treat each state texel as an independent droplet identity.\n9. Prefer simple stable approximations over unnecessary fluid-dynamics complexity.\n10. When a change affects physical behavior, record the reason and the observed result.\n11. Record important debugging discoveries in this document so later refactors do not repeat discarded hypotheses.\n12. Physics and rendering must remain separable.\n\n## 15. Current repository state\n\nRepository: GH-saltyH/saltyH_RealVisorRender\nActive branch: feature-RainFXPersistentGPU\nLatest implementation commits before this documentation update:
- da55059612eb30a55b7aaba16d6ab82fdba4a86e — make C3 boundary handling explicit in state integration
- 72731558888385fb3373b2223320b163f941dcc4 — document C3 state mode
- 82d61c643675b7dff1994d97d1eae4bbcdf7944a — enable C3 validation debug mode
- aa1a2651c3004d1868750086a33022b4804136f5 — C3 lifecycle debug renderer
- e7e97b7895507b3b1e236a336f249ce23c709c9f — persistent C3 boundary/death/respawn implementation\n\nRelevant files:\n- realvisor.lua\n- shaders/rainVisorScreen.hlsl\n- texture/GLASS_EXT_RAINFX_surfaceNormal_objectSpace_2K.dds\n- texture/drops.dds\n\nRecent architectural commits:\n- 389c02b6ba35f04f8c103c730377335f82bf6445 — persistent physics consolidation\n- e527bfe1cd95d6b13a167fb40250d45f2c4e5a70 — calibrated persistent droplet renderer\n- af2ed00beb1250204f18fdbe5e7b4b982295a1 — Debug 37 tangent-frame comparison\n\n## 17. 2026-09-23 validation result: STATE_MODE 4 / Debug 36

Current in-game observation:
- L/M/S drops remain persistent during long tests and do not respawn at their original point.
- Physical travel is still considerably slower than real visor droplet motion.
- In the current 3x3 test, larger drops were observed moving less than smaller drops.

This is not yet accepted as a radius-only causal result. The current adhesion function uses a per-state hashed adhesion base, so Debug 36 mixes surface force, position, radius/mass, and adhesion variation. Do not change the physics or add a visual speed multiplier from this observation alone.

## 18. Validation plan

### C1 — Persistent movement baseline — PASS
Use STATE_MODE 4 + Debug 36.
Observed long-duration result:
- no teleport or sudden state jump;
- A/B ping-pong remained stable;
- drops did not return to their initial spawn positions;
- no opposite-edge wrapping or later pop at another mesh location was observed;
- movement remained consistent through different visor corners/tracks.

C1 is therefore closed. Do not alter physics or trail presentation to “improve” C1.

### C2 — Radius / mass / adhesion isolation — IMPLEMENTED
Use STATE_MODE 5 + Debug 38.

C2 deliberately removes the variables that made Debug 36 ambiguous:
- three states share the same normalized physical spawn position;
- all three use the same fixed tangent-force vector;
- all three use the same fixed adhesion base;
- only radius/mass differs;
- per-state hashed adhesion is bypassed;
- visual left/center/right offsets in Debug 38 are visualization-only and do not affect physics.

Initial controlled values:
- S radius = 0.032, mass = 1.0;
- M radius = 0.0735, mass = 3.0;
- L radius = 0.115, mass = 9.0;
- adhesion base = 1.20;
- controlled tangent force = (1.50, 0.00).

With the current adhesion model:
adhesion = adhesionBase / sqrt(mass)

the expected thresholds are approximately:
- S: 1.20;
- M: 0.693;
- L: 0.400.

Force 1.50 therefore places all three above threshold while preserving a clear excess-force difference. This is a controlled test of the current model, not a final parameter decision.

Debug 38 shows actual persistent displacement from the common physical origin and the current velocity direction/magnitude. S/M/L are separated only for visibility.

Observed controlled test on 2026-09-23:
- 60 s: red/blue ≈ 4 cm, yellow ≈ 2.5 cm;
- 120 s: red/blue ≈ 8.3 cm, yellow ≈ 5.3 cm;
- 240 s: red/blue ≈ 18.5 cm, yellow ≈ 11 cm;
- 300 s: red/blue ≈ 19.4 cm, yellow ≈ 14.7 cm;
- 360 s: red/blue ≈ 19.4 cm, yellow ≈ 17.1 cm;
- 420 s: red/blue ≈ 19.4 cm, yellow ≈ 19.4 cm;
- 450 s: red/blue ≈ 19.4 cm, yellow ≈ 19.4 cm.

The leading states stopped at the same approximately 19.4 cm monitor distance before the slower state caught up. This is consistent with the temporary normalized-position clamp/boundary, so the observation is treated as evidence that the mass/adhesion ordering is functioning, not as evidence that the physical speed reaches a hard 19.4 cm limit.

### C3 — Boundary behavior — IMPLEMENTED

The temporary clamp remains only as a numerical guard for an alive state. Explicit lifecycle ownership now handles the visor edge:

spawn -> alive -> boundary exit -> dead/waiting -> respawn pending -> new spawn

Implementation details:
- no `frac(position)` wraparound;
- normalized state coordinates remain the physics domain;
- Meta.A lifecycle flag: 0 = dead/waiting, 1 = alive, 2 = respawn pending;
- Meta.B remains age;
- Meta.C is a deterministic respawn-cycle counter used to decorrelate repeated respawns;
- boundary detection uses the predicted persistent position and a configurable normalized margin;
- a dead drop is hidden by the renderer while waiting for its respawn gap;
- respawn position and radius are deterministically re-hashed per state and respawn cycle;
- unrelated state entries continue through the same A/B ping-pong path.

Initial C3 parameters:
- boundary margin = 0.005 normalized state units;
- respawn gap = 0.15..0.75 seconds;
- STATE_MODE = 6;
- Debug = 39.

This is an architectural lifecycle implementation, not yet a visual acceptance result. The next in-game test must verify that drops actually disappear at the visor boundary, remain absent briefly, and return at a different valid location without cross-edge teleportation.

### D1 — Lifecycle
Implement spawn -> attached -> threshold -> flowing -> exit/death -> respawn. Verify that each drop keeps its identity until death and respawn does not disturb unrelated state.

### D2 — Respawn distribution
Validate long-run position/size distribution for visible patterns. Deterministic hashing is acceptable if the visual distribution is sufficiently uncorrelated.

### E1 — Merge
After lifecycle stability: overlap detection -> combine mass/radius -> recompute adhesion -> conservatively combine velocity -> retire one identity.

### F1 — Residue / shrink
Last priority. Validate slow, plausible material loss without using residue to hide incorrect movement.

## 18.1 C3 lifecycle validation speed preset

Because the current physical persistent droplet motion is intentionally much slower than the time scale needed to visually validate lifecycle behavior, C3 now has an isolated validation-speed preset.

Default C3 validation values:
- RAIN_GPU_STATE_C3_TEST_SPEED = true
- RAIN_GPU_STATE_C3_FLOW_ACCELERATION = 0.20
- RAIN_GPU_STATE_C3_DRAG = 3.0
- RAIN_GPU_STATE_C3_MAX_SPEED = 0.15

These values are used only when persistent lifecycle handling is active. They do not overwrite or redefine the final RainFX physics parameters.

The purpose of this preset is strictly to make the following observable within a short in-game test:
1. a persistent drop reaches the normalized visor boundary;
2. the drop becomes hidden/dead;
3. it remains absent for the configured respawn gap;
4. the same state identity respawns at a different hashed position;
5. unrelated persistent drops continue without teleporting.

The C3 speed preset must not be used to judge final real-world droplet speed, mass/adhesion tuning, airflow behavior, or visual trail length. After lifecycle validation passes, disable the preset and return to the baseline physics before testing the next physical subsystem.

## 19. Stage gate rule

Do not change multiple physical concepts at once. C movement must pass before lifecycle, lifecycle before merge, merge before residue. Visual trail length must never compensate for insufficient physical displacement.

The long-duration persistent test is now a major validation advantage because cumulative drift, clamping, and identity errors remain observable instead of being hidden by spawn reset.

## 16. Decision record\n\nThe project has passed the initial physics-prototyping stage.\n\nThe current priority is architectural completion:\npersistent state -> physically plausible movement -> robust surface/boundary handling -> lifecycle -> merge -> residue\n\nThe definition of success is visual/physical plausibility at game-view scale, not exact reconstruction of a fluid solver.\n\nWhen evidence conflicts, prefer direct observation of the actual droplet behavior over a diagnostic that only proves equality to an intermediate mathematical representation.\n

## 19. 2026-09-23 C3 lifecycle boundary test preparation

The previous Debug 41 observation must not be interpreted as proof that a droplet was permanently removed when it briefly became red. A moving droplet can cross the predicted boundary and then return inward after braking or a force-direction change. Therefore the red marker is only a per-frame boundary decision diagnostic.

A stationary test also showed that a newly spawned droplet whose radius overlaps the visor boundary can appear yellow at the edge. This confirms that center-position lifecycle validation and radius-aware occupancy are separate concerns. Radius-aware boundary handling is intentionally deferred until the persistent lifecycle transition itself is verified.

For the next C3 test, the temporary normalized-state clamp in rainStateUpdatePhysics() has been removed from both the normal and C2-isolation paths. A live state is therefore allowed to cross normalized 0..1 coordinates instead of being pinned to the rectangular state box. The boundary mask remains authoritative for lifecycle exit.

The primary acceptance sequence for this test is:

spawn inside valid mask -> move toward boundary -> observe boundary/red decision -> verify whether the state actually becomes dead -> wait for respawn gap -> observe a new droplet appearing at a new valid mask position.

Do not infer death from the red marker alone. In particular, observe whether a red-marked droplet can later reverse direction and return to the valid surface.

This test does not change physics parameters, mask coordinates, calibration, radius-aware boundary rules, trail rendering, or merge behavior.


## 20. 2026-09-23 C3 boundary sampler domain fix

The persistent boundary-mask helper now explicitly rejects normalized state positions outside [0, 1] before converting them to visor mesh UVs and sampling the DDS mask.

Reason:
- samLinearRain uses CLAMP addressing;
- an out-of-domain persistent state could therefore be sampled at the texture edge instead of being treated as outside;
- this could prevent the lifecycle exit condition from becoming true and make an escaping state appear to continue elsewhere.

The change is intentionally limited to rainStateBoundaryMask().

No changes were made to:
- physics force/acceleration;
- drag or max speed;
- boundary mask texture;
- mesh UV calibration;
- radius/mass/adhesion;
- trail rendering;
- merge/residue logic.

Next validation remains:
1. accelerate a persistent drop toward an actual mask boundary;
2. verify it can leave the normalized state domain;
3. verify lifecycle transitions to dead/waiting rather than bouncing/pinning;
4. observe the respawn gap;
5. verify the same state reappears at a different valid mask position.

Debug 41 remains a diagnostic only: red means the current frame predicts a boundary crossing; it is not itself proof of permanent death.


## 21. 2026-09-23 single-drop position probe

The next diagnostic isolates position-dependent behavior from multi-drop interaction.

### Purpose

Use exactly one persistent droplet and keep the existing Debug 41 mask interpretation:

- white = current droplet position is inside the boundary mask;
- yellow = current droplet position is outside the boundary mask;
- red = the current frame predicts a boundary crossing.

The probe answers two questions independently:

1. At multiple manually selected positions inside the real visor region, does the droplet receive a locally consistent movement direction?
2. Does the boundary-mask decision coincide with the actual visible visor surface boundary rather than an artificial rectangular state boundary?

### Implementation

STATE_MODE = 7 allocates exactly one persistent state texel.

The UI exposes:

- SINGLE_DROP_X: normalized persistent-state X, 0..1
- SINGLE_DROP_Y: normalized persistent-state Y, 0..1

Changing either value reinitializes the single state on the next simulation frame with zero velocity. This makes the UI position an actual test spawn point rather than a per-frame position override, so the droplet can immediately resume normal persistent physics from that location.

The probe uses a fixed medium drop:

- radius = 0.0735
- mass = 3.0

Radius/mass variation is intentionally removed from this test.

Lifecycle respawn is disabled for STATE_MODE = 7. Once the state leaves the valid mask, it is allowed to remain outside so Debug 41 can directly show the yellow invalid state instead of replacing it with a new randomized respawn. This keeps the test focused on position and boundary mapping.

### Test procedure

Keep RAIN_DEBUG = 41.

For each test point:

1. Set SINGLE_DROP_X/Y to a position clearly inside the visible visor.
2. Let the single drop move under the normal persistent force model.
3. Observe the movement direction over time.
4. Repeat at left, center, right, upper, and lower portions of the valid visor area.
5. Move the UI position close to the visually observed boundary and compare the yellow transition with the actual image boundary.
6. Repeat the same points under the same straight acceleration/braking input.

Interpretation:

- If the same external acceleration produces a stable local direction at each manually selected point, the position-to-surface-force path is behaving consistently.
- If the direction suddenly rotates, stalls, or points toward an artificial common center only at certain positions, the position-dependent normal/tangent reconstruction becomes the primary suspect.
- If yellow appears substantially inside the visible visor or remains white substantially outside it, the state-to-mesh-UV mapping or boundary-mask calibration is incorrect.
- A red marker remains only a predicted crossing diagnostic; in this mode the absence of lifecycle respawn makes yellow directly useful for inspecting the mask boundary.

This test deliberately does not modify drag, mass/adhesion, merge, residue, or the normal-map asset.


## 22. 2026-09-25 signed visor-V coordinate audit and Stage 7A test environment

The project-wide persistent-state coordinate contract is:

- U: 0 = left, 1 = right.
- V: -1 = top, 0 = bottom.
- visor center: (0.5, -0.5).
- increasing V therefore means moving downward on the visor.

This contract is a physical/state-space rule, not merely a debug-display convention.

### 22.1 Audit result

The following paths were checked:

1. Persistent state integration:
   - State.RG is already raw visor UV.
   - Position integration remains `position + velocity * dt`.
   - No Y sign inversion is required here.

2. Direct C2 gravity validation:
   - Mode 8/9 uses `float2(0, +gRainStateGravity)`.
   - This is correct for the signed visor-V contract: positive V is downward.
   - Debug 50 therefore represented the expected vertical direction.

3. World gravity path:
   - Physical gravity remains world-space `float3(0, -gRainGravity, 0)`.
   - This sign is correct in the AC world coordinate system and must not be changed merely because visor V uses a different sign convention.
   - The world force is converted to signed visor UV through the surface tangent frame.

4. Surface tangent projection:
   - `rainSurfaceBasisWorld()` reconstructs tangent V directly from the mesh's dP/dv.
   - The previous handedness correction in `rainProjectForceToUVWorld()` could negate tangent V after that reconstruction.
   - That correction has been removed. The function now preserves the actual mesh-V direction and keeps only the intentionally existing U mirror.
   - This is the important correction for the suspected inversion between the older surface-normal tests and the Mode 9 direct-C2 test.

5. Debug 38:
   - Its diagnostic origin was `(0.5, 0.5)`, which violated the signed visor-V contract.
   - It is now `(0.5, -0.5)`.
   - The visual offset remains diagnostic-only.

6. Debug 45:
   - The lower-half State.V encoding previously used `-position.y`, which visually inverted the signed V axis.
   - It now uses `position.y + 1`, so top V=-1 maps to 0 and bottom V=0 maps to 1.
   - This is display encoding only; State.RG physics was not changed.

7. Debug 4:
   - The UV coverage green channel was also changed to encode increasing V directly from top to bottom instead of visually reversing it.
   - No physics value is modified by this diagnostic.

The remaining uses of negative V are intentional coordinate-domain constructions, such as random spawn generation `-hash()` and the fixed center `(0.5,-0.5)`. They are not movement-direction inversions.

### 22.2 New Stage 7A environment: physical surface-normal + gravity

A new persistent state mode was added:

- STATE_MODE = 10: physical 9-drop surface-normal + gravity validation.
- Uses the same nine fixed physical-reference droplets as Debug 50.
- Keeps the calibrated diameters/masses unchanged.
- Uses the normal-map + mesh-derived UV tangent path instead of C2 direct tangent gravity.
- Uses `ac.getSim().gravity` as the physical gravity source.
- Uses the existing physical size-dependent maximum-speed model.
- Vehicle acceleration can be isolated by setting `RAIN_TEST_ACCEL_ENABLED = false`.
- Drag is independently disabled by `RAIN_GPU_STATE_SURFACE_GRAVITY_TEST_DRAG = 0.0`.
- The normal persistent physics path is therefore:

`world gravity -> surface normal/tangent projection -> adhesion -> flow acceleration -> max speed -> position integration`

No airflow is included.

The existing CSP API reference confirms `ac.getSim()` is the simulation-state reference used by CSP Lua; the project already uses its `gravity` field in this branch. citeturn2search3

### 22.3 Stage 7A acceptance procedure

Use:

- STATE_MODE = 10
- RAIN_DEBUG = 50
- RAIN_TEST_ACCEL_ENABLED = false
- RAIN_GPU_STATE_SURFACE_GRAVITY_TEST_DRAG = 0
- C2 gravity multiplier is irrelevant in this mode.
- Keep the established physical gravity gain unchanged.

Test in a stationary vehicle.

Observe, in order:

1. Do drops remain stationary below their individual adhesion threshold?
2. Which drops begin flowing first?
3. After flow begins, do they move toward the physical bottom direction rather than toward the visor top?
4. Does each drop follow its local surface curvature instead of sharing one screen-space direction?
5. Does increasing/decreasing visor pitch alter the projected path consistently with the surface normal?
6. Does speed eventually stop increasing because of the size-dependent MaxSpeed rather than an artificial direction reversal?
7. Do 0.5/0.95/1.5/2.0/2.5/4.0/6.0 mm drops retain the previously accepted relative ordering?

Do not tune the gravity gain during the first run. The first acceptance target is direction and surface-following consistency.

### 22.4 Expected diagnostic interpretation

The key comparison is now:

- Mode 9 / Debug 50: direct C2 gravity in signed tangent-state coordinates. This is the direction reference.
- Mode 10 / Debug 50: the same physical droplets, but gravity must pass through the real surface-normal/tangent projection first.

Therefore:

- If Mode 9 flows downward and Mode 10 flows upward, the remaining problem is in the world-gravity -> mesh tangent projection path.
- If both flow downward but Mode 10 differs locally across the visor, that difference is expected and is the actual curvature response under test.
- If Mode 10 has the correct direction but no movement, inspect the projected tangent force versus adhesion before changing acceleration.
- If direction is correct but speed keeps increasing indefinitely, inspect MaxSpeed activation before adding drag.
- Do not change the established gravity magnitude, droplet dimensions, or size exponent to compensate for a sign error.

### 22.5 Next physical integration gates

After Stage 7A passes:

1. Stage 7B/vehicle-force gate:
   - re-enable `RAIN_TEST_ACCEL_ENABLED`;
   - keep airflow and drag disabled;
   - compare gravity-only against gravity + vehicle acceleration;
   - verify acceleration is projected through the same local tangent frame and does not reverse the signed V convention.

2. Stage 7C/drag:
   - implement velocity-relative drag;
   - validate that drag changes speed and direction response without becoming an additional arbitrary movement direction.

3. Airflow:
   - combine relative air velocity with the verified external-force pipeline;
   - keep airflow separate until its force model is independently validated.

The physical subsystem must therefore be integrated one force at a time:

`gravity -> vehicle acceleration -> drag -> airflow`

with the signed visor-V contract preserved at every stage.
