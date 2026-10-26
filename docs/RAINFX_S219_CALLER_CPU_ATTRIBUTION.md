# s219 — Calling-thread CPU and bounded completion tails

2026-10-21. Parent: `RAINFX_S218_EVENT_PHYSICAL_PREFIX.md`.

State: **ACTIVE, attribution/parity gates passed; full-owner event gate held**.

## Decision and observations

All eight natural processes preserve the original physical prefix. The separate
control batch adds one healthy prefix, classifies the expected retained GPU bit
fault and stops before its third process starts. Both CPU-boundary and bounded
trace audits pass, with no native retry or acceptance change.

| Condition, two runs each | Mean physical wall | Mean process CPU | Mean calling-thread CPU | Mean signed residual CPU |
| --- | ---: | ---: | ---: | ---: |
| Sleep, plain | 4.1676s | 1.3594s | 0.4297s | 0.9297s |
| Event, plain | 1.0982s | 1.5156s | 0.5234s | 0.9922s |
| Sleep, traced | 4.2389s | 1.7344s | 0.6484s | 1.0859s |
| Event, traced | 1.0992s | 1.6172s | 0.6016s | 1.0156s |

Event wall is lower in both plain/traced comparisons. CPU selection is
inconsistent: event/sleep process CPU is1.115× plain and0.932× traced;
calling-thread CPU is1.218× plain and0.928× traced. The event-only2.77× CPU
difference seen in s218 is not reproduced as a consistent policy difference.
This does not erase that prior observation or qualify the event default.

The strongest new observation is a change with execution order:

| Fixed sequence | Mean process CPU | Mean calling-thread CPU | Mean signed residual CPU | Mean whole-process CPU |
| --- | ---: | ---: | ---: | ---: |
| First four, one of each condition | 2.5430s | 0.5859s | 1.9570s | 17.2617s |
| Last four, one of each condition | 0.5703s | 0.5156s | 0.0547s | 11.0391s |

Both halves have the same set of four conditions, in mirrored order. Much of
the large process-CPU change is outside the measured calling thread and occurs
under both sleep and event, with or without recording. All boundary captures
take6.3–13.2µs; process-before/after counters do not advance within these
captures. These facts narrow attribution, but they do not identify a worker,
prove a driver cause or make the signed residual exact. The split into halves
is a **post-observation description**, not a predeclared statistical test.

Trace/plain calling-thread ratios are1.509× for sleep and1.149× for event.
Wall ratios are1.017× and1.001×. Recording overhead therefore cannot be declared
zero, and these small samples cannot separate its direct CPU cost from
time/order-dependent state. The CPU result is insufficient for default or
full-owner selection. Keep the existing owner policy and characterize the
recorder independently before changing timing policy.

No100ms slice timeout occurs in this bounded batch; the19 slice timeouts in
the first s218 event process are not reproduced. Traced maximum retained waits
are45.54/35.78ms for sleep and12.95/14.12ms for event. There is no proof that
longer waits cannot recur. GPU-reported interval means also differ0.759/0.741s
for sleep plain/trace and0.475/0.475s for event plain/trace; these are not busy
counters or a controlled isolation of GPU work.

The expected fault completes193 existing events, retains192 physical wait/
submission records in aggregate (eight per kind retained), and saves the same
frame7/phase1875 capture classification. Its partial physical window reports
0.7093s wall,0.3281s process CPU and0.2813s calling-thread CPU. Previous seven
publications and accepted debt remain protected, and no failed-frame bank or
following process is published/started.

## Fixed CPU boundaries

All four healthy consumers use exactly the same CPU observer. At each of two
boundaries it reads process CPU, calling-thread CPU, then process CPU again.
There are four GetProcessTimes calls and two GetThreadTimes calls per physical
window, outside the per-query loop. Both process-before and process-after
snapshots, thread ID, thread kernel/user values and monotonic capture start/end
timestamps are retained. The signed process-minus-calling-thread delta remains
signed; no negative result is silently clamped or reassigned.

The process-after pair remains the reported process CPU interval, matching the
s218 convention. The additional process-before samples expose inner/outer
process windows surrounding the thread reads. They quantify endpoint movement,
not a guaranteed accounting precision bound. The physical wall interval starts
after the beginning capture and ends before the ending capture. CPU boundaries
therefore include a small measurement envelope around that wall interval.

