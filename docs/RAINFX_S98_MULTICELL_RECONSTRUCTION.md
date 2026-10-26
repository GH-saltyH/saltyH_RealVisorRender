# s98 — positive reconstruction and multi-cell resolved transport

Date: 2026-10-17

Status: **ACTIVE — offline numerical implementation; coupled time accuracy blocks game adoption**

## 1. Result and scope

Implemented the next s97 comparison: limited linear volume reconstruction and
a source-local affine remap that can cross many cells in one accepted step.
It keeps actual cell-area film, separate end/mean momentum, explicit runoff,
GPU admission and the s95/s96 retained-time transaction. No numerical point
position/area history, invented droplet footprint or display gain is used.

The smooth transport result is substantially less diffusive. Actual curved SI
budgets, rotation, compression refusal and retained-time retry pass. A held
100µm/40m/s actual-mesh case travels about 6.8 cells in one step, avoiding the
s97 local outgoing-fraction restriction. However, its one-step film differs
from the four-piece result by **10.44% relative volume-profile L1**. This is a
coarse/finer comparison, not an error against an exact physical solution.

Decision: retain the implementation and its guards, but **do not adopt it as
game transport yet**. Positivity, conserved water and large travel do not prove
accurate coupled force/height evolution. The next target is temporal coupling,
including stiff relaxation and changes of depth along the transported film.
Production physics, tuning, assets and user materials remain unchanged.

## 2. Reconstruction and map

Each cell is a resolved finite-volume sample of water on its actual mesh area.
Inside its unit source coordinate, reconstruct conserved volume density with
a monotonized central slope:

```text
s = minmod((right-left)/2, 2*(mass-left), 2*(right-mass))
abs(s) <= 2*mass
q(t) = mass + s*(t-1/2),  0 <= t <= 1
```

The slope bound makes `q(t)` nonnegative. Its integral across the complete
source equals the original mass. A destination receives the analytic integral
over its intersection with the mapped source interval. The same positive
fraction multiplies volume and each end/mean momentum component. Thus this is
a higher-order **volume** reconstruction; donor velocity remains piecewise
constant. No second-order coupled momentum claim is made.

For each sweep, the mean world velocity is projected through the current mesh
Jacobian. A wet source's left/right face velocities are averages with adjacent
real wet neighbours. A dry neighbour uses the source's own velocity. Advect the
two cell edges with these frozen source-local face velocities.

This is not the s90/s91 frozen Eulerian nearest-donor velocity field. An empty
gap does not insert an artificial stationary front before real water contact.
The numerical source interval describes a resolved cell, not the fixed physical
width excluded by s92. It can compress to a positive fractional width.

Two-level bounds (16 sources per leaf, 16 leaves per group) select contributors
to each destination. End/mean packets are gathered together. Connected run
clipping absorbs water at holes/edges and prevents transfer to another island.
The fraction outside the donor's own run is recorded as end/mean runoff.

### Admission and swept interactions

Admission requires finite, representably positive interval widths and ordered,
nonoverlapping retained intervals. It also compares each source's **full** image
with the next real wet source in the same run. Retained-only bounds would miss
a donor that passes through stationary water and entirely out of the boundary.

The next-wet scan stops at the first wet source or its connected run boundary.
Its maximum loop is the run length; logical scan distances between consecutive
wet sources sum to at most that length per row. This is not a constant-time
neighbour lookup, and SIMD/texture cost is not inferred from logical counts.

Invalid/reversing/overtaking maps refuse the whole axis. An axis refusal keeps
its old packets and reports zero provisional runoff. If either axis or the
physical post step refuses, the interval attempt publishes no stock, impulse,
evaporation, runoff or elapsed time. Exact remaining ticks are retained and
the cap is halved. This is a safe admission/retry policy, **not** a physical
collision or capillary-pressure solver.

Recipient tangent projection and evaporation, force/metric version receipts,
source-once/P4b ownership, compensated physical ledgers and all-output publication
are retained. Returned heads are still staged at rest; this is not a full live
P1/P2 lifecycle implementation.

## 3. Numerical verification

Exercised shaders compile warning-free with FXC `ps_5_0 /Ges /WX` and execute
in D3D11 WARP. The harness reads/uploads between draws; these are offline
numerical results, not game GPU-ms/FPS or memory measurements.

### Independent integral, static identity and symmetry

A float64 source-scatter integral oracle covers random positive stocks, signed
end/mean momentum, variable affine face speeds, holes and boundary runoff.

- Maximum packet difference: 1.544e-6; map-edge difference: 1.857e-6 cells.
- Maximum runoff packet difference: 2.176e-6.
- Water residual: 5.207e-7mm³ in the specified fixture.
- Positivity and no hole/island crossing pass.
- Zero velocity is bit-identical even for mixed cells.
- X/Y transpose is bit-identical; reflection differs by at most 1.967e-6.

### Smooth profile and large travel

The same s97 100mm domain, 0.1m/s, 0.1s Gaussian translation is evaluated
against exact cell-integrated translated profiles. New remaps use one step.

| Cells | Travel in cells | s97 local donor L1 | New constant remap L1 | New limited remap L1 |
| --- | --- | --- | --- | --- |
| 32 | 3.2 | 0.198487 | 0.0198662 | 0.00582992 |
| 64 | 6.4 | 0.112163 | 0.00783283 | 0.000447833 |
| 128 | 12.8 | 0.0591693 | 0.00131100 | 0.000109007 |

The old local scheme used 8/16/32 small steps. Avoiding repeated remaps and
using limited reconstruction both reduce diffusion. This is smooth prescribed
constant-velocity transport, not nonlinear SI/contact accuracy.

