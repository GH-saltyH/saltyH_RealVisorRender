# s280: fixed-cadence input integration foundation

## Delivered scope

`rain_fixed_cadence.lua` is a product module with no CSP/UI/GPU dependency.
It integrates explicitly declared rate channels into bounded physical work tickets,
independently of render FPS. It is **not yet wired to actual engine capture,
solver headers, GPU publication or optics**. No new app/checkbox or user test.
The existing main application is unchanged.

Default cadence is32Hz: one interval is exactly32768 of the existing1048576
clock ticks. The previous30Hz target was provisional. At30Hz, rounded solver
periods34953/1048576 cross the old1/30 boundary and select16 rather than8 transport
substeps.32Hz uses8 consistently and fits the established31.25ms interval bound.
Logical emission boundaries use physical seconds; integer model-clock rounding
is accounted separately, avoiding a one-render-frame delay near30Hz boundaries.

For scale only,94 calls x60Hz versus110 x32Hz gives5640 versus3520 submissions/s
before further product changes. This is a topology estimate, not measured CSP
CPU/GPU/FPS improvement or a claim that the complete runtime is now realtime.

## Input contract

Construct with epoch, rate-channel declarations (key, rateUnit, integralUnit,
nonnegative where appropriate), optional frequency/capacity/debt cap. Current
bounds:21-120Hz, at most16 pending steps and at most0.5s debt. Default32Hz.

Offer one contiguous sample per source frame with rawDt, epoch, geometryKey,
materialKey, calibrationKey, declared finite rates, and affine uniform-scale
orthogonal poseStart/poseEnd. Zero-time pause repetitions do not advance the clock.
Unknown channels (including accidental display gain), identity changes, malformed
poses, invalid signed rates and frame gaps refuse before input admission.

Rates must already represent valid quantities. A supplied water rate inmm3/s
integrates tomm3; acceleration inm/s2 integrates tom/s. This does not calculate
real visor incident water from weather or spatial normals. Do not average all52
old header rows: nonlinear incident flux, DSD/normal interactions and aerodynamic
force need a typed adapter, possibly additional derived integral channels.
Unit strings are declarations, not an automatic dimensional-analysis engine.

Compensated sums retain time and integrals. Long frames split over fixed steps
without discarding the remainder. Pose endpoint pairs and fractional locations
are retained, not matrix-averaged. A later adapter must resolve rigid poses.
A partial final step can close with explicit sub-microsecond model-clock carry;
a smaller-than-one-tick pending input stays reported instead of being dropped.

## Work and ownership

- `offer(sample)`: validate and integrate atomically, or return backpressure with
  the sample unadmitted. The caller must retain/retry that sample; this module
  alone does not solve overload policy.
- `reserve()`: own-copy one work ticket; a concurrent reservation is refused.
- `submitted(ticket)`: require an unmodified ordered reservation. This advances
  the submission cursor only, not accepted physical time.
- `acknowledge(ticket, accepted)`: ordered exact receipt; only acceptance advances
  physical time and integral ownership. Refusal freezes new work with debt retained.
- `close()`: seal a representable final partial step. A full queue may require
  retiring work before close retries. Status exposes accepted/queued/partial input
  integrals and physical/model-clock decomposition.

The queue holds physical steps rather than one context per render frame. It does
not grow to pass a test. At32Hz the existing ten-render-frame callback latency
would occupy fewer work slots at60FPS, but actual latency/throughput is untested.

## Focused verification

One local LuaJIT checker covers11 result groups:30/60/144FPS rate/impulse closure,
32Hz exact periods and actual transport-plan selection,250ms long frame, bounded
backpressure/retry, rigid endpoint and ticket isolation, six invalid input forms,
pause, ordered refused receipts and subtick retention. Declared linear input
closure is checked; this is not new GPU birth/transport/visual qualification.

Five local checker invocations were used: two successful, three failed while
correcting one scheduling design issue and two fixture expectations/API calls.
No GPU probe, SDK matrix, repeated shader compilation or user game run was used.
Details and measured work interval are in the development ledger.

## Efficient next step

Implement the actual engine-to-ticket adapter and fixed-cadence owner, then
connect committed state to existing optics. The next requested game evaluation
must yield useful product output or address an essential safety blocker.
Keep nonlinear flux integration and rigid-pose reconstruction explicit; do not
claim this generic rate accumulator already integrates real RainFX input.

Track before/after effort, approach count, local/user runs and benefit using
`development/work_ledger.json` and `RAINFX_DEVELOPMENT_EFFICIENCY.md`. Current
estimates are uncertain active-work ranges and must be revised after each stage.
