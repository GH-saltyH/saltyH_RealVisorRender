# RealVisor RainFX — historical docs index and working rules

## 현재 설치·운용·개발의 진입점 — 2026-10-25

새 개발 방향: [CSP 기반 새 구현안](RAINFX_CSP_REDESIGN.md).
테스트 도구 정리 후 활성 도구·의존성은 [개발 안내](guide/DEVELOPMENT.md)를 따른다.
아래 옛 단계별 테스트·산출물 경로 상당수는 `archive/2026-10-25_legacy_research.zip`
안의 동일 상대 경로로 보관됐다. 이 파일의 역사적 실행 명령을 현재 도구로 간주하지 않는다.

**이 파일의 아래 s번호별 “현재/다음/pending”은 작성 당시의 역사적 기록이다.**
설치·운용 판단은 [프로젝트 README](../README.md)와
[현재 상태](guide/CURRENT_STATUS.md)를 먼저 읽는다.

- [설치·업데이트](guide/INSTALLATION.md)
- [운용·장애 보고](guide/OPERATIONS.md)
- [개발 구조와 검사](guide/DEVELOPMENT.md)
- [유지보수·자산 변경·인계](guide/MAINTENANCE.md)

`docs/runtime`, `docs/prototypes`, `docs/probes`에는 실제 앱이 사용하는 실행 코드가 있다.
이 폴더를 문서/옛 실험이라고 보고 설치에서 통째 제외하면 안 된다.
최신 P0에는 표시 보간과 regional pool return이 연결됐지만 전체 게임 품질은 미합격이다.
아래의 오래된128개 자원·14개 texture·미연결 등의 수치는 현재 값으로 재사용하지 않는다.

---

## s282: six-minute visible follow-up and bounded input recovery

[Input recovery and actual milestone](RAINFX_S282_BOUNDED_INPUT_RECOVERY.md).
The user observed drops/film and11618 accepted intervals before an atomic input
capacity stop. A focused baseline reproduces that stop after a200ms frame; the
product now stages bounded captured input and retries in order while keeping
solver16-slot/0.5s limits and GPU storage unchanged. Both200/250ms bursts recover
locally; genuine stalled completion remains bounded. Actual recovery is pending
ordinary use; no new long-run probe requested. Essential interactions remain next.


## s282 follow-up: signed-momentum inventory comparison repaired

[Actual refusal and focused repair](RAINFX_S282_INVENTORY_ROUNDOFF_REPAIR.md).
The actual serial326 refusal was source mask32: water matched exactly, while a
7.45e-9 signed-momentum reduction difference exceeded a bound scaled only by its
near-zero resultant. Product-only comparison now uses the existing absolute
ledger-term scale for momentum; mass/physics/passes remain unchanged. Two changed
production programs compile strictly; injected meaningful errors still refuse.
Actual continued visible-product verification is pending. Failure reports are
retained independently of the game log quota.

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

Start here. This file lists every document in `docs/` with its state, the
current architecture in one screen, and the rules for working on the
project.

## 1. Current architecture (one screen)

