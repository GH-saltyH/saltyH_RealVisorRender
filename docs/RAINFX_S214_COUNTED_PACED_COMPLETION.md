# s214 — Counted and spaced completion candidate

State: **ACTIVE, private experiment complete; owner policy not adopted**.
2026-10-21. Parent: `RAINFX_S213_COMPLETION_CALL_ATTRIBUTION.md`.

## Result and next step

Limiting dense GetData calls removes the observed long call envelope in this
private workload. For8MiB, plain mean whole-copy wall falls14.433→5.576ms
(61.37%); both independent plain processes improve, with ratios0.423/0.352.
The original fast policy reproduces poll1004 long calls in all32 retained large
copy records. Paced retained call maxima are below0.160ms; all1,024 measured
paced8MiB waits across plain/trace stay at82 total queries or fewer.

This supports evaluating the candidate on a **bounded private physical prefix**,
not replacing the owner default or game policy. Small-copy means and some tail
latencies regress. A synthetic copy is not a physical shader workload.

**Next implementation:** add an explicit opt-in candidate to a separate s211
nine-interval native physical prefix build. Compare with the unchanged owner
sleep policy, measure host/process CPU, and retain full-byte bank, stock, time,
queued debt, cap and first-refusal witnesses. Stop at the first discrepancy and
preserve its evidence. If prefix gates pass, run the established full/protected-
stop/control checks before any owner adoption. Keep the s208 cause/release
qualification gate open; the present experiment does not repair that mismatch.

## Candidate and comparison semantics

The baseline here is **s212/s213 fast polling**, not their sleep1ms baseline:
poll below150µs, yield below1ms, then sleep1ms after a pending query. Raw block
`candidate=false` identifies that legacy fast policy; `candidate=true` is paced.
`build.json` and this report state that mapping explicitly.

The paced candidate:

1. Allows an initial burst of64 total queries, including the first query.
2. After the burst, schedules the next query50µs after the pending result and
   bookkeeping; yields without querying until it is due.
3. Ends the fast phase at80 queries or1ms elapsed, whichever is first observed.
4. Uses the unchanged requested1ms sleep fallback, then one query per wake.

Completion still requires S_OK and TRUE; failed HRESULTs refuse. A pending query
at30s refuses, while a final completion query at the deadline can still succeed
as in the original guard ordering. That final probe is outside the fast budget.
No global timer setting, additional Flush, asynchronous worker or acceptance
shortcut is introduced. Counts/time bound policy decisions; they cannot bound
one API call, yield, sleep or OS scheduling delay. Fallback total query counts
can exceed80;80 is the fast-phase cap, not the whole-wait limit.

The source is derived from sealed s213 with unchanged resource, payload, query
reuse and comparator paths. New plain/trace builds differ by instrumentation.
The legacy policy still uses its original code. Four sequential processes run
plain/trace/trace/plain; each contains opposite size orders and ABBA/BAAB policy
blocks. Each size/policy/build has512 measured copies, plus separate warmups.
Every copy is completed, mapped and fully compared:6,240 successful copies /
18,027,642,880 bytes. No overlapping native trials or automatic retries occurred.

## Plain cost and latency

Whole-copy wall includes submission, completion, Map, row copy and full comparison.
CPU includes all process threads over the same blocks, not just the wait loop.

| Payload | Legacy wall/copy | Paced wall/copy | Legacy CPU/copy | Paced CPU/copy |
| --- | ---: | ---: | ---: | ---: |
| 16KiB | 0.6912ms | 1.0954ms | 0.2747ms | 0.5188ms |
| 256KiB | 0.6335ms | 0.9859ms | 0.3052ms | 0.2747ms |
| 8MiB | 14.4331ms | 5.5761ms | 3.9063ms | 2.8076ms |

Small means increase58.5%/55.6%.16KiB plain process ratios are5.871 and0.818;
256KiB ratios2.091 and1.173. Small timing remains variable, and no blanket
performance improvement is claimed.8MiB measured process CPU drops1.099ms/copy,
but counter quantization, other process threads and observation windows prevent
attributing this to intrinsic API CPU consumption.

| Plain wait | Legacy median / p95 / maximum | Paced median / p95 / maximum |
| --- | ---: | ---: |
| 16KiB | 0.0134 / 0.8891 / 24.8064ms | 0.0606 / 12.9162 / 20.9370ms |
| 256KiB | 0.0236 / 0.8455 / 15.3972ms | 0.0641 / 10.1117 / 15.5365ms |
| 8MiB | 12.9030 / 13.8020 / 14.7144ms | 0.5407 / 14.3063 / 22.3563ms |

The paced large-copy mean improves while p95/maximum remain worse in this sample.
Fallback sleep tails remain material, so this candidate is not a latency bound.

## Query and traced evidence

Every measured paced wait respects the80-query fast cap. Peak total queries are82
for all three sizes; no measured paced wait exceeds1,000 queries. Across both
builds, legacy waits exceeding1,000 queries number153/170/1,022 by size. These
are measured counts, not a general runtime throttle threshold.

For8MiB, the32 retained legacy longest GetData calls are all poll1004, returning
S_OK/TRUE after13.387–14.435ms. Paced retained ordinals vary1–82, with maxima
0.1597ms. Only13 of these32 paced records are completed queries; pending queries
can also be the longest. Records are the four slowest per stage/block; no claim
is made that every individual call is retained.

| Traced8MiB stage | Legacy ms/copy | Paced ms/copy |
| --- | ---: | ---: |
| GetData | 12.6310 | 0.0297 |
| Between/control | 0.0687 | 0.2068 |
| Yield | 0.0392 | 0.4385 |
| Sleep | 0.0541 | 4.7425 |
| Row copy + comparison | 2.4935 | 2.4353 |

The new observed wait mostly shifts to fallback sleep and paced yielding.
Across plain+trace large blocks, legacy/paced sleep calls total10/363. Traced
whole-copy wall is15.4276/7.9829ms versus plain14.4331/5.5761ms. Instrumentation
alters cadence and fallback frequency, so its cost is not subtracted from plain
results. GetData envelopes include descheduling; driver/OS/GPU causality remains
unestablished. These are private host measurements, not game FPS predictions.

## Checks and preservation

- Seven inherited completion/error/timeout controls and nine new selector cases
  cover burst, spacing boundary, count cap, time cap, wake and final deadline
  probe. Timeout/error cases are synthetic, not actual device-loss/hang tests.
- Consumer/seed/adapter mutations refuse before benchmark allocation. Both builds
  reject one-bit corruption after one actually completed/mapped copy, with no next
  copy. These validate the same full-payload refusal path.
- All48 traced blocks have exact integer wait partition closure and bounded,
  sorted top records. Query classification, fast caps, copy/event/byte counts,
  derived sources, executable receipts and process non-overlap pass saved audits.
- 2,410 older source/config files preserve SHA256 and mtime. Only docs index and
  roadmap change; nine new source/document files are sealed. Main, settings,
  shaders, game files, owner wait and Git HEAD remain unchanged.

Tools: `build_s214_pacing.py` → `run_s214_pacing.py` → `check_s214_pacing.py` →
`finalize_s214.py`, Python `-B`. Reports, per-block samples, bounded call records,
receipts and compressed payloads are in `docs/diagnostics/2026-10-21/s214/`.
Saved audits support raw/gzip; old builder/checker entry points are not rerun.
No user game test is required now. Production physics remains s87.
