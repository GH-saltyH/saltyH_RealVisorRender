# Regional pool → SI head return — 2026-10-25

Latest actual execution: [serial156 near-start fault](RAINFX_JOINT156_COMMIT_FIX.md).
Source commits are now specialized; peak bindings12, cumulative commit3.
The original15-binding qualification below is historical. Actual CSP fix pending.

## Product change and present verdict

The existing P0 continuous physical RainFX preview now includes a regional
film-to-head return. It closes a missing physical connection: old film can form
a resolved drop, move under the existing SI forces, deposit a trail and leave
the visor through the existing boundary exit. It does not delete water or alter
evaporation to clear the image. App reload applies it; no standalone probe or
additional menu/start procedure.

**Local conservative-transfer checks pass. Broad-film game quality is still
unaccepted.** A linked frozen-stock comparison shows real exit but substantial
remaining film. Do not advertise this as completed drainage or reference-scene
weather calibration.

## Implemented event and accounting

Use existing16×16 field-cell ownership regions and rotating region→head-slot
mapping. Three GPU passes precede the existing birth producer:

1. Sum excess film in each region and choose the largest excess cell whose
   centre passes the actual producer boundary mask. Partial boundary cells can
   own water while having an unsupported centre; they must not become head sites.
2. Write an immutable R32F per-cell debit plan. Each amount is computed as the
   representable difference `old - (old - requested)`.
3. Sum those actual debit amounts into the pool candidate consumed by P2.

The existing birth path gives incident birth priority, then uses a free owner slot
for a pool candidate. Only an actual pool birth event authorizes the cell debits.
Busy slots, unsupported centres and failed births leave the field unchanged.
Candidate volume and source debits use the same immutable plan. No new rain is
recorded for this internal transfer. Original current-stock, step momentum and
water admission rules remain; no physical comparison tolerance was widened.

Source status/totals/six commits share the same debit function. Cached and first
recipes enable the producer-owned pool row without mutating captured weather
inputs. Same physical units, contact radius, mass and display-gain separation as
ordinary heads. Existing optical interpolation also applies to returned heads.

## Provisional reduced-model parameters

`rain_product_pool.lua` makes these explicit defaults, not measured universal
visor constants or weather-preset rules:

| Parameter | First candidate | Meaning |
| --- | ---: | --- |
| Bare/coated retained film |10 /2µm | Effective residual before regional reconstitution |
| Relaxation time |0.25s | Requested fraction `1-exp(-dt/tau)` |
| Equivalent-volume diameter |1–3mm | Resolved return event size; spherical volume convention |

Once a region contains the minimum resolved volume, return at least that minimum
event instead of requiring `minimum/fraction`. The latter would itself leave a
thick permanent reservoir. The per-event maximum bounds work and head size; it
does not limit total stored water. The regional concentration is a lumped
capillary-coalescence approximation, not simulated lateral film flow. It can
create visible concentration events rather than a continuous retracting sheet.

The physical diameter never uses display gain. Film return is driven by local
physical stock/coating, not by the name of a weather preset. Head merging and
absorption into existing attached heads are still absent.

## Evidence: conservation and actual code paths

-9 native WARP draws: candidate/debit equality, thin-film identity, busy-slot
  identity, unsupported-region refusal, actual source totals and original ledger
  admission. Internal-transfer step closure is0mm³ in the fixture.
-6 changed production programs strict-compile with SDK prelude and real binding
  names. Peak15 textures, below CSP16 limit. The field binding guard allows the
  additional pool-debit texture specifically; physical admission is unchanged.
- Six first/odd/even/cached recipes contain one proposal/debit/candidate sequence.
- Product regression13 groups +8 native optical draws pass. Actual host/backend
  calls are mocked there, not a real CSP execution or GPU timing measurement.

The first unit attempt exposed an FP32 summation mismatch; adding `precise` to
the existing compensated reduction fixed it. Cached recipes then exposed the
old14-texture assertion, corrected specifically for the15-input pool consumer.
No separate ABI research was opened.

## Recorded flooded stock and linked scene result

Use immutable recorded12343 film:20,481.524mm³, plus1,217.448mm³ micro. This is
not the user's latest video exact stock. First native proposal produces529 valid
regional candidates totalling2,379.212mm³. One-step actual SI force/trace moves
291/529 under gravity and383/529 under captured forcing, with2/9 exits respectively
and no invalid trace codes.

A four-second linked counterfactual starts that field with empty head slots and
uses frozen captured pose/forcing,4096 slots,32Hz force oracle and actual bounded
mesh-trace shader. CPU trail raster is a conservative Gaussian proxy with the
uniform bare deposition coefficient; actual coating remains in force and pool
residual. This overstates coated trail return relative to the runtime; it is not
the exact runtime raster. There is no new incident rain in this case.

| Quantity | Initial | After4s |
| --- | ---: | ---: |
| Film |20,481.524mm³ |12,033.813mm³ |
| Returned-head stock |0 |3,746.977mm³ |
| Micro |1,217.448mm³ |1,217.086mm³ |
| Physical exit |0 |4,698.347mm³ |
| Evaporation |0 |2.749mm³ |
| Median film height |444.601µm |245.006µm |

Total budget error is at most0.000281mm³. Returned-to-head and head-to-film totals
are internal throughput, not extra input. Current cubic optical reconstruction
is used for the final paired image; the broad pattern remains visibly excessive.
This explicitly fails a claim that reconstitution alone solves the flooded case.

Capacity-only controls omit motion/exits: blocked slots retain all film exactly;
2048/4096 slots retain15,236/11,514mm³ film after4s. Those are storage controls,
not2048/4096 FPS predictions or a full simulated runtime comparison.

Dry-start controlled film flux2 versus50mm³/s over30s produces median film1.49
versus7.97µm; the stronger case transfers water to heads. These are declared
film-only supply controls with no incident DSD, micro source, head motion or
evaporation, **not a CSP Light rain/Heavy rain replay**. They cannot clear the
reported low-rain bug or qualify weather appearance.

## Remaining quality limit and bounded next work

Outflow slows while many returned small heads remain attached. With no local
head absorption/merging, a wet region cannot keep feeding a larger mobile drop
through occupied slots. Increasing slot count, deleting water or forcing every
head to move would conceal that missing interaction. The next implementation
candidate is bounded local absorption/coalescence using existing spatial regions,
followed by one dry-start weak/heavy input comparison. No global O(N²) pair scan
or new precision/probe series is required.

The old trajectory helper used mask R in its offline boundary construction.
It now uses A, matching the actual producer. Archived old results retain their
original sources; current candidate evidence uses the correct A boundary.
Force-oracle rounding is judged by one-step image displacement (<0.001 fine
pixel), rather than relative error near a cancelled velocity; runtime gates are
unchanged. Largest observed comparison error was0.0000611 fine pixel.

## Runtime cost and limits

Two extra canvases,1.015625MiB total, and3 recurring GPU draws per physics step;
first step replaces the former zero-candidate write, so adds2. Two regional
reductions and one cell plan are O(field cells), independent of all-pairs head
counts. Existing birth and source passes consume them. No extra readback/sync,
no change to32Hz physics or frame-rate display interpolation.

Actual CSP shader startup, frame time and long-run visual behaviour remain
unverified. Source consumers now bind15 textures; strict compilation does not
prove engine binding behaviour. Keep this as a preview candidate.

Evidence: `docs/diagnostics/2026-10-25/regional_pool/`.
Tools: `check_regional_pool.py`, `review_regional_pool.py`,
`review_pool_drainage.py`, `review_pool_display.py`.
