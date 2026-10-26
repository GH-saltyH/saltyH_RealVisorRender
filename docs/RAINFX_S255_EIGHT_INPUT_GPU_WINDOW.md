# s255 — eight-input GPU confirmation window (2026-10-23)

## Change

s254 shows that CPU confirmation occupies roughly77–79% of fast four-input
cycles. s255 runs up to eight ordered physical input intervals before reading
one final receipt. It uses the qualified private3ms/256-call soft whole-pump
policy,without another call-ceiling experiment. Physical dt,forces,water events,
material calibration and the transport solver are unchanged.

| Sixteen normal complete inputs | Four-input windows | Eight-input windows |
| --- | ---: | ---: |
| CPU receipts | 4 | 2 |
| Draws | 1184 | 1152 |
| Logical resources per graph | 296 | 576 |
| Owned textures | 65 | 65 |
| Texture descriptor bytes | 74434592 | 74434592 |
| Descriptor MiB | 70.986 | 70.986 |

The logical node/pass cap is explicitly extended to1024;the physical cap stays
192MiB. The same last-use map keeps final film/history/checkpoint,dummy and
receipt exclusive. Long-lived static geometry is shared within all eight
intervals. The executor still waits for a validated CPU receipt before rebinding
the working set;this is a longer static window,not asynchronous speculative
CPU reuse or a general GPU completion fence.

## Time and refusal contracts

The descriptor carries two `vec4` time banks. A bounds-safe shader adapter
selects interval1..8 without out-of-range vector access. Accepted-action masks
are contiguous0/1/3/7/15/31/63/127/255;the completed-input prefix is0..8. All
mask values remain exactly representable in FP32.

Later inputs run only after a clean,complete prior prefix. A refused or partial
input preserves its checkpoint and blocks every later commit. The queue halves
the refused step and retains all remaining time. A native reference may not
advance to the next generation until that step completes. Tail slots outside
the declared count neither advance time nor rearm checkpoints. Queue capacity
stays16 inputs,64 windows and24 attempts per input. One-tick refusal still faults.

Even blocked suffixes submit the576-pass bounded graph. Thus longer windows
amortize confirmation on successful runs but can increase wasted work during
frequent refusal. Larger input batches do not justify dropping time or changing
the admission threshold. Capacity metrics count completed inputs only and
continue to leave continuous-throughput qualification false.

## Verification

- Independent lifetime/shape/pin checks confirm576 logical resources in65
  owned allocations with the same74434592 descriptor bytes.
- Eighteen full-owner modes cover all eight refusal positions,pending/slow SDK,
  sync receipt,invalid status/prefix/time,timeout,cancel and repeated refusal.
  Nine tail-count cases cover1..7,9 and15 declared inputs. Ten inherited
  queue/receipt/storage guards and both time-bank bindings pass.
- Three new control shader variants compile warning-free with strict flags;
  all texture bindings stay within16. No physical shader change is claimed.
- The native oracle passes5792 shader draws,replaying actual accepted/refused
  adaptive steps through an independent sequential solver. The16-input run
  produces complete prefixes8/6/0/2:masks255/63/1/3. The15th input naturally
  refuses,then succeeds as two half steps. Every window's film/history/
  checkpoint matches the sequential reference word for word;final debt0.
  Explicit refusals1/4/5/8,invalid summary propagation across the bank boundary
  and an accepted partial first step also pass. See `gpu_checks.json`. Native
  arrays model storage reuse;actual CSP is separate.
- An initial reference-only harness stopped at a naturally refused15th input.
  Its source/output are preserved in `initial_reference_harness.py` and
  `initial_full_step_reference_refusal.json`;the qualified oracle includes
  adaptive recovery instead of assuming every full step succeeds. Test dt is
  1.953125/0.9765625ms;production dt/admission thresholds are unchanged.
- Seven real-adapter mocked panel cases,five main host guards and six decoder
  rejection controls pass. The game symlinks match the workspace.

## Actual CSP observed

