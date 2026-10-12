# Cached visor optics implementation

Status: REFERENCE — implementation and dated verification; in-game observations are identified separately.

The supplied design is archived as `VISOR_OPTICS_USER_DESIGN.txt`. The new implementation is `visor_optics.lua`, with shader passes under `shaders/visorOptics*.hlsl` and `rainVisorOptics.hlsl`.

## Runtime path

### 2026-10-10 user verification and UV / temporal review

User verification of the preceding build: the abnormal base-scene behavior with
Prebaked Dust/Scratch disabled is gone; cached optics no longer disables E2/E3.
Motion smearing and stepped facial reflection boundaries remain. These are game
observations, not results of the offline shader checks. This review changes no
runtime code and does not claim either remaining defect has been fixed.

**Common glass UV.** Matching UV at corresponding physical surface points can
remove `txLayerBandUV` from the INT E2/E3 path. Currently this is a 1024-square
RGBA16F field (8 MiB, one level), sampled with four explicit bilinear `Load`
operations per shaded optics fragment. It converts INT UV to EXT band UV;
direct shared UV would also remove derivatives of that conversion field.
This requires changing the shader/bindings and rebuilding the material masks.
Moving UV islands without changing code saves nothing. Matching islands in an
editor is insufficient if their texels describe different surface points.
Shared orientation, scale, tile convention, padding and seam placement matter;
thickness-separated surfaces need correspondence along the intended surface
projection, not a promise that every oblique ray hits identical UV.

Common UV also permits shared masks and channel packing, if resolution and
filtering requirements agree. A later UV-space E1 bake could avoid view/FOV
dependent raster cache layout, but eye changes still alter reflected rays and
must invalidate or reproject the geometry data. That would be an architectural
change. Current E1 is canonical-camera projected, not shared-glass-UV baked.
UV authoring alone does not reduce its 44 bake steps, native colour/metric
captures, HDR frame copies/MIP generation, lighting raster or PSF/ghost/scratch
taps. A large FPS gain is therefore not established; the immediate benefit is
mapping consistency and one remap read, with broader savings requiring changes
to the passes. Do not combine normals or merge E2/E3 into E1 solely because UV
is shared: E1 intentionally uses geometric normals.

**Temporal smear.** Native interior capture is not a necessary cause: the user
has reproduced the defect with it disabled and previously found that disabling
DLSS removes E1 trailing. RainFX also reads captured scene colour. E1 radiance
is overwritten each frame with opaque blending, not accumulated from a previous
radiance image. Its final draw is pre-upscale `render.mesh`, premultiplied
additive RGB with alpha zero and read-only depth. This alpha is a blending
choice, not a DLSS transparency/reactivity mask. The Lua path supplies no
dedicated reflection motion vectors. Mismatched temporal reprojection is the
leading inference; the actual engine velocity input has not been inspected.

RainFX's previous fixes corrected later-glass overdraw and shading/depth
coverage. Its depth-only pass covers selected solid water pixels; it does not
provide reflection motion vectors. Earlier notes describe the resulting
temporal benefit as unverified, and later regional-drag observations survived.
Background refraction and helmet-interior reflection also have different
apparent motion. RainFX's present stability therefore warrants comparing paths,
but does not prove that writing near depth across the entire faint E1 image is
safe or sufficient: that can suppress later glass and mismatch background
depth. UV alignment does not supply the missing temporal inputs either.

NVIDIA's SR integration guide identifies colour, depth and motion vectors as
inputs: https://github.com/NVIDIA-RTX/Streamline/blob/main/docs/ProgrammingGuideDLSS.md
The engine's provision of those inputs is distinct from this Lua shader API.
Treat the API constraint as a scope limit, not proof that all visible smear is
unfixable or attributable solely to DLSS.

**Stepped face: candidates, not a confirmed diagnosis.**

1. `optMaterialSample` floors its LOD and samples only one MIP, making material
   detail switch abruptly at footprint boundaries. Interpolating adjacent
   levels is the first sampling change to evaluate.
2. That footprint uses derivatives of independently traced hit UV. Across
   triangle/island/material transitions it can describe unrelated hits. A
   same-hit triangle footprint must not be replaced by cross-island smoothing.
3. The material bake converts diffuse to linear RGB, then stores it in
   RGBA8 UNorm. Linear 8-bit quantization can expose tonal steps in amplified
   faint reflections. A half-float material target is a separate precision
   experiment, with four additional bytes per bake pixel (about 10.3 MiB at
   2159x1249, about 37.0 MiB at 4096x2369); it is not an FPS optimization.
