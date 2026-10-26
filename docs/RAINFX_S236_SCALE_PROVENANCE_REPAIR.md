# s236 — measured-scale roundoff and explicit scale provenance (2026-10-22)

## Actual s235 failure

The first interval completes4/4:267 submissions,81 cache hits,87 canvases and
zero represented debt. Admission of captured frame1884 after frame1438 fails
at the exact equality comparison of four matrix-derived physical-unit values.
The complete failure report and both original context hashes are preserved in
`diagnostics/2026-10-22/s236/s235_fault.log` and `fault_observation.json`.
The original s235 implementation/evidence are preserved; this is not a pass.

Both captures have identical verified geometry and runtime material keys.
Their first basis-vector length is recomputed from a rotating FP32 world matrix:

| Derived quantity | Frame1438 | Frame1884 |
|---|---:|---:|
| Scale squared | 1.0000001192092896 | 1.0000000000000000 |
| Physical unit coefficient | 0.6826665997505188 | 0.6826666593551636 |
| UV per physical mm | 0.00146484375 | 0.00146484375 |
| Area m² | 0.04028860852122307 | 0.04028860107064247 |

`s151_engine_inputs.lua` measures `sqrt(dot(basisX,basisX))`; s152 derives the
unit coefficient, squared scale and area from it. Rigid-pose floating-point
roundoff can therefore change these derived values by one or two FP32 ULPs.
s234 incorrectly treated every bit change as a semantic calibration change.
The observed squared-scale difference is about0.119ppm. This is a narrow
measured-unit provenance issue, not a failed water/receipt budget.

The old report does not record the exact configured/applied scale settings.
New explicit provenance below closes that gap; unchanged geometry/material
keys alone are not proof that the transform scale setting was unchanged.

## Repair

A versioned `rain_interval_admission_v2.lua` and default-OFF **s236 two-input
water intervals** panel are installed. Existing s235 code remains available
for its archived failure. The transport/owner/GPU shader bodies are unchanged.

- The main hook supplies the exact configured `activeScale` and applied
  `lastScale`. Both are checked before/after each capture and must match the
  initially admitted settings exactly between intervals. Even a one-ULP setting
  change is refused. Diameter UV/mm calibration remains exact as well.
- Permit at most `8*FP32epsilon` relative drift in matrix-measured squared scale
  (about0.954ppm), with finite positive values, consistent physical-unit/area
  ratios and agreement with every measured basis-vector length. Larger measured
  changes or inconsistent units are refused before GPU work.
- Keep the initially admitted physical reference. Align the new three basis
  rows by `sqrt(referenceScaleSquared/measuredScaleSquared)`, round them to
  FP32, and pin physical-unit/area values and the source-area header to that
  reference. Translation is unchanged. For the observed pair the factor is
  `1.00000005960464`.
- Recompute the admitted header's exact canonical bytes/fingerprint after this
  explicit conversion. Original captured rows, hashes and pose identity remain
  preserved separately in the automatic log. The independent collector applies
  the same specified conversion and checks the derived bytes exactly.

No water is resized, reset or remapped. The constant reference stops pose
roundoff from changing cell areas or physical calibration between retained
intervals. This is not a general approximate identity check: geometry files,
calibration/settings, tokens, status, copies and graph ABI remain guarded.
Display diameter gains do not enter this policy. Runtime cost is a square root
and nine basis-component conversions per admitted interval; GPU cost is unchanged.

## Verification

The exact two logged capture headers reproduce the original s235 refusal in
the old admission code. The new policy admits them without modifying the source
tables. A local stable-setting value of1 is supplied explicitly because the old
report did not capture it; this assumption is not presented as new engine data.

