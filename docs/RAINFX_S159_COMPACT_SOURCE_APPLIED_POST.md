# s159 — source-applied identity and compact recipient

Status: ACTIVE — offline physical-output parity, bounded ledgers and rollback passed
Date: 2026-10-19

## Implemented

The source-applied continuation still allocated four source bands, a head
staging texture, zero supply/event inputs and a three-band force copy. s159
replaces them with an explicit identity input plus a scalar physical-context
guard and reads the existing two force bands through the checked bank ABI.
It also stores only recipient End/Mean, evaluating exchange and evaporation
packets inside the ledger when needed. The physical equations and coefficients
are unchanged. No production app, shader, setting or historical prototype changed.

This is an uninstalled private continuation recipe. It does not create rainfall,
evolve heads, advance a public clock or authorize a new live solver. Game physics
remains s87, diagnostics s89.

## Identity source and guard

The input contract is still `source_applied_phase1_v1`. Eight protocol headers,
inventory validation, source identity, retained-time checks and existing plan
validation remain. A new scalar guard retains the exact `physicalContext()`
predicate and requires the private control's fresh-source flag to be zero.
Even dry input must pass material/context validation; it is not skipped.

The donor reads the same immutable original film used by compact status/exchange
readers. It receives the guarded plan. Wet cells with negative support runs are
still refused. The inventory pass checks all pinned physical heads and micro,
so removing their source copies does not remove packet validation. Import
positions1…11 are unchanged; input read leases remain retained.

The first executed axis now uses the existing compact force texture directly:
checked bank origins0 and H within its2H parent. Map/leaves/gather equations
are unchanged. Eligibility still refuses invalid donor output before acceptance;
failed candidates preserve original film/mean, micro, heads, history and debt.

The old four-band debug `flowSource` root is deliberately removed. The new
`sourceLayout='identity_input_and_guard_v1'` exports `sourceAppliedInput` and
`sourcePlan`. Consumers must explicitly support that ABI; it must not be
interpreted as the previous four-band source. Tests compare the identity input
to the old first band and verify the old supply/pool bands are zero on acceptance.

## Compact recipient and ledger

The parent recipient calculations are extracted into `postCell` without changing
their expressions or order. The producer writes End and retained-path Mean
into two bands. A failed local calculation writes a finite negative-volume
marker, like the existing compact donor. The status consumer verifies shape,
finite/valid packets and equal End/Mean mass. Markers never enter accepted stock.

The ledger retains the same eight packet meanings: initial stock, final stock,
supply, internal pool, impulse, wall exchange, evaporation and runoff. Supply
and pool are zero in this already-applied phase. Pinned head stock is read from
its original input. Existing compact donor exchange readers remain unchanged.

For recipient impulse, wall exchange and evaporation rows, the ledger evaluates
the exact parent `postCell` on the same immutable transported field, metric,
area, physical settings and dt. End/Mean remain stored. Logical recipient
evaluations per supported cell are5 before, versus2 producer +3 ledger =5 after
when accepted. The5→2 storage change therefore does not introduce a higher
logical force-evaluation count. It moves work into a tiled shader; register
pressure, reads, cache behavior and actual GPU time still require measurement.

There is no target pooling/recycling or relaxation of resource completion rules.
Each remaining target has separate retained storage.

## Verification

The paired harness executes frozen s158 and new s159 graphs with identical
inputs. It reuses the frozen s157 field fixture generator and actual frame660
geometry/physical rows. Both axis orders,13×7 and273×17 multi-group fields,
pinned nonempty heads, actual1024×256 dry/static/physical film and a second
physical quarter are covered. Actual-grid stock is a controlled1µm film plus
0.1µm pinned micro and4096 empty head slots, not observed game water or active
head saturation. Additional controls cover viscosity and complete evaporation.

Twenty-three pairs comprise12 accepted cases and11 refusals. The latter include
wrong debt/token/material/history, invalid material even with dry stock, wet
stock outside support, invalid pinned heads, and injected axis/ledger/donor/post
faults. Eight malformed CPU recipe requests also refuse. The complete run uses
**1,952 WARP draws /33 strict shader compilations**. No new actual CSP test ran.

All common non-ledger roots are bit-identical in the19 comparisons without
injected GPU faults. Film/Mean, pinned stock, decisions and checkpoint retain
their exact physical values. On refusal, original stocks/history/checkpoint
are restored exactly, including deliberately malformed input history. Accepted
inventory and cumulative closure pass the inherited128-float-epsilon summed
bound with its1e−9 floor. The second physical quarter preserves the expected
remaining dt0.008438587188720703s, with no source replay.

Recomputed evaporation momentum can round differently from stored packets.
The three ledger roots therefore use the existing128-epsilon packet comparison
bound and1e−9 floor, as well as the unchanged cumulative closure gate. Their
maximum non-injected difference is7.275957614183426e−12 in packet components.
They are not claimed to be bit-identical. No physical acceptance threshold is
widened. The initial bit-comparison failure (2.6645352591003757e−15 in the small
fixture) is preserved, with the corrected comparison policy in `initial_notes`.

Strict compilation also caught X3577 on `isfinite(status)` after the new status
expression was provably Boolean0/1. Only that redundant check was removed;
finite checks on raw packets remain. The failed source is retained. Final
compiled shaders pass `/WX /Ges` without warnings.

WARP uses serialized uploads/readbacks, not a persistent live CSP bank. These
cases do not establish thick/high-Courant accuracy, arbitrary changing weather,
full head/film coupling, target GPU cost or warm recurrent stability.

## Cost result

| Actual1024×256 /4096-slot descriptors | s158 | s159 |
| --- | ---: | ---: |
| Passes |50 |46 |
| Resources including11 imports |61 |57 |
| Nominal retained graph |130.3114MiB |85.8104MiB |
| Recipient target |20MiB /5 bands |8MiB /2 bands |
| Field cache + graph, shared world imports counted once |142.7106MiB |98.2096MiB |
| Static last-read frontier, graph only |76.9537MiB |56.8288MiB |

Four targets disappear and the source, recipient and status/reduction extents
shrink. The graph saves44.5010MiB. The scalar guard is16 bytes; the12MiB packed
force copy is removed. Source-image caches, driver overhead and birth/head
evolution are excluded from these counts. No FPS improvement is claimed.

Retaining the whole graph still exceeds64MiB. The static frontier is only
dependency accounting, not proof of GPU completion or permission to reuse a
target. Including the retained field bundle above shared imports gives a
69.2280MiB static estimate, also above64MiB. No owner limit was increased.

## Next

Evaluate direct tiled status reduction to avoid the remaining full-field
status images while preserving every packet/context check. Then validate
bounded target lifetimes/reuse for this actual-grid graph and its retained
world cache. A live backend still needs verified completion/order and continuous
inventory authority before adoption, followed by common optics and measured
game cost. No additional user game test is requested for s159.

Evidence: `docs/diagnostics/2026-10-19/s159/lean_checks.json`, `cost_checks.json`,
`layouts.json`, `results.npz`, `transformed_harness.py`, `initial_notes.json`,
the initial failed packet archive and `delivery.json`.
