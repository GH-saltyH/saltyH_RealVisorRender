# s198: first/recurrent phase and frame metadata templates

2026-10-20. Parent s197. Status: ACTIVE. Offline native D3D11 WARP/debug only.

## Result

The fixed64-interval profile has two exact symbolic phase/frame structures:
initialization and recurrence. The native owner now binds those structures to
the current interval,static inputs and eight previous-bank roles. It retains
17 active phase indexes and seven upload-event keys rather than1088 phase
indexes and448 keys for the complete run. Frame/bank descriptors and packet
directory positions are derived from first/recurrent templates.

All64 intervals still publish exactly1.08013916015625s of solver time. Complete
stock/ledger/checkpoint,owner/recovery traces and1,457,304,640 retained cold,
physical and cache GPU readback bytes match s197 bit for bit. No physical shader,
weather/DSD input,size/display scale,source amount,force or timestep changes.

This does **not** complete total CPU streaming. The full16,085 logical-resource
descriptors and1,037 physical shape entries remain in memory. Audit/decision
sets,acceptance counters and diagnostic identity history also remain dependent
on the fixed profile. No longer-duration,target-FPS or live integration result.

## Representation

| Metadata | Previously retained | s198 representation |
| --- | ---: | --- |
| Phase start/end descriptors | 1,088 full records | 34 boundary templates;17 initial+17 recurrent |
| Phase required-backing/flow-role indexes | 1,088 | 17 active indexes plus34 immutable symbolic recipes |
| Upload event indexes | 448 | maximum7 current-interval keys |
| Frame/bank descriptions | 64 frame descriptions plus64 duplicate bank maps | 2 frame templates with generated IDs |
| Packet directory positions/lengths | 64 offsets+64 lengths | 5 offset/length coefficients plus two record counters |

The recipes retain1,480 symbolic resource references. References0–12 are static,
13–20 are the previous film/micro/head/state/meta/pose/ledger/checkpoint bank,
and21–271 are the current interval's251 logical roles. Those roles resolve to
the original logical IDs;the original logical-to-physical assignment still
selects the backing. Physical allocation generations are neither renumbered nor
reused. A backing's `mustExist` flag combines every intersecting logical role
with OR,so an aliased older input cannot be recreated as a new output.

For every bound reference,the native owner checks that the original resource
lifetime intersects the phase and that the older-input flag matches its birth.
Replacing indexes is refused during GPU flight or an active recovery cursor.
Capacity,reader protection,cache generation,source retry and integer adaptive
debt rules remain the same. Pending queue entries still carry their identities
and time debt;decoding occurs when the interval executes.

The schedule loader still validates the original complete allocation/protection
proof against the retained resource table. It then discards the transient phase
allocation/retirement/protection vectors. The actual physical owner consumes
phase start/end and its bound required-object index;it already performs dynamic
capacity/retirement checks instead of executing the original fixed allocation
lists. The unused historical canary entry is not a supported execution mode
with this compact phase table.

Two frame templates derive all context,forcing,source and bank IDs. Every original
serialized frame field is checked against the derived record before GPU work.
The directory requires one initial block length and one repeated block length;
other encodings are refused. These formulas are verified for this fixed profile,
not a general replacement for arbitrary engine input timelines. Selected audit
frames and the four-context metric pattern remain explicit diagnostic fixtures.

## Verification and cost

- Every saved required-object/`mustExist`/transport-role index and upload entry
  matches s197 byte for byte. The inherited index audit independently compares
  these entries to the complete original lifetimes and physical assignments.
- Every input byte and native reconstructed draw command retains the original
  FP32 constants,bindings and shader identity. The complete decoded packet matches
  s197. All64 original frame descriptions pass the template comparison.
-60 newly executed CPU binding probes cover all eight previous-bank roles and
  static/current endpoints in intervals0,1,2,26,63. Four refusal controls cover
  an out-of-range frame,two invalid role references,and substitution of the
  equally shaped current/expected context roles. The latter refuses before GPU
  device creation;shape equality alone cannot authorize a different role.
- Full64-bank water/momentum closure,exact tick debt,source-once/retry behavior
  and dynamic creation/release accounting pass.265 adaptive attempts include262
  accepted and3 recovered refusals;maximum49 physical draws per native pump.
- Default-texture peak remains66,577,136B(63.492905MiB),final owned textures0B.
  GPU work,cache publication and allocation churn are unchanged. Strict native
  compilation and D3D debug validation report no warnings.

These are record/payload counts,not measured C++ heap/RSS. Container capacity,
string storage,shader reflection,staging,driver allocations and the remaining
resource/audit tables are outside them. The offline generator still reads full
frozen graph/packet files. Actual runtime inputs still need a bounded engine
provider rather than the diagnostic disk provider.

One host run reports879.654ms for diagnostic index generation,8.031ms cumulative
timed upload/phase lookup regions,and47.745s native run wall time. Index generation
now includes binding,window decoding and trace output;its scope differs from
s196/s197. These are unpaired WARP/debug measurements including diagnostic work,
not evidence of improved CPU latency,game loading or target GPU/FPS. General
CSP completion and real wall-time callback budgets remain unverified. Bit parity
and conservation do not reclassify the recorded near-cancelled UV-component
accuracy failure from s191–s194 or prove longer physical/time accuracy.

## Evidence and next work

Evidence: `diagnostics/2026-10-20/s198/recipes.json`, `binding_checks.json`,
`run.metadata.json`, `metadata_audit.json`, `metadata_checks.json`,native traces
and complete retained GPU readbacks. Finalization audits saved evidence without
rerunning GPU work or old builders.

Next replace the remaining complete logical-resource/shape table with reusable
resource templates and a bounded current/previous/live-occupant window. Retired
pool occupants still need their last-use and type information;dropping those
records must not permit stale reads or bypass reader/capacity checks. Then extend
continuous duration and measure allocation churn and target CPU/GPU cost with
diagnostic reads separated. Actual CSP scheduling/completion and common optics
remain open. Production remains s87,diagnostics s89. Main/settings/production
shaders,assets and installed game files are unchanged. No user game test,commit
or push is required for this stage.
