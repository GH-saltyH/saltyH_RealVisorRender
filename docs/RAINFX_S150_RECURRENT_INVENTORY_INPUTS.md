# s150 — recurrent physical intervals from retained inventory

Status: ACTIVE
Date: 2026-10-18
Scope: offline, uninstalled; game physics s87, diagnostics s89.

## Implemented

`s150_inventory_inputs` binds a next frame's protected inputs directly to the
previous s149 inventory bank. A recurrent frame now computes real birth, head
motion/merge ownership, source deposition and both transport substeps from that
inventory, copies its result to the next bank, and retires the temporary graph.
The s149 controlled second candidate is no longer the only cross-frame evidence.
No production shader, app callback or setting was modified.

| Stage | Mandatory bank inputs |
| --- | --- |
| s146 birth | slots 1/2: previous raw state/metadata |
| s148 heads | slots 1/2/7: previous raw state/metadata/object-to-world pose |
| s144 source | slots 5/6/10/11/12: previous film/micro/cumulative ledger/phase-2 checkpoint/physical heads |
| s145 transport | no direct bank imports; use the frame owner's admitted parent outputs |

Other inputs remain the trusted stage verifier's responsibility: current
geometry/pose/weather/material data, source parameters, creator-stamped merge
commands and per-frame physics headers. Descriptor keys do not authenticate GPU
contents by themselves. Actual engine uploads and their identity seals are still
unconnected.

## Input and lifetime contract

`open(bank, identity, externalSources, {offlineReplay=true})` obtains the bank's
opaque next-identity read capability. The existing contiguous clock, previous
token, source tick, frame ordering and geometry checks apply. The external and
bank authorities must share the same canonical identity domain.

The trusted stage verifier calls `bindStage(record)` with an offline stage
record. Protected source slots must contain exactly `{inventory='name'}`; their
recipe dimensions/format/mips must match the bank. Misplaced markers, attempts to
substitute external descriptors into protected slots, wrong identity/epoch and
changed reuse of a source key are refused. Exact immutable retries are allowed.
Only those slots are replaced with private copies of the bank descriptors.

The router registers the complete sealed stage record before allowing resource
acquisition. Unknown stage keys and resources are refused. Bank resources acquire
leases from the bank's scoped authority; other resources acquire leases from the
external authority. Returned opaque leases retain the correct canonical handle,
revision and descriptor authority. This matters when bank revision 2 differs from
the external registry's default revision 1. A canonical-domain mismatch rolls back
the acquired lease. Caller edits cannot mutate the registered record.

The owner/provider track submission and completion exactly as before. The router
cannot close while any stage input lease remains. On successful bank exchange the
old inventory remains retained until frame retirement releases those leases and
the router closes its bank reader. Unknown submission or numerical refusal keeps
the current bank unchanged. Bounds: 16 distinct stage authorizations, 512 wrapped
source pins, and the existing bank limits (two versions, eight readers and
32 bank pins per reader). The stage verifier must supply a record table and obey
the existing serialized, transactional, non-reentrant backend contract.

## Actual recurrent test

Three complete GPU operator sequences execute:

`birth → SI heads → source → half transport → half transport → inventory copy`

Frames 2 and 3 bind the actual copied allocations as protected inputs; they do
not upload fresh replacements for previous state or reset water/ledger history.
All physical packet rows and copy outputs are retained for independent audit.
Each frame advances 16384 integer ticks (0.015625s), for 0.046875s total.

Controlled supply is on, off, on. Initial physical head inventory is 1mm³. The
test observes:

| Interval | Cumulative external water (mm³) | Outcome |
| --- | ---: | --- |
| 1 | 1.150346518 | initial merge, incoming birth packets and head/film transfer |
| 2 | 1.150346518 | existing inventory moves/evaporates; no source replay |
| 3 | 2.300693035 | newly admitted supply is added once |

Initial ledger rows remain unchanged across frames. Source outputs retain the
entire field-time debt; two half steps consume it to zero without replaying source
or pool rows. Each checkpoint carries its own token and phase 2. Head force is
also checked against the independent double-precision oracle at the unchanged
32-float-epsilon/1e-9 gate. Cumulative water/momentum closure retains the existing
128-epsilon accumulated bound.

The fixture uses 8 head slots, fixed planar geometry/pose, controlled SI/source
parameters and a 13×7 field. Local wet-height feedback and pool return are disabled
in this recurrence fixture. Film/micro/head inventories themselves are retained
and computed; no claim about those unexercised feedback hooks follows. The small
time span does not establish long-run stability, curved recurrent accuracy or
game quality/performance.

## Failure found and preserved

The first recurrence used the initial test helper's force header again in frame 2:
its token ended in 42 while the new request ended in 43. The source boundary was
valid, but the unchanged physical-context gate refused the flow. Final inventory,
ledger and checkpoint remained the previous step's inputs; time debt did not
advance. The complete failing arrays and pass bindings are preserved as
`initial_recurrent_failure.*`.

The fixture now stamps its current physical snapshot with the current token.
No shader, equality check or numerical tolerance was relaxed. This negative
control demonstrates that fresh clock/source labels cannot silently authorize an
old force snapshot.

## Verification and remaining gates

- 7 scenarios: normal, shader pending, unknown submission, numerical refusal,
  stale completion, schema/authority guards and the actual recurrent GPU chain.
- 525 WARP draws and 57 strict synthetic shader bodies; 24 bit-identical inventory
  copies, 15 admitted physical stages, 20 protected bank-slot bindings.
- The guard scenario exercises 48 refusal/lifetime assertions, including wrong
  markers/shapes/identity, unregistered resources, canonical rollback and bounded
  stage authorization. Submitted reads prevent early close.
- Every successful frame retires to exactly eight owned bank resources; fault
  cases retain the first committed bank until safe discard. Final cleanup releases
  all owned resources and source leases.

WARP uploads/readbacks arrays between shader draws. Persistent allocation and
completion behavior use the mocked canonical backend. This verifies the offline
composition and operator results, not a persistent CSP GPU bank, hardware fence
or target-device timing. Only a private offline clock advances. The game remains
unchanged. Final hashes/metrics are in
`docs/diagnostics/2026-10-18/s150/delivery.json`.

Next: authentic engine snapshots and upload provenance; verified ordered/
completion backend; recurrent curved/feedback and time-accuracy evidence, followed
by graph fusion, shared optics and measured warm game cost before live adoption.
