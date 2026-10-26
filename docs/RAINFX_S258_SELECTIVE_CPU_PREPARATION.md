# s258 — selective CPU packet preparation (2026-10-23)

## Implemented change

s257 verifies reduced GPU work at unchanged memory but leaves warm CPU bind plus
submit preparation4.803ms and a5.349ms whole-pump peak. s258 targets bind packet
construction. It retains the s257 GPU recipe,541 draws per eight-input window,
two receipts per16 inputs,65 canvases/74434592 descriptor bytes,and the same
3ms/256-call soft owner policy. It does not change the executor's independent
submission snapshot,typed-value cache,resource lifetime or completion rules.

The original runtime path binds a full single-input template eight times. Each
template clones its85-pass packet,clones the input context/rows,and replaces
dynamic values. The batch then copies the541 selected pass values again. Only
533 single-input pass packets plus8 summaries actually reach the compact GPU
graph;the other147 single-input packets are discarded.

The new template compiles private selections once:85 entries for stage1 and64
for each of stages2..8. Its constant prototypes exclude the row/ticket/id fields
that will be replaced. Each bind validates the full context/calibration as before,
generates only the selected fresh pass tables and copies current header/audit rows
directly into them. The batch adopts those new tables without another deep copy.
Frame/audit row keys are precomputed. No whole input-context clone is needed.

The full original bind path is retained behind `bind(job,false)` for controlled
comparison. Default/true uses selective preparation. The resulting complete
resource graph,shader text,schemas,texture links,cache keys and payload bits
are unchanged. Physical/time/receipt ABI remains qualified255001.

## Ownership

- Selection indices are validated and copied into constructor-owned operations.
  The public token is an opaque identity;editing its fields or the original
  index list cannot edit the private selection. Foreign/duplicate/out-of-range
  selectors refuse.
- Every bind returns fresh values,including separate frame/audit vectors and
  ticket/token vectors. Values do not alias input contexts,earlier results or
  mutable prototypes. This is not a borrowed scratch packet API.
- The existing executor still validates and independently copies all submitted
  values before preparing typed uniforms. Caller changes after submission cannot
  change the GPU job. No busy slot,queued uniform or readback resource is reused
  early. Owner calls bind again only after the prior validated receipt.
- No validation tolerance,finite input check,calibration guard,queue debt or
  reference-audit check is relaxed to obtain the reduction.

## Verification

81 combinations of starting identity,declared count and full/refused/partial
ticket progress compare every packet's FP32 bits against s257 and the retained
original path. Fixtures include changing force/weather/material input rows and
signed zero. Complete GPU descriptors/passes/retention maps match exactly.
Mutation/previous-result/prototype isolation,owned selectors,nonfinite inputs
and calibration changes pass. The paired-protocol test checks120 matches,
24 warmup pairs/96 measured pairs,48 of each ordering and mismatch refusal.

Eighteen complete owner/executor command streams match the s257 path,including
all eight refusal positions,SDK pending/slow/synchronous callbacks,invalid
status/prefix/time,cancel,timeout and repeated refusal. Targets,texture inputs,
cache keys and uniform values are included in each command digest. Nine tails
and ten inherited unsafe/storage/receipt controls also pass. Seven actual-adapter
mocked panel cases,five lazy host guards and eight collector corruption cases pass.

Because physical commands and shaders are unchanged,s257's4204 native draws and
actual CSP alias/receipt qualification are inherited by report hash. No optional
repeat of the identical native physics oracle is claimed as new GPU evidence.
This stage's actual CPU cost and host integration test are recorded below.

Local LuaJIT96-pair timing medians are approximately1.772→0.630ms in the captured
run. They are host-side bind-only measurements,not CSP/FPS/GPU results. They do
not include executor submission preparation or status callbacks and do not
establish a frame-time/adoption pass.

## Same-input actual CSP comparison

The default-OFF diagnostic first captures the main app's real context. Before
GPU allocation,it performs one CPU-only comparison pair per callback for120
callbacks. Each pair calls both bind paths on the same frozen eight-input job,
alternating order. All120 results must match,including signed zero. The first24
pairs warm up;the remaining96 supply medians,nearest-rank p95,max and48/48 order
counts. Packet comparison is timed separately and excluded from bind samples.
There is no forced collection to hide allocation/GC cost.

