# RainFX roadmap (accepted items, not scheduled) — updated 2026-10-14

See `docs/README.md` for the document index and working rules.

## Latest s77 P1 persistent SI motion preview (2026-10-14)

Connected true volume/mm3, SI contact forces and world gravity/inertia to
persistent state/meta with independent head display gain. Opt-in preview
defaults OFF and omits Smear/legacy film/trail/wipe/splash/micro/haze. Mode
changes dispose banks and reject stale epoch readbacks. Active state/meta
entries now use initialized single-exit external programs, resolving the
reproduced X4000 without warning suppression. /WX WARP checks cover legacy
OFF identity, SI codec/rotation/display invariance, V/momentum merge and
the macro variants; LuaJIT wiring checks cover pooling/reset/publication.
Actual game preview confirmation and P2/P3 supply/impact/film remain next.
See `RAINFX_S77_SI_MOTION_PREVIEW.md`.

## Latest s76 SI core primitives and observed inertia (2026-10-14)

User stationary G=0 and acceleration/braking Z signs establish gravity-free
car acceleration; adapter now exposes its reversed world vector as inertia.
Added the P1 shared GPU primitives for true volume/mass, contact-cap shape,
static/dynamic pinning, cap air drag, stiff viscous/contact integration, SI
Jacobian projection and volume/momentum merge. FXC /WX + D3D11 WARP checks
pass, including display/UV independence. Persistent state/renderer binding,
DSD/virtual impact and conservative film remain subsequent implementation.
See `RAINFX_S76_SI_CORE_PRIMITIVES.md`.

## Latest s75 P0 weather inputs and physical units (2026-10-14)

Started implementation from user-published 3975491 on the physics branch.
Added an independent allocation-bounded weather/phase observer and physical
unit/contact-cap helpers, connected to an explicit RainFX P0 diagnostic panel.
Valid zero/fallback, kPa/Pa, snow/sleet/hail transitions, raw G/world basis and
skewed geometry metrics have LuaJIT fixture checks. Companion modules are
installed with hash-guarded copies. Existing physics/shaders/tuning remain
the baseline while P0 observes actual G/wind/metric inputs. Stationary,
accelerating and braking snapshots requested before SI inertia activation.
See `RAINFX_S75_WEATHER_INPUTS_AND_UNITS.md`.

## Latest s74 Core implementation scope and branch (2026-10-14)

The user preserved the legacy at commit 0c092e0. Implementation now targets
`codex/rainfx-physics-weather`, derived from that commit. First build the
physical drops, virtual impact, flow and volume-based trail/rivulet/sheet.
Exclude Smear from the core path and do not port legacy local impact film.
Keep physical impact/deposition; evaluate correction effects only after the
core water behaviour and rendering have been reviewed. Smear remains a
possible removal, not a decision to delete its legacy code now. Updated s73
scope accordingly. This step changes documentation only.
See `RAINFX_S74_CORE_IMPLEMENTATION_SCOPE.md`.

## Latest s73 Physics/weather refactor design (2026-10-14)

Design only; runtime and user tuning unchanged. Verified the user's updated
6 px/mm at 4096x1024 reference. Audited mixed SI/normalized masses, reference
force/speed calibration and trail-only diameter x3. Proposed volume-based
surface state, contact-angle pinning, independent display-size gain,
filtered CSP weather/phase adapter, estimated DSD/flux and birth-only
virtual impact. Track water and RH have separate physical roles; effect
gates share actual local water state. Reuse existing GPU slots/sparse
sweeps; film transport/absorption/children follow explicit cost gates.
s72 remains the live implementation until the staged model is implemented.
See `RAINFX_S73_PHYSICS_WEATHER_REFACTOR_DESIGN.md`.

## Latest s72 Trail sampling/model calibration (2026-10-13)

