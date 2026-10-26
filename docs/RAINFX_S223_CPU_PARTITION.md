# s223 — CPU partition candidate; exact ledger gate refused (2026-10-22)

## Status

**Implementation compiled; the physical comparison did not pass.** No measured
physical trial was launched and no new CPU bottleneck conclusion is available.
s222 remains the last passed comparison. Six planned natural trials and the
separate fault batch remain unstarted. No game solver or default was changed.

## Implemented candidate

The private cycle sampler supports nested scopes with exclusive self-cycle and
self-wall accounting. Child work is charged to the child category and excluded
from the parent's self totals. The retained whole-window counter and explicit
unclassified remainder prevent silently losing or double-counting work.

The three original categories (submission wrappers, wait, timestamp resolver)
are extended with resource API calls/release, dispatch preparation, readback CPU
processing, selected validation functions, metadata preparation and diagnostic
output. Categories describe instrumented entry points, not universal semantic
coverage. For example `validation` includes the self work of cache completion,
stock checks and retained-witness comparisons, excluding their instrumented
children. `metadata_preparation` covers index activation, reservation/cache
preparation and context configuration. Other caller work remains explicit.

CPU-only normal/reversed controls passed, including three-level nested scopes,
reentrant category use, exception unwinding, call/read counts and cycle sums
bounded by the whole window. The sampler and CPU-control source were identical
in the corrected build, so their original executions are retained, not repeated.
Their original executable hashes are checked against the initial snapshots.
Cycles remain cycles; no seconds conversion or whole-process worker attribution
is claimed. GPU shaders, commands, queries, completion predicates and numerical
criteria are unchanged by the intended instrumentation.

## Preparation failure, preserved separately

The initial stage-name substitution mistakenly changed numeric forcing ID 222
to 223 in a frame template. The first native process refused `frame template
mismatch` before device creation. The initial source, executable, receipt and
failed-batch records are retained under the stage root and `initial_generation/`.

The generator now renames identifiers only, preserving numeric literals. A
separate `corrected/` build and admission batch uses the original numeric
template and all original gates. A Python corrected-directory loader wiring
error was then fixed before any corrected native execution. No failed GPU
observation was retried and no acceptance tolerance was relaxed.

## Actual GPU observation and stop

Corrected trial00, sleep plain, passes the original full prefix oracle.
Corrected trial01, event plain, completes the native nine-interval prefix but
is refused by the external exact-byte audit. Neither trial enables the new
scope sampler. The orchestrator stops at that refusal; it does not retry until
a passing sample is obtained.

Saved-data comparison identifies exactly one differing archived resource:

- archive phase `20022`, adaptive attempt 22;
- stage `f5/flow/39`, output `stepLedger`, resource 1425, shape 1×8×RGBA;
- five FP32 words: indices 17, 19, 21, 22 and 23;
- maximum absolute difference about `1.2733e-11`;
- bit-pattern distances 1, 28, 11, 5 and 4 respectively.

The producer is frozen shader `physical_e929a0330b3950780ab9.cso`, consuming
`txFlowLedger=1422`, `txInventory=1383`, and `txFinish=1423`. The finish decision,
cumulative ledger and checkpoint captured alongside the step ledger match.
The upstream flow-ledger and inventory textures are not in the saved capture;
the data therefore cannot distinguish an upstream variation from a variation
inside this producer. Small magnitude is not a reason to waive the exact gate.

Bootstrap geometry, final bank, stock packets, published stock/ledger text,
owner/phase/recovery/cache traces and retained-metric witness text match the
frozen reference. Native counts remain 9 published /12 accepted, 246 completion
events, 2,260 draws, and peak scoped payload 66,582,496 bytes under66,584,576.
These are not total memory or game performance measurements.

The native solver was **not quarantined** by this discrepancy: it completed
the private prefix, and the external exact audit then refused the result.
Only the orchestrator's stop-before-next-process behavior is established here.
Do not describe this as an in-solver rollback test. The planned injected GPU
fault did not run. This step-ledger difference is not the earlier s208 retained
metric mismatch; a common cause has not been established.

## Next bounded diagnostic

Capture the three actual producer inputs and output at this stage, with explicit
resource admission and lifetime checks. Compare frozen source/consumer identity,
upstream bytes, producer bytes, and published inventories. Preserve this failed
observation, investigate reproducibility/rounding/resource hazards, and keep
the original exact criterion. This is a targeted diagnostic, not a timing retry.
Resume broad performance partitioning only after its admission criterion is met.

## Evidence and audit

Root: `docs/diagnostics/2026-10-22/s223/`.
Corrected observations and refusal audit: `corrected/`.
`audit_s223_refusal.py` verifies saved data without running a GPU trial, checks
source/consumer provenance and initial refused generation, and seals a delivery
explicitly marked `refused_at_exact_intermediate_ledger`. The ordinary full
comparison checker remains refusing; it is not changed to accept this output.

Game physics remains s87. No user game test, game installation, commit or push.
Full event-policy qualification, natural discrepancy causes, physical/optical
accuracy, long duration, total cost and live CSP integration remain open.
