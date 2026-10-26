# RainFX roadmap (accepted items, not scheduled) — updated 2026-10-23

## Current direction — 2026-10-25 product refocus

Superseding direction: [CSP implementation redesign](RAINFX_CSP_REDESIGN.md).
The user requested a fresh plan independent of the existing model. The old P0 is
retained for comparison; its repair/absorption roadmap below is historical and
is not a prerequisite for the new design. Thirty-eight diagnostic menus and13
installed probe apps were removed; tool/archive inventory is in development/cleanup_20261025.

[Actual serial156 execution blocker](RAINFX_JOINT156_COMMIT_FIX.md) takes priority.
Commit-specific input specialization is connected and locally checked, but actual
CSP repair is pending. Do not add absorption/coalescence before this near-start
fault is resolved in ordinary use. No new standalone diagnostic app is required.

[Actual fine-optics game review](RAINFX_FINE_TRAIL_GAME_REVIEW.md): video quality
FAILED despite running state. Parent-cell point expansion caused grid tearing;
continuous optical reconstruction is locally corrected. Persistent broad film
is a separate structural gap: no active drainage/pool handling. Prioritize that
bulk-water behaviour before more trail polish. The next user video confirms
visible trails but reports low-cadence motion and weak-rain overcoverage.
[Frame-rate display interpolation](RAINFX_FRAME_DISPLAY_INTERPOLATION.md) is now
connected and locally checked; actual CSP quality/cost remain unverified.
Bulk drainage/pool handling and weak-rain scene consistency remain required.

[Regional film-to-head return](RAINFX_REGIONAL_POOL_RETURN.md) is now connected
to P0. Native source/ledger checks pass; a4s linked frozen-stock case produces
physical exit but still leaves excessive broad film. It is a preview candidate,
not game-quality approval. Next required interaction is bounded local absorption
or coalescence, then dry-start weak/heavy source evaluation. No new standalone
probe series or repeated long game run is requested.

[Fine trail product optics](RAINFX_FINE_TRAIL_PRODUCT_OPTICS.md) now feeds the
actual P0 output with4096x1024 reconstructed film. Per-cell coarse/detail budgets,
GPU receipt phase, sparse display bins, and unchanged-state caching are connected.
About102MiB optical workspace accepted for quality; actual GPU time is unmeasured.
Local/native checks pass. One bundled game quality/cost observation is pending;
Game validation of display interpolation and full reference-scene qualification remain open.

[Accepted trail source export](RAINFX_ACCEPTED_TRAIL_SOURCE_EXPORT.md) is connected
to the actual P0 graph/executor:16 fixed GPU cohorts preserve unrounded geometry
and isolated coarse trail contribution. About18MiB and4 draws/interval added;
no physical recipe changes or extra readbacks. Fine optical consumption remains
next. Quality takes precedence over texture occupancy; judge execution bandwidth,
submission and synchronization costs separately from VRAM usage.

[Bounded trail display ownership](RAINFX_TRAIL_DISPLAY_HISTORY.md) now limits
history, fades/evicts detail back to coarse film, and conserves each existing
cell's display budget in measured-path offline scenes. Lua/HLSL checks pass.
Product optical inputs still lack accepted per-step trail geometry and isolated
coarse trail contributions: exporting those together is the next concrete
connection. Film total differences are not a valid substitute. No runtime call yet.

[Continuous trail line](RAINFX_CONTINUOUS_TRAIL_LINE.md) replaces per-segment caps
with a normalized integrated compact profile. Native split checks pass and actual
recorded paths are compared with matched field/RGB sampling. Roughness is reduced
in the optical reference but not fully removed. No runtime integration yet; the
next task is bounded detail ownership/history, not further kernel precision work.

[Sub-cell trail display implementation](RAINFX_SUBCELL_TRAIL_RECONSTRUCTION.md)
records real transferred segments, reconstructs narrow display detail, and provides
a native-checked analytic HLSL profile. Thin refraction becomes visible, but
roughness remains and runtime adoption is deferred. No physics/default/field
resolution changes. Bounded coherent detail history and32Hz display continuity
remain product work, not another transport-precision prerequisite.

[Linked material trajectories](RAINFX_MATERIAL_TRAJECTORY_REVIEW.md) now compare
measured seeds on the actual mesh using SI force and native bounded tracing.
Captured spatial coating already differs from uniform hypotheses; no new
material default is adopted. Current P0 shows its captured material values.
Sub-cell trail presentation and bulk-pool separation remain required.

[Visor material contract and reusable evidence](RAINFX_VISOR_MATERIAL_MODEL.md)
separate contact shape, pinning, dynamic resistance, residue and optics.
Primary-source registry, unmeasured profile hypotheses and Python/native helper
comparisons are available. These are not new runtime defaults or a completed
reference-scene material fit; bulk-pool classification remains required.

[Weather input visibility and cumulative diagnostics](RAINFX_WEATHER_RESPONSE_AND_DIAGNOSTICS.md)
now distinguish captured engine changes, supported responses and incomplete effects.
Historical momentum alone is diagnostic; current stock/per-step/water remain hard.
No new GPU work. CSP stability and visual adequacy remain pending.

[Actual deposit+drying baseline](RAINFX_PRODUCT_DEPOSIT_BASELINE.md) now removes
optional active film transport and its ledger delta from the same P0 product path.
74 recurring draws/interval and87 graph canvases; actual timing/CSP stability are
pending. This is a code change, not merely a priority document. Display continuity
and coherent head/trail appearance remain next.

First implementation: [field drying/micro joining](RAINFX_PRODUCT_FIELD_LIFECYCLE.md)
is connected to the existing actual-input continuous path with no extra passes
or resources. Local native and product regression pass; CSP/scene quality is
pending. Continuous displayed motion and coherent appearance scales remain next.

[Three user-supplied target scenes](RAINFX_TARGET_SCENES.md) define the visual
acceptance: mostly clear/sparse rain, partial haze with clear paths, and abundant
water with strong local refraction. Use one continuous model and actual inputs;
do not add three weather presets or standalone probes. Start with the clear case.

[Current product scope and retrospective](RAINFX_PRODUCT_REFOCUS_2026-10-25.md)
supersedes the ordering and forecasts below. First deliver one minimal integrated
scene with actual weather/car input, physical drops, deposit/decay/runoff and
optics. Active film transport/pool work and further independent numerical probes
are on hold until that scene demonstrates their need. The current audited runtime
still exists and is not release-qualified; this document change does not disable
guards or implement the simpler path. Next implementation timebox60–120min with
one approach; evidence is working scene linkage, not another isolated pass count.

[Preview visual contract and missing processes](RAINFX_PREVIEW_VISUAL_CONTRACT.md):
preserve the useful SI model; restore field drying/micro conversion, provide
continuous displayed motion and define coherent head/trail/film display scales.
The current32Hz zero-order display and large field appearance are not final quality.

All following sections are development history, not current prerequisite gates.

## s282: six-minute visible follow-up and bounded input recovery

[Input recovery and actual milestone](RAINFX_S282_BOUNDED_INPUT_RECOVERY.md).
The user observed drops/film and11618 accepted intervals before an atomic input
capacity stop. A focused baseline reproduces that stop after a200ms frame; the
product now stages bounded captured input and retries in order while keeping
solver16-slot/0.5s limits and GPU storage unchanged. Both200/250ms bursts recover
locally; genuine stalled completion remains bounded. Actual recovery is pending
ordinary use; no new long-run probe requested. Essential interactions remain next.


## s282 follow-up: continuous-runtime refusal classified and repaired

[Focused inventory comparison repair](RAINFX_S282_INVENTORY_ROUNDOFF_REPAIR.md).
Source mask32 from actual serial326 is an ill-conditioned signed momentum
comparison; no water difference or per-head error was reported. Apply the
existing ledger-term precision scale to that momentum comparison only. The
visible candidate remains pending actual CSP validation; essential merge/pool
work follows once the existing product run continues. No new probe app.

## s282: continuous physical RainFX optical preview connected

[Visible product candidate](RAINFX_S282_COMMITTED_OPTICAL_PREVIEW.md) / [effort ledger](development/work_ledger.json).
The main P0 panel now offers a default-OFF continuous physical preview. Fixed32Hz
birth/head/source/film state feeds existing head and film optics through GPU
receipt-selected read-only snapshots. No extra readback or three-second run cap.
Local capture/owner/raster-seam checks use mocked engine/solver GPU; three optical
programs also pass strict FXC and native WARP checks. Actual CSP appearance and
throughput remain unverified. Next: one bundled **visible** game evaluation, then
essential merge/pool interactions and whole-app2048/4096 qualification. No new
invisible probe. Read the stage document for activation and remaining limits.


## s281: actual input adapter and fixed32Hz owner implemented

[Product input/runtime](RAINFX_S281_FIXED_INPUT_RUNTIME.md) / [effort ledger](development/work_ledger.json).
Actual engine capture, typed fixed-step headers and existing executor are wired
through a product factory. Linear coefficients integrate; density-time weighted
source sampling and midpoint air retain explicit approximation limits. Local
real-capture/mocked-GPU cases pass. Main-app activation, optical commit consumption
and actual CSP performance remain outstanding; no new user probe. Next: useful
optical preview with safe latest-commit selection, not CPU-stale bank handles.

## s280: fixed-cadence foundation and development-effort tracking

[Scheduler foundation](RAINFX_S280_FIXED_CADENCE_FOUNDATION.md) / [effort and benefit tracking](RAINFX_DEVELOPMENT_EFFICIENCY.md).
Default32Hz avoids the old30Hz quantized transport-cost boundary. Declared linear
input/time integration, bounded work tickets and ownership are locally verified;
actual engine/GPU/optics integration is still outstanding. No new user test.
Before each stage, record effort range, expected product benefit and approach/run
budgets; afterwards record measured scope, failures, outcome and next decision in
`development/work_ledger.json`. Start the clock before analysis; do not count user
waiting as implementation time or invent missing historical durations.

## Current priority: product execution and optics, not repeated probes (s279)

[Product delivery priorities](RAINFX_S279_PRODUCT_DELIVERY_PRIORITIES.md).
User-directed policy: stop the repeated invisible3-second gate. s278 accepted148
nonzero-water intervals with small closure residual, then overloaded; realtime
adoption remains unqualified. Next: bounded fixed-cadence product execution,
separate qualification audits from the hot path, and connect committed optics.
No new s279 probe or user run. Preserve conservation, ownership and overload
criteria; do not enlarge the queue or mark stopped runs passed.

## s278: canonical inventory and bounded recipe reuse (2026-10-24)

[s278 handoff and reuse](RAINFX_S278_CANONICAL_HANDOFF_AND_REUSE.md).
Actual s277 first session reaches source head contract1 at slot1538/serial37;
second session hits entry_capacity earlier with zero live compilation retries.
Reuse accepted physical old packets and fixed recipe topology; keep all limits.
Native controlled handoff,2865 cached/fresh draw descriptors and local controls
pass. The existing actual3-second combined gate remains pending.

## s277: queue retirement and dispatch preparation (2026-10-24)

[s277 scheduling and allocation repair](RAINFX_S277_RETIREMENT_AND_DISPATCH.md).
Actual s276 accepted23 receipts, then hit entry_capacity before nonzero water;
the physical fix remains unqualified. Retire completed inputs before intake,
build dispatch packets lazily, release submitted CPU recipes and cache rewrites.
Capacity/physics/GPU calls are unchanged. Controlled capacity boundary now drains;
293 draw descriptors match s276 exactly. Actual3-second gate pending.

## s276: CSP728 review and source-cell fix candidate (2026-10-24)

[s276 compatibility and zero debit](RAINFX_S276_CSP728_AND_ZERO_DEBIT.md).
Full649/728 package diff and23 critical API blocks reviewed; no API rename needed.
Actual728 s275 again refuses serial37, now located in source cells (mask330).
Zero pool debit now preserves the old packet exactly across all8 source passes;
physical thresholds remain unchanged. Local controls pass; actual gate pending.

## s275: current integration gate (2026-10-24)

[s275 source approval and cold startup](RAINFX_S275_SOURCE_APPROVAL.md).
Actual s274 produced nonzero water but stopped at serial37 (reason7);
the three-second gate remains unpassed. s275 retains approval criteria and adds
source-specific reasons to the existing audit, with seven snapshot bindings and
no new canvases. Warmup uses the existing60-second overall startup bound.
Next: same integrated run, then optics and whole-app performance after acceptance.

See `docs/README.md` for the document index and working rules.

## Current roadmap and measurement summary (2026-10-20)

See `RAINFX_S122_PROGRESS_SUMMARY.md` for consolidated game observations,
physical/accuracy metrics, resource/protocol evidence and remaining gates.
Current game physics remains s87, diagnostics s89; s91+ physics is offline.
s127–s151 add isolated actual CSP and offline input/ownership diagnostics.
s152 connects a default-off CPU context diagnostic to the main app's actual
visor world pose and physical settings, without live solver adoption.
s153 owns immutable GPU copies of seven static physical inputs and the context;
actual full-input fingerprints pass, with session retention and no solver adoption.
s154 derives the actual-grid world metric/area/connected-run cache; actual full-grid
consumer and independent CPU samples pass at frame660, without water evolution.
s155 binds a reconstructed actual-frame cache to the unchanged physical film
force operator at1024×256; full-grid offline force/units/closure checks pass.
s156 halves its force buffer to8MiB and connects compact status/exchange readers
to the offline source/transport/ledger and retained-time continuation paths.
s157 restricts du/dv copies to exact field-centre samples and reduces the owned
world cache to32.3992MiB; actual1024×256 film continuation and physical resume
pass offline. The complete reference graph still needs a smaller production form.
s158 selects the checked bank path, removes23 private outputs and retains
continuation/ledger/debt results with130.3114MiB instead of199.9678MiB.
s159 removes applied-source/event/force copies and stores only recipient End/Mean;
the actual-grid graph is85.8104MiB /46 passes, still above the retained owner cap.
s160 directly reduces status per16×16 tile:77.8104MiB /44 passes. The peak at
second-axis gather is unchanged; proposed pooling plus cache still exceeds64MiB.
s161 reduces donor exchange earlier:static peak48.8288MiB, or61.2280MiB with
retained cache. Exact-shape reservation plus cache66.2272MiB still needs reduction.
s162 packs final End/Mean and validates checked direct packed resume.47 passes;
fresh-input pool proposal plus cache62.2272MiB, but recurrent66.2272MiB retains
the previous2H bank. That recurrent64MiB gate remains open; no pool is executed.
s163 validates a scalar R32F film-area cache without losing area precision or
invalid-packet rejection. Recurrent pool+cache descriptor proposal63.2272MiB
passes its scoped64MiB gate with0.7728MiB margin;real pool/completion and the
complete application budget remain open. Main/game are unchanged.
s164 executes native typed pooling with real immediate-context order/event
completion. Scoped descriptor peak63.2272MiB matches the proposal;separate and
pooled roots retain bits. Explicit observer returns protect prior input views.
General CSP completion/new-frame cache ownership and live solver admission
remain open;no main/game changes or timing claim.
s165 adds controlled new-frame admission, two waiting contexts, completed-reader
cache replacement/quarantine and retry. Water/time closure and pool parity pass
with32 extra bytes; nonzero source/head and actual frame cadence remain open.
s166 adds retained nonzero birth/head/source and quarter transport on a small
native reference. Source-on/off/on/retry/replay gates pass, but existing actual
source diagnostics plus cache exceed64MiB. Source fusion and combining this
chain with the bounded queue/cache remain open before live adoption.
s167 removes the large source atlas/full status and preserves public bits;
full-resolution sparse source plus reserved cache now fits60.210MiB. The joint
head/source/transport banks and leases still require a complete retention plan.
s168 adds that two-frame descriptor plan with full-resolution head geometry,
previous/new banks and explicit readers. Field-centre metric aliases and raw
boundary/source-cell channel assumptions require adapters; current static
inputs alone exceed64MiB. Minimal retained-cache plan is122.687MiB live and
133.501MiB reserved. Total64MiB gate fails;core-cache/R8 and a split128MiB
policy are unverified/unadopted proposals, not live execution authorization.
s169 verifies the binary R8 boundary component and independent-size/red-channel
birth/head readers offline. Actual full mask/geometry point checks and28 small
producer graphs pass317 WARP draws with legacy root bits retained. Descriptor
saving12MiB leaves the current-cache joint proposal121.501MiB reserved, so
resolved source-cell/view adapters and complete retention remain open.
s170 implements and composes resolved source cells with area/header/frame
validation. Full actual cell bits and23 preserved source cases match;10 added
faults roll back.527 native draws/36 graphs pass. Real adapter plus independent
current/expected headers add1664 reserved bytes;current joint R8 estimate is
121.503MiB. Packed-End views,verified frame/cache ownership and total64MiB
admission remain open;no main/game changes.
s171 validates checked packed-End source reads through491 native draws and31
source graphs. Direct/cropped/frozen source roots retain bits;Mean isolation,
rollback and full view bounds pass. Six joint plans show direct packed saves
4MiB versus packed+crop,but costs4MiB more than End-only bank retention. Keep
End-only121.503MiB as baseline;next optimize static/working lifetimes. Total
64MiB still fails and runtime remains unchanged.
s172 executes the full actual-grid cache build and implements private native
core retention after real completion/audit/reader return. Cache29.399→21.001MiB
and subsequent force/resolved-cell bits match.118 draws/5 events verify pending,
stale,read-held and failure quarantine guards. This proves one native generation;
CSP session retention stays unchanged. Core joint113.104MiB is still a warm
descriptor estimate,not combined execution,and total64MiB remains open.
s173 connects native core retirement to bounded immutable cache generations.
Four controlled actual-geometry contexts,weather sharing,rigid-pose rebuild,
held old readers and failed preparation/retry pass247 draws/19 events. Every
core/physical output matches full-build references and independent SI force
checks pass. Replacement peak89.019MiB is measured in default-texture descriptor
bytes under the local96MiB cap. Stock/clock evolution and the combined source/
head/transport owner remain to compose;the joint64MiB gate is still open.
s174 connects the bounded immutable-context policy to nonzero source/head/
transport and whole-frame bank/cache/clock publication on the preserved13×7,
eight-slot reference.618 draws/37 real events/32 copies retain every s166
physical and bank bit;cache/source/copy failure,replay,held reader and accepted
time closure pass. Three commits publish46.875ms. Full-grid declared plan
113.104MiB refuses before device creation;actual cache construction and curved
physical recurrence are not composed. Reduce complete lifetimes before the
actual-grid chain can be admitted;no game changes or user test.
s175 verifies a lossless full-resolution FP32 geometry dictionary:32MiB raw
du/dv becomes8.71875MiB index/tables.140 native draws/30 strict bodies retain
every full-grid/field-centre/point decode bit and physical fixture root. Actual
head post-force parity passes,but the planar-packet curved transaction refuses
in both paths;accepted curved recurrence is not claimed. Warm joint reservation
113.104→89.823MiB remains a proposal and exceeds64MiB. Dependent-load costs rise;
integrate the dictionary with cache construction/leases and measure before adoption.
s176 executes the dictionary through the full native cache build and bounded
replacement owner,with a shared8192-position head-geometry reader.83 draws/11
real events retain all prior cache/physical/probe bits across weather,rotation,
failure/retry and old readers. Cold native du/dv image uploads become zero;
dictionary8.71875MiB stays retained. Component peak89.019→70.379MiB still fails
64MiB. Full source/head/transport/bank/time composition and timing remain open.
s177 replaces whole-generation observer retention with exact resource leases
and explicit completed-preview return. Identical83-draw output bits and four SI
force oracles pass;13 native events include two extra force observer audits.
Replacement peak70.379→58.362MiB passes the scoped default-texture64MiB ceiling,
with separate46.095MiB staging excluded. Held force prevents eviction/capacity
admission;old geometry readers survive unrelated returns. Full physical owner
composition,whole-app64MiB and target timing remain open.
s178 replaces disabled wet/pool zero images by two1×1 RGBA32F inputs only after
immutable OFF-profile/payload validation.618 native physical-stream draws plus
44 full4096-slot birth draws retain output bits and all inventory/time checks.
Warm dictionary plan89.823→85.808MiB remains over64MiB;16 actual force and2
source-cell last-reader records remain unchanged. This is preparation for cache/
physical owner composition,not complete actual-grid execution or live adoption.
s179 hands off seven completed immutable bank roots;film retains its independent
End copy.618 native draws/37 events preserve all physical/bank bits,water/time,
failure/retry and old readers. Bank copies32→4 avoid8.375MiB of full-grid logical
read/write traffic per publication. Existing pool reuse offsets the memory
benefit:reservation drops only48B to85.807526MiB,live peak stays74.992050MiB.
The64MiB gate still fails;force/map/gather overlap is the next memory target.
s180 introduces an explicit physical End-only output profile without an external
Mean consumer. Internal force/gather Mean equations remain unchanged.615 recurring
native draws and141 actual-grid operator draws preserve End/ledger/checkpoint
and bank bits across acceptance,refusal and continuation. Warm live peak drops
4MiB to70.992050MiB and reservation8MiB to77.807526MiB;64MiB still fails. Mean
requests require the preserved packed output profile. Joint actual-grid cache/
physical ownership,common optics and target timing remain open.
s181 stores exact FP32 world bases/Gram diagonals in two bands instead of three.
Native construction/decode of four actual frames,signed disabled flags and
physical recurrence retain original bits across766 final-configuration draws.
Warm metric12→8MiB reduces live66.992050MiB and reservation73.807526MiB;the
64MiB gate still fails. A qualifier experiment with physical bit drift is saved
and rejected. Packed metric construction still needs composition with the
actual-grid cache owner;target timing and CSP adoption remain open.
s182 composes the packed metric producer with actual-grid immutable cache
construction/replacement,weather reuse,resource readers and failed/retried pose
builds.83 native draws/13 events retain cache/force/head-lookup/audit bits;local
cache peak58.362→54.096MiB now admits the held-force pose. Full warm live66.992050/
reserved73.807526MiB remain unchanged from s181;the same saving is not counted
twice. Complete source/head/transport ownership,CSP completion and timing remain
open;no water stock or solver clock evolves in this cache component test.
s183 rejects simple map/gather/post size changes that increase exact-shape pool
reservation. Bounded integer connected-run coordinates instead use lossless
RGBA16F:4→2MiB with unchanged shader bodies/draw count. Actual-grid cache and
small physical recurrence preserve cache/force/water/time/bank bits across698
draws/50 native events. Full warm live64.992050MiB/reserved71.807526MiB still
exceed64MiB. All18 physical last-reader records remain intact;next reduce
remaining working/bank or exactly representable static-input overlap.
s184 stores raw-cell area/coating FP32 bits and exact quarter coverage in
RG32_UINT:retained4→2MiB and no extra draw.83 actual-cache draws/13 events retain
all logical cells,cache/force/resolved-source/audit bits;typed format/payload
guards and119 native/Python codec cases pass. Proposed full warm live62.992050MiB
now fits64MiB,while reservation69.807526MiB remains5.807526MiB over. All previous
adapter and physical last-reader gates remain;no whole ownership or CSP adoption.
Next reduce persistent typed-pool reservation/working-bank overlap before
actual-grid cache/source/head/transport publication.
s185 retires only completed,unreserved free textures after atomic preflight.
The224KiB small native owner preserves physical/bank/water/time bits across615
draws/37 events;14 evictions add11 texture creations and no GPU draws/events.
Independent lifetime certification places the full warm bounded proposal at
63.998932MiB,but its1120B margin is narrow and allocation churn increases.
Permanent-pool69.807526MiB remains an unchanged fallback;full actual-grid joint
execution,cold/replacement ownership,CSP completion and timing are still open.
Next reduce churn/increase margin before actual-grid joint execution/adoption.
s186 compares largest-first,best-fit,smallest-first,oldest-request and least-used
retirement. All alternatives worsen warm creation traffic/count;keep largest-first.
Both native comparison runs preserve physical/bank/water/time bits. Independent
typed-shape witnesses establish a63.991043MiB phase floor,so victim reordering
can leave at most9392B below64MiB. Next inspect exact transport-intermediate
storage/layout reduction rather than further eviction tuning. Full ownership,
CSP completion,target timing and live adoption remain open.
s187 verifies a seven-word FP32 End/Mean candidate with shared exact volume.
All four private packet shapes change together;778 verification draws preserve
small recurring and actual-grid physical outputs. Phase floor61.991043MiB is
2MiB lower,but permanent reservation75.807526MiB,creation-byte traffic and
logical producer work increase. Preserve as experimental,not the default.
Next evaluate a supported paired output layout that emits each cell once and
shares donor traversal;verify backend support and pool traffic before adoption.
s188 gates paired output on the exposed SDK and rejects two ordinary output
targets in the descriptor model. Static dictionary tags instead pack exactly
with six FP32 xyz words:608KiB and one binding saved.119 standalone native
draws retain full geometry and10 birth/head graph outputs. Warm modeled63.5MiB
retention leaves536,672B under64MiB and reduces creates111→107. Select this
representation for the next offline retained owner;runtime remains unchanged.
s189 connects that representation to the actual-grid native cache/preview and
paired input-generation rebuild.83 draws retain all logical outputs;608KiB
default-texture/staging savings are verified. Four extra geometry-test events,
without shader draws,verify fresh uploads,failed revision discard,new-ID retry,
old readers and exact8.125MiB atomic pair retirement. Total17 events;the same
asset is rebuilt,while changed asset contents remain refused. Next compose
whole cache/source/head/transport ownership,including cold/overlap accounting.
s190 executes that schedule's full-size typed allocations on one native context:
523 logical resources,107 backings,29 retirements;peak66,572,192B matches the
certificate. Real bootstrap cache transfers without copies and retains all
proof bits. Warm canary writes and2,890 sampled reads validate lifetimes,not
water physics. Failed/retried bootstrap and adapter phase,held retirement and
budget refusal pass;an extra geometry revision at the peak refuses. Next bind
actual physical shaders and recurrent bank/time publication to this owner.
s191 connects those actual shaders to the same full-size owner. Two controlled
fixed-context intervals publish recurrent GPU water banks and exact solver
time together. Positive/zero-arrival runs pass independent source/world-velocity
and water/momentum checks;one near-cancelled legacy UV-component criterion
remains failed and is reported. Default texture peak stays63.488190MiB;107
warm generations,29 retirements and final0B match the certificate. Native
fixed-context physical64MiB gate passes. Next compose pose/weather cache refresh
with blocked overlap,retry and preserved accepted-time accounting,then long runs.
s192 composes controlled forcing/rigid-pose refresh with the actual physical
owner. Header-only metric sharing and new-metric replacement pass failed/retried
preparation and old-reader waits. Physical banks/time close under the same cap;
81 per-generation ownership snapshots per case reconcile all resources. Peak
63.488983MiB,final0B. Native controlled-refresh64MiB gate passes;next longer
recurrent streams,backlog/retirement and target cost before live/CSP adoption.
s193 constructs64 recurrent intervals with a three-request admission queue.
Execution commits26 before a genuine reversed Y donor interval refuses in
frame26. Independent Float64 widths are negative,not rounding/cache mismatch.
Quarantine protects the published bank and accepted debt;observed peak remains
63.488983MiB,final0B. The64-interval recurrence gate FAILS. Next bounded adaptive
substep recovery,then this same sequence and longer/cost/live verification.
Remaining: verified live CSP inputs/resources
and bounded backlog; economical accuracy/physical closure; head/film motion and
common optics; actual target GPU/CPU timing and long warm-run adoption checks.
Smear/local impact film are optional future corrections, not core requirements.

## Latest s274 actual CSP boundary simplification (2026-10-24)

Actual s273 rejects the empty first head at entry/context/shape code1, before
physical checks. s274 reduces the sole16-input decoder to14 using owned validated
head packets and the proven trace copy, and reuses stable per-shader CSP parameter
tables. Physical values, numeric gates and queue limits remain.11 native decoder
draws,15 owner/seven panel cases and56 shader variants pass, all with at most14
bindings. Actual fix remains unconfirmed. Next is the same combined actual gate,
then removal of the larger audit and optics/game frame-time/visual evaluation.
Do not add another broad probe series or exhaustive precision project. See
RAINFX_S274_CSP_INTEGRATION_SIMPLIFICATION.md.

## Previous s273 first failed head snapshot (2026-10-24)

Actual s272 first refusal14/context8 identifies a missing producer head receipt.
Captured CPU input/prior pose do not reproduce the failure natively. s273 keeps
all acceptance gates, propagates the first existing head error code/slot and
snapshots its raw GPU inputs/intermediates before scratch reuse. Same128 canvases,
audit payload64→640B /+18KiB. This is temporary diagnosis, not a physics fix.
Next: capture one actual failed head, fix its concrete condition, remove the
larger audit and resume combined throughput/optics evaluation. See
RAINFX_S273_FIRST_HEAD_FAILURE_SNAPSHOT.md.

## Previous s272 source context replay (2026-10-24)

Actual s271 first refusal15/mask517 is a source context failure, with checkpoint
and source-decision failures following. Transport/conservation bits are clear.
s272 keeps original acceptance and logs its failed comparison plus exact admitted
input/prior pose for local replay. No extra GPU target/readback or numerical
relaxation.22 native guard parity draws,15 owner and seven panel/log reconstruction
cases pass. Next: collect one narrow failed comparison, reproduce locally and fix
that producer/header condition. Actual throughput/optics/FPS are not qualified.
See RAINFX_S272_SOURCE_CONTEXT_REPLAY.md.

## Previous s271 warmup/earliest refusal (2026-10-24)

Actual s270 did not pass: first session hit a pending retry-count limit; second
advanced0.30392s and retained0.270326s after GPU refusal, with zero published
incident water. s271 bounds shader pending by elapsed time and retains the first
refusal condition in the existing receipt; numerical gates/queues remain intact.
Dry-start nonzero controlled source passes293 native draws;18 native receipt
parity draws,15 owner cases, six panel cases and55 shader variants pass locally.
The actual refusal is not reproduced or fixed yet. Next: one combined run with
the integrated earliest-refusal code, then fix its specific failing condition.
No optical adoption or FPS qualification. See RAINFX_S271_WARMUP_AND_FIRST_REFUSAL.md.

