# s152 — main-app visor, material and baked geometry context

Status: ACTIVE — local checks and actual main-app CPU capture passed
Date: 2026-10-19

## Purpose and current connection

s151 established actual CSP engine-to-header transmission for a car-reference
pose and probe constants. s152 adds a default-off **read-only capture inside the
main app**. It freezes the real `rainTargetMesh` world transform, current physical
settings, P0/P2 engine inputs and the verified file identities behind the baked
geometry. It does not run the new recurrent solver or change the current s87
physics, water stocks, shaders, material settings or public clock.

The UI is under RainFX → Weather inputs and physical units (P0):

1. Enable **Enable s152 physical context capture (read only)**.
2. In an unpaused session, press **Capture s152 physical context once**.
3. Wait for `State: captured_cpu`, then press **Log s152 physical context**.

The capture is one-shot until app reload. Use a fresh game session for logging:
the known per-session log cap survives an app reload. No separate probe app,
weather comparison, driving sequence or FPS measurement is needed for this gate.
`captured_cpu` explicitly does not mean GPU execution or completion.

## Frame, pose and ownership

Enabling loads the optional diagnostic helpers from `docs/prototypes/s152/` and
the preserved s151 sampler/codec. No helper is loaded while the checkbox has never
been enabled. One scene-ready callback is registered on first enable; disabled
or offscreen callbacks return immediately. The capture happens at
`render.onSceneReady`, after engine world-matrix preparation, using the same
`rainTargetMesh:getWorldTransformationRaw()` source as the existing physical path.
The UI does not read an early/stale matrix to manufacture pose provenance.

The matrix therefore includes the actual camera hierarchy, offset, G-force
motion, axis correction and physical model scale. Only a single GLASS_RAINFX mesh
is accepted. The sampler checks finite affine rows, positive uniform scale,
orthogonality and handedness. The mesh, surface object, model path, count and
physical settings must remain unchanged across the synchronous capture. Engine
frame checks reject a torn read. This remains one render-frame observation, not a
proof of physics-thread atomicity or a lease on engine-owned GPU geometry.

The existing main SI observer currently uses car 0. s152 refuses a different
focused car rather than combining its acceleration with this visor. Paused or
dt >0.05s snapshots are refused, without truncating time. Rain override and manual
DSD-seed override are also explicitly refused in this first context adapter.

## Geometry verification and units

A button request performs 20 asynchronous SHA256 checks: the selected KN5 and
19 existing physical asset/source files. The manifest reconciles the existing
birth and film metadata, model/mask stamps and exact baked area
0.04028860095237055m². No texture is rebuilt and no full atlas is read into Lua.
Duplicate callbacks cannot decrement the pending count twice. Disable cancels
the request generation; late callbacks cannot revive it.

The resulting scope is **verified files only**. It does not authenticate an
already-uploaded GPU resource or prevent subsequent external file changes. GPU
resource identity, leases and completion remain adoption gates.

The physical unit coefficient matches `rain_surface:unit()`:

`metersPerUnit = 0.001 / physicalDiameterUVPerMM / worldScale`

Area is the baked local area multiplied by worldScale². The nominal calibration
remains 6px/mm at 4096×1024; local mesh metrics can differ. Display diameter gain,
P2 display scale, film optical gain and other appearance settings are absent from
the physical settings hash, packet and pose key. The .46 and 1.5 display-gain
controls produce identical physical context identities.

## Header meanings

The 50 common s151 rows are repopulated from actual physical settings. Two
auxiliary rows retain unit/area and micro/downward-air configuration. The new
52-row checksum uses `RealVisor/s152/header_rows_v1`; it cannot be confused with
the old s151 payload. Pose, physical-settings and verified-file keys are recorded
separately. These hashes identify values; they do not grant solver authority.

Existing shader consumers determine the units and channels:

- P2: incident-air fraction in row4.w, tangent fraction in row6.w, minimum
  persistent diameter in row7.w, outward normal sign in row8.w.
- SI: current hysteresis spans, viscous coefficient, attached drag, force mask,
  local air fraction and optional wind exclusion.
- Film: minimum trail speed converted from mm/s to m/s, current estimated
  ventilation/evaporation law, friction coefficient and 0.05s maximum interval.
- Auxiliary units: current physical UV calibration, world scale² and world area;
  micro join µm and the configured downward-air option.