Current policy: [s229 game acceptance v1](RAINFX_GAME_ACCEPTANCE_POLICY.md).
Latest compatibility change: [s274 CSP integration simplification](RAINFX_S274_CSP_INTEGRATION_SIMPLIFICATION.md).
Actual s273 code1/slot0 points to the decoder's entry/context/shape gate before
physical calculations. Its16-input shader now consumes proven owned packets/copies
with14 inputs; all runtime passes stay within14. Stable CSP submission tables
replace fresh binding tables. Numerical gates/model/queues remain unchanged.
11 native parity/negative draws,15 owner and seven panel cases pass. Actual
compatibility fix is unconfirmed until the same combined gate is rerun; no new
standalone probe or precision study is planned.
Previous diagnosis: [s273 first failed head snapshot](RAINFX_S273_FIRST_HEAD_FAILURE_SNAPSHOT.md).
Actual s272 context8 means its head producer receipt is zero. Captured CPU input
and prior pose replay locally without failure, so actual GPU intermediates are
still needed. s273 retains the first head code/slot and its full snapshot in the
existing audit (64→640B; +18KiB, same128 canvases). Numerical gates remain intact.
Native snapshot parity and owner/panel/strict shader checks pass; actual fix is
pending this focused capture. Remove the larger audit after resolving the bug.
Previous diagnosis: [s272 source context replay](RAINFX_S272_SOURCE_CONTEXT_REPLAY.md).
Actual s271 first refusal15/mask517 narrows failure to the source context gate;
transport/conservation bits were clear. s272 preserves the same acceptance bit
and records the internal comparison, exact admitted input and prior pose on
failure. No additional GPU target/readback.22 native guard parity draws,15 owner
and seven panel/replay-log cases pass. Actual cause/fix remains pending capture.
Previous correction/diagnosis: [s271 warmup and first refusal](RAINFX_S271_WARMUP_AND_FIRST_REFUSAL.md).
Actual s270 had one pending-count warmup fault and one stopped source run.
s271 uses bounded elapsed compilation waits and preserves the earliest refusal
with a condition bitmask, in the existing16-float receipt. Actual rejection
cause remains unresolved. Dry-start nonzero source passes293 native draws;
18 receipt parity draws,15 owner cases and six panel cases pass. Same128 resources.
Previous correction: [s270 CSP sampler compatibility](RAINFX_S270_CSP_SAMPLER_COMPATIBILITY.md).
Actual s269 warmup failed because its birth shader redeclared CSP's built-in
samLinearClamp. The s270 submission adapter removes only that duplicate and
retains the same physical graph/owner. All55 distinct combined shaders compile
with the observed CSP sampler prelude; six panel/menu cases pass. Actual retry
is pending. Same128 resources; no new numerical or FPS qualification.
Previous implementation: [s269 joint live rain transport](RAINFX_S269_JOINT_LIVE_RAIN_TRANSPORT.md).
Default-off main-app runtime now combines physical births/heads, conserved source,
compact film transport and the retained source-time owner. Eight stock/pose roots
select together; refusal propagates to queued suffixes. 293 native draws / full
4096-slot shapes, 13 controlled owner cases and six panel/menu cases pass.
128 private canvases use132.69MiB, plus40.13MiB verified read-only files.
One combined actual three-second gate is pending; optics/public adoption and
2048/4096 populated-rain frame time remain unqualified. Runtime starts dry.
Previous implementation: [s268 actual-context physical producer binding](RAINFX_S268_ACTUAL_CONTEXT_PRODUCER_BINDING.md).
Admitted engine rows now bind matching birth/SI/head/pose/material cohorts,
including same-engine-frame slices and physical film/micro wet feedback.
Hoisted immutable frame checks plus compiler-reflected bindings keep every
producer pass within16 textures. Recorded actual input/current bake/4096 slots
pass53 native draws, including one declared retained head and unchanged-shader
reference (maximum error0). The short recorded slice has zero new incidents.
Live source/joint owner and optics remain disconnected; no new user probe.
Previous implementation: [s267 joint supply and compact transport](RAINFX_S267_JOINT_SOURCE_COMPACT_TRANSPORT.md).
Native physical birth/head/source feeds compact film transport with a joint
seven-root stock/raw-state/meta decision. Source ON/OFF/ON, source replay,
transport/identity/metadata failures and retained plan reuse pass locally.
726 native draws /15 cases; three recurrent physical producer intervals.
Actual source runtime/whole-pipeline optics and performance remain unqualified;
no new game diagnostic or change to the observed s266 main-app path.
Previous implementation: [s266 actual-input compact film integration](RAINFX_S266_ACTUAL_INPUT_COMPACT_TRANSPORT.md).
Default-OFF main-app path connects verified actual visor headers, private world
cache/material, compact transactional transport and the retained source-time FIFO.
78 native draws,13 controlled owner cases and6 real-adapter panel fixtures pass;
actual menu dispatch and linked installation are checked. 50 private canvases
reserve104.597MiB plus36MiB read-only file images, excluding driver/app/staging.
One warmup then3seconds actual input capture; no public renderer/head/source
connection. Actual CSP controlled-film gate passes:171/171 inputs,3.012811s,zero debt,
172/172 readbacks disposed. Source-time residual closes with0.407us quantization
remainder. Peak owner CPU7.2193ms;10-frame callbacks overlap submission.
This qualifies this controlled run, not full-app FPS or optical adoption.
See [actual results](RAINFX_S266_ACTUAL_RESULT.md).
Previous implementation: [s265 private transactional execution](RAINFX_S265_PRIVATE_TRANSACTIONAL_EXECUTION.md).
Private GPU selectors commit validated stock/time receipts or retain all last-good
state bands;blocked suffixes cannot advance.92 native draws verify commit/rollback,
momentum/diagnostic refusal and exact small snapshots.12 controlled executor cases
verify64-input delayed audits,reuse,ordered settlement,lease retention,cancel and
quarantine. One full-grid workspace/committed roots/audits reserves80.096MiB,
excluding external inputs/cache/app. Main/game unchanged;next admitted engine
input/cache leases plus source-time queue connection,then one actual integrated gate.
Previous implementation: [s264 compact SI-force/advection/ledger](RAINFX_S264_COUPLED_FORCE_LEDGER.md).
Each substep now updates inherited SI relaxation from evolved local depth/momentum,
projects Mean velocity,and conservatively transports End. Cumulative runoff,
force impulse,wall exchange and a small GPU time/identity receipt are connected.
178 native draws pass8 recurrent inputs/0.15s,an independent analytic force check,
6 invalid-physics/7 invalid-ledger refusals and stale receipt refusal. Cached plans
use20/36/68 numeric draws,not the old graph builder.48.094MiB excludes external
inputs/cache and transaction roots. Main/game unchanged;next owned input/commit
and retained executor integration,then one actual continuous/startup gate.
Previous implementation: [s263 bounded donor-cell advection](RAINFX_S263_BOUNDED_FLUX_TRANSPORT.md).
Two fixed shader bodies and a4/8/16-substep GPU plan replace CPU retry in the new
advection core candidate.118 native draws verify positivity,End/Mean packet
conservation and accumulated runoff. On one actual-grid interval,the4-step plan
limits at most0.015533% of water and differs0.096893% in volume L1 from16 steps.
Single-step clipping affects about42% and is rejected.40MiB describes the plan's
three textures only. Force/ledger/owned execution integration is next;main/game
unchanged,no continuous/FPS/startup success claimed. No new user probe required.
Previous implementation: [s262 bounded recovery](RAINFX_S262_BOUNDED_RECOVERY.md).
The installed default-OFF path drains failed suffixes,retries original inputs
with bounded dyadic subdivision,and replays blocked inputs without a stock reset.
Native refusal/recovery and10 owner/6 panel controls pass.99 GPU textures remain;
allocation is staged8 per callback. Exceptional recovery allows1s/64 CPU contexts,
not a product latency pass. Graph construction remains synchronous and separately
timed. Actual CSP recovered/replayed11 slices with13 recovery submissions;
75/75 reads audited/disposed,but stopped at time_capacity with0.787547s debt.
Ten-frame audit waits serialize recovery;the3s continuous gate failed. Keep this
as a safety/reference path,not normal transport. Graph construction80.7245ms and
live pump peak6.0575ms remain costs. Next bounded-cost GPU stability/transport
without a CPU audit per retry,and cached/staged graph preparation. No larger queue
or repeated latency probe. Public effects remain s87;no FPS claim.
Previous implementation: [s261 refusal provenance](RAINFX_S261_REFUSAL_PROVENANCE.md).
21 native draws verify rejection conditions in existing receipt words.
Previous implementation: [s260 resident live transport](RAINFX_S260_RESIDENT_LIVE_TRANSPORT.md).
Main default-OFF integrated path now submits real successive input slices without
the normal CPU callback barrier. One pooled workspace/pinned constants and32
immutable64-byte audit copies reserve about71.1MiB/99 canvases. GPU predecessor
checks block refused suffixes;CPU-audited time remains separate from projected
submission. Shared3ms/256-attempt pacing supports multiple slices at30FPS.
531 native recurrence/control draws plus one snapshot draw,16 owner and6 panel
cases pass. Actual CSP submitted/audited34 receipts(including warmup),with32
continuations before the preceding CPU audit and all34 reads disposed. However,
transport stopped after22 live slices/0.457918s;0.200001s debt is retained.
The three-second continuous gate failed. Aggregate status does not identify the
refusal predicate. Initialization93.95ms and live owner peak5.03ms need work.
Next inspect existing refusal conditions and implement bounded stable/cheaper
transport plus staged/cached startup;avoid another isolated latency probe.
Controlled20um film only;no head/source/optics or public state adoption/FPS claim.
Previous implementation: [s259 bounded live intake](RAINFX_S259_BOUNDED_LIVE_INTAKE.md).
Reusable CPU controller composes the observed s239 capture and existing time FIFO:
finite context/time/age limits,one leased slice,explicit overload/reset/cancel,
and exact late settlement without discarding queued time.12 integration cases
pass,including real dependency factory/20 bootstrap checks and1200 slices.
The recorded s258 service-rate envelope overloads under60Hz intake;this is not a
new GPU measurement. No new probe/UI or main runtime connection. Next is one
integrated GPU-resident transport path with async audit separated from normal
progress,then one focused continuous CSP gate;avoid further isolated probe growth.
Previous implementation: [s258 selective CPU preparation](RAINFX_S258_SELECTIVE_CPU_PREPARATION.md).
Selected fresh packet construction replaces eight full85-pass packet builds and
the second batch copy. Only533 base-pass packets plus8 summaries are generated;
dynamic rows/ids/tickets are filled once from validated input. Executor snapshots,
GPU descriptors/commands and1082 draws/65 canvases/70.986MiB stay unchanged.
81 full packet-bit cases,18 complete command streams/9 tails/10 guards and7
panel/5 host/8 collector checks pass. Prior physical/native evidence is inherited.
Actual CSP passes2 batches/16 inputs/1082 draws/65 resources/debt0. All120 paired
CPU outputs match. The96 measured alternating pairs improve median1.7638→0.71555ms
and p95 12.7925→3.8304ms;selective wins96/96,48/48 in each order. Qualify CPU
bind preparation only and retain s258 as private development base. Warm owner
bind+submit2.1607ms/max pump3.0073ms is encouraging but cross-session. Whole
cycle262.22ms still includes174.78ms/10-frame readback. Continuous/FPS/public
adoption remains open. Next:remaining executor preparation spikes,bounded live
intake and response age;do not require microsecond-perfect soft-budget pacing.
Previous implementation: [s257 recurrent copy elision](RAINFX_S257_RECURRENT_COPY_ELISION.md).
Preferred single-arena eight-input execution now aliases prior film/history at
stages2..8 and prunes their unused initial-inventory subgraphs.35 passes/window
are removed:normal16 inputs1082 draws versus1152,still2 receipts/65 canvases/
70.986MiB. All retained shader bodies,payloads,checkpoint/time/ledger guards are
unchanged;independent lifetimes protect aliased read roots.4204 native draws,
18 owner modes/9 tails/10 guards and7 panel/5 host/6 collector controls pass.
Actual CSP completes2 windows/16 inputs/1082 draws/65 resources/debt0. Work
reduction is verified at unchanged memory. Warm SDK-call sum5.20→5.01ms is a
limited observation;whole caller cycle240.76→267.15ms does not establish speedup.
Both use3 submission pumps and10-frame readbacks;readback wall difference
accounts for22.44 of26.38ms cycle difference. Different sessions/dt and one warm
sample prevent causal regression/speedup claims. Warm preparation4.803ms and
whole-pump peak5.349ms remain targets. Retain s257 as the lean private development
base;optimization timing,continuous/FPS/public adoption remain unqualified.
Next:reduce repeated CPU packet construction/preparation and indivisible spikes.
Previous implementation: [s256 two-arena continuation](RAINFX_S256_TWO_ARENA_CONTINUATION.md).
Two protected four-input GPU windows can progress while the first CPU receipt is
pending. The second checks the owned prior GPU receipt;refused/partial/invalid
prefixes block its motion and preserve inventory/checkpoint. Both CPU receipts
must validate before either arena is rebound. Normal16 frozen inputs plan4
windows/2 cohorts/1184 draws/130 canvases/141.973MiB,within192MiB diagnostic cap.
Seventeen owner modes/10 tails,4378 native draws and7 panel/5 host/6 decoder controls pass;new
shader variants compile warning-free with at most15 texture bindings. Actual CSP
passes4 windows/16 inputs/1184 draws/130 resources/debt0. Both second windows
finish SDK submission7/8 frames before the first callbacks;all4 readbacks still
take10 frames. Warm8-input cohort246.88ms versus s255240.76ms shows no throughput
gain in these limited,nonidentical captures at twice the descriptor memory.
Reserved count capacity25.92/s remains only a20Hz planning candidate;physical
time/elapsed ratio0.647 misses framewise catch-up. Execution gate passes;
optimization adoption is deferred and s255 remains the lower-memory candidate.
Next:reduce per-interval repeated work/static duplication and account for live
input/response age. No dt/source changes,continuous/FPS or public adoption.
Previous implementation: [s255 eight-input GPU window](RAINFX_S255_EIGHT_INPUT_GPU_WINDOW.md).
Up to8 ordered intervals share one CPU receipt at fixed3ms/256-call pacing.
Sixteen normal inputs plan1152 draws/two receipts,versus1184/four. Two vec4 time
banks and8-bit prefix preserve partial/refused time. Logical576 resources still
use65 allocations/70.986MiB. Eighteen owner modes,nine tails,three strict shader
variants and seven panel/five host cases pass.5792 native draws verify natural
late refusal/recovery,all retained roots and bank-boundary/error/partial gates.
Actual CSP passes2 windows/16 inputs/1152 draws/65 resources/debt0. The one warm
window completes8 inputs in240.76ms:33.23 inputs/s,26.58/s with20% reserve;
per-input caller elapsed cost is37–46% below the two s254 fast observations.
This is a limited cross-session comparison,not FPS or continuous qualification.
Readback still takes10 frames/154.97ms;accepted physical time is only63.59%
of elapsed time. Cold preparation has535 SDK-pending retries/9.26s;no9s single
frame stall is inferred. Warm whole-pump peak4.085ms exceeds the soft3ms budget.
20Hz is a capacity planning candidate only:batch filling plus confirmation can
make displayed state old. Next:bounded GPU continuation/reduced interval work
and explicit response-age/time/source integration,not a larger window by default.
No dt/source resampling;continuous capacity,FPS and public adoption remain open.
Previous implementation: [s254 whole-pump capacity](RAINFX_S254_WHOLE_PUMP_CAPACITY.md).
Warm preparation and drawing share a soft1..3ms pump budget. Bounded profiles
up to256 calls alternate32/1ms and256/3ms across16 frozen inputs. Callback-to-
callback wall time,accepted physical time and provisional capacity are logged;
no dt change/resampling/public-clock update occurs. Fifteen complete command
parity modes plus duplicate/policy guards and seven panel/five host checks pass.
Physical s253 native evidence is inherited. Actual4 windows/16 inputs/1184
draws/65 resources/debt0 pass. Fast warmed cycles191.54/224.20ms versus361.97ms
baseline,with2 pumps versus10;whole owner peaks3.004/3.013ms. Qualify faster
private execution,but not continuous intake/FPS adoption. Reserved capacity
14.27–16.71 inputs/s misses20Hz;all readbacks still take10 frames. Next:less
frequent CPU confirmation or solver-work reduction. Visible s87.
Previous implementation: [s253 four-input GPU window](RAINFX_S253_FOUR_INPUT_GPU_WINDOW.md).
Four ordered intervals share one GPU receipt. Intermediate summaries gate the
accepted prefix;partial retries block later inputs and retain all time debt.
Eight inputs now plan592 draws/two receipts,versus620/four. Lifetime storage
uses65 textures/70.986MiB(+64 descriptor bytes). Fourteen owner modes,six tails
and ten guards pass.2250 native draws verify sequential root equality,all four
refusal positions,bad-summary propagation and partial-first blocking. Actual
CSP completes2 windows/8 inputs/592 draws/65 resources/debt0 with2 readbacks.
Warm submission takes10 pumps;receipt still takes10 frames. Four inputs use
20 frame increments between receipts,so frame-by-frame intake cannot catch up.
Warm dispatch peaks0.6948ms but whole pump2.7044ms;cold SDK peaks6.8391ms.
Qualify bounded four-input execution;continuous throughput/FPS/live adoption
remain unqualified. Next:an explicit intake-time/pacing/update-frequency policy.
Previous implementation: [s252 last-use storage](RAINFX_S252_LAST_USE_STORAGE.md).
Verified logical lifetimes map155 textures to64 owned allocations,70.986MiB
instead of162.104MiB. Retained film/history/checkpoint,dummy and receipt stay
exclusive. Eight command/lifecycle modes,eight unsafe controls and1455 native
shader draws pass;retained roots match the sequential solver including recovery.
Native arrays simulate storage overwrites;actual CSP now completes2 batches,
4 inputs,310 draws,64 resources and zero debt through validated receipts.
Descriptor sum70.986MiB;2 CPU readbacks/disposals. Qualify this bounded private
reuse path;full-field CSP equivalence and general completion remain unclaimed.
Readbacks still take10 frames (155.6204/164.1538ms). Next:longer GPU-gated
continuation and bounded continuous intake. No CPU/GPU/FPS speedup or live
adoption claimed.
Previous implementation: [s251 preparation reuse](RAINFX_S251_PREPARATION_REUSE.md).
Single-copy payload refresh and slot-local typed-uniform reuse reduce repeated
preparation;receipt conversion is once per reused job. Signed-zero words and
busy/caller isolation are preserved. Thirty packet cases,complete command
parity/pending/retry controls and seven panel/five host cases pass. Installed
original/reused/original/reused comparison uses32-call pacing in all4 batches.
Actual8-input/4-batch run passes:620 draws,155 resources,zero debt. Warm
original bind+submit2.5139ms versus reused1.1157/0.8773ms;typed conversions
918 versus39/33. Preparation reuse qualifies within these limited samples.
Whole pump peaks1.7149/1.2894ms and readback remains10 frames;continuous
throughput/FPS adoption stays open. Physical graph/queue unchanged. Visible s87.
Previous implementation: [s250 bounded dispatch pacing](RAINFX_S250_BOUNDED_DISPATCH_PACING.md).
Versioned owner raises the configurable call ceiling to32 while retaining the
1ms pre-call soft deadline. Nine command-parity/pending/retry/slow-call controls
and seven panel/five host cases pass;physical graph and resource count stay.
Installed default-OFF same-session8/32/8/32 diagnostic uses8 frozen inputs,
4 batches,620 draws and155 canvases. Warm frame spans and deadline/tail costs
are logged. Actual8-input/4-batch run passes with620 draws,155 resources and
zero debt. Warm32 submits in5 frames versus20 at8;dispatch maxima0.8645/
0.6431ms stay below1ms. Full owner pump reaches2.0326ms;readback remains10
frames. Qualify32 for private warmed dispatch,not whole-frame/FPS adoption.
Cold non-preemptible6.1715ms backend call remains a startup/tail observation.
Previous implementation: [s249 retained batches and recovery](RAINFX_S249_RETAINED_BATCH_RECOVERY.md).
One155-canvas set retains validated film/checkpoint/ledger across batches.
Normalized per-input progress retries refused steps at half size,without
reapplying accepted inputs;single tail blocks the unused lane. 1455 native
draws verify every retained batch root against changed-input sequential
references and refused-input recovery. Queue guards,seven panel/five host
cases pass. Actual CSP completes4 inputs/2 batches with310 draws,155 fixed
resources,2 readbacks/disposals and zero debt;inventory and cumulative ledger
continue. Batch2 takes20 frames to submit plus10-frame readback under the
8-call ceiling;next assess higher bounded dispatch within the1ms CPU budget
before continuous intake. About162.1MiB fixed;throughput/optics open. Visible s87.
Previous implementation: [s248 two-interval GPU batch](RAINFX_S248_TWO_INTERVAL_GPU_BATCH.md).
Two private intervals now form one GPU-dependent DAG with a single CPU receipt.
First refusal blocks stage2;GPU audit failure propagates;prefix/time debt stays.
Native changed-pose/force/dt/air results match all six sequential roots,with
first/second refusal and bad-audit controls. Seven panel/five host cases pass.
Actual CSP passes1/1 batch,prefix2/2,155 draws/resources and exactly one
readback/disposal. Advanced0.0434837341s,debt0. Final callback remains10 frames
/146.8544ms,paid once for the pair;total throughput/FPS gain is unmeasured.
About162.1MiB is retained under an explicit192MiB cap. Next retain inventory
across batches and recover refused/deferred input time. Visible s87.
Previous implementation: [s247 paired completion latency](RAINFX_S247_PAIRED_COMPLETION_LATENCY.md).
Default-OFF diagnostic interleaves eight minimal16-word readbacks with the
s246 physical intervals to separate callback-path latency from workload.
Seven panel/eight control/five host cases pass;actual CSP completes8/8 with
568 physical draws,86 resources and16 validated/disposed reads. Every minimal
and full readback returns exactly10 engine frames later (16 samples total);
repeat means148.2389/150.6607ms. This supports reducing serial CPU barriers
via bounded GPU-dependent continuation with propagated refusal/audit state.
Adds one64-byte canvas/eight control draws,keeps all water/ownership checks.
This is attribution,not a measured throughput optimization.
Previous implementation: [s246 retained graph template](RAINFX_S246_RETAINED_GRAPH_TEMPLATE.md).
The private candidate compiles s243 once and refreshes each input's values and
validation state. All recipe/packet fields match the reference across5 changed
contexts/15 tickets;210 validator comparisons,six refusals,seven panel cases
and five host guards pass. Actual CSP passes8/8,568 draws,85 resources and zero
debt. Repeated bind averages0.1568ms;admission66.8287→0.5391ms. Initial build
remains73.9595ms once. Status latency156.6886ms remains a separate throughput
issue;next review completion/readback policy. Draws/resources stay unchanged;
FPS/GPU time and continuous throughput remain unqualified.
Previous implementation: [s245 callable clock adapter](RAINFX_S245_CLOCK_ADAPTER.md).
Actual s245 passes8/8,568 draws,85 resources and zero retained debt. The engine
clock is confirmed as callable cdata;the Lua wrapper fixes the strict clock
boundary. Seven repeats expose graph reconstruction at66.4969ms mean per
interval (admission66.8287ms);retain a graph template and refresh input values
next. Status request-to-callback latency averages144.5055ms and requires a
separate completion-policy review;it is not GPU execution time. No GPU/FPS or
continuous throughput qualification. Visible physics/optics remains s87.
Previous implementation: [s244 CSP dispatch profile](RAINFX_S244_CSP_DISPATCH_PROFILE.md).
Default-OFF main panel captures one actual context and repeats eight private
benchmark intervals on the s243 graph. It records CPU allocation/graph/uniform/
SDK group costs,not-ready attempts and callback latency;no GPU timestamps,FPS
or continuous-time claim. Seven real-adapter/executor mocked cases,six benchmark
controls,five decoder refusals and five host guards pass;linked dependencies
are audited. Original s244 clock-guard failure is preserved;actual successful
profiling is recorded in s245. ~91.193MiB is retained in the session.
Previous implementation: [s243 exact small-header audit](RAINFX_S243_EXACT_HEADER_AUDIT.md).
The seed audit compares208 uploaded FP32 words directly,removing two dynamic
header digest passes while retaining all geometry proofs. Native full-field
continuation matches all six s242 End/Mean/ledger arrays bit-for-bit;five input
corruptions refuse and10 scheduling cases pass. Three-input-generation draws
fall229→223/resources87→85,status reads stay3;800 extra logical uniform bytes
make actual CPU/GPU benefit unqualified. Sustainable throughput remains open.
No main/game change. Next actual warm dispatch/constant/completion profiling.
Previous implementation: [s242 budgeted private stream](RAINFX_S242_BUDGETED_STREAM.md).
The adaptive owner now drives the real private executor with up to8 SDK calls
per pump and a soft deadline;queue/admission consume only validated normalized
progress. Ten scheduling/fault/callback cases pass. A real native full-grid run
retains film/history across two synthetic-duration inputs/three slices with229
submissions,three reads,87 fixed resources and zero debt. This is local,not a
live engine connection or throughput/FPS pass;at8 calls a cold87-draw interval
still needs at least11 pumps. Next economical dispatch/completion and actual CSP
throughput before source/renderer adoption. No main/game changes.
Previous implementation: [s241 bounded retry and rollback repair](RAINFX_S241_BOUNDED_RETRY.md).
Private attempt tickets halve refused steps,advance time only on acceptance and
retain explicit debt on budget/one-tick failure. Stress validation found the old
packed export replaced Mean with End on refusal after progress; the versioned
fallback now preserves each original band. Normal20um End matches s240.
Full-grid500um opposing flow completes13 attempts(9 accepted/4 refused),807
submissions and zero debt;all refusals preserve both bands/ledger/checkpoint.
Six owner controls pass;
no game installation,actual CSP cost or continuous solver claim. Next bounded
batch/completion integration and economic step selection before sources/optics.
Previous implementation: [s240 whole-interval candidate](RAINFX_S240_WHOLE_INTERVAL_CANDIDATE.md).
The private graph supports1/2/4/8 dyadic steps. Full-grid equal-time local WARP
comparison accepts1/4/8 steps; one step consumes the full16.6664ms interval with
87 submissions/one completion versus267/four,using the same91.193MiB graph.
One-step spatial volume/momentum differences versus8 steps are0.0103%/0.0346%;
four-step End is bit-identical to old s233. This controlled20um fixture is not
natural rain,actual CSP cost or continuous solver qualification. Next bounded
retry/subdivision and batched execution,then continuous queue/source/optics.
Previous implementation and latest actual CPU comparison: [s239 cached CPU identities](RAINFX_S239_CACHED_CPU_IDENTITIES.md).
The versioned composer keeps52 private row strings,uses bit.tohex and reuses pose
encoding without changing canonical bytes or either SHA call.487 identity
comparisons,4096 independent IEEE words,25 capture controls and120-frame
queue/admission pass. Static120-frame encoding calls fall26880→2112; this is a
work count,not a target speedup. A default-OFF paired cost panel is installed:
one coherent sample feeds both composers,120 warmup/480 measured frames,exact
comparison on all600 inputs. Actual frames981–1580 now match600/600 pairs;
mean composition0.360916→0.260773ms/P95 0.8961→0.4709ms improves,while single
max1.4803→2.5821ms leaves a tail warning and the final performance gate open.
Encoding is the largest remaining attributed mean component; standalone capture
and FPS are unqualified. Next compare whole-interval/adaptive execution before
live queue/solver integration. No solver/GPU or visible water change.
Previous actual CPU qualification: [s238 persistent CPU intake](RAINFX_S238_PERSISTENT_CPU_INTAKE.md).
One verified bootstrap now feeds coherent consecutive CPU inputs with zero
per-frame file checks. Local25-case physical-context/dynamic/pause/replay parity,
120-frame time admission and zero-GPU panel/log tests pass. A default-OFF
120-observation input/cost panel passes in actual CSP: frames3153–3272,
120/120 inputs,20 bootstrap file checks,zero duplicates/gaps. Capture-only CPU
mean0.7603675ms/p95 2.0361ms/max3.5412ms is material; production cost remains
unqualified. Next reduce/profile packing and identity work, then compare
whole-interval/adaptive execution. Raising the proof draw limit alone cannot
fix its four sequential receipt boundaries. No solver/GPU is connected here.
Previous local implementation: [s237 bounded time stream](RAINFX_S237_BOUNDED_TIME_STREAM.md).
An owned contiguous-frame FIFO preserves raw time/debt/remainder and splits long
frames into exact-tick intervals of at most31.25ms. It drives the unchanged
private solver locally, retaining stock through two slices of a declared60ms
frame on87 fixed canvases. Pause/duplicate/overflow/reset/receipt guards pass.
This stream owner is local, uninstalled; s238 separately observes actual CPU
intake. A bounded execution budget must still drain real-time input. Current one-draw-per-callback
proof pacing cannot sustain it; capacity overflow is explicit, not dropped time.
Latest actual private-water qualification: [s236 measured-scale provenance repair](RAINFX_S236_SCALE_PROVENANCE_REPAIR.md).
Actual s235 completes its first interval but refuses the second: rotating FP32
pose changes measured scale squared by0.119ppm, tripping exact derived-unit
equality. Failure is archived. The versioned repair keeps configured/applied
scale and calibration exact, then aligns bounded measured-unit roundoff to the
first physical reference. Actual s236 now passes two fresh inputs/eight quarters:
518 submissions/178 cache hits,87 fixed canvases,seven reuses and zero debt.
All88 log lines, context/pose/settings, water budgets and time closure pass;
0.00745058us signed remainder is retained. Complete elapsed-time coverage remains
open; this qualifies two sampled frames.
Previous main integration: [s235 main-app two-input intervals](RAINFX_S235_MAIN_TWO_INPUT_INTERVALS.md).
The default-OFF main panel now captures a fresh second context after the first
interval completes, then retains water/time in the same87-canvas pool. Host,
88-line report/parser and deployment checks pass. Its actual scale-unit refusal
is archived; the s236 repair above qualifies the two-input continuation.
Previous local implementation: [s234 new interval admission](RAINFX_S234_NEW_INTERVAL_ADMISSION.md).
Two immutable input generations now carry private water/time locally:518 draws,
178 cache hits and87 fixed canvases, with no water reseeding or GPU allocation
on the second input. Changed pose/forces refresh input-dependent caches; signed
raw-time remainder persists. Eight lifecycle controls and1024 time carries pass.
Its unchanged owner is installed through s235 and actual two-input execution
passes through s236; complete elapsed-time admission remains open.
Earlier actual CSP qualification: [s233 retained private interval](RAINFX_S233_RETAINED_PRIVATE_INTERVAL.md).
Four retained quarters finish one captured represented dt locally. End/Mean,
checkpoint and ledger copies are exact; one fixed87-canvas slot accepts267
actual draws and81 immutable-cache hits, with no per-quarter GPU allocations.
Protocol/panel guards pass. Actual CSP completes4/4 with267 accepted draws,
81 cache hits, three reuses and zero remaining represented-time debt; all four
water/time receipts and context/pose identities pass.
The [s232 private physical interval](RAINFX_S232_PRIVATE_PHYSICAL_INTERVAL.md)
already passed actual one-quarter execution. Initial water is controlled20µm.
Next complete elapsed-time/subdivision/backlog ownership, conserved incident/head source and renderer
leases/common optics. Visible game water physics remains s87; no FPS claim.
The [s231 private execution boundary](RAINFX_S231_PRIVATE_EXECUTION_BOUNDARY.md)
already passed actual packet-echo completion/reuse observation.
The [s230 CPU partition review](RAINFX_S230_CPU_PARTITION_REVIEW.md) supports
separating deep diagnostics from the runtime path.

