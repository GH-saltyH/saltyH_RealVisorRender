# s260 — GPU-resident continuous film transport (2026-10-23)

## Implemented path

The main app now has one default-OFF integrated live transport run. It uses real
successive engine observations,not repeated frozen contexts or an expanding
eight-input window. The existing controlled20µm film and unchanged transport
bodies run in one ordered GPU workspace. Head birth/merge/source and optical
publication are not connected;the visible s87 physics/rendering remains in use.

`s260_owner.lua` composes the observed s239 sampler/composer,s259 time FIFO and
physical unit normalization,s258 selected packet construction and the retained
s243 single-input transport. No new standalone probe app is installed.

The normal next submission does **not** wait for the preceding CPU callback.
Three small shader changes check the preceding owned GPU receipt,rearm its
checkpoint only on valid continuation,and propagate a blocked result on refusal.
Accepted film/checkpoint/history roots match the independent original transport.
Invalid predecessor identity cannot authorize motion. The first refusal stops
new intake;already submitted suffixes are blocked on GPU and later audited.
There is no automatic dyadic retry/recovery in this first continuous path.

## Resource and completion ownership

- One statically verified pooled workspace. Final film/checkpoint/history and
  all persistent constants have exclusive retained storage. A cache flag alone
  does not protect data from later pooled writes:constants are explicitly pinned.
- Each finished input copies its16-word receipt to one immutable16×1 R32F audit
  canvas. The fixed32-slot ring adds2048 descriptor bytes,not32 full film buffers.
  A ring slot's parameters and status copy remain owned until its callback is
  validated. The latest predecessor status also remains pinned until its
  dependent submission has been accepted in the same ordered command stream.
- Pool/resource rewriting follows SDK submission order. An asynchronous read
  refers only to the dedicated audit copy,not to a working buffer that the next
  transport overwrites. CPU audit is not used as a general GPU fence or permission
  to expose these resources to the public renderer. The actual short run below
  confirms this scoped private reuse;long-run stability remains unqualified.
- Persistent file/topology/zero passes are skipped after warmup only because
  their physical storage is retained. Pose-dependent metric/force/audits still
  update. The file wrapper consequently retains a fixed set of initial bindings.
- Shader warmup and its CPU audit precede real live capture. The first live
  context explicitly reinitializes this private test stock;warmup time is not
  added to the live water/time ledger. Geometry/template/allocator startup is
  timed separately as `initializationMS`;it is outside the warm pump limit and
  does not include all module loading or asynchronous asset wait.

| Configured head slots | Workspace + audit descriptor bytes | MiB |
| --- | ---: | ---: |
| 2048 | 74501536 | 71.0502 |
| 4096 | 74534304 | 71.0815 |

There are67 workspace allocations and32 small audit canvases(99 total). These
are descriptor reservations,excluding driver alignment,staging,Lua objects and
the existing app. Head textures contain zeros;the small difference above is not
a2048/4096-drop simulation performance result. The earlier unpinned plan was
about63MiB;retaining cached constants correctly costs about8MiB more. It avoids
a second full workspace and stays below the explicit96MiB private cap.

## Time,pressure and bounded work

Two bounded cursors distinguish **reserved/submitted** input from **CPU-audited**
physical progress. Both own the same source frames. Projection creates normalized
headers/tokens for upcoming GPU work;its local cursor is never published as
physical advancement. Only validated,ordered CPU receipts settle the audited
FIFO. Out-of-order callbacks are held in the finite ring until the prefix arrives.
Source raw time equals advanced+unconfirmed debt+quantization remainder;one
already sampled but unadmitted observation is retained separately on overload.

Capture occurs once per engine callback. Whole warm owner work uses a3ms soft
deadline and at most256 SDK draw attempts. Up to four bounded work iterations
can dispatch multiple31.25ms time slices under the same total budget. This is
needed at30FPS,where one33.3ms frame spans two slices. It does not change dt,
drop elapsed time or force one simulation step per render frame.

Defaults remain16 source contexts. The continuous path allows500ms of **unconfirmed
audited time** because a ten-frame callback at30FPS alone is about333ms. Separately,
unsubmitted source age is bounded to250ms. This separates slow CPU acknowledgement
from actual dispatch backlog;neither250ms nor500ms is a visible-quality target.
The32-copy ring covers two slices per frame at30FPS with ten-frame acknowledgements.
Exhausted capacity/deadline,invalid input,refusal or timeout stops intake and
retains stock/time for explicit reset/recovery. No ring eviction or assumed
completion is used to make the test drain.

`maxSubmitFrameLag` measures source-frame age when SDK submission finishes;it
is not a GPU timestamp or measured visible state age. `maxSourceAge` is waiting
dispatch age. `maxDebt` still includes intervals awaiting CPU audit. Rendering
and head/trail synchronization need their own later integration checks.

## Verification

- **531 native WARP draws:**two independent physical reference inputs,actual-grid
  pooled recurrence with cached passes skipped,accepted-root equality,real
  decision refusal and blocked suffix,film/checkpoint/history preservation,and
  corrupted predecessor identity refusal. Three changed bodies compile strictly
  without warnings;maximum texture count15. Native per-draw readbacks do not
  reproduce continuous CSP execution order,which remains the actual gate.