User confirms current head/micro size profile is appropriate, but observes rough
traces and no thick-film response at those diameters. Reproduced segment phase
resets and unresolved noise/ripple frequencies; added carried generation phase,
projected pixel integration/bandlimit and a half-history-texel derivative floor.
Water-model diameter ×3 / thin-output compensation 1/3 retains accepted head,
micro and thin/wipe sizes; developed sheets use model width and radius-scaled
thickness. Deposited ordinary-film history reaches the production lens (alpha
0.953, bare-visor contribution zero in the controlled test). Additional metadata
384 KiB, no new full-atlas pass; actual 4096-slot model-width candidates +0.148%.
Actual game FPS and remaining true trajectory/chord corners need confirmation.
See `RAINFX_S72_TRAIL_SAMPLING_AND_DIAMETER.md`; this follows the s70 diagnosis.

## Latest s71 Smear red-region correction (2026-10-13)

User reports green/high-G smear looks correct but red/low-G areas do not,
at 100% rain, 220–287 km/h and density 1.00–1.50. Reproduced two bypasses:
raw clearance erased low-G classes and restored opaque heads; neutral trail
coverage ignored G visibility. Class wipe now uses pre-erasure path/G weakening,
and neutral trails use the existing trail visibility control. Colour/presence
share symmetric class interpolation. Numeric/bool Smear UI settings now persist.
No default tuning, physics or render pass changes. High-G endpoint and smear-off
outputs are identical in controlled GPU replays; actual game validation pending.
See `RAINFX_S71_SMEAR_RED_REGION.md`. s70 trail calibration remains open.

## Latest s70 Trail visibility evaluation (2026-10-12)

User confirms s69 G-force conflict and memory leak resolved, then reports no
visible New Trail refraction. Current saved width is 0.26 D. Production-shader
readbacks show ordinary coated 0.65 mm paths can disappear between atlas rows;
aligned paths reach G=0.0512 but only 4.32% alpha and 0.0124 px shift on the
controlled projection. Actual baked coated samples show the same strong
suppression. Thickness starts above 1.3653 mm/s and 0.20 mm, but max history
does not add water mass and legacy sheet height floors are inactive. Subpixel
deposition and optical calibration need correction within the existing passes.
Runtime/tuning unchanged by this evaluation. See `RAINFX_S70_TRAIL_VISIBILITY.md`.

## Latest s69 G-force/memory follow-up (2026-10-12)

User isolates FX loss to moving G-force transforms; profiler shows 2297.72 MB,
GC 58.1% and merge/splash hotspots, with repeated 5-FPS stalls. Moving native
mask GeometryShots now prepare before main rendering. Reproduced and removed
CPU splash-history growth and a retired New Trail queue without a consumer.
4096-slot merge scratch reuses an ascending linked grid: identical commands,
99.67% less allocation in the offline workload; CPU median remains similar.
Current motion/tuning and GPU physics retained. The user subsequently confirms
G-force conflict and memory leak resolved. See `RAINFX_S69_MOTION_AND_MEMORY.md`.

## Latest s68 FX/UI follow-up (2026-10-12)

User reports FX disappearing near automatic driving and returning with ESC,
plus an invalid native-state tree UI call. Fixed the confirmed tree callback
contract and reproduced a frame-only guard suppressing another render view.
FX completion now belongs to a main view/target, pending stages retry and
successful items do not composite twice. Added independent authored-convex
E2/E3 dark tint, default neutral, with UI/persistence and HDR shader checks.
The exact automatic-driving trigger and real-game recovery remain to verify.
New Trail review follows that confirmation. See `RAINFX_S68_VIEW_AND_CONVEX_TINT.md`.

## Latest s67 New Trail follow-up (2026-10-12)

