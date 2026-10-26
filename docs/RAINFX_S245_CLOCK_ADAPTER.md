# s245 — callable clock boundary adapter (2026-10-22)

## Actual failure preserved

The s244 actual CSP run faults at s242 owner's `soft CPU deadline` guard after
CPU capture and graph construction, before any canvas allocation/submission.
The log records completed0/8,resources0,draws0,20 file checks. The captured
frame is628 and cold graph construction reports80.0571ms in this failed run.
That is one startup CPU observation, not warm dispatch/GPU/FPS evidence.

The guard requires `type(d.clock)=='function'`. Earlier graph timing already
successfully calls the supplied clock; configuration explicitly supplies the
numeric1ms budget. This points to a callable clock value with a different Lua
type. The original runtime source type was not logged, so its exact type is
not claimed as an observed fact for that failed run. The subsequent successful
s245 run directly confirms source type `cdata` (see below). The failure is retained in
`diagnostics/2026-10-22/s245/s244_fault.log` and `fault_observation.json`.

## Repair

The new versioned panel captures `os.preciseClock` as `rawClock` and passes
`function() return rawClock() end` to the profiler/owner. The owner still checks
for an actual Lua function; deadlines, limits and numerical rules are unchanged.
The benchmark, profiler, executor, physical graph and failed s244 panel remain
unchanged. A new report line records `clockSourceType` and `clockAdapterType`.
The decoder requires a function adapter and preserves the original source type.

No production FFI or alternative clock source is introduced. The wrapper calls
the same engine clock on each use rather than caching time. The source must
still be callable and return valid times; this does not mask a broken clock.

## Reproduction and local checks

A real LuaJIT callable FFI function-pointer value (`type=='cdata'`) reproduces
the old panel failure at the same guard with zero allocations. The new panel
completes8/8 with callable cdata, a callable table and a regular Lua function.
The cdata fixture runs without JIT compilation to avoid test-only Lua callback
reentry issues; no benchmark CPU numbers from it are interpreted as CSP cost.

All10 panel cases, the original six benchmark controls, five report-refusal
cases and five lazy/native/offscreen host guards pass. This includes pending
shaders, synchronous callback, invalid GPU audit, readback timeout, image
readiness wait and cancellation. Successful cases use85 canvases and8 status
reads/disposals. These are mocked GPU statuses; physical s243 evidence is reused.
Installed symlink/dependency/helper/SDK hashes pass the runtime audit.

## Actual CSP result

The user ran s245 in a fresh unpaused session and reported completed8/8,
draws568,resources85. The automatic report independently confirms `observed`,
eight validated status receipts, eight disposed CPU readbacks and zero debt or
quarantine. It records `clockSourceType=cdata`, `clockAdapterType=function`:
the adapter repair passes against the actual engine clock.

The graph retains85 canvases /95,622,448 bytes (91.193MiB) until session end.
There were289 callbacks,20 file checks and zero image waits. All87 not-ready
SDK attempts occurred in the first interval; each of the seven repeats had
69 accepted draws and zero not-ready attempts. Total accepted draws are
85+7×69=568. No actual refusal/retry occurred in this run.

Evidence: `diagnostics/2026-10-22/s245/actual_capture.log` and
`actual_observation.json`. Pending documentation is preserved in `pending_sources/`.

## Measured cost and priority

All CPU values below are milliseconds. Status latency is wall time from
readback request to callback, including engine scheduling, queue and readback.

| Measurement | Samples | Mean ms | Max ms |
| --- | ---: | ---: | ---: |
| Cold graph construction | 1 | 73.7325 | 73.7325 |
| Repeat graph construction | 7 | 66.4969 | 73.3149 |
| Repeat admission, including graph construction | 7 | 66.8287 | 73.6308 |
| Repeat accepted SDK submissions, total per interval | 7 | 1.2768 | Not aggregated |
| Repeat pump call | 136 | 0.1410 | 1.2438 |
| Repeat status callback | 7 | 0.2000 | 0.4790 |
| Repeat status latency (wall) | 7 | 144.5055 | 164.8177 |

Initial85 allocations cost10.1077ms in total. Repeat SDK submissions total
8.9379ms across483 accepted calls. Graph construction accounts for about99.5%
of repeat admission time. Unlike the failed s244 single cold build, this is
direct evidence of recurring CPU work in the actual benchmark. The owner
calls the full graph factory again for every interval, so retaining a compiled
recipe/template and refreshing only input values and validation context is
the next optimization priority. It must preserve new pose/force/time/header
inputs and refusal guards; reusing stale closures is insufficient.

Completion latency is a separate throughput issue. After removing repeated
graph construction, evaluate a completion policy that reduces CPU round trips
while preserving private ownership and validated publication. Further removal
of tiny proof passes is a lower priority given these measurements.

Do not add nested timers: graph construction is inside admission, submissions
are inside pump, and validation overlaps the status callback. The144.5ms wall
latency is not measured shader/GPU execution time. No GPU timestamps or FPS
were collected, so neither a GPU bottleneck attribution nor a performance
acceptance pass is justified.

## Remaining qualification

One captured frame686 is frozen for all eight intervals. Fixed dt is
0.015288352966308594s; total private modeled time is0.12230682373046875s.
This is not continuous replay coverage or sustainable live throughput.
Seven repeat intervals are a limited sample, not a long-run tail estimate.
Changed-input template parity, actual CPU improvement, completion throughput,
source/head integration and live optics adoption remain open. Visible s87,
public physics clock and renderer are unchanged. No Git commit/push.
