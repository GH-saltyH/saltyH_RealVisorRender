# s112 — persistent native GPU graph and target reuse

2026-10-17. **Status: ACTIVE — bounded offline D3D11 WARP executor.**
Production remains s87 physics with s89 diagnostics; no game build is installed.

## 1. From ownership replay to actual GPU execution

s108–s111 checked resource ownership by replaying captured outputs into CPU
pool slots. Their real shader tests still uploaded separate textures for each
draw. s112 executes complete captured graphs on persistent D3D11 resources:

1. Upload each imported parent once into an immutable SRV texture. Imports never
   enter the writable target pool and have no RTV.
2. Allocate the audited exact-descriptor SRV/RTV slots, or one dedicated target
   per output for the comparison execution.
3. Bind whole parents for s111's first axis. Execute actual
   `CopySubresourceRegion` operations for logical row bands elsewhere, including
   second-axis end/mean inputs and retained exported banks.
4. Execute the original compiled shaders using reflected named bindings and
   constants. All produced data stays on GPU between consumers.
5. Unbind PS SRVs and OM targets at every command boundary. The offline graph
   validator rejects aliased reads/writes, stale generations, live overwrites,
   mismatched extents and invalid copies before creating the device.
6. Copy each output to diagnostic staging before its pool slot is overwritten.
   After all submitted commands, drain a D3D11 event query, then map and compare
   every produced output and every original import byte for byte.

Reuse is scoped to one ordered immediate context and a prevalidated graph.
No CPU read/write or second context modifies a reused default texture between
commands. The final completion event precedes diagnostic mapping and normal
retirement. This is a bounded native GPU pool, not an asynchronous general
allocator or a CSP render-target implementation.

## 2. Explicit fixture defaults

The inherited single-draw runner supplied an all-zero1×1 texture for source
names absent from its binding dictionary. For example, the snapshot shader
contains both initialization and publication branches; initialization does not
supply the publication-only snapshot textures, although reflection lists them.

s112 makes these defaults explicit: one shared zero import per graph, named
bindings listed in the report, included in upload counts/read edges, and no
silent missing reflected binding in the native executor. It preserves the
existing fixture's semantics; it does not validate arbitrary missing inputs in
an active live branch. This adds16 bytes to imported storage, not to target/copy
budgets. Shader bodies, arithmetic and all s110 load proofs remain unchanged.

## 3. Verification

C++ builds with MSVC `/W4 /WX`; all captured shaders compile with FXC `/Ges /WX`.
The actual D3D11 debug layer was available in every executed test.

| Case | Accepted | Shader draws per execution | Region copies |
|---|---|---:|---:|
| Compressive source/pool first attempt | no | 69 | 23 |
| Its checkpoint resume, two attempts | yes | 118 | 41 |
| Actual curved geometry, X then Y, hybrid | yes | 69 | 23 |
| Same geometry/order, full copy | yes | 69 | 29 |
| Actual curved geometry, Y then X, hybrid | yes | 69 | 23 |
| Same geometry/order, full copy | yes | 69 | 29 |

Each case executes with pooled and dedicated GPU allocation: **926 draws,
336 region copies and1660 core output/import readback comparisons** in total.
Every readback matches the single-draw upload oracle byte for byte, with zero
produced-texture uploads and zero D3D debug warnings/errors. Hybrid and full-copy
complete public packets/ledgers also match in both curved orders. Source and
pool water are accounted once; prior water/momentum residual tolerances hold.

Six actual native command-prefix executions stop before any commands, before
coarse gather, before ledger publication, before snapshot publication, after
the first region copy and after the first slot reuse. Each drains completion
and verifies all completed outputs and every original import. These check
failure-prefix GPU ownership, not a new native transaction API.

Six corrupt fixtures fail in native validation **before device creation**:
same-event SRV/RTV alias, retained-target overwrite, incompatible slot extent,
protected import assigned a writable slot, copy beyond parent rows and false
last-use metadata. CPU graph replay and independent serialized-DAG reconstruction
remain additional checks, rather than substitutes for the native executions.

## 4. Resource evidence and limits

For the captured160×90 curved graph:

| Allocated default output textures | Hybrid | Full copy |
|---|---:|---:|
| Dedicated targets | 17,806,624 B | 19,189,024 B |
| Actual pooled targets | 8,165,424 B | 8,165,424 B |
| Actual copy output extent | 5,299,200 B | 6,681,600 B |

These native allocation counters agree with the corresponding captured graph
plan. They exclude imported textures, staging diagnostics, buffers, shaders,
driver overhead and allocator granularity. In particular they are **not peak
VRAM or application Memory measurements**. Readback staging intentionally keeps
every output for verification and is not a proposed production configuration.

The symbolic1024×256/4096-head plan remains s111: hybrid69 draws,23 copies,
92MiB copy extent and141.89MiB reserved new-target pool; separate inputs have
29 copies/116MiB and the same pool reservation. That symbolic profile was not
executed as a full native GPU workload here. No dynamic timing/FPS conclusion
is drawn from WARP, native byte counts or static instruction counts.

**Decision:** persistent texture binding, copies and reuse pass the bounded
native gate. Performance adoption and CSP integration remain withheld.

## 5. Next implementation

Keep public, private checkpoint and interval-cache GPU handles alive across
multiple calls in one native executor. Test refused/resumed intervals and
pending joint-publication prefixes without uploading the checkpoint from CPU.
Protect the incoming generations until the candidate's complete publication
succeeds; establish completion and retirement across that ownership boundary.

Current resume tests import the checkpoint captured by the existing oracle,
once at the next native execution's start. They do not establish native
cross-call handle retention or failure-safe joint handle publication. Bounded
work/backlog, economical material accuracy, physical closure/convergence,
full head/source lifecycle and target GPU/CSP timing remain open.

Runtime, calibration, INIs/materials, published assets and prior stages are
preserved. No installation, game reload/log request, commit or push.

## 6. Reproduce and inspect

```text
docs/tools/check_s112_persistent.py
docs/tools/finalize_s112.py
```

Executor: `docs/tools/s112_persistent_graph.cpp`. Capture/serialization helper:
`docs/tools/s112_native_graph_reference.py`. VS2022 Community C++ tools, Windows
SDK FXC and D3D11 WARP are required. The existing physical fixture also uses
the prior single-draw native runner.

Evidence: `docs/diagnostics/2026-10-17/s112/`. Complete binary fixtures are
losslessly gzip archived with raw and archive SHA256 hashes. `run()` in the
helper unpacks an archived fixture temporarily when needed. Per-case native
reports/logs, serialized DAGs, compiled shader hashes, build log, baseline,
source diff and final audit are retained.
