# s277: retire completed inputs before intake; lazy dispatch packets

## Actual s276 observation

State stopped, submitted/audited23, pending0, resources128. All23 live receipts
were accepted. Raw admitted0.630640103s, advanced0.464261055s, retained debt
0.166378975s. Capture raw0.649485102s includes rejected observation0.018845s,
which remains explicitly reported outside the admitted timeline. Incident/stock/
exits are zero: this run did not reach a nonzero source-cell validation, and does
not qualify the s276 identity fix. No source/GPU refusal was reported.

The stop is entry_capacity, with31 accepted frames,23 completed slices and a
nine-frame maximum submit lag. Audit callback delay remains10frames (median
181.64ms, maximum218.41ms). Maximum whole-pump CPU was12.46ms. These timings are
not a GPU timestamp or a whole-app FPS measurement. The pre-stop cause of the
submission backlog (CPU construction, collection or shader readiness) is not
fully separated by the old counters;148 retries includes warmup retries.

## Concrete scheduling and allocation repairs

1. Retire ready ordered receipts before offering the next engine input. Old code
   offered first, so a queue at capacity could reject a new input even when a
   callback already available in that frame could free an entry. Keep the later
   retirement after dispatch, including synchronous callback support.
2. Build per-draw texture/value packets lazily inside the existing3ms/256-call
   pump budget. Keep a prepared packet verbatim if compilation yields. A single
   packet or API call can still exceed a soft budget; this is not a hard realtime
   guarantee. Graph binding itself remains atomic and is measured separately.
3. After the audit draw is submitted, release the job's CPU recipe/parameter
   tables. Retain every GPU canvas, input lease, identity and callback state until
   ordered retirement. Do not free/recycle resources on the GPU's behalf.
4. Copy full160-word failure details only for a rejected receipt; keep16 receipt
   words for accepted jobs, while still validating all160 returned words.
5. Cache source-cell rewritten strings once per shader key, including negative
   lookups. s276 previously constructed eight replacement strings per interval
   before discarding them in favour of an already cached string.

No queue/time/age limits were increased:16 contexts,0.5s debt,.25s undispatched
age and the same32 audit slots. No frame is dropped or merged; no physics time is
advanced before accepted ordered audit. GPU resources and calls are unchanged:
128 canvases,139151152 owned bytes and640-byte snapshots. The existing s276
physical change is preserved exactly; no equations or thresholds change here.

Added existing terminal-report fields: maxBindMS,totalPacketMS,maxPacketMS,
liveRetries,warmupRetries,retainedRecipes. These distinguish actual live compiler
waiting from cold startup and identify remaining atomic preparation cost.

## Local verification

-16 controlled owner cases (normal/30FPS/pause/long-frame/display/async/pending/
  refusal/pressure/reset/bad receipt/timeout/cancel/cold startup and capacity
  boundary). Same boundary with16-frame callbacks and16-context capacity:
  original owner stops with entry_capacity; revised owner drains successfully.
  This reproduces a scheduling defect, not the entire actual s276 workload.
-Pending packets retain identity across retries. Terminal drained jobs retain
  zero CPU recipes. Genuine overload/refusal and timeout controls still stop.
-Seven real-adapter panel/menu cases and linked installed-file checks pass.
-Three complete recipes,293 draw descriptors, match s276 exactly including
  shader bodies, keys, values, texture bindings and audit. Source rewrite lookup
  calls stay76/76/76 across the three intervals, rather than repeating work.
-The prior56 strict shader variants remain applicable because shader bodies and
  keys are unchanged. No additional native GPU precision experiment is needed.

## Finite next gate

Run the same3-second integrated s277 path once in a fresh unpaused rainy session,
other diagnostics OFF. Need observed/drained, nonzero incident and zero retained
debt before connecting optics. If throughput still falls behind, inspect the
separated preparation/live readiness counters first. Do not raise capacity or
create another broad test matrix as a substitute for fixing throughput.