- **One targeted native draw:**the production64-byte snapshot shader preserves
  all16 float words,including signed zero.
- **16 integrated owner cases:**real engine/bootstrap/capture/composer/FIFO and
  physical header projection with controlled SDK scheduling. Normal30/60FPS,
  long frame,pause,display-only gain,async/pending/sync/reordered callbacks,
  ring pressure,refusal,invalid audit,timeout,SDK exception,reset and cancellation
  are covered. A real SDK adapter wrapper checks readback disposal as well.
  These fixtures demonstrate continuation before delayed callbacks;their fake
  clock times are not performance measurements.
- **Six main-panel/adapter cases,five lazy host guards and six collector refusal
  checks** pass. Disabled controls allocate nothing. Linked game/workspace source
  hashes agree. Actual CSP evaluation is recorded below.

An initial status-wrapper early return triggered FXC X4000;the production wrapper
now initializes its result and selects the blocked result afterward. Strict
compilation passes. The initial source and the superseded unpinned native report
are retained under `diagnostics/2026-10-23/s260/`.

## Actual CSP result — controlled stop (2026-10-23)

The user ran the installed path in a fresh unpaused game session. Automatic
evidence is retained in `diagnostics/2026-10-23/s260/actual_failure.log`,
`actual_failure.json` and `actual_evaluation.json`.

| Observation | Actual result |
| --- | ---: |
| Terminal state | stopped;GPU transport refused |
| Submitted / audited / pending | 34 / 34 / 0(includes one warmup) |
| Live inputs / completed slices | 33 / 22 |
| Raw input / advanced / retained debt | 0.6579192 / 0.4579182 / 0.2000008 s |
| Quantization remainder | 0.2701 µs |
| Continued before preceding CPU audit | 32 |
| Peak pending / ring capacity | 13 / 32 |
| Resources / descriptor reservation | 99 / 71.0815 MiB |
| Readbacks / disposed / duplicate callbacks | 34 / 34 / 0 |
| Waiting submission age / source frame lag | 30.8754 ms / 2 frames |
| Audit median / p95 / maximum | 176.3897 / 210.6339 / 220.3958 ms(10 frames) |
| Synchronous initialization | 93.9495 ms |
| Maximum live owner pump | 5.0305 ms |

**The normal CPU callback barrier is separated successfully in actual CSP.**
The next private GPU interval can be submitted while prior audits are pending.
All reads were audited and disposed,resource bounds held,and raw source time
equals advanced+debt+remainder. No rejected raw time was discarded. This is one
short scoped execution/reuse result,not a general GPU completion fence.

**The planned three-second continuous transport gate failed.** Only22 live
slices advanced. Based on the prefix/blocking contract,the first refused live
slice is inferred to be23 and the ten remaining live receipts are blocked
suffixes;individual receipt traces were not logged. The final260002 marker
reports this blocking. It does not identify the first failed internal check.
Existing transport decisions include packet/status,loss,inventory and stability
checks,so the result must not be labeled a confirmed CFL failure.

The audit latency is no longer a normal step barrier,but remains ten frames.
Submission source age is not measured GPU completion age or visible latency.
Initialization is a real synchronous preparation/allocation cost in one callback;
the live pump peak also exceeds the3ms soft target. These maxima are not full-app
p95/p99 measurements. SDK/dispatch maxima include shader warmup. No GPU timing,
FPS benefit,2048/4096-drop throughput or renderer adoption is established.

Retain the resident/deferred-audit connection as the execution base. Next inspect
the existing refusal predicates and implement bounded stable/cheaper transport
with explicit retained elapsed time;stage/cache initialization. Preserve water,
time and ownership checks. Do not request another small-read/two-arena probe or
expand windows to conceal this refusal. Head/source/optics coupling follows a
successful continuous transport gate.

## Executed gate procedure (retained for reproducibility)

Fresh unpaused game/replay,other diagnostics OFF. In the main app:

**RainFX → Weather inputs and physical units (P0) → Enable s260 continuous film
transport → Start s260 continuous film transport.**

Wait through shader warmup and three seconds of actual input capture,then audit
drain. Expected terminal state is **observed**,99 resources,submitted=audited,
pending0 and debt0;counts/draws depend on actual dt and frame rate. Automatic
output is at most eight lines. If it stops or faults,retain that outcome and its
reason. No weather matrix,FPS comparison,film screenshot or extra button is needed.

Judge that one run on water/time closure,continued submission before audit,
dispatch age/backlog,resource bounds and CPU tails. `initializationMS` identifies
cold allocator/template work separately. Do not claim overall FPS improvement
or general GPU completion from a successful status result.

If this path remains too costly or frequently refuses real intervals,the next
decision is a cheaper stable film/update policy with explicit elapsed-time and
visual checks. Do not keep enlarging full workspaces/windows or multiplying
precision/latency probes. A successful gate enables subsequent head/source and
optical coupling before the actual2048/4096-slot product performance comparison.
