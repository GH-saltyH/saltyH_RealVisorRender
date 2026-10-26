# s225 — donor/recipient addition and propagation capture (2026-10-22)

## Result and decision

Four planned event / sleep / sleep / event runs pass all three captured
boundary relations and the original exact physical-prefix oracle. The eight
captured resources are bit-identical across the four runs. **The original s223
five-word difference did not reproduce and is not declared fixed.**

This validates the addition and copies for the observed input sets, not general
reproducibility, resource-hazard freedom, performance or game integration.
Repeating full prefixes until another difference appears is not the next step.
Next isolate the frozen arithmetic shaders using immutable captured inputs and
an independent CPU oracle in a small bounded GPU replay. Preserve the original
s223 refusal and gate; this cannot recover its missing input textures.

## Actual captured boundaries

At frame5 / adaptive attempt22, one existing phase contains three producers:

| Boundary | Captured inputs | Captured output | Check |
| --- | --- | --- | --- |
| Step1485, addition | donor1402, recipient1420, readiness1417 | combined1421 | Ready rows4/5 add donor rows0/1; other rows copy recipient |
| Step1486, commit | prior combined1421 and readiness1417 | committed1422 | Commit-kind3 copies combined ledger when ready |
| Step1489, terminal | prior committed1422, inventory1383, finish1423 | final1425 | Ready rows0/1 add inventory row1; rows2..7 copy committed ledger |

Each input snapshot precedes the relevant producer; each output snapshot is
queued immediately after its producer, before scheduled backing reuse. Logical
IDs, resource extents, texture binding maps, order and commit-kind3 are asserted.
Previously captured values used by downstream producers rely on the same
immutable logical lifetime; comparison across boundaries also checks that value
propagation agrees with those snapshots. It does not prove the old failed run
had the same inputs or resource state.

All eight copies are read after the existing phase completion with `flight=false`
and observed GPU completion. Staging snapshots and source owners are retained
until then, and extra ownership is cleared before the next phase reservation.
No extra completion event, timestamp query or shader draw is introduced.

Eight staging payloads total624 bytes:32+128+16+128+128+48+16+128. This is a
logical payload bound, not total VRAM; driver object/row-pitch/allocation overhead
is excluded. The native default-texture cap remains unchanged. Every run adds
eight raw CopyResource commands and eight CPU maps. Such observations can alter
timing/resource placement, so non-reproduction under capture is not a fix.

## Independent checks

CPU expectations use captured inputs, explicit FP32 addition at rows4/5 and
rows0/1, and bit-exact copy expectations at the commit boundary. Each boundary
is checked against its own actual inputs instead of replacing an earlier wrong
output with an expected value. A future failure can therefore identify the
first observed relation that fails. The final captured ledger must also match
the existing intermediate archive.

Synthetic CPU controls cover ready/refused branches and unchanged addition
rows;96 single-word output-bit mutations (32 at each boundary) are rejected.
These are checker controls, not GPU fault injection or GPU completion controls.

The four physical runs retain original archive/bank/stock bits and all original
clock/debt/queue/ownership checks:9 published /12 accepted intervals, queue
[9,10,11],246 completion events and2260 draws. Scoped default payload peaks
at66,582,496 bytes under66,584,576; capture staging is accounted separately.
No failed numerical run is retried and no numerical tolerance is changed.

## What remains unknown

Donor, recipient, readiness, combined, committed, inventory, finish and terminal
bytes all match between these four observations. There is consequently no
observed upstream or addition divergence to classify in s225. Neither the
original s223 inputs nor the cause of that difference are available here.
The earlier s208 retained-metric discrepancy is also not explained by this work.

The next small replay should use the frozen CSOs and exact captured inputs,
check arithmetic and propagation repeatedly within a fixed bound, and include
refused readiness and fault controls. Its results must stay separate from full
pipeline/release qualification. Broad CPU partitioning, event-policy adoption,
physical accuracy, optics, long duration and live CSP integration remain open.

## Build preparation and delivery

Before any native GPU run, strict compilation rejected a new helper's local
`count` hiding an inherited member. The local is renamed `requiredSnapshots`;
the original source and raw compiler report are retained. The build wrapper now
saves raw output bytes, avoiding the diagnostic decoder failure. Both policy
consumers then compile with `/W4 /WX /O2 /fp:strict` and all four planned runs
complete. These are build-only corrections, not GPU retries.

Evidence: `docs/diagnostics/2026-10-22/s225/`. The stage-local builder, runner and
`check_s225_chain.py` provide frozen-source provenance, bounded execution and a
saved-data audit/seal. Repeat saved audits do not run a GPU experiment. Older
source/settings/main app and Git HEAD are preserved; only index/roadmap change.
No game installation, commit/push or user game test. Game physics remains s87.
