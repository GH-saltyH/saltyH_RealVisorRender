# RainFX s94 — two-axis coherent history and stock mutations

Date: 2026-10-16
Status: ACTIVE — offline GPU prototype; production physics remains s87

## 1. Scope and decision

Continue the user-stamped s90 lineage and local s91–s93 numerical work.
Extend s93's complete-image coherent position to both coordinates. A point's
numerical CIC copies must travel through X and Y with the same interpretation.
After an incompatible source edit or mixed deposit, use resolved cell centres.
Do not reconstruct a material interval from mixed first/second moments; s93
demonstrated that this moves static water without any applied velocity.

The selected representation is a resolved film stock with optional subcell
position coherence. It is **not** a new population of spherical droplets,
a droplet radius, a physical contact line or a calibrated pressure law.
Physical volume and end/mean world momentum remain independent of display gain.

No runtime Lua, production shader, texture asset, user material or tuning change.
No game installation, new game test request, commit or push.

## 2. History payload and complete-image certificate

One RGBA32F texel per film cell:

| Channel | Meaning |
| --- | --- |
| RG | point X/Y offsets from this cell centre, in grid cells |
| B | resolved volume tag, in mm³ |
| A | coherent image eligibility, 0 or 1 |

A coherent point can occupy up to four positive bilinear/CIC image cells.
The active axis uses its own offset during the unchanged s93 bounded,
mass-weighted pressureless projection. Gather carries the transverse coordinate
from the source history as well. A recipient may retain history only if all
contributors identify the same two-coordinate point.

Local recipient purity is insufficient. The subsequent certificate reads the
complete 2×2 image and checks point agreement, eligibility and the bilinear mass
ratios. If a companion is mixed or inconsistent, every affected copy falls back
to its resolved cell centre. At a rectangular component edge, only connected
in-component recipients participate and their kernel weights are normalized.
Ambiguous diagonal connectivity around a hole clears history conservatively.
Every copy checks the same full stencil topology: an L-shaped or disconnected
positive image is ineligible even when one local copy links to both neighbours.

Coordinate tolerance is eight float32 epsilons times coordinate magnitude;
mass-image comparison uses 2e-5 of the local image volume. These are numerical
certification tolerances. They never rescale the physical stock or momentum.
No persistent identity list, per-drop CPU stamp loop or readback-driven draw
branch is introduced in the proposed pass graph.

## 3. Birth, evaporation and pool-return boundary

Before transport, `pointHistoryValidate.hlsl` reads immutable previous stock,
post-source stock and previous history. This is a **boundary contract**, not yet
the live P2/P4b source pipeline.

- Unchanged volume/momentum and a valid complete image retain history.
- Uniform proportional removal across all copies can retain the coordinates;
  tags update to the actual remaining volumes. This permits uniform evaporation
  without destroying subcell history every frame.
- New water, asymmetric removal, a missing copy, or independently changed end
  or mean momentum clears the complete old image. This includes a localized
  pool-return debit. Its actual water removal stays in the source stock.
- Source packet comparisons allow 2e-6 relative arithmetic roundoff when
  checking proportional removal. They do not modify any packet.
- The prior volume tag and prior complete CIC mass image must themselves agree.

Tests use synthetic birth/removal/momentum edits. Live source event generation,
P4b accepted-event ownership, force ordering, head publication and simulation
generation binding remain to be connected. A generally nonuniform film
evaporation rate is allowed to invalidate history; shape preservation under
repeated such edits is not claimed here.

## 4. Two-axis publication

Both axes execute their bounded work and GPU admission paths. A final shader
publishes **end stock, mean stock and history together** only if both axes
accepted. Otherwise all three input banks are returned bit-identically.
A separate GPU diagnostic loss reduction uses the same pair of admission flags:
provisional runoff from the first axis is suppressed if the second axis fails.
The CPU reads results to assert tests; it does not select the stock draw branch.

This transaction begins at the post-source transport boundary. It is not yet
an atomic production update of source/head/reservoir/runoff/clock generations.
Rejected elapsed time still needs an admitted retry/fallback scheduler before
runtime adoption; simply holding stocks and consuming dt would be incorrect.

## 5. Verification

All tested paths compile with FXC ps_5_0 `/Ges /WX`, and execute in D3D11 WARP.
Reports are in `diagnostics/2026-10-16/s94/`.

