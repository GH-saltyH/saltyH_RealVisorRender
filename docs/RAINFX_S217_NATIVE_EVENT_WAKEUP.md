# s217 — Private native event-wakeup comparison

State: **ACTIVE, immutable-copy gates passed; private owner prefix eligible**.
2026-10-21. Parent: `RAINFX_S216_FULL_PACED_GATES.md`.

## Decision

The isolated event-notification mechanism passes the predeclared small-experiment
wall/CPU gate. Proceed to a separate opt-in native nine-interval owner prefix.
The production app and original owner wait remain unchanged. The s216 full-run
pacing regression remains valid; these synthetic copies cannot select an owner
policy or predict game FPS.

Final revision2, two fresh sequential processes, mean whole-copy wall:

| Logical copy size | Requested1ms sleep | Counted/spaced pacing | Event wakeup |
| --- | ---: | ---: | ---: |
| 16KiB | 16.6512ms | 2.8223ms | 0.5886ms |
| 256KiB | 16.0001ms | 3.5511ms | 1.0633ms |
| 8MiB | 15.9292ms | 10.2726ms | 5.9361ms |

Each cell aggregates768 measured copies in12 blocks. Each final process uses all
six policy permutations and alternating forward/reverse size order; the second
process reverses the permutation order. There are6,912 timed copies and108
excluded validated warmups. These are block means, not independent process
replicates. Map, row-pitch-aware CPU copy, full-byte comparison, submission and
wait are all inside the measured wall/CPU window. Driver/device startup, input
hashing, controls, warmups and report I/O are outside it.

Event/sleep wall ratios in the two fresh processes are0.0438/0.0279 for16KiB,
0.0714/0.0617 for256KiB, and0.3920/0.3530 for8MiB. Every size improves in both.
Reported process CPU summed over all measured blocks is2.265625s for sleep,
2.375000s for pacing and1.796875s for event. Event minus sleep is-0.20345ms/copy,
passing the predeclared maximum extra aggregate0.05ms/copy. This gate permits
the next private experiment only. It is not an accuracy tolerance or a
requirement to accept a slower default.

## Different submission policy, original read authority

All policies use one event query and the original successful `GetData` predicate:
`S_OK` **and** returned `TRUE`, with `D3D11_ASYNC_GETDATA_DONOTFLUSH`. All also
check device status before Map. The inherited sleep and paced paths submit with
`End(query)` followed by one explicit `Flush`.

