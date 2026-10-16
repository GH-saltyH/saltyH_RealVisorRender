# s64 — Rain CPU bottleneck, physical airflow and native glass follow-up

2026-10-12. Status: **REFERENCE** — implemented, offline replay / Lua / HLSL
verified. Actual CSP FPS recovery and sunlight appearance remain unmeasured.

## User result

E4 still covered native glass in the main camera; mirrors excluded custom glass.
Native INT appeared above physically exterior EXT. Frontal sunlight left the
opening/interior unusually dark, while local lights illuminated it. Driving in
daytime 60% precipitation reached about 15 FPS versus the old 56–60 FPS range.
The enabled downward-airflow option appeared to drive water upward.

Current files/settings were preserved in `diagnostics/2026-10-12/s64/baseline/`.
E2/E3 appearance controls, particle population, size/force/speed gains and the
user's existing profiling additions are retained.

## Reproduced CPU bottleneck

`updateMergeCommands()` was excluded from the old birth/WF timing display.
It independently linearly predicted raw UV, then sampled positions even when
the predicted centre had left valid geometry. Unsupported pixels returned
zero positions, while outside coordinates clamped to atlas edges. These points
collapsed into dense spatial buckets and could consume the 256-pair merge
budget with artificial contacts. The search also built 27 string keys per live
drop, allocated a three-component point table per drop, and reconstructed a
physical plane for every neighbour candidate.

`bench_s64_cpu.py` executes the real previous/current Lua with current tuning,
the actual KN5 geometry bake and 2000 seeded records. It excludes CSP draw calls
and GPU work. Its moving fixture uses 1.4 reference units/s along projected
gravity (~0.478 m/s at scale 1), not a recording of the user's precise car state.

Latest replay (median of five warmed runs):

| Condition | s63 merge CPU | s64 merge CPU | Unsupported points in grid |
|---|---:|---:|---:|
| stationary | 9.73 ms | 2.62 ms | 0 → 0 |
| moving | 20.01 ms | 2.16 ms | 637 → 0 |

Other runs varied from roughly 17–22.5 ms to 1.8–2.2 ms for the moving fixture.
These are this machine's offline CPU measurements, **not new game frame times**.
Stationary valid pair count remained 68. The moving fixture now also finds 68
valid pairs instead of saturating the budget with unsupported points.

Changes:

- Reuse the supported, bounded CPU preview and reject unsupported source points.
- Use collision-free numeric grid keys with dynamically computed extents and
  neighbour padding; retain 3D physical distances and the full neighbour search.
- Reuse coordinate/cell arrays, rather than allocating a point table per record.
- Compare squared contact distances; use actual 3D velocity for the attraction
  cone. Stop merge selection after its existing pair budget is reached.
- Empty command snapshots keep `mergeActive=false`, including cached calls.

## GPU work and readback lifecycle

- Adaptive transport carries each step's Jacobian into the next step and reuses
  it for momentum, projection and speed. Per valid step, it needs the next du,
  dv and boundary taps instead of repeatedly loading the same frame. The 1 mm
  interior step, conservative boundary refinement, 128-step limit, absorbing
  boundaries and transported inertia remain. Old/new WARP trajectories and
  exit classifications matched exactly in the .016/.05 s fixtures.
- State merge decoding now runs only on slots with an actual merge/attraction
  command. Metadata merge decoding skips attraction-only commands as those do
  not change mass or radius. Previously even empty commands paid for partner
  texture reads and physical projections when any slot had a command.
- Wet-path work skips disabled steering, zero time steps and speeds where its
  existing gain is mathematically zero. Motionless birth-held states bypass
  force/drag integration after merge handling.
- Accepted, stale and error readback paths dispose owned `ExtraCanvasData`.
  Readback processing time is reported separately, reducing reliance on GC for
  per-frame CPU texture copies.

## Airflow option was connected, but its meaning had changed

The car/wind velocity, force enable bits and downward gain still reached the
state shader. The migration replaced the old signed UV-down treatment with
world geometry projection, but its downward mode **added** a capped downhill
term while retaining the original upward aerodynamic tangent component. At
driving pressure, that original term could overpower the added component.

Downward mode now replaces the airflow component along physical downhill and
retains the lateral component. Downhill comes from world gravity projected onto
the actual Jacobian plane. The supplied smooth object normal still determines
air incidence. This distinction prevents smooth-normal/triangle differences
from leaking the redirected force sideways. UV U/V can remain arbitrarily
rotated, stretched and skewed. Gravity, inertia, adhesion, drag, speed caps,
wetting and actual UV transport still use the existing physical model.

With actual geometry, scale-1 model rotation and 50 m/s frontal relative air:
842 of 1710 active tested samples were upward under the previous enabled option;
the new option had zero upward samples. A 15/0/−45 m/s crosswind had 810 upward
samples before and zero after. Lateral difference against the original option-off
airflow was below 1.2e-5. This verifies the airflow force itself; total motion can
still include prior inertia, car acceleration and gravity on the curved surface.

## E4: correct the missed live integration

The s63 mask module and shaders were implemented, but its setup/update block was
mistakenly inserted in the archived HUD overlay function. Its `phase` condition
never ran on the active scene path. Component tests did not catch that missing
connection. This was an implementation error, not evidence that the main-camera
mask worked.

