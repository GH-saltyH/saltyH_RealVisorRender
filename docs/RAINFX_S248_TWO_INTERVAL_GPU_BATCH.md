# s248 — two-interval GPU-dependent batch (2026-10-23)

## Implemented boundary

s247 measured10 engine frames between request and callback for both minimal
and physical status textures. s248 removes the CPU readback **between two
input intervals**. Both intervals form one ordered private DAG. Their physical
working sets are distinct;static file/topology resources are shared. Stage2
initializers directly consume stage1 film,checkpoint and cumulative ledger.
One final16-word batch status consumes both intermediate GPU statuses and
is read once. No public stock,time or renderer handle is published.

The first GPU status is checked for receipt,finite values,physical audit,
inventory,area and exact advanced/debt time. Stage2 may commit only when that
status is valid and the first full interval was accepted. If first refuses,
stage2 decision is zero and its checkpoint copies the refused prior state.
Final status retains an accepted prefix0/1/2 and the corresponding time debt:

| Result | Advanced time | Retained debt |
| --- | --- | --- |
| First refused;second blocked | 0 | dtA+dtB |
| First accepted;second refused | dtA | dtB |
| Both accepted | dtA+dtB | 0 |

An invalid first/second audit faults the batch rather than producing a valid
published result. Refusal is distinct from audit failure. The final receipt
also consumes the blocked stage2 graph,so completion covers every submitted
write even though blocked status does not count as a second accepted input.

## Cost and ownership

The first candidate deliberately duplicates physical working storage,avoiding
unverified reuse of a target still involved in the chain. At4096 slots it uses
155 canvases /169,978,048 bytes (162.1037MiB),with an explicit192MiB diagnostic
cap. The root executor remains untouched;a versioned copy changes only its
allowed explicit byte cap128→192MiB. Receipt,ordered dependencies,pending,
timeout,cancel and quarantine rules are retained. No GPU allocation is freed
or reused early. Managed canvases remain until app/session ends.

Accepted submissions are155:85 first-stage passes,69 second-stage passes after
16 static aliases,and1 batch status. This adds one GPU pass versus the previous
two-interval total154,while reducing CPU status round trips2→1. Submission
pacing is still at most8 SDK calls per callback with the existing1ms soft
deadline. It is not a real-time throughput pass or a complete memory policy.

## Verification

Local D3D11 WARP executes483 native draws including a sequential two-input
reference,normal batch and fault branches. Inputs have different dt,force,
air and pose. All six film/checkpoint/ledger roots match the sequential
reference bits in the accepted case. First refusal leaves both intervals'
time as debt and stage2 roots match stage1 rollback bits. Second refusal
retains stage1 film/history and only dtB debt. Injecting a bad first audit
propagates a hard batch refusal. All newly used HLSL bodies compile strictly.
An initial strict compile found reused loop variable names;the corrected
variant uses distinct loop identifiers. Failed generated source is preserved.

Seven mocked real batch/executor/adapter panel cases cover normal,pending,
synchronous callback,invalid status,timeout,image readiness and cancellation;
five main/native/offscreen host guards pass. Normal reports are parsed by the
actual decoder. Installed links/dependencies and preserved-source hashes pass.
These are native reference/correctness results,not actual CSP GPU timing.

## Actual CSP observation

Fresh-session user report and automatic log agree:observed,completed1/1,
accepted prefix2/2,155 accepted draws,155 resources /169,978,048 bytes.
Exactly one status readback and one CPU disposal are recorded for both
intervals. All20 file checks completed. Each frozen interval represents
0.021741867065429688s;advanced time is0.043483734130859375s and debt is0.

Final readback request at engine frame1269 returns at1279:10 frames,
146.8544ms wall latency. This retains the per-request latency observed in
s247 but pays it once after two GPU-dependent intervals. It confirms the
actual CSP dependency and single-receipt boundary;it does not demonstrate
a halving of total execution time or any FPS gain. The one cold run includes
171 not-ready attempts and230 scene-ready callbacks;there is no warmed,
matched sequential-versus-batch throughput measurement yet.

The actual initial/final water inventory is805.7721558→805.3399658mm3;
field evaporation0.0315554mm3 and runoff0.4006243mm3 are recorded. The GPU
ledger residual/bound ratio is0.002989 (below1);the final GPU audit passes.
This qualifies controlled20µm frozen-pair execution,not live source/head or
changed actual engine inputs. Refusal branches are covered natively;the
actual CSP run accepted both intervals and did not exercise those branches.

Evidence:`diagnostics/2026-10-23/s248/actual_capture.log` and
`actual_observation.json`. Pending documents/tool and delivery are preserved
in `pending_sources/` and `pending_delivery.json`.

Next retain validated inventory across batches and recover refused/deferred
input time without reapplying accepted input. Distinct working sets currently
remain private/session-retained;reduce memory after safe continuation is
composed. Continuous cadence,representative throughput and visible optics
adoption remain open. No Git commit/push was performed.

## Reproduction procedure

Fresh unpaused game/replay session;other diagnostics OFF. Main RainFX →
Weather inputs and physical units (P0): **Enable s248 two-interval GPU batch**
→ **Run s248 two-interval GPU batch once**.

Expected:observed,completed1/1,accepted prefix2/2,155 draws,155 resources,
one readback/disposal and zero debt. If refused,the prefix/debt are meaningful
results;send those or any fault. About162.1MiB remains until session ends.
Five automatic log lines are collected with `collect_s248_observation.py`.
No weather/driving/FPS comparison is needed. The runtime diagnostic clones
one captured input into an explicitly frozen pair;the changed-input case is
qualified by the native test,not claimed as two actual engine captures.

Actual CSP dependency/readback behavior now passes;throughput improvement is unmeasured.
The prototype starts from controlled20µm film and does not yet combine with
live source/head production,retained batches or adaptive recovery after a
refused prefix. Next connect retained inventory/debt continuation and reduce
duplicated memory. Visible s87 remains.
