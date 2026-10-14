# Visor glass: shimmer under DLSS, and how to take over its render pass (2026-10-02)

Status (2026-10-05): **CLOSED / ABSORBED.**
- §1–§2 (layer/specular diagnosis): superseded by §6 (render-pass problem).
- §3.C / §4 (own glass pass, glass shader design E-list): **absorbed by
  `RAINFX_VISOR_LAYER.md`** (scene stack, V3/V4).
- §7 (shimmer inside our mesh from the T3 redraw bug): **fixed, closed**.
- §8 (drops dragged by DLSS reprojection): **accepted, won't fix**; the post
  overlay proposed there was built and **archived**
  (`RAINFX_POST_OVERLAY.md`).
- Stock-KN5 shimmer under DLSS: re-evaluate with the scene stack (our own
  glass shaders replace the stacked transparent KN5 layers).

Original status: exploration. Test switches T1–T3 are in the code.

## 1. Facts so far

**Visor glass meshes.** From `MATERIAL_EDITORS` in `realvisor.lua`, these
are stacked transparent layers about 3 cm from the eye:

| Mesh | Material | Role |
|---|---|---|
| `GLASS_INT` | `mtGLASS_INT` | inner face |
| `GLASS_EXT` | `mtGLASS_EXT` | outer face |
| `GLASS_EXT_BAND` | `mtGLASS_EXT_BAND` | tinted top band |
| `GLASS_COATING` | `mtGLASS_COATING` | coating |
| `GLASS_COATING_REFL` | `mtGLASS_COATING_REFL` | reflective coating |
| `GLASS_EXT_DUMMY` | — | rain target. Our surface mesh is built from it. |

**Tests that failed (user, 2026-10-02).** Both were set on the whole visor
KN5:

- `visor:setMotionStencil(1)` ("reduced TAA");
- `visor:setDepthMode(render.DepthMode.Normal)`.

**What this tells us.**

- The CSP motion stencil weights CSP's own TAA. Whether DLSS sees it is not
  documented in lib.lua, and the result suggests it does not.
- Depth on a transparent layer does not give DLSS a reactive or
  transparency mask either.
- So the shimmer is most likely one of two things:
  - **(a)** specular aliasing: tiny highlights from the coatings' sharp
    reflection on a strongly curved, thin, near surface. This flickers even
    without DLSS, and DLSS amplifies it.
  - **(b)** temporal reprojection of up to five transparent layers with the
    motion of the scene behind them.

## 2. Diagnosis to run first (cheap, decides the path)

1. **Isolate the layer.** Use the KN5 tab "Visible" toggles. Hide one glass
   layer at a time, starting with `GLASS_COATING_REFL`, then
   `GLASS_COATING`, then `GLASS_EXT_BAND`. Note which one removes the
   shimmer.
2. **Separate (a) from (b).** Compare DLSS with TAA and with AA off.
   - If it also flickers with AA off, it is (a), specular aliasing.
   - If it only appears with DLSS or TAA, it is (b).
3. **Try "Extra TAA".** `RAIN_VISOR_MOTION_STENCIL = 0.5` on the shimmering
   layer only, not on the whole KN5. It is a cheap check that is still open.
4. **Dump the material.** `editor.targetMesh:dumpShaderReplacements()`
   (lib.lua 10413) on the guilty mesh, logged once. It shows the shader name
   and its properties (specular exponent, fresnel, reflection), which we
   need for §3.A.

## 3. Options, cheapest first

All the APIs below are checked in `lib.lua`:

- `ac.SceneReference`: `setMaterialProperty` (9883), `setMaterialTexture`
  (9919), `ensureUniqueMaterials` (9925), `setVisible` (10109),
  `setTransparent`, `setBlendMode`, `setDepthMode`, `setMotionStencil`
  (10157), `dumpShaderReplacements` (10413), `applyShaderReplacements`
  (10559);
- `render.mesh` with `{mesh = ac.SceneReference, transform = 'original'}`
  (16469).

### A. Fix the material (if the cause is (a))

