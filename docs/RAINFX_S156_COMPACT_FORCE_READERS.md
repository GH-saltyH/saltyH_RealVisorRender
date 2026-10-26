# s156 — compact film force and downstream readers

Status: ACTIVE — offline compact representation and downstream checks passed
Date: 2026-10-19

## Implemented

The s155 force buffer stored four full-field bands: half-step End, full-interval
Mean, impulse and normal-momentum/status. s156 stores **only End and Mean** and
adds explicit readers for the remaining information. At1024×256 this reduces
the force buffer from **16MiB to8MiB** and its target from1,048,576 to524,288
fragments. The original physical force functions and coefficients are unchanged.

The actual-grid offline adapter uses the same captured frame660/cache and
controlled water fixture as s155. New wrappers also connect compact status and
exchange readers to the existing source/transport/recipient ledger graph and
the source-applied time-debt continuation. No production app, shader, setting or
existing prototype was edited. There is no new game probe in this step.

## Compact ABI and invalid states

| Region | Valid contents | Invalid contents |
| --- | --- | --- |
| Rows0…H−1 | Half-step End `(mm³, mm³ × world m/s)` | `(-1,0,0,0)` |
| RowsH…2H−1 | Full-dt Mean in the same format | `(-1,0,0,0)` |

Negative volume is an internal error marker, never physical water. A failed
plan, force status or invalid/nonfinite produced packet writes the marker.
Overflow is therefore refused before a malformed packet reaches the ledger.
The reader checks the2H shape, finite/nonnegative input and output packets,
and equality of both stored volumes to the immutable staged input volume.
Malformed markers, altered Mean volume and the old four-band layout are refused.

Admission must use the corresponding status/decision path. The unchanged
End/Mean extractor reads the first two bands only after that decision; on a
refusal it returns the original physical stock. Invalid markers are not copied
into a committed inventory. No public commit/clock API is added by this stage.

## Reconstructing exchange

With the same immutable staged packet, metric and area used by the producer:

```text
previousTangentMomentum = tangent(oldMomentum / volume, normal) × volume
impulse                 = storedEndMomentum − previousTangentMomentum
normalExchange          = oldMomentum − previousTangentMomentum
```

Zero-volume valid cells return zero exchange. Geometry failure returns an error.
Readers use the unchanged `packetValid`, `resolvedMetric` and `tangent` functions.
They do not rerun the exponential film response.

End and Mean remain **bit-identical** to the original force buffer in all eight
accepted full-grid cases. Normal exchange is also bit-identical in those cases.
Impulse changes floating-point rounding because subtraction now follows the
stored End momentum. It is not advertised as bit-identical. Its maximum
difference is1.86264515e−9mm³·m/s in the actual-context fixture and
7.45058060e−9 in the scaled fixture, within the inherited packet bounds.

The velocity oracle remains32 float32 epsilons with a1e−9m/s floor; momentum
exchange and closure retain128 epsilons with a1e−9 floor. No numerical or
physical acceptance threshold was widened. The s155 input-conditioned tangency
audit is preserved, with compact decoding replacing its four direct loads.

## Downstream implementation

- `s156_consumer` selects the explicit compact actual-grid graph.
- `s156_producer` replaces the donor, source-status and ledger readers in a
  privately copied s141 graph. It resolves remapped metric/area bindings from
  the donor rather than hardcoding source slots. Already compact or unknown
  graphs are refused without altering the caller's recipe.
- `s156_transport` makes the same explicit selection in the s145 source-applied
  continuation. Checkpoint and cumulative-ledger operators remain unchanged.
- The End/Mean extractor and recipient physics remain unchanged. The status
  reader decodes errors; the ledger reconstructs impulse/normal exchange in
  place. There is no four-band expansion allocation in either runtime recipe.

The four-band expansion shader exists only for independent test comparison.
These modules construct offline recipes; they do not establish CSP resource
ownership, a completion fence or safe recurrent buffer reuse.

## Verification

### Actual-grid force:171 WARP draws /7 strict shader compilations

Twenty-one1024×256 cases cover eight accepted responses and thirteen refusals.
They include the original force masks, SI scale, dry/viscous/inviscid response,
small impulse and force-free cases, plus bad dt/token/material/shape/geometry/
stock/run, nonzero dry momentum and output overflow. Four additional malformed
compact-output controls exercise the readers. All comparable inherited error
statuses agree with the original path. Output overflow additionally produces
a finite error marker rather than an inadmissible nonfinite force packet.

The actual-context fixture has120,765 controlled wet cells. Its maximum velocity
oracle ratio remains0.3785761 (limit1), with zero audit failures. Across the
accepted cases the maximum oracle ratio remains0.4900021.

### Downstream:1,118 WARP draws /33 strict shader compilations

Eight complete s141 source/transport/recipient comparisons cover both axis
orders, planar stiffness, dry input, invalid physical context/area, partial
resume and the4096-head layout. Final physical End, Mean, heads, extracted
transport inputs and logical transported stock are bit-identical to the old
graph. Ledger differences and closure pass the unchanged accumulated bounds;
the maximum observed ledger difference is9.53674316e−7 in packet components.

Three s145 comparisons cover the first and second quarter of an interval and
wrong retained time debt. Film, Mean, micro, heads, checkpoint and source/plan
outputs match bit-for-bit. Source is not replayed. Step and cumulative ledgers
pass the existing bounds; a refused interval retains its input stock/history/
checkpoint. Three adapter checks cover private copying and refusal behavior.

**These complete downstream graphs use13×7 fields.** The4096 case checks capacity
and indexing, not4096 active-head saturation or timing. Full1024×256 transport,
birth/head ownership and recurrent live execution are not established here.
WARP serializes/uploads/readbacks between draws; it is not a persistent CSP bank.

Total for this step: **1,289 WARP draws /40 strict shader compilations**, across
the two independent harnesses. These counts are verification work, not a runtime
pass count or measured performance improvement.

## Cost result

| Actual-grid descriptor | s155 | s156 |
| --- | ---: | ---: |
| Force output | 16MiB | **8MiB** |
| Private outputs | 16.01579MiB | **8.01579MiB** |
| Five imports + private outputs | 40.01659MiB | **32.01659MiB** |
| Force fragments | 1,048,576 | **524,288** |
| Logical force calls per wet cell | 4 | **2** |
| Passes / private targets | 6 /6 | **6 /6** |
| Retained s154 + stock + private outputs | 76.60321MiB | **68.60321MiB** |

Each evaluation writes8,405,168 nominal output bytes instead of16,793,776.
This excludes texture reads, cache behavior and driver overhead. The compact
ledger/status readers introduce extra reads/projection arithmetic; halving the
force target does not establish a50% total GPU-time improvement. No target
GPU timing or live residency was measured.

The combined retained diagnostic stack still exceeds the single64MiB owner
limit by about4.60MiB. No owner limit was increased and no new game allocation
was made. Raw source copies and diagnostic intermediates remain retained under
the existing completion policy; this stage does not authorize releasing them.

## Next step

Compact storage and its selected consumers are ready for further offline frame
integration. Next resolve the remaining input/cache/scratch budget and generalize
the complete frame continuation to the actual grid. Preserve source-once and
time-debt semantics while doing so. Verified recurrent completion/reuse, live
inventory authority, curved transport accuracy, common optics and measured
warm game cost remain required before adopting a new live solver.

Evidence: `docs/diagnostics/2026-10-19/s156/compact_checks.json`,
`downstream_checks.json`, `cost_checks.json`, both result archives and the recipe.