## Previous s270 CSP sampler correction (2026-10-24)

The actual s269 run stopped during warmup after25 draws: its birth shader
redeclared samLinearClamp, which CSP already provides. No live interval began.
s270 removes only that declaration at submission, reusing the same graph/owner.
All55 distinct variants compile with the actual failure-log sampler prelude;
the original error is reproduced and six panel/menu cases pass. Resource/time
limits are unchanged. Next: one fresh actual s270 combined gate, then optical
consumption/visual/frame-time evaluation after nonzero supply and zero-debt drain.
See RAINFX_S270_CSP_SAMPLER_COMPATIBILITY.md.

## Previous s269 joint live rain runtime (2026-10-24)

Physical births/heads, conserved source, compact film transport and the retained
asynchronous source-time owner now share one default-off main-app path. Dry
startup, actual visor inputs, eight jointly selected stock/pose roots and queued
refusal propagation are implemented. No merge/pool-return/optical publication.
293 native full-bake draws (controlled20um film; zero newly incident packets),
13 controlled owner cases and six panel/actual-menu cases pass. Every binding
fits16 textures after compiler reflection and hoisted global source checks.
128 canvases /132.69MiB plus40.13MiB file images; queue limits are unchanged.
Next: one combined actual three-second gate with nonzero rain supply and ordered
zero-debt drain, then checked optical consumption and common frame-time/visual
evaluation. No additional standalone probe series is planned. Actual populated
2048/4096-head FPS is not yet measured. See RAINFX_S269_JOINT_LIVE_RAIN_TRANSPORT.md.

## Previous s268 actual-context producer binding (2026-10-24)

One admitted context maps to immutable birth/SI/head/physics/pose headers, with
private monotonic producer frames for same-engine-frame slices. Physical wet
height comes from leased film/micro stocks. Existing pool/merge producers are
explicitly not enabled. Adapt the authored4096x1024 BC3 boundary to2048x512
physical geometry. Frame-global validation is hoisted once; all imports/targets
require typed leases. FXC reflection and body hashes limit bindings to16.
Recorded actual frame745/current bake/4096-slot native execution passes53 draws;
one declared retained head moves and matches unchanged physical shaders (error0).
No new incident occurs in that short slice; nonzero live supply is not qualified.
Six malformed context controls, display isolation and lease refusal pass locally.
Main game code is preserved. Next: assemble producer/source/raw/pose cohort into
s267 and the retained actual owner, account its complete resources, then one
combined actual continuous gate and common optical/frame-time/visual evaluation.
No separate new user probe. See RAINFX_S268_ACTUAL_CONTEXT_PRODUCER_BINDING.md.

## Previous s267 physical source + compact transport (2026-10-24)

Reuses the tested conserved source raster and preserved physical birth/head
producers. Compact film transport reconciles into the joint cumulative ledger;
End film,micro,physical heads,ledger,checkpoint and raw head state/meta select
together or retain all original bits. Retained plans avoid per-input graph
reconstruction. 726 native draws /15 cases pass, including three source ON/OFF/ON
intervals and downstream transport/metadata refusal. Nine retained/direct plan
parity cases pass. Small-grid native composition is not actual CSP source runtime.
Full-grid descriptor plans:52 source/flow/joint passes at dt<=1/60 for2048/4096
slots, before producer/cache/audit work. FPS and joint pipeline VRAM unmeasured.
Next: actual admitted context -> immutable physical producer/source/raw cohort
binding -> retained owner integration; then optical consumption/frame-time check.
Keep s266 actual scheduling as the execution route. No extra user probe required.
See RAINFX_S267_JOINT_SOURCE_COMPACT_TRANSPORT.md.

## Previous s266 actual-input compact film integration (2026-10-24)

Default-OFF main menu now connects actual context/immutable verified files to a
private world cache, s264 force/transport and s265 transactional GPU commits.
The existing source FIFO settles only ordered accepted audits; overload/refusal
retains admitted debt and separately records captured-but-unadmitted time.
A warmup is drained and reset before three seconds of real input capture.
Local evidence:78 native passes,13 owner fixtures,6 SDK-adapter panel fixtures,
actual menu dispatcher and linked installation. 50 canvases/104.597MiB owned,
plus36MiB read-only files; app/driver/staging excluded. Actual CSP controlled-film
run passes171/171 inputs over3.012811s with zero debt,50 resources and172 readbacks
all disposed. CPU owner peak7.2193ms;10-frame audits no longer serialize intake.
Scoped recurrent execution passes; sustained throughput/full-app FPS/public optical
adoption remain unqualified. See RAINFX_S266_ACTUAL_RESULT.md.
Next: conserved source/head coupling, followed by optical consumption and a scoped
frame-time/visual check. Keep the measured CPU tail and display latency explicit. Do not expand queues or generate another
standalone diagnostic ladder. See RAINFX_S266_ACTUAL_INPUT_COMPACT_TRANSPORT.md.

## Previous s265 private validated stock/time execution (2026-10-24)

See `RAINFX_S265_PRIVATE_TRANSACTIONAL_EXECUTION.md`. Provisional fields and two
committed roots are separate. GPU receipt validation selects new stock or exact
last-good fallback;submitted suffixes block after refusal.92 native draws pass
approved copy,rollback,suffix blocking,water/momentum/diagnostic failure and status
copy.12 controlled executor cases exercise64-input overlapping submission/delayed
audit,FIFO time settlement,lease retention,cancellation and quarantine. Full-grid
owned descriptors reserve80.096MiB/43 textures,excluding external inputs/cache/app.
Main/game unchanged;no actual CSP ownership/throughput/FPS/startup qualification.
Next admitted engine input/cache leases and authoritative source-time FIFO connection,
then one default-OFF actual continuous/startup gate. No new isolated latency probes.

## History s264 compact SI-force/advection/ledger (2026-10-24)

See `RAINFX_S264_COUPLED_FORCE_LEDGER.md`. Updated local depth/momentum drives
inherited analytical relaxation at every substep,then Mean-velocity projection,
bounded donor-cell advection,cumulative runoff/impulse/wall ledger and GPU identity/
time receipt.178 native draws cover8 recurrent controlled inputs/0.15s,independent
SI force closure,6 malformed physics/7 malformed ledgers and stale identity refusal.
Numeric plans are cached once with20/36/68 draws,not reconstructed through the
legacy85-pass graph. About48.094MiB working descriptors exclude external cache/
inputs/commit roots. Main/game unchanged;this writes provisional work state only.
Next retained input/cache leases and GPU-gated stock/time/ledger commit,then one
actual continuous/startup gate. Head/source/optics and whole-app cost remain open.

## History s263 bounded donor-cell advection (2026-10-24)

See `RAINFX_S263_BOUNDED_FLUX_TRANSPORT.md`. Implemented two-shader conservative
advection and a fixed4/8/16-subcycle plan without intermediate CPU acknowledgements.
118 native draws pass End/Mean conservation,nonnegative volume,disconnected
topology,known diffusion and accumulated runoff. The one-step42% limited-mass
configuration is rejected.4 substeps at1/60s limit at most0.015533% of water and
have0.096893% volume L1 difference from16 substeps on one frozen-velocity visor
interval. This is a development configuration,not a physical/visual adoption pass.
Next compact force/cache/validation/ledger owner integration and cached recipe,
then one actual continuous/startup gate. No new standalone/user probe. Main/game
unchanged;head/source/optics,whole-app memory and2048/4096 performance remain open.

## History s262 bounded recovery (2026-10-23)

See `RAINFX_S262_BOUNDED_RECOVERY.md`. Installed default-OFF path retains original
inputs through refusal,drains blocked suffixes,uses up to24 dyadic attempts and
replays original suffixes in order without a stock reset. Native actual-grid
refusal recovers with zero debt;10 owner/6 panel controls pass.99 textures remain;
allocation is staged8 per callback. Exceptional1s/64-context recovery bounds do
not qualify visible latency. Graph preparation remains synchronous and timed
separately. Actual CSP recovered/replayed11 original slices with13 retry submissions
and75/75 audited/disposed reads,then stopped on time_capacity.0.700489s advanced,
0.787547s admitted debt and one17.43ms unadmitted captured observation are retained.
The planned3s continuous gate fails. Ten-frame audit waits serialize recovery;
graph construction80.7245ms and live owner peak6.0575ms remain unsuitable costs.
Keep recovery as safety/reference;next bounded-cost GPU stability/transport without
per-retry CPU audit,and cached/staged graph preparation. Do not enlarge queues or
repeat latency probes. Head/source/optics and whole-app performance remain gated.

## History s260 GPU-resident live transport (2026-10-23)

See `RAINFX_S260_RESIDENT_LIVE_TRANSPORT.md`. One integrated main-app path connects
real capture,time reservations and retained GPU film with deferred CPU audit.
One workspace/pinned constants plus32 small audit copies reserve about71.1MiB,
not another full arena. GPU predecessor validity gates the next step;refusal
blocks suffixes and retains time. Audited physical progress is separate from
the submitted header cursor. Finite source/ring bounds,unsubmitted age,500ms
unconfirmed audit debt and shared3ms/256-call pacing prevent hidden backlog.
Multiple slices per callback support30FPS without truncation.531 actual-grid
native draws plus one snapshot-copy draw,16 integrated owner and6 main-panel
cases pass. Actual CSP then submitted/audited34 receipts(including warmup),32
continuations before prior CPU audit,99 resources and34/34 disposed reads.
The run stopped after22 live slices/0.457918s,retaining0.200001s debt;the planned
three-second continuous gate failed. Time closure and scoped asynchronous reuse
pass in this short run;throughput/FPS adoption does not. The aggregate refusal
does not identify its internal predicate. Initialization93.9495ms and maximum
live owner pump5.0305ms are remaining costs. Next review existing refusal checks,
choose bounded stable/cheaper transport and stage/cache startup. Preserve elapsed
time and water checks;do not repeat small-read/two-arena probes or grow windows. Public
head/source/optics and2048/4096-slot application performance remain later gates.

## History s259 bounded live intake (2026-10-23)

See `RAINFX_S259_BOUNDED_LIVE_INTAKE.md`. Compose observed s239 live capture with
the existing finite FIFO/quantized time slices. Entry/time/host-age overflow and
reset/cancel stop capture;retain all admitted debt and at most one unadmitted
observation. One immutable slice lease settles only after downstream validation.
12 local integration cases pass,including real factory/physical admission,
1200 slices,20 bootstrap file checks,pause/reset/mutation/late receipt controls.
Replaying s258's recorded service-rate envelope at60Hz reaches250ms debt and
stops safely;not a new CSP solver execution or throughput improvement. No main
game hook,new UI/probe or rendering change. Reuse this controller in the next
integrated GPU-resident transport owner. Normal step progress must not depend
on each asynchronous CPU audit. One focused continuous CSP gate follows that
complete path;then decide adoption or cheaper film/update policy. Avoid repeating
small-read/two-arena experiments,increasing window sizes or more precision probes
without a changed product risk. Visible2048/4096-slot costs remain unmeasured.

## History s258 selective CPU packet preparation (2026-10-23)

See `RAINFX_S258_SELECTIVE_CPU_PREPARATION.md`. Constructor-owned selections
generate only533 fresh base packets/8 summaries,excluding overwritten prototype
rows/tickets. Whole context clones and the second batch packet copy are removed.
The executor's independent submission snapshot and all physical commands remain
unchanged:1082 draws/65 textures/70.986MiB per16 normal inputs.81 packet-bit cases,
18 command streams/9 tails/10 guards and7 panel/5 host/8 decoder controls pass.
Physical/native/CSP s257 evidence is inherited;no identical native rerun claimed.
Actual CSP passes2 batches/16 inputs/1082 draws/65 resources/debt0;all120 CPU
packet pairs match. The96 measured alternating pairs improve median1.7638→
0.71555ms(-59.43%)and p95 12.7925→3.8304ms(-70.06%). Selective wins96/96,
48/48 in each order;each order improves median/p95 separately. Qualify CPU bind
preparation and use s258 as private development base. Warm owner bind+submit
2.1607ms/max pump3.0073ms is a separate limited observation;do not turn it into
an FPS claim or reject useful progress for7.3µs soft-budget excess. Bind-only
maximum6.2642ms still merits bounded preparation. Whole caller cycle262.22ms
includes174.78ms/10-frame readback;physical service ratio0.7312 and finite debt0
do not qualify continuous throughput. Next:remaining executor snapshot/typed
preparation spikes,bounded continuous intake and response-age policy. Visible
s87;no public stock/optics or dt/source changes. Whole-pipeline/FPS remain open.

## History s257 recurrent film/history copy elision (2026-10-23)

See `RAINFX_S257_RECURRENT_COPY_ELISION.md`. Retain the single-arena eight-input
s255 execution policy and alias previous owned film/history for resumed stages
2..8. Their three unused initial-inventory passes are removed with the two copies:
35 passes/window,541 logical nodes,1082 normal16-input draws instead of1152.
Memory stays65 allocations/70.986MiB;2 CPU receipts. All retained shader/payload
bits and physical equations,checkpoint/decision/stock/time audits remain unchanged.
Independent lifetime checks,4204 native draws,18 owner modes/9 tails/10 guards and7 panel/5 host/
6 decoder controls pass. Actual CSP passes2 windows/16 inputs/1082 draws/65
resources/debt0. Warm SDK sum5.014ms versus s2555.203ms;whole cycle267.15ms versus
240.76ms,with22.44ms of26.38ms difference in readback wall duration. Both retain
3 submission pumps/10-frame reads/14 callback-to-callback increments. Separate
sessions,different dt and one warm sample do not establish speedup or regression.
Work reduction/correctness pass;timing optimization remains unqualified. Keep
s257 as the lean private development base. Next:repeat CPU packet construction/
preparation4.803ms and whole-pump5.349ms spike,bounded live intake/response age.
Visible s87;no public stock/optics adoption.

## History s256 bounded two-arena continuation (2026-10-23)

See `RAINFX_S256_TWO_ARENA_CONTINUATION.md`. Two four-input GPU windows use
protected independent working sets. Arena2 may submit after arena1's final
GPU status while its CPU callback remains pending;GPU receipt/prefix/time/water
guards decide continuation. Both CPU receipts must validate before either set
is reused;per-job validators preserve concurrent dt/ticket identity. Refused or
partial arena1 blocks arena2 and retains all time for the existing adaptive queue.
Normal16 inputs plan4 windows/2 cohorts/1184 draws/130 textures/141.973MiB under
the explicit192MiB cap.4378 native draws,17 owner modes/10 tails plus7 panel/5 host/6 collector
guards pass;6 shader variants compile warning-free. Actual CSP passes4 windows/
16 inputs/1184 draws/130 resources/debt0. Both second windows finish ordered SDK
submission before the prior CPU callback;all readbacks stay10 frames. Warm8-input
cohort246.88ms versus s255240.76ms does not demonstrate a throughput benefit at
double memory. Different sessions/endpoints and one warm sample do not establish
a2.54% regression. Execution passes;optimization adoption is deferred;retain s255
as the lower-memory candidate. Cold5.38s/pending315/start26.23ms remain startup
risks. No bigger window,dt/source change,public clock/stock or optics adoption.
Next:measured reduction of interval work/static duplication and bounded live
intake/response age. Visible s87;continuous/FPS/visual gates remain open.

## History s255 eight-input GPU window (2026-10-23)

See `RAINFX_S255_EIGHT_INPUT_GPU_WINDOW.md`. Eight intervals share one receipt;
fixed3ms/256-call pacing replaces further budget comparisons. Sixteen normal
inputs plan1152 draws/two receipts with the same65 allocations/70.986MiB.
The576-node DAG uses two vec4 time banks and an8-bit contiguous accepted mask.
All8 refusal positions,partial/tail time,ownership and memory guards pass local
controls.5792 native draws pass:natural15th-input refusal and two half-step
recovery match all sequential retained roots,prefixes8/6/0/2 and final debt0.
Bank-boundary,error and partial controls pass. Actual CSP completes2 windows/
16 inputs/1152 draws/65 resources/debt0. Warm8-input cycle240.76ms gives33.23
inputs/s,26.58/s reserved;per-input caller elapsed cost falls37–46% versus the
two prior fast4-input observations. One warm sample across different sessions
does not establish FPS or continuous speedup. Readbacks remain10 frames;
accepted physical time/caller time is0.636. Cold SDK pending535/9.26s and warm
whole-pump4.085ms remain integration risks.20Hz passes only the planning gate;
batch-fill/output age is unqualified. No dt/source resampling. Next:bounded
ordered GPU continuation and lower interval work,with explicit response-age/
source/force integration before adopting any coarser cadence.
Do not infer continuous catch-up from finite drain or expand windows indefinitely.
Visible s87;FPS/visual/public head-film-optics adoption remains unqualified.

## History s254 whole-pump capacity (2026-10-23)

See `RAINFX_S254_WHOLE_PUMP_CAPACITY.md`. Pacing profiles share a soft1..3ms
budget across warm preparation/drawing and permit up to256 ordered calls.
Receipt-to-receipt caller time and accepted physical time drive a provisional
capacity assessment with20% reserve;no input resampling,dt extension or clock
publication. Fifteen complete command-parity modes,duplicate/invalid-policy
guards and seven adapter/five host cases pass. Physical graph/native evidence
unchanged. Actual comparison completes4 windows/16 inputs/1184 draws/65
resources/debt0. Fast3ms/256 cycles191.54/224.20ms versus warm1ms/32 at361.97ms;
2 dispatch pumps versus10. Fast whole-pump peaks3.004/3.013ms;all readbacks
still take10 frames. Qualify fast private execution with this limited sample.
Reserved capacity14.27–16.71 inputs/s fails the20Hz planning gate. Further call
ceiling comparisons are not the next priority:reduce CPU confirmation frequency
or solver work. Coarser film sampling needs time/force/source integration and
quality checks. Continuous intake/FPS/live adoption remain unqualified.

## History s253 four-input GPU window (2026-10-23)

See `RAINFX_S253_FOUR_INPUT_GPU_WINDOW.md`. Four inputs share one CPU receipt;
intermediate GPU summaries stop the accepted prefix at the first refusal or
incomplete retry. Checkpoint and all remaining time persist. Eight inputs plan
592 draws/two receipts instead of620/four,with65 owned textures/70.986MiB.
Fourteen owner modes,six tails and ten guards pass.2250 native draws pass
physical root comparisons,all four refused suffixes,bad-summary propagation
and partial-first blocking. Actual CSP completes2 windows/8 inputs/592 draws/
65 resources/zero debt;advanced0.17249298095703125s,2 readbacks/disposals.
Both prefixes4/masks15 pass. Warm submission takes10 pumps plus10 readback
frames:four inputs per20 engine-frame increments between receipts. At one
input per frame,this cannot catch up. Warm dispatch max0.6948ms,whole pump
2.7044ms;cold SDK max6.8391ms. Qualify bounded four-input execution,not
continuous throughput/FPS. Next:explicit incoming-time budget and pacing/
update-frequency/continuation policy,then bounded continuous intake.
Visible s87;public source/head/film/optics adoption remains pending.

## History s252 last-use storage (2026-10-23)

See `RAINFX_S252_LAST_USE_STORAGE.md`. A verified lifetime map recycles physical
intermediates after their final ordered read;retained roots and receipt stay
exclusive.155 logical resources use64 allocations/70.986MiB,down from162.104MiB.
Eight command/lifecycle parity modes,eight unsafe controls and1455 native
shader draws pass,including refused-input recovery and sequential root checks.
Native per-pass arrays model overwrites;actual CSP now completes2 batches,
4 inputs,310 draws,64 allocations,2 readbacks/disposals and zero retained debt.
Private receipts pass;advanced0.0657958984375s. Qualify bounded storage reuse,
without claiming actual CSP full-field equality or a general fence. Both
callbacks still take10 frames (155.6204/164.1538ms). Next:longer GPU-gated
continuation/confirmation amortization and bounded continuous intake. This is
not a readback/FPS improvement. Visible s87;public source/head/film/optics
adoption pending.

## History s251 preparation reuse (2026-10-23)

See `RAINFX_S251_PREPARATION_REUSE.md`. Packet bind copies one fixed payload
then refreshes dynamic fields. Idle slots reuse typed uniforms with exact
signed-zero-aware equality;one receipt conversion per reused job. Original
preparation stays available for the same-session false/true/false/true
comparison under32-call pacing. Thirty complete packet cases,typed-cache
ownership/signed-zero controls,command parity and seven panel/five host cases
pass. Actual run completes4 batches/8 inputs,620 draws,155 resources,debt0.
Warm original preparation2.5139ms versus reused1.1157/0.8773ms;conversions
918 versus39/33. Qualify scoped preparation reuse with limited sample coverage.
Reused whole pumps still peak1.7149/1.2894ms;warm submission remains5 frames
and all readbacks10 frames. Prioritize safe GPU continuation/confirmation
amortization and bounded continuous intake next. Physical shaders/queue stay
unchanged;no GPU/FPS or continuous throughput pass. Live source/head/optics
adoption remains open. Visible s87.

## History s250 bounded dispatch pacing (2026-10-23)

See `RAINFX_S250_BOUNDED_DISPATCH_PACING.md`. The versioned owner accepts
1..64 calls per pump(default32),keeps the1ms pre-call soft deadline and logs
cap/deadline deferrals,submission spans and elapsed tails. Nine local complete-
command-parity/pending/retry/slow-call controls and seven panel/five host
cases pass. Same-session8/32/8/32 comparison installed with8 frozen inputs,
4 batches,620 draws,155 canvases. Actual run completes8 inputs with zero debt.
Warm32 submits155 draws in5 frames versus20 at8,with dispatch maxima0.8645/
0.6431ms and no warm deadline deferrals. Qualify32 as a scoped private dispatch
candidate;full owner pump max2.0326ms and10-frame readbacks prevent any whole-
frame/continuous throughput pass. Cold8 backend max6.1715ms demonstrates the
non-preemptible-call limit. Next total preparation/owner cost and amortized
CPU confirmation barriers,memory/static dispatch and live inputs. Visible s87.

## History s249 retained batch recovery (2026-10-23)

See `RAINFX_S249_RETAINED_BATCH_RECOVERY.md`. Validated stage2 inventory seeds
the next batch;all seed copies/handoff audits bind the same owned prior roots
before overwrite. Exact per-input ticks retain deferred time and half-step
retries without reapplying accepted inputs;single-tail lane is disabled.
1455 native draws verify every batch's roots against changed-input sequential
references in normal four-input/two-batch and refused two-input/three-batch
recovery cases. Fixed155 allocations/162.1037MiB;CPU queue closure/lifecycle
and seven panel/five host guards pass. Default-OFF four-frozen-input main
diagnostic installed. Actual CSP completes4 inputs/2 batches with310 draws,
155 fixed resources,2 readbacks/disposals and zero debt;inventory/ledger
continue across batches. Receipt1→request2 is20 frames,then another10 frames
to receipt2. The8-call ceiling paces155 passes across at least20 callbacks;
next measure a higher call ceiling within the1ms soft CPU budget before
continuous input intake. No continuous throughput/FPS/GPU/optics adoption pass.

## History s248 two-interval GPU batch (2026-10-23)

See `RAINFX_S248_TWO_INTERVAL_GPU_BATCH.md`. GPU dependency replaces the CPU
readback between two intervals. First refusal blocks stage2;final receipt
validates both stages and preserves prefix0/1/2 and exact unadvanced debt.
483 native WARP draws verify all six accepted roots against changed-input
sequential reference plus first/second refusal and bad first audit. Seven
mocked panel/five host cases pass. Installed default-OFF frozen-pair diagnostic
uses155 draws/canvases,162.1037MiB under an explicit192MiB private cap;root
executor unchanged. Actual CSP passes1/1 batch,prefix2/2,155 draws/resources,
one readback/disposal,advanced0.0434837341s and zero debt. Final callback is
10 frames/146.8544ms,paid once for both intervals. Cold171 not-ready attempts
and230 callbacks do not establish steady throughput or an FPS gain. Next
retained batch inventory/debt recovery and lower memory;no live source/head/
optics adoption. Visible s87.

## History s247 paired completion latency (2026-10-23)

See `RAINFX_S247_PAIRED_COMPLETION_LATENCY.md`. Before replacing the serial
status barrier,interleave minimal16-word and physical-graph readbacks on the
same adapter to measure request/callback engine frames and wall latency.
Default-OFF panel installed;seven panel/eight control/five host cases pass.
Adds64 bytes/one canvas/eight control draws;physical568 draws unchanged.
Actual8/8 completes with16 readbacks/disposals and zero debt. Minimal and full
requests all return10 engine frames later (8 samples each),repeat means
148.2389/150.6607ms. This supports readback/callback-path dominance in this
session,not an internal CSP delay guarantee or GPU timestamp. Next bounded
GPU-dependent continuation with GPU refusal/audit propagation and delayed
validated publication;preserve accepted stock and refused time debt. Current
owner/executor remain unchanged;no throughput/FPS optimization claim yet.

## History s246 retained graph template (2026-10-23)

See `RAINFX_S246_RETAINED_GRAPH_TEMPLATE.md`. The candidate graph compiles
once;bind refreshes52 input/audit rows,dt,tokens,attempt progress and private
validator/results state. Shape/files/calibration changes refuse. All recipe
and packet fields match s243 for5 changed contexts/15 tickets;210 validator
comparisons,six guards,seven panel lifecycle cases/five host guards pass.
Actual CSP passes8/8,568 draws,85 resources,8 validated/disposed readbacks and
zero debt. Repeated bind averages0.1568ms;admission66.8287→0.5391ms,confirming
the scoped recurring CPU construction fix. Initial build stays73.9595ms once.
Status wall latency156.6886ms remains;different fresh captures do not establish
a causal regression from s245144.5055ms. Next review completion/readback policy
with rollback/ownership intact. Owner layout checks and draw/resource counts
stay. No actual GPU time/FPS/continuous throughput pass;visible s87 unchanged.

## History s245 callable clock adapter (2026-10-22)

See `RAINFX_S245_CLOCK_ADAPTER.md`. Actual s245 completes8/8 with568 accepted
draws,85 resources,8 validated/disposed status readbacks and zero debt. The
engine source clock is confirmed as callable cdata;the Lua wrapper fixes the
strict function boundary. Failed s244 and pending records are preserved.
Seven repeats have no not-ready calls, but reconstructing the graph costs
66.4969ms mean /73.3149ms max per interval, inside66.8287ms mean admission.
Accepted SDK submissions average1.2768ms aggregate per repeat. The first
priority is a retained immutable graph template with changed-input value and
validation-context refresh, retaining exact identity/ownership guards.
Status request-to-callback latency averages144.5055ms (max164.8177ms):review
completion policy separately after the CPU construction fix. It includes
engine scheduling/queue/readback and is not GPU execution time. Nested timer
totals must not be added. Frozen modeled time0.1223068s is not continuous
engine coverage. Actual FPS/GPU timing and sustainable throughput remain open;
visible s87 and public clock/renderer remain unchanged.

## History s244 actual-CSP dispatch profile (2026-10-22)

See `RAINFX_S244_CSP_DISPATCH_PROFILE.md`. Installed default-OFF panel captures
one visor context and repeats eight explicit private benchmark intervals with
the s243 graph/s242 owner. Cold/repeat CPU allocation,graph,uniform,SDK-group
costs,not-ready counts and callback latency are recorded;no GPU timestamps or
FPS/continuous-engine-time claim. Seven mocked real-adapter/executor panel
cases,six benchmark controls,five decoder refusals/five host guards and linked
runtime audits pass. Actual s244 faults at the clock guard before allocation;
s245 preserves the failure and records a successful repaired profile. The
85-resource91.193MiB plan remains until session end. Live source/renderer
adoption remains open. Visible s87.

## History s243 exact small-header audit (2026-10-22)

See `RAINFX_S243_EXACT_HEADER_AUDIT.md`. Seed audit compares208 uploaded header
words with exact asuint equality,removing header digest/reduction while retaining
all geometry proofs. Native two-input/three-slice continuation matches all six
s242 packed field/ledger arrays bit-for-bit;valid+five corrupted-input audit
cases and10 scheduling cases pass. Submissions229→223,resources87→85,bytes
95622608→95622448,status reads unchanged3. Expected header constants add800
logical bytes;actual CPU/GPU benefit is unqualified. At8 calls,cold85 draws
still need11 pumps,so real-time throughput remains open. Next actual warm
dispatch/constant/completion costs and dominant field-pass profiling before
further proof reduction. No game/main/settings change;visible s87.

## History s242 budgeted private stream (2026-10-22)

See `RAINFX_S242_BUDGETED_STREAM.md`. The adaptive owner connects the existing
private executor to normalized-progress admission/FIFO with default8 SDK calls
per pump and a1ms soft pre-call deadline. Pending calls keep immutable payloads;
only validated accepted progress consumes time;fault/cancel retains debt.
Ten mocked scheduling cases pass,including delayed/synchronous/duplicate/bad
callbacks and timeout. Native full-field two-input/three-slice execution carries
film/history on87 fixed resources:229 submissions,32 cache hits,three real reads,
80391 ticks advanced,debt0,remainder−0.164970us. Inputs use synthetic durations
and qualified physical rows;this is not actual continuous capture or FPS evidence.
At8 calls,cold87 draws still need at least11 pumps. Next economical dispatch/
completion and actual CSP throughput,then live sampler,conserved sources and
renderer/common optics. No game/main/settings change;visible s87.

## History s241 bounded retry and packed rollback (2026-10-22)

