# s262 — bounded recovery of continuous film transport (2026-10-23)

## Implemented and installed, default OFF

The main app's s262 path composes s261 refusal provenance, the existing s241
dyadic retry policy, retained s260 storage, and real engine input capture.
The s260 experiment and its evidence remain preserved. Public rendering stays s87;
heads/source/optics are not connected to this controlled20µm field.

On a validated refusal, new normal submissions stop. Already submitted suffixes
are GPU-blocked and all their audits are drained. The physical film, checkpoint
and cumulative ledger remain retained. Only the predecessor receipt gate is reset;
no stock reset or resource reallocation occurs. The original normalized input is
retried at half its previous time span. Each accepted portion advances its retained
checkpoint; failed portions advance no time. Up to24 attempts per original input
are permitted. Once complete, the original blocked suffix is replayed in order,
with submission overlap under the existing whole-pump3ms/256-call soft budget.
Only complete original slices settle the input FIFO, exactly once.

Invalid receipts, duplicate identity, exceptions and timeout still fault and
quarantine. Repeated physical refusal exhausts the finite retry budget. No safety
predicate or tolerance is weakened. A valid accepted result is required after
every retry; a smaller time step is not assumed to succeed.

Normal unsubmitted source age remains250ms. Exceptional recovery/catch-up allows
at most1s unsubmitted age and1s audited debt,with64 CPU input contexts. The GPU
ring remains32 slots/99 total textures,about71.1MiB. These exceptional bounds are
an explicit recovery envelope,not an acceptable visible-latency/performance
result. Full input capture continues during recovery; buffer exhaustion stops
and retains admitted time plus one captured-but-unadmitted observation.

## Startup

GPU canvas creation is now staged: at most8 allocations per callback under a3ms
pre-call soft budget. Graph/template construction remains synchronous and is
reported separately as `graphInitializationMS`. This removes the single-callback
allocation burst;it does **not** establish that the former93.95ms startup peak is
fully solved. A single graph build or driver call can still overrun the soft
budget. The actual s262 run must determine the remaining graph-construction cost.

## Local evidence

- Native actual-grid recurrence reproduces a refusal on input7. Its final reason
  mask is278;inner flow loss statuses are2 while interval eligibility and post
  status remain valid. Captured map inputs contain rejected/reversing/overtaking
  donor intervals. This is a local reproduction;the original s260 aggregate log
  cannot prove its first internal cause was identical.
- Retry halves the rejected15.625ms interval. The first7.8125ms succeeds;the
  second half refuses,then two3.90625ms portions succeed. The full15.625ms is
  advanced with zero remaining debt,using the same physical roots and source.
- Ten integrated owner fixtures cover normal/30FPS/pause/pending/reordered,
  rejection followed by recovery/replay,permanent refusal,bad audit,timeout and
  cancellation. Recovery and the full3-second input drain pass in the recoverable
  fixture;permanent refusal faults within the finite cap. Simulated scheduling
  times are not measured game performance.
- Six real-adapter panel fixtures,five lazy main-host guards and six inherited
  decoder negative controls pass. Linked workspace/game hashes match. No new
  standalone app is installed. The inherited parser tests apply to normal
  no-refusal fixture output;they do not qualify actual recovery output.

Evidence: `diagnostics/2026-10-23/s262/`. Native replay reads between draws;
continuous CSP recovery still needs the installed integration gate.

## Actual CSP result: recovery works,continuous gate fails

The corrected s262 UI was executed in a fresh session. All75 submitted receipts
were audited and all75 readbacks disposed;pending0,duplicates0,99 resources.
Eleven original slices were recovered/replayed,with13 recovery submissions.
First refusal reason278 identifies inner flow refusal,matching the local final
mask;the actual detailed map/inner failure was not captured and is not proven
identical to the local deformation failure.

The run stopped on `time_capacity`,not a pending GPU refusal. It represented
1.488035699s of admitted source time,advanced0.700489044s and retained0.787547112s
of debt,with a-0.456348µs quantization remainder. One captured but unadmitted
17.430000ms observation is also retained;capture time1.505465699s equals admitted
time plus that observation. No admitted or captured source time disappeared.
Peak debt was0.984004s before the capacity stop;later audits reduced it. Thus the
terminal debt need not equal the1s prospective-admission limit that caused stop.

Normal GPU continuation occurred55 times before the prior CPU audit. However,
recovery serializes validated attempts across ten-frame readbacks (median192.4121ms,
p95 216.6992ms). The causal inference is that exceptional recovery reintroduces
the callback barrier in a path that is exercised too often for continuous intake.
GPU execution time was not measured. Do not label0.700489/1.488036 a measured
wall-clock throughput ratio or claim that every recovery submission failed.

Graph construction still costs80.7245ms synchronously;allocation staging did not
solve that remaining startup spike. Maximum live owner pump is6.0575ms,above its
3ms soft budget. This is not a full-app timing percentile or FPS measurement.

**Decision:** accept the scoped recovery/time-ownership behavior,fail the planned
three-second continuous gate and reject CPU-audited dyadic recovery as normal
game transport. Keep it as a safety/reference path. Do not enlarge queues or
repeat latency probes. Next use an established bounded-cost GPU transport policy
that enforces stability before submission and avoids a CPU callback per retry;
cache/stage graph preparation as separate work. Head/source/optical adoption stays
gated. No additional user experiment is requested for this failed candidate.

Actual evidence: `actual_capture.log`, `actual_evaluation.json`;the pending
delivery/documents are archived in the same diagnostic directory.

## Executed integrated gate procedure

Delivery correction: the first delivery defined the s262 UI helper but omitted
its call from the actual `physics_inputs` dispatcher. The user's subsequent run
was s260,not an s262 observation. The missing call is now present;the verifier
first rejected the missing-call version,then executed the actual menu prefix and
confirmed exactly one s262 call. Prior delivery/checks and the user's s260 log
are preserved in `diagnostics/2026-10-23/s262/ui_dispatch_fix/`.

Fresh unpaused game/replay,other diagnostics OFF:
RainFX → Weather inputs and physical units(P0) →
**Enable s262 continuous film transport → Start s262 continuous film transport**.

The path captures3s after warmup and drains automatically. Send terminal State,
Submitted/audited/pending,advanced/debt and error if present. Logs automatically
include first refusal reason,recovered slices,retry attempts and graph preparation
time. No FPS/weather matrix or screenshots are needed for this functional gate.
Actual continuation,recovery latency and startup cost remain unqualified until
that result. Product performance/visible coupling remain later acceptance gates.
