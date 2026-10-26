# s238 — persistent coherent CPU intake and execution-budget review (2026-10-22)

## Delivered

`rain_live_capture.lua` now collects coherent engine/visor inputs across
consecutive frames after one verified bootstrap. Versioned s238 input, packet
and composer modules preserve existing physical formulas and avoid per-frame
asset hashing, material/geometry digest rebuilding and duplicate header hashing.
A default-OFF **s238 continuous input capture** panel is installed in the main
app to qualify120 observations and record actual CPU cost.

Local capture/parity, time-queue/admission and panel/log tests pass.
**Actual CSP continuous CPU-input observation passes. Capture cost still needs
reduction and a production performance budget is not qualified.** This stage does not
connect a solver, allocate GPU resources or change displayed s87 water/optics.
The previous s236 actual private-water execution remains preserved.

## Bootstrap and hot capture

1. Run the existing s152 verified20-file bootstrap once. A qualifying unpaused
   dt≤50ms frame anchors the stream after verification; startup pause/long dt
   waits for that anchor instead of truncating its duration. Coverage is only
   claimed for the subsequent accepted input prefix. Pending file verification
   has a10s host timeout; waiting for an unpaused anchor does not consume time.
2. Retain the verified file manifest, material/geometry identity, mesh/surface
   binding, head count and exact configured/applied scales. Each subsequent
   observation checks the binding and physical-setting values before/after
   sampling. Changes require reset; display-only gains do not enter this check.
3. Reuse one weather observer and birth-distribution sampler. Copy the current
   car/weather/pose snapshot coherently, preserving existing SI units, physical
   diameter calibration, force switches and evaporation law.
4. Compose52 physical rows and hash that final header once, plus its pose.
   The redundant50-row hash and repeated material/geometry digests are removed.
   Returned snapshots own their mutable tables; changing one cannot affect a
   later observation. No growing input history is retained in the controller.

The module relies on the retained verified binding while it is active. It is
not a filesystem change watcher or a general GPU geometry/resource lease.
Material, mode and geometry changes need explicit reset/renewed verification.

## Time, pause and replay epochs

The installed SDK declares `StateSim.dt` as zero when paused and already
affected by replay speed. Intake therefore uses that dt directly, without
another playback-rate multiplication. The SDK fields are checked locally and
their exact SDK hash is bound by the deployment audit.

- Positive dt up to250ms is retained in full for the s237 splitter. Versioned
  source packing permits long or sub-tick source headers; the GPU still only
  receives bounded derived slices through the separate admission path.
- New zero-dt frames emit typed zero-time pause markers, compatible with the
  queue's no-GPU pause path. Repeated paused callbacks do not emit another frame.
  Positive duplicate callbacks do no resampling/hashing. Conflicting dt or a
  pause flag with positive dt refuses rather than guessing elapsed time.
- Within one explicit epoch require consecutive source frames. Gaps, rewind,
  focused-car changes, replay/live mode changes and material/binding changes
  stop intake with a reset-required/fault reason. Epoch reset does not silently
  clear the existing water/debt; a future solver owner must handle that policy.
- In replay, require a valid cursor/timebase. Backward cursor movement, paused
  cursor movement or a changed recorded-frame duration refuses. Compare
  cumulative cursor advance with cumulative sim dt within two recorded-frame
  quanta plus1µs; a larger forward seek or stall refuses. Playback-rate changes
  are allowed because dt already incorporates them.

The replay check cannot distinguish every tiny forward seek from normal cursor
quantization. There is no invented exact replay subframe clock. Its actual
behavior still needs qualification on the user's CSP/replay path.

## Local verification

Twenty-five cases use the real old bootstrap, new sampler/controller/composer
and existing weather/birth models: normal and dynamically changing rain/air/
humidity/inertia, exact s152 context parity, display gains,200ms frames,
sub-tick frames, replay playback, pause/resume, duplicates, paused bootstrap,
gaps/rewind, mode/focus/scale/material/mesh changes, bad weather input, torn
capture, pause conflict, absent clock fields and replay seek/stall cases.

On the supported normal fixture every physical row and context/pose/material/
geometry identity agrees with the qualified s152 snapshot. A120-frame run
performs only the initial20 file checks; all subsequent frames avoid file I/O.
The sampler sees fresh dynamic values rather than reusing bootstrap weather.
Mutating a returned context does not contaminate later snapshots.

A separate120-frame CPU integration feeds real emitted headers into the s237
FIFO and v3 admission, including200ms splitting and a zero-time pause. Source
identity, quarter progress and raw/debt/remainder closure pass without another
file check. This is clock/admission integration, not a new GPU simulation.