See `RAINFX_S241_BOUNDED_RETRY.md`. Versioned private attempt owner preserves
time on transport refusal,halves the requested step and retains its successful
size;attempt cap/one-tick failure keep debt explicit. Tickets reject changed,
duplicate and foreign-owner resolutions. A real opposing-flow refusal after
progress exposed inherited packed export copying End into Mean on rollback.
Failed evidence is preserved;the versioned fallback now reads the original
packed row. Accepted normal End matches s240;independent full-field stock,
ledger,checkpoint and source-once checks cover normal/stress retries.
The500um stress run completes13 attempts(9 accepted/4 refused),807 submissions
and zero debt;all refused states retain both film bands and history bits.
No game/main/settings change or target cost claim. Next bounded batched
execution/completion with the continuous queue and cheaper safe-step selection;
actual throughput/tail and source/renderer integration remain open. Visible s87.

## History s240 whole-interval transport candidate (2026-10-22)

See `RAINFX_S240_WHOLE_INTERVAL_CANDIDATE.md`. A versioned graph supports1/2/4/8
equal dyadic substeps without changing the transport kernels. Local full-grid
1/4/8-step equal-time runs all accept and conserve the controlled20um film.
One step advances16.666412ms with87 submissions/one completion boundary versus
267/four,with the same87 resources/91.193MiB. Compared with8 steps,volume L1
0.0103066%,momentum-vector L1 0.0346359% and total water difference0.0001641%;
the generalized4-step End matches archived s233 bits. This is one local normal
fixture,not actual CSP timing,adaptive stress coverage or continuous adoption.
Next bounded rejected-step retry/subdivision from unpublished stock,then a
batched executor that can drain the continuous queue; conserved sources and
renderer/common optics follow. No game/main/settings changes; visible s87.

## History s239 bounded CPU identity reuse (2026-10-22)

See `RAINFX_S239_CACHED_CPU_IDENTITIES.md`. Preserve s238 actual capture while
versioning packet/composer/controller: native bit.tohex,read-only observation
traversal and52 private row strings avoid repeated scalar encoding. Same
canonical bytes,pose identity and two SHA calls; no changes to physical inputs.
Static120-frame encoding calls26880→2112 is a workload result,not target CPU/FPS.
487 full identity comparisons,4096 IEEE words,25 capture controls and120-frame
queue/admission pass. Five paired panel cases,eight decoder refusals,five host
guards and linked deployment pass. Default-OFF panel now runs one sample through
both composers with alternating order:120 warmup+480 measured frames,all600
identities checked. Actual600/600 pairs now match on frames981–1580,with20 file
checks and no duplicates/pauses.480 measured composition pairs yield baseline
mean0.360915833ms/P95 0.8961ms/max1.4803ms versus candidate0.260772708ms/
0.4709ms/2.5821ms. Mean improves27.75% and P95 47.45%,but the larger single
maximum preserves a tail warning; final optimization/adoption is unqualified.
Encoding0.117706875ms is the largest candidate mean phase; row-build max2.2795ms
has no aligned event/GC/JIT trace and cannot establish the stall cause. Common
capture includes pair/wrapper overhead; standalone cost/FPS is not measured.
The dynamic run reuses20578/31200 rows on52 fixed slots,with600+600 hashes.
Short s238 whole-capture timings are a different scope,not a direct A/B.
Keep this candidate and warning,then prioritize bounded whole-interval/adaptive
execution before connecting continuous queue/solver,incident/head sources and
renderer/common optics. Current public water and optics remain s87.

## History s238 persistent coherent CPU intake (2026-10-22)

See `RAINFX_S238_PERSISTENT_CPU_INTAKE.md`. A single verified s152 bootstrap
now feeds a persistent sampler/composer with no per-frame file checks or
repeated static digests. Existing physical rows/hashes match the qualified
context; dynamic weather/forces remain fresh. Local25-case pause/long-dt/
duplicate/mode/replay/setting/owner guards and120-frame queue/v3-admission
integration pass. A default-OFF120-observation CPU capture/cost panel is installed;
four mocked panel cases,46-line decoder/five refusals,five host guards and SDK/
deployment checks pass with zero GPU allocations. Actual CSP now completes
120/120 inputs on frames3153–3272,with20 bootstrap checks and no per-frame file
checks,gaps or duplicates; raw time sums to2.2372770998626947s. First/last
header/pose identities validate,geometry/material/scales remain fixed.
Capture-only CPU mean0.7603675ms/p95 2.0361ms/max3.5412ms is material: correctness
passes but production cost is not qualified. This short sample does not isolate
JIT/GC or individual contributors; no paired FPS result exists.
SDK sim.dt already includes replay speed; cumulative cursor checks
use a stated quantization tolerance and cannot detect every tiny seek. Merely
raising the current draw cap cannot remove its four sequential quarter receipt
boundaries. Next profile/reduce physical-header packing and identity work,then
compare a bounded whole-interval/adaptive execution candidate and actual warm
cost before live queue/solver integration. Actual pause/seek/reset coverage is
still open; this120-frame run is read-only with no solver/public-clock advance.
Incident/head sources and renderer/common optics follow; displayed water s87.

## History s237 bounded elapsed-time stream (2026-10-22)

See `RAINFX_S237_BOUNDED_TIME_STREAM.md`. A16-context/250ms-debt FIFO owns a
contiguous accepted source-frame prefix,quantizes raw time once,carries signed
remainder and advances only on validated private receipts. Long frames split
into at-most32768-tick intervals while preserving the source frame/hash; no
forged frame identity or double time admission. Local pause/duplicate/partial
debt/close/drain/overflow/rewind/epoch checks,eight intake refusals,five scheduler
cases and ten split guards pass.30/60/144Hz clock runs close at one second.
One declared60ms frame drives the real full-grid private graph through two
slices/eight quarters:518 submissions/178 cache hits,87 fixed canvases,twenty
exact copies and existing water budgets; represented62915ticks,debt0,remainder
−0.419617us preserve raw time. This is local synthetic-duration integration,
not actual continuous engine intake or FPS evidence; no installation/main change.
Current proof pacing(one SDK attempt/callback)cannot sustain every-frame solving
within the bounded queue. Next coherent cheap intake plus pause/replay/reset
epochs and a measured bounded execution budget; then conserved incident/head
sources and renderer/common optics. Actual s236 remains qualified; visible s87.

## History s236 measured-scale provenance repair (2026-10-22)

See `RAINFX_S236_SCALE_PROVENANCE_REPAIR.md`. Actual s235 finishes4/4 quarters
of input one, then refuses input two at exact equality of derived unit values.
Verified geometry/material keys match; squared measured scale changes by about
0.119ppm as its FP32 pose rotates. The archived failure remains a failure.
Versioned v2 admission adds exact configured/applied scale provenance, retains
exact diameter calibration and aligns bounded measured-unit drift to the first
physical reference before fingerprinting. Actual two-header local replay passes
8/8,518 draws/178 cache hits, twenty exact copies and existing water budgets
on the same87 canvases; eight strict refusal controls, panel/parser/host and
deployment checks pass. Actual s236 frames1507/1940 now complete2/2 inputs,
8/8 quarters,518 draws/178 cache hits,seven reuses,eight CPU releases and zero
quarantines on the same87 canvases. Exact configured/applied scales stay1;
the measured reciprocal-unit one-ULP change is aligned to the initial reference.
All88 log lines,input/pose/settings/time checks and water budgets pass. Film
805.772156→805.371948mm³; cumulative evap0.028873/runoff0.371301mm³,final mass
residual−0.0000331961mm³. Represented0.03978729248s,debt0 and retained signed
remainder0.00745058us close admitted raw time. This actual pair has alignment
factor1; non-unit correction remains local replay evidence. No transport
coefficient, GPU shader or tolerance budget change. Next complete elapsed-time/
subdivision/backlog admission and incident/head/renderer/common optics. This
qualifies two sampled engine frames,not continuous time or visible-water/FPS
adoption; displayed game water s87. Original failure/pending evidence preserved.

## History s235 main-app two-input intervals (2026-10-22)

See `RAINFX_S235_MAIN_TWO_INPUT_INTERVALS.md`. A default-OFF main panel connects
the unchanged s234 owner to two independent s152 actual-visor capture instances.
The second is created only after the first four validated receipts, then the
same87-canvas pool retains stock/history/time for four new quarters. Expected
518 draws/178 cache hits, seven reuses and zero represented debt. Local real-panel
mock, capture ordering/cancellation/timeout,88-line report/parser, five host
guards and installed SDK/helper/link audit pass. Actual two-input CSP observation
is pending; s233 remains the newest actual-qualified retained-interval run.
This samples two engine frames, not the intervening elapsed time. Next validate
the deployed execution, then complete time subdivision/backlog ownership,
conserved incident/head source and renderer leases/common optics. No new visible
game water, continuous performance or long-run memory claim; displayed s87.

## History s234 new immutable interval admission (2026-10-22)

See `RAINFX_S234_NEW_INTERVAL_ADMISSION.md`. The new private owner accepts a
second immutable input only after the prior four quarters finish. Full-grid
local integration preserves packed End/Mean and cumulative water/momentum
history across changed pose/acceleration/air/evaporation. Checkpoint re-arming
requires the exact prior completed token and zero old debt. The same87 canvases
execute518 draws/178 cache hits over eight quarters, with no extra GPU allocation.
Sixteen static cached passes persist; eleven input-dependent passes refresh.
Twenty exact copies, first-interval s233 parity, unfinished-debt GPU refusal,
eight lifecycle controls and1024 time carries pass existing budgets. Signed
raw-dt remainder is preserved; rejected inputs consume no time. Geometry/scale
changes require remap/reset and are refused. This stage is local only, with a
synthetic second input; s233 remains the newest actual-CSP-qualified path.
Next fresh main-app captures/actual multi-input execution and complete elapsed
time/subdivision/backlog admission, then incident/head sources and renderer
leases/common optics. No continuous throughput, FPS or visible-water adoption
is claimed. Displayed game water remains s87.

## History s233 retained private interval (2026-10-22)

See `RAINFX_S233_RETAINED_PRIVATE_INTERVAL.md`. One default-OFF owner carries
packed End/Mean, checkpoint and cumulative ledger through four quarters of one
captured represented dt. Full-grid local integration reaches zero retained debt;
nine exact state copies and a Mean-only bit-fault check pass. One fixed87-canvas
slot retains91.1928MiB logical texture data at4096 capacity. Four traversals use
267 actual draw submissions plus81 immutable-cache hits, with one SDK attempt
per callback and no per-quarter allocation. Twelve protocol cases, a dynamic
cache refusal, real panel mock and five host guards pass. Actual CSP frame1513
finishes4/4:267 accepted draws/81 cache hits, three reuses, four CPU-data releases
and zero quarantine. All four water/time receipts and input/pose identities
pass;0.016301155s represented time is fully consumed. Final film805.612122mm³,
cumulative evaporation0.011829mm³/runoff0.148078mm³ and mass residual
−0.0000660000mm³ satisfy the existing budget. One-quarter s232 actual admission
remains preserved. Next new engine
interval/context-generation ownership and raw-time remainder, then conserved
incident/head source and renderer leases/common optics. This is one controlled
20µm interval, not continuous runtime, full-frame temporal Mean or FPS evidence.
Displayed game water remains s87.

## History s232 actual-grid private physical interval (2026-10-22)

See `RAINFX_S232_PRIVATE_PHYSICAL_INTERVAL.md`. A default-OFF main-app panel
now submits actual visor geometry/context plus unchanged s163 conservative
transport through the s231 executor.84 software-GPU draws pass:20µm controlled
film805.772095→805.748413mm³, evaporation0.003739mm³,runoff0.019864mm³,
advanced0.004166603s and retained0.012499809s. Full-array CPU stock checks,
ledger/debt, exact seed fingerprints, one-bit fault and five status refusals pass.
Maximum bindings15; one fixed graph retains87.1614MiB logical texture data in
the local4096-capacity capture. It is a one-shot snapshot, not a real-time cost
or whole-app VRAM result. Actual CSP frame1538 completes1/1 and84/84 with zero
quarantine:805.772156→805.731567mm³, evaporation0.003107170mm³,
runoff0.037439175mm³; mass residual−0.0000420341mm³ fits the existing budget.
Exact input/pose identities and0.004257441s advanced/0.012772322s retained
time pass. This qualifies one private quarter interval only. Natural
birth/head evolution, persistent interval/clock ownership and renderer access
are not yet connected; displayed game water remains s87. Next persistent
private intervals, conserved incident/head source, then common optics and
same-scene frame-ms/warm-memory/continuity assessment.

## History s231 private execution boundary (2026-10-22)

See `RAINFX_S231_PRIVATE_EXECUTION_BOUNDARY.md`. The default-OFF main-app
packet-echo executor passes actual CSP observation:16 completed/48 draws,
14 reuses, six canvases,16 CPU-data releases and no quarantine. Two private
slots allocate640 logical texture bytes, excluding GPU objects/driver overhead.
Local pending/error/cancellation, stale receipt, duplicate callback, graph and
host checks pass;48 software-GPU draws validate the three shader bodies.
The exact tested sources are preserved. A subsequent explicit-false binding
fix passes local checks; that unused branch has no new actual CSP observation.
Private status-tail receipt qualifies only this owned graph's reuse. General
GPU completion, persistent water-bank/clock publication and renderer leases
remain open. Next connect real physical inputs and a bounded private water
interval, then recurrent state and common optics. Avoid further toy expansion.
No FPS/whole-pipeline memory claim; existing game water physics remains s87.

## History s230 CPU partition and priority review (2026-10-22)

See `RAINFX_S230_CPU_PARTITION_REVIEW.md`. Four preplanned event/sleep plain/meter
prefixes pass s229 admission and original state/stock/time/lease/cap contracts;
all diagnostic archives are also bit-exact, with zero new warnings. One retained
metric GPU-bit control is strictly refused before failed-frame publication.
Nested self cycles cover95.1–96.3% of the measured caller window. Validation,
readback CPU and selected diagnostic output account for67.7–69.8%;metadata is
10.4–11.2%,resource API6.4–6.9%. These are instrumented native caller-cycle shares,
not GPU/game CPU cost or removable percentages. Each condition has one observation;
no speedup/overhead causality,percentile or event default decision follows.
Next implement the safe CSP preview boundary: retain completion/lease/publication,
small status/budget and invalid-cache guards while separating deep full-image
readback/proof/archive diagnostics. Do not optimize the diagnostic runner as if
it were the final game model. Main/game physics remain s87 and no user test is
requested. This is a profiling-path pass, not a performance optimization pass.

## Current policy s229 product acceptance v1 (2026-10-22)

See `RAINFX_GAME_ACCEPTANCE_POLICY.md`. User requests severity-based evaluation
against the final game goal. New work separates exact safety/identity/copy
contracts, scoped numerical/visual budgets, measured optimization benefit and
actual game release evidence. Blanket bit equality for recalculated intermediate
floats and blocking all work on the s223 diagnostic were disproportionate.
Saved s223 drift is confined to five impulse/wall words, up to0.0002873% relative,
with other archived states/final bank/time unchanged over0.152 simulated seconds.
It fits the existing s203 ledger bound and now permits profiling with a warning;
old strict refusal/cause uncertainty remain. No long-run/render/performance pass
is inferred. s208 has no failed values to quantify; retain its cache-publication
guard or verified fallback, without blocking unrelated development.
Initial game targets include same-scene frame ms, subpixel optimization differences,
event/closed-water budgets and warm stability; numbers are project budgets pending
CSP A/B validation.64MiB is a scoped planning target, not universal total VRAM.
End repetitive toy expansion; measure major CPU costs and plan the minimal safe
CSP preview. s222 remains the last passed cost comparison; game physics is s87.
This policy supersedes prior blanket development blockers prospectively; historical
tools, source hashes, old failures and release evidence are preserved.

## History s228 compensated-reduction replay (2026-10-22)

See `RAINFX_S228_REDUCTION_REPLAY.md`. Six fresh GPU processes pass192 small
reduction repetitions and384 exact output checks for captured, cancellation and
invalid-packet inputs across both completion policies. Pre/post inputs retain
bits; known compensation results differ from plain sums in10 banks. Two SHA
receipt controls refuse before GPU-owner creation and two output-bit controls
stop at iteration0. Logical default/staging payloads are1952/1280 bytes,
excluding other objects/driver overhead. No physical interval or timing benefit
is qualified. The original s223 cause remains unresolved; more identical
prefix repetitions or indefinite toy expansion are not the next step. Prepare
bounded exclusive CPU-partition admission against s222, retaining the original
exact gate and first-refusal evidence, before drawing a new bottleneck conclusion.
s222 is still the last passed cost comparison; release/physical/optics/live CSP
and long-run gates remain open. Game physics remains s87; no user test needed.

## History s227 ordered lifetime observations (2026-10-22)

See `RAINFX_S227_ORDERED_LIFETIME.md`. One event and one sleep observation pass
the original exact prefix gates and six new relations. Donor/recipient/decision
bytes and native owner identities remain unchanged from production to combine;
last donor/recipient compensated reductions match ordered FP32 CPU expectations.
All ten images match across observations. Static target backing lifetimes have
no declared overlap/intervening graph write; that is not general runtime proof.
Ten copies use1888 logical staging bytes and the original completion; no added
draw/query/fence. The original s223 cause remains unresolved and the observation
can change timing. Next replay the two upstream reductions with frozen inputs
and bounded cancellation/guard/fault controls, avoiding more full-prefix repeats.
s222 remains the last passed cost comparison; game physics remains s87.

## History s226 immutable arithmetic replay (2026-10-22)

See `RAINFX_S226_IMMUTABLE_REPLAY.md`. Eight fresh GPU processes pass256 small
arithmetic repetitions and768 exact output comparisons across both completion
policies and four readiness cases. Frozen inputs also pass pre/post byte checks.
Two SHA receipt controls refuse before GPU owner creation; one output-bit fault
stops at its first iteration. A receipt-name collision prevented that control's
initial launch; a distinct receipt completes it with no native retry. The original
report/source manifests remain preserved. Logical default/staging payloads are
1120/384 bytes, excluding object/driver overhead. No physical solver interval,
clock/publication, performance comparison or live CSP integration is qualified.
The original s223 inputs were not captured and its cause remains unresolved.
Next trace upstream donor/recipient production and backing reuse, then add one
bounded ownership control under the original exact gate. s222 remains the last
passed cost comparison; game physics remains s87. No user game test is needed.

## History s225 addition/commit/terminal capture (2026-10-22)

See `RAINFX_S225_LEDGER_CHAIN.md`. Four planned event/sleep/sleep/event runs pass
independent FP32 addition and bit-copy checks at1421/1422/1425, plus original
exact archive/bank/stock/clock/debt/lease/cap gates. All eight captured resources
are identical across runs; the original s223 difference does not reproduce.
Eight copies add624 logical staging bytes, using the existing phase completion.
No root cause, fix, general resource safety or performance benefit is claimed.
Next use immutable captured inputs in a small bounded GPU arithmetic replay,
with independent expectations and refusal controls, instead of more full-prefix
repetition. Original refusal/acceptance criteria remain preserved. Game is s87.

## History s224 targeted producer capture (2026-10-22)

See `RAINFX_S224_PRODUCER_CAPTURE.md`. Four event/sleep/sleep/event captures
match actual inputs, the source-relation check and original exact prefix gates.
The s223 difference does not reproduce; no fix or general cause is established.
Each capture adds four ordered copies and320 logical staging bytes, using the
same completion event. No performance comparison or default adoption follows.
Source tracing narrows the next target to ledger1421: donor1402 + recipient1420
on the same rows4/5 that differed. Next capture those inputs/readiness/output,
extending total logical staging to624 bytes, with the original failure and
numeric gate preserved. A Python default-argument correction reuses the first
GPU observation; it does not repeat it. No game/default change; physics is s87.

## History s223 partition candidate — exact gate refused (2026-10-22)

See `RAINFX_S223_CPU_PARTITION.md`. Nested exclusive scopes compile and CPU-only
controls pass, but the corrected physical batch stops after one passed sleep
prefix and one externally refused event prefix. Five archived intermediate
step-ledger words differ at f5/flow/39, attempt22, resource1425. Final bank,
stock packets/published ledgers and retained metric witnesses match; no tolerance
is relaxed. Native completion is not an in-solver quarantine. No measured
partition or injected-fault trial ran; six natural cases remain unstarted.
The initial numeric stage-renaming error was separately refused before device
creation and preserved. s222 remains the last passed cost comparison.
Next capture actual inputs/output of that producer with bounded lifetime/cap
guards before resuming broad performance work. No game/default change.

## History s222 calling-thread cycle attribution (2026-10-22)

See `RAINFX_S222_CALLER_CYCLES.md`. Eight mirrored prefixes and the separate
healthy/bit-fault batch pass original output/stock/clock/debt/lease/cap gates.
Cycle sampling resolves all three measured categories without converting cycles
to seconds. Submission wrappers account for5.2–5.6%, waits0.5–1.2%, and timestamp
resolution0.5–0.9%;92.4–93.8% remains outside those scopes. CPU-only scope cost
is about1299–1302 cycles per operation in the fixture. Event plain wall is1.018s
versus sleep3.958s, two samples each, not a full/default/game qualification.
Next partition the remainder: allocations/setup, readback/CPU validation and
owner/packet bookkeeping, with an explicit remainder and plain/measured control.
No solver, GPU-command or completion-predicate change. Full event cost, natural
s208 cause/release, physical/optical accuracy and CSP/live remain open.

## History s221 caller CPU bucket controls (2026-10-21)

See `RAINFX_S221_CALLER_CPU_BUCKETS.md`. Eight mirrored prefixes and a separate
healthy/fault batch pass unchanged bank/stock/clock/debt/cap/query gates.
CPU-only added thread-counter scopes cost about261–283ns each in the fixture.
Short physical scopes expose coarse GetThreadTimes attribution: zero samples
and CPU sums exceeding the same scopes' wall sums. No literal short-function
CPU attribution or default-policy decision is justified. Event plain prefix
wall is1.052s versus sleep4.102s; caller CPU is0.539s versus0.508s, two samples
each, not a full-workload or game result. Preserve the first pre-device input
admission failure; supplying the omitted frozen bindings table enables a
separate corrected batch. Next evaluate caller cycles with CPU-only and
plain/measured controls, keeping whole-window CPU and all completion guards.
Full event cost, s208 natural cause/release, physical/optical accuracy and
CSP/live integration remain open. Game physics remains s87; no user test needed.

## History s220 recorder CPU and fixed-settle controls (2026-10-21)

See `RAINFX_S220_RECORDER_SETTLE_CONTROLS.md`. CPU-only replay of the frozen
recorder adds0.015–0.023ms per245 wait/submission pairs in the tested fixtures.
Eight mirrored physical conditions and the separate first-refusal batch pass;
startup/pause/physical/cleanup CPU reconcile exactly to whole-process totals.
The fixed2s pause records no CPU shift at counter resolution and does not reduce
physical/whole-process CPU; it is not a product optimization. The prior large
non-caller CPU signature is not reproduced, and policy CPU means still vary.
Initial admission refuses a changed boot LUID; original evidence is retained.
Four two-pose debug/release full-byte rebuilds, two bit faults and stale-LUID /
wrong-driver controls revalidate geometry for fresh current-boot bindings.
A negative-control input/output-path defect is preserved and corrected without
repeating healthy rebuilds. Next partition caller CPU in submit/wait/timestamp
resolution, with plain/instrumented and CPU-only read controls. Use the current
qualification and retain all parity/cost/identity gates. No default/game change;
full/stop/fault cost, s208 cause/release, accuracy/optics/long duration/total CPU
and CSP/live remain open. No user game action is needed.

## History s219 calling-thread CPU and bounded tails (2026-10-21)

See `RAINFX_S219_CALLER_CPU_ATTRIBUTION.md`. Fixed caller/process boundaries
and top-eight wait/submission records pass original parity in eight mirrored
natural trials and the expected first-refusal batch. Both halves contain all
four plain/traced sleep/event conditions. Mean process-minus-caller CPU falls
1.957→0.055s between halves while caller CPU changes0.586→0.516s: a strong
order-associated observation across policies, not an identified driver cause.
Recorder CPU overhead cannot be isolated from these samples; CPU policy ratios
also differ plain/traced. All wait slices complete without the s218 timeout
pattern, which is not proved fixed. Keep original owner and hold full comparison.
Next characterize recorder CPU without GPU work and use bounded no-settle /
fixed2s pre-physical-pause controls with startup/pause/physical/whole-process CPU
accounted. A pause is diagnostic, not an optimization or omitted CPU cost.
Original s208 cause/release, full/stop/fault cost gates, accuracy/optics/long
duration/total CPU and CSP/live remain open. No user game test is needed.

## History s218 event-wakeup physical prefix (2026-10-21)

See `RAINFX_S218_EVENT_PHYSICAL_PREFIX.md`. Separate sleep/event prefix builds
preserve exact frozen nine-interval output, stock, time, three queued contexts,
cap and first-refusal behavior. Four ABBA cost trials plus a separate successful
event/control/refused-third batch yield five healthy prefixes. Mean physical
wall7.481→4.917s, but process CPU in that window0.617→1.711s; the first event
process is variable and has19 finite wait-slice timeouts before all completions.
All submitted queries still complete, one handle closes per event consumer,
and no wake replaces GetData/device authority. Cost gate fails: hold full256
event comparison. Next add fixed calling-thread/process CPU snapshots and
bounded wait/submission tails, with traced/untraced observer comparison.
Original owner/game are unchanged. Full/protected-stop/fault gates, s208
cause/release, total CPU/startup, accuracy/optics/long duration and CSP/live
remain open. No user game test is needed.

## History s217 private native event wakeup (2026-10-21)

See `RAINFX_S217_NATIVE_EVENT_WAKEUP.md`. A separate immutable-copy process
compares original sleep, counted/spaced pacing and EnqueueSetEvent notification.
Final revision2 passes7,020 full-byte copies, five admission and three completed
payload fault controls. Initial revision1 evidence is retained; revision2 fixes
unresolved notification-handle lifetime and repeats the experiment. Mean whole
8MiB-copy wall15.929→5.936ms; every size improves in both final processes, and
the predeclared small aggregate process-CPU gate passes. This allows a private
nine-interval owner-prefix comparison only. EnqueueSetEvent implicitly flushes;
successful GetData/readiness, device status and deadlines remain read authority.
Then full256/protected-stop/fault cost and correctness gates precede selection.
The original owner default/game are unchanged. Original s208 cause/release,
total CPU/startup, accuracy/common optics/long duration and CSP/live remain open.
No user game test is needed.

## History s216 full paced gates and physical CPU windows (2026-10-21)

See `RAINFX_S216_FULL_PACED_GATES.md`. Separate full256 sleep/paced executions,
protected26/29 stop and three CPU/GPU/shared-selection fault controls preserve
original bank/stock/clock/debt/cap evidence. Two native CPU snapshots exclude
startup from the physical window. The single full observation per policy gives
wall146.68→211.67s and CPU15.42→19.23s, reversing the prefix benefit; reject this
candidate for default selection. GPU interval sums also differ, so this does not
isolate a driver/OS/GPU cause. An erroneous wrapper stock-row count stopped the
initial plan; the original stop oracle validates the preserved extra checkpoint.
Initial evidence remains sealed, and only unstarted controls ran after correction.
Next test an isolated native event-wakeup alternative, declaring its flush behavior
and retaining GetData success/readiness plus device/error/timeout guards before
any subsequent owner experiment. Owner default/game remain unchanged. Natural
s208 cause/release qualification, physical accuracy/total CPU/common optics/long
duration and actual CSP/live gates remain open. No user game test is needed.

## History s215 opt-in paced physical prefix (2026-10-21)

See `RAINFX_S215_PACED_PHYSICAL_PREFIX.md`. The candidate is connected only to
separate native prefix builds. Four sequential sleep/paced/paced/sleep trials
preserve all original nine-interval outputs, stocks, clock, cap and three queued
unstarted contexts. Physical-run wall mean4.21→1.89s; whole-process16.98→14.31s.
Startup/driver CPU varies too much for a CPU-saving conclusion. A separate
paced/fault/paced batch stops at the injected frame7 retained-GPU mismatch,
preserving preceding publications/debt and leaving the third trial unstarted.
Next keep opt-in and run full256, protected26/29-stop and fault/control gates;
add physical-window CPU snapshots beside whole-process CPU. No owner default,
shader or game change; production remains s87. The s208 natural cause/release
qualification, accuracy/total CPU/common optics/long duration and CSP/live gates
remain open. No user game test is needed.

## History s214 counted/spaced completion candidate (2026-10-21)

See `RAINFX_S214_COUNTED_PACED_COMPLETION.md`. A private candidate uses a64-query
burst,50µs spacing,80-query/1ms fast phase then the existing1ms sleep fallback.
6,240 full-byte copy checks, completion/refusal/selector guards and exact traced
partitions pass. All measured fast phases respect80 queries; large observed
GetData maxima fall14.43→0.160ms.8MiB plain whole-copy mean improves14.43→5.58ms
in both plain processes, but small means and some p95/maximum waits regress.
Next evaluate a separate opt-in nine-interval native physical prefix against
the unchanged owner sleep policy, retaining bank/stock/time/queued debt/cap/
first-refusal witnesses and CPU/wall measurement. Stop on any discrepancy;
full/protected-stop/control gates follow before owner adoption. No synthetic
copy-to-game timing inference, global timer change or selected global policy.
Original s208 cause/release qualification, accuracy/total CPU/common optics/
long duration and CSP/live adoption remain open. No user game test is needed.

## History s213 completion-call wall attribution (2026-10-21)

