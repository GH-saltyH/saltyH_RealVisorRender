# s99 — wet-front continuity, recipient relaxation and accuracy control

Date: 2026-10-17

Status: **ACTIVE — offline corrective implementation and accuracy reference; not game adoption**

## 1. Findings

The s98 high-shear coarse/finer discrepancy is reproduced on 4,251 wet cells
cropped from the published mesh. Holding force depth at100µm or removing force
reduces that discrepancy from about10.45% to1.59–1.60%. Reversing sweep order
leaves it near10.54%; XY/YX coarse fields differ by0.86%. Depth/force feedback
is therefore a major contributor in this case. These counterfactual differences
interact and cannot be added as causal percentages.

Further tracing found two concrete numerical defects at newly wet cells:

1. **Wet-presence discontinuity.** The old arithmetic face average changes from
   the donor speed to half that speed as soon as an adjacent stationary cell
   contains any positive volume, however small. Newly deposited thin water
   relaxes quickly and triggers this artificial face-speed change.
2. **Delayed recipient relaxation.** The old force-before-remap ordering leaves
   newly transferred momentum undamped until the next physical step. A single
   step and two half steps then differ at the new wet front even when the
   incoming layer is very stiff.

Implemented volume-weighted shared faces and a recipient end-force half-step,
while retaining the exact frozen-depth full-interval mean for travel. Added a
positive embedded accuracy controller to verify where the corrected large-step
candidate remains insufficient. Neither correction changes water density,
viscosity, calibration, physical diameter, display gain or weather inputs.

Production Lua/shaders/settings/assets and user materials remain unchanged.
Full head/birth lifecycle, pressure/contact-line calibration and runtime cost
remain separate adoption gates. No new user game measurements are needed now.

## 2. Corrected candidate

### 2.1 Continuous volume-weighted faces

Use existing conserved cell volumes and projected mean velocities:

```text
face = (VL*uL + VR*uR) / (VL+VR)
```

The dry limit is continuous: as `VR -> 0`, `face -> uL`. No physical threshold,
new footprint or adhesion multiplier is introduced. The same symmetric
operation order is used by both cells so shared faces remain bit-identical.
Dry-gap next-wet ordering, positive map width, full-image overtake refusal,
connected run clipping, positive reconstruction and paired end/mean packets
are retained from s98. This is a numerical velocity interpolation, not a
calibrated pressure/contact-angle Riemann solver.

### 2.2 End-force split with a stiff-aware travel predictor

For each physical step of lengthdt:

1. At donor depth, compute the exact frozen-height end velocity fordt/2 and
   the exact mean velocity over the **full dt**. Apply only the first half's
   physical impulse to the end packet.
2. Advect that end packet and the separate full-mean packet across both axes.
3. At recipient depth, apply the remaining end-force half-step, including
   tangent wall reaction. Preserve the already-used path-mean packet.
4. Project/evaporate at the recipient and include all impulses/losses in the
   physical ledger.

A midpoint end velocity is not substituted for the full travel mean. For
stiff relaxation those are different quantities: the predictor oracle observes
a difference as large as0.00575m/s in its100µm case. With unchanged height and
tangent plane, the two end-force halves compose to the exact frozen-height
full response and the travel mean remains the exact full mean.

For evolving depth, curved geometry and evaporation this is **not claimed
second order**. The path predictor still freezes donor depth during the step;
boundary residence and contact/pinning physics need further verification.
The additional recipient pass is deliberately explicit before any fusion.

### 2.3 Physical budgets

The reduction includes donor and recipient applied impulses, all initial and
recipient tangent wall reactions, evaporation, and end/mean runoff. A rejected
proposal publishes none of them. The accepted force ledger satisfies:

```text
final film + heads + evaporation + runoff + wall impulses
    - applied impulses - external supply - original stock = 0
```

Pool return remains an internal volume transfer with its existing wall budget.
Returned heads are staged at rest as in s95–s98; full P1 motion is not coupled
by this offline implementation.

## 3. Positive embedded accuracy reference

Evaluate one corrected coarse step and two corrected half steps from the same
immutable staged stock. Reduce their final volume/end-momentum differences on
GPU. The accepted state is the ordinary positive two-half-step result. There
is no signed Richardson extrapolation or after-the-fact momentum replacement.

