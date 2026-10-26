# s118 — execution without per-output readbacks, completion backend contract

2026-10-17. **Status: ACTIVE — offline execution/diagnostic separation.**
Production remains s87 physics with s89 diagnostics. No game installation or
CSP connection of the s91+ physical model is included.

## 1. Two execution modes

s117 created a staging texture and copied every produced output, input and
incoming root into it before its completion event. A successful poll then mapped
all of those copies. s118 makes that diagnostic path optional:

| Operation | Full audit mode | Lean execution mode |
|---|---|---|
| Physical draws and required bank copies | unchanged | unchanged |
| Per-output/import/incoming-root staging | enabled | disabled |
| Per-flight CPU texture maps/comparisons | enabled after actual completion | none |
| Completion event and atomic bundle publication | required | required |
| Explicit test boundary/shutdown root audit | enabled | enabled |

The mode is fixed when the engine is created. Turning diagnostics off does not
alter shaders, constants, source/time receipts, cache admission, target reuse or
publication rules. It removes diagnostic copies, not physical transport work.

The new boundary-audit command is a separate test operation. It refuses while a
flight exists; otherwise it reads the published roots and compares their exact
bytes to the oracle. It is inserted after finalization in both test modes and
also runs at test shutdown. These reads are not inside submit/poll/finalize and
are not proposed as an every-frame production operation.

Lean execution still loads fixture oracle arrays and owns CPU expected root
snapshots. This stage removes the GPU staging/map work; it does not claim an
oracle-free CPU descriptor ABI or a finished production backend.

## 2. Backend-neutral completion contract

`s118_completion_contract.h` defines a fence reporting `Pending`, `Complete` or
`Failed`, plus the publication/retirement latch. It does not depend on D3D11.

- `Pending` permits neither publication nor reclamation.
- `Complete` permits reclamation. Publication also requires a nonfailed,
  nonabandoned, complete candidate with matching generation and bundle epoch.
- `Failed` permanently marks that flight failed and abandoned. A failure report
  does **not** establish that GPU resource use has ended.
- A later actual `Complete` may allow the failed flight to retire, but cannot
  clear its failure/abandonment or publish it. Admission reset cannot revive it.

The D3D11 adapter performs one `GetData` with `DONOTFLUSH`, mapping HRESULT/ready
to those statuses. A failed HRESULT is not converted into completion.

The test-only adapter delays observations by a configured number of polls and
can report one failure for a chosen serial. It never manufactures `Complete`:
after delay/failure it must delegate to the actual native event. This makes
pending/failure quarantine deterministic even when WARP finishes quickly.

A real device failure can continue reporting failure, leaving the flight held.
Device loss, timeout policy and device recreation are not implemented here.
The injected failure is a control-path report over a healthy WARP queue, not
evidence of successful hardware/device-loss recovery.

## 3. Paired native evidence

Thirteen schedules each run in full and lean mode. The nine s117 schedules are
preserved, with explicit boundary audits. Additional schedules exercise forced
pending polls, failed completion reports, reset after failure, and failure of
the initial candidate followed by GPU-root bootstrap recovery.

| Evidence per mode | Full audit | Lean execution |
|---|---:|---:|
| Host commands | 493 | 493 |
| Submitted/finalized flights | 49 | 49 |
| Atomic bundle publications | 39 | 39 |
| Abandoned discards / partial unpublished completion | 9 / 1 | 9 / 1 |
| Physical shader draws / region copies | 4260 / 1392 | 4260 / 1392 |
| Per-flight staging allocations/copies and mapped comparisons | 7969 | 0 |
| Cumulative per-flight diagnostic payload bytes | 24765152 | 0 |
| Explicit boundary/shutdown root comparisons | 965 | 965 |
| Cumulative boundary diagnostic payload bytes | 2259008 | 2259008 |
| Forced pending results / injected failures | 29 / 3 | 29 / 3 |
| Checkpoint/produced-texture uploads | 0 / 0 | 0 / 0 |
| D3D debug warnings/errors | 0 | 0 |

All finalized physical call records match between modes after excluding the
declared diagnostic counters. Allocations, reuse, draws, physical copies,
epochs and publication/discard choices are identical. Every boundary audit
passes. All final16-role public/private/cache bundles, including ledger,
clock/control and source snapshot, equal s117 byte for byte.

These are repeated frozen candidates on the small8×32 source/pool fixture.
The first publication is a physically refused checkpoint;39 publications are
not39 accepted time intervals or49 independent weather frames. Four additional
fatal-path runs (two guards in both modes) are excluded from the table. They
retain the active flight during a diagnostic drain and preserve the previously
published roots after malformed control input or unfinalized EOF.

The byte counts are cumulative logical diagnostic payload, not peak VRAM/RSS,
driver traffic, a GPU timing estimate or game FPS evidence. Required physical
work remains unchanged, and full/lean nominal target/cache capacities match.

## 4. Audit and preservation

MSVC `/W4 /WX` and the actual WARP debug layer pass. Physical shader bytecode is
copied unchanged. Independent command/graph decoding reconstructs admission,
target ownership, delayed/failing fence observations, sticky abandonment,
publication and diagnostic counters for every command in both modes.

The native executor still keeps one pending call or one flight, bounded roots/
caches and streamed statistics. CPU fixture generation/audit may hold aggregate
evidence. Pipeline/constant-buffer creation, explicit submit flush, CPU oracle
payload and test waits/audits remain outside any production cost claim.

Runtime53 Lua/HLSL files, three INIs, published assets/materials and280 prior
s91–s117 files are unchanged. No install, repeated game logs, commit or push.

## 5. Next implementation

Separate immutable execution descriptors from expected-output/oracle payload
ownership. Keep CPU expected arrays and diagnostic snapshots outside the lean
backend while preserving final GPU result comparison gates. CSP integration,
full physical lifecycle, economical accuracy/convergence, device recovery and
target GPU timing remain open.

## 6. Reproduce

```text
docs/tools/check_s118_backend.py
docs/tools/finalize_s118.py
```

Executor: `docs/tools/s118_execution_backend.cpp`. Completion contract:
`docs/tools/s118_completion_contract.h`. Build/fixture helper:
`docs/tools/s118_backend_reference.py`. Native results, compressed fixtures,
hashes, baseline, source diff and independent audit:
`docs/diagnostics/2026-10-17/s118/`.