4. Per-texel normal/visibility changes and seams already in the diffuse remain
   possible. Inspect unblurred Debug 10 before changing final blur or assigning
   the screenshot's broad boundaries to mesh geometry.

Recommended sequence: isolate static material/normal/visibility boundaries,
then compare E1 and RainFX draw/depth/jitter behavior during the same motion.
Do not increase Bake width or globally overwrite visor depth as a substitute
for identifying which stage introduces the defect.

### 2026-10-10 cached toggle follow-up: E2/E3, base image and downward opening

Inspected `CACHED VISOR OPTICS 문제.mp4` (26.666 seconds) with Windows Media
Foundation. Contact sheet: `docs/diagnostics/2026-10-10/cached-toggle/video1_contact.jpg`.
The native interior source is disabled in the supplied comparison.

- **Confirmed E2/E3 regression:** cached enabled explicitly set `gLayerOptics=0`
  and returned before exposing the E2/E3 controls. Both conditions are removed.
  E1 continues using geometric INT normals; E2/E3 uses its own relief/refraction
  draw. The two effects share neither normal perturbation nor cache geometry.
- **Source isolation:** the cached master switch used to change the MIP count
  and source binding of the ordinary inner-glass draw. E2/E3 now keeps its own
  canvas and existing 1/6-MIP policy. Cached lighting/bright extraction receives
  a separate full-MIP HDR snapshot. Both are taken before E2/E3, so refracted
  output does not feed back into scatter. Cached-capture failure leaves E2/E3
  intact. This removes a master-switch coupling; it is not proof that every
  reported lamp/motion defect came from the source binding.
- **Neutral comparison:** Final with Reflection gain=0, Internal double-image
  gain=0 and Final + debug effect gain=0 now bypasses the additional snapshot,
  offscreen updates and composite draw at every tier. Debug must be 0. Zero
  production contributions also discard individual fragments instead of
  touching the target. On-demand geometry baking still follows the tier.
  Dust/smudge/sun scatter operates in **every tier**; only ghosts/scratches
  require tier 2. The 8.983-second frame shows effect gain=20, dust gain=.139
  and smudge gain=.159, so this particular frame is not a zero-effect baseline.
- **Opening light bounds:** the prior bounce had an unconditional sun floor,
  and ambient could borrow front-frame energy even with closed visibility.
  Bounce base now scales with baked open fraction. Direct/highlight/bounce
  is bounded by sun direction versus canonical helmet/camera forward, using
  the existing shadow cosine thresholds. Ambient also requires baked upper
  hemisphere sky access and fades as the opening turns toward the ground.
  This bounds L1 visibility leakage. It is still an approximation: 32 rays
  and L1 cannot resolve exact aperture edges, indirect ground light or track
  local lights. Accepted native local light remains independent of these
  estimated sun/sky terms.

Validation: 13 production FXC passes, full LuaJIT syntax and the actual main
scene-stack helper across toggles/tiers, stable E2/E3 parameters/source identity,
failed cached capture, zero-gain bypass and independent E2/E3 disable. Production
D3D11 WARP readbacks verify closed/downward/backlit opening bounds, nonzero
shaded-hit indirect light, preservation of bright destination pixels at zero
gains, and existing native/material/effect cases. No game FPS or DLSS appearance
measurement was possible. Keeping two HDR snapshots adds an E2/E3-size canvas
(about 27.4 MiB at 2159x1249) and an extra copy when both paths are active.

Reload the Lua app; its usual bake runs again. For the base-image A/B, keep
E2/E3 enabled, Native source disabled and Debug=0; set the three gains above
to zero and toggle Cached optics. Then restore gains individually. The known
pre-upscale transparent DLSS trailing remains an integration limitation;
these changes do not supply motion vectors or guarantee its elimination.

### 2026-10-10 video follow-up: split face, native replacement, dry haze and DLSS

Inspected `E1잔상.mp4` and `내부가 환히비춰져도 드러나지 않음.mp4` with
Windows Media Foundation; frame sheets are in `docs/diagnostics/2026-10-10/`.
The user subsequently confirmed that the trails disappear with DLSS disabled.

**Implemented:**

- Native colour previously replaced the entire analytic radiance wherever a
  binary depth/ID test passed. It now adds only the positive native lighting
  excess over analytic direct/bounce/highlight. Ambient and the full BVH image
  survive black/rejected native pixels. Four bilinear colour taps are each
  checked against their own depth and material ID. Depth confidence and a
  1.5% capture-frustum edge fade avoid abrupt acceptance seams. Debug 14 is
  now continuous confidence, not a binary coverage flag. Capture is still a
  finite view; it cannot illuminate every hidden surface or reproduce the
  exact specular view of the reflecting visor point.