See `RAINFX_S213_COMPLETION_CALL_ATTRIBUTION.md`. Four sequential plain/trace/
trace/plain processes compare observer effects and retain exact integer wait
partitions plus four longest calls per stage/block.6,240 complete-copy byte gates
and provenance/payload refusals pass.8MiB candidate wait is97.76% inside GetData
call envelopes; all32 retained longest GetData records are poll1004,13.60–14.70ms,
returning S_OK/TRUE. This locates host wall delay, not a driver/GPU/OS root cause.
Trace changes small-copy cadence substantially; no negative-overhead correction
or direct game timing claim. Next compare a bounded initial query burst and
spaced polls on a private stream, preserving exact completion/timeout/one-Flush/
byte gates and plain/trace comparisons before owner adoption. s211 full/prefix/
protected-stop/witness gates, original s208 cause, accuracy/common optics/total
CPU/long duration and CSP/live adoption remain open. No user game test is needed.

## History s212 immutable-copy completion-wait cost (2026-10-21)

See `RAINFX_S212_IMMUTABLE_WAIT_COST.md`. Two sequential private processes compare
sleep1ms with150µs polling/1ms yield-budget/fallback sleep, using unchanged
S_OK+TRUE completion and30s deadline guards.6,192 full-byte successful copies,
seven predicate controls and four provenance/payload refusals pass.16KiB/256KiB
wall cost drops from15.10/15.32ms to0.0635/0.5309ms per copy.8MiB varies between
processes, with aggregate15.60→14.77ms and CPU1.80→2.15ms per copy. The candidate
is not adopted. Large-copy wait is mostly outside explicit sleep; next isolate
GetData duration, scheduling gaps, yield and copy/Map/compare in a separate bounded
immutable experiment before selecting any physical-owner policy change. Preserve
s212 uninstrumented evidence and s211 full/prefix/stop/witness gates. Original
s208 cause/release qualification, accuracy, common optics, total CPU and live/CSP
adoption remain open; no game/FPS claim or user test is required now.

## History s211 bounded target-window trials (2026-10-21)

See `RAINFX_S211_BOUNDED_REPRODUCTION_TRIALS.md`. Four independent fresh-process
prefix trials each publish9 intervals and retain12 accepted, with all3 unstarted
future intervals explicitly queued. Their final banks and original stock/GPU
prefixes match. A controlled second-trial GPU discrepancy preserves its first
witness/capture and stops the batch before the planned third trial. Full256 and
26/29 stop gates remain unchanged with the prefix switch off. No natural s208
recurrence, root cause or release qualification is established. Reproduction is
ready; independently characterize immutable-stream completion waits as a
non-adopted experiment, retaining exact guards and full/prefix/stop/witness gates
before later adoption. Native process overlap is recorded; no isolated timing,
long-warm-run, FPS or CSP/live claim. Accuracy/total CPU/common optics remain open.

## History s210 retained-metric/reference/shared witnesses (2026-10-21)

See `RAINFX_S210_RETAINED_METRIC_WITNESSES.md`.21 bounded observations cover the
frame7 validated cache,17 physical pairs,stock pair,frame8 configuration and
cache comparison.36 extra metric copies complete under existing events; full
and stopped counts remain7,085/725 with legacy mandatory reads unchanged. Full
hardware256-interval byte/state/stock/time parity and protected26/29 stop pass.
CPU-expected,retained-GPU and shared-selection controls fail at their first
affected row and preserve previous publications/debt. The natural s208 mismatch
does not recur; root cause and release recurrence qualification remain open.
Next use bounded repeated target-window trials with these validated witnesses
before selecting a repair. Scoped diagnostic payload bounds do not prove total
application memory; timing is perturbed. No wait-policy/shader change or game/FPS
adoption. Accuracy,long duration,common optics and CSP completion remain open.

## History s209 cache-refusal capture qualification (2026-10-21)

See `RAINFX_S209_CACHE_REFUSAL_CAPTURE.md`. Corrected refusal-only capture separates
CPU result and retained GPU-cache one-bit controls using three staging rereads
and fresh post-refusal GPU copies; exact guards refuse both before publication.
Four native full runs (two preliminary release, AddressSanitizer and capture v2)
retain all parent GPU/state/stock/time bits and47,400 inventory snapshots; the v2
26/29 forced stop preserves the bank and debt. No natural s208 refusal recurs and
the sanitizer reports no finding, which does not establish general memory safety
or release recurrence qualification. Frozen frame7/8 contexts and370 original
inventory snapshots narrow the missing interval to retained metric/reference/
readback between frame7 validation and frame8 comparison. Next add bounded
per-phase witnesses there before claiming a cause or choosing a repair. Wait
optimization, physical accuracy, long duration and CSP/live/FPS gates remain open.

## History s208 explicit hardware operation profile (2026-10-21)

See `RAINFX_S208_HARDWARE_OPERATION_PROFILE.md`. Explicit draw/transfer/allocation/
readback/poll/sleep instrumentation retains debug hardware 256-interval full-byte
state/stock/time parity, 11,850 inventory snapshots and protected 26/29 stop.
No solver/shader/wait changes or added completion events. Recurrent debug wall
123.3614 s includes113.2099 s in requested1 ms sleeps (mean14.2277 ms); newly
measured adaptive-bound GPU intervals total11.0862 s. CPU/GPU times overlap.
Startup input decode/validation/hash takes10.8105 s in this native fixture.
Initial release recurrence refuses the exact new-cache metric guard at frame8;
a separate failure-capture executable subsequently passes complete parity, so
the failure is retained and release recurrence qualification remains open.
Next isolate that refusal before release timing comparisons, then evaluate a
bounded wait policy and the measured bound-shader cost. Whole-process CPU/driver
coverage, physical accuracy, long duration and CSP/live/FPS gates remain open.

## History s207 full hardware physical admission (2026-10-21)

See `RAINFX_S207_HARDWARE_PHYSICAL_ADMISSION.md`. A new consumer-bound v2 receipt
connects qualified two-pose geometry references to the full native hardware owner.
The initial source refusal is diagnosed to 40 duplicate old-packet momentum bit
disagreements. Explicit precise arithmetic and exact zero-debit identity candidates
retain the original predicates. Hardware shadow/reuse now publish all 256 intervals
and 4.320556640625 s with full state/stock/time and 11,850 inventory-snapshot parity.
Eight adaptive refusals recover; the 26-published/29-accepted budget stop protects
the prior bank and debt. The 66,582,496 B scoped texture peak remains under cap;
all counted textures retire. Three v2 provenance faults refuse. Next complete
profiling coverage, then choose measured optimization. This is offline hardware,
not CSP/live/FPS qualification; physical accuracy and long duration remain open.

## History s206 qualified backend geometry references (2026-10-21)

See `RAINFX_S206_BACKEND_REFERENCE_QUALIFICATION.md`. Both frozen poses pass
independent full-field CPU geometry/Gram/area/support qualification. Immutable
receipts bind complete program inputs, reference images, cache shaders, native
executable and adapter/driver. Four debug/release native cache rebuilds match
all ten proof images in full bytes; two one-bit GPU faults, eight provenance
faults and twenty invalid CPU qualification cases are refused. This standalone
cache consumer publishes no water bank or solver time. Next explicitly bind
the qualified references to the full physical consumer, retain exact same-backend
checks and verify hardware 256-interval/forced-stop state and debt parity before
integrated cost. No new shader, game writes, FPS claim, commit or push.

## History s205 hardware preflight and isolated transfer cost (2026-10-21)

See `RAINFX_S205_HARDWARE_PREFLIGHT.md`. Adapter 0 is an RTX 3070 with FP64.
Hardware exact-byte controls and an isolated 8 MiB A/B/B/A duplicate-copy/read
experiment pass. Full physical hardware timing is refused at bootstrap: 30/640
WARP-reference atlas words differ, derived from 52,937 changed packed metric
words (maximum absolute error 1.1920928955078125e-7). Immutable inputs, cells,
header, areas and runs match complete bytes; debug/release outputs match.
Independent float64 full-field transformation/Gram/area diagnostics pass the
existing numerical bounds, but the exact reference predicate is not waived.
No physical intervals or solver clock are published in these hardware runs.
Next qualify both pose-dependent backend references, retain exact same-backend
rebuild predicates, then verify 256-interval/stop parity before integrated cost.
Component timings are instrumented observations, not a pipeline or FPS claim.
Production/main/game remain unchanged; no user game test or commit/push.

## History s204 exact cache snapshot reuse (2026-10-21)

Identical live metric sources at one post-build write epoch/lease reuse their
complete staging snapshot and CPU bytes.143 of271 preparations remove1.200GB
of duplicate read results and staging copies;cache reads6.821GB to5.621GB.
Complete before/after and expected-image byte predicates remain.10 guard
controls,six GPU-copy/corruption cases,shadow/reuse256-interval runs and the
protected stop pass. Physical/stock/control bits,time debt and typed occupancy
match s203;no additional draws,uploads or default textures. A general streamed
GPU comparator is not adopted because reference transfer/storage must also be
budgeted. Next measure target hardware execution/transfer categories before a
larger rewrite. Target FP64/cost,CSP scheduling/completion,total CPU/provider,
long-duration/live weather,physical/time accuracy,common optics and live adoption
remain open. Production s87/diagnostics s89;no game writes or user game test.
See `RAINFX_S204_CACHE_SNAPSHOT_REUSE.md`.

## History s203 compact stock validation (2026-10-21)

A complete tiled FP64 reduction replaces full stock-image reads,with explicit
finite/nonnegative checks,conservative addition-order error intervals and the
original full-image predicate for ambiguous boundaries.25 component cases and
1091 independently reconstructed GPU groups pass. Shadow and compact256-interval
runs retain physical bank/control bits,ledger/checkpoints,owner/recovery/phase/
index traces and exact debt. A forced stop still preserves26 published/29 accepted
intervals. Stock read payload2.164GB to1.626MB;one extra validation draw per check
and6192B temporary UINT scratch yield a66,582,496B scoped peak(2080B cap margin),
with complete teardown. No full-image fallback occurs in the integrated clean
runs;four adversarial component cases exercise it. Target FP64/hardware timing
and real CSP cadence remain unverified. Next compact6.821GB of cache validation
reads against full-reference and corrupt/stale/held/failure cases under the cap.
Total CPU/provider streaming,long-duration/live weather,physical/time accuracy,
common optics and live adoption remain open. Production s87/diagnostics s89;
no game writes or user game test.
See `RAINFX_S203_COMPACT_STOCK_VALIDATION.md`.

## History s202 diagnostic capture policy and read accounting (2026-10-20)

Full and controls-only archives complete the same256 intervals and preserve
final bank bits,owner/stock/recovery/phase/index traces,normalized inventory,water/time
and scoped ownership caps. A new forced-stop control retains the prior26-bank
publication and three intervals of accepted debt. Optional archive reads fall
from1.976GB to0.443MB;required validation reads remain9.044GB,primarily cache
6.821GB and stock2.164GB. Both sequential WARP/debug wall observations are near
192s,so an end-to-end speedup is not established. CPU text traces and required
full-image checks remain enabled. Next compact required validation payload with
the full reference and failure cases under the retention cap;keep acceptance,
completion and exact water/time guards. Hardware cost,total CPU/provider/startup
streaming,true long-duration/live-weather,CSP scheduling/completion,physical/time
accuracy,common optics and live adoption remain open. Production s87/diagnostics
s89;no game writes or user game test for this stage.
See `RAINFX_S202_DIAGNOSTIC_CAPTURE_POLICY.md`.

## History s201 controlled extended recurrence (2026-10-20)

The same bounded native owner completes256 contiguous controlled intervals,
publishing exactly4.320556640625s with zero remaining time debt. Seven numerical
refusals(including four beyond the first64)recover under unchanged thresholds
and attempt limits. First64 GPU/input bytes and stock/recovery/phase traces
match;1.484GB is compared. Named recurring metadata caps and63.492905MiB scoped
default-texture peak stay equal;4,702 created generations release completely.
This remains a short four-context offline fixture. True long-duration/live-
weather stability,total CPU/provider/startup streaming,target timing and actual
CSP scheduling/completion remain open. Next separate diagnostic readback/file
work from the native cost path while retaining numerical,completion and exact
water/time guards,then establish hardware cost. Physical/time accuracy,common
optics and live adoption remain open. Production s87/diagnostics s89;no game
writes or user game test for this stage.
See `RAINFX_S201_EXTENDED_RECURRENCE.md`.

## History s200 bounded recurring history (2026-10-20)

Acceptance uses one current counter;object-local diagnostic IDs remove expired
weak-key history. Five immutable audit patterns(518 normalized roles)and8 decision
prototypes reproduce all2314/512 original selectors without whole-run sets.
The full64-interval run and newly executed forced one-attempt-budget stop retain
reference physical/GPU/index and publication/debt traces;2.167GB of GPU bits match.
The stop preserves26 published/29 accepted intervals and3 intervals of debt.
Named recurring metadata caps now pass;total CPU streaming remains open because
startup proof summaries and offline/provider artifacts still scale. GPU work and
63.492905MiB peak stay equal. Next extend continuous recurrence beyond64 intervals
with these caps and report any new numerical/budget refusal,then target timing
with diagnostic reads separated. Actual CSP scheduling/completion,physical/time
accuracy and common optics/live adoption remain open. Production s87/diagnostics
s89;no game writes or user game test for this stage.
See `RAINFX_S200_BOUNDED_HISTORY.md`.

## History s199 bounded resource descriptions (2026-10-20)

Native resource metadata now uses523 immutable prototypes plus a maximum523-
description current/previous/bootstrap cache instead of16085 retained logical
descriptions. Typed-shape entries peak109 instead of1037. Live pool objects
retain their current occupant's original last-use event,so retirement does not
need expired descriptor windows. Every original descriptor/read/assignment,
all64 physical/GPU/index results and225553 recorded last-use/type checks match.
Four invalid frame/old/future/domain lookups refuse. GPU work/churn and63.492905MiB
peak stay equal. Total CPU streaming remains open:fixed-run acceptance/audit/
identity history and transient complete-proof summaries still scale. Next bound
that history and extend continuous recurrence,then target timing with reads
separated. Actual CSP scheduling/completion,physical/time accuracy and common
optics/live adoption remain open. Production s87/diagnostics s89;no game writes.
See `RAINFX_S199_RESOURCE_WINDOWS.md`.

## History s198 phase/frame metadata templates (2026-10-20)

Two exact first/recurrent structures now derive phase boundaries,frame/bank IDs
and packet directory positions. The native owner retains17 active phase indexes
and7 upload keys,with34 immutable recipes instead of1088 bound indexes. Complete
64-interval stock/debt/owner/GPU/index evidence matches s197 bits.60 valid bank/
static/current bindings and4 invalid role/frame cases pass native CPU controls.
GPU work and63.492905MiB default-texture peak remain equal. The16085 logical
resource descriptors/1037 shapes and some audit/history metadata remain unrolled;
total bounded CPU streaming and longer recurrence are still open. Next reusable
resource templates with current/previous/live-occupant metadata,then longer
continuous execution and target timing with diagnostic reads separated. Real CSP
completion/cadence,physical/time accuracy and common optics/live adoption remain
open. Production stays s87,diagnostics s89;no user game test or installation.
See `RAINFX_S198_METADATA_TEMPLATES.md`.

## History s197 interval packet window (2026-10-20)

Native input/draw payloads now use one replaceable interval window and56 immutable
command schemas. Maximum input payload12,985,328B during initialization,133,888B
on subsequent intervals;at most235 instantiated commands instead of14977 held
together. Native complete-packet roundtrip and six parser refusal controls pass.
All64 physical banks,owner/debt traces,indexes and1.457GB retained GPU readbacks
match s196 bit for bit. GPU work/churn and63.492905MiB descriptor peak are equal.
This bounds active packet payloads,not total CPU memory:resource lifetimes,phase
indexes,frame/bank descriptors and directory still scale with the unrolled graph.
The offline packer is also not bounded. No longer-duration,target timing or game
loading improvement is claimed. Next reusable resource/phase/frame templates,
then longer continuous recurrence and allocation/target cost with reads separated.
Actual CSP scheduling/completion,physical accuracy gates and common optics/live
adoption remain open. Production remains s87,diagnostics s89. No user game test.
See `RAINFX_S197_PACKET_WINDOW.md`.

## History s196 indexed native dispatch (2026-10-20)

Immutable upload/reservation/role indexes replace repeated full-graph searches.
Independent exhaustive checks pass1088 phases/448 upload keys;all retained GPU
readbacks(1.457GB) and physical/debt traces match s195 exactly.64 intervals still
publish with unchanged GPU work,allocation counts and63.492905MiB peak. Runtime
upload dispatch replaces284M resource predicates with17668 lookups/1119 candidate
inputs;reservation replaces35M predicates with2176 lookups/87040 candidates.
These are work counts,not measured FPS gains. Metadata remains preloaded/unrolled;
next bounded reusable templates/input streaming,then longer continuous recurrence,
allocation/target cost and real CSP scheduling/completion/common optics.
See `RAINFX_S196_INDEXED_DISPATCH.md`.

## s195 bounded native owner recovery (2026-10-20)

The same64-interval sequence now completes in the counted owner:all64 banks and
1.08013916015625s publish,with3 refusals recovered and no repeated source water.
Native work pumps retain a persistent cursor and exact debt;observed49 draws
within a64-draw cap.4KiB+16B bound targets fit63.5MiB retention:observed peak
63.492905MiB,final0B. Forced attempt-limit1 preserves the previous bank/queue/
debt on refusal. Native64-interval physical gate passes. This is not a long-run
or actual CSP callback/timing result. Next longer recurrence,allocation/input
streaming and target cost before real CSP scheduling/completion and common optics.
See `RAINFX_S195_BOUNDED_OWNER_RECOVERY.md`.

## s194 isolated adaptive recovery (2026-10-20)

The s193 failed full-grid input reproduces exactly. A GPU shared-face contraction/
dry-gap ordering bound matches independent Float64 evaluation. Nine accepted
substeps recover all786432 remaining ticks without reapplying birth/source/trail;
water/momentum and exact debt pass. This is an isolated native replay,not the
counted joint owner. Next integrate retry leases,queue and callback work limits,
reuse/retire scratch for the16400B bound outputs,then rerun64 intervals. The
64-interval,CSP,long-duration,target timing and common optics gates remain open.
See `RAINFX_S194_ADAPTIVE_TRANSPORT_RECOVERY.md`.

## s193 recurrent stream refusal (2026-10-20)

Actual4096-head/1024x256-field stream commits26 intervals with repeated cache
changes and a bounded three-request queue. Interval27 quarter2(Y) refuses at
4.219ms:three proposed donor widths are negative in Float64. This is a real
step-validity failure;the64-interval recurrence gate FAILS. The owner quarantines
refusal,keeps the previous published bank and0.050631523s accepted debt,then
releases all diagnostic GPU ownership explicitly. Full stock/ledger sums on
every published interval and sampled force/source/quarter checks pass. Observed
peak63.488983MiB;debug warnings0. Next adaptive shared-face/support time bounds
and exact-debt recovery under a work budget. Long-duration,CSP,target cost and
common optics remain open. Main/game unchanged,no user test.
See `RAINFX_S193_RECURRENT_STREAM_REFUSAL.md`.

## s192 physical cache refresh (2026-10-20)

Actual4096-head/1024x256-field execution now changes context between two
intervals. Controlled forcing-only and90-degree rigid-yaw cases both publish
physical bank/time after cache failure/discard/retry and old-reader return.
Complete cache bit/reference comparisons,independent source/world-force audits,
eight transport quarter closures and dynamic ownership inventories pass.
16 negative packets refuse before device creation. Peak63.488983MiB;final0B;
no debug warnings. The legacy first-frame UV-component miss remains reported.
Native controlled-refresh64MiB gate passes. This is not a live weather replay
or long-run test;CSP completion,target timing,arbitrary scale/assets and common
optics remain open. Next longer recurrent streams with bounded backlog and
generation retirement. Main/game unchanged,no user test.
See `RAINFX_S192_PHYSICAL_CACHE_REFRESH.md`.

## s191 full-size native physical owner (2026-10-20)

Actual birth/SI head/source-cell/source/transport shaders replace the canaries.
4096 heads and1024x256 field execute two fixed-context intervals;the second
consumes retained first-frame GPU inventory. Native bank/time publication,
failure/retry,reader protection and capacity refusal pass. One controlled RNG
seed admits42.85897446mm3 of incident water;the zero-arrival control also passes.
Independent complete source and physical-world force checks plus eight quarter
closure checks pass. A legacy per-component UV criterion fails one small
component;physical world error is at most1.102e-8m/s and the failed diagnostic
is retained. Peak63.488190MiB;final counted ownership0B. The native fixed-context
physical64MiB gate passes. Next add pose/weather cache refresh with bounded
overlap and preserved debt,then long recurrent runs;CSP completion,target cost
and common optics remain open. Main/game unchanged,no user test.
See `RAINFX_S191_FULL_SIZE_PHYSICAL_OWNER.md`.

## s190 full-size native allocations (2026-10-20)

The complete two-frame warm lifetime plan now allocates actual D3D textures
with the seven real bootstrap cache/geometry objects moved into the same owner.
35 phases stay at or below63.5MiB retention;the combined cold/warm peak is
63.488190MiB,leaving536,672B to64MiB.107 generations include7 adopted inputs;
29 are retired and final counted ownership reaches0B.2,890 three-texel reads,
retry/quarantine,old-object reader and whole-batch refusal checks pass. Seven
bad schedules refuse before device creation. A concurrent8.125MiB geometry
revision at the high frontier also refuses. Warm outputs are diagnostic
canaries;source/head/transport physics,water stock and solver clock are not
executed/published. The physical64MiB,CSP,timing,optics and long-run gates stay
open. Next replace canaries with the physical graph using the tested allocations.
Main/game unchanged,no user test.
See `RAINFX_S190_FULL_SIZE_NATIVE_ALLOCATION.md`.

## s189 owned native packed geometry (2026-10-20)

Private native cache uploads index/packed table directly;old table49 has no
allocation or binding.83 recurring cache/preview draws retain every logical
output and pass four force oracles. Nine malformed inputs refuse before device
creation. Frame leases require both geometry inputs together. A separate paired
rebuild on the same context/counter verifies initial upload,completed validation
failure/quarantine/discard,new-ID retry,old readers and8.125MiB whole-pair
retirement;it adds4 events and0 draws. Total83 draws/17 events. Peak49.502457MiB,
retained25.500793MiB and audit staging each improve608KiB over s184. No leaked
revision/reader remains in the bounded scenario. Same asset content only;
arbitrary hot asset replacement is unverified. No water stock/solver time is
published. Next compose complete actual-grid physical ownership with cold and
overlap accounting;full64MiB,CSP,timing and optics adoption remain open.
Main/game unchanged,no user test.
See `RAINFX_S189_OWNED_GEOMETRY_INPUT_GENERATIONS.md`.

## s188 exact static geometry words (2026-10-20)

The audited reference/installed SDKs document one canvas output,no verified MRT
or compute route. This is a capability gate,not proof undocumented support is
impossible. A two-single-target descriptor alternative adds32 draws,keeps the
same phase floor and increases permanent reservation8MiB;reject without GPU
implementation. Instead pack integer du.w/binary dv.w into one exact tag word
beside six unchanged FP32 xyz words. Two1024×151 tables become1024×264,saving
622,592B and reducing geometry bindings3→2.119 standalone WARP draws match all
geometry bits and10 birth/head graphs. The523-resource proposal preserves all
18 physical/source-cell last readers and original completion boundaries.
Phase floor66,476,880B;modeled63.5MiB retention peaks66,572,192B,536,672B under
the original64MiB budget. Creates111→107 and cumulative creation bytes decrease.
Next implement retained-input generation upload/replacement/failure/retry/old
reader ownership before full joint composition. Target timing and CSP completion
remain unverified;main/game unchanged,no user test.
See `RAINFX_S188_GEOMETRY_WORDS_AND_OUTPUT_GATES.md`.

## s187 seven-word packet candidate (2026-10-20)

Share the equal FP32 volume bits of private End/Mean packets and densely retain
three Mean momentum words. Four1024×512 intermediates become1024×448,8→7MiB each.
Unsigned word moves preserve signed zero;logical bounds/extent and pre-device
grid guards pass.615 native recurring draws retain physical/bank/water/time
bits;153 actual-grid draws match all frozen roots and12 intermediate images;
10 codec draws pass. Independent phase floor falls2MiB to61.991043MiB. A63MiB
retention cap peaks62.807526MiB,but creates107,801,504B versus87,677,856B in the
old64MiB proposal. Permanent pool reservation also grows6MiB to75.807526MiB.
Tail packing raises logical producer evaluations2N→2.5N. Keep s185 default;
this exact candidate is not adopted and supplies no FPS claim. Next inspect
backend-supported paired output without repeated cell evaluation,then recompute
pool traffic. Main/game unchanged;no user game test. Full joint ownership,
CSP completion,timing and common optics remain open.
See `RAINFX_S187_SEVEN_WORD_PACKET_CANDIDATE.md`.

## s186 policy comparison and phase floor (2026-10-20)

Five warm policies pass the independent524-resource lifetime certificate,but
every alternative increases creation bytes and count. Keep s185 largest-first;
the selector rejects regressions in peak,creation bytes or creation count. Two
native615-draw/37-event experiments retain all physical/inventory bits,with
failure/retry/replay/old-reader protections. Best-fit adds two creates and reaches
the small224KiB cap. A victim-order-independent per-shape simultaneous-witness
proof establishes a67,099,472B/63.991043MiB minimum for the unchanged phase layout.
The maximum64MiB margin is9392B;eviction tuning cannot recover substantial room.
Next inspect the two transport intermediates sharing the24MiB typed-shape peak
with the metric cache,without changing Mean/End math or last readers. No FPS
claim,game change or user test. Full actual-grid joint ownership and CSP/timing
adoption remain unverified.
See `RAINFX_S186_RETIREMENT_POLICY_AND_PHASE_FLOOR.md`.

## s185 bounded free-slot retirement (2026-10-20)

Preflight reuses exact typed free objects first,then retires only unreserved free
backings when required by the cap. Whole-batch validation protects current/
pending banks,cache inputs,old readers and submitted work. An insufficient phase
refuses without allocation/retirement.615 native recurring draws/37 events retain
all physical/inventory bits under224KiB with14 evictions;texture creations211→222,
no new shader/GPU draw/event. Existing-completion-only full warm simulation and
independent524-resource certificate fit63.998932MiB,with1120B margin,111 physical
generations and35 retirements across two frames. A63MiB control refuses the first
transport phase. The old permanent69.807526MiB plan stays intact. This is a warm
descriptor fit plus a small native policy proof,not full actual-grid execution
or a CSP completion/timing result. Next reduce churn/increase margin,then execute
actual-grid cache/source/head/transport ownership. Main/game unchanged;no user
game test required.
See `RAINFX_S185_BOUNDED_FREE_SLOT_RETIREMENT.md`.

## s184 exact cell word storage (2026-10-20)

Keep original FP32 area/coating bits;encode four active quarter-coverage values
in the coating word's unused top bits and derive alpha from positive area.
Use typed RG32_UINT throughout,so opaque high-bit words never depend on float
NaN storage. Raw upload and retained cell cache each shrink4→2MiB.83 native
actual-cache draws/13 events preserve all logical field,metric,force,resolved
source-cell and audit bits across generation replacement/failure/retry/readers.
119 Python/native codec cases and8 pre-device format/payload refusals pass.
No extra draw;fixed bit decode replaces float cell loads. Full warm static
25.850433MiB/live62.992050MiB/reserved69.807526MiB now fit the live64MiB bound
only;reservation still fails and complete actual-grid ownership is unexecuted.
All18 physical last readers and earlier adapter gates are preserved. Next reduce
persistent typed-pool reservation/working-bank overlap,then compose actual-grid
cache/source/head/transport publication. General CSP completion,common optics
and target timing remain open. Main/game unchanged;no user game test required.
See `RAINFX_S184_EXACT_CELL_WORD_STORAGE.md`.

## s183 exact connected-run storage (2026-10-20)

Store only bounded integer topology edges/sentinel(-1…2048) in RGBA16F,retaining
their exact logical FP32 bits. Actual1024×256 run cache shrinks4→2MiB;automatic
typed loads require no new shader arithmetic or draw.83 actual-cache draws/
13 events and615 small recurring physical draws/37 events preserve prior
cache,force,source,water/time and inventory bits. Native exhaustive integer
roundtrip and malformed-input refusals pass. Physical metric/area/mass/momentum
precision stays unchanged. Actual cache replacement peak52.096207MiB and final
set28.094543MiB decrease2MiB;separate staging40.094666MiB is excluded. Full warm
static27.850433MiB/live64.992050MiB/reserved71.807526MiB still fail64MiB.
Descriptor-only smaller maps/final gather/final force increase pool reservation
and are rejected. Next reduce remaining working/bank/static residency,then
compose full actual-grid cache/source/head/transport publication. General CSP
completion,common optics and target timing remain open. Main/game unchanged;
no user game test required.
See `RAINFX_S183_EXACT_INTEGER_RUN_STORAGE.md`.

## s182 packed metric cache ownership (2026-10-20)

The actual1024×256 native cache owner now directly produces/retains the8MiB
two-band metric and adapts cache audits,fingerprints and physical force readers.
83 draws/13 real events preserve all retained legacy logical bits and independent
SI force checks across initial/weather/pose/failure/retry/return contexts. Old
resource-specific readers retain exact objects;retirement and premature return
guards remain. Four malformed inputs refuse before device creation. Local cold
allocation42.243805MiB,replacement peak54.096207MiB and final set30.094543MiB
fit the enforced64MiB component cap;separate staging42.094666MiB is excluded.
The formerly refused held-force pose is now admitted through a failed build,
without evicting its observer. This different lifetime explains why the measured
peak reduction is4.265808MiB rather than an assumed8MiB. The whole warm plan
remains66.992050MiB live/73.807526MiB reserved and fails64MiB. Next reduce physical
working overlap,then compose actual-grid cache/source/head/transport publication.
General CSP completion,common optics and target timing remain open. No main/game
changes or new user game test.
See `RAINFX_S182_PACKED_METRIC_CACHE_OWNER.md`.

