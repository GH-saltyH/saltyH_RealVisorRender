# s263 — bounded donor-cell film advection (2026-10-24)

## Decision and implementation

Replace the normal CPU-audited retry strategy with a compact,first-order
finite-volume donor-cell **advection candidate**. This stage implements and
executes its shaders and ordered pass plan;it is not connected to the main app.
The s262 path and its actual failed continuous gate remain unchanged.

Each donor computes four nonnegative outgoing fractions from cell velocity and
represented dt. Wet neighbours use a shared mass-weighted face velocity;dry
neighbours use the wet donor velocity. Outgoing fractions are scaled together
only when their sum exceeds0.95. Gather retains the residual and adds neighbours'
stored outgoing packets. It transports all four packet components,including
signed world momentum. Disconnected runs cannot exchange water. Boundaries can
be closed or absorbing;escaped End and Mean packets are explicitly accumulated.

There is no source arrival,evaporation,force update,head coupling or dt rejection
inside this operator. The caller must supply validated physical End/Mean packets,
cell velocities in cells/s,connected-run topology and positive represented dt.
The test projects world mean velocity through the retained physical visor metric.
Display diameter gain does not enter the operator.

This is an explicit advection-speed approximation when limited. Full elapsed
time is represented,but limited trajectories travel less far. It is not an exact
replacement for the characteristic remap. First-order numerical diffusion is
also real:the analytical translation test measures the expected variance.
Uncapped water/momentum conservation alone is not a visual-quality pass.

## Why the single-step candidate was rejected

At1/60s on the retained actual-grid input,the initial limited water share is
41.86%,reaching42.09% in the12-step frozen-velocity fixture. Such broad speed
limiting is unsuitable as the normal visual policy. Keep that result as a rejected
configuration;do not call its unconditional numerical stability a quality pass.

Use a **bounded GPU subcycle plan**,with no CPU receipt between substeps:

| Full input dt | Substeps | Advection draws |
| --- | ---: | ---: |
| ≤1/60s | 4 | 8 |
| ≤1/30s | 8 | 16 |
| ≤50ms | 16 | 32 |

These are fixed schedules,not adaptive shader retries. The final exceptional
limiter still guarantees nonnegative retained volume for large local velocities.
No infinite subdivision,larger input queue or discarded elapsed time is used.

## Measured local comparison

One1/60s interval,actual1024×256 visor topology and retained physical packets,
with the same frozen velocity for each configuration:

| Substeps | Maximum limited mass share per substep | End-volume L1 difference versus16 | Exit volume |
| ---: | ---: | ---: | ---: |
| 4 | 0.015533% | 0.096893% | 8.419534 mm³ |
| 8 | 0% | 0.030544% | 8.351007 mm³ |
| 16 | 0% | reference | 8.313390 mm³ |

The4-step plan is the preferred **development** configuration on this fixture.
The finer configuration is a discretization reference,not measured physical
ground truth. The comparison covers one represented interval,not rain coverage,
long-run coupled force evolution,thin trail optics or actual frame latency.
The former s2290.5% volume-distribution scale is satisfied in this narrow check;
that does not grant a whole-model/visual adoption pass.

The emitted8-draw plan is executed and its End/Mean output matches the separately
executed4-substep result bit-for-bit. Accumulated End runoff plus remaining water
closes the790.124062mm³ input with absolute error1.69e-8mm³.

## Resource and startup implications

The plan reserves one2W×H flux/diagnostic texture and two alternating W×4H
End/Mean/exitEnd/exitMean outputs:40MiB at1024×256. Single-pair temporary output
is24MiB. These numbers exclude external input,velocity,topology,physical cache,
heads,source,receipt ring and driver allocations;they are not an app memory win.

Plans contain8/16/32 small pass records and two fixed shader bodies. This avoids
constructing the old85-pass transport graph for this core. The existing main-app
graph construction still takes80.7245ms in the s262 observation and has not been
changed. Actual startup savings require replacing its construction during the
next integration;they are not inferred from record count.

Native tests use readback after each draw. They do not prove CSP asynchronous
alias safety,actual texture lifetime or removal of real engine callback waits.
The plan is designed to submit without intermediate CPU completion;the retained
private owner must qualify that execution before use. Eight advection draws are
not comparable to the former complete70-draw input graph without counting forces,
validation,source and ledger passes.

## Verification

`tools/check_s263_flux.py`:118 strict native D3D WARP draws,two shader bodies.
Closed/stationary/directional/high-speed flows,disconnected dry gap,known
translation centroid/variance,12 actual-grid frozen-velocity steps,4/8/16
subcycle comparison and the emitted accumulating plan pass. Volume remains
nonnegative and End/Mean signed packet sums close including boundary exits.
Evidence: `diagnostics/2026-10-24/s263/checks.json`.

## Next bounded delivery

Compose this plan with the existing SI force/metric cache,physical validation and
water/time ledger in a compact retained owner. Keep the proven identity/quarantine
checks and final asynchronous audit;remove normal CPU callbacks between substeps.
Cache its static recipe before live intake. Then use one integrated actual CSP
continuous/startup gate,followed by coupled visual comparison. Do not create a
new standalone probe or ask the user to repeat the failed s262 gate.

Head/source/optical publication and full2048/4096-slot cost remain later product
integration work. No FPS improvement,continuous CSP throughput,graph-startup
resolution or game adoption is claimed in s263.
