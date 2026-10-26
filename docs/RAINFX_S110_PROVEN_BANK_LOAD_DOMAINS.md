# s110 — proven in-grid bank load domains

2026-10-17. **Status: ACTIVE — offline call-site proof and specialization.**
Production remains s87 physics with s89 diagnostics; no game build is installed.

## 1. What can safely omit the repeated check

s109's checked bank ABI preserves logical zero borders, but adds bounds work
at every load. s110 separates loads with a closed in-grid domain proof from
loads whose addresses still depend on untrusted run values. The proof applies
only to four exact shader bodies, identified by frozen SHA256 fingerprints.
An edited shader, changed loop bound or incompatible grid metadata falls back
to the fully checked ABI.

| Kernel/context | Proven address | Reason | Checks retained |
|---|---|---|---|
| Map centre | `p`, mip0 | normalized fullscreen pixel centre, upper-clamped cell | neighbour `p±axis`, next-source `q` and their speeds |
| Leaf/loss source | `p`, mip0 | nonnegative leaf/lane loops, lane<lanes and row<rows | slope neighbours controlled by run bounds |
| Gather centre | `p`, mip0 | normalized fullscreen cell and packed output bank mapping | slope neighbours |
| Gather source | `q`, mip0 | nonnegative group/leaf/src loops with src<lanes, row<rows | slope neighbours |
| `advFraction`/`advSlope` centre | their `p`, mip0 | closed call graph from bounded leaf/gather source domains | their `p±axis` loads |

The map's centre speed has a separate exact copy of the speed function using
the in-grid mean load. Other speed calls remain checked: their parameter named
`p` can actually be an out-of-grid neighbour or next-source coordinate. A
variable's spelling alone is not a proof. All floating physical/transport
expressions and their operation order remain unchanged.

Axis metadata must match the logical grid exactly: axis0/1, lanes/rows,
ceil(lanes/16) leaves and ceil(leaves/16) groups, with integer grid dimensions
in1..16384. No assumption about the **contents** of the run texture is made.
Negative starts, oversized ends, reversed bounds or inconsistent islands do
not authorize unchecked neighbour loads.

This research renderer's invocation contract is normalized fullscreen
pixel-centre `PS_IN.Tex`; a different renderer/domain requires a new proof.
The helper is not an unrestricted load API for arbitrary shaders. Unknown
source bodies retain checked loads, including the arbitrary-coordinate ABI
probe. Host row-band format/stride/origin and unsupported-operation guards from
s109 run before proof selection and are not bypassed.

The immutable offline flag `gResearchProvenBankLoads` defaults to1. Set0 for
the complete s109 checked bank path. `gResearchBankAxisInputs=0` independently
restores the s107 separate-input/copy path. Neither is a new runtime/UI option.

## 2. Evidence

Strict FXC `/Ges /WX` and D3D11 WARP verify:

- All36 broader axis cases retain maps, leaf/group totals, admission, runoff
  and end outputs against the separate-texture reference, including actual
  curved geometry, dry/degenerate limits, overtakes and both runoff directions.
- **20 domain cases** compare copy, checked-parent and proven-parent execution
  on both axes and both gather variants. Adjacent banks contain large poison
  values. Valid, negative-start, oversized-end, reversed and inconsistent-island
  run tables all preserve every output. Unsafe neighbours/searches stay checked.
- Eight proof fallbacks cover disabled specialization, edited source/loop
  bounds and mismatched axis/row/lane/leaf/group metadata. No unchecked helper
  is emitted for these inputs.
- The10 arbitrary coordinate/mip cases and9 host guards from s109 remain valid.
  Neighbour-bank leakage from a naive offset-only implementation is still
  reproduced and isolated by the checked path.
- The six accepted/refused/resumed/reverse/curved call scenarios retain334 real
  GPU axis-draw comparisons against original shaders with separate logical
  textures. Complete source/pool budgets, time/control, publication and failure
  prefixes remain valid under the prior lifetime/alias audit.
- Actual curved output matches both the full copy fallback and the fully
  checked bank fallback. All four kernel families select their frozen proofs
  during the graph tests; the checked fallback selects none.

These are scoped address-domain and numerical equivalence checks, not a
universal physical correctness/convergence proof. Pool replay remains a CPU
ownership check of captured GPU results, not a new GPU allocator.

## 3. Cost and retained limits

| Compiled kernel | s109 fully checked | s110 proven-centre path |
|---|---:|---:|
| Map | 331 | 304 |
| Leaves/loss | 175 | 149 |
| Full gather | 262 | 233 |
| End-only gather | 250 | 217 |

These static instruction counts decrease for every family, while uncertain
addresses retain zero-border isolation. They still exceed the separate-input
reference's225/126/199/191 lines. No dynamic GPU-time or game FPS improvement
has been measured.

Physical bindings, target extents and lifetimes are identical to s109. At
symbolic1024x256/4096 heads, a fresh default attempt still has69 shader draws,
17 conservative copies and68 MiB copy output extent. The exact-size new-target
pool is149.89 MiB,8 MiB larger than s108's explicit-copy plan; this stage does
not remove that retained-parent cost. Cache, imports, diagnostics and all
resource proof limits from s108/s109 remain in force.

**Decision:** keep the proven-centre specialization within the offline bank
ABI. Do not treat lower static work as evidence that the complete bank strategy
is faster or smaller in the game. Full checked and copy fallbacks remain.

## 4. Next implementation and adoption gates

Next compare a lifetime-aware hybrid binding strategy: direct parent reads for
the donor-to-first-axis packet banks whose full force parent must remain alive
through post anyway; separate input/copy bindings for the first-gather-to-second-
axis boundary where parent retention caused the8 MiB pool increase. Preserve
either axis order, both fallbacks and the copy/checked GPU oracles, then compare
copy extent, pool reservation and arithmetic before choosing a policy.

Live allocation/completion/retirement, bounded work/backlog, diagnostic history,
economical material accuracy, triple physical stepping, physical closure/general
convergence and full head/source integration remain open. Production runtime,
calibration, INIs/materials, published assets and earlier stages are preserved.
No reload/log request, installation, commit or push.

## 5. Reproduce

```text
docs/tools/check_s110_cost.py
docs/tools/check_s110_domains.py
docs/tools/check_s110_axis.py
docs/tools/check_s110_transactions.py
docs/tools/finalize_s110.py
```

Factory: `docs/tools/s110_proven_axis_reference.py`. Helper:
`docs/prototypes/s110/bankGridLoad.hlsl`. Baseline, proof fingerprints, numeric/
resource reports, disassemblies, source diff and audit:
`docs/diagnostics/2026-10-17/s110/`.