[`GetThreadTimes`](https://learn.microsoft.com/en-us/windows/win32/api/processthreadsapi/nf-processthreadsapi-getthreadtimes)
returns kernel and user CPU time for the specified thread in100ns units. Here it
uses the current-thread pseudo-handle; no thread enumeration or worker handle
collection occurs. The two IDs must match. Process times cover all process
threads, including work charged to driver/runtime threads. Counter units do not
imply fine accounting resolution; earlier observations have15.625ms steps.

The residual is an approximate separation from the calling thread, with endpoint
skew and accounting quantization. It does not identify worker threads, stacks,
driver functions, shader compilation or GPU activity. A large residual cannot
by itself establish a driver cause. CPU can exceed wall across active threads.
No process CPU is discarded because the calling thread is waiting.

## Bounded tails and observer comparison

Four separate native consumers are original sleep / event notification, each
with plain / tail-recording compilation. Plain consumers still include the
fixed CPU boundaries and pre-existing timing observer. Only the new tail recorder
is compiled out. Eight fresh processes use this fixed mirrored order:

`sleep_plain → event_plain → event_trace → sleep_trace → sleep_trace →
event_trace → event_plain → sleep_plain`.

This supplies two observations per condition. It checks the effect of the new
tail recorder, not the total overhead of all inherited validation/profiling.
It does not isolate system GPU/driver/scheduler state or support a precise
population effect estimate from only two observations.

Traced consumers retain the longest eight successful wait envelopes and longest
eight submission envelopes, sorted by duration with query ID as the tie-break.
Each fixed record stores query ID, monotonic start/end, query-poll count and
wait-slice timeout count. Sixteen retained rows occupy640 logical data bytes,
plus fixed counters and metadata. Counts and elapsed-nanosecond totals cover
all physical waits/submissions; no unbounded sample list or hot-loop file I/O
is added. A deterministic native control verifies capacity, tie ordering and
discarding shorter records using the same keeper.

Tracing begins after startup completion and observer reset, before CPU capture.
It excludes the first bootstrap query. The trace is written after execution,
including on the injected failure. Plain trace reports explicitly contain zero
rows/totals. The trace adds no GPU command, completion query or CPU-time sample
inside the hot loop. Its own clock reads and fixed-array updates are real work
and are included in the traced run cost.

Recorded waits end before inherited timestamp resolution and exclude the tail
keeper's subsequent sorting. The inherited completion-wait envelope also covers
that recording work. Submission records similarly end before their keeper.
Neither wait/submission wall nor GPU-reported intervals are CPU consumption;
nested timing envelopes must not be summed as independent work.

## Preserved physics, completion and refusal

All consumers use the frozen nine-interval physical prefix and qualified native
adapter/driver/input/shader receipts. Original bank and GPU snapshot prefixes,
stock conservation, time/debt, ownership, read-call/byte inventory and memory cap
are checked with the same prior pure oracles. Only variant names and diagnostic
filenames are adapted for those oracles. No numerical threshold is relaxed.

The sleep path retains explicit Flush and the original successful event query
predicate. The event path retains EnqueueSetEvent's declared implicit flush,
one notification handle, query identity, successful GetData/readiness/device
checks and finite deadline. A wake still cannot authorize Map or publication.
Notification lifetime and terminal private-process error behavior are unchanged.
The frozen s218 gate code is included directly. No solver, shader, weather,
diameter, physical/display-unit or source input changes occur.

Successful prefixes still publish9 /accept12 intervals, preserve future queue
[9,10,11], and complete246 existing query events. Peak logical default payload
remains66,582,496 bytes under the66,584,576-byte cap, with zero final default
payload. These logical counts do not bound driver/OS/process overhead.

A separate event_trace → GPU-bit-control → event_trace batch checks the modified
diagnostic failure path. The expected retained-pair bit fault must preserve prior
publications/stock/debt, emit the same classified capture, save a partial CPU/tail
report and stop the batch before its third process starts. Actual device removal
or30s completion-deadline failure is not induced.

## Delivery and remaining gates

Next implement a separate CPU-only replay control for the exact fixed tail
recorder. Then compare original sleep/event plain consumers with no settle
versus a fixed2s pause before the same physical prefix, in a bounded mirrored
sequence. Measure startup, pause and physical calling-thread/process CPU and
whole-process totals. The pause is an attribution control, not an optimization,
physics warmup or permission to hide/omit CPU cost. It can test whether work is
already pending before physical execution or appears during that execution;
it cannot identify a driver stack. Preserve all current results and stop on any
unexpected parity/refusal failure. Do not expand to a full-owner event run yet.

Tools: `build_s219_attribution.py` → `run_s219_attribution.py` →
`check_s219_attribution.py` → `finalize_s219.py`, Python `-B`. Earlier-stage entry
points are not run. All source derivations, executable/input receipts, raw CPU
boundaries, fixed trace rows, complete parity/refusal evidence and cost summaries
are stored under `docs/diagnostics/2026-10-21/s219/` with raw/gzip re-audit support.

The full-owner event comparison remains ineligible in this attribution stage.
Original s208 cause/release recurrence qualification, full/protected-stop/fault
cost and correctness gates, physical accuracy, total CPU/startup streaming,
common optics, long duration and actual CSP/live integration remain open.
There is no game FPS claim, game installation or user game test in this stage.

2,452 older source/configuration files retain SHA256 and mtime. Only the docs
index/roadmap change, with ten new topic/tool/source files. Main app, settings,
shaders, original owner default and Git HEAD remain unchanged. No commit/push.
