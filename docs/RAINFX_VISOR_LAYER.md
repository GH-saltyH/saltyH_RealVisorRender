# RainFX: the whole visor as one overlay layer (plan, 2026-10-03)

Status: **plan**, decided with the user. Nothing is implemented yet.
Supersedes `RAINFX_POST_OVERLAY.md` P3 (KN5 occlusion) and absorbs
`RAINFX_VISOR_GLASS.md` §3.C/§4 (own glass pass) and Roadmap R2.

## 1. Decisions taken (user, 2026-10-03)

- **Post overlay is the render path.**
  - The quality of the transparent areas, drops and film is fine as it is:
    no DLSS, no supersampling, no extra AA work.
  - Conditional AC HUD elements (pit config, damage display, …) that the
    overlay covers are **accepted**. No keep-out zones: those elements
    appear conditionally, and reserving space for them is not acceptable.
- **KN5: the remaining visor parts are rendered like the rain layer.**
  - They go inside the same overlay shot, each with our own shader, and
    with depth deciding front and back.
  - The goal is to keep, and finally own, everything the stock KN5 shows
    in the area it shares with the rain.

## 2. Effects to build (user list)

| # | Effect | Data / idea |
|---|---|---|
| E1 | **Projected strong forward light.** Bright parts of the forward image are refracted onto the visor, as inside a real visor. | camera view × visor normal → gathered forward image; only the strong part (threshold) is projected. Source = final frame. |
| E2 | **Relief of the glass surface.** | pre-baked normal map, fast. |
| E3 | **Optics of the relief zones.** The image is slightly turbid and smeared; at normal borders it tears blurrily in every direction; strong light is likely caught there. | a lens effect driven by the normal map, like a drop: refraction offset from N, mip up at high ∥∇N∥, split sampling across edges (`VISOR_GLASS` §4 "rim tear"). |
| E4 | **Top band.** Simple texture plus a matte surface that blocks a set amount of light. The band lies **outside the inner glass film**, so it does not cover the inner film's gloss. | band texture × transmission; inner-film gloss drawn over it. |
| E5 | **Per-part material and light response** | masks (existing assets). |
| E6 | **Scratches** highlighted by light | the scratch pattern texture exists. Anisotropic highlight × light (`VISOR_GLASS` §4). |
| E7 | **Interior objects projected onto the glass**: strong when light comes from outside in, plus blur | baked image in visor UV first; a mirrored GeometryShot later (`VISOR_GLASS` §4 option (ii)). |

### Meshes

The drop mesh alone is not enough. It covers a reduced area, and E1–E7
need the full glass. The KN5 meshes are reused, from `MATERIAL_EDITORS`,
profile `visor_lando_2025Champion_maxquality.kn5`.

| Group | Meshes | Treatment |
|---|---|---|
| Glass, 3 layers | `GLASS_INT` (inner), `GLASS_EXT` / `GLASS_EXT_DUMMY` (rain zone), `GLASS_COATING`, `GLASS_COATING_REFL` (coating, scratches) | Our glass shader. **Most effects on the inner layer**, as the user specified. |
| Band | `GLASS_EXT_BAND` | E4 |
| Housing | `BODY_FRAME`, `BODY_FRAME_FLIP`, `BODY_INT_BORDER_GLASSLINE`, `BODY_INT_FABRIC` (alcantara) | Diffuse + detail + normal map from the existing assets; simple lighting. |

## 3. Architecture (inside the existing P1 overlay shot)

### Draw order in the overlay GeometryShot

All passes use one depth buffer (the shot is created `withDepth`).

1. **Housing, opaque, depth write.** Frame, fabric and border write colour
   with alpha 1 and depth. Anything behind them is hidden by depth, which
   is the KN5-in-front problem solved by construction.
2. **Glass layers, back to front** (from the eye: farthest first). Depth
   test is read-only against the housing.
   1. coating;
   2. the rain-zone glass, with our existing drop/film/haze shader on its
      own mesh;
   3. band;
   4. inner glass.

   The exact order of coating vs rain zone must be confirmed from the mesh
   positions (V0).
