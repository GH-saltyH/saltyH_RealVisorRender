# s194: isolated adaptive recovery of the s193 transport refusal

2026-10-20. Parent s193. Offline native WARP experiment; game unchanged.

## Result

The exact failed frame26 Y-quarter input reproduces the s193 refusal with
bit-identical force, map, loss and decision outputs. A new GPU bound kernel
computes shared-face contraction and disconnected-wet support ordering limits
over the full1024x256 field. Its reduced limit is0.0029828855767846107s;
an independent Float64 full-field computation gives0.002982885515329681s.

Half that limit, rounded down to92663 normalized integer ticks, yields an
accepted substep. Nine accepted substeps consume all786432 remaining ticks
(0.012657880783081055s), ending with exactly zero remaining debt. The original
262144-tick request is still refused. No overlap or packet tolerance is relaxed.

This establishes **isolated remaining-interval recovery**, not completion of the
64-interval joint owner test. Callback scheduling, pool reservation, retry leases
and physical bank/clock publication are not connected to this prototype yet.

## Method and safeguards

- Derive conservative bounds from the current forced mean velocities, actual
  metric and connected runs. Include both donor-width contraction and overtaking
  across a dry gap. Leave a positive FP32 width margin.
- Reduce16x16-cell tiles to one global bound. The estimate applies to frozen
  velocities; it is not a guarantee after forces are recomputed or the second
  axis is gathered. The unchanged complete transport decision remains authoritative.
- Retry from the identical unpublished film/ledger/checkpoint, recomputing forces
  at the shorter dt. Only accepted steps consume integer ticks. Existing request
  headers track elapsed/remaining time; final checkpoint debt must equal zero.
- Keep the successful step size for the rest of this interval, shortening the
  final remainder. Bound attempts at24 and refuse progress below one tick.
  The half-bound factor is a numerical safety choice, not a physical coefficient.
- Run transport only. Birth, impact, trail transfer and source handoff are not
  invoked again; cumulative incident volume remains unchanged.

## Evaluation

| Check | Result |
| --- | --- |
| Initial failure reproduction | Five critical full-array outputs retain s193 bits |
| Final retry policy | 10 attempts:1 refusal,9 accepted steps |
| Refused output | Film/ledger/checkpoint retain input bits;step ledger zero |
| Accepted output | Full-field water/momentum sums match ledger within existing FP32 bounds |
| Time accounting | 786432 ticks consumed exactly;remaining0 |
| Source accounting | No repeated incident source |
| Native execution | Strict FXC and debug-layer native draws succeed |
| Joint64-interval test | Not rerun;gate remains open |

An earlier controller reset every successful request to the large quarter. It
also recovered, but needed13 attempts (6 refusals,7 accepted). Its trace/results
are retained separately. Keeping an accepted step avoids repeatedly requesting
an already demonstrated unsafe interval. Different substep sequences can produce
different numerical solutions; equal-time convergence/physical accuracy still
requires evaluation beyond conservation.

## Cost and integration constraints

The bound pass writes64x16 RGBA32F tiles (16384B), then one16B scalar. This is
small, but **cannot simply be added to the s193 peak under its63.5MiB retention
cap**:16400B exceeds the11552B slack. Integration must reuse status storage,
coarsen the reduction, or retire another completed scratch target first.

The experiment uses separate R32 texture uploads/readbacks and a fresh native
draw process per pass. It does not measure pooled memory, target GPU time, game
FPS or callback latency. Full rejected-pass retries can be expensive. The next
implementation should stop invalid work earlier, retain safe inputs, limit work
per callback and carry exact debt across callbacks. No low-cost game claim is made.

## Evidence and next work

`diagnostics/2026-10-20/s194/results.npz` contains every attempt's input/output
film, ledger, checkpoint and decision plus bound tiles/scalar. `trace.json` records
integer debt and the independent bound. `reset_policy_*` retain the earlier
controller. `adaptive_checks.json` and the saved-evidence finalizer record hashes.

Next: connect adaptive retry/debt to the counted owner and three-request queue,
fit bound buffers within retention, and enforce a callback work budget. Then
rerun the unchanged64-interval sequence before long-duration and target-cost
tests. General CSP completion and common optics/live adoption remain open.
Main, settings, production shaders/assets and game installation are preserved.
No user game test or commit/push.
