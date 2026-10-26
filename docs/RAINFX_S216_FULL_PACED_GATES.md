# s216 — Full paced-wait gates and physical CPU windows

State: **ACTIVE, correctness gates passed; paced candidate rejected for default**.
2026-10-21. Parent: `RAINFX_S215_PACED_PHYSICAL_PREFIX.md`.

## Decision

The full256-interval candidate preserves the established GPU outputs, stocks,
clock, ownership and cap, and passes protected-stop and three fault controls.
However, this full-run comparison reverses the short-prefix timing benefit:

| Full256 observation | Original sleep | Paced candidate |
| --- | ---: | ---: |
| Physical-run wall | 146.6801s | 211.6739s |
| Physical-window process CPU | 15.4219s | 19.2344s |
| Whole-process wall | 160.859s | 226.547s |
| Whole-process CPU | 28.6563s | 32.8125s |

Physical wall rises44.31%, and CPU consumed in that window rises24.72%. These
are **one full observation per policy**, in that order; they are not a general
causal performance result or a benchmark distribution. They are sufficient to
withhold adoption. The owner default, game files and production physics remain
unchanged. s215's short-prefix improvement alone cannot select this policy.

## What changed

New private executables derive from s215, retain the same64-query burst,50µs
spacing,80-query/1ms fast phase and sleep fallback, and compile the existing
prefix switch off. No physics, shader, bank, queue, tolerance or completion guard
is changed. Five consumers bind original-sleep, paced and the existing CPU/GPU/
shared-selection fault modes to the frozen physical inputs and actual adapter/
driver receipt. No WARP or unqualified-input fallback is used.

Two GetProcessTimes snapshots bracket `runPhysical()`. The window includes its
mandatory validation/readbacks and successful internal teardown, while excluding
input decode/hash, shader preparation and later report writing. Counts cover
all process threads, including driver work attributed during the window; they
do not identify intrinsic solver/API CPU or exclude deferred background work.
CPU counters use100ns units and have coarser observed accounting resolution.
Whole-process CPU is separately read after native process exit. CPU can exceed
wall with multiple executing threads.

On an exception, the partial physical CPU window is written before propagating
the failure; external exception cleanup is marked excluded. The successful
budget-stop flag means `runPhysical()` returned normally, not that256 intervals
were published. All CPU samples stay within the final native process counters.

## Full and stop preservation

Both full runs publish and accept256 intervals,4.320556640625s of simulation,
and finish with zero time debt. Full GPU snapshots/final bank/stock packets,
owner/stock/recovery/phase/index traces, metadata and canonical resource
inventories match the qualified original full reference. All256 stock ledgers
also pass the existing balance checker. Each full run retains7,085 completion
events and the original21 metric witnesses/36 copies; no extra event is added.

The paced protected-stop run uses the established attempt budget and debug device:

| Protected-stop property | Observed |
| --- | --- |
| Published / accepted intervals | 26 /29 |
| Active / queued debt | 1dt /2dt |
| Existing completion events | 725 |
| Physical wall / CPU | 12.1307s /2.8281s |
| Peak default payload / cap | 66,582,496 /66,584,576 bytes |
| Final default payload | 0 |

The prior published bank and the last stock/ledger/checkpoint remain protected.
The original protected-stop oracle passes unchanged. Full and stop resource
inventories, retained readers, cache/witness checks and mandatory read semantics
match the original reference. This does not prove total process memory, long
duration, live scheduling, physical realism or real-time readiness.

## Cost evidence and its limits

| Physical-run host timing | Original sleep | Paced |
| --- | ---: | ---: |
| Completion-wait envelopes | 133.1091s | 199.1748s |
| Explicit sleep envelopes | 132.9114s | 193.8507s |
| Explicit yield envelopes | 0 | 3.6865s |
| Profiled sleep calls | 9,386 | 13,607 |