3. **Composite as before:** one full-screen draw in `onExclusiveHUD`.

### Blending inside the shot

P1 used Opaque because there was a single layer. With several transparent
layers:

- Clear to (0,0,0,0).
- Every glass shader outputs **premultiplied** colour and is drawn with
  `BlendPremultiplied`.
- The composite becomes `BlendPremultiplied` as well.
- The drop shader gets a `gDynamicDropPremulOut` switch (LDR overlay only).

### In-scene KN5

- The visor KN5 meshes are hidden from the normal scene pass, using the
  same `setVisible` trick as the drop mesh. They are drawn only in the
  overlay.
- Per mesh group there is a toggle: overlay, scene or both, so each part can
  be compared against stock while it is being built.

### Light and source data

All of this is already available:

- final frame plus mips (overlay source);
- `sim.lightDirection` / light colour (already passed for the micro relief);
- the fog/ambient tone (`gFogTone`, LDR estimate);
- the visor normal from `NormalW` (verified PS_IN, `VISOR_GLASS` §6).

### Textures

- From disk (staged assets), passed by file path to `render.mesh`.
- Where needed, the KN5's own slots are read with
  `SceneReference:getTextureSlotFilename` / `getTextureSlotDetails`
  (lib.lua).

## 4. Check of earlier open items

| Item | Source | Decision |
|---|---|---|
| P3 KN5 occlusion | POST_OVERLAY | **Superseded** by §3 step 1 (housing depth in the overlay). |
| P4 rim AA / supersampling | POST_OVERLAY | **Dropped.** The user sees no quality problem. |
| HUD keep-out zones | POST_OVERLAY | **Dropped** (conditional HUD). |
| R2 visor glass pass | ROADMAP, VISOR_GLASS §3.C/§4 | **Absorbed**: E2, E3, E6, E7 and the specular AA idea. |
| Visor KN5 shimmer under DLSS | REVIEW §3, VISOR_GLASS §1–2 | **Solved structurally** once the KN5 is drawn in the overlay (no DLSS). |
| Drops shaking with the background | VISOR_GLASS §8 | **Solved** by the overlay (P1). |
| Haze over the wipers / glass | NEAR_OBJECTS §2a | **Solved** by the overlay. |
| Missing wheel/bonnet in the F1 camera | NEAR_OBJECTS §9 | Game issue, out of scope. |
| R1 pre-laid GPU drops | ROADMAP, REVIEW §1 | **Kept**, after the visor layer, and independent of it. |
| In-scene path (tone mode 3, frame priority, near trust) | SHOT_TONE, NEAR_OBJECTS | Kept as fallback while the overlay is off. Not developed further. |

## 5. Phases

| Phase | Content | Done when |
|---|---|---|
| **V0 inventory** | Log every visor KN5 mesh once: name, material, texture slots (`getTextureSlotDetails`), `dumpShaderReplacements()`, bounding position (distance from the eye) for the layer order. Plus the user's asset list (band, scratch, normal maps). | Mesh/texture table in this doc. |
| **V1 skeleton** | Housing (flat diffuse) and glass layers (plain tint) drawn in the overlay with depth and premultiplied blending. The KN5 is hidden in the scene. Per-group toggle. | Front/back order correct everywhere, including band and frame over the drops. |
| V2 housing material | Diffuse + detail + normal, simple light (E5 for the housing). | Matches stock closely. |
| V3 glass base | E2 relief normal, E3 lens and tear, E4 band transmission. | |
| V4 light effects | E1 strong-light projection, E6 scratches, E7 interior projection (baked). | |
| later | R1 pre-laid GPU drops. | |

**Next step: V0.** It is a one-time log plus a small UI table, and it
decides the mesh order and which assets are already in the KN5.

## 6. Mesh plan fixed by the user (2026-10-03)

The order runs from **outermost to innermost**. "Two-sided" means the mesh
must render from both sides.

