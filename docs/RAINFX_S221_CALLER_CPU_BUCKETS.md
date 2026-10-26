# s221 — caller CPU buckets and counter controls (2026-10-21)

## Decision

The bounded comparison passes unchanged physical-output and ownership gates.
The new small-scope GetThreadTimes buckets do **not** provide adequate temporal
resolution for a reliable CPU bottleneck attribution. Do not select a default
wait policy or optimize the solver from those bucket values. The next diagnostic
should evaluate calling-thread cycle counters with matching controls, retaining
whole-window process/thread CPU measurements and all original completion gates.
Cycle counts must remain cycles, not be converted to seconds using an assumed
fixed CPU frequency. No game action is required at this stage.

## Scope and method

Five private consumers use frozen s220/s219 physical code and the qualified
s220 current-context geometry. New CPU scopes cover draw/copy/upload submission
wrappers and completion-fence submission, completion waiting, and the inherited
timestamp-query resolver. Other code, including binding/allocation/readback and
verification outside those wrappers, remains in an explicit caller remainder.
The buckets are exclusive and runtime nesting is refused. No shader, GPU command,
timestamp query, completion event, water input, display gain or acceptance
tolerance is added or changed. The original sleep/event completion predicates,
device checks, deadline, ownership and first-refusal behavior are retained.

The order is sleep plain / event plain / event measured / sleep measured,
followed by its reverse. Each condition has two fresh-process observations.
No prephysical pause is added. A separate event measured / GPU-bit-fault /
event measured batch stops at the expected fault before launching the last case.
CPU-only normal/reverse controls perform 1,048,576 scopes per block, four blocks
per process, comparing two instrumented with two uninstrumented blocks.

## Observations

Mean physical-prefix times, seconds (two observations per condition):

| Condition | Wall | Caller CPU | All-thread process CPU |
| --- | ---: | ---: | ---: |
| Sleep, plain | 4.102248 | 0.507813 | 0.539063 |
| Event, plain | 1.051820 | 0.539063 | 0.593750 |
| Sleep, measured | 4.026968 | 0.632813 | 0.742188 |
| Event, measured | 1.085984 | 0.515625 | 0.609375 |

Each successful measured prefix has 3,220 submission scopes, 245 waits and 181
timestamp resolves: 3,646 scopes and 7,292 extra thread-time calls. Its raw
submission CPU sums range 46.875–250 ms. In some trials these CPU sums exceed
the corresponding scope wall sums. Wait CPU is 0 in three measured cases and
15.625 ms in one; resolver CPU is 0 in all four. These are counter attribution
artifacts/limits, not evidence of zero CPU work or literal per-function costs.
The signed whole-process minus caller residual is also not a driver attribution.

CPU-only extra scope cost is approximately 261–283 ns per scope, about
0.95–1.03 ms when arithmetically scaled to 3,646 scopes. This is a synthetic
operation-cost observation, not a causal correction to the real GPU run.
For example, measured sleep caller CPU is 125 ms higher than plain, whereas
measured event caller CPU is 23.438 ms lower. The two samples per condition,
coarse accounting, execution order and runtime variability prevent attributing
these differences solely to instrumentation. Do not subtract the synthetic
cost and present the result as an uninstrumented performance measurement.

Event wakeup shortens this bounded prefix's wall time; it does not establish
full-workload CPU benefit, game FPS gain or a release default. Timestamp
intervals are not GPU busy counters. Whole-system GPU isolation is not proved.

## Correctness and preserved failures

Eight natural prefixes and one separate healthy control prefix pass the frozen
full-byte bank, water ledger, clock, queue/debt, read ownership, witness and
resource-cap oracles. Each publishes 9 intervals and accepts 12, retaining
queue [9,10,11], 246 completion events and 2,260 total draws. Peak scoped default
payload stays 66,582,496 bytes under the 66,584,576-byte cap. This is not total
VRAM or process memory. The injected GPU-bit fault is classified as
`retained_GPU_pair_changed` and refuses with prior stock/clock protected.

Before native execution, sandbox tasklist preflight failed; its continuation
retains the original sources and bindings. The first native input admission
then refused `input EOF` before device creation: the preparation tool omitted
the frozen `bindings.bin` companion table needed by the schedule decoder.
`natural/` retains that failed admission and seven unstarted cases. The missing
table is copied unchanged from s220; `admitted_natural/` is a separate corrected
admission batch. No native consumer was rebuilt and no numeric gate relaxed.
The preparation scripts are historical evidence; do not rerun their fresh-run
entry points against this sealed directory. Use the finalizer for saved audits.

## Evidence and remaining work

Evidence: `docs/diagnostics/2026-10-21/s221/`. Tools and generated C++ headers
use the s221 prefix; `finalize_s221_attribution.py` performs the saved audit and
seals the source manifest, preserving the failed admission and corrected run.
The audit passes; game solver/defaults/settings and Git HEAD are unchanged.

Next: validate higher-resolution caller-cycle attribution with a CPU-only
counter control and bounded plain/measured physical comparison. Full event
256-interval/stop/fault cost qualification, the original natural s208 mismatch,
release recurrence, physical accuracy, optics and actual CSP integration remain
open. The game physics remains s87; this stage is private native diagnostics.
