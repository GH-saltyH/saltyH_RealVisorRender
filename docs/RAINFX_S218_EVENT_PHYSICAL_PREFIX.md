# s218 — Event-wakeup physical prefix and CPU windows

State: **ACTIVE, prefix correctness passed; CPU cost gate failed**.
2026-10-21. Parent: `RAINFX_S217_NATIVE_EVENT_WAKEUP.md`.

## Decision

The event path is connected to a separate native physical build. It preserves
the complete established nine-interval prefix, including GPU output bits,
water stocks, clock, queued debt, retained readers, memory cap and first-refusal
behavior. The game/production app and original owner wait are unchanged.

The small-copy benefit does not settle this physical workload. Four sequential
fresh processes use sleep/event/event/sleep order:

| Trial | Policy | Physical wall | Physical process CPU | Whole-process wall | Whole-process CPU |
| --- | --- | ---: | ---: | ---: | ---: |
| 00 | Original sleep | 5.5054s | 0.5469s | 18.500s | 13.1563s |
| 01 | Event | 7.3062s | 2.7813s | 19.954s | 17.7188s |
| 02 | Event | 2.5277s | 0.6406s | 14.984s | 12.6719s |
| 03 | Original sleep | 9.4558s | 0.6875s | 22.125s | 12.7813s |
| Mean | Original sleep | 7.4806s | 0.6172s | 20.313s | 12.9688s |
| Mean | Event | 4.9170s | 1.7109s | 17.469s | 15.1953s |

Mean physical wall falls34.27%, but physical process CPU rises177.22% (2.77×).
Whole-process CPU also rises17.17%. The event runs vary substantially, and the
first event run is slower than the preceding sleep run. There are only two
healthy timing observations per policy, not an isolated causal benchmark.
The cost criterion requires lower mean physical wall without higher mean
physical process CPU before a full-owner comparison. It fails here.

Keep the event path private and opt-in. **Do not proceed to an expensive full256
event trial yet.** First separate calling-thread CPU from all-process CPU and
capture bounded long-wait/submission evidence, with an instrumentation-effect
comparison. Preserve the high-CPU observation; do not retry until a favorable
sample replaces it. No default selection or FPS improvement is claimed.

## Connection and completion authority

The new consumers derive the physical source from s216 with the existing
nine-interval prefix switch enabled. Cache-owner changes are restricted to
the completion/submission path and bounded observations. No physics shader,
schedule, stock model, geometry input, tolerance or comparison oracle changes.

