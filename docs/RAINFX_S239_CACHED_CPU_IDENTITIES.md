# s239 — bounded CPU row identities and paired attribution (2026-10-22)

## Delivered

The s238 actual input capture passed, but measured mean0.7603675ms,
p95 2.0361ms and max3.5412ms do not establish an affordable production path.
s239 versions the packet/composer/controller to remove avoidable CPU work and
installs a default-OFF paired composition measurement in the main app.
**Actual600-pair correctness passes. Mean/p95 composition cost improves in this
run; the larger single maximum and unmeasured standalone/full-path cost keep
the final optimization/adoption gate open.**

The displayed s87 water and optics, existing solver, physical formulas,
weather/DSD distribution and all previous diagnostic modules remain unchanged.
No new GPU allocation, public-clock advance or continuous solver is introduced.

## Changed work

- Replace each eight-iteration nibble table/string assembly with LuaJIT
  `bit.tohex`. Preserve the existing FP32 round-to-even conversion, finite
  checks, overflow refusal, subnormals and signed zero. The installed SDK
  documents `bit.tohex`; no FFI or native memory view is introduced.
- Stop recursively copying the entire observation and configuration at the
  packet-builder entrance. It only reads them, copies every emitted vector/row
  and returns owned values. Returned settings/geometry metadata still have
  separate copies; input and output mutation cannot contaminate future frames.
- Keep at most52 private row witnesses and52 immutable encoded strings in each
  composer owner. Compare all four values, including the sign of zero, before
  reusing a string. Cache no caller-owned row/table reference. A changed row is
  encoded again; this is not a hash cache or a tolerance-based physical match.
- Reuse the encoded header pose rows14–17 for the pose fingerprint, avoiding a
  second conversion of the same16 numbers. Both complete canonical strings and
  both SHA256 calls remain byte-identical to s238 for each accepted input.
- Add optional build/encode/hash/tail timers. Normal controller use does not
  enable those clock calls. Status returns copies of the bounded counters.

In the unchanged-geometry/weather/pose120-frame fixture, the old path performs
26,880 float-to-hex calls. The candidate performs2,112:52 initial rows and four
changed rows per subsequent frame, with5,712 reused rows. Both paths still issue
120 header hashes and120 pose hashes. This count depends on how many rows
actually change; it is not a claimed real-world CPU speedup.

## Verification

The new controller passes the existing25 dynamic input, physical parity,
pause/replay/duplicate/long-frame/setting/owner controls. A120-frame integration
through the unchanged time FIFO and physical admission includes a200ms frame
and a zero-time pause, and ends with zero retained debt and20 bootstrap checks.

An independent IEEE decoder checks4,096 finite float words, eight rounding/
underflow values and five invalid/overflow refusals. There are487 complete
canonical/header/pose identity comparisons against the old composer across
dynamic weather, forces, translating/rotating pose, scale, long/sub-tick dt,
material/calibration changes and caller mutation. Positive and negative zero
produce their distinct original identities. Attributed time components close
under a deterministic clock; caller mutation of status cannot alter the owner.

Five real-controller panel cases cover normal600-frame completion, changed
material, pause during measurement, cancellation and an injected identity
mismatch. The report decoder rejects eight count/time/header/scope/work
corruptions. Five lazy/native/offscreen host guards, Lua syntax and linked-file
deployment checks pass. No shader/numerical simulation gate needs rerunning:
the physical row bytes and admission inputs are identical.

Local host timing in `capture_checks.json` uses LuaJIT `os.clock` with SHA work
disabled only during the timing fixture. That clock is coarsely quantized on
this host; its per-frame tails/phase values are not useful target estimates.
It is neither actual CSP CPU cost nor an FPS comparison and has no timing gate.
Correctness comparisons use real SHA256.

## Actual CSP result

All39 log lines decode and match the installed source audit. Frames981–1580
complete600/600 inputs after seed980, with no duplicates or paused frames,
one asset proof and20 bootstrap file checks. The first120 inputs are warmup;
frames1101–1580 supply480 measured pairs. All600 pairs have identical canonical
headers, context/pose and material/geometry identities. The two emitted full
measured snapshots independently validate their header/pose hashes and fixed
geometry/material/configured/applied scales. Raw input time is10.194846887141466s.

