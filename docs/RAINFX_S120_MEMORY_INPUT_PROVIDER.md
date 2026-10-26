# s120 — typed memory input provider and owned submission snapshots

2026-10-17. **Status: ACTIVE — offline memory-provider entry point.**
Production remains s87 physics with s89 diagnostics. No game installation or
CSP connection of the s91+ model is included.

## 1. Entry point and ownership

`s120_input_provider.h` adds a typed entry accepting a call packet, source/
interval receipt and input provider. It has no descriptor/input file I/O, oracle
arrays or GPU commands. The packet contains execution metadata, uniforms,
links and exported root IDs. The host supplies its prior-submission context.

The entry validates the packet before acquiring input data, then builds an owned
snapshot of graph metadata, constants, links, exports and receipt. External
immutable inputs are copied from provider views into the existing upload leases.
Retained GPU inputs never call the CPU input provider.

The provider owns each view until its matching release. Views must remain stable
while the synchronous entry is using them; concurrent producer mutation during
the call is outside the contract. After entry returns, producer storage may be
changed or destroyed. Pending/retry execution uses the frozen snapshot and does
not acquire inputs again. Successful GPU submission still clears upload leases
as in s119.

Each acquired view has a scope guard that returns its token on success or
failure, including validation failure after earlier inputs were already copied.
The provider's key must match the requested identity and its extent/count/data
must match the resource descriptor. Inputs and uniforms must be finite.

Receipt validation checks format, equality and epoch consistency; it does not
cryptographically authenticate payload bytes. The provider owns the association
between its identity label and data. Host generation/serial, retained GPU-root
resolution, admission and publication remain guarded by the existing engine.

## 2. Validation before submission

The typed path validates limits that the old binary parser used to establish:
resource/slot/event bounds, texture dimensions, shader metadata and uniform
sizes, plus graph lifetimes, aliases, copy regions, imports, exports and root
schema. It also checks complete-only publication, receipt epochs, external
identity labels, retained-link epochs and forbidden checkpoint uploads.

Fourteen negative cases cover:

- Invalid resource extent and incompatible target slot.
- Stale retained-link epoch, invalid receipt epoch and malformed source receipt.
- Missing input after earlier successful acquisitions.
- Wrong input length, wrong identity, null data and nonfinite input.
- Nonfinite uniform, incomplete root schema and invalid copy region.
- A protected checkpoint CPU-upload attempt after an existing publication.

All refuse before that candidate submits any GPU work. Every acquired view is
returned. The missing-last-input case acquires and returns32 views before it
fails; the post-commit upload guard retains and verifies epoch1 GPU roots.

## 3. Producer mutation and actual GPU comparison

The offline fixture adapter still reads files to construct a producer packet.
It then calls the memory API with typed objects; file loading is outside that
entry. This is not a live CSP provider or a claim of zero filesystem access for
the entire test process. Shader program keys also remain fixture paths.

Immediately after the entry returns, the adapter deliberately invalidates the
producer graph extent/events, links, exports, receipt and input storage. Frozen
execution must still work. The same13 schedules run through four paths:

| Evidence per path | Disk/full | Disk/lean | Provider/full | Provider/lean |
|---|---:|---:|---:|---:|
| Host commands | 493 | 493 | 493 | 493 |
| Submitted/finalized flights | 49 | 49 | 49 | 49 |
| Physical draws / required region copies | 4260 / 1392 | 4260 / 1392 | 4260 / 1392 | 4260 / 1392 |
| Provider snapshots / producer invalidations | 0 / 0 | 0 / 0 | 49 / 49 | 49 / 49 |
| Provider acquire / release calls | 0 / 0 | 0 / 0 | 1245 / 1245 | 1245 / 1245 |
| Outstanding provider views on return | 0 | 0 | 0 | 0 |
| Per-flight staging/maps | 7969 | 0 | 7969 | 0 |
| Backend-owned expected-array bytes | 0 | 0 | 0 | 0 |
| D3D debug warnings/errors | 0 | 0 | 0 | 0 |

The primary matrix totals1972 commands and196 flights. Allocator decisions,
physical work, epochs, publications/discards and final root bytes agree across
all four paths and with s119. Delayed/failing completion, cancel/reset, partial
abort and pending-capacity recovery remain intact after producer invalidation.

An additional provider/lean run completes with nonexistent oracle files and
zero oracle opens. Its final actual-GPU dump matches full-mode output and s119
under independent comparison. Explicit boundary audits and final dumps remain
test operations, not production-frame reads.

These schedules reuse frozen8×32 physical candidates. Publications include a
physically refused checkpoint;196 flights are not196 distinct weather frames or
accepted time intervals. No physical expressions or shader bytecode changed.

## 4. Audit, cost and preservation

MSVC `/W4 /WX` and the actual WARP debug layer pass. Independent command/graph/
sidecar/dump decoding replays admission, owned input bytes, provider acquisition
and return counts, completion and publication for each action. The guard audit
also checks acquisition counts for failure and partial-copy cleanup.

The memory entry currently deep-copies and validates graph metadata and external
payloads per accepted call. That buys explicit snapshot ownership; it is not a
measured CPU optimization. The fixture adapter adds preparation copies of its
own. GPU pipeline/constant-buffer setup, explicit flush, diagnostics and test
waits retain their prior limitations. There is no game FPS, RSS/VRAM or device
loss-recovery claim.

Runtime53 Lua/HLSL files, three INIs, assets/materials and293 prior s91–s119 files
are preserved. No install, repeated game logs, commit or push.

## 5. Next implementation

Add reusable immutable graph templates with per-interval uniform/input/receipt
binding. Avoid rebuilding and revalidating static topology on every accepted
call while keeping snapshot isolation, provider-return and retained-GPU-root
guards. A live CSP data source, full physical lifecycle, economical accuracy/
convergence, device recovery and target GPU timing remain open.

## 6. Reproduce

```text
docs/tools/check_s120_provider.py
docs/tools/finalize_s120.py
```

Entry: `docs/tools/s120_input_provider.h`. Native fixture/engine adapter:
`docs/tools/s120_provider_backend.cpp`. Build/helper:
`docs/tools/s120_provider_reference.py`. Evidence, split fixtures, GPU dumps,
baseline, source diff and independent audit:
`docs/diagnostics/2026-10-17/s120/`.
