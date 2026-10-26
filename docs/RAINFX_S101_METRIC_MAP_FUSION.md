# s101 — metric projection inside the interval map

2026-10-17. Offline candidate after s100. Actual game physics remains s87,
with the existing s89 diagnostic. This stage does not install a game build.

## 1. Implementation

The old split-axis graph first materializes a world-mean-momentum to UV-velocity
image for every cell, then reads it from the interval map. The new map evaluates
the same projection at each wet source/neighbour it queries. It uses the same
signed UV cell centres, discrete geometry reads, world transform, metric inverse
and `packet.gba/max(packet.r,1e-30)` expression as the old mean-velocity shader.

The five remap passes remain map/leaves/groups/totals/gather. The two standalone
mean-velocity passes are removed. An adjacent right neighbour's projected speed
is reused when checking the next real wet source; a nonadjacent wet source is
still projected at its own location. Shared faces retain symmetric conserved
volume weighting. Source intervals, positive reconstruction, full-image
overtake refusal and absorbing boundary accounting are unchanged.

`s101_metric_map_reference.py` reuses the original s99 immutable interval,
snapshot, dyadic debt, embedded accuracy and joint publication protocol. It
retains s100 recipient/post fusion. It does not connect the rejected s100 cheap
proxies to admission or change force, physical diameter, display gain or tuning.

## 2. Numerical verification

Strict FXC `/Ges /WX` and D3D11 WARP tests compare the materialized and fused
paths. All26 axis comparisons are bit-identical for map coordinates/status,
leaf/group reductions, totals, gathered physical end and transported mean.
Tested shared faces also remain bit-identical. Cases include:

- Skewed UV and disconnected valid runs, and a rotated world transform.
- Zero mean with nonzero physical end momentum; degenerate projection.
- Dry neighbour mass ratios0,1e-8,1e-6,.001,1.
- Published curved visor geometry with its actual per-cell Jacobians.
- Nonadjacent moving/stationary fronts at20,60,230 cells of travel. The first
  passes; the latter cases refuse without tunnelling through real liquid.

A full actual-mesh transaction matches s100 in all public and private fields,
head stocks, ledgers, clock and snapshot. Volume residual is1.835e-7 mm3 and
maximum momentum residual1.249e-8 mm3 m/s. The accuracy-only refusal has the
same error indicators and retained debt. A compressive source/pool case matches
the old complete publication, applies source/transfer once, and gives the same
result in resumed/together calls; volume residual5.079e-8 mm3. Stale physics
and metric receipts keep the pending work, and exceptions at the fused map or
snapshot publication preserve caller-owned handles.

These specified tests do not establish universal float32 equivalence, physical
accuracy or target-game compiler/performance behavior.

## 3. Cost: fewer passes with an occupancy-dependent tradeoff

`A` counts all attempted steps, accepted or refused, in one host call. Another
host call repeats16 staging/publication draws. Recipient force is enabled.

| Graph | s100 | s101 |
|---|---:|---:|
| Uncontrolled candidate | 16+21A | 16+19A |
| One uncontrolled attempt | 37 | 35 |
| Embedded reference | 16+57A | 16+51A |
| One embedded attempt | 73 | 67 |
| Three embedded attempts | 187 | 169 |

The two removed RGBA32F velocity outputs total8 MiB of target output extent
per physical advance at1024x256, or24 MiB across three embedded advances. This
is not measured peak allocation or actual bandwidth; one velocity target can
be reused between axes and the driver controls lifetimes/caching.

Each materialized projection pass evaluates one projection per grid cell.
The fused map can evaluate its own, adjacent left/right and next wet neighbour.
Source-level query counts for both axes of the160x90 fixture are:

| Wet layout | Fused / materialized projection queries |
|---|---:|
| Dry | 0 |
| Random1% | 0.0163 |
| Random10% | 0.2064 |
| Random50% | 1.2641 |
| Completely wet film | 2.9826 |
| Actual initial patch | 0.8753 |
| Actual coarse result | 0.8980 |

These count the intended cached-neighbour branch. The report also includes an
uncached-next bound, because compiler branch predication may evaluate unused
ternary expressions. Counts are not texture-cache behavior or dynamic GPU
instruction counts. Arbitrarily thin positive film remains wet; introducing
a physical-volume cutoff to improve these numbers would change the model.

Strict compiled DXBC has49 static instruction lines for the old projection,
118 for the old map, and268 for the fused map. This is static code expansion,
including branches/loop bodies, not runtime instructions or timing. The
disassemblies and binary hashes are retained under the stage diagnostics.

**Decision:** keep the fused map as an equivalent offline alternative. The
dense case performs substantially more projection work, so pass reduction
alone does not justify replacing the materialized path in the game. No game
FPS improvement or peak-memory result is claimed.

## 4. Next implementation

Cache/reuse frozen-interval metric projection coefficients rather than solve
the same local inverse metric at every neighbour query. Compare its setup and
storage cost against both paths, especially dense/thin widespread film and
multiple accepted/refused substeps. The cache must follow geometry/physics
receipts and world transform ownership; it may not survive incompatible
metric/pose changes. Preserve shared-face rounding and the current projection
and loss/refusal oracle when introducing the cache.

The expensive triple physical candidate still needs an economical material
transport/coupling defect estimate. s100's force-free-remap and exact-evaporation
counterexamples remain requirements. Pressure/contact-line/high-shear closure,
general nonlinear convergence, full head/source lifecycle, live backlog and
recovery, then actual game timing remain runtime adoption gates.

Production Lua/HLSL, user INIs/materials, physical calibration and published
assets are preserved. No reload/log request, installation, commit or push.

## 5. Reproduce

```text
docs/tools/check_s101_maps.py
docs/tools/check_s101_transactions.py
docs/tools/check_s101_cost.py
docs/tools/finalize_s101.py
```

Reports, strict disassemblies, preserved baseline, source diff and delivery
audit: `docs/diagnostics/2026-10-17/s101/`.
