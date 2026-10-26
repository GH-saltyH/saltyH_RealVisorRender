# s282: transient input backpressure recovery

## Reported game milestone and limit

The user observed continuous `running`, a small population of drops, flowing film
and fast-moving large drops. Before the later admission stop the UI reported:

```
Submitted11624; audited11618; pending6; resources128 (+ optical snapshots)
Advanced363.062s; debt0.336s; max pump8.266ms
overloaded: rain_fixed_cadence_v2.lua:72: entry_capacity
```

11618 accepted full32Hz intervals imply363.0625s. This is useful actual evidence
that the earlier signed-momentum rejection repair and integrated optical path ran
for roughly six minutes. It is not a measured average GPU time, FPS comparison,
memory-leak qualification, or final product acceptance.

The old admission is atomic: a whole captured engine frame must fit the cadence's
16 slots and0.5s admitted-debt bound. Failure immediately ended the preview. With
reported debt below11 full steps, at most10 full steps were retained. Exceeding16
therefore needs at least7 new steps from the next frame. At32Hz this is consistent
with an approximately195–250ms input frame. The actual failed raw duration was not
exported by the old UI, so this duration is an inference, not a captured value.
The supplied numbers alone do not establish a sustained throughput deficit.

## Changed behavior and explicit bounds

The existing solver capacity remains16 steps/0.5s, and GPU storage remains128
owned canvases plus the existing optical targets. Physics, cadence frequency,
shader programs, per-step draw count and audit readbacks are unchanged.

The runtime now treats only `entry_capacity` and `time_capacity` as retryable:

1. Retire ordinary completed audits and retry retained input before new capture.
2. If a valid captured frame cannot fit, retain its immutable packet in a FIFO.
3. Continue capturing subsequent frames, preserving order, original time, poses,
   rates and nonlinear source snapshots. Do not skip capture, blend headers,
   discard elapsed time, or update the adapter's previous pose on a failed offer.
4. Keep dispatching already admitted work and retry when capacity returns.
5. Stop drains staged input before closing the cadence tail. Invalid material,
   identity/time changes and GPU refusals remain failures.

The CPU input FIFO has independent limits of16 engine frames and0.5s, whichever
is reached first. This is an additional bounded input buffer, not a claim that no
extra memory or latency exists. Normally it is empty. During a stall, admitted
debt plus staged time can approach1s; a final rejected atomic frame of at most
0.25s is retained on terminal overload. Such an overflow still stops capture and
publication rather than growing storage. Sustained insufficient throughput is
not solved or hidden by this buffer.

The first draft used0.25s staging. A maximum-size valid250ms frame filled it
before enough audit callbacks returned, leaving no room for subsequent capture.
A local boundary test caught that failure. The final0.5s bound allows one such
frame and a bounded following-input window; frame count remains16. No user game
run was requested for this refinement.

UI `debt` now includes admitted cadence debt, staged input and the final rejected
frame. Previously the display omitted the rejected input. Do not interpret a
larger new total as an A/B timing measurement. `Input staging` and `recovered
frames` show whether temporary pressure is being consumed. On terminal overload,
the existing CPU status is saved once to
`docs/diagnostics/runtime/rain_product_overload.txt`, outside the game log quota.

## Focused local comparison

`docs/tools/check_s282_backpressure.py` uses the real capture/typed-graph/executor
code with mocked engine/GPU services and controlled callback delay:

| Case | Before / after |
|---|---|
|0.333s outstanding debt followed by200ms frame|Old runtime reproduces `entry_capacity`; new runtime drains all captured time|
|250ms maximum-size frame|New path recovers; peak staged0.316667s/11 frames, then empty|
|Stop while200ms input is staged|All captured0.533333s drains before tail close; normal quantized-clock remainder retained|
|No live GPU completions|Stops with16 staged frames; storage and unprocessed time remain bounded|
|Normal30/60FPS, ordinary long frame, pause|Continue to drain with no staged input in these fixtures|

The comparison checks `captured raw time = admitted raw time + staged raw time +
rejected raw time`, unchanged16-slot cadence bounds and128 GPU allocations.
It does not use mock throughput as a claim about actual CSP performance. The
ordinary13-group product/raster regression also passes. No new shader is needed.

The new backpressure recovery itself is not yet observed in actual CSP. No new
six-minute run or standalone probe is requested at this stage. Ordinary next use
can show whether staging recovers; any new terminal overload should be assessed
from the automatic report before changing another capacity or adding research.
