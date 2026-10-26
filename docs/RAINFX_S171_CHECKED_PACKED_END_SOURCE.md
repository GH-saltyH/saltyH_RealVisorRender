# s171 — checked packed End views for conserved sources

Date: 2026-10-19. Status: ACTIVE (offline native component and budget comparison).

## Implementation

`prototypes/s171/s171_packed_source.lua` composes the s170 source-cell adapter
and conserved source transaction with a checked End view of an immutable packed
End/Mean inventory. The imported film must be RGBA32F, one mip, W×2H, with End
starting at row zero and Mean at row H. The logical source domain remains W×H.
Host validation checks the explicit layout and resource/view/lease identities;
an ordinary H-high film cannot be relabelled as a packed bank.

All original-film reads, including the pool-availability macro, source-cell
evaluation, totals and rollback, now use a bounded point-load helper. It refuses
negative coordinates, rows at or above H, X outside W and nonzero mip indices
with a finite invalid packet. Shader context checks require the physical 2H
dimensions. Source outputs remain H-high; the source never publishes Mean as
old inventory. Changed shader bodies use distinct cache keys. Unknown sampling
forms and repeated adaptation are refused.

The helper is an addressing adapter. It changes no mass, coverage, force,
transfer, runoff, ledger or admission formula. The complete packed resource
must remain leased through all source consumers and any rollback/old-bank
readers. A logical End view cannot release or overwrite the underlying Mean
half early. Identity strings refer to a verified owner; they do not prove
arbitrary GPU resource provenance, payload validity or completion by themselves.

## Native evidence

**491 native WARP draws, 31 source graphs and 24 explicit GPU End crops** pass.
The stage-private harness reuses the byte-verified s169 native binary read-only;
strict shader compilation and D3D11 debug checks report no warnings.

- All 23 applicable preserved source cases match s170's seven public roots
  bit-for-bit: five admit and 18 refuse. Every packed input's explicit GPU
  End crop also matches its original H-high fixture bits.
- Four cases additionally execute the unchanged s170 source graph on the
  cropped input: ordinary supply, fractional coverage, masked runoff and
  insufficient pool funding. Direct packed and copied inputs retain all bits.
- Changed Mean and NaN-filled Mean controls leave the End-only source outputs
  unchanged. These are adversarial isolation tests, not approval of arbitrary
  Mean data for transport or other consumers.
- Stale area receipt and old water in a hole still refuse and reproduce the
  previous End inventory, micro, heads, cumulative ledger and checkpoint,
  with zero step ledger. The rollback path does not return Mean rows.
- All 262,144 synthetic full-grid End texels match an explicit crop. Separate
  first/last-End and excluded-Mean/outside/mip probes verify the half-open
  row bounds. This tests view addressing, not full-grid physical evolution.
- Nine malformed descriptor/identity cases and double adaptation refuse.
  The preceding injected bin-fault case remains excluded as documented in s170;
  its original evidence remains preserved.

The explicit reference is a native point-load crop into an H-high target,
read back and supplied to the reference source graph. These isolated draws
do not exercise one retained native source/transport owner or establish a
general CSP completion fence. Copy bandwidth, FPS and target-device cost
are not measured. The current runtime, settings and installed game are unchanged.

## Joint lifetime result: direct packed is not the smallest bank

Six two-frame descriptor plans include full R8 head geometry, the actual s170
two-pass cell adapter, separate current/expected frame headers, previous/new
inventory, source, four transport quarters and explicit reader lifetimes.

| Inventory policy | Retained-cache live MiB | Retained-cache reservation MiB | Proposed core-cache reservation MiB |
| --- | ---: | ---: | ---: |
| End-only bank, explicit final End copy | **110.687286** | **121.502808** | **113.104416** |
| Packed bank, source End crop | 114.687286 | 129.502808 | 121.104416 |
| Packed bank, direct source End view | 114.687286 | 125.502808 | 117.104416 |

Direct reading removes a 4MiB source End copy from the packed-bank path, but
does not reduce its live peak. The previous 8MiB packed bank remains pinned
until the next atomic inventory exchange. Compared with the End-only bank,
that adds 4MiB at the live peak and 4MiB of exact-shape reservation. Deleting a
copy pass therefore does not establish a lower whole-pipeline memory cost.

The **End-only bank remains the smallest verified descriptor proposal**.
Direct packed reading stays an optional offline component; it is not adopted
as the default inventory policy. Mean remains available for the transport
calculations that already require it inside the frame. Future common-optics
readers may add further lifetimes and must be charged separately.

All six typed-slot/lifetime certificates pass, while every 64MiB total gate
still fails. Core-cache retirement and static64+working64/total128 remain
unimplemented/unadopted proposals. This step grants no actual pooling,
joint execution or solver admission. Cold cache construction, changing-pose
replacement/quarantine, queue backlog, driver/image caches and common optics
remain outside these warm descriptor estimates.

Evidence is in `diagnostics/2026-10-19/s171/`: numerical results, graph layouts,
root hashes, strict compilations, six plans, certificates and `delivery.json`.
Main script and existing shaders, settings and textures are preserved.

## Next implementation

Keep the End-only bank as the cost baseline and optimize shared static-cache
retention and working-buffer lifetimes before combined native admission.
Current-frame area-header ownership, full-grid physical composition, bounded
frame/cache replacement, water/time closure, CSP completion, common optics
and measured target cost remain before game adoption. No user game test is
required for s171.
