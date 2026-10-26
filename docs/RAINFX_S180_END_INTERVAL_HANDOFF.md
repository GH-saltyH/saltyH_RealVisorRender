# s180 — explicit End-only physical interval output

Status: offline native recurrence and actual-grid operator verified, 2026-10-20.
Main game physics remains s87; diagnostics remain s89.

## Dependency finding and selected profile

Completed quarter intervals exported a2H End/Mean texture although the next
physical quarter reads only its End band. The first quarter also consumed a
duplicated source End texture. These long-lived inputs overlap the8MiB force,
gather outputs and4MiB maps at the working peak.

The new **`physical_interval_End_only_v1`** profile is permitted only when no
external Mean consumer is requested. It exports an exact H-row End texture and
passes the completed source End backing directly into the first quarter. The
field remains1024×256; geometry resolution, FP32 precision and physical units
are unchanged. All within-interval force and gather Mean calculations and their
buffers remain unchanged. There is no approximation of Mean by End.

The original packed profile remains available for diagnostics or future optics
that request Mean. That consumer cannot use the new memory count: requesting
Mean refuses the End-only path before device construction. No production output
or game option is switched to this profile in this step.

## Implementation and guards

The existing checked H/2H input reader receives the exact H-row parent extent.
The original final-selector shader writes only End rows by changing its target
and extent parameters; its shader body stays unchanged. Native viewport extent
and output extent must agree. Every external root view is checked against the
new backing dimensions. Internal force/map/gather descriptors keep their sizes.

The source duplication stage becomes an exact completed-source ownership
handoff. The owner retains the source through the first quarter, observes real
native completion and preserves pending/publication guards. A separate film End
bank copy and the s179 seven-root bank handoff remain in use. Typed slots are
replanned by their actual shapes; an8MiB2H slot is never reinterpreted as4MiB H.
Packed input supplied to the new owner, a Mean request, a wrong viewport or a
wrong input-parent extent refuse before native device construction.

## Native and numerical results

The persistent13×7 field /8-head physical reference runs source ON/OFF/ON across
three frames, with head/source/four transport quarters/bank/cache/time guards:

- **615 draws /37 real completion events /4 bank copies**, versus618 draws in
  s179. Three source-duplication draws become direct handoffs.
- End, physical status/ledger, checkpoint and all eight bank roots retain s179
  bits. Comparisons intentionally do not request the removed external Mean root.
- Independent head-force, source and water-budget oracles pass. Three bank/cache
  publications advance46.875ms; active/queued time closure is preserved.
- Cache/source/bank failures, retry, replay refusal, old-cache readers and direct
  root protection still pass. No failed candidate publishes new stock or time.
- Native texture peak falls405,952→397,216B in this small reference; separate
  diagnostic staging remains282,096B. This is not a measured full-grid saving.

Another **141 standalone native draws** execute the actual1024×256 physical
operator using the frozen curved world metric and4096-head descriptors: accepted
quarter, incorrect-debt refusal, then accepted continuation from the first new
End/checkpoint/ledger. All retained public root bits match frozen s164 outputs;
the refusal preserves stock and ledger. Water closure passes. These passes use
host readback between shaders and do not execute the complete persistent
actual-grid owner. Total component evidence is756 draws.

Fifty native-chain strict shader bodies are reused and29 full-grid wrapper
bodies are strict-compiled. The actual-grid shader bodies are identical to the
preserved physical recipe. C++ builds with `/W4 /WX`; native debug checks report
no warnings. No earlier builder/checker/finalizer runs.

## Warm lifetime proposal

| Full warm proposal | s179 | s180 End-only |
| --- | ---: | ---: |
| Static inputs |33.850433MiB |33.850433MiB |
| Maximum simultaneous live set |74.992050MiB |**70.992050MiB** |
| Exact-shape reservation |85.807526MiB |**77.807526MiB** |

Reservation falls8MiB and the live maximum4MiB. Two source End duplication
resources disappear; eight quarter exports shrink from2H to H, and source End
leases extend through their consumers. All16 physical force and2 source-cell
last-reader records are unchanged. The independent lifetime certificate passes.
This remains a declared warm plan; the complete actual-grid source/head/cache/
transport allocation, cold construction and changing-pose overlap are unexecuted.
Both live and reserved figures still exceed64MiB. No alternate cap is adopted.

CPU fixtures, diagnostic staging, driver/shader allocations and source caches
are outside those descriptor figures. Target GPU milliseconds and FPS remain
unmeasured. The saved output agreement does not verify general CSP completion.

Next reduce the remaining force/map/gather or static-input residency and compose
actual-grid cache/physical publication while maintaining the Mean-consumer
contract, old stock and retry data. If common optics requires Mean, retain the
packed profile and account for it before adoption. Main app, settings, production
shaders/assets and installed game are unchanged. No user game test is requested;
Git stamping remains with the user.

Evidence: `diagnostics/2026-10-20/s180/end_checks.json`, native reports, saved
physical/bank images and actual-grid root pairs, `actual_recipe.json`,
`joint_plan.json`, `physical_last_readers.json`, `numerical_audit.json`,
archive manifest and `delivery.json`.
