# s143 — paired merge and retained boundary-exit ownership

Date: 2026-10-18
Status: ACTIVE

## Implemented boundary

The uninstalled s142 adapter is extended with an executable paired-merge receipt
and a retained exit trace. It can account for a retired donor, the surviving
combined volume, and an immediately exiting survivor in the same interval.
It exports candidate head packets/ownership, not a game publication.

Production still uses s87 physics/s89 diagnostics. No game files are changed.
The stage does not yet rasterize sources into s141 film inventory or provide the
joint cumulative field/head ledger, source clock and completion authority.

## Findings in the existing implementation

The production command canvas is RGBA8 UNorm: R/G encode the partner's two-byte
slot, B encodes command kind and **partner generation modulo 64**. Both production
state/meta shaders recheck reciprocal commands, generations, geometry and role.
Six-bit generation checks alone cannot distinguish a command reused after 64
birth generations. Full generation provenance must come from the command creator.

Production `rainAdvance` returns `(2,2,0,0)` for all three cases:

1. Leaving the signed UV rectangle;
2. Entering a masked/unsupported region;
3. Still having motion time after its 128-iteration numerical work limit.

This loses the last supported position/velocity, and merges numerical exhaustion
with physical departure. The s143 derivative retains the last state and separates
those reasons. It does not reinterpret exhausted numerical work as physical runoff.

## Frozen inputs and source requirements

The recipe takes the original 13 raw-channel inputs plus four resources:

| Input | Contract |
| --- | --- |
| 14 | Canonical float copy of production RGBA8 command values |
| 15 | Per-command `(selfFullGeneration, partnerFullGeneration, snapshotFrame,1)` |
| 16 | Three-row immutable merge/transport configuration |
| 17 | Matched post-force/pre-advance `(signed UV position, raw UV/s velocity)` |

Configuration rows are the interval token, `(contactAngleDeg,reach,snapshotFrame,1)`,
and `(referenceUnit,referencePerMM,matchedDt,1)`. The token/frame must match the
original adapter's frozen header. Command snapshots must not be from the future
or span the 4096-generation wrap window. That window assumes the production P2
contract of at most one generation increment per slot/frame and an epoch reset
when the source session changes. It is not proof of arbitrary caller provenance.

The full generation stamp must be captured **when the command is created**. It
must not be fabricated later from whichever current heads happen to be bound.
Post-force input must similarly be retained before the original transport can
discard the last state. Actual command-creator/force-producer hooks, immutable
source leases and live frame scheduling still need wiring.

No new engine API is used. The common lease provider expands to 17 pinned inputs
per bundle, capacity two. The existing s141 bridge remains unchanged and refuses
publication without trusted completion.

## Paired ownership

Commands are decoded without clamping an out-of-range partner onto another slot.
Canonical bytes, both active states, full and low generations, reciprocal links,
snapshot frame, surface support and reciprocal physical contact distance must
agree. A chain or asymmetric pair refuses the whole export.

Physical contact radii come from authoritative **meta.G volume** and contact angle
using the existing SI primitive. Both endpoints' metric distances are checked.
The larger physical volume survives; equal volume chooses the lower slot.
The renderer's radius codec cannot change that choice or the physical footprint.
SI attraction commands carry no ownership transfer; as in current SI routing,
their steering effect is inactive.

Each accepted pair produces two exactly opposite signed volume/world-momentum
transfer packets. The loser retires; only the winner stores the combined volume.
The volume-weighted UV centre is checked against support. Combined old momentum
is projected into the new tangent plane at that centre. The projection difference
is recorded **once** as a wall-reaction packet on the winner.

Nonfinite sums and absorptions whose positive donor volume rounds completely out
of the survivor's stored float32 volume refuse. Ordinary aggregate roundoff still
uses the existing arithmetic budget bound; exact real-number arithmetic is not
claimed. No source-water or impact event is synthesized for a merge.

The six-row internal ownership atlas stores merged state/meta, signed transfer,
projection wall reaction, code/role/partner and original physical inventory.

## Retained transport and immediate exit

