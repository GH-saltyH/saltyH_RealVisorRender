# s220 — Recorder CPU control and startup/settle attribution

2026-10-21. Parent: `RAINFX_S219_CALLER_CPU_ATTRIBUTION.md`.

State: **ACTIVE, CPU/control and phase/parity gates passed; default unchanged**.

## Decision and observations

The independent recorder benchmark and all eight qualified physical conditions
pass. A separate successful control prefix and expected GPU-bit refusal preserve
prior output/stock/time/debt and stop the next process. All phase CPU sums
reconcile exactly to completed-process CPU, including failure cleanup.

| CPU-only synthetic input | Added caller/process CPU per245 wait/submission pairs |
| --- | ---: |
| Mixed durations | 0.01526ms |
| Increasing durations | 0.02337ms |

These are pooled differences over32,768 recorded and32,768 baseline synthetic
prefixes per pattern, not per-call precision claims. The operation cost is far
below the0.078–0.219s caller-CPU differences between traced/plain means in s219.
The inference is that the recorder's direct arithmetic/clock/keeper cost alone
does not explain those earlier gaps under this CPU-only control. It does not
exclude recording/scheduling interaction or provide a universal upper bound.

| Physical condition, two runs each | Physical wall | Physical process CPU | Caller CPU | Startup process CPU | Settle process CPU | Whole-process wall / CPU |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Sleep, no pause | 4.2480s | 0.5234s | 0.4219s | 10.8906s | 0 | 14.727s /11.4688s |
| Event, no pause | 1.0483s | 0.6406s | 0.5391s | 11.3203s | 0 | 11.821s /12.0000s |
| Sleep,2s pause | 4.4405s | 0.6953s | 0.5781s | 11.1250s | 0 | 17.110s /11.8750s |
| Event,2s pause | 1.1848s | 0.6484s | 0.5313s | 11.5625s | 0 | 14.039s /12.2734s |

All four paused natural processes report zero process/caller CPU advance in the
pause at this accounting resolution; mean pause wall is2.0052s for sleep and
2.0091s for event. The pause does not reduce measured physical or whole-process
CPU in these means. It adds wall and offers no measured cost improvement.
Do not add it to the app. The hypothesis that a substantial already-running
pre-physical CPU tail is simply moving into this idle window is not supported
in this batch. That does not rule out the different transient state seen in s219.

Process-minus-caller CPU means are0.1016s in both no-pause conditions and0.1172s
in both paused conditions. The earlier roughly2s non-caller signature is not
reproduced. No-pause event CPU is about22% higher than sleep, while paused event
CPU is lower than paused sleep. Two samples per condition and uncontrolled
system state do not settle a causal policy CPU difference. Startup dominates
whole-process CPU here, but this standalone validation workload is not a game
FPS or live app-cost measurement.

Keep the event path private and the existing owner policy. Next partition
calling-thread CPU around submission, wait and inherited timestamp resolution,
leaving an explicit other-work remainder. Compare plain/instrumented consumers
and a CPU-only counter-read control to detect the new observer's cost. Carry
forward complete phase/whole-process accounting and the new boot's strict
qualification; do not reintroduce an old-LUID receipt or remove identity checks.

## CPU-only recorder operation control

The new CPU executable includes the frozen `s219_trace.h` and `s219_cpu.h`
directly. It creates no D3D device, shader or GPU command. It compares the same
fixture loop with recording off/on using the exact fixed top-eight keeper and
real clock reads. Each repetition performs245 wait/submission pairs, resetting
the fixed recorder as for a new physical prefix. Fixed synthetic durations use
a mixed pattern and an increasing pattern that exercises frequent replacement.
They are operation-cost inputs, not simulated GPU latency or actual wait times.

Each timed block has8,192 repetitions, with one excluded warmup repetition.
Two fresh processes use opposite pattern order and ABBA/BAAB recording order:
16 blocks in total, four baseline and four recording blocks per pattern. The
fixture arithmetic checksum is independently checked for every block. Record
counts, bounded storage, native keeper controls and unchanged source hashes
are required. CPU boundaries collect both caller and all-process CPU; reporting
is outside the timed loop. Clock/checksum sink values prevent dead-code removal.

The baseline includes the common fixture, clock reads, recorder initialization
and checks. Additional recording cost is the difference between those blocks.
The actual target physical runs compile the new recorder off. The replay does
not bound driver scheduling, cache state or the interaction of recording with
a live GPU workload, and cannot be used as a universal latency/CPU upper bound.

## Contiguous phase accounting

Four physical consumers use original sleep or event submission, with no pause
or a fixed2s pre-physical pause. Their mirrored order contains one of each
condition in each half, two fresh processes per condition. The fixed pause adds
only a host sleep between CPU boundaries. It submits no GPU work and advances
no physical clock or state. The full source and command stream remain frozen.

Six fixed CPU boundaries define five contiguous intervals:

`entry → startup end → settle end → physical begin → physical end → teardown`.

