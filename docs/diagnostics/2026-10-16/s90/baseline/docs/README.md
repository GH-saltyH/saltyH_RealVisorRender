# RealVisor RainFX — docs index and working rules (2026-10-16)

Start here. This file lists every document in `docs/` with its state, the
current architecture in one screen, and the rules for working on the
project.

## 1. Current architecture (one screen)

- **App.** `realvisor.lua` is a CSP Lua app (CSP 0.3.0-preview; reference
  SDK `lights-patch-v0.3.0-preview634/extension/internal/lua-sdk/ac_apps/lib.lua`).
  - It loads the visor KN5 on a camera-locked node hierarchy.
  - It runs the GPU-persistent rain state machine:
    - `rainStateUpdateParams`: position and velocity (RGBA texels);
    - `rainStateMetaUpdateParams`: radius, mass and lifecycle.
    - Opt-in P1 uses actual volume/SI motion. Opt-in P2 adds physical-area/normal
      birth events and a conserved source/reservoir budget. Opt-in P3 adds spatial
      incident/trail water, paired head loss, evaporation/runoff and physical-height optics;
      supplied 60% water budgets and 3-minute/40-toggle memory observations pass;
      opt-in P4a conserves water with observed comparable FPS, but high Courant fails
      transport time accuracy; s85 diagnoses localized millimetre columns outside
      P4a's regime; s86 integrates opt-in P4b conserved pool-to-P1 return with
      production GPU/Lua/optics gates passed; s87 supplied game water/cost data
      pass with no >1mm columns. Film time accuracy and unified head/field
      motion/optics remain open; view5 compares both in the same UV.
      s88 evaluates offline inertial and long-travel candidates; neither meets
      adoption gates yet. Production remains s87.
      s89 adds view6 to isolate debug channels from scene transmission and a
      positive source-local overlap prototype; physical runtime is still s87.
- **Rain rendering.** `shaders/rainVisorDynamicDrop.hlsl` draws the visor
  rain surface mesh (built from `GLASS_RAINFX`) with `render.mesh` in an
  in-scene stage. The stage is `main.smoke` by user setting
  (`RAIN_DYNAMIC_DROP_DRAW_AT_SMOKE_DEBUG`).
  - Water field: drops, trails, film.
  - Micro pattern, haze, smear.
  - Exact depth pass.
  - New Trail (`rain_trails.lua`): same-frame GPU swept liquid/clearance history;
    4:1 metrics, diameter/mm UI, independent channels. Legacy CPU paths remain
    behind the New Trail toggle.
- **Refraction source.** The geometry shot plus the HDR frame copy, through
  tone mode 3 (frame-first composite; rules in `RAINFX_NEAR_OBJECTS.md`
  §10).
- **Visor stack (scene stack, current work).**
  `shaders/rainVisorLayer.hlsl` draws the KN5 `*_FX` meshes in the same
  callback:
  1. housing (opaque, depth write);
  2. `GLASS_COAT_FX`;
  3. the rain mesh;
  4. `GLASS_EXT_FX` (band) and `GLASS_INT_FX`;
  5. the drop depth pass.

  Output is HDR. See `RAINFX_VISOR_LAYER.md` §17–§20, and §18 for the KN5
  rules.
- **Post overlay.** Archived and off (`RAIN_VISOR_OVERLAY = false`).

## 2. Document index

States:

- **ACTIVE**: current work, read first.
- **REFERENCE**: implemented, describes live code.
- **CLOSED**: investigation finished; result lives elsewhere.
- **ARCHIVED**: the feature still exists in code but is off and not
  developed.
- **REMOVED**: the code was deleted; history only.
- **HISTORY**: chronological log.

