# KN5 / independent 4:1 glass UV migration — s61 (2026-10-12)

Status: **REFERENCE** — implemented and verified offline; CSP visual and frame-time verification remains in game.

## Current contract

The current KN5 has 26 meshes. RainFX uses `GLASS_RAINFX`; glass passes use
`GLASS_COAT_FX`, `GLASS_EXT_FX`, and `GLASS_INT_FX`. Each has its own UV layout.
Raw KN5 coordinates use U `[0,1]`, V `[-1,0]`; texture sampling uses `(U,V+1)`.
The provided `texture/RAINFX_ObjNormal_BoundaryMask.dds` is 4096 × 1024:
RGB is object normal, **alpha** is valid surface. Black RGB is not a validity test.
Holes, outer edges and disconnected regions are absorbing boundaries, with no wrapping.

Model SHA256: `2596f63e20a02bc0608bfc11270f892d500f45b499a1b2331045b361d83031b9`.
Mask SHA256: `08bf1ede69d7bdd3dccbb586d87e78db0f0ff6416e6639fbae09e77da17ee7a5`.

The KN5 and original textures were not rewritten. The starting source/configuration
snapshot is `docs/diagnostics/2026-10-12/kn5-migration/baseline/manifest.json`.
Existing user material settings and tuning are retained. Files the user moved to
`texture/Pre 7.0 Textures/` remain there; the reusable smear pattern points there.

## Surface physics and units

`bake_rain_surface.py` rasterizes the actual RainFX triangles into 2048 × 512
static fields. The geometry Jacobian is `J=[dP/dU,dP/dV]`, in KN5 local metres.
Force-to-UV projection uses `(JᵀJ)⁻¹Jᵀ`, retaining UV rotation, skew and scale.
Gravity, inertia and airflow enter in world space and are transformed into object space.
Uniform helmet profile scaling is included. The current camera node hierarchy uses
uniform scale; nonuniform model scaling would require a different world-space metric.

State position/velocity remain actual UV / UV per second. Radius, mass profiles and
previously tuned speed controls retain a **reference unit** for compatibility:
`RAIN_GPU_STATE_PHYSICAL_DIAMETER_UV_PER_MM = 0.0029296875` means reference units
per millimetre, not current-mesh U or V per millimetre. Geometry converts reference
distances into the actual local UV footprint. Radius, speed threshold, drag, steering,
merge distance, CPU stamps and GPU heads use this metric. Changing UV layout does
not redefine the physical diameter.

Inertia is carried between changing triangle bases in 3D and reprojected locally,
preserving speed. Merge momentum is also combined in 3D before projection.
Integration uses adaptive steps: at most 1 mm inside the surface, refining to half
a source-mask texel near a boundary. A conservative distance transform in `du.A`
permits longer interior steps without jumping through small holes. The shader caps
at 128 steps; an excessive unresolved displacement retires the drop instead of
wrapping, stalling or teleporting. Meta processing does not integrate a second time.

8192 deterministic birth sites are sampled by **real triangle area**, filtered by
the new mask. Both prelaid and fallback birth paths use these sites. CPU coalescence
uses a physical 3D spatial hash, rather than a square UV distance grid.

### Baked fields

| Asset | Meaning |
|---|---|
| `RAIN_GEOMETRY/du.dds` | RGB dP/dU; A 0 invalid, ≥1 conservative source-mask step distance |
| `RAIN_GEOMETRY/dv.dds` | RGB dP/dV; A coating coverage |
| `RAIN_GEOMETRY/position.dds` | RGB local surface position for CPU spatial queries |
| `RAIN_GEOMETRY/normal.dds` | Diagnostic interpolated mesh normals; supplied object-normal map remains the force normal source |
| `RAIN_GEOMETRY/spawn_sites.dds` | 8192 × 1 data records: texture U/V, activation order, valid flag |
| `RAIN_GEOMETRY/surface_bounds.lua` | Conservative micro-footprint bounds for adaptive bake stencil |

These data textures are linear, not colour textures. Data-record/BVH/state atlases
keep their record dimensions. Only UV surface atlases use the 4:1 shape.

### Coating versus bare glass

Coverage is baked by nearest COAT geometry within 1.5 mm. The resulting map labels
the central exposed lens as coating and the top/bottom bands and attachment regions
as bare glass. Coating is 66.39% of the **entire RainFX surface by area**; this is not
the fraction of the visible helmet opening. The baked classification can be inspected
in `docs/diagnostics/2026-10-12/kn5-migration/rain_coating_classification.png`.

The water-repellent coating has lower pinning and shorter trail retention; bare glass
has additional drag. Initial factors are `RAIN_SURFACE_COAT_ADHESION=.55`,
`RAIN_SURFACE_GLASS_EXTRA_DRAG=1.5`, `RAIN_SURFACE_COAT_RETENTION=.65`.
These are tunable hysteresis/wetting approximations, not measured contact angles.
They and `RAIN_MIRROR_WATER` persist through material settings. Other accepted
RainFX force/shape/optical gains were not retuned.

## Independent glass UVs and rendering

Each FX surface receives its own 2048 × 512 atlas under `texture/GLASS/FX/`.
Materials are read from the KN5's authored `*_MRR` slots, then transferred to the
corresponding `*_FX` geometry. No filename-based metallic/roughness guess is used.
Tangent-space normal vectors are transported between the two geometric frames.
INT's authored 16-bit normal remains **RGBA16 UNORM DDS** in the runtime; its PNG
is an 8-bit preview. The INT lens/outline masks are regenerated from its transferred
closed relief. INT→EXT band correspondence is baked once into
`GLASS_INT_EXT_UV_FIELD.dds`, including its own validity alpha.

