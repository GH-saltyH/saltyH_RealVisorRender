# s161 — early donor exchange and shorter force lifetime

Status: ACTIVE — offline physical parity, ledger bounds and rejection checks passed
Date: 2026-10-19

## Implemented

The s160 final ledger still read the8MiB donor force texture, so that texture
remained live through both transport axes and recipient processing. s161 reduces
donor impulse/wall exchange immediately after source eligibility, using the
unchanged compact reader and immutable film/metric/area. The final per-cell
ledger computes recipient exchange only, then combines the two small global
donor rows. The force texture's last consumer is now the first-axis gather.

Physical force/recipient/transport equations, film/Mean packets, material settings,
source-once rules, time debt and closure bounds are unchanged. This is an
uninstalled private graph; production app, shaders, settings and historical
prototypes are preserved. Game physics remains s87, diagnostics s89.

## Exchange ABI and validation

The explicit `exchangeLayout='status_and_world_momentum_v1'` has two rows:

| Row | Valid payload | Error payload |
| --- | --- | --- |
|0 | `(0, donor impulse.xyz)` in mm³·world m/s | `(1,0,0,0)` |
|1 | `(0, normal/wall exchange.xyz)` in the same units | `(1,0,0,0)` |

The first component is a status flag, never physical water. The early tile pass
uses the same16×16 Kahan expressions as the ledger. Its extent includes the
ledger's padded head rows, which contribute zero to these two exchange sums;
this preserves zero-addition behavior at tile edges. Two-band reductions carry
errors and reject nonfinite inputs or overflow with finite error markers.
Source-ineligible work returns zero but remains refused by its original plan.

The inherited flow decision additionally requires a1×2 donor summary, finite
components and zero flags in both rows. The eight-row physical ledger retains
its meanings. Donor exchange is added only to rows4 and5 after recipient
reduction; the unchanged finish gate still checks step/cumulative conservation
before selecting physical outputs. Bad summaries cannot publish stock or time.

The new targets are internal, not extra exported physical roots. Diagnostic
metadata identifies their resource IDs; a future late reader of force or
exchange must request an explicit lease/pin. No resource is released or reused
by this stage.

## Numerical verification

Moving donor addition out of each cell changes floating-point grouping. All
common non-ledger physical roots remain bit-identical in the20 non-injected
comparisons. The three ledger roots use their inherited128-float-epsilon packet
bound and1e−9 floor, and cumulative conservation retains its existing summed
bound. No threshold is widened. Maximum ledger difference is3.725290298461914e−9
across the fixtures; the captured actual-grid cases differ by at most
7.275957614183426e−12 in packet components.

Twenty-six paired s160/s161 graph executions comprise13 accepted cases and13
refusals. They cover both orders, small/ragged fields, pinned heads, actual
1024×256 dry/static/physical film, physical resume, viscosity, full evaporation,
invalid input/history/debt and injected axis/ledger/donor/recipient faults.
New summary-flag and finite-momentum corruptions refuse with original stock,
history and checkpoint restoration. A32×16 opposing-impulse control is accepted
with every common root bit-identical. Eight malformed CPU recipe requests refuse.
The frame run uses2,059 WARP draws /31 strict compilations.

An independent18-case harness uses dyadic planar packets with an exact CPU
exchange oracle, dry/source-ineligible cases, invalid End/Mean/stock/metric,
NaN/Inf, malformed dimensions, overflow and propagated reduction flags. Valid
dyadic exchange is bit-exact; all invalid conditions refuse. It uses44 WARP
draws /3 strict compilations. Total:2,103 draws /34 compilations across the two
harnesses, with final `/WX /Ges` compilation free of warnings.

The actual grid still uses frozen main-app frame660 geometry/physical rows and
controlled1µm film,0.1µm pinned micro and4096 empty head slots. Neither these
fixtures nor the opposing-impulse control establish all cancellation patterns,
thick/high-Courant accuracy, continuous weather or active head/film interaction.
Overflow rejects the candidate; it does not expand numerical tolerances. WARP
uses serialized upload/readback, not a persistent CSP graph. No new game test
or target GPU timing was performed.

## Lifetime and cost result

| Actual1024×256 /4096-slot descriptors | s160 | s161 |
| --- | ---: | ---: |
| Nominal separately retained graph |77.8104MiB |77.8440MiB |
| Passes /resources including11 imports |44 /55 |48 /59 |
| Static last-read frontier |56.8288MiB |48.8288MiB |
| Static frontier plus retained cache |69.2280MiB |61.2280MiB |
| Proposed exact-shape reservation, graph only |61.7945MiB |53.8280MiB |
| Proposed reservation plus retained cache |74.1937MiB |66.2272MiB |

Early reduction and final combination add34.40625KiB and4 passes. The completed
summary is32 bytes. The force resource's last read moves from the late ledger
at old step35 to the first gather at new step27, before the second gather at
new step32. It has no late ledger binding. The static peak drops by almost8MiB
(the retained32-byte summary accounts for the difference).

This is a lifetime improvement, not a decrease in current total allocation or a
measured speedup. Every current target remains separately retained. Additional
draw overhead and different shader work placement need actual GPU/CPU timing.

The lifetime proposal recomputes immutable import leases, exact-shape slots,
read/write prefix ownership and physical-root pins. It remains descriptor
analysis, not an allocator, numerical pool replay or GPU completion proof.
The normal plan uses36 private slots; pinning status diagnostics uses37. Late
force/exchange diagnostics use38 slots and restore the long force lifetime,
so a future debug consumer cannot ignore its lease cost.

The static cache-inclusive frontier is now below64MiB, but the proposed
exact-shape reservation including cache is still66.2272MiB. No owner cap was
increased and no reuse, completion or live inventory authority was granted.
Source-image caches, driver overhead and birth/head evolution are excluded.

## Next

Evaluate a packed final End/Mean export with checked logical row-band consumers
and exact refusal/resume behavior. It can address remaining exact-shape pool
reservation overhead before native execution. Then validate actual ordered
pooling, completion and retained-cache/diagnostic leases, followed by live
inventory, common optics and measured game cost. No additional user game test
is requested for s161.

Evidence: `docs/diagnostics/2026-10-19/s161/lean_checks.json`,
`exchange_checks.json`, `cost_checks.json`, `lifetime_plan.json`, `layouts.json`,
both result archives, `transformed_harness.py` and `delivery.json`.