| Document | State | Content |
|---|---|---|
| `README.md` | ACTIVE | this index and the working rules |
| `RAINFX_ROADMAP.md` | ACTIVE | R1 (pre-laid GPU drops), R2 (visor scene stack and glass optics), closed list |
| `RAINFX_S89_VIDEO_AND_POSITIVE_REMAP.md` | ACTIVE | film video direction reaction is expected in current preview; view6 blocks debug scene transmission, normal output unchanged; positive source-local overlap GPU arithmetic passes, trajectory/curved support/worst cost/runtime integration pending |
| `RAINFX_S88_FILM_TRANSPORT_CANDIDATES.md` | ACTIVE | offline finite-inertia/momentum and tiled-prefix long-travel GPU candidates: useful numerical gates pass, warm CFL / arbitrary-flow positivity / thin-stock translation fail adoption; no runtime changes |
| `RAINFX_S87_P4B_GAME_REVIEW.md` | ACTIVE | supplied P4b water conservation/internal return and67/67FPS observations pass; no >1mm columns, remaining time/visual gates; actual same-head GPU link proof, same-UV head/film/micro view5, user fabric material preserved |
| `RAINFX_S86_P4B_POOL_RETURN.md` | REFERENCE | opt-in P4b localized pool→P1 return, preserved rain centre, internal ledger, paired donor/field debit and atomic publication; +1 pass/+80KiB at4096, view4; production GPU/Lua/optics/regression gates passed; actual game review follows in s87 |
| `RAINFX_S85_P4_REGIME_AND_POOL_TRANSFER.md` | REFERENCE | same-frame data confirms 45–49% film inventory is CFL-limited; full-coverage/coated peak cells and valid SI units; offline /WX WARP conserved localized-pool-to-head prototype, handoff design/cost; runtime integration follows in s86 |
| `RAINFX_S84_P4_GAME_REVIEW.md` | REFERENCE | supplied P4 water budgets pass and FPS observed comparable; high-C transport-time gate fails; real-mesh unit probes, media review, same-frame16-float thickness/limited-mass/metric diagnostics; physical transport unchanged |
| `RAINFX_S83_P4_FILM_TRANSPORT.md` | REFERENCE | opt-in P4a four-neighbour conserved film transport/runoff, P1 world forces/downward air, manual limiter stats, compensated snapshot sum; +4MiB/one pass; game findings and expanded diagnostics follow in s84 |
| `RAINFX_S82_P3_GAME_REVIEW.md` | REFERENCE | supplied P3 conservation passes (interval error ≤2.043e-5); 3-minute/40-toggle game memory shows no sustained accumulation, 100 reset fixtures; long float32 precision/trail quality remain open, first P4 transport follows in s83 |
| `RAINFX_S81_P3_SPATIAL_WATER_PREVIEW.md` | REFERENCE | first P3 conserved spatial film/micro/trail, paired head loss, wet impact/evaporation/runoff, um optics and manual field budget; initial game findings and limits follow in s82 |
| `RAINFX_S80_P2_GAME_REVIEW_AND_MERGE.md` | REFERENCE | P2 FPS/budget/videos and SI merge correction; corrected 60% stationary/straight game conservation passed (interval error ≤6.10e-6), measured source rates; P3 spatial film/micro/trail next |
| `RAINFX_S79_GPU_PHYSICAL_BIRTH.md` | REFERENCE | opt-in P2 real-area/normal source, virtual impact/shared generation commit, GPU reservoir budget and display compensation; game results and merge correction follow in s80 |
| `RAINFX_S78_BIRTH_DISTRIBUTION_AND_BUDGET.md` | REFERENCE | P1 game result/response-time diagnosis and P2 DSD/flux/impact diagnostic preparation; live GPU birth/event/budget preview follows in s79 |
| `RAINFX_S77_SI_MOTION_PREVIEW.md` | REFERENCE | opt-in P1 persistent SI motion/volume/display separation, single-exit state/meta fix and epoch retirement; WARP/LuaJIT plus game qualitative validation passed, weaving/friction and driving cost still open |
| `RAINFX_S76_SI_CORE_PRIMITIVES.md` | REFERENCE | P1 shared SI GPU functions and /WX WARP invariants; persistent state binding implemented as opt-in s77 preview |
| `RAINFX_S75_WEATHER_INPUTS_AND_UNITS.md` | ACTIVE | P0 independent weather/G/metric panel and SI/contact helpers; installed-source/LuaJIT checks passed, user stationary/acceleration/braking logs confirm G excludes gravity |
| `RAINFX_S74_CORE_IMPLEMENTATION_SCOPE.md` | ACTIVE | implementation branch derived from preserved 0c092e0; core physics/flow/sheet/impact first, Smear deferred and legacy local impact film excluded; documentation only |
| `RAINFX_S73_PHYSICS_WEATHER_REFACTOR_DESIGN.md` | ACTIVE | design only: audited 6 px/mm calibration, volume/SI physics, independent display gain, CSP weather adapter, virtual impact and shared effect state; s74 core-first exclusions incorporated |
| `RAINFX_S72_TRAIL_SAMPLING_AND_DIAMETER.md` | ACTIVE | carried phase, pixel integration/bandlimit, trail derivative floor; model diameter ×3 with compensated thin output, wide sheets, preserved head/micro profile; cost and GPU checks, game verification pending |
| `RAINFX_S71_SMEAR_RED_REGION.md` | ACTIVE | low-G red region restored: class wipe follows G, neutral trails follow visibility, shared class boundaries and persisted Smear tuning; game confirmation pending |
| `RAINFX_S70_TRAIL_VISIBILITY.md` | REFERENCE | diagnosis of weak ordinary-film optics; sampling/model calibration implemented and evaluated in s72 |
| `RAINFX_S69_MOTION_AND_MEMORY.md` | REFERENCE | user confirms G-force conflict and memory leak fixed; scene-ready native mask, accumulating splash/queue fixes and merge allocation reduction |
| `RAINFX_S68_VIEW_AND_CONVEX_TINT.md` | ACTIVE | main-view FX completion/retries, native glass UI callback fix, independent E2/E3 convex tint; automatic-driving game confirmation pending |
| `RAINFX_S67_NEW_TRAIL.md` | ACTIVE | current GPU liquid/wipe history, pending-callback fix, diameter/mm controls, 4096-slot work reduction and offline checks; game verification pending |
| `RAINFX_S66_STARTUP_AND_GLASS_DIAGNOSIS.md` | REFERENCE | missing installed module, measured cold compile stall, async startup, independent glass/test routing and shadow/capture isolation; user FPS/light results in s67 |
| `RAINFX_S62_OUTPUT_AND_COST_FIXES.md` | REFERENCE | user game-output follow-up: warning-free shaders, EXT/E2/E3/micro fixes, cost reductions and verification limits |
| `RAINFX_S63_GLITCH_AND_NATIVE_OCCLUSION.md` | REFERENCE | bounded wipe/trail/splash geometry, physical splash positions, native exterior ownership and additional cost fixes |
| `RAINFX_S64_BOTTLENECK_AIRFLOW_LIGHTING.md` | REFERENCE | reproduced merge CPU bottleneck, cheaper physical transport, corrected downward airflow/live native hook, sunlight shadow policy and engine CPU/GPU timings |
| `RAINFX_S65_LAYER_TRAIL_COST.md` | REFERENCE | incomplete-install correction, live INT/source gate, Rain occlusion, cached smooth smear, physical trail frames, GPU swept wipe and bounded rendering costs |
| `RAINFX_KN5_4_TO_1_MIGRATION.md` | REFERENCE | s61: independent glass UVs, physical Rain geometry, E1/mirror visibility, rebuild and validation |
| `VISOR_CACHED_OPTICS.md` | REFERENCE | cached optics, post-rain source, E1 capture and dated verification |
| `RAINFX_GPU_PRELAID.md` | REFERENCE | R1 GPU pre-laid drops: CPU A/B, tile-binning heads, R1.2 birth-site atlas prototype |
| `RAINFX_IMPACT_FILM.md` | REFERENCE | local impact film, trigger, layer composition and validation |
| `RAINFX_UI.md` | REFERENCE | grouped popup controls, conditional settings, and validation |
| `RELEASE_0.6.0.md` | REFERENCE | accepted RainFX release, performance cleanup and deferred movement work |
| `RAINFX_VISOR_LAYER.md` | ACTIVE | visor stack: V1/V2 overlay phase (archived §1–16), scene stack §17, KN5 rules §18, material editors §19, open items §20 |
| `RAINFX_WATER_FIELD.md` | REFERENCE | the drop renderer: soft-kernel heads, metaball silhouettes, trails, refraction rule; backlog #3 closed |
| `RAINFX_MICRO_PATTERN.md` | REFERENCE | micro drop pattern v2, pop-in, point reads |
| `RAINFX_SMEAR_MASK.md` | REFERENCE | smear (fingerprint) mask v1–v9, texture contract |
| `RAINFX_HAZE.md` | REFERENCE | haze / condensation film |
| `RAINFX_IMPACT_SPLASH.md` | REFERENCE | impact splash v2, birth hold, exact depth pass (§7–§9), car glass vs drops |
| `RAINFX_COALESCENCE.md` | REFERENCE | merge and absorption steering |
| `RAINFX_TRAIL_FLOW.md` | REFERENCE | trail flow, anti-chrome tone, wipe-mask fp16 fix, thin-film lifetime (s34), open "Next" items |
| `RAINFX_TRAIL_REFRACTION.md` | CLOSED | trail and film refraction T1–T6, smear v9 (implemented) |
| `RAINFX_SHOT_TONE.md` | REFERENCE | refraction-source tone; v1/v2 superseded by mode 3 |
| `RAINFX_REFRACTION_SOURCE.md` | CLOSED | how CSP gets clouds; led to mode 3 |
| `RAINFX_STAGE_PROBE.md` | CLOSED | what each render stage contains; mode 3 v3; diagnostic probe |
| `RAINFX_NEAR_OBJECTS.md` | CLOSED | wiper/wheel/KN5 near objects; composite rules summary §10; haze-depth option; F1-camera game issue |
| `RAINFX_VISOR_GLASS.md` | CLOSED | KN5 shimmer, render-pass analysis, DLSS drag (accepted); glass design absorbed by VISOR_LAYER |
| `RAINFX_POST_OVERLAY.md` | ARCHIVED | P0/P1 overlay, HUD lift, resolution |
| `RAINFX_REVIEW_2026-10-02.md` | CLOSED | feature reviews: §1 → R1, §2 done, §3 moved |
| `RAINFX_MICRO_PATTERN_NEXT.md` | CLOSED | requirements, implemented as micro pattern v2 |
| `RAINFX_FLOW_LAYER.md` | REMOVED | flow layer (deleted 2026-10-02) |
| `RAINFX_SPRAY.md` | REMOVED | spray film (deleted 2026-10-02) |
| `RAINFX_PERSISTENT_GPU.md` | HISTORY | long development log of the GPU state machine |
| `RAINFX_PERSISTENT_GPU_TEXEL_IDENTITY_TEST.md` | HISTORY | texel identity / lifecycle writeback tests |
| `RainFXPersistentGPU.md` | HISTORY | original project-goal overview of the GPU simulation |
| `tools/` | REFERENCE | template and prototype scripts (smear v7 template, trail refraction proto) |
| `images/` | REFERENCE | templates and captures (smear mask templates, …) |