At each boundary the unchanged s219 observer reads process-before, caller and
process-after values. There are12 process-CPU and6 caller-CPU reads per process,
outside the query loop. Startup, settle, small glue interval, physical window
and post-physical work all remain counted. The sum of their integer CPU values
must exactly equal entry-through-teardown CPU; their signed residuals and wall
nanoseconds also telescope exactly. No negative residual is clamped.

The original physical CPU report is preserved with its original two boundaries.
Those exact snapshots are also used in the phase report. Post-physical includes
normal teardown or exception cleanup. Phase report writing and later native
runtime exit occur after its final capture. Pre-entry CPU, measured phase CPU
and post-capture CPU reconcile exactly to the separately collected completed
native process CPU. No startup, pause, failure cleanup or report cost is silently
dropped from whole-process totals.

The pause is an attribution control, not a proposed product delay, optimization
or discarded warmup. Zero reported CPU during a pause does not prove zero work
below the coarse counter resolution. The snapshots identify the caller only;
the residual does not identify worker stacks, shader compilation or a driver
cause. The whole system/driver/GPU state remains uncontrolled.

## New boot identity and preserved first refusal

The initial batch stopped on its first admission, before producer draws or
physical execution: `physical adapter/driver mismatch`. Seven requested cases
remained unstarted. The initial receipt, executable, refusal, incomplete phase
report and stopped batch remain immutable. This admission is not a timing sample.

A new DXGI-only inventory found the same adapter index/vendor/device and driver
version; only LUID low changed68878→62310. The inventory creates no D3D device.
[LUID uniqueness is limited to a system lifetime](https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-dtyp/48cbee2a-0790-45f2-8269-931d7083b2c3).
The observation is consistent with a new boot context; it does not independently
prove when or why the identifier changed. The original device guard is retained.

A new executable includes the frozen s206 geometry verifier without changing
its checks. Both poses retain the old independently CPU-qualified expected
bytes and shader/input hashes. The CPU geometric oracle and its20 mutation
controls are rechecked. On the current identity, four debug/release rebuilds
match every expected byte, two injected GPU bits are refused, and stale LUID /
wrong-driver requests are independently refused. No solver interval or clock
is published by this reference verification.

Only after these saved checks pass is the current-context delivery published.
Fresh physical bindings name that delivery, consumer and per-pose receipts,
along with the unchanged proof data, shaders and physical executables. Initial
bindings and the previous s206 qualification remain intact. A separate fresh
eight-case continuation is used; the first refused admission is not rewritten
or presented as a successful run. Requalification precedes timing and can affect
system warm state, so cross-stage timing comparisons are not causal evidence.

## Receipt-path correction and publication order

The first two negative identity controls used request names that collided with
the native output `.bin` names. The verifier read each request before opening
its output, then produced the expected refusal, but this truncated the request
file and invalidated the saved provenance check. Those two initial controls
are not counted in the final qualified set. The initial failed candidate,
zero-length artifacts, execution records and helper source are retained.

The correction separates `.receipt.bin` inputs from output paths, rejects any
such alias before launch, and checks input hashes before/after execution. Only
the two affected negative controls run again with new labels. Four successful
rebuilds and two GPU-bit faults are preserved, not repeated. Candidate context
delivery is now audited before atomic publication. No native verifier, shader,
numerical acceptance condition or identity guard is relaxed.

Before any native observation, a separate validator correction allowed equal
adjacent boundary clock readings at clock resolution. Initial build/checker
snapshots and the correction record are retained. Native executables are
unchanged by this monotonic-clock audit correction.

## Frozen physical gates and delivery

Each successful physical prefix must preserve9 published /12 accepted intervals,
queue [9,10,11], the original246 completion events, output/stock/clock/debt/read
inventory and66,582,496-byte peak default payload under the66,584,576-byte cap.
The prior pure parity/refusal oracles are reused with diagnostic filenames and
variant labels adapted. No comparison tolerance, solver, weather input or
diameter/display unit changes occur. A separate event_pause / GPU-bit-control /
event_pause batch must stop at the expected fault before its third process.
Whole-process phase accounting is also required on that failure path.

Tools: `build_s220_controls.py` → `run_s220_controls.py`, followed after the
preserved admission stop by `inventory_s220_hardware.py` and
`continue_s220_context.py resume-receipt-path-fix`, then
`check_s220_controls.py` → `finalize_s220.py`, Python `-B`. Earlier-stage entry
points are not executed. Pure CPU oracles and frozen source includes are reused.

Evidence is in `docs/diagnostics/2026-10-21/s220/`, with raw/gzip read-only re-audit
support.2,462 older source/configuration files retain SHA256 and mtime. Only docs
index/roadmap change, with ten new topic/tool/source files. Main app, settings,
shaders, original owner wait and Git HEAD remain unchanged. No commit or push,
game installation or user game test. Full event adoption, original s208 cause /
release recurrence, physical accuracy, total CPU, common optics, long duration
and actual CSP/live integration remain open.
