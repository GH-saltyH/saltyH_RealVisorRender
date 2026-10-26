# s215 — Opt-in paced wait on the bounded physical prefix

State: **ACTIVE, prefix experiment passed; candidate not adopted**. 2026-10-21.
Parent: `RAINFX_S214_COUNTED_PACED_COMPLETION.md`.
Physical reference: sealed s211 nine-interval cutoff and witnesses.

## Result and next implementation

The paced candidate preserves the established physical prefix exactly. Two
original-sleep and two paced fresh processes all publish9 intervals, retain12
accepted, leave future intervals9/10/11 entirely unstarted and queued, and match
the original bank, stocks, clock, ownership and cap. A further paced prefix in
the control batch also passes. These are independent short runs, not a combined
long simulation.

Physical-run wall mean improves **4.2107→1.8904s (55.10%)**. Whole-process wall
mean improves16.984→14.313s (15.73%). That narrower effect includes
startup/validation/cleanup cost. Whole-process CPU varies too much to establish
a CPU-saving result. No game FPS or live solver claim follows from this test.

**Next implementation:** keep the candidate opt-in and run the established full
256-interval, protected26/29-stop and fault/control checks in separate native
builds. Measure physical-window CPU as well as whole-process CPU to separate
startup from solver work in the present mixed windows. Require original bank/stock/time/debt/cap and
first-refusal evidence before any later selection. Stop on first discrepancy.
The s208 natural mismatch/root cause/release recurrence gate remains open.

## Code and unchanged gates

- New `s215_cache_owner.inc` derives from the original s208 owner include. Its
  baseline branch contains the original wait body. A compile flag chooses the
  paced branch only in these new private executables.
- `s215_physical.cpp` derives from s211 and keeps its original owner, cutoff,
  physics, witness and numerical validation code. It selects the new include
  and writes bounded wait counters at process exit, including failed runs.
- The pure policy selector is byte-derived from s214, with identifiers renamed.
  Its previously checked burst/cadence/count/time/wake/deadline logic is retained:
  burst64,50µs spacing,80-query/1ms fast phase, then requested1ms sleep fallback.
- Every accepted event still requires successful GetData and TRUE readiness;
  errors/deadline refuse. The owner still performs its original fence/one Flush
  and resolves timestamp observations only after that event. No additional event,
  query object or global timer setting is introduced.
- The runner validates every successful prefix with the existing pure s211
  oracle before starting the next process. Native failure or saved-state mismatch
  stops the batch and preserves its outputs. No automatic retry is used.

All inputs and compiled shaders are bound to each executable by the established
full physical receipt. Actual adapter/driver admission and qualified bootstrap
checks are retained. The synthetic-copy receipt is not reused as physical
qualification. Source hashes and old compiled shader identities are rechecked.

## Exact physical and resource evidence

Each successful prefix preserves:

| Property | Observed value |
| --- | --- |
| Published / accepted intervals | 9 / 12 |
| Published / accepted simulation time | 0.15189456939697266 / 0.20252609252929688s |
| Active / queued time debt | 0 / 0.050631523132324219s |
| Entirely unstarted queued contexts | 9,10,11 |
| Physical / cache / total draws | 2,196 /21 /2,260 |
| Completion events, including bootstrap | 246 |
| Cache publications / final lease | 8 /10 |
| Peak default payload / cap | 66,582,496 /66,584,576 bytes |
| Final default payload | 0 |
| Owned created objects / cumulative payload | 266 /288,445,088 bytes |
| Retained metric witnesses / copies | 21 /36 |

The complete final bank is8,585,560 bytes, SHA256
`b33e42dfeeb90acc0f155122e15b68c226cb4a6cc32b2418d3469a3aed6505e9`.
Original physical/audit/stock packet prefixes, mandatory reads, owner/stock/
phase/recovery/cache traces, metadata and all witness rows match. This is the
same numerical scope as s211, not a new proof of physical realism or a total
process-memory bound. The native requested256-interval gate correctly remains
false for this9-interval cutoff; a separate prefix gate is validated.
The cutoff freezes admission and ends the diagnostic with resource cleanup and
queued-debt evidence. It does not implement a live pause/resume path.

## Sequential cost comparison

Four natural trials run **sleep → paced → paced → sleep**, in release mode with
the same frozen inputs and mandatory diagnostics. No native GPU trials overlap.
Known game/native GPU processes are refused before launch; whole-system activity
is not isolated. The fifth successful paced/control-batch prefix and failed
control are excluded from this performance comparison.

| Natural trial | Policy | Physical-run wall | Process wall | Process CPU |
| --- | --- | ---: | ---: | ---: |
| 00 | original sleep | 4.2457s | 17.625s | 19.1406s |
| 01 | paced | 1.9832s | 14.829s | 18.0781s |
| 02 | paced | 1.7976s | 13.797s | 12.2344s |
| 03 | original sleep | 4.1756s | 16.343s | 12.3281s |

Physical-run completion-wait wall mean falls3.5263→1.2409s. Process CPU is read
with GetProcessTimes from the completed native process handle, includes all
threads plus startup/shader preparation/cleanup, and can exceed wall on multiple
cores. Means15.7344→15.1563s are small relative to the between-run variation.
Physical-window CPU is not isolated here, so the shorter wall result does not
prove lower CPU consumption in the solver. CPU counter units are100ns; their
resolution does not imply100ns measurement accuracy.

Baseline global wait counters show506/513 queries and260/267 sleeps. Paced shows
15,073/15,873 queries,106/100 fallback sleeps and roughly302k/330k yield calls.
Fast phases respect80 queries; total wait peaks are82 because fallback queries
are outside that cap. Polling/yield work increases, despite shorter wall time.
These global counters include bootstrap; physical-run timing resets afterward.
The test still takes seconds to validate0.152s of simulated time under mandatory
readback/witness instrumentation, so it does not establish real-time readiness.

## First-refusal control

A separate planned batch is paced → injected retained-GPU fault → paced. The
first prefix passes. The second stops at frame7 phase1875 with
`retained metric witness mismatch`, independently classified as
`retained_GPU_pair_changed`. The captured after-pair differs by the injected bit;
frozen/live references and preceding witnesses remain unchanged. The preceding
seven stock publications and accepted-time debt are protected; the failed frame
bank is not published. The third process is never started.

The failed run writes193 completed events, fast-query peak80 and its first
fault capture. This is a deliberate refusal-path check, not reproduction of the
natural s208 mismatch. The runner saves the native reason and first divergent
witness before terminating the batch.

## Artifacts and preservation

Tools: `build_s215_prefix.py` → `run_s215_prefix.py` → `check_s215_prefix.py` →
`finalize_s215.py`, Python `-B`. Saved reports, receipts, per-trial CPU and wall
observations, bank proofs and fault artifacts are in
`docs/diagnostics/2026-10-21/s215/`. Read-only audits support raw/gzip. Existing
observations are not overwritten; no old builder/checker entry points are run.

2,419 older source/config files preserve SHA256 and mtime. Only docs index and
roadmap change; eight new source/document files are sealed. Existing owner
default, main app, settings, shaders, game files and Git HEAD remain unchanged.
Production physics remains s87. Full candidate and protected-stop gates,
long-duration, total CPU/startup streaming, physical accuracy, common optics and
CSP/live adoption remain open. No user game test is required now.
