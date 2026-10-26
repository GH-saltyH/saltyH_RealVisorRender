# s141 — physical End/Mean producer and conservative packet handoff

Date: 2026-10-18
Status: ACTIVE

## 1. Implemented boundary

The uninstalled producer now constructs the imported transporter's End/Mean and
packed bank from authoritative physical end inventory, immutable accepted supply,
pool events, head inventory, physical cell areas and force/material snapshots.
It runs the unchanged twenty-six selected consumers, recipient force relaxation,
evaporation and a water/world-momentum ledger. This is an executable shader/Lua
graph, not a relabelling of the old P3 texture.

The prototype targets the existing **13×7 curved candidate** and can stage
1…4096 head packets. Root runtime, INI tuning, optics and installed probe apps
are unchanged. No new game run is required for this stage. Production stays
s87/s89. Runtime resolution, live P1/P2 conversion, interval owner/ledger commit,
accuracy admission and lifetime completion still need integration.

## 2. Physical input contract

| Imported resources | Meaning |
| --- | --- |
| 1 | Physical end: `(V_mm3, V·worldVelocity_m/s.xyz)` |
| 2–3 | Connected runs and world-space metric basis/Gram atlas |
| 4–11 | Existing eight s138 interval/checkpoint headers |
| 12 | Accepted external liquid rate: mm³/s and volume-rate-weighted world velocity |
| 13 | Immutable five-row production-format pool event packet |
| 14 | Physical head inventory: volume/world momentum; not raw P1 state/meta |
| 15 | Physical cell area in mm² and explicit resolved-support tag 1 |
| 16 | Token-bound five-row physical snapshot |

The physical snapshot contains token `(epoch,generation,intervalId,1)`, total
gravity+inertia acceleration and water density, local world air and air density,
viscosity/air coefficient/evaporation rate/max dt, and model version/reserved flags.
Inputs must be finite, physical coefficients nonnegative, density/area positive,
and head count consistent with the interval. Air and acceleration are already in
the same world frame as the metric. Gravity is not added a second time.

The Lua recipe requires `end_mm3_world_v1` and `resolved_film_v1`; legacy
film/micro/evap/runoff and coherent-point declarations refuse. These labels do
not prove arbitrary GPU payload contents. The producer must own valid physical
inventory and resolved areas; compressed/subcell footprint reconstruction remains
an open physical closure problem. No diameter, texel size, optical gain, Smear
mask or legacy impact-film channel enters the force/source equations.

## 3. GPU dependency chain

1. Compute the genuine interval plan from s138 headers.
2. If the checkpoint is fresh, debit the pool event from physical film and add
   accepted external rate × **original interval seconds** once. Reuse the
   unchanged production pool ownership/address decoder. Existing source-time
   ordering is retained from s95; it is not a continuous injection model.
3. Stage the corresponding empty physical head packet at rest. Occupied slots,
   wrong owners, out-of-domain events and excessive film debit refuse. Returned
   film momentum is recorded as a wall reaction, not lost or duplicated.
4. At donor depth `h_m=V_mm3/area_mm2·.001`, compute physical half-step End
   momentum and exact frozen-depth full-step Mean momentum. Density and
   viscosity come from the immutable physical snapshot. The existing s96/s99
   stable thin-film response is retained with explicit density.
5. Reduce source/head/force status in bounded 16×16 groups. Invalid source
   context makes the usable plan inactive. Extract genuine End/Mean/bank inputs.
6. Run the original observed twenty-six consumers without changing their
   shader bodies, typed values or numerical gates.
7. At recipient depth, complete the end-force half-step; preserve the used path
   mean, project momentum onto the recipient tangent plane and evaporate volume
   with the same proportional end/mean momentum removal.
8. Reduce recipient validity and require admission in both axes/branches. Return
   immutable **candidate** end/mean/heads and step-ledger roots. Refusal returns
   previous physical End/heads bit for bit and a zero step-ledger contribution.

Checkpoint resume (`fresh=0`) keeps already staged supply/head inventory and does
not apply the original event/rate a second time. Identical retry from the same
immutable base produces identical bits. A real owner must preserve these handles
and apply ledger contributions only after the whole required transaction commits.
This module does not itself publish a game clock or cumulative interval ledger.

Head packets currently participate in conserved ownership only: existing heads
are held, and returned heads start at rest. Full P1 position/meta/motion, P2
birth/bounce/reservoir conversion and outgoing-film contact remain next work.

## 4. Physical ledger

Eight compensated packet sums hold initial inventory, final inventory, external
input, diagnostic internal pool volume, applied impulse, wall reaction,
evaporation and end runoff. Initial/final inventory includes film and heads.

```text
final + evaporation + runoff + wall
    - initial - external input - applied impulse = 0
```

Internal pool volume is not an external loss. Donor/recipient normal momentum
and pool return-at-rest momentum are wall reactions. Both force halves contribute
their actual end-momentum impulse. Mean runoff stays diagnostic in the unchanged
consumer roots; Mean is a travel packet, not additional water inventory.

## 5. Verification

**958 WARP draws / 24 strict /WX /Ges shader bodies** pass with no warnings:
954 complete-chain/prefix draws and four extra large-inventory ledger reductions.
Twenty physical/refusal cases cover curved YX and sparse XY, planar inviscid and
stiff-viscous response, dry state, newly wet invalid recipient geometry, checkpoint
resume and invalid force/source/head data. The maximum-slot prefix test detects
an invalid 4096th head through the bounded reduction tree.

The independent float64 frozen-depth oracle observes maximum donor half-end/
full-mean velocity error **5.54e-9 m/s**. All admitted water/momentum residuals fit
the stated 128-float-ULP aggregate bound. This is arithmetic/ownership evidence,
not a new convergence or general physical accuracy claim.

Six mocked managed-lifetime cases exercise pending prefixes, unknown submission,
default-off ordering, unsubmitted cancellation and capacity. Sixteen input read
pins stay held after submission; two bundles reach 32 pins. No submitted outputs
or borrowed inputs are freed. Unlike the earlier logical-only bridge operation,
the s141 bridge additionally refuses publication without a trusted completion
capability and observation. Neither exists for a live CSP integration yet.

## 6. Cost and remaining gates

For eight heads the explicit graph is **16 borrowed inputs + 45 private passes**,
61 resources, 73,168 nominal bytes at this tiny test grid. The 4096-slot graph has
49 passes/65 resources. The managed schema is bounded at 96 resources/passes;
each shader call remains within CSP's 32-texture limit. Allocation/driver overhead
and actual game timing are unmeasured. WARP uploads test arrays between draws.

This explicit graph is not ready for production cost acceptance. Force/source
bank generation repeats calculations across output banks; extraction, status and
ledger passes are deliberately separated for diagnosis. Fusion, target lifetime
reuse, runtime-scale geometry and a bounded live scheduling owner must be designed
and measured before enabling it in the game. No FPS improvement is claimed.

Next connect real P1/P2 accepted water and physical head state to these packet
inputs with one-time ownership, add full head/lifecycle and cumulative-ledger
commit, and validate recurrent force/depth/contact behavior. Do not bypass the
remaining source-frame, numerical accuracy or GPU lifetime gates.
