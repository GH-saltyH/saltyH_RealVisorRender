# s149 — persistent inventory handoff

Status: ACTIVE
Date: 2026-10-18
Scope: offline, uninstalled; game physics remains s87, diagnostics s89.

## Boundary closed

A completed interval can now copy its inventory into independent GPU allocations,
release the original frame graph and expose retained read leases for the next
interval. This closes the previous dependency on keeping every temporary graph
allocation alive merely to retain final water. It does not connect the game,
advance its public clock or establish a live CSP completion fence.

The copy includes eight resources:

| Resource | Source |
| --- | --- |
| raw position/velocity | s148 head `newState` |
| physical metadata | s148 head `finalMeta` |
| film, pinned micro, physical heads | final s145 transport outputs |
| cumulative water/momentum ledger | final s145 transport output |
| phase-2 checkpoint | final s145 transport output |
| previous object-to-world transform | retained s148 current-pose input |

Raw head state/metadata and physical head packets have different jobs and are
both retained. The pose is required to interpret the previous raw UV velocity in
the next head interval. Geometry changes require a separate reset/remap policy;
this handoff refuses a changed geometry key.

## Composite reader

The derived `s149_frame_owner` preserves the s148 admission and stage protocol.
`inventory()` acquires private head and final-transport root pins together. The
pose input remains protected by the head stage's immutable input lease and by the
composite consumer preventing frame retirement. One inventory reader per frame is
allowed. Raw handles are passed only to the trusted copy callback.

`pumpInventory()` attempts at most one copy draw per call. Pending means that
call submitted nothing; earlier submissions remain retained. Partial progress
does not imply completion. Unknown submission blocks retry and requires discard
after completion. The existing completion request binds the opaque owner/frame/
consumer, latest invocation count and frame/stage keys. Polling a partial prefix
is refused unless it has been cancelled for discard. A preceding stage proof or
an earlier copy attempt cannot complete a later use.

Eight copies execute through the existing readiness-reporting shader-copy bridge,
using one source texture per pass. No CPU pixel readback is part of the handoff.
Copy completion must be independently established before numerical verification.
The verification callback is synchronous, cannot submit/retain reads, and must
admit matching identity, phase 2 and zero debt. Invalid numerical receipts or
seals retain the candidate for safe discard rather than replacing current stock.

## Bank transaction and next reads

`s149_inventory_bank` is disabled unless offline replay, ordered submission and
the completion capability are explicitly enabled. The first inventory requires a
trusted seed verifier. Later candidates must continue the current end tick,
token, frame ordering, source tick and geometry. Weather/pose/material can change
in the next identity; their actual sealed uploads are still a backend seam.

Commit is a synchronous private ownership exchange after copy completion and
numerical admission. It checks that the parent remains active and uncancelled.
It updates only an offline private clock and returns the original composite root
pins. The completed frame graph can then retire. The independent bank buffers
remain alive. There is no game publication, timeout-completion guess or implicit
drop of time debt.

`openRead(nextIdentity)` returns an opaque reader capability plus keyed resource
descriptors, not public canvases. Its source backend integrates with the existing
immutable source provider. Each acquisition validates lineage, resource key,
revision, full descriptor and canonical live allocation. Submitted provider reads
cannot release before their own completion. Closing the reader is blocked while
source leases remain. Edits to returned descriptors cannot alter the bank.

At most two bank versions exist, including a pending copy. An old bank with
readers remains alive when the next bank commits; a third candidate is refused
until the old readers release. New acquisitions from a retired bank are refused,
while existing immutable leases stay valid. Collection disposes only private
copies. Additional bounds are eight reader capabilities, 32 source pins per
reader and 64MiB of private inventory per bank (128MiB for two full banks).
Allocation or byte-limit failures roll back private allocations and keep current
stock unchanged. These are storage bounds, not a production memory target.

## Evidence

The checker executes the same real s146→s148→s144→s145→s145 physical frame as
s148, followed by eight actual WARP inventory copies. Every copy is bit-identical
to its source. The original graph retires before the next-identity source provider
binds all eight copied resources. Water/momentum closure, head volume and the
phase-2 zero-debt checkpoint are checked independently.

- 175 WARP draws, 57 strict synthetic shader bodies.
- 41 owner/inventory scenarios, including the 28 prior mocked owner modes,
  12 new inventory modes and the actual GPU frame/copy/read case.
- Six frame-schema and six root-lease guards remain covered.
- Five next-read lineage refusals and reader/pin capacity guards.
- Pending, accepted-then-unknown, partial cancellation, allocation/byte refusal,
  numeric/seal refusal, parent cancellation, default/seed refusal and two-bank
  collection are exercised.

The two-bank scenario uses a controlled second candidate to test lifetime and
capacity, not a second physical simulation. The real GPU evidence covers one
physical frame, its copy and subsequent canonical reads. Completion callbacks
remain injected offline proofs. WARP uploads/readbacks arrays between draws;
persistent allocation/retirement uses the mocked bridge backend, so no live
persistent GPU-bank lifetime or hardware fence has been established.
No actual CSP performance, cross-frame recurrent
physics accuracy or live completion claim follows from these tests.

See `docs/diagnostics/2026-10-18/s149/delivery.json` for final hashes and metrics.

## Next

Bind authentic engine snapshots, previous/current pose and merge creator/upload
identities to this owner and bank. Establish actual ordered/completion evidence
and run repeated physical intervals from these retained inventories. Then fuse
diagnostic intermediates and measure recurrent accuracy, common head/film optics
and warm target-device cost before enabling a live preview.
