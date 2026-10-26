# s257 — recurrent film/history copy elision (2026-10-23)

## Selected work

s256 passes two-arena submission overlap but does not show faster caller cycles
at twice the texture memory. s257 returns to the preferred single-arena s255
path and removes repeated interval work. The eight-input window,CPU confirmation
boundary,soft3ms/256-call policy,time tickets and physical equations are unchanged.

Each successor interval has `id>1`,so its initial film and initial history select
the previous interval's owned roots unconditionally. The old graph materializes
copies of both. It also runs three initial-inventory passes whose only live
purpose would be initializing a fresh history;that branch is not used here.

s257 directly references the previous owned film/history roots for stages2..8.
An ancestor walk then removes those now-dead initial-inventory subgraphs. Five
passes per successor,35 per eight-input window,are removed. Stage1 keeps its
initializers and inventory so first seed,retry and cross-window resume retain
their established behavior. Checkpoint rearming,source generation headers,
geometry audit,physical decisions,handoff checks,final stock/ledger audit and
all time/receipt validation remain.

| Sixteen normally completed frozen inputs | s255 | s257 |
| --- | ---: | ---: |
| GPU windows / CPU receipts | 2 | 2 |
| Passes per window | 576 | 541 |
| Total accepted draws | 1152 | 1082 |
| Owned textures | 65 | 65 |
| Descriptor bytes | 74434592 | 74434592 |
| Descriptor MiB | 70.986 | 70.986 |

Draw count falls6.076%. Seven removed packed-film outputs avoid56MiB of film-copy
target writes per window by descriptor dimensions,plus associated source reads
and initial-inventory work. This is a structural traffic estimate,not a measured
memory-bandwidth/GPU/FPS improvement. Physical allocation peak stays unchanged;
the existing lifetime pool still needs65 allocations. No extra arena is used.

## Owned read domains

The previous film/history banks remain inputs until all current readers finish
in the ordered graph. Canonical lifetime compilation and an independent Python
audit prohibit a new target from sharing storage with a resource read by that
same pass. The prior root can serve several read-only texture names;it is never
simultaneously a render target. Final film/history/checkpoint,dummy frame and
receipt remain exclusive pins. No external or renderer texture is imported.

Construction and binding require eight consecutive positive input identities.
This makes the resumed-only successor assumption explicit. A blocked or partial
prefix also preserves those prior roots,as the original copy shaders did. The
existing GPU checkpoint/decision gates remain responsible for stopping later
time advancement. No cached geometry is assumed invariant across changing poses,
forces or weather;those dependent passes still run normally.

All retained descriptors,shader bodies,uniform schemas and bound values match
their named s255 counterparts exactly. Only the two initializer input links and
dead nodes change. Cache keys use a separate257000 namespace so changed topology
cannot collide with a previously loaded diagnostic's pass/schema keys. The
qualified receipt marker255001 and dyadic queue ABI remain unchanged.

## Verification

- Independent DAG comparison identifies precisely35 removed nodes:initialFilm,
  initialHistory and three initialInventory passes at each successor stage.
  Every retained shader/schema/payload is unchanged;changed texture links are
  exclusively aliases to that stage's previous film/history roots.
- Independent lifetime/shape/pin analysis reports541 logical nodes,65 physical
  allocations and74434592 bytes. The existing strict shader preflight is inherited
  because shader bodies and binding schemas are unchanged;native execution also
  compiles its used variants under the existing strict oracle.
- Eighteen qualified owner modes,nine tails and ten queue/receipt/storage guards
  pass,including all eight refusal positions,pending/slow/synchronous callbacks,
  malformed status/prefix/time,cancellation,timeout and bounded repeated refusal.
- Native HLSL checks compare the first eight changed-force/dt intervals against
  independent single-input physical references. The complete16-input adaptive
  sequence replays the sealed s255 receipts/tickets and compares final packed
  film/history/checkpoint against its sealed independent reference roots. Natural
  late refusal and half-step recovery must be preserved. Refused first/last,
  invalid middle summary and partial-first controls cover stopped alias paths.
  All4204 native draws pass. Native results are in `gpu_checks.json`;this is
  correctness,not GPU timing.
- Seven actual-adapter mocked panel cases,five lazy host guards and six decoder
  rejection cases pass. Game links/source hashes match the workspace.

The first native validation was stopped after its first matching window to give
the compact topology a separate cache-key namespace. `pre_namespace_batch.lua`
and `pre_namespace_builder.py` retain that intermediate source. The completed
native report must hash the final namespaced source;the interrupted run is not
reported as a completed pass. There is no change to a physical shader or numeric
tolerance to obtain the expected results.

Native arrays model physical-slot overwrites;actual CSP resource scheduling is
a separate gate. Old s255/s256 evidence is preserved. No Git commit/push.

