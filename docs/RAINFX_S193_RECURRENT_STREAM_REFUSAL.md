# s193: recurrent physical stream and isolated transport refusal

Date: 2026-10-20. Parent: s192. Offline native D3D11 diagnostics.
Production physics remains s87, diagnostics s89.

## Outcome

The full physical owner now has a 64-interval recurrent graph, a three-request
admission queue, repeated forcing/rigid-pose cache replacement, source retries
and generation retirement. Actual execution **commits 26 intervals, then refuses
the second transport quarter of interval 27**. The 64-interval physical gate
therefore **fails**. This stage does not establish long-duration stability.

The refusal is a real reversed donor interval under the tested forcing. Three
cells have negative proposed interval width even in an independent Float64
calculation. It is not the previously reported near-cancellation UV rounding
diagnostic, a cache reader failure or an overwritten previous bank.

The native owner now quarantines numerical refusal instead of terminating with
an exception. Further publication, allocation and admission are refused. The
previous published bank and accepted-time debt remain intact. Explicit diagnostic
teardown releases GPU ownership while preserving that debt in the final record.
There is no automatic recovery yet, and this code is not in the game app.

## Stream implementation

- Sealed physical shader bodies are reused unchanged. `s193_graph.py` connects
  each output bank directly to the next interval's birth/head/source/transport
  inputs. Initial water is uploaded once and the initial head packet is derived
  once on GPU; subsequent intervals do not reseed water or reset their ledgers.
- The descriptor plan has 16,085 logical resources and 1,088 completion phases.
  Its static 64-interval scratch certificate passes. Dynamic cache replacements
  are accounted separately by actual per-generation ownership snapshots.
- Four controlled contexts repeat: original pose, same pose/changed forcing,
  90-degree rigid yaw/changed forcing, and return pose/changed forcing. These
  abrupt perturbations stress the owner; they are not a measured engine weather
  sequence or a realistic continuous head-motion trace. Geometry/material/scale
  stay fixed. A controlled birth RNG counter starts at 669.
- Admission permits one active and two waiting requests. Out-of-order and full
  requests are refused without consuming accepted time. A full request is retried
  after publication opens capacity. Request metadata for the entire scripted
  graph is preloaded; this is not a bounded CPU streaming-provider proof.
- Cache refresh waits for old header/metric readers and uses a fresh lease.
  Same-pose metrics are shared; changed-pose metrics are rebuilt. Failed candidates
  at frames 1 and 17 are quarantined, discarded and retried. Source computations
  at frames 0 and 16 are likewise failed/retried without republishing water.

## Actual execution and resource accounting

| Measurement | Result |
| --- | ---: |
| Planned intervals / planned simulated duration | 64 / 1.08013916015625s |
| Published intervals | 26 |
| Accepted requests | 29 |
| Published time | 0.43880653381347656s |
| Accepted time | 0.48943805694580078s |
| Preserved active + waiting debt | 0.05063152313232422s |
| Maximum queue depth | 3 |
| Physical draws, including source retries and refused work | 6,258 |
| Cache refresh draws | 67 |
| Total draws including bootstrap | 6,359 |
| Native completion events, including stock audits | 507 |
| Cache publications / failed candidates / source retries | 26 / 2 / 2 |
| Unique owned default textures | 562 |
| Pool retirements / cache releases / final releases | 417 / 67 / 78 |
| Peak default-texture bytes | 66,573,024 |
| Final default-texture bytes after diagnostic teardown | 0 |

Peak remains **63.488983MiB**. The observed prefix passes its scoped 64MiB
default-texture gate, with 535,840B margin; the complete physical recurrence
gate fails for numerical reasons. There are 1,064 ownership snapshots. Independent
shape/identity accounting reconciles 773,955,232 created/released bytes without
resurrecting expired generations. This is cumulative allocation churn, not
simultaneous memory use, and target allocation/cadence cost remains unmeasured.

The budget excludes staging, CPU/driver/shader allocations and allocation
padding. Separate peak staging is 48,005,152B for expanded physical diagnostics,
25,168,320B for cache comparisons and 8,454,304B for stock audits. These diagnostic
readbacks and scripted metadata cannot be used to infer game FPS or total RAM.
D3D debug warnings: zero.

## Refusal cause

