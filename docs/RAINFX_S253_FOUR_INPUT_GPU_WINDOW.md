# s253 — four-input GPU continuation window (2026-10-23)

## Change

Four ordered physical input intervals run in one private GPU submission,with
one CPU receipt after the fourth interval. The previous window held two inputs.
Input headers remain distinct;static geometry/topology/zero fields are shared
within the window. The physical transport shaders and water model are unchanged.

| Eight declared inputs,normal complete steps | s252 two-input windows | s253 four-input windows |
| --- | ---: | ---: |
| GPU windows / CPU receipts | 4 | 2 |
| Draws | 620 | 592 |
| Logical resources per window | 155 | 296 |
| Owned textures per working set | 64 | 65 |
| Texture descriptor bytes | 74434528 | 74434592 |
| Descriptor MiB | 70.986 | 70.986 |

Storage grows by64 bytes:one16-float status-sized allocation. The versioned
lifetime verifier/executor allow up to512 logical resources,with the same
192MiB physical cap. Retained final film/history/checkpoint,dummy frame and
receipt remain exclusive. Aliasing never crosses a same-pass read/write.

## Dependency and refusal handling

Each input writes a16-word chain summary. Later transport decisions run only
if the preceding summary has the correct receipt,a clean audit and a complete
accepted prefix. A blocked input copies the preceding checkpoint rather than
rearming it for a new token. Its decision is zero,so packed film/history outputs
retain the last accepted or refused state. Later summaries propagate previous
failure rather than hiding it behind an otherwise valid later solve.

The final receipt contains the completed-input prefix0..4 and contiguous
accepted-action mask0/1/3/7/15. The first input may be a partial dyadic retry.
An accepted partial step does not unlock the next input. The queue accounts for
the exact normalized ticks;the shader recomputes advanced and retained time
from the action mask,without dropping a blocked suffix's declared time.

After a refusal,the CPU queue halves the refused input's step and preserves
all later inputs. It retries only after the existing validated receipt returns.
At most16 inputs,64 windows and24 attempts per input are allowed. A one-tick
refusal faults instead of looping. Last windows with1..3 real inputs use
disabled dummy slots;those slots neither advance time nor rearm checkpoints.

The whole296-draw command graph still gets submitted for blocked suffixes;
GPU decisions gate commits. This is bounded speculative work,not a claim that
refusal avoids all GPU cost. A GPU audit failure quarantines the slot;it is not
treated as an ordinary physical refusal.

## Verification and gate

Local evidence is under `diagnostics/2026-10-23/s253/`:

- Independent lifetime/shape/pin audit and bounded allocation sum.
- Fourteen complete-owner modes:normal,pending,slow,synchronous receipt,
  refusal at each of four inputs,bad status/prefix/time,timeout,cancel,and
  repeated refusal. Six tail-count cases and ten queue/receipt/storage guards.
- Native2250 shader draws pass:eight changed inputs across two windows match
  every retained root of the sequential solver. Four refusal positions,
  an invalid earlier summary and an accepted half first interval preserve
  inventory/checkpoint and block later inputs. This uses per-pass native
  arrays for storage reuse,not a general D3D completion fence. The completed
  native result is in `gpu_checks.json`.
- The all-accepted native control uses changed contexts with1.953125/0.9765625ms
  intervals. A larger-step reference run crossed an unfinished generation;
  its failure is retained in `full_step_reference_transition_failure.json`.
  It is not a passing full-step/real-time observation. Refusals are separately
  injected at all four positions;an accepted half first interval also checks
  the blocked suffix. Solver admission thresholds are unchanged.
- Three new window shader variants compile with strict warnings-as-errors;
  texture bindings stay within16. Explicit casts correct signed/unsigned
  comparisons in the new control loops,without changing the physical solver.
- Main panel/adapter and default-OFF host guards pass. Actual CSP results are
  recorded below;full-field CSP comparison is not part of the small receipt.