- **App.** `realvisor.lua` is a CSP Lua app (CSP 0.3.0-preview; reference
  SDK `lights-patch-v0.3.0-preview634/extension/internal/lua-sdk/ac_apps/lib.lua`).
  - It loads the visor KN5 on a camera-locked node hierarchy.
  - It runs the GPU-persistent rain state machine:
    - `rainStateUpdateParams`: position and velocity (RGBA texels);
    - `rainStateMetaUpdateParams`: radius, mass and lifecycle.
    - Opt-in P1 uses actual volume/SI motion. Opt-in P2 adds physical-area/normal
      birth events and a conserved source/reservoir budget. Opt-in P3 adds spatial
      incident/trail water, paired head loss, evaporation/runoff and physical-height optics;
      supplied 60% water budgets and 3-minute/40-toggle memory observations pass;
      opt-in P4a conserves water with observed comparable FPS, but high Courant fails
      transport time accuracy; s85 diagnoses localized millimetre columns outside
      P4a's regime; s86 integrates opt-in P4b conserved pool-to-P1 return with
      production GPU/Lua/optics gates passed; s87 supplied game water/cost data
      pass with no >1mm columns. Film time accuracy and unified head/field
      motion/optics remain open; view5 compares both in the same UV.
      s88 evaluates offline inertial and long-travel candidates; neither meets
      adoption gates yet. Production remains s87.
      s89 adds view6 to isolate debug channels from scene transmission and a
      positive source-local overlap prototype; physical runtime is still s87.
      s90 generates intervals from frozen velocity, clips connected supports and
      admits ordered maps on GPU; dry-front closure blocks runtime adoption.
      s91 adds bounded dry numerical velocity extension and transports end/mean
      momentum separately; isolated fronts/equal-time/sparse actual-mesh gates
      pass. High-C interacting fronts still fail; runtime remains unchanged.
      s92 implements a finite-width contact candidate, subcell support carry and
      GPU end/mean/support publication. Isolated contact/time checks pass, but
      the hard-width constraint fails continuous curved film; not adopted.
      s93 removes that constraint with pressureless resolved-cell projection and
      positive deposit; actual-mesh two-axis budgets pass. A complete-image
      coherent-point history fixes the specified1D collapse/time counterexample;
      cross-axis history/force/app publication and game cost remain open.
      s94 carries coherent X/Y offsets through both sweeps, validates complete
      bilinear images after source edits, and publishes both-axis stocks/history
      with shared loss rejection. Specified symmetry/mutation/actual-mesh checks
      pass offline; generation/clock, recurrent force, remaining-dt and cost gates
      remain open. Production remains s87.
      s95 stages one immutable source/P4b interval, retains private transport
      progress and exact dyadic time debt, then publishes stocks/ledger/clock
      together. Specified retry/ownership/clock checks pass offline; full live
      lifecycle/queue, recurrent physics and graph fusion remain open.
      s96 connects per-substep curved SI force/current height/evaporation to the
      interval protocol, with applied/wall impulses and snapshot ownership.
      Analytic/retry/actual-mesh budgets pass offline, but coherent numerical
      points lack a physical footprint for their force law; this counterexample
      blocks adoption. Resolved-area closure, full lifecycle and fusion remain.
      s97 compares resolved physical-area donor transport without point history.
      Positive flux/runoff, smooth refinement, exact retry debt and curved SI
      budgets pass. Its diffusion and high-speed global CFL substep demand block
      adoption; use it as a reference for a cheaper multi-cell transport method.
      s98 adds positive limited reconstruction and source-local multi-cell maps.
      Smooth diffusion/large-travel and curved budgets improve; swept overtakes
      refuse without water/time loss. Actual high-shear coarse/finer film differs
      by10.44%, so coupled temporal accuracy still blocks game adoption.
      s99 fixes a wet-presence face-speed jump with conserved-volume weighting
      and completes end-force relaxation at recipient depth while keeping the
      full-interval travel mean. A positive embedded controller audits time
      error/retained debt; its triple-candidate cost is an offline reference.
      s100 fuses recipient force/post with equivalent fields and physical
      ledgers in the specified tests, reducing one embedded attempt76 to73
      draws. Cheap depth/drag proxies fail counterexamples and stay diagnostic;
      the expensive accuracy reference and runtime adoption limits remain.
      s101 folds mean-momentum metric projection into each axis map, preserving
      the specified outputs/transactions and reducing one embedded attempt73
      to67 draws. Dense film repeats projection work (~3x source queries), so
      frozen-interval metric reuse is next; game speedup is unmeasured.
      s102 adds a read-only interval-owned world-basis/Gram cache, reused across
      axes/trials/resumes. Specified26-axis and joint-publication checks match;
      pose/receipt/grid mismatches refuse stale use. Setup costs2 draws and12MiB
      at1024x256; map solves disappear, but game benefit remains unmeasured.
      s103 reuses the owned bases for physical force/post metrics. Independent
      basis-validity bits and format2 preserve physical normals even when Gram
      inversion fails. Specified physical/projection/ownership tests match;
      retained storage and draw counts are unchanged, game timing unmeasured.
      s104 shares one local geometry metric between recipient force and post,
      with independent force/post validation.20 physical cases, accepted curved
      embedded output and accuracy-only refusals match; fused static lines302
      to271 and load lines12 to9, with unchanged cache/pass counts.
      s105 removes unused final mean and impulse/wall outputs from unpublished
      coarse trials.22 component cases and transaction gates preserve consumed
      error/status/loss and full fine ledgers; output extents shrink, draw counts
      stay unchanged. Full coarse diagnostic fallback is retained; offline only.
      s106 omits the unused first-fine final mean, retaining all physical ledger
      rows and the second fine published mean.22 component and transaction
      checks match s105; one post bank is removed, draw/cache counts unchanged.
      s107 omits last-axis mean gathers only for compact coarse/first-fine post.
      All mean-dependent maps/losses and the published second-fine mean remain;
      36 axis comparisons and both-order/fallback/transaction gates match s106.
      Output targets shrink by two banks; draw/cache counts remain unchanged.
      s108 records actual draws and explicit packed-bank copy dependencies,
      then checks exact-size target reuse against retained state and diagnostics.
      Captured-output CPU pool replay verifies every consumer/failure prefix;
      symbolic budgets expose copy cost. No new GPU allocator or runtime change.
      s109 verifies bank-aware integer end/mean inputs against real GPU copy
      oracles. Copies decrease, but bounds-check arithmetic and parent lifetimes
      grow; retain the checked offline ABI, not a claimed performance win.
      s110 proves centre/bounded-source load domains against frozen shader
      fingerprints and exact grid metadata. Only those checks are omitted;
      malformed-run neighbours stay checked. Static work falls, resource costs
      remain unchanged; checked and copy fallbacks pass offline GPU comparisons.
      s111 binds the retained force parent on the first executed axis and copies
      gather banks for the second. Both orders and all fallbacks preserve GPU
      outputs/transactions; copies29 to23 with the s108141.89MiB pool reservation,
      removing s110's8MiB increase. This remains an offline resource policy.
      s112 executes bounded graphs on persistent native D3D11 WARP textures.
      Six pooled/dedicated cases, both curved axis orders and hybrid/copy policies
      preserve every output with zero produced-texture uploads and no debug
      warnings. Prefix/alias guards pass; cross-call GPU ownership remains next.
      s113 keeps public/private/cache parent handles across native calls and
      swaps the complete root bundle only after GPU completion.12 calls include
      five aborts, true GPU checkpoint resume and both curved orders; seven
      protocol guards pass. Later calls add three band copies; no game adoption.
      s114 retains existing logical-band exports and rebases their input
      descriptors. Later fresh calls26 to23 copies, two-attempt resumes44 to38;
      frozen parent outputs and live parent fallback agree. Atomic ownership
      remains; allocation counts increase in these finite sessions, timing open.
      s115 streams one native graph at a time, caps target/input/shader caches,
      owns only current root snapshots and writes statistics incrementally.
      Two131-call schedules verify a stable target plateau and bounded eviction;
      budget refusal preserves existing roots. Recovery/CSP integration is next.
      s116 keeps one immutable pending call and plans all admission changes before
      applying them. Reduced/restored limits, busy/stale/duplicate work and
      cancel/reset preserve physical state; recovered roots match uninterrupted
      execution. Submission/completion separation and CSP integration remain open.
      s117 separates submission, completion observation and explicit finalization
      with one retained flight. Cancel/reset keep resources until completion;
      early publication/reuse refuses, final roots equal s116. Diagnostic staging,
      backend separation, physical accuracy and CSP integration remain open.
      s118 makes per-output diagnostic staging/maps optional; paired full/lean
      native runs preserve all physical work and boundary roots. A portable
      completion contract handles forced pending/failure without early reuse or
      revived publication. CPU oracle ownership and CSP integration remain open.
      s119 separates descriptor-only execution and GPU roots from a test-owned
      oracle harness. Upload leases cover external inputs only and release after
      submit. Paired runs and a nonexistent-oracle native run preserve final GPU
      results; in-memory input-provider/CSP integration remain open.
      s120 adds typed memory packet/provider acceptance with validated, owned
      snapshots and scoped input returns. Producer storage is invalidated after
      entry; four execution paths and14 rejection cases pass. Static template
      reuse and a live CSP data source remain open.
      s121 registers bounded immutable topology templates and binds owned
      per-interval uniforms/inputs/receipts. Four paths pass2104 commands/224
      flights with equal GPU roots; pending/in-flight template clear and16
      rejection cases preserve ownership. Shader layout reuse and CSP remain open.
      s122 caches immutable reflected constant/texture layouts with each shader
      and preflights bound values before GPU submission. Four paths preserve GPU
      bytes; metadata walks9578 to615, buffer creation unchanged. A consolidated
      roadmap/measurement summary separates game evidence from offline counts.
      s123 retains per-flight constant packets and distinct GPU buffers through
      completion, then reuses completed exact-width storage within byte/entry
      admission limits. Four paths pass2288 commands/260 flights; creations5470
      to2088 with equal GPU bytes. Live CSP capability mapping is next.
      s124 audits preview634 app APIs and adds a bounded Lua interval queue with
      separate source/time accounting.16 LuaJIT scenarios/15640 actions match an
      exact-volume reference. Shader readiness is not GPU completion; strict
      submission stays gated until a verified completion policy is available.
      s125 implements a fixed-schema managed-canvas pass bridge with owned typed
      values, compile-pending prefix cursors and separate logical publication /
      physical retirement.16 LuaJIT scenarios/6271 actions and21 guards pass
      against a mock backend;11 SDK blocks agree. CSP adapter stays gated and
      uninstalled; actual layout/ordering/completion require a small probe next.
      s126 packages that default-off standalone probe: asymmetric typed/matrix
      seed, whole-copy/transform and four R32FLOAT channel extractions.27 mock
      LuaJIT cases/658 actions, exact pattern checks and4 synthetic shader
      compiles pass;23 SDK blocks agree. The package is not installed; actual
      CSP layout/range/ordering and general completion remain unverified.
      s127 installs isolated opt-in probes and captures actual preview649 data.
      Seed/matrix, forward copy, signed R32FLOAT and UV controls match exactly;
      the reversed integer Load expression fails while reversed SampleLevel
      matches128 values. Three real observations retain1792 floats and exact
      package provenance. A narrow diagnostic recipe selects the tested branch;
      arbitrary transport readers/completion/production adoption remain open.
      s128 observes3 parent grids and6 address/bank reader forms on actual CSP.
      All6912 readback values match, including504 explicit guard zeros; signed
      integer Load is valid on this tested path. Retain integer readers as
      candidates; generic solver ABI/live stocks/completion/cost remain open.
      s129 installs exact s109/s110 helpers, original End/Mean wrappers and
      solver uniform names in an isolated default-off CSP app.14 descriptor
      guards/lifecycle cases,15 decoder cases and9 synthetic compiles pass;
      actual7680 values match exactly, including576 guard zeros. Texture
      arguments/End-Mean packet ABI pass; full consumer/live solver remains open.
      s130 runs both-axis map/loss/group/totals/full/end-only gather consumers.
      All48 original logical/bank pairs match on CSP, but normal Y runoff is
      falsely refused after sub-microcell boundary differences. Preserve the
      original failure; a precise candidate removes false Y refusal on CSP.
      All96 pair comparisons match across both versions; strict analytic map
      equality still fails by4.768e-7 cell. Live solver/cost gates remain open.
      s131 traces quotient/projection/endpoints and samples real visor basis
      for sequential XY/YX plus internal cuts.198 WARP draws/17 compiles and
      bounded capture controls pass. Actual98304 floats retain72 bit-identical
      consumer pairs and scoped sequential budgets/admission. Traces locate
      a1-ULP quotient difference removed by diagnostic residual refinement;
      the unchanged strict affine gate remains false. No live model adoption.
      s132 applies residual correction in mass/Gram/face map divisions.318
      WARP graph/affine draws and49152 rational quotient checks pass. Actual
      98304 floats/72 matching pairs close the signed-affine strict gate with
      zero map error; curved budgets pass. Synthetic maps add44 slots with
      equal load sites; actual timing/live adoption remain open.
      s133 tests all8 correction masks over4 fixed fixtures. Actual166784
      selected-root floats/192 matching pairs reproduce native/full controls.
      Only mass+face and full correction pass exact affine maps; mass+face
      saves16 synthetic slots. Curved near-zero error remains; an uninstalled
      exact-source prototype is exported, without live adoption.
      s134 derives conditional arithmetic enclosures from that expression graph.
      All8736 reused actual curved endpoint checks fit; near-zero cancellation
      is separated from absolute UV-atlas error. Eight frozen input receipts
      guard offline identity only; runtime admission/completion remain open.
      s135 composes the exact selected curved recipes with the retained queue
      and managed bridge.64 WARP draws preserve frozen outputs;17 lifecycle
      cases/12 binding guards pass with mocked completion. Roots/time publish
      together; cancelled flights remain held. Fixed replay is not live adoption.
      s136 replaces six seed passes with canonical borrowed input leases and
      retains26 downstream passes.104 WARP draws/56 field checks and37 lease
      cases pass; private outputs never dispose inputs. Immutable leases and
      completion are mocked; actual CSP import evidence remains next.
      s137 prepares a default-off standalone producer/import/prefix probe.
      Four cases capture all32 fields in228 log lines;132 WARP draws/13 strict
      bodies,19 controller/15 decoder controls pass. Actual42240 floats pass
      56 strict controls/48 matching pairs/16 end-only checks;14 calls retry
      without accepted-prefix replay. Used resources stay retained; no fence.
      s138 binds dynamic interval snapshots to thirteen imported stocks/headers
      and a genuine GPU substep plan before the unchanged26 consumers.282 WARP
      draws/13 strict bodies,29 snapshot/29 header guards and19 lease cases pass.
      Legacy P3 channels are explicitly incompatible; this adapter is uninstalled.
      s139 prepares an isolated genuine-header/partial-time CSP probe: five
      eligible intervals and three refused plans.250 WARP draws/17 bodies,
      19 controller/16 decoder/9 scratch installer controls pass; actual pending.
      Actual s139 faults at its40-texture extraction versus CSP's32 limit.
      Separate s139v2 pages capture at24 bindings maximum;255 WARP/19 bodies,
      22 controller/16 decoder/9 installer controls pass. Actual v2 captured;
      s140 corrects the evaluator's mixed WARP/actual source reference.25 actual
      source/64 header controls,5 plans/3 refusals,60 pairs/20 end-only/3640 bounds
      pass with the original mismatch preserved. No new game run or live adoption.
      s141 constructs genuine physical End/Mean from accepted source/head packets,
      resolved area and force snapshots, runs the observed transport and recipient
      force/evaporation, and exports conservative candidate/ledger roots.958 WARP/
      24 bodies,20 physical/refusal cases and6 lease cases pass; uninstalled.
      s142 decodes actual P1/P2/P3 raw channel formats into physical head/source
      descriptors with exact paired debits and codec-independent world velocity.
      330 WARP/4 bodies,39 cases,24 recurrent and6 lease checks pass offline;
      merge/exit ownership, field rasterization and joint publication remain open.
      s143 adds reciprocal full-generation merge ownership and the original
      transport's retained last-valid exit state; numerical exhaustion refuses
      without runoff.263 WARP/6 bodies,32 cases,3 original-state controls and6
      lease cases pass offline. Source raster/joint owner/live wiring remain open.
      s144 deposits paired head/impact packets into physical film and separate
      micro, debits pool returns, and gates inventory/cumulative-ledger/source-phase
      candidates together.555 WARP/16 bodies,27 cases,4096-slot/1024x256 gates and6
      cumulative/6 lease cases pass; field time debt is retained, uninstalled.
      s145 connects source-applied film to unchanged s141 field transport, retains
      separate micro/heads and consumes matched remaining debt without source/pool
      replay. Both orders and recurrent source/transport intervals pass offline;
      phase-2 candidates do not publish a clock or prove GPU completion. Runtime
      adoption, actual source hooks, accuracy and measured cost remain open.
      s146 captures world incident/normal/initial-head velocity inside the original
      P2 calculation, preserving event bits while producing explicit retained
      film/micro/rebound packets.438 WARP/43 bodies,37 cases,actual curved assets
      and4096 slots pass. Frozen context/identity descriptors and offline s144→s145
      connection pass; shared frame owner and actual callbacks remain open.
      s147 owns the offline birth→heads→source→transport chain with immutable
      identity, exact parent handles and output pins.29 owner cases/6 frame/6 root
      guards and161 WARP/46 bodies pass, including tracked final readers. Actual
      P1/source callbacks, persistent stock handoff and live fence stay open.
      s148 produces SI force/advance/meta and P3 transfer descriptors from raw
      previous states, matching birth roots and creator-sealed full merge
      generations.21 head cases/276 WARP/12 bodies include4096 slots and an
      independent force oracle. Stable contact-angle/exponential evaluation fixes
      the preserved original-core precision failure. Actual game hooks, persistent
      inventory publication, CSP binding layout and completion remain open.
      s149 copies raw heads/meta, physical stocks/ledger/checkpoint and previous
      pose into an independent bounded inventory bank. Original graphs retire
      before next-identity provider reads.41 owner/inventory scenarios and175
      WARP/57 strict bodies cover copy, rejection and two-bank reader lifetime;
      authentic engine inputs, recurrent live execution and CSP completion remain
      open. Only a private offline clock changes.
      s150 routes protected next-frame inputs to retained bank allocations and
      runs three full physical intervals with supply on/off/on.7 scenarios,
      525 WARP/57 bodies and24 copies pass; cumulative supply is unchanged in the
      dry-supply interval. Stale force-header refusal is preserved. The short
      fixed-planar fixture does not establish curved/feedback accuracy, actual
      CSP lifetime or performance; engine uploads and live completion stay open.
      s151 packages a default-off focused-car engine observation/common header
      upload probe.15 input/8 controller/8 decoder cases and6 WARP/2 bodies pass;
      actual CSP frame866 returns all50 rows/200 values bit-identically.
      Car-reference pose and probe material
      constants are explicit; readback never enables general completion or the
      solver. The main app remains unchanged.
      s152 adds a default-off main-app context capture after scene preparation:
      actual rain-mesh pose, physical settings, units and verified asset files.
      27 context/9 hook/6 decoder cases and20 WARP/5 bodies pass; display gains
      leave physical identities unchanged. Actual main frame745 passes52 rows /
      208 values, pose/unit/settings identities and force relationships;
      GPU resource leases/completion and recurrent solver adoption remain open.
      s153 creates a bounded read-only GPU input domain: seven actual static
      physical textures plus the frozen52-row context, with full-texel numerical
      fingerprints.33 WARP/8 bodies and14 managed cases pass; actual main frame939
      matches all8 fingerprints after31 passes.31 canvases/52.934MiB stay retained;
      the R32 boundary ABI is explicit, and general completion/solver adoption
      remain unapproved.
      s154 derives actual1024×256 world U/V/Gram, baked world area and connected
      support runs in a retained input cache. Full-grid audits and16 CPU samples
      pass locally:69 WARP draws/17 strict bodies,19 controller/5 hook checks.
      One34-pass diagnostic retains56.5874MiB and emits42 lines. Actual main
      frame660 passes with0 invalid/123,224 supported cells and all16 CPU samples
      within tolerance; no new water evolution or recurrent adoption.
      s155 binds the reconstructed actual-frame cache to unchanged physical film
      force on1024×256.106 WARP/9 bodies cover17 full-grid cases, original bit
      parity and SI scaling. The16MiB four-band force buffer dominates private
      cost; compact outputs/readers are next. Offline only; no new game test.
      s156 halves force storage/calls with explicit compact status/exchange
      readers. End/Mean and downstream physical stocks match; reconstructed
      impulse/ledgers retain the existing closure bounds.1,289 WARP/40 strict
      compilations pass across actual-grid force and small-field full continuations.
      Remaining retained stack68.60321MiB; actual-grid full-frame budget and live
      recurrent completion are still open. No game change or new user test.
      s157 copies exact field-centre du/dv values into a restricted input domain:
      owned world-field bundle56.5874→32.3992MiB, with full cache bit parity.
      Parameterized continuation passes actual1024×256 force/transport/ledger
      and a second physical time-debt quarter;878 WARP/42 strict compilations.
      Full reference graph199.9678MiB still exceeds the live owner budget;
      next remove comparison/unconsumed intermediates. No game change or new test.
      s158 selects checked bank transport and removes unreachable comparison,
      extraction and commit copies. Actual-grid continuation73→50 passes and
      199.9678→130.3114MiB; bit-parity/rollback/ledger/debt checks remain offline.
      Micro/head roots alias retained immutable inputs; no target reuse or
      completion claim. The64MiB owner budget and live adoption remain open.
      s159 specializes source-applied staging to a guarded identity input,
      reads compact force bands directly and stores only recipient End/Mean.
      Actual-grid50→46 passes and130.3114→85.8104MiB;1,952 WARP/33 strict bodies
      preserve physical roots exactly and ledger/closure bounds. The56.8288MiB
      static frontier is not completion/reuse proof; full retained cost remains
      above64MiB. Next tiled status reduction and bounded target lifetimes.
      s160 fuses source/post predicates with first16×16 max reductions: actual
      graph46→44 passes,85.8104→77.8104MiB.50 independent tile cases and23 paired
      continuations pass;1,964 WARP/33 strict compilations, all non-injected roots
      and tiles bit-exact. Static peak56.8288MiB is unchanged. Proposed exact-shape
      pool61.7945MiB plus retained cache74.1937MiB remains analysis, not actual
      reuse or completion proof. Next shorten donor force's ledger lifetime.
      s161 reduces donor exchange before transport and removes the late force
      read from the ledger. Physical roots retain bits; ledgers/closure keep
      inherited bounds.26 paired/18 independent cases pass:2,103 WARP/34 strict
      compilations. Static peak56.8288→48.8288MiB, with cache61.2280MiB; separate
      allocation grows34.4KiB/4 passes. Proposed exact pool plus cache66.2272MiB
      still exceeds64MiB. Next packed final End/Mean and checked band consumers.
      s162 packs final End/Mean with explicit checked row-band views and direct
      packed resume.29 graph pairs plus malformed-shape/refusal/retry controls
      pass:2,668 WARP/63 strict compilations, non-injected roots/ledgers bit-exact.
      Actual graph48→47 passes, unchanged77.8440MiB separate fresh allocation.
      Proposed pool+cache62.2272MiB fresh, but66.2272MiB recurrent because the
      prior2H input bank stays leased. Recurrent64MiB gate and native pool/
      completion remain open; no game change or timing claim.
      s163 stores validated film area as R32F while retaining binary32 values
      and malformed-metadata refusal.34 graph pairs plus cache/retry controls
      pass:3,280 typed WARP draws/73 strict compilations, physical roots/ledgers
      bit-exact. Cache32.3992→29.3992MiB;recurrent exact-pool+cache proposal
      66.2272→63.2272MiB (0.7728MiB margin). This is the scoped descriptor gate;
      separate retention, real pool/completion and complete app budget remain
      open.47 transport passes;main/game unchanged. Next native typed pool.
      s164 executes the frozen typed graph on a native WARP immediate context.
      Separate/pooled roots and first two actual s163 quarters retain bits;
      1,258 draws,32 completed event fences and six pre-device refusals pass.
      Actual default-texture descriptor peak91.2432→63.2272MiB, with35 private
      slots reused across eight submissions. In-flight/failed/observer-held
      admission cannot mutate state;explicit observer return precedes reuse.
      Audit staging is separate;general CSP completion, new-frame cache/input
      ownership, head/birth/optics and measured game cost remain open.
      s165 continues the native pool through four controlled zero-source frames,
      with a two-frame waiting queue, explicit observer return and quarantined
      cache replacement/retry.3,024 solver draws plus two cache draws pass;
      64 quarter publications retain water/time closure and separate/pool bits.
      Actual scoped peak63.227219MiB adds32 bytes; only changed metric uploads
      are needed. Nonzero source/head evolution, real input cadence, CSP
      completion and full app/optics cost remain open. No game changes/test.
      s166 runs real birth/SI heads/source and four packed transport quarters
      from retained native inventory on the13×7/8-slot reference. Source
      on/off/on, completion retry and source replay refusal conserve water;
      all48 inventory copies and separate/pool payloads retain bits.1,236
      draws/62 real events pass. Actual source diagnostic roots plus cache
      already need74.134MiB;compact source stages before full-grid admission
      and composition with s165 backlog/cache. Main/game remain unchanged.
      s167 removes the7H source atlas and full status image with shared cell
      evaluation/direct tile status. Full-resolution4096-slot sparse source
      plus reserved cache92.273→60.210MiB; all public source/pipeline roots
      retain reference bits.24 small cases,full-resolution pair and recurrent
      chain pass1,556 draws/88 events. Full joint head/source/transport bank
      retention still needs its own64MiB plan;main/game unchanged.
      s168 plans two joint frames with actual head geometry, previous/new
      inventory and explicit readers. Field-centre geometry cannot substitute
      for head inputs; native boundary/source-cell adapters remain unverified.
      Minimal current-cache plan:122.687MiB live,133.501MiB typed reservation;
      total64MiB gate fails. Core cache/R8 are unverified alternatives; a split
      128MiB policy is comparison only, not adopted. Zero GPU draws/game changes.
      s169 verifies binary R8 boundary storage (12MiB descriptor saving) and
      independent-resolution/red-channel birth/head adapters.317 WARP draws,
      28 producer graphs, all4194304 actual boundary texels and8192 actual
      geometry/address samples pass. Frozen legacy roots retain bits; a narrow
      hole still causes exit. Current-cache joint estimate remains121.501MiB
      reserved;source-cell/view adapters and combined64MiB gate remain open.
      s170 implements the two-pass raw coverage/R32F physical-area→resolved
      source-cell adapter.262144 actual cells/1809 partial cells retain bits;
      23 old source fixtures match,10 added faults roll back exactly.527 WARP
      draws/36 graphs pass. Real adapter/header lifetimes add1664 reserved bytes;
      current R8 joint proposal121.503MiB still fails64MiB. Packed-End views and
      current-frame cache/header ownership remain open;main/game unchanged.
      s171 adds a checked packed-End source view;491 WARP draws/31 graphs
      retain23 prior source results,including pool/rollback. Changed/NaN Mean
      cannot enter End reads;full-grid view bounds pass. Direct reads save4MiB
      versus packed+crop,but retain4MiB more than an End-only bank. Six joint
      plans preserve the End-only baseline121.503MiB as smallest;packed direct
      is optional,not adopted. Static/working lifetimes remain to optimize.
      s172 builds all34 actual cache textures natively,then retires29 after
      observed event completion,audit and reader return. Core cache29.399→
      21.001MiB;unchanged force/source-cell readers retain all bits.118 GPU
      draws/5 real events pass;pending,stale,read-held and failed caches refuse
      unsafe retirement/consumption. This verifies one private native generation;
      CSP diagnostics remain retained. Core joint estimate113.104MiB still
      exceeds64MiB;frame/cache composition and working lifetimes remain open.
      s173 composes native core retirement with a bounded immutable frame cache:
      two generations/two waiting contexts,weather-only metric sharing and rigid
      pose rebuild. Four contexts,failed preparation/retry and held old readers
      pass247 draws/19 real events;full-grid physical bits and force oracle pass.
      Replacement descriptor peak89.019MiB is charged under the local96MiB cap.
      Stock stays immutable;solver clock/source/head/transport are not composed.
      Joint64MiB and live admission remain open;game unchanged. See
      `RAINFX_S173_BOUNDED_FRAME_CACHE.md`.
      s174 combines bounded immutable cached inputs with nonzero source/head/
      transport and atomic whole-frame bank/cache/time publication on13×7,
      eight slots.618 draws/37 real events/32 bank copies pass;all physical and
      committed inventory bits match s166. Cache/source/copy failures,replay,
      held old cache and time closure pass. Actual-grid plan113.104MiB refuses
      before device creation. The actual s173 cache builder/curved physical
      stream remain uncombined;full64MiB and runtime adoption are still open.
      See `RAINFX_S174_BOUNDED_PHYSICAL_HANDOFF.md`.
      s175 stores full2048×512 FP32 head geometry as an exact pair dictionary:
      index plus FP32 tables32→8.71875MiB,with no spatial resampling or value
      quantization.140 native draws/30 strict bodies retain full decode and
      physical fixture bits. Warm joint proposal113.104→89.823MiB still fails
      total64MiB;whole-pipeline allocation/cold replacement are unexecuted.
      Dependent loads increase selected static shader instructions;timing is
      unmeasured. Actual curved head transaction is not admitted by this test.
      See `RAINFX_S175_LOSSLESS_GEOMETRY_DICTIONARY.md`.
      s176 connects that prebuilt dictionary to all34 actual cache build passes,
      bounded pose replacement/retry and a shared full-resolution head-geometry
      probe.83 draws/11 real events retain all prior cache/force/source-cell bits
      and all dictionary/probe bits. Raw du/dv GPU uploads are removed;dictionary
      stays leased for readers. Component replacement peak89.019→70.379MiB still
      exceeds64MiB;full SI head/source/transport and clock remain uncombined.
      See `RAINFX_S176_DICTIONARY_CACHE_OWNER.md`.
      s177 leases individual resources and returns completed unleased previews,
      preserving older geometry readers and refusing held-force eviction.
      The same83 draws retain all output bits;13 real events include two extra
      force-observer audits. Component peak70.379→58.362MiB now fits its scoped
      default-texture64MiB ceiling;separate staging46.095MiB is excluded.
      The complete physical pipeline and whole-app64MiB gate remain open.
      See `RAINFX_S177_RESOURCE_READERS.md`.
      s178 verifies two1×1 neutral inputs for the immutable wet/pool OFF profile.
      618-draw native physical recurrence retains root/inventory/time bits;
      44 extra4096-slot birth draws retain original/compact bits. Enabled feedback
      refuses this path. Full warm proposal89.823→85.808MiB still exceeds64MiB;
      all16 physical force and2 source-cell lifetimes are preserved. Cache-owner
      composition and actual-grid recurrence remain open.
      See `RAINFX_S178_DISABLED_FEEDBACK.md`.
      s179 transfers seven completed immutable roots into the pending bank,
      preserving independent film End copies and atomic reader/cache/time guards.
      618 draws/37 events retain all physical/inventory bits;bank copies32→4.
      Full-grid logical copy traffic drops8.375MiB per publication,but the warm
      pool falls only48B and remains85.808MiB. Memory work must target force/map/
      gather overlap;actual-grid cache/physical ownership is still uncombined.
      See `RAINFX_S179_IMMUTABLE_BANK_HANDOFF.md`.
      s180 adds an explicit End-only interval profile when no external Mean
      consumer is requested;internal force/gather Mean calculations stay intact.
      615 recurring native draws plus141 actual-grid operator draws retain End/
      stock/time bits. Source duplication becomes a direct handoff;quarter
      outputs become H-row textures. Warm live74.992→70.992MiB and reservation
      85.808→77.808MiB still exceed64MiB. Mean consumers require the packed path;
      complete actual-grid cache/physical ownership remains uncombined.
      See `RAINFX_S180_END_INTERVAL_HANDOFF.md`.
      s181 packs the FP32 world metric12→8MiB without changing field samples.
      Four actual GPU cache reconstructions and recurrent physical/bank outputs
      retain original bits across766 final-configuration draws. A precise-helper
      variant with physical bit drift is retained and rejected. Warm live drops
      to66.992MiB,reservation73.808MiB;64MiB still fails. Packed construction must
      join the actual-grid immutable cache owner;target timing remains unmeasured.
      See `RAINFX_S181_COMPACT_WORLD_METRIC.md`.
      s182 connects the packed producer to actual-grid native cache construction,
      weather reuse,pose replacement,old readers and failed/retried generations.
      83 draws/13 events preserve logical metric,force,head lookup and audit bits.
      Cache component peak58.362→54.096MiB admits the previously refused held-force
      pose. Whole warm reservation stays73.808MiB;this realizes the saving already
      counted by s181. Complete physical ownership and general CSP completion remain
      open;no water/clock evolution or game change.
      See `RAINFX_S182_PACKED_METRIC_CACHE_OWNER.md`.
      s183 rejects map/gather/post size-only changes that increase reserved slots.
      It stores bounded integer connected-run edges exactly in RGBA16F:4→2MiB,
      with automatic identical FP32 shader reads and no new shader body/draw.
      Actual-grid cache plus small recurring physics pass698 draws/50 events
      with identical outputs,water/time and bank bits. Full warm live64.992MiB/
      reservation71.808MiB still fail64MiB;physical last readers remain intact.
      No game change or new test;next reduce remaining working/bank/static overlap.
      See `RAINFX_S183_EXACT_INTEGER_RUN_STORAGE.md`.
      s184 packs raw-cell FP32 area/coating bits and quarter coverage into two
      UINT32 words. Actual retained cells4→2MiB;83 native draws/13 events retain
      all cache/force/resolved-source/audit bits. No extra draw;ten typed consumer
      wrappers change. Proposed live62.992MiB now fits64MiB,but reservation
      69.808MiB and complete actual-grid ownership still block the overall gate.
      Existing reader/adapter gates remain;no game change or new user test.
      See `RAINFX_S184_EXACT_CELL_WORD_STORAGE.md`.
      s185 adds preflight retirement of completed,unreserved free typed textures.
      A224KiB small native owner passes615 draws/37 events with exact physical/
      bank bits and no new GPU work;14 evictions add11 texture creations. An
      independent full warm descriptor proof fits63.998932MiB with only1120B
      margin,111 physical generations and35 retirements. Permanent reservation
      stays69.807526MiB;the bounded path is an alternative,not full adoption.
      Next reduce churn/increase margin,then execute actual-grid joint ownership.
      See `RAINFX_S185_BOUNDED_FREE_SLOT_RETIREMENT.md`.
      s186 compares five retirement policies;all four alternatives increase warm
      creation traffic/count,so largest-first stays selected. Two native615-draw/
      37-event runs preserve exact physical/bank bits. Independent simultaneous
      typed-shape witnesses prove the unchanged phase layout needs63.991043MiB,
      leaving at most9392B below64MiB regardless of victim order. Next reduce
      transport-intermediate storage,then execute full actual-grid ownership.
      No runtime change,FPS claim or new user game test.
      See `RAINFX_S186_RETIREMENT_POLICY_AND_PHASE_FLOOR.md`.
      s187 implements an exact seven-FP32-word End/Mean packet candidate across
      all four private two-bank intermediates.615 recurring plus153 actual-grid
      operator and10 codec draws retain physical/bank/root bits. Phase floor
      falls2MiB to61.991043MiB,but permanent typed reservation grows6MiB and
      modeled creation traffic plus logical producer evaluations increase.
      Candidate stays experimental;keep s185 storage. Next evaluate supported
      paired output that avoids repeated cell evaluation. No game test or change.
      See `RAINFX_S187_SEVEN_WORD_PACKET_CANDIDATE.md`.
      s188 finds no documented paired/MRT output route in the two audited app
      SDKs;two single-target outputs also fail the descriptor comparison. An
      exact static geometry codec instead packs integer du.w/binary dv.w tags
      with six untouched xyz words. Two tables become one,saving608KiB and one
      binding.119 standalone draws retain all geometry/birth/head bits. Warm
      modeled63.5MiB retention peaks66,572,192B,leaves536,672B under64MiB,and
      creates107 generations versus111. Next connect this input generation to
      a native retained owner;full joint/CSP/timing adoption remains open.
      See `RAINFX_S188_GEOMETRY_WORDS_AND_OUTPUT_GATES.md`.
      s189 connects packed geometry to the private actual-grid retained cache.
      All logical cache/force/head preview bits remain identical across83 draws;
      native peak49.502457MiB and retained25.500793MiB are608KiB lower. A paired
      input-rebuild test adds4 native events/0 draws,covering upload,failure,
      quarantine,retry,old readers and exact8.125MiB whole-pair retirement.
      Total83 draws/17 events;arbitrary asset changes/full joint water/time/CSP
      and timing adoption remain open. Next compose the full actual-grid owner.
      See `RAINFX_S189_OWNED_GEOMETRY_INPUT_GENERATIONS.md`.
      s190 replays the entire two-frame schedule's actual typed GPU allocations:
      523 logical resources,107 backing generations,29 retirements and35 phases.
      Imported real cache bits match;2,890 three-texel read checks pass. Cold and
      warm peak66,572,192B fits the63.5MiB retention limit;cleanup reaches0B.
      Warm writes are diagnostic canaries,not physical shader results. Extra
      geometry revision at the high frontier refuses before allocation. Next
      bind the actual physical shaders and recurrent bank/time publication;
      the full physical64MiB/CSP/timing gates remain open. Main/game unchanged.
      See `RAINFX_S190_FULL_SIZE_NATIVE_ALLOCATION.md`.
      s191 replaces canaries with the actual physical graph:two controlled
      fixed-context intervals,4096 heads and1024x256 field;recurrent GPU banks
      and solver time publish together. Independent source and physical-world
      force comparisons pass;one legacy UV-component diagnostic remains failed
      and is documented. Positive/zero-arrival runs conserve water/momentum.
      Default texture peak63.488190MiB,107 warm generations,29 retirements and
      final0B match the lifetime certificate. Native fixed-context physical64MiB
      gate passes;cache refresh,long runs,CSP,timing and common optics remain
      open. Main/game unchanged,no user test.
      See `RAINFX_S191_FULL_SIZE_PHYSICAL_OWNER.md`.
      s192 composes controlled forcing/rigid-pose cache refresh with that actual
      physical owner. Same-pose metric sharing and new-pose metric replacement,
      failed preparation/retry,old-reader waits and preserved water/time pass.
      Two independent full-field/force audits and per-generation inventories
      pass at63.488983MiB peak,final0B;16 bad packets refuse before device creation.
      Native controlled-refresh64MiB gate passes. Long recurrent runs,CSP,target
      timing and common optics remain open. Main/game unchanged,no user test.
      See `RAINFX_S192_PHYSICAL_CACHE_REFRESH.md`.
      s193 adds a64-interval recurrent graph and three-request admission queue.
      Actual execution commits26 intervals,then refuses a genuine Y donor-map
      reversal in interval27. Independent Float64 widths are negative;the64-
      interval gate FAILS. Numerical refusal now quarantines work and preserves
      the prior bank plus active/waiting debt. Observed peak63.488983MiB,final0B.
      Next bounded adaptive transport recovery before long-duration/timing/live
      tests. Main/game unchanged,no user test.
      See `RAINFX_S193_RECURRENT_STREAM_REFUSAL.md`.
      s194 reproduces that refusal in an isolated full-grid native replay and
      recovers all remaining786432 ticks with9 accepted adaptive substeps.
      GPU shared-face/support bounds match independent Float64 evaluation;
      conservation,rollback and exact debt pass without repeating source water.
      The joint owner/queue/callback budget is not integrated;64-interval gate
      remains open. Bound buffers also require reuse/retirement to fit63.5MiB.
      See `RAINFX_S194_ADAPTIVE_TRANSPORT_RECOVERY.md`.
      s195 integrates adaptive retry/carry into the counted native owner and
      three-request queue. All64 intervals and exact1.080139s publish;3 refusals
      recover with265 bounded pumps/262 accepted substeps.4KiB+16B bound targets
      fit at63.492905MiB peak;final0B. A forced one-attempt budget safely stops
      with the previous bank/debt preserved. Native64-interval gate passes;
      actual CSP callbacks,long-duration,target timing and live optics remain open.
      See `RAINFX_S195_BOUNDED_OWNER_RECOVERY.md`.
      s196 caches immutable upload/phase/transport-role indexes. Independent
      exhaustive checks pass1088 phases;all1.457GB retained GPU readbacks and
      stock/debt traces match s195 bits. Repeated resource scans are replaced
      by direct lookup/candidate visits;GPU work and63.492905MiB peak stay equal.
      WARP/debug lookup measurements are not game FPS/target GPU results.
      Next bounded reusable metadata/input templates before longer recurrence.
      See `RAINFX_S196_INDEXED_DISPATCH.md`.
      s197 shares56 command schemas and decodes one interval's input/draw window.
      Active inputs peak12.38MiB initially,then0.128MiB;commands peak235 instead
      of14977 retained together. Full64-interval GPU bits and indexes match s196;
      six native parser refusal controls pass. Remaining unrolled lifetime/frame
      metadata means total bounded CPU streaming and longer recurrence stay open.
      See `RAINFX_S197_PACKET_WINDOW.md`.
      s198 binds two first/recurrent phase/frame structures to original bank IDs.
      It retains17 phase indexes/7 upload keys,34 phase recipes/boundaries and2
      frame templates. All64 physical/GPU results and complete index bits match
      s197;60 binding probes and4 role/bounds refusals pass. The16085-resource
      table remains;total CPU streaming,long-duration and live gates stay open.
      See `RAINFX_S198_METADATA_TEMPLATES.md`.
      s199 replaces the retained16085-resource table with523 immutable prototypes
      and a current/previous/bootstrap cache of at most523 descriptions;typed
      shape entries peak109 instead of1037. Pool objects retain exact occupant
      last use so older descriptors can leave the cache. Full64-interval GPU/
      index bits and225553 lifetime checks pass. Fixed-run audit/history and
      transient proof metadata keep total CPU streaming/long-duration gates open.
      See `RAINFX_S199_RESOURCE_WINDOWS.md`.
      s200 replaces all-frame acceptance with one current counter,stores diagnostic
      IDs on live objects and replaces global audit/decision sets with518/8
      normalized prototype entries. No expired weak-key index remains. Full64
      and newly executed forced-stop traces/GPU bits retain their references;
      named recurring metadata caps pass. Whole-provider/startup streaming and
      longer continuous execution remain open;next extend beyond64 intervals.
      See `RAINFX_S200_BOUNDED_HISTORY.md`.
      s201 extends that owner to256 contiguous controlled intervals(4.320557s).
      Seven numerical refusals recover with unchanged acceptance/budget policy;
      all time publishes and first64 GPU/input bits match. Recurring metadata
      caps and63.492905MiB scoped default-texture peak stay equal. True long-
      duration/live-weather,whole-provider CPU streaming and target timing remain
      open;next separate diagnostic reads/file work from native execution cost.
      See `RAINFX_S201_EXTENDED_RECURRENCE.md`.
      s202 separates optional full-image archives from control captures. Both
      256-interval runs retain physical/debt/ownership traces and final bank bits;
      forced-stop protection also matches. Archive reads1.976GB to0.443MB;
      required cache/stock/adaptive/decision reads still9.044GB. The two WARP
      wall observations stay near192s,so no end-to-end speedup is established.
      Next compact required validation with full-reference/failure checks;
      target timing and CSP/live adoption remain open.
      See `RAINFX_S202_DIAGNOSTIC_CAPTURE_POLICY.md`.
      s203 integrates complete tiled FP64 stock checks with outward error bounds
      and original full-image fallback at ambiguous acceptance boundaries.25
      component cases and shadow/compact256-interval plus stop controls pass.
      Physical final banks/debt remain unchanged;stock reads2.164GB to1.626MB.
      One extra validation draw per check and6192B temporary typed scratch keep
      the scoped cap,with2080B margin. Target FP64/cost and CSP/live gates remain;
      next compact the remaining6.821GB cache validation reads.
      See `RAINFX_S203_COMPACT_STOCK_VALIDATION.md`.
      s204 reuses full metric snapshots only for identical source/format/extent,
      post-build write epoch and lease.143/271 preparations eliminate1.200GB
      read results and staging copies;cache reads6.821GB to5.621GB. Full byte
      predicates,256-interval physical/stock/debt outputs and stop guards match;
      no extra draws,uploads or default textures. Target hardware cost is next
      before a larger cache rewrite;CSP/live gates remain open.
      See `RAINFX_S204_CACHE_SNAPSHOT_REUSE.md`.
      s205 executes hardware preflight on detected RTX 3070 adapter 0. Exact-byte
      mutation controls and isolated ABBA duplicate-copy/read timing pass.
      Complete physical execution is refused at the original exact bootstrap
      gate: world-metric rounding changes 30 atlas words, while full immutable
      inputs/support/areas/runs match. Independent float64 full-field diagnostics
      pass existing bounds; no replacement reference or physical clock is adopted.
      Next qualify both backend metric references before integrated hardware
      timing. Component timing is not a pipeline speedup or game FPS result.
      See `RAINFX_S205_HARDWARE_PREFLIGHT.md`.
      s206 independently qualifies both pose-dependent RTX 3070 geometry caches,
      binds complete inputs/shaders/reference/executable/adapter/driver in an
      immutable receipt, and passes four exact debug/release cache rebuilds.
      Twenty invalid CPU qualifications, eight provenance faults and two one-bit
      GPU corruptions are refused. This is a standalone cache consumer; complete
      physical-owner admission and hardware 256-interval/stop gates remain next.
      See `RAINFX_S206_BACKEND_REFERENCE_QUALIFICATION.md`.
      s207 binds those references to the full native hardware owner. Explicit
      precise packet arithmetic and a zero-debit identity fix hardware source
      refusal without loosening predicates. Hardware shadow/reuse complete 256
      intervals with identical state/stock/time, protected 26/29 budget stop and
      unchanged scoped texture peak. Three v2 provenance faults are refused.
      Full profiling coverage, physical accuracy and CSP/live adoption remain.
      See `RAINFX_S207_HARDWARE_PHYSICAL_ADMISSION.md`.
      s208 instruments explicit draws/uploads/copies, allocation/readback APIs and
      event poll/sleep without changing the solver or waits. Debug 256-interval
      parent parity and protected stop pass. Requested 1 ms sleeps average 14.23 ms;
      adaptive-bound GPU work, previously omitted, totals 11.09 s. An initial
      release cache-reference refusal remains unresolved despite later passing
      observations; release qualification precedes optimization. No FPS claim.
      See `RAINFX_S208_HARDWARE_OPERATION_PROFILE.md`.
      s209 validates a refusal-only collector with distinct CPU-result/GPU-cache
      one-bit controls. Four full 256-interval runs, including AddressSanitizer,
      retain complete parent parity; the original failure does not reproduce.
      Frozen contexts and 370 original inventory snapshots narrow the missing
      interval to frame7 validation through frame8 shared-metric comparison.
      Original root cause and release recurrence qualification remain open.
      See `RAINFX_S209_CACHE_REFUSAL_CAPTURE.md`.
      s210 adds21 bounded witnesses across frame7 physical/stock work and frame8
      configuration/cache validation. Existing event counts stay unchanged;
      36 diagnostic copies use those completions. Full hardware parent parity
      and protected stop pass. CPU-expected/GPU-retention/shared-selection controls
      locate their first changed row; the original natural cause remains open.
      See `RAINFX_S210_RETAINED_METRIC_WITNESSES.md`.
      s211 adds bounded fresh-process nine-interval trials, preserving three
      accepted but unstarted contexts as queued debt. Four natural prefixes
      match, and an injected second-trial fault stops the batch before trial3.
      Full256/26-29 stop parity remains; no natural recurrence or root-cause
      qualification is claimed. Independent immutable-stream wait characterization
      can proceed as a non-adopted experiment while the cache issue stays open.
      See `RAINFX_S211_BOUNDED_REPRODUCTION_TRIALS.md`.
      s212 compares immutable-copy event waits with wall and process CPU windows,
      retaining the exact completion predicate and full-byte refusal gates. Small
      copies improve, but8MiB wall benefit is inconsistent and measured CPU rises.
      The bounded polling candidate is not adopted; separate per-call attribution
      follows before any physical-owner wait change. Original cache cause remains
      open; production remains s87.
      See `RAINFX_S212_IMMUTABLE_WAIT_COST.md`.
      s213 partitions completion wait into GetData/between/yield/sleep and times
      submission/Map/row copy/comparison, with a paired uninstrumented control.
      Large candidate wait is97.76% inside GetData envelopes;32 retained longest
      calls are poll1004. This locates wall delay without proving driver/OS cause.
      Next compare count/cadence-limited polling; no physical-owner policy adoption.
      See `RAINFX_S213_COMPLETION_CALL_ATTRIBUTION.md`.
      s214 limits the initial query burst and spaces later polls: all measured
      paced fast phases stay at80 queries or fewer.8MiB plain mean improves
      14.43→5.58ms and the observed long call envelope disappears; small means
      and tail latencies regress. Next evaluate an opt-in bounded physical prefix
      against the unchanged owner sleep policy before any adoption.
      See `RAINFX_S214_COUNTED_PACED_COMPLETION.md`.
      s215 connects that candidate to a separate opt-in native nine-interval
      physical prefix. Output/stock/time/queued debt/cap and first-refusal gates
      match; physical-run wall mean4.21→1.89s, with startup-heavy process CPU
      unresolved. The owner default remains unchanged. Full256/protected-stop/
      control gates and physical-window CPU measurement are next.
      See `RAINFX_S215_PACED_PHYSICAL_PREFIX.md`.
      s216 passes full256, protected26/29-stop and all three fault controls with
      separate physical CPU windows. The full observation regresses wall146.68→
      211.67s and CPU15.42→19.23s, so pacing is rejected for default selection.
      A protected-stop wrapper row-count defect is corrected from saved data;
      no native run is repeated. Next evaluate a private event-wakeup mechanism
      under the original query-success guard. Existing owner/game stay unchanged.
      See `RAINFX_S216_FULL_PACED_GATES.md`.
      s217 validates a separate immutable-copy event-wakeup mechanism with
      7,020 full-byte copies and admission/payload refusal controls. The final
      revision retains unresolved notification handles until process exit.
      EnqueueSetEvent changes flush/submission behavior; wakeup never replaces
      successful GetData/device checks. All three sizes improve wall in both
      processes; the small CPU gate passes. Next evaluate a private owner prefix,
      then full/stop/control gates; no owner default or game adoption.
      See `RAINFX_S217_NATIVE_EVENT_WAKEUP.md`.
      s218 connects event wakeup only to separate nine-interval physical builds.
      Five healthy prefixes and the expected first-refusal control preserve
      exact output/stock/time/queued debt/cap. Mean physical wall7.481→4.917s,
      but CPU0.617→1.711s with strong variation; full-owner comparison is held.
      Next separate calling-thread/process CPU and bounded wait tails, checking
      instrumentation effects. Original owner/game remain unchanged.
      See `RAINFX_S218_EVENT_PHYSICAL_PREFIX.md`.
      s219 separates calling-thread and all-process CPU with fixed boundaries,
      and compares plain/traced sleep/event consumers with eight-record tails.
      Nine healthy prefixes and the expected stopped fault preserve parity.
      Large CPU residuals occur in the first four processes under all conditions,
      then fall in the mirrored half; no driver cause is established. Recorder
      CPU overhead is not isolated. Next use a CPU-only recorder control and a
      fixed pre-physical pause attribution experiment, counting all phase costs.
      See `RAINFX_S219_CALLER_CPU_ATTRIBUTION.md`.
      s220 measures the unchanged recorder without GPU work: added caller CPU
      is0.015–0.023ms per245 wait/submission pairs in the synthetic control.
      A fixed2s pre-physical pause shows no CPU shift/improvement; all costs
      reconcile to process totals. Initial stale-LUID admission is preserved;
      current-boot two-pose byte/fault revalidation authorizes fresh bindings.
      Nine healthy physical prefixes and the expected stopped fault pass.
      Next partition completion-envelope caller CPU; no default or game change.
      See `RAINFX_S220_RECORDER_SETTLE_CONTROLS.md`.
