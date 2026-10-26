# s250 — bounded dispatch pacing (2026-10-23)

## Change and invariant

s249's warmed pair took20 engine frames to submit155 passes under an8-call
ceiling,then10 more frames for status readback. s250 versions only the owner
submission policy and adds bounded telemetry. The physical graph,queue,
receipt validation,rollback,managed resources and source s249 remain unchanged.
Default call ceiling is32,validated in1..64;the pre-call soft deadline remains
1ms. Diagnostic schedules can choose a ceiling per batch. Options are copied
so caller edits cannot change an existing pacing policy.

The deadline is checked before each backend submission,so an SDK call already
running cannot be interrupted. A single slow call can exceed1ms. Telemetry
records this;1ms is not a hard frame-time guarantee. Bind/uniform preparation,
allocation and callback work are not preempted by this guard. `maxPumpMS`
includes bind/submit/owner processing in a pump;dispatch metrics cover the
executor pump. Initial preparation/build/allocation is outside pump timing.

## Measured fields

Each bounded per-batch record includes ceiling,attempts/accepted/not-ready,
call-cap and deadline deferrals,active pump count,max calls per pump,total/
maximum dispatch ms,over-budget pump count,total/maximum backend call ms,
maximum owner pump ms,and first/last accepted-draw engine frames.
Backend call durations include the existing file-readiness wrapper;they are
not isolated GPU/driver timing. Cold not-ready calls are not automatically
classified as compilation. Profile clock is the existing wrapped engine clock.

## Local evidence

Nine simulated pacing cases compare the complete accepted command stream
(shader identities,all values,target and texture IDs) across old8/new8/new32,
pending8/32 and retry8/32. Each comparison group matches exactly. Slow backend
calls stop further submission on the deadline;an oversized2ms call is allowed
to finish and prevents a second call in that pump. No early resource reuse,
changed receipt,extra accepted input or lost debt is introduced.

Seven real-owner/executor/adapter mocked panel cases and five host/native/
offscreen guards pass,including synchronous callback,bad status,timeout,
cancel and image readiness. Normal/pending/sync logs pass the actual decoder.
The full physical native s249 reference is inherited;no physics shader changed
and no repeated native solve or GPU/FPS performance claim is made here.
Simulated clock values and callback counts are control checks,not CSP speedups.

## Actual CSP result

Fresh-session report and automatic log agree:observed,4 batches,8 inputs,
620 accepted draws,155 resources /169,978,048 bytes,4 readbacks/disposals,
20 file checks. Advanced time is0.1162261962890625s and debt is0. Both32-call
batches and the warmed8-call batch have155 accepted attempts,no not-ready
returns and no deadline deferrals.

| Warm batch | Call limit | Submission pumps/frame span | Max dispatch ms | Max owner pump ms | Cap deferrals |
| --- | ---: | ---: | ---: | ---: | ---: |
| 2 | 32 | 5 | 0.8645 | 2.0326 | 4 |
| 3 | 8 | 20 | 0.2617 | 1.4026 | 19 |
| 4 | 32 | 5 | 0.6431 | 1.9223 | 4 |

Accepted-draw spans are875–879,890–909 and920–924 respectively. Warm32
reduces submission frames20→5 (75%) in this observation. Consecutive receipt
gaps are15 frames for the32-call batches and30 frames for the8-call batch.
All four readbacks still take10 engine frames;wall latencies are144.2286,
151.9773,151.8998 and148.5162ms. This is scoped submission-pacing evidence,
not a measured FPS gain or a sustainable continuous-time simulation pass.

**32 is qualified as the next private warmed dispatch candidate:** neither
warm32 dispatch pump exceeds1ms in these two samples. The entire owner pump
does exceed1ms (maximum2.0326ms),since binding/uniform preparation/owner work
is outside the pre-call dispatch deadline. Maximum timer values need not
belong to the same pump and must not be subtracted to claim an exact cost
partition. No hard1ms callback guarantee or tail-run qualification is claimed.

Cold batch1 at limit8 has151 not-ready returns and one over-budget dispatch
pump:6.2423ms,including a maximum backend call6.1715ms. This confirms the
non-preemptible-call limitation;its cause is not identified as compilation.
It is excluded from the warm8/32 comparison and remains a startup/tail issue.

The first cold sample and only one warm8/two warm32 samples do not establish
long-run distributions. Private inventory evolves between batches,so this
is not an identical-state paired benchmark. Next address total preparation/
owner pump cost and amortize the remaining10-frame CPU confirmation barrier
through safe GPU continuation;memory/static dispatch and live inputs remain
open. Preserve the measured32-call candidate rather than claiming the full
frame budget or live adoption has passed.

Evidence:`diagnostics/2026-10-23/s250/actual_capture.log` and
`actual_observation.json`. Pending documents/tool/delivery are retained in
`pending_sources/` and `pending_delivery.json`. No Git commit/push.

## Reproduction procedure

The default-OFF panel captures one context and clones eight frozen private
inputs into four retained batches. Limits are **8,32,8,32**. Batch1 is cold;
compare batches2/4 against the warm8-call batch3,considering clock variation
and evolving private water inventory. This is same-session attribution,not a
paired identical-inventory FPS benchmark or continuous engine coverage.

Fresh unpaused game/replay session,other diagnostics OFF. Main RainFX →
Weather inputs and physical units (P0): **Enable s250 bounded dispatch comparison**
→ **Run s250 bounded dispatch comparison once**.

Normal expectation:observed,batches4,inputs8/8,draws620,resources155,debt0,
four reads/disposals. About162.1MiB stays until session end. No weather/driving/
FPS comparison is needed. Automatic logs are collected by
`docs/tools/collect_s250_observation.py`. A refusal can exhaust the fixed four-
batch diagnostic schedule;report the fault rather than treating it as success.

The actual scoped warm32 result is recorded above;complete frame/continuous
throughput qualification remains open. The10-frame
readback mechanism is unchanged;more GPU-resident work,static dispatch/memory
and continuous input intake remain open. Visible physics/optics stays s87.
No Git commit/push.
