# s131 — curved sequential transport and arithmetic trace

Date: 2026-10-18
Status: ACTIVE

## 1. Scope

s130v2 removed false shared-face refusals on actual CSP, while its unchanged
exact affine-map gate still failed. s131 separates the remaining arithmetic
stages and exercises sequential X→Y and Y→X consumers with sampled visor geometry.
It is an independent default-OFF one-shot app, not a change to live RainFX.

Six cases contain two signed affine traces, two curved sequential cases and
two curved cases with synthetic internal cuts. Each case has32 RGBA32F targets,
32 original/diagnostic passes and one R32FLOAT extraction atlas. The app retains
all198 accepted submissions and six readbacks. Nominal texel payload is674,816B;
this is not measured GPU allocation, peak memory or timing.

## 2. Inputs and independent checks

The curved fixture samples13×7 pairs from the existing2048×512 `du.dds`/`dv.dds`
and valid-cell information from1024×256 `cells.dds`. Sample coordinates are
`floor(860+(i+.5)*320/13)`, `floor(180+(j+.5)*180/7)`. Derivatives are scaled
by320/2048 and180/512 respectively. This is a coarse frozen real-bake fixture,
not a full-resolution visor accuracy test. The sparse cases additionally cut
x6/y2..4 and y3/x1..2; these are diagnostic holes, not measured mesh holes.

Initial thickness is50µm, varied by a dyadic mass factor. Momentum uses a fixed
world velocity `(0.01,-0.006,0.002)`m/s; the interval is0.0625s. Mean stock is
0.75×End to distinguish their channels, not a claim about physical time closure.
Frozen source hashes and actual sample arrays are recorded with the fixture.

The first axis runs logical and bank consumers independently. The second
logical axis reads explicit copies of first-axis End/Mean; the second bank axis
reads its own first-axis gathered bands. Both sequences use unchanged s130v2
map/leaves/groups/totals/full/end-only consumer bodies. Copies, each consumer
pair and full/end-only outputs are checked bit-for-bit; invalid recipients must
stay zero. End/Mean mass and all momentum components close per step and across
both axes, including boundary losses. Per-step bounds remain64 float32 epsilon
times input absolute sums; the two-step bound is128 epsilon for two contributions.

Copied U/V values must match. Gram dot/determinant errors are checked separately
against declared normal-float operation bounds: gamma5 for each three-term dot,
gamma3 for the determinant using captured coefficients. Maximum fixture Gram
condition is3.60818. These bounds do not replace the s130 exact-map criterion.
Map differences versus a float64 expression over captured float32 inputs are
reported as absolute cell error and rounded-reference ULP, not hidden as zero.

## 3. Arithmetic trace and user result

The trace records raw Mean, native quotient, `precise` quotient, a diagnostic
quotient residual correction, projected speed/reference and original map replay.
The residual correction is `q + (momentum - q*mass)/mass`, with intermediate
`precise` values. It is observation-only; sequential consumers do not use it.

The user completed the actual preview649 run in a fresh game session. All
**98,304 floats** and198 once-accepted draw counters were collected in770 lines.
All six scoped checks pass. There are72 bit-identical consumer pairs:24 from
the signed affine traces and48 from the four sequential curved/cut cases.
Both axis orders admit every planned step; copied bands, End-only output,
invalid recipients and per-step/cumulative End/Mean budgets pass.
The largest budget error consumes0.1003% of its predeclared roundoff bound.

Each signed affine trace/axis has18 differing quotient components, maximum
**1 ULP /1.1920928955078125e-7**. Native and `precise` division have the same
observed error. The residual-refinement trace has zero differences against
these exact dyadic quotient controls. Raw packet and original map replay match
bit-for-bit. The first observed arithmetic difference is therefore at the
normalization expression; `precise` alone does not remove it.

Real-bake Gram calculations use at most38.044% of their declared dot/determinant
bounds. Sequential map endpoints differ from the float64 expression by at most
**4.7547985282392347e-7 cell**. The largest rounded-reference ULP count is181,
at an endpoint near1.3428e-5 cell with only1.64957e-10 cell absolute difference.
ULP and absolute error are both retained; near-zero projections and cancellation
make a universal1-ULP map assertion inappropriate. No new general map bound is
claimed. The unchanged s130 strict analytic gate still returns false because
its original consumer does not use the diagnostic quotient correction.

Expression-level evidence cannot identify a particular reciprocal/FMA instruction
inside CSP's closed compiler template. Shared expression optimization may also
affect how the trace is compiled. The old exact analytic gate is called unchanged
at its original affine case indices and is reported independently of scoped
copy/admission/budget checks. Passing the latter does not close the former.

## 4. Capture failure and correction — user result

The first `observed` run logged exactly1000 lines: full cases0..2, case3 rows0..230,
no cases4/5 and no final counters. This is an incomplete capture, not a full GPU
pass. `first_capture/` preserves original sources, reports, package, installation,
fresh log bytes and the independently analysed complete three-case subset.

Splitting64 rows per scene callback still stopped at exactly1000 total lines.
`second_capture/` preserves that attempt and the corresponding package/receipt.
The original attribution to a per-frame limit was unsupported and corrected.
The user confirmed CSP's basic log stops once the initial-load cumulative
quota is exhausted; app auto-reload does not restore output. A game-session
restart is necessary for a new capture after reaching that quota. The final
770-line capture was collected after that restart. The numerical quota/reset
behavior is observed/user-confirmed, not specified by the audited API.

The final format packs128 floats per log row:6×128 rows plus header/counters,
**770 calls total**, at most33 calls in a normal callback. All98,304 values remain
present; the GPU graph, shaders, seed, uniforms and198 draws are unchanged.
The decoder requires the new row width explicitly and rejects missing/duplicate,
nonfinite, out-of-range, stale pending and malformed-counter dumps. A1000-call
mock cap, pause/resume and duplicate dump requests exercise the observed failure.
The first two executable versions and log evidence are retained. Logging upgrades
replace only the exact previously installed `s131_probe.lua` hash and refuse
unknown files, package changes or path escapes. Other app files stay intact.

## 5. Verification and boundaries

- 198 WARP draws and17 synthetic strict `/WX /Ges` shader bodies pass.
- 18 mocked lifecycle cases,15 decoder controls and15 scratch installer cases pass.
- 14 main cache schemas plus3 extraction schemas are checked for collisions.
- Every accepted prefix survives pending without replay. Data handles are disposed;
  submitted GPU targets remain owned because no general completion fence exists.
- The installed SDK still matches the23-block s127 audit. New capture packing uses
  existing Lua string/table and `ac.log` operations; no new engine API is required.

Source/report/hash provenance is under `docs/diagnostics/2026-10-18/s131/`.
`packed/` retains the final installation receipt, fresh log boundary and actual
observation. `delivery.json` and `source.diff` record the final preservation audit.
Runtime53 files, root INI3 files, s91–s130 source396 files and prior assets/reports
are preserved. Game physics remains s87, diagnostics s89; no commit/push.

## 6. Next implementation

Evaluate a compensated quotient inside the actual map consumer, including its
effect on the unchanged strict affine gate, sparse curved admission and sequential
budgets. Keep a separately derived finite-precision error model for nonexact
curved projections; do not loosen an old threshold to declare completion.
Then connect interval-owned live inputs/stocks with bounded publication and
measure actual target GPU/CPU cost. This probe neither authorizes general GPU
completion/reuse nor establishes production accuracy or a performance win.
