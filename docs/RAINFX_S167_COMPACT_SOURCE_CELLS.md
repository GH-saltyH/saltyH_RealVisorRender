# s167 — source cells without the seven-band atlas

Date: 2026-10-19. Status: ACTIVE (offline source/native reference).

## Change

The source stage no longer materializes the7H cell atlas containing next film,
micro, wall reaction, runoff, raw incoming packets, pool debit and status.
`sourceCell()` contains the same extracted expressions. Tiled status, tiled
totals and final film/micro commit evaluate these expressions directly.

The full field/head status image is also removed. Its first16×16 max reduction
now reads cell validation and source-head status directly, then uses the existing
remaining reduction levels. Nonfinite status still refuses. Summation ordering,
ledger admission, pool ownership/debit, coverage, off-domain rejection, original
inventory rollback and previous-token/phase checks remain unchanged.

Sources,96-slot bin masks, word summaries and the two-band sparse gather retain
the original s144 shader bodies. The expensive sparse gather is not duplicated.
Only the six transaction outputs and decision are mandatory roots. An explicit
offline diagnostic option exposes raster/source/status/totals for comparison;
there is no7H diagnostic allocation in either mode.

This exchanges large writes/reads for recomputing the inexpensive cell equations
in three consumers. Tiny context/stock/raster loads and cell arithmetic repeat.
Target-device ALU/cache cost and FPS have not been measured; fewer bytes and
passes alone do not establish a frame-time improvement.

## Full-resolution source allocation

| Native source stage,1024×256 /4096 slots | Original | Compact |
| --- | ---: | ---: |
| Shader passes |19 |17 |
| Default-texture descriptor peak, cache included |96,754,784 bytes |63,134,816 bytes |
| MiB |92.272552 |**60.210052** |
| Execution cap |256MiB reference |64MiB |
| Audit staging, separately charged |76,006,576 bytes |37,553,136 bytes |

The saving is **33,619,968 bytes =32.0625MiB**:28MiB for7H staging plus
4.0625MiB for the full1024×260 status image. The small reduced status was already
present and remains. There are3,974,048 bytes (3.789948MiB) below the source-only
64MiB cap. Native capacity preflight enforces the compact cap before submission.
The legacy reference retains its separate256MiB comparison limit.

Both runs also create and retain all34 existing world-cache descriptors:
30,827,280 bytes. In this test those allocations are reservation placeholders;
their contents are not sampled or claimed verified. Source inputs/candidate
buffers are additional allocations and are fully charged. Driver objects,
constant buffers, shader storage, CPU fixtures, audit staging and actual hardware
residency are outside the descriptor cap.

The full-resolution fixture pads the preserved s144 full field to4096 slots,
puts a real incoming packet at4095, and restamps the declared pool ownership tick
for that capacity. All packet sums are preserved. Only the original few slots
contain water: this is a sparse source/capacity test, not4096 active heads or dense
storm throughput. The field is synthetic planar support; it is not an evolving
actual-mesh/weather/normal simulation. No new physical producer law is introduced.

## Correctness results

- 24 preserved small source cases:5 admitted and19 refused. They include coverage,
  masked/off-domain water, missing receipt, wrong frame/shape, stale token,
  source reapplication, pool ownership/funding, original-head/history mismatch,
  unresolved support and interior-mask-loss detection.
- The original and compact full-resolution source graphs both admit. All seven
  public roots—film, micro, heads, step/cumulative ledger, checkpoint and
  decision—are bit-identical, including the last-slot incident.
- Every small public root is also bit-identical to the preserved reference.
  Refused cases retain input inventory/checkpoint/ledger exactly and zero the
  step ledger. The interior-mask fault is injected into the test bin shader;
  it is not a production change.
- Independent double-precision raster/packet and unchanged32ε /1e−9 per-cell gates
  pass; cumulative water/momentum uses the existing128ε /1e−9 bound. No numerical
  bound was widened. Full-field maximum film error remains2.79e−9mm³; ledger
  error2.11e−8 in packet units, the same as the original graph.

The compact source is then placed in s166's native birth→SI heads→source→packed
film→four transport quarters→eight inventory copies chain. Both separate and
pooled runs commit three source-on/off/on frames. All source public roots,
downstream physical outputs, ledgers, checkpoint debt, refusal decisions and
48 inventory copies match s166 bytes. Failed source completion retries still
match; three replay controls per run still refuse. Cumulative incoming water is
1.150346518 →1.150346518 →2.300693035mm³; committed time0.046875s per run.

Each chain runs604 draws rather than618: two passes saved on each of the seven
source executions (normal frames, failed attempt and replay controls). Combined
chain totals:1,208 draws,62 native events,48 inventory copies and594 immutable
input comparisons. The24 small standalone cases use312 draws; the two full
resolution references use36, giving **1,556 draws /88 real native events** total.
The55 used synthetic shader bodies include50 byte-verified preceding strict
compilations and five new strict warning-free bodies. All native runs have the
debug layer enabled and no final warnings/errors.

## Limits and next implementation

The60.21MiB result closes the **source-only plus reserved-cache** gate. It does
not include a simultaneously retained actual-resolution head/birth pipeline,
transport pool, old/new raw inventory, queue/cache replacement or common optics.
Those allocations cannot be inferred to fit from two independently passing
stage peaks. The complete pipeline64MiB gate remains open.

Next build a joint source/head/transport lifetime plan at full resolution,
accounting for End-only versus packed views, raw-state banks and every reader.
Retire source diagnostics/inputs only after verified last use and completion;
evaluate any required shared/scalar input adapters before native joint execution.
Then compose with the bounded frame/cache boundary and evaluate curved feedback,
actual CSP ownership/completion, common optics and measured warm device cost.

Current game physics remains s87 and diagnostics s89. Main app, production
shaders, settings and installation are unchanged. The prototypes are offline;
native events are not CSP Canvas fences. No new game test is requested.

Evidence: `docs/diagnostics/2026-10-19/s167/source_checks.json`, source/pipeline
layouts, full-resolution fixture, strict build receipts, native payloads/traces,
`source.diff`, archived binaries and `delivery.json`. Older tools were used only
through their pure helpers; their builders/checkers/finalizers were not run.