- Call `ensureUniqueMaterials()`, then `setMaterialProperty()` on the guilty
  layer. Lower the specular exponent and the sharp reflection, or raise the
  roughness through the CSP shader-replacement props.
- `applyShaderReplacements(ini)` can switch the shader or set CSP extra
  props, and `dumpShaderReplacements()` tells us what is there.
- Cost: none.
- Limit: the look is stock CSP, so it cannot give the optics in §4.

### B. Merge the layers

- Hide `GLASS_COATING` and `GLASS_COATING_REFL`, and fold their look into
  `GLASS_EXT`, either by material props or by the next option.
- Fewer transparent layers means less temporal instability.

### C. Own render pass for the glass (recommended if A and B are not enough)

This is the same mechanism our drop mesh already uses:

1. Keep the glass meshes hidden in the normal scene pass:
   `setVisible(false)`.
2. In our `render.on` callback, before the drop draw:
   `setVisible(true, false)`, then
   `render.mesh({mesh = glassRef, transform = 'original', shader = …})`,
   then `setVisible(false)`.
3. Best variant: merge it into the existing visor surface draw. Our surface
   mesh has the same shape and UV as `GLASS_EXT_DUMMY`, so glass and rain
   become one shader and one transparent layer. That gives:
   - the lowest cost;
   - no ordering problems between glass and drops;
   - our own depth pass, so the glass writes stable near depth. A
     head-locked depth reprojects cleanly.
4. **Specular anti-aliasing is in our hands.** Use Toksvig or Kaplanyan
   style roughness widening, with `roughness² += k × (|ddx N|² + |ddy N|²)`,
   and mip-filtered normal and scratch maps. This removes (a) at the source.

**`PS_IN` fields: verified (§6).** `shader-tpl` is compiled and not
shipped, so the fields were read from CSP's own Lua sources in
`lights-patch-v0.3.0-preview634`.

## 4. Glass shader design for option C (the user's spec)

All terms are in visor UV unless noted. Light is
`sim.lightDirection` (`ac.StateSim` field, already passed as `gDynamicDropMicroLightWorld`) × `sim.lightColor` intensity, plus the weather fog colour as
ambient. That is the data we already pass for the micro relief.

| Element | Data | Rule |
|---|---|---|
| Scratches revealed by light | scratch tangent map (RG = direction, B = depth/mask) | Anisotropic highlight `pow(1 - |dot(T, H)|, n)` × sun. Invisible without direct light, and sharper with stronger light. |
| Local refraction and relief | pre-made normal map (`txVisorNormal`) | Scene offset `N.xy × REFR_PX`. A low-frequency waviness of the shield. |
| Convex rim zone | rim mask (baked from curvature, or painted) | Blur mip up, stronger refraction, and **tear**: on each side of the edge line, sample with opposite offsets along the edge normal, so the image splits left and right. |
| Flat zone, bent reflection | flat mask = 1 - rim mask | Reflect the view about N and warp the forward shot, mirrored. Weight = Fresnel × light intensity. The mip falls (sharper) as the light gets brighter, and the reflection only appears inside an angle window. |
| Interior reflection (visor bottom, nose) | (i) baked image in visor UV, shown by incoming light; or (ii) a real `ac.GeometryShot` of a head or nose mesh from a mirrored camera, blurred | Start with (i), which costs one tap. (ii) is the "real" option but costs one more shot per frame. It can be updated at a low rate. |
| Tint, band, coating | the existing textures (`setMaterialTexture` / staged files) | A multiply tint, with a band gradient at the top. |

Compositing order inside the merged shader, top first:

1. rain (water field, film, micro, haze, facets);
2. glass reflection and scratches;
3. glass refraction and tint.

Rain sits on the outer face, and its refraction already samples the forward
shot. The interior reflection belongs to the inner face, so it goes under
the rain.

## 5. Recommended order

1. Run §2.1 and §2.2 to find the guilty layer and the cause.
2. If the cause is (a), try §3.A on that layer.
3. If the shimmer stays, or we want the §4 optics anyway, build §3.C merged
   into the surface draw:
   1. first refraction, tint and specular AA;
   2. then the rim tear;
   3. then the reflection and scratches;
   4. then the interior reflection.

