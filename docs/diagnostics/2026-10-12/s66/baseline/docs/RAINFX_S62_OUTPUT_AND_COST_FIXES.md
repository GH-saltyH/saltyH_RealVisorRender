# s62 — Rain / EXT / E2–E3 output and cost fixes (2026-10-12)

Status: **REFERENCE** — implemented; production HLSL and Lua verified offline.
The new build's actual CSP frame time and appearance have not been measured.

## User result and evidence

The user reports a black EXT surface, fixed-looking E2/E3 border marks,
visor-wide offset ghosts when rain begins, missing basic micro drops, shader
warnings, and approximately 30 FPS of rain-related cost at 60% precipitation
(previously approximately 5–7 FPS). These are reported FPS differences, not
measured GPU milliseconds.

The supplied 18.583 s video was decoded with Windows Media Foundation. Its
contact sheet and selected frames are in `docs/diagnostics/2026-10-12/s62/`.
The final selected frame shows 19.1 FPS / 52.45 ms for the whole scene. That is
a pre-fix observation and cannot establish the new build's cost.
The current sources and user settings were snapshotted to `s62/baseline/`.

## EXT alpha semantics

The native diffuse's alpha represents material opacity: transparent lens areas
are approximately .7; the authored band is near 1. The saved custom band threshold
is .06. Passing this native opacity directly into the custom band test classified
the lens as an opaque black band.

`build_fx_atlases.py` now additionally creates `GLASS/FX/ext_txBand.png`: the same
RGB, but alpha is a band/opaque-marking mask derived from the inspected .90–.94
alpha transition. Custom EXT rendering, INT band reconstruction, and cached band
visibility use this mask. The original native material/opacity and user's band
threshold, glass alpha, tint and opacity controls are retained. In the GPU fixture,
only 13.07% of the atlas is opaque at threshold .06; transparent mask pixels have
exactly zero output alpha when the saved glass film alpha is zero.

## E2/E3 border response

The old cotangent frame used one common normalization for both UV axes. With
rectangular, skewed UVs, this changed the physical strength of a normal component.
The frame now reconstructs dP/dU and dP/dV, orthonormalizes them, and retains
handedness. E3 uses the difference between flat and bevel Snell rays (IOR 1.49),
projected into the current camera, rather than a fixed normal-XY screen shift.

The old `opticalImage *= brightness` darkened the whole allowed ring even with a
flat normal and zero lens slope. Brightness now scales the optical **difference**
from the base image. Transmission and reflection use incidence, normal support
and differential Fresnel; the constant reflection floor was removed. Interior
blur/difference is inactive when there is no lens displacement. The user's
normal/refraction/blur/specular controls are preserved.

D3D11 WARP tests execute the actual layer shader with the saved .75 brightness
and .66 transmission loss: flat INT adds exactly zero at both tested view angles.
A supported bevel produces a different image when the view changes. This verifies
the mechanism; reference-image matching still needs an in-game capture.

## Whole-surface ghosts and missing micro pattern

- Rain source coordinates previously mixed window and target resolutions with
  a `.98` blend. Under DLSS, this introduces a systematic offset into any broadly
  blended film. The source lookup now uses exact active-target pixel coordinates.
- Packed micro gate/radius/class now always use `Load`. Filtered lens-local XY
  remains available through the existing appearance setting; filtering packed
  metadata cannot enable an empty pixel or suppress a real drop.
- A pending/disabled micro bake returns an explicit empty micro record, even
  if the engine's unbound/default texture is white. WARP verifies zero output
  in that case, preventing a default texture from becoming a visor-wide lens.
- Micro baking uses `async=false`, publishes its key only on success, retries
  pending results and reuses the allocated canvas. A pending micro bake no longer
  clips the independent water-field renderer. Actual Lua tests cover a failed/
  pending first attempt followed by successful retry without another allocation.
