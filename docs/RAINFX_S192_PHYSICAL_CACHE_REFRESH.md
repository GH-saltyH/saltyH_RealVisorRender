# s192: cache refresh in the full native physical owner

Date: 2026-10-20. Parent: s191. Offline implementation and native D3D11
validation; production physics remains s87 and diagnostics s89.

## Result and scope

The actual 4096-head / 1024x256-field owner now replaces its immutable
forcing/pose context between two physical intervals. Both controlled cases
publish recurrent water banks and solver time, with real cache shader work,
completion waits, failed validation, discard/retry and prior-reader returns.
The scoped native controlled-refresh 64MiB descriptor gate passes.

This is a captured initial visor/material with controlled perturbations:
same pose plus changed inertia/airflow, and a 90-degree rigid yaw plus changed
inertia/airflow. It is not a continuously captured engine-weather/replay run.
Scale, geometry assets and material are fixed. The second interval's seeded
birth sampler happens to produce zero arrivals; its retained heads, source
handoff and film transport still execute and change physically.

## Implementation

- `s192_graph.py` privately composes the frozen physical graph with one new
  immutable context. Birth, head SI/pose, source area headers and all four
  transport force inputs use that same context. Display gains do not enter it.
- Same-pose refresh shares the existing metric and builds only a new header.
  Rigid-pose refresh builds new derivative preparation, header and metric
  targets. Old header/metric remain readable until both readers return.
- The allocator reclaims completed, unused exact-shape pool objects before
  preparing a cache generation. Whole-batch preflight refuses an over-budget
  or held victim without partial retirement. Missing live inputs cannot be
  recreated from an expired generation.
- One completed candidate is deliberately marked invalid and quarantined.
  Explicit discard restores its post-trim allocation base; retry has a fresh
  lease. Pending, failed and read-held candidates cannot publish.
- Cache publication replaces roots only. It does not advance the water bank,
  accepted time or solver clock. The next physical interval uses context 2;
  physical bank/time publication still waits for its own completion/readers.
- A profile-specific pre-device guard compares the second physical packet
  against the new cache context. It rejects mismatched birth, pose, SI, area
  or film forcing, alongside geometry/scale/context identity changes.

These are additions to private native tools. Main Lua, settings, production
shaders/assets and installed game files were preserved from the stage baseline.

## Measured native execution

| Per run | Forcing only | Rigid pose + forcing |
| --- | ---: | ---: |
| Actual physical draws, including source retry | 486 | 486 |
| Cache refresh draws, including failed attempt | 2 | 8 |
| Total draws, including cold bootstrap/retry | 556 | 562 |
| Native completion events | 40 | 40 |
| Physical bank/time commits | 2 | 2 |
| Accepted and published seconds | 0.033754348754882812 | 0.033754348754882812 |
| Unique owned default-texture generations | 109 | 116 |
| Pool retirements | 29 | 30 |
| Cache object releases | 2 | 8 |
| Final object releases | 78 | 78 |
| Peak default-texture bytes | 66,573,024 | 66,573,024 |
| Final default-texture bytes | 0 | 0 |

Peak is **63.488983MiB**, 832B above s191. It leaves 11,552B to the 63.5MiB
retention cap and 535,840B to 64MiB. Each run's 81 ownership snapshots independently
sum every distinct owned default texture, follow fresh physical identities,
reject generation resurrection and reconcile all created/released bytes.
The old static scratch certificate describes unchanged physical lifetimes;
it is not reused as a certificate for dynamic cache replacement.

The accounting excludes staging, CPU data, shader/driver allocations and
allocation padding. Peak cache-audit staging is separately 25,168,320B;
physical audit staging is 17,758,192B and cold audit staging 26,479,936B.
These are native validation readbacks, not a total application memory budget.

## Independent checks

Both candidate attempts compare complete old headers/metrics before and after
GPU work, and complete new headers/metrics against the immutable context and
frozen reference. Each comparison includes 2,097,360 old and 2,097,360 new
float words. The same-pose metric retains bits; the rotated metric changes
and matches its reference. Header-only return cannot bypass the held metric.

The independent Float64 source audit passes full raster, film, micro and ledger
outputs. Maximum error/bound ratio is 0.080405. Head forces pass the independent
physical-world velocity criterion; maximum absolute velocity error across both
runs is 1.306e-8m/s. All eight transport quarters per run conserve water/momentum
within the unchanged FP32 reduction bounds and close exact remaining-time debt.

The earlier near-cancellation **legacy UV component criterion remains failed**
in the common first interval (ratio 1.625061). Its physical world norm passes;
the failed diagnostic is retained rather than reclassified or relaxed.

The first interval's published bank is bit-identical to s191. Against s191's
fixed-context second bank, forcing-only changes 422,286 film words and 124 head
words; rigid pose changes 461,759 film words and 142 head words. This confirms
the new context affects actual physical work, beyond cache/header diagnostics.
Micro remains unchanged as prescribed by these transport operators.

Sixteen negative packets refuse before device/resource creation: seven inherited
physical input/layout guards, five physical/cache context mismatches, immutable
geometry, context identity, scale identity and truncated metric reference.
Native tests also exercise capacity refusal, a held late retirement victim,
pending/failed/read-held cache publication, stale/duplicate reader returns,
source retry and physical bank publication. D3D debug warnings: zero.

## Evidence and remaining work

Saved evidence: `diagnostics/2026-10-20/s192/physical_checks.json`,
`numerical_audit.json`, and each case's `run.json`, `run.owner.jsonl`,
`run.inventory.jsonl`, complete physical/cache readbacks and frozen packets.
`finalize_s192.py` re-audits saved evidence and seals hashes without GPU reruns.

Next implement a longer recurrent native stream with repeated context changes,
bounded admission/backlog and generation retirement. Then measure target GPU/CPU
cost and connect verified live input/resource completion before common optics
and game adoption. General CSP Canvas completion, arbitrary asset/scale changes,
long-run stability, target timing and the whole application 64MiB gate remain
open. No additional user game test is needed for this stage. No commit/push.
