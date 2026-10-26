# s256 — bounded two-arena GPU continuation (2026-10-23)

## Purpose

s255's eight-input window improves per-input caller elapsed cost but still
waits10 engine frames for each CPU receipt. Its one warm window advances only
0.636s of physical time per elapsed second. A positive20Hz count-capacity
estimate does not establish a responsive continuous model. s256 implements
bounded GPU progress during a pending CPU confirmation,using shorter four-input
windows rather than enlarging the eight-input window.

The first four-input window runs in arena1 and requests its ordinary asynchronous
16-word CPU readback. After its final GPU pass is accepted,the next callback may
submit a second four-input window in arena2,before the first CPU callback arrives.
Arena2 consumes arena1's owned film/history/checkpoint and GPU receipt. GPU
predicate checks decide whether it may advance. Two CPU receipts are still
requested. This is not a general GPU fence or permission to reuse a pending
resource. The actual CSP overlap and cost remain unmeasured until the game gate.

## Ownership and rollback

- All textures belong to this private executor. The wrapper selects only its
  two known arenas and pinned roots/status;no renderer/user GPU handle is admitted.
- Each arena has independent canvas objects,parameter tables,typed values and
  receipt storage. Fixed-slot submission prevents a synchronous/early callback
  from selecting arena1 again for the second window.
- Neither arena is reused until both CPU receipts have validated. After that,
  the next cohort seeds arena1 from the prior arena2. Arena2 is not rewritten
  until arena1's full ordered graph,including seed reads,has been accepted.
- The trusted ordered backend is the same private CSP path used previously.
  GPU dependency on the first status does not turn CPU readback into a general
  completion fence. Status requests keep their source texture unmodified until
  completion;the entire arena remains protected for the pair.
- Validation uses each executor job's immutable payload. A second bind cannot
  replace the first receipt's dt/count/ticket validation context. Callback order
  and duplicate delivery cannot change commit order.
- CPU queue progress is committed in input order after both receipts validate.
  An unknown submission,invalid receipt,timeout or cancellation retains managed
  storage and prevents future reuse/publication. No public stock/clock is changed.

The GPU predecessor predicate verifies16 finite words,expected receipt identity,
valid marker/error,area/initial stock,nonnegative water terms,accepted prefix and
mask. A complete prefix must have full mask,zero debt and the expected advanced
time within the existing FP32 summation bound. Only then does arena2 rearm its
first checkpoint and enable its physical decision. Refused/partial arena1 makes
arena2 preserve all retained roots;its receipt uses explicit blocked marker256002,
zero advance/accepted mask/prefix and all arena2 input time as debt. Invalid
predecessor data produces an error receipt as well as blocking motion.

A valid blocked second receipt does not count as an attempted refusal of its
first future input. CPU resolution applies arena1's existing dyadic retry queue,
discards that blocked speculative action and rebuilds the next cohort from the
earliest unfinished input. No generation is skipped or invented water applied.

## Cost and scope

| Sixteen normal frozen inputs | s255 | s256 |
| --- | ---: | ---: |
| Inputs per GPU window | 8 | 4 |
| CPU receipts | 2 | 4 |
| Two-window cohorts | — | 2 |
| Accepted draws | 1152 | 1184 |
| Owned textures | 65 | 130 |
| Descriptor bytes | 74434592 | 148869184 |
| Descriptor MiB | 70.986 | 141.973 |

The two workspaces fit the explicitly retained192MiB diagnostic cap. Static
geometry/cache are duplicated between arenas in this candidate;sharing immutable
static textures can be evaluated after the ordered cross-arena path is qualified.
No allocation occurs per cohort. Used canvases remain until app/session ends;
CPU receipt data are disposed once by the existing adapter. Descriptor bytes do
not include driver/staging/constant-buffer/Lua heap costs.

Preparation and dispatch share a soft3ms owner-pump budget with at most256 SDK
draw calls per callback. Indivisible setup/SDK calls may exceed it and are logged.
The first allocation/start is separately recorded. No busy wait,synchronous
readback or invented completion API is used. A cold pending path is bounded by
the existing per-pass retry/60s session/4096-callback limits. Runtime freeze or
startup responsiveness is not declared solved by these limits.

Inputs are16 frozen copies of one actual captured main-app context with controlled
20µm seed film. Physical equations,dt,force/source resampling and displayed s87
physics are unchanged. Nonzero coupled births/heads,continuous intake,film optics
and game FPS remain separate integration gates. Failed suffixes still submit
their bounded graph;this is not a speculative unbounded source stream.

## Verification

Seventeen real-owner/queue/executor modes and10 tails cover delayed/pending/slow
SDK,synchronous/reversed/duplicate callbacks,all four first-window refusal
positions,invalid first/second or falsely blocked receipts,unknown submissions,
timeout,cancel and repeated refusal. Normal16 inputs produce4 windows/2 cohorts/
1184 draws/130 allocations/debt0;the delayed path begins arena2 while arena1's
CPU result is pending. The owner refuses reuse until both validated results.

Six chain/window shader variants compile warning-free under `/WX /Ges ps_5_0`;
texture bindings peak15. An early first-summary variant triggered X4000 in FXC
after adding an early-return branch. A single final return plus explicitly
bounded vector indices compiles cleanly. The failed generated source/log remain
in `window_preflight/510efc…` and `chain_compiled/body_887859…`;no warning is
suppressed or excluded from the passing compile report.

