# s242 — budgeted private adaptive stream (2026-10-22)

## Delivered

The versioned owner connects the s241 attempt/rollback graph, the existing
private executor and a normalized-progress time queue. The previous one-SDK-
attempt-per-pump guard is replaced by a configurable1–64-call ceiling (default8)
and a soft clock deadline (default1ms). The executor retains its64-logical-pass
ceiling, stable pending parameters, serial/generation receipts, read timeout,
duplicate callback handling and quarantine rules.

This is a locally executed private stream, not installed live RainFX physics.
No source water, public time or renderer handle is published. Visible s87 and
the s239 CPU-tail warning remain unchanged.

## Execution and ownership

- One87-resource slot persists across attempts and source generations. Its
  byte plan is95,622,608 (91.193MiB). All prior-state reads/copies precede any
  root overwrite. File/topology cache stays immutable; input-dependent cache
  is invalidated on a fresh admitted context, under the existing layout checks.
- A callback may attempt at most8 SDK draws by default. The deadline is checked
  before SDK calls; a pending shader returns immediately and keeps the same
  parameters. A single SDK call can exceed the remaining deadline. Allocation,
  submit-time payload conversion and cached signature work are not preempted by
  that check. This is not a guaranteed1ms app/frame CPU budget.
- The budget is per `pump`, not a global frame quota. A future game hook must
  call it at most once in the intended render callback and exclude offscreen/
  native captures. No new attempt is dispatched in the same pump that commits
  its predecessor's validated result.
- Only a validated accepted attempt advances physical and queue progress.
  A validated refusal keeps time unchanged and halves the next request via
  s241. A bad receipt/audit or unknown draw outcome faults the stream, closes
  intake and preserves debt/resources; it is not treated as normal refusal.
- The FIFO/admission now accept monotonically increasing normalized progress
  in0…1048576 instead of exactly four quarter receipts. Intermediate source-tick
  progress can be a dyadic fraction; completion snaps to the exact integer
  source endpoint. Quantization occurs only on source admission, with the
  original signed remainder retained. Existing16-context/250ms debt and1024-
  slice diagnostic limits remain.
- New source/slice admission occurs only after a complete validated interval.
  The checkpoint is rearmed from old phase2/debt0 to the new token/debt, while
  packed film and history are copied unchanged. The s236 physical-scale guards
  and s237 source/slice identity rules remain in the versioned admission.

## Scheduling controls

Ten cases run the actual graph builders and private executor with a mocked
backend: normal batching, pending/retry stability, transport refusal/recovery,
deadline yield, synchronous callback, bad receipt, failed GPU audit, unknown
draw outcome, missing-callback timeout and cancellation. Delayed/duplicate
callbacks cannot advance queue time. Fault/cancel paths retain outstanding debt.

These controls adapt s241's recorded summary fields to their synthetic tickets;
they are not new physical solves. In the deadline fixture, each SDK call costs
200µs and a300µs deadline permits at most two calls, demonstrating the allowed
one-call overshoot. No case exceeds the configured8-call ceiling. Normal,
pending,refusal,deadline and synchronous runs drain two inputs/three slices on
the same87 resources. Full input physical validity is covered separately below.

## Native full-field continuation

A separate WARP execution uses real shaders, full1024x256 fields and real
16-float status outputs, without synthesized receipt/stock fields. Two declared
source contexts carry60ms and16.666667ms, respectively. They use qualified
s236 input rows with explicitly synthetic durations and a controlled20µm seed;
they do not constitute a real continuous engine-frame capture.

| Check | Result |
| --- | --- |
| Accepted sources / completed slices | 2 /3 |
| SDK submissions / immutable cache hits | 229 /32 |
| Real status reads | 3 |
| Peak SDK calls per pump | 8 |
| Resource count / bytes | 87 /95,622,608 |
| Exact film/history copies across boundaries | 4 |
| Represented / advanced ticks | 80391 /80391 |
| Advanced time | 0.07666683197021484s |
| Raw input time | 0.076666667s |
| Signed remainder | −0.164970214846µs |
| Final queued/private debt | 0 /0 |

Independent full-array stock sums match each cumulative ledger within the
existing componentwise FP32 budget; fields remain finite and nonnegative.
Original water stays fixed in history while stored water falls across each
input boundary. Final rounded summary:805.772156→804.987732mm³,evaporation
0.0556358mm³,runoff0.728762mm³. Source volume remains zero. Checkpoint rearm
and exact film/history copies establish continuation rather than reseeding.
The native run has no transport refusals; s241's native stress and this stage's
mocked rejection scheduling cover that branch separately.

## Limitations and next

This proves bounded local scheduling and multi-input physical continuation,
not sustainable throughput. A cold87-draw interval requires at least11 pumps
at an8-call ceiling, even before readback latency. It therefore cannot be
declared capable of consuming every real-time engine frame. Raising the ceiling
alone would not establish acceptable GPU/frame cost, and hard resource/CPU
budgets have not been measured in actual CSP.

Next measure/choose an economical dispatch and completion policy, reducing
proof/reduction/readback work where justified and retaining explicit debt when
over budget. Then qualify actual CSP throughput/tails, replay/reset and long-
run memory before connecting conserved incident/head sources and common optics.
The working path does not yet connect s239's engine sampler automatically.
No game installation, main/settings changes, user test or Git commit/push.

Evidence: `diagnostics/2026-10-22/s242/execution_checks.json`, `gpu_checks.json`,
`continuation_results.npz`, strict compile artifacts and `delivery.json`.