The block now runs in the live `visorSceneStack` before its glass draws. Runtime
tests explicitly spy on that call and verify that a pending mask stops the post
optics path. Mirrors still use their independent water-only callback.

Camera-facing native exterior glass owns its covered pixels irrespective of
small interleaving/depth differences between independently modelled FX and native
surfaces. Custom layers and cached HDR E4 discard those pixels; native colour
is never mixed into a custom pass. Back-facing native exterior normals do not
mask the inside view. Visible controls and static relative-pose cache remain.
When all native sheets are missing/hidden, no camera pose/capture is requested.

## Native EXT/INT ordering judgement

Both use `ksPerPixelMultiMap_emissive`, alpha blending, the transparent-mesh flag,
KN5 default depth field 0 and `emAlphaFromDiffuse=1`; both have `isAdditive=0`.
The local native pixel shader returns diffuse-alpha/reflection output and has no
inter-mesh ordering mechanism.

Front-facing ray intersections from two exterior model-local views found EXT
in front on all 110 + 96 common sampled rays. The model therefore supports the
user's exterior/interior ordering in those samples. They do not cover every
view/triangle. The observed overwrite is consistent with native transparent
mesh ordering/depth/blending, rather than an inversion established by this
geometry inspection or a special INT shader branch. Alpha layers can also show
inner output through outer glass even in the correct order.

Actual CSP depth/cull overrides and draw order cannot be inferred fully from
KN5 field 0. The KN5 panel now exposes each native sheet's runtime transparent,
blend, depth, cull and shadow states. Material shader/alpha/depth/cull settings
remain authored. Forcing a transparent whole EXT lens to write opaque depth
would remove internal layers and is not a physically correct general sorting fix.
A deterministic multilayer native result requires explicit ordering or separating
the opaque printed band from transparent lens geometry; it is not supplied by
changing the pixel shader's specular/roughness parameters.

## Sunlight and previous processing

The migration restored normal main/mirror visibility for the native MRR sheets
and preserved their authored render/shadow states. The inspected new KN5 marks
**all four native glass sheets as shadow casters**. This can put opaque cascade
shadows across the opening; local-light illumination can still be different.
Earlier cached lighting also added opening/SH/sky visibility constraints, but
s63 did not lower the user's diffuse/ambient/light/tint settings. E4's missed
mask additionally allowed custom optical output over native exterior output.

`native_glass_state.lua` now disables native glass hard sun shadows before engine
shadow-list preparation. Frame, band, fabric and actors retain their shadow and
Visible states. Geometry/material colours/opacity are preserved. Original flags
are saved and restorable. This lets native sunlight reach the opening; cached
optics retains its existing tint/transmission treatment. It does not implement
coloured partial transmission in the native shadow map.

KN5 panel comparison: **Native glass casts hard sun shadows (comparison)**
(`RAIN_VISOR_LAYER_NATIVE_GLASS_SHADOWS`, default false). This permits checking
the causal sunlight difference in game without changing material brightness.
Actual sunny-view recovery still needs the user's game comparison.

## Profiling the remaining real-game budget

The existing **CPU timing and diagnostic counters (profiling)** toggle now enables
the installed SDK's `render.measure()` CPU/GPU records in **Render Stats**:

- `RealVisor/Merge CPU`, `State transport`, `State lifecycle`;
- `Head metric`, `Head tiles`, `Head kernels`, `WF trail + film`;
- `World refraction capture`, `Refraction tone + copies`;
- `Rain colour`, `Rain depth`, `Native glass mask`, `Glass pre`, `Glass post`.

The Lua panel also reports merge/readback CPU time, candidate checks and largest
bucket. Nested totals overlap, so compare leaf passes rather than summing totals.
Measurements default off and do not allocate timing closures when off. This
replaces the prior inference from GPU submission clocks with actual engine
GPU timings. Real 15 FPS (~66.7 ms) to 56–60 FPS (~16.7–17.9 ms) recovery has
not been established by the offline replay.

## Verification

- Full LuaJIT syntax, cached optics/E2–E3/source lifecycle and material-settings
  regressions pass; settings files are byte-identical to the s64 baseline.
- 16 production Rain/glass variants, 13 optics variants and final physics
  variants compile with FXC /Ges /WX; actual bindings remain within 11 textures.
- `check_s64_runtime.py`: live native hook, pending gate, shadow policy/restore,
  unchanged frame visibility/shadows, measurement return/error semantics,
  disabled empty-merge cache and all readback disposal paths.
- `check_s64_gpu.py`: physical downward/crosswind forces, lateral preservation,
  unchanged adaptive paths/exits and seeded active state empty-command,
  attraction, merge and birth-hold paths (<3.1e-7 state delta with downward mode
  off). Initialization/respawn is compiled separately in the unchanged full
  production entries; the artificial active-state wrapper excludes those
  branches to avoid its FXC helper-return false-positive.
- Existing surface-hole/no-wrap, EXT/E2/E3/micro and native coverage GPU checks.

Diagnostic JSON: `merge_benchmark.json`, `physics_gpu_checks.json`,
`native_layers.json`, `runtime_checks.json` in `diagnostics/2026-10-12/s64/`.
Reload the Lua app to load the new sidecar and inline shaders, then compare the
same daylight 60% driving view and the Render Stats leaf timings.