The builder extracts the **original** bounded `rainAdvance` function and changes
only its return type/return expressions. Its step sizes, 128-step bound, metric
transport and floating-point operations remain unchanged. A reversible textual
audit and WARP bit comparisons against the original function guard this claim.

The trace adds four rows: returned raw state, last supported state, exit packet,
and `(reason,remainingMotionTime,usedMotionTime,1)`.

- Reason 0: normal completion, stopped motion or a skipped inactive/newborn slot;
- Reason 1: UV edge;
- Reason 2: mask/support edge;
- Reason 3: work-limit exhaustion;
- Reason 4: invalid context/state.

Reasons 1/2 export the merged/current volume and its last supported world-component
velocity. Provisional/final metadata must retire it **in that interval**, with no
duplicate legacy P2 exit charge in event row 3.Y. A merged survivor can carry both
partners out once. Existing invalid-position inventory without a retained source
state refuses instead of inventing its missing outgoing momentum.

Reasons 3/4 refuse every candidate/receipt/head export. Reason 3 emits no exit
water. Source resources remain immutable; a future owner must retain time debt
and retry/subdivide it. This stage is not itself a remaining-time scheduler.

The original reference-unit transport is admitted only when its reference product
and the uniform physical transform scale still denote **one millimetre**. Display
diameter gain must not be substituted for this physical calibration. Nonuniform
scale refuses on this path.

## Candidate packet budget

The extended atlas has 20 rows. Rows 0–17 retain the s142 meanings; row 18 adds the
signed merge transfer, row 19 the once-owned projection wall reaction.

```text
final heads + trail + head evaporation + exit + wall
  - old heads - attached births - pool head return
  - signed merge transfer - observed motion impulse = 0
```

Signed merge transfers cancel across the pair. The scalar source-water equation
also includes film/capacity, micro, bounce and external input volumes separately.
Internal pool return is conditional on a corresponding future film debit.

As before, the motion impulse is an **observed residual**, not an independent
force oracle. It includes frame/transport redirection not yet separated into all
surface reaction terms. Impact/bounce momentum is not present in the old event
format; volume-only channels are not silently treated as complete momentum input.
Thus packet ownership checks do not establish full physical force/field closure.

## Verification and cost

The checker exercises mixed merge/birth/pool/exit, equal-volume role selection,
merged-survivor exit, mask exit, retry, four radius-codec gains, malformed/stale/
asymmetric commands, full-generation aliasing, duplicate exits, missing donor or
survivor debits, wrong trace state and transport calibration. A valid 4096-slot
control includes a reciprocal pair at slots 4094/4095, followed by a last-slot
generation fault. The 128-step exhaustion test verifies no exit charge.

Independent float64 metric/transform calculations check old/exit inventory and
pair momentum/projection packets. Original production transport states are also
compared bit for bit for normal, hole and exhaustion cases. No numerical tolerance
is fitted to these comparisons. Six mocked lifetime cases retain submitted input
leases and refuse completion-free publication/disposal.

**263 WARP draws / 6 strict `/WX /Ges` bodies**, 32 channel/refusal cases,
three original-transport bit controls and six managed lifetime cases pass without
shader warnings. The exhaustion-only case has valid ownership in every slot;
only its deliberately overloaded transport refuses.

The diagnostic graph has **17 imports + 7 private passes** for eight heads, and
9 passes at 4096 heads. Each call binds at most 19 textures, below the verified
32-texture limit. Multirow diagnostic calculations repeat work; fusion and target
reuse remain necessary before production adoption. No actual CSP timing or FPS
improvement is claimed. WARP uploads intermediate test arrays between draws.

Evidence: `diagnostics/2026-10-18/s143/delivery.json`, `ownership_checks.json`,
`graph_values.json` and `instrumented_advance.hlsl`.

## Next implementation

Rasterize accepted external/paired trail sources and pool debits into physical
film and separate micro inventory, then connect the s141 transport candidate to a
joint head/field cumulative ledger and interval owner. Wire actual command stamps,
post-force retained state and frame leases. Recurrent footprint/contact accuracy,
impact momentum, time-debt scheduling, live completion authority, fusion and
runtime-scale cost remain open before changing the game's physics path.
