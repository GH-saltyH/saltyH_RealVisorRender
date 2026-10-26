# s251 — packet and typed-uniform preparation reuse (2026-10-23)

## Why

s250 qualifies32-call warmed dispatch below1ms in its samples,but whole owner
pumps peak at2.0326ms. Binding/submit preparation is outside that pre-call
deadline. s251 reduces this work and separates bind/submit time for observation.
It does not change physical shaders,draw order,receipt semantics or the queue.

## Changes

The candidate binder copies the fixed155-pass payload once and refreshes
frame/audit rows,tokens,dt,boundary and normalized attempt values. Cached row
keys and stage mappings replace two full85-pass packet constructions,their
per-bind index maps and an additional155-pass copy. The existing context
guard/bind still checks files,shape,calibration and finite rows;validator state
is refreshed for every input. The original binder remains as reference mode.

The versioned executor validates/copies caller input as before. Once an owned
slot is idle after validated completion,it reuses typed uniform objects whose
canonical values are unchanged. Equality distinguishes-0 from+0,including
vector components,so exact header audit words remain correct. A new job gets
one receipt vector shared by its passes instead of155 identical conversions.
Reference mode forces original per-pass conversion. Slot-local last values
are bounded to one submission;no history/resource pool grows per batch.

No values are changed while a prior job is in flight. Busy submits remain
refused. A conversion/submission failure still quarantines the private slot.
Caller vectors cannot mutate saved canonical or converted data. The original
executor and all sealed prior stages remain unchanged.

## Verification

- All155 resource/pass descriptions and shader bodies match s249.
- 30 complete packet comparisons match every FP32 word across changed context,
  dt,pose/force/material,full/partial/retry and single-tail conditions.
- Typed conversion controls cover unchanged values,scalar/vector signed zero,
  boolean changes,forced reference conversion,busy slots and caller mutation.
- Nine inherited pacing/command controls match original and reused accepted
  streams including values,shader identities and texture/target IDs. Pending,
  retry,slow and oversized SDK cases retain their ordering/budget behavior.
- Seven real-owner/executor/adapter mocked panel cases and five host guards
  pass;normal/pending/synchronous logs decode with the actual parser.

In the frozen mock fixture,backend make calls are918/39/918/33 across the
four comparison batches. These are deterministic operation counts,not runtime
CPU savings. Physical native s249 evidence is inherited because all shader
bodies and submitted words match;no redundant native solve is claimed.

## Actual comparison observed

All four batches use32-call/1ms dispatch pacing. Preparation modes are original,
reused,original,reused. Batch1 is cold;compare reused batches2/4 to warm
original batch3. The panel records `bindMS`,`submitMS`,`makeCalls` alongside
existing total owner/dispatch peaks,limits,frames and callback latency.
Time measurements are caller elapsed time,not GPU timestamps. Whole owner
work is not hard bounded to1ms. The same-session frozen-input chain evolves
inventory,so it is not an identical-state FPS benchmark.

Fresh unpaused session,other diagnostics OFF. Main RainFX → Weather inputs
and physical units (P0): **Enable s251 preparation reuse comparison** →
**Run s251 preparation reuse comparison once**.

Expected:observed,4 batches,8 inputs,620 draws,155 canvases,debt0,4 readbacks/
disposals. Approximately162.1MiB is retained until session ends. No weather,
driving or FPS comparison is needed. Logs are automatic and collected with
`docs/tools/collect_s251_observation.py`.

Actual CSP run completed4 batches/8 inputs,620 draws,155 resources and4
readbacks/disposals. Advanced0.152496337890625s;retained debt0. All private
receipt/header/water checks pass through the existing decoder. GPU storage
remains169978048 bytes (162.104MiB). This is eight copies of one frozen engine
snapshot,not eight continuously captured inputs.

| Caller elapsed metric | Warm original batch3 | Reused batch2 | Reused batch4 |
| --- | ---: | ---: | ---: |
| Bind preparation (ms) | 1.5268 | 0.5840 | 0.5602 |
| Submit preparation (ms) | 0.9871 | 0.5317 | 0.3171 |
| Bind + submit (ms) | 2.5139 | 1.1157 | 0.8773 |
| Typed conversion calls | 918 | 39 | 33 |
| Maximum whole pump (ms) | 3.2056 | 1.7149 | 1.2894 |
| Maximum dispatch (ms) | 0.8042 | 0.6548 | 0.4427 |

Qualify preparation reuse for the private warmed path: both reused observations
reduce measured preparation and preserve commands/resources/receipt checks.
There is only one warm original and two reused samples;these are not long-run
averages or an FPS improvement claim. Bind+submit sums sequential scoped work;
do not subtract independent maxima to infer unmeasured costs. All warm batches
still require5 submission frames;there is no cadence gain from this change.

Whole pump still exceeds1ms. This does not fail the unchanged pre-call dispatch
budget:that soft budget never covered preparation or preempted SDK calls.
Cold batch1 had147 pending attempts and a6.1834ms maximum SDK wrapper call,
with a6.5248ms maximum dispatch pump;this remains a startup/tail risk rather
than a measured GPU duration or proven compilation attribution.

All four readbacks arrive10 engine frames after request (146.1205–157.6693ms).
Next priority is safe GPU continuation/confirmation amortization and bounded
continuous intake,then memory/static dispatch and live source/head/optics
adoption. Repeating small preparation comparisons is not the current gate.
Visible physics is s87. No Git commit/push.

Evidence:`diagnostics/2026-10-23/s251/actual_capture.log`,
`actual_observation.json` and `delivery.json`. Pending sources/delivery are
archived separately before updating this actual-result record.
