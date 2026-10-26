# s157 — field-only inputs and actual-grid continuation

Status: ACTIVE — offline cache parity and actual-grid continuation passed
Date: 2026-10-19

## Implemented

s157 reduces owned field input copies and removes the fixed13×7 dimensions
from the complete film continuation recipe. It runs the existing force,
two-axis transport, recipient/ledger and retained-time operators at1024×256.
The physical equations, material coefficients and acceptance bounds are unchanged.
No production app, shader, setting or historical prototype was edited. These
new recipes are uninstalled; game physics remains s87 with s89 diagnostics.

## Field-only input profile

The world-field builder reads the2048×512 du/dv textures only at integer
coordinates `(2x+1, 2y+1)` for each1024×256 field cell. A new owned-input profile
copies those exact RGBA point values into1024×256 textures. It does not average,
filter or rescale the derivatives: they remain metres per UV, independent of
the copied texture dimensions. The1024×256 cell-area input is copied unchanged.

Three full-copy comparisons pass bit-for-bit against independent source slices.
Every component of the derived world metric, area and connected-run cache is
also bit-identical to the s155 reconstruction of actual main-app frame660.
Original file hashes still identify the source geometry; numerical fingerprints
describe the cropped owned data. Source and destination dimensions are separate.

This profile is restricted to `1024x256_field_point_centres_only`. It is not a
full-resolution input for head consumers or arbitrary UV sampling. A wrong scope
is refused before allocation. The diagnostic owner retains its submitted inputs,
read lease and derived targets for the session, as before. There is no new
release/reuse rule or claim of general GPU completion.

## Parameterized continuation

`s157_core` derives axis lanes, rows, reduction leaves/groups, bank row origins
and target extents from W,H. Supported bounds are W1…1024 and H1…256; the source
status atlas also checks that field rows plus head rows fit4096. Order1 is Y→X;
order2 is X→Y. The existing corrected transport bodies and bank ABI are reused.

The derived interval, physical-source, compact-force and source-applied
continuation recipes use those dimensions consistently. End/Mean extraction,
error decoding, cumulative ledger and private checkpoint behavior are preserved.
Descriptor accounting now includes every import and private output. The existing
256MiB offline candidate cap and96-resource cap are unchanged; they are not an
increase to the64MiB live owner budget.

## Verification

### Owned cache:34 WARP draws /11 strict shader compilations

Nineteen controller cases cover readiness, unknown/read errors, corrupt output,
padding/nonfinite values, cancellation, repeated callbacks, stale inputs,
topology and shape failures, plus the WARP run. The additional domain refusal
allocates no canvas. The successful34-pass bundle retains34 canvases and
33,973,008 nominal bytes. GPU disposal remains zero.

### Complete continuation:844 WARP draws /31 strict shader compilations

Twelve graph executions cover:

- Original and parameterized13×7 graphs in both axis orders: all imports and
  intermediate results match bit-for-bit, not just final stock.
- 273×17 moving planar fields in both orders: ragged leaves and multiple
  reduction groups are exercised.
- Actual1024×256 geometry: dry, static film, physical thin film in both orders,
  wrong retained debt, and a second physical quarter using the first result's
  stock, cumulative ledger and remaining debt.

Eleven executions accept. Wrong debt refuses with exact stock/history/checkpoint
rollback. Six invalid shape/capacity requests refuse during CPU recipe creation.
The actual-grid graphs contain73 passes and84 resources; maximum bindings stay
within32 textures. Source already applied to the interval is never replayed.

The actual-grid physical fixtures use the captured frame660 gravity, air,
material and evaporation rows with its frozen dt0.016877174377441406s. Initial
film is a controlled1µm and pinned micro is0.1µm, with zero initial momentum and
4096 **empty** head slots. These are test inventories, not observed game water
stock or4096 active droplets. This stage does not execute birth/SI-head evolution.

After the first quarter the remaining debt is0.012657880783081055s; after a
second physical quarter it is0.008438587188720703s. Mass closure residual is
about−6.08e−7mm³ after the first Y→X quarter and2.60e−6mm³ after the second.
All mass/momentum components pass the unchanged128-float-epsilon accumulated
closure bound with its1e−9 floor. No public clock or live inventory is published.

Total:878 WARP draws and42 strict compilations across two harnesses. These are
verification counts, not runtime pass counts or target GPU timing. WARP uses
serialized upload/readback between draws. The low-displacement thin-film cases
do not establish thick/high-Courant sheet accuracy, large-dt behavior, changing
weather recurrence, full head/film interaction or long-run stability.

## Resource result

| Nominal descriptor budget | Before | s157 |
| --- | ---: | ---: |
| Owned du/dv/cells input copies |36MiB |12MiB |
| Retained world-field diagnostic bundle |56.5874MiB |32.3992MiB |
| Field bundle +4MiB stock + compact force scratch |68.6032MiB |44.4150MiB |
| Complete actual-grid reference continuation | Previously small-field only |199.9678MiB |
| Field bundle + full continuation, shared world imports counted once | — |212.3670MiB |

The field bundle saves24.1882MiB, including24MiB in du/dv and smaller fingerprint
intermediates. Its isolated force branch now fits64MiB by descriptor accounting.
The complete reference continuation still exceeds that budget: it owns both
logical/bank comparison branches and their intermediates. It is not admitted as
a live solver. A static last-read frontier of93.2663MiB is only a diagnostic
liveness calculation; it proves neither GPU completion nor safe buffer reuse.

These counts exclude the original source-image cache, driver overhead and
birth/head pipeline. No target GPU timing, FPS improvement or live residency
measurement is claimed. No game allocation was added by s157.

## Next step

Build a lean actual-grid continuation candidate: select the production bank
branch and remove comparison/unconsumed outputs while preserving status,
rollback, source-once, cumulative closure and retained-time semantics. Measure
its descriptors before connecting it to a native backend. Do not raise the
owner limit or reuse targets based solely on static last-read analysis.

Then establish bounded resource lifetime/completion and continuous inventory
authority, connect head/birth/field evolution and common optics, and measure
target GPU/CPU cost and warm-run behavior. No additional user game test is
requested for s157.

Evidence: `docs/diagnostics/2026-10-19/s157/field_checks.json`,
`transport_checks.json`, `cost_checks.json`, `layouts.json`, both result archives
and `delivery.json`.