The symmetric volume norm sums absolute cell-volume differences divided by
the average total volume. Momentum uses a spatial sum of Euclidean vector
norms, so the norm does not depend on world-axis orientation. Integrated total
evaporation+runoff packets enter both numerator and normalizer, avoiding an
empty-domain blind spot. Individual loss-category errors are not separately
bounded by this total-loss norm.

For original intervalT and trialdt, admit only if both geometric/physical
candidates are valid and:

```text
volume indicator   <= volumeTolerance   * dt/T
momentum indicator <= momentumTolerance * dt/T
```

Both tolerances are numerical accuracy controls, not physical coefficients.
They default to0.02/0.05 in this reference. Sum of the admitted indicators stays
within those allocated interval budgets, but changing normalizers, spatial
remap error and nonlinear evolution mean this is **not a rigorous global-error
bound**. A finer common field is still needed for independent comparison.

Coarse-invalid, fine-invalid or accuracy-invalid attempts retain exact time
debt and halve the cap. Fine-half physical ledgers combine only after both
halves and the estimate pass. Stocks, heads, compensated ledger, interval
clock and receipts publish jointly. An unrepresentable half-dt refuses; the
one-tick blocked-debt limit remains explicit. This does not implement a live
input queue or its recovery policy.

## 4. Evidence and verification

Exercised shaders compile with FXC `ps_5_0 /Ges /WX` and execute in D3D11 WARP.
The harness reads/uploads between draws. No game GPU-ms/FPS or leak conclusion
is drawn from it.

### 4.1 Preserved failure before correction

The initial embedded controller using s98 faces/ordering and default2%/5%
budgets rejected21 times, reached one tick, and retained the full interval
without advancing time. At trialdt=T/64, its volume indicator was0.0011909,
above the allocated0.0003125. Merely reducing dt did not remove the wet-front
discontinuity; eventual floating-point floors further limited the estimate.

Original source snapshots, reports and captured blocked observation are under
`diagnostics/2026-10-17/s99/pre_correction/`. The captured observation is from
the actual failed command output, not a regenerated corrected run. Its
archived reports are audited against archived sources rather than current ones.

After volume weighting alone, the same small-dt volume indicator fell to
0.0001331, but delayed end momentum still failed. With recipient relaxation,
volume/momentum indicators0.0001431/0.0001838 both pass the allocated limits.
These are diagnostic initial-state probes, not final interval accuracy claims.

### 4.2 Direct face, force and norm oracles

- At adjacent volume ratio1e-8, the old face speed jumps from1 to0.5; the
  corrected speed remains1 to float32 precision. A1e-6 ratio gives0.999999.
- Random weighted maps agree with an independent float64 face formula;
  adjacent shared face coordinates are bit-identical.
- For2/20/100/500µm, analytic donor half-end, full travel mean and final two-half
  end response pass. Maximum force-oracle velocity difference is below2.7e-9m/s.
- The full-mean packet is not rewritten by recipient relaxation. Combined
  force-packet residual is below2e-9 in the force-only oracle.
- The independent normalized error formula agrees within3.7e-9; a45° rigid
  rotation changes the norm by less than3.8e-9. Near-empty runoff differences,
  strict refusal and half-dt underflow refusal pass.
- Uniform planar fixed-depth tests agree with the analytic end velocity to
  relative9e-8 or better. Depth is explicitly held for this ODE oracle so ULP
  perturbations from edge remapping do not turn it into a height-feedback test.

### 4.3 Actual-geometry ablations

The160×90 crop rescales UV derivatives by crop/full resolution, retains actual
mm² cell areas and source samples, and pads the4251-cell wet patch. Its tested
crop-edge water is zero. It reproduces the full s98 counterexample within6e-5
relative L1; float32 Jacobian rescaling is not a bitwise full-atlas replay.

| Candidate | Coarse/finer volume L1 | Actual finer accepted steps / refusals |
| --- | --- | --- |
| s98 faces and force ordering | 0.104491 | 4 / 0 |
| Weighted faces only | 0.0640534 | 6 / 1 |
| Weighted faces + recipient relaxation | 0.0624190 | 6 / 1 |
| Corrected, force height held at100µm | 0.0159206 | 4 / 0 |
| Corrected, force-free | 0.0159755 | 4 / 0 |
| Corrected, reverse sweep | 0.0637250 | 6 / 1 |