- **Rain rendering.** `shaders/rainVisorDynamicDrop.hlsl` draws the visor
  rain surface mesh (built from `GLASS_RAINFX`) with `render.mesh` in an
  in-scene stage. The stage is `main.smoke` by user setting
  (`RAIN_DYNAMIC_DROP_DRAW_AT_SMOKE_DEBUG`).
  - Water field: drops, trails, film.
  - Micro pattern, haze, smear.
  - Exact depth pass.
  - New Trail (`rain_trails.lua`): same-frame GPU swept liquid/clearance history;
    4:1 metrics, diameter/mm UI, independent channels. Legacy CPU paths remain
    behind the New Trail toggle.
- **Refraction source.** The geometry shot plus the HDR frame copy, through
  tone mode 3 (frame-first composite; rules in `RAINFX_NEAR_OBJECTS.md`
  §10).
- **Visor stack (scene stack, current work).**
  `shaders/rainVisorLayer.hlsl` draws the KN5 `*_FX` meshes in the same
  callback:
  1. housing (opaque, depth write);
  2. `GLASS_COAT_FX`;
  3. the rain mesh;
  4. `GLASS_EXT_FX` (band) and `GLASS_INT_FX`;
  5. the drop depth pass.

  Output is HDR. See `RAINFX_VISOR_LAYER.md` §17–§20, and §18 for the KN5
  rules.
