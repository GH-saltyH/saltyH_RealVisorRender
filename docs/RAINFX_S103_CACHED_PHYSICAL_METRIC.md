# s103 — cached world bases in force and post metrics

2026-10-17. **Status: ACTIVE — offline prototype.** Production remains s87
physics with the existing s89 diagnostic; no game installation in this stage.

## 1. Implementation

s102 cached the world U/V bases and Gram values for interval-map queries, but
physical force and post projection still fetched the original geometry and
transformed those bases repeatedly. s103's physical `stepMetric` reads the same
owned cached U/V bases. Cross product, squared normal length, reciprocal square
root, normal orientation, current cell-area read and `gFilmScale2` application
retain the original expression/order. Physical SI constants, depth/diameter,
coating, display gain, air controls and evaporation law are unchanged.

The physical metric now uses two cache-bank reads in place of the two geometry
reads and world transforms. It still reads the actual physical cell area;
normals and area are not separately precomputed in this stage. Projection maps
and the positive time/admission/publication protocol remain unchanged.

## 2. Cache format2: independent basis validity

The new consumer needs to distinguish a valid physical basis from an unusable
inverse Gram. s102 cleared both bases if any Gram value overflowed. A finite
pair such as U=(1e20,0,0), V=(0,1e-20,0) has a finite usable cross product while
U.U overflows. Erasing that basis would incorrectly invalidate the physical
metric when adding cache reuse. This synthetic case is a representation
regression; it is not evidence that such an inverse metric is usable for flow.

The new preparation stores:

| Bank | Format2 values |
|---|---|
| 0 | Finite world U xyz, w=1; otherwise zero and w=0 |
| 1 | Finite world V xyz, w=1; otherwise zero and w=0 |
| 2 | Finite original Gram a/b/c/det; otherwise zero |

The physical metric checks both validity bits, original finite checks and normal
support independently of Gram. Projection still uses the original cached Gram
and determinant cutoff; it does not read those two new w flags.

No extra target/bank is allocated. The existing nine-row receipt now requires
format2. A format1 pending cache refuses ownership rather than being silently
interpreted or rebuilt. All previous pose/version/grid/interval checks and
preparation/publication fences remain. Old pending progress is not migrated
here; refusal retains its water and unspent time. Live recovery/retirement still
needs an explicit application policy before integration.

## 3. Verification

Strict FXC `/Ges /WX` compilation and D3D11 WARP execution pass.

- **15 physical cases:** cached normal/area, all four donor-force banks and all
  five fused recipient/post banks are bit-identical to s102's uncached physical
  oracle. These include ordinary/full evaporation, downward airflow, zero dt,
  disabled recipient force, affine/reflected transforms, invalid/NaN area,
  invalid viscosity, degenerate/nonfinite basis, Gram overflow, and normals
  below/at/above the existing support threshold.
- **26 projection comparisons:** format2 preparation preserves map/status,
  reductions, totals, end/mean gather and tested shared-face coordinates.
  The preserved s102 fixture is reused with old/new cache preparation; inverse
  determinant cutoffs, dry limits, affine/skew and actual geometry are included.
- **Actual-mesh full transaction:** all physical public/private progress fields
  match s102. Cache format/validity contents intentionally change. Volume
  residual1.835e-7 mm3; maximum momentum residual1.249e-8 mm3 m/s.
- **Source/pool retry:** one refusal followed by resumed completion uses one
  cache. Joint publication matches s102 and the together call; source/transfer
  occur once. Residual5.079e-8 mm3.
- **Ownership/fences:** prior nine receipt tests, same-version changed-pose
  refusal and fresh-pose preparation pass. A full format1 reuse attempt also
  keeps public stocks and private water/time. Pending data/receipt/map/snapshot
  passes preserve caller handles. Nonfinite pose remains not-ready using the
  existing GPU NaN-bit test, without relying on text-uniform NaN parsing.

The regression adapters assert exact fixture anchors and retain fixture hashes;
previous test files and evidence are unchanged. Specified float32 equivalence
does not prove every input/backend or physical accuracy.

## 4. Cost

No extra setup draw, retained bank or per-attempt draw is introduced. At1024x256
the cache remains12 MiB plus144 receipt bytes. With `A` attempted steps in one
host call (including refused attempts):

| Graph | Fresh interval | Resumed interval |
|---|---:|---:|
| Uncontrolled candidate | 18+19A | 16+19A |
| Embedded accuracy reference | 18+51A | 16+51A |

The fresh single embedded attempt still uses69 draws; three attempts use171.
Another host call repeats the16 fixed transaction draws, but not cache setup.

The corrected static DXBC counter includes parenthesized texture opcodes:

| Shader | s102 instruction lines | s103 instruction lines |
|---|---:|---:|
| Donor force | 238 | 221 |
| Fused recipient/post | 338 | 302 |
| Cache preparation | 63 | 65 |

Both new physical shaders no longer bind original `txRainDu`/`txRainDv` in their
compiled reflection. They read the owned cache instead. Static texture-load
lines remain5 for force and12 for recipient/post; loads are redistributed and
world transforms disappear. Normal cross/normalization, area, packed output
banks and triple-candidate work remain. Static code size and resource bindings
do not measure dynamic GPU instructions, frame time, bandwidth or peak memory.

**Decision:** retain the equivalent cached physical metric. It reduces repeated
geometry arithmetic with unchanged storage/pass counts, at the small setup-code
cost shown above. Actual target-game performance remains unmeasured.

## 5. Next implementation and adoption limits

Within the fused recipient/post invocation, share the local metric result
between force relaxation and post projection/evaporation. Keep geometry
validity separate from force-parameter validity: invalid viscosity may reject
force while geometry and evaporation still have their original post behavior.
Compare packets and static work before considering more cache storage. Then
continue the economical material transport/coupling error estimate; s100's
force-free-remap and exact-evaporation counterexamples still apply.

Pressure/contact-line/high-shear closure, general nonlinear convergence, full
head/source lifecycle, live backlog/cache retirement/recovery and actual game
timing remain adoption gates. Production Lua/HLSL, physical calibration, user
INIs/materials, published assets and earlier stages are preserved. No reload/
log request, installation, commit or push.

## 6. Reproduce

```text
docs/tools/check_s103_physics.py
docs/tools/check_s103_projection.py
docs/tools/check_s103_transactions.py
docs/tools/check_s103_cost.py
docs/tools/finalize_s103.py
```

Baseline, reports, strict disassemblies, source diff and delivery audit:
`docs/diagnostics/2026-10-17/s103/`.
