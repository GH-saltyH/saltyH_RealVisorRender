# s249 — retained batch inventory and deferred-input recovery (2026-10-23)

## Implemented

s249 keeps one155-canvas working set across successive two-input batches.
After the private receipt is validated,stage2 film/checkpoint/history become
the next batch's prior inputs. All initial copies and handoff audits read
the same owned roots,before those roots can be overwritten. The previous
batch must be complete before new values or retry state are submitted.
No global GPU fence,public clock or visible renderer access is introduced.

The static graph/template is constructed once;bind refreshes context rows,
expected audit values,tokens,dt and normalized attempt progress. Per-input
CPU state uses1048576 exact normalized ticks. An accepted step advances only
its submitted ticks;a refused step halves the next step without advancing
time. Stage2 runs only after stage1's input is fully complete and validated.
Already accepted inputs are removed exactly once;refused/deferred inputs
retain their original context and debt. Last-single-input execution blocks
the unused second lane and does not create extra input time.

Private batch status marker249001 reports completed input prefix0/1/2,
newly advanced time,remaining debt for the attempted pair,and action flags.
Those flags determine exact CPU tick updates;float time summaries are checked
within8 FP32 eps relative tolerance (minimum1e-15). This tolerance does not
change CPU integer progress. The previous GPU physical ledger/audit bounds
remain unchanged. Retry limits are24 attempts per input and64 batch attempts;
one-tick refusal,cancel,invalid receipt and budget exhaustion cannot silently
drop debt. Inputs are bounded to16 declared contexts in this diagnostic owner.

## Verification

Local D3D11 WARP executes1455 draws including independent sequential references:

| Native case | Declared inputs | Batches/CPU receipts | Accepted draws | GPU allocations | Final debt |
| --- | ---: | ---: | ---: | ---: | ---: |
| Changed pose/force/air/dt,normal | 4 | 2 | 310 | 155 | 0 |
| Second input refused,then two half steps and single-input tail | 2 | 3 | 465 | 155 | 0 |

Every film/checkpoint/cumulative-ledger root after each batch is bit-identical
to the sequential reference using the same attempted steps. The normal case
advances0.046875s;recovery advances0.0234375s. No GPU allocation occurs per
batch. The recovery's already accepted first input is never reapplied.

CPU queue controls separately cover first/second refusal,duplicate/stale/
mutated/foreign resolution,cancellation,one-tick failure,single tail and
advanced+debt closure. Seven real-owner/executor/adapter mocked panel cases
cover normal,pending,synchronous callback,bad status,timeout,image readiness
and cancel;five host/native/offscreen guards and report decoding pass.
First-refusal GPU rollback remains qualified by s248;its s249 scheduling is
covered by the CPU queue. The new end-to-end native recovery case deliberately
exercises second refusal,partial continuation and a single tail.

Initial retained-run testing found that the first-stage handoff audit still
referenced the s248 dummy input while the initializers copied retained roots.
The audit rejected batch2. Both copies and all three handoff bindings now use
the same owned prior roots. The rejected status is preserved in
`diagnostics/2026-10-23/s249/before_handoff_repair.json`.

## Actual CSP observation

Fresh-session user report and automatic log agree:observed,2 batches,4 inputs,
310 accepted draws,155 resources /169,978,048 bytes. Exactly2 status readbacks
and2 CPU disposals are recorded,with20 file checks. Total advanced time is
0.06168365478515625s and retained debt is0. Both batches accept their full
two-input prefix;this actual run does not exercise refusal recovery.

Initial water inventory stays805.7721558mm3 while final inventory continues
805.4676514→805.1440430mm3. Cumulative evaporation0.0223814→0.0447628mm3
and runoff0.2820610→0.5832616mm3 continue across batches. GPU ledger residual/
bound ratios0.004115/0.005042 are below1. Both audits pass. This qualifies
actual retained state/resource reuse for the controlled frozen-input chain.

| Receipt | Request frame | Callback frame | Wall latency |
| --- | ---: | ---: | ---: |
| Batch1 | 3741 | 3751 | 175.4393ms |
| Batch2 | 3771 | 3781 | 158.6305ms |

There are20 engine frames from receipt1 to request2 and10 more to receipt2.
This matches the current submission pacing:155 passes at at most8 accepted
draws per callback need at least20 callbacks,followed by the observed10-frame
readback delay. Exact wall time for the full second batch is not logged,so
the frame gaps are not a GPU timer or an FPS measurement. This is a clear
remaining cadence constraint;it is not a sustainable real-time throughput
pass despite zero debt for the four declared frozen inputs.

**Next prioritize bounded dispatch pacing before continuous intake.** Measure
whether a higher call ceiling can use the existing1ms soft CPU budget safely,
instead of spending20 frames submitting a pair. Keep the CPU budget,receipt
dependency and retained-input invariants. Reducing readback cadence,static
dispatch and memory remain open,as do live source/head supply and optics.

Evidence:`diagnostics/2026-10-23/s249/actual_capture.log` and
`actual_observation.json`. Pending source/delivery are archived under
`pending_sources/` and `pending_delivery.json`. No Git commit/push.

## Runtime diagnostic and cost

Default-OFF main panel:RainFX → Weather inputs and physical units (P0) →
**Enable s249 retained GPU batches** → **Run s249 retained GPU batches once**.
Use a fresh unpaused session with other diagnostics OFF. The panel clones
one captured context into four explicitly frozen private inputs. Native
tests use changed inputs;four actual changing engine captures are not claimed.

Normal expectation:observed,batches2,inputs4/4,draws310,resources155,debt0,
two readbacks/disposals. Logs are automatic and decoded by
`docs/tools/collect_s249_observation.py`. The actual CSP result is recorded above.
Refusal can require more batches and remains a valid diagnostic outcome if
all declared inputs eventually complete;send the displayed count or fault.

Memory remains169,978,048 bytes (162.1037MiB) at4096 slots under the192MiB
private cap. The source s248 executor and all prior stages are unchanged.
Per-batch reuse waits for validated completion;it does not skip ownership
validation. All155 passes still execute per batch,including copied static
inputs and an unused lane on a single-input tail. No GPU/FPS or sustained
throughput improvement is claimed. Managed allocations remain until app/session
end;this is not a general resource-retirement implementation.

Next improve bounded submission pacing,then connect bounded actual input
intake and optimize memory/static dispatch lifetime. Live source/head supply,
continuous engine-time coverage and visible optics adoption remain open.
Current visible physics is s87. No Git commit/push is performed.
