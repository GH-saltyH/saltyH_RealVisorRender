# s254 — whole-pump pacing and measured capacity policy (2026-10-23)

## Decision

s253's four inputs per20 engine frames cannot serve one input every frame.
Simply declaring a lower update rate would not preserve forces or water events
between samples. Increasing dt beyond50ms would also bypass the current solver
contract. s254 changes neither input data nor physical time. It measures a
stronger execution budget and the complete receipt-to-receipt cycle so the
next scheduling/model decision has a measured capacity basis.

## Execution changes

The private owner accepts up to four immutable pacing profiles. Each profile
has1..256 SDK calls and a1..3ms soft whole-owner-pump budget. The diagnostic
alternates **32 calls/1ms →256 calls/3ms**,repeating for every window including
retries. The same296-pass four-input graph,queue,storage map,shaders and receipt
schema are used throughout. Sixteen declared inputs normally need four windows,
1184 draws,65 textures and74434592 descriptor bytes (~70.986MiB).

Unlike s253,the deadline starts **before** queue preparation,binding and typed
uniform preparation in a warm owner pump. If that work exhausts the budget,
no new draw is issued in that pump. Atomic bind/submit and SDK calls cannot be
preempted;an oversized operation can still overrun the soft budget. Both
dispatch and whole-pump overruns are recorded. Initial capture/graph creation
are outside `pump()`;`startMS` separately measures executor preparation and
first payload submission. This is not a hard bound on the full scene callback,
UI,bootstrap or all app work.

The versioned executor only raises its bounded per-pump draw ceiling64→256.
Receipt identity,ordered single-write logical DAG,lifetime/physical byte cap,
timeout,cancellation and quarantine guards are unchanged. Used resources remain
retained;the CPU still validates a receipt before rebinding the working set.

## Cycle and capacity accounting

Each warm window records wall-clock time from the preceding receipt callback
to its own receipt callback. It includes the intervening owner polling,queue
preparation,submission and readback delay. Cold cycle starts at executor start
and excludes capture and graph construction. Callback timing is sampled before
the executor validation function;only subsequently accepted receipts produce
a capacity result. These are caller-clock observations,not GPU timestamps.

The small policy module reports:

- `sourceHz = completed prefix ×1000 / cycleMS`.
- `safeHz = sourceHz ×0.8`,an explicit provisional20% scheduling reserve.
- `frozenServiceRatio = newly advanced physical ms / cycleMS`.
- Conditional per-frame capacity at30/60/144 FPS.
- A **coarser cadence candidate** only if safe capacity≥20 inputs/s,consistent
  with a maximum50ms physical interval at unit simulation/wall-clock rate.

Refused or accepted-partial inputs do not count as completed input throughput.
The20% reserve is a development planning assumption,not a measured p99 bound.
Replay rates other than1× require their own incoming-simulation-time budget.
No result sets `continuousThroughputQualified=true`,changes dt,resamples input,
averages forces,moves the public clock or drops time debt. Even a candidate
capacity result still needs a physically valid sampling/interval model and
continuous-input/quality verification. Inputs remain frozen copies here.

## Verification

- Fifteen complete accepted-command comparisons against s253,under baseline
  and alternating profiles,cover pending/slow SDK,all four refusal positions,
  sync receipt,invalid status/prefix/time,timeout,cancel,repeated refusal and
  expensive preparation. Shaders,uniform words,texture IDs and order match.
- Preparation consumes the same budget as drawing. Synthetic preparation
  overruns are retained and defer drawing;256-call pumps are exercised.
- Full-cycle calculations match independent callback timestamps. A delayed
  duplicate cannot overwrite the current receipt or cycle observation.
- Profile options are copied. Invalid limits/timing/prefix values are refused.
- Seven actual-adapter mocked panel cases,five default-OFF main host guards
  and six collector rejection cases pass. Game symlinks match the workspace.
- s253's2250 native physical draws are inherited because physical commands
  are unchanged. No redundant native solver run or new GPU speedup is claimed.

## Actual comparison

Fresh unpaused game/replay session,other diagnostics OFF. RainFX → Weather
inputs and physical units (P0):**Enable s254 whole-pump pacing comparison** →
**Run s254 whole-pump pacing comparison once**.

