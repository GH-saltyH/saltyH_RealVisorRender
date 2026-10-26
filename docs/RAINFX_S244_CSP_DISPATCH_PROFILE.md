# s244 — actual-CSP dispatch CPU and completion-latency probe (2026-10-22)

## Delivered and scope

A default-OFF main-app panel executes the s243 private graph through the s242
budgeted owner and existing CSP canvas/status adapter. It bootstraps one actual
visor context, then repeats that frozen input for eight benchmark intervals.
Controlled20µm water is initialized once; private film/history persist between
intervals. Local panel/executor checks pass; **actual CSP observation is pending**.

This explicitly frozen benchmark is not eight sampled engine frames or coverage
of elapsed replay time. Its dedicated admission adapter owns only benchmark
tokens/order/progress. It does not replace production source/scale admission.
The original frame, pose, weather, material and calibration remain frozen;
the private tokens advance to exercise continuation. Public time, natural rain
birth/head sources, renderer access and visible s87 optics remain disconnected.

## Measurements

CPU aggregates record count,total,mean and maximum; storage is bounded by fixed
metric names and eight interval summaries rather than a growing frame history.
They distinguish interval one (`cold`) from intervals2–8 (`repeat`). Repeat
does not automatically mean warmed: each interval records pending submissions,
and only repeats with zero pending calls count as `readyRepeatIntervals`.

- One-time canvas allocation and per-interval graph construction.
- Backend uniform conversion, including benchmark profiling overhead.
- Actual SDK `updateWithShader` call time, split into input proof, geometry,
  initialization, handoff, transport and stock/status groups, and accepted vs
  not-ready outcomes. Not-ready does not identify compilation as its sole cause.
- Status request-to-callback latency, and callback-forwarding CPU time.
- Inclusive owner pump and subsequent admission CPU time. These overlap the
  uniform/draw/validation work and must not be added as independent components.
  Synchronous callbacks may defer executor validation into the pump; callback
  forwarding is not guaranteed to include all validation in that case.

There are **no GPU timestamps**. SDK call duration is CPU submission time,
possibly including driver work; status latency includes engine scheduling and
queue/readback delay. Neither is a GPU execution timer or FPS measurement.
Per-uniform clock calls and profile aggregation perturb CPU cost; group
comparisons are diagnostic, not an uninstrumented production budget.

File-image readiness waits are counted separately from actual SDK attempts.
The85 canvases/95,622,448-byte logical plan (~91.193MiB) remain retained until
the app/session ends. Default execution remains8 SDK calls/pump with a1ms soft
pre-call deadline. The overall probe stops after60s or4096 callbacks, and the
existing per-read timeout and invalid-receipt fault rules remain active.

## Local verification

Seven cases exercise the real panel, graph, benchmark admission, budgeted owner,
executor and CSP adapter with mocked canvases/status: normal, shader-not-ready,
synchronous callback, failed GPU audit, absent readback, pending file images and
cancellation. Successful cases complete8/8 with85 resources and8 reads/disposals.
The expected no-refusal accepted draw count is85+7×69=568. Mocked status values
are fixture-adapted; these tests are not another physical solve. Physical kernel
and packed continuation evidence remain the preserved s243 native results.

Six benchmark controls reject mutated/busy/duplicate/out-of-range/foreign-source/
over-limit progress; the final benchmark time closes at eight represented dts.
Five report corruptions and five lazy/native/offscreen host guards refuse, and
Lua syntax passes. Mock file dimensions were corrected to the actual2048×512
du/dv and1024×256 cells dimensions before final checks. Installed helper,
prototype/dependency hashes, SDK and main/docs symlinks are audited.

## Actual game procedure

Start a fresh unpaused game/replay session so the app log quota and retained
diagnostic canvases start clean. Keep other diagnostic panels OFF. In Real
Visor Overlay → RainFX → Weather inputs and physical units (P0), enable
**s244 dispatch profile**, then press **Run s244 dispatch profile once**.

Report `observed`, `completed8/8`, and `resources85`, or the error message.
The automatic report contains at most100 lines; no manual log/FPS/weather/
driving comparison is needed. Shader readiness can make the first interval
slow. `observed` is set after all eight private intervals validate and the
report is written. Pending/rejected attempts can increase draws/readbacks,
so568 is not an unconditional acceptance requirement.

## Next

Collect the actual result and distinguish CPU graph/uniform/submission work,
not-ready retries and callback latency before choosing the next throughput
change. Low CPU call time alone cannot clear a GPU/frame bottleneck. Cold85
submissions still need at least11 pumps under the8-call ceiling; this probe does
not claim sustainable every-frame intake. Continuous sampler/source linkage,
conserved birth/head effects, common optics, reset/replay and long-run adoption
remain open. The s239 CPU-tail warning remains. No Git commit/push is performed.

Evidence: `diagnostics/2026-10-22/s244/checks.json`, `runtime_audit.json` and
`delivery.json`; actual capture/observation will be added after the game run.
