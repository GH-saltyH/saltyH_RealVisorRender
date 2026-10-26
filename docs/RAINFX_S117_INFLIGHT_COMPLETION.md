# s117 — separate submission, completion observation and publication

2026-10-17. **Status: ACTIVE — offline single-flight GPU protocol.**
Production remains s87 physics with s89 diagnostics. No CSP installation or
connection of the s91+ model is included.

## 1. Execution phases

s116 completed and read back a whole candidate inside its submit operation.
s117 retains one candidate across separate host commands:

```text
idle -> pending admission -> submitted -> observed ready -> finalized
                               |              |
                         cancel/reset     cancel/reset
                               +---- discard intent ----> discard after ready
```

- **Submit:** run the transactional admission planner, allocate/borrow targets,
  enqueue draws/copies and diagnostic readback copies, then end an event query
  and flush. Keep the graph, inputs, targets, incoming bundle and event alive.
  Submit does not poll, map a readback or call a completion drain.
- **Poll:** issue one `GetData(..., D3D11_ASYNC_GETDATA_DONOTFLUSH)` unless the
  flight is already verified. An incomplete event returns `waiting` immediately.
  After actual query success, compare the retained staging copies to their
  oracles and mark the flight ready. Poll does not publish or retire targets.
- **Finalize:** require observed, verified completion. Publish the complete
  16-role bundle atomically, or discard an abandoned/partial candidate. Only
  then return completed, unretained targets to the free pool.

There is one active slot: either pending admission or one in-flight candidate.
New submits/retries are refused while a flight exists, including when it is
ready but has not been finalized. No later graph is loaded or candidate queue
accumulated. Source/interval labels and all original inputs remain frozen.

The native ownership assertion checks retained, free and in-flight default
targets as disjoint sets and accounts for their exact descriptor bytes after
every command. During a flight, incoming root handles and bundle epoch must
remain unchanged. Physical byte comparisons occur after its event, and final
published roots are read back again at orderly test shutdown.

## 2. Cancellation and admission reset

Cancel on pending work releases it immediately because it has submitted no GPU
work. Cancel on a flight sets discard intent and retains every GPU reference.
Admission reset likewise clears pending work, increments the admission
generation and marks any flight for discard. It preserves published physical
state and serial high-water, as in s116.

Neither operation returns in-flight targets to the free pool. Polling under the
current admission generation can observe the old flight, but finalization can
only discard it. An old-generation command cannot publish. The active slot
stays occupied until verified completion and explicit finalization.

The initial submit installs the immutable initial seven public roots before
enqueuing a candidate. If that first flight is cancelled/reset, subsequent work
at epoch0 borrows those existing GPU roots; it must not upload a checkpoint.
Both bootstrap recovery paths are tested. The new serial is still required.

This reset invalidates admission work, not the game session, simulation clock or
device. Device removal, timeout recovery and replacement weather ownership need
separate integration contracts. Failure before finalization preserves the old
bundle; it does not consume the uncommitted source/physical time.

## 3. Actual WARP evidence

Nine schedules reuse the three frozen s116/s114 physical graphs on the small
8×32 source/pool fixture. They include:

1. Ordinary submit/observe/finalize for checkpoint, resume and fresh interval.
2. Repeated publication requests before any completion observation, newer
   submits and duplicate retries. The event may physically finish early, but
   publication remains forbidden until the host verifies it.
3. Cancel and reset both before observation and after ready observation.
4. Cancel/reset the first submitted candidate, then recover by borrowing the
   initial GPU roots.
5. Reduced/restored admission capacity and a genuinely executed partial graph
   whose `commit=false` contract prevents publication.

| Evidence across nine schedules | Count |
|---|---:|
| Host commands | 356 |
| Submitted and finalized flights | 34 |
| Bundle publications | 27 |
| Cancel/reset discards | 6 |
| Partial, unpublished completion | 1 |
| Publication refusals before observation | 77 |
| New submit/retry refusals while in flight | 155 |
| Physical shader draws / region copies | 2931 / 957 |
| Output/import/incoming-root comparisons | 5497 |
| Checkpoint/produced-texture uploads | 0 / 0 |
| D3D debug warnings/errors | 0 |

Every completed candidate, including abandoned ones, matches its exact oracle.
All nine final public/private/cache bundles, ledger, clock/control and snapshot
arrays equal uninterrupted execution and s116 byte for byte. Each schedule
publishes three bundles; the first is a physically refused checkpoint, so these
are not27 accepted physical intervals or34 distinct weather frames.

This recorded run also observed seven actual incomplete `GetData` results.
That count is scheduling-dependent and is not a fixed regression expectation.
An explicit **test-only bounded wait** repeatedly calls the same poll function
to make fixtures deterministic. Normal poll issues a single query check; the
test wait and final shutdown audit are not a production frame path.

Two additional fatal-path guards are excluded from the table: a replacement
body on a control command, and EOF with an unfinalized flight. Both hold the
flight during a diagnostic drain and verify the previously published GPU roots
unchanged. Neither publishes the unfinished candidate. This is fail-closed
test shutdown, not a successful device-loss recovery implementation.

## 4. Independent audit and remaining cost

MSVC `/W4 /WX` and the actual WARP debug layer pass. Existing physical shader
bytecode is copied unchanged; no shader expressions are modified.

The audit independently decodes commands and graphs, reconstructs each
admission/cache/free-list decision, tracks the active graph and retained oracle
ownership, and checks every transition/counter against native JSONL results.
It verifies that query/map counters cannot advance through submission, rejected
publication, cancellation or reset; retirement only occurs after verification.
Final root hashes also match the previous s116 audit.

The submit path still constructs pipeline/constant-buffer objects, creates
diagnostic staging textures, copies every output and explicitly flushes. A
successful poll maps those diagnostic copies. Therefore this stage proves the
ownership protocol, not cheap rendering, zero driver stalls, an asynchronous CSP
backend, measured VRAM/RSS bounds or an FPS gain. Descriptor budgets remain
fixture constraints excluding staging, buffers, driver and CPU oracle storage.

One graph, one flight and bounded current roots/caches survive across commands.
Stats append directly to disk; the C++ executor keeps no command-history vector.
Python fixture generation/audit may retain aggregate evidence for comparison.

Runtime53 Lua/HLSL files, three INIs, assets/materials and275 s91–s116 files are
preserved. No install, reload/log request, commit or push.

## 5. Next implementation

Separate per-output oracle staging from the normal candidate path. Define a
backend contract for submit/poll/finalize/discard and validate delayed/failing
completion independently of the fixture readback machinery. Preserve the
single-flight and joint-publication rules before designing a CSP adapter.
Economical physical accuracy, full lifecycle/convergence, device recovery and
target GPU/CSP timing remain open adoption gates.

## 6. Reproduce

```text
docs/tools/check_s117_inflight.py
docs/tools/finalize_s117.py
```

Executor: `docs/tools/s117_inflight_stream.cpp`. Build/fixture helper:
`docs/tools/s117_inflight_reference.py`. Evidence, compressed graphs/commands,
native build and shader hashes, independent audit, baseline and source diff:
`docs/diagnostics/2026-10-17/s117/`.
