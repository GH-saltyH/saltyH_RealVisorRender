# s247 — paired minimal/full completion latency (2026-10-23)

## Decision needed

s246 fixes repeated recipe construction but still waits156.6886ms on average
from status request to callback. The actual executor refuses to admit the next
input until its16-word status is validated. This is a serial CPU round trip.
That wall latency does not identify GPU shader execution cost.

The installed SDK `ac_apps/lib.lua` documents `ExtraCanvas:accessData(callback)`
as asynchronous and provides no latency/queue mode parameter. The small data
size alone does not guarantee a short callback delay. Before changing water
ownership or speculatively advancing time, distinguish minimal readback latency
from latency on the physical graph path using the same engine/adapter.

## Implementation

The default-OFF s247 panel derives from s246 and inserts one minimal control
before each of its eight physical intervals. It writes16 known exact integer
values into one16×1 R32F canvas,then invokes the same private CSP adapter's
`readStatus`. All16 values are checked. The canvas is not overwritten until
the control callback completes. Physical execution starts only after that
check;existing owner,template,transport,rollback and receipt validation stay.

Each pair records minimal request-to-callback wall milliseconds,engine frame
numbers at both callbacks/requests and physical status frame numbers. Existing
profiler metrics record physical graph latency. No public stock/time/renderer
is advanced. This step adds attribution,not a throughput optimization.

One64-byte canvas is added:86 canvases /95,622,512 bytes in total. There remain
568 accepted physical draws and8 physical receipts;8 extra control draws and
8 extra readbacks yield16 reads/disposals. Control shader preparation may add
pending attempts. Used GPU allocations remain until the session ends.

## Qualification and limits

Seven adapter/executor mocked panel cases pass,plus eight focused control
lifecycle cases and five main/native/offscreen guards. Wrong words,timeout,
unknown submission,cancel,duplicate and synchronous callbacks are covered.
Installed dependencies and linked files are verified. Actual GPU control words
and runtime latency now pass the CSP observation below.

Controls precede physical intervals rather than running concurrently;other
game GPU work can affect both. Similar minimal/full delays would support
prioritizing fewer CPU readback barriers,not prove a specific engine delay
mechanism. A larger full delay indicates further workload/queue attribution
may be needed;the difference is not a direct GPU timestamp. Frame gaps are
engine-frame deltas,not GPU durations. No FPS or sustained throughput claim.

Future batching must retain GPU refusal/audit propagation,exact time debt,
private ownership and delayed publication. Removing a CPU check without an
equivalent GPU dependency/validation path is not an acceptable optimization.

## Actual CSP observation

Fresh-session report and automatic log agree:observed8/8,568 physical draws,
86 resources. There are8 additional control draws,16 readbacks/disposals,
zero control duplicates,20 file checks,zero image waits and zero debt or
quarantine. Control had1 not-ready attempt;all82 physical not-ready attempts
were cold,with seven ready repeats. Total allocated bytes are95,622,512;
the inherited summary's95,622,448 covers only the physical graph.

| Path | Repeated mean wall latency (7 samples) | Request→callback engine frames |
| --- | ---: | ---: |
| Minimal16-word texture | 148.2389ms | 10 in all8 samples |
| Physical graph status | 150.6607ms | 10 in all8 samples |

The first minimal/full measurements are151.7810/149.1491ms and also10 frames
each. Repeated physical admission remains0.5120ms mean (max0.7704ms),consistent
with the construction fix. Frozen modeled time is0.153167724609375s,not
continuous engine coverage.

**The observed delay is dominated by the readback/callback delivery path in
this session,not explained by the water graph workload alone.** All16 requests
return exactly10 engine frames later despite very different GPU work. This
does not prove an internal CSP fixed-delay implementation or a universal
10-frame guarantee. Shared engine scheduling,queue/readback policy remain
possible mechanisms. The2.4218ms difference of repeat means is not GPU time;
sequential frame durations and other game work vary.

Next implement bounded GPU-dependent continuation with refusal/audit state
propagated on GPU,then validate a batch receipt before CPU publication/reuse
outside that private chain. Waiting for CPU confirmation after every input
would retain this observed10-frame serial barrier. A valid batch must preserve
prior accepted water,unadvanced debt after refusals and input provenance;
simply removing the callback wait is not safe. The current executor/owner is
unchanged,so throughput improvement is not yet implemented or measured.

Evidence:`diagnostics/2026-10-23/s247/actual_capture.log` and
`actual_observation.json`. Pending documents/tool and delivery are archived
under `pending_sources/` and `pending_delivery.json`. Visible s87 and public
clock/renderer remain unchanged;no FPS/GPU timestamp or adoption claim.

## Reproduction procedure

Fresh unpaused game/replay session;other diagnostic toggles OFF. Main RainFX →
Weather inputs and physical units (P0): **Enable s247 paired completion profile**
→ **Run s247 paired completion profile once**. Expected observed8/8,
568 physical draws,86 resources. No weather/driving/FPS comparison needed.
Automatic logs stay within the existing100-line decoder bound. Collect with
`docs/tools/collect_s247_observation.py`. The actual observation is recorded above.
