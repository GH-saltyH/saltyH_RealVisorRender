# s160 — direct tiled status reduction

Status: ACTIVE — offline tile predicates and complete continuation parity passed
Date: 2026-10-19

## Implemented

s159 wrote source/donor and recipient status into two1024×256 textures, then
reduced each into64×16 maxima. s160 evaluates the same per-cell predicates
inside the first16×16 tile reduction. The full-field status images and two
separate reduction draws disappear. No physical force, transport, recipient,
ledger, checkpoint or acceptance equation changes.

This is an uninstalled private recipe. The production app, shaders, settings
and historical prototypes remain unchanged. Game physics remains s87 and
diagnostics s89; this step does not advance a live stock or public clock.

## Predicates and coverage

Each tile loops over its in-grid cells, including partial tiles at the right
and bottom edges. Source status retains valid/finite original and compact
End/Mean packets, matching volumes and the wet-cell support-run check.
Recipient status retains finite/valid End/Mean packets and matching volumes.
The original2H parent-dimension checks run once per tile, before any packet
loop. Invalid dimensions return a failed tile. All per-cell predicates are
Boolean0/1, so their maximum is exact and order independent. No cells are
subsampled, averaged or skipped because another cell already failed.

The smaller status textures have a new explicit
`statusLayout='direct_16x16_max_v1'`. Force, source and recipient ABIs, all named
physical roots, immutable import positions and input leases are preserved.
`statusTargets` identifies internal diagnostic targets, not exported physical
roots. A future late diagnostic reader must pin those targets explicitly.
Remaining reductions and the existing decision/rollback paths are unchanged.

## Independent tile verification

Fifty source/post cases compare the fused shader both to the original two
draws and to independent NumPy packet predicates. Eleven grid shapes cover
single cells, thin rows/columns,15/16/17 boundaries, ragged33×17 and273×17,
and full1024×256. Each shape tests normal input and an error in its final valid
cell. Additional controls mix negative volume, unequal volumes, NaN/infinite
momentum, zero-volume momentum and unsupported wet cells; short-height and
extra-width parents must fail all tiles.

Every tile component matches both oracles bit-for-bit. The independent run uses
**150 WARP draws /5 strict shader compilations**. Raw nonfinite input values
produce finite failed statuses, not NaN reductions.

## Whole continuation verification

The frozen s159 and new s160 graphs run23 paired cases:12 accepted and11 refused,
plus8 malformed CPU recipe refusals. Coverage retains both orders, small/ragged
fields, pinned nonempty heads, actual1024×256 dry/static/physical film, a second
physical quarter, complete evaporation and changed viscosity. Wrong tokens,
debt, material, support, head packets, history and injected axis/ledger/donor/
recipient faults retain their previous refusal behavior.

All named outputs, including all three ledgers, match bit-for-bit in the19
comparisons without injected GPU faults. The internal source/post tile arrays
also match the original first-reduction outputs exactly. The four injected
GPU faults verify refusal and original stock/history/checkpoint restoration.
Accepted inventory, cumulative closure, source-once semantics and private time
debt retain the existing bounds. No new ledger rounding occurs relative to s159.

This run uses **1,814 WARP draws /28 strict compilations**. Total for the two
harnesses is1,964 draws /33 compilations; these are verification counts, not a
runtime frame cost. Final compilations pass `/WX /Ges` without warnings.

The actual geometry and physical rows remain the frozen main-app frame660 from
s154/s157. Actual-grid film/micro are controlled1µm/0.1µm stocks with4096 empty
head slots. They do not represent live weather recurrence or active-head
saturation. WARP serializes uploads/readbacks between draws. No new actual CSP,
target GPU timing or warm-run test was performed.

## Cost result

| Actual1024×256 /4096-slot descriptors | s159 | s160 |
| --- | ---: | ---: |
| Passes |46 |44 |
| Resources including11 imports |57 |55 |
| Nominal retained graph |85.8104MiB |77.8104MiB |
| Field cache + graph, shared world imports counted once |98.2096MiB |90.2096MiB |
| Static graph last-read frontier |56.8288MiB |56.8288MiB |
| Static frontier plus retained cache |69.2280MiB |69.2280MiB |

The net saving is8MiB: each full4MiB status image and its16KiB first reduction
become one16KiB direct tile target. The two producers now shade2,048 output
pixels rather than524,288, but still evaluate524,288 cell predicates. The old
full-status writes and first-reduction reads disappear. Longer per-pixel loops,
occupancy and cache behavior may affect GPU time; no speedup is claimed.

The static maximum remains at the second-axis gather. Status fusion therefore
reduces total retained allocation, not that peak. It does not make the current
retained graph fit64MiB.

## Resource lifetime plan — analysis only

`lifetime_plan.json` drafts an exact-size/format/single-mip private target pool.
Imports always retain separate immutable leases. A private slot is considered
available only when its prior last-read step is strictly before the next write;
same-draw read/write aliasing is forbidden. Physical roots stay pinned through
graph end. Symbolic owner checks cover every read/write prefix and final root.
The diagnostic variant also pins both internal tile arrays through graph end.

The proposal reserves61.7945MiB for graph imports plus34 private slots. Including
the retained field cache above shared imports gives74.1937MiB, still over64MiB.
Pinning tile diagnostics adds one16KiB slot. These are proposed descriptors,
not implemented allocations or numerical pool replays. The plan does not prove
CSP submission ordering, GPU completion, safe cross-call reuse or disposal.
The current runtime recipe still uses55 separate resource descriptors.

Counts exclude source-image caches, driver overhead and birth/head evolution.
No owner limit was increased and no target was recycled in CSP or WARP.

## Next

The remaining peak includes the donor force texture retained for the later
exchange ledger. Evaluate reducing donor exchange sums earlier so that texture
can finish its consumer lifetime after the first axis, while preserving the
existing closure bounds. Then validate ordered execution and bounded resource
lifetime for an actual native pool, including retained cache and diagnostic
leases. Live inventory authority, common optics, accuracy and measured game
cost remain required before adoption. No new user game test is requested here.

Evidence: `docs/diagnostics/2026-10-19/s160/tiles_checks.json`, `lean_checks.json`,
`cost_checks.json`, `lifetime_plan.json`, both result archives, `layouts.json`,
`transformed_harness.py` and `delivery.json`.
