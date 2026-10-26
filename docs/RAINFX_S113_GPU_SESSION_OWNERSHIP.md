# s113 — GPU ownership across native calls

2026-10-17. **Status: ACTIVE — bounded offline native session protocol.**
Production remains s87 physics with s89 diagnostics; no game build is installed.

## 1. Public, checkpoint and cache share one publication boundary

s112 executed persistent GPU graphs but uploaded the checkpoint at the next
call's start. s113 keeps actual D3D11 texture handles in a session root bundle:

- Seven public roles: end, mean, history, heads, ledger, header and snapshot.
- Seven private roles: end, mean, history, heads, ledger, control and snapshot.
- Two interval-cache roles: metric data and its receipt.

Roles can alias the same whole parent texture. End/mean/history typically share
three-bank parents; the root layer preserves that physical identity and extent.
The seven initial public roles are seeded from immutable external inputs.
Successful calls publish all16 logical roles as one map, with one bundle epoch.

At a later call, retained imports resolve by root name and expected epoch.
Their actual GPU handles are bound directly. The captured expected arrays are
used only for readback comparisons, never as initialization data for a retained
checkpoint/cache/public texture. External immutable content is uploaded once
per session/content key; constants still follow the inherited host upload path.

Each call executes into private candidate pool slots. The incoming bundle is
held through all candidate/publication passes, including an unused old private
checkpoint/cache while a new interval prepares its replacement. After all
requested commands, the executor checks an event query and compares every
produced output, imported parent and incoming logical root against the oracle.
Only a complete call may swap the entire root map and increment the epoch.

A stopped call or a complete-but-abandoned candidate leaves both the handles
and epoch unchanged. Completed, unbound default textures enter the free list
only when no current root or external import retains them. Later calls reuse
matching descriptors. One ordered immediate context and per-call completion
drains bound this ownership proof; asynchronous queues/device recovery remain
outside its scope.

## 2. Verification

MSVC `/W4 /WX`, FXC `/Ges /WX` and the actual D3D11 WARP debug layer pass.

| Session | Native calls | Retained imports borrowed | Completed targets reused |
|---|---:|---:|---:|
| Compressive source/pool refusal, abort/retry, next interval | 8 | 70 | 292 |
| Actual curved film, two intervals, X then Y | 2 | 5 | 30 |
| Actual curved film, two intervals, Y then X | 2 | 5 | 30 |

Across12 core calls, **999 draws,358 region copies and1905 readbacks** match the
existing single-draw oracle byte for byte. Checkpoint/cache/produced texture
uploads are zero. All original imports and incoming root handles remain intact
until publication. There are no D3D debug warnings/errors. Source and pool water
are applied once; the established water/momentum ledger tolerances hold for
the resumed source case and both consecutive curved sessions.

For the two-interval curved sessions, the final audit checks each interval's
residual increment against the existing single-interval gate. Accumulated
float32 ledger roundoff is checked against the sum of those two bounds.

The planar session performs:

1. A complete, physically refused attempt publishes its private checkpoint;
   public data is preserved by the existing GPU transaction shaders. Epoch0→1.
2. Three resume attempts abort before ledger, header and snapshot publication.
3. A full GPU resume completes, then is abandoned before the host root swap.
4. The same resume succeeds and publishes the complete bundle. Epoch1→2.
5. The next interval aborts before its new cache receipt, then succeeds.
   Epoch2→3.

The five aborts preserve the incoming bundle. All resume/abort calls in the
same interval borrow both cache parents and require no fresh texture uploads.
New intervals build a new GPU cache while the old root bundle remains protected.

Seven corrupt protocol requests reject:

| Mutation | Rejection boundary |
|---|---|
| Stale bundle epoch | prepare, previous epoch1 intact |
| Stale retained-root generation | prepare, previous epoch1 intact |
| Unknown retained root | prepare, previous epoch1 intact |
| Wrong retained-parent extent | prepare, previous epoch1 intact |
| Partial root bundle | whole-session validation, before device creation |
| Publish a partial command graph | whole-session validation, before device creation |
| Re-upload a protected GPU input | whole-session validation, before device creation |

The s112 graph validator still checks every graph's copy regions, slot aliases,
last uses and retained exports. Final audit also independently reconstructs
serialized graph pools and the CPU-side epoch/root-link sequence. Native
readback comparisons establish actual GPU execution; CPU reconstruction is
additional ownership evidence, not a substitute.

## 3. Costs exposed by this implementation

Holding whole parents across calls adds three materializations when subsequent
graphs consume public end/mean/history as separate inputs. Full later calls
therefore use26 copies instead of23, or44 instead of41 on the two-attempt
resume. At the symbolic1024×256 profile this is12MiB additional copy output
per complete later call. Shader arithmetic and physical expressions do not
change. The per-call exact-size reserved target pool in the tested graphs stays
at the prior value; the session also holds incoming roots until publication.

The native reuse counts demonstrate actual reuse after completion, not a
general fixed-memory bound. They exclude the cost of retained roots, staging
diagnostics, all loaded fixtures, driver allocations and buffers from any peak
memory claim. Readback staging and completion waits are verification tools.
WARP counts and symbolic sizes do not establish target GPU time or game FPS.

**Decision:** cross-call GPU ownership and joint publication pass this bounded
native gate. The boundary copies and whole-parent lifetimes need further work
before performance adoption or CSP integration.

## 4. Next implementation

Compare retaining the already-produced logical band exports as public/private
roots, instead of retaining their whole packed parents. Define the corresponding
input descriptor/owner mapping explicitly and verify it against the current
parent-root session. Aim to remove the three extra boundary copies without
losing zero-border semantics, complete ledgers, shared cache ownership, aborted
publication protection or generation checks.

Then evaluate longer repeated sessions and capacity/retirement behavior.
Bounded work/backlog, economical material accuracy, physical closure/convergence,
full head/source lifecycle, device failure recovery, asynchronous integration
and target GPU/CSP timing remain open. Runtime, calibration, INIs/materials,
published assets and prior stages are preserved. No installation, game reload/
log request, commit or push.

## 5. Reproduce

```text
docs/tools/check_s113_sessions.py
docs/tools/finalize_s113.py
```

Executor: `docs/tools/s113_session_graph.cpp`, reusing the frozen s112 graph
helpers. Capture/session manifest helper: `docs/tools/s113_session_reference.py`.
Native reports, generation/link metadata, compressed fixtures, per-graph DAGs,
strict build log, compiled shader hashes, baseline and final audit are under
`docs/diagnostics/2026-10-17/s113/`. The helper restores archived sibling graphs
temporarily when executing an archived session and verifies that path with a
stale-epoch guard.
