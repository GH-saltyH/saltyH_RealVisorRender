# s148 — SI head motion and transfer producer

Status: ACTIVE
Date: 2026-10-18
Scope: offline, uninstalled; production physics s87, diagnostics s89.

## Implemented

The head stage now produces its own force, position, provisional metadata,
trail/evaporation descriptors and final head inventory on GPU. It replaces the
controlled post-motion inputs used by the s147 frame test. The dependency chain
is s146 birth → s148 SI heads → s144 source → s145 transport substeps.

The original P1 SI force arm is extracted from `realvisor.lua`. Physical volume
is authoritative for contact radius, mass, pinning, aerodynamic force and drag.
The original s143 reciprocal merge/advance trace and production P3 descriptor/
metadata operators are reused. No display diameter gain enters this interface.
This stage has not changed the running game or retuned physical coefficients.

Newborns take their initial state from the same admitted P2 event and skip the
existing-head force/advance step. Surviving merged heads use merged physical
volume and momentum. Absorbed heads retire. Heads leaving a boundary retire in
this interval and export their retained last-valid exit packet; this deliberately
avoids the legacy path's possible one-frame retirement delay. A trace work-limit
refusal cannot export a candidate.

## Inputs and ownership

`s148_heads.recipe(count, gridWidth, gridHeight, 'si_head_producer_v1')` has fifteen
imports. It returns an offline graph/parameter packet, not a renderer callback.

| Slot | Input |
| --- | --- |
| 1–2 | previous raw position/velocity and SI metadata |
| 3 | admitted s146 five-row birth events |
| 4–6 | du, dv and boundary geometry |
| 7–8 | previous/current object-to-world transforms |
| 9 | s143 frame/token/time/geometry header |
| 10–12 | reciprocal merge commands, full-generation stamps, merge configuration |
| 13 | sealed ten-row SI/material/film parameter atlas |
| 14–15 | admitted s146 receipt and source header |

The SI atlas freezes token, inertia, world air, force selection, air fraction,
water/air properties, contact angle and hysteresis, attached drag, downward-air
mode, time bound, P3 deposition/evaporation and revision/source-tick identities.
Headers, receipt, dimensions, previous token, frame, revisions, physical units,
material angle and source tick must agree. Invalid inputs produce no export.
Upload identity/content authentication remains the backend's responsibility.

The derived s148 owner pins the actual birth event/receipt/source-header handles
in slots 3/14/15. All other s147 stage, completion, reader and cancellation gates
are preserved. The source stage imports the head stage's header at its new slot;
it does not confuse that header with the SI parameter atlas.

## Merge creation provenance

`s148_merge_snapshot.build(snapshot, proposals, seal)` constructs commands and
generation stamps together from one privately copied SI metadata snapshot.
Proposals are disjoint zero-based pairs. Both members must be alive; the builder
stores each full self/partner generation at command creation, plus snapshot frame
and geometry/pose/material identities. Later edits cannot alter the result.
Canonical command bytes retain the existing low-six-generation encoding; full
stamps prevent a stale command alias from becoming valid after 64 generations.
The inherited bounded frame/generation-wrap assumptions still apply.

This is O(slots + pairs). It does not implement a new spatial broad phase or
connect an actual game readback/upload hook. Proposal selection and cryptographic
seals remain explicit trusted seams, rather than reconstructed current-generation
values masquerading as creator provenance.

## Numerical finding

An unchanged copy of the force model failed the independent double-precision
oracle. Its maximum UV velocity error was about 1.64e-5. The principal error came
from subtracting close contact-angle cosines. Stabilizing only the exponential
response did not resolve it. The derived offline core now uses:

- `cos(R)-cos(A) = 2*sin((A+R)/2)*sin((A-R)/2)`;
- a bounded small-x series for `(1-exp(-x))/x`, with the ordinary expression
  outside that branch.

These evaluate the same physical equations and preserve coefficients. Float bits
intentionally change. The original production core is unchanged. The original
failing output, compiled shader and component trace are preserved, and a fresh
unmodified-core control must reproduce those bits. The maximum error falls to
about 1.65e-7 (roughly 99 times smaller) under the same 32-float-epsilon relative
force gate with a 1e-9 floor. Water/momentum closure retains its separate
128-epsilon accumulated bound. No threshold was relaxed.

## Evidence and cost boundary

`check_s148_heads.py` executes 21 cases (12 accepted, 9 refused), 276 WARP draws
and 12 strict synthetic shader bodies. It covers individual force masks,
downward air, zero viscosity, static pinning, merge/absorbed heads, newborn/pool
transfer, immediate exit, immutable retry, invalid context and full-generation
alias rejection. Five snapshot-schema and three pair-shape refusals pass.
The same producer runs at 4096 slots and checks force and packet closure. This
capacity fixture contains five old active heads and two births; it is not a
4096-active-head performance or saturation test. Curved/recurrent force accuracy
still requires separate adoption evidence.

The small head graph uses 13 private passes; 4096 slots require 15 because of
status reduction. This is a diagnostic graph, with retained intermediate textures
and up to 27 declared bindings in synthetic checks. These figures are not an
approved CSP binding layout, live GPU cost or evidence of a speed improvement.

The owner check runs the complete birth/head/source/two-step transport chain with
existing moving heads and a full-generation merge, rather than only newborns.
It separately checks 29 owner modes, six frame guards and six root-lease guards.
The connected frame executes 167 WARP draws and 52 strict synthetic bodies;
its equal/opposite 0.25mm³ merge transfers cancel, and the final source/transport
ledger passes the unchanged accumulated closure bound with zero remaining debt.
Completion is supplied by the offline harness; phase 2 is a numerical candidate,
not public-clock advancement, cross-frame inventory ownership or a CSP fence.
See `docs/diagnostics/2026-10-18/s148/delivery.json` for audited final counts,
resource figures, residuals and immutable source hashes.

## Next implementation

Connect authentic geometry/pose/weather/SI snapshots, merge creator metadata and
upload identities to the frame owner. Implement a verified ordered/completion
backend and persistent final-inventory handoff before admitting another frame.
Then fuse diagnostic intermediates and evaluate recurrent physical/time accuracy,
head/film common optics and measured warm game cost before any live preview.
