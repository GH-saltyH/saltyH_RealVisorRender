# s123 — per-flight constant packets and completion-safe reuse

2026-10-17. **Status: ACTIVE — offline D3D11 constant-storage prototype.**
Game physics remains s87 with s89 diagnostics. This stage changes no Lua,
physical shader, INI, material or installed game file. The consolidated
project roadmap/measurement context remains `RAINFX_S122_PROGRESS_SUMMARY.md`.

## 1. Pack before submission, retain through completion

`s123_constant_packets.h` builds an owned constant packet for every reflected
constant block in the submitted draw prefix. Packets retain the s122 offsets,
float/uint conversion, default values and zero padding. They belong to the
pending request and move with it into the flight. Constant-capacity retries
reuse the same bytes; cancel/reset of a pending request releases them.

Each packet receives a **distinct** exact-width default D3D11 constant buffer
within its flight. No deduplication or within-flight overwriting is used.
All packets upload with `UpdateSubresource` once before any physical draws.
Draws then bind the already-uploaded buffers. A lease ticket and unique IDs
guard duplicate upload, stale plans, active/free aliasing and premature reuse.
CPU packet data and GPU buffer handles remain owned until explicit finalization.

The new pool reserves matching completed buffers before considering other
completed buffers for eviction. Byte and entry admission limits default to
32768B/256 in these small fixtures; they are not proposed game settings.
An unmet limit returns `constant_bytes` or `constant_entries` without changing
the incoming GPU roots, free storage or epoch. The frozen request remains
pending. Restoring capacity retries the same packet/input/receipt snapshot.

Cancel/reset marks a submitted flight for discard. Pending/failing query
observations, a ready query without finalization and rejected early finish
commands retain its buffers. Retirement runs only after the existing completion
latch permits it, on either publication, abort or discard. A reported failure
never grants early retirement or revives publication.

Two execution choices share this packet path:

- **Fresh:** allocate each flight's buffers and release them after completion.
- **Pooled:** return completed buffers to the bounded exact-width free list.

Default-buffer upload replaces the previous `CreateBuffer` initial-data path.
It adds one `UpdateSubresource` per uploaded packet in both new choices.
Fewer allocations alone do not establish a net CPU/GPU speedup.

## 2. Actual GPU comparison

Eighteen schedules run fresh/full, fresh/lean, pooled/full and pooled/lean.
The inherited15 schedules cover physical refusal/resume, admission, delayed/
failed completion, cancel/reset, partial abort and template clear. Three new
schedules exercise byte/entry capacity recovery after packet freeze and pending
cancel/reset. One recovery clears template registration while retaining the
prepared constant snapshot. Retries do not repack it or reacquire provider views.

| Evidence per path | Fresh/full | Fresh/lean | Pooled/full | Pooled/lean |
|---|---:|---:|---:|---:|
| Host commands / finalized flights | 572 / 65 | 572 / 65 | 572 / 65 | 572 / 65 |
| Physical draws / region copies | 5557 / 1815 | 5557 / 1815 | 5557 / 1815 | 5557 / 1815 |
| CPU packet preparations | 67 | 67 | 67 | 67 |
| Packed blocks | 5606 | 5606 | 5606 | 5606 |
| GPU constant-buffer creations | 5470 | 5470 | **2088** | **2088** |
| Reused completed buffers | 0 | 0 | **3382** | **3382** |
| Uploads / retired buffers | 5470 / 5470 | 5470 / 5470 | 5470 / 5470 | 5470 / 5470 |
| Maximum nominal constant storage | 7040B / 116 entries | 7040B / 116 entries | 7040B / 116 entries | 7040B / 116 entries |
| Maximum owned CPU packet bytes | 7040 | 7040 | 7040 | 7040 |
| Per-flight diagnostic comparisons | 10446 | 0 | 10446 | 0 |
| D3D warnings/errors | 0 | 0 | 0 | 0 |

The primary matrix totals2288 commands/260 finalized flights. All physical
outputs, allocator decisions, publication and final actual-GPU roots match
the four paths and s122. The creation count falls61.83% for the **same18-case
matrix**; this is not a comparison of different-stage test totals or a timing
measurement. Draw/copy counts and physical bytecode/formulas are unchanged.

