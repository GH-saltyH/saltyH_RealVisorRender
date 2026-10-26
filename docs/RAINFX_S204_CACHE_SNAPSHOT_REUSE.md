# s204: exact cache snapshot reuse

2026-10-21. Parent s203. Status: ACTIVE. Offline native D3D11 WARP/debug only.

## Result

Cache validation reuses one completed full-image read when the old metric and
new metric are the same GPU resource at the same post-build capture epoch.
There are143 such preparations among271 cache preparations in this fixture.
The optimized run removes1,199,570,944B of CPU read results and the same number
of GPU staging-copy bytes. Cache-validation reads fall from6,820,614,720B to
5,621,043,776B. The remaining comparisons still consume their complete bytes.

Shadow and reuse modes both complete256 intervals and4.320556640625s. Final
bank/control/stock-packet bits,stock and ledger values,owner/recovery/phase/index
traces,typed occupancy and time debt match s203. No numerical tolerance,physical
shader,input,default-texture allocation,GPU draw,upload or completion event is
added or removed. The one-attempt-budget stop retains its prior published bank
and three intervals of accepted debt.

## Why this scope

The source has a direct duplicate in the shared-metric branch. The post-build
old-metric snapshot and new-metric snapshot refer to the same source,with no
intervening draw that can write it. Previously both GPU copies were made and
both staging images were read,even though the subsequent full-byte predicates
use the same contents.

A general GPU comparison against CPU reference images would also require
reference upload/storage and synchronization. A full metric image is8MiB,
while the current cache-reservation peak leaves7,440B under its scoped cap.
Streaming or borrowing storage introduces further transfers/lifetime work.
Those alternatives are not implemented or claimed faster here. This stage
removes a proven duplicate without hiding extra uploads or replacing equality
with a hash.

## Reuse conditions and byte predicates

The candidate must be declared shared and have all of the following:

- The identical live `ID3D11Texture2D` source identity.
- Equal nonempty width/height and actual RGBA32_FLOAT format.
- One mip,one array slice and no multisampling.
- Equal managed-cache write epoch and the same nonzero preparation lease.

The write epoch advances on every native cache producer draw. The two relevant
captures are made after those draws,inside the same synchronous owner operation;
the intervening commands only copy other resources into staging. They cannot
write the metric. Source owners remain live throughout capture and completion.
This witness is specific to the private native command stream. It is not a
general GPU completion proof or an external-writer/CSP concurrency protocol.

Reuse mode keeps the after-old-metric staging image and its complete CPU byte
buffer for both consumers. Shadow mode keeps the original separate copies and
reads,then additionally confirms every eligible pair's full byte equality.
Both modes still perform:

1. Old header before/after full-byte preservation.
2. Old metric before/after full-byte preservation.
3. New header comparison with the complete expected header.
4. New metric comparison with the complete frozen reference image.

The earlier old-metric snapshot is never reused as a post-build snapshot. Its
CPU comparison buffer is destroyed as soon as the preservation comparison ends.
At most two8MiB scratch readback vectors(`metricBefore`,`metricAfter`,
`metricStorage`)are live simultaneously. Existing frozen expected/reference
vectors are unchanged and excluded from this statement. This is a scoped
lifetime change,not a measured general heap/RSS bound. Final native runs were
repeated after that lifetime correction.

Pending completion,old reader holds,failed preparation quarantine/discard,
source retry and atomic publication guards remain unchanged. A failed prepared
generation still cannot publish. A nonshared metric retains all original copies
and reads. The reuse decision refuses inconsistent shared-source witnesses.

## Verification

The native component passes10 eligibility controls:one valid witness and nine
refusals for wrong source,write epoch,lease,extent,format,null source,nonshared
declaration or zero lease. Six actual GPU-copy cases compare full and reused
predicates. Identical resources pass;equal data in distinct resources uses the
full path;rebuilt-metric one-bit corruption,old-metric corruption,a signed-zero
change and a NaN-payload change reject in both paths. There is no float numeric
comparison or probabilistic fingerprint.

In the integrated shadow run,all143 eligible full8MiB pairs match. The reuse
run omits exactly those143 copies and143 validation reads. All271 preparations
still pass the original predicates,including16 deliberately failed generations
that are subsequently quarantined,discarded and retried. Lease/write-epoch
traces match between modes after removing only the `reused` flag.

All saved physical/cold-cache/control/final-bank/stock-packet bytes and complete
owner/stock/recovery/phase/index text traces match s203. Inventory identities
are normalized across processes;complete shape/occupant/last-use records and
independent per-run creation/release audits still pass. Recurring metadata caps
are unchanged. Both full runs retain1,049 adaptive attempts,1,042 accepted
substeps,seven recovered transport refusals and zero final accepted-time debt.

The stop run still publishes26 of29 accepted intervals,and preserves the final
published bank with one active and two waiting intervals of debt. Its byte
results and traces match s203. Strict native compilation and D3D debug checks
report zero warnings. Prior stage builder/checker mains are not executed.

## Cost and next work

| Measurement over256 intervals | Full post-capture reads | Reused post-capture reads |
| --- | ---: | ---: |
| Cache preparations | 271 | 271 |
| Shared/eligible preparations | 143 | 143 |
| Cache-validation read calls | 1,626 | 1,483 |
| Cache-validation read bytes | 6,820,614,720 | 5,621,043,776 |
| Additional draws/uploads/default textures | 0 | 0 |

This removes approximately17.59% of cache-validation read bytes. Peak default
textures remain66,582,496B,with2,080B under the scoped cap,and0B at teardown.
The whole-run cache staging peak remains unchanged because nonshared rebuilds
still require all original images. Cumulative eliminated staging copies are
not a claim about retained memory. Staging,CPU/shader/driver resources and the
rest of the app remain outside the default-texture cap.

Cost records are single sequential WARP/debug observations with required
validation,text traces and final proof enabled. They do not establish hardware
speedup,FPS or CSP callback latency. Next measure target hardware execution and
transfer categories with optional archives disabled before choosing a larger
cache rewrite. Account for reference uploads,temporary storage and completion
cost;keep the complete byte predicates.

Target FP64/cost,CSP scheduling/completion,total CPU/provider/startup streaming,
true long-duration/live weather,physical/time accuracy,common optics and live
adoption remain open. Production remains s87,diagnostics s89. Main,settings,
production shaders,assets and installed game files are preserved. No user game
test,commit or push for this stage.

Evidence:`diagnostics/2026-10-21/s204/cache_checks.json`,`cache_audit.json`,
`probe.json`,each run's cache eligibility/cost/ownership traces and complete
retained bank/control readbacks. Finalization verifies saved evidence and
streams archival compression without another GPU run.
