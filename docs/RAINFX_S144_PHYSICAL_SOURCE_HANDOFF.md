# s144 — physical source raster and source-phase inventory transaction

Date: 2026-10-18
Status: ACTIVE

## Implemented boundary

An uninstalled GPU recipe now takes an admitted s143 head packet and deposits its
paired trail water and explicit retained impact packets into physical film and
separate micro inventory. Pool return debits the old film in the same transaction
as the corresponding new head. Film, micro, head, step/cumulative ledger and
source-checkpoint candidates are selected together or retain their old values.

This is source staging, **not s141 time integration**. No global simulation clock
is advanced. Actual production stays s87 physics/s89 diagnostics. This stage has
no app hooks, installation or changes to RainFX optics/tuning.

## Twelve immutable inputs

| Input | Contract |
| --- | --- |
| 1–3 | s143 20-row candidate heads, admitted token receipt, six-row raw snapshot header |
| 4 | Matching five-row P2 event, including original incident and pool spawn locations |
| 5–6 | Old film and micro physical packets `(V_mm3,V*worldVelocity.xyz)` |
| 7 | Physical cells `(area_mm2,coverage,resolvedSupport=1,version=1)` |
| 8 | Four-row explicit impact packet stream: incident, retained film, retained micro, bounce |
| 9 | Five-row source token/shape/frame/model/previous-token header |
| 10–12 | Previous eight-row cumulative ledger, completed source checkpoint, original physical heads |

The four impact volumes must exactly match the admitted head stream's recorded
external/film/micro/bounce volumes. Their momenta are explicit new inputs. The old
P2/P3 format does **not** contain these full vectors; the prototype cannot derive
them by renaming old RGBA channels. An actual retained-impact producer and its
immutable frame bindings remain to be implemented. Tests supply declared impact
packets; no new impact-force law is claimed.

Original head inventory is supplied independently of the candidate. Therefore a
refused/zero upstream receipt can preserve original water instead of treating a
zero candidate as the original head stock. An admitted candidate must match it.

The source header contains:

1. `(epoch,generation,intervalId,1)`;
2. `(fieldWidth,fieldHeight,descriptorPad,headCount)`;
3. `(poolTick,matchedHeadFrame,impactModelRevision,1)`;
4. `(fresh=1,resolvedModel=1,maxKernelSupport=16,0)`;
5. previous completed checkpoint token.

The head receipt/header and source shape/frame must match. The prior checkpoint
must be phase 2 (interval complete), exactly the preceding token, with no remaining
time. These labels assert trusted provenance; they do not establish GPU completion
or validate an arbitrary caller's claim about its texture contents.

## Bounded source raster

The production P3 integer-width tent basis and piecewise Simpson swept-line
kernel are reused unchanged. Their infinite-cell lattice partition is one. The
new descriptors retain actual world packet momentum as well as volume.

The caller translates each source/path into the recipient cell's local coordinates
before invoking those unchanged helpers. An initial full-resolution test exposed
absolute-coordinate interpolation error (maximum 1.41e-8 packet-volume error,
exceeding the existing per-cell oracle gate). Cell-local evaluation removes that
coordinate cancellation without widening the numerical tolerance. This is an
offline arithmetic correction, not a claim about current game trail appearance.

Production 96-slot tile masks, four exact 24-bit float words, and nonempty-word
summaries select relevant heads. Pixel work walks occupied masks rather than a
fixed all-head scan. Slot 4095 is represented; no 384-stamp or dense-tile truncation
is introduced. Dense overlapping sources can still be expensive and require
measurement. The graph does not require per-drop CPU stamping/readback.

Descriptors must already refer to this field resolution. The adapter subtracts
the declared padding; it does not silently rescale old texel radii to another
atlas. Small-grid fixtures declare resolved integer-width kernels specifically
for those grids. They are ownership/numerical tests, not a new physical droplet
size calibration or a solution to compressed/subcell footprint closure.

Existing inventory is already coverage-weighted and is not multiplied by coverage
again. Incoming packets split into retained `coverage` and rejected `1-coverage`
parts. A zero-area/zero-coverage cell rejects incoming water as runoff; existing
water in such a cell refuses rather than disappearing.

Off-domain loss is computed from **the deposition stream total minus the raw
pre-coverage raster total**, using the reused partition-of-unity kernel. It is
not a residual of old/final inventories used to repair an arbitrary budget.
Independent float64 per-cell kernel integration verifies that difference against
the genuinely clipped kernel tail. Interior-only sources also constrain the
allowed missing amount; a dropped interior mask is rejected.

Tiny cancellation is admitted under the pre-existing 128-float-ULP aggregate bound
and 1e-9 floor. Negative/nonphysical tails outside that arithmetic allowance
refuse. No tolerance is fitted to a new fixture. Physical boundary flux below
the arithmetic envelope is not separately resolved by this float32 model.

