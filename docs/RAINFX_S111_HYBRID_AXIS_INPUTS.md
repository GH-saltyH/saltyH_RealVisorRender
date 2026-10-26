# s111 — lifetime-aware hybrid axis inputs

2026-10-17. **Status: ACTIVE — offline GPU equivalence and resource policy.**
Production remains s87 physics with s89 diagnostics; no game build is installed.

## 1. Selection follows execution order

s110's full parent binding removed twelve copies per default attempt, but the
first gather's two-bank parent stayed live through the second gather. Under
the conservative exact-descriptor pool, that added8MiB to reserved targets.

s111 chooses the binding at each axis boundary:

| Boundary | Input policy | Lifetime reason |
|---|---|---|
| Donor force → first executed axis | whole force parent + logical row origins | force status/wall/impulse banks already retain that parent through post |
| First gather → second executed axis | original separate end/mean inputs, materialized copies in the resource plan | copied banks allow the two-bank gather parent to retire after its last copy |

The first executed axis is X in normal order and Y in reverse order. It is
never hardcoded to X. Both sweeps retain their original transport, reconstruction,
loss/status, recipient force and publication expressions. No physical model,
rain input, diameter calibration or display scale changes.

The first-axis path reuses s110's exact source/domain proof and s109's host
layout guards and checked zero border. It introduces no new HLSL helper or
unchecked load site. The second axis receives the unchanged raw shader and
logical textures, including its original conservative unused bindings. Its
end-only gather remains available on compact coarse/first-fine candidates.

Three immutable offline flags preserve research alternatives:

- Default `gResearchHybridAxisInputs=1`: first parent, second copy.
- `gResearchHybridAxisInputs=0`: all-axis s110 parent policy.
- `gResearchProvenBankLoads=0`: fully checked first-axis bank loads.
- `gResearchBankAxisInputs=0`: all-axis original separate-input policy.

These are factory metadata, not runtime/UI additions. Full-copy selection has
priority. Unknown shader/domain proof inputs retain the inherited checked ABI.

## 2. Verification scope

Strict FXC `/Ges /WX` and D3D11 WARP compare every axis draw to an additional
execution of the original shader with separate logical texture uploads. The
fixture includes stationary both-order acceptance, a real compressive refusal,
two-attempt checkpoint resume, fresh three-attempt completion, actual curved
geometry, four real pending-publication prefixes, and an additional nonzero
curved reverse-order graph. Comparisons cover both parent and copy selections.

The complete public stocks, time/control and fine water/momentum ledgers match
under the full-bank, checked-hybrid and full-copy fallbacks. Source and pool
water are applied once; split/together publication remains bit-identical.
A16-case routing matrix checks both orders and all four policies without
mutating batch metadata. No previously tested bank proof is widened.

Captured graphs preserve every consumer/export in exact-size CPU pool replay,
including all event failure prefixes, retained incoming cache/checkpoint/public
state and returned GPU diagnostics. Six overwrite/alias/extent/input/stride
mutations still reject. Serialized DAG last-use stamps and concrete/symbolic
budgets are reconstructed independently in the final audit.

This is numerical equivalence to the existing reference plus a resource
ownership proof. The native harness still uploads textures for individual
draws; it does not execute a persistent GPU pool or measure game performance.
The prior physical-accuracy and full-lifecycle adoption limits remain open.

## 3. Cost comparison

Symbolic1024×256,4096 heads,RGBA32_FLOAT, one fresh default embedded attempt:

| Resource metric | s108 separate inputs | s110 all parent | s111 hybrid |
|---|---:|---:|---:|
| Shader draws | 69 | 69 | 69 |
| Conservative bank copies | 29 | 17 | 23 |
| Copy output extent | 116MiB | 68MiB | 92MiB |
| New-target extent without reuse | 333.08MiB | 285.08MiB | 309.08MiB |
| Exact-size reserved new-target pool | 141.89MiB | 149.89MiB | 141.89MiB |
| Maximum simultaneous live new-target extent | 84.06MiB | 84.06MiB | 84.06MiB |

Thus the hybrid removes s110's reserved-pool regression and saves24MiB of copy
output versus separate inputs. It restores24MiB of copy output versus all-parent
binding. Reserved extent is not peak live extent, VRAM usage or Lua Memory;
imports are reported separately and diagnostics remain conservatively retained.
The allocation result is scoped to the inherited exact-descriptor greedy pool
and these graphs; no universal minimum or arbitrary-grid bound is claimed.

| Kernel | First-axis proven parent | Second-axis original copy |
|---|---:|---:|
| Map static instruction lines | 304 | 225 |
| Leaves/loss | 149 | 126 |
| Full gather | 233 | 199 |
| End-only gather | not selected on first axis | 191 |

Per-kernel static lines do not predict dynamic GPU time. The first-axis parent
still costs more arithmetic than its original separate-input kernel. All-parent
binding can still be a better bandwidth tradeoff on a particular GPU. Preserve
all policies until persistent-resource and target timing evidence can choose.

## 4. Next implementation

Validate actual persistent D3D11 texture bindings, row-region copies and safe
target reuse in a bounded native offline graph. Compare the hybrid and separate
input policies without replacing every input with a fresh CPU upload. Retain
the exact logical zero border, SRV/RTV separation, failure ownership and joint
publication contract. Establish resource completion/retirement before any live
allocator is connected to CSP. Performance adoption remains withheld.

Economical material error estimation, bounded work/backlog, triple stepping,
physical closure/general convergence and full head/source lifecycle integration
remain open. Runtime, INIs/materials, published assets and earlier stages are
preserved. No installation, reload/log request, commit or push.

## 5. Reproduce

```text
docs/tools/check_s111_cost.py
docs/tools/check_s111_transactions.py
docs/tools/finalize_s111.py
```

Factory: `docs/tools/s111_hybrid_axis_reference.py`. Baseline, compiled shaders,
GPU oracle/resource reports, per-call DAGs, source diff and final audit:
`docs/diagnostics/2026-10-17/s111/`.
