# s102 — interval-owned metric projection cache

2026-10-17. Offline implementation after s101. Production remains s87 physics
with the existing s89 diagnostic; no new game build is installed.

## 1. Implementation and numerical operation order

s101 removed standalone UV-velocity outputs but repeated world-basis and Gram
calculations at every queried wet neighbour. s102 prepares the frozen metric
once per interval, then reuses it across both axes, coarse/fine trials, refused
attempts and resumed host calls.

The cache is three RGBA32F banks:

| Bank | Stored values |
|---|---|
| 0 | World U basis xyz, unused w |
| 1 | World V basis xyz, unused w |
| 2 | Original Gram a=U.U, b=U.V, c=V.V, det=a*c-b*b |

Each query still divides the transported mean momentum by its own volume and
uses the **original expression/order** for both UV components. A premultiplied
dual basis would reassociate those expressions, so it is not used here. The
existing determinant cutoff and volume divisor are retained; no new physical
size/depth threshold or display gain enters the model. End and travel-mean
momentum remain separate packets. Force/post metric evaluation is unchanged.

The cache setup writes finite zeros for unsupported/nonfinite basis values.
For wet invalid geometry, the existing physical metric/status path still
refuses the trial; this is not a replacement for geometry validation.

## 2. Ownership and lifetime

One read-only cache pair (data plus receipt) belongs to an immutable interval.
Its nine-row receipt contains:

1. Physics header and metric header.
2. Grid dimensions, format version1 and readiness.
3. All four rows of the object-to-world matrix.
4. Both original batch-header rows, including interval duration and pool tick.

The GPU interval context checks the receipt against the current frozen input.
In particular, a changed pose is refused **even if the caller leaves the old
physics-version number unchanged**. Physics/metric version, grid, format,
readiness, batch or pool-tick mismatches also refuse ownership. A reused cache
is not automatically replaced while private progress owns unfinished time.

New intervals start with `private=None` and build a new immutable pair.
Resumed calls receive `private['projectionCache']` and keep the same pair.
Successful publication still consists only of the previous public field/head/
ledger/header/snapshot schema; the cache is private scratch. A live application
must release the completed interval's private cache when retiring that interval.
This prototype has no live queue, cross-interval cache eviction or shared cache
manager. Raw geometry edits still require a new metric version; the existing
batch factory freezes/copies geometry and physical inputs.

Preparation of the data and receipt is covered by the same caller-side output
fence: an exception returns no partially created pair or new public handles.
It does not cryptographically validate caller-fabricated data/receipt mixtures.

## 3. Verification

Strict FXC `/Ges /WX` compilation and D3D11 WARP execution pass.

- All26 axis comparisons match s101 bit-for-bit in map/status, leaf/group
  reductions, totals, physical end/mean gather and tested shared faces.
  Cases include skewed/disconnected UV, rotation, affine scale/skew, degenerate
  bases, actual curved visor geometry, dry-limit volume ratios and determinants
  just below/at/above the existing inverse-metric cutoff.
- The complete actual-mesh transaction matches s101 in all old public/private
  fields. Volume residual1.835e-7 mm3; maximum momentum residual1.249e-8 mm3 m/s.
- A compressive source/pool trial refuses, resumes with the same cache and then
  completes. Resumed/together and s101/s102 publications are bit-identical;
  source and pool transfer occur once. Residual5.079e-8 mm3.
- Nine GPU receipt cases admit only the matching input. A full pending
  transaction with changed pose/same version keeps public stocks and private
  water/time unchanged; a fresh cache prepared from that pose owns it.
- A nonfinite pose produces a not-ready receipt. The legacy native harness
  cannot reliably parse textual NaN uniforms, so this test injects a NaN bit
  pattern in the shader instead.
- Pending exceptions at cache-data preparation, receipt preparation, the map
  and final snapshot publication preserve caller-owned state.

These are specified float32/backend checks, not universal equivalence or a
physical-accuracy claim. Actual game compiler, timing and lifetime behavior
remain untested for this offline cache.

## 4. Cost and diagnostic correction

There are two setup draws **once per new interval**, with no setup draws on
resume. `A` is attempts in one host call, including refused attempts:

| Graph | Fresh cache | Reused cache |
|---|---:|---:|
| Uncontrolled candidate | 18+19A | 16+19A |
| Embedded accuracy reference | 18+51A | 16+51A |

One fresh embedded attempt is69 draws versus s101's67. Three attempts in one
fresh call use171 versus169. A one-attempt refusal followed by two resumed
attempts uses69+118, with no repeated cache preparation. The extra setup is an
ALU/storage tradeoff; this stage does not reduce the embedded physical graphs.

At1024x256 the retained cache has12 MiB of RGBA32F data plus144 receipt bytes.
That is explicit resource extent, not measured peak app memory. Queries now
load three cache banks instead of two geometry inputs and repeated transforms/
Gram calculations; they still compute velocity-dependent dot products.

For the fully wet160x90 fixture and three physical advances, s101's source
model makes257,700 world-basis/Gram evaluations; the new cache writes43,200
setup pixels and performs none of those calculations inside the map. The
materialized s100 path would evaluate86,400. These are different source/setup
invocation counts, **not a6x or2x measured speedup**. Three setup banks repeat
preparation work, so dry/sparse or short intervals can lose. Physical force/post
geometry work is excluded from this projection comparison.

The static disassembly parser was corrected: the former whitespace-only
opcode pattern omitted parenthesized `ld_indexable(...)` and similar opcodes.
The preserved s101 assemblies recount as54 projection,128 materialized-map
and288 fused-map instruction lines (formerly49/118/268). The new cache prepare
has63 and cached map225, including2 and22 static texture-load lines. Earlier
reports/assemblies remain unchanged; the corrected recount is in s102's report.
Static code includes branches and loop bodies, so these counts are not dynamic
GPU instruction counts, bandwidth or execution time.

**Decision:** keep the interval-owned cache as a verified offline alternative.
It removes the dense repeated basis/Gram solves but adds setup, storage and
loads. No unconditional target-game performance improvement is established.

## 5. Next implementation and adoption limits

Reuse the same owned world bases in physical force/post metric evaluation,
where repeated geometry transforms are still present. Preserve normals, area,
physical impulse/wall/evaporation budgets and all stale-pose/fence checks; compare
its cost against the uncached oracle. Then continue the economical material
transport/coupling error estimate, preserving s100's rejected-proxy examples.

Triple-candidate cost, pressure/contact-line/high-shear closure, general
nonlinear convergence, full head/source lifecycle, live backlog/recovery and
target-game timing remain adoption gates. Production Lua/HLSL, calibration,
user settings/materials and published assets are preserved. No game reload/log
request, installation, commit or push.

## 6. Reproduce

```text
docs/tools/check_s102_cache.py
docs/tools/check_s102_transactions.py
docs/tools/check_s102_cost.py
docs/tools/finalize_s102.py
```

Baseline, reports, strict disassemblies, source diff and delivery audit:
`docs/diagnostics/2026-10-17/s102/`.
