# s213 — Completion-call wall attribution

State: **ACTIVE, experiment complete; wait policy not adopted**. 2026-10-21.
Parent: `RAINFX_S212_IMMUTABLE_WAIT_COST.md`.

## Result and next implementation

The long8MiB candidate wait is observed **inside GetData call envelopes**:
97.76% of traced wait wall, or12.126ms per copy. The two trace processes separately
show97.07% and98.39%. Yield and between-call wall are much smaller. This locates
the measured delay; it does not identify driver blocking, GPU busy time or OS
descheduling as the cause.

All32 retained longest GetData records from8MiB candidate blocks are poll1004,
returning S_OK/TRUE after13.602–14.703ms. These are the slowest four per block,
**not a trace of every call or proof of a general1004-call runtime rule**.
The repeatable ordinal motivates a count/cadence experiment rather than more
unbounded fast polling.

**Next implementation:** compare a private candidate that limits the initial
GetData burst and spaces later polls, while retaining the exact completion/error/
timeout predicate, one explicit Flush, full-byte checks, fixed storage and the
existing sleep fallback. Bound both the time and pending-query count. Compare
plain wall/process CPU and an independently instrumented sample before deciding
whether to try it in the physical owner. Preserve s211 full/prefix/protected-stop/
witness gates for that later step. No physical-owner wait change is selected here.

## Paired implementation

The builder derives a new consumer from the sealed s212 source. A compile switch
selects the original wait/copy implementation or `s213_trace.inc`. Both use the
same three immutable integer textures, staging textures, one event, seed, hardware
identity, driver and byte comparator. Per-block measured copies are64 in both
builds, with one excluded full-byte-checked warmup. Algorithm/policy, resource
count and accepted event condition are unchanged.

Four sequential fresh processes run **plain → trace → trace → plain**. Within
each process the two size orders are opposite, and policy blocks are ABBA/BAAB.
Each size/policy/executable combination has512 measured copies across two
processes. Total6,144 measured +96 warmups =6,240 successful copies, with
18,027,642,880 bytes compared. No automatic retry or process overlap occurred.
Known game/native GPU consumers are refused; unrelated system activity remains
uncontrolled. Old s212 binaries, observations and source are preserved.

## What is measured

For each wait, monotonic timestamps partition integer nanoseconds into:

1. GetData call envelopes, including any descheduling while inside those calls.
2. Control/recorder work and gaps between calls/actions.
3. The explicit yield call envelope.
4. The explicit requested1ms sleep call envelope.

The sum equals the observed wait exactly in all48 traced blocks. Recorder calls
are outside the API/yield/sleep windows; their cost enters the between-call or
surrounding-copy remainder. Submission CopyResource, End(event), Flush, Map,
row copying, Unmap and full comparison are separately timed. Their sum plus wait
is bounded by the whole-copy window; remaining bookkeeping and inter-copy work
are explicitly reported. No GPU timestamp/busy counter is added.

Each block retains totals/counts and the four longest records for each of11
stages: at most44 records per block. A record includes copy/poll ordinal, start,
duration and GetData HRESULT/ready state. Fixed arrays are allocated before the
timed block. No per-call allocation or output; block output occurs after CPU/
wall measurement. Raw wait samples are retained as in s212.

## Observations

| Payload/policy | Plain wall/copy | Traced wall/copy | Trace/plain ratio |
| --- | ---: | ---: | ---: |
| 16KiB sleep1ms | 15.290ms | 15.065ms | 0.985 |
| 16KiB candidate | 0.0937ms | 0.0589ms | 0.629 |
| 256KiB sleep1ms | 15.455ms | 15.356ms | 0.994 |
| 256KiB candidate | 1.3306ms | 0.1645ms | 0.124 |
| 8MiB sleep1ms | 15.512ms | 15.532ms | 1.001 |
| 8MiB candidate | 15.382ms | 14.717ms | 0.957 |

The instrumented run is not transparently equivalent in timing. Small candidate
windows vary substantially across runs and against s212. Extra timing/recording
changes polling cadence, alongside uncontrolled system variability. Ratios below
one are **not negative overhead** and cannot be subtracted as an observer correction.
Large candidate wall stays near the s21214.766ms observation; it has not become
a low-latency large-copy wait.

| 8MiB traced stage | Baseline ms/copy | Candidate ms/copy |
| --- | ---: | ---: |
| GetData | 0.01565 | 12.12612 |
| Between/control | 0.00175 | 0.07333 |
| Yield | 0 | 0.04697 |
| Sleep | 13.23352 | 0.15809 |
| Map | 0.00558 | 0.00716 |
| Row copy | 1.12963 | 1.13020 |
| Full comparison | 1.01871 | 1.04526 |

Thus the candidate changes the observed location of most wait wall from sleep
to GetData, while full-row copy and comparison add about2.18ms/copy. That CPU
validation cost is part of this diagnostic workload, not a production optics
performance claim. Reducing sleep alone does not remove the large-copy delay.

Process CPU is kernel+user for all process threads, including instrumentation,
copy and comparison, over block windows.8MiB plain CPU is2.960ms/copy baseline
and2.777ms candidate; traced CPU is2.136ms and1.251ms. Deferred driver work,
run variation and15.625ms observed counter steps prevent attributing these
differences to intrinsic call CPU. Some short blocks report zero CPU; that does
not mean the trace or polling is free. Whole-system scheduling/driver/GPU causality
would require different evidence. This stage establishes host wall location only.

## Validation, preservation and reproduction

- Both executables pass the seven unchanged completion/timeout/error controls.
  Timeout/error cases are synthetic, not actual30s hangs/device loss.
- Three mutated provenance inputs refuse before benchmark allocation. Both
  executables reject a one-bit mutation after one actual completed/mapped copy,
  with no subsequent copy. Saved artifacts retain exact reasons.
- The checker validates receipts, build identities, exact source derivation,
  sample/byte counts, integer timing closure, stage totals, bounded sorted top
  records, copy identities and execution non-overlap. It also reports current
  plain/s212 comparisons without treating cross-run differences as causal.
- 2,403 older source/config files preserve SHA256 and mtime. Only docs index and
  roadmap change; seven new source/document files are sealed. Main app, settings,
  shaders, physical owner wait, game files and Git HEAD remain unchanged.

Run `build_s213_trace.py` → `run_s213_trace.py` → `check_s213_trace.py` →
`finalize_s213.py` with Python `-B`. Existing observations cannot be overwritten.
Saved reports, per-block top records, samples, executable receipts and compressed
input artifacts: `docs/diagnostics/2026-10-21/s213/`. Saved read-only audit supports
raw/gzip inputs. No old builder/checker entry points are rerun.

Production physics remains s87. The original s208 cache cause and release
recurrence qualification, total CPU/startup streaming, physical accuracy, common
optics, long-duration and CSP/live adoption gates remain open. No user game test
is needed for this private experiment.