The shipped panel runs four mocked-SDK cases (normal,pause,material reset,
cancellation), performs zero ExtraCanvas calls and emits the46-line report.
The independent decoder accepts normal/pause reports and rejects five corrupted
time/identity/scope/file-count cases. Five lazy-host/native/offscreen guards and
Lua syntax pass. No transport/shader/numerical budget is changed.

During development the extracted composer was missing its seed head-count
binding; it was restored before final tests. The paused-bootstrap success case
was also corrected in the harness dispatch. Earlier diagnostics are preserved.
Host benchmark time includes Python SHA bridging and is explicitly not CSP CPU
timing, GPU timing or evidence of FPS improvement.

## Actual CSP observation

The installed read-only panel completed 120/120 inputs and 120 positive-time
samples on frames3153–3272 after seed frame3152, in one epoch. All46 automatic
log lines decode successfully. There are no frame gaps, duplicates or paused
observations in this run. The120 raw durations sum to2.2372770998626947s.
This run does not exercise the pause, seek or reset paths in the actual engine.

The20 bootstrap file checks and one asset proof are recorded; no per-frame
file checks are added. Both emitted full headers and pose identities validate;
geometry/material identities remain fixed, with configured/applied scales1.
The controller emits all120 durations but only the first/last complete headers,
so the log does not independently reconstruct every intermediate physical row.

| Capture-only CPU statistic | Actual time |
| --- | ---: |
| Mean | 0.7603675ms |
| 95th percentile | 2.0361ms |
| Maximum | 3.5412ms |

These timings cover emitted positive-frame sampling, composition and hashing.
They exclude bootstrap, UI, the existing rain solver and GPU work. The short
120-frame sample does not separate JIT/GC effects or establish a warm steady
state. There is no paired FPS measurement or measured improvement against the
previous capture path. The capture cost is material: correctness passes, while
production performance remains open. Profile/reduce repeated physical-header
packing and identity work before treating intake as an affordable live path;
the current measurement does not isolate the dominant contributor.

No GPU resource is allocated, no solver is connected and no public water clock
advances. Actual continuous solving and displayed physics remain unchanged.
Pre-observation documentation is retained in `pending_sources/`; the prior
delivery manifest is retained in `pending_delivery.json` beside the actual logs.

## Why a draw-budget increase is insufficient

The existing proof owner allows one SDK attempt per callback, eight logical
passes per pump, four sequential quarter receipts and no next-quarter admission
within the same pump. Even if all shader work fit a callback and the draw limit
were raised, those four sequential receipt/pump boundaries still prevent one
new source interval per callback. A larger queue only delays overflow.

The next production candidate needs a whole bounded interval/adaptive-substep
path with fewer proof/readback boundaries and a separately measured warm
execution budget. Larger step sizes can change physical results, so comparison
must use the existing game accuracy/closure policy rather than assuming that
removing three diagnostic quarters is harmless. Existing adaptive transport and
pooling results remain candidates. No high draw limit is enabled in the game.

CPU intake is kept separate so its cost and clock behavior can be measured
without the slow proof solver consuming the queue. Continuous live
solving remains unqualified until the execution path can drain that input.

## Actual CPU-input procedure

Start a fresh unpaused game/replay session for a clean app-log quota. In
Real Visor Overlay → RainFX → Weather inputs and physical units (P0), enable
**s238 continuous input capture**, then press **Run s238 continuous input capture
once**. Other diagnostic switches can remain OFF. Expect `observed`,
`inputs120/120`, `samples120`, `file checks20` during normal unpaused playback.
If reset/fault is shown, report its message instead.

No driving,weather,FPS comparison or manual Log action is needed. The automatic
46-line report contains first/last full-header and pose identities, all120 raw
frame durations, continuity/file-check counts and capture-only CPU mean/p95/max.
Measured CPU time excludes bootstrap, UI, the existing rain solver and GPU work.
The probe holds at most120 duration/frame records and two context snapshots.

## Next

Reduce and profile the measured CPU capture cost, including whether full-header
packing/hashing can be cached or deferred without weakening input ownership.
Build/compare the bounded whole-interval execution candidate and measure actual
warm throughput/tail cost. Then integrate
the continuous source epoch with the bounded queue, conserved incident/head
sources, protected renderer leases and common optics. Reset/replay reconciliation,
long-run memory and visual adoption remain open. No Git commit/push is performed.

Evidence: `diagnostics/2026-10-22/s238/capture_checks.json`, `host_checks.json`,
`installation.json`, `runtime_audit.json`, `actual_capture.log`,
`actual_observation.json` and `delivery.json`.