## s181 compact FP32 world metric (2026-10-20)

Keep actual1024×256 geometry samples and FP32 precision;store world u/v and
Guu/Gvv in8MiB,reconstruct Guv/determinant and checked legacy logical bands.
Sign bits preserve intentionally disabled synthetic bases;host admission
requires every original word to be reconstructible. Four actual cache contexts
and a synthetic decode pass exact GPU reconstruction.615 persistent small-owner
draws/37 events and141 standalone actual-grid physical draws retain all relevant
physical/bank bits;766 final-configuration component draws in total. An earlier
precise-qualifier variant failed physical bit equality and remains rejected.
Static/live/reserved warm counts each fall4MiB:29.850433/66.992050/73.807526MiB.
The64MiB gate still fails;all18 physical last readers are unchanged. Next compose
the packed producer with actual-grid immutable cache construction/retirement,
then reduce working overlap and execute complete cache/source/head/transport
ownership. Added reconstruction arithmetic has no measured target timing yet.
Main/game unchanged;no user game test required.
See `RAINFX_S181_COMPACT_WORLD_METRIC.md`.

## s180 End-only interval handoff (2026-10-20)

Use an explicitly requested physical End-only interval profile when no external
Mean consumer exists. Preserve every within-interval force/gather Mean equation;
write completed End only and hand source End directly to the first quarter.
Mean requests,packed-profile mismatches,viewport and parent-shape errors refuse
before native device creation. Exact typed slots and independent film End bank
copies remain. The persistent small physical owner runs615 draws/37 real events
and three bank/cache/time publications with identical retained outputs;failure,
retry,replay,old readers and water/time checks pass.141 more standalone native
draws verify accepted/refused/resumed actual1024×256 operators against frozen
End/ledger/checkpoint bits. Full warm live74.992→70.992MiB and reservation
85.808→77.808MiB remain above64MiB. Actual-grid persistent joint execution,
changing-pose/cold overlap and CSP completion remain open. Future optics that
requests Mean must use/account for the packed profile. Next reduce remaining
force/map/gather or static-input residency,then compose cache/physical ownership.
Main/game unchanged;no game test required.
See `RAINFX_S180_END_INTERVAL_HANDOFF.md`.

## s179 immutable bank-root handoff (2026-10-20)

Retain micro/heads/state/meta/pose/ledger/checkpoint backing directly in the
pending bank after physical completion;preserve the separate film End copy.
Pending/published leases prevent recycling,and failed completion leaves old
bank/cache/time unchanged for retry. Native13×7/8-slot source ON/OFF/ON
recurrence passes618 draws/37 events,three publications and all eight inventory
root bits;bank copies32→4. Fifty preserved strict shader bodies are unchanged.
Full-grid descriptors avoid4,391,120B of copy destinations or8.375397MiB minimum
read/write traffic per publication;target timing is unmeasured. The small native
peak falls384B;the full warm pool only48B to85.807526MiB and live peak remains
74.992050MiB. Large copy targets were already reused,so this step improves copy
work without resolving memory admission. All16 force/2 source-cell last readers
are preserved and direct root leases extend through the new bank lifetime.
Next reduce force/map/gather simultaneous residency,then compose actual-grid
physical/cache publication. Whole64MiB,curved recurrence,CSP completion and live
adoption remain open. Main/game unchanged;no game test requested.
See `RAINFX_S179_IMMUTABLE_BANK_HANDOFF.md`.

## s178 disabled feedback and physical readers (2026-10-20)

Keep the physical source/force buffers through their actual final consumers;
the s177 diagnostic-preview return point is insufficient for those outputs.
Record16 quarter-step force and2 resolved-cell lifetimes unchanged. Validate
immutable wet-feedback OFF/pool-return OFF contexts and positive-zero inputs,
then replace their large neutral textures by two1×1 images. Enabled feedback,
nonzero/negative-zero data or wrong bindings refuse before device creation.
The bounded13×7 physical owner retains source ON/OFF/ON,three bank/cache/time
publications,failure/retry/replay and water closure:618 draws/37 events/32 copies.
Another44 draws compare original/compact birth inputs at4096 slots;planar birth
is nonzero,while canonical-curved incident volume remains zero in both paths.
Full warm static/live/reserved proposals fall4.015594MiB to33.850433/74.992050/
85.807571MiB. The complete64MiB admission still refuses;this proposal excludes
joint cold/replacement execution and does not compose the s177 owner yet.
Next reduce remaining physical working/bank overlap,then compose the actual-grid
cache/source/head/transport transaction. Main/game unchanged;no game test needed.
See `RAINFX_S178_DISABLED_FEEDBACK.md`.

## s177 resource-specific readers (2026-10-20)

Readers retain requested immutable objects instead of an entire generation.
Completed/audited preview headers,force,resolve and private audit outputs return
after their last consumers;cache/dictionary/stock/position inputs stay protected.
Held force observers refuse retirement and the next64MiB pose reservation until
explicit return. Older geometry observers retain exact header/metric/head lookup
bits through replacement and failure/retry;pending reader returns also refuse.
83 native draws/13 observed events,19 preserved strict bodies and89,328,208
compared FP32 words pass. Four SI force oracles retain the same normalized
ratios. Peak61,197,008B /58.362015MiB and final35,750,720B /34.094543MiB are each
12.016678MiB below the rerun s176 baseline. Separate audit staging46.094666MiB,
CPU/driver/shader storage are outside this scoped descriptor result. The warm
whole-plan89.823166MiB is still unexecuted and above64MiB. Next compose actual
physical consumers and cache lifetimes,reduce disabled-input/owner overlap,
and verify complete stock/time publication before runtime adoption. Main/game
unchanged;no game test requested. See `RAINFX_S177_RESOURCE_READERS.md`.

## s176 dictionary cache owner (2026-10-20)

Use the prebuilt exact dictionary as native geometry input for all34 actual
cache build passes. Two dictionary reads produce exact field-centre copies;
the other cache/physical operators retain their shaders and equations. Reuse
the same immutable bundle through weather/pose replacement,completed failure
quarantine/retry and previous-generation readers. Four8192-position geometry
probes share the bundle on the same context.83 draws/11 real events/19 strict
bodies pass full prior cache/force/resolved-cell and dictionary/probe bit checks;
independent SI force oracle passes. Fractional index/table-shape errors refuse
before native owner construction;foreign table/position data and64MiB capacity
refuse without allocation/submission. Geometry GPU raw-image upload bytes are
zero;dictionary8.71875MiB remains owned. Cold46.243805MiB,final46.111221MiB,
replacement peak70.378693MiB,separate audit staging46.094666MiB. Previous peak
89.019135MiB drops18.640442MiB despite additional head-reader retention;workload
differences are explicit. Local96MiB reference cap stays unchanged;component
and warm full89.823166MiB proposal still fail64MiB. No water/clock evolution,
SI head solver,whole pipeline or runtime adoption is claimed. Next reduce
per-resource preview/working and disabled-input lifetimes,then compose admitted
actual source/head/transport/bank/time ownership. Main/game unchanged;no game
test requested. See `RAINFX_S176_DICTIONARY_CACHE_OWNER.md`.

## s175 lossless geometry dictionary (2026-10-20)

Replace repeated full-resolution du/dv bit patterns with one2048×512 R32F index
and two1024×151 RGBA32F tables.153990 exact eight-float entries preserve the
original logical sampling resolution,FP32 precision and signed zeros. Geometry
storage32→8.718750MiB saves23.281250MiB.140 native WARP draws/30 strict bodies
verify every decoded texel,field-centre taps,8192 UV samples,accepted/refused
planar physical fixtures and original-versus-dictionary actual geometry roots.
Actual head post-force is nonzero and bit-identical;the final curved transaction
still refuses its planar external packets in both paths. No accepted curved
physical stream is claimed. Warm plan certificate passes with static37.866028,
live79.007645,reservation89.823166MiB;all drop23.281250MiB but full64MiB still
fails. This is a recertified descriptor proposal,not joint allocation/residency.
Selected static instruction counts rise778→1038,773→899 and1279→1601;target
timing is unmeasured. Next integrate a prebuilt dictionary provider with native
cache construction/replacement and immutable bundle leases,then reduce remaining
working/disabled-input lifetimes. Original GPU image copies must not remain
uncharged alongside the bundle. Main/game unchanged;no user test requested.
See `RAINFX_S175_LOSSLESS_GEOMETRY_DICTIONARY.md`.

## s174 bounded physical handoff (2026-10-20)

Execute source ON/OFF/ON with retained birth/head inventory,conserved source,
four transport quarters and eight independent final inventory copies on one
native context. Immutable per-frame planar inputs share only after complete
payload/shape comparison;pending,failed and old-reader states guard replacement.
The13×7/eight-slot fixture publishes bank,cache generation and whole-frame
clock together. Cache preparation,source completion and final copy failures
preserve publication;retry,three refused replays and50 held prior-cache input
checks pass. All physical outputs and24 committed bank payloads retain frozen
s166 bits;inherited force/source/water closure gates pass.618 draws/37 observed
events/32 copies;three commits publish46.875ms with exact accepted-time closure.
Default texture peak409232B,audit staging284976B separately,are small-fixture
costs. The unchanged full actual-grid End-only reservation118598576B refuses
against64MiB before native device construction. No budget change or full-grid
execution is claimed. s173's actual cache producer and changing-pose curved
physical stream remain to compose after complete static/working memory costs
are reduced. Main/game unchanged;no game measurement is requested. See
`RAINFX_S174_BOUNDED_PHYSICAL_HANDOFF.md`.

## s173 bounded native frame cache (2026-10-19)

Compose s172 core retirement with two immutable cache generations and two
waiting contexts on one native context. Weather-only frames share the metric
and draw one new header;rigid-pose changes rebuild through four cache draws.
Both execute eight physical-preview draws. Four full34-pass build references
and the79-draw bounded stream total247 native draws/19 observed D3D events.
Whole core images,force and resolved source cells match their references;four
independent SI force checks pass. Previous reader images remain unchanged
through weather and pose replacement. A completed injected failure remains
quarantined;explicit disposal retries the same queued context under a new
attempt identity. Pending,wrong-generation,duplicate,capacity,mutated-geometry
and mismatched-header cases refuse unsafe work. Unique descriptor accounting
charges replacement overlap:peak89.019135MiB,final37.017471MiB,separate audit
staging37.000916MiB. This preserves the local96MiB reference cap;it does not
relax or pass the full application64MiB gate. Controlled stock is unchanged and
no solver clock or water bank is published. Next compose retained nonzero
source/head/transport and inventory/time ownership,then charge all working
lifetimes before full admission. Main/game unchanged;no game test requested.
See `RAINFX_S173_BOUNDED_FRAME_CACHE.md`.

## s172 native core-cache retirement (2026-10-19)

Build all34 unchanged actual cache textures on one native WARP context. A
private owner validates full audit and observed event completion,then atomically
retires29 construction/diagnostic textures after their readers return. Five
core textures remain:raw cells,header,metric,scalar area and connected runs.
Cache reservation29.399185→21.000793MiB saves8.398392MiB without changing head
geometry precision. Native physical force and s170 resolved cells match their
preserved results before/after retirement.118 draws/5 real completion events/
17 strict bodies pass. Pending/unaudited/stale/read-held/duplicate retirement
and pending/unaudited/stale/failed consumers refuse without unsafe mutation.
Failure remains quarantined even after the real fence completes. Test-owned
source upload textures also retire;their36MiB is separate from cache savings
and cannot be counted as a second whole-app saving. Component harness peak
81.415863→69.400055MiB uses an explicit96MiB local reference cap;it does not
relax the joint64MiB gate. Native core retirement is verified for one generation;
CSP diagnostic retention and installed game are unchanged. The End-only core
joint proposal113.104416MiB remains a warm estimate;replacement overlap,frame
header ownership,backlog/common optics and measured cost remain open. Next
compose the bounded frame/cache owner and optimize working lifetimes before
full native admission. No user game test. See `RAINFX_S172_NATIVE_CORE_CACHE_RETIREMENT.md`.

## s171 checked packed-End source view (2026-10-19)

Adapt all original-film reads,including pool funding,totals and rollback,to a
bounded End view of explicit W×2H RGBA32F inventory. Shader shape checks and
host domain/layout/lease guards prevent relabelling an ordinary H image or
addressing Mean.491 native WARP draws/31 source graphs/19 strict bodies pass.
All23 prior cases retain the seven public roots;four source graphs also match
an explicit GPU End crop. Changed/NaN Mean leaves End results unchanged;stale
area receipt and old water in a hole preserve rollback. Full262144-texel crop
and excluded-Mean/outside/mip probes pass. These are isolated native functional
checks,not retained whole-pipeline execution or CSP completion/timing.
Six two-frame plans compare End bank,packed+crop and direct packed with actual
s170 adapter/header lifetimes. Retained-cache reservation121.503/129.503/125.503
MiB respectively:direct removes4MiB from packed+crop but still costs4MiB more
than End-only. Preserve the End-only baseline;direct packed stays optional and
unadopted. All64MiB gates fail;core-cache retirement/alternative128MiB policy
remain unadopted. Next optimize shared static-cache retention and working-buffer
lifetimes before combined native admission,then verify frame/cache ownership,
full-grid closure,common optics,CSP completion and measured cost. No main/game
change or user test. See `RAINFX_S171_CHECKED_PACKED_END_SOURCE.md`.

## s170 resolved source cells (2026-10-19)

Convert raw local-area/coverage/coating/version plus R32F physical-area cache
into physical-area/coverage/resolved/version. A single-pixel full-header receipt
checks source frame/token/grid/count;per-cell conversion checks exact area
scale,finite values and support. Malformed inputs become invalid sentinels that
the unchanged source transaction rejects globally, preserving stock/history.
Actual262144 cells including1809 partial-coverage cells retain expected bits;
23 legacy source cases preserve all seven roots (5 admits/18 refusals). Existing
injected bin-fault evidence is preserved separately. Ten new faults roll back,
six descriptor guards refuse,scale²4 preserves outputs and double-coverage
control changes film.527 WARP draws/36 graphs/10 strict bodies pass. The real
two-pass recipe and separate current/expected headers add1664 reserved bytes:
retained-cache R8 proposal121.502808MiB;live peak110.687286MiB is unchanged.
Core-cache candidate113.104416MiB is not adopted;total64MiB still fails. A new
frame requires an owned area-header receipt,not a relabelled retained header.
Next verify packed-End source views,then optimize/recount joint retention and
connect verified frame/cache ownership before native full-grid composition.
CSP completion,common optics and target-device cost remain open. No game test
or main/shader/settings/texture changes. See `RAINFX_S170_RESOLVED_SOURCE_CELLS.md`.

## s169 binary boundary and native input adapter (2026-10-19)

Implement native R32F/R8 birth/head boundary recipes using independent dimensions
and red-channel reads. All4194304 actual binary texels retain float bits in R8;
owned boundary descriptor16→4MiB. Eight legacy physical fixtures preserve all
roots in both formats;four nonmatching-dimension solid/hole cases match expanded
alpha references.8192 actual du/dv/boundary point queries match an independent
CPU oracle, and a one-texel hole still causes exit with unchanged adaptive step
law. Total317 WARP draws/28 producer graphs/26 strict compiled bodies pass with
native debug layer. Binary/format/domain/identity guards refuse unsupported
inputs. These are isolated component checks, not actual-mesh physical evolution,
CSP completion or frame-time results. R8 reduces the retained-cache joint
estimate to69.546MiB static/110.687MiB live/121.501MiB reserved;total64MiB gate
still fails. Core-cache retirement and the alternative128MiB policy are not
adopted. Next verify raw-coverage/scalar-area→resolved source cells and packed-End
views, then optimize/recount joint retention before native combined execution.
Main/shaders/settings/textures/game remain unchanged;no new user game test.
See `RAINFX_S169_BINARY_BOUNDARY_ADAPTER.md`.

## s168 joint lifetimes and physical input domains (2026-10-19)

Plan two warm birth/head/source/four-quarter/inventory frames with actual
2048×512 head metrics and4096×1024 boundary. Field-centre du/dv cannot serve
heads;actual boundary needs independent-size/red-channel consumers and raw
cells need resolved physical-area/source tags. These adapters are unverified,
so admission refuses even a fitting allocation proposal. Prior inventory and
next-bank copies coexist through atomic exchange;explicit readers protect
inputs until return. Eight exact-shape lifetime certificates and16 refusal
controls pass without GPU execution. Current minimal roots require81.546MiB
static,122.687MiB live,133.501MiB reserved. Core cache alone remains over64MiB
static;core+R8 is102.289MiB live/113.103MiB reserved. The total64MiB gate fails.
A static64+working64/total128 policy is comparison only and is not adopted.
Next verify lossless boundary representation and explicit physical input/view
adapters, optimize joint retention and resolve the complete budget before
native combined execution. Cold builds,queue/cache replacements,common optics,
CSP completion and measured target cost remain open. No game change/test.
See `RAINFX_S168_JOINT_LIFETIME_AND_INPUT_DOMAINS.md`.

## s167 compact source cells (2026-10-19)

Extract unchanged source-cell expressions into status/totals/commit consumers;
remove28MiB7H staging and4.0625MiB full status at1024×256/4096 slots. Direct
tile max status preserves the refusal path and remaining reduction. Full-resolution
sparse source plus34 reserved world-cache textures runs natively at60.210MiB,
from92.273MiB;source-only64MiB gate passes with3.790MiB margin. The field is
synthetic support, cache contents are placeholders and dense4096-head timing
is unmeasured.24 small source cases and a full-resolution pair retain all
public root bits. Native source-on/off/on chain, source completion retry,
replay refusal, downstream quarters and48 inventory copies also retain bits.
Total1,556 draws/88 real native events;new equations/tolerances are not introduced.
The whole head/birth/source/transport/queue/optics gate remains open; passing
individual peaks cannot establish the combined budget. Next plan full-grid
joint lifetimes including raw banks/packed film/observers and required adapters,
then execute a bounded joint pipeline. Actual CSP completion,curved feedback,
common optics and warm target timing remain before game adoption. No new game
test;main/settings/shaders are unchanged. See `RAINFX_S167_COMPACT_SOURCE_CELLS.md`.

## s166 native nonzero source/head handoff (2026-10-19)

Existing s146 birth/s148 SI heads/s144 conserved source now feed s163 packed
transport and eight independent inventory copies on one native immediate
context. Three13×7/8-slot source-on/off/on frames retain actual GPU stock;
external accumulated water1.150346518→1.150346518→2.300693035mm³ is added once.
Separate/pool imports/roots, all48 inventory copies and prior birth/head
producer bits match.1,236 draws,62 native events and594 immutable-input
comparisons pass;completion-failed source retry and three source replay
refusals per run preserve water/time. Total committed time0.046875s per run.
These are fixed planar/control inputs; s165 backlog/cache changes are not yet
composed with the nonzero source chain. Full-grid diagnostic source roots plus
world cache already require74.134MiB before other inputs/transport, so the64MiB
actual-grid gate remains open. Next fuse/shorten source raster/staged/status/
commit outputs, verify identical physical gates and recount full-grid costs.
Then combine the bounded frame/cache owner, validate curved head/feedback,
common optics, CSP ownership/completion and warm target-device cost. Game and
settings are unchanged; no new user game test.
See `RAINFX_S166_NATIVE_SOURCE_HEAD_HANDOFF.md`.

## s165 new-frame queue and cache replacement (2026-10-19)

A controlled zero-source stream carries stock/ledger across four distinct
context tokens, dt/air/acceleration values and fixed-scale pose caches. A
bounded two-frame waiting queue, explicit observer returns and real native
preparation fences prevent early reads. Failed cache preparation is quarantined;
retry and producer resubmission preserve water and accepted time. Four runs
pass3,024 solver draws plus two strict cache draws,72 solver/16 preparation
completions and64 quarter publications. Separate/pool payloads retain bits;
first actual frame equals s164.59.377174ms input time has zero residual.
Scoped native texture peak63.227219MiB adds32 bytes and keeps0.772781MiB margin;
changed-only metric uploads total36MiB for the two replacements plus retry.
Audit staging/CPU fixtures and hardware timing remain outside this gate.
Next bounded nonzero source/head handoff with once-only conservation and leases,
then common optics/full budget and actual CSP completion/admission. These are
controlled snapshots, not live frame-cadence tests. Main/game are unchanged;
no new user game test. See `RAINFX_S165_FRAME_STREAM_AND_CACHE.md`.

## s164 native typed pool and completion (2026-10-19)

Frozen s163 shaders run in persistent separate/pooled native WARP graphs.
1,258 draws,32 completed event fences,16 publications and16 discards pass;
six malformed graphs refuse before device creation. All root-parent payloads
match, and first two actual quarters match saved s163 physical roots/ledgers.
Native texture descriptor peak91.2432→63.2272MiB;35 private slots reuse across
eight submissions. No in-flight reuse, failed/pending publication or hidden
observer release;returning the observer lease is required before next admission.
All11 imports remain unchanged per flight. Audit staging reaches78.1887MiB
outside the scoped cap;driver/CPU costs and live head/birth remain excluded.
Native event completion does not establish CSP Canvas completion. Next scoped
input/completion/lease boundary for new frames, bounded cache replacement and
backlog, then head/birth/common-optics budget and measured game adoption.
No new user game test. See `RAINFX_S164_NATIVE_TYPED_POOL.md`.

## s163 scalar physical area (2026-10-19)

Film force/post/exchange only use physical area and validity. A direct R32F
producer retains original header/support/finite-cell guards and binary32 area;
checked adapters preserve malformed legacy packet refusal. Actual typed native
storage, full-grid cache parity,34 graph pairs (15 accepted/19 refused) and
failed-resume/retry pass:3,280 WARP draws/73 strict shader compilations.
Non-injected physical roots and ledgers are bit-exact.47 transport passes;
cache32.3992→29.3992MiB and recurrent exact-shape proposal plus cache
66.2272→63.2272MiB, with0.7728MiB headroom. Late force diagnostics still exceed
the cap. The End-only-copy alternative plans62.2272MiB but adds one pass,
4MiB output and at least8MiB interval traffic. Select scalar area for native
pool validation;no real pooling, completion, target timing or game adoption
claim. Next execute typed pooling with immutable input/output/cache leases,
then full head/birth and optics costs. No new user game test.
See `RAINFX_S163_SCALAR_PHYSICAL_AREA.md`.

## s162 packed outputs and direct resume (2026-10-19)

Explicit logical End/Mean row views share one physical2H backing. All original
film input readers support the checked End band directly, without compatibility
copies.29 paired cases (15 accepted/14 refused), row/mip/shape controls and a
failed-resume/retry chain pass:2,668 WARP /63 strict compilations; all non-injected
roots including ledgers are bit-identical. Actual48→47 passes,59→58 resources;
fresh separate retention stays77.8440MiB. The proposed exact-shape pool saves
4MiB fresh (cache-inclusive62.2272MiB), but retaining the previous2H packed input
adds it back on resume (66.2272MiB). No recurrent64MiB, native reuse/completion,
live solver or measured target timing claim. Next reduce recurrent retention
without losing immutable input/debt/rollback guarantees, then validate native
ordered pooling and output/cache leases. No new user game test.
See `RAINFX_S162_PACKED_OUTPUTS.md`.

## s161 early donor exchange (2026-10-19)

Reduce donor impulse/wall rows immediately after source eligibility; the late
ledger reads recipient exchange and a validated1×2 summary. The8MiB force's
last read becomes the first-axis gather.26 graph pairs (13 accepted/13 refused),
18 independent controls and2,103 WARP/34 strict compilations pass. Physical
roots retain bits; ledger differences≤3.73e−9 remain inside inherited packet
and cumulative bounds. The opposing-impulse control is bit-exact. Static peak
56.8288→48.8288MiB;cache-inclusive61.2280MiB. Current separate allocation adds
34.4KiB and4 passes, reaching77.8440MiB /48 passes. The proposed exact pool plus
cache66.2272MiB remains above64MiB and is not executed or completion-verified.
Next packed End/Mean exports and checked band consumers, then native pooling
with ordering/completion and cache leases. No game change or timing claim.
See `RAINFX_S161_EARLY_DONOR_EXCHANGE.md`.

## s160 direct tiled status (2026-10-19)

Fuse unchanged per-cell packet predicates with their first16×16 maximum.
Two full status images and two reduction draws disappear:46→44 passes,
57→55 resources,85.8104→77.8104MiB;combined retained cost90.2096MiB.
50 CPU/two-pass tile comparisons and23 whole-graph pairs pass:1,964 WARP /
33 strict compilations. All non-injected roots and intermediate tiles retain
bits, including ledgers. Static peak56.8288MiB remains at second-axis gather.
An exact-shape lifetime proposal checks symbolic owners and pins roots/imports;
61.7945MiB becomes74.1937MiB with retained cache, and is not an allocator or
completion proof. Next evaluate early donor-exchange reduction to shorten its
force-buffer lifetime, then validate ordered native pooling and cache budget.
No main/game change, target timing claim or new user game test.
See `RAINFX_S160_DIRECT_TILED_STATUS.md`.

## s159 compact applied-source/recipient (2026-10-19)

Use immutable film plus a scalar physical/context guard for already-applied
source, direct checked compact force bands, and2-band recipient storage.
Ledger-only post extras use the unchanged expressions; logical post evaluations
stay5 per supported cell.50→46 passes,61→57 resources and130.3114→85.8104MiB;
combined retained field/graph98.2096MiB.23 paired cases (12 accepted/11 refused),
8 CPU refusals and1,952 WARP/33 strict bodies pass. Physical roots retain bits;
ledger differences up to7.28e−12 stay within inherited bounds. Old debug source
ABI is explicitly replaced by identity/guard roots. Static graph frontier
56.8288MiB is not a completion/reuse proof, and with retained cache it estimates
69.2280MiB. Next direct tiled status reduction and bounded target lifetimes;
no main/game change, timing claim or new user game test.
See `RAINFX_S159_COMPACT_SOURCE_APPLIED_POST.md`.

## s158 selected bank continuation (2026-10-19)

Select bank transport in both axes, retain axis/status/recipient/ledger gates,
and remove unreachable logical comparisons and copies. Final film/mean select
recipient data after accepted finish; immutable micro/head roots alias inputs
under retained read leases. Actual-grid73→50 passes,84→61 resources and
199.9678→130.3114MiB; combined with retained field cache142.7106MiB. Both-order
small/ragged/actual-grid comparisons, physical resume and fault rollback are
checked against the frozen full graph. No target recycling, owner-limit increase,
game change or timing claim. Next source-applied staging/recipient storage, then
bounded lifetime/completion and live inventory authority.
See `RAINFX_S158_SELECTED_BANK_CONTINUATION.md`.

## s157 field inputs and sized continuation (2026-10-19)

Exact field-centre point copies preserve every world metric/area/run component
while reducing the retained field bundle56.5874→32.3992MiB. The isolated force
branch becomes44.4150MiB. Parameterize full continuation without changing
numerical bodies: both13×7 orders retain complete intermediate bit parity;
273×17 multi-group reductions and actual1024×256 dry/static/thin physical film,
both orders, debt refusal and a second physical quarter pass.878 WARP draws /
42 strict compilations across two harnesses. Actual graphs use73 passes and84
resources at199.9678MiB, so they remain offline reference graphs.4096 empty head
slots are capacity coverage, not active rainfall. Next remove comparison and
unconsumed outputs before native/live connection; completion/reuse and inventory
authority remain open. No new game test or timing claim.
See `RAINFX_S157_FIELD_INPUTS_AND_SIZED_CONTINUATION.md`.

## s156 compact force and readers (2026-10-19)

Store half-End/full-Mean in2 bands; decode errors and reconstruct impulse/normal
exchange from immutable inputs. End/Mean bits match, impulse rounding stays inside
the unchanged128-epsilon closure gate.21 full-grid force cases/4 reader controls,
8 small-field full-graph comparisons and3 time-debt continuations pass:1,289 WARP
draws/40 strict compilations. Full-grid force storage16→8MiB; logical calls4→2;
6 passes unchanged. The retained diagnostic stack still totals68.60321MiB, above
the64MiB owner limit. No game change, new test or measured FPS claim. Next remaining
cache/scratch budget and actual-grid full-frame continuation; recurrent completion
and live inventory authority remain open. See `RAINFX_S156_COMPACT_FORCE_READERS.md`.

## s155 actual-grid film force consumer (2026-10-19)

Connect captured frame660 and the reconstructed world cache to unchanged film
force functions.106 WARP draws/9 bodies verify17 full-grid cases (6 accepted,
11 refused),6 CPU refusals, original bit parity and scale-independent SI response.
Maximum oracle ratio0.49001 within the unchanged32-epsilon gate. Preserve the
initial3-cell ill-conditioned tangency-audit failure; correct its input roundoff
scale without changing force or the physical oracle. The6-pass diagnostic owns
16.01579MiB private outputs; the16MiB four-band force buffer dominates, and stacking
with retained s154 would reach76.60321MiB. Next compact force outputs/readers before
live connection. No new game test, stock/time publication or owner-limit increase.
See `RAINFX_S155_ACTUAL_GRID_FORCE_CONSUMER.md`.

## s154 world field cache (2026-10-19)

Derive actual1024×256 world U/V/Gram, authoritative world cell area and connected
X/Y run endpoints from owned du/dv/cells plus the actual main context. Full-grid
consumer checks123,224 supported cells; 16 CPU samples independently check pose,
metric/area and exact endpoints.35 field +34 managed-graph WARP draws pass with
6+11 strict bodies,19 controller cases and5 main-hook checks. One default-off
run retains34 canvases/56.5874 nominal MiB;42 log lines include the complete
header/audit/sample payload. Actual main frame660 passes with0 invalid cells,
123,224 supported cells and all16 CPU samples within tolerance; header/input
identities and resource counts match. No water step, recurrent reuse, clock or
live solver adoption. Next actual-grid frame
consumers and bounded resource cost. See `RAINFX_S154_WORLD_FIELD_CACHE.md`.

