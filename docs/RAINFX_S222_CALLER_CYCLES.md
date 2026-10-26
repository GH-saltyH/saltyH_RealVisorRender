# s222 — calling-thread cycle attribution (2026-10-22)

## Decision

All bounded parity/refusal gates pass. QueryThreadCycleTime resolves nonzero
aggregate costs in the three scopes that were poorly resolved by s221's
GetThreadTimes. In measured runs, **92.4–93.8% of calling-thread cycles remain
outside those three scopes**. Completion waiting and timestamp resolution are
not the dominant measured caller-cycle categories in this workload. Investigate
the remainder before attempting another wait-policy optimization.

Next: partition that remainder into resource allocation and driver setup,
readback/CPU data processing and validation, and owner/packet bookkeeping, using
exclusive cycle scopes, a retained remainder, plain/measured controls and the
same immutable physical gates. These are candidate categories, not identified
causes. Full event-policy cost qualification remains a separate requirement.

## Implementation and boundaries

The stage-local s222 header replaces only the private s221 thread CPU sampler
with QueryThreadCycleTime. It adds two whole-window cycle reads in both plain
and measured consumers. Measured consumers retain three exclusive scopes:

- draw/copy/upload submission wrappers and completion-fence submission;
- completion waiting, including inherited polling and sleeping;
- the inherited timestamp-query result resolver.

The scope list does not cover all GPU-related CPU work: allocation, state and
binding preparation, staging Map/CPU processing, proof/ledger checks and owner
bookkeeping outside those wrappers are included in the explicit remainder.
Whole-window cycle count equals scope-cycle sums plus remainder exactly. Caller
identity, monotonicity, non-overlap and positive measured bucket sums are checked.
Three thousand six hundred forty-six scopes add 7,292 scope cycle reads per
healthy measured prefix, plus two window reads. The original whole-window
GetThreadTimes/GetProcessTimes boundaries remain for CPU-time comparison.

Cycles include user/kernel work for the calling thread; they are not process
worker accounting. They are never converted to elapsed seconds or compared to
wall time using an assumed CPU frequency, following the
[Microsoft API contract](https://learn.microsoft.com/en-us/windows/win32/api/realtimeapiset/nf-realtimeapiset-querythreadcycletime).
They are observed accounting values, not an exact uninstrumented instruction
profile or a general driver attribution. Scope overhead remains in the results.

## Results

Two fresh-process observations per condition, mirrored order:
sleep plain / event plain / event measured / sleep measured, then reverse.

| Condition | Physical wall s | Caller CPU s | Process CPU s | Window cycles, millions |
| --- | ---: | ---: | ---: | ---: |
| Sleep plain | 3.957665 | 0.710938 | 0.796875 | 1978.958 |
| Event plain | 1.018270 | 0.492188 | 0.546875 | 1870.030 |
| Sleep measured | 3.848540 | 0.671875 | 0.804688 | 2023.331 |
| Event measured | 1.013157 | 0.539063 | 0.625000 | 1868.128 |

Mean of per-trial cycle shares in measured runs:

| Scope | Sleep | Event |
| --- | ---: | ---: |
| Submission wrappers | 5.574% | 5.200% |
| Completion wait | 1.151% | 0.541% |
| Timestamp resolver | 0.856% | 0.493% |
| Other caller work | **92.419%** | **93.767%** |

Measured wait wall time is 3.299s for sleep and 0.508s for event, whereas its
cycle share is small in both. Wall time spent waiting is not equivalent to
calling-thread CPU work. Event has lower wall time in this bounded workload;
two samples per policy do not establish full-workload/default benefit, isolate
runtime variability, or measure game FPS. Differences between CPU-time and
cycle ratios must not be explained using an assumed fixed CPU frequency.

The two CPU-only controls use normal/reversed four-block orders, 1,048,576
synthetic scopes per block, and no GPU device. Baseline-subtracted cycle cost is
approximately 1,299 and 1,302 cycles per scope. Scaling that observation to
3,646 scopes gives about 4.74 million cycles, roughly 0.23–0.25% of measured
physical-window cycles. This is an operation-cost scale check, not a correction
to subtract from the GPU trials or a causal bound on instrumentation effects.

## Correctness and preservation

Eight natural prefixes, a separate healthy event prefix and the expected
GPU-bit refusal pass. Healthy prefixes retain 9 published / 12 accepted
intervals, queue [9,10,11], original bank and ledger bytes, clocks/debt/read
leases, 246 completion events and 2,260 total draws. Peak scoped default payload
is 66,582,496 bytes under the 66,584,576-byte cap; this is not total VRAM.
The fault is classified `retained_GPU_pair_changed`; no third control process
starts, and prior stock and clock remain protected.

The s220 current-context geometry receipts and immutable physical shaders are
reused with new executable hashes; the strict device/driver/reference checks
pass. The previously omitted bindings companion table is included before
launch. No shader, GPU command, timestamp pair, completion event, numerical
tolerance or original wait predicate is added or changed. No timing retry or
failed trial occurs in this stage. The known tasklist sandbox restriction is
handled by the approved independent-run execution.

## Delivery and limits

Evidence: `docs/diagnostics/2026-10-22/s222/`.
`build_s222_cycles.py` generates/compiles stage-local consumers;
`run_s222_cycles.py` runs bounded comparisons;
`check_s222_cycles.py` audits saved observations and seals the manifest.
The saved audit does not repeat GPU experiments. Older source/settings/main app
and Git HEAD are preserved; only the docs index and roadmap change.

Game physics remains s87. This is private native diagnostics, not live CSP
completion verification or solver/optics integration. Full 256-interval event
cost/stop/fault qualification, the natural s208 discrepancy/release recurrence,
physical accuracy, optics, long duration, total memory and live integration
remain open. No user game test is requested for s222.
