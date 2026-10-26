# s235 — main-app two-input private intervals (2026-10-22)

## Delivered

The main app now has a default-OFF **s235 two-input water intervals** diagnostic.
It uses the unchanged s234 owner/admission/graph and s231 executor/CSP adapter.
After the first four quarters finish and their receipts validate, it creates a
second s152 CPU capture, verifies assets and samples the current visor pose,
runtime material and engine inputs. That fresh sample is admitted into the same
GPU slot. Controlled20µm water is seeded only on the very first quarter.

The real physical graph already passed s234 full-grid local WARP integration.
This stage changes host/capture/logging/deployment only; no transport shader,
physical coefficient or numerical acceptance budget changes. Installed helper
hashes and main/docs symlinks match. **Actual CSP two-input observation remains
pending.** The displayed rain/optics path stays on s87; no FPS claim.

## Host behavior

1. Enable and Run are one-shot for the app/session. Disabled UI loading allocates
   no GPU resource and starts no input capture.
2. The first s152 capture verifies the existing model/assets and collects a
   coherent current context. Build the fixed owned graph and bind only verified
   file inputs through the unchanged s232 file adapter.
3. Run four private quarters. Each scene-ready callback attempts at most one SDK
   draw. A validated receipt is required before the next quarter is admitted.
4. On `awaiting_input`, create a new CPU capture. Its result must occur in a
   later callback and have a source frame greater than the first. Asset identity
   and physical scale/shape must remain compatible. The owner refreshes the
   input-dependent cache without allocating GPU resources.
5. Finish four more quarters, then stop. The panel reports `observed` only after
   eight accepted receipts; this interface never admits a third input.

Capture has a10s host-clock timeout. Capture/admission/submission/readback faults
and OFF cancellation stop new work while keeping managed resources retained.
OFF/ON cannot restart the run or allocate another pool. An uncertain private
output is never exported to the renderer.

These are **two sampled engine frames**, not ownership of all engine time
between them. The intervening wall/replay time is deliberately outside this
diagnostic. Quantized represented dt and signed raw-dt remainder are owned for
the two accepted samples only. Pause/long-frame subdivision, continuous backlog
and protected renderer readers still need separate integration.

## Bounded resources and automatic report

Expected at4096 head capacity:

- Two inputs, eight quarters,518 actual draw submissions and178 cache hits.
- One fixed pool:87 canvases,95,622,608 logical texture bytes (91.193MiB).
- Seven slot reuses; eight64-byte status reads and eight CPU-data releases.
- No per-quarter/per-input GPU allocations. GPU resources stay retained until
  the app/session ends. These totals exclude driver overhead and cached images.

The automatic report has **88 lines**:

- One summary and one time/scope record.
- Per input: one identity/raw-dt/tick-range record,13 captured-header blocks
  and13 admitted-header blocks. Both full208-float contexts are preserved.
- Eight receipts, each split into four exact16-byte hex records.

The independent collector reconstructs the original s152 context and pose hashes,
the derived s234 header hashes and all token/tick changes. It checks increasing
source frames, fixed geometry/calibration, signed remainder accumulation, quarter
time/debt, receipt identity and existing water-budget bounds. Only its successful
actual run can upgrade the stage's actual-CSP status.

## Local verification

The actual shipped panel runs with mocked SDK/capture services and saved s234
physical receipts. Two independent capture objects are constructed; capture two
cannot be constructed before the fourth status read. Both normal pending-shader
execution and eight readback CPU releases complete. The panel emits exactly88
lines, accepted by the independent parser, with518 draws/178 cache hits and no
GPU allocation after its initial87 canvases.

Four panel cases cover completion, CPU capture timeout, cancellation after the
first quarter and cancellation while the second capture is pending. A terminal
run does not restart. Seven malformed/truncated/duplicate/time/scope records are
rejected by the parser. Five main-host checks cover lazy load, callbacks,
offscreen/native capture exclusion and missing optional files; Lua syntax passes.
This host test reuses already verified physical receipts; it does not claim new
GPU physics execution or real engine capture. Existing s152 input-contract and
s234 physical evidence remain preserved.

The first parser-negative test attempted to replace a particular printed raw-dt
decimal;17-digit formatting used another spelling. The test now matches the
raw-dt field structurally, and all seven corruptions are confirmed to change
the report before testing refusal. Product code was unaffected by that harness
correction.

## Actual CSP procedure

Start a **fresh unpaused game session** to reset the CSP app log quota.
Open Real Visor Overlay → RainFX → Weather inputs and physical units (P0).
Enable **s235 two-input water intervals**, then press
**Run s235 two-input water intervals once**. Other diagnostic switches can stay
OFF. When State becomes `observed`, report inputs/completed/actual draws/cached
and retained debt; send the displayed error if it faults. Expected:
`inputs2/2; completed8/8; actual draws518; cached178; retained debt0`.
The signed remainder can be positive or negative and need not be zero.

No driving/weather/FPS comparison is required for this execution check. Inputs
are captured after the preceding interval completes, so the probe can take
several seconds while submitting its bounded per-callback work. All88 lines
are automatic; manual Log is optional. Avoid running earlier diagnostics in the
same session, which would consume resources and the finite log quota.

## Evidence and next implementation

Artifacts: `diagnostics/2026-10-22/s235/host_checks.json`, `installation.json`,
`runtime_audit.json` and `delivery.json`. The collector is
`tools/collect_s235_observation.py`. Actual observation is currently pending.
No Git commit or push is performed.

After actual two-input continuation is accepted, own complete elapsed engine
time, pause/long-frame subdivision and bounded pending intervals. Then integrate
conserved incident/head sources, renderer read leases and common head/film optics.
Continuous cost, warm memory, replay/reset and visual quality remain adoption
gates. Smear/local impact film remain optional later corrections.