## 3. Working rules

### Files and versions

1. **Work on local files.** Preserve user tuning. The user normally commits; commit and integrate only when they explicitly request it (0.6.0 main integration authorised 2026-10-07).
2. **Before every patch:**
   - re-stage `realvisor.lua`, the shaders and the docs, and diff them
     against the last delivered version;
   - **keep the user's tuned values** (they edit the files between
     sessions);
   - patch with exact-match replacements (each anchor must match once).
3. **Deliver** the changed files and write them back to the project folder,
   guarded by the staged modification time. Each delivery is a session step
   `sNN`, named in the docs.

### APIs

4. **Verify every new API** against `lib.lua` / `README.md` of preview634
   before use. `shader-tpl` is closed source. Facts verified so far:
   - `render.mesh` PS_IN fields: `PosH`, `PosC` (camera-relative position),
     `NormalW`, `Tex`, `ApplyFog`. There is **no tangent**.
   - Uniforms are auto-declared from `values`. Every `params` table that
     uses a shader must carry the **same keys**, and every uniform the
     shader reads must be in all of them; otherwise it does not compile.
   - Effect-syntax `SamplerState` blocks are ignored, so samplers behave as
     linear/clamp. Wrap UVs by hand (`frac` + `SampleGrad`) and use `Load()`
     for point reads.
   - In HLSL, statics and functions must be declared **before** their first
     use (s39 bug).
   - `sim.lightDirection` points **from the light into the scene**; use
     `−lightDirection` for "toward the light".
   - `ui.onExclusiveHUD` holds one callback. `render.on` stages:
     `main.track/root.opaque/transparent`, `main.smoke`, `mirror.*`,
     `shadow.root`.

