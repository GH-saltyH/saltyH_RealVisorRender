# s282 source12810: outside-deposition momentum cancellation

2026-10-25 (Asia/Seoul). The reported new session stayed running for more than
300 stationary seconds, then refused shortly after driving. Its accepted prefix
is400.28125s,12810 audited submissions, four pending, no input staging and no
staging recovery. Source mask8 identifies outside-deposition packet validity/cap,
not a queue overflow or closure64/288. The9 native frozen stock files validate.

## Recorded evidence

|Quantity|Value|
|---|---|
|Source water / raster water|6.688035011291504 /6.688035011291504 mm3|
|Source Z momentum|0.00546138733625412 mm3 m/s|
|Raster Z momentum|0.005460934713482857 mm3 m/s|
|Remainder Z momentum|0.00000045262277126312256 mm3 m/s|
|Existing Z comparison bound|0.00000016666140822962916 mm3 m/s|
|Water remainder / authorized edge water|0 /0 mm3|

Inventory, single-step, prior cumulative and new cumulative closure all pass in
the recorded mask and written-order reconstruction. The outside packet has zero
water and a nonzero Z momentum, which is invalid. The existing rounding clamp
uses absolute *net sums*. Opposite signed momentum can make that scale too small.
This establishes a cancellation-sensitive comparison; the original run did not
record leaf absolute momentum, so its correct numerical bound cannot be measured
retrospectively. Driving coincides with this failure, but no independent motion
or direction defect is established by that timing alone.

## Product amendment

`rain_product_deposition.lua` reuses source total row10 YZW for the sum of absolute
momentum contributions from the three source packet types and both raster layers.
Its R channel retains exactly the existing authorized edge-water cap. The existing
compensated reduction carries these positive values through the same passes.
The outside comparison uses the larger of the existing net scale and this current
leaf absolute scale, with the original128-epsilon multiplier and1e-9 floor.

Water bounds, the edge cap, source packets, physical stock and all other ledger
bounds are unchanged. A zero-water remainder is cleared only if **every** component
fits its numerical bound; significant pure momentum and missing water still
reject. This does not add momentum to the wall bucket or invent escaped water.
It does not widen a scale using accumulated historical force terms.

There are no added GPU passes, textures, bindings or readbacks. The extra raster
absolute sum reads two existing RGBA32F texels per1024x256 cell: up to8MiB logical
reads/step,256MiB/s at32Hz, plus absolute/add instructions. Cache behavior and
actual GPU time are unmeasured; this is a nonzero incremental cost within an
existing pass, not a claim of free computation or higher FPS.

The failure audit marker changes to v3 so row10 YZW cannot be confused with its
old meaning. The same160-float640-byte record carries the scale. The audit shader
cache key changes. Parser and offline analysis support both v2 and v3.

## Validation and remaining acceptance

- Three changed production shader programs compile under strict warnings-as-errors.
- Eleven native WARP draws exercise old/new totals, inside/edge sources, packet
  admission and the v3 snapshot. Physical totals0..9 and edge water remain equal.
- The captured tail with an explicitly synthetic cancelling-packet absolute scale
  is rejected before and accepted after. The scale is not claimed captured data.
  Positive/negative missing water and large pure momentum still reject; a genuine
  authorized edge exit remains accepted.
- Product13 groups, foreground7 cases, bounded-input recovery and closure analysis
  pass. Engine/context services in these integration regressions are mocked.

The amended shared runtime is connected to the main product path. Reload the app
before ordinary continuous-preview use; no separate probe or dedicated long run
is requested. Actual CSP success of this numerical amendment remains unverified.
Earlier64/288 failures remain open; this mask8 result does not prove their repair.
Keep source correctness ahead of merge/pool activation and final performance work.

Evidence and hashes: `diagnostics/2026-10-25/s282_deposition/`.