Zero-based frame 26, quarter 1, Y axis, uses a 0.0042192935943603516s step.
The proposed donor width is `1 + (rightFaceSpeed-leftFaceSpeed)*dt` in cell units.
The independent calculation uses the retained GPU mean packet and decoded metric,
with Float64 projection and mass-weighted shared faces:

| Cell (x,y) | Left face cells/s | Right face cells/s | Proposed width | Local non-reversing dt bound |
| --- | ---: | ---: | ---: | ---: |
| 466,128 | 346.870044 | 80.128891 | -0.125459 | 0.003748953s |
| 467,128 | 621.477952 | 286.562045 | -0.413109 | 0.002985824s |
| 468,129 | 433.356580 | 136.793734 | -0.251286 | 0.003371967s |

These are local bounds for the three identified cells, not a certified global
safe step. A smaller step must also satisfy disconnected-wet support ordering
and all other cells. The current shader marks the reversed map invalid and uses
its identity fallback; neighbouring retained bounds then also overlap. The Y
loss admission is `(0,2,123224,0)` and the final flow decision is zero. X loss
admission passes. Raising a rounding tolerance would not repair negative widths.

The refused output bit-rolls back film, micro, heads, cumulative ledger and
checkpoint to that quarter's input; its step ledger is zero. The tentative
source and first quarter in frame 26 remain unpublished. Complete stock audits
before/after quarantine match the last published frame exactly in their stored
water/momentum sums, ledger and checkpoint. The independent lifetime certificate
and owner pointer checks also protect the published state/meta/pose backings.

## Validation evidence

- All 26 committed intervals have full CPU Float64 stock sums from GPU readbacks,
  compared against their water/momentum ledgers. Queue records close accepted =
  published + active debt + waiting time on every transition, including refusal
  and final teardown.
- Complete numerical samples cover frames 0,1,2,3,15,16 and the admitted portion
  of frame 26: seven independent head/source audits and 25 transport quarters.
  Maximum source error/bound ratio is 0.174623; maximum head world-velocity error
  is 1.703e-8m/s. The earlier first-frame legacy UV component ratio 1.625061 is
  still reported as failed; physical-world velocity criteria pass.
- Both source retries compare 4,439,548 float words each against their successful
  retry. Selected cache attempts compare complete old/new headers and metrics;
  native full comparisons run for every candidate.
- Two initial runs stop at the same decision before the owner quarantine handler
  is added. Their saved outputs are supplemental reproduction evidence. The final
  owner run and `stream_checks.json` are authoritative. Saved refused map/field
  arrays reproduce the same negative-width diagnosis with unchanged shaders.
- Five bad packets, including a pose/scale mismatch in frame 40 that execution
  never reaches, refuse before device creation. Typed bank lifetime, profile range,
  immutable geometry and physical/cache context guards remain enabled.

Evidence is under `diagnostics/2026-10-20/s193/`: `run.json`,
`run.owner.jsonl`, `run.inventory.jsonl`, `run.stocks.jsonl`, full sampled GPU
readbacks, `refused_flow.npz`, `numerical_audit.json` and `stream_checks.json`.
The finalizer re-audits saved evidence without running the GPU again.

## Next implementation

Implement bounded adaptive transport recovery before claiming the 64-interval
gate or conducting a long-duration run:

1. Compute a conservative shared-face contraction/support-ordering time bound
   with a tile/global reduction. Reuse existing status storage where possible.
2. Quantize the accepted substep to the existing exact remaining-time protocol.
   On refusal, recompute from the same unpublished quarter input at smaller dt.
3. Consume only accepted substeps. Do not repeat birth, source transfer or trail
   mass, and do not publish the frame until its complete debt is consumed.
4. Bound work per callback and retry count. Preserve queue/bank/debt if a safe
   positive step or resource reservation cannot be obtained.
5. Re-run this unchanged adversarial context/source sequence, then longer runs
   and target CPU/GPU measurements.

This adds arithmetic/reduction and occasional retry work; actual cost is not
measured. A permanent global quarter-size increase or relaxed overlap test is
not adopted. General CSP completion, common optics and live solver adoption
remain open. Main/runtime/settings/production shaders/assets and installed game
files are preserved from the stage baseline. No user game test or commit/push.