Both paths create exactly the existing number of event queries. The original
path retains `End(query)` and explicit `Flush`, then its original successful
GetData/readiness gate and requested1ms sleeps. The candidate retains End but
uses `EnqueueSetEvent` in place of explicit Flush. The implicit flush is a
declared submission change, not a pure wait substitution. See the
[API contract](https://learn.microsoft.com/en-us/windows/win32/api/dxgi1_2/nf-dxgi1_2-idxgidevice2-enqueuesetevent)
and the detailed s217 mechanism evidence.

One notification object is created for the event consumer and reused across all
its queries. A retained query reference binds each signal to the expected query
identity. A new fence, reset or enqueue cannot replace an unresolved one.
Notification wake alone never sets the owner's complete/read state. The path
requires successful `GetData` with returned TRUE and DONOTFLUSH, valid device
state and an unexpired deadline before returning to the existing read/observer
path. The shared pure query/device/deadline and Win32 status selectors are
extracted from s217 with only identifiers and the equivalent completion predicate
adapted; the new runner checks11 negative/success status cases in every process.

The candidate waits in100ms slices with a30s deadline measured from enqueue.
A slice timeout rechecks the device and deadline and continues waiting; it is
not completion, failure or permission to read. After a signal, any still-pending
query sleeps before retrying rather than repeatedly waiting on a signalled
manual-reset handle. Device errors, failed query/wait status, identity mismatch
or deadline expiry refuse the private process. API calls and OS scheduling can
exceed host decision budgets; the outer process timeout is180s.

An unresolved handle is retained through exception unwinding until process exit.
Normally completed handles close during owner teardown. This is a terminal
private-process failure contract, not reusable in-process recovery or a CSP
completion facility. In these six processes every submitted event completed,
each candidate process created/closed exactly one notification handle, and no
handle remained unresolved. Actual device removal or30s deadline failure was
not induced. Slice timeouts did occur and must not be confused with that limit.

## Frozen prefix preservation

Five successful prefix executions (the four cost trials plus the successful
first control-batch trial) independently preserve:

| Property | Evidence per successful process |
| --- | --- |
| Published / accepted intervals | 9 /12 |
| Unstarted future queue | [9,10,11], three dt of debt |
| Completion events | 246, no added event |
| Physical / total draws | 2,196 /2,260 |
| Retained-metric witness rows / copies | 21 /36 |
| Peak logical default payload / cap | 66,582,496 /66,584,576 bytes |
| Final logical default payload | 0 |
| Published bank, stock packet and GPU snapshot bits | Exact frozen reference |
| Owner/stock/phase/recovery/cache/witness traces | Exact frozen prefix |
| Water conservation and accepted/published/debt identity | Original checks pass |

The original prefix oracle is reused as a pure saved-data function. It verifies
the prior full reference prefixes, all published stocks, ownership inventory,
retained proof and protected administrative cutoff. The three accepted future
contexts stay unstarted/queued; this does not claim the full256 requested gate.
Canonical resource and read-call/byte inventories remain unchanged.

Bindings retain the qualified hardware adapter/LUID/driver, exact consumer
hash and all frozen input/shader hashes. No WARP, alternate-device, relaxed
tolerance or substitute-input fallback is used. Release-device mode is the same
as the original prefix. Three new consumers compile with warnings as errors.

## Expected first refusal

A separate bounded batch requests event → GPU-bit-control → event. The first
prefix passes. The control modifies the existing retained GPU-pair bit at the
established frame7/phase1875 witness and is independently classified
`retained_GPU_pair_changed`. It returns `retained metric witness mismatch`,
preserves preceding valid publications, stocks and debt, and does not publish
the failed frame. The batch stops immediately; the third process never starts.

The control completes193 query events and closes its one notification handle.
Its partial physical CPU window is saved before propagation:1.8106s wall,
0.4844s process CPU, with external exception cleanup marked excluded. The same
original fault-capture oracle and full captured bytes are used. This injected
failure does not reproduce or explain the natural s208 failure.

## Saved cost evidence and limits

| Mean physical timing envelope | Sleep | Event |
| --- | ---: | ---: |
| Completion wait | 6.8278s | 4.2832s |
| Explicit submit (End + Flush/enqueue) | 0.0270s | 0.0608s |
| Requested sleep envelope | 6.8206s | 0 |
| Win32 wait envelope | 0 | 4.2805s |
| Reported GPU interval sum | 2.5509s | 2.4931s |

Wait/submission envelopes are elapsed wall, not CPU consumed. Win32/sleep
envelopes nest inside completion wait; they must not be added as independent
work. The mean wall reduction is observed chiefly in completion waits. The
aggregate GPU intervals are not busy counters or an isolation of driver work.
Their similar means conceal large per-process differences:

| Trial | Reported GPU interval sum | Global100ms wait-slice timeouts | Physical process user CPU |
| --- | ---: | ---: | ---: |
| 00 sleep | 1.5391s | 0 | 0.4219s |
| 01 event | 3.6306s | 19 | 2.3906s |
| 02 event | 1.3556s | 0 | 0.4531s |
| 03 sleep | 3.5626s | 0 | 0.3750s |

The first event process has19 slice timeouts, but all246 signals and successful
query completions are subsequently observed, with no post-signal pending query.
Its physical wait envelope is6.6354s; the second event process is1.9310s. Both
use exactly one query poll per completion. The observations do not attribute
the CPU excess to polling, Win32 waiting, shader execution or a driver thread.
The new process-wide user-CPU measurement does not identify which thread ran.

Two GetProcessTimes snapshots bracket runPhysical, exactly inheriting the s216
observer. They include all process threads and mandatory read/validation plus
successful physical teardown, and exclude startup/input hash/compile preparation
and later report writing. End counters remain within the separately collected
completed-process counters. Failed-run windows mark external cleanup excluded.
100ns units do not imply fine accounting precision; earlier measurements expose
coarse15.625ms steps. Timing/driver work on other threads can contribute.

Known conflicting native/game processes are checked before each sequential
trial, but the whole system/GPU scheduler/driver state is not isolated. The
existing instrumentation remains active. The logical payload cap excludes OS,
driver, query/event and process overhead. No total-memory or real-time guarantee
is inferred from it. No game installation or user game measurement occurred.

## Next implementation

Add separate fixed calling-thread and process CPU snapshots around the same
private prefix. Retain a fixed number of the longest wait/submission records
and per-wait slice-timeout counts, with no extra completion events. Compare
traced and untraced sleep/event consumers in a bounded counterbalanced sequence
to detect observer effects before interpreting the attribution. Preserve
submission semantics, all frozen byte/stock/time/debt/cap gates and first-refusal
termination. This is an investigation plan, not an identified driver cause.

Only a passing cost investigation permits full256 event/original-sleep,
protected26/29-stop and CPU/GPU/shared-selection fault gates. No owner default
or CSP/live adoption follows from a short prefix alone. Original s208 cause and
release recurrence qualification, total CPU/startup streaming, physical accuracy,
common optics and long duration remain open. No user game action is needed now.

## Delivery

`build_s218_prefix.py` → `run_s218_prefix.py` → `check_s218_prefix.py` →
`finalize_s218.py`, Python `-B`. Earlier-stage entry points were not executed.
Source derivations, receipts, native cost/CPU evidence, frozen prefix comparisons,
complete refusal capture and stopped batch are sealed under
`docs/diagnostics/2026-10-21/s218/`, with raw/gzip saved-data re-audit support.

2,443 older source/configuration files retain SHA256 and mtime. Only docs
index/roadmap change, with nine new topic/tool/source files. Main app, settings,
shaders, original owner default and Git HEAD are unchanged. No commit or push.
