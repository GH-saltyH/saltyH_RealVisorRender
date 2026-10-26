# s132 — compensated divisions in the actual map consumers

Date: 2026-10-18
Status: ACTIVE

## 1. Decision and scope

s131 actual CSP traces first differ at `momentum/mass`, by1 ULP. Its diagnostic
residual correction matches the affine quotient controls, but the real map still
uses the original division. s132 applies that correction to both original logical
and bank map consumers. This is a standalone default-OFF diagnostic candidate;
production game physics remains s87 and diagnostics s89.

Three quotient sites change: Mean momentum/mass, world-to-UV Gram projection,
and volume-weighted face velocity. Scalar, float2 and float3 overloads each use
`q=n/d; product=q*d; residual=n-product; correction=residual/d; result=q+correction`,
with `precise` intermediates. Denominator clamps, physical coefficients, source
mass/momentum, elapsed time, sparse runs, endpoints and admission criteria stay
unchanged. Inverse source transformation restores the exact s130v2 module.
Other consumer bodies are byte-identical. No new engine API or shader uniform.

This is a finite-float residual correction, not an exact arithmetic division
proof. Rounded products can discard residual information; tests of exact dyadic
quotients do not establish universal accuracy for arbitrary data or hardware.
No approximate comparison replaces the old strict affine equality criterion.

## 2. Coverage and offline result

The independent s131 numerical model and original s130 affine model are reused
unchanged, including the failed exact-map criterion. Geometry/seed/run inputs
match s131 byte-for-byte. The six actual-probe cases keep its two signed affine
traces and four sampled-real-bake XY/YX cases, including synthetic internal cuts.
For each sequence, logical copies feed the next axis while the bank branch reads
its own first-axis gathered bands. All helpers preserve the bank addressing ABI.

WARP completes198 main-probe draws plus120 draws for all four original affine
fixtures (small movement/dry cell, positive/negative runoff and intended overtake
refusal). All four original strict affine checks pass offline; both runoff traces
also pass their unchanged strict gate. Curved/cut sequential admission, copy and
consumer-pair equality, full/end-only equality, invalid recipients and End/Mean
per-step/cumulative budgets pass using the same limits as s131.

There are17 strict synthetic `/WX /Ges` shader bodies,18 mocked lifecycle cases,
15 decoder controls and9 scratch installer cases. The six-case app submits198
draws and reads98,304 values. All770 log lines fit below the observed1000-line
cumulative CSP basic-log quota. A fresh game session is needed after that quota
has already been exhausted; app reload alone does not restore logging.

## 3. Independent quotient stress and cost

An additional3 synthetic WARP draws compare native, corrected float3 and corrected
float2/scalar overloads over16,384 vectors /49,152 quotient components. The fixture
includes signed dyadic controls, zero/small components and seeded random positive
masses from2^-24 to2^16. The reference rounds the exact rational quotient of each
float32 numerator/denominator to nearest float32 with ties to even. All tested
overloads and native WARP division match that reference exactly; no worsening is
observed. WARP already returns the correct native control quotients, so these
samples cannot establish that CSP's previously observed error is fixed.

Synthetic ps_5_0 DXBC static comparison:

| Map | s131 slots | s132 slots | Static load sites | Temporary registers |
|---|---:|---:|---:|---:|
| logical |231 |275 |22 →22 |13 →15 |
| checked bank |337 |381 |26 →26 |18 →20 |

Each body adds44 static instruction slots, including11 `div` sites,22 `add` sites
and11 `mul` sites. Those are static sites with loops/control flow, not executed
instruction counts, hardware DIV instructions or actual GPU time. No extra pass,
target, texture binding or source load site is introduced. Nominal app texel
payload remains674,816B. This does not yet justify calling the correction free
or a measured low-cost solution; correction-site ablation remains worthwhile.

## 4. Actual CSP user result

The user started a fresh game session, ran s132 and waited after `observed`.
All98,304 values and198 once-accepted draws were captured in770 log lines.
The two signed affine cases now pass the **unchanged original strict criterion**:
both axes and both texture branches have **zero map error** against the dyadic
analytic coordinates. All72 logical/bank consumer pairs match bit-for-bit.
This closes the specific signed-affine failure recorded in s130/s131, not a
universal curved-physics or all-weather accuracy gate. The other two original
fixtures (small movement/dry cell and intended overtake refusal) were checked
in WARP here; they were not additional actual s132 cases.

All four curved/cut sequences pass admission, copied End/Mean bands, full/end-only
output, invalid recipients and step/cumulative budgets. The largest budget
error consumes0.1079% of its existing bound. Curved map maximum absolute
difference remains4.7547985282392347e-7 cell. Maximum rounded-reference ULP
increases from181 to1175 ULP: the worst s132 endpoint is1.34258452817e-05 cell,
versus1.34269137848e-05, an absolute error of1.0685031e-09 cell (case3,
first Y step, cell11/0). Near-zero cancellation makes ULP highly sensitive,
so this is not itself a material visual displacement, but the correction does
not uniformly improve curved precision. Correction changes actual curved
map/gather values without removing the maximum error of the full calculation.
Independent dot/projection, endpoint rounding and cancellation still need a
scoped error model; ablation must preserve this counterexample too.

Native/precise division trace controls still show1 ULP, while the diagnostic
residual trace shows0. The changed actual **map** passes exactly, which is the
relevant improvement over the previous observation-only correction. No existing
tolerance was widened. General completion and live-physics adoption stay false.

The raw trace still includes native and `precise` division as controls. Its direct
residual diagnostic is unchanged. The significant new test is the compensated
map replay and the original exact affine model, rather than relabelling the old
native-control error as a candidate failure or success. Gram/copy/budget scope
checks and map-versus-float64 absolute/ULP reports remain separate.

## 5. Ownership, preservation and next step

The separate app is `realvisor_s132_probe`,8 files, default OFF and one-shot per
load. Stable schema/cache keys are distinct from s131; repeated pending does not
replay accepted submissions. Submitted canvases remain retained, while CPU data
handles are disposed. No general completion fence, queue retirement or live stock
publication is inferred from these readbacks. No user tuning, runtime shader,
other probe app or app configuration is modified. User normally commits; none here.

Diagnostics are under `docs/diagnostics/2026-10-18/s132/`: source freeze, copied
geometry/layout, main and four-affine WARP results, quotient rational oracle,
DXBC disassembly/cost, mocked controls, immutable installation/log provenance,
and final source/preservation audit.

Next ablate the three correction sites to determine which are required by the actual CSP result.
Reduce unnecessary divisions only against unchanged gates, and derive a scoped
roundoff model for curved projections/cancellation without hiding near-zero ULP
behavior. Live interval input/stock ownership, bounded publication and measured
target performance remain later adoption requirements.