The finite-film prototype has no downward-air variant. That option is retained
for diagnosis without changing its model row. Birth supply keeps the existing P2
world-wind behavior; the SI include-wind option is separate. Dynamic wet-field
input and pool input are not acquired: wetOn/poolOn remain zero. Tokens, previous
frame and source tick are diagnostic references rather than current stock
identities. Admission, strict completion and public-clock flags stay false.

## Verification

- 27 LuaJIT context cases: 8 captures, 18 explicit refusals and cancellation;
  includes scale/rotation, force/wind choices, normal reversal, overrides,
  invalid/missing settings, owner/material/frame changes and hash failures.
- Actual main helper exercised in 9 UI/callback cases, including zero helper
  loads while disabled and offscreen/native capture exclusion.
- The real diagnostic panel emits exactly 54 lines once. Six decoder cases
  validate the normal log and reject truncation, duplicate data, corruption and
  scope escalation. Both the explicit host callback and the older-host fallback
  panel emit valid dumps in the LuaJIT harness.
- 20 WARP draws / 5 strict FXC bodies: 208 header values preserve all bits,
  padding remains zero, and the existing P2, SI and film context consumers read
  the intended fields in normal, scaled/rotated, wind-excluded and reversed-normal
  cases. This is local WARP evidence, not actual CSP execution of these headers.
- The main file differs only by this diagnostic UI/scene-ready hook. Existing
  settings and all prior stage sources remain unchanged.

One initial synthetic SI-reader shader triggered FXC X4000 on its multiple-return
form. The failing source is retained under the stage's `failures/`. An initialized
result with one final return passes `/WX /Ges`; no production shader was changed.

The installed SDK declarations for matrix rows, world transformation and async
file hashing were checked. Existing game symlinks already expose the main script,
docs and textures; all 20 game input hashes match the manifest. No installation,
app enablement or settings write was performed.

Evidence: `docs/diagnostics/2026-10-19/s152/`.

## User result and mixed-load compatibility

The first game attempt failed immediately on enable:
`s152_panel.lua:15: 'sceneReady' (a nil value)`.
This is consistent with the main app retaining the earlier invocation while
loading the newer diagnostic helper. No capture or GPU work occurred.

The helper now accepts both host versions. If the injected scene-ready seam is
absent, it registers the same SDK scene-ready callback directly, guarded by the
main app's enable/error/offscreen/native-capture state. It does not fall back to
UI-time matrix capture. The log explicitly identifies `callback=host` or
`callback=panel`. The original delivery/diff are retained under `failures/`.
OFF→ON clears the earlier constructor error and reloads this helper; a main-app
reload is needed only if the old helper remains cached. The subsequent actual
capture below confirms successful operation after the reported error.

## Actual main-app capture result

The user reported `captured_cpu`, zero pending assets and all 54 lines emitted.
The collector independently validates **frame745, car0, 52 rows / 208 binary32
values**, the complete payload checksum, pose checksum and common frame/token/dt.
The log records `callback=host`: this run used the main app's supplied scene-ready
callback. The compatibility fallback is locally tested but was not exercised in
this successful actual run.

The recorded geometry identity matches the 20 verified input files; the material
identity matches the complete physical settings recorded by the local fixture.
The material-only rows agree bit-for-bit with that configuration. Independent
analysis also checks the current air/force and evaporation relationships:

| Observed quantity | Result |
| --- | --- |
| Physical world scale | 1.000000 |
| World area | 0.0402886011m² |
| Physical calibration at 4096×1024 | 6px/mm |
| Metres per raw surface unit | 0.6826666594 |
| Head count / field grid | 4096 / 1024×256 |
| Pose determinant | 0.9999999800 |
| Maximum uniform-basis Gram error | 1.619e-7 |
| Estimated local air speed | 1.4062493m/s |
| Estimated field evaporation | 0.01801213µm/s |

Raw dt was 0.01651019975543022s; represented diagnostic dt was
0.016510009765625s. The remaining 1.8998980522155762e-7s is explicitly recorded;
no solver/public clock was advanced. Wet-field and pool inputs remain absent.

This confirms one actual CPU context through the main app. It does not establish
GPU geometry identity, completion, recurrent solver execution, motion quality or
performance. No extra game experiment is required to close this capture gate.
`actual_observation.json`, `actual_capture.log` and `actual_analysis.json` retain
the observation, exact emitted bits and independent numerical checks.

## Remaining work

Connect these context identities to retained GPU geometry/resources and a
substantiated ordered/completion
lifetime strategy. Actual recurrent solver adoption, bounded elapsed-time debt,
curved/feedback accuracy, unified optics and measured target GPU cost remain open.
