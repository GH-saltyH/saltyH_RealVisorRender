# s145 — source-applied remaining-time transport

Status: ACTIVE
Date: 2026-10-18
Scope: offline, uninstalled candidate; production physics remains s87 and s89 diagnostics.

## Purpose and boundary

s144 deposited accepted trail/impact packets, debited pool returns and selected a
joint film/micro/head inventory with a cumulative ledger. Its phase-1 checkpoint
retained the entire field time debt. This stage connects that physical stock to
the existing s141 field integrator, without applying external inputs or pool
events again. The s141 shader bodies and observed s138 transport consumers are
unchanged.

This is a private continuation graph, not a game callback or clock publisher.
Inputs must come from the same immutable, producer-sealed source checkpoint.
Packet formats and matching inventory totals cannot prove arbitrary GPU contents,
same-frame provenance or physical completion. Those remain integration gates.

## Eleven imports

`s145_transport.recipe(order, heads, 'source_applied_phase1_v1')` supports the
observed 13×7 candidate field and 1–4096 heads. Axis order is 1 (Y→X) or 2 (X→Y).

| Slot | Input |
| --- | --- |
| 1 | s144 source-applied physical film `(mm³, mm³·world m/s)` |
| 2 | connected support runs for this field |
| 3 | three-row world metric atlas |
| 4 | already-selected physical head inventory |
| 5 | separate pinned micro inventory, zero momentum |
| 6 | physical cell area in mm² and resolved support tag 1 |
| 7 | s141 physical force/material snapshot, token plus four rows |
| 8 | s144 or prior s145 checkpoint: token; `(phase,id,remainingSeconds,1)` |
| 9 | original s144 five-row source header, retained for the whole interval |
| 10 | joint cumulative ledger including film, micro and heads |
| 11 | matched continuation request, three rows below |

Request rows are the current token, `(referenceSeconds,remaining,cap,consumed)`
and `(sourceTick,headCount,order,1)`. Fractions use Q=1,048,576; all three tick
fields are integers, remaining+consumed=Q, and remaining/cap are positive.
`referenceSeconds*remaining/Q` must equal the stored remaining seconds exactly.
`dt=referenceSeconds*min(remaining,cap)/Q` is therefore bounded by the retained
debt. The request is a private partition of that debt; it cannot change the
source-applied stock or authorize publication. Frozen request identity and input
leases are still required from the eventual owner.

## Typed continuation and rollback

A compensated reduction separately sums film+heads, micro and invalid packets.
The boundary requires matching source/checkpoint/request tokens, source model,
grid/count/order/source tick, phase 1, exact remaining time, typed nonnegative
packets, pinned micro, a balanced stored ledger and matching current inventory.

Only this admitted boundary can produce an active private s141 resume header.
The original public token remains the source header's previous token. The current
source-applied ownership is established by the enclosing s145 boundary, not by
pretending that those fields are globally published old stocks. These private
headers are never exported to a runtime publisher. The graph supplies its own
zero external-rate and zero event textures and a source-fresh flag of zero.
There is no raw event/rate import that could replay s144 sources.

The unchanged s141 graph applies donor/recipient force response, both ordered
transport axes, evaporation and runoff for one admitted dt. Heads remain held;
micro remains a pinned reservoir. This does not implement continuous head/film
exchange or micro drainage.

The final guard requires successful s141 admission, exactly the selected dt,
typed/balanced transport ledger, initial film+head inventory matching the input
reduction, and **zero** external/pool entries. Its joint step ledger adds micro
only to initial/final inventory. Cumulative row 0 retains the first initial
stock, row 1 becomes the new total stock, rows 2/3 retain s144's already-counted
external/pool entries, and rows 4–7 add only transport impulse, wall reaction,
evaporation and runoff. Cumulative closure is checked again.

An admitted partial step selects film/mean, unchanged micro/heads, step/cumulative
ledger and a new phase-1 remaining-time checkpoint. Only zero remaining debt
produces a **phase-2 numerical candidate**. It is not a trusted GPU completion
fence or an authorization to advance the global clock. A refused step preserves
film, micro, heads, history and checkpoint bit for bit, with a zero step ledger.
The current graph cannot consume phase 2 or reuse an old request on partial stock.

## Verification and limitations

The checker consumes the preserved s144 physical-source fixture and executes the
actual s141 shader recipe on WARP. It tests both axis orders through four partial
steps, completed and stale requests, immutable retries, malformed source/token/
time/model/history inputs, force/area refusal and injected repeated external
source. Independent rest and uniform evaporation oracles check field results.
Two further intervals alternate actual s144 source raster/debit/ledger passes
with s145 transport and finish, rather than authorizing identity completions.
Their upstream head streams and retained impact packets remain controlled
fixtures, not live CSP producers. A 4096-head continuation is also exercised.

**2,571 WARP draws / 40 strict `/WX /Ges` bodies**, 39 accepted/refused cases,
two four-part axis-order chains, two recurrent source/transport intervals and
six mocked lease/lifetime cases pass without shader warnings. Tolerances remain
the inherited 32-ULP-style local and 128-ULP-style aggregate bounds with 1e-9
floor. This is packet/time ownership evidence, not a new physical accuracy claim.

The inherited s141 completion-guarded bridge and eleven-input provider are
exercised with mocked ordered, pending and unknown submissions, capacity limits
and unsubmitted cancellation. Submitted leases and private targets remain held;
the graph cannot publish through this mock authority.

The 8-head graph uses 65 private passes / 76 total resources, 79,776 nominal
bytes including imports, with at most 18 textures per call. The 4096-head graph
uses 71 passes / 82 resources and 803,792 nominal bytes. These are separated
diagnostic allocations, not accepted production costs. WARP uploads CPU arrays
between draws; no actual persistent GPU timing or live lifetime safety is proven.

This completes the source-applied remaining-time **connection**, not the accuracy
or performance adoption gates. Frozen-depth force splitting, reconstructed film
footprints, batched source timing, head/film synchronization, equal-time physical
accuracy, full-resolution solver geometry and long-run game cost still need
evaluation. Micro remains held. Actual retained impact momentum/source hooks and
a trusted completion/clock owner must be implemented before live adoption.

Evidence: `diagnostics/2026-10-18/s145/transport_checks.json`, `graph_values.json`
and `delivery.json`. Prior sources, runtime files, INI files, installed probe,
SDK and generated physical assets are preserved.

## Next implementation

Build the immutable frame/interval owner and retained impact packet producer,
including actual source timestamps and physics/geometry identity. Reuse private
targets only with verified lifetime, fuse diagnostic passes, then evaluate
physical/time accuracy and cost before exposing a default-off live preview.