- Projection subtracts hit/source positions in helmet-local coordinates before
  rotating them to capture view. This avoids millimetre precision loss from
  subtracting large track-space coordinates during the strict depth check.
- Normal mapping no longer reconstructs its tangent basis from screen-space
  derivatives of adjacent BVH hits. Each hit triangle supplies its own UV
  basis, transformed as vectors and orthogonalized against its smooth normal.
  Mirrored UV handedness is preserved; degenerate UVs use the smooth normal.
  The current face KN5 has identical normals at coincident vertices; the
  screenshots alone do not establish a new mesh seam. These rendering defects
  are plausible split-image causes, not an in-game confirmation of the fix.
- Dry condensation is exactly zero. The soft reveal interval formerly crossed
  rain zero for part of the haze pattern. Positive rain also scales film amount;
  rain one retains the old amount. Manual rain override still deliberately
  overrides weather. The separately authored smear facet film is independent
  of condensation and is not disabled by this change.
- All optics data canvases explicitly overwrite RGBA using Opaque, preserving
  alpha as data. The documented ExtraCanvas default was already Opaque, so
  missing explicit blend mode is **not** evidence of an accumulation bug.
  The 120 ms sun visibility smoothing is removed. Track shadow/probe sampling
  remains at 10 Hz and is an approximate scalar, not spatial local-light data.

**Remaining DLSS issue:** E1 is rendered in `main.root.transparent` before
upscaling. The supplied Lua API exposes neither motion-vector writes nor a
DLSS reactive/transparency mask for this custom draw. Its transparent pixels
can inherit background velocity; overwriting the offscreen radiance does not
fix that final-frame reprojection. Disabling DLSS removes the observed trails
according to the user's A/B test. A separate E1-only post-upscale composition
would require a new display-space path and decisions about post-processing,
VR/mirrors and HUD order. The previously closed full-visor HUD overlay remains
closed; this build does not silently change that architecture. No claim is
made that DLSS trails or exact native-highlight matching are fixed.

Reload the Lua app to load shader changes, then allow the normal 44-step bake.
The changed normal-basis cache version forces fresh surface data; no offline
KN5/BVH asset rebuild is needed. Compare native on/off at the same pose in
Final and debug 10/14. Check dry weather with rain override -1 or 0 and distinguish
Haze from the separate **Facet film on bare glass** control. Game app source
and shaders are symbolic links to this repository.

Validation: 13 production FXC variants and actual Lua cache/capture lifecycle;
D3D11 WARP HDR tests with mixed 2x2 material/depth silhouettes, black native
pixels, far track translations, gradual depth acceptance and frustum edges;
mirrored/scaled/rotated/degenerate UV bases and dry/wet production haze function
readbacks. Each readback overwrites a bright prior frame twice to check that
data alpha zero does not accumulate colour. This validates code/energy, not
game appearance or DLSS itself. Native capture still costs two source shots;
the four-tap validation adds work. No game FPS measurement was performed.

### 2026-10-10 follow-up: coverage, night fill and fixed contamination

The user reported little native-source benefit at about 2.8 FPS cost, coverage
only on two upper regions, near-black ambient fill, and contamination visible
only in isolated diagnostics. These observations are not a new performance
measurement by this implementation.

- **Native source:** new `SOURCE_AUTO_FIT=true` positions the backward-looking
  source camera 18 cm in front of the actual face bounds centre, transformed
  through the face mesh and current helmet pose. Existing source offset,
  height and pitch are then applied. Model face vertex Y is roughly -11 cm;
  the previous neutral-eye anchor could frame different regions. This is a
  framing correction, not proof that every reflected hit is visible from one
  source camera. Disabling fit restores the eye-based camera. The panel shows
  the unprojected colour capture; debug 14 still shows accepted, depth/ID-checked
  coverage. Uncovered hits retain estimated lighting. Disabling the native
  source prevents both source captures; it leaves the separate sun probe active.
- **Ambient:** zero night sky/horizon colour now uses neutral chroma instead of
  suppressing ambient energy. `AMBIENT_AO=.85` multiplies fill by
  `0.15 + 0.85*AO`; setting 1 restores full AO weighting. The floor represents
  unresolved indirect bounce and is a tuning approximation. Fill still depends
  on the pre-optics scene HDR mean; it is not measured local light transport.
  The brief flash reported during changing light has not been reproduced in-game.