User confirms s66 lighting repaired and daytime 60% rain at 79→59 FPS,
100% rain at 75→45 FPS. Normal async pending no longer throws from owned
optics/capture callbacks. New Trail combines current-GPU liquid and wipe
segments in one 4:1 history, removing delayed CPU path stamps and their budget.
Head bins exclude swept-path work (38.32% fewer candidates at 4096 slots,
identical water RGB). Diameter/mm controls retain physical size across texture
resolution changes. Production shader, lifecycle, lens, skewed/actual-baked
mesh and hole checks pass. Real game FPS/appearance remains pending.
See `RAINFX_S67_NEW_TRAIL.md`.

## Latest s66 startup and missing glass follow-up (2026-10-12)

The installed native occlusion module was still absent, blocking both glass
passes and their diagnostic. Measured cold head-kernel compilation at about
50 seconds; shared channel loops reduce this to about 1.5 seconds with identical
water RGB. Shader/model loading is asynchronous, pending GPU builds avoid CPU
fallback, and the obsolete full UV lookup is skipped in the shared GPU mode.
Glass and E1 tests have independent pending/Rain-off routing. Scoped offscreen
captures and explicit generated Rain shadow disable address additional state
risks. Wrapped colour/depth warning now reproduces and is fixed without
suppression. Settings and current concurrent tuning edits retained. Complete
game installation, load/FPS/visibility/sunlight verification remains required.
See `RAINFX_S66_STARTUP_AND_GLASS_DIAGNOSIS.md`.

## Latest s65 rendering/cost follow-up (2026-10-12)

Previous game experiment omitted both native modules, so its FPS/lighting and
layer results are not a complete-runtime baseline. User supplied CPU profiling
(scene-ready 3.18 ms, merge/tap hotspots), reports ordinary mesh occlusion fixed
and remaining FX hidden. Fixed the unset post-rain INT readiness flag, added
Rain's scene/native depth rejection and explicit submission state. Smear uses
filtered class mixing and a parameter-only 4:1 mask cache. Physical ribbons and
supported preview/history connect, and current GPU sweeps refresh wipe paths
without raising the CPU 384-stamp budget. Bounded/sparse tile work and specialized
depth remove repeated work. Saved settings and actual GPU physics remain.
Game GPU timings and recovery to former total cost remain pending.
See `RAINFX_S65_LAYER_TRAIL_COST.md`.

## Latest s64 urgent performance follow-up (2026-10-12)

User reports daytime 60% rain falling to 15 FPS while driving. Reproduced an
unmeasured merge CPU hot path (roughly 20 ms to 2.2 ms in the current 2000-record
offline replay), removed unsupported predicted grid entries/string keys,
reused adaptive GPU Jacobians, gated empty merge/wet-path/held-state work and
disposed CPU readback copies. Corrected downward airflow and the missed live
s63 native-glass mask hook; added native hard-shadow comparison and actual
Render Stats CPU/GPU intervals. Existing E2/E3/tuning retained. Actual recovery
to the previous game FPS remains pending. See `RAINFX_S64_BOTTLENECK_AIRFLOW_LIGHTING.md`.

## Latest s63 follow-up (2026-10-12)

User accepts E2/E3 and the new physical drop directions. Daytime 60% rain still
reports below 36 FPS versus the former 56–60 FPS. Fixed a zero-Jacobian inverse
that could expand wipe/trail/splash kernels across the visor; bounded CPU paths
and placed splash pieces in the actual surface plane. Added non-compositing
native exterior glass occlusion for custom glass/E4 output and further GPU/CPU
head-work reductions. Offline checks pass; new game performance/appearance is
pending. See `RAINFX_S63_GLITCH_AND_NATIVE_OCCLUSION.md`.

## R1. GPU drops pre-laid like the micro pattern — accepted for 0.6.0 (2026-10-07) (`RAINFX_GPU_PRELAID.md`)

Source: `RAINFX_REVIEW_2026-10-02.md` §1.

**Goal.** Control many more drops smoothly, with birth sites laid out in
advance and selected by intensity, as the micro pattern does.

**Plan, in order.**
1. **GPU-side WF head stamping.** Draw the WF head canvas from the state
   texture (`txRainState` / meta) with an instanced or point-sprite pass;
   removes the per-drop CPU loop in `waterFieldDrawStamps`.