## Actual CSP observation

Fresh-session user report and automatic logs agree:observed;2 windows;16 inputs;
1082 accepted draws;65 textures/74434592 descriptor bytes;2 readbacks and2 CPU
disposals;20 verified file checks. Advanced physical time0.2222900390625s,debt0.
Both receipts have prefix8/mask255 and the qualified normal marker255001. The
unchanged decoder accepts finite water/time/area/status and resource ownership.

| Caller metric | s255 warm window | s257 warm window |
| --- | ---: | ---: |
| Completed inputs | 8 | 8 |
| Accepted draws | 576 | 541 |
| SDK-call elapsed sum ms | 5.2033 | 5.0137 |
| Submission pumps | 3 | 3 |
| Read request→callback increments | 10 | 10 |
| Prior receipt→current receipt increments | 14 | 14 |
| Readback wall ms in owner | 154.9726 | 177.4158 |
| Whole caller cycle ms | 240.7645 | 267.1470 |
| Bind ms | 2.2580 | 2.8404 |
| Submit preparation ms | 1.4623 | 1.9625 |
| Whole-pump maximum ms | 4.0850 | 5.3486 |
| Advanced physical time ms | 153.0991 | 111.1450 |

The structural work reduction is confirmed in actual CSP with unchanged memory.
SDK-call elapsed sum is0.1896ms/3.64% lower in these observations,which is not a
qualified performance improvement from a single sample. The whole caller cycle
is26.3825ms longer;readback wall time is22.4432ms longer,85.07% of that arithmetic
difference. The remaining cycle-minus-readback increase is3.9393ms. Identical
frame increment counts with different wall durations do not isolate copy-elision
cost or prove identical GPU execution. No GPU timestamps/FPS were measured.

Both variants have one warm sample in separate sessions. Their frozen dt,pose
and water stock differ. In particular,the smaller captured s257 dt explains less
physical time represented per input;the0.41604 physical-time/elapsed ratio cannot
be interpreted as a matched-model regression from s2550.63589. For this sample,
count capacity is29.9461 inputs/s,23.9568/s with20% reserve:a20Hz planning
candidate only. Zero final debt from a finite list is not continuous catch-up.

Warm bind+submit preparation is4.8029ms,and the maximum whole pump5.3486ms
exceeds the3ms soft budget. This is material CPU preparation work to reduce;
the aggregate logs do not locate the peak at one specific statement. The current
batch builder still constructs full single-input packets before selecting the
retained passes,and the executor copies/validates submission values. Future
reuse must retain immutable per-job submission ownership and may not mutate
parameters referenced by a pending GPU/readback job.

The cold window takes8866.8176ms with529 SDK pending returns,start18.1189ms,
whole-pump peak8.0695ms and single SDK-call peak7.9666ms. The pending path is
spread over callbacks;this does not show an8.9s blocking frame. Cold setup and
occasional SDK calls remain startup/tail risks. Different cold captures do not
establish a universal initialization improvement.

**Decision:**actual correctness/owned aliases and reduced work at unchanged
memory pass. Keep s257 as the lean private development base;measured speedup,
continuous processing and public/FPS adoption remain unqualified. Preserve the
s255 baseline and the original pending evidence. Raw/decoded/comparison files:
`actual_capture.log`,`actual_observation.json`,`actual_evaluation.json`.

## Reproduction

Fresh unpaused game/replay;other diagnostics OFF. Main RainFX → Weather inputs
and physical units (P0):**Enable s257 recurrent copy elision** →
**Run s257 recurrent copy elision once**.

Normal expected:observed;2 windows/batches;16/16 inputs;1082 draws;65 resources;
advanced all input time;debt0. Physical refusal can add windows/draws without
new allocations. Send the displayed values/error. About71MiB of private GPU
canvases remains until session end. Per-window preparation/SDK/pump/cycle/readback
and planning capacity are automatically logged. Weather/driving/FPS comparisons
are not needed for this private correctness/caller-cost gate.

The context is still16 frozen copies of one captured engine input with controlled
20µm film. Continuous intake,head/birth coupling,renderer access,source/force
resampling and displayed s87 physics are unchanged/unadopted.

## Evaluation and next

Actual ownership/physical receipt checks now pass. Removing35 passes does not
shorten the asynchronous callback delay;draw/traffic savings alone do not pass
optimization or FPS adoption. Keep the work reduction separate from that timing
conclusion and avoid adding larger windows or arenas. Next reduce repeated CPU
packet construction/preparation and indivisible spikes,with immutable-cache reuse
only where inputs truly match. Bounded live-input/response-age integration remains
necessary. No automatic20Hz cadence or unbounded time debt is introduced.