- **Bright sources:** a half-resolution HDR canvas extracts luminance excess
  above `max(GHOST_THRESHOLD, sceneMean*BRIGHT_RELATIVE)` with default relative
  threshold 4. Each of four original scene samples is thresholded *before*
  averaging and building MIPs. Dust PSF, ghosts and scratch fans use this canvas.
  This removes the old whole-front-scene ghost from thresholding blurred RGB.
  Debug 19 displays the extracted sources. `GHOST_THRESHOLD` now applies to
  all three effects; its UI name is **Bright source HDR threshold**.
- **Final comparison:** the old hard-coded 20x debug gain is removed. Modes
  16–18 use `DEBUG_GAIN=1` initially. **Effect debug over scene** uses additive
  alpha zero for these modes, matching Final energy when display gain is 1.
  **Final + debug effect gain** (`EFFECT_GAIN=4` initially) scales all three
  effects in production and diagnostics. It is an artistic starting gain,
  not a calibrated material measurement. Reflection gain remains independent.
- **Fixed pattern:** `PATTERN_TEXTURE=true` selects
  `texture/GLASS/visor_contamination_rgba.dds`, 2048-square linear RGBA8 data:
  R sparse grains, G irregular short wipe arcs, B tangent angle, A faint smudge.
  Alpha is data, not opacity. The numerical authoring script is
  `docs/tools/build_visor_contamination.py`; seed 17 and UV placement are fixed.
  Density scales and saturates channel coverage without generating new grains.
  The seed slider only changes the procedural fallback. A cached RGBA8 canvas
  generates MIPs on density/pattern changes; pupil defocus accounts for its
  resolution. Sparse defocused scratches are no longer discarded by the old
  0.02 coverage cutoff. Their fan is limited to areas near extracted lights.

No geometry rebuild is required for contamination, fill or source camera
changes. Model export now includes per-mesh local bounds in optics metadata.
Reload the app to load the new shaders and defaults. A normal 44-step GPU bake
after reload is expected. Game app Lua/shader/texture links resolve to this repo.

Validation: 13 FXC shader variants within the 11-texture budget; actual Lua
capture alignment, face-bound camera placement, cache/lifecycle and disposal;
D3D11 WARP HDR readbacks for zero-sky fill, AO floor, uniform-sky rejection,
local source energy/hue, defocused scratches and Final/debug energy parity.
The DDS payload matches its PNG data exactly. Real native coverage, night
appearance and the new extraction pass's FPS cost still need game verification.
At a 3237x1872 scene, the half-size RGBA16F bright canvas with MIPs is roughly
15.4 MiB; the cached RGBA8 mask with MIPs is roughly 21.3 MiB, plus its 16 MiB
source DDS. Procedural masks were already cached; prebaking primarily controls
pattern quality and predictability, not per-frame generation cost.

Suggested comparison: enable fit and inspect raw native capture + debug 14;
inspect 19 facing lamps (it should retain lamps, not the full sky); compare
16/17/18 with display gain 1 and over-scene preview, then Final at unchanged
effect settings. Prefer lamp-facing night and sun-facing daylight captures at
the same camera position. A fully black mode 19 means the threshold removes
the sources; lowering the threshold is then the relevant control.

### 2026-10-10: native HDR lighting at cached hits

The sunny/night feedback exposed a silent resolution cap: the width slider went
to 4096, but `startBake` clamped every request above 1024 to 1024. Earlier 2048
versus 4096 screenshots therefore did not compare those actual resolutions.
The cap now matches the UI (4096), and the panel reports actual width, height,
MIP count and approximate bake-buffer memory. At 4096×2304 the bake buffers
alone are about 708 MiB, excluding source/scene/mask/probe textures and engine
overhead. Increasing width now adds real bake and per-frame lighting/MIP cost;
the earlier unchanged FPS cannot predict its cost.

`Native HDR interior source (local lights)` defaults on. A registered, isolated
KN5 copy captures Frame/Rubber/Fabric/Face/Balaclava with their original native
materials, engine lighting and shadows. Colour is RGBA16F, metric view depth
and material ID are RGBA32F. Both shots use the same camera and clipping planes.
The source defaults to 1536×1024, 120° FOV, 25 mm in front of the canonical eye,
looking back into the helmet. Its resolution/offset/height/pitch/FOV are separate
from bake width and do not require retracing BVH geometry.