## 6. Update (user, 2026-10-02): this is a render-pass problem

### Facts

- The test was made with **only one layer visible**, and it still shimmers.
  So it is not overlap.
- **Every** mesh of the KN5 shimmers under DLSS, whatever its ksEditor
  shader, even a plain diffuse-only one. So it is not specular aliasing of
  the coatings.
- Our `render.mesh` drops on the same node do **not** shimmer.

This rules out §1 (a) and (b) as the main cause. What all KN5 meshes share,
and our `render.mesh` draws do not, is the scene path. That path includes
the **per-node motion vectors**.

### Main hypothesis: wrong motion vectors on a camera-locked hierarchy

From lib.lua (preview634), `ac.SceneReference:clearMotion()`: "CSP keeps
track of previous world position of each node to do its motion blur."

- DLSS reprojects history with those vectors. A camera-locked object is
  correct only if `prevWorld × prevViewProj == curWorld × curViewProj`.
- The visor chain is written in `script.update` from
  `ac.getCameraPosition()` / `getCameraForward()` / `getCameraUp()`. The
  chain is cameraAnchor (a bounding-sphere node under carsRoot) → cameraRoot
  → offset → motion → scale → axis pitch/yaw/roll → KN5.
- The NeckFX camera (`RealVisorCameras/cockpit.lua`) sets the neck in its
  own `script.update`. If the app runs before the camera script, or CSP
  samples the previous transform at another point of the frame, the visor
  gets a one-frame mismatch. Its motion vectors then carry part of the
  camera motion, and DLSS smears and "wobbles" every pixel of it. TAA is
  hit less, because it is more conservative.
- `render.mesh` draws evidently do not take this per-node history (no
  shimmer on our drops). That points straight at the fix: draw through our
  pass.

### Test switches (realvisor.lua, UI: Trail flow → "DLSS shimmer tests")

Turn `RAIN_VISOR_MOTION_STENCIL` back to -1 first, so only one thing changes
at a time.

| Switch | What it does | Reading |
|---|---|---|
| T1 `RAIN_VISOR_MOTION_TEST_CLEAR` | `clearMotion()` on the 9 nodes of the chain every frame, after the transform update. | If the shimmer *changes* (better, or a different smear), the per-node motion is the lever. If nothing changes, CSP does not use that history for these meshes. |
| T2 `RAIN_VISOR_MOTION_TEST_LATE` | Re-applies the camera-locked transform in `render.on('main.track.opaque')`, after all scripts. With T1 on, motion is also cleared there. | If it gets better, it was a one-frame lag. Keep it, and move the transform update to the render callback for good. |
| T3 `RAIN_VISOR_REDRAW_TEST_MESH = 'BODY_FRAME'` (UI checkbox) | Hides `BODY_FRAME` in the scene pass and draws it ourselves with `render.mesh` (`transform 'original'`, flat lit test shader, opaque, depth Normal) in `main.track.opaque`. | If our BODY_FRAME is stable while its neighbours shimmer, the KN5 render path is proven to be the cause, and §3.C is the fix for every mesh. |

**Extra check.** Pause in a replay with a still camera. If the visor is
stable when nothing moves and shimmers only while the head or car moves,
that confirms the motion-vector cause.

### `render.mesh` PS_IN, verified in CSP sources (preview634)

| Field or helper | Seen in |
|---|---|
| `pin.PosH`, `pin.Tex` | our shader |
| `pin.NormalW` (world normal) | CspDebug.lua 468/1062, revenant/mode.lua 592 |
| `pin.PosC` (camera-relative world position, `posW = pin.PosC + gCameraPosition`) | rally/mode.lua 247, CspDebug.lua 1062 |
| `pin.ApplyFog(float4)`, `pin.FogAlphaMultiplier()` | rally, revenant |
| Globals `gCameraPosition`, `gWhiteRefPoint`, sampler `samLinearBorder0`, define `USE_LINEAR_COLOR_SPACE` | rally, CspDebug |