Fresh-session user result and automatic logs agree:observed;2 windows;16 inputs;
1152 draws;65 resources;2 readbacks and2 disposed CPU receipts;advanced
0.3061981201171875s;debt0. Both completed prefixes8/masks255 pass the unchanged
receipt/water/time decoder. Owned descriptor bytes remain74434592.

| Caller metric | Cold first window | Warm second window |
| --- | ---: | ---: |
| Cycle ms | 9262.1663 | 240.7645 |
| SDK pending returns | 535 | 0 |
| Active pumps | 536 | 3 |
| Readback ms in owner | 149.5233 | 154.9726 |
| Request→callback frame increments | 10 | 10 |
| Maximum whole pump ms | 5.8169 | 4.0850 |
| Maximum SDK call ms | 5.7403 | 0.0983 |
| Preparation bind ms | 2.3915 | 2.2580 |

Warm count throughput is33.2275 inputs/s;with20% reserve26.5820/s. The20Hz
planning gate is positive. Caller time per completed input is30.0956ms,versus
47.8840/56.0509ms for s254's two fast4-input captures:37.15–46.31% less in these
observations. Cycle time itself rises from191.54/224.20ms to240.76ms because
the window contains twice as many inputs. There is only one warm s255 sample;
sessions,frozen dt and evolving stock differ. This is not a paired FPS A/B or
a general performance bound. Native GPU timestamps were not measured.

The warm window advances153.0991ms in240.7645ms:physical-time service ratio
0.6359. Draining the finite16-input list with debt0 therefore does not prove
framewise continuous catch-up. Readback is still64.37% of warm caller cycle
and10 frame increments. The longer window amortizes this cost without reducing
its latency. At a hypothetical20Hz intake,collecting8 intervals covers400ms;
sample1→sample8 spans350ms. Adding this observed cycle suggests oldest-sample
age around591ms,or interval-start age641ms under that collect-then-execute
schedule. These are planning estimates,not measured live/display delays. Such
age cannot be assumed compatible with the one-render-frame head/trail goal.

Cold startup requires535 pending retries over9.26s,plus a14.1411ms owner start.
Pending is spread across callbacks;this is not evidence of a9s blocking frame.
It does require a bounded preparation/readiness path and preserving the current
renderer until ready. The exact SDK/compile reason for every pending return is
not proven. Warm whole-pump4.085ms is1.085ms over the3ms soft budget,with2
recorded overruns;single SDK calls peak0.0983ms. Indivisible CPU preparation and
poll overhead remain possible contributors;the aggregate log does not assign
that peak to a specific statement. Do not call it a strict budget pass or an
observed product FPS regression. See `actual_capture.log`,
`actual_observation.json` and reproducible `actual_evaluation.json`.

## Reproduction

Fresh unpaused game/replay session,other diagnostics OFF. Main RainFX → Weather
inputs and physical units (P0):**Enable s255 eight-input GPU window** →
**Run s255 eight-input GPU window once**.

Normal expected:observed;2 windows;16/16 inputs;1152 draws;65 resources;debt0.
Physical refusal can require more windows/draws without new allocations. Report
the displayed values or error. All inputs are frozen copies of one captured
engine snapshot;the seed is still the controlled20µm film. About71MiB remains
retained until session end. Cycle/pump/readback/preparation/capacity logs are
automatic. Weather/driving/FPS comparisons are not required for this private gate.

## Evaluation and next

Bounded eight-input execution passes its actual CSP gate. The observed
per-input caller cost improvement supports keeping this private candidate.
It does not pass continuous or visual adoption. A positive20Hz planning
candidate still requires valid time/force/source integration and response-age
checks before lowering film sampling frequency. Input staleness and wasted
blocked work can increase with window length. Never infer continuous catch-up
from a drained finite list.

Next evaluate bounded GPU continuation that separates CPU audit delay from
ordered GPU progress,or reduce interval work enough to use shorter windows.
Keep bounded in-flight storage,validated GPU prefix/time/ledger gates and
explicit resource ownership;never reuse CPU working slots on assumed completion.
Do not simply keep expanding batch size. Public head/film/optics,FPS and long-run
stability gates remain open. Visible game physics stays s87. No Git commit/push.
