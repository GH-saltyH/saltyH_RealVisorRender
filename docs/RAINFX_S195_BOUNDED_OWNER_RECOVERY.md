# s195: bounded adaptive transport in the native joint owner

2026-10-20. Parent s194. Production physics s87/diagnostics s89 remain unchanged.

## Result

The unchanged s19364-interval context/source sequence now completes in the
counted native physical owner. All64 physical banks and1.08013916015625s of
accepted solver time publish. Three transport refusals recover through smaller
integer-tick substeps. No birth/source/trail mass is reapplied.

The **scoped native64-interval physical gate passes**. This is only about1.08s
of simulated time with controlled abrupt context changes, not a long-duration
game test. Actual CSP completion/callback integration and target timings remain
unverified. No FPS or general application memory claim is made.

## Integration

- A persistent owner cursor holds the private film/ledger/checkpoint views,
  requested step, elapsed/remaining ticks and retry count. `pumpTransport()`
  returns after one bounded attempt; the native host drives subsequent pumps.
  This exercises resumable native work boundaries, not actual CSP callbacks.
- A refused quarter keeps its input bits. Only a fully validated substep consumes
  ticks. A partial accepted output is copied into the same private input backing
  after completion, avoiding another4MiB film allocation. Published bank inputs
  are explicitly rejected as carry targets.
- A held input reader blocks carry. The native test attempts that carry while
  held, then returns the reader and completes the copy. No logical frame bank or
  public clock advances between adaptive pumps.
- The original lifetime certificate covers scratch lifetimes. The new private
  input revisions additionally rely on cursor ownership, ordered completion,
  reader-guarded carry and dynamic ownership accounting; they are not represented
  as new immutable generations in the old static certificate.
- Bounds are evaluated while the forced mean buffer is still live, before later
  aliases overwrite it. The full unchanged transport decision remains the final
  authority for both axes and cumulative conservation.
- Coarsening to32x8 tiles with32x32 cells per tile reduces bound storage to4096B
  plus a16B scalar. Both are real owned textures in the same accounting domain.
- Per-quarter attempts are capped at24; each adaptive pump is limited to64 draw
  submissions (observed49). A zero safe tick or exhausted attempt budget stops
  and quarantines work. This is a submission limit, not a GPU/CPU millisecond
  deadline or a proven bound on total callback wall time.

## Native measurements

| Measurement | Normal run |
| --- | ---: |
| Requested / accepted / published intervals | 64 /64 /64 |
| Accepted = published solver seconds | 1.08013916015625 |
| Original quarter intervals | 256 |
| Adaptive attempts / refusals / accepted substeps | 265 /3 /262 |
| Maximum adaptive pump draws | 49 |
| Physical draws including bounds/retries | 15,998 |
| Cache refresh draws | 163 |
| Total draws including bootstrap | 16,195 |
| Native completion events, including diagnostics | 1,784 |
| Cache publications / cache failure retries / source retries | 63 /4 /4 |
| Maximum queue depth | 3 |
| Owned default-texture generations | 1,234 |
| Pool retirement / cache release / final release objects | 991 /163 /80 |
| Peak default-texture bytes | 66,577,136 |
| Final owned default-texture bytes | 0 |

Peak is63.492905MiB, leaving7440B to63.5MiB retention and531728B to64MiB.
Dynamic snapshots count all distinct default textures, including adaptive targets.
Cumulative created/released bytes are1,784,658,288; this is allocation churn,
not simultaneous memory use. Allocation/cadence cost still requires measurement.
Staging, CPU/shader/driver allocations and padding are excluded from this budget.
Debug-layer warnings: zero.

## Independent saved-evidence checks

- Full Float64 sums of GPU film/micro/head inventory match the ledger after every
  published interval. All step/cumulative ledgers retain the existing water and
  momentum tolerance. Every frame consumes exactly1048576 normalized ticks.
- Each of256 quarters closes its entire262144-tick request, including adaptive
  substeps. Rejected attempts consume zero ticks. Incident source volume stays
  unchanged across all quarters/substeps within a frame.
- Accepted time = published time + active unpublished frame debt + waiting time
  on every owner transition. No cache/context/lease or bank publication occurs
  inside an adaptive yield. The first26 published stocks/ledgers/checkpoints are
  identical to s193, showing that extra bound draws do not change the valid prefix.
- Unique resource identities, descriptor sizes, creations, retirements and final
  releases reconcile independently; no expired generation resurrects.
- Physical/cached shader hashes and typed descriptors remain frozen. The earlier
  legacy UV-component near-cancellation miss is not reclassified by this gate;
  s191-s194 independent world-force results retain their original scope.

## Forced-budget control

With the per-quarter attempt limit forced to1, the owner stops at the first
genuine refusal in frame26. It publishes26 intervals, accepts29 requests and
preserves one active plus two waiting frame debts. The last published bank's
water/momentum sums, ledger and checkpoint remain unchanged. Publication,
admission and reservation are refused while quarantined. Explicit diagnostic
teardown releases all GPU ownership while retaining the debt in the final trace.
This is a safe-stop test; automatic resume after a hard budget stop is not claimed.

## Remaining work

Next investigate longer recurrent stability, allocation churn and bounded input
streaming; the scripted graph currently preloads64 requests' metadata. Measure
target GPU/CPU cost with diagnostic readbacks separated. Then connect real CSP
inputs, completion and callbacks before common head/trail/film optics and game
adoption. The native host currently drives pumps synchronously; no game scheduler
or general CSP Canvas completion fence is established here.

Evidence: `diagnostics/2026-10-20/s195/owner_checks.json`, `numerical_audit.json`,
`run.*` and `budget_stop.*`, including per-attempt ledger/tick traces, per-frame
stock sums and complete ownership inventories. `initial_driver_run.json` is a
supplemental earlier successful driver result, not the authoritative final run.
The finalizer verifies saved results without GPU reruns. Main/settings/production
shaders/assets/game installation are preserved. No user game test or commit/push.