- The CPU readback no longer clips actual UV velocities to ±.125. Signed
  velocity uses reversible rational encoding inside 0..1 (`q=v/(abs(v)+scale)`), following the SDK's
  numeric `floatValue` range without discarding faster UV motion. The callback
  decodes using that request's saved scale. WARP verifies values −.4 and +1.7
  survive; this retains the actual physical direction/speed for trails and
  coalescence. Old linear encoded readbacks require app reload.

The production micro bake fixture contains active interiors at 60% rain. The
appearance and rain/film/wipe/shape gains have not been reduced to hide a cost.

## Cost reductions

1. **Birth lookup:** use the 8192 offline-validated, real-area-distributed sites
   with a deterministic permutation. Remove the per-birth 128-candidate search
   and its 16-live-drop clearance probes per candidate. Boundary validity remains
   checked. Invalid data cannot fabricate a valid centre birth.
2. **Per-drop GPU frame:** cache a/b/c physical metric and validity in a 4096 × 1
   RGBA32F canvas. Tile binning and head kernels reuse it. At a 2048 × 512 head
   canvas and 64 px tile, the old binning could evaluate the Jacobian 1,048,576
   times; it now evaluates it 4096 times in the prepass. The cache is a state-record
   atlas, not an inter-mesh UV conversion, and does not run in mirrors.
3. **Unused geometry uploads:** production shades the fixed surface and water
   canvases. Skip the per-frame physical lookup and upload of old individual
   droplet quads that the production pixel shader discards.
4. **CPU stroke caps:** one physical ribbon and two cached circular image quads
   replace one ribbon plus 16 individual cap triangles. The physical skewed
   footprint is retained. Actual Lua tests confirm 3000 UI calls for 1000 strokes
   instead of 17000, with reused vectors and one transparent circle texture.
5. Pending GPU metric/tile/head shaders return to the existing CPU fallback
   instead of publishing an incomplete GPU result.

These are structural reductions. No claim is made that CSP is back to a 5–7 FPS
cost until the same scene/settings are measured. The 4096-slot capacity and user
force, shape, material and film settings remain unchanged.

## Warnings

- X3556: use unsigned, bounded spawn and diagnostic indexes for integer division
  and modulus.
- X4000: initialize dimension/frame outputs; remove the early-return structure
  in validity/respawn helpers; use initialized single results. The respawn helper
  no longer has the conditional search loop. Head frame/out values are initialized.
- X3571: positive decay bases are explicitly bounded before fractional `pow`.

`check_rain_migration_shaders.py` now compiles **16 actual Rain/glass variants with
`/Ges /WX`**: any remaining warning is an error. The 13 optics variants also pass
the existing strict compilation checks. Maximum texture bindings remain within
CSP's limit of 11.

## Delivery / validation

Only the derived band atlas needs rebuilding for this step; it has already been
generated by `build_fx_atlases.py`. The complete migration builder includes it
automatically. Reload the CSP app to load the shader, band texture, new readback
layout and per-drop frame cache. No KN5 re-export is required.

Passed checks:

- `check_rain_migration_shaders.py` — 16 warning-free Rain/glass variants;
- `check_s62_output_gpu.py` — actual EXT, flat/bevel optics, micro, metric and
  signed readback on D3D11 WARP; results in `s62/output_gpu_checks.json`;
- `check_s62_runtime.py` — actual pending-bake lifecycle, allocation reuse,
  stroke call bound and obsolete-upload gate;
- `check_rain_spawn_gpu.py`, `check_rain_surface_gpu.py` — valid births,
  direction/size/transport and absorbing holes/boundaries;
- material settings, model/texture/mask contracts and cached optics regressions.

User settings files remain byte-identical to the s62 starting snapshot. Check in
game at the same track position: EXT with its Visible toggle; dry/rainy E2/E3;
initial micro bake then 60% rain; full-surface ghost alignment; and FPS with
RainFX on/off. Keep debug views off for the frame-time comparison.
