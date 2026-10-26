# RainFX s96 — recurrent curved SI force, height and evaporation

Date: 2026-10-16
Status: ACTIVE — offline coupled prototype; not adopted into the game

## 1. Scope and result

Extend s95's immutable interval/checkpoint protocol so **each attempted substep**
recomputes SI momentum from the current film volume/area, transports its physical
end and interval-mean packets, projects onto the recipient tangent plane, and
evaporates water there. Only an admitted attempt changes physical stock, impulse
budgets or consumed time. Force/geometry snapshots are bound to pending work.

The specified analytic, retry, actual-curved-geometry, symmetry and ownership
checks pass. A separate counterexample exposes an unresolved physical closure:
s93/s94's coherent numerical point has a position witness but **no physical
footprint area**. Applying independent resolved-cell thickness drag to its CIC
copies gives different velocities. This is an adoption blocker, not a passing
physical-point model. Section 6 records it quantitatively.

Production physics remains s87, with the existing s89 diagnostic view. Root Lua,
production shaders, assets, tuning and user materials are unchanged. No install,
game reload/log request, commit or push.

## 2. One accepted substep

1. Read the s95 GPU plan's dt and the private **physical end** packet.
   The previous substep's mean velocity is not reused as new physical inertia.
2. Load actual metric/area and transform the tangent plane to world space.
   Resolve current height as `h_m = volume_mm3 / area_mm2 * .001`.
3. Project the incoming momentum onto this tangent plane, retaining the removed
   normal component as an initial wall reaction. Integrate gravity/inertia,
   prescribed air shear and viscous relaxation over the planned dt.
4. Generate separate physical end and interval-average world momentum packets.
   Both have exactly the same volume. The transported mean supplies each split
   axis's metric-aware UV velocity; the end packet remains physical inertia.
5. Execute s94's X/Y candidate transport and its existing admission checks.
6. At each destination, project transported momentum onto its current tangent
   plane. Record the removed component as a final wall reaction. Evaporate at
   `area_mm2 * evap_um_s * .001 * dt`, limited by remaining water, removing the
   same fraction of end/mean momentum. Shared packet volumes remain identical.
7. Validate the position witness after volume removal; reduce applied impulse,
   wall reaction, evaporation and invalid-cell status.
8. Publish this private substep and its ledger only if both axes and physical
   readiness pass. Otherwise keep all prior private stocks/ledgers and halve dt.
   The s95 public interval still waits for its complete time debt to finish.

Source/P4b staging remains once per immutable interval. Unlike s95, evaporation
is no longer applied once up front: the physical rate is applied to current
recipient area and water on each admitted substep. A GPU-selected dyadic maximum
substep caps fresh intervals; the default prototype cap is 1/60s and is part of
the frozen physical input snapshot. Invalid wet geometry refuses the attempt;
it must not erase water to make a valid-looking result.

## 3. Force equation and numerical limits

Use the s88 depth-averaged, frozen-height closure with the existing coefficients:

```text
du/dt = a_t + 3*tau_air/(2*rho*h) - lambda*u
lambda = 3*mu/(rho*h²)
tau_air = .5*rho_air*Cf*|air_t|*air_t
rho = 998.2 kg/m³, mu = .001002 Pa·s by default
```

These are world metres/seconds, physical mm³ and baked physical cell areas.
Display diameter, texel gain and render radius are not inputs. Existing air
downward handling and Cf convention are preserved. Prescribed air shear is
still a reduced closure; no pressure/contact-line model or full CFD is added.

The exact frozen-height response is evaluated in two numerical forms:

- For `x=lambda*dt < .1`, fourth-order phi series avoid subtracting nearly equal
  values in the interval mean. Against independent float64 `expm1` evaluation,
  observed maximum packet errors are below 8.70e-9 end / 7.63e-9 mean in the
  specified 2–5000µm test. This also improves the cancellation seen with the old
  `.01` cutoff in the new coupled path; the old prototype is preserved.
- In the stiff regime, use terminal terms
  `a_t*rho*h²/(3*mu) + tau_air*h/(2*mu)`. This avoids an infinite `tau/h`
  intermediate multiplied by a vanishing response for very thin water.
