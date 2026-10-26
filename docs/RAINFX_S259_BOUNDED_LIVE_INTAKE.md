# s259 — bounded continuous intake (2026-10-23)

## Decision and scope

The s258 paired CPU preparation improvement is accepted. Existing actual results
already establish a roughly ten-frame status callback delay;smaller status reads
(s247)and two arenas(s256)did not remove it. Do not repeat those experiments or
make more isolated precision probes to postpone live integration.

This step implements a reusable live intake controller rather than another game
probe. It composes the observed s239 continuous capture with the existing bounded
`rain_time_queue.lua`. It makes overload,old input and cancellation explicit so
the transport adapter cannot conceal growing lag by dropping frames or declaring
an empty finite test a continuous throughput pass.

Files: `docs/prototypes/s259/s259_stream.lua`,`s259_time_queue.lua`,`s259_live.lua`.
The deployment factory uses the actual main-app API,pose/settings bootstrap and
retained row composer. No additional UI,game reload or user experiment is needed
for this CPU-only composition. It is not yet called from `realvisor.lua`;no new
water solver or visual effect is connected to the game in this step.

## Standard queue and lease rules

- Defaults:16 positive-time source contexts,262144 ticks(250ms)of represented
  uncompleted time,and250ms of unpaused host waiting age. These are configurable
  overload guardrails,not a claim that250ms is acceptable visible trail latency.
- Capture every contiguous engine frame. Queue the actual physical rows and
  provenance;do not merge frames,average forces,change rain supply or resample
  physical dt to obtain a better throughput number.
- Reuse the existing error-carrying1048576-tick/second clock. Frames longer than
  31.25ms produce contiguous slices,not truncated elapsed time. Zero-time pauses
  consume no positive-time queue entry. Repeated callbacks do not add time.
- One owned active slice can be issued/retried. The existing physical admission
  module consumes its context;the downstream owner must validate the GPU result
  before calling `acceptQuarter(ticket,q)`. This API is not a GPU fence or receipt
  validator. Out-of-order/duplicate/changed-ticket completion is refused.
- Intake continues while that slice waits. Capacity,physical debt or source age
  overflow closes intake and stops capture. One already captured but unadmitted
  observation is retained separately,including its raw time. No ring overwrite,
  automatic stock clear,oldest-frame eviction or silent time loss occurs.
- Cancel/overload stops issuing work but allows the already issued slice to
  settle exactly once. Queued debt and the unadmitted observation stay recorded.
  Recovery requires an explicit new epoch and a solver stock/reset/remap policy;
  this controller does not invent that policy or erase water.
- Pause is excluded from host waiting age;resume and setting/replay/geometry
  changes inherit the actual capture checks. A bad/regressing host clock stops
  intake. Source settings and returned tickets cannot mutate retained queue data.

`s259_time_queue.lua`changes only the old1024-slice diagnostic identity ceiling
to an explicit configurable maximum(default1048575). FIFO,quantization,source
checks,31.25ms slicing and quarter settlement are unchanged. Identity exhaustion
requires a new epoch;it never wraps silently. This is not an unlimited-session
claim. The controller holds at most capacity+1 distinct positive-time source
observations,plus fixed bootstrap/composer and lease copies. That count is not
a measurement of total Lua heap or VRAM.

## Verification and what it means

One local suite checks12 cases:actual deployment factory and physical admission;
1200-slice session/ring reuse;lease mutation and duplicate completion;long pause;
entry/time/age overflow;cancel with late settlement;setting/replay reset;clock/
duplicate callbacks;and explicit session identity exhaustion. The factory runs
the real bootstrap,engine sampler,cached composer and queue against controlled
engine API fixtures. It performs20 initial file checks and no per-frame file I/O.
A200ms frame is fully subdivided,paused time stays zero,and admission/queue clocks
agree. Every recorded source time equals admitted raw time plus separately held
unadmitted time;admitted time equals advanced+debt+quantization remainder.

The same suite replays a service-rate envelope using s258's recorded warm
262.2187ms/eight-input cycle at60Hz arrival. It overloads at event24:23 frames
admitted,eight settled,15 still held and250ms debt,with one rejected observation
retained. Maximum retained source count is16. This is deterministic queue-pressure
evidence,not a new CSP run or actual batch-adapter execution. A synthetic100ms/
eight-input envelope stays open for180 arrivals with peak seven queued contexts;
its remaining six contexts are explicitly still debt,not reported as drained.

Report: `docs/diagnostics/2026-10-23/s259/checks.json`.
Run: `docs/tools/check_s259_stream.py`. GPU shaders/resources and public runtime
are unchanged;no repeated native GPU qualification or FPS comparison is needed.

## Bounded next task and stopping rules

1. **Next implementation:one integrated GPU-resident transport path.** Connect
   live capture/time slices to ordered retained state,ping-pong resources and a
   bounded ring of immutable small audit copies. CPU audit callbacks must not be
   the normal step-to-step simulation barrier. GPU acceptance must gate ordered
   continuation;no arbitrary skipped debt or early CPU completion assumptions.
   The current controller leases one slice;the adapter must compose reservations
   and aggregate validated receipts for its chosen execution shape rather than
   pretending the old finite eight-input queue already supports live intake.
2. **One focused CSP integration gate when that ownership path is complete.**
   Measure continuous accepted time/backlog,oldest input/state age,CPU pump tail,
   retained resources and reset/cancel behavior. Reuse existing physics oracles;
   rerun changed ownership/transport regressions,not all historical precision work.
3. **Decide on the result.** If sustainable processing and state age remain
   inadequate,choose a cheaper film solver/update policy and evaluate water/visual
   quality. Do not keep increasing window length,arena count or probe variants.
   A lower film update rate must account for the full physical interval and
   head/trail synchronization. It cannot be an implicit dt truncation.

The subsequent visible comparison is the actual2048/4096-slot workload. Use
frame-time increment and p95/p99 with head/trail connection and stable memory.
Targets remain those in `RAINFX_GAME_ACCEPTANCE_POLICY.md`;do not promote a
bind-only speedup,draw count or this safety controller to a whole-app FPS result.
