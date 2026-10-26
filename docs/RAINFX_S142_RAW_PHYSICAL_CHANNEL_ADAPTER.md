# s142 — actual P1/P2/P3 channel adapter

Date: 2026-10-18
Status: ACTIVE

## Implemented boundary

An executable, uninstalled GPU recipe now decodes the **actual production channel
formats**, rather than assuming that P1 state or P3 RGBA already contains a world
water packet. It emits candidate physical head inventory and per-slot ownership
descriptors for the next joint head/field transaction. Production stays s87/s89.

This is offline verification with synthetic raw-channel inputs. It is not a
live P1/P2 binding, a complete lifecycle solver, or a completed s141 source raster
handoff. No new game test, install, commit or push is required for this stage.

## Source channels and units

Thirteen immutable, jointly leased resources are required:

| Resources | Actual format |
| --- | --- |
| 1–2 | Old state `(signed U,V, raw UV/s)` and old meta `(radius codec, V_mm3, age, generation*4+status)` |
| 3–5 | New state, provisional P1/P2 meta, final P3-debited meta |
| 6 | Original five-row P2 birth event |
| 7 | Original five-row P3 source/transfer descriptor |
| 8–10 | Local metre/UV Jacobian U,V and boundary alpha |
| 11–12 | Old/new physical transform linear rows, each 3×1 RGBA |
| 13 | Six-row version, interval, frame and physical-mode header |

`meta.G` is authoritative volume. The radius codec never sets volume, velocity,
mass or momentum. SI raw UV velocity becomes `du_world*velocityU +
dv_world*velocityV`; there is no display gain, texel calibration or legacy
`gRainMetersPerUnit` division. Old and new snapshots use their respective physical
transforms and point-loaded metric at their respective positions. These are world
components of velocity relative to the surface, not absolute car translation.

The header contains:

1. `(epoch,generation,intervalId,1)`;
2. previous published token, requiring exactly the preceding interval;
3. `(oldStateFrame,newStateFrame,eventFrame,descriptorFrame)`;
4. `(SI=1,P2=1,P3=1,matchedIntervalSeconds)`;
5. `(fieldWidth,fieldHeight,pad,5)`;
6. positive geometry/old-transform/new-transform revisions and format version 1.

This header is an assertion from a trusted, immutable source owner. A shader
cannot prove provenance merely because numbers match. Actual source-provider
revision/frame integration remains required. Intervals over the current raw
motion model's 0.05-second limit refuse; elapsed time is not silently clamped.

## Export atlas

The candidate atlas is `headCount × 18`, not a field texture:

| Row | Meaning |
| --- | --- |
| 0–2 | Old, provisional, final head `(V_mm3, V*worldVelocity.xyz)` |
| 3 | External attached head birth packet |
| 4 | Internal pool-return head packet, initialized at rest |
| 5–6 | Trail transfer and head evaporation packets |
| 7 | Boundary exit packet |
| 8 | Film plus capacity source volume |
| 9 | Micro reservoir source volume |
| 10–11 | Bounce and total external input volume |
| 12 | Observed head momentum-change residual |
| 13 | Refusal code / slot index |
| 14–17 | Original path, transfer/support, incident and source-support descriptors |

Rows 8–11 are explicitly **volume-only**. The P2 event does not retain full
incident/rebound momentum, and the old P3 field does not store momentum. No
invented zero-momentum impact law is passed off as measured physical input.
Micro stays separate inventory. Capacity joins film, matching production P3.

The P2 spawn volume can be a pool return. External attachment is instead event
row 3.Z; pool transfer is row 4.Z. If pool return changes the spawn location, the
incident source keeps **row 4.XY**, preserving the different original location.
Neither pool return nor capacity is counted again as external incident water.

For the proposed transfer packet, trail and head evaporation inherit the new
head's surface-relative velocity. Row 12 is an **observed residual impulse**,
including basis changes; it is not an independent force prediction or force
validation. Pool field momentum removal/wall reaction is still pending, so this
adapter alone does not establish a complete field+head momentum budget.

## Transition and refusal rules

Supported transitions include same-generation motion, external birth, pool birth,
generation wrap, trail/head evaporation, full depletion, idle slots and explicit
boundary retirement. Birth tag, position and velocity must agree with the exact
immutable event. The two P3 subtractions must reproduce final meta.G exactly.
Partial depletion retains age; full depletion resets lifecycle/age.

Winner/loser merges refuse until the immutable partner command and paired
ownership are integrated. A change in old-to-provisional head volume is not
silently interpreted as rain or evaporation. Boundary retirement can be decoded
only where the production invalid-position sentinel has zero velocity; a nonzero
velocity with a missing last valid metric refuses. Recovering the true outgoing
momentum requires retaining that pre-exit state in the future producer.

The adapter also refuses stale tokens/frames, legacy modes, singular/overflowing
transforms or bases, invalid packets, unpaired debits, wrong incident coordinates,
wrong trail endpoints and invalid supports. It applies the existing 128-float-ULP
aggregate budget bound, with no new fitted tolerance. Geometry coordinates and
paired meta debits remain exact channel comparisons.

Codes: 1 context, 2 raw data/meta, 3 lifecycle/velocity, 4 paired head debit,
5 deposition geometry, 6 water partition, 7 nonfinite packet result.

Any invalid slot zeros **all** exported descriptors, head packets and candidate
receipt. Original imported raw resources remain untouched. A receipt is only a
token-bearing candidate. Identical retry returns identical bits; an already
published interval must be refused against the updated published token. Only a
future joint transaction owner may consume source events and commit stocks once.

## Verification and cost

The stage checker executes the shader recipe on D3D11 WARP and compares decoded
head packets against an independent float64 Jacobian/transform calculation.
It also executes the unchanged production `rainFilmMeta.hlsl` with the actual
`rainPhysicsSI.hlsl` primitives, verifying its debit matches the adapter exactly.

Checks include mixed lifecycle/source slots, codec gains 0.0001/0.46/1.5/100,
immutable retry, 24 recurrent debit/receipt steps, stale/malformed/merge refusal,
finite arithmetic overflow and maximum 4096-slot status reduction. The maximum
count has both a valid control and a faulty final-slot case. The receipt test is
not a GPU completion fence.

**330 WARP draws / 4 strict `/WX /Ges` bodies**, 39 channel/refusal cases,
24 recurrent steps and six managed lifetime cases pass without shader warnings.

The existing s138 thirteen-resource provider and s141 completion-guarded bridge
are reused unchanged. Six mocked lifetime cases cover normal/pending/unknown
submission, default-off ordering, unsubmitted cancellation and two-bundle capacity.
Submitted inputs stay leased; outputs are not disposed or published without
trusted completion. Live CSP completion authority remains unverified.

The eight-head diagnostic recipe has **13 imports + 5 private passes**, 18 total
resources. At 4096 heads it has 7 passes/20 resources. Each call binds at most 13
textures. The 18-row diagnostic atlas is calculated once and copied for export;
it is not a production cost target. WARP uploads test arrays between draws.
Actual GPU/CPU timing and target lifetime reuse are unmeasured.

Evidence: `diagnostics/2026-10-18/s142/delivery.json` and `adapter_checks.json`.

## Next implementation

Consume immutable merge/exit ownership, then rasterize accepted source and paired
head-to-field transfers into the s141 physical inventory without double staging
pool or external water. Preserve unresolved micro and explicit impact momentum
closure. Add the joint cumulative ledger/interval owner and actual source-frame
leases. Runtime-scale geometry, recurrent footprint/contact accuracy, completion
authority, fusion and measured cost remain gates before game adoption.
