# s199: bounded resource descriptions and historical occupant lifetimes

2026-10-20. Parent s198. Status: ACTIVE. Offline D3D11 WARP/debug only.

## Result

The native owner no longer retains every logical-resource descriptor and physical
shape in its active schedule. Exact initialization/first/recurrent prototypes
reconstruct the original descriptions. A cache holds21 bootstrap descriptions
and the current/previous251-role intervals:maximum523 active descriptors.
The typed backing-shape map peaks at109 entries instead of1037.

Pool objects now retain the last-use event of their current logical occupant.
Retirement can therefore inspect an older free pool object after its descriptor
has left the cache. The last-use field changes with the occupant on every upload
and draw;unwritten objects retain an invalid/maximal last-use value and cannot
be reclaimed as completed work. Published cache roots receive their original
static last-use value. Physical object generation IDs remain distinct.

All64 intervals and exact1.08013916015625s publish. Complete stock/ledger/
checkpoint,owner/adaptive/index traces and1,457,304,640 retained GPU readback
bytes match s198 bit for bit. GPU work and allocation churn are unchanged.
Physical shaders,source/DSD/weather,size/display gains,forces and time policy
are unchanged. This remains offline;the installed application is unchanged.

## Representation and bounds

| Component | s198 | s199 observed/retained |
| --- | ---: | ---: |
| Active logical descriptors | 16,085 | maximum523 |
| Immutable descriptor prototypes | none | 523:21 bootstrap+251 first+251 recurrent |
| Active typed backing-shape entries | 1,037 | maximum109 |
| All logical-to-backing assignments in memory | part of complete descriptors | only active bindings;full mapping streams from64,352B file |
| Pool retirement lifetime source | complete logical-resource table | last-use field on each live pool object |

The active cache includes the21 bootstrap records throughout the run. Of these,
13 describe shared inputs and8 describe the historical initial bank;their
presence does not authorize a GPU read. Actual read paths still require the
backing's current occupant to match the requested logical ID. Other old/future
IDs outside the current/previous window refuse descriptor lookup.

Shared-input read lists are generated for the active frame from first/recurrent
read patterns. Current/previous resource read lists include any declared next-
interval readers,clipped at the fixed profile's final event. Last uses,births,
types,static flags and assignment IDs remain identical to the original schedule.
Shape alias compatibility is checked when loading the cache. The cache enforces
at most523 descriptors and523 shape slots;109 shapes were observed. Payload/
record counts exclude C++ container overhead and do not measure heap/RSS.

The original full schedule is still streamed and validated before GPU work:
every reconstructed descriptor matches its wire record,all declared read events
remain inside its lifetime,and per-backing summary records check typed aliases,
non-overlap and static protection. Phase allocations,retirements,protected sets
and descriptor bytes still pass the original proof checks. A transient1037-entry
summary and created/resident sets are released after validation. This startup
validation is not claimed to have memory independent of profile length.

The generator also remains offline and reads full frozen files. Assignment file
size and validation work scale with interval count. The native profile still
requires64 intervals;this stage does not establish longer-run support merely
because descriptor-cache caps are explicit.

## Verification

- The native reader reconstructs all16,085 original descriptions. All893,960
  descriptor bytes match the schedule,including complete read lists,last use,
  shape,static flag and backing ID. All16,085 assignments match the independent
  saved allocation certificate.
- Native packet roundtrip retains every original input byte and draw command.
  Full required-backing/older-input/transport-role and upload indexes retain
  s198 bytes. Source/cache retry,observer returns,capacity refusal and adaptive
  debt checks execute unchanged.
-2,836 actual ownership snapshots check225,553 initialized occupant records
  against original assignment,last-use and shape information.1,091 unwritten
  records keep the invalid/maximal last-use marker.3,280 checks concern objects
  older than the previous interval(maximum observed context age2),demonstrating
  the separate retirement metadata path. All last uses and types match.
- Four newly executed native CPU controls refuse old and future descriptors
  outside the active window,an out-of-domain logical ID,and an invalid frame.
  These are lookup/protocol controls;the existing physical reader-held and
  capacity refusal checks still run in the complete owner.
- All64 stock sums retain water/momentum closure and exact tick accounting.
  There are265 adaptive attempts:262 accepted and3 recovered refusals,with
  maximum49 physical draws per native pump.
- Default-texture peak remains66,577,136B(63.492905MiB);final owned textures0B.
  Dynamic generation creation/retirement/cache-release accounting matches s198.
  Strict native compilation and D3D debug checks report no warnings.

One WARP/debug run reports1,261.150ms diagnostic index generation,8.523ms timed
upload/phase lookup regions,and50.316s native run wall time. The descriptor
provider now performs file reads and map operations;these measurements do not
show improved CPU latency or game loading. They include diagnostic work and
are not target GPU/FPS or callback-latency measurements. This work bounds active
metadata;performance requires a bounded live-input provider and separate target
measurements. Conservation/bit parity also does not reclassify the recorded
s191–s194 near-cancelled UV-component accuracy failure.

## Remaining gates and next work

Total CPU streaming remains **open**. Acceptance counters,audit/decision sets
and diagnostic weak-reference identity history still scale with the fixed run.
The constructor uses transient complete-proof summaries,while the offline
generator and on-disk stream remain whole-profile artifacts. Staging/readback,
shader reflection and driver allocations are outside the default-texture budget.

Next bound acceptance/audit/generation history,then extend continuous recurrence
with diagnostic reads separated from production work. Measure allocation churn
and target CPU/GPU cost before live adoption. Real CSP scheduling/completion,
remaining physical/time accuracy and common optics remain open. Production
remains s87,diagnostics s89. No main/settings/production shader/asset/game writes,
user game test,commit or push are part of this stage.

Evidence: `diagnostics/2026-10-20/s199/resource_templates.json`,
`window_refusals.json`, `run.metadata.json`, `resources_audit.json`,
`resources_checks.json`,native ownership/lifetime traces and complete retained
GPU readbacks. Finalization only audits saved evidence and streams archives.
