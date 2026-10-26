# s264 — compact SI-force/advection/ledger integration (2026-10-24)

## Implemented

`prototypes/s264/s264_coupled.lua` composes the inherited s156 physical relaxation
closure with s263 donor-cell advection. Every GPU substep now recalculates forces
from the updated local depth and momentum;velocity is no longer frozen as in s263.
The caller supplies an immutable world-metric cache,measured areas,connected runs,
physical material/weather rows and previously owned End packets.

1. Project old momentum to the local tangent. Apply full-substep analytical
   gravity/inertia and air-shear/viscosity relaxation,using unchanged s156
   `relaxFilm`. Produce full End and full Mean,plus force impulse and normal-wall
   exchange. The original s156 public donor used half-End;this candidate explicitly
   uses full End for a first-order force→advection split.
2. Project the new Mean world velocity through the metric/Gram cache into cells/s.
3. Compute bounded outgoing donor fractions and gather End packets conservatively.
4. Carry cumulative runoff,force impulse and wall exchange as accounting bands.
5. Reduce a six-row water/momentum/diagnostic ledger and generate a small identity
   and time receipt. The next numeric receipt verifies the prior identity/acceptance;
   stale identity produces rejection and no accepted time increment.

The ledger relation is:

`final End + cumulative exit + cumulative wall = initial End + cumulative impulse`.

Force impulse and wall exchange have exactly zero mass. Numerical packet
conservation is checked separately from a valid-looking aggregate volume.
Display diameter gain is absent. There is no birth/source arrival,evaporation,
micro reservoir,coating response or optical publication in this controlled film.

## Cached construction and cost scope

`compile()` builds4/8/16-substep templates once. `bind()` supplies fresh small
uniform/texture maps without rebuilding shader bodies or calling the old
`Reference.recipe`/85-pass graph constructors. Cached templates and prior bound
plans remain isolated from caller mutation.

| Represented interval | Substeps | Force/advection/ledger/receipt draws |
| --- | ---: | ---: |
| ≤1/60s | 4 | 20 |
| ≤1/30s | 8 | 36 |
| ≤50ms | 16 | 68 |

There are four full-field passes per substep,three ledger reduction passes on
the1024×256 grid,and one receipt pass. No intermediate CPU result is required by
the plan. These counts exclude cache creation,input identity validation,source
generation,resource leasing,final commit and rendering. They are not whole-app
costs and must not be reported as an FPS improvement over s262.

Local module construction took0.0529ms and100 fresh binds had median recorded in
`checks.json` (about hundredths of a millisecond). This is local LuaJIT/host timing,
excluding module loading,shader compilation,assets,driver allocation and CSP.
The main app's former80.7245ms startup path is unchanged. The new construction
avoids that legacy graph builder by design;actual startup qualification is pending.

Working resources reserve50,430,560 descriptor bytes(about48.094MiB):force five
bands,one velocity plane,flux plus diagnostics,four state/accounting bands,
ledger tiles/reductions and two small receipt outputs. External initial state,
metric/area/run caches,physics inputs,CPU staging and driver alignment are excluded.
This is not a complete retained-owner or app memory measurement.

## Native validation

`tools/check_s264_coupled.py` runs178 strict native D3D WARP draws:

- Independent flat-surface SI relaxation against the analytical full-End result.
- Actual visor metric/topology and a measured-area adapter matching s163 semantics:
  raw coverage is not mistaken for validity. The fixture uses the retained unit
  physical scale;arbitrary scale/new pose admission is not tested here.
- Eight recurrent controlled-weather inputs,including one1/30s input,cover0.15s.
  Each substep recomputes force/velocity from the evolved End state. End volume
  remains nonnegative. The six-row cumulative ledger passes in every interval.
- Maximum absolute water residual is0.000214577mm³ over about790.124mm³ initial
  water;maximum relative residual is2.72e-7. Signed momentum closes with explicit
  impulse and normal-wall exchange. Final water plus runoff closes numerically.
- GPU time receipts chain through all eight inputs,within1e-7s of the test's
  represented0.15s. Stale predecessor identity rejects advancement. This tests
  receipt arithmetic,not a general GPU completion fence or public app clock.
- Six malformed physical parameter cases and seven malformed ledger cases refuse.
  Independent bound-plan mutation cannot alter the cache or an earlier plan.

Physics rows in this fixture are controlled:water density997kg/m³,viscosity
0.001Pa·s,gravity(0,-9.81,0)m/s²,air velocity(0,0,20)m/s,air density1.1865kg/m³
and the inherited skin-shear coefficient0.01. These are not captured live s264
engine inputs. A new force/advection split and donor-cell diffusion require
coupled visual/accuracy comparison before adoption.

## Ownership and remaining connection

**This is a provisional numeric plan,not a transactional game owner.** It writes
its work state before the final receipt is validated. The next integration must
keep the last accepted physical stock/ledger separate and select/commit only on
a valid owned receipt. An invalid receipt cannot authorize publication of this
provisional state. Do not simply alias `prior` to publicly committed work storage.
Input identity,immutable cache generations and invalid material/geometry rejection
must be supplied by the existing physical admission boundary.

Native draws use per-pass CPU readbacks. Actual ordered CSP resource reuse and
continuous GPU submission are unqualified for this new plan. No main app file,
public s87 effect or game UI has changed. No new user experiment is requested.

Next connect the cached plan to the retained private executor with validated
input leases and a GPU-gated commit of stock/time/ledger. Then use one integrated
actual continuous/startup gate. Head/source/optical integration and2048/4096-slot
product performance remain later work. Do not multiply isolated timing probes.
