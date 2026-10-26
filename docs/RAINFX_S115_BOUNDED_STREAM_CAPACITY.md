# s115 — bounded native stream, caches and retirement

2026-10-17. **Status: ACTIVE — offline capacity and metadata lifecycle.**
Production remains s87 physics with s89 diagnostics; no game build is installed.

## 1. Bound what survives a call

s113's native test executor loaded every call graph and retained a statistics
vector for the entire session. Its external-input cache and free-target list
also kept every previously encountered key/descriptor. s115 replaces that
execution path with a streamed reader and explicit capacity admission:

- One current graph, with the existing resource/event/texture layout guards.
- One16-role root bundle. Oracle data is owned by the current root snapshots,
  rather than pointing into old call graphs. An incoming and candidate bundle
  coexist briefly during atomic publication; old snapshots release afterwards.
- Statistics are appended directly to a JSONL file. No in-memory call-history
  vector; D3D debug messages are checked and cleared every call.
- Default target bytes have a hard nominal descriptor limit. Compatible free
  targets are reserved first; unrelated completed free targets may then be
  evicted before any new target is created. Incoming roots cannot be evicted.
- Immutable external inputs have both byte and entry limits. Current inputs
  and root-pinned textures are protected; unused cache entries can be removed.
- Pixel shaders have an entry limit. Every shader required by the submitted
  prefix must fit; other cached shader keys may be removed.

The graph is checked before candidate submission. Unmet admission limits refuse
the call without swapping roots or consuming the bundle epoch. A post-commit
refusal additionally reads back the preserved GPU roots. The offline runner
currently ends on refusal; resumable pending/admission recovery is the next gate.

All normal GPU work still uses one ordered immediate context and per-call
completion drains. Completed, unbound resources can be retired or reused only
after readback verification; publication remains an atomic16-role swap.

## 2. Two repeated schedules

Both131-call streams use frozen, verified s114 physical graphs on the8×32
planar source/pool fixture:

1. Publish a physically refused checkpoint.
2. Repeat64 aborted resumes, alternating ledger/header/snapshot boundaries and
   a complete-but-unpublished candidate.
3. Complete the resume and publish the second bundle epoch.
4. Repeat64 new-interval attempts, alternating an early cache-receipt abort and
   a complete-but-unpublished candidate.
5. Complete the new interval and publish epoch3.

These are long ownership/admission schedules, not131 distinct accepted
physical steps. A fixed incoming bundle intentionally remains unchanged while
its candidate is retried. The physical output/ledger oracle is the prior s114
fixture; no new physical calibration or convergence claim is made.

| Evidence | Steady stream | Capacity-stress stream |
|---|---:|---:|
| Calls | 131 | 131 |
| Shader draws | 9952 | 10003 |
| Region copies | 3108 | 3108 |
| Output/import/root readbacks | 19665 | 19847 |
| Maximum nominal default-target bytes | 194000 | 200000 |
| Maximum external cache entries | 21 | 24 |
| Maximum shader entries | 41 | 64 |
| Checkpoint/produced texture uploads | 0 | 0 |
| D3D debug warnings/errors | 0 | 0 |

Every produced output, input and incoming root matches its oracle byte for byte.
The last32 steady calls create no new targets. Its default-target extent stays
at194000 bytes. Current root oracle storage is37648 bytes in these fixtures;
the largest current graph oracle payload is635728 bytes across both schedules.
These counters are diagnostics of this small fixture, not process RSS bounds.

## 3. Deliberate capacity stress

The second schedule adds explicitly nonphysical diagnostics:

- A new unused immutable1×1 probe per call, forcing input-cache key turnover.
- A small, varying scratch target after the original graph, forcing descriptor
  turnover. Partial candidates may stop before this diagnostic draw.
- Three sets of shader fixture paths containing byte-identical compiled shader
  data, forcing shader-key turnover without changing physical expressions.

Target capacity is200000 bytes, external capacity65536 bytes/24 entries, and
shader capacity64 entries. The stress stream evicts128 free targets,130 unused
external entries and3141 shader keys while staying within all limits. This is a
deliberately adverse cache test, not a performance configuration or a recommended
shader-key scheme. Copy/dispatch counts include the scratch diagnostics.

The byte cap covers default output textures, including retained roots and free
targets. Immutable inputs have their own cap. Staging diagnostics, buffers,
driver overhead and CPU oracle storage are excluded; these values are not peak
VRAM, app Memory or game FPS measurements. No automatic capacity values are
proposed for the live1024×256/4096-slot workload.

## 4. Refusal and independent audit

Four undersized limits reject at admission: target bytes, external bytes,
external entry count and shader count. The target-byte refusal occurs after a
successful checkpoint publication; epoch1 and its original GPU roots are
verified unchanged. The other three limits reject the initial call before any
bundle is seeded. No partial candidate is published.

MSVC `/W4 /WX`, FXC `/Ges /WX` and the actual D3D11 WARP debug layer pass.
Final audit reconstructs graph edges, slot lifetimes, incoming root links and
epochs, plus the capped free/input/shader cache decisions and native counters.
The legacy s112/s113 helpers are reused unchanged; a generated include renames
only their old executable entry point. Physics shaders remain unchanged.

The native executor holds one current graph and bounded roots/caches; the
Python fixture builder and audit intentionally keep aggregate evidence on disk
and may load it for comparison. This is not a claim that oracle generation,
shader compilation or diagnostic staging is a production rendering path.

## 5. Next implementation

Make admission refusal recoverable. Retain one pending call and its source/
interval identity without accepting later work, consuming time/water twice or
publishing partial roots. Test reduced→restored budgets, stale generations,
cancel/reset, and successful retries before a CSP adapter is connected.

Economical material accuracy, physical closure/convergence, full head/source
lifecycle, asynchronous/device recovery and target GPU/CSP timing remain open.
Runtime, INIs/materials, published assets and prior stages are preserved. No
installation, game reload/log request, commit or push.

## 6. Reproduce

```text
docs/tools/check_s115_capacity.py
docs/tools/finalize_s115.py
```

Executor: `docs/tools/s115_bounded_stream.cpp`. Fixture reader/writer and build:
`docs/tools/s115_stream_reference.py`. Evidence, JSONL native statistics,
compressed fixtures, alias shader hashes, baseline, generated helper include
and final audit: `docs/diagnostics/2026-10-17/s115/`.