### Docs

5. **Record every important finding** in the topic document:
   - user results go in "User result" sections;
   - causes, decisions, config keys and UI labels, and limits;
   - add a dated section instead of rewriting history.
6. **Keep states current.** When a status changes:
   - update the document's `Status` line (ACTIVE / REFERENCE / CLOSED /
     ARCHIVED / REMOVED / HISTORY);
   - update this index and `RAINFX_ROADMAP.md`.
7. **New topic.** Create `docs/RAINFX_<TOPIC>.md` with a title, a date and a
   Status line. Add it to this index.

### Testing

8. **Isolate the cause first.** Before attributing an artefact to RainFX,
   compare with the app removed or RainFX off at the same track spot
   (`RAINFX_NEAR_OBJECTS.md` §9).
9. **Toggles.** New features come with a toggle and a debug view.
   Diagnostics default to off. Name the reload requirement when a change
   needs one (draw stage, KN5 path).

### KN5

10. **Naming rules** are in `RAINFX_VISOR_LAYER.md` §18:
    - `GLASS_COAT_FX`, `GLASS_EXT_FX`, `GLASS_INT_FX`: custom glass passes;
    - `GLASS_RAINFX`: water target and optional water-only mirror pass;
    - these four originals are dummy alpha-zero sheets, hidden from native colour/shadows;
    - all other native meshes, including `*_MRR`, follow their Visible box in every view.

    Each glass mesh has independent 4:1 UVs. The s61 contract and required rebuild
    order are in `RAINFX_KN5_4_TO_1_MIGRATION.md`; they supersede earlier naming rules.

### Priority

11. **Current priorities** (2026-10-07): RainFX 0.6.0 integrated; E2/E3/E4 accepted at user commit ff085b5. Next is E1. Final RainFX movement refinement remains deferred.

12. **Inner optical layer contract (E1–E7).** All lens effects are camera-side
    of the rain surface. Refraction, blur, brightness and reflected/ghost
    images must include already-rendered drops, trails and water film. Use
    a stable post-rain HDR capture, never the pre-rain scene snapshot or the
    live target being written. Preserve the accepted E2/E3/E4 tuning. Read
    `VISOR_E1_DESIGN.md` before implementing E1.
