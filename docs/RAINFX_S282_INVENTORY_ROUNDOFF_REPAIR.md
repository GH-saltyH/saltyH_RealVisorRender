# s282 continuous preview: inventory comparison repair

## Actual evidence

The first post-clock-fix report stopped at audited interval160:159 accepted
32Hz intervals account for exactly4.96875s. The old summary lacked reason fields,
so the cause of that particular run remains unclassified. Counters alone did not
justify changing physics or calling this an out-of-memory/throughput failure.

The existing640-byte audit already retained the rejection. It is now displayed in
the same product panel and saved once to
`docs/diagnostics/runtime/rain_product_failure.txt`, independently of the game log
quota. No additional GPU pass, target or readback was introduced. The report is
at most64KiB and writes only on first rejection, outside normal running work.

The next actual report, preserved under
`diagnostics/2026-10-24/s282_refusal/actual_serial326.*`, identified:

- First refused326; joint reason7; source mask32; aggregate status0.
- Source head code/mask0: the source's per-head and aggregate checks passed.
- Source mask32 selects previous ledger stock versus newly reduced old inventory.
- Water is145.2926788330078mm³ on both sides: difference exactly0 in these FP32 words.
- The differing momentum component is0.00015730038285255432 versus
  0.0001572929322719574mm³·m/s: difference7.450580596923828e-9.
- The old128ε relative-to-net bound is4.800313035957515e-9 on that component.
- The ordinary joint water residual is0.00030517578125mm³ on425.8071594238281mm³
  accounted supply. It is inside its existing bound; water closure was not the
  source rejection in this run.

The stock ledger is composed as source final stock plus the transported field's
final-minus-initial packet. The next interval reduces retained heads/film/micro in
a different order. Equivalent signed momentum sums can differ by FP32 rounding,
especially near cancellation. The observed mask and values localize the rejected
comparison. They do not establish which individual native instruction rounded.

## Product-only correction and limits

`docs/runtime/s282/rain_product_inventory.lua` wraps the existing graph and changes
only the inventory-continuity comparison in the source decision, matching
diagnostic mask and source commit helpers:

```
scale.mass = abs(previous stock.mass) + abs(reduced old stock.mass)
scale.momentum = max(abs(previous stock.momentum) + abs(reduced old stock.momentum),
                     sum(abs(previous ledger momentum terms)))
bound = max(scale * 128 * FP32 epsilon, 1e-9)
```

This follows the absolute-ledger-term basis already used by the adjacent closure
checks and the project's game acceptance policy. It avoids treating a nearly zero
signed resultant as the precision scale for all contributing quantities. The
water bound,128ε multiplier, finite/positivity checks, head/state/generation and
ownership checks, closure checks and clocks are unchanged. No stock is clamped,
replaced or rebalanced; no force, mass, velocity or display gain is modified.

The cumulative ledger scale can grow with cumulative exchanges. This is the same
scaling policy used for cumulative closure, not an unlimited absolute tolerance.
It does not qualify long-run momentum/visual accuracy by itself. Existing
per-head, per-cell, ledger and water checks continue to apply. Do not extend this
change to unrelated guards without evidence.

Seven source pass descriptions share the changed helper; two distinct production
programs require recompilation. No pass/target/binding/uniform is added. New cache
keys prevent reuse of an old compiled body. Original prototype files and earlier
strict comparisons remain unchanged; the product wrapper applies once per cached
recipe and is reused.

## Focused validation

- The ordinary product/capture/raster suite passes13groups, including a simulated
  interval160 rejection, single automatic report save, retained input rows and no
  early disposal. It still mocks engine APIs/solver GPU.
- Both changed production programs pass strict FXC compilation with the CSP
  sampler prelude. Resource/pass/input descriptors match the unmodified graph.
- Four native WARP cases accept the observed tiny difference with a cancelling
  ledger fixture, reject injected0.01mm³ water error and0.001mm³·m/s momentum error,
  and accept identity.
- Only the actual stock row, not all eight prior ledger rows, was exported.
  Cancelling contributor rows in that WARP fixture are explicitly synthetic;
  their gross scale is not represented as a captured measurement.

Actual CSP verification of the repair is pending. One continued visible-product
run is requested; there is no new diagnostic app or weather/FPS matrix. If the
same source mask persists, read the automatically preserved record first rather
than increasing tolerance again or starting a broad experiment program.

## Actual follow-up

The next user report maintained running and visible drops/film through11618
accepted32Hz intervals (derived363.0625s), then stopped on CPU input
`entry_capacity`. That is actual follow-up evidence for this comparison repair
and optical continuity; it does not validate the later input recovery change or
FPS. See [bounded input recovery](RAINFX_S282_BOUNDED_INPUT_RECOVERY.md).