In the canonical three-flight sequence,252 uploads use116 created buffers and
136 reuses. The largest resume establishes the storage set; the following
fresh interval creates no additional buffers. The two canceled pending packet
sets account for the difference between5606 packed blocks and5470 uploads.
The cancellation/reset case prepares five requests but submits only three;
its388 packed blocks yield252 uploads in either execution choice.

A pooled/lean process using nonexistent oracle files opens zero oracles and
produces the same final actual-GPU dump. Explicit boundary/final dumps and
packet traces remain fixture diagnostics. These frozen8×32 candidates are not
260 independent weather frames or a full live head/source lifecycle test.

## 3. Independent packet and ownership audit

`s123_packet_audit.py` parses the actual compiled DXBC/RDEF chunks independently
of the C++ reflection implementation. It reads constant-buffer resource slots,
variable offsets/sizes/types and the serialized float uniforms. It reconstructs
every packet, including matrix data and zero-filled unused bytes, and compares
the full bytes with the native packet traces. Canceled pending snapshots and
the absent-oracle process are included; shader output oracle arrays are not
used to reconstruct these constant bytes.

The CPU model independently reserves/creates/evicts exact-width buffers and
replays every ID, size, free-list order, active ticket and accounting counter
per host action. It verifies that no active ID enters the free list before
completion/finalization and that capacity refusal leaves both lists unchanged.
Native pointer/ID checks additionally reject aliasing; full GPU output checks
detect incorrect cross-draw constant contents.

The17 inherited template/provider/shader-width guards still refuse before
the affected candidate submits. Prior template/default/packing contracts pass.
A new actual-WARP pool contract covers six refusals: foreign/stale plan,
planning while active, premature retirement, repeated upload and double return.
It also checks both capacity refusals, reserve-before-eviction, actual query
completion and a zero-packet lease. It creates3 buffers, reuses1, evicts3,
uploads/retires4 and ends with0B and zero debug warnings.

MSVC `/W4 /WX`, frozen shader hashes, binary/command/sidecar decoding, physical
CPU ownership replay and final GPU dump comparison all pass.

## 4. Limits and preservation

The byte limit counts the current active/free pool's **nominal descriptor
bytes**. It excludes driver allocation granularity, staging, textures, other
buffers and CPU containers. Planning objects hold temporary references,
including evicted completed objects, so it is not an actual peak-VRAM bound.
A declined lower limit also preserves the prior cache instead of silently
destroying it. CPU packet figures count payload bytes, not process RSS.

The test uses one ordered immediate context and one in-flight candidate.
Packet-by-packet upload/metadata setup still costs work. No hardware GPU/CPU
timing, game FPS, general device-loss/OOM recovery or multi-context reuse is
claimed. Fatal-path draining retains the existing executor's limitations;
injected completion failure is not a test of real device removal.

The452-file baseline preserves53 runtime Lua/HLSL, three INIs and313 prior
s91–s122 files. User tuning, materials, assets and earlier reports remain
unchanged. Only the existing index/roadmap receive updates. No game install,
reload/log request, commit or push.

## 5. Next implementation

Audit the local CSP SDK's actual resource creation/update, shader value and
completion/lifetime capabilities. Specify which native guarantees can map
directly, which require a supported alternative, and the bounded live input/
backlog policy before connecting this prototype to the game. Do not assume
the native D3D11 constant-buffer pool is exposed by CSP Lua.

Economical transport accuracy/convergence, physical closure, full live head/
source lifecycle, unified head/film optics, real device recovery and target
timing remain separate adoption gates.

## 6. Reproduce

```text
docs/tools/check_s123_constants.py
docs/tools/finalize_s123.py
```

Header: `docs/tools/s123_constant_packets.h`. Native adapter:
`docs/tools/s123_constant_backend.cpp`. Build/helper:
`docs/tools/s123_constant_reference.py`. Independent packet/pool model:
`docs/tools/s123_packet_audit.py`. Evidence, packet traces, compressed fixtures,
GPU dumps, baseline, diff and delivery audit:
`docs/diagnostics/2026-10-17/s123/`.