### Two coordinates and symmetry

An independently evaluated bilinear point moves from (20.8,22.3) to
(28.18,17.68) grid cells in 0.03s. Both X→Y and Y→X at 30/60/144Hz retain
four coherent image cells. Worst absolute volume-profile L1 error is
5.79e-6 mm³ for a 1mm³ point; mass residual is below 3.73e-8 mm³.
Transposing coordinates, momentum and sweep order gives identical packets in
the specified fixture. Full reflection gives max packet difference 2.74e-4
in a test using grid-cell/s momentum values up to hundreds.

These are planar frozen-force checks, not general axis-order invariance for
colliding film or recurrent SI-force convergence.

### Mutations, mixed images and rejection

Synthetic birth, asymmetric evaporation, localized pool return, end-momentum
change, mean-momentum change and a removed copy all invalidate the complete
old point image. At zero velocity the post-source stocks remain bit-identical.
Uniform proportional removal retains coordinates and updates volume tags.

Partial transverse overlap invalidates four locally pure-looking edge copies;
after stopping motion, stock L1 change is zero. A stale volume tag invalidates
its complete image. A clipped corner point has no repeated zero-step runoff.
An L-shaped three-cell component clears all histories before moving and keeps
its zero-velocity stocks bit-identical.

The rejection fixture admits X and rejects an oversized Y group. It contains
distinct end/mean momenta, nonzero initial histories and actual provisional X
runoff. Final stock/history roll back and published rejected runoff is zero.
An accepted outflow case publishes the actual distinct end/mean momentum losses
and zero remaining stock, excluding an accidentally always-zero loss branch.

### Actual geometry bridge

Same actual-mesh synthetic 100µm/4,251-cell SI patch used in s91–s93; one frozen
force step, no replay stock or live sources:

- Both axes accept; 149 new wet cells.
- Input water: 145.436235789 mm³.
- Water residual: −2.30386e-7 mm³.
- World momentum + outflow + wall residual: at most 2.794e-9 in packet units
  (mm³·m/s; multiply by water density in kg/mm³ for SI momentum).
- Peak resolved film height: 103.0594µm.
- Final coherent cells: **zero**. This dense mixed film correctly falls back
  to resolved stock; the test proves compatibility/conservation, not a shape
  improvement for dense film.

## 6. Cost and remaining adoption gates

The history payload remains one RGBA32F H-sized texture: 4MiB at 1024×256.
The two-axis extension adds a post-source validation pass and final three-bank
publication pass to s93's estimated coherent graph. Standalone transport is
20 steady passes, excluding the manual per-axis loss probes and final 1×2 loss
probe. With two mean projections plus the three SI predictor/prepare/commit
passes, the unfused estimate is **25 draws per step**.

The gather target is 3H (12MiB); a distinct final three-bank target is another
12MiB before lifetime aliasing. The H-sized validation result needs 4MiB if
not reused. These are raw allocations, not measured peak engine memory.
Certificate and source validation each inspect a bounded 2×2 history image plus
its 2×2 topology mask;
source projection still has s93's bounded 33-source window/16-member group cap.
The old hierarchy/gather traversal cost is unchanged. This graph is not ready
for a low-cost runtime claim. No game GPU ms or FPS was measured.

Next implementation gates:

1. Bind history, post-source stock, accepted head/P4b events and time to one
   generation; publish cumulative loss and clock atomically, including rejection.
2. Complete rejected-dt retry/fallback without silently dropping time.
3. Couple recurrent SI force/height and evaporation to the chosen representation.
   Numerical CIC copies must not accidentally receive an independent physical
   droplet law; dense film fallback still needs general time/shape convergence.
4. Pressure/contact-line and general interaction/rotation tests, then pass/storage
   fusion and actual game cost. Transpose/reflection fixtures alone do not close
   arbitrary curved-surface rotational convergence.

## 7. Reproduce

Use the bundled Python runtime with NumPy and the existing FXC/WARP harness:

```text
docs/tools/check_s94_points.py
docs/tools/check_s94_mutations.py
docs/tools/check_s94_mixed_images.py
docs/tools/check_s94_dense_mesh.py
docs/tools/finalize_s94.py
```

The final audit compares the staged s93 baseline, verifies prior local work,
runtime and asset hashes, records current source hashes and produces delivery
metadata/source diff. The user retains control of Git stamps.