No tangent was seen. A normal map therefore needs a cotangent frame built
from `ddx`/`ddy` of `PosC` and `Tex` (Schüler 2006), which is cheap and
standard, or a baked tangent texture.

### Consequence for §3.C

If T3 confirms the cause, the visor parts move to our pass, one per
material group:

1. glass, merged with the rain surface draw (§3.C.3);
2. the opaque parts (frame, fabric, rubber), with a simple lit shader:
   diffuse texture passed through `textures = {}`. KN5 textures are usually embedded, so either export them next to the app or try `getTextureSlotFilename()` first (lib.lua; check what it returns for embedded textures). Then
   `NormalW` lighting with `sim.lightDirection` / `sim.lightColor` and
   ambient.

The opaque parts are lower priority, as the user decided, but they shimmer
too, so they will need it eventually.

## 7. Shimmer inside our own render mesh since the last patches (2026-10-03)

**User report.** Our added render mesh (drops, micro, trails), not only the
KN5 meshes, has shown shimmer since the last few patches. The exact patch
is hard to pinpoint.

### Found bug (fixed): the T3 redraw diagnostic broke the render state

- `RAIN_VISOR_REDRAW_TEST_MESH` was set to `'GLASS_COATING_REFL'` in the
  build, which made the T3 diagnostic active.
- Its callback used `sim.lightDirection`, but `sim` is not a chunk-level
  local. So every frame the callback:
  1. made the mesh visible;
  2. set opaque blend, depth Normal and cull None;
  3. then **raised an error** before drawing and before restoring
     anything.
- The mesh was left visible in the normal pass, and the render state leaked
  into the rest of `main.track.opaque`. A coating at the visor surface
  that writes depth fights with our drop mesh, which is drawn with a depth
  test at almost the same depth. The result is shimmer inside our mesh.
- **Fix:** `ac.getSim()` is called locally, `render.mesh` is wrapped in
  `pcall` (one warning only), and the state is always restored. The
  default is `''` again; the setting is a diagnostic only.

### Other changes from the last patches that can shimmer under DLSS

Isolate them one at a time:

| Since | Change | Why it can shimmer | Toggle |
|---|---|---|---|
| s19 | Micro point reads by `Load()` | Exact texel switch under DLSS sub-pixel jitter. The ignored point sampler had actually been bilinear, which is smoother. | `RAIN_DYNAMIC_MICRO_POINT_LOAD` (new, UI "Micro exact point reads") |
| s24 | Trail v2: sharp mip 0.75 with offsets of up to about 25 px | High-frequency shot detail plus jitter. The gradient of the 1024 trail canvas is piecewise linear, so the offsets step between texels. | "Trails: cylindrical lens refraction", or raise `TRAIL_MIP_BASE` to 1.5 |
| s25 | T3 ripple | Phase from a mean flow read back every 4 frames, then smoothed. Small steps are possible. | `TRAIL_RIPPLE_AMP` = 0 |
| s15 | Exact depth on `gSolidA ≥ 0.35` | Depth toggles at alpha edges (pop-in, wipes), and DLSS reads depth. | depth pass mode 1, or occlude off |
| s15 | Micro pop-in | Intended blinking | `MICRO_POP_ENABLED` |

**Suggested order:**

1. Run with this build first; the state-leak fix alone may cure it.
2. Then point reads.
3. Then trail v2 and the ripple.
4. Then the depth mode.

## 8. Drops shaking with whatever lies behind them (2026-10-03)

### User observations (after the §7 fix; the shimmer inside the projected image is gone)

1. Where the car's wheels vibrate, the micro pattern over them moves *with
   the wheels*.
2. Drops over the car body stay fixed, while drops over the background
   shake.
3. With NeckFX off it is the reverse: the drops over the body shake and the
   background ones stay fixed.
4. Toggling micro exact point reads, or reloading, changes nothing.
5. The mesh border itself is not perfectly camera-locked; it shakes (G-force
   motion is off). Yet only some regions shake, not all of it.

