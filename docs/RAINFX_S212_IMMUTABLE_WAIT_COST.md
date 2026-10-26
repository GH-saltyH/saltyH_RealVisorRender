# s212 — Immutable-copy completion-wait cost

State: **ACTIVE, experiment complete; candidate not adopted**. 2026-10-21.
Parent: `RAINFX_S211_BOUNDED_REPRODUCTION_TRIALS.md`.

## Purpose and decision

Separate the requested 1ms sleep cost from completion integrity and measure a
bounded polling candidate on a private immutable command stream. The small-copy
result warrants further investigation, but the large-copy result prevents a
general wait-policy recommendation. Production physics remains s87. The s208
cache mismatch still has no established natural cause or release qualification.

**Next implementation:** instrument a separate immutable stream to distinguish
time inside GetData from time between calls, yield, explicit sleep, submission,
Map and full-byte comparison, with bounded samples and process CPU windows.
Retain uninstrumented s212 observations for comparison. Determine why 8MiB
candidate waits remain long before selecting a physical-owner wait change.
Any later owner candidate must pass the full/prefix/protected-stop/witness gates.

## Experiment

- Hardware adapter0: NVIDIA RTX3070, vendor4318/device9348, LUID0:68878,
  driver9007199255790656. The actual native adapter/driver must match the receipt.
- Separate `/O2 /fp:strict /W4 /WX` executable, no debug layer, shaders or solver.
  Its SHA256, deterministic 8MiB seed SHA256 and existing s206 qualification seal
  are checked before benchmark resource allocation. That seal supplies provenance;
  it does not qualify the synthetic workload as a physical solver.
- Three immutable RGBA32_UINT source textures and three CPU-read staging textures:
  256×4 (16KiB), 256×64 (256KiB), 1024×512 (8MiB). Logical texture payload is
  17,334,272 bytes; this is not measured VRAM or total process memory.
- One preallocated EVENT query, reused only after observed completion. Each copy
  executes CopyResource → End(event) → one Flush → GetData(DONOTFLUSH).
  Map and a full row-pitch-aware byte comparison follow observed completion.
- Both policies require `S_OK && ready == TRUE`; errors refuse the stream. The
  existing 30s deadline check remains, after the completion check. No global
  timer setting or background polling thread is introduced.
- Baseline sleeps for a requested1ms after each pending query. Candidate polls
  while elapsed time is below150µs, yields below1ms, then uses the same1ms sleep.
  These are decisions between calls, **not hard bounds on API/scheduler latency**.
- Two sequential fresh processes. Each runs both ascending and descending size
  orders; policies use ABBA then BAAB. Each block has one validated, excluded
  warmup followed by128 measured copies. Per size/policy:1,024 measured samples
  across both processes. Total6,144 measured +48 warmup copies.
- Every successful copy is compared:6,192 copies /17,888,968,704 bytes. The seed
  is also regenerated independently with widened integer arithmetic in Python.
  Query/texture allocation and hashing are outside timed blocks; fixed resources
  are retained until process exit. No overlapping benchmark processes occurred.

## Observed cost

Block wall time includes copy submission, completion wait, Map, row copy and
full comparison. Process CPU is kernel+user time for all process threads across
the same blocks; it includes driver work attributed to those threads. It does
not cover other processes or work deferred beyond a measured block. The smallest
observed CPU counter step was15.625ms, so short-block zeros do not mean free CPU.

| Payload | Baseline wall/copy | Candidate wall/copy | Baseline CPU/copy | Candidate CPU/copy |
| --- | ---: | ---: | ---: | ---: |
| 16KiB | 15.101ms | 0.0635ms | 0.3967ms | 0.0305ms |
| 256KiB | 15.323ms | 0.5309ms | 0.3052ms | 0.2747ms |
| 8MiB | 15.597ms | 14.766ms | 1.8005ms | 2.1515ms |

For 16KiB/256KiB, both independent processes show lower candidate wall time.
For8MiB, candidate/baseline wall ratios are1.00187 and0.89170: aggregate5.33%
improvement is not consistent across processes. Measured8MiB CPU rises by
0.351ms/copy. Aggregate CPU over all measured blocks is2.5625s baseline and
2.515625s candidate, too close and too coarsely counted to support a general
CPU-saving claim. Higher short-window CPU/wall ratios do not mean higher total
CPU consumed per successful operation.

Candidate median wait is0.0143ms /0.0245ms /13.3488ms across the three sizes.
For8MiB,12.8616s of aggregate wait contains only0.0702s of explicit sleep; most
wait wall remains outside sleep. The current instrumentation cannot distinguish
individual GetData call duration, scheduling gaps, polling and yield contributions.
It therefore does not establish an API blocking cause. Candidate max waits remain
14.06ms /29.61ms /26.73ms; a1ms policy budget is not a1ms latency guarantee.
These are private host observations, not GPU busy time or predicted game FPS.
Other system GPU users and scheduler conditions were not isolated.

## Integrity and refusal checks

- Seven shared-predicate controls cover pending HRESULT with stale TRUE, S_OK
  with FALSE, exact success, spin/yield/sleep selection, timeout and failed API.
  Timeout/error controls are synthetic; no real30s hang/device loss is claimed.
- Wrong consumer SHA, one-bit seed mutation and wrong adapter receipt each refuse
  before benchmark output/resource allocation. Native errors are saved verbatim.
- A one-bit mutation of an actually completed, mapped16KiB copy is rejected after
  exactly one event/copy; no following copy starts. It tests payload validation,
  not a claim that hardware naturally produced corruption.
- Saved checker verifies every control result, receipt, source/build identity,
  sequence, sample count, byte count, timing partition and process non-overlap.
  It does not rerun older builder or checker entry points.

## Files and reproduction

Tools: `docs/tools/{build,run,check}_s212_wait.py`, `s212_wait.cpp`,
`finalize_s212.py`. Build → run → check → finalize in that order, Python `-B`.
Saved observations are immutable; rerunning the runner refuses existing outputs.
Reports, raw wait samples, executions, controls and archive hashes are in
`docs/diagnostics/2026-10-21/s212/`. The finalized read-only audit reads raw/gzip.

All2,397 older source/config files retain SHA256 and mtime; only docs index and
roadmap change. Six new source/document files are sealed. Main app, settings,
solver shaders, game files, Git HEAD and original physical wait remain unchanged.

## API references

- [GetProcessTimes](https://learn.microsoft.com/en-us/windows/win32/api/processthreadsapi/nf-processthreadsapi-getprocesstimes): kernel/user FILETIME units are100ns; counts are process CPU time.
- [D3D11 GetData](https://learn.microsoft.com/en-us/windows/win32/api/d3d11/nf-d3d11-id3d11devicecontext-getdata) and [EVENT queries](https://learn.microsoft.com/en-us/windows/win32/api/d3d11/ne-d3d11-d3d11_query): observed event completion requires S_OK and TRUE.
- [D3D11_ASYNC_GETDATA_FLAG](https://learn.microsoft.com/en-us/windows/win32/api/d3d11/ne-d3d11-d3d11_async_getdata_flag): DONOTFLUSH flag.