1. **`GLASS_COATING`** (two-sided): E1, E5.
   - Optical effects first. The fine material look comes later.
   - E5 is dropped if it is independent enough of the other reflections
     (low priority).
2. **Rain mesh.** Same geometry as `GLASS_EXT`, different UV mapping.
3. **`GLASS_EXT`** (two-sided): E4, E6.
   - **Top band:** `texture/GLASS/GLASS_INT_EXT_4k_txDIFF.dds`. Where
     alpha = 1, the band glows white in light or blocks the forward image.
   - **Scratches:** same texture, inside 0 < alpha < 1. They can be split
     into their own texture if needed.
   - **Surface normal:** `texture/GLASS/GLASS_INT_EXT_4k_txNormal.dds`.
   - **Light response:** `texture/GLASS/GLASS_INT_EXT_4k_txMAPS.dds`. Its
     RGBA layout is ours to define.
4. **`GLASS_INT`** (two-sided): E2, E3, E7.
   - **Relief normal:** `GLASS_INT_EXT_4k_txNormal.dds`.
   - **Relief vs other-zone optical border:** `GLASS_INT_EXT_4k_txMAPS.dds`.
     The channels can be redefined.
5. **`BODY_FRAME`** (two-sided). Low priority, barely visible.
   - Diffuse `BODY_FRAME/BODY_FRAME_1K_txDiff.dds`.
   - Normal `BODY_FRAME_1K_txNormal.dds`.
   - A metallic map can be added if needed.
6. **`BODY_INT_BORDER_GLASSLINE`** (single-sided).
   - Diffuse: solid dark grey / strong black.
   - Normal `BODY_FRAME/BODY_INT_BORDER_GLASSLINE_2K_txNormal.dds`.
   - Glossy-rubber highlight.
7. **`BODY_INT_FABRIC`** (single-sided): soft, fuzzy alcantara.
   - Diffuse `BODY_FRAME/BODY_INT_FABRIC_2K_txDiff.dds`.
   - Normal `BODY_INT_FABRIC_4K_txNormal.dds`.
   - Gloss `BODY_INT_FABRIC_2K_txMaps.dds`.

Not drawn, but hidden in the scene while the layer is on:

- `BODY_FRAME_FLIP` (it **is** drawn, as part of the frame);
- `GLASS_EXT_BAND`, `GLASS_COATING_REFL`, `GLASS_EXT_DUMMY`.

## 7. V1 skeleton (s43, `RAIN_VISOR_LAYER = false` by default)

**Requires** `RAIN_VISOR_OVERLAY`.

### When on

- **Scene.** Every visor KN5 mesh in `MATERIAL_EDITORS` is hidden in the
  scene, re-applied every HUD frame. The overlay source (final frame) then
  holds no visor either. That also cleans the refraction source.
- **Drawn inside the overlay GeometryShot** (one depth buffer):
  1. **Housing, opaque, depth write:** `BODY_FRAME`, `BODY_FRAME_FLIP`
     (cull none), `BODY_INT_BORDER_GLASSLINE` (flat grey),
     `BODY_INT_FABRIC` (cull back; the UI can flip it). Diffuse × (frame-mean
     ambient + sun · N·L).
  2. **Glass, back to front, `BlendPremultiplied`, depth read-only:**
     1. `GLASS_COATING` (faint film);
     2. the **rain** mesh (drop shader with `gDynamicDropPremulOut = 1`);
     3. `GLASS_EXT` (band where diffuse alpha is about 1, opacity
        `BAND_OPACITY`; faint film elsewhere);
     4. `GLASS_INT` (faint film).
- **Composite:** `BlendPremultiplied`.
- **Visibility.** A mesh whose editor "Visible" is off is not drawn.
- **Restore.** Everything is restored when the layer is switched off, and on
  unload.

### Shader

`shaders/rainVisorLayer.hlsl`, a new file:

- `gLayerKind` 0 housing / 1 GLASS_EXT / 2 glass film.
- Hand-wrapped UV with `SampleGrad`.
- Two-sided normal.

### Test

- **Order:** frame, fabric and the glass line must lie over the drops at
  the edges.