| Measured CPU scope | Mean (ms) | P95 (ms) | Maximum (ms) |
| --- | ---: | ---: | ---: |
| Baseline composer | 0.360915833 | 0.8961 | 1.4803 |
| Candidate composer, including attribution clocks | 0.260772708 | 0.4709 | 2.5821 |
| Common capture, including pair/wrapper overhead | 0.070123125 | 0.1523 | 0.4871 |
| Candidate row construction | 0.0778345833 | 0.2342 | 2.2795 |
| Candidate encoding/canonical assembly | 0.117706875 | 0.2248 | 0.6173 |
| Candidate SHA256 | 0.049368125 | 0.0881 | 0.1883 |
| Candidate metadata tail | 0.0151179167 | 0.0540 | 0.2285 |

The mean composition saving is0.100143125ms (27.75%); P95 decreases47.45%.
The candidate maximum increases1.1018ms. This is a short alternating-order
paired workload, not the repeated representative A/B or full frame-time gate
in the game acceptance policy. It supports continuing with the candidate while
retaining the tail warning; it does not establish final optimization acceptance.
Do not compare it directly with the earlier s238 whole-capture mean0.760ms as
if the measured scopes and workload were identical, or claim FPS improvement.

Encoding remains the largest attributed mean component, about45% of candidate
composer time. The largest row-build sample is2.2795ms, but the report retains
only aggregates, not aligned phase samples or GC/JIT events. It cannot prove
whether that event caused the candidate maximum, diagnose GC/JIT as its cause,
or establish periodic stalls. Sum phase means only; their P95/maxima need not
occur in the same frame. The standalone candidate capture tail remains open.

Across all600 frames the bounded cache encodes10,622 rows and reuses20,578
(65.96%), with exactly52 slots and600 header plus600 pose hashes. This implies
42,488 float encodings versus134,400 in the old path for these600 inputs, a
68.39% reduction. The dynamic workload therefore reuses fewer rows than the
static fixture, as expected. It allocates no GPU resources, connects no solver
and advances no public physics clock.

Pre-observation documentation is preserved under `pending_sources/`; the prior
delivery is preserved as `pending_delivery.json`. Actual logs and decoded
results are in `actual_capture.log` and `actual_observation.json`.

## Actual paired cost procedure

Start an unpaused session with a fresh app-log allowance. In Real Visor Overlay
→ RainFX → Weather inputs and physical units (P0), enable **s239 paired capture
cost**, then press **Run s239 paired capture cost once**. Keep other diagnostic
panels OFF. Stay unpaused and avoid replay seeks or physical-setting changes.
No particular weather, driving speed or manual FPS measurement is needed.

One coherent engine sample feeds both composers in the same callback. Their
canonical header, context/pose and material/geometry identities must match.
Call order alternates to reduce first/second-call bias. The first120 frames are
warmup, followed by480 measured frames; all600 pairs are checked. `observed`
means all39 automatic log lines have been emitted. Report `inputs600/600`,
`measured480/480` and `matches600`, or any fault/reset message.

Measurements report mean/p95/max for both complete composers and the candidate
build/encode/hash/tail phases. Candidate timing includes the additional clock
calls used for attribution. The remaining common-capture timer includes
sampling, binding checks, pair comparison/wrapper overhead and bookkeeping;
it is not an isolated sampler measurement. It must not be added to composer
p95 values as if their maxima occurred in the same frame. The paired workload
can itself affect JIT/GC/cache behavior. This is not a standalone candidate
capture cost, a solver throughput measurement or a before/after FPS result.

The panel retains two full measured snapshots and seven fixed480-value timing
arrays. It performs20 initial file checks, zero per-frame checks and zero GPU
allocations. Pause/seek/setting changes stop this cost run; the underlying
controller's pause support is preserved and tested separately. No source water
or physics time is consumed by this diagnostic.

## Next

Keep the candidate's measured mean/P95 improvement and tail warning. Encoding
is the remaining mean CPU contributor; avoid multiplying small CPU-only probes
before the continuous execution bottleneck is addressed. Implement/compare the
bounded whole-interval/adaptive execution candidate;
raising the old draw cap does not remove its four quarter-receipt boundaries.
Continuous queue/solver integration, conserved incident/head sources, renderer
leases/common optics and long-run adoption checks remain open. The user owns
Git stamps; this stage does not commit or push.

Evidence: `diagnostics/2026-10-22/s239/capture_checks.json`, `host_checks.json`,
`runtime_audit.json`, `actual_capture.log`, `actual_observation.json` and
`delivery.json`. Prior actual s238 evidence is preserved.