Water influence on camera-side optics continues to use the stable **post-rain HDR
screen capture**. It never converts entire surface UV atlases every frame.
Surface backing canvases (heads, trails, wipe, impact film and micro pattern) now
use width × width/4. Vertical texel steps and derivative denominators are corrected.
UI stamping retains virtual reference coordinates and scales once on submission.
The generic dust/scratch/smudge pattern is regenerated as a 2048 × 512 INT atlas;
its scratch tangent uses rectangular UV coordinates. The old archived square
pattern stays archived. This also fixes its previously missing runtime path.
Micro bake search bounds grow for smaller profile scale or larger user radii so
footprints are not cut by the old fixed neighbour stencil. Optical mask defocus uses
the rectangular mask height. Screen captures and sprite/data atlases retain their
own aspect ratios.

## E1 and native visibility

The native HDR capture allowlist is:
`FRAME_MAIN`, `BAND_INNER`, `BODY_FABRIC_TRACE`, `DRIVER_FACE`,
`DRIVER_BALAKLAVA`, `CAM`, `CAM_COVER`, `CAM_FABRIC`.

BVHs, smooth normals, UVs, material tables and transformed bounds were rebuilt.
`FRAME_MAIN` keeps its native shader/material and uses runtime
`SceneReference:setCullMode(render.CullMode.None)` on the original and isolated
capture copies. No native shader replacement is needed for two-sided output.

`CAM_COVER` has authored transparent material: it participates in native HDR colour
capture, but is excluded from opaque ray occlusion, opaque source depth and white
probe occlusion. Treating it as opaque would hide internal geometry.

All other original native meshes remain normally visible in main and mirror views,
following the existing user Visible control. The four dummy FX/Rain originals are
hidden from native colour/shadow preparation, while their custom passes remain
controlled by their editor visibility. Capture copies use only their allowlist,
inherit logical visibility and are hidden after pending/success/error callbacks.
Visible membership changes invalidate source/probe captures; camera motion does
not unnecessarily invalidate the static interior optics bake.

Mirrors receive an optional **water-only** pass (`RAIN_MIRROR_WATER=true`). It reuses
completed water fields and adds highlights, without running state updates, E1
captures or glass FX bakes in the mirror callback. COAT/EXT/INT custom passes have
no mirror draw/capture. The mirror water approximation has no refractive scene
capture; its cost and visual strength must be measured in CSP.

## Rebuild and reload

After another KN5/mask change, run with the project's Python (NumPy/Pillow):

```powershell
& 'C:/Users/songak/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' docs/tools/build_kn5_migration.py
```

The builder runs, in order: E1 BVH → optics assets → Blender surface/correspondence
bake → boundary step limits → independent FX materials → physical birth sites →
rectangular contamination pattern → geometry checks. Pass
`--blender 'absolute/path/to/blender.exe'` if needed.
It does not regenerate or alter the user's KN5. The one-shot `migrate_*` / `finish_*`
patch scripts are implementation history and must not be rerun as asset builders.

Reload the CSP app after rebuilding. RainFX refuses mismatching model/mask hashes,
missing surface files, old data version, or mismatching FX/spawn stamps. The UI's
**Recheck Rain geometry files** retries hash verification; it does not replace an
already-loaded KN5 or cached DDS/mesh references, so it does not substitute for reload.

Diagnostics: Rain debug **7** shows coating (cyan) / bare glass (orange); **8** shows
the geometry metric. Return debug to 0 for normal rendering.

## Verification and remaining visual checks

Results are under `docs/diagnostics/2026-10-12/kn5-migration/`:

- `check_kn5_migration.py`: exact KN5 parse; 40,201 Rain triangles; all 489,325
  sampled valid pixels have geometry support; UV/frame/mask/hash contracts,
  physical circle/force invariants, 16-bit INT format, and birth-site validity.
- `check_rain_migration_shaders.py`: 13 actual Rain shader variants compile;
  at most 11 bound textures. `check_visor_optics.py`: 13 optics variants compile,
  at most 10 bound textures; actual Lua capture/cache/visibility/pending cleanup.
- `check_rain_surface_gpu.py`: production HLSL executed on D3D11 WARP; 1 mm
  radius and force projection at profile scales .75, 1 and 2; transported speed
  error ≤5.37e-7 reference units; a crossed one-texel hole and outer edge retire.
- `check_rain_spawn_gpu.py`: 4096 finite, valid births per initialization,
  fallback-respawn and prelaid-atlas mode on D3D11 WARP.
- Material INI round-trip, E1 geometry/ray and runtime regression checks pass.
- `check_rain_surface_runtime.py`: actual Lua hash/cache/missing-file gates,
  metric projection, profile scaling and micro stencil. Verification files
  tolerate Windows CRLF when read in binary mode; the regression caught and
  corrected a CRLF data-version mismatch that would have blocked RainFX.

FXC still reports a conditional-loop definite-assignment warning in the initialized
respawn helper and signed modulus performance warnings. The respawn helper's actual
compiled shader was executed in all three modes above with valid finite results.
These tests do not establish CSP visual appearance, mirror ordering or FPS. In game,
check the independent material alignment, the INT relief, Visible toggles, camera
cover transmission, strong COAT reflection, and water diameter/direction at the same
track position. Record any native sorting/depth interaction from that test rather
than attributing it to UV physics without a capture.


## s62 correction (2026-10-12)

User game results identified errors not established by the earlier numerical
checks. s62 fixes EXT native-opacity versus band-mask semantics, fixed rim
contrast, DLSS refraction alignment, pending micro bakes and signed velocity
readback. It also removes the respawn warning and redundant coordinate/geometry
work. The previous warning note describes s61; current actual Rain/glass
variants compile with /Ges /WX and no warnings. See RAINFX_S62_OUTPUT_AND_COST_FIXES.md.