- **Band:** the top band must cover the drops and the scene.
- **Culling:** no part may be missing or inside-out. If one is, use the
  cull flip.
- Then compare the overall look with the stock KN5, toggling the layer.

## 8. V1 result and V2 housing materials (s44)

### V1 result (user, 2026-10-03)

1. Everything is drawn in the intended order.
2. With `two = false`, the two-sided meshes overdrew the single-sided ones.
   All housing parts are now `two = true`: the user's fix, adopted in the
   code. The cost difference is negligible.
3. The KN5 tab's Visible toggle stays in sync with show/hide.
4. `GLASS_EXT` and the rain mesh share exactly the same position, and the
   order separates them correctly. The top band (alpha 1) covers both the
   drops and the scene.
5. All glass layers show a faint film.

### V2 (s44): housing materials in `rainVisorLayer.hlsl`, kind 0

- **Normal maps.**
  - PS_IN has no tangent, so a derivative cotangent frame is built (Schüler)
    from `PosC` and the unwrapped UV.
  - z is reconstructed from xy, so RGB and BC5 maps both work.
  - Strength per material. Global green flip (`NORMAL_FLIP_G`) in case the
    relief looks inverted.
- **Light** (LDR):
  - ambient = frame mean × `AMBIENT`;
  - sun = light colour normalised × `SUN`. There is no shadow information:
    the gain stands in for the helmet occlusion.
- **Materials.**

  | `gLayerMat` | Meshes | Model | Defaults |
  |---|---|---|---|
  | 0 FRAME | `BODY_FRAME(_FLIP)` | Lambert + Blinn + Fresnel environment; diffuse `BODY_FRAME_1K_txDiff`, normal `..._txNormal` | spec 0.25, gloss 0.5 |
  | 1 RUBBER | `BODY_INT_BORDER_GLASSLINE` | Grey diffuse (`BORDER_GREY`), normal `_2K_txNormal`, sharp highlight plus Fresnel environment: glossy rubber | spec 0.8, gloss 0.85 |
  | 2 FABRIC | `BODY_INT_FABRIC` | Alcantara: wrapped diffuse, grazing sheen `(1−N·V)^p`, fuzzy normal, weak specular; diffuse, normal and maps from the listed files | normal 1.5, sheen 0.35, power 3, spec 0.1, gloss 0.6 |

- **txMaps.** Read with the AC `ksPerPixelMultiMap` convention: R = spec
  mask, G = gloss, B = reflection. **Assumption:** confirm the fabric
  `txMaps` channels.
- **Glass kinds 1 and 2.** Unchanged from V1. V3 is next: E2, E3 and E4 on
  `GLASS_INT` / `GLASS_EXT`.

## 9. s44 result and s45 light fix

### User result (free camera, 2026-10-03)

- **Fabric `txMaps`.** The R = spec, G = gloss, B = reflection rule is
  confirmed. The user left the spec mask as it is.
- **Light direction is reversed.** Parts get brighter when they face away
  from the sun.
- **Sky tone glow.** Against the sky, the parts glow strongly in the sky
  tone. Expected: the stock model looks **dark** when backlit, and its own
  tone brightens naturally when lit from the front.
- **User tuning kept:** rubber spec 2.0, gloss 0.32; fabric normal 1.29,
  sheen 0.91, sheen power 1.0.

### Causes

1. **Light direction.** `sim.lightDirection` points from the light into the
   scene, which is the CSP shader convention (`dot(N, -ksLightDirection)`).
   s44 used it as "toward light".
2. **Ambient.** s44's ambient was the **mean colour of the final frame**.
   Viewed against a bright blue sky, that mean is the sky, so every part
   was lit with sky-blue at near sky brightness, even when backlit.

### Fix (s45)

- **Light.** `RAIN_VISOR_LAYER_LIGHT_FLIP = true` (default): the light
  vector is `−sim.lightDirection`. The toggle stays for verification.