The finer request uses a maximumdt=T/4; some proposals need further subdivision.
These figures are each method's time sensitivity, **not** errors against a
common exact field. The corrections reduce the specific failure but alone do
not make the coarse step accurate enough for adoption.

### 4.4 Common-reference controller result

The corrected16-piece field is a common numerical reference, not exact physics.

| Volume / momentum tolerances | Accepted / refused outer steps | Volume L1 to common16 | Actual submitted draws |
| --- | --- | --- | --- |
| 0.05 / 0.10 | 10 / 4 | 0.01657422 | 1064 |
| 0.02 / 0.05 | 32 / 5 | 0.00717644 | 2812 |

The corrected coarse step differs from that same16-piece field by 0.09327672 (9.33%); the corrected8-piece field differs by 0.02694821 (2.69%). The embedded runs reduce the comparison differences to1.66% and0.718% while completing all original time ticks.

Both sums of accepted indicators stay inside their allocated budgets; physical ledgers and positive water pass. Crop-edge water remains below1e-8mm³. The strict run represents64 accepted physical half steps, so its smaller difference from16 pieces must not be called an error against ground truth. More refinement is not evaluated here. The16-piece field has its own discretization error and cannot establish final physical accuracy.

Each outer attempt is a resumed one-slot host call, including discarded proposals. Actual1,064/2,812 draws include this repeated staging/publication. A hypothetical single fixed call with the same14/37 slots would submit856/2,236 draws, still far beyond a practical game budget. The experiment validates the corrections and provides an accuracy reference; it does not justify unconditional triple stepping in the app.

### 4.5 Transaction guards

An accuracy-only refusal with valid geometry preserves stock, ledger and full
time debt. A designed viscous compression/source/pool fixture passes combined
half-step physical budgets, source-once transfer, split/together identity and
proactive-cap equivalence. Its water residual is5.08e-8mm³. Loose tolerances10
are used only to isolate those transaction gates, not as an accuracy result.

Stale force/metric receipts, unsupported wet area and pending/error at the
second fine gather or final receipt publication preserve caller-owned handles.
The two-cell compression fixture isolates retry/ownership and is not a general
pressure/collision or compressive convergence proof.

## 5. Cost and adoption decision

The standalone corrected candidate adds **one GPU draw per physical step** and
an additional half-force evaluation at the donor/recipient. Weighted faces add
arithmetic and existing-volume reads without a new image/pass. Physical
coefficients and the physical/display size separation are unchanged.

- s98 graph: `16 + 21A` draws forA attempt slots,37 for one.
- Corrected candidate without embedded estimate: `16 + 22A`,38 for one.
- Full embedded accuracy reference: `16 + 60A`,76 for one,196 for three.

The embedded reference evaluates three candidates per trial, including rejected
trials, and repeats staging/publication on each resumed host call. It is not a
game-performance solution. Submitted graph counts are not GPU-time speedups.
The new recipient diagnostic image is4H (16MiB at1024×256RGBA32F) before fusion;
this is not measured peak memory. Folding recipient force into post transport
and deriving/recording its impulse safely is a concrete next optimization.

Keep the two corrections and the accuracy reference. Runtime adoption still
requires a cheaper validated local coupling/error predictor, fused passes and
actual game timing. Also open: pressure/contact angle/pinning, appropriate
high-shear force regime, full P1/P2 source/head lifecycle, live backlog/recovery
and broader nonlinear spatial/time convergence. A16-piece field is not a
physical ground truth, and no final accuracy order is established here.

Next: reuse this reference to compare a donor/recipient depth/deformation
predictor and fused post-force path, avoiding unconditional triple stepping.
Preserve the original counterexamples, positivity and exact retained-time
protocol when reducing cost.

No game installation, reload/log request, commit or push.

## 6. Reproduce and audit

```text
docs/tools/check_s99_ablation.py
docs/tools/check_s99_faces.py
docs/tools/check_s99_force_predictor.py
docs/tools/check_s99_metric.py
docs/tools/check_s99_guards.py
docs/tools/check_s99_controller.py
docs/tools/finalize_s99.py
```

Diagnostics/baseline/archives are under`docs/diagnostics/2026-10-17/s99/`.
Audit current report/source hashes, archived evidence, prior s91–s98 work,
production Lua/shaders/INI files, published asset hashes and Python syntax.