For every cached BVH hit, the lighting shader projects its position into this
source camera. It accepts colour only inside the source view, with positive
clip W, matching material ID and metric depth (1–5 mm tolerance), and valid
alpha. Covered pixels use native HDR colour plus the explicit ambient fill;
they do not add the analytical direct sun/specular/bounce a second time.
Uncovered/occluded pixels retain the analytical lighting estimate. Lighting
alpha records native coverage, which is also reported by on-demand diagnostics.
Ten textures are bound in this lighting pass, within the eleven-slot limit.

The previous estimate contained sunlight and frame-average ambient, but no
native local lights. The new covered path can carry night floodlight/headlight
colour and authored skin/fabric response even when sun and frame mean are zero.
It remains a single finite source view: native highlight direction is viewed
from that capture camera, not independently from every reflecting visor point.
Source coverage and appearance must be checked in game; no automatic night
gain, exposure remap or increase in physical Fresnel reflectance was added.

`Interior ambient fill` is the existing linear-albedo × sky-chroma × frame-HDR
mean × AO × hemisphere term. Debug 15 isolates it before Fresnel so its effect
can be measured without direct light dominating. Sun bounce/base controls now
explicitly apply to the fallback estimate. High values flatten fallback shading
as the user observed; they do not brighten native-covered pixels.

Cached rays, Fresnel and image displacement now use the geometric INT normal.
The earlier suspension of INT E2/E3 was reversed in the cached-toggle follow-up
above. Its draw and controls now remain independent of cached E1. Material normals remain part of the native KN5
shader; their custom strength slider applies only to the lighting estimate.
Original Face/Balaclava meshes are visible to the main camera for inspection;
their capture copies remain hidden outside scoped captures and cast no shadows.

Additional diagnostics: 14 native coverage (white covered, black fallback),
15 ambient fill, 16 dust/smudge/scatter, 17 ghosts, 18 scratches. Modes 16–18
apply a **display-only 20× gain**, leaving final gains unchanged. Ghosts and
scratches still require Tier 2; the user's Tier 1 screenshots cannot show them.
Ghost threshold is applied to the sampled blurred HDR signal; raising blur
can remove a small bright light before it passes that threshold.

Reload Lua/model, press `Rebake cached optics`, wait for 44/44. Start with bake
1024 and source 1536; compare source coverage (14), raw radiance (10), reflection
(12), ambient (15) and final (0) at the same daytime and night light positions.
For contamination use Tier 2 and modes 16–18, then return to 0. Compare frame
milliseconds with native source on/off; native capture adds two scene passes
each frame, so this update does not preserve the previous performance claim.

Validation: eleven FXC variants, the actual Lua lifecycle/capture registration
and cleanup, genuine 4096×2304 allocation dimensions, matching source cameras,
settings round trips, and 26 D3D11 WARP HDR fixtures pass. New fixtures cover
night source colour independent of sunlight/mean, depth/ID rejection, ambient
isolation, INT atlas independence, native coverage and each contamination
component. Real CSP/game appearance and GPU cost remain unmeasured.

The sections below describe the analytical fallback and original design stages;
the native source/geometry-normal behavior above supersedes their earlier
lighting-eight-texture and visor-normal-map descriptions.

`RAIN_VISOR_OPTICS_ENABLED` defaults on. While enabled, the previous E1 source cameras, per-frame BVH geometry draw and primary resolve stop. Their controls are hidden behind the new mode selection; disabling the new mode restores the previous experiment configuration for comparison. The original native KN5 materials/main housing stay intact.

The current five-mesh BVH is reused. `build_visor_optics_assets.py` exports smooth KN5 vertex normals in precisely the packed triangle order, the authored diffuse/normal/maps textures, and the outer-band BVH. Original KN5/symlink files are not written. Both base BVH and extra optics assets must match the active model SHA256.

### Change-only buffers

| Buffer | Format | Contents |
|---|---|---|
| Hit | RGBA32F | Helmet-local position, material ID 1–5 |
| Surface | RGBA16F | Octahedral local normal, reflected hit distance, authored specular strength × map R |
| Material | RGBA8 | Linear albedo, roughness from material exponent and gloss map |
| Glass | RGBA16F | Octahedral visor normal, eye-to-visor distance, coverage |
| SH | RGBA16F | Four real SH L1 coefficients |
| AO | RGBA16F | Cosine hemisphere visibility in alpha |
| Contamination mask | RGBA16F + MIPs | R dust, G scratches, B wipe-arc tangent angle, A smudges/fingerprint film |

Geometry has four capture steps; SH accumulates 32 uniform sphere directions, AO eight cosine hemisphere directions. One visibility sample is processed per frame: **44 bake steps**, then a lighting-only frame. These BVH rays run only while baking. This amortizes an expensive geometry change rather than executing all occlusion rays in one frame. Two distinct ping-pong buffers prevent feedback/partial accumulation on pending updates.

