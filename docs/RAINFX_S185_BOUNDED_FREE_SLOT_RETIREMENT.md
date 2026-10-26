# s185 — bounded free-slot retirement

Status: offline native recurrence and independent warm descriptor proof verified,
2026-10-20. Game physics remains s87;diagnostics remain s89.

## Allocation policy

The s184 live frontier is62.992050MiB,but retaining every exact-shape slot
reserves69.807526MiB. Many source/head-only shapes are idle during transport;
keeping them permanently consumes capacity needed by later working textures.

The new private allocator first reserves exact typed free objects needed by
the next phase. If the remaining allocation would exceed the cap,it plans
retirement from **unreserved free objects only**,largest first. It validates the
whole batch before changing anything. If releasing every eligible object still
cannot fit the phase,the preflight refuses without allocation,retirement,stock
or clock mutation. A completed native boundary is required;an in-flight call
cannot retire objects. No extra completion boundary is introduced.

Victims cannot be in immutable cache inputs,current/pending banks,explicit
references or held frame roots. Retirement also verifies there is no unexpected
strong owner:only the free list,the preflight list and the retirement plan may
own each object. Those references are cleared before new textures are created.
Typed shapes are never reinterpreted. Protected old readers remain valid even
while unrelated free textures are returned.

Cache-generation preflight now computes missing bytes using the same exact
shape/payload equality as its allocation path. Previously it charged unchanged
imports again even when they were shared. This strengthens the correspondence
between preflight and allocation;it does not relax immutable-input validation.
An explicitly discarded failed cache may enter the free pool only after real
native completion,then be reused or retired by this policy.

## Native recurring physical test

A private s183 physical owner uses a **224KiB default-texture descriptor cap**.
The frozen baseline needed376,832B;the new path peaks at **227,968B**,below its
229,376B cap. Separate audit staging remains282,096B and is excluded from that
cap,as are CPU fixtures and driver/shader allocations. These are descriptor
counts,not measured resident VRAM or total process memory.

- **615 draws /37 real completion events /4 bank copies**,unchanged from the
  frozen physical reference. No shader body,new GPU draw or event is added.
- Every retained physical output and inventory image is byte-identical. The
  independent force/head/source/water/time oracles pass. Three publications
  advance46.875ms without losing accepted or queued time debt.
- Failed cache/source/bank candidates,retry,replay refusal,held old-cache readers
  and pending publication checks pass. All37 event paths also reject an attempted
  in-flight retirement. Forced insufficient-capacity requests remain atomic.
- The owner retires14 free textures /183,808B. It creates222 textures versus211
  before,and reuses406 versus417. This trades allocation churn for lower retained
  capacity;it is not a zero-cost performance claim.
- Every retirement has a completed native event and no submitted work outstanding.
  C++ builds with`/W4 /WX`;native debug checks report zero warnings.

This is a13×7 field/8-head recurring reference,not execution of the complete
actual-grid cache/source/head/transport owner. It reuses the previous physical
shaders and typed run-input path. Native D3D events do not verify general CSP
Canvas ownership or completion.

## Full warm descriptor proof

The same policy is simulated against the unchanged524-resource,two-frame warm
plan,including static inputs,banks,readers,source cells and physical last uses.
Each phase preallocates its complete typed requirements and retires only after
an **existing** completion boundary. An independent certificate reconstructs
physical generations,checks every logical lifetime and typed assignment,
rejects overlapping owners/static or leased retirement,and recounts bytes.
Corrupted overlap,retirement,byte counts and completion claims all refuse.

| Warm policy | Descriptor count |
| --- | ---: |
| Prior permanent exact-shape reservation |69.807526MiB |
| Prior simultaneous live frontier |62.992050MiB |
| New bounded resident peak,modeled |**63.998932MiB** |
| Margin below64MiB |**1,120B** |

The bounded proposal numerically fits its descriptor cap. It creates111 physical
generations versus93 permanent slots,retiring35 objects /19.617188MiB over two
frames. Cumulative created bytes are83.616119MiB;that is creation traffic,not
simultaneous residency. Seventeen source/head objects retire before each frame's
first transport phase,and an8MiB free slot also retires near the first bank
exchange. That last eviction contributes to later recreation and merits
optimization. Existing force/source-cell last readers and all resource metadata
are unchanged.

A63MiB control refuses before the first transport phase. That phase alone needs
67,099,472B /63.991043MiB when its typed slots are preallocated,even after every
eligible free object is returned. The1,120B successful margin is too narrow to
treat as a deployment allowance. Driver memory,staging,cold construction and
changing-pose overlap of the full physical owner are not included or executed.

The old`joint_plan.json`and its69.807526MiB reservation remain intact as the
permanent-pool fallback. The alternative lives in`bounded_plan.json`;it is not
presented as a smaller immutable slot array. Full-pipeline admission remains
**false**. No actual-grid joint allocator,CSP completion or target GPU/CPU timing
is verified by the descriptor result.

## Next work

Reduce retirement/recreation churn and increase the narrow descriptor margin,
then execute actual-grid cache/source/head/transport ownership with the same
reader and retirement guards. Measure creation overhead and target timing before
adopting the policy. Common optics and live integration remain open. Main app,
settings,production shaders/assets and installed game are preserved. No user
game test is needed for s185;Git stamping remains with the user.

Evidence:`diagnostics/2026-10-20/s185/pool_checks.json`,native physical/bank
images and reports,`joint.pool.jsonl`,`bounded_plan.json`,`bounded_certificate.json`,
four certificate controls,63MiB refusal,unchanged joint plan/readers,
`numerical_audit.json`,source diff,archive manifest and`delivery.json`.
Earlier frozen builders must not regenerate their evidence.