- **Hemisphere ambient.**
  - **Chroma:** a lerp from `horizonColor` to `skyColor` by the normal's up
    component. Each colour is luminance-normalised in Lua and desaturated
    toward grey by `AMBIENT_SAT` (0.35).
  - **Brightness:** the **luminance only** of the frame mean × `AMBIENT`
    (0.35, was 0.9).
  - **Occlusion:** a cheap up/down term: downward faces × `AMBIENT_FLOOR`
    (0.35).
  - Housing uses the shaded normal; glass uses the geometric normal.
- **UI.** Ambient gain, sky chroma, floor, light flip.

## 10. s45 result and s46 helmet shadow

### User result (2026-10-03)

- Reflection direction is now correct.
- The light-source colour cast is gone, so each part shows its own colour.
- **New issue:** with the visor opening pointed at the ground, the inside
  lights up brightly, as if lit from behind. Looking at the sun, the inside
  is correctly dark.
- **User tuning kept:** frame normal 1.76, spec 1.03, gloss 0.72.

### Cause

There is no shadowing:

- With the sun behind the camera, the interior surfaces facing the eye get
  N·L > 0, even though the helmet shell blocks that light.
- Facing the sun, the same surfaces have N·L < 0, so they are dark. That is
  correct, but only by accident.

### Fix (s46, interior parts only: `BODY_INT_FABRIC`, `BODY_INT_BORDER_GLASSLINE`)

- **Sun visibility.** The sun can reach the interior only through the visor
  opening, which means from in front of the head:
  `vis = smoothstep(SHADOW_COS_LO −0.05, SHADOW_COS_HI 0.35, dot(toLight, cameraLook))`.
  It multiplies the sun term. The camera is head-locked, so the visor
  faces the camera look.
- **Interior ambient.** Ambient inside × `INTERIOR_AMBIENT` (0.6).
- **Scope.** The frame and the glass band are outside the shell and stay
  unshadowed.
- Computed in Lua per item. No shader change.
- **UI.** Toggle, the two cos bounds, interior ambient.

## 11. s47: scattered light inside the helmet

**User (2026-10-03):** with only direct light, the interior is far too dark.
Scattered light also reaches it, so a hard-coded correction was requested.

**Model.** For interior parts only, a non-directional term is added to the
ambient in the shader (`gLayerBounce` + horizon chroma ×
`gLayerBounceFrame` × frame luminance):

- **Sun bounce.** Sun light bounced inside the shell and off the face:
  `sun × SUN_BOUNCE (0.22) × (BOUNCE_BASE 0.45 + 0.55 × sunVis)`. Even with
  the sun blocked, 45 % of the bounce remains.
- **Opening.** Scene light entering through the visor opening:
  `frame-mean luminance × OPENING (0.30)`, tinted by the horizon chroma.

`INTERIOR_AMBIENT` goes from 0.6 to 1.0. Exterior parts get 0, so they are
unchanged.

**UI.** Sun bounce, bounce kept in shadow, light through opening.

## 12. s48: neutral interior bounce, visor self-shadow, scene shadow

**User (2026-10-03).**

- The s47 bounce gives brightness, but it takes on the sky tone.
- Can the visor cast its own shadows?
- It must also receive the basic scene shadows.

### 12.1 Interior light without the sky tone

`RAIN_VISOR_LAYER_INTERIOR_SKY_CHROMA = 0`. For interior parts the
hemisphere and opening light are now **neutral grey**. The value lerps back
toward the sky/horizon chroma.

### 12.2 Visor self-shadow (`RAIN_VISOR_LAYER_SELF_SHADOW`)

**Shot.** An orthographic depth `GeometryShot` from the light every frame:

- extent 0.6 m, depth range 1.2 m, 1024², centred 5 cm in front of the eye;
- custom callback with the casters: all housing parts plus the `GLASS_EXT`
  top band (`txDIFF.a > 0.96`);
- layer shader with `gLayerDepthPass = 1`; the glass film does not cast.

**Receivers.** Housing and band:

- world = `PosC + cameraPosition` (+ normal bias), × `gLayerShadowVP`;
- the shot's depth is read with `Load` and compared with bias, 3×3 PCF;
- the sun term is multiplied by the result.

