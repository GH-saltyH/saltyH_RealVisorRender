# P0 serial156 near-start fault — 2026-10-25

## Actual evidence

User reported that P0 stopped shortly after continuous start. The retained
report is serial156,4.84375s advanced, reason64, sourceMask0/context0/head0.
Source admission and current-stock checks passed. Frozen field/head/ledger are
consistent at191.272213/191.272217mm³. There is no evidence of this water being
lost from the authoritative old stock.

Source totals for the next step contain191.266510mm³ remaining water. The final
receipt instead reports zero stock, and cumulative exits unchanged at the old
353.438232mm³. This is not a shader startup timeout, queue overload or the old
source closure fault. Previous overload reports in the runtime folder belong to
different runs and are not evidence for this failure.

Original inputs, frozen DDS and pre-change pool/diagnostic/deposit modules are
preserved under `diagnostics/2026-10-25/joint156/`.

## Bounded local reproduction

The actual old cumulative source-commit shader with correctly bound retained
totals computes the correct next ledger on WARP. The new specialized shader
produces bit-identical output. Passing zero `txTotals` into the old cumulative
commit reproduces the **full16-word actual failed receipt**, including the old
exit sum and reason64. A zero stock injection only at the final ledger did not
match the recorded exit sum; that narrower hypothesis was rejected.

This localizes the observed failure signature to source-total delivery/consumption
at cumulative commit, or equivalent corruption before final ledger consumption.
It does not prove why CSP returned those values: native software replay cannot
establish a specific CSP binding bug, driver defect or dispatch-order fault.

## Candidate implementation

Source commits previously used a uniform `gKind` over one broad shader/input
schema. Regional pool return expanded that schema to15 textures. This exceeds
the earlier deliberately used14-input margin, although it is below the nominal
16-input ceiling. Strict FXC compilation alone did not qualify that CSP path.

The six commit modes are fixed topology; they do not change within a pass.
`rain_product_pool.lua` now specializes `gKind` to a literal and assigns a unique
cache key/schema per mode. It binds only the inputs each mode consumes. Dead
helper texture declarations remain parseable and are eliminated by the compiler.

| Commit | Bound inputs now |
| --- | ---: |
| Film/micro |9 each |
| Head packets |3 |
| Step ledger |2 |
| Cumulative ledger |3 |
| Checkpoint |4 |

Maximum among changed source/pool programs is12, including non-commit passes.
No new canvases, passes, readbacks or gates. Water, source model, motion and
comparison tolerances are unchanged. The final receipt still rejects actual
wrong quantities; it is not filled from a synthetic water summary.

## Validation and remaining uncertainty

- Retained-failure replay:7 WARP draws,4 programs; correct old/new commit outputs
  bit-equal, final copy and receipt accepted, zero-total failure fully reproduced,
  meaningful mass corruption still refused.
- Regional pool checker:9 native draws,7 changed production programs strict-compile,
  actual source admission and closure pass; first/cached recipe variants pass.
- Product regression:13 groups and8 native optical draws pass; actual host and
  engine adapter calls in lifecycle tests remain mocked.

The fix is connected to the same P0 and shared game runtime. **Actual CSP repair
is pending ordinary use**, not declared confirmed. There is no new standalone
probe, tolerance study or long-run matrix. Reload the main app before applying
the changed commit schemas. If the same path fails, retain the new report before
reloading; current failure snapshots must not be confused with preserved156.

This runtime blocker takes priority over local absorption/coalescence. Current
visual-quality failures remain open even if the execution fix succeeds.