- **Post overlay.** Archived and off (`RAIN_VISOR_OVERLAY = false`).

## 2. Document index

States:

- **ACTIVE**: current work, read first.
- **REFERENCE**: implemented, describes live code.
- **CLOSED**: investigation finished; result lives elsewhere.
- **ARCHIVED**: the feature still exists in code but is off and not
  developed.
- **REMOVED**: the code was deleted; history only.
- **HISTORY**: chronological log.

| Document | State | Content |
|---|---|---|
| `README.md` | ACTIVE | this index and the working rules |
| `RAINFX_S233_RETAINED_PRIVATE_INTERVAL.md` | ACTIVE | Actual CSP four-quarter recurrence passes:267 draws/81 cache hits, three reuses, four validated receipts and zero represented-time debt; fixed87 canvases; new engine intervals/source/optics next |
| `RAINFX_S234_NEW_INTERVAL_ADMISSION.md` | ACTIVE | Local two-generation stock/time continuation:518 draws/178 cache hits, same87 canvases; new pose/force cache generation and signed time remainder; fresh main-app capture/actual CSP connection next |
| `RAINFX_S235_MAIN_TWO_INPUT_INTERVALS.md` | ACTIVE | Main-app two fresh captures connected; host/order/88-line report/deployment checks pass; actual two-input CSP observation pending; complete elapsed-time/source/renderer integration next |
| `RAINFX_S236_SCALE_PROVENANCE_REPAIR.md` | ACTIVE | Actual two-input CSP passes8/8:518 draws/178 cache hits,seven reuses,87 canvases and zero debt; scale/settings/hash/water/time checks pass; s235 failure preserved; complete elapsed-time/source/renderer next |
| `RAINFX_S237_BOUNDED_TIME_STREAM.md` | ACTIVE | Local bounded FIFO/split-frame time ownership and unchanged GPU continuation pass; pause/duplicate/debt/overflow guards; not installed; coherent intake and sustainable execution budget next |
| `RAINFX_S238_PERSISTENT_CPU_INTAKE.md` | ACTIVE | Actual120/120 CPU inputs pass;20 bootstrap checks/no per-frame I/O; mean0.7604ms/p95 2.0361ms/max3.5412ms; production cost unqualified; reduce capture work and compare whole-interval execution next |
| `RAINFX_S239_CACHED_CPU_IDENTITIES.md` | ACTIVE | Actual600/600 pairs match;480 measured composition mean0.360916→0.260773ms/P95 0.8961→0.4709ms; max1.4803→2.5821ms tail warning; final performance/standalone capture unqualified; no solver/GPU change |
| `RAINFX_S240_WHOLE_INTERVAL_CANDIDATE.md` | ACTIVE | Local full-grid1/4/8-step comparison;whole interval87 submissions/one boundary versus267/four;volume/momentum differences0.0103%/0.0346%;adaptive retry/batched execution and actual cost pending;game unchanged |
| `RAINFX_S241_BOUNDED_RETRY.md` | ACTIVE | Bounded private retry/debt ownership and packed Mean rollback repair;full-field normal/stress validation and six controls;actual CSP batching/cost/continuous adoption pending;game unchanged |
| `RAINFX_S242_BUDGETED_STREAM.md` | ACTIVE | Paced adaptive owner/normalized FIFO;10 scheduler cases and native two-input/three-slice continuation pass;229 submissions/3 reads/87 fixed resources/debt0;actual throughput and live sampler/source/renderer pending |
| `RAINFX_S243_EXACT_HEADER_AUDIT.md` | ACTIVE | Direct208-word seed audit removes2 header digest passes;223 versus229 submissions,85 resources;all six field/ledger arrays match bits;five corruptions refuse;actual timing/throughput pending |
| `RAINFX_S244_CSP_DISPATCH_PROFILE.md` | HISTORY | Frozen-input CPU profile design and local checks;actual clock-guard failure preserved in s245;no GPU timer or live adoption |
| `RAINFX_S245_CLOCK_ADAPTER.md` | ACTIVE | Actual8/8,568 draws,85 resources;engine cdata clock repair confirmed;repeat graph build66.4969ms and status latency144.5055ms expose template/completion priorities;live throughput open |
| `RAINFX_S246_RETAINED_GRAPH_TEMPLATE.md` | ACTIVE | Actual8/8,568 draws,85 resources;repeat admission66.8287→0.5391ms;initial build remains73.9595ms once;completion latency156.6886ms remains open;no FPS/GPU timing claim |
| `RAINFX_S247_PAIRED_COMPLETION_LATENCY.md` | ACTIVE | Actual8/8,86 resources,16 reads;minimal/full both10 frames in all samples,repeat148.2389/150.6607ms;next GPU-dependent continuation;no throughput improvement claim |
| `RAINFX_S248_TWO_INTERVAL_GPU_BATCH.md` | ACTIVE | Actual1/1 batch,prefix2/2,155 draws/resources,one readback/disposal,debt0;10-frame146.8544ms final wait;162.1MiB;retained batches/recovery and throughput remain open |
| `RAINFX_S249_RETAINED_BATCH_RECOVERY.md` | ACTIVE | Actual4 inputs/2 batches,310 draws,155 fixed resources,2 readbacks,debt0;retained inventory passes;20-frame submission +10-frame readback motivates bounded pacing before live intake |
| `RAINFX_S250_BOUNDED_DISPATCH_PACING.md` | ACTIVE | Actual warm32 reduces submission20→5 frames;dispatch max0.8645ms,full pump max2.0326ms;8 inputs/4 batches/620 draws/debt0;10-frame readback and cold6.1715ms call remain;scoped candidate only |
| `RAINFX_S251_PREPARATION_REUSE.md` | ACTIVE | Single-copy packet/typed-uniform reuse;30 word-parity cases,signed-zero/busy/caller controls and command parity pass;installed original/reused comparison,actual CPU benefit pending |
| `RAINFX_S232_PRIVATE_PHYSICAL_INTERVAL.md` | ACTIVE | Default-OFF actual-grid conservative quarter interval; actual CSP1/1 and84/84 pass, exact input identities/water/debt checks;20µm controlled inventory; persistent water, incident/head source and optics next |
| `RAINFX_S231_PRIVATE_EXECUTION_BOUNDARY.md` | ACTIVE | Main-app default-OFF private executor; actual CSP16 jobs/48 draws/14 reuses, six canvases; bounded status/retention guards; physical interval, persistent water and renderer ownership next |
| `RAINFX_S200_BOUNDED_HISTORY.md` | ACTIVE | One acceptance counter,object-local diagnostic IDs,518/8 selector prototypes;64-interval and forced-stop physical/GPU parity(2.167GB),publication/debt/ownership guards;long-duration,total CPU/provider,target timing and CSP/live gates open |
| `RAINFX_S201_EXTENDED_RECURRENCE.md` | ACTIVE | 256 controlled intervals(4.320557s),seven recovered refusals,exact published water/time,first64 GPU/input parity;unchanged recurring metadata/63.492905MiB scoped peak;true long-duration,total CPU/provider,target timing and CSP/live gates open |
| `RAINFX_S202_DIAGNOSTIC_CAPTURE_POLICY.md` | ACTIVE | Full/control capture policies retain256-interval final bits/traces and forced-stop debt;optional archive reads1.976GB to0.443MB with mandatory9.044GB retained;both WARP wall runs near192s,no speedup claim;required validation,target timing and CSP/live gates remain |
| `RAINFX_S203_COMPACT_STOCK_VALIDATION.md` | ACTIVE | Complete FP64 tiled stock reduction with conservative boundary fallback;25 component cases,256-interval shadow/compact and protected stop pass;stock reads2.164GB to1.626MB,one extra validation draw/check,6192B typed scratch within cap;cache reads,target FP64/cost and CSP/live remain |
| `RAINFX_S211_BOUNDED_REPRODUCTION_TRIALS.md` | ACTIVE | Four fresh-process nine-interval prefixes preserve queued debt; controlled first refusal stops later trials; full/stop parity retained, original cause open |
| `RAINFX_S212_IMMUTABLE_WAIT_COST.md` | ACTIVE | Private copy/event wall and process CPU comparison; small copies improve,8MiB result varies; completion/refusal gates pass, candidate not adopted |
| `RAINFX_S213_COMPLETION_CALL_ATTRIBUTION.md` | ACTIVE | Exact wait partitions and bounded call witnesses; large candidate delay is inside GetData, retained longest calls at poll1004; count/cadence comparison next |
| `RAINFX_S214_COUNTED_PACED_COMPLETION.md` | ACTIVE | Query burst/cadence cap removes observed long call; large means improve, small means/tails regress; bounded opt-in physical prefix evaluation next |
| `RAINFX_S215_PACED_PHYSICAL_PREFIX.md` | ACTIVE | Opt-in native nine-interval output/stock/time/debt/cap parity and first-refusal control pass; wall improves; full/protected-stop gates next, default unchanged |
| `RAINFX_S216_FULL_PACED_GATES.md` | ACTIVE | Full/stop/three controls pass; physical CPU measured; full-run cost regresses, so default retains original wait; native event-wakeup probe next |
| `RAINFX_S217_NATIVE_EVENT_WAKEUP.md` | ACTIVE | Immutable event-wakeup byte/refusal and small wall/CPU gates pass; next private owner prefix, original wait/game unchanged |
| `RAINFX_S218_EVENT_PHYSICAL_PREFIX.md` | ACTIVE | Event physical prefix/refusal parity passes; wall improves but CPU regresses; investigate thread/wait cost before full-owner comparison |
| `RAINFX_S219_CALLER_CPU_ATTRIBUTION.md` | ACTIVE | Caller/process CPU and bounded tails pass; large residual varies with execution order across policies; isolate recorder/startup cost, full-owner gate held |
| `RAINFX_S220_RECORDER_SETTLE_CONTROLS.md` | ACTIVE | Recorder direct CPU cost is small; fixed pause offers no measured benefit; current-boot qualification and full phase accounting pass, completion CPU partition next |
| `RAINFX_S210_RETAINED_METRIC_WITNESSES.md` | ACTIVE | 21 bounded phase/reference/sharing witnesses, three first-divergence controls, complete hardware parent parity and protected stop; original failure not reproduced |
| `RAINFX_S209_CACHE_REFUSAL_CAPTURE.md` | ACTIVE | Corrected exact refusal capture passes CPU/GPU one-bit controls; four full parity runs and sanitizer report no natural recurrence; original cause remains open |
| `RAINFX_S208_HARDWARE_OPERATION_PROFILE.md` | ACTIVE | Explicit operation coverage and debug parity/stop pass; completion oversleep and adaptive-bound costs measured; initial release cache-reference refusal remains open |
| `RAINFX_S207_HARDWARE_PHYSICAL_ADMISSION.md` | ACTIVE | Qualified-reference full hardware admission; precise packet/no-debit candidates; 256-interval shadow/reuse state/stock/time parity and protected stop pass; complete profiling, accuracy and CSP/live gates remain |
| `RAINFX_S206_BACKEND_REFERENCE_QUALIFICATION.md` | ACTIVE | Two independently qualified hardware geometry references; immutable provenance and four exact native rebuilds; qualification/provenance/GPU corruption refusals pass; full physical consumer and timing remain open |
| `RAINFX_S205_HARDWARE_PREFLIGHT.md` | ACTIVE | RTX 3070 exact-byte controls and isolated transfer timing; strict WARP-reference metric portability fails before physical execution, independent full-field diagnostics pass; backend reference qualification precedes integrated timing |
| `RAINFX_S204_CACHE_SNAPSHOT_REUSE.md` | ACTIVE | Exact same-epoch full-snapshot reuse for143 shared preparations;cache reads6.821GB to5.621GB,identical physical/stock/debt bits and protected stop;no extra draws/uploads/default textures;target timing,CSP and live adoption remain |
| `RAINFX_S199_RESOURCE_WINDOWS.md` | ACTIVE | Bounded523-description/109-observed-shape cache and exact historical occupant last use;all16085 descriptions/full64-interval GPU bits retained,225553 lifetime checks/4 refusals;total CPU history,long-duration,target timing and CSP/live gates open |
| `RAINFX_S198_METADATA_TEMPLATES.md` | ACTIVE | First/recurrent phase/frame templates;17 active indexes,original previous/current-bank bindings;all64 physical/GPU/index bits retained,60 binding probes/4 refusals;resource-table streaming,long-duration,target cost and CSP/live gates open |
| `RAINFX_S197_PACKET_WINDOW.md` | ACTIVE | One-interval input/draw window and56 immutable schemas;full64-interval GPU bits match s196,six native parser controls pass;total CPU metadata,long-duration,target cost and CSP/live integration remain open |
| `RAINFX_ROADMAP.md` | ACTIVE | R1 (pre-laid GPU drops), R2 (visor scene stack and glass optics), closed list |
| `RAINFX_S185_BOUNDED_FREE_SLOT_RETIREMENT.md` | ACTIVE |Completed free-slot retirement;615 native draws/37 events exact under224KiB;bounded warm model63.998932MiB with1120B margin,churn/full-grid/timing gates remain open |
| `RAINFX_S184_EXACT_CELL_WORD_STORAGE.md` | ACTIVE |Lossless RG32_UINT area/coating bits and quarter coverage;83 actual-cache draws/13 events exact;proposed live62.992MiB fits,but reservation69.808MiB and whole ownership remain open |
| `RAINFX_S183_EXACT_INTEGER_RUN_STORAGE.md` | ACTIVE |Lossless RGBA16F bounded integer runs;698 native draws/50 events retain cache/physics/bank bits,no extra passes;warm64.992MiB live/71.808MiB reserved,whole64MiB open |
| `RAINFX_S182_PACKED_METRIC_CACHE_OWNER.md` | ACTIVE |Actual-grid packed metric producer/cache generations and exact physical readers;83 native draws/13 events;local peak54.096MiB,whole73.808MiB reservation and joint physical ownership open |
| `RAINFX_S181_COMPACT_WORLD_METRIC.md` | ACTIVE |Exact two-band FP32 world metric and checked logical decode;766 component draws retain metric/physical/bank bits;warm reservation73.808MiB,whole64MiB and actual-grid cache composition open |
| `RAINFX_S172_NATIVE_CORE_CACHE_RETIREMENT.md` | ACTIVE |Actual native cache build/fenced reader-safe retirement;118 draws,5 events;cache29.399→21.001MiB,physical force/cells exact;single generation,whole pipeline/game gates open |
| `RAINFX_S171_CHECKED_PACKED_END_SOURCE.md` | ACTIVE |Checked direct End reads over packed inventory;491 native draws,31 source graphs,23 cases exact;6 lifetime plans show End-only bank still smaller;optional component,not adopted |
| `RAINFX_S170_RESOLVED_SOURCE_CELLS.md` | ACTIVE |Raw coverage/scalar physical-area adapter and conserved source composition;527 native draws,36 graphs,actual full-grid cell bits/23 source fixtures preserved;rollback and joint lifetime gates;game adoption open |
| `RAINFX_S169_BINARY_BOUNDARY_ADAPTER.md` | ACTIVE |Native R8 binary boundary and independent-resolution/red-channel birth/head readers;317 WARP draws,28 graphs,full actual mask exact;12MiB descriptor saving;combined budget/game adoption open |
| `RAINFX_S168_JOINT_LIFETIME_AND_INPUT_DOMAINS.md` | ACTIVE |Two-frame joint descriptor lifetimes;physical-domain alias refusal;122.687MiB live/133.501MiB reserved with current inputs;total64MiB gate fails,alternative budgets unadopted;no GPU/game execution |
| `RAINFX_S167_COMPACT_SOURCE_CELLS.md` | ACTIVE |No7H source atlas/full status map;1,556 draws,88 native events,all public physical bits preserved;full-resolution source+reserved cache60.210MiB;complete head/transport lifetime budget open |
| `RAINFX_S166_NATIVE_SOURCE_HEAD_HANDOFF.md` | ACTIVE |Retained native birth/head/source→four quarters→inventory;1,236 draws,62 events,48 copies;on/off/on and replay/retry conservation;small-grid only,actual source+cache lower bound74.134MiB needs fusion |
| `RAINFX_S165_FRAME_STREAM_AND_CACHE.md` | ACTIVE |Four controlled zero-source frames;bounded queue/cache quarantine and retry;3,024 solver +2 cache draws,water/time closure and bit parity;native63.227219MiB,CSP/source-head/full budget open |
| `RAINFX_S164_NATIVE_TYPED_POOL.md` | ACTIVE |Persistent typed WARP pool/events/observer leases;1,258 draws,32 event completions,six pre-device refusals;bit-identical roots and native63.23MiB descriptor peak;CSP/new-frame/full app admission open |
| `RAINFX_S163_SCALAR_PHYSICAL_AREA.md` | ACTIVE |R32F film area preserves physical bits/invalid guards;3,280 typed WARP draws,34 graph pairs;cache saves3MiB and recurrent proposal63.23MiB fits scoped64MiB gate;actual pool/completion/app budget open |
| `RAINFX_S162_PACKED_OUTPUTS.md` | ACTIVE |Packed End/Mean and checked direct resume;47 passes,29 graph pairs plus refusal/retry;2,668 WARP;fresh proposal62.23MiB but recurrent66.23MiB, native reuse/completion still open |
| `RAINFX_S161_EARLY_DONOR_EXCHANGE.md` | ACTIVE |Early exchange shortens force lifetime;static peak56.83→48.83MiB, proposed pool+cache66.23MiB;26 paired/18 independent cases;physical bits and bounded ledgers;adds34.4KiB/4 passes, offline |
| `RAINFX_S160_DIRECT_TILED_STATUS.md` | ACTIVE |Direct16×16 status maxima remove8MiB/2 draws;46→44 passes and77.81MiB;50 tile/23 paired cases bit-exact;static peak unchanged,61.79MiB pool proposal needs ordering/completion and cache budget |
| `RAINFX_S159_COMPACT_SOURCE_APPLIED_POST.md` | ACTIVE |Guarded identity source and2-band recipient;50→46 passes,130.31→85.81MiB;23 paired cases/1,952 WARP/33 compilations;physical roots exact, bounded ledger rounding;offline, lifetime/budget open |
| `RAINFX_S158_SELECTED_BANK_CONTINUATION.md` | ACTIVE |Selected bank continuation removes23 targets;73→50 passes,199.97→130.31MiB;bit-parity/refusal/ledger/time-debt checks, immutable micro/head aliases;offline, budget still open |
| `RAINFX_S157_FIELD_INPUTS_AND_SIZED_CONTINUATION.md` | ACTIVE |Field-centre copies reduce retained cache56.59→32.40MiB;actual1024×256 full film continuation/ledger/time-debt verified offline;878 WARP/42 compilations;199.97MiB reference graph needs reduction |
| `RAINFX_S156_COMPACT_FORCE_READERS.md` | ACTIVE |Force buffer16→8MiB;2 bands and reconstructed exchange;1,289 WARP/40 strict compilations,21 full-grid force/8 small-frame/3 continuation cases;offline, live resource/time gates remain |
| `RAINFX_S155_ACTUAL_GRID_FORCE_CONSUMER.md` | ACTIVE |Captured-frame world cache→unchanged film force;106 WARP/9 bodies,17 GPU cases/6 CPU refusals;6-pass/16.01579MiB private graph;compact force outputs next, offline only |
| `RAINFX_S154_WORLD_FIELD_CACHE.md` | ACTIVE |Actual-grid world metric/area/connected runs;69 WARP/17 bodies,19 controller/5 hook checks;actual frame660 passes full-grid audit and16 CPU samples;34 passes/56.5874MiB, no water evolution |
| `RAINFX_S141_PHYSICAL_PACKET_PRODUCER.md` | ACTIVE |Physical End/Mean/source/head/force/recipient/ledger graph;958 WARP/24 bodies,20 physical/refusal and6 lifetime cases;16 imports/45 private passes at13x7;live P1/P2 and cumulative owner pending |
| `RAINFX_S142_RAW_PHYSICAL_CHANNEL_ADAPTER.md` | ACTIVE |Actual P1/P2/P3 channel adapter;physical head packets and separated external/pool/field/micro descriptors;330 WARP/4 bodies,39 cases/24 recurrent/6 lifetime;uninstalled, joint field handoff pending |
| `RAINFX_S143_PAIRED_MERGE_AND_EXIT_OWNERSHIP.md` | ACTIVE |Paired full-generation merge transfer and retained boundary-exit momentum;263 WARP/6 bodies,32 cases/3 original-state controls/6 lifetimes;exhaustion held, uninstalled source raster/joint owner pending |
| `RAINFX_S144_PHYSICAL_SOURCE_HANDOFF.md` | ACTIVE |Sparse physical source raster, pool debit, separate pinned micro and source-phase cumulative inventory;555 WARP/16 bodies,27 cases/6 cumulative/6 leases;4096 slots/1024x256 pass, time integration/live hooks pending |
| `RAINFX_S145_SOURCE_APPLIED_TRANSPORT.md` | ACTIVE |Source-applied s141 remaining-time continuation;joint ledger/debt without source replay;2571 WARP/40 bodies,39 cases/6 leases,both orders/recurrent source cycles/4096 heads;uninstalled,completion/accuracy/cost pending |
| `RAINFX_S146_RETAINED_IMPACT_PRODUCER.md` | ACTIVE |Original P2 bit-preserved incident capture and retained momentum;438 WARP/43 bodies,37 cases/7 snapshot guards,actual geometry/4096 slots;offline source→transport pass,frame owner/live hooks pending |
| `RAINFX_S147_FRAME_DEPENDENCY_OWNER.md` | ACTIVE |Offline frame identity/dependency owner and pinned parent/final-reader lifetime;29 owner/6 frame/6 root guards,161 WARP/46 bodies;actual callbacks,stock publication/live completion pending |
| `RAINFX_S148_SI_HEAD_PRODUCER.md` | ACTIVE |Offline SI head motion/P3 transfer producer and creator-generation sidecar;21 head cases including4096 slots, independent force oracle; actual callbacks, persistent stocks and completion pending |
| `RAINFX_S149_PERSISTENT_INVENTORY_HANDOFF.md` | ACTIVE |Independent eight-resource GPU inventory copy and next-identity immutable reads;41 owner/inventory scenarios,175 WARP/57 bodies; actual engine hooks, recurrent physics and live completion pending |
| `RAINFX_S150_RECURRENT_INVENTORY_INPUTS.md` | ACTIVE |Mandatory next-frame bank input routing;3 actual physical intervals,7 scenarios,525 WARP/57 bodies,24 copies; source on/off/on and stale force-header refusal; actual engine/CSP lifetime and broader accuracy pending |
| `RAINFX_S151_ENGINE_INPUT_HEADER_PROBE.md` | ACTIVE |Default-off engine observation/common GPU header probe;15 input/8 controller/8 decoder cases,6 WARP/2 bodies; actual CSP50 rows/200 values bit-identical, car-reference pose only and strict completion false |
| `RAINFX_S152_MAIN_PHYSICAL_CONTEXT.md` | ACTIVE |Default-off main-app CPU context: actual visor world pose/settings/units and20 verified input files;27 context/9 hook/6 decoder,20 WARP/5 bodies; actual frame745/52 rows/208 values and physical meanings pass, no GPU lease/completion or solver admission |
| `RAINFX_S153_OWNED_GPU_GEOMETRY.md` | ACTIVE |Owned immutable inputs and explicit R32 boundary;14 managed cases,33 WARP/8 bodies; actual frame939 matches8 full-input fingerprints,31 passes/31 retained canvases/52.934MiB; no general completion or solver admission |
| `RAINFX_S140_SOURCE_BACKEND_REFERENCE.md` | ACTIVE |Actual v2 complete;source reference mixed WARP/actual corrected separately;25 strict actual sources/64 headers,5 plans/3 refusals,60 pairs/20 end-only/3640 bounds pass;original mismatch retained,13 mutation guards |
| `RAINFX_S139V2_PAGED_CAPTURE_FIX.md` | ACTIVE |Actual v1 Too many textures preserved/reproduced;CSP32 limit,capture24 maximum;v2 actual captured,reference mismatch assessed in s140;original evidence retained |
| `RAINFX_S139_ACTUAL_INTERVAL_HEADER_PROBE.md` | ACTIVE |Default-off genuine-header/partial-time probe;5 eligible/3 refused cases,53312 floats/296 lines;local checks pass;actual40-texture extraction fault preserved and fixed by separate s139v2 |
| `RAINFX_S138_INTERVAL_SNAPSHOT_HEADERS.md` | ACTIVE |Dynamic interval/header admission, GPU-derived substep and13 read leases/27 private passes;282 WARP draws,29 snapshot/29 header guards,19 lease cases;legacy P3 layout refused;uninstalled |
| `RAINFX_S137_ACTUAL_IMPORTED_INPUT_PROBE.md` | ACTIVE |Actual producer/import/prefix path passes42240 floats/56 strict controls/48 pairs/16 end-only checks;14 retrying calls/132 accepted once;no completion fence or live adoption |
| `RAINFX_S136_OWNED_GPU_SOURCE_PROVIDER.md` | ACTIVE |Six imported read leases/26 private passes;104 WARP draws/11 compiles/56 field checks;37 lease cases/4 identity mutations;no actual CSP lease/completion claim |
| `RAINFX_S135_RETAINED_CANDIDATE_INTERVAL.md` | ACTIVE |Selected candidate/queue/bridge composition;64 WARP draws/12 compiles match frozen outputs;17 lifecycle cases/12 binding guards;fixed replay and mocked completion only |
| `RAINFX_S134_CURVED_ROUNDOFF_BOUNDS.md` | ACTIVE |Conditional source-graph enclosures contain8736 reused CSP endpoints; near-zero cancellation/absolute UV-atlas error distinguished;8 offline identity receipts; no live adoption |
| `RAINFX_S133_QUOTIENT_ABLATION.md` | ACTIVE |Actual8-mask ablation:166784 floats/192 pairs; mass+face preserves scoped gates and saves16 synthetic slots; near-zero error retained; uninstalled candidate export |
| `RAINFX_S132_COMPENSATED_MAP_CONSUMERS.md` | ACTIVE |Compensated map divisions;318 WARP graph draws/17 compiles,49152 rational quotient checks;44 added synthetic slots/no added load sites; actual98304 floats/72 pairs, signed-affine strict gate passes; curved roundoff/live adoption remain open |
| `RAINFX_S131_CURVED_SEQUENTIAL_TRACE.md` | ACTIVE |Real-bake XY/YX/cuts and arithmetic trace;198 WARP draws/17 compiles;18 lifecycle/15 decoder/15 install controls; 98304 actual floats/72 matching consumer pairs; quotient1 ULP, diagnostic refinement0; strict affine gate open |
| `RAINFX_S130_AXIS_CSP_CONSUMERS.md` | ACTIVE |Actual96 consumer pairs bit-identical across original/precise candidate; false Y refusal fixed, strict analytic map equality still open;78336 actual floats,124 WARP draws/12 compiles per variant |
| `RAINFX_S129_SOLVER_BANK_ABI.md` | ACTIVE |Actual s109/s110 generic helpers and End/Mean packet ABI pass:7680 exact floats,576 guard zeros;14 host guards/lifecycle cases,15 decoder cases,9 synthetic compiles; full consumers remain open |
| `RAINFX_S128_BANK_READER_PROBE.md` | ACTIVE |Actual3 grids x6 bank readers:6912 exact floats,504 guard zeros; integer Load works on this path;14 mocked controls,15 decoder cases,9 synthetic compiles; solver ABI not yet connected |
| `RAINFX_S127_ACTUAL_CSP_TRACE.md` | ACTIVE |Actual preview649 observations: matrix/forward copy/control pass; reverse Load fails, reversed sampling matches128 values;1792 recorded floats,14 install cases,31 parser fixtures; narrow recipe candidate only |
| `RAINFX_S126_STANDALONE_CSP_PROBE.md` | ACTIVE |Default-off isolated app ZIP; asymmetric matrix/copy pattern and four R32FLOAT readbacks;27 mock cases/658 actions,4 synthetic shader compiles,23 SDK blocks; subsequent actual result in s127 |
| `RAINFX_S125_MANAGED_PASS_BRIDGE.md` | ACTIVE |Fixed-schema managed canvas bridge, pending-prefix resume and owned values;16 mock LuaJIT scenarios/6271 actions,21 guards,11 SDK blocks; uninstalled gated CSP adapter, actual completion/layout unverified |
| `RAINFX_S124_CSP_BOUNDARY_AND_QUEUE.md` | ACTIVE |15 local SDK evidence blocks,41 shader binding checks, bounded owned Lua input queue;16 scenarios/15640 actions, distinct source/time receipts and explicit reset ledger; no game integration |
| `RAINFX_S123_CONSTANT_PACKET_REUSE.md` | ACTIVE | completion-safe constant packets/storage, capacity recovery and independent DXBC/pool replay;2288 commands/260 flights, creations5470→2088 with equal GPU bytes; offline only |
| `RAINFX_S122_PROGRESS_SUMMARY.md` | ACTIVE | consolidated remaining roadmap, game/physics/resource/protocol metrics and report index; distinguishes current s87/s89 runtime from offline s91+ research |
| `RAINFX_S122_SHADER_BINDING_LAYOUT.md` | ACTIVE | immutable shader layout reuse and preflight, reflection walks9578→615 with equal GPU bytes;2104 commands/224 flights,17 candidate and10 packing guards; offline only |
| `RAINFX_S121_IMMUTABLE_GRAPH_TEMPLATES.md` | ACTIVE | bounded immutable topology, owned interval bindings and registration clear during pending/flight;2104 commands/224 flights,16 guards, GPU roots equal s120; offline only |
| `RAINFX_S120_MEMORY_INPUT_PROVIDER.md` | ACTIVE | typed memory entry, owned packet/input snapshots and scoped provider returns;1972 commands/196 flights across four paths, producer invalidation and14 guards; GPU roots equal s119, offline only |
| `RAINFX_S119_DESCRIPTOR_ORACLE_SPLIT.md` | ACTIVE | descriptor-only execution/roots, separate input leases and oracle harness;986 paired commands plus native absent-oracle run, actual GPU dumps equal s118; runtime unchanged |
| `RAINFX_S118_EXECUTION_AND_AUDIT.md` | ACTIVE | optional per-output staging/maps, paired full/lean native execution and portable pending/complete/failed contract;986 commands,98 flights, delayed/failing completion quarantine, boundary roots equal s117; offline only |
| `RAINFX_S117_INFLIGHT_COMPLETION.md` | ACTIVE | single-flight submit/poll/finalize;356 commands,34 flights, cancellation/reset around completion and bootstrap recovery; no early reuse/publication, final GPU roots equal s116; offline only |
| `RAINFX_S116_RECOVERABLE_ADMISSION.md` | ACTIVE | one immutable pending call; transactional capacity planning, restore/retry, busy/stale/duplicate rejection and cancel/reset; recovered GPU roots match uninterrupted execution; offline only |
| `RAINFX_S115_BOUNDED_STREAM_CAPACITY.md` | ACTIVE | native one-graph stream and bounded target/input/shader caches;262 calls, steady plateau and diagnostic eviction stress, four admission guards; recovery/live integration remain open |
| `RAINFX_S114_LOGICAL_BAND_ROOTS.md` | ACTIVE | logical-band GPU roots;192 frozen role comparisons, eight live fallback calls and seven protocol guards; later copies26→23/44→38; allocation/capacity tradeoff retained, runtime unchanged |
| `RAINFX_S113_GPU_SESSION_OWNERSHIP.md` | ACTIVE | native public/private/cache GPU roots across12 calls; five aborts and seven protocol guards;999 draws/358 copies preserve outputs, no checkpoint upload; whole-parent retention adds three copies on later calls, runtime unchanged |
| `RAINFX_S112_PERSISTENT_GPU_GRAPH.md` | ACTIVE | bounded native persistent GPU graph/pool;926 draws and336 region copies match upload oracles; both policies/orders, six failure prefixes and six native guards pass; cross-call GPU ownership/CSP/timing remain open |
| `RAINFX_S111_HYBRID_AXIS_INPUTS.md` | ACTIVE | offline first-axis parent/second-axis copy policy; both-order GPU oracles, fallbacks and ownership pass;23 copies,92MiB copy output,141.89MiB logical pool; target timing/allocator remain open |
| `RAINFX_S110_PROVEN_BANK_LOAD_DOMAINS.md` | ACTIVE | offline frozen call-site/domain proofs;36 axis,20 poisoned-bank/malformed-run cases and334 GPU copy-oracle comparisons; less redundant checking, unchanged resource costs, checked/copy fallbacks; runtime unchanged |
| `RAINFX_S109_BANK_AWARE_AXIS_INPUTS.md` | ACTIVE | offline checked bank input ABI; coordinate/host guards,36 axis and real GPU copy-oracle comparisons pass; fewer copies but more arithmetic and larger pool reservation; performance adoption withheld, runtime unchanged |
| `RAINFX_S108_TARGET_LIFETIME_AND_REUSE.md` | ACTIVE | offline explicit bank-copy DAG and exact-size reuse plan; six captured call cases, consumer/failure-prefix replay and alias guards; symbolic target budgets, no new GPU allocator or runtime change |
| `RAINFX_S107_LAST_AXIS_MEAN_ELISION.md` | ACTIVE | offline last-axis end-only gathers for compact coarse/first fine;36 axis and both-order/fallback/transaction checks preserve all mean losses and final publication; two fewer output banks, runtime unchanged |
| `RAINFX_S106_FIRST_FINE_MEAN_ELISION.md` | ACTIVE | offline first-fine final-mean omission;22 component cases, complete fine ledgers, error/retry/publication and final mean match s105; post target smaller by one bank, full fallback; runtime unchanged |
| `RAINFX_S105_COMPACT_COARSE_CANDIDATE.md` | ACTIVE | offline unpublished coarse specialization;22 component cases and transaction gates preserve error/admission and complete fine ledgers; smaller force/post/block targets, full diagnostic fallback; runtime unchanged |
| `RAINFX_S104_SHARED_RECIPIENT_METRIC.md` | ACTIVE | offline local metric sharing;20 physical cases, accepted embedded outputs/accuracy refusal, ownership/source/fence checks pass; static recipient/post work reduced, cache and draw counts unchanged; runtime unchanged |
| `RAINFX_S103_CACHED_PHYSICAL_METRIC.md` | ACTIVE | offline cached force/post bases, independent validity/format2;15 physical and26 projection comparisons plus joint-publication/ownership gates pass; less static work without more passes/storage; runtime unchanged |
| `RAINFX_S102_INTERVAL_METRIC_CACHE.md` | ACTIVE | offline interval-owned world-basis/Gram cache;26-axis and physical transaction equivalence, pose/receipt/fence guards, setup/storage versus repeated-work comparison; force/post reuse and game timing pending |
| `RAINFX_S101_METRIC_MAP_FUSION.md` | ACTIVE | offline in-map metric projection;26 axis and full transaction equivalence checks,73 to67 embedded draws; dense-film projection work rises, metric reuse and game timing pending; runtime unchanged |
| `RAINFX_S100_FUSED_COUPLING_AND_PROXY.md` | ACTIVE | offline recipient/post fusion, s99 bit-equivalent curved/ledger/retry checks; embedded76 to73 draws; cheap depth/drag proxy counterexamples prevent replacement; runtime unchanged |
| `RAINFX_S99_TEMPORAL_COUPLING.md` | ACTIVE | offline volume-weighted wet faces, recipient half-force/full travel mean and positive accuracy control; physical/analytic/ownership gates pass; costly reference requires predictor/fusion before game adoption |
| `RAINFX_S98_MULTICELL_RECONSTRUCTION.md` | ACTIVE | offline positive reconstruction/multi-cell remap; front/refusal/retry/curved budgets pass,10.44% high-shear coarse/finer volume difference blocks temporal accuracy/adoption; runtime unchanged |
| `RAINFX_S97_RESOLVED_AREA_TRANSPORT.md` | ACTIVE | offline resolved-area positive flux and curved SI/reference; smooth refinement and interval guards pass, diffusion/high-speed substep cost block adoption; runtime unchanged |
| `RAINFX_S96_RECURRENT_CURVED_PHYSICS.md` | ACTIVE | offline recurrent SI/current-height/evaporation with impulse budgets and snapshot guards; actual curved/retry/analytic tests pass, coherent-point physical-area counterexample blocks adoption; runtime unchanged |
| `RAINFX_S95_INTERVAL_TRANSACTION.md` | ACTIVE | offline immutable source/P4b interval, private checkpoints, exact retained time and joint stock/head/budget/clock publication; specified retry/guard/arithmetic checks pass; live lifecycle/queue/force/fusion pending, runtime unchanged |
| `RAINFX_S94_TWO_AXIS_COHERENT_HISTORY.md` | ACTIVE | offline two-coordinate coherent history, complete-image source validation and shared two-axis stock/loss rejection; planar/symmetry/mutation/actual-mesh checks pass; generation/clock/force/time/cost gates pending, runtime unchanged |
| `RAINFX_S93_COMPRESSIBLE_TRANSPORT.md` | ACTIVE | offline pressureless cell projection and complete-image coherent history; actual-mesh budgets/1D collapse pass, rejected moment-history and resolved-only counterexamples recorded; cross-axis/source/force/cost gates pending, runtime unchanged |
| `RAINFX_S92_CONTACT_AND_SUBCELL_SUPPORT.md` | ACTIVE | offline finite-width contact and subcell support history, shared GPU publication/loss gate; isolated/equal-time gates pass, dense-film closure and general support fail adoption; runtime unchanged |
| `RAINFX_S91_DRY_FRONT_AND_PAIRED_TRANSPORT.md` | ACTIVE | offline dry numerical velocity extension and separate end/mean momentum; isolated/equal-time/sparse mesh gates pass, high-C interacting fronts fail adoption; pass/storage costs and next interaction scope, no runtime changes |
| `RAINFX_S90_CHARACTERISTICS_AND_CURVED_TRANSPORT.md` | ACTIVE | offline SI predictor→characteristics→component-clipped positive remap; limited linear reconstruction, GPU axis admission, real-mesh volume/momentum+wall and prescribed-time gates; dry-front closure and app transaction pending, runtime unchanged |
| `RAINFX_S89_VIDEO_AND_POSITIVE_REMAP.md` | ACTIVE | film video direction reaction is expected in current preview; view6 blocks debug scene transmission, normal output unchanged; positive source-local overlap GPU arithmetic passes, trajectory/curved support/worst cost/runtime integration pending |
| `RAINFX_S88_FILM_TRANSPORT_CANDIDATES.md` | ACTIVE | offline finite-inertia/momentum and tiled-prefix long-travel GPU candidates: useful numerical gates pass, warm CFL / arbitrary-flow positivity / thin-stock translation fail adoption; no runtime changes |
| `RAINFX_S87_P4B_GAME_REVIEW.md` | ACTIVE | supplied P4b water conservation/internal return and67/67FPS observations pass; no >1mm columns, remaining time/visual gates; actual same-head GPU link proof, same-UV head/film/micro view5, user fabric material preserved |
| `RAINFX_S86_P4B_POOL_RETURN.md` | REFERENCE | opt-in P4b localized pool→P1 return, preserved rain centre, internal ledger, paired donor/field debit and atomic publication; +1 pass/+80KiB at4096, view4; production GPU/Lua/optics/regression gates passed; actual game review follows in s87 |
| `RAINFX_S85_P4_REGIME_AND_POOL_TRANSFER.md` | REFERENCE | same-frame data confirms 45–49% film inventory is CFL-limited; full-coverage/coated peak cells and valid SI units; offline /WX WARP conserved localized-pool-to-head prototype, handoff design/cost; runtime integration follows in s86 |
| `RAINFX_S84_P4_GAME_REVIEW.md` | REFERENCE | supplied P4 water budgets pass and FPS observed comparable; high-C transport-time gate fails; real-mesh unit probes, media review, same-frame16-float thickness/limited-mass/metric diagnostics; physical transport unchanged |
| `RAINFX_S83_P4_FILM_TRANSPORT.md` | REFERENCE | opt-in P4a four-neighbour conserved film transport/runoff, P1 world forces/downward air, manual limiter stats, compensated snapshot sum; +4MiB/one pass; game findings and expanded diagnostics follow in s84 |
| `RAINFX_S82_P3_GAME_REVIEW.md` | REFERENCE | supplied P3 conservation passes (interval error ≤2.043e-5); 3-minute/40-toggle game memory shows no sustained accumulation, 100 reset fixtures; long float32 precision/trail quality remain open, first P4 transport follows in s83 |
| `RAINFX_S81_P3_SPATIAL_WATER_PREVIEW.md` | REFERENCE | first P3 conserved spatial film/micro/trail, paired head loss, wet impact/evaporation/runoff, um optics and manual field budget; initial game findings and limits follow in s82 |
| `RAINFX_S80_P2_GAME_REVIEW_AND_MERGE.md` | REFERENCE | P2 FPS/budget/videos and SI merge correction; corrected 60% stationary/straight game conservation passed (interval error ≤6.10e-6), measured source rates; P3 spatial film/micro/trail next |
| `RAINFX_S79_GPU_PHYSICAL_BIRTH.md` | REFERENCE | opt-in P2 real-area/normal source, virtual impact/shared generation commit, GPU reservoir budget and display compensation; game results and merge correction follow in s80 |
| `RAINFX_S78_BIRTH_DISTRIBUTION_AND_BUDGET.md` | REFERENCE | P1 game result/response-time diagnosis and P2 DSD/flux/impact diagnostic preparation; live GPU birth/event/budget preview follows in s79 |
| `RAINFX_S77_SI_MOTION_PREVIEW.md` | REFERENCE | opt-in P1 persistent SI motion/volume/display separation, single-exit state/meta fix and epoch retirement; WARP/LuaJIT plus game qualitative validation passed, weaving/friction and driving cost still open |
| `RAINFX_S76_SI_CORE_PRIMITIVES.md` | REFERENCE | P1 shared SI GPU functions and /WX WARP invariants; persistent state binding implemented as opt-in s77 preview |
| `RAINFX_S75_WEATHER_INPUTS_AND_UNITS.md` | ACTIVE | P0 independent weather/G/metric panel and SI/contact helpers; installed-source/LuaJIT checks passed, user stationary/acceleration/braking logs confirm G excludes gravity |
| `RAINFX_S74_CORE_IMPLEMENTATION_SCOPE.md` | ACTIVE | implementation branch derived from preserved 0c092e0; core physics/flow/sheet/impact first, Smear deferred and legacy local impact film excluded; documentation only |
| `RAINFX_S73_PHYSICS_WEATHER_REFACTOR_DESIGN.md` | ACTIVE | design only: audited 6 px/mm calibration, volume/SI physics, independent display gain, CSP weather adapter, virtual impact and shared effect state; s74 core-first exclusions incorporated |
| `RAINFX_S72_TRAIL_SAMPLING_AND_DIAMETER.md` | ACTIVE | carried phase, pixel integration/bandlimit, trail derivative floor; model diameter ×3 with compensated thin output, wide sheets, preserved head/micro profile; cost and GPU checks, game verification pending |
| `RAINFX_S71_SMEAR_RED_REGION.md` | ACTIVE | low-G red region restored: class wipe follows G, neutral trails follow visibility, shared class boundaries and persisted Smear tuning; game confirmation pending |
| `RAINFX_S70_TRAIL_VISIBILITY.md` | REFERENCE | diagnosis of weak ordinary-film optics; sampling/model calibration implemented and evaluated in s72 |
| `RAINFX_S69_MOTION_AND_MEMORY.md` | REFERENCE | user confirms G-force conflict and memory leak fixed; scene-ready native mask, accumulating splash/queue fixes and merge allocation reduction |
| `RAINFX_S68_VIEW_AND_CONVEX_TINT.md` | ACTIVE | main-view FX completion/retries, native glass UI callback fix, independent E2/E3 convex tint; automatic-driving game confirmation pending |
| `RAINFX_S67_NEW_TRAIL.md` | ACTIVE | current GPU liquid/wipe history, pending-callback fix, diameter/mm controls, 4096-slot work reduction and offline checks; game verification pending |
| `RAINFX_S66_STARTUP_AND_GLASS_DIAGNOSIS.md` | REFERENCE | missing installed module, measured cold compile stall, async startup, independent glass/test routing and shadow/capture isolation; user FPS/light results in s67 |
| `RAINFX_S62_OUTPUT_AND_COST_FIXES.md` | REFERENCE | user game-output follow-up: warning-free shaders, EXT/E2/E3/micro fixes, cost reductions and verification limits |
| `RAINFX_S63_GLITCH_AND_NATIVE_OCCLUSION.md` | REFERENCE | bounded wipe/trail/splash geometry, physical splash positions, native exterior ownership and additional cost fixes |
| `RAINFX_S64_BOTTLENECK_AIRFLOW_LIGHTING.md` | REFERENCE | reproduced merge CPU bottleneck, cheaper physical transport, corrected downward airflow/live native hook, sunlight shadow policy and engine CPU/GPU timings |
| `RAINFX_S65_LAYER_TRAIL_COST.md` | REFERENCE | incomplete-install correction, live INT/source gate, Rain occlusion, cached smooth smear, physical trail frames, GPU swept wipe and bounded rendering costs |
| `RAINFX_KN5_4_TO_1_MIGRATION.md` | REFERENCE | s61: independent glass UVs, physical Rain geometry, E1/mirror visibility, rebuild and validation |
| `VISOR_CACHED_OPTICS.md` | REFERENCE | cached optics, post-rain source, E1 capture and dated verification |
| `RAINFX_GPU_PRELAID.md` | REFERENCE | R1 GPU pre-laid drops: CPU A/B, tile-binning heads, R1.2 birth-site atlas prototype |
| `RAINFX_IMPACT_FILM.md` | REFERENCE | local impact film, trigger, layer composition and validation |
| `RAINFX_UI.md` | REFERENCE | grouped popup controls, conditional settings, and validation |
| `RELEASE_0.6.0.md` | REFERENCE | accepted RainFX release, performance cleanup and deferred movement work |
| `RAINFX_VISOR_LAYER.md` | ACTIVE | visor stack: V1/V2 overlay phase (archived §1–16), scene stack §17, KN5 rules §18, material editors §19, open items §20 |
| `RAINFX_WATER_FIELD.md` | REFERENCE | the drop renderer: soft-kernel heads, metaball silhouettes, trails, refraction rule; backlog #3 closed |
| `RAINFX_MICRO_PATTERN.md` | REFERENCE | micro drop pattern v2, pop-in, point reads |
| `RAINFX_SMEAR_MASK.md` | REFERENCE | smear (fingerprint) mask v1–v9, texture contract |
| `RAINFX_HAZE.md` | REFERENCE | haze / condensation film |
| `RAINFX_IMPACT_SPLASH.md` | REFERENCE | impact splash v2, birth hold, exact depth pass (§7–§9), car glass vs drops |
| `RAINFX_COALESCENCE.md` | REFERENCE | merge and absorption steering |
| `RAINFX_TRAIL_FLOW.md` | REFERENCE | trail flow, anti-chrome tone, wipe-mask fp16 fix, thin-film lifetime (s34), open "Next" items |
| `RAINFX_TRAIL_REFRACTION.md` | CLOSED | trail and film refraction T1–T6, smear v9 (implemented) |
| `RAINFX_SHOT_TONE.md` | REFERENCE | refraction-source tone; v1/v2 superseded by mode 3 |
| `RAINFX_REFRACTION_SOURCE.md` | CLOSED | how CSP gets clouds; led to mode 3 |
| `RAINFX_STAGE_PROBE.md` | CLOSED | what each render stage contains; mode 3 v3; diagnostic probe |
| `RAINFX_NEAR_OBJECTS.md` | CLOSED | wiper/wheel/KN5 near objects; composite rules summary §10; haze-depth option; F1-camera game issue |
| `RAINFX_VISOR_GLASS.md` | CLOSED | KN5 shimmer, render-pass analysis, DLSS drag (accepted); glass design absorbed by VISOR_LAYER |
| `RAINFX_POST_OVERLAY.md` | ARCHIVED | P0/P1 overlay, HUD lift, resolution |
| `RAINFX_REVIEW_2026-10-02.md` | CLOSED | feature reviews: §1 → R1, §2 done, §3 moved |
| `RAINFX_MICRO_PATTERN_NEXT.md` | CLOSED | requirements, implemented as micro pattern v2 |
| `RAINFX_FLOW_LAYER.md` | REMOVED | flow layer (deleted 2026-10-02) |
| `RAINFX_SPRAY.md` | REMOVED | spray film (deleted 2026-10-02) |
| `RAINFX_PERSISTENT_GPU.md` | HISTORY | long development log of the GPU state machine |
| `RAINFX_PERSISTENT_GPU_TEXEL_IDENTITY_TEST.md` | HISTORY | texel identity / lifecycle writeback tests |
| `RainFXPersistentGPU.md` | HISTORY | original project-goal overview of the GPU simulation |
| `tools/` | REFERENCE | template and prototype scripts (smear v7 template, trail refraction proto) |
| `images/` | REFERENCE | templates and captures (smear mask templates, …) |