Texture bindings respect the project's conservative 11-slot CSP limit. `optics_geometry.dds` concatenates the six BVHs' node, triangle and normal records without changing their values or local indices; the material metadata supplies each segment's record offset. Hit/glass use two textures, surface/material four, SH/AO five, lighting eight and final composite ten. Surface and material captures each draw five material-ID variants with normal depth testing and discard all pixels belonging to other nearest-hit IDs, preserving the nearest INT sheet across the draws. This repeats tracing during these two change-only captures, but does not add per-frame tracing or change the 44-step bake schedule. The original all-mesh binding table caused `std/lib_shader: Too many textures` before shader execution.

Cache inputs: active model/profile, scale/axis/offset, canonical local eye and axes, FOV/near clip, render size, bake width, individual relative mesh transforms/visibility, material exponent and specular strength, normal strength, trace range, glass and band transmission. Head/world motion does not invalidate the cache. Transient G-force translation is removed from the bake eye/key; its runtime projection uses cached hit distance. A 0.2 second debounce avoids rebaking on every slider change. A manual rebake button is available.

The camera-attached runtime computes the neutral eye/look/up by inverting the local offset, scale and axis nodes, skipping the motion node. The key uses the model root and mesh local transforms, not a world-space transform/inverse-transform round trip. The latter loses precision at large track coordinates and can repeatedly restart a supposedly fixed bake. The UI reports `Bake starts`, `completed`, `progress: n/44`, and the last changed cache field. In a stable profile the expected result is one start, one completion and 44/44; the start count is not a number of meshes. An automated 700-update moving-world/jitter/G-force regression keeps exactly one completed bake, while FOV, local mesh transform and visibility edits invalidate it.

After replacing KN5, run `docs/tools/build_e1_housing_bvh.py` and `docs/tools/build_visor_optics_assets.py` with Python, reload the model, and use the rebake button. It rechecks the model hash; that hash is part of the cache key and the exported texture table is reloaded at bake start.

The baked SH rays trace all five internal meshes and the outer-band mesh. Band texture alpha blends the exposed glass transmission and opaque-band transmission. SH L1 has low angular resolution and can soften small aperture patches; this is the proposed representation's limitation, not exact directional shadow evaluation.

### Per frame

After the rain colour draw, `visorOpticsCapture` copies scene-linear HDR into a canvas with a full MIP chain. The final 1×1 MIP supplies frame-average brightness; the PSF uses MIPs up to 8. It never samples its own final target. The runtime radiance canvas shades albedo with AO-weighted hemisphere ambient, SH-masked coloured sunlight/visor tint, and the existing sun-bounce control. It also adds a Blinn-Phong highlight using authored `ksSpecular × txMaps.R`; material roughness reconstructs the exponent from `ksSpecularEXP × txMaps.G`. A material without a maps texture uses unit specular/gloss map multipliers. The highlight carries the sun colour and visor tint independently of diffuse albedo and retains SH/external shadow masking.

The highlight's view direction runs from the cached BVH hit towards its reflecting visor point. That point is reconstructed from the baked glass distance, inverse capture projection/view and inverse bake pose, plus the canonical local eye. Using the player's eye directly would shade a different ray. This adds one glass-buffer fetch and highlight arithmetic per lighting texel, plus a maps fetch in the change-only surface pass; capture dimensions and the 44-step bake schedule stay the same. It updates radiance MIPs for distance/pupil blur. This remains a custom lighting proxy: native engine/local-light BRDFs, cubemap reflection, native face `sunSpecular` extensions and transient G-force changes to the specular view direction are not reproduced. Local scene brightness contributes through the frame HDR mean.

INT post composite adds internal reflection, internal double image, external bright ghosts, dust/smudge PSF glare, analytic sun scatter and perpendicular scratch streaks. Cached E1 uses the geometric INT normal for Fresnel/displacement; E2/E3 keeps its separate authored normal. Final output is HDR RGB with alpha zero and BlendPremultiplied. Diagnostics intentionally use alpha one. The cached glass distance rejects overlapping rear INT sheets when the interior cache is ready.

CSP simulation vectors are read-only views and its `vec3:cross`/`normalize` methods mutate the receiver. Camera-side calculation clones `sim.cameraUp` before crossing; the original call threw `attempt to write to constant location` before every tier's composite. The regression mock now implements these mutating/const semantics. `Composite draws` counts successful calls independently of geometry bakes; Tier 0 intentionally has no geometry bake and can stay at progress 0/44. Debug 8 at Tier 0 provides a white-output routing check without depending on any interior cache.

