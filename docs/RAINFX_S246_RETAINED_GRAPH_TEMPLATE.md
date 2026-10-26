# s246 — retained graph template (2026-10-23)

## Purpose and scope

s245 measured repeat graph construction at66.4969ms mean, inside66.8287ms
admission. This is construction of the candidate physical/validation graph,
not a cost attribution to the current visible s87 renderer. The benchmark
repeats a frozen input; it does not cover continuous engine time.

s246 compiles s243 topology once per private diagnostic run. It retains all
85 resource descriptions, shader bodies, edges, caches and loopbacks. Each
input bind owns a copied context, fresh validation/results state and updated
packet values:52 frame rows and expected audit rows, dt, boundary/current/
previous tokens, resume and adaptive attempt progress. Nothing uses an old
context closure to validate a new input. Shape/files/physical calibration
changes refuse and require a new template; existing admission guards remain.

The s242 owner is unchanged, including its layout checks and CPU call budget.
Initial graph construction, packet copying, admission layout comparisons,
GPU submission count and status round trips are not removed. The new validator
also explicitly refuses nonfinite or malformed16-word summaries. This is a
private solver candidate optimization; source/head production and visible
optics remain unconnected.

## Local qualification

- Every resource, shader, texture edge and uniform schema matches s243.
- Every packet value matches across5 changed pose/air/force/material/dt/token
  contexts and15 full/refused-retry/partial-completion tickets.
- 210 validator comparisons match the previous acceptance/refusal outcomes;
  independent context/packet/result state survives later binds and caller edits.
- Six file/shape/scale/calibration/downward-air/nonfinite input controls refuse.
- Reference graph generation occurs once per template, rather than each bind.
- Seven real-adapter/executor mocked panel cases pass:normal,pending,sync,
  invalid status,timeout,image readiness wait,cancel;five main host guards pass.
- Main/docs symlinks and inherited installed dependency hashes are verified.

These tests compare all shader bodies and packet inputs, not a new native GPU
solve or actual CSP timing measurement. No cost reduction percentage is claimed.
Prior sealed stages are preserved. No Git commit/push or root-helper copy.

## Actual CSP result

Fresh-session user report and automatic log agree:observed,completed8/8,
draws568,resources85. Eight status readbacks were validated/disposed;retained
debt and quarantine are zero. All seven repeats had zero not-ready attempts;
81 not-ready attempts occurred in the cold interval. There were282 callbacks,
20 file checks and zero image waits. Engine clock source is cdata;adapter is
a Lua function. Storage remains95,622,448 bytes (91.193MiB).

| Metric | s245 mean ms | s246 mean ms | s246 max ms |
| --- | ---: | ---: | ---: |
| Initial graph build (one sample) | 73.7325 | 73.9595 | 73.9595 |
| Repeated graph build → template bind (7 samples) | 66.4969 | 0.1568 | 0.3174 |
| Repeated admission including build/bind (7 samples) | 66.8287 | 0.5391 | 0.8089 |
| Status request-to-callback wall latency (7 samples) | 144.5055 | 156.6886 | 168.2104 |

The recurring construction bottleneck is removed in the actual private
benchmark. Admission mean falls99.19%;this is a scoped CPU improvement,not
an application FPS gain. Initial construction remains about74ms once per
template. Bind/graph time is nested inside admission;do not sum them.

Status latency remains large. These are different fresh-session captures,
not paired identical-frame measurements,so the difference144.5→156.7ms does
not establish a causal regression. It includes engine scheduling,queue and
readback;no GPU execution timer was used. Next review the status/readback
completion policy and whether whole input intervals can proceed with fewer
CPU round trips while preserving rollback,ownership and validation.

Frozen private modeled time is0.13896942138671875s across eight intervals;
this is not continuous engine coverage. Actual FPS/GPU timing and sustained
throughput remain open. Visible physics/optics stays s87. Evidence is in
`diagnostics/2026-10-23/s246/actual_capture.log`, `actual_observation.json`
and `comparison.json`;pending documentation/tool source is retained in
`pending_sources/` and the earlier delivery in `pending_delivery.json`.

## Reproduction procedure

The default-OFF main panel is **Enable s246 retained graph profile** →
**Run s246 retained graph profile once**, under RainFX → Weather inputs and
physical units (P0). Other diagnostics should be OFF. Use a fresh unpaused
session to clear retained resources and the app log quota.

Expected:observed,completed8/8,draws568,resources85,eight readbacks/disposals,
zero debt. About91.193MiB remains until session end. No weather/driving/FPS
comparison is required. The existing profiler labels `repeat/graph_build`
now measure template binding; cold includes the single reference build.
Keep this semantic distinction when comparing to s245. Admission-inclusive
time remains the useful total because owner layout checks remain unchanged.

Collected via `docs/tools/collect_s246_observation.py`. Status latency includes
scheduling/queue/readback; no GPU timestamp or continuous throughput
qualification is produced by this benchmark.