## 3. Working rules

### Files and versions

1. **Work on local files.** Preserve user tuning. The user normally commits; commit and integrate only when they explicitly request it (0.6.0 main integration authorised 2026-10-07).
2. **Before every patch:**
   - re-stage `realvisor.lua`, the shaders and the docs, and diff them
     against the last delivered version;
   - **keep the user's tuned values** (they edit the files between
     sessions);
   - patch with exact-match replacements (each anchor must match once).
3. **Deliver** the changed files and write them back to the project folder,
   guarded by the staged modification time. Each delivery is a session step
   `sNN`, named in the docs.

### APIs

4. **Verify every new API** against `lib.lua` / `README.md` of preview634
   before use. `shader-tpl` is closed source. Facts verified so far:
   - `render.mesh` PS_IN fields: `PosH`, `PosC` (camera-relative position),
     `NormalW`, `Tex`, `ApplyFog`. There is **no tangent**.
   - Uniforms are auto-declared from `values`. Every `params` table that
     uses a shader must carry the **same keys**, and every uniform the
     shader reads must be in all of them; otherwise it does not compile.
   - Effect-syntax `SamplerState` blocks are ignored, so samplers behave as
     linear/clamp. Wrap UVs by hand (`frac` + `SampleGrad`) and use `Load()`
     for point reads.
   - In HLSL, statics and functions must be declared **before** their first
     use (s39 bug).
   - `sim.lightDirection` points **from the light into the scene**; use
     `−lightDirection` for "toward the light".
   - `ui.onExclusiveHUD` holds one callback. `render.on` stages:
     `main.track/root.opaque/transparent`, `main.smoke`, `mirror.*`,
     `shadow.root`.