All96 original/selective sample pairs are emitted in12 compact log rows,so the
collector independently recomputes the summaries. These are paired CPU samples
for one input,not a representative weather/driving or GPU benchmark. Workload
order is balanced;JIT/GC/scheduling may still affect the distribution. The extra
reference binds are diagnostic-only and are not part of the selected runtime
owner path.

After profiling,the same graph is passed to the ordinary owner and runs16 frozen
GPU inputs using selective preparation only. No reference preparation is inserted
into those GPU pumps. Canvases are allocated once at this point and retained
until session end. The pair object becomes inert after120 pairs. Disabling or
canceling the diagnostic prevents later CPU/GPU work.

## Actual CSP result — CPU preparation gate passed

The fresh-session observation completes2 batches/16 inputs/1082 draws with65
resources/74434592 descriptor bytes,2 readbacks disposed once each,and zero
retained debt. Accepted physical time is0.38348388671875s. All120 paired results
match;the96 measured pairs reproduce the logged summaries from raw samples.

| Bind-only caller CPU time | Original | Selective |
| --- | ---: | ---: |
| Median | 1.7638ms | 0.71555ms |
| Nearest-rank p95 | 12.7925ms | 3.8304ms |
| Maximum | 17.0696ms | 6.2642ms |

Median decreases59.43% and p95 decreases70.06%. Selective is faster in96/96
measured pairs,including48/48 in each call order. Median paired saving is
1.0664ms (range0.407..10.8054ms). Each order separately improves median and p95;
the result is not explained solely by always executing one variant first.
These sequential samples come from one frozen job/session,not independent
weather/driving trials. No forced GC is used;the data does not isolate GC,JIT
or scheduling causes. Comparison itself peaks0.4759ms and is excluded from
bind timers. Executor snapshots/typed preparation and GPU work are also excluded.

The ordinary selective-only warm owner records bind0.6394ms plus submit1.5213ms
(2.1607ms combined),four submission pumps,and a3.0073ms maximum whole pump.
The preceding s257 capture was4.8029ms combined and5.3486ms maximum,but inputs
and sessions differ;use the paired benchmark above for the causal bind comparison.
The7.3µs soft3ms budget excess is not a product failure by itself. The6.2642ms
bind-only maximum remains a possible preparation spike,not a claimed hard bound.

Warm caller cycle is262.2187ms,of which174.7808ms waits for readback. Both
readbacks still span10 engine-frame increments;warm receipt-to-receipt spans14.
Raw count capacity30.51 inputs/s,or24.41/s with20% reserve,is only a20Hz planning
candidate. Advanced physical time/elapsed is0.7312;finite-list debt0 does not
prove continuous catch-up. Warm SDK caller time totals5.6603ms,not GPU time.
Cold preparation has522 SDK-pending retries over9.715s;maximum cold whole pump
is7.3285ms. This is not evidence of a9.7-second blocking frame.

Evidence: `docs/diagnostics/2026-10-23/s258/actual_capture.log`,
`actual_observation.json` and `actual_evaluation.json`. The collector independently
recalculates median/p95/max;the evaluator records both order groups and all
paired savings. Pending delivery/source snapshots are preserved before sealing.

This remains controlled20µm film with frozen context copies. Visible s87,public
stock/clock/renderer access,continuous source/head integration and physical dt
resampling remain unchanged/unadopted. Git commits/pushes are left to the user.

## Evaluation and next

Accept s258 as the private development base:actual packet/receipt/ownership
checks pass and CPU bind median/p95 improve in both orders. This qualifies the
CPU preparation optimization only;whole-pipeline speedup,FPS and live adoption
remain unqualified. Review remaining executor snapshot/typed preparation and
budget indivisible work where its spikes matter,then address bounded continuous
intake,readback delay and displayed response age. Do not require elimination of
every microsecond soft-budget overrun before useful integration. No larger
arenas/windows or implicit20Hz model change is introduced.
