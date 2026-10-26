# s267 — joint physical supply and compact film transport

Date: 2026-10-24. Implemented native component; not installed as a live game
solver. Parent: [s266 actual CSP result](RAINFX_S266_ACTUAL_RESULT.md).

## Implemented connection

The existing conserved source raster now feeds the compact SI force/advection
solver. No rainfall, contact-angle, size, mass, adhesion or impact law is changed.
The source stage reuses the tested integer tent / swept-line kernels, sparse tile
masks, impact partition, head-to-film trail debit and film-to-head pool funding.
It keeps fractional coverage, clipped tails and pinned micro water distinct.
No per-drop CPU stamping or CPU source readback is introduced by the recipe.

The native recurrence executes preserved birth/head producer shader recipes,
then source, then compact transport, with one final joint decision. Physical
head packets, raw state/meta and film/micro stocks from the committed result
feed the next interval. This connects real producer equations, not synthetic
film supply alone. Inputs are controlled preserved fixtures, **not live engine
weather or current actual-grid head buffers**.

### Inventory and ledger

1. Apply one admitted source to the old physical inventory. Source admission
   already checks matching producer receipts, old stock, phase-2 checkpoint,
   immutable frame identity, incident/retained/bounce packets and pool funding.
2. Start compact transport from the source-applied End film. Each interval has
   its own transport ledger; the source is not repeated in its 4/8/16 substeps.
3. Update cumulative row 1 by `transport End − source-applied initial film`;
   add transport force impulse to row 4, wall exchange to row 5 and runoff to
   row 7. Preserve source initial stock, external supply and informational pool
   volume. Thus heads/micro are neither omitted nor added again after transport.
4. Require source and flow acceptance, matching source/physics token and dt,
   balanced cumulative water/momentum, previous joint receipt and matching
   physical head volume versus raw metadata. The head check is a bounded
   parallel reduction, not a per-pixel all-head scan.
5. One immutable decision selects **all seven** roots: End film, pinned micro,
   physical heads, cumulative ledger, phase-2 checkpoint, raw head state and
   metadata. Any refused step selects all original roots bit-for-bit.

The joint receipt is four RGBA texels (16 words), namespace 267. It records
identity/acceptance, cumulative private time, accepted dt/debt, total initial plus
incident water, current joint stock, cumulative exits and closure diagnostics.
The CPU decoder checks identity, clock and water summary. These receipts are
private; they do not advance the public renderer clock.

This is first-order source-then-transport splitting. Swept-path water is applied
once at the interval boundary before transport. It does not claim exact
within-frame deposition timing or prove final head/trail visual alignment.

## Execution API and ownership

`s267_joint.compile(Core, sourceRecipe, sourcePacket, W, H, count)` builds fixed
plans once. `bind(dt, serial)` makes job-owned parameter maps and selects the
4/8/16-substep plan; it does not rebuild the source graph in a frame callback.
Retained/direct plan parity covers all three plans at three grid/count layouts.

The existing source graph keeps its first twelve imports. Additional immutable
imports are metric, areas, support runs, physical parameters, previous joint
receipt and old/new raw head state/meta. The source composer also supports the
resolved-cell adapter's unchanged first twelve imports. Raw state/meta and source
head packets must belong to the **same producer-owned cohort**. Matching numeric
volumes cannot establish arbitrary handle provenance.

All provisional outputs remain private. A runtime owner must submit every
selector before its final small audit copy/readback and hold source/head/geometry
leases until that ordered result is retired. It must not expose the early
decision texel as proof that the later selectors have completed. This component
alone is not a CSP completion fence, resource pool or continuous runtime owner.

## Bounded local evidence

- Native D3D, 726 draws, 15 integrated cases; warning-free strict compilation.
- Three recurrent 13×7 / eight-slot intervals, 0.046875 seconds total, execute
  inherited birth/head producers with incident supply **1.150346518 → 0 →
  1.150346518 mm³**. Source-off still evolves existing head/film water.
- Final total initial plus incident water: 3.300693035 mm³. Final joint stock
  about 2.840478897 mm³; cumulative exit about 0.460213900 mm³. Global water and
  momentum close within the inherited FP32 budgets. Native per-cell film sums
  independently match the compact reduction.
- Partial coverage, masked runoff and clipped tails accept. Missing head receipt,
  insufficient pool water, old water in a hole, source replay, transport refusal,
  wrong physics identity, wrong raw metadata volume and stale joint parent refuse.
  All seven physical/raw roots retain their original bits on refusal.
- Accepted raw state/meta copies retain producer bits. Numerical force/transport
  recomputation uses physical error tolerances, not a whole-array bit-match gate.

The single-draw native harness reads back intermediate results and rebinds them
as immutable next-draw inputs. This verifies composition and numerical recurrence;
it does **not** exercise one retained CSP working set, asynchronous SDK callbacks,
actual-grid supply evolution, changing-pose head ownership or target GPU cost.

## Cost and next runtime integration

At 1024×256 and dt at or below 1/60 s, the full retained source/transport recipe
has 52 passes for either 2048 or 4096 slots. This excludes upstream birth/head
producer passes, actual cache updates and the runtime audit copy. Larger dt uses
the bounded 8/16-substep plans. Exact descriptor byte counts, including separate
owned/import charges, are recorded in `diagnostics/2026-10-24/s267/checks.json`.
Existing diagnostic source intermediates are retained in this correctness
composition; they are not a proposed extra permanent allocation atop s266.

These are descriptor plans, not FPS or GPU timing results. The count difference
mainly changes head data and sparse masks; dense overlapping footprints can cost
more despite unchanged pass count. No 2048/4096 FPS projection is justified yet.

The next bounded task is to bind the existing physical birth/head producer to
the actual admitted context and package its immutable source/raw cohort for the
retained runtime owner. Reuse the observed s266 scheduling/audit route and retain
the seven-root joint decision. Before a game run, account for producer working
storage and SDK texture binding limits together; do not reinstall diagnostic
intermediates unexamined. Then connect common optical consumption and measure
the complete pipeline. This step requests no new standalone probe or user test.

The s266 main-app path and its actual result stay unchanged. No settings, existing shaders,
textures or Git commits were changed by this stage.