### Docs

5. **Record every important finding** in the topic document:
   - user results go in "User result" sections;
   - causes, decisions, config keys and UI labels, and limits;
   - add a dated section instead of rewriting history.
6. **Keep states current.** When a status changes:
   - update the document's `Status` line (ACTIVE / REFERENCE / CLOSED /
     ARCHIVED / REMOVED / HISTORY);
   - update this index and `RAINFX_ROADMAP.md`.
7. **New topic.** Create `docs/RAINFX_<TOPIC>.md` with a title, a date and a
   Status line. Add it to this index.

### Testing

8. **Isolate the cause first.** Before attributing an artefact to RainFX,
   compare with the app removed or RainFX off at the same track spot
   (`RAINFX_NEAR_OBJECTS.md` §9).
9. **Toggles.** New features come with a toggle and a debug view.
   Diagnostics default to off. Name the reload requirement when a change
   needs one (draw stage, KN5 path).

### KN5

10. **Naming rules** are in `RAINFX_VISOR_LAYER.md` §18:
    - `GLASS_COAT_FX`, `GLASS_EXT_FX`, `GLASS_INT_FX`: custom glass passes;
    - `GLASS_RAINFX`: water target and optional water-only mirror pass;
    - these four originals are dummy alpha-zero sheets, hidden from native colour/shadows;
    - all other native meshes, including `*_MRR`, follow their Visible box in every view.

    Each glass mesh has independent 4:1 UVs. The s61 contract and required rebuild
    order are in `RAINFX_KN5_4_TO_1_MIGRATION.md`; they supersede earlier naming rules.

### Priority

11. **Current priorities** (2026-10-07): RainFX 0.6.0 integrated; E2/E3/E4 accepted at user commit ff085b5. Next is E1. Final RainFX movement refinement remains deferred.

12. **Inner optical layer contract (E1–E7).** All lens effects are camera-side
    of the rain surface. Refraction, blur, brightness and reflected/ghost
    images must include already-rendered drops, trails and water film. Use
    a stable post-rain HDR capture, never the pre-rain scene snapshot or the
    live target being written. Preserve the accepted E2/E3/E4 tuning. Read
    `VISOR_E1_DESIGN.md` before implementing E1.