Before engine render-list preparation, the main update hides all custom optical sheets, including `GLASS_RAINFX_OVERLAY`, and disables their native shadows. Explicit custom draws restore their prior hidden visibility. This rule applies with cached optics both enabled and disabled; native housing and mirror mesh visibility/shadows retain their configured behavior. Logical editor visibility is separate from transient render visibility, and nil/default-on visibility is normalized to true in the cache key. A deliberate EXT visibility toggle still invalidates the occlusion bake.

F0 is 0.04; two-bounce images use `F²` (normal incidence 0.0016). The design's internal-double-image example used `F*(1-F)²`, which would make the double image almost as strong as the primary; this implementation uses `F²*(1-F)²*0.8` to preserve the stated two-bounce reflectance. Gain remains adjustable.

PSF weights for MIPs 2,3,4,5,6,8 are 0.30,0.24,0.18,0.12,0.09,0.07, summing to one. They are a normalized initial heavy-tail approximation, **not a measured HG fit**. HG analytic sun scatter defaults to g=0.9. Mask and reflection blur include pupil/virtual-distance estimates, with extra MIP controls and pupil zero allowing a sharp comparison.

Sun visibility uses a smoothed 5×5 sky fraction at the projected sun. A registered native probe copy of the three housing meshes reads the engine's lighting/shadow maps into a 32×32 HDR capture, with a matching 32×32 normal-cosine pass for the denominator. Its average luminance divided by `0.05 × sun luminance × average N.L × calibration` provides one helmet-area external shadow scalar. The two auxiliary shots update at most ten times per CPU second and never enter the main image. Original native materials are not changed; only the separate probe copy is white, ambient/specular/emissive-free and does not cast shadows. Existing capture preparation and guarded visibility cleanup apply to both passes. Offscreen sun uses the same scalar; the 1×1 result is temporally smoothed on GPU. Probe calibration is exposed because engine native shading/local lights can influence the measured ratio. Until the probe is prepared, a track collision ray provides a fallback; it can miss nonphysical visual objects/cars, and the UI identifies which source is active. Exact visual parity still needs game verification.

## Controls and validation

Open the COATING or INT material editor: **Cached visor optics (HDR)**.

- Tier 0: dust/smudge PSF + analytic sun; no reflection BVH bake.
- Tier 1: cached interior reflection and internal double image.
- Tier 2: adds external ghosts and conditional scratch fan.
- Default bake width 512, pupil 4mm, visor thickness 3mm, seed 17. The gains are tuning starting values, not measured visor calibration.
- All `RAIN_VISOR_OPTICS_*` scalar/bool values persist in `settings_mats.ini` alongside the existing material controls.

| Debug | Output |
|---|---|
| 0 | Final |
| 1 | Hit IDs: frame red, rubber green, fabric blue, face yellow, balaclava magenta |
| 2 | AO |
| 3 | SH visibility for current sun direction |
| 4–7 | Mask RGBA separately |
| 8 | PSF weight sum (white) |
| 9 | Reflection CoC MIP |
| 10 | Raw scene-linear HDR radiance, game exposure/tonemapping applied once |
| 11 | External sun visibility scalar |
| 12 | Raw HDR internal reflection and double image, including Fresnel and gains |
| 13 | Raw HDR dust/smudge glare, external ghosts and scratch contribution |

Unit diagnostics (IDs, AO, SH, masks, PSF sum, CoC and sun visibility) are scaled by the scene HDR mean before game exposure. Previously these were sent as 0–1 values into HDR and became nearly black in daylight. Mode 10 previously compressed HDR to 0–1 before the game's second tonemap; it now returns raw HDR, like modes 12/13. These diagnostic corrections do not boost final output.

The interior sun bounce now uses the existing `SUN_BOUNCE * externalShadow * (BOUNCE_BASE + (1-BOUNCE_BASE)*apertureVisibility)` estimate. Applying direct SH visibility and AO again to bounce had removed indirect lighting from surfaces without a direct line to the sun. AO continues to modulate sky ambient; direct sunlight retains SH and external shadow. External shadow zero removes all sunlight-driven direct/bounce terms. This remains an indirect-light estimate, not a new light transport bake. `Interior sun bounce` and `Indirect sun base` expose the existing shared settings in the cached optics panel; tuning them updates lighting without rebaking.

