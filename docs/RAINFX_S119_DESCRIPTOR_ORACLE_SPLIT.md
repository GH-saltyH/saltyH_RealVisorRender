# s119 — execution descriptors separated from oracle payload ownership

2026-10-17. **Status: ACTIVE — offline descriptor/input/diagnostic separation.**
Production remains s87 physics with s89 diagnostics. The s91+ model is not
installed or connected to CSP by this stage.

## 1. Ownership boundary

s118 could disable per-output GPU readbacks, but its graph and retained roots
still owned expected CPU texture arrays. s119 removes those payload members
from the execution schema:

| Owner | Stored data |
|---|---|
| `ExecutionResource` | seven integers: extent, kind, birth/last use, slot and protection |
| `ExecutionGraph` | resource descriptors, events, bindings, uniforms, slots and export IDs |
| `ExecutionRoot` | GPU texture handles and one resource descriptor |
| Pending execution call | immutable input upload leases, source/interval identity and graph |
| In-flight execution call | GPU inputs/targets, descriptor graph, event and completion state; upload leases released |
| Test oracle harness | expected output/input/root arrays, optional staging and boundary audits |

The execution resource/root types have no expected-array member. Full diagnostics
attach through a non-owning observer interface. That observer and its oracle
arrays are owned by the harness outside the engine; lean execution passes no
observer. The engine never opens an oracle file or copies expected arrays into
published roots.

Initial input data and shader uniforms remain legitimate execution inputs. They
are not eliminated or counted as zero CPU memory. Only external immutable imports
acquire upload leases; retained GPU inputs skip those payload rows. Successful
submission clears the upload leases after D3D immutable texture creation has
consumed them. Pending admission retains its original leases for retry.

## 2. Split fixture ABI

The previous combined graph file is split into three independent files:

- Descriptor file: resource/event/lifetime metadata and actual shader uniforms,
  with no expected texture payload.
- Input file: immutable input data. The provider loads only external import
  rows requested by the call, skipping borrowed GPU rows.
- Oracle sidecar: all expected arrays, read only by the optional test harness.

The existing alias, live-range, bank-copy, export, root-schema, epoch and
protected-input-upload guards are retained for the descriptor schema. Separate
input/oracle readers check row identity, extents, payload coverage and byte
bounds, including skipped rows. A truncated input is refused before submission.

The sidecar is diagnostic metadata in the offline command envelope. It is not a
member of the execution graph or a prerequisite for a lean backend call.
Disk fixture parsing is not proposed as a per-frame CSP data source.

| Frozen graph | Descriptor file bytes | Separate oracle file bytes | Input file bytes |
|---|---:|---:|---:|
| Initial checkpoint | 88930 | 386420 | 62724 |
| Two-attempt resume | 146841 | 635000 | 79288 |
| Fresh interval | 88930 | 386420 | 62724 |

These file sizes include headers/records and are not resident-memory counters.
Input files contain all fixture import rows; only requested external rows become
CPU upload leases. The largest observed admission lease payload is62320 bytes.
All submitted-flight lease counters are zero after upload.

## 3. GPU evidence, including absent oracle files

The13 s118 schedules run again in full and lean mode:986 host commands and98
submitted/finalized flights. Each mode executes4260 physical draws and1392
required region copies; allocations, reuse, publication and discard decisions
remain paired. Full diagnostics perform7969 comparisons; lean execution
performs zero per-flight staging copies or readback maps.

Expected payload ownership inside the backend is zero in both modes. The
previous fixture graph payload maximum632688 bytes and retained expected-root
payload37648 bytes are no longer execution-owned. In full mode the external
harness still owns diagnostic arrays, so moving that ownership is not itself a
claim of lower total process memory.

Boundary audits and final GPU dumps match s118 for every public/private/cache
role, including water ledger, clock/control and source snapshot. Deterministic
delay/failure quarantine, cancellation/reset, GPU bootstrap recovery and partial
aborts retain the previous guarantees. Physical shaders are unchanged.

An additional native run deliberately names nonexistent oracle files:

- Nine commands complete three flights and publish epoch3.
- Oracle file opens, harness-owned expected payload and backend-owned expected
  payload are all zero. Per-flight staging/maps are also zero.
- The test runner writes the actual final GPU roots without consulting expected
  arrays. A separate Python audit reads that dump after execution and verifies
  exact equality with s118 and full-mode output.
- The same missing-sidecar fixture refuses in full diagnostic mode before any
  submission, proving that the diagnostic path actually depends on its sidecar.

Final root dumping is explicit test readback, not a normal execution operation.
It is separate from the zero per-flight readback claim. The absent-oracle native
report therefore says `finalRootsDumped=true` and `finalRootsVerified=false`;
verification occurs outside that process.

Four inherited in-flight fatal-path runs preserve the previous published roots.
Two additional guards refuse missing full diagnostics and truncated input before
any GPU submission. Repeated frozen candidates are not98 distinct weather
frames, and host bundle publication includes physically refused checkpoints.

## 4. Independent audit and limits

MSVC `/W4 /WX` and the actual D3D11 WARP debug layer pass without warnings.
Independent readers decode descriptor metadata, input and oracle sidecars,
commands and GPU dumps. They reconstruct target ownership, upload-lease bytes,
admission, completion/failure and publication, checking both modes against the
native records. Final dump bytes are compared directly to their expected arrays.

The lean backend still owns descriptor/event/uniform metadata, GPU handles and
necessary input leases. Pipeline/constant-buffer creation and explicit flush
remain. Optional diagnostic observers, boundary audits, test waits and dumps are
not a production frame path. No game FPS, process RSS, peak VRAM or device-loss
recovery claim is made.

Runtime53 Lua/HLSL files, three INIs, published assets/materials and286 prior
s91–s118 files are preserved. No install, repeated game logs, commit or push.

## 5. Next implementation

Add a validated in-memory descriptor/input-provider entry point, replacing the
disk loader at the execution boundary. Compare disk and provider calls under the
same immutable source/interval receipts and retained GPU roots. A live CSP
provider, full head/source lifecycle, economical physical accuracy/convergence,
device recovery and target GPU timing remain open integration gates.

## 6. Reproduce

```text
docs/tools/check_s119_descriptors.py
docs/tools/finalize_s119.py
```

Executor: `docs/tools/s119_descriptor_backend.cpp`. Execution schema and test
harness: `docs/tools/s119_execution_schema.h`, `docs/tools/s119_oracle_harness.h`.
Build/fixture helper: `docs/tools/s119_descriptor_reference.py`. Evidence,
compressed split fixtures and GPU dumps, baseline and independent audit:
`docs/diagnostics/2026-10-17/s119/`.
