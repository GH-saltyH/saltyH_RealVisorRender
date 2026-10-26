# s237 — bounded elapsed-time queue and split-frame continuation (2026-10-22)

## Delivered

`rain_time_queue.lua` owns immutable inputs for a contiguous prefix of engine
frames. `rain_preview_stream.lua` connects its FIFO to the unchanged private
interval owner. Versioned `rain_interval_admission_v3.lua` accepts successive
slices of one source frame without pretending that each slice is another
engine frame. s236 scale/calibration guards remain unchanged.

Local time/protocol tests and a full-grid software-D3D integration pass.
**This stage is not connected to game input capture or installed.** Actual s236
two-input execution remains preserved and is the latest actual qualification.
No new game experiment is needed now; visible water stays on s87.

## Time and input ownership

- Accept the first source frame as an anchor, then require contiguous frames
  in the same explicit epoch. Missing frames, rewind or a new epoch require
  an explicit new stream/reset. A latest sample is never claimed to contain
  forces/weather from missing frames.
- Copy each accepted positive-duration source once into the bounded FIFO.
  Duplicate observations do not add time. New zero-dt paused observations and
  repeated zero-dt callbacks at the same frame do not create GPU work.
- Quantize the whole source frame exactly once with the carried signed
  remainder: `ticks=round((rawDt+remainder)*1048576)`. The remainder stays within
  half a tick. Positive sub-tick frames can carry time without a GPU interval.
  A paused observation leaves that remainder unchanged.
- Keep a queued frame until all of its time slices finish. A pending compile
  or readback retries the same immutable slice. Only the owner's validated
  private quarter receipt advances the queue; duplicate/mutated receipts refuse.
- The accounting invariant is
  `accepted raw seconds = advanced + retained represented debt + signed remainder`.
  The queue and physical owner's represented progress must match after every
  accepted quarter. Raw-frame remainder belongs to the queue; the physical
  admission receives exact slice ticks, so it never quantizes that frame again.

The queue owns accepted input time, not wall-clock time. Future engine intake
must sample every required frame and mark replay/reset epochs coherently.
No current implementation claims to reconstruct missing engine states.

## Long frames and bounds

Accepted source dt is0–250ms. Split represented time into slices of at most
32768 ticks (31.25ms), safely below the unchanged transport's50ms interval bound.
The last slice uses the exact remaining ticks. Source frame/key/forcing remain
the same; offset, serial and private interval token advance. Zero-order holding
the captured forcing across a long frame is an explicit approximation; no
intermediate pose or force measurement is invented.

Default bounds include the active head:16 retained source contexts and262144
unadvanced ticks (250ms represented debt). The context remains in the queue
while its slice is active. Time admission does not create another GPU pool.
The private owner still has a1024-slice diagnostic lifetime limit; reaching it
faults with accepted debt retained. It is not an unlimited production scheduler.

At capacity/time overflow or a continuity violation, `offer` refuses the new
input without consuming its time. The stream stops intake/work, records the
refused frame/key/raw-dt metadata and retains the previously accepted prefix
and its debt. The rejected full input remains the caller's responsibility.
The status does not claim coverage beyond that prefix or recovery without reset.
Cancellation/failure also preserves accepted debt and uncertain GPU resources.
Closing intake normally permits draining existing records; it does not cancel
them. A terminal stream does not restart or silently drop its debt.

There are no new rain/head/birth sources in this controlled-film path. Future
incident/head integration must stage each source-frame supply exactly once,
independently of the number of time slices.

## Local verification

CPU tests cover FIFO immutability/retry, long-frame splitting, pause and repeated
paused callbacks, duplicates, sub-tick accumulation, partial-quarter debt,
close/drain, eight intake refusals and five scheduler cases including pending,
cancel, overflow and owner failure. One-second30/60/144Hz input streams all
finish at1048576 ticks with raw/remainder closure. This is a **clock test**,
not evidence of frame-rate-independent physical motion or game performance.

Ten split-admission refusals cover duplicate/changed source, epoch, skipped
offset, wrong global clock/frame/serial, unfinished prior frame, scale setting
and diameter calibration. The valid two-slice case keeps the exact same source
frame/hash and does not mutate its original snapshot.

The real queue/stream/interval owner and unchanged transport then execute one
declared60ms source on the actual1024×256 grid using WARP:

| Slice | Source frame | Offset ticks | Ticks | Represented seconds |
|---:|---:|---:|---:|---:|
| 1 | 1507 | 0 | 32768 | 0.031250000000 |
| 2 | 1507 | 32768 | 30147 | 0.028750419617 |

Eight validated quarters use518 draw submissions/178 cache hits,87 fixed
canvases/91.193MiB, seven reuses and eight status reads/CPU releases. Twenty
retained copies remain exact; full-array inventory and every component of the
cumulative ledger satisfy the existing128-FP32-epsilon/1e−9 budget. Water is
805.772156→805.157715mm³, evaporation0.043541mm³ and runoff0.570901mm³. There
is no water/ledger reset at the split boundary or extra GPU allocation.

Represented time is62915 ticks (0.0600004196166992s), retained debt0 and signed
remainder−0.419616699µs. Together they preserve the declared0.06s raw duration.
The60ms duration is a **local synthetic long frame** using a previously observed
physical context; it was not captured from a new actual engine long frame.
The current s151/s152 capture API still rejects long dt/pause and needs a
separate coherent continuous-intake implementation.

The first negative retry test changed a slice length to1, which did not mutate
an already-one-tick case. It now changes the serial unconditionally. Repeated
pause handling and the terminal intake flag were tightened before final tests.
No physical coefficient, shader or acceptance tolerance was changed.

WARP draws roundtrip through CPU arrays; these results do not independently
qualify actual CSP persistent resource lifetime, continuous engine coverage,
optics, memory stability or target cost. No FPS improvement is claimed.

## Next integration and throughput constraint

The s236 proof path deliberately attempts at most one SDK draw per callback;
one validated quarter needs many callbacks. With every-frame intake and only16
retained contexts, its proof budget cannot drain real-time input before this
queue fills. A bigger unbounded queue would hide this throughput problem.

Next separate a cheap coherent every-frame intake from one-shot asset checks,
own pause/replay/reset epochs, and establish a bounded execution budget/warm-up
policy that can drain the queue. Measure target callback/GPU cost before turning
on continuous live solving. Then integrate conserved incident/head sources,
renderer read leases and common optics. Earlier pooling/graph optimizations
remain candidates; callback count alone is not a hardware timing measurement.

Evidence: `diagnostics/2026-10-22/s237/time_checks.json`, `admission_checks.json`,
`gpu_checks.json`, `split_results.npz` and `delivery.json`. No Git commit/push.