`Read lighting diagnostics` performs one on-demand nine-pixel R32Float readback. It reports sampled hit coverage, mean AO and current SH visibility on hit pixels, external sun scalar, scene HDR mean, and hit radiance means at MIPs 0, 1, 2 and 4. Comparing MIPs helps identify energy changes during blur sampling. A 16×8 grid provides indicative values, not an exact reduction of all pixels; narrow features can be missed and hit-only means can differ with blur across coverage boundaries. There is no periodic readback or additional pass in normal use. Data from a disposed/replaced bake is rejected. These numbers help distinguish low physical energy from missing/over-occluded geometry.

At the user's fixed sunny view, the reported hit coverage was 96.1%, AO 0.374, SH 0.351, external sun 0.999, scene HDR mean 8.054 and hit radiance mean 11.707. Pupil zero revealed faint central line detail in final but did not make mode 12 clearly visible, so blur alone did not resolve the report. At normal incidence, 11.707 × 0.04 × gain 1.11 is about 0.52 HDR before double image. These averages do not prove per-pixel visibility or identify the central line artefact. The added material highlight addresses the previously absent specular response; its real-game appearance still requires comparison at the same view.

Game checks: first load without toggles; wait for bake cached status; move/rotate camera and apply G-force; edit profiles/FOV/visibility and verify invalidation; compare sun front/side/back, tunnel exit and night headlights. Tune dust/defocus/ghost/scratch gains and record frame milliseconds before/after. No measured GPU performance or visual approval is asserted by the automated tests.

`check_visor_optics.py` compiles eleven shader variants with only each pass's bound texture declarations using FXC ps_5_0 `/Ges /WX`, enforces the 11-slot budget on actual Lua draw/canvas parameter tables, and checks atlas records against the original six mesh buffers. It also verifies hashes/textures/normals and executes the actual Lua 44-step lifecycle, five material-ID draws per material capture, no-trace steady state, moving helmet, 15mm motion parallax, FOV invalidation, pending/error restoration, Tier 0 cleanup and prepared/pending native scalar probing. `check_material_settings.py` checks new settings round trips. Existing E1/native-material checks are retained.

`check_optics_hdr.py` executes the production lighting/composite HLSL on D3D11 WARP and reads RGBA32Float results. Sixteen constant-texture fixtures verify indirect light without direct visibility, complete external shadow, open-aperture lighting, HDR diagnostic scale, uncompressed HDR radiance, 4% Fresnel reflection and alpha-zero additive final output. Highlight fixtures check light colour independent of diffuse albedo, SH/external masking, rough/glossy lobe widths, BVH-hit-to-visor direction, canonical eye/pose rotation with large world translation, finite output for opposing light, and additive reflection of the highlight. It requires Visual Studio C++ tools and Windows SDK. This checks shader energy/routing independently of compilation and Lua mocks; it does not measure GPU performance or validate CSP/game exposure and real geometry.


## 2026-10-12 s61 — independent 4:1 glass UV / E1 KN5 migration

The previous common/square-UV discussion is historical. The active surfaces are
GLASS_INT_FX, GLASS_EXT_FX, GLASS_COAT_FX and GLASS_RAINFX, each independently
unwrapped. INT→EXT correspondence and all material/normal/lens atlases are now
baked from this KN5. INT normal remains 16-bit UNORM; contamination is rectangular.
Runtime water/optical composition retains the stable post-rain screen capture.

Captures include FRAME_MAIN, BAND_INNER, BODY_FABRIC_TRACE, DRIVER_FACE,
DRIVER_BALAKLAVA, CAM, CAM_COVER and CAM_FABRIC. CAM_COVER is transparent: native
HDR only, excluded from opaque BVH/depth/probe. FRAME_MAIN uses native two-sided
culling. Capture membership tracks Visible changes; other native meshes are
visible normally, including mirrors. Custom glass optics do not run in mirrors.

Thirteen optics variants and the actual Lua capture/cache/visibility lifecycle
pass offline tests. The former observed motion/face-edge issues have not been
claimed fixed by these numerical tests. Full migration contract, rebuild and
remaining CSP visual checks: RAINFX_KN5_4_TO_1_MIGRATION.md.


## 2026-10-12 s62 — user output / cost follow-up

The user reports black EXT, fixed-looking rim marks, broad rain ghosts and
increased RainFX cost in actual game captures. s62 separates the native diffuse
opacity from the custom band mask (also used by cached band visibility), corrects
rectangular optical normal frames and scales only optical differences. Rain source
pixels use exact target coordinates; pending micro data cannot become a full lens.
Other performance and warning fixes are documented in RAINFX_S62_OUTPUT_AND_COST_FIXES.md.
Offline checks pass; this does not claim a new in-game FPS measurement.
