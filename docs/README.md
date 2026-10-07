# RealVisor RainFX — docs index and working rules (2026-10-07)

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
- **Rain rendering.** `shaders/rainVisorDynamicDrop.hlsl` draws the visor
  rain surface mesh (built from `GLASS_EXT_DUMMY`) with `render.mesh` in an
  in-scene stage. The stage is `main.smoke` by user setting
  (`RAIN_DYNAMIC_DROP_DRAW_AT_SMOKE_DEBUG`).
  - Water field: drops, trails, film.
  - Micro pattern, haze, smear.
  - Exact depth pass.
- **Refraction source.** The geometry shot plus the HDR frame copy, through
  tone mode 3 (frame-first composite; rules in `RAINFX_NEAR_OBJECTS.md`
  §10).
- **Visor stack (scene stack, current work).**
  `shaders/rainVisorLayer.hlsl` draws the KN5 `*_OVERLAY` meshes in the same
  callback:
  1. housing (opaque, depth write);
  2. `GLASS_COATING`;
  3. the rain mesh;
  4. `GLASS_EXT` (band) and `GLASS_INT`;
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
    - `*_OVERLAY`: our shaders, hidden in the scene;
    - `*_MIRROR`: mirror-only shape, never touched;
    - stock meshes: follow their Visible box.

    Keep `GLASS_EXT_DUMMY`: it is the rain target.

### Priority

11. **Current priorities** (2026-10-07): RainFX 0.6.0 integrated; E2/E3/E4 accepted at user commit ff085b5. Next is E1. Final RainFX movement refinement remains deferred.

12. **Inner optical layer contract (E1–E7).** All lens effects are camera-side
    of the rain surface. Refraction, blur, brightness and reflected/ghost
    images must include already-rendered drops, trails and water film. Use
    a stable post-rain HDR capture, never the pre-rain scene snapshot or the
    live target being written. Preserve the accepted E2/E3/E4 tuning. Read
    `VISOR_E1_DESIGN.md` before implementing E1.