The additional wait wall is largely observed in sleep envelopes. Global counters
(including bootstrap) show9,388/13,610 sleeps and16,473/544,436 event-query polls.
The paced fast cap remains80; total wait-query peak is100 because fallback polls
are outside the fast phase. It also executes about16.17 million yields. Bounded
fast query counts do not imply low total CPU or low completion latency.

Reported explicit GPU interval sums also differ38.1420→82.6594s. Those intervals
are not busy counters, and the system GPU/scheduler/driver state was not isolated.
Consequently the extra wall cannot be attributed solely to the wait algorithm,
nor to a proven GPU slowdown. The current evidence rejects selection of this
candidate; it does not establish an internal driver or scheduling root cause.
No game FPS prediction is made.

## Three expected fault controls

| Injected control | First affected location | Independent classification |
| --- | --- | --- |
| CPU expected reference bit | Frame7, phase1875 | CPU_expected_changed |
| Retained GPU pair bit | Frame7, phase1875 | retained_GPU_pair_changed |
| Shared-metric selection | Frame8 configuration | CPU_shared_selection_changed |

All fail with the original `retained metric witness mismatch`, retain the first
capture and preceding valid witnesses, preserve the prior7/7/8 stock publications
and time debt, and do not publish the failed frame bank. These are expected
negative tests. The natural s208 failure is not reproduced or explained.

## Saved checker defect and continuation

The first plan stopped before the three fault controls because a new wrapper
incorrectly required one stock row per published interval for the protected stop.
That trace intentionally contains26 publication rows plus a preserved checkpoint
for the refused next interval. Native execution returned successfully, and the
unchanged reference parity test had already passed.

The wrapper was corrected to require that extra row specifically for this stop.
The unchanged original stop oracle independently confirmed preserved bank/debt/
stock state. The initial stopped `plan.json` and `checker_before_stock_fix.py`
are retained. `continuation.json` binds that plan and validator versions, records
revalidation of the existing full/stop outputs, and runs only the three previously
unstarted fault cases. No full or stop native execution was repeated or overwritten.
All six native cases are sequential; every unexpected refusal stops further work.
No numerical acceptance condition or tolerance was relaxed.

## Next implementation

Keep the original owner policy. Investigate a separate immutable-stream **native
event-wakeup probe**, comparing CPU and wall with original sleep and paced waits,
before another expensive full-owner run. Reuse one bounded event, retain a finite
deadline and the original successful GetData/readiness check as the authority for
reading or publishing. A stale signal, timeout or removed device must not satisfy
that authority. No CSP/presentation completion or live adoption is implied.

One candidate API is
[IDXGIDevice2::EnqueueSetEvent](https://learn.microsoft.com/en-us/windows/win32/api/dxgi1_2/nf-dxgi1_2-idxgidevice2-enqueuesetevent).
Its documented behavior includes flushing pending commands and signalling after
prior rendering completes **or the device is removed**. Thus wakeup alone cannot
prove success. Its flush behavior differs from the current explicit-Flush path
and must be declared and tested in the separate probe. This is a proposed
mechanism to evaluate, not a demonstrated cost improvement or CSP fence.

## Delivery

Tools: `build_s216_full.py` → `run_s216_full.py` → `check_s216_full.py` →
`finalize_s216.py`, Python `-B`. This run's deliberate continuation uses
`run_s216_full.py resume-stock-audit` after revalidating the recorded checker
correction. Existing observations and plans are immutable.

Reports, physical/whole-process CPU observations, original stop and continuation,
receipts, bank proofs and fault captures are sealed in
`docs/diagnostics/2026-10-21/s216/`. Saved audits support raw/gzip; old builder/
checker entry points are not rerun.2,427 older source/config files preserve
SHA256 and mtime; only docs index/roadmap change, with eight new files sealed.
Main app, settings, shaders, owner default and Git HEAD remain unchanged.
Original natural cause/release recurrence qualification, physical accuracy,
total CPU/startup streaming, common optics, long duration and actual CSP/live
gates remain open. No user game test is required now.
