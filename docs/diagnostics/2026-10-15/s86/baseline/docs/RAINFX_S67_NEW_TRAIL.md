# RainFX s67: current GPU trails and startup pending — 2026-10-12

Status: ACTIVE — implementation and offline verification complete; game output/FPS verification pending.

## User result and scope

The user tested s66 and reported that the internal lighting problem was resolved.
Daytime 60% rain changed from 79 FPS without the app to 59 FPS with it; 100%
rain changed from 75 to 45 FPS. These correspond to total frame intervals of
12.66 → 16.95 ms and 13.33 → 22.22 ms respectively. The differences (4.29 and
8.89 ms) include the whole app and engine interaction, and are not isolated GPU
pass measurements. The 4096-slot heavy-rain case still requires optimization.

The remaining errors/defects were an `Optics shader/capture pending` traceback
at load, a delayed/discontinuous trail behind moving heads, and fast sheets
which did not refract. This step integrates the requested New Trail design.
It retains the accepted surface transport, downward-airflow option, native
visibility/shadow policies and E2/E3/E4 tuning.

## Causes and implementation

### Normal asynchronous preparation is not an error

`render.mesh()` can return false while its shader is compiling, even if its
owning GeometryShot returns true. Previously `requireUpdate` threw from inside
the C capture callback. `visor_optics.lua` now records capture-local pending
flags and retries the same bake step without publishing incomplete data.
Actual exceptions still restore visibility/render state and propagate.

The native-glass capture, legacy housing/depth source, primary reflection
resolve and geometry trace also distinguish callback pending from genuine
errors. Main Rain state/meta textures publish as a pair only after both writes
complete. The s66 async model/shader loading remains in use; s67 adds no
blocking compile loop or synchronous whole-atlas UV conversion.

### One path producer, two meanings

`rain_trails.lua` consumes the current GPU state and its previous bank after
the current head pass. The pipeline is:

1. Per-slot descriptor: previous/current UV endpoints, physical plane,
   footprint, height, sheet fraction and conservative bounds.
2. Sparse 24-bit tile masks and word summary at trail resolution.
3. One resolve: sweep each eligible segment, combine fresh water/clearance
   using max, and decay/diffuse previous history.
4. Publish history atomically with ready current heads.

The 1024×256 history contract is:

| Channel | Meaning |
|---|---|
| R | physical reference half-width × head-resolution/32 × liquid height |
| G | liquid height |
| B | sheet fraction × liquid height |
| A | independent micro/haze clearance |

All active wipe reads map A to the legacy clearance-G interface. Physics and
mirror water use liquid G. Old impact-film and wipe-ridge interpretation is
disabled in New Trail, preventing clearance from becoming a whole-visor lens.
Bare and wipe-only regions produce no liquid colour/refraction.

New Trail bypasses CPU WF/wipe stamping, the 384-stamp limit and delayed
readback/prediction for paths. The remaining CPU centre pass only previews
recent eligible impact splashes; it no longer builds head/tail/lobe/puddle
tables for every live GPU drop. The GPU head bounds no longer include long
swept paths; those are handled in the smaller trail canvas.
The composed resolve program is built once per module load; its source string
and uniform table are reused rather than rebuilt each frame.

WF disabled with wipe enabled clears stale splash-body overrides. Mode switches
and resizes clear published references before disposing old histories. Both
legacy canvases remain available when New Trail is disabled; both sets are
not retained at the same time.

### Shape, refraction and transport

Paths use a physical plane derived from the baked du/dv metrics, not a UV-axis
direction or square-texture assumption. Capsules connect every point between
current GPU endpoints and include both ends. Support checks exclude holes,
unsupported atlas joins, birth hold, absorbed/respawned generations and
stationary drops. Tiny drops can clear a path without depositing liquid.
Subpixel footprint coverage is a sampling correction, not an artist texel width.

Liquid height responds to supply, drop speed/diameter, coating, previous water
and shear. Thin films bead; thick sheets retain a curved profile and small
ripple rather than a flat plateau. Film overlap selects max height rather than
additive buildup. Coating reduces liquid height/lifetime while retaining wipe.
Pre-wet paths optionally reduce adhesion by at most 25%; existing force,
metric transport and steering remain in the current solver.

The optical shader uses metric offsets proportional to footprint diameter and
a bounded displacement proportional to projected diameter. A shared local
frame serves both derivatives and offsets, avoiding repeated metric texture
reads for the diameter-based controls. New Trail uses cylindrical refraction
even if the old trail-v2 toggle is off. Head lenses still use the head branch.

## Physical interpretation and design corrections