- The zero-viscosity limit is implemented for an analytic rejection fixture;
  it is not the selected viscosity for real water.

Height is frozen only **within** a substep and recomputed before the next one.
The force/evaporation splitting is consequently a numerical approximation.
Kernel convergence at fixed area does not establish spatial film convergence.

## 4. Budgets, history and snapshot ownership

The cumulative packet ledger extends s95's five banks to seven, with seven
Kahan correction banks:

| Bank | Meaning |
| --- | --- |
| 0 | external field input |
| 1 | accepted evaporated physical packet |
| 2 | accepted physical end runoff |
| 3 | internal pool volume and pool-to-rest wall momentum |
| 4 | mean runoff, diagnostic |
| 5 | accepted applied SI momentum impulse, zero water component |
| 6 | initial + recipient tangent wall reaction, zero water component |

The physical check is:

```text
final film + final head packets + evaporation + runoff
+ pool wall momentum + tangent wall reaction
- applied impulse - external input - initial stock = 0
```

Pool volume remains internal and is not counted as an external loss. Momentum
packet units are mm³·m/s; multiply by water density in kg/mm³ for SI momentum.
Mean packets are current-substep transport descriptors, not a second stock.

Body force and tangent projection change momentum without moving an existing
position witness. They must not clear it merely because momentum changed.
`stepEvapHistory.hlsl` therefore checks whole-image **volume** coherence after
evaporation, while preserving s94 topology, point-position and mass-image checks.
The stricter source-stage full-packet validator remains responsible for incoming
liquid mixing. Uneven evaporation invalidates all copies of an old coherent
image; it does not invent a new material shape or infer an aggregate height.

Force and metric headers identify epoch/base generation/interval and an exact
resource version. The checkpoint retains both version receipts. Changing either
version while its interval is pending cannot advance its state or time. The
receipt exports with the final stock/budget/clock under the same finish gate and
all-output host fence. Caller physics arrays are copied into immutable tuples;
geometry/cell arrays are copied and frozen. A real app must retain immutable
texture handles, scalar snapshots and their versions, not mutate content under
an unchanged version.

## 5. Verification

FXC ps_5_0 `/Ges /WX` and D3D11 WARP. Reports reside in
`diagnostics/2026-10-16/s96/`.

### Analytic force and changing height

- Independent float64 exact frozen-height end/mean response passes across
  2/20/100/500/1000/5000µm, including the initial normal momentum reaction.
- Repeated constant-height relaxation over .1s at 30/60/144Hz differs from the
  exact solution by at most 1.08e-7m/s in the specified kernel-only fixture.
- A constant-area drying stress case reduces 1mm to .9mm over .1s. Exact
  zero-drive velocity is computed by integrating `lambda(h(t))`. Frozen-height
  splitting errors decrease from .00083249 to .00041876 to .00017171m/s at
  30/60/144Hz. The prescribed 1000µm/s rate is an analytic stress input, **not**
  a weather tuning value. Spatial transport is excluded from this oracle.

### Actual transport rejection with nonzero force and evaporation

A dyadic planar/inviscid diagnostic has twenty compressing cells. The dt=1s
attempt admits X and rejects Y while having nonzero candidate impulse and
evaporation. Neither reaches the private ledger/stock. Two admitted .5s steps
then complete the interval.

- One-attempt calls and a single three-attempt call produce identical exported
  banks. The result also matches proactively capped .5s steps without the failed
  attempt, excluding an applied-on-rejection force/evaporation error.
- Source/P4b quantities remain one-time amounts.
- Water residual about −6.04e-9mm³; momentum residual at most 2.34e-10 packet units.
- The dyadic fixture avoids ambiguous near-equal projection ordering. It is
  not a real-water parameter preset or arbitrary collision-convergence proof.

### Actual curved geometry

Same synthetic 4,251-cell 100µm patch on the actual baked mesh; total .02s,
two .01s steps, actual viscosity, gravity and local air (5,0,−10)m/s. Includes
.01mm³ pool return, .004mm³ supplied water and ongoing .2µm/s evaporation.

