# s97 — resolved physical-area film transport

Date: 2026-10-17 (baseline staged 2026-10-16)

Status: **ACTIVE — offline comparison/reference; not adopted into the game**

## 1. Purpose and decision

s96 showed that a coherent numerical point has no physical contact area. Its
bilinear copies received different viscous responses when their individual
volumes were divided by cell areas. Keeping a common position did not supply
the missing physical footprint.

s97 implements the proposed alternative: **resolved finite-volume film**.
Every stock value describes water occupying an actual mesh cell area. The
current depth is `Vmm3 / areaMM2` in mm; end momentum and interval-mean momentum
remain separate conserved packets. There is no point-position history or
shared subcell footprint to carry through the force law. This changes the
numerical representation; it does not establish a footprint model for an
unresolved physical droplet. P1 remains responsible for free attached heads.

Decision: retain this as a positive, conservative local reference, **not the
final game transport**. Smooth-profile refinement and actual curved SI budgets
pass. First-order diffusion and high-speed substep demand are too large to
justify adoption. Do not conceal those limits by clamping physical velocity,
skipping elapsed time, or feeding display diameter gain into physical depth.

Production remains s87 physics plus the existing s89 diagnostic view. No Lua,
production shader, tuning, asset, material or game installation changes.

## 2. Local conservative transport

For each substep, the s96 current-depth SI integrator computes physical end
velocity and mean velocity over that substep. The mean world velocity is
projected through the local mesh Jacobian into UV velocity. Define signed
swept-cell fractions:

```text
cx = meanUV.x * gridWidth  * dt
cy = meanUV.y * gridHeight * dt
outgoing = abs(cx) + abs(cy)
```

The donor keeps `1-outgoing` of both packets and sends `abs(cx)` to its X
neighbour and `abs(cy)` to its Y neighbour. Each recipient gathers its own
remainder and up to four neighbours. The same donor fractions debit volume,
end momentum and mean momentum. No CPU stamp loop, particle search, coherent
point certificate or PAVA hierarchy is used.

For admitted steps, `outgoing <= 0.8` everywhere. Thus every coefficient is
nonnegative and water cannot be created by the gather. A missing/disconnected
recipient receives no water; its donor fraction is recorded as runoff. Static
horizontal/vertical connected runs prevent crossing holes or islands. Rejected
temporary results never reach accepted stock or the ledger.

Recipient momentum is projected to the new tangent plane, recording the wall
reaction, before physical evaporation removes the corresponding packet
fraction. Applied impulse, wall reaction, evaporation and runoff retain s96's
physical ledger. The area and force are recalculated from the accepted film
before the next substep.

This is a first-order donor scheme for a depth-averaged, pressureless film
candidate. It is **not** a capillary/contact-angle solver. Opposing streams
numerically mix momentum within cells; stability and conservation alone do not
prove the resulting contact/rivulet physics.

## 3. Time and ownership

The s95/s96 interval protocol is preserved:

- One immutable source/P4b batch is staged once into private water/head banks.
- Force and metric receipts bind pending work to the original input interval.
- Global outgoing-fraction/invalid-cell reductions decide admission on GPU.
- A rejected attempt publishes no force, evaporation, runoff or elapsed time.
  Its exact dyadic time cap is halved; the unconsumed ticks remain pending.
- Accepted private work advances until the complete original interval finishes.
  Stocks, head packets, compensated ledger, clock and receipts publish jointly.
- Failure/pending at any output keeps caller-owned handles intact.

The graph submits a fixed number of attempt slots. Inactive slots still draw.
The offline harness reads/uploads textures between draws; it is not a
production-resident pipeline. It does not implement the full P1/P2 lifecycle,
a live changing-input queue, or recovery from the one-tick blocked-debt limit.

The unused history bank is currently retained for the comparison factory's
publication interface and cleared on accepted finite-volume work. Removing
that allocation belongs to a future fused runtime implementation.

## 4. Verification

All exercised GPU shaders compile with FXC `ps_5_0 /Ges /WX` and run in the
existing D3D11 WARP readback harness. These are numerical tests, not game
performance measurements.

### Flux, runoff and refinement

An independent float64 donor-scatter oracle covers a random 37×19 field with
both velocity signs, separate end/mean momentum, holes and outer boundaries.
Maximum end/mean packet error is 9.15e-8. GPU runoff reduction agrees with the
independent boundary debits within 2e-5 packet units. Volume remains positive;
holes receive zero stock. Zero motion is bit-identical, including mixed cells.

A smooth Gaussian travels 10mm across a fixed 100mm domain with constant
0.1m/s velocity. Exact cell-integrated translated profiles provide the spatial
reference; domain truncation is negligible in this fixture.

| Cells | Steps | Outgoing fraction | Relative profile L1 error |
| --- | --- | --- | --- |
| 32 | 8 | 0.4 | 0.198487 |
| 64 | 16 | 0.4 | 0.112163 |
| 128 | 32 | 0.4 | 0.0591693 |

Refinement reduces the error, but even the finest test has about 5.9% profile
L1 error. Increasing canvas resolution alone is an expensive remedy.

At fixed 32 cells, an independent Poisson-series solution of the semidiscrete
donor equation separates temporal error from spatial diffusion. For 8/16/32
steps, profile L1 errors are 0.096226/0.045922/0.022402. Smaller dt converges to
that discrete equation; it does **not** remove its spatial diffusion.

These tests establish smooth scalar transport convergence only. They do not
establish coupled nonlinear SI convergence, sharp rivulet, wet-front, collision
or coating/pinning accuracy.

