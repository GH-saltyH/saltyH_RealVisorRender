# s241 — bounded refused-step recovery and packed rollback repair (2026-10-22)

## Implementation

The new private retry owner proposes the full normalized interval,1048576
ticks. A validated transport refusal consumes no time; the next requested step
is half as large. After acceptance the successful size is retained, shortening
only the final remainder. The default limit is24 attempts. Budget exhaustion,
one-tick refusal, invalid receipts and cancellation leave the outstanding debt
explicit. They never declare an interval complete or discard its water/time.

Attempt tickets include a private owner identity, serial, completed/remaining
ticks and requested ticks. A pending ticket is stable across prepare calls;
changed, stale, duplicate or cross-owner resolutions refuse. The graph packet
sets the exact request and completion expectations for each attempt. An accepted
step alone advances completed ticks; source/birth routines are not called.

The receipt distinguishes accepted from refused transport while still checking
the handoff, immutable seed, geometry, finite/nonnegative stock, componentwise
ledger and exact checkpoint/debt expectations. An invalid receipt is a fault,
not a retryable transport outcome. Transport refusal itself is not assigned a
specific physical cause by this status; unknown persistent refusal stops at
the attempt budget. The owner expects its caller to validate the receipt before
resolving; it is not a general GPU fence or renderer lease.

## Packed Mean rollback bug

The inherited packed export's refusal branch loaded the End row for both End
and Mean outputs. Initial tests did not expose this because the initial bands
were identical. A refusal after seven accepted stress steps changed369672
Mean words while End stayed unchanged. The failed input/output and attempt
trace are preserved in `rollback_failure.npz` and `rollback_failure.json`.

s241 changes only this export fallback to load the original packed row `q`,
preserving both bands separately. The graph explicitly uses a2H packed input;
this adapter must not be used for a single-H input. Accepted export still reads
the original candidate output. Force, map, loss, gather and physical decision
formulas stay unchanged. Earlier stage files and game code are not patched.

## Validation scope

The local test uses the full1024x256 native WARP field with the existing geometry
and componentwise FP32 ledger bounds. Normal20µm film completes in one attempt
and its final End matches s240 exactly. The stress fixture uses a500µm controlled
pool with alternating ±0.02m/s components, a deliberate opposing-flow seed,
not a weather/drop distribution. Initial inventory includes that momentum.
Each refusal must preserve packed End/Mean, ledger and checkpoint bits. Each
accepted step is independently checked against full-array inventory sums.
Incident source stays zero and is never reapplied during retry.

| Local run | Attempts | Accepted / refused | Final remaining ticks | Native submissions |
| --- | ---: | ---: | ---: | ---: |
| Normal20µm | 1 | 1 /0 | 0 | 87 |
| Opposing-flow500µm | 13 | 9 /4 | 0 | 807 |

The stress run refuses its first three requests, accepts seven1/8-interval
steps, then refuses the final1/8 request. It completes that remainder as two
1/16 steps. All four refusals preserve End/Mean, ledger and checkpoint bits;
the accepted steps consume exactly1048576 ticks in total. This last refusal
after progress is also the regression that exposed the original Mean bug.

Six owner controls exercise recovery, attempt exhaustion, one-tick failure,
cancellation, invalid outcome/receipt handling and cross-owner rejection.
The stress seed initially used signed integer modulus; strict FXC correctly
rejected its performance warning. It now uses an unsigned bit parity check,
without disabling warnings. Preparation also encountered an already-created
prototype directory; guarded setup was fixed before any baseline was sealed.

Exact native attempt/draw/debt results are in `retry_checks.json`; only
successful full-field completion qualifies local recovery. Failure captures
are retained. The new path is not installed in the game and does not qualify
actual CSP scheduling, target GPU time, FPS, long-run accuracy or visual optics.
The87-resource graph remains about91.193MiB; retries increase work rather than
removing its memory cost. Full-graph halving is a bounded correctness fallback,
not yet an economical adaptive controller.

## Next

Connect bounded batches and the private completion receipts to the continuous
queue, preserving unpublished state and explicit time debt. Use conservative
step bounds/earlier refusal to reduce expensive full-graph retries where useful.
Then measure warm actual CSP throughput/tails and stress/replay/reset behavior;
conserved incident/head sources and renderer/common optics follow. Public
physics/optics remains s87 and the s239 CPU-tail warning remains open.

Evidence: `diagnostics/2026-10-22/s241/retry_checks.json`, `retry_results.npz`,
the preserved rollback failure, strict compile artifacts and `delivery.json`.
No Git commit/push or user game test is requested in this local stage.