## s153 owned GPU geometry (2026-10-19)

Freeze seven static physical inputs plus the actual main-app context in a private
whole-allocation namespace. Retain submitted read leases/canvases for the session;
no completion guess or reuse. Boundary alpha is R32F with an explicit consumer
adapter, saving48MiB.14 managed cases,33 WARP/8 strict bodies and full-copy checks
pass. Actual main frame939 matches all8 full-input numerical fingerprints after
31 passes;31 canvases total52.934 nominal MiB remain retained. No current solver,
stock, tuning or production shader changes. Next derive owned world-space field
metrics/run inputs and bind frame consumers; substantiate bounded graph resource
lifetime/completion before live recurrent adoption. General completion remains
false. See `RAINFX_S153_OWNED_GPU_GEOMETRY.md`.

## s152 main physical context (2026-10-19)

Capture actual GLASS_RAINFX world pose at scene-ready, physical settings, SI units
and common engine inputs after20 asynchronous input-file hashes. Main-app mesh,
surface/material/count changes and invalid settings refuse the capture. Display
gains cannot affect physical identities.27 context/9 main-hook/6 decoder cases,
20 WARP draws/5 bodies pass; existing P2/SI/film consumers verify header meanings.
The existing game links expose the files with matching input hashes; no install
or tuning change was needed. Actual main frame745 passes52 rows/208 values,
payload/pose checksums, unit/settings identities and force/evaporation checks.
The successful run uses the host scene-ready callback; mixed-load compatibility
is also locally tested after the first missing-callback error. This is CPU
observation with verified files, not a GPU geometry lease or new solver.
Next establish retained resource identity and
completion/order before recurrent adoption. See `RAINFX_S152_MAIN_PHYSICAL_CONTEXT.md`.

## s151 engine input/header observation (2026-10-18)

Package a default-off independent app that freezes focused-car weather, wind,
inertia and reference pose once, derives existing P0/P2 supply and stamps all50
diagnostic header rows with common frame/token/dt. GPU upload and capture preserve
the snapshot during compile retries.15 input/8 controller/8 decoder cases,
6 WARP/2 strict bodies and binary32 controls pass locally. Actual CSP frame866
also passes: all50 rows/200 values bit-identical, with common frame/token/time and
payload checksum verified. Car-reference pose/material constants are diagnostic.
The SDK still provides no audited general completion API; used canvases stay
retained and readback never enables strict completion, solver or public clock.
Next authentic visor/material/geometry authority, then
substantiated completion/resource lifetime before live solver integration.
See `RAINFX_S151_ENGINE_INPUT_HEADER_PROBE.md`.

## s150 recurrent inventory inputs (2026-10-18)

Bind protected old state/meta/pose, field stocks and checkpoint/ledger directly
to the previous bank through a scoped immutable source router. Three actual
birth/head/source/two-step transport/copy intervals advance a private clock and
retain water across on/off/on supply; the middle interval does not replay input.
7 scenarios,525 WARP/57 strict bodies,24 bit-identical copies and independent
force/ledger checks pass. A stale force-header token is correctly refused with
stock/debt unchanged; its failed evidence is retained. Current fixture is8 slots,
fixed planar pose,13×7 cells and0.046875s, with pool/wet-height feedback off.
Actual engine uploads, CSP completion/persistence, broader recurrent accuracy,
fusion, shared optics and measured warm cost remain open.
See `RAINFX_S150_RECURRENT_INVENTORY_INPUTS.md`.

## s149 persistent inventory handoff (2026-10-18)

Copy the complete raw/physical head state, film, micro, ledger, checkpoint and
previous pose into independent GPU allocations. Retain original roots through
tracked multi-pass copy and trusted completion, then retire the frame graph
before next-identity immutable provider reads. Two bank versions, eight readers,
32 pins/reader and64MiB/bank bound retention; private clock/stock exchange never
publishes the game clock.41 owner/inventory scenarios,175 WARP/57 strict bodies,
six frame/six root guards and copy bit-identity pass offline. The two-bank test
uses controlled second data, not repeated physical intervals. Next authentic
engine snapshots/upload provenance and actual completion, followed by recurrent
physical/time accuracy, fusion and measured warm cost.
See `RAINFX_S149_PERSISTENT_INVENTORY_HANDOFF.md`.

## s148 SI head motion and transfer producer (2026-10-18)

Produce post-force motion, advance trace, physical metadata and original P3
trail/evaporation descriptors inside the head graph. Birth events/receipt/header
are exact retained parent roots. Merge commands and full-generation stamps are
created from one frozen SI metadata snapshot.21 head cases,276 WARP/12 strict
bodies include4096 slots and independent force/packet closure. The unchanged
force core's precision failure is preserved; stable contact-angle and exponential
evaluation passes the same numerical gate. Physical coefficients and game runtime
are unchanged. The complete offline owner chain now uses existing moving/merged
heads rather than just controlled newborns. Next authentic engine snapshots and
upload identity, verified completion and persistent inventory handoff, then fusion,
physical/time accuracy and measured cost. See `RAINFX_S148_SI_HEAD_PRODUCER.md`.

## s147 frame dependency owner and output lifetime (2026-10-18)

Own the offline s146→s143→s144→s145 partial-step chain. Match immutable frame,
clock and material/weather/pose identities, pin exact parent output handles and
retain children/readers through trusted completion and numerical admission.
Cancellation/unknown submission never free early.29 owner cases,6 frame guards
and6 root guards pass;161 WARP/46 strict bodies execute an all-newborn frame
through source and two transport steps to phase2. Public clock and game stocks
remain unmodified. One active interval and bounded stages/bytes refuse excess
work without dropping time debt. Next authentic P1/merge/source/upload hooks and
actual completion/persistent handoff backend, then diagnostic fusion and accuracy/
warm cost adoption gates.
See `RAINFX_S147_FRAME_DEPENDENCY_OWNER.md`.

## s146 retained impact producer and frozen context (2026-10-18)

Capture world incident/normal/initial-head velocity in the original P2 event
calculation. Preserve volume/seed/DSD/impact/pool decisions bit for bit and emit
explicit film, pinned micro, bounded rebound and capture reaction packets.
438 WARP draws/43 strict bodies,37 cases,7 snapshot guards and6+1 lease scenarios
pass, including actual curved assets and4096 slots. P2-produced packets pass
through s144 and s145 to phase2 with a controlled stationary head envelope.
The18-row context freezes source time, pose/weather/material and resource
identities; no actual multi-stage frame owner or completion authority yet.
Next implement shared P1/s143 frame ownership and live source/upload hooks,
then fuse diagnostics and evaluate physical/time accuracy and persistent cost.
See `RAINFX_S146_RETAINED_IMPACT_PRODUCER.md`.

## s145 source-applied remaining-time transport (2026-10-18)

Connect s144 physical film to unchanged s141 ordered field transport. Admit the
source-applied checkpoint and joint inventory, retain pinned micro/heads, supply
zero new source/events and consume only matched remaining time. Partial candidates
carry debt; phase 2 requires zero debt and remains a numerical candidate, not a
completion fence or clock publication. Step/cumulative ledgers preserve already
counted source and pool entries. Both axis orders, real source/transport cycles,
rest/evaporation oracles, refusal rollback,4096 heads and retained lease checks
pass offline:2571 WARP draws/40 strict bodies,39 cases/6 lifetime checks.
The 8-head diagnostic graph uses65 passes/76 resources;
fusion/reuse and actual timing remain required. Next implement immutable frame
ownership/retained impact packets and trusted lifetime, then physical/time and
cost gates before a default-off live preview.
See `RAINFX_S145_SOURCE_APPLIED_TRANSPORT.md`.

## s144 physical source and source-phase inventory handoff (2026-10-18)

Rasterize admitted s143 trail/retained-impact packets with the production tent/
line kernels and sparse masks. Debit uniquely owned pool returns, keep pinned
micro separate, record clipping/reaction packets and select film/micro/head,
cumulative ledger and source checkpoint together. Refusal preserves old stocks
bitwise; source reapplication is blocked. Cell-local kernel evaluation resolves
the full-resolution precision failure without changing the oracle gate.
555 WARP draws/16 strict bodies,27 cases,5 upstream head graphs and6 cumulative/
6 lifetime cases pass, including4096 slots and1024x256. The latter uses63.2MB
nominal diagnostic resources, not an accepted production cost. Source checkpoint
retains the entire field-time debt. Next connect s141 remaining-time transport,
complete interval ownership and implement actual retained-impact/source-frame/
lifetime hooks; recurrent physics/time accuracy and measured cost stay open.
See `RAINFX_S144_PHYSICAL_SOURCE_HANDOFF.md`.

## s143 paired merge and retained exit ownership (2026-10-18)

Consume canonical reciprocal merge commands with full-generation creator stamps,
physical-volume contact/role decisions and opposite pair transfer packets. Record
the survivor's tangent projection as a once-owned wall reaction. Instrument the
original bounded advance only at its returns: preserve raw-state arithmetic and
last-valid exit momentum, distinguish UV/mask exit from128-step exhaustion.
263 WARP draws/6 strict bodies,32 channel/refusal cases,3 original-state bit
controls and6 managed lifetime cases pass.4096 slots include a final-slot pair
and generation fault. Numerical exhaustion exports no exit water or receipt.
This is an uninstalled candidate; actual full-generation/post-force source hooks,
physical source raster, joint field/head ledger and interval publication remain
next. Force/contact/time accuracy, completion authority and measured runtime-scale
cost are still gates. See `RAINFX_S143_PAIRED_MERGE_AND_EXIT_OWNERSHIP.md`.

## s142 actual physical-channel adapter (2026-10-18)

Decode actual raw SI state/meta, five-row P2 events and P3 paired transfer/meta
channels into world-component physical head packets and separate external/pool,
film/capacity, micro, bounce and exit descriptors. Radius/display codec never
sets physical volume or velocity. Exact birth/debit/geometry checks and bounded
4096-slot status reduction refuse inconsistent or unsupported merge transitions.
330 WARP draws/4 strict bodies,39 channel/refusal cases,24 recurrent steps and6
managed lease cases pass. The production P3 meta debit is exercised unchanged.
This is an uninstalled candidate adapter, not live solver adoption or independent
force validation. Source field/micro/impact momentum is not inferred from volume
channels. Next integrate immutable merge/exit ownership, physical source raster,
joint head/field ledger and interval commit; actual frame leases, completion,
accuracy and measured runtime-scale cost remain open. See
`RAINFX_S142_RAW_PHYSICAL_CHANNEL_ADAPTER.md`.

## s141 physical packet producer (2026-10-18)

Construct real physical End/Mean and packed transport inputs from authoritative
world packets, one-time accepted supply/pool/head transfer, resolved physical area
and immutable force/material snapshots. Run the unchanged observed consumers,
recipient force/evaporation and a conservative film+head+impulse/wall/loss ledger.
958 WARP draws/24 strict bodies,20 physical/refusal cases and6 managed lifetime
cases pass; the4096th-slot fault is detected. Defaults remain uninstalled with
no game publication; direct bridge publication now requires trusted completion.
Next connect actual P1/P2 state/accepted source, full head lifecycle and cumulative
ledger/clock ownership; recurrent footprint/contact accuracy, fusion/runtime-scale
cost and lifetime authority remain open. See `RAINFX_S141_PHYSICAL_PACKET_PRODUCER.md`.

## s140 actual header/partial-plan assessment (2026-10-18)

Actual s139v2 completes53312 floats/296 lines without the texture-limit fault.
Its original evaluator mixed WARP source metrics with actual CSP. Preserve the
initial mismatch and correct only source-reference selection in a separate s140
evaluator:25 inputs match the pre-existing actual s137 capture bit for bit.
64 headers,5 exact active plans/3 refusals,60 logical/bank pairs,20 end-only checks,
3640 conditional endpoint bounds and original conservation gates pass.255 calls
are accepted once in319 attempts.13 mutation guards retain strict detection,
including one-bit metric changes. No new shader, game run or tolerance change.
Next construct the true End/Mean/force/source/head-ledger handoff; general runtime
admission, lifetime authority, recurrent physical closure and measured cost remain
open. Main app stays s87/s89. See `RAINFX_S140_SOURCE_BACKEND_REFERENCE.md`.

## s139 genuine-header/partial-time CSP probe (2026-10-18)

Actual s139 fails at the40-texture extraction call; installed CSP documentation
limits one shader call to32 textures. Preserve that failure and original sources.
Separate s139v2 pages extraction at24 textures maximum, checks each request against
32 and reproduces v1 failure under that mock limit.255 WARP draws/19 bodies,
22 controller/16 decoder/9 scratch installer checks pass with identical53312
reassembled words/296 lines. Actual v2 is captured; s140 separately assesses the
initial evaluator source-reference mismatch. See `RAINFX_S139V2_PAGED_CAPTURE_FIX.md`.

Prepare an independent default-off probe for five eligible interval plans and
three deliberately refused GPU headers. Capture53312 floats/296 bounded lines,
60 logical/bank pairs,20 end-only checks and producer/early-return guards.250
WARP draws/17 strict bodies,19 controller/16 decoder/9 scratch installer controls
pass. Local fields match s138 bits; actual observation is pending. Retain all
used resources without host clock/root publication or lifetime fence inference.
Next assess actual headers/plans/conditional map bounds, then construct the true
End/Mean/force/source/head-ledger handoff. Main app stays s87/s89.
See `RAINFX_S139_ACTUAL_INTERVAL_HEADER_PROBE.md`.

## s138 dynamic interval/header adapter (2026-10-18)

Freeze a bounded, unit-tagged interval snapshot and acquire thirteen stock/header
read leases. Genuine s95 GPU protocol plus stricter ID/debt checks derives the
substep for the unchanged26 consumers. Retained roots/clock require a matching
eligible plan before publication.282 WARP draws/13 strict compiles,130 bit-field
comparisons,29 snapshot/29 GPU header guards and19 lease cases pass. Current P3
film/micro/evap/runoff channels cannot be aliased as End/Mean momentum inputs.
Adapter stays uninstalled; completion/leases remain mocked locally. Next observe
genuine headers/partial plans/import consumers together in an isolated CSP probe,
then build the production End/Mean/force/source/head-ledger handoff. Live numerical
admission, lifetime authority, physical closure and measured cost remain open.
See `RAINFX_S138_INTERVAL_SNAPSHOT_HEADERS.md`.

## s137 imported input/prefix probe (2026-10-18)

Prepare a default-off standalone GPU producer→six read leases→26-pass import
graph for both axis orders and stock scales. Capture all32 fields per case:
42240 exact floats,228 bounded log lines,48 logical/bank pairs and16 end-only
checks. Producer writes/early source return must refuse at a three-pass prefix.
132 WARP draws/13 strict compiles,19 controller and15 decoder controls pass.
Actual42240 floats pass all four cases,24 source/56 selected controls,48 matching
pairs and16 end-only checks.186 attempts/132 once-accepted calls exercise14
retrying draws; all three-pass write/return guards pass. Retain used resources,
publish no game roots and infer no completion fence. Production stays s87/s89.
Next bind a real interval source/header snapshot to this input path with bounded
ownership/backlog and explicit immutability/completion refusal.
See `RAINFX_S137_ACTUAL_IMPORTED_INPUT_PROBE.md`.

## s136 owned source provider (2026-10-18)

Replace six fixed seed passes with borrowed canonical End/Mean/bank/runs/metric/
header input leases. Keep26 downstream passes and exact candidate bodies; release
only private outputs. Validate identity/revision/descriptors, roll back partial
acquisition and retain submitted invalid/reset sources until trusted completion.
104 WARP draws/11 strict compiles pass56 baseline/double-stock field checks.
37 lifecycle/lease cases and4 identity mutations pass, with at most26 instrumented
private canvases/12 read pins. Immutable leases/completion are mocked; no game
memory/FPS or zero-upload claim. Next obtain isolated actual CSP input/import and
prefix evidence while retaining used resources. Production stays s87/s89; live
admission, completion ownership, recurrent accuracy and cost remain open.
See `RAINFX_S136_OWNED_GPU_SOURCE_PROVIDER.md`.

## s135 retained candidate intervals (2026-10-18)

Bind the exact selected curved recipes, typed inputs and s134 provenance to the
existing queue and managed bridge. Retain accepted prefixes, private roots and
cancelled flights; publish stock/loss roots and clock together only after full
execution, trusted completion and result identity checks.64 WARP draws/12 strict
compiles preserve frozen selected outputs;17 lifecycle cases/12 binding guards
pass. A16-interval fixed replay peaks at32 instrumented canvases; this is not an
actual memory/FPS measurement. Fixed seeds, zero new supply and mocked completion
remain explicit. No game change. Next replace fixed seeds with an owned source
provider, then obtain actual CSP prefix evidence without inventing a completion
fence. Production remains s87/s89 and recurrent physical closure stays open.
See `RAINFX_S135_RETAINED_CANDIDATE_INTERVAL.md`.

## s134 curved arithmetic bounds (2026-10-18)

Derive outward interval enclosures for native, mass+face and full-correction map
graphs under explicit finite/FTZ/reciprocal/Gram-branch domains. Reuse the frozen
CSP capture: all8736 endpoint checks and tested Gram values fit the conditional
model. Selected mass+face maximum expanded radius is6.86211e-5 reference UV-atlas
texel, not a viewport-pixel/physical/optical bound. The1175-ULP near-zero case is
1.06850e-9 cell absolute with projection cancellation about239.03; preserve it
and the original exact affine gate. Eight frozen input receipts,182 fixed map
faults,9 ownership mutations and arithmetic/source-domain controls pass offline.
No new app/test run or game change. Next bind the exact candidate and immutable
inputs to retained interval transactions; runtime admission/general completion,
full recurrent accuracy and actual cost remain open. Production stays s87/s89.
See `RAINFX_S134_CURVED_ROUNDOFF_BOUNDS.md`.

## s133 quotient ablation (2026-10-18)

Compare all8 mass/projection/face masks on signed affine, real YX and sparse XY.
Actual166784 selected-root floats/192 matching pairs reproduce native/full CSP
controls exactly. All scoped budgets/copies/admission pass; only masks5/7 pass
exact affine maps. Select mass+face (mask5): additional synthetic map slots44→28
with no extra load sites. This is not a timing/FPS win. Mass-enabled masks retain
the near-zero1175-ULP counterexample (1.07e-9 cell); curved results are not all
bit-identical to full correction. Export exact tested map bodies as an uninstalled
prototype.1504 WARP draws/31 compiles,1029 codec,18 lifecycle/15 decoder/9 installer
controls and32-plan ownership checks pass. Next derive scoped curved error bounds
and retained interval ownership before live adoption; production stays s87/s89.
See `RAINFX_S133_QUOTIENT_ABLATION.md`.

## s132 compensated map consumers (2026-10-18)

Apply the s131 residual quotient correction at mass normalization, Gram projection
and weighted-face division in both real map consumers. Unchanged original affine
criteria and curved/cut sequential checks pass318 WARP draws/17 strict compiles;
49152 exact rational quotient components match in3 additional WARP draws.
18 lifecycle/15 decoder/9 installer controls pass. Synthetic maps add44 static
slots and2 temporary registers with unchanged load sites; cost is not yet timed.
Actual98304 floats/72 matching pairs pass all scoped checks. Both signed-affine
cases now have zero map error under unchanged strict criteria. Curved/cut budgets
pass; curved max absolute error stays4.7548e-7 cell, while near-zero error grows
from181 to1175 ULP (1.0685e-9 cell absolute). No uniform precision gain is claimed.
Preserve production s87/s89 and prior failures. Next ablate correction sites to
reduce extra divisions and derive scoped curved bounds before live stock adoption.
See `RAINFX_S132_COMPENSATED_MAP_CONSUMERS.md`.

## s131 curved sequential/arithmetic probe (2026-10-18)

Sample13x7 real visor U/V/validity into independent XY/YX sequences, including
synthetic internal cuts. Trace native/precise/residual quotient and map replay.
198 WARP draws/17 strict synthetic compiles,18 mocked lifecycle,15 decoder and15
installer controls pass. Actual98304 floats retain72 bit-identical consumer
pairs; both orders/cut cases pass scoped admission and step/cumulative budgets.
Native and precise normalization differ by1 ULP from the dyadic control;
diagnostic residual correction matches exactly. Original consumers remain
unchanged, so the strict affine gate still fails. Curved map max absolute error
is4.7548e-7 cell;181 ULP near zero is separately reported, not hidden.
Preserve both1000-line truncated dumps; packed770-line capture succeeds after
a game-session restart. Next evaluate compensation in original consumers and
derive map error bounds. No live physics/cost adoption.
See `RAINFX_S131_CURVED_SEQUENTIAL_TRACE.md`.

## s130 actual axis consumers and precision counterexample (2026-10-18)

Connect original map/leaves/groups/totals/full gather/end-only gather on both
axes with4 affine moving/runoff/refused scenarios.124 WARP draws pass; actual
CSP39168 values retain48 bit-identical logical/bank output pairs and all seeds.
Independent checks expose normal Y runoff falsely refused: adjacent map edges
overlap by4.76837158203125e-7 cell at7 positive/15 negative faces. Preserve
original failure; do not call equality alone a physical pass. A separate precise
speed/face/endpoint candidate removes false Y refusal on actual CSP; normal
admission and intended rejection hold. Both versions total78336 actual floats/
96 bit-identical consumer pairs. Strict exact analytic map equality remains
false at4.76837158203125e-7 cell, so the full gate stays open. No extra pass/fetch
or target; actual precision cost
is unmeasured. Lifecycle16/decoder14/install9 controls per variant. Preserve
53 runtime,3 INI,374 prior sources/assets; game physics s87/diagnostics s89.
See `RAINFX_S130_AXIS_CSP_CONSUMERS.md`.

## s129 existing solver helper/packet ABI (2026-10-17)

Install a default-off standalone app with exact s109/s110 helper bodies and
original txAdvEnd/txAdvMean, gAdvGrid and bank row names.3 grids with different
contained End/Mean bands test6 checked/explicitly guarded/wrapper paths, including
8 invalid coordinates/mips each. Host descriptor guards14, mocked lifecycle
cases14, decoder cases15, installer scratch cases9 and9 synthetic compiles pass.
Actual7680 values all match exactly, including576 guard zeros and all controls.
Texture arguments, distinct End/Mean rows and wrapper mixing/selection pass.
All33 draws accepted once. This does not enable frozen s110 solver proofs or
connect full map/loss/gather consumers/live stocks. Keep strict completion
false and production s87/s89. Preserve53 runtime,3 INI and362 prior stage files.
See `RAINFX_S129_SOLVER_BANK_ABI.md`.

## s128 actual integer/address and bank readers (2026-10-17)

Run a default-off standalone app on actual preview649.3 parent layouts (8x4,
13x21 and1056x864),6 integer/sample reader forms and57 valid/7 invalid queries
per combination yield6912 exact floats, including504 guarded zeros. Parent,
address and generated logical-oracle controls agree. All34 draws accepted once;
accepted prefixes survive shader pending. Integer Load works on this path;
s127's specific failure is not a general Load limitation or a solved compiler cause.
14 mocked lifecycle cases,15 decoder cases,9 installer scratch cases and9
synthetic shader compiles pass; nominal texel payload29,255,200B is not a GPU
allocation/timing measurement. Preserve53 runtime,3 INI,352 prior files/assets.
Next connect the actual s109/s110 generic helper/packet ABI before live solver
stocks; strict completion and production s87/s89 remain unchanged.
See `RAINFX_S128_BANK_READER_PROBE.md`.

## s127 actual CSP data and reverse-read isolation (2026-10-17)

Install two isolated default-off apps with verified ownership; user starts their
one-shot probes in an existing replay. Capture3 actual preview649 observations
(1792 float values) and exact executable/log provenance. All23 used API blocks
match preview634. Matrix/vector seed, forward Load copy, signed/above-one R32FLOAT
and UV controls match exactly. Reverse integer Load returns zero input despite
texture/uniform renaming; reverse SampleLevel matches all128 expected values.
The internal cause is unconfirmed; a narrow8x4 diagnostic recipe selects the
tested sampling branch. General Load replacement/linear sampling for arbitrary
physical grids is not approved by this result. Strict completion stays false.
14 scratch installer cases,31 parser fixtures/4 boundary checks,11 mocked trace
controls and5 synthetic shader bodies pass. Preserve53 runtime,3 INI,340 prior
files; physics remains s87/diagnostics s89. Next validate scoped integer/parent
bank readers, live ownership and actual cost before full solver adoption.
See `RAINFX_S127_ACTUAL_CSP_TRACE.md`.

## s126 standalone CSP observation probe (2026-10-17)

Prepare a separate default-off app ZIP with one asymmetric matrix/vector seed,
whole-canvas copy and spatial/channel transform. Extract all four float channels
to R32FLOAT before using the documented floatValue readback accessor; color is
documented for RGBA8888. Seven accepted draws/four reads per one-shot run,
2KiB nominal texel payload; no target GPU/CPU timing or actual allocation claim.
27 mocked LuaJIT scenarios/658 actions check pending, disable, duplicate/late/error
callbacks, failure and a bounded attempt budget. Exact rational patterns identify
transpose/flips and reject stale/clamp/channel faults; four shader bodies compile
with synthetic declarations, not CSP's closed template.23 SDK blocks agree.
The package remains uninstalled. Actual CSP signed-range/layout/ordering and app
lifetime must be observed next; readback is never promoted into a general fence.
Strict queue gate and game physics s87/diagnostics s89 remain unchanged.
See `RAINFX_S126_STANDALONE_CSP_PROBE.md` and its prepared package.

## s125 managed canvas pass bridge (2026-10-17)

Implement owned whole-canvas resources and stable params/textures/values schema.
Retain compile-pending pass prefixes without replaying accepted draws; copy
ordinary vector/matrix inputs and distinguish logical root metadata from
physical GPU completion/retirement. Cancel/reset/unknown submission retain
resources; unsupported capability cannot progress or infer elapsed-frame fences.
16 LuaJIT scenarios/6271 operations,21 guards and11 matching local SDK evidence
blocks pass with an instrumented mock backend and independent scalar/state replay.
No actual CSP shader/layout/ordering/fence validation or performance claim.
The uninstalled adapter defaults both capabilities unavailable; s124 strict queue
stays gated. Next build a standalone default-off asymmetric matrix/copy probe,
then verify real managed resource semantics before full transport integration.
53 runtime files,3 INI,326 prior stage files/assets preserved; game physics s87,
diagnostics s89. See `RAINFX_S125_MANAGED_PASS_BRIDGE.md`.

## s124 CSP boundary and bounded input queue (2026-10-17)

Audit15 API evidence blocks in the local preview634 app SDK; the critical
root-file docs agree. Shader readiness/image loading are not general GPU
completion. No direct native buffer/fence/region-copy mapping is declared.
The41 frozen prototype shaders bind at most16 textures versus the documented32.
Implement an owned scalar/receipt Lua queue with bounded slots/time/supply,
FIFO pose/forcing history, separate source staging/time progress and explicit
reset abandonment.16 LuaJIT scenarios/15640 actions match an exact-rational
reference, including2000 consecutive intervals and randomized stale/failure/
reset cases. Accepted water/time balance; rejected inputs remain producer-owned.
Strict completion defaults unavailable and refuses before creating a job.
Next prototype a CSP-managed stable-schema pass bridge, tracking pending
prefixes and separating logical publication from physical retirement. Actual
GPU completion, live resource ownership, accuracy and target cost remain open.
Runtime/settings/assets unchanged; no install/log request/commit/push. See
`RAINFX_S124_CSP_BOUNDARY_AND_QUEUE.md`.

## s123 completion-safe constant storage (2026-10-17)

Prepare owned constant packets once per pending request; capacity retries keep
their bytes. Give each packet distinct GPU storage within its flight, upload
before draws and retire only after actual completion plus explicit finish.
Matching completed buffers are reused with byte/entry admission and reserve-
before-eviction. Four WARP paths pass2288 commands/260 flights in18 schedules,
including constant-capacity recovery and pending cancel/reset. Creation calls
fall5470→2088 with3382 reuses per pooled path; uploads/draws/copies stay unchanged
between the new paths and physical GPU roots equal s122. Independent DXBC/RDEF
packet bytes and per-action ID/size/ownership replay pass. The native pool
contract ends with0B and no D3D warnings. No FPS/RSS/VRAM improvement is claimed.
Next audit the actual local CSP resource/update/completion APIs and design
their adapter/backlog boundary; native D3D11 storage is not assumed exposed.
Runtime/settings/assets unchanged; no install/log request/commit/push. See
`RAINFX_S123_CONSTANT_PACKET_REUSE.md`.

## s122 prepared shader binding layouts (2026-10-17)

Cache reflected constant/texture metadata with the bounded shader entry and
share immutable layouts during admission. Validate all candidate values and
texture names before root seeding or command submission, then pack interval
values with the same offsets/types/zero padding. Four WARP paths again pass
2104 commands/224 flights, matching s121 physical work, allocations and GPU
bytes. Metadata reflection walks per path fall9578→615;4714 buffer creations
and all physical draws/copies remain. This is not a measured FPS improvement.
Seventeen candidate refusals and10 literal-packing/validation guards pass.
Next prepare bounded per-flight constant storage and completion-safe reuse.
Runtime/settings/assets unchanged; no install/log request/commit/push. See
`RAINFX_S122_SHADER_BINDING_LAYOUT.md`.

## s121 immutable templates and interval bindings (2026-10-17)

