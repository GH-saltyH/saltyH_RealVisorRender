# s146 — retained impact packets from the P2 incident calculation

Status: ACTIVE
Date: 2026-10-18
Scope: offline, uninstalled. Production physics remains s87, diagnostics s89.

## What changed

s144/s145 previously required caller-supplied retained impact momentum. P2's
five-row event atlas held volumes and attached-head UV velocity, but discarded
the original world incident velocity and surface normal. Later head velocity
cannot recover those quantities, especially after pool replacement or motion.

The new producer instruments the original `rainBirthEvent.hlsl` at the incident
calculation. It preserves DSD sampling, random seeds, normals, Weber/LUT fractions,
capacity overflow, microscopic routing and pool decisions. No display diameter,
texel coefficient, Smear or track-water optical correction enters this producer.
The unchanged production file is preserved; the new body is an offline derivative.

The first five trace rows are the canonical event records, followed by world
incident velocity, authored outward world normal and the initial attached-head
world velocity reconstructed from the original UV projection. The latter is
captured before a pool return can replace `motion.xy` with zero. When pool mode
is off, the original four event rows remain identical and the new fifth row
additionally exposes the already-computed incident centre. There is one immutable
event atlas; trace rows evaluate the same deterministic incident, not additional
independent arrivals.

## Explicit physical closure

All packets use `(volume_mm³, volume_mm³ × worldRelativeVelocity_m/s)`.

| Output | Volume | Velocity |
| --- | --- | --- |
| Incident | P2 allocation.x, including bounded continuum overflow | captured relative incident velocity |
| Retained film | allocation.y + capacity/continuum ledger.x | incident tangent × explicit film retention |
| Pinned micro | allocation.z | zero |
| Rebound | allocation.w | tangent × eT minus normal incident component × eN |
| Attached head | external attached ledger.z, excluding pool return | captured P2 initial world velocity |

`eN`, `eT` and film retention are explicit bounded [0,1] material inputs. These
are **estimated reduced-model parameters**, not newly measured splash physics.
P2's existing attached tangent fraction and estimated impact LUT remain unchanged.
Film and micro retain the original incident centre even if a head is born from a
different pool location. Pool volume is internal inventory; it creates no new
incident, retained-impact or external attached-head packet.

Wall reaction is the independently specified capture/rebound momentum difference:

```text
incident = film + micro + rebound + attached head + wall reaction
```

Its volume is zero. This is impact capture/reaction, not an unrecorded force
added to make a later field inventory balance. s144 already uses the same capture
identity; its pinned-micro step therefore does not remove micro momentum twice.
The closure tracks momentum but does not store surface heat or impact energy.
Bounds on the speed-retention/restitution parameters prevent deliberate energy
amplification; this is not a calibrated energy or splash-fragment model.

## Eighteen-row immutable context and provenance

`s146_birth.recipe(count, geometryW, geometryH, siteCount, fieldW, fieldH,
'p2_retained_impact_v1')` has eleven canonical rgba32f imports: old raw state/meta,
du/dv/boundary, weighted birth sites, DSD and material LUTs, wet height, pool
candidates and context. There is no CPU drop loop or GPU readback in the recipe.

| Context row | Contents |
| --- | --- |
| 0 | current epoch/generation/interval token |
| 1 | actual frame, birth tick, matched dt, head count |
| 2 | start high/low and end high/low tick words, base 65,536 |
| 3 | metric, pose, weather and material revisions |
| 4 | number density, physical area, exposure, incident-air fraction |
| 5 | four DSD weights |
| 6 | world relative air.xyz and P2 attached tangent fraction |
| 7 | water density, surface tension, viscosity, persistent diameter threshold |
| 8 | wet override/on/height scale and outward-normal sign |
| 9 | advancing angles bare/coated, contact angle, reserved zero |
| 10 | pool on, head count, matching pool tick, reserved zero |
| 11 | field dimensions, descriptor pad, version 1 |
| 12 | eN, eT, film retention, model 1 |
| 13–16 | object-to-world matrix rows |
| 17 | previous completed interval token |