Normal expected:observed;4 windows;16/16 inputs;1184 draws;65 resources;debt0.
Refusals can require more windows and draws without changing the allocation
count. The collector accepts that bounded recovery;report the displayed values
if they differ or fault. Logs include cycle/pump/readback/preparation times and
capacity classification. Storage stays near71MiB until session end. Weather,
driving and FPS comparisons are not needed for this execution-policy gate.

The first baseline window is cold;compare subsequent warmed baseline/fast
observations with their evolved inventory noted. This is a small private
throughput sample,not an identical-state A/B or release-performance test.
The actual run completes4 windows/16 inputs/1184 draws/65 allocations with4
readbacks/disposals,74434592 descriptor bytes and zero retained debt. Advanced
time is0.2757720947265625s. Every window has completed prefix4/action mask15
and passes the existing GPU header/time/water audit path. No physical refusal
occurs in this capture. Full-field CSP equivalence and actual refused-input
recovery are outside this small receipt capture.

| Warm observation | Baseline window3 | Fast window2 | Fast window4 |
| --- | ---: | ---: | ---: |
| Whole-pump soft budget / call ceiling | 1ms / 32 | 3ms / 256 | 3ms / 256 |
| Active dispatch pumps | 10 | 2 | 2 |
| Full measured cycle (ms) | 361.9700 | 191.5358 | 224.2036 |
| Readback portion (ms) | 161.1970 | 146.9352 | 178.1609 |
| Maximum whole owner pump (ms) | 2.2964 | 3.0039 | 3.0126 |
| Bind + submit preparation (ms) | 2.1016 | 1.9947 | 1.4686 |
| Completed inputs/s | 11.0506 | 20.8838 | 17.8409 |
| Capacity with provisional20% reserve (inputs/s) | 8.8405 | 16.7071 | 14.2727 |
| Frozen accepted-time / cycle-time ratio | 0.1905 | 0.3599 | 0.3075 |

Both fast windows reduce the observed cycle by38–47% relative to the single
warm baseline and submit in two pumps. This qualifies the faster profile as a
bounded private execution candidate. It is one baseline and two fast samples
with evolving stock;there is no identical-state A/B,stable average,p95/p99
frame-time,FPS or isolated GPU timing claim. More SDK call-ceiling comparison
is not the next priority.

The fast pumps each record one strict overrun,only0.0039/0.0126ms above3ms.
Keep these counts,without treating such tiny soft-bound differences as product
failures or as proof of a hard3ms guarantee. The baseline also overruns because
its atomic preparation exceeds1ms;the owner then defers drawing. Raising the
budget increases the observed peak owner cost to about3ms,so game frame tails
remain a separate adoption gate.

All four callbacks still arrive10 engine frames after request (adapter
latencies153.5679/146.9287/161.1923/178.1562ms). Fast callbacks cover frame1410
to1422 and1443 to1455:12 frame increments per four completed inputs,versus21
for the warm baseline. Readback occupies about77–79% of the two fast cycle
times. These intervals are observations of this path,not a general GPU fence
or proof of internal CSP scheduling behavior.

Neither fast window reaches20 completed inputs/s after the provisional reserve.
Even a20Hz/50ms film cadence therefore does **not** pass this planning gate.
The declared input time per window is only68.9430ms,so the0.31–0.36 frozen
service ratios are also below real-time progression. No live input stream was
sampled during the solve;zero debt for the drained finite list does not prove
continuous catch-up.

Cold window1 takes4480.0804ms from executor start to receipt,with240 pending
attempts,244 active pumps,max SDK wrapper5.1413ms and max owner pump5.4768ms.
`startMS` is13.7579ms;capture/graph creation are outside it. The multi-second
readiness interval is not a measured single blocking call. Its cause and the
full startup scene-callback cost remain unqualified.

Evidence:`diagnostics/2026-10-23/s254/actual_capture.log`,
`actual_observation.json` and `delivery.json`. Pending source/delivery versions
are archived before recording actual results. Descriptor storage stays near
71MiB;driver VRAM and game FPS remain unmeasured.

## Next decision

The fast profile improves finite-window execution,but misses the reserved20Hz
capacity gate. Prioritize safe GPU continuation with less frequent CPU
confirmation or reduce per-interval solver work. Do not compensate with silent
decimation or larger unverified time steps. A coarser film cadence still needs
explicit time/force/source integration,interpolation and quality verification.
Public head/film/optics adoption,FPS and
warm stability remain separate gates. Visible physics stays s87. No Git write.
