# s162 — packed End/Mean outputs and checked direct resume

2026-10-19. Offline candidate; production physics remains s87 and diagnostics
s89. No main app, settings, production shader or game installation changes.

## Output and input contracts

The final two W×H selectors become one W×2H RGBA32F output. Rows [0,H)
contain End stock and rows [H,2H) contain interval Mean stock. Channels retain
the existing `(volume mm³, volume × world velocity mm³·m/s)` meaning. Both
logical roots share one physical backing ID; `rootViews` is mandatory to
interpret them. A numeric backing root alone is not a logical H-row texture.
The explicit layout is `packed_end_mean_v1`, with single mip and full-width
integer row bands. No formula, physical threshold or numerical tolerance changes.

`s162_outputs.consumer` validates all descriptor members, including unknown
keys, format, extent and row containment. The GPU consumer checks the physical
parent dimensions, logical coordinate bounds and mip zero. Logical out-of-range
reads return zero instead of entering the adjacent band. Malformed physical
dimensions return a finite negative-volume marker. It is never publishable stock.

`s162_transport.recipe(..., inputLayout)` accepts `film_v1` (default W×H input)
or `packed_end_mean_v1` (W×2H input). Every consumer of immutable film import1
uses the checked End-band reader. The Mean band never enters the next stock.
All imports and shared physical roots keep their leases. No extraction or
compatibility-copy pass is added to the recipe. Diagnostic consumer draws in
the verification harness are counted separately from the recipe's pass count.

Successful output reads the existing recipient post End/Mean. On refusal, both
output bands restore the original End stock, as the two old selectors did.
Checkpoint, ledger and interval debt remain unchanged. A malformed backing
shape is refused with finite private error output; it cannot restore missing
input rows and must not be published or treated as an accepted rollback stock.

## Verification

- 29 paired s161/s162 graph cases:15 accepted,14 refused. All non-injected
  physical roots **and ledgers** are bit-identical, including actual-grid packed
  resume. Existing packet and cumulative closure gates remain unchanged.
- Actual1024×256 geometry/physical context at frozen frame660,4096 empty head
  slots, controlled1µm film and0.1µm pinned micro. Includes both axis orders,
  dry/static cases, physical resume, ragged supports, pinned nonempty heads,
  evaporation, viscosity, malformed history/debt/material and injected failures.
- A distinct123.25 Mean-band sentinel cannot enter moving/dry resume End stock.
  Both bands restore End on refused packed input. Eight existing recipe refusals
  and nine descriptor/layout refusals pass. Two signed sentinel images, eight
  whole-band boundary offsets, four invalid mip cases and wrong parent shapes
  exercise the standalone GPU consumer.
- Separate targeted checks refuse malformed parent dimensions for dry and wet
  inputs. A valid first interval followed by an injected failed packed resume
  preserves water/debt; retrying its rollback bank matches uninterrupted resume
  in every root, bit for bit.

Whole-graph harness:2,428 WARP draws /37 strict shader bodies. Targeted resume:
240 draws /26 strict bodies. Total2,668 draws /63 compilations, including121
diagnostic band-consumer draws. Final `/WX /Ges` builds are warning-free. The
initial signed-modulus compiler warning was fixed by unsigned row arithmetic;
warnings were not suppressed. Old evidence was not regenerated.

These tests use serialized native upload/readback. They do not establish CSP
submission order, general completion, actual target timing, continuous weather,
head/birth evolution, or thick/high-Courant accuracy. Empty4096 slots test
capacity, not4096 active drops.

## Cost and the remaining recurrent-input cost

Actual1024×256 /4096-slot descriptors; MiB=2²⁰ bytes:

| Measure | s161 H-row input | s162 H-row input | s162 packed resume |
| --- | ---: | ---: | ---: |
| Passes /resources including11 imports |48 /59 |47 /58 |47 /58 |
| Separately retained graph |77.8440 |77.8440 |81.8440 |
| Static last-read frontier |48.8288 |48.8288 |52.8288 |
| Static frontier plus retained cache |61.2280 |61.2280 |65.2280 |
| Proposed exact-shape graph reservation |53.8280 |49.8280 |53.8280 |
| Proposed reservation plus retained cache |66.2272 |62.2272 |66.2272 |

Packing removes one pass and one resource, but not output bytes or fragment
count. The proposed fresh-input pool reuses an existing2H-shaped slot, avoiding
one4MiB H-shaped reservation:36→35 private slots. This is an analysis of exact
shapes and lifetimes, not an executed pool or a measured memory/FPS improvement.

Direct recurrent input retains the entire previous2H bank, including its Mean
half, even though only End is consumed. That costs4MiB above an H-row input.
It cancels the fresh-input saving: **recurrent pool plus retained cache is still
66.2272MiB**,2.2272MiB above64MiB. Even its static cache-inclusive frontier is
65.2280MiB. The recurrent64MiB gate therefore remains open. Neither the ignored
Mean rows nor immutable input leases are silently discounted.

Late status diagnostics raise the resume proposal to66.2428MiB; additionally
pinning donor force/exchange raises it to74.2428MiB. Full separate retained
graph plus cache is90.2432MiB fresh and94.2432MiB on packed resume. Source-image
caches, driver costs and active head/birth evolution remain excluded.

## Next

Reduce the recurrent retained reservation by at least2.2272MiB while preserving
immutable input leases, row-band semantics and refusal/debt behavior. Evaluate
the cost of an End-only handoff against another bounded graph/cache reduction;
an extra copy is not automatically a net saving. Then execute the selected
native pool with verified submission/completion and recurrent cache/output
ownership. Actual main-app solver adoption, common optics and measured game
performance follow those gates. No new user game test is needed for s162.

Evidence: `docs/diagnostics/2026-10-19/s162/lean_checks.json`,
`resume_checks.json`, `cost_checks.json`, `lifetime_plan.json`, both harnesses,
`layouts.json`, `packed_resume_layout.json`, `results.npz` and `delivery.json`.