The split clock supports exact integer ticks through 2^40−1; each span must be
1–52,428 ticks at Q=1,048,576 ticks/s and exactly equal the birth dt. Context,
recipe field/count and pool tick must match. Tokens/revisions are bounded, and
source frame can reach 16,777,215 without float32 integer aliasing. Proper uniform
physical scaling and rotation are allowed; nonuniform/reflected/degenerate linear
transforms are refused. Physical area must be supplied consistently by the sealed
geometry producer; this graph does not infer or authenticate it from an area sum.

`s146_birth_snapshot.freeze` copies the complete context, resource revisions and
geometry/pose/weather/material identity keys before submission. It requires a
producer seal and returns an uploadable context, matching descriptors and source
request. It rejects unknown fields such as a display gain, stale/malformed timing,
missing identity and missing seal. This is a frozen input record, **not yet the
multi-stage frame owner**. Backend hashing, actual upload verification, canonical
read leases and identity seals are trusted seams; a table or receipt is not a
cryptographic proof of arbitrary texture contents.

A global status reduction gates event/impact/attached/reaction outputs, token
receipt and matching s144 source header together. Refusal exports zeros, not a
partially usable event atlas. Old physical stocks are not inputs owned by this
producer and must remain held by the enclosing transaction.

## Verification

**438 WARP draws / 43 strict `/WX /Ges` shader bodies**, 37 positive/refusal
cases, seven snapshot guards and six lease scenarios plus one actual-asset lease
scenario pass. Positive cases compare the exported event rows bit for bit with
the original P2 shader, using the same frozen context. They cover overflow,
occupied slots, micro routing, wet material, missing normal impact, pool-only,
rotation, uniform physical scale, skew metrics, split long clocks, 4096 slots and
the actual project geometry/DSD/material/site assets. The actual-asset case has
nonzero source, not an all-dry control.

An independent CPU hash/CDF/metric/world calculation checks captured incident
velocity, normal and attached velocity. A float64 packet oracle checks the new
retained/rebound/capture outputs. The first curved test exposed an incorrectly
result-relative cancellation bound: maximum error was 1.735258639e-7 in a small
wall component made from larger terms. The final oracle scales the 32-epsilon
bound by the explicit dot/projection/subtraction operands, with the original
1e-9 floor. It does not inflate a global epsilon or change shader output to fit.
The unchanged aggregate 128-epsilon water/momentum closure gate also passes.
The actual curved packet error occupies 2.24% of this operation-scale bound.

The checker then passes **P2-generated** event and impact packets through actual
s144 source shader passes and s145 remaining-time transport to phase 2, without
reapplying the source. The accompanying head envelope is explicitly a controlled
no-advance/no-merge stream. This does not prove the live s143/P1 frame hook or
continuous head/film timing. Source identity, source clock and final stocks still
need a shared immutable frame owner.

## Cost, lifetime and remaining work

The 8-head producer has nine private passes / 20 resources, 144,208 nominal bytes
including imports. At 4096 heads it has 11 passes / 22 resources and 1,979,984
bytes. The actual 128-head geometry case has ten passes / 21 resources and
50,528,208 bytes, mostly imported immutable geometry. Calls bind at most eleven
textures. These are diagnostic counts, not GPU timing or adopted production cost.
The eight-row birth trace evaluates more output lanes than the old four/five-row
atlas. Context validation, diagnostic extraction and storage need fusion/reuse.

The existing site texture is 8192 pixels wide. A derived bridge permits imported
widths up to 16,384 while keeping private targets capped at 4096; the derived
eleven-input provider raises its bounded import budget to 128MiB per bundle.
The old bridge/provider are preserved. The actual geometry bundle and wide site
import pass mocked descriptor/lease checks; no new live CSP compatibility claim
is made. Submitted/unknown resources stay retained and publication stays blocked
without trusted completion. No timeout, frame delay or readback callback is
treated as a GPU fence.

No game files, runtime shader, settings or previous-stage evidence were changed.
Evidence: `diagnostics/2026-10-18/s146/birth_checks.json`, `graph_values.json`,
`large_packets.npz`, `actual_asset_packets.npz` and `delivery.json`.

Next: implement the frame/interval owner that retains this event/context bundle,
paired P1/s143 states and s144/s145 children through verified completion; provide
actual source hooks and upload/identity authority. Then fuse diagnostics, assess
physical/time accuracy and measure persistent target-game cost before preview.
