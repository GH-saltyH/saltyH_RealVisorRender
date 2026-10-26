# s134 — conditional curved map roundoff bounds

Date: 2026-10-18
Status: ACTIVE

## 1. Scope

s133 selected mass + weighted-face correction (mask5), leaving Gram projection
division native. This step derives an arithmetic enclosure for that exact source
graph and compares it with the existing actual CSP capture. No new game probe,
shader, uniform, physical parameter or renderer admission threshold is introduced.
Production remains s87 physics / s89 diagnostics. The prototype stays uninstalled.

This is a conditional expression-graph model, not a proof that every closed CSP
shader template/compiler evaluates that graph with these semantics. It bounds
roundoff relative to captured inputs, not physical discretization, integration
time error, full-mesh baking error or the final optics/screen image.

## 2. Arithmetic model and domain

The primary references are Microsoft's [D3D11 floating-point rules](https://learn.microsoft.com/en-us/windows/win32/direct3d11/floating-point-rules)
and [D3D11.3 functional specification, section 3.1.3.2](https://microsoft.github.io/DirectX-Specs/d3d/archive/D3D11_3_FunctionalSpec.htm).
The specification permits arithmetic input/output denormal flushing; Load/move
preserve bits. Add/subtract/multiply have 0.5-ULP accuracy requirements. Division
may use a 1-ULP reciprocal followed by a 0.5-ULP multiply. Fused dot operations
must meet the permitted serial expansion's worst accuracy. The following bounds
are our conservative derivation under those rules and the stated domain.

Let `u = 2^-24` and `tiny = 2^-126`:

- Add/subtract/multiply expand the exact interval by `u * maxAbs + tiny`.
- Division uses `4u * maxAbs + tiny`: reciprocal/multiply relative factors give
  `(1 + 2u)(1 + u) - 1 = 3u + 2u² < 4u` in the normal-margin domain.
- Dot3 expands by `gamma5 * sumAbsProducts + 5*tiny*(1 + gamma5)`, with
  `gamma5 = 5u/(1 - 5u)`, covering three products and two additions.
- Quotient compensation follows all five source stages: quotient, product,
  residual, correction quotient and final sum. Interval dependencies are allowed
  to widen; correctly rounded compensated division is not assumed.
- Weighted faces and endpoint multiplication/addition are bounded separately.
  The integer lane offset, grid dimensions and exact captured dt are retained.

Bounds use exact rational operations, then directed binary64 endpoint storage.
They are derived before comparing observed endpoint errors. The model explicitly
handles intermediate FTZ and rejects nonzero subnormal source inputs, nonfinite
inputs, negative masses, invalid axis/dt, and insufficient Gram clamp separation.
Denominators must be positive within `[2^-124, 2^124]`; arithmetic magnitude and
dot sum-absolute-products must stay below the finite overflow margin `2^124`.
These conservative domain refusals are not permission to change runtime values.
The fixed 13×7 captured fixtures are the supported source shape in this stage.

Two scopes are reported for every map:

1. **consumer_only:** the captured stored Gram values are exact inputs.
2. **basis_and_gram:** Gram construction is also enclosed from the captured U/V
   basis. Stored Gram values must lie inside that enclosure. This does not bound
   errors upstream of the captured U/V values or establish full mesh accuracy.

For the second axis, each variant's captured first gather supplies End/Mean.
The result is conditional per map invocation; first-axis state uncertainty is
not propagated through the entire recurrent solver in this step.

## 3. Existing actual capture comparison

Reuse the frozen s133 actual capture and mask5 source export, with native mask0
and full-correction mask7 as controls. Two curved fixtures (YX and sparse XY),
two axes, logical/bank branches, 91 cells and two endpoint channels are evaluated
under both scopes: **8,736 endpoint checks**, including **2,912 for mask5**.
All observed endpoints and all tested stored Gram values lie in their enclosures.
The largest observed error/radius ratio across the controls is 0.731169.

| Selected mask5 scope | Maximum observed error (cell) | Maximum enclosure radius (cell) | Maximum reference UV-atlas radius (texel) |
|---|---:|---:|---:|
| consumer_only | 4.75480e-7 | 1.16744e-6 | 5.74741e-5 |
| basis_and_gram | 4.74851e-7 | 1.39387e-6 | 6.86211e-5 |

The UV-atlas conversion uses the captured source UV span and a **reference**
4096×1024 atlas: 640/13 texels per X cell and 360/7 per Y cell. These are not
viewport pixels, physical millimetres, the active runtime canvas resolution or
a bound on final visible refraction. The largest radius across all controls is
0.000123689 reference-atlas texel. No active endpoint enclosure straddles an
integer boundary in these fixtures. This does not prove ordering, non-overtake
or remap-kernel stability for arbitrary inputs.

### Near-zero counterexample

For mask5's first Y projection at cell(11,0), the retained 1,175-ULP discrepancy
has absolute error **1.0685031e-9 cell** under consumer_only, or **5.49516e-8
reference-atlas texel**. Its derived radius is 2.98955e-8 cell, and the error
uses 3.575% of that radius. The exact projected numerator subtracts terms with
a cancellation ratio `(abs(A)+abs(B))/abs(A-B)` of about **239.03**.

This explains why a very small absolute difference can have a large near-zero
ULP count. It does not establish a unique compiler cause, uniform accuracy
improvement, or that a complete visual artifact has been resolved. The original
counterexample and the unchanged exact signed-affine gate remain preserved.
The new curved enclosure is a separate diagnostic, not a relaxed affine gate.

## 4. Input identity and negative controls

Eight mask5 frozen snapshots retain End/Mean, runs, basis/Gram, axis, dt, grid,
UV reference, source prototype identity and parent actual-observation identity.
Each has a canonical SHA256 input receipt. These are **offline identity records**;
they authorize neither runtime admission nor GPU resource retirement/completion.

Verification passes 1,280 rounded primitive examples, three exact rational pairs,
two FTZ cases and six arithmetic-domain refusals. Five source-domain refusals
cover zero dt, invalid axis, the Gram guard, subnormal input and negative mass.
All 182 fixed `+0.001 cell` endpoint faults are outside their derived intervals.
Nine ownership/capability mutations reject changed stock, dt, metric, mask,
coordinate reference, prototype or unsupported live/completion/model claims.
These finite controls check implementation behavior; they are not exhaustive
proofs for every floating-point graph or arbitrary user-supplied receipt.

Evidence is in `docs/diagnostics/2026-10-18/s134/roundoff_checks.json` and
`snapshot_receipts.json`. Bounds include binary64 hex endpoints for replay.
The final delivery audit freezes report/source hashes and checks all prior
runtime, settings, source, SDK and asset identities. No measured GPU-time/FPS,
allocation or compilation improvement is claimed by this CPU-only analysis.

## 5. Next implementation

Carry the exact mask5 source and immutable input identity into the retained,
bounded interval transaction. Keep unsupported arithmetic/branch domains as
explicit refusals, and test resume/cancel/stale-input handling before stock
publication. A runtime interval implementation needs its own captured evidence;
these offline receipts do not grant it admission. Full recurrent physics and
remap accuracy, closed CSP execution/completion ownership, unified head/film
optics and target-machine cost remain adoption gates.
