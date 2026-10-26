# s100 — fused recipient force/post and cheap proxy evaluation

2026-10-17. Offline implementation following s99. Production remains s87
physics with the existing s89 diagnostic; this stage does not install a game build.

## 1. Implemented path

`docs/tools/s100_fused_reference.py` uses the unchanged s99 interval transaction,
weighted faces, two-axis positive remap and positive embedded accuracy gate.
It replaces recipient force plus post projection/evaporation with one pass.

The old recipient image contains four RGBA32F banks and the old post image
another four. The fused image contains five:

| Bank | Packet |
|---|---|
| 0 | Final end volume/momentum |
| 1 | Transported full-interval mean, projected and evaporated as before |
| 2 | Evaporated volume/momentum |
| 3 | Sum of donor/recipient/post status and wall impulses |
| 4 | Sum of donor/recipient applied impulses |

The donor impulse/wall image already exists. Read its diagnostics in the fused
pass and sum in **the same order as s99**; then retain the same compensated
tile/global reductions. Do not recover the small force impulse by subtracting
large final momenta. `fusedPost` is an asserted textual adaptation of the
unchanged post function, accepting local packets instead of a texture reload.
The recipient mean is still the transported full-interval travel mean; it is
not replaced by the second half's mean. Physics constants, depth, physical
diameter and display gain are unchanged.

## 2. Equivalence and retained progress

Strict FXC `/Ges /WX` compilation and D3D11 WARP execution pass for every new
shader. Seven direct comparisons cover ordinary partial evaporation, disabled
recipient force, full evaporation, invalid area, invalid evaporation, zero dt
and downward-air control. All tested end/mean/evaporation pixels and all
physical tile ledger blocks are **bit-identical** to s99.

On the cropped published curved visor geometry, a complete uncontrolled
transaction is bit-identical in public fields/heads/ledger/header/snapshot and
private state, and also matches s99's saved coarse field. Volume residual is
1.835e-7 mm3; maximum momentum residual is1.249e-8 mm3 m/s.

The embedded accuracy-only refusal retains all water/time and matches s99.
A compressive source+pool test refuses the first trial, then completes two
halves. Resumed and together calls, and the complete s99/s100 publication,
are bit-identical; source and internal pool transfer occur once. Its volume
residual is5.079e-8 mm3. Pending exceptions at the new fused pass and final
snapshot publication preserve all caller-owned handles.

These are specified float32 equivalence tests, not a proof for every input or
the compiler/backend used in the game.

## 3. Cost change

Counts below include the existing16 fixed transaction draws. `A` is the number
of attempted steps **in one host call**, including refused attempts; recipient
force is enabled. Resuming another host call repeats the fixed overhead.

| Graph | s99 | s100 |
|---|---:|---:|
| Uncontrolled candidate | 16+22A | 16+21A |
| One uncontrolled attempt | 38 | 37 |
| Embedded accuracy reference | 16+60A | 16+57A |
| One embedded attempt | 76 | 73 |
| Three embedded attempts | 196 | 187 |

Recipient/post output targets decrease from8H to5H per physical advance.
At1024x256 RGBA32F this removes12 MiB of allocated target extent/output pixels
per advance, or36 MiB of target output extent across three embedded advances.
This is **not peak memory or measured memory bandwidth**: lifetimes, driver
allocation, cache traffic and shader work matter. Five output banks can repeat
recipient SI calculations in more pixel invocations than its former four-bank
pass. The fusion trades passes/targets for ALU; an FPS gain is unmeasured.
The opt-out path previously had no recipient draw and does not gain that draw
reduction. Full triple stepping remains too costly for runtime adoption.

## 4. Cheap estimators: measured rejection of two replacements

Implemented two diagnostic proxies in two small reduction passes, disconnected
from admission/publication:

- **Eulerian depth change:** symmetric L1 of before/after cell volume. Actual
  areas are unchanged within a cell, so this is also a local depth comparison.
  It compares fixed positions, not transported donor material.
- **Drag-only defect:** volume momentum weighted change of the half-step
  exponential viscous attenuation when local before/after depths differ.
  It omits changing drive, newly wet cells, remap and integrated losses.

Both GPU reductions agree with independent float64 formulas within3e-6. The
existing2% volume/5% momentum interval budgets are used only for a comparative
threshold experiment; they do not calibrate either proxy as an error bound.

1. **False acceptance by drag-only proxy.** Force-free fractional translation
   of an isolated resolved packet gives proxy0, while one-step/two-half volume
   difference is2.1998% and momentum difference2.1998%. The existing embedded
   gate refuses. Removing force coupling does not remove spatial remap error.
2. **False refusal by depth-change proxy.** A uniform2um film with exact4um/s
   evaporation has essentially zero embedded error, but real depth change is
   22.22%,10.53%,5.13% for dt0.1/0.05/0.025s. It refuses every trial against
   interval allocations2%,1%,0.5%. Halving dt cannot distinguish this exact
   physical change from numerical error; using it as the gate can stall time.
3. The actual curved high-shear case is compared at the original interval and
   at an admitted smaller interval. The original coarse/two-half comparison
   is geometrically ineligible, so its error numbers are not calibration data.
   The smaller case checks proxy behavior against an eligible embedded trial.
   Details are in `proxy_checks.json`.

Neither proxy replaces the embedded controller. Combining them with arbitrary
thresholds would not establish safety. The missing information is a material
coupling/remap defect, not simply the amount of physical depth change.

## 5. Next implementation and adoption limits

Keep the equivalent fusion. Next compare folding metric mean-velocity
projection into the axis map against its extra neighbour Jacobian/ALU work;
preserve exact shared-face coordinates and all map/refusal guards. Then seek
an economical transport/coupling defect estimate using the existing embedded
results as counterexamples. Do not relax error gates or introduce minimum
physical depth/size to make a cheap predictor pass.

Pressure/contact-line/high-shear calibration, general nonlinear space/time
convergence, full head/source lifecycle, live backlog/recovery and actual game
timing remain adoption requirements. No game reload/log request, runtime
change, settings/material change, commit or push in this stage.

## 6. Reproduce

```text
docs/tools/check_s100_fusion.py
docs/tools/check_s100_transactions.py
docs/tools/check_s100_proxy.py
docs/tools/finalize_s100.py
```

Reports, source diff, preserved baseline and delivery audit:
`docs/diagnostics/2026-10-17/s100/`.
