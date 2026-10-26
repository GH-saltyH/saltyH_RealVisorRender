# s166 — native birth/head/source handoff

Date: 2026-10-19. Status: ACTIVE (small-grid native reference).

## Implemented

The existing physical chain now executes in one persistent native D3D11 WARP
context, with actual retained GPU inventory between frames:

```
P2 birth → SI heads/merge → conserved source raster → packed film adapter
        → four transport quarters → eight independent inventory copies
```

This closes s165's zero-source restriction in a controlled13×7,8-slot reference.
It reuses s146 birth, s148 SI head motion/merge/transfer, s144 source staging
and s163 packed/scalar-area transport equations. Physical coefficients, size
sampling and numerical tolerances are unchanged. No display gain is applied.

The controlled source-on/off/on fixtures and fixed planar geometry come from
preserved s150 inputs. Each interval is0.015625s; three committed intervals total
0.046875s. Initial head volume is1mm³. Existing heads move/merge and exchange
water with the film; newly arriving water is partitioned into attached heads,
film, pinned micro, bounce and reaction packets by the existing producers.
Wet-height feedback and pool return remain disabled in this recurrence fixture.

The source inputs in frames2/3 bind GPU buffers from the preceding committed
inventory rather than uploading saved previous water. Raw state/meta and the
previous pose similarly come from that bank. Existing frozen external geometry,
weather/material context, DSD and merge-creator packets remain explicit inputs.
This is not new engine input capture, a spatial merge broad phase or a live app.

## Transaction and ownership

All stage imports are immutable during a flight. Exact shape/format pool slots
are selected only from completed, unleased allocations. Capacity refusal is
checked before uploads/allocation/submission and leaves the bank and clock intact.
Native last-reader and SRV/RTV alias checks also run at every draw.

An actual `D3D11_QUERY_EVENT` completes each stage before its candidates can be
read, reused or admitted. An injected failed completion latch still waits for
the actual event; it prevents admission and keeps the old inventory. The source
retry produces identical candidate bytes. The completion control is not device
removal or a general CSP completion proof.

The source stage's phase-1 candidate feeds transport without advancing the
committed frame clock. Reapplying that same source to phase-1 stock is refused by
the unchanged GPU previous-token/phase-2 guard. Refusal preserves film, micro,
physical heads, cumulative ledger and checkpoint; all three replay controls pass.
The four quarters consume the remaining debt without reapplying incoming water.

After phase2 and zero debt, eight resources are copied into independent GPU
allocations: raw state, physical metadata, previous pose, End film, pinned micro,
physical heads, cumulative ledger and checkpoint. The End copy addresses only
the logical firstH rows of the2H packed film. The copy batch has its own native
event and byte comparisons before bank exchange. The old bank reader must return
explicitly; old resources cannot enter the free pool while that reader is active.
Intermediate graphs can then retire without losing final inventory.

This is a serialized native reference. It commits a complete frame after the
copy batch. s165 separately verifies quarter publication, a two-frame waiting
queue and fixed-scale cache replacement. Those queue/cache semantics and this
nonzero source/head chain have **not yet been exercised together**. Concurrent
consumers, cancellation/device loss and actual input cadence remain outside s166.

## Results

| Metric | Result |
| --- | --- |
| Storage modes | Separate targets and exact-shape reuse |
| Per run |618 solver/source draws,31 actual event completions,24 inventory copies |
| Combined |1,236 draws,62 events,48 copies, six complete frame commits |
| Synthetic pixel shaders |50 bodies, strict warning-free compilation |
| Source accumulated mm³ |1.150346518 →1.150346518 →2.300693035 |
| Per-frame incoming mm³ |1.150346518 →0 →1.150346518 |
| Birth/head producers |All root bits match preserved s150 in all three frames |
| Independent SI force error |Maximum7.87e−7 UV/s, within inherited32ε /1e−9 gate |
| Source raster and packet oracle |Inherited32ε /1e−9 gate passes per cell |
| Water/momentum closure |Inherited128ε /1e−9 gate passes per publication |
| Copy/next-frame lineage |All24 copies bit-identical per run; raw metadata and physical head volume agree |
| Immutable input comparisons |297 per run;594 total |
| Failure/replay |One failed completion/retry and three refused source replays per run |
| Separate vs reuse |Every audited import/root payload is bit-identical |
| Debug layer |Enabled; final runs have no warnings/errors |

Native descriptor peaks are225,836 bytes separate and216,892 bytes pooled
(0.215374 /0.206844MiB). Audit staging reaches284,976 bytes separately. These
are small-fixture reference costs, not application VRAM, target-GPU timing,
4096-active-head throughput or a warm-run result. CPU fixtures, shader/driver/
constant-buffer costs and source-image caches are outside these figures.

## Actual-grid cost gate remains open

The unchanged diagnostic s144 source graph at1024×256 with4096 slots retains
46,907,888 bytes of root backings. Adding the already retained30,827,280-byte
world cache gives **77,735,168 bytes =74.134033MiB**, before charging all source
imports, raw banks and transport targets. This exceeds the64MiB gate.

This is a lower bound for retaining the existing *diagnostic* roots; it is not
a minimum required by the physics. The7H staged atlas alone is28MiB, the2H
raster8MiB, and film/micro outputs another8MiB. Production-oriented source
fusion and shorter diagnostic lifetimes are needed. The gate was not raised,
and the full actual-grid chain was not executed or admitted.

## Findings preserved

The first native loader refused the8192-wide birth-site input because s164's
transport-only descriptor limit was4096. The scoped adapter now permits input
widths through16384, matching the existing birth recipe; private targets remain
limited to4096. Physical model/schema/finite-byte bounds are unchanged.

The next debug run reported an unbound sampler in the birth shader. The native
runner now binds the existing linear/clamp sampler explicitly at reflected
sampler slots, matching the established WARP reference. No shader or warning
suppression was used. Both initial refusal/warning logs are retained.

## Next implementation and game state

Compact the source raster/staged/status/commit path while preserving per-cell
packet checks, paired head loss, source replay rejection and rollback. Recount
actual-grid source/head/transport retention against64MiB, then combine admitted
source handoff with s165's bounded frame/cache boundary. Curved head recurrence,
feedback, common optics and measured runtime cost remain adoption gates.

Game physics remains s87 and diagnostics s89. Main app, production shaders,
settings and installation were not changed. Native events do not establish CSP
Canvas completion. No game test is requested for s166; no commit/push was made.

Evidence: `docs/diagnostics/2026-10-19/s166/handoff_checks.json`,
`actual_source_cost.json`, layouts, native traces, copied inventory payloads,
strict shader/native build receipts, initial failure logs and `delivery.json`.
Parent sources and diagnostics are preserved without rerunning earlier tools.
