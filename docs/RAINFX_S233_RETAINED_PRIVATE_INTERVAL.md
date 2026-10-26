# s233 — retained private interval (2026-10-22)

## Delivered

The main app now offers a default-OFF **retained water interval**. One captured
visor context is solved in four consecutive quarters using the existing s163
packed End/Mean transport. It initializes20µm of controlled film once, then
carries End/Mean, checkpoint and cumulative ledger into each next quarter.
The fourth accepted quarter finishes the represented interval with zero private
time debt. **Local integration and one actual CSP retained-interval observation pass.**

The new owner is `rain_preview_recurrent.lua`, built around the unchanged s231
executor, CSP adapter and s232 verified-file adapter. It holds one fixed slot,
exports no GPU handle, and admits a next quarter only after the previous status
readback validates. s232 remains preserved and available separately.

## Actual CSP observation

Captured frame1513 completes4/4 quarters:267 accepted draw submissions,
81 cached passes,348 logical passes,87 canvases and three slot reuses.
Four status readbacks and four CPU-data releases complete with zero quarantine.
The32 automatic log lines preserve all input rows and four exact receipts;
independent context/pose identity, sequence, water-budget and time checks pass.
The GPU handoff checks accept all three transitions. Actual whole-array CPU
comparisons are not claimed; those remain local WARP evidence.

| Accepted quarter | Film mm³ | Cumulative evaporation mm³ | Cumulative runoff mm³ | Advanced s | Retained s |
|---:|---:|---:|---:|---:|---:|
| 1 | 805.733398 | 0.002957 | 0.035695 | 0.004075289 | 0.012225866 |
| 2 | 805.693298 | 0.005915 | 0.072867 | 0.008150578 | 0.008150578 |
| 3 | 805.652832 | 0.008872 | 0.110325 | 0.012225866 | 0.004075289 |
| 4 | 805.612122 | 0.011829 | 0.148078 | 0.016301155 | 0 |

Initial controlled water is805.772095mm³ throughout the history. Every quarter
passes the existing mass budget; the final residual is−0.0000660000mm³.
Maximum normalized GPU ledger residual across the run is0.00521154, limit1.
No quarter reinitializes water or reapplies completed time. The full captured
represented dt0.016301155s is consumed; raw-dt quantization remainder remains
a separate future engine-interval responsibility.

This qualifies one frozen context and four private steps in actual CSP. It
does not establish continuous frame admission, whole-app memory stability,
renderer lifetime, optical quality or FPS improvement. Original observation and
pre-observation delivery remain bound by `actual_observation.json`,
`actual_capture.log` and `pending_delivery.json`; pre-observation documentation
is copied under `pending_sources/`.

## State and lifetime contract

1. Capture one immutable engine/visor context. Quantized represented dt,
   geometry, forces, material and token stay fixed for its four quarters.
2. Initialize the controlled water and geometry only for the first quarter.
3. After its valid private receipt, copy the prior packed End/Mean output,
   checkpoint and history into separate input-snapshot canvases for the next
   quarter. The old output is never simultaneously the new draw target/input.
4. A full-bank GPU handoff check compares every End/Mean word and all checkpoint/
   ledger words exactly. All prior-output reads precede every state-root write.
5. Run the unchanged conservative transport, then validate stock, water closure,
   sequence and time. Commit only this validated quarter to private progress.
6. Stop after four quarters. No fifth quarter, automatic restart or new weather
   frame is admitted through this one-shot interface.

Twenty-seven initialization passes have only immutable dependencies. Their
shader/uniform/texture signatures are retained after the first validated run;
subsequent quarters use the owned cache. Per-job receipt uniforms are excluded
only because those cached shader bodies never read them. Dynamic state-copy
passes cannot enter the immutable cache. No foreign mutable textures are imported.

Unknown submission, bad receipt, timeout, cache mutation or rejected handoff
stops further admission and retains uncertain resources. Cancellation preserves
the last committed progress/debt and does not restart or allocate another pool.
Outputs of an unvalidated attempt have no renderer/publication authority; this
owner does not provide a renderer rollback/export API. A future renderer lease
must protect its own readers and published bank independently.

## Bounded cost