On a separate 256-cell compact profile, travel of 0.4/16.4/64.4 cells uses the
same five remap draws and **688 source tests total, maximum 32 per recipient**.
These are diagnostic shader loop counts for that fixture, not measured cost
or a universal upper bound for arbitrary compression/expansion.

### Moving/stationary fronts and compression

The s91-style fixture has moving water at cells40–44 and stationary water at
100–104. Its moving front starts at45.

| Proposed travel | Result |
| --- | --- |
| 20 cells | Advances exactly; no premature dry-gap stagnation |
| 54 cells | Advances to99; stationary patch unchanged |
| 55 cells | Reaches contact at100 without crossing |
| 60 cells | Refuses overlap/overtake; old packets, zero loss |
| 230 cells | Refuses tunnelling through water and out of boundary |

Without the intervening stationary patch, the 230-cell full exit is admitted
and its complete end/mean packet becomes runoff. A continuous compressive
profile with velocity gradient−0.4 per step is admitted and increases local
volume; gradients−1/−2 reverse/collapse a map and refuse without mass loss.
No imposed hard minimum material width is used; the width tolerance only
protects floating-point representability.

### Physical retry and transaction

A designed physical viscous-relaxation compression fixture rejects its 1s
map, then completes with two 0.5s steps. Rejected force/evaporation/time stay
private. Split/together scheduling and proactively selecting the half-step cap
produce bit-identical public banks. Source and pool debit are applied once.
Water residual is−8.385e-8mm³; the specified momentum residual is zero.

Stale force/metric receipts, invalid wet-cell area and pending draws at gather
or final receipt publication retain caller-owned water and time. These guards
do not establish completion for every compressive state; the inherited one-tick
blocked-debt case still needs a live recovery design.

## 4. Actual curved mesh and coupled time limitation

The actual 1024×256 cell-area/Jacobian/boundary assets and 4,251-cell,100µm
initial film are tested with gravity, air `(5,0,-10)m/s`, source supply, a
localized pool return and evaporation. A 20ms interval completes in one
accepted step (37 unfused draws), maximum sweep travel0.6923cells.

- Water residual: 8.161e-8mm³.
- Maximum physical momentum residual: 3.341e-8 packet units.
- Final normal momentum: below5.83e-11.
- Static90° world rotation: relative volume-profile difference6.542e-8,
  rotated momentum packet difference8.033e-9.

The second actual-mesh test starts from the s97 local equilibrium at100µm and
40m/s air, then lets water, depth and SI force evolve over1/60s. It has no new
source or pool transfer during this comparison.

| Requested pieces | Accepted / rejected | Max sweep travel | Difference from four-piece volume profile | Submitted draws |
| --- | --- | --- | --- | --- |
| 1 | 1 / 0 | 6.8063cells | 0.104434 | 37 |
| 2 | 3 / 1 | 3.4097cells | 0.0666415 | 132 across3 host calls |
| 4 | 4 / 0 | 1.8465cells | Reference only | 100 |

The two-piece request actually needs three accepted steps because its second
proposal refuses on the evolving film. The failed attempt consumes no time.
All three physical water/momentum ledgers pass. The smaller caps approach the
four-piece profile, but four pieces are **not** an exact/asymptotic reference.
No time order or final accuracy has been established.

The 10.44% coarse/finer volume difference is large enough to block adoption.
Conservation does not measure path/depth/force accuracy. Current-height force
is frozen within each substep; film redistribution changes that depth and its
viscous relaxation. Directional splitting, affine face trajectories and
piecewise-constant momentum also remain possible contributors. This stage
does not attribute the entire discrepancy to a single operator.

Large-depth/high-shear cases additionally require a justified force regime;
the current laminar SI law is not calibrated across all of them. Pressure,
contact angle/pinning and new pool/head exchanges are still missing here.

## 5. Cost and next step

The unfused transaction graph is **16 + 21A draws** for A attempt slots:
37 for one,58 for two,79 for three. Each axis uses a mean metric projection
plus five remap passes. s97 is cheaper per attempt (27 for one), but its local
CFL restriction requires many more attempts in fast smooth flow. Fusion must
address both the higher per-attempt cost here and remaining allocations.

It is not valid to compare this coarse37-draw high-shear result with s97's
held192-draw demand as equally accurate solutions. The newly measured coupled
time difference is precisely why no game speedup or FPS gain is claimed.

The force/post diagnostics remain4H each (16MiB each at1024×256RGBA32F), paired
gather2H (8MiB), and mapH (4MiB). Axis scratch can potentially alias between
sweeps. Public/private unused history banks and diagnostic lifetimes remain
unfused; this is not a measured peak-memory total or a leak conclusion.

Next implementation:

1. Isolate temporal coupling error with controlled fixed-height/force-free,
   evolving-depth and sweep-order references. Preserve the explicit10.44%
   coarse/finer counterexample rather than treating large-C admission as accuracy.
2. Compare a conservative predictor/corrector or symmetric force/transport
   composition under stiff relaxation, with explicit impulse/evaporation/wall
   accounting and the same retained-time protocol. Admit on accuracy as well
   as map geometry; avoid blindly restoring global local-CFL stepping.
3. Resolve wet-front/contact/pressure and high-shear physical regimes before
   full head/source lifecycle, live backlog/recovery and runtime graph fusion.

No production install, tuning change, reload/log request, commit or push.

## 6. Reproduce and audit

```text
docs/tools/check_s98_remap.py
docs/tools/check_s98_interactions.py
docs/tools/check_s98_transaction.py
docs/tools/check_s98_curved.py
docs/tools/finalize_s98.py
```

Staged baseline, reports, source diff and delivery audit are under
`docs/diagnostics/2026-10-17/s98/`. The final audit checks prior work/runtime
preservation, report/source hashes, published assets and Python syntax.