Register and validate bounded immutable graph topology once, then share it with
owned per-interval uniform/input/receipt snapshots. Binding does not copy or
revalidate static pass/resource topology. Registry clear invalidates new handle
use while pending/in-flight calls retain their template until retirement.
Fifteen four-path WARP schedules pass2104 commands/224 flights; physical work,
ownership/publication and actual GPU roots equal s120. Per template path,
45 registrations serve56 bindings with1423 acquired/returned input views.
Registered zero defaults plus actual bound constants verify the value path.
Sixteen rejection cases, a distinct-value/default-fallback contract probe and
absent-oracle execution pass. Structural reuse is not a CPU/FPS measurement.
Next reuse shader reflection/constant packing layouts; live CSP, complete
physical lifecycle/accuracy and target timing remain open.
Runtime/settings/assets unchanged; no install/log request/commit/push. See
`RAINFX_S121_IMMUTABLE_GRAPH_TEMPLATES.md`.

## s120 typed memory input provider (2026-10-17)

Accept typed graph/receipt/provider objects, validate them before GPU submission,
and freeze owned metadata and external input snapshots. Provider views return on
success or failure; retries do not reacquire. Producer graph/uniform/receipt/input
storage is deliberately invalidated immediately after entry. Four disk/provider
and full/lean paths pass1972 commands/196 flights with identical physical work,
allocator decisions and GPU roots equal s119. Each provider path acquires and
returns1245 views over49 snapshots, with zero outstanding views. Fourteen malformed
packet/view/receipt cases fail before submission; the post-commit upload guard
preserves epoch1. An absent-oracle provider run also matches final GPU results.
The fixture adapter still reads files to construct typed producer data; the
entry itself does not. Deep copy/validation is not a CPU/FPS improvement claim.
Next reuse immutable topology templates with per-interval bindings. Live CSP,
physical accuracy/full lifecycle and target timing remain open.
Runtime/settings/assets unchanged; no install/log request/commit/push. See
`RAINFX_S120_MEMORY_INPUT_PROVIDER.md`.

## s119 descriptor/oracle ownership split (2026-10-17)

Execution resources/roots now own only descriptors and GPU handles. Expected
texture arrays live in a separate optional harness; descriptor/input/oracle files
are independent. Only external immutable inputs acquire upload leases, cleared
after submission. The13 paired schedules again pass986 commands/98 flights,
with unchanged physical work and roots equal s118. An extra native run completes
with nonexistent oracle files and zero oracle opens/expected payload; an
independent actual-GPU dump comparison passes. Missing full diagnostics and
truncated input refuse before submission; inherited in-flight guards still pass.
Backend expected-array ownership is zero, not total CPU memory. Test readbacks,
disk fixtures and pipeline setup remain; no game FPS/VRAM or device-loss claim.
Next add an in-memory descriptor/input-provider boundary before live CSP work.
Physical accuracy/full lifecycle/convergence and target timing remain open.
Runtime/settings/assets unchanged; no install/log request/commit/push. See
`RAINFX_S119_DESCRIPTOR_ORACLE_SPLIT.md`.

## s118 lean execution and completion backend (2026-10-17)

Separate optional per-output staging/maps from GPU execution. Thirteen native
schedules pass in both full and lean modes:493 commands/49 flights each, identical
physical work and allocator/publication decisions, and boundary roots equal s117.
Lean mode removes7969 per-flight staging/maps and24765152 cumulative diagnostic
payload bytes in this fixture; explicit test boundary/shutdown audits remain.
A backend-neutral pending/complete/failed contract preserves quarantine through
29 forced pending observations and three reported failures per mode. Failure
never grants retirement; later actual completion permits discard only. Four
fatal-path runs preserve published roots. These are offline protocol/copy counts,
not FPS/peak-memory or real device-loss evidence. CPU fixture oracles still
remain in lean descriptors; separate them next before a CSP adapter. Physical
accuracy/full lifecycle/convergence and target timing remain open.
Runtime/settings/assets unchanged; no install/log request/commit/push. See
`RAINFX_S118_EXECUTION_AND_AUDIT.md`.

## s117 single-flight completion protocol (2026-10-17)

Split native submit, one-shot completion polling and explicit finalization.
One candidate retains its event, graph and all targets until verified completion;
cancel/reset mark it for discard and cannot release or publish it early.
Nine WARP schedules pass356 commands/34 flights:77 premature publication and155
in-flight submit/retry refusals, cancellation/reset before/after observation,
bootstrap GPU-root recovery, pending admission recovery and a partial abort.
All2931 draws/957 copies and5497 readback comparisons match; final roots equal
s116, including ledger/clock/source arrays. Two fatal-path drains preserve the
published roots. Test-only waits/diagnostic staging remain; there is no game
integration, FPS claim or device-loss recovery. Next separate oracle readbacks
from the backend candidate path and validate delayed/failing completion before
a CSP adapter. Accuracy/full lifecycle/convergence and target timing remain open.
Runtime/settings/assets unchanged; no install/log request/commit/push. See
`RAINFX_S117_INFLIGHT_COMPLETION.md`.

## s116 recoverable pending admission (2026-10-17)

Retain one immutable call when capacity is insufficient; retries cannot replace
its inputs or admit newer work. Plan every cache/target change before admission
so refused attempts leave all live ownership unchanged. Four reduced capacities
recover after restoration. Repeated waits, busy/stale/duplicate requests,
cancel/reset before and after initial publication, and a replacement-body guard
pass on native WARP. Recovered final16-role roots match uninterrupted execution,
including water/clock/source arrays. Independent command/admission/root replay
matches all native counters. This is an offline recovery protocol; game physics
remains s87, diagnostics s89. Next split submission from completion/publication
and prove bounded in-flight ownership before a CSP adapter. Accuracy/full
lifecycle, asynchronous/device recovery and target timing remain open.
Runtime/settings/assets unchanged; no install/log request/commit/push. See
`RAINFX_S116_RECOVERABLE_ADMISSION.md`.

## s115 bounded native stream capacity (2026-10-17)

Read one graph per call instead of retaining the entire session. Root oracle
snapshots own their bounded data; statistics/debug history do not accumulate.
Target/input/shader caches have explicit admission limits and evict completed,
unretained resources. Two131-call physical-oracle schedules pass: the steady
tail creates no new targets at194000 nominal bytes; diagnostic cache/descriptor
stress stays within200000 target bytes,24 external entries and64 shaders.
All19955 draws/6216 copies match their oracles, with no checkpoint uploads or
D3D warnings. Four capacity refusals pass; the post-commit target refusal
verifies the incoming GPU roots unchanged. These are bounded offline schedules,
not262 distinct accepted weather frames or game memory/FPS evidence. Next make
capacity refusal recoverable with one retained pending call before CSP use.
Accuracy/closure/full lifecycle, asynchronous recovery and timing remain open.
Runtime/settings/assets unchanged; no install/log request/commit/push. See
`RAINFX_S115_BOUNDED_STREAM_CAPACITY.md`.

## s114 logical-band GPU roots (2026-10-17)

Retain already-produced logical-band export textures across calls, with explicit
shape/origin/owner mappings. Root selection adds no GPU copy or shader change;
protected input links still forbid CPU uploads. Later fresh calls26→23 copies,
two-attempt resumes44→38. Twelve band-policy native calls, eight current parent
fallback calls,192 frozen parent role comparisons, aborted publication and all
seven protocol guards pass. Completion/epoch/cache ownership remains intact.
Finite target creation counts increase with the new descriptor mix, while the
planar stream's reconstructed target byte extents match the parent policy.
Fewer copies do not establish a memory/FPS win. Next bound repeated-session target
capacity/retirement and metadata retention before live integration. Economical
accuracy, physical closure/full lifecycle, CSP recovery and target timing remain
open. Runtime/settings/assets/materials unchanged; no install, repeated logs,
commit or push. See `RAINFX_S114_LOGICAL_BAND_ROOTS.md`.

## s113 cross-call native GPU ownership (2026-10-17)

Keep actual GPU public/private/cache parents across calls, check bundle epochs
and parent extents, and swap all16 logical roots only after complete execution
and GPU drain. Twelve native calls include a refused checkpoint, five aborts,
its GPU-only resume and consecutive curved intervals in both orders.999 draws,
358 copies and1905 output/import/root readbacks match; no checkpoint/produced
texture uploads or debug warnings. Seven stale/partial/upload protocol guards
pass.80 imports borrow retained GPU parents and352 targets reuse completed
free textures. Whole-parent retention adds three band copies on later complete
calls; next compare retained logical-band roots to remove this boundary cost.
Long-run capacity/backlog, economical accuracy, physical closure/full lifecycle,
CSP recovery and target timing remain open. Runtime/settings/assets/materials
unchanged; no install, repeated logs, commit or push. See
`RAINFX_S113_GPU_SESSION_OWNERSHIP.md`.

## s112 persistent native GPU graph (2026-10-17)

Implemented bounded persistent D3D11 WARP graph execution with explicit region
copies, immutable imports, exact-descriptor GPU target reuse, unbinding and
completion-event drain. Six cases run with pooled and dedicated allocation:
926 draws/336 region copies and all1660 core readbacks match the upload oracle,
with zero produced-texture uploads and no D3D debug warnings. Hybrid/copy curved
public packets agree in both orders; refusal/resume budgets, six real command
prefixes and six fail-closed native guards pass. s111's logical copy/pool tradeoff
is retained, not promoted to game FPS/peak-memory evidence. Next retain native
GPU public/private/cache handles across calls and prove failure-safe joint
publication before any CSP integration. Economical accuracy, bounded work,
physical closure/full lifecycle and target timing remain open. Runtime/settings/
assets/materials unchanged; no install, repeated logs, commit or push. See
`RAINFX_S112_PERSISTENT_GPU_GRAPH.md`.

## s111 lifetime-aware hybrid axis inputs (2026-10-17)

Bind the donor force parent on the first executed axis, materialize separate
gather banks on the second. This preserves either axis order, complete fine
ledgers, refusal/resume/publication and checked/full-bank/full-copy fallbacks.
Actual WARP copy-oracle comparisons pass. At symbolic1024x256/4096 heads, one
fresh attempt keeps69 draws and reduces s108's29 copies/116MiB copy output to
23/92MiB, while restoring its141.89MiB exact-size pool instead of s110's149.89MiB.
Second-axis shaders keep the original arithmetic; first-axis bank overhead
remains. Pool replay is a CPU ownership proof, not a live GPU allocator or
measured game improvement. Next validate persistent GPU resource bindings,
copies and safe reuse in a bounded native offline graph before live adoption.
Economical accuracy, physical closure/full lifecycle and target timing remain
open. Runtime/settings/assets/materials unchanged; no install, repeated logs,
commit or push. See `RAINFX_S111_HYBRID_AXIS_INPUTS.md`.

## s110 proven in-grid bank load domains (2026-10-17)

Removed repeated bank checks only for frozen-source/fullscreen/bounded-loop
domains, preserving checked neighbours and untrusted next-source searches.
Edited shaders or incompatible grid metadata fall back to s109.36 axis cases,
20 poisoned-bank/malformed-run cases,8 proof fallbacks and334 GPU copy-oracle
comparisons preserve output/loss/refusal/retry/publication behavior. Static
map/leaves/gather/end-gather lines331/175/262/250 to304/149/233/217. Resource
costs remain s109, including the8MiB parent-retention pool regression; no game
speedup claim. Next compare donor-first-axis direct binding with copied second-
axis input in a lifetime-aware hybrid policy. Live allocation/retirement,
economical accuracy, physical closure/full lifecycle and game timing remain
open. Runtime/settings/assets/materials unchanged; no install, repeated logs,
commit or push. See `RAINFX_S110_PROVEN_BANK_LOAD_DOMAINS.md`.

## s109 checked bank-aware axis inputs (2026-10-17)

Bound parent textures with logical row origins for integer end/mean axis loads,
retaining zero-border/mip isolation and a full-copy fallback. Ten coordinate
cases, nine host guards,36 axis cases and actual GPU copy-oracle comparisons
retain numeric/physical/retry/publication behavior. Logical copies29 to17 and
copy output116 to68MiB per symbolic default attempt, but exact-size pool
reservation141.89 to149.89MiB and shader arithmetic increase. Keep the checked
ABI as an offline correctness reference; performance adoption is not approved.
Next prove in-range load domains before specializing away redundant checks,
then re-evaluate arithmetic and retained-parent costs. Live allocation/retirement,
economical error estimation, physical closure, live lifecycle and game timing
remain open. Runtime/settings/assets/materials unchanged; no install, repeated
logs, commit or push. See `RAINFX_S109_BANK_AWARE_AXIS_INPUTS.md`.

## s108 explicit bank-copy target lifetime proof (2026-10-17)

Recorded six real s107 draw graphs and modeled packed CPU row-band views as
explicit copy targets, rather than free GPU SRV offsets. Exact-descriptor pool
replay preserves all consumers/retained exports and caller inputs at every
failure prefix; alias/overwrite/stride guards and real PendingPass checks pass.
At symbolic1024x256/4096 heads, one fresh attempt reserves141.89MiB new targets
versus333.08MiB without reuse, including conservative copies. These are logical
subgraph budgets, not measured game memory/FPS. Copy output alone is116MiB and
diagnostic retention grows with attempts; live adoption remains blocked. Next
verify a bank-aware input ABI against explicit copies before live allocation/
retirement. Triple stepping, economical error estimation, physical closure,
live lifecycle/recovery and target timing remain open. Runtime/settings/assets/
materials unchanged; no install, repeated logs, commit or push. See
`RAINFX_S108_TARGET_LIFETIME_AND_REUSE.md`.

## s107 last-axis mean gather omission (2026-10-17)

Removed final mean gathers only where compact coarse/first-fine post no longer
consumes them. First-axis means, all mean-dependent maps/losses, second-fine
published mean and complete fine ledgers remain.36 axis comparisons and actual
curved/both-order/fallback/refusal/retry/ownership/fence checks match s106.
Default target extent shrinks by8MiB per attempt at1024x256; static gather
lines199 to191 and load lines12 to10. Draw/cache counts are unchanged; target
GPU benefit is unmeasured. Next prove bounded render-target lifetimes/reuse
across candidate stages, retry checkpoints and pending publication before live
allocation. Triple stepping, economical error estimation, physical closure,
live lifecycle/recovery and game timing remain open. Runtime/settings/assets/
materials unchanged; no install, repeated logs, commit or push. See
`RAINFX_S107_LAST_AXIS_MEAN_ELISION.md`.

## s106 first-fine final mean omission (2026-10-17)

Removed only the first fine final mean and its post texture read; all donor/
travel means, four reduction banks and six physical total rows remain. The
second fine retains its full published mean.22 component cases and actual
curved/accuracy-refusal/source/pool/retry/ownership/fence checks match s105,
including complete fine ledgers, errors/control and full fallback. One post
bank saves4MiB of target extent per embedded attempt at1024x256; post static
lines271 to260, block70 unchanged. Draw/cache counts stay fixed; target GPU
benefit is unmeasured. Next evaluate last-axis gathered mean omission only
where post no longer consumes it, retaining all maps and mean runoff losses.
Physical closure, economical error estimation, live lifecycle/recovery and
game timing remain open. Runtime/settings/materials/assets unchanged; no
installation, repeated logs, commit or push. See `RAINFX_S106_FIRST_FINE_MEAN_ELISION.md`.

## s105 compact unpublished coarse candidate (2026-10-17)

Removed unused coarse final mean and applied/wall diagnostic outputs while
retaining donor travel mean, end, evaporation/runoff and failure status.
Complete fine ledgers/publication remain intact; accuracy-off and explicit
full diagnostic fallback retain all outputs.22 component cases and actual
curved/retry/ownership/fence gates match s104 for consumed results and decisions.
Force/post targets shrink by12MiB and block target by32KiB per coarse trial at
1024x256; cache/draw counts are unchanged. Static force/post/block work decreases,
six-pixel total branching increases; no measured game-time benefit. Next remove
only the unused first-fine final mean while preserving its complete ledger.
Physical closure, economical error estimation, full live lifecycle/recovery and
game timing remain open. Runtime/tuning/assets/materials unchanged; no install,
repeated game logs, commit or push. See `RAINFX_S105_COMPACT_COARSE_CANDIDATE.md`.

## s104 shared local recipient/post metric (2026-10-17)

Shared one normal/area/geometry-validity result inside the fused recipient/post
invocation. Kept force-only parameter validation separate, preserving post
evaporation/projection when viscosity/air/Cf/research depth is invalid.20 physical
cases and standalone wrapper checks match s103. Actual curved accepted embedded
publication/error indicators, accuracy-only refusal, source/pool retry and
ownership/fences also match. Static fused instructions302 to271, texture-load
lines12 to9; donor/preparation work, cache extent and draw counts are unchanged.
Per-bank output invocations and triple-candidate cost remain. Next specialize
unused coarse-candidate outputs/ledger work while retaining full fine budgets,
identical error/admission and retained-time behavior. Physical closure, live
lifecycle/recovery and game timing remain open. No runtime/tuning/assets/material
change, install, repeated logs, commit or push.
See `RAINFX_S104_SHARED_RECIPIENT_METRIC.md`.

## s103 cached physical metric and independent validity (2026-10-17)

Reused interval-owned U/V bases in donor/recipient force and post metrics,
preserving normal/area/SI expressions. Independent finite-basis flags prevent
an inverse-Gram failure from incorrectly erasing a usable physical normal;
format2 rejects old pending caches without consuming water/time. All15 physical
and26 projection comparisons, actual-mesh joint budgets, source/pool retry and
pose/receipt/fence tests match the previous oracle. Cache remains12MiB+144B
at1024x256, with unchanged setup/draw counts. Static force instructions238 to221,
recipient/post338 to302; setup63 to65. These are not target GPU/FPS results.
Next share the local metric inside recipient/post while keeping geometry and
force validity separate, then continue economical material error estimation.
Physical closure, full lifecycle/backlog/recovery and game timing remain open.
Runtime, tuning, assets/materials unchanged; no install/log request/commit/push.
See `RAINFX_S103_CACHED_PHYSICAL_METRIC.md`.

## s102 interval metric cache and ownership (2026-10-17)

Prepared frozen world U/V bases and the original Gram values once per interval,
then reused them for both axes, coarse/fine trials, refusals and resumed calls.
Kept the original projection operation order; all26 specified axis comparisons
and complete physical/source/pool publications match s101. A nine-row receipt
binds physics/metric headers, grid/format/readiness, full pose and both batch
rows. Changed pose with unchanged version refuses without spending owned time;
fresh intervals rebuild, and pending preparation/publication retains handles.
Costs2 setup draws and12MiB+144B at1024x256; fresh/reused embedded graphs are
18+51A /16+51A. Cached map removes repeated basis/Gram solves but adds loads;
dry/sparse setup and target GPU timing remain tradeoffs. Corrected the static
assembly parser's omission of parenthesized opcodes; preserved s101 evidence
and recorded the recount. Next reuse owned bases in force/post geometry, then
continue economical material error estimation and live lifecycle/backlog.
Runtime/tuning/assets/materials unchanged; no install/log request/commit/push.
See `RAINFX_S102_INTERVAL_METRIC_CACHE.md`.

## s101 metric/map fusion and occupancy cost (2026-10-17)

Folded the standalone world-mean to UV-velocity projection into both axis maps.
All26 specified axis comparisons, actual curved publication, accuracy refusal,
source/pool/retry and stale-receipt/pending guards match s100 bit-for-bit.
One embedded attempt73 to67 draws (three187 to169), two velocity outputs removed.
Source-level projection counts depend on wet occupancy: the actual initial
patch uses0.875x the old queries, but fully wet film uses2.983x. Static DXBC code
also expands; fewer draws are not evidence of faster game execution. Keep the
equivalent offline alternative and next implement frozen-interval metric reuse
with explicit pose/receipt ownership. Cheap error estimation, physical closure,
full lifecycle/backlog and target game timing remain open. No runtime/tuning/
assets/material change, install, repeated game logs, commit or push. See
`RAINFX_S101_METRIC_MAP_FUSION.md`.

## s100 fused coupling and proxy evaluation (2026-10-17)

Fused recipient force and post projection/evaporation; keep the transported
full-interval mean and the original impulse summation order. Specified direct,
actual curved-mesh and source/pool/retry transactions match s99 bit-for-bit;
pending publication retains caller handles. One embedded attempt76 to73 draws,
three196 to187; recipient/post output targets8H to5H. No measured game speedup
or peak-memory claim. Two-pass depth/drag proxies are implemented as diagnostics:
drag-only misses a2.20% force-free remap difference; depth-only refuses exact
evaporation even after refinement. Neither replaces accuracy admission.
Next compare fused metric projection/map costs and investigate a material
transport/coupling defect estimate. Triple stepping, physical closure/full
lifecycle/backlog and game timing still block runtime adoption. Runtime,
settings/assets and user materials unchanged; no install/log request/commit/push.
See `RAINFX_S100_FUSED_COUPLING_AND_PROXY.md`.

## s99 temporal coupling corrections and accuracy reference (2026-10-17)

Reproduced s98's10.45% counterexample and isolated depth/force feedback from
fixed-height/force-free/sweep-order counterfactuals. Found a discontinuous50%
face-speed drop when any tiny slow volume wets a neighbour; use symmetric
conserved-volume weighting. Also split physical end force before/after remap,
relaxing incoming water at recipient depth while preserving exact frozen-depth
full-interval mean travel. Analytic stiff response, face continuity, physical
budgets and source/receipt/fence guards pass offline. Original2%/5% naive
controller's21-rejection blocked case is archived with unchanged time debt.
New positive embedded comparison publishes two admitted half steps and their
combined ledger; geometric/accuracy failures retain full trial debt. Candidate
adds1 draw per physical step (38 for one); unconditional embedded reference
uses76 for one attempt and is not game-ready. Corrected coarse/finer sensitivity
is6.24% in the specified case (six accepted finer steps); no final time order
or exact physics claim. Next reduce coupling/error-estimator cost with a depth/
deformation predictor and fuse recipient force/post before full lifecycle,
backlog/recovery and game timing. No runtime/tuning/assets change, game logs,
install, commit or push. See `RAINFX_S99_TEMPORAL_COUPLING.md`.

## s98 positive reconstruction and multi-cell remap (2026-10-17)

Implemented limited volume reconstruction and source-local shared wet-face maps,
paired end/mean gather and explicit boundary loss. Multiple cells can be crossed
without a global outgoing<=0.8 limit. Whole-image next-wet ordering also refuses
overtakes that would tunnel through water and completely out of the boundary.
Independent integrals/static/symmetry, pre-contact fronts, compression refusal,
real viscous retry/source-once/receipt guards and actual curved budgets pass.
Specified128-cell Gaussian L1 improves from s97's0.05917 to0.000109;64.4-cell
translation retains the same fixture source-test count as0.4cells.
Actual100um/40m/s film crosses6.8cells in one step, but differs from four-piece
volume by10.44% (two-piece request needs3 accepted steps/1refusal, difference
6.66%). Conservation and large-C admission do not establish coupled time accuracy.
Graph16+21A draws; not adopted. Next isolate temporal error and compare conservative
stiff-aware force/transport predictor or symmetric composition before lifecycle,
recovery and fusion. No game FPS claim, runtime/tuning/assets change, install,
reload/log request, commit or push. See `RAINFX_S98_MULTICELL_RECONSTRUCTION.md`.

## s97 resolved physical-area transport reference (2026-10-17)

Implemented positive unsplit local donor flux over actual cell areas, current
SI force and end/mean momentum, recipient wall/evaporation and explicit runoff.
GPU outgoing<=0.8 admits steps; rejection retains exact interval debt and retries
without publishing provisional forces/losses. Random signed flux/holes/runoff,
static identity, smooth spatial/time refinement and transaction guards pass.
Actual4251-cell curved20ms fixture accepts2x10ms, maxOutgoing0.6585, water residual
-8.98e-7mm3, momentum residual<4.85e-8; rigid world rotation passes.
Graph16+11A draws vs s96's17+33A. This is not game timing: first-order profile
diffusion remains5.9% L1 in the finest smooth fixture, and a100um/40m/s held
equilibrium needs16 global dyadic substeps at60Hz (192 unfused draws). Do not
adopt this reference as the game default. Next compare positive reconstruction
and multi-cell resolved transport on interacting/compressive fronts, assess the
high-shear force regime, then lifecycle/backlog/fusion. No runtime/tuning/assets
change, install, reload/log request, commit or push.
See `RAINFX_S97_RESOLVED_AREA_TRANSPORT.md`.

## s96 recurrent curved SI/height/evaporation (2026-10-16)

Each GPU-plan substep recomputes current physical depth and exact frozen-height
SI end/mean momentum; recipient tangent projection and evaporation feed accepted
applied/wall/loss budgets. Rejected force/evaporation never reach stock/ledger.
Force/metric versions and immutable snapshots bind pending work and final receipt.
Analytic30/60/144Hz force and drying ODE checks pass; actual4251-cell curved
two-step fixture has water residual-8.83e-7mm3, momentum residual<5.65e-8,
split/together identity and rigid world-rotation checks passed.
Explicit adoption blocker: one coherent numerical point's .7/.3 volume images
receive different resolved thickness drag (.022477m/s velocity spread); its
physical footprint/coverage is undefined. Do not invent an aggregate area or
restore rejected fixed-width/mixed-moment closures. Next compare resolved-area
bounded transport, then full lifecycle/backlog/recovery and pass/storage fusion.
Unfused17+33A draws; no game cost claim, runtime/tuning/assets change, install,
reload/log request, commit or push. See `RAINFX_S96_RECURRENT_CURVED_PHYSICS.md`.

## s95 interval transaction and retained time (2026-10-16)

Immutable epoch/generation-bound supply and production-layout P4b events stage
once into private field/head/budget banks. GPU-plan retry subdivides rejected
time, keeps accepted checkpoints across calls and publishes the whole original
interval's stocks/ledger/clock only after completion. Exact2^20 dyadic ticks
prevent tiny time debt loss; one-tick rejection remains explicitly blocked.
Specified1s compression rejects then finishes via2x0.5s; split/together host
scheduling is bit-identical. Duplicate/stale/source-invalid intervals, pending
output fences, reset epochs and bounded counters pass offline. Precise Kahan
intermediates preserve long clock and packet budget additions under FXC.
This is protocol/head-packet staging, not live P1/P2 lifecycle integration or
general physical/time convergence. Unfused graph14+28A draws for A attempts
requires fusion; no game performance claim or runtime/tuning/assets change.
Next: per-substep SI/height/head coupling and bounded live input/recovery, then
physical convergence and fusion. No reload/log request, commit or push.
See `RAINFX_S95_INTERVAL_TRANSACTION.md`.

## s94 two-axis coherent positions and source validation (2026-10-16)

Carries point X/Y offsets through both axis gathers with complete2x2 image and
mass-ratio certification. New supply, asymmetric evaporation/P4b-like removal or
momentum edits invalidate all old image copies; uniform proportional removal
retains coordinates. Fixed GPU two-axis publication rolls back end/mean/history
and suppresses provisional runoff if either axis rejects. Planar fractional
point30/60/144Hz in both sweep orders, transpose/reflection, mixed static identity,
source mutations and actual4251-cell SI frozen-step budgets pass offline.
Dense mixed actual film retains zero coherent points; no dense-film shape claim.
Transport20 standalone steady draws; SI/mean projections estimate25 before
fusion, diagnostic loss probes excluded. Generation/source/head/clock transaction,
rejected elapsed time, recurrent force/height and general convergence/cost remain
open. No production/tuning/assets change, reload/log request or commit/push.
See `RAINFX_S94_TWO_AXIS_COHERENT_HISTORY.md`.

## s93 compressible transport and coherent positions (2026-10-16)

Removed s92 hard width using resolved-cell pressureless projection/positive CIC
deposit. Source end/mean momentum stays intact until actual-volume gather;
10x smaller dt gives10.002x smaller velocity change in the impulse fixture.
Same actual-mesh4251-cell100um SI patch now accepts both axes: water residual
-2.304e-7mm3, momentum+outflow+wall<2.794e-9 packet units;149 newly wet cells.
Resolved compact translation profile L1 .1845/.2282/.8382% at30/60/144Hz passes
the specified2% gate. General material moment history fails mixed static state
(.06555mm3 L1 movement of .2mm3); resolved-only collapse has~100% profile error
at144Hz. Added complete-CIC-image coherence before retaining lump position:
mixed static identity and specified repeated1D collapse pass (profile L1=0 in
that grid-aligned final-point fixture); fractional point position error<7.33e-6.
One point/source reduces arrays66->33 and output2H->H. Axis8 passes, coherent
history+1; estimated two-axis+SI21/23 before cross-axis history implementation.
General pressure/contact-line/force and source/P4b/clock transaction, large-group
elapsed time and actual cost gates remain open. No runtime/tuning/assets change,
no reload/logs requested. See `RAINFX_S93_COMPRESSIBLE_TRANSPORT.md`.

## s92 contact and subcell support (2026-10-16)

Added offline preserved-width inelastic contact candidate with bounded33-source
local PAVA/16-member certificates and paired end/mean momentum. Moving-vs-static
60cells/frame contact now agrees with whole-run CPU reference in +/-X/Y; no
nearest-donor vacuum stagnation. Fractional wet support must persist: resetting
it every frame gave8.75% repeated-contact profile error at144Hz; carrying it gives
.000123% or less in the specified30/60/144Hz frozen planar fixture.
Post-gather GPU tile/whole-axis admission selects original end/mean/support and
zero signed runoff on unsupported disjoint unions, preserving all three banks.
Component boundaries and uniform1024-cell +/-60.25cell travel pass.
Hard-width contact is NOT adopted for general film: the actual curved100um
4251-cell wet patch rejects all cells through large/inconsistent contact groups.
It forbids the longitudinal compression/thickness changes film needs; raising
the cap is not a pressure/contact-line model. Keep support/publication primitives,
replace this closure. General2D/disjoint support and full app transaction remain
open. Separate axis13 passes; estimated two-axis+SI29 before2D support closure,
larger payloads and no measured game ms; no low-cost claim or runtime change.
No reload/logs requested. See `RAINFX_S92_CONTACT_AND_SUBCELL_SUPPORT.md`.

## s91 dry-front and paired momentum transport (2026-10-16)