- `Ca^(2/3)` is a bounded visual thickness surrogate, not a calibrated physical
  thickness solver. Film entrainment depends on wetting and contact-line
  regimes; classical LLD scaling is not universally valid for rolling coated
  visor drops. See the primary papers on
  [partially wettable film deposition](https://www.sciencedirect.com/science/article/pii/S000925092030364X)
  and [slip-dependent droplet film deposition](https://www.cambridge.org/core/journals/journal-of-fluid-mechanics/article/film-deposition-and-dynamics-of-a-selfpropelled-wetting-droplet-on-a-conical-fibre/A3D2C9B6CBD72A55B6B305AAE17123FA).
- Supply is bounded rain + current density, with an optional track-puddle
  speed/facing proxy. SDK `rainWater` describes track puddles; it is not a
  measurement of preceding-car spray. The proxy defaults to zero.
- SDK track wetness does not impose a visor wetness floor. Visor W approaches
  supply exponentially (3 s rise, 20 s dry, accelerated by shear), once/frame.
- Pure exponential decay is equivalent over matched time intervals at 30/60
  Hz. Deposition, diffusion and changing inputs are not equivalent. Deposition
  remains every frame to keep paths connected to current heads.
- A frame's sweep is a local capsule, not a saved curved substep polyline.
  Sharp metric/sticker turns in unusually long steps can still be approximated
  by a chord. The existing adaptive physical transport remains responsible for
  the actual drop trajectory. User video is needed to assess remaining corners.
- Lifetime is reconstructed from the stored width/sheet code and current
  wetness/coating. It is an approximation; no extra per-pixel lifetime texture
  or full fluid conservation/film-merging solver is added.

## UI and migration

New Trail is enabled by default with a toggle and path debug. GPU heads are
required. Its liquid/wipe panels share one UI:

- widths and gradient radii: multiples of drop/footprint diameter D;
- minimum footprints and film-producing drops: mm;
- speed gates: mm/s;
- recovery and wetness response: seconds;
- optical displacement: projected footprint D, bounded by screen pixels.

Active head-gradient controls use D, micro-rim controls use disk D, and splash
reference/minimum piece sizes use mm. Their initial values convert the current
texel tuning once, then remain fixed across atlas-resolution changes. Canvas
resolution, micro sampling quality and actual screen-displacement pixels
retain their units because they describe sampling/output rather than object
length. The inactive legacy mode retains its old settings and UI.

`material_settings.lua` persists New Trail, shared trail/sheet and clearance
controls with the existing runtime-key mechanism. No source or installed
settings/profile files are rewritten by this delivery.

## Verification

Artifacts: `docs/diagnostics/2026-10-12/s67/`.

| Check | Result |
|---|---|
| LuaJIT production syntax and module/runtime replay | pass |
| 4096-slot module lifecycle | five bounded allocations; async retry reuse, paired current publication, resize cleanup |
| Settings round trip | New Trail/mm/D, shared flags/values and existing materials preserved |
| Shader compilation | 28 Rain/glass and 13 optics variants; `/Ges /WX`, no warnings; ≤11 textures |
| Production D3D11 readbacks | connected endpoints/intermediate samples; skewed metrics and holes; max overlap; birth/generation/stopped exclusions |
| Film/clearance | tiny drops wipe without liquid; coating thins; high shear thins |
| Lens | continuous sheet shifts image; bare and wipe-only output exactly zero |
| Shared local lens frame | head/trail output delta zero against independent helper calls |
| Actual baked mesh, 4096 slots | 3826 eligible descriptors; liquid/wipe present; unsupported output exactly zero |
| Head candidate comparison | 17169 → 10590 tile candidates, 38.32% fewer; water RGB delta zero |
| Narrowed CPU replay | 4096 live records with 20 eligible splashes require 20 previews, no CPU trail stamps |
| Pure decay at matched time | 30/60 Hz delta ≤5.97e−8; deposition stays every frame |

At 4096 slots /1024×256, the new descriptor/mask/summary/history textures total
about 4.43 MiB of pixel storage versus about 12 MiB for the retired active
WF+wipe pairs. This is layout arithmetic, not measured engine memory.
Candidate counts measure eliminated work. WARP wall times include setup and
compilation and are **not game GPU frame timings or an FPS prediction**.

## Deployment and remaining game check

Reload the app to replace cached module/shader state. Source Lua/shaders are
linked into the game app; the new `rain_trails.lua` must also exist in the
installed folder (installed as a verified copy in this delivery). The existing
native-glass module link also resolves correctly. Delivery hash verification
is in `s67/delivery.json`.

After reload, inspect the same 60% and 100% daytime scenes: startup errors,
head/path attachment at high speed and sticker boundaries, thin/thick trail
transitions, sheet refraction, coating response and the accepted glass/light
output. Render Stats exposes `RealVisor/*` leaf passes including `New Trail
descriptors`, `New Trail tiles`, `New Trail summary` and `New Trail resolve`.
Nested totals overlap. No s67 real-game FPS or appearance claim has been made.