The new path uses `End(query)` followed by
[`IDXGIDevice2::EnqueueSetEvent`](https://learn.microsoft.com/en-us/windows/win32/api/dxgi1_2/nf-dxgi1_2-idxgidevice2-enqueuesetevent),
whose documented operation flushes pending rendering and signals after preceding
commands complete or the device is removed. It therefore replaces the explicit
Flush; it is not a second flush or a notification-only change. Its documented
scope does not establish swap-chain presentation completion or a CSP fence.

One manual-reset Win32 event is reused only after the preceding signal and query
completion have both been observed. The private process waits in100ms slices,
checks device status on wake/timeout, and retains a30s overall completion deadline.
A signal is never Map/publication authority. A signal followed by a pending
query triggers a1ms sleep and another strict query/device/deadline check; it
cannot hot-spin on the still-signalled handle. Failed HRESULT, device removal,
deadline expiry, failed/unknown Win32 wait status all refuse the stream. No
fallback maps pending resources. There is no shader, solver, stock or clock in
this experiment.

The wait loop and deadline are bounded at host decision boundaries. They cannot
bound a blocking driver API, scheduler delay, submission or system suspension.
The external process timeout is240s. Requested1ms sleeps are not guaranteed1ms
elapsed sleeps; the observed sleep-policy wait medians are about13–15ms. No
global timer-resolution request is made. Win32 status meanings follow
[`WaitForSingleObject`](https://learn.microsoft.com/en-us/windows/win32/api/synchapi/nf-synchapi-waitforsingleobject).

## Resources and failure lifetime

Three immutable RGBA32_UINT sources and three staging textures total17,334,272
logical payload bytes. This is not total VRAM, driver allocation or process
memory. There is one query, one reusable GPU notification handle, fixed-size
readback storage and bounded64-sample/block vectors. A temporary host-control
event exists only during controls. No resource list grows with copy count.

Final revision2 explicitly marks a notification unresolved before submission.
Reset/reuse is refused until both completion authorities and the device check
succeed. On failure, the executable stops; an unresolved notification handle
is retained through exception unwinding and reclaimed at process exit rather
than explicitly closed while it could still be used. Normally completed handles
close during orderly teardown. This isolated process-exit contract is not an
in-process recovery or reusable live owner implementation. Actual device loss
and timeout teardown were not induced in this run.

Post-run review found this failure-lifetime omission in revision1. All initial
sources, executable, receipt, reports and audited observations are preserved in
`initial_v1/` with an immutable manifest. Revision2 then rebuilt and repeated the
same admission controls, payload faults and two trials. The table and selection
above use only final revision2. The first results were not overwritten or mixed
into the final timing averages. No acceptance gate changed.

## Correctness and refusal evidence

Final revision2 checks7,020 completed copies, including warmups, against every
source byte:20,281,098,240 compared bytes. No sampled-value shortcut is used.
All query events complete before Map; the final event blocks make exactly one
Win32 wait and one successful query per measured copy, with no wait timeouts,
post-wake pending queries, spin polls or yields in these observations. This is
an observation, not a guarantee for arbitrary workloads.

Five admission faults independently change the consumer executable hash, source
seed byte, adapter identity, qualification seal and parent seal. Each refuses
before benchmark output or copy-resource allocation. Successful consumers bind
the exact adapter/LUID/driver and seed to the qualified native reference and
sealed s216 parent; no WARP or substitute-adapter fallback is used.

Each of the three policies also completes and reads one16KiB copy, flips one
observed bit and refuses it. No following copy starts. Shared pure controls
exercise stale `S_FALSE/TRUE`, `S_OK/FALSE`, success, failed HRESULT, device
removed despite ready success, and deadline at both ready/pending states.
Four shared Win32 status controls cover signal, timeout, failure and unexpected
abandoned status. A real manually signalled host event paired with an injected
pending query is refused by the same gate; reset is checked with a real zero-time
host timeout. Device/query failures are injected status controls, not proof of
actual driver removal or a naturally stale GPU notification.

## CPU and timing limits

[`GetProcessTimes`](https://learn.microsoft.com/en-us/windows/win32/api/processthreadsapi/nf-processthreadsapi-getprocesstimes)
sums kernel and user time across process threads. Its100ns representation does
not imply100ns accounting precision: the smallest observed positive step here
is15.625ms. A short block with zero CPU is not free. Totals include work charged
to any process thread during the timing windows, including driver work, and do
not isolate intrinsic API or solver CPU. CPU can exceed wall across cores.

The event mechanism has lower means and p95 than sleep here, but it is not a
uniform tail bound: at256KiB its observed maximum wait is44.7991ms, versus
47.1403ms for sleep, despite much lower medians. No GPU busy-time measurement
or whole-system GPU isolation is claimed. Known conflicting processes are
checked before every native process, but OS/driver scheduling and other GPU
activity remain uncontrolled. Readback and compare cost is substantial at8MiB.

## Next implementation and open gates

Create a separate opt-in native nine-interval owner build with event submission,
preserving original bank/stock/time/queued-debt/cap/first-refusal witnesses.
Counterbalance original sleep and event trials, measure physical-window CPU/wall
beside whole-process cost, and stop on the first discrepancy. Declare implicit
flush, preserve successful query/device/deadline authority, and carry forward
safe notification lifetime. Do not infer solver completion from wakeup alone.

Only a passing prefix permits a new full256/protected26/29-stop/three-fault
comparison. Default adoption requires those correctness and full-workload cost
gates; s216 already demonstrates that a short benefit can reverse. The original
s208 natural failure cause and release recurrence qualification remain open.
Total CPU/startup streaming, physical accuracy, common optics, long duration and
actual CSP/live integration remain open. No user game test is needed now.

## Delivery

`build_s217_event.py` → `run_s217_event.py` → `check_s217_event.py` →
`finalize_s217.py`, Python `-B`. The first three were run for initial revision1,
which was preserved before the final revision2 sequence. Previous-stage entry
points were not executed. Saved evidence is in
`docs/diagnostics/2026-10-21/s217/`, with raw/gzip read-only re-audit support.

2,435 older source/configuration files retain SHA256 and mtime. Only the docs
index/roadmap change, with eight new source/topic files. Main app, settings,
shaders and Git HEAD remain unchanged; no commit, push or game installation.