Fresh unpaused game/replay session;other diagnostics OFF. RainFX → Weather
inputs and physical units (P0):**Enable s253 four-input GPU window** →
**Run s253 four-input GPU window once**. Normal expected result:
2 windows,8/8 inputs,592 draws,65 resources,debt0. Two CPU readbacks/disposals.
The initial inventory is the existing controlled20µm film. Inputs are eight
frozen copies of one captured engine context;this is not new rain supply or
live visual physics. About71MiB remains allocated until session end. Logs
include command pacing and readback frame/time measurements.

## Actual CSP observation

The collected run completes2 windows/8 inputs/592 draws with65 allocations,
74434592 descriptor bytes,2 readbacks and2 CPU-data disposals. Advanced time
is0.17249298095703125s;retained debt0. Each window has completed prefix4 and
action mask15. Both GPU receipt/header/time/water audits pass. No physical
refusal occurred in this actual capture;refusal/partial recovery evidence is
the separate native and local controls.

| Metric | Cold window1 | Warm window2 |
| --- | ---: | ---: |
| Accepted draws | 296 | 296 |
| Pending attempts | 278 | 0 |
| Active dispatch pumps | 284 | 10 |
| Maximum dispatch (ms) | 6.9219 | 0.6948 |
| Maximum SDK wrapper call (ms) | 6.8391 | 0.2467 |
| Maximum whole owner pump (ms) | 6.9277 | 2.7044 |
| Bind + submit preparation (ms) | 3.0853 | 2.0842 |
| Typed conversion calls | 1502 | 71 |
| Readback latency (ms / engine frames) | 150.1825 / 10 | 160.5524 / 10 |

The warm window has9 call-cap deferrals and no deadline deferrals/dispatch
overruns. It submits from frame1572 through1581,after the preceding receipt
at1571;its receipt arrives at1591. Thus four inputs consume20 engine-frame
increments between validated receipts. The two windows each advance
0.086246490478515625s of the frozen declared input time. There is no measured
wall-clock duration for the entire warm cycle;do not turn a captured dt or
readback-only elapsed time into a measured full-cycle throughput ratio.

At one newly captured input per engine frame,this20-frame/four-input cadence
cannot catch up:it accepts only one fifth of that input count. This conditional
frame-count comparison is not a measured physical-seconds or GPU speedup.
Reducing receipts to one per four inputs passes the bounded execution gate,
but continuous throughput remains unqualified. The per-receipt10-frame wait
has not shortened. The cold SDK call also remains non-preemptible;its cause
is not established as shader compilation by these timings.

Retained water changes805.772156→804.874512→803.845703mm3;the final cumulative
evaporation/runoff are0.126119/1.800259mm3. These use the unchanged solver's
GPU ledger checks. Actual full-field equivalence,general completion fencing,
GPU timestamps,FPS and total driver VRAM remain unmeasured. The70.986MiB is
the texture descriptor sum. Pending source/delivery versions are archived;
actual logs and decoded values are in `actual_capture.log` and
`actual_observation.json` under this stage's diagnostic directory.

## Limits and next decision

Halving receipt count does not shorten the latency of each callback. At the
unchanged32-call pacing ceiling,a warm296-draw window needs at least10 pump
callbacks. Continuous catch-up is therefore **not qualified**,even if this
bounded diagnostic drains its declared time. Per-call SDK stalls can still
exceed the1ms pre-call soft budget,and whole preparation is outside that budget.
GPU timestamps,FPS,long-run stability and visible rendering remain unmeasured.

The actual result identifies both the call ceiling and CPU receipt wait as
throughput limits. Next,choose the pacing/update-frequency and continuation
policy against an explicit incoming-time budget,then connect bounded continuous
intake. Whole-pump preparation/cold tails also remain outside the dispatch
budget. Do not assume simply expanding a frozen window can reach real time. Main
public source/head/film/optics adoption follows its separate game gates.
Visible physics stays s87. No Git commit/push is made by this stage.