- Both substeps admit; intermediate public banks remain unchanged. Split host
  calls and one two-attempt call produce bit-identical final banks.
- Water residual: −8.8291e-7mm³.
- Physical momentum residual including all impulses: at most 5.641e-8 packet units.
- Height changes by up to 40.6819µm before the second force calculation; final
  peak resolved height is 104.2928µm. There are 298 newly wet cells.
- Maximum final normal momentum is about 7.28e-11 packet units.
- A static 90° rigid world rotation of geometry transform, forces and supply
  momentum passes: relative volume-profile L1 about 6.74e-8 and maximum rotated
  momentum packet difference 1.58e-8. This excludes changing-frame inertial terms.

### Guards and publication

Stale force/metric versions preserve all public banks, private progress and time.
Unsupported wet cell area refuses an attempt without erasing mass. Injected
pending/error paths at force preparation and final snapshot publication preserve
caller-owned handles. Momentum-only projection preserves a valid position image;
nonuniform volume removal clears its complete image. Frozen snapshots are not
aliases of mutable caller arrays.

## 6. Explicit failure: coherent numerical points have no physical area

A coherent numerical film packet can be deposited with .7/.3 CIC weights.
The test uses .25mm³ total, .25mm² cell areas and .1m/s initial speed. Its
copies have resolved depths .7/.3mm. At dt=.01s, their independent viscous
responses differ by **.0224770m/s** despite having originated from one position
witness. This is not a physically justified breakup criterion.

The position witness fixed s93's specified force-free temporal counterexample.
It does not define material coverage, contact area or pressure. Dividing the
sum of its volume by an arbitrarily selected cell/area would add an unsupported
physical footprint. Restoring s92's hard fixed width would reintroduce its
continuous-film compression failure. Reusing rejected mixed spatial moments
would reintroduce s93's zero-motion redistribution.

Decision: do not claim that the coherent-point candidate is a complete SI film
model, and do not adopt it into the game. Retain the interval ownership,
SI integration, wall/evaporation budgets and diagnostic/reference machinery.
Next compare a fully resolved physical-area transport model with bounded
substeps before proposing any aggregate force law for numerical point copies.
A retained material-coverage alternative needs its own conservative area/shape
closure and compression/mixing proof. This issue remains open in the reports
as `unresolvedPointForceClosurePassed=false`.

## 7. Cost and remaining gates

The unoptimized graph is **17 + 33A draws** for A attempt slots: 50 for one,
83 for two. The actual two-attempt fixture records 83 submitted draws. It
includes source checks, physical budgets, loss probes, version receipts and
the all-output publication path. Inactive attempts still submit their shaders.

Force and post-transport diagnostic outputs are each 4H: 16MiB at
1024×256 RGBA32F before aliasing. Existing public/private stock is each 3H
(12MiB); source preparation is 2H (8MiB). Do not sum these as measured peak
memory; lifetimes must be fused/aliased in a runtime design. Final serial
reductions and diagnostic banks remain unfused. No game GPU-ms/FPS or leak
conclusion is drawn from the standalone readback/upload WARP harness.

Before adoption:

1. Resolve the physical area/force problem above and establish spatial/time
   convergence under meaningful compression, wet-front and coating conditions.
2. Couple the full P1 head lifecycle and P2 source/reservoir evolution; this
   stage holds returned head packets at rest and stages liquid supply up front.
   Local contact angle/pinning and surface-pressure effects remain open.
3. Implement bounded live immutable input backlog/recovery, including intervals
   that reach the s95 one-tick rejection limit. No time may be silently skipped.
4. Reduce passes/storage and eliminate production readbacks, integrate an opt-in
   game path, then measure actual cost. No user game tests are required now.

## 8. Reproduce and audit

```text
docs/tools/check_s96_physics.py
docs/tools/check_s96_retry.py
docs/tools/check_s96_curved.py
docs/tools/check_s96_guards.py
docs/tools/finalize_s96.py
```

Use bundled Python/NumPy/Pillow plus the existing FXC/WARP harness. Final audit
checks report/source hashes, staged s95 preservation, production and prior local
work, published birth/film asset hashes and Python syntax. It writes a source
diff and delivery report without installing or publishing the work.