Native physical checks pass4378 draws across separate sequential intervals and two owned
arenas using actual HLSL outputs. Normal roots,refused/partial predecessors and
malformed predecessor receipts are checked in `gpu_checks.json`. Native arrays
model ordered storage reuse;they do not prove actual CSP scheduling/callback
overlap or measure GPU timing. Seven real-adapter/panel cases,five lazy main
guards and six decoder rejection controls pass. Installed links are hashed.

The deliberate NaN predecessor produces a first-summary error flag1,advance0
and blocked marker256002 while retaining NaN in the diagnostic water word.
The shared native oracle rejects that nonfinite output. This expected stop is
captured as an error-path control,not converted into an accepted full-window
receipt. The guarded interval's retained roots remain unchanged;the remaining
blocked window is not claimed executed in this NaN control. Initial stopped
harness/source and the real64-byte error output are preserved separately.

## Actual CSP observation and decision

Fresh-session report and decoded log agree:observed;2 cohorts/4 windows/16 inputs;
1184 accepted draws;130 textures/148869184 descriptor bytes;4 readbacks and4 CPU
disposals;20 verified file checks. Advanced time0.319580078125s,debt0. Every
window has completed prefix4/mask15 and normal marker256001. Ordered receipt,
finite stock/time/area and resource checks pass without changing their bounds.

| Actual ordered submissions | Cold cohort | Warm cohort |
| --- | ---: | ---: |
| First window accepted frames | 646–961 | 975–977 |
| First CPU callback frame | 971 | 987 |
| Second window accepted frames | 962–964 | 978–979 |
| Second CPU callback frame | 974 | 989 |
| Cohort caller time ms | 5375.0797 | 246.8832 |
| Whole-pump peak ms | 6.8384 | 3.0340 |
| SDK pending returns | 315 | 0 |

All second-window SDK draws are accepted7/8 frame increments before their first
window's CPU callbacks. Both valid final receipts verify eventual ordered
physical results. This passes the actual two-arena submission/ownership gate;
it does not locate GPU execution/completion before the callback without GPU
timestamps. All4 read requests still return10 engine frame increments later,
with153.55–165.38ms caller readback latency.

The warm cohort completes8 inputs in246.8832ms:32.4040 inputs/s,or25.9232/s after
20% reserve. This is a20Hz count-capacity planning candidate only. Physical time
advanced is159.7900ms:service ratio0.64723. Final finite-list debt0 does not
demonstrate continuous input catch-up. Runtime response age is unmeasured.

The prior s255 warm8-input window took240.7645ms. Here the observed caller cycle
is2.54% longer while descriptor memory doubles70.986→141.973MiB,receipts double
2→4 and total16-input draws rise1152→1184. Sessions,physical dt and stock differ;
there is one warm sample per variant. In addition,s255's cycle ends at the
receipt callback and starts at the previous callback,while this cohort starts
at preparation and ends at owner consumption. The comparison is approximate,
not a matched replay A/B or statistically established2.54% regression. It does
not demonstrate the throughput gain needed to adopt the extra memory.

Warm submission spans5 frame labels(975–979),versus3 s255 submission callbacks;
the two preparations and second window still have a cost. Warm SDK-call elapsed
sum9.5647ms,max0.2481ms;bind2.3281ms and submit preparation1.3000ms. These sums
are host/SDK measurements,not GPU timings or proof of which operation dominates.
Whole-pump peak3.034ms exceeds the3ms soft budget by0.034ms;record it without
using this tiny overrun as the reason to reject adoption. The missing throughput
benefit at doubled memory is the material decision.

Cold cohort5.375s includes315 pending returns;start is26.2275ms and maximum
whole pump6.8384ms. This does not show a5s blocked frame,but cold preparation
and the indivisible start remain integration risks. Different pending counts
versus s255 do not establish a general startup improvement.

**Decision:**execution gate passes;optimization adoption is deferred. Preserve
s256 as a qualified functional prototype and keep s255 as the current lower-memory
execution candidate. No game-visible default changes are made. Results and
reproducible comparison are sealed in `actual_capture.log`,
`actual_observation.json` and `actual_evaluation.json`.

## Reproduction

Fresh unpaused game/replay;other diagnostics OFF. Main RainFX → Weather inputs
and physical units (P0):**Enable s256 two-arena continuation** →
**Run s256 two-arena continuation once**.

Normal expected:observed;4 windows;16/16 inputs;1184 draws;130 resources;debt0.
There are2 cohorts. Physical refusals may increase windows/cohorts/draws without
new canvases. Send displayed values/error. About142MiB is retained until session
end. Logs automatically contain GPU submit/read request/callback frames,per-window
preparation/SDK costs and per-cohort caller cycles. No driving/weather/FPS
comparison is needed for this ownership/overlap gate;the log is below1000 lines
even at the bounded retry count.

## Next work

The actual submission overlap is now demonstrated. It does not justify more
arenas or longer windows without a measured benefit. Reduce per-interval repeated
work and static duplication where measurements support it;retain the bounded
continuation prototype for later intake/response-age work. Do not infer live20Hz
suitability from frozen-list drain or automatically lower cadence. Resource
ownership,physical time/source integration and public visual adoption remain
necessary;no arbitrary larger-window experiment is selected.
