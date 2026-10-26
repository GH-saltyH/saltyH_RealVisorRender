# s224 — captured producer inputs and output (2026-10-22)

## Result

The capture implementation passes four bounded native runs in the planned
event / sleep / sleep / event order. All three inputs and the output match
bitwise across these runs. Every captured output matches the independent
source-relation check and the original frozen archive, bank, stock, clock,
queue/debt and ownership oracles. **The original s223 discrepancy did not
reproduce; its cause is not established or declared fixed.**

No further timing trial or performance-policy adoption is justified by this
result. These are targeted captures, not application FPS or live solver tests.

## Capture contract

At frame5, adaptive attempt22, step1489, before output1425 is drawn, snapshot
the actual resources bound as `txFlowLedger=1422`, `txInventory=1383` and
`txFinish=1423`. Snapshot output1425 immediately after its draw, before any
scheduled reuse of that backing. Source/output identities and extents are
validated. Same-context copy ordering protects each immutable staging copy;
retained source owners and staging snapshots survive until the existing phase
completion. Mapping requires the existing event observation and `flight=false`.
All extra leases are returned before the next phase reservation.

Four staging textures contain **320 bytes of logical payload**, capped exactly:
128+48+16+128. This excludes driver allocation granularity, row pitch and object
overhead; it is not a claim of320 bytes of total VRAM. The default-texture
payload cap is unchanged. Each run adds four raw CopyResource commands and four
CPU readbacks, with no additional timestamp query, completion event or shader
draw. Copies can perturb timing/reproducibility, so non-reproduction under
capture is not proof that the uncaptured path is correct.

The original physical counts remain246 completion events and2260 draws,
9 published /12 accepted intervals with queue[9,10,11]. Scoped default payload
peaks at66,582,496 bytes under66,584,576. Capture staging is reported separately.

## Independent relation check

The source for output1425 reads the flow-ledger rows directly when the finish
decision is ready; only rows0 and1 add inventory row1. For rows2..7 the expected
output is an exact copy of input1422. The CPU check uses the captured values,
FP32 addition for the first two rows, and bitwise comparison of all32 words.
Output1425 must also match the copy already in the original physical audit.
The ready/refused branches and32 individual output-bit mutations are checked
with synthetic CPU controls. These are not injected GPU-fault experiments.

All four runs pass the original exact prefix oracle, including intermediate
`run.audit.bin`; no tolerance is relaxed. There are no input/output differences
between the four captured sets. The original failed s223 inputs were not saved,
so this cannot retrospectively determine where its five differing values arose.

## Source chain and next target

Saved graph and HLSL/CSO hashes identify this conditional source chain:

1. Output1425 copies changed rows4/5 from1422.
2. With commit kind3 and a ready decision,1422 copies1421.
3. Producer1421 computes recipient ledger1420, adding donor exchange1402 row0
   to row4 and donor row1 to row5.

That last arithmetic site corresponds to the rows that differed in s223. It is
an investigation candidate, not a confirmed point of divergence. Resource or
binding hazards and earlier-input differences are not excluded. The source
trace is recorded separately in `upstream_trace.json` and re-audited at seal.

Next capture donor1402, recipient1420, readiness1417 and combined output1421,
alongside the present capture. The graph-derived total logical staging payload
would be624 bytes. Compare each actual addition and copy boundary before
resuming broad CPU partitioning. Do not alter numeric acceptance or claim the
s208 retained-metric issue shares this cause.

## Validation adapter correction

The first GPU run completed successfully, but its Python checker clone omitted
the inherited `control=False` default. The original TypeError and stopped batch
remain in `capture_batch.json`. The continuation restores only that default,
re-audits the same native files and then executes the remaining three planned
cases. No first-case GPU rerun, native rebuild or numerical gate change occurs.
The revalidated batch is stored separately as `qualified_capture_batch.json`.

## Delivery

Evidence: `docs/diagnostics/2026-10-22/s224/`.
Tools: build → run → default-argument validation continuation; the saved-only
`finalize_s224_capture.py` audits captures and source trace and seals delivery.
Use the finalizer for repeat audits; do not rerun fresh-build/launch entry points
against this sealed directory. Original s223 failure evidence and older sources
are preserved. Main app/settings/shaders and Git HEAD remain unchanged; only
the documentation index and roadmap are updated. Game physics remains s87.
No game installation, commit/push or user game test is requested.
