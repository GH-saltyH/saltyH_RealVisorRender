# s268 — actual-context physical producer binding

Date: 2026-10-24. Implemented input/producer component. The observed s266 game
execution and s267 joint source/transport component are preserved. **This stage
does not install a new live solver or connect producer outputs to transport.**

## Implemented

`s268_cohort.lua` projects an already admitted 50-row engine context plus two
physical-unit rows into one immutable producer cohort. It retains the captured
engine frame/key/slice as provenance and leaves original telemetry intact.
Legacy birth/head code needs a strictly increasing frame number; private input
serials provide that number, including two slices of the same engine frame.
They do not represent extra engine frames or advance public time. Birth random
tick and matching SI/request stamps follow the private interval serial.

Actual rain supply, DSD mixture, air, inertia, material, contact angles, viscosity,
world pose and physical calibration come from the captured rows. Display gain
does not enter this mapping. Contact/impact/motion laws are inherited unchanged.
Calibration must first be aligned by the existing admission path; the producer
does not repair a changed physical scale or infer mass from displayed radius.

`s268_producer.lua` binds that cohort to existing s146 physical birth and s148
SI head producers. It supplies matching birth/SI/head/field headers, current pose,
physical merge calibration and the previously owned pose/state/meta. Wet feedback
comes from physical old film/micro volume divided by current physical area in
mm², converted to µm. Track wetness is not substituted for visor water.

Pool spawning and merge commands are explicitly OFF in this binding. Their
proper producers remain an integration task; no synthesized merge pairs or
unfunded pool returns are fabricated. Wet-path steering and common optics are
not added here. Existing physical motion, evaporation and trail descriptors run.

## Actual bake adaptation

The verified authored boundary is 4096×1024 DXT5/BC3; tangent geometry is
2048×512 RGBA32F. Legacy head context requires matching geometry/boundary shapes.
A static pass creates a matching binary-alpha boundary, taking the minimum of
each 2×2 authored-alpha block and intersecting geometry support. This conservatively
excludes edge cells rather than opening holes. It is a spatial approximation to
review with final head/edge visuals, not a change to physical droplet diameter.

The BC3 source is declared as such in the input descriptor. Native numerical tests
upload its decoded normalized alpha in RGBA32F; they do not qualify CSP BC3 resource
ownership or compressed-image allocation. All existing images/bakes are unchanged.

## CSP binding limit and immutable context

The old recipes bind as many as 27 names per head pass. Even native compiler
reflection reports 17 active resources in an old merge pass. A live CSP caller
cannot safely assume all those bindings fit its 16-texture interface.

The new route evaluates frame-global numerical/header validation once on GPU.
Later head stages read that immutable result. Texture shape checks are replaced
only under a mandatory typed lease contract for **every import and owned target**;
the owner must validate actual allocations/images, including resources written
later in the prefix. Missing, invalid or stale leases refuse binding. This moves
global/shape validation; it does not remove per-slot physical or packet checks.

Fixed shader bodies are strictly compiled and reflected with FXC. Only inputs
the compiler proves inactive are removed from API bindings; their declarations
remain in shader text so unreachable helper functions still compile. A generated
Lua manifest records body SHA256 and active names. Runtime specialization checks
those hashes, runs once, and refuses more than 16 bindings. Every producer pass
now fits, with a maximum of **16**. This is a binding/numerical result, not an
actual CSP execution or performance measurement.

The factory builds its plan once. `bind(cohort, leases)` returns job-owned values;
it does not stamp drops on CPU, read heads back for simulation or rebuild the
producer graph per frame. Headers/pose/wet feedback refresh per interval; boundary
and empty command/pool resources initialize at serial 1. Warmup/reset semantics
belong to the retained owner, not to this component's private serial alone.

## Local evidence

- Actual recorded P0 input, frame 745, from the sealed s152 CPU capture; actual
  current-bake files and 4096-slot shapes. Header tokens/clocks are converted to
  the admitted/private representation for this native component test. This is
  **recorded input replay, not a current live game callback**.
- One explicitly controlled retained head (1 mm equivalent diameter,
  0.5235987902 mm³) exercises motion and transfer under those recorded conditions.
  The short sampled interval has zero newly incident packets. It therefore does
  not validate nonzero rain arrival rate or a fully populated 4096-head workload.
- 38 native producer/prelude draws plus 15 unchanged-head reference draws. Frame,
  birth and head receipts accept; retained head movement is nonzero. Final head
  stock is about 0.5235980749 mm³. State/meta/physical heads/decoded candidates
  match the unchanged reference with maximum observed error **0**. Numerical
  acceptance still uses inherited FP32 tolerances, not a universal bit gate.
- Same-engine-frame two-slice mapping, display-gain isolation, missing/invalid
  leases and six malformed cohort cases pass. Invalid token, engine frame,
  geometry, units, nonfinite row or source clock is refused.
- Strict warning-free compilation and full active-binding reflection. The merge
  calibration shader uses a single initialized result on all paths.

Evidence: `diagnostics/2026-10-24/s268/`; commands:
`docs/tools/check_s268_producer.py` and `docs/tools/finalize_s268.py`.

## Remaining runtime work

Bind these producer outputs to s267's source/raw cohort and retained source-time
owner; select previous/current pose with the joint inventory as well. Allocate
and certify the complete working set, retain immutable inputs through ordered
audit retirement, and copy status only after all joint selectors are submitted.
The early producer/frame receipts alone must not publish stocks or free leases.

Then perform one combined actual continuous gate before optical consumption and
the full-pipeline frame-time/visual check. No new standalone probe or user test
is requested by s268. FPS, actual CSP binding behavior, continuous source time,
live joint ownership and 2048/4096-active-head cost remain unqualified.
