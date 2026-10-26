# s151 — engine observation and common header upload

Status: ACTIVE — local checks and actual CSP header observation passed
Date: 2026-10-18

## What changed

A new default-off independent app captures the focused car's engine inputs once,
copies them into plain Lua values, derives the existing P0/P2 weather/supply
model, and stamps all diagnostic physical headers from that same observation.
Shader compilation retries retain that observation; newer weather/car values
cannot silently replace it. The existing RealVisor app, shaders and settings are
unchanged. The new app does not invoke the s150 solver or publish water stocks.

The installed SDK still exposes no declared general native fence/GetData/buffer
completion API among the audited symbols. The probe deliberately leaves strict
completion and solver admission false. An asynchronous `accessData()` result is
an observation of the captured texture, not permission to retire arbitrary GPU
work or promote the persistent solver.

## Authentic and reference inputs

`s151_engine_inputs` reads `ac.getSim()` once and `ac.getCar(sim.focusedCar)` once.
It copies weather conditions, world wind/velocity, local vehicle G and basis,
position and dt without yielding. Matching frame checks reject a frame changing
during the read. This is a render-frame observation; it is not proof of hidden
physics-thread atomicity.

The unchanged `rain_environment.lua` and `rain_birth_model.lua` provide weather
phase filtering, humidity/pressure/temperature air density, relative wind,
world-space inertia and DSD/supply. The gravity-exclusion convention is explicitly
the convention established by the supplied P0 experiment, not a new guess.
Snow/sleet/hail mixtures reduce liquid supply. Missing/unverified, nonfinite or
out-of-range critical inputs are refused rather than silently used as defaults.
Paused or missing-car observations wait. dt >0.05s is refused without truncation.

The default independent probe uses **car-reference pose**, not the actual visor
node's transform. Its material/area/force constants are named probe references,
not a capture of the user's live material settings. A future caller can provide a
frame-matched `visor_model_world_v1` pose callback; this probe has no such main-app
hook. Both pose scopes still have solver admission false. No decorative display
diameter gain enters the physical/header data.

## Fifty immutable rows

| Rows (zero based) | Contents |
| --- | --- |
| 0–17 | P2 birth context: common token, clock, supply, air/material and pose |
| 18–27 | SI motion parameters and matched source tick |
| 28–33 | head frame/time/geometry header |
| 34–38 | current field-force snapshot |
| 39–41 | remaining-time request |
| 42–49 | raw engine/weather/kinematic and provenance diagnostics |

Every group receives the same token and represented duration. Raw engine dt is
rounded to integer 1/1048576s ticks for these diagnostic headers. The unrepresented
seconds are recorded alongside raw dt. No scheduling/clock state is advanced;
this is not an elapsed-time/backlog policy and does not silently approve dropping
fractional time in a future live solver.

A pure nearest-even binary32 conversion freezes the expected values. SHA256 of
the canonical header payload identifies exactly those rows, including engine
frame diagnostics. The packet explicitly carries diagnostic scope and false
admission/completion/publication flags. A checksum alone does not authenticate
arbitrary GPU uploads or establish mesh/pose provenance.

The app uploads ordinary vec4 uniforms into a 1×50 RGBA32F texture and reads them
through one named texture into a 64×4 R32F capture atlas. There are two shader
submissions, no direct constant-buffer writes and at most one bound texture.
Two small canvases (1824 nominal texel bytes) stay retained for the app/session
lifetime; no submitted GPU canvas is disposed or reused. CPU readback objects are
disposed after decoding. Unknown submission stops retries. Pending shader retries
are bounded at 256 per pass. No timed or frame-count completion guess is added.

## Local verification

- 15 input cases: normal, zero rain, solid phase, mixed phase, duplicate frame,
  force selection, pause/long dt, invalid/missing weather, frame tear, reflected
  basis and unverified gravity.
- 8 controller cases: normal/pending/pause, unknown submission, readback error,
  mismatch, duplicate callback and actual WARP shader execution.
- 15 binary32 codec controls plus three nonfinite/overflow refusals.
- 8 log-decoder cases, including truncation, duplicate rows, bad identity and
  multiple captures. Display gain changes leave the packet unchanged.
- 6 WARP draws, 2 strict synthetic shader bodies (ordinary, solid and mixed input
  packets); 200 returned values and 56 zero padding values checked per capture.

These engine APIs are mocked in local tests. The separate actual CSP observation
below verifies engine sampling/uniform delivery for one captured frame. The SDK,
local test hashes and actual evidence are in `docs/diagnostics/2026-10-18/s151/`.

## Actual CSP result

The user ran the installed app in a fresh session and reported `observed` /
`matched`. The collected 102 log lines independently confirm all **50 rows / 200
binary32 values are bit-identical**, including the common frame/token/time and
canonical payload checksum. Engine frame: **866**, focused car: **0**.

Raw dt was 0.015541999600827694s; the diagnostic represented duration was
0.015542030334472656s, leaving -3.073364496231079e-08s unrepresented. This
rounding record does not advance a public clock or approve a future scheduling
policy. Pose scope remained `car_reference_only`; material source remained
`probe_reference_v1`. This result verifies one actual engine snapshot and GPU
header path, with strict completion, solver admission and live physics integration
still false.

`actual_observation.json` preserves the first successful parse. Writing its
filtered companion log initially failed because the CSP prefix contains a Unicode
symbol unsupported by the host's default encoding. The collector now writes UTF-8
explicitly. The same 102 lines were recovered from the continuing game log and
their full parsed result was required to equal the original observation;
`capture_recovery.json` records both source hashes and the repair provenance.

## One game observation

Use a fresh, unpaused game session to avoid the known per-session logging limit.
Open **RealVisor s151 engine input probe**, enable it, then press
**Capture engine inputs once**. Weather/driving comparisons are unnecessary.
`State: observed` is set only after all 102 log lines are emitted; the UI also
shows `Classification: matched` or `mismatch`. Errors remain visible. The app
stays one-shot; do not repeatedly reload a used probe to assume its GPU resources
have completed. A new session starts the next observation.

The collector validates all 50 expected/observed rows, the payload checksum,
common frame/token/time and the reported classification. Signed zero differences
are reported through `bitIdentical`; numerical matching intentionally treats
signed zeros as equal. It records actual observation only from the new app's log
and verified installation receipt. It never enables a general completion flag.

Next: connect the actual visor-pose/material/
geometry authority, and substantiate an ordered resource/completion strategy
before the recurrent solver can use these inputs. Curved/feedback accuracy,
fusion, shared optics and measured game cost remain separate adoption gates.
