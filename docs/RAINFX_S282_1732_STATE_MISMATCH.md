# s282 interval1732: stock mismatch remains under investigation

The input staging queue was empty in the new game report. This is a source
admission rejection, not a recurrence of the input burst failure:

```
submitted1736; audited1732; pending4; advanced54.09375s
source mask288 =32(previous stock comparison)+256(new cumulative closure)
aggregate/head status0; reason7
```

The exact retained report is preserved under
`diagnostics/2026-10-24/s282_1732/actual.*`. Its old-stock values are:

| Component | Fresh reduction total0 | Previous stock ledger | Difference ledger−total0 |
|---|---:|---:|---:|
|Water mm³|1357.528076171875|1357.52783203125|−0.000244140625|
|X momentum mm³·m/s|2.1778626441955566|0.9589716792106628|−1.2188909649848938|
|Y momentum|−1.3879061937332153|−1.3879066705703735|−4.76837158203125e−7|
|Z momentum|0.2675406038761139|0.26754099130630493|3.8743019104003906e−7|

The water difference is below its existing bound. The X difference is materially
larger than the earlier7.45e−9 example, and new cumulative closure also rejects.
No additional tolerance increase, stock rebalance or physics change is justified
from these aggregate numbers alone. Dividing X difference by current water gives
about0.9mm/s volume-weighted mean velocity difference; this normalization does not
establish per-drop error or prove that either aggregate is the accurate one.

The remaining alternatives include cancellation in signed head/field reductions,
or an incorrect stock composition/transfer. The640-byte record has aggregate
values but not the canonical leaf packets or all previous ledger rows. Replaying
one input snapshot cannot reconstruct the preceding1731 dynamic states. Do not
start a large offline simulation campaign or relax unrelated guards on that basis.

## One failure-only canonical export

The existing product runtime now exposes retained roots only after its first GPU
rejection and cancellation. The first rejected serial identifies its old bank.
Already submitted refused suffixes select the old committed values, and no new
solver submission is allowed after cancellation. This is a resource-specific
frozen-value contract, not a general GPU completion claim.

The host requests the documented `ExtraCanvas:save(...,ac.ImageFormat.ZippedDDS)`
for film, micro, physical heads, raw state/meta, ledger, pose and both receipts.
These are existing retained canvases. Export happens once only on failure, with
fixed filenames under `docs/diagnostics/runtime/frozen_current`. At4096 heads the
uncompressed payload is about8.2MiB. Native save involves additional GPU→CPU data
transfer and background compression/I/O on that failure path; it is not free.
There are no new solver passes, retained GPU canvases or ordinary-running exports.

The offline reader `docs/tools/read_frozen_product.py` verifies ZIP completeness,
native RGBA32F DDS, dimensions, timestamp freshness, head/meta volume consistency,
receipt prefix time and equality with the recorded ledger stock. It refuses
quantized or mixed-epoch data. Then it computes FP64 signed/gross leaf sums,
canonical stock, ledger closure and largest momentum packets/velocities. This
separates reduction conditioning from stock-transfer corruption using one capsule.

The decoded-source summaries8/9 in the earlier640-byte trace are deposition
totals, not old/new whole-field stock. Do not interpret those rows as canonical
field inventory.

## Evidence and work limit

The product regression passes13groups with mocked engine/GPU, including no export
during normal running and exactly9native save requests on a retained rejection.
Synthetic ZIP/DDS round-trip, double reduction, mixed-stock rejection and RGBA16F
rejection pass; existing native float geometry/film assets decode successfully.
The original validation above preceded the actual capsule. Subsequent evidence
and the remaining limits are recorded below.

One further existing-product run was requested to obtain this failure-only
capsule. No separate probe app, weather matrix or performance experiment was
added. Once data arrives, analyse it before choosing a repair. The25–60minute
stage budget and two-approach limit remain applicable; do not generate an open-ended
sequence of new probes.

## Actual capsule and bounded investigation outcome

The later failure at serial10170 supplied nine native RGBA32F ZIP/DDS files.
Freshness, receipt prefix, ledger identity, dimensions and leaf packet checks
passed. FP64 leaf inventory agrees with the old reduced stock: water3094.0484263
versus3094.048584 mm3, signed X momentum0.00007111424 versus0.00007110584.
This validates the captured old stock; it does not prove the failed source-step
closure (mask64) or explain the earlier serial1732 X discrepancy of1.21889.
Evidence: `diagnostics/2026-10-24/s282_1732/capsule_10170/analysis.json`.

One native54-draw source-prefix replay failed a different context guard (323),
so it did not reproduce the actual CSP failure. It is not evidence for a physics
repair. The initial60-minute investigation budget was reached and the work was
replanned rather than expanding replay scope or relaxing conservation tolerances.

Unused words in the existing160-float/640-byte audit now preserve all8 previous
ledger rows and11 source totals on refusal, with version marker in row30. Existing
receipt/diagnostic rows,7 bindings, draw/readback count and payload size are
unchanged. Native layout validation passed2 draws; actual extended failure data
is pending. The next ordinary product failure can supply it without a separate
requested experiment. Source64/288 remains unresolved.

The reported sustained2FPS background overload is a separate throughput problem.
The explicit [background pause](RAINFX_S282_BACKGROUND_SUSPENSION.md) addresses
that condition without changing source gates. It is locally tested, not yet
verified in CSP. No new long game run is requested as part of this delivery.