From user-stamped s90 commit2c192e3, added offline bounded nearest-wet numerical
velocity extension within connected runs, with metric axis-speed compensation.
No dry mass/momentum is generated; wet/pinned velocities remain bit-identical.
End and interval-mean world momentum share hierarchy/admission/remap weights;
transported means rebuild the second split axis rather than reusing stale/end
velocity. Isolated +/-X/Y four-cell fronts and end/mean diagonal test pass.
Force-free compact pulse at equal0.1s30/60/144Hz: worst profile L1 .4072%,
centroid error2.65e-5cells. Actual-mesh sparse100um SI step newly wets149 cells,
volume residual-3.97e-8mm3; physical momentum+outflow+wall residual<2.21e-9.
High-C moving-vs-stationary fronts fail: frozen nearest-donor switch creates
false stagnation before contact; rejected candidate holds both payloads/loss0.
Next is dynamic front interaction/contact closure, then app transaction/fusion.
Extension scratch raw proposal4.265625MiB, paired output2H; current standalone
factory23 steady-equivalent draws requires cost reduction before runtime use.
No actual game ms measured, no runtime/tuning/assets change, no reload/logs needed.
See `RAINFX_S91_DRY_FRONT_AND_PAIRED_TRANSPORT.md`.

## s90 velocity characteristics and curved transport bridge (2026-10-16)

Implemented offline sampled-velocity characteristic intervals: exact piecewise
linear frozen-field integration, affine-block skips, connected row/column clips
and explicit runoff prevent crossing holes. Added positive limited-linear source
reconstruction; equal0.2s prescribed-density profile L1 at30/60/144Hz is at most
.1583%, with centroid error4.65e-5cells. This is not coupled film time convergence.
GPU axis admission rejects bad/status/unordered intervals before recipient work,
keeps old packets/zero loss; full app head/source/clock transaction remains open.
Actual-mesh synthetic100um SI-force/pool-debit bridge: volume residual6.96e-7mm3,
momentum+outflow+wall residual<1.14e-8 in packet units, display independent.
Dry-cell zero velocity creates a false front stagnation layer (100→100.8647 versus
104-cell uniform free-flight reference). Implement physical dry-front extension/
closure before game adoption. Six operator passes/axis plus predictor/packet/
velocity stages need fusion/cost gates; no game ms measured. Runtime/tuning/assets
unchanged, no reload or repeat logs requested. See s90 topic document.

## s89 video review and positive overlap remap (2026-10-16)

Supplied18.833s video shows a translucent purple field/green head diagnostic.
Direction response is expected from current gravity/inertia/air projection;
background transmission and mesh extent cannot certify water thickness or time
accuracy. Added view6 with the same RGB channels at alpha1 in this rain pass;
later visor optics remain. View5/normal/head+film s87 bit-equivalence, scene
independence, native/depth and full /WX GPU gates pass; no new pass/storage/API.
Offline source-local interval overlap avoids s88 negative-stock/global-prefix
thin-translation failures. Eight GPU arithmetic groups pass, but physical
trajectories, curved holes, variable-flow time convergence and atomic integration
are pending. Three remap passes/axis excluding mapping; hierarchy reduces typical
visits but adversarial broad overlaps remain N^2/row. No performance guarantee,
no physical runtime/tuning change or repeated game log matrix requested.
See `RAINFX_S89_VIDEO_AND_POSITIVE_REMAP.md`.

## s88 film transport candidate gates (2026-10-16)

Offline finite-inertia predictor + paired momentum gather passes frozen-height
30/60/144Hz analytic motion, UV/rotation, production volume gather, planar momentum
and evaporation/new-stock tests. It needs8MiB/+2 passes but warm supplied peak-scale
estimates still give C16.37/58.44: inertia alone does not solve transport-time loss.
A tiled-prefix long-travel reference handles uniform +/-60.25-cell translation
and boundary runoff, but arbitrary face travel creates negative stock and global
float32 prefixes misplace thin packets behind large stock. Neither candidate is
adopted. Next remap gate requires noncrossing characteristics/conservative overlap,
local thin-stock precision, paired momentum/volume and bounded resource cost.
All production runtime/tuning/assets remain staged s87; no install or repeat game
log matrix requested. See `RAINFX_S88_FILM_TRANSPORT_CANDIDATES.md`.

## s87 P4b game review and same-UV link view (2026-10-16)

Supplied paired stationary/137kmh P4b snapshots pass water balance: cumulative
relative residual6.99e-7/1.72e-6, mixed transition interval2.05e-6. Internal return
9.39/306.87mm3; maximum field height.474/.874mm and no >1mm stock. Limited film
mass11.75/17.25%, velocity retention91.84/86.28%. Earlier P4a snapshots had different
accumulation/source history, so comparisons are qualitative rather than matched ratios.
Approximately40s P4b OFF/ON captures show67/67FPS, Memory82.52/85.99MB; no observed
incremental FPS loss, no leak conclusion from single Memory samples.
User video uses head-only display scale2 and WF slope debug2. Actual GPU same-head
tests confirm shared position/segment/time and invariant trail transfer across head
display gains. P1 head dynamics and P4 quasi-steady field motion/optics are still
different laws; existing-head wet-path feedback/absorption/shared optical normal
remain incomplete. Do not dismiss separation as merely a debug setting.
Added P3 view5 (red film/green displayed head/blue micro), no physical changes or
new canvas/pass. Full shader /WX and s86 normal-output equivalence pass; preserve
the user's BODY_FABRIC_CULL material addition. See `RAINFX_S87_P4B_GAME_REVIEW.md`.

## s86 P4b conserved localized pool return (2026-10-15)

From user stamp a23527e, added default-OFF P4b pool return to the actual P2/P3
pipeline. One bounded region pass reads only the previous published field;
unique rotating free-slot ownership preserves same-frame rain-head priority.
Five-row events retain the original incident centre and internal return volume.
Head, donor flux, field debit and P2/P3 ledgers share the event and atomic publish.
Fixed slot-group/region rotation aliasing at4096. Added last-step view4 marker;
current-field Courant estimates ignore already-debited/speculative pool events.
Extra payload16KiB+16*slots (+80KiB at4096), +1 pass, no steady readback/CPU loop.
Production /WX WARP8 gates, actual-mesh synthetic pool probe, eight nonempty
P4b-OFF bit-equivalence cases, full optics/depth/native gates, P3/P4 numerical
regression13/9, actual Lua13 pending points/40 toggles pass.
Game classification/cost/limiter improvement pending. Broad film pressure/inertia
transport and long-session float32 gates remain open. Existing tuning preserved.
See `RAINFX_S86_P4B_POOL_RETURN.md`.

## s85 P4 regime diagnosis and pool transfer prototype (2026-10-15)

Supplied paired stationary/137km/h snapshots confirm49.0823%/44.8306% of film mass
is in CFL-limited cells; mass-weighted model velocity retention52.0827%/59.7221%.
Worst-C cells have full coverage/coating, normal .37mm2 area/.58mm stride/~9m/s2
tangent acceleration, but5.17–11.91mm columns. Equivalent sphere diameters of their
local masses are1.54–2.03mm: do not shrink physical diameters/display gain.
P4a quasi-steady h^2 mobility and missing localized pooling/phase redistribution
are outside the intended regime; conservation still passes, transport-time gate stays open.
Offline /WX WARP prototype passes6 localized pool-to-free-head volume/ownership/
actual donor-gather gates, including full slots/rain priority/sheet rejection.
Bounded integrated candidate+P2 event expansion estimates+1 pass/+80KiB at4096,
not measured game ms. P4b runtime integration still requires preserved incident
position, internal-return counter, paired field/flux debit and atomic publication.
Runtime/tuning/installation unchanged. No further identical logs requested.
See `RAINFX_S85_P4_REGIME_AND_POOL_TRANSFER.md`.

## s84 P4a game review (2026-10-15)

After a continuous replay session warm-up >30 minutes, supplied P4 stationary/
137 km/h budgets pass: max stable-interval relative error2.77438e-5, residual
.079355mm3. Recompute intervals from cumulative snapshots because intermediate
button clicks are omitted. User observes comparable P3/P4 FPS in supplied60%.
P4 transport-time accuracy fails: raw Courant568..97620, limited cells0.626..1.401%
but their film inventory reaches986mm3. Flow/water logs differ in frame, so exact
limited mass shares require paired snapshots. Real-mesh100/1000um unit probes
show max C5.38/538 even with correct SI units and gravity only.
Added manual16-float thickness/limited mass/argmax cell metric logs and same-frame
budget+flow button requests. Steady physical shaders/prepare/publish and tuning
remain unchanged. P4b model choice follows peak-height/metric/retention evidence;
long precision and100%/4096 workload gates remain open. See `RAINFX_S84_P4_GAME_REVIEW.md`.

## s83 P4a film transport preview (2026-10-15)

Added opt-in donor/upwind film transport from the shared P1 world transform,
gravity/inertia and local air/downward settings. Four stored directional fluxes
are gathered in the existing P3 resolve; unsupported recipients record runoff.
One extra steady pass and4.00MiB flux storage, no CPU drop loop or draw pass.
Courant0.8 limits positivity and can slow physical time; manual-only max/limited
cell/volume logs expose that limitation. Micro stays pinned until joining film;
head reabsorption, pressure/contact-line solver and children remain deferred.
Compensated manual snapshots improve reduction precision without extra steady
storage; persistent float32 accumulation remains an open long-run gate.
WARP9/P3 GPU13/Lua pending/ownership/40-toggle fixtures pass. Game cost/CFL/look
validation is next; P4 remains OFF by default. See `RAINFX_S83_P4_FILM_TRANSPORT.md`.

## s82 P3 game review (2026-10-15)

Supplied six 60% stationary/137 km/h logs pass water conservation: maximum
stable-interval relative error2.04288e-5, cumulative residual .070037mm3 at29.915mL.
Normal/film-height images show spatial water and lens regions; reviewed timestamped
samples of both16-second videos. Individual head/trail continuity remains unresolved.
Reported P2/P3 66/65FPS is within roughly1FPS measurement uncertainty.
100 production mode-reset fixtures keep live-bank counts constant and release all
banks. Follow-up actual replay Memory ranges show no sustained accumulation over
3 minutes or up to40 P3 toggles: P2 minimum66→66MB, P3 minimum68.98→62.13MB;
toggle reference64.33MB, after5 toggles67.76MB, after40 toggles64.45MB.
Startup-dependent declining P3 minima and33.3ms sampling limit interpretation;
the observed-range memory check passes, not a universal leak-free certification.
Long production float32 arithmetic stress identifies a precision limit beyond the
short original test; compensation storage/bandwidth must be evaluated with P4.
No runtime/tuning changes in this review. Active transport/drainage/reabsorption,
long precision and10-minute/100%/4096 memory/cost gates remain open. See `RAINFX_S82_P3_GAME_REVIEW.md`.

## s81 first P3 spatial water preview (2026-10-15)

Continued from user stamp 1ad4a95 (P2 Conservation Passed). Added opt-in
1024x256 spatial incident film/micro/capacity water and same-frame conserved
head trail debit. Integer tent/segment integration, boundary halo/coverage,
micro-to-film joining, previous-field wet impact and explicit head/field
evaporation/runoff now feed physical micrometre optics. No Smear/legacy film.
Eleven pending points preserve all read banks; metadata scratch ownership is
exchanged only on atomic publication. Whole-field budget reductions/readback
run only on a manual request, with matching published source counters.
Raw added storage is about 17.856 MiB and six steady passes; actual game cost
and visual quality are pending. WARP/production lens/Lua/regression gates pass.
Active field drainage/advection and reabsorption remain deferred; long-rain
field accumulation is a known limit of this first preview.
See `RAINFX_S81_P3_SPATIAL_WATER_PREVIEW.md` for the first game gate.

## s80 follow-up: P2 actual-game conservation passed (2026-10-15)

Six corrected-game snapshots at cumulative 53.512–67.533 mL input show absolute
residual ≤.003304 mm3. The four stable stationary/100–150 km/h straight intervals
have relative residualDelta/input ≤6.09135e-6, below the 1e-4 design criterion.
Observed rates are 43.917926/82.924185 mm3/s and 5.767867/14.587958 arrivals/s;
film+micro receive 20.64465%/29.10952% of the stable-interval input.
P2 conservation gate passed for the supplied conditions; no runtime/tuning changes.
P3 spatial deposition, same-frame conserved trail, physical film optics and
evaporation/runoff are now the next stage. Historical reserve totals must not
be injected as current field water; field version/epoch starts with an explicit reset.
Absolute material/weather calibration and P3 rendering remain unverified.
See `RAINFX_S80_P2_GAME_REVIEW_AND_MERGE.md` §7.

## Initial s80 delivery: P2 game review and SI merge correction (2026-10-15)

User stationary app OFF91–94FPS, P1/P1+P2 both72–73FPS (+2.710–3.251ms whole app);
P2 incremental cost is unresolved at this measurement precision. Actual cumulative
budgets show residual -4.332008/-1.903673mm3 and film/micro reserves are still invisible.
Reviewed timestamped samples of four supplied videos and estimated source incidence.
Reproduced curved-metric one-sided SI merges and departed-partner exit double accounting.
State/meta now share a symmetric distance and require both supported positions.
Added committed simulation time/interval rate logs; no new GPU pass or per-drop CPU work.
Actual shader /WX WARP cases and s79 numeric/wiring regression pass. Corrected game
conservation gate is required before P3 spatial film/micro/trail rendering.
See `RAINFX_S80_P2_GAME_REVIEW_AND_MERGE.md`.

## Latest s79 GPU physical birth and source budget (2026-10-14)

Started from user stamp acc0c63. Added opt-in P2 physical-area/outward-normal
arrival sampling, estimated virtual impact and shared-generation state/meta
commit. GPU cumulative reserves/exit/inventory balance are atomically
published with source/state; pending steps and stale readbacks are isolated.
Display-only P2 compensation, small offline LUTs and async asset checks are
connected. /WX WARP and actual Lua wiring checks pass, including 4096 events,
volume/momentum/normal/reference invariants, P2 OFF identity and long-session
sum compensation. Game input direction/look/cost verification is next;
film/micro are reserve totals pending P3 spatial water/evaporation/optics.
See `RAINFX_S79_GPU_PHYSICAL_BIRTH.md`.

## Latest s78 P1 game result and P2 birth diagnostic preparation (2026-10-14)

User stationary same-scene FPS 93 app OFF, 71 legacy, 76 P1: estimated
whole-app frame costs +3.332/+2.405 ms. P1 pinning/direction/display-gain
independence pass qualitative review. Immediate centre weaving remains
open; current small physical sizes give viscous relaxation below one frame.
Added opt-in airborne DSD/normalized reference-plane flux/normal-impact
diagnostics with probability/volume/impulse and allocation invariants.
Accepted P1 physics/shader/settings hashes are unchanged. GPU birth event
commit, material impact calibration and P3 conserved film remain next.
See `RAINFX_S78_BIRTH_DISTRIBUTION_AND_BUDGET.md`.

## Latest s77 P1 persistent SI motion preview (2026-10-14)

Connected true volume/mm3, SI contact forces and world gravity/inertia to
persistent state/meta with independent head display gain. Opt-in preview
defaults OFF and omits Smear/legacy film/trail/wipe/splash/micro/haze. Mode
changes dispose banks and reject stale epoch readbacks. Active state/meta
entries now use initialized single-exit external programs, resolving the
reproduced X4000 without warning suppression. /WX WARP checks cover legacy
OFF identity, SI codec/rotation/display invariance, V/momentum merge and
the macro variants; LuaJIT wiring checks cover pooling/reset/publication.
Game qualitative motion/display validation is recorded; weaving/friction,
driving cost and P2/P3 supply/impact/film remain next.
See `RAINFX_S77_SI_MOTION_PREVIEW.md`.

## Latest s76 SI core primitives and observed inertia (2026-10-14)

User stationary G=0 and acceleration/braking Z signs establish gravity-free
car acceleration; adapter now exposes its reversed world vector as inertia.
Added the P1 shared GPU primitives for true volume/mass, contact-cap shape,
static/dynamic pinning, cap air drag, stiff viscous/contact integration, SI
Jacobian projection and volume/momentum merge. FXC /WX + D3D11 WARP checks
pass, including display/UV independence. Persistent state/renderer binding,
DSD/virtual impact and conservative film remain subsequent implementation.
See `RAINFX_S76_SI_CORE_PRIMITIVES.md`.

## Latest s75 P0 weather inputs and physical units (2026-10-14)

Started implementation from user-published 3975491 on the physics branch.
Added an independent allocation-bounded weather/phase observer and physical
unit/contact-cap helpers, connected to an explicit RainFX P0 diagnostic panel.
Valid zero/fallback, kPa/Pa, snow/sleet/hail transitions, raw G/world basis and
skewed geometry metrics have LuaJIT fixture checks. Companion modules are
installed with hash-guarded copies. Existing physics/shaders/tuning remain
the baseline while P0 observes actual G/wind/metric inputs. Stationary,
accelerating and braking snapshots requested before SI inertia activation.
See `RAINFX_S75_WEATHER_INPUTS_AND_UNITS.md`.

## Latest s74 Core implementation scope and branch (2026-10-14)

The user preserved the legacy at commit 0c092e0. Implementation now targets
`codex/rainfx-physics-weather`, derived from that commit. First build the
physical drops, virtual impact, flow and volume-based trail/rivulet/sheet.
Exclude Smear from the core path and do not port legacy local impact film.
Keep physical impact/deposition; evaluate correction effects only after the
core water behaviour and rendering have been reviewed. Smear remains a
possible removal, not a decision to delete its legacy code now. Updated s73
scope accordingly. This step changes documentation only.
See `RAINFX_S74_CORE_IMPLEMENTATION_SCOPE.md`.

## Latest s73 Physics/weather refactor design (2026-10-14)

Design only; runtime and user tuning unchanged. Verified the user's updated
6 px/mm at 4096x1024 reference. Audited mixed SI/normalized masses, reference
force/speed calibration and trail-only diameter x3. Proposed volume-based
surface state, contact-angle pinning, independent display-size gain,
filtered CSP weather/phase adapter, estimated DSD/flux and birth-only
virtual impact. Track water and RH have separate physical roles; effect
gates share actual local water state. Reuse existing GPU slots/sparse
sweeps; film transport/absorption/children follow explicit cost gates.
s72 remains the live implementation until the staged model is implemented.
See `RAINFX_S73_PHYSICS_WEATHER_REFACTOR_DESIGN.md`.

## Latest s72 Trail sampling/model calibration (2026-10-13)

User confirms current head/micro size profile is appropriate, but observes rough
traces and no thick-film response at those diameters. Reproduced segment phase
resets and unresolved noise/ripple frequencies; added carried generation phase,
projected pixel integration/bandlimit and a half-history-texel derivative floor.
Water-model diameter ×3 / thin-output compensation 1/3 retains accepted head,
micro and thin/wipe sizes; developed sheets use model width and radius-scaled
thickness. Deposited ordinary-film history reaches the production lens (alpha
0.953, bare-visor contribution zero in the controlled test). Additional metadata
384 KiB, no new full-atlas pass; actual 4096-slot model-width candidates +0.148%.
Actual game FPS and remaining true trajectory/chord corners need confirmation.
See `RAINFX_S72_TRAIL_SAMPLING_AND_DIAMETER.md`; this follows the s70 diagnosis.

## Latest s71 Smear red-region correction (2026-10-13)

User reports green/high-G smear looks correct but red/low-G areas do not,
at 100% rain, 220–287 km/h and density 1.00–1.50. Reproduced two bypasses:
raw clearance erased low-G classes and restored opaque heads; neutral trail
coverage ignored G visibility. Class wipe now uses pre-erasure path/G weakening,
and neutral trails use the existing trail visibility control. Colour/presence
share symmetric class interpolation. Numeric/bool Smear UI settings now persist.
No default tuning, physics or render pass changes. High-G endpoint and smear-off
outputs are identical in controlled GPU replays; actual game validation pending.
See `RAINFX_S71_SMEAR_RED_REGION.md`. s70 trail calibration remains open.

## Latest s70 Trail visibility evaluation (2026-10-12)

User confirms s69 G-force conflict and memory leak resolved, then reports no
visible New Trail refraction. Current saved width is 0.26 D. Production-shader
readbacks show ordinary coated 0.65 mm paths can disappear between atlas rows;
aligned paths reach G=0.0512 but only 4.32% alpha and 0.0124 px shift on the
controlled projection. Actual baked coated samples show the same strong
suppression. Thickness starts above 1.3653 mm/s and 0.20 mm, but max history
does not add water mass and legacy sheet height floors are inactive. Subpixel
deposition and optical calibration need correction within the existing passes.
Runtime/tuning unchanged by this evaluation. See `RAINFX_S70_TRAIL_VISIBILITY.md`.

## Latest s69 G-force/memory follow-up (2026-10-12)

User isolates FX loss to moving G-force transforms; profiler shows 2297.72 MB,
GC 58.1% and merge/splash hotspots, with repeated 5-FPS stalls. Moving native
mask GeometryShots now prepare before main rendering. Reproduced and removed
CPU splash-history growth and a retired New Trail queue without a consumer.
4096-slot merge scratch reuses an ascending linked grid: identical commands,
99.67% less allocation in the offline workload; CPU median remains similar.
Current motion/tuning and GPU physics retained. The user subsequently confirms
G-force conflict and memory leak resolved. See `RAINFX_S69_MOTION_AND_MEMORY.md`.

## Latest s68 FX/UI follow-up (2026-10-12)

User reports FX disappearing near automatic driving and returning with ESC,
plus an invalid native-state tree UI call. Fixed the confirmed tree callback
contract and reproduced a frame-only guard suppressing another render view.
FX completion now belongs to a main view/target, pending stages retry and
successful items do not composite twice. Added independent authored-convex
E2/E3 dark tint, default neutral, with UI/persistence and HDR shader checks.
The exact automatic-driving trigger and real-game recovery remain to verify.
New Trail review follows that confirmation. See `RAINFX_S68_VIEW_AND_CONVEX_TINT.md`.

## Latest s67 New Trail follow-up (2026-10-12)

User confirms s66 lighting repaired and daytime 60% rain at 79→59 FPS,
100% rain at 75→45 FPS. Normal async pending no longer throws from owned
optics/capture callbacks. New Trail combines current-GPU liquid and wipe
segments in one 4:1 history, removing delayed CPU path stamps and their budget.
Head bins exclude swept-path work (38.32% fewer candidates at 4096 slots,
identical water RGB). Diameter/mm controls retain physical size across texture
resolution changes. Production shader, lifecycle, lens, skewed/actual-baked
mesh and hole checks pass. Real game FPS/appearance remains pending.
See `RAINFX_S67_NEW_TRAIL.md`.

## Latest s66 startup and missing glass follow-up (2026-10-12)

The installed native occlusion module was still absent, blocking both glass
passes and their diagnostic. Measured cold head-kernel compilation at about
50 seconds; shared channel loops reduce this to about 1.5 seconds with identical
water RGB. Shader/model loading is asynchronous, pending GPU builds avoid CPU
fallback, and the obsolete full UV lookup is skipped in the shared GPU mode.
Glass and E1 tests have independent pending/Rain-off routing. Scoped offscreen
captures and explicit generated Rain shadow disable address additional state
risks. Wrapped colour/depth warning now reproduces and is fixed without
suppression. Settings and current concurrent tuning edits retained. Complete
game installation, load/FPS/visibility/sunlight verification remains required.
See `RAINFX_S66_STARTUP_AND_GLASS_DIAGNOSIS.md`.

## Latest s65 rendering/cost follow-up (2026-10-12)

Previous game experiment omitted both native modules, so its FPS/lighting and
layer results are not a complete-runtime baseline. User supplied CPU profiling
(scene-ready 3.18 ms, merge/tap hotspots), reports ordinary mesh occlusion fixed
and remaining FX hidden. Fixed the unset post-rain INT readiness flag, added
Rain's scene/native depth rejection and explicit submission state. Smear uses
filtered class mixing and a parameter-only 4:1 mask cache. Physical ribbons and
supported preview/history connect, and current GPU sweeps refresh wipe paths
without raising the CPU 384-stamp budget. Bounded/sparse tile work and specialized
depth remove repeated work. Saved settings and actual GPU physics remain.
Game GPU timings and recovery to former total cost remain pending.
See `RAINFX_S65_LAYER_TRAIL_COST.md`.

## Latest s64 urgent performance follow-up (2026-10-12)

User reports daytime 60% rain falling to 15 FPS while driving. Reproduced an
unmeasured merge CPU hot path (roughly 20 ms to 2.2 ms in the current 2000-record
offline replay), removed unsupported predicted grid entries/string keys,
reused adaptive GPU Jacobians, gated empty merge/wet-path/held-state work and
disposed CPU readback copies. Corrected downward airflow and the missed live
s63 native-glass mask hook; added native hard-shadow comparison and actual
Render Stats CPU/GPU intervals. Existing E2/E3/tuning retained. Actual recovery
to the previous game FPS remains pending. See `RAINFX_S64_BOTTLENECK_AIRFLOW_LIGHTING.md`.

## Latest s63 follow-up (2026-10-12)

User accepts E2/E3 and the new physical drop directions. Daytime 60% rain still
reports below 36 FPS versus the former 56–60 FPS. Fixed a zero-Jacobian inverse
that could expand wipe/trail/splash kernels across the visor; bounded CPU paths
and placed splash pieces in the actual surface plane. Added non-compositing
native exterior glass occlusion for custom glass/E4 output and further GPU/CPU
head-work reductions. Offline checks pass; new game performance/appearance is
pending. See `RAINFX_S63_GLITCH_AND_NATIVE_OCCLUSION.md`.

## R1. GPU drops pre-laid like the micro pattern — accepted for 0.6.0 (2026-10-07) (`RAINFX_GPU_PRELAID.md`)

Source: `RAINFX_REVIEW_2026-10-02.md` §1.

**Goal.** Control many more drops smoothly, with birth sites laid out in
advance and selected by intensity, as the micro pattern does.

**Plan, in order.**
1. **GPU-side WF head stamping.** Draw the WF head canvas from the state
   texture (`txRainState` / meta) with an instanced or point-sprite pass;
   removes the per-drop CPU loop in `waterFieldDrawStamps`.
2. **Atlas-driven respawn.** R1.2 prototype bakes valid visor-UV sites and
   stable activation order on the GPU, behind a toggle. In-game validation
   is pending; size class remains on the existing birth-size path.
3. **Raise the state texture size** (10k+ slots) once 1 and 2 hold. A
   sparse-word GPU head pass is now behind a toggle for scaling tests;
   CPU trail/splash/readback work still needs bounding before 10k+ slots.

**Current result (2026-10-07):** user accepts the current RainFX for release.
R1.1–R1.4, local impact film, sheet tuning and grouped UI form the 4096-slot
baseline. User captures reached roughly 50+ FPS in the demanding scene;
instantaneous captures are variable and are not a universal FPS guarantee.
Further particle-cap increases are not a release requirement.

## Deferred RainFX movement finish — user request, no date scheduled

- Use currently available physical inputs to produce naturally curved paths
  rather than excessively straight movement.
- With no sustained driving force, let water gradually lose speed and stop.
- At Rain or higher intensity, allow appropriate downward flow while parked.
- Separate tuning factors for adhesion, external acceleration, curvature,
  dissipation and rain feed so adjusting one goal does not break another.
- Preserve the accepted trail/film appearance and physical coordinate model.

Do not implement these changes in the 0.6.0 release. No reminder or automatic
execution time was requested; this is a deferred engineering backlog.

## R2. Visor scene stack and glass optics — resumed after 0.6.0 integration

Replaces the former "R2 visor glass pass" (`RAINFX_VISOR_GLASS.md` §3.C/§4).
Work and open items: `RAINFX_VISOR_LAYER.md` §17–§20.
- S2 verification of the scene stack (order, brightness).
- Shadows and local lights for the custom housing.
- Shadow signal for the glass optics (§15.1).
- V3 glass base (E2 relief normal, E3 lens/tear, E4 band transmission).
- V4 light effects (E1 strong-light projection, E6 scratches, E7 interior
  projection).

## Closed / withdrawn
- Post overlay (P0–P4, HUD lift): **archived** 2026-10-04
  (`RAINFX_POST_OVERLAY.md`).
- `RAINFX_WATER_FIELD.md` backlog #3 (metallic non-sky contrast with many
  large drops): **closed 2026-10-05**, not important; re-open if it recurs
  in the latest build.


## s61 — new KN5 / independent 4:1 UV migration (2026-10-12)

User authorized adapting all affected processing to the rebuilt KN5. Completed:
new FX/Rain mesh names; geometry Jacobians and physical birth/merge/transport;
absorbing holes/edges; coating/bare-glass coefficients; rectangular surface
canvases and independently transferred materials; E1 eight-mesh captures and
native FRAME_MAIN two-sided output; native Visible preservation; optional water
mirror pass with no glass-optics captures; stale asset gates and ordered rebuild.

Offline Lua, geometry, shader compilation and D3D11 WARP checks pass. Actual CSP
appearance and frame time remain to be verified. See
`RAINFX_KN5_4_TO_1_MIGRATION.md` for assets, commands and diagnostic views.
This is the user-requested coordinate/KN5 migration; the separate creative
RainFX movement finish listed above remains deferred.


## s62 — output / warning / cost correction (2026-10-12)

User game captures exposed black EXT, fixed E2/E3 marks, broad rain ghosts,
missing micro drops and increased cost after s61. Corrected band-alpha semantics,
optical frame/incidence/delta composition, DLSS source alignment and micro
pending/metadata handling. Added per-drop metric cache and bounded physical
birth lookup; removed unused mesh uploads and CPU cap triangle expansion.
Strict warning-free shaders and D3D11 WARP/Lua checks pass. Actual new game FPS
and reference matching remain unmeasured. See RAINFX_S62_OUTPUT_AND_COST_FIXES.md.
