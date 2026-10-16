# RainFX s68: FX view ownership, native UI and convex tint

Date: 2026-10-12. Status: ACTIVE — implementation/offline verification complete; the user's automatic-driving disappearance needs game confirmation.

## User result

After initially correct output, the FX layers disappeared around the time
automatic driving was enabled, but were visible with the ESC menu open. The
user could not identify the exact transition. Native-glass render states in
the KN5 tab also raised `std/ac_common: attempt to call a nil value` from
`native_glass_state.lua:34`. Trail-quality review is deferred until these bugs
are fixed. A separate convex-area dark tint was requested for E2/E3.

## Diagnosis and changes

### Confirmed native UI cause

The SDK's `ui.treeNode(label, content)` is a callback wrapper. It owns the tree
stack; it is not the boolean `beginTreeNode` pattern. The native UI passed only
a label, then attempted a manual `treePop`. It now supplies the content
callback. Expanded/collapsed nodes preserve all material states and Visible.
SDK reference: `extension/internal/lua-sdk/ac_apps/lib.lua`, `ui.treeNode` and
SceneReference `isTransparent/blendMode/depthMode/cullMode`.

### Confirmed vulnerable FX routing; observed game trigger unconfirmed

Rain's `lastSmokeDrawFrame` and glass's pre/post completion used `sim.frame`.
A render frame can contain more than one view/target. Once an earlier view
claimed the frame, another view could be skipped. The old guard's suppression
was reproduced locally with an equal frame number and a new main view.
That is a confirmed code defect; it does not prove which engine event occurred
when the user enabled automatic driving.

An early `main.track.opaque` callback now creates a main-view serial and target
size key. Owned GeometryShots cannot advance it. Rain/glass completion and
fallback sources use that key. A target of different size cannot claim it.
Another view/redraw with the same `sim.frame` can render normally. GPU physics,
readback and trail integration still retain their existing frame cadence.

Glass no longer marks a pass complete when a custom mesh/source is pending.
The pre-pass call checks the protected function's false result as well as
`pcall` success. Native exterior ownership remains mandatory; a pending mask
does not cause an unoccluded fallback over native glass. Layer draws are
asynchronous, preserve visibility, and report false for pending/failure.
Completed items and cached E1 composites are tracked per view, so a partial
retry cannot double an already-rendered INT/COAT effect. A completed pass
clears obsolete error text. The surface diagnostic also uses view completion.

KN5 diagnostics now show the current FX view key, completed pre/post keys,
native-mask readiness/update count/error and glass status. If disappearance
persists, these distinguish a suppressed render view from native-mask or
shader preparation without changing native visibility or materials.

### Independent convex tint

New runtime key: `RAIN_VISOR_LAYER_OPTICS_CONVEX_TINT` (default 0).
Shader input: `gLayerOpticsConvexTint`.
UI: INT FX editor → E2/E3 optics → **Convex region tint darkness**, range 0…1.

0 keeps the prior image; 1 darkens to black inside the authored convex region.
The existing lens-field alpha identifies that region, including its flat
crown. The central unmasked window is excluded. Tint multiplies the optical
image after the existing relief/refraction effect gain, so it still works
when `Masked optics brightness (effect gain)` is zero. Clear glass returns a
premultiplied HDR scene difference, preserving the current layer composition.
No new render pass, atlas, texture binding or per-frame UV remapping is added.
The existing material-settings runtime prefix saves/restores the new slider.

## Verification and delivery

- Whole production LuaJIT syntax passes.
- Native UI's expanded/collapsed callback contract passes, with no manual pop
  and no material mutation.
- Production stack replay covers another view in the same frame, owned nested
  captures, different-sized targets, pending EXT/native mask, retries and
  duplicate-INT prevention.
- Existing 13 optics shader/cache/source tests pass, including E2/E3
  independence, moving/noisy world frames and zero-gain paths.
- Updated common glass shader compiles `/Ges /WX` without warnings and with
  the existing texture limit.
- Actual D3D11 shader readbacks: default tint output equals s67 exactly; 0.5
  tint subtracts 1 from an HDR scene value of 2 in the convex area; outside,
  central hole and alpha output are exactly zero. Old effect gain was zero.
- Material-settings round trip includes the new tint value.
- Source/installed shader and Lua hashes are audited. Settings/profile files,
  New Trail programs and the surface physics remain unchanged by this step.

Artifacts: `docs/diagnostics/2026-10-12/s68/` (`runtime_checks.json`,
`tint_gpu_checks.json`, `shaders/bindings_glassLayer.json`, `delivery.json`).

The installed Lua/shader entries are links to the project, so no separate
game-folder copy is needed. Reload the app to replace cached code/shaders.
Recheck automatic driving and ESC/menu transitions before detailed trail
review. Actual disappearance recovery and game FPS have not been measured.