One fixed graph has **87 canvases / 95,622,608 logical texture bytes
(91.1928MiB at4096 head capacity)**, within its128MiB private budget. There are
no per-quarter GPU allocations. The packed input bank adds4MiB over s232; the
handoff scratch adds about32KiB. These figures exclude cached file images,
object/driver overhead and the rest of the app.

Each graph traversal has87 logical passes. Four traversals accept348 logical
passes: **267 actual draw submissions and81 immutable cache hits**. This is a
command-count result, not a measured FPS improvement. Each scene-ready callback
attempts at most one SDK draw, while allowing up to eight logical cached passes.
One64-byte status readback per accepted quarter totals256 bytes per interval.
All GPU allocations remain held until app/session end.

## Local verification

The test runs the real Lua owner/executor/adapter against software D3D draws
on the actual1024×256 grid, with a mocked SDK lifecycle. WARP single-draw tools
copy results through CPU arrays between calls; this does **not** itself prove
CSP persistent-resource lifetime or target timing. That requires the game run.

All retained transport shader bodies equal their s163 packed-input parents.
53 final shader bodies compile with `/WX /Ges`. Nine state copies—three per
handoff—match their prior source arrays bit-for-bit, including the full Mean
bank. A one-bit Mean-only copy corruption is detected by the GPU handoff check.
Independent CPU sums of every quarter's full output and eight-row water/momentum
ledger satisfy the existing128-FP32-epsilon /1e−9 component budget.

The existing s152 local fixture starts at805.772095mm³:

| Accepted quarter | Film mm³ | Cumulative evaporation mm³ | Cumulative runoff mm³ | Advanced s | Retained s |
|---:|---:|---:|---:|---:|---:|
| 1 | 805.748413 | 0.003739 | 0.019864 | 0.004166603 | 0.012499809 |
| 2 | 805.724060 | 0.007478 | 0.040520 | 0.008333206 | 0.008333206 |
| 3 | 805.699524 | 0.011217 | 0.061318 | 0.012499809 | 0.004166603 |
| 4 | 805.674805 | 0.014956 | 0.082267 | 0.016666412 | 0 |

The cold start and warm quarters use the same87 logical handles. Local protocol
checks cover pending shaders, duplicate callbacks, wrong receipt, GPU refusal,
read error/timeout, uncertain copy submission, cache mutation, and cancellation
before/between/during quarters. A dynamic-cache admission mutation is rejected.
The real panel mock completes4/4 with three reuses and four CPU-data releases;
five lazy-host/capture guards pass. No public clock or game optics is advanced.

Two new initializer warnings were caught before deployment: signed integer
modulus (X3556) and an early-return branch (X4000). Unsigned indexing and
initialized single-return outputs fix them. Failed sources/logs remain under
`initial_failure/` and `initializer_warning/`. No physical coefficient, transport
body or tolerance was changed. An initial preparation-script directory ordering
error was fixed before the baseline was written.

## Actual CSP operation

In a fresh unpaused game session, open RainFX → Weather inputs and physical
units (P0), enable **s233 retained water interval**, then press
**Run s233 retained water interval once**. Expected: State observed,
completed4/4, actual draws267, cached81 and retained debt0.

The 32-line report is automatic. It contains exact context/pose identities,
52 captured input rows and four16-float quarter receipts. No driving, weather,
FPS or screenshot comparison is needed for this execution check. A fresh
session avoids the CSP app log cap. Used memory stays retained for the session;
OFF/ON does not create another run.

Evidence lives under `diagnostics/2026-10-22/s233/`: `checks.json`,
`recurrent_results.npz`, `host_checks.json`, `layout.json`, `draws.json`,
`runtime_audit.json` and `delivery.json`.

## Limits and next implementation

This finishes one **represented** captured dt. It does not establish handling
of new engine frames or accumulation of raw-dt quantization remainder. Mean is
the current accepted subinterval's Mean, not a time-weighted full-frame exposure.
No continuous performance, long-run memory or optical quality result is claimed.

Next admit new immutable engine intervals while preserving stock/time and
handling pose/material cache generations and pending time. Then connect the
conserved incident/head source and a protected renderer read lease/common
optics. Natural rain/birth, live head evolution and visible game water remain
on the existing s87 path. Smear/local impact film remain optional later work.