## Pool and micro ownership

Pool addressing reuses the production unique 16×16-region/slot/tick decoder.
Each positive return must belong to that slot, begin with an empty old head, and
be funded by old film at the spawn cell. Micro and fresh arrivals cannot fund it.
The requested float32 debit must equal the actually removed film volume; rounded
away debits refuse. Corresponding film momentum is removed proportionally and
recorded as a wall reaction because the returned head starts at rest.

Micro remains separate inventory. This stage explicitly uses a **pinned micro
reservoir**: old and retained micro momentum goes to the surface; retained volume
stays in micro at zero relative velocity. It does not automatically join film or
receive an unbudgeted evaporation/optical effect. Those physical closures remain
later work.

Retained film/trail momentum remains in the new film packet. Recipient tangent
projection, field forces and transport belong to the next s141 handoff. Impact
capture reaction is the supplied incident packet minus retained head/film/micro
and bounce packets. As with s143, this is an observed ownership reaction, not an
independent validation of impact or head forces.

## Ledger and source checkpoint

Eight rows use the existing s141 meanings: initial inventory, final inventory,
external input, diagnostic internal pool volume, applied head impulse, wall
reaction, head evaporation and runoff/bounce/head exit.

```text
final + wall + evaporation + runoff - initial - external - impulse = 0
```

Initial/final inventory includes **film + micro + heads**. Pair transfers cancel
inside the admitted head stream. Pool return is internal. Cumulative row 0 keeps
the first initial stock; row 1 is replaced by final stock; only flow/impulse rows
are added. Stored rows must have valid packet types, match current inventory and
satisfy the original conservation bound. A numerically balanced negative source
history is still rejected.

An admitted source checkpoint becomes `(current token)` plus
`(phase=1,lastSourceInterval,remainingIntervalSeconds,1)`. It records source
ownership while retaining the **entire field-transport time debt**. The same
source cannot be applied again, and another fresh interval cannot start from
phase 1. Refusal returns original film, micro, heads, cumulative ledger and
checkpoint bit for bit, with a zero step ledger.

Next, a real field integrator must consume the remaining time and finish phase 2.
It must not reapply raw pool events or external source packets already staged
here. A typed phase adapter to s141 and its force/accuracy checks are still open;
no false completion flag or `fresh=0` relabelling is used here.

The cumulative test authorizes six **controlled identity-completion fixtures** to
exercise source ownership across intervals. Those are not actual s141 integration,
an elapsed-time accuracy test or a GPU completion fence. Source staging is a
batched operator; continuous arrival/deposition timing and head/film coupling
accuracy must be assessed before adoption.

## Verification and cost limits

The checker executes the unchanged s143 shader recipe to supply this adapter,
then compares source raster, clipped tails, film/micro packets and joint ledger
with an independent float64 kernel/packet calculation. Cases cover coverage,
holes, off-domain trail, pool funding/ownership, token/frame/phase mismatch,
stale inventories, invalid history, retry and source reapplication. It includes
4096 slots with a source in the final sparse-mask word and a 1024×256 field.

**555 WARP draws / 16 strict `/WX /Ges` bodies**, 27 source/refusal cases,
five upstream head graphs, six cumulative source intervals and six mocked
lifetime cases pass without shader warnings. The maximum raster packet-component
error against the float64 oracle is **8.20e-10**, within the unchanged gate.

The existing completion-guarded s141 bridge is reused. Twelve input leases per
bundle, two-bundle capacity, pending/unknown submission and unsubmitted
cancellation are exercised with mocked backends. Submitted sources and outputs
are retained; no trusted live CSP completion authority exists yet.

The prototype intentionally separates diagnostic raster/status/ledger targets.
Memory/pass counts are reported in `delivery.json`, not a production cost promise.
The eight-head 13×7 graph has 15 private passes/27 resources and 28,144 nominal
bytes. The 4096-head graph has 19 passes/31 resources and 2,654,368 bytes. The
1024×256 field has 19 passes/31 resources and **63,155,408 nominal bytes**, including
imports. Its separated diagnostic allocations need fusion/reuse before adoption.
Each call stays within 32 textures. WARP uploads arrays between draws, so these
checks are not actual target GPU/CPU timings or proof of persistent execution.
Fusion, target reuse and warm-run game cost remain required.

Evidence: `diagnostics/2026-10-18/s144/delivery.json`, `handoff_checks.json`,
`graph_values.json` and `large_and_full_fields.npz`.

## Next implementation

Connect this source-staged phase and separate micro stock to the observed s141
field transport, accumulate its forces/evaporation/runoff, and complete interval
ownership without repeating source events. Add the actual impact packet producer,
source-frame hooks and trusted lifetime authority. Recurrent physical/contact/time
accuracy, full-resolution geometry and measured cost remain adoption gates.