### Interpretation: temporal reprojection with the motion vectors of the layer BEHIND

Every observation fits one mechanism:

- Our drop mesh is drawn with `render.mesh` in a **transparent** stage.
  Transparent draws do not write motion vectors. The velocity buffer under
  our pixels still holds the motion of the **opaque surface behind**:
  wheels, car body, track or sky.
- DLSS (or TAA) reprojects the history of each pixel with that vector. Our
  camera-locked drops are therefore dragged by the motion of whatever is
  behind them:
  - over vibrating wheels → wheel motion (1);
  - over a car body that does not move relative to the camera → still (2);
  - over a background that moves relative to the camera → shake (2).
- NeckFX changes which layer moves relative to the camera. With NeckFX the
  camera sways against the car, so the background vectors carry the head
  motion. Without it the camera is car-locked and the body/wheel vectors
  carry it. So the pattern flips (3).
- Point reads cannot change any of this, because the shaking is not in our
  shading (4).
- The "border shakes" impression is the same history drag at the mesh
  edge, which is why it is regional and not global (5). A real one-frame
  transform lag would move the whole mesh at once. That can still be
  tested with switch T2 (`RAIN_VISOR_MOTION_TEST_LATE`).

**Confirming test (no code needed).** Switch the anti-aliasing to *off*
(no DLSS, no TAA) and compare. If the regional shake disappears, the cause
is reprojection. With TAA instead of DLSS it should also be reduced but
present.

### Why the API offers no direct fix in the current draw path

- lib.lua (preview634) has no Lua access to the velocity buffer and no
  reactive or transparency mask for upscalers. The only related knob is
  `ac.SceneReference:setMotionStencil` (1 = reduced TAA, 0.5 = extra TAA),
  which applies to scene-drawn meshes and did not help the KN5 (§1).
- A `render.mesh` shader returns a single colour. It cannot write motion
  vectors.
- Our depth pass writes near depth only. It cannot give the pixels a
  "camera-locked = zero motion" vector.

### Proposed fix: draw the visor layer AFTER the upscaler (post overlay)

The visor is the closest surface to the eye; everything else is behind it.
It can therefore be composited on top of the final, upscaled frame:

1. Render the drop mesh (same shader) into an offscreen target with the
   main camera, every frame: an `ac.GeometryShot` built with custom draw
   callbacks (`{reference = …, transparent = function() render.mesh(…) end}`,
   lib.lua `ac.GeometryShot(sceneReference | {reference, opaque, transparent})`).
   The target is at output resolution, premultiplied RGBA.
2. Composite it full-screen in the HUD stage with `ui.onExclusiveHUD` or a
   full-screen transparent window and `ui.drawImage`. That is after DLSS
   and post-processing, so there is **no temporal reprojection** of our
   pixels: no shake, no ghosting.
3. Bonus, the project's top open item: at that point the final frame
   (`dynamic::screen` after post, to be verified) can be the refraction
   source. The drops then refract the **final rendered tone**, with clouds,
   cars and post-processing, which is exactly what
   `RAINFX_REFRACTION_SOURCE.md` and `RAINFX_SHOT_TONE.md` are after. The
   geometry shot stays only for what the frame covers with near helmet
   parts.

**Costs and trade-offs.**

- One extra offscreen render of the visor mesh, at output resolution.
- The drops no longer receive in-scene post effects (bloom, motion blur,
  scene exposure). Our shader then works in LDR display space; tone
  helpers change from HDR to LDR.
- The depth occlusion against car glass becomes unnecessary: the overlay is
  on top by construction.
- DLSS no longer anti-aliases our drops, so their rims need their own
  analytic AA (smoothstep with `fwidth`). Most of it already exists.

**To verify before building it:**

1. That a `GeometryShot` with a `transparent` callback can run our
   `render.mesh` (custom shader, SceneReference mesh, setVisible trick).
2. Which texture holds the final post-processed frame at HUD time.
3. Whether `ui.onExclusiveHUD` (or a transparent window) covers the whole
   screen, VR excluded.

A small probe can check all three.