2. **Atlas-driven respawn.** R1.2 prototype bakes valid visor-UV sites and
   stable activation order on the GPU, behind a toggle. In-game validation
   is pending; size class remains on the existing birth-size path.
3. **Raise the state texture size** (10k+ slots) once 1 and 2 hold. A
   sparse-word GPU head pass is now behind a toggle for scaling tests;
   CPU trail/splash/readback work still needs bounding before 10k+ slots.

**Current result (2026-10-07):** user accepts the current RainFX for release.
R1.1–R1.4, local impact film, sheet tuning and grouped UI form the 4096-slot
baseline. User captures reached roughly 50+ FPS in the demanding scene;
instantaneous captures are variable and are not a universal FPS guarantee.
Further particle-cap increases are not a release requirement.

## Deferred RainFX movement finish — user request, no date scheduled

- Use currently available physical inputs to produce naturally curved paths
  rather than excessively straight movement.
- With no sustained driving force, let water gradually lose speed and stop.
- At Rain or higher intensity, allow appropriate downward flow while parked.
- Separate tuning factors for adhesion, external acceleration, curvature,
  dissipation and rain feed so adjusting one goal does not break another.
- Preserve the accepted trail/film appearance and physical coordinate model.

Do not implement these changes in the 0.6.0 release. No reminder or automatic
execution time was requested; this is a deferred engineering backlog.

## R2. Visor scene stack and glass optics — resumed after 0.6.0 integration

Replaces the former "R2 visor glass pass" (`RAINFX_VISOR_GLASS.md` §3.C/§4).
Work and open items: `RAINFX_VISOR_LAYER.md` §17–§20.
- S2 verification of the scene stack (order, brightness).
- Shadows and local lights for the custom housing.
- Shadow signal for the glass optics (§15.1).
- V3 glass base (E2 relief normal, E3 lens/tear, E4 band transmission).
- V4 light effects (E1 strong-light projection, E6 scratches, E7 interior
  projection).

## Closed / withdrawn
- Post overlay (P0–P4, HUD lift): **archived** 2026-10-04
  (`RAINFX_POST_OVERLAY.md`).
- `RAINFX_WATER_FIELD.md` backlog #3 (metallic non-sky contrast with many
  large drops): **closed 2026-10-05**, not important; re-open if it recurs
  in the latest build.


## s61 — new KN5 / independent 4:1 UV migration (2026-10-12)

User authorized adapting all affected processing to the rebuilt KN5. Completed:
new FX/Rain mesh names; geometry Jacobians and physical birth/merge/transport;
absorbing holes/edges; coating/bare-glass coefficients; rectangular surface
canvases and independently transferred materials; E1 eight-mesh captures and
native FRAME_MAIN two-sided output; native Visible preservation; optional water
mirror pass with no glass-optics captures; stale asset gates and ordered rebuild.

Offline Lua, geometry, shader compilation and D3D11 WARP checks pass. Actual CSP
appearance and frame time remain to be verified. See
`RAINFX_KN5_4_TO_1_MIGRATION.md` for assets, commands and diagnostic views.
This is the user-requested coordinate/KN5 migration; the separate creative
RainFX movement finish listed above remains deferred.


## s62 — output / warning / cost correction (2026-10-12)

User game captures exposed black EXT, fixed E2/E3 marks, broad rain ghosts,
missing micro drops and increased cost after s61. Corrected band-alpha semantics,
optical frame/incidence/delta composition, DLSS source alignment and micro
pending/metadata handling. Added per-drop metric cache and bounded physical
birth lookup; removed unused mesh uploads and CPU cap triangle expansion.
Strict warning-free shaders and D3D11 WARP/Lua checks pass. Actual new game FPS
and reference matching remain unmeasured. See RAINFX_S62_OUTPUT_AND_COST_FIXES.md.
