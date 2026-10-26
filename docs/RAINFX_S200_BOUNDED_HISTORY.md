# s200: bounded acceptance and diagnostic history

2026-10-20. Parent s199. Status: ACTIVE. Offline native D3D11 WARP/debug only.

## Result

The native owner now retains one current acceptance count instead of an array
for every interval. Diagnostic generation IDs live on the objects themselves,
with a monotonic scalar counter;there is no external weak-pointer index retaining
expired control blocks. Audit/decision membership uses small immutable patterns
instead of whole-run sets. These remove the remaining identified recurring
history containers that grew with this fixed profile's interval count.

The64-interval run retains s199 physical,stock/ledger/checkpoint,owner/recovery,
index and legacy phase-trace bits. Its1,457,304,640 retained GPU readback bytes
match s199. A newly executed forced one-attempt-budget control retains its
earlier s195 published bank/debt and709,732,752 GPU bytes. Total compared GPU
readbacks:2,167,037,392B. Physical shaders,inputs,size/display gains,source amounts,
forces and timestep policy are unchanged.

This establishes the scoped recurring metadata representation. It does **not**
establish general heap/RSS bounds,long-duration stability or complete CPU
streaming:startup proof summaries and whole-profile offline/provider artifacts
remain. The native profile still has64 intervals. No game/runtime installation.

## Implementation

### Current acceptance

Publication requires the queue front to equal the current interval and its
acceptance count to equal8. The count resets only when the preceding interval
has published(`commits == currentFrame`). A future queued interval cannot inherit
the previous interval's count. Private adaptive cursors retain/restore the current
base count exactly as before. GPU-flight,quarantine,recovery and outstanding-reader
publication refusals remain in force.

Final full coverage follows from every atomic publication passing that gate,
the ordered commit count,and the final current count. The historical `good0`/
`good1` diagnostic fields derive from those publication invariants instead of
retaining old counters;their complete phase traces still match the reference.

### Object-local diagnostic identities

Each live `Object190` has one initially-zero diagnostic ID. First observation
assigns the next serial;later observations and held readers see the same ID.
Object destruction releases that ID field with the object. No map/weak reference
keeps its old control block. A diagnostic-ID exhaustion guard refuses a new ID
before counter wrap,while allowing observation of an already assigned live ID.
This is a diagnostic fault guard,not proof of a general live-engine overflow
rollback protocol.

The complete run assigns1234 IDs for1234 created generations;the forced-stop
control assigns564 for564 creations. These are cumulative scalar counts,not
retained historical entries. Independent ownership audits still reject reused
generation identities,changed shapes,uncounted objects and incomplete teardown.
Numerical ID/order details in ownership snapshots can change when control blocks
are freed sooner;no physical resource IDs or outputs are renumbered.

### Compact readback selectors

| Metadata | s199 retained | s200 representation |
| --- | ---: | --- |
| Acceptance counts | 64 entries | one current count |
| Diagnostic identity index | up to1234 weak keys in this run | zero external entries;one ID per live object+serial |
| Audit membership | 2314 logical IDs | five immutable patterns totaling518 normalized roles |
| Decision expectations | 512 records | eight immutable normalized role/value pairs |

The five audit patterns cover initialization,selected frames,ordinary frames,
frames preceding selected captures,and the original dense frame26 capture.
Selection remains a diagnostic fixture,not a weather/physics condition. Membership
resolves the original frame/logical IDs and reproduces every original audit and
decision record. The file reader validates the complete sorted selector trailer
by count,uniqueness,membership,values and type while streaming it;it no longer
constructs global selector containers. Arbitrary changed capture profiles are
refused rather than silently approximated.

## Verification

- Native exhaustive selector export matches all2314 original audit IDs and512
  decision records. The control validates that only518 audit-pattern roles and8
  decision prototype entries define that membership.
- A native CPU control checks repeated/held identity stability,object expiry
  after the last strong owner,and refusal at diagnostic-ID exhaustion without
  changing an existing held identity. It is not a measured heap/control-block
  allocation benchmark.
- The full64-bank run passes water/momentum closure,exact integer debt,source-
  once/retry and observer/capacity/cache guards.265 adaptive attempts include262
  accepted and3 recovered refusals. All prior physical and GPU results match.
- The newly executed one-attempt-budget control safely quarantines frame26:
  26 intervals published,29 accepted,one active interval plus two waiting remain
  owed. Stocks,ledgers,checkpoint and owner/recovery/phase traces match s195;
  no partial bank publication or source repetition occurs. Its106 attempts
  include105 accepted substeps and1 refusal.
- Both executions have maximum49 physical draws per native pump,peak default
  textures66,577,136B(63.492905MiB),and final owned default textures0B. GPU work
  and allocation traffic match their respective references. Native strict
  compilation and D3D debug validation report no warnings.
- The s199 occupant/last-use/type audit passes against the original schedule,
  with actual live-generation creation/release reconciliation. The scoped caps
  remain523 active descriptors,109 observed shapes,17 phase indexes,7 upload
  keys and a three-request queue.

All seven frozen input streams retain their source bytes. Complete native input/
draw reconstruction also matches s199. Prior builders/checker mains were not run;
only pure saved-data audits were reused against this stage's new native results.

## Cost and remaining scope

One host run reports1,221.642ms diagnostic index generation,8.266ms cumulative
timed upload/phase lookup regions,and49.236s full native wall time. Forced-stop
wall time is19.422s. These include WARP/debug,diagnostic readbacks,file I/O and
validation;the lookup regions have a narrower scope and include timer overhead.
They are unpaired telemetry,not target GPU/FPS,loading-time or callback-latency
improvements. Container overhead,staging,shader reflection and driver/OS caches
are not measured by the metadata record counts or default-texture budget.

`steadyRuntimeMetadataBoundVerified` describes the named recurring metadata
structures above. `totalCpuStreamingBounded` and `longDurationStabilityVerified`
remain false:the constructor still uses transient whole-proof summaries,the
offline generator/files are whole-profile artifacts,and the64-interval fixture
does not validate a longer engine timeline. General CSP completion/cadence and
counter/engine lifetime limits remain open. Bit parity/conservation do not
reclassify the recorded s191–s194 near-cancelled UV-component accuracy failure.

## Next work and evidence

Next extend continuous recurrence beyond64 intervals while retaining these
metadata caps,explicit input-generation identities and exact time debt. Report
any new numerical or budget refusal as a remaining gate;do not infer long-run
stability from this short parity test. Then measure target CPU/GPU cost with
diagnostic reads separated and address actual CSP scheduling/completion and
common optics/live adoption. Production remains s87,diagnostics s89. Main,
settings,production shaders,assets and installed game files are preserved. No
user game test,commit or push is required for this stage.

Evidence: `diagnostics/2026-10-20/s200/selector_templates.json`,
`selectors_control.json`, `identity_control.json`, `history_audit.json`,
`history_checks.json`,both executions' metadata/traces and complete retained GPU
readbacks. Finalization audits saved evidence and streams compression without
rerunning GPU work.
