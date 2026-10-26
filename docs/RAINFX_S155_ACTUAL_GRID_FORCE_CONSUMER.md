# s155 — actual-grid physical film force consumer

Status: ACTIVE — offline adapter and full-grid numerical verification passed
Date: 2026-10-19

## Implemented connection

s154 verified the actual main-app world field cache at frame660. s155 connects
that input ABI to the existing physical film force operator on **1024×256** cells.
It uses the recorded 52-row context, reconstructs the world cache with the frozen
s154 shaders, and consumes its U/V, authoritative area and connected-run data.
The reconstructed cache agrees with the actual CSP samples (maximum absolute
difference 2.98023224e−8) and the independent float64 geometry oracle. The run
fingerprint matches the actual captured cache.

This is an **offline reconstruction from an actual captured context**. It does
not acquire s154's session-retained native handles, execute a new game callback,
or read a live water inventory. The input stock is an explicitly controlled
physical packet fixture. Production physics remains s87, diagnostics s89, and
the default-off s154 diagnostic remains the latest actual geometry observation.

## Input and output ABI

| Input | Shape / meaning |
| --- | --- |
| captured frame | 1×52 RGBA32F, s152 context layout observed through s154 |
| world metric | 1024×768 RGBA32F, U/V/Gram vertical bands |
| world areas | 1024×256 RGBA32F, mm²/valid/coverage/coating |
| connected runs | 1024×256 RGBA32F, X/Y connected endpoints |
| staged stock | 1024×256 RGBA32F, `(mm³, mm³ × world m/s)` |

`s155_consumer.recipe` requires `offlineReplay=true`. It privately copies the
capture, verifies the binary32 context/pose SHA256 and frame identities, and
retains copied upload rows in the parameter packet. Display-gain options,
unknown options, altered identities, changed rows and solver-enabled captures
are refused. The returned graph has no CSP handle acquisition or completion
backend. Binding the provided arrays to the declared roles remains the trusted
offline harness's responsibility; descriptor keys do not authenticate GPU data.

The six-pass graph extracts physical rows34…38, validates the common frame and
shapes, evaluates force, audits every cell, and reduces the audit twice. The
frame gate checks common token/dt/grid/count, material range, finite data and
model revision. The inherited film model has no downward-air variant; a header
enabling that option is explicitly refused.

The force output preserves the existing four vertical bands:

1. End packet after **half** of the captured dt;
2. mean packet over the **full** dt;
3. impulse packet at the half-step;
4. status and removed normal momentum.

These are the existing operator's asymmetric half-End/full-Mean semantics.
They are not an already transported full-frame stock and do not advance time.
The source, evaporation, transport, pool-return and final inventory steps have
not run. A frame gate or cell audit failure prevents admission of this candidate;
no public stock/clock publication API is supplied.

## Physical equations and units

`packetValid`, `resolvedMetric`, `tangent`, `relaxFilm` and `forcePacket` are
copied unchanged from s141. The original full donor operator is executed as a
separate control and gives **bit-identical output across the entire field**.
No density, viscosity, shear coefficient, drag or gravity tuning was changed.

Local film height comes from `volumeMM3 / areaMM2`, then converts mm to metres.
World gravity/inertia and tangential air/shear use the captured physical rows.
The display diameter gain and the nominal UV/mm coefficient do not enter the
operator. This remains the inherited frozen-height laminar relaxation model;
it does not establish turbulent-sheet or millimetre-pool realism.

The controlled fixture spans dry cells and **0.1, 1, 10, 50, 100, 250, 500µm**
stripes, with mixed tangent and normal initial momentum. There are 120,765 wet
cells and 3,467.0198mm³ of controlled inventory. Those quantities are test inputs,
not measured water on the user's visor.

## Numerical result

**106 WARP draws / 9 strict FXC bodies** cover 17 full-grid cases:

- Six accepted cases: actual-context mixed depths, dry, gravity/inertia without
  air, viscous relaxation only, inviscid response and uniform-scale SI units.
- Eleven refused cases: zero dt, stale physics token, negative viscosity,
  unsupported downward air, wrong stock dimensions, negative/nonfinite stock,
  wet unsupported geometry, invalid area, metric or run.
- Six CPU scope/identity/option refusals and a copied-capture mutation check.
- Original force bit parity and reproduction of the first diagnostic failure.

The float64 oracle uses an independent closed-form exponential response with
`expm1`, without the shader's small-x polynomial. The velocity gate remains
**32 float32 epsilons relative to response/input speed, with a 1e−9m/s floor**.
The actual-context maximum velocity error is **3.0852024e−8m/s**, normalized
ratio **0.3785761** (limit1). Across the accepted cases the maximum ratio is
**0.4900021**. The separate momentum closure keeps its 128-epsilon / 1e−9 bound.
Volume bits are preserved exactly in both End and Mean packets.

Scaling the geometry by1.7, area/volume/momentum by1.7², and holding physical
depth and initial world velocity fixed preserves the response within the same
gate. Maximum velocity difference is **3.4808940e−8m/s**. This verifies that the
force is using world area/depth, rather than an optical pixel scale.

## Initial diagnostic failure and correction

The first audit rejected three cells with tangency ratios1.07988…1.28283. It
normalized the residual normal momentum only by the nearly cancelled output.
The absolute normal components were about0.8…1.4e−9mm³·m/s, while the original
input momenta were larger. The unchanged force already passed the independent
float64 oracle (ratio0.37858). This was an ill-conditioned diagnostic denominator.

The tangency check now includes the original momentum as well as End/Mean in its
roundoff scale. Its coefficient4e−6 and acceptance limit1 are unchanged. No force
function, physical coefficient, velocity oracle or closure gate was relaxed.
The corrected actual-context audit reports zero bad cells and maximum ratio
**0.1390318**. The first source, compiled body and full arrays are preserved;
the old three-cell failure is reproduced bit-for-bit by a control draw.

## Resource and calculation cost

| Descriptor accounting | Nominal size |
| --- | ---: |
| Five imported resources | 24.00079MiB |
| Six private outputs | 16.01579MiB |
| Standalone consumer graph | 40.01659MiB |
| Four-band force output alone | 16MiB |
| Retained s154 + new stock + private consumer outputs | 76.60321MiB |

The last row shares existing cache imports and does not count them twice. It
exceeds the current single64MiB owner limit, so stacking the current diagnostic
graphs is not an admitted game implementation. No owner limit was increased.
Source-image cache and driver overhead are additional to these nominal values.

The force target has1,048,576 fragments: four bands revisit the same physical
cell. Each wet cell logically invokes the same force function four times. The
16MiB output is about99.90% of private storage. A two-band representation could
remove8MiB and reduce this repeated evaluation, but reconstruction of impulse,
normal exchange and status must pass the existing closure checks before adoption.
This is a next implementation target, not a measured speedup or verified compact
ABI. The six-pass graph writes16,793,776 nominal bytes per evaluation; this does
not include reads, caches or driver traffic. No target GPU timing was measured.

## Delivery and next step

Evidence: `docs/diagnostics/2026-10-19/s155/`, including `consumer_checks.json`,
`cost_checks.json`, `actual_context_force.npz`, `recipe.json` and the initial
failure artifacts. All prior source/evidence, production shaders, main app and
tuned settings are preserved. There is no new game probe to run in this step.

Next implement a compact force representation and its downstream readers,
preserving impulse/normal/status accounting. Then connect the remaining frame
operators under a bounded resource strategy. Recurrent GPU completion/reuse,
source and inventory authority, transport time accuracy, common optics and
target warm-run cost remain live-adoption gates.