### Actual CFL rejection and transaction guards

A zero-viscosity diagnostic fixture proposes a 1s interval with nonzero
acceleration, evaporation, source supply and a production-layout pool event.
The 1s and 0.5s attempts reject on GPU; four 0.25s steps complete all exact
ticks. The result is bit-identical to proactively selecting the 0.25s cap.
Split host calls and one six-attempt call also produce identical public banks.
Supply and pool transfer occur once. Physical ledger residual is about
−1.06e-7mm³, with momentum residual below 7e-11 packet units.

Stale force/metric receipts, unsupported wet-cell area and injected pending
passes preserve old public water/time. Unsupported area does not erase water.
Pending at gather and at final snapshot publication preserves caller handles.
Zero viscosity is an exact transport test limit, not a proposed weather value.

### Actual curved mesh

The fixture uses the published 1024×256 cell areas, Jacobians, boundary mask,
and 4,251 initially wet cells at 100µm depth. It includes gravity, relative air
`(5,0,-10)m/s`, source supply, a localized pool return and 0.2µm/s evaporation.

- The 20ms interval finishes in two accepted 10ms substeps; no CFL rejection.
- Maximum outgoing fraction: 0.658513, below the 0.8 admission limit.
- Water residual: −8.975e-7mm³; maximum momentum residual: 4.85e-8 packet units.
- Peak final depth: 104.268µm; final normal momentum is below 7.3e-11.
- A static 90° rigid world rotation passes: relative volume-profile difference
  4.95e-8 and rotated momentum packet difference 4.08e-10.

These are synthetic stocks on actual geometry, not replay-derived film. The
rotation check excludes changing-frame inertial terms.

## 5. Cost result and adoption blocker

The unfused comparison graph is **16 + 11A draws** for A attempt slots:
27 for one, 38 for two, and 82 for six. This reduces s96's **17 + 33A** graph
(50 for one, 83 for two). This is a graph count, not a GPU-time speedup.
Source staging, reductions, diagnostics and publication remain unfused.

The curved test intentionally splits calls: one slot followed by two slots,
one of which is inactive. It submits 65 total draws across two calls. Its
equivalent single three-slot call submits 49. Batching only the two needed
slots would have the 38-draw graph above; no inactive-slot savings are claimed.

Main temporary RGBA32F images at 1024×256 before aliasing:

| Image | Banks | Raw bytes |
| --- | --- | --- |
| Current-depth force/diagnostics | 4H | 16MiB |
| Signed outgoing coefficients | H | 4MiB |
| Gathered end/mean | 2H | 8MiB |
| Recipient projection/evaporation/diagnostics | 4H | 16MiB |

This table is not a measured peak-memory sum. Public/private history and
diagnostic lifetimes require removal/fusion/aliasing before a runtime design.

An additional actual-metric held-equilibrium probe quantifies global CFL demand
under the **current**, uncalibrated SI force law. Its independent float64 UV
projection agrees with the GPU coefficient shader to relative 3.49e-7.

| Depth | Air speed | Max outgoing at 60Hz | Uniform dyadic substeps |
| --- | --- | --- | --- |
| 100µm | 0m/s | 0.4752 | 1 |
| 100µm | 20m/s | 2.1132 | 4 |
| 100µm | 40m/s | 7.0935 | 16 |
| 100µm | 80m/s | 27.0590 | 64 |
| 500µm | 40m/s | 44.5809 | 64 |
| 1000µm | 80m/s | 310.2976 | 512 |

These substep counts apply to the held local equilibrium, not the initially
stationary 20ms curved fixture. They exclude retries, evolving film and queue
overhead. The full report also records depth Reynolds estimates. Large-depth,
high-shear cases stress the current laminar depth-averaged closure and must not
be treated as calibrated physical predictions. Even the 100µm/40m/s case
requires 16 uniform steps: **192 unfused draws** without rejected attempts.
Graph fusion alone does not remove the repeated spatial work.

Consequently, adopting global local-CFL stepping would risk restoring the
performance problem the refactor is intended to solve. Preserve this reference
for correctness comparisons; do not install it as the game default.

## 6. Next implementation

Evaluate a resolved-area transport method that moves water across multiple
cells per accepted step, preserves volume/end momentum and explicitly counts
boundary loss. It must beat this reference on diffusion and step demand while
retaining the immutable interval protocol. Include interacting wet fronts from
s91 and compression from s92/s93 in its admission criteria. Isolated advection
or water-budget success alone is insufficient.

Use bounded, positive reconstruction as the first accuracy comparison; it may
reduce diffusion but cannot alone eliminate the local CFL cost. Before choosing
a final method, also assess the current high-shear force regime and the missing
pressure/contact-line closure. No arbitrary force cap or invented particle area
is an acceptable replacement for those decisions. Full head/source lifecycle,
live backlog/recovery and a fused opt-in game path follow the numerical choice.

No repeated user game tests are requested at this stage.

## 7. Reproduce and audit

```text
docs/tools/check_s97_flux.py
docs/tools/check_s97_transaction.py
docs/tools/check_s97_curved.py
docs/tools/check_s97_demand.py
docs/tools/finalize_s97.py
```

Reports, staged baseline, source diff and delivery audit are under
`docs/diagnostics/2026-10-16/s97/`. The baseline includes runtime, tuning, prior
s91–s96 work and topic documents. The audit checks preservation, report/source
hashes, published asset hashes and Python syntax. No commit or push is made.