**Unverified conventions** (toggles in the UI):

- matrix order/transposition (`SHADOW_MATRIX_MODE` 0 = V·P, 1 = (V·P)ᵀ,
  2 = P·V, 3 = (P·V)ᵀ);
- reversed depth.

Shadow debug shows lit white and shadow black, and the depth thumbnail is
in the UI. **To verify:** find the mode in which the frame's shadow lands
where expected.

### 12.3 Scene shadow (`RAIN_VISOR_LAYER_SCENE_SHADOW`)

The base shadow is a **soft CPU ray test from the head toward the light**,
with 5 rays (a centre and ±5 cm offsets). The rays start 12 cm from the eye,
past the visor.

- **Car:** `ac.findNodes('carRoot:<focused>'):raycast(render.createRay(...))`
  covers the roll hoop, body and driver.
- **Track:** `physics.raycastTrack` against the track physics mesh
  (bridges, buildings, pit roof). It is pcall'd, in case physics access is
  missing.
- Runs every second frame, smoothed (8/s).
- Scales the sun of every visor part, and the interior sun bounce.
- `car.ambientOcclusion` (track VAO, tunnels) × `SCENE_AO` scales the
  ambient.
- The UI shows visibility, AO and ray cost in ms.

**Limits.**

- The shadow is one value for the whole visor. A shadow edge cannot cross
  the visor partially, except through the self-shadow.
- Trees and visual-only track objects are not in the physics mesh.

## 13. s49: scene-shadow probe (trees, poles, any CSP shadow)

**User (2026-10-03).** The stock KN5 in the scene received dynamic tree and
roadside-tree shadows, which gave a strong sense of presence. The overlay
does not. Can it be handled like the old scene path?

**Why the overlay cannot sample shadows directly.**

- `render.mesh` shaders have no documented shadow-map access. The template
  is closed, and lib.lua exposes no shadow function.
- The overlay runs after the scene in any case.

**Idea: let CSP shade a probe in the scene, then read it back.**

1. **A second instance of the visor KN5**, loaded once with
   `axisRollNode:loadKN5` (same file, same transform node), with
   `ensureUniqueMaterials()`. Only the housing meshes stay visible: frame,
   frame flip, glass line, fabric. The probe material:
   - `txDiffuse` white and `txNormal` flat;
   - `ksDiffuse = PROBE_ALBEDO` (0.05, dark, so it barely shows in the
     final frame under our opaque housing);
   - `ksAmbient = 0`, `ksSpecular = 0`, `ksEmissive = 0`;
   - fresnel 0 (pcall);
   - `setShadows(false)`, so the probe does not cast.

   CSP lights it normally, **with its shadow maps** (trees, poles,
   buildings, car).
2. **Copy.** In the drop callback (in-scene stage, smoke by user setting),
   `dynamic::hdr` plus linear depth are copied to a half-res fp16 canvas.
3. **Read.** In the overlay layer shader, at the same screen UV:

   `shadow = lum(probe) / (albedo × lum(sim.lightColor) × N·L × PROBE_GAIN)`

   - N·L < `PROBE_MIN_NL` (0.12): no signal, 1.
   - Probe depth > 0.35 m: not the probe (jitter or edge), 1.
   - The result multiplies the sun with the self-shadow. While the probe is
     active, the housing ignores the ray scene shadow; glass and band keep
     the rays.

**Calibration.** `PROBE_GAIN` maps `sim.lightColor` to the shader's sun
intensity, if CSP scales it. With probe debug (white lit, black shadow),
set the gain so that fully lit parts are just white.

**Limits.**

- The probe adds a very dark copy of the housing to the final frame. It is
  hidden under our opaque housing, but the haze blur near the frame edges
  can pick it up slightly.
- Extra CSP lighting (headlights, emissive, SSGI) leaks into the ratio.
- At night the sun signal is weak, so the probe is effectively 1.

## 14. s50: the scene-shadow probe is the only shadow source

