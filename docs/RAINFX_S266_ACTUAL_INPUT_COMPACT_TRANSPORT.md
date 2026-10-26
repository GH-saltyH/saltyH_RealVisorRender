# s266 — actual inputs connected to compact private film transport

Status: implemented and locally checked, **actual CSP run pending**. Parent:
[s265](RAINFX_S265_PRIVATE_TRANSACTIONAL_EXECUTION.md). Existing visual RainFX
remains s87. This default-OFF main-app path runs three seconds of admitted engine
inputs through the compact solver, with a controlled initial 20 µm film.

## Execution

The existing actual visor context capture verifies files, physical calibration,
weather/material inputs and world pose. Three read-only DDS images supply local
tangents and cells. s266 creates its own header, world metric, area, physics and
connected-run caches. Each input updates pose-dependent caches; first input builds
topology and initial stock. Display gain does not enter these physical inputs.

The inherited source sampler/FIFO and physical admission retain original elapsed
time. s264 force and donor-cell transport feed s265 transactional commits. GPU
submission can continue before previous CPU audits return; 32 immutable small
audit slots settle source tickets in order. Rejection retains the last accepted
stock, stops new submission and drains already submitted rejected suffixes.
Malformed receipts, lost ownership or timeout quarantine the path. Cancellation
does not settle outstanding time. Captured but unadmitted time is reported apart
from admitted FIFO debt. Queues and age limits have not been enlarged.

One accepted warmup is drained before live capture. Its clock and input serial
are reset; the first live input initializes new stock. Warmup contributes one
readback and draw costs but no engine source time. Allocation is spread over
callbacks (up to eight creations / 3 ms soft budget); live submission shares a
3 ms / 256-call soft budget. A single SDK call can exceed a soft deadline.
Graph construction, allocation, live owner cost, source age and callback latency
are reported separately. All preparation and execution have bounded timeouts.

## Resources and scope

- 50 retained private canvases, including 32 audit copies:
  109,678,064 descriptor bytes (104.597 MiB).
- Read-only file texture descriptors: 37,748,736 bytes (36 MiB).
- Combined static descriptors: 140.597 MiB; enforced below 160 MiB.
- This excludes the existing app, SDK/driver allocations, staging and CPU GC.
  It is not a whole-app memory limit. GPU resources stay until session ends.
- No new head spawning, rainfall source, impact, evaporation, pool return, trail
  rendering or optical output is connected. A pass does not establish final FPS
  or visual readiness. No public stock/time or renderer handle is exported.

## Local evidence

- Native D3D: 78 passes across three actual admitted headers. Header values,
  actual-grid world metric/material, physical initial inventory and evolving
  transactional receipts pass strict shader compilation and numerical checks.
- 13 controlled owner cases use the real context/admission/source-time queue:
  normal, 30 FPS, pause, long input, display gain, pending shader, synchronous
  callback, refused transaction, pressure, calibration reset, malformed audit,
  missing audit and cancellation. These exercise ownership and time accounting;
  their emulated receipts/timings are not native throughput measurements.
- Six real SDK-adapter panel fixtures, lazy main-app guards, actual menu dispatch
  and linked installation pass. Permanently pending images time out before any
  GPU canvas is allocated. The menu test covers the actual dispatcher call.
- Parent source hashes and mtimes are preserved except the documented main UI
  addition and documentation index/roadmap changes.

Evidence: `diagnostics/2026-10-24/s266/`. Run checks with
`docs/tools/check_s266_graph.py`, `check_s266_owner.py`, `check_s266_panel.py`;
seal with `finalize_s266.py`. The collector preserves a failed real run too.

## One actual integration gate

Fresh unpaused session; other diagnostics OFF. Main app → RainFX → Weather inputs
and physical units (P0) → **Enable s266 continuous film transport** →
**Start s266 continuous film transport**. Warmup then actual capture run
automatically. Terminal state should be `observed`, pending zero, equal positive
submitted/audited counts, 50 resources, zero debt and complete time closure.
Counts depend on input dt; no fixed input count is required. Log output is at
most seven lines. No weather matrix, FPS comparison or screenshots are needed.

Collect with `docs/tools/collect_s266_observation.py`. A stop is evaluated by its
retained source time and explicit cause. Do not grow queues to conceal a sustained
throughput deficit. If successful, proceed to physically conserved source/head
coupling and optical consumption; if unsuccessful, address the measured blocking
cost before expanding the feature set.
