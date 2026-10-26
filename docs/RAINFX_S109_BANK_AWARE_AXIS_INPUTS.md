# s109 — bank-aware integer axis inputs

2026-10-17. **Status: ACTIVE — offline ABI reference; performance adoption
not approved.** Production remains s87 physics with s89 diagnostics.

## 1. Bounded input contract

s108 exposed the cost of materializing packed CPU row-band views as separate
GPU textures. s109 binds the full parent texture for exactly two axis inputs,
`txAdvEnd` and `txAdvMean`, and adds the logical bank's row origin to integer
loads. This is a shader input contract, not an SRV subrect or a new allocator.

The adapter covers their consumers in axis map, leaves and both gather variants.
Groups/totals do not reference these packet textures; their unused supplied
bindings are removed. Changing only gather would leave copies already required
by earlier map/loss consumers. All other texture bindings and physical/source/
publication consumers retain their previous contracts.

Host binding requires float32 RGBA, a full-width contiguous row band, integer
positive logical grid, aligned nonnegative origin and a contained parent with
at most16384 rows. Only single-argument integer `Load` is supported. Filtered
sampling, dimension queries, load-offset overloads, missing bindings and column/
strided views fail closed. The adapter never changes physical grid dimensions
to match the larger parent texture.

The checked shader helper returns0 for coordinates outside the **logical**
grid or nonzero mip, before applying the row origin. Simply adding an offset
is incorrect: a negative local row or a row just beyond the logical height can
read a neighbouring packed bank instead of the copied texture's zero border.
The ABI test reproduces that leak and verifies its isolation. No sampling or
filtering contract is changed.

The immutable offline flag `gResearchBankAxisInputs` defaults to1 for research
runs. Set0 to restore the unmodified s107 shader/binding path. It is not a game
setting. Coarse/first-fine compaction, either axis order, second-fine published
mean, all six physical total rows, sources/pool, interval clock and receipts
remain as before. There are no new draw passes.

## 2. Verification

Strict FXC `/Ges /WX` compilation and D3D11 WARP execute actual parent textures,
not a CPU-only address simulation:

- Ten coordinate/mip cases match separate logical input textures bit-for-bit,
  including both bank boundaries and out-of-range coordinates. Nine host ABI
  guards reject unsupported operations, layout/format and grid errors.
- All36 prior axis cases retain identical maps, leaves, groups, admission,
  runoff and end gather. Cases include affine/curved geometry, degenerate/dry
  limits, nonadjacent overtake refusal and both complete-runoff directions.
- Each modified axis draw in the six s108 call scenarios and real pending
  prefixes also runs its original shader with separate logical textures as a
  GPU copy oracle. Outputs must match before later physical stages proceed.
  This checks full and end-only gathers, either axis order, accepted/refused
  steps, source/pool resume and actual curved packets.
- Source/pool transfers remain once-only; split and uninterrupted publication
  agree. Full-binding opt-out reproduces actual curved final stocks/mean/ledger.
- The s108 target lifetime/copy model is rerun on the actual parent bindings.
  Every consumer, retained export and failure prefix survives CPU pool replay,
  with all six overwrite/alias/descriptor/stride mutation guards retained.

Per-draw GPU equality establishes the specified binding transformation's
numeric equivalence in these cases; it does not prove universal float32
equivalence or a new physical model. Pool replay is still captured-output CPU
ownership verification, not an implemented GPU allocator.

## 3. Arithmetic and resource tradeoffs

| Compiled kernel | s107 static instruction lines | Checked bank ABI |
|---|---:|---:|
| Map | 225 | 331 |
| Leaves/loss | 126 | 175 |
| Full gather | 199 | 262 |
| End-only gather | 191 | 250 |

Logical bounds checks and address additions have substantial compiled cost.
These are static code lines, not dynamic work or target GPU timings. Existing
physical and transport source kernels are unchanged; only the bounded load
adapter adds code.

At symbolic1024x256/4096 heads, one default fresh attempt has:

| Logical resource quantity | s108 copy oracle | s109 bank inputs |
|---|---:|---:|
| Shader draws | 69 | 69 |
| Conservative bank copies | 29 | 17 |
| Copy output extent | 116 MiB | 68 MiB |
| New targets without reuse | 333.08 MiB | 285.08 MiB |
| Exact-size target pool reservation | 141.89 MiB | 149.89 MiB |

Twelve logical copies disappear per default attempt. However, the first-axis
packed gather parent must now remain alive through the second-axis gather;
the copy oracle could retire it after materializing its two bands. The changed
lifetimes and descriptor compatibility increase reserved pool extent by8 MiB
in this case, despite reducing copied bytes. Mean/head/diagnostic exports and
non-axis consumers still require their explicit copies.

The per-scenario resource report includes resumed/multiple attempts and imports.
As in s108, these are logical subgraph budgets, not measured game memory,
bandwidth or FPS. In-flight completion, device overhead, binding/unbinding and
all other app resources remain outside this proof.

**Decision:** retain the checked ABI as an equivalent offline reference and
fallback basis. Do not adopt it as a performance optimization on copy reduction
alone. It trades fewer copies for more shader work and longer parent lifetimes.

## 4. Next implementation

Investigate separating provably in-range centre loads from loads that can cross
a logical boundary, using the checked helper as the oracle. A fast load needs
an explicit call-site/domain proof; malformed/disconnected run data must not
permit neighbour-bank leakage. Preserve checked fallback and exact output/
loss/refusal behavior. Re-evaluate arithmetic and parent-lifetime costs before
choosing the next binding/packing strategy. Do not weaken error tolerances or
remove bounds blindly to obtain a lower instruction count.

Live allocator/retirement, bounded work/backlog, diagnostic retention, economical
material error estimation, triple stepping, physical closure/general convergence
and full live head/source integration remain adoption gates. Runtime Lua/HLSL,
calibration, INIs/materials, assets and prior evidence are preserved. No reload/
log request, install, commit or push; target game benefit is unmeasured.

## 5. Reproduce

```text
docs/tools/check_s109_abi.py
docs/tools/check_s109_axis.py
docs/tools/check_s109_transactions.py
docs/tools/check_s109_cost.py
docs/tools/finalize_s109.py
```

Prototype helper: `docs/prototypes/s109/bankLoad.hlsl`. Binding factory:
`docs/tools/s109_bank_axis_reference.py`. Baseline, reports, resource DAGs,
strict disassemblies, source diff and audit: `docs/diagnostics/2026-10-17/s109/`.