The user asked for all earlier shadow methods to be removed, to avoid
conflicts with the probe.

- **Removed (code, config and UI) from s48:**
  - the visor self-shadow (light-space ortho GeometryShot, matrix modes,
    PCF, depth pass, `txLayerShadow`, `gLayerShadow*`, `gLayerDepthPass`);
  - the ray scene shadow (car / track raycasts, `sceneVis`);
  - the track VAO ambient-occlusion factor.
- **s46 helmet shadow** (sun-forward cone for interior parts): the code is
  kept, but `RAIN_VISOR_LAYER_HELMET_SHADOW = false` by default. It can be
  re-enabled in the UI if the interior lights up again with the opening
  pointed at the ground.
- **Kept:**
  - the s47 interior bounce (`sunVis` = 1 while the helmet shadow is off);
  - the s48 neutral interior chroma;
  - the s49 probe.
- **Shader.** `shadow = rainLayerProbeShadow()` only.
  `gLayerProbeDebug` shows it on housing parts (white lit, black shadow).

## 15. s51: requirements recorded, fabric spec, mirror exception

### 15.1 REQUIREMENT for V3/V4 glass optics (user, 2026-10-03)

Every light-driven glass effect **must be multiplied by the scene shadow**
(the s49 probe, or whatever replaces it). This covers:

- E1 strong forward-light projection;
- E3 light caught at relief borders;
- E4 band glow;
- E6 scratch highlights;
- E7 interior projection when lit from outside.

The probe currently covers only housing pixels. The glass needs its own
shadow signal, for example a probe for `GLASS_EXT` / `GLASS_INT` with the
same material trick, or the nearest housing value. **Decide this in V3.**

### 15.2 Fabric spec (user: `FABRIC_SPEC` had no visible effect)

**Cause.** The fabric branch scaled the Blinn term by 0.15, and the gloss
(0.6 × txMaps G) gives a broad, low lobe. Together the slider was nearly
inert.

**Fix.**

- The ×0.15 is removed.
- A **lit-zone lift** is added for direct light only, so it is shadowed by
  the probe: `specMask × FABRIC_SPEC × N·L × FABRIC_LIT_LIFT (0.6)`.
- Sunlit patches now read crisper than the shaded fabric.
- The spec slider goes up to 2.

**How to bake the fabric `txMaps` for a crisper lit zone** (R = spec mask,
G = gloss, B = reflection):

- **R, spec mask.** This is the main lever. Make it high on the **fibre
  tips** and low in the pores, for example from the fabric normal or height
  map: the cavity inverted, plus a fine grain noise. Use a mean around 0.35
  to 0.5, with tips up to 0.8 to 0.9 and pores near 0.1. The lift and
  highlight then sparkle on the tips only.
- **G, gloss.** Keep it low and fairly uniform, 0.2 to 0.35. Alcantara is a
  broad, soft lobe; high gloss gives a plastic look. Here gloss =
  `FABRIC_GLOSS × G`.
- **B, reflection.** Barely used by the fabric branch, so leave it low.
- **Contrast.** The contrast of R is what reads as "crisp". Raise its local
  contrast rather than its mean.

### 15.3 Interior mirror exception

The user observed that the mirror showed our model in black and white: the
s49 probe, which is visible in the scene.

- **Overlay-drawn meshes.** In the scene pass they are hidden as before.
  In the **mirror pass** (`render.on('mirror.track.opaque')`) they are made
  visible again with their **stock materials** (coloured), if their Visible
  box is on, and the probe is hidden. `main.track.opaque` switches back:
  stock hidden, probe visible.
  `RAIN_VISOR_LAYER_MIRROR_STOCK = true`.
- **Meshes the overlay does not draw** (`GLASS_EXT_BAND`,
  `GLASS_COATING_REFL`, `GLASS_EXT_DUMMY`) now **always follow their Visible
  box** in the scene. They are no longer force-hidden.
- **Assumption.** Each pass calls its `track.opaque` stage before the visor
  is drawn. The stage probe showed the KN5 visor appears from
  `root.opaque` on.