Full1024×256 WARP replay then completes8/8 with518 submissions,178 cache hits,
87 fixed canvases/91.193MiB and no new GPU allocation. Twenty retained copies
remain exact. Water805.772156→805.379883mm³, cumulative evaporation0.028258mm³
and runoff0.363977mm³ pass all eight existing component-wise ledger/inventory
budgets. The first interval agrees with the actual failed run's four water
summary components within the existing128-FP32-epsilon/1e−9 budget. The old
unfinished-checkpoint GPU refusal still passes. Represented time0.0390758514s
finishes with zero represented debt; signed quantization remainder is retained.

Eight CPU refusal controls cover one-ULP configured/applied scale changes,
one-ULP diameter calibration changes, changed geometry, larger measured drift,
nonuniform basis, inconsistent area and missing provenance. All refuse without
consuming new interval time. The shipped panel passes its four lifecycle cases,
88-line independent parser, corrupted scale/derived/scope report refusals and
five lazy-host/capture guards. Lua syntax and installed SDK/helper/link audit pass.

The first version of the replay harness had indentation mismatch while replacing
an AST-extracted test block; corrected before any GPU execution. No shader or
physical coefficient was changed to address that harness error.

The local replay and host/deployment results are supplemented by the actual
CSP observation below. WARP single-draw CPU roundtrips alone do not establish
persistent CSP resource lifetime or target timing.

## Actual CSP observation — passed

Frames1507 and1940 complete two actual main-app inputs and8/8 quarters:
518 accepted submissions,178 cache hits,696 logical passes and the same87
canvases/91.193MiB. Seven slot reuses, eight status reads/eight CPU-data releases
and zero quarantines are recorded. The independent collector accepts all88
lines, original/derived context hashes, pose identities, setting/calibration
provenance, quarter receipts, water budgets and time/remainder accounting.

Configured and applied scale are exactly1 in both captures. Their measured
squared scales both round to1.0000001192092896, while the reciprocal physical
unit changes from0.6826666593551636 to0.6826665997505188. v2 pins this one-ULP
derived difference to the first physical reference. The area reference is
unchanged and source headers are preserved separately. The alignment factor
in this actual pair is1; non-unit factor correction remains local replay
evidence from the original failed pair, not newly observed here.

| Point | Film mm³ | Cumulative evaporation mm³ | Cumulative runoff mm³ |
|---|---:|---:|---:|
| Initial | 805.772156 | 0 | 0 |
| First input completed | 805.599609 | 0.012744 | 0.159767 |
| Second input, first quarter | 805.543579 | 0.016776 | 0.211774 |
| Second input completed | 805.371948 | 0.028873 | 0.371301 |

Every quarter satisfies the existing water budget. Final mass residual is
−0.0000331961mm³; maximum normalized GPU component-ledger residual is0.00386694
(limit1). Neither stock nor cumulative losses restart at the input boundary.
Admitted raw time0.039787299931049347s equals represented time
0.03978729248046875s plus signed remainder0.000000007450580597s
(0.00745058µs); represented debt is0. The remainder is retained for later
admission, not discarded.

This qualifies two sampled actual engine frames and their private retained-state
execution. It does not qualify complete elapsed-time coverage between them,
continuous throughput, general GPU completion, renderer lifetime, FPS, whole-app
memory stability or visible optics. The original s235 failure remains archived.
Actual report/source bindings are in `actual_capture.log` and
`actual_observation.json`; the pre-observation delivery/documentation are kept
as `pending_delivery.json` and `pending_sources/`.

## Actual CSP retest

Start a **fresh unpaused game session** for a clean log quota. In Real Visor
Overlay → RainFX → Weather inputs and physical units (P0), enable
**s236 two-input water intervals** and press **Run s236 two-input water intervals
once**. Leave s235/other diagnostics OFF. Expected:
`observed; inputs2/2; completed8/8; draws518; cached178; retained debt0`.
Signed remainder need not be zero. The88 log lines are automatic. Report those
values or the error; no driving/weather/FPS comparison is required.

The next roadmap remains complete elapsed-time/subdivision/backlog ownership,
then conserved incident/head sources, protected renderer leases/common optics
and target cost/visual adoption checks. Visible game water remains s87.
No Git commit or push is performed.
