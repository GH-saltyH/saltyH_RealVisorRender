# RainFX s66: startup stalls, invisible glass and compiler warning

Date: 2026-10-12. Status: REFERENCE — user reports improved FPS and repaired lighting; startup pending and trail follow-up are recorded in `RAINFX_S67_NEW_TRAIL.md`.

## User result and scope

The user reports X4000 on `main`, more than ten seconds of load stall after the
KN5 migration, missing EXT/INT, no COAT E1 test colour, and renewed sunlight
loss. s65 did not establish recovery of real game FPS or a complete installation.
The source, installed modules, KN5/texture links, current SDK, and earlier
migration/performance/optics documents were reviewed together.

Baseline, compiler timings, output readbacks, runtime checks and delivery diff:
`docs/diagnostics/2026-10-12/s66/`.

## Confirmed causes

1. **Installed dependency unavailable.** The game folder's
   `native_glass_occlusion.lua` was a dangling link targeting
   `C:\source\LocalProjects\saltyH_RealVisorRender\native_glass_occlusionlua`
   (missing the dot before `lua`). Reads therefore failed as a missing file.
   The unconditional `dofile` in the pre-stack threw even
   when all four native MRR Visible boxes were off. It prevented pre/post glass
   and the routing test located within those passes. All other current Lua and
   shader dependencies match the source via existing links. Textures point to
   the source tree. The model is a valid linked KN5, with the expected SHA256;
   Windows reporting Length=0 on a link does not mean an empty model.
2. **Cold synchronous compilation.** The previous head-kernel program compiled
   in 49,764 ms offline; Rain colour took 7,799 ms and exact depth 2,533 ms.
   These are FXC timings, not a measured game loading duration. The synchronous
   shader requests provide a concrete cause for long blocking startup work.
3. **Compiler control-flow warning.** The packed-UV wrapper reproduces X4000.
   Removing the surface diagnostic branch removes it; simply initializing local
   variables or adding a branch hint does not. The depth wrapper also needs
   the unused colour continuation excluded. The s65 description of the wrapped
   warning as fixture-only was incorrect for this investigation.
4. **Render dependencies.** Glass previously depended on the Rain callback and
   its complete preparation. Rain off or a pending stage could leave dummy
   originals hidden without submitting their custom glass. Test colour shared
   that dependency and therefore could not isolate a failed stack.

## Changes

- Read-only RGBA channel loops share one head-kernel body. Slot order and water
  output stay identical. FXC head compilation is now about 1.5 seconds; bytecode
  changes from 235,356 to 29,716 bytes, with approximately 7,945 to 952 instruction
  slots. This alone is not a real game FPS measurement.
- Shader submissions for the head stages, glass/cached optics, smear/micro bake,
  main Rain and mirror water use async compilation. Pending results do not mark
  the corresponding stage ready. A pending GPU head build returns before the
  costly CPU head fallback and before marking the frame prepared.
- Main KN5 loading uses the SDK's `loadKN5Async`, retains one node hierarchy
  while pending, records duration/status, and handles failed/stale callbacks.
- The shared GPU rain mesh skips the obsolete per-triangle lookup and exhaustive
  inside-probe validation. Legacy diagnostic/per-drop mode retains them.
  Physical bakes, spawn sites, surface transport and simulation shader laws
  are unchanged.
- `RAIN_SURFACE_DEBUG` selects a separate program for modes 7/8. Colour, depth,
  packed UV and diagnostic variants compile with /Ges /WX, without suppression.
  The depth program excludes RGB continuation using preprocessor branches.
  File shader logs now have a `RealVisor/<ID>.hlsl` source name.
- Glass fallback draws independently while Rain is off/pending. It captures a
  stable current HDR source, tracks completed pre/post phases, avoids duplicate
  successful passes, and releases the temporary source after normal Rain resumes.
  The E1 output test remains callable even when the native mask/module fails.
  Missing modules produce a specific, once-per-load error. Reload after repair.
- All owned GeometryShot updates run within a shared capture scope. Main Rain,
  fallback, redraw and mirror-water callbacks skip nested offscreen execution.
  This prevents capture contamination/re-entry; actual game recursion was not
  measured. Native capture visibility scopes retain their own cleanup.
- Generated Rain mesh shadows are explicitly off and its visibility is reset
  before update early exits. Dummy FX originals remain hidden/shadow-free when
  Rain is off. Native mesh visibility remains controlled by the editor.
  Rain colour/depth submission errors no longer skip their normal restoration.

## Sunlight diagnosis and limits

`native_glass_state.lua` is installed and its policy remains intact. The generated
Rain mesh previously had no explicit shadow disable; it is now excluded from
native sun shadow lists. Native frame/fabric/band material lighting and their
authored shadows were not globally disabled to brighten the interior. Offline
checks prove these state changes and capture isolation, but do not establish
that the user's specific sunlight angle is now correct. Check it in game after
a complete reload, including the generated mesh.

The pasted previous profiler measures CPU sampling/submission, not the missing
GPU intervals. The expensive kernel code was reduced, but total steady game
cost must still be compared at the same camera, weather, track and speed.
Existing `Render Stats -> RealVisor/*` instrumentation remains available.

## Verification and delivery

- Production LuaJIT syntax; authored material/capture isolation; nested capture
  cleanup; async startup across 300 pending calls; missing dependency diagnostics;
  Rain-off output test; pending head fallback gate; legacy lookup selection.
- 25 Rain/glass shader variants and 13 optics variants compile warning-free with
  actual texture bindings (maximum eleven).
- D3D11 WARP: 384-slot baseline/new head RGB max delta 0; GPU swept wipe;
  cached smear delta approximately 1.2e-7; full Rain nearer opaque/native rejection;
  specialized depth coverage equality, including enabled haze/flow.
- Existing optical cache/tier/source, native-lighting and accepted E2/E3 checks
  pass. Settings files and physical transport code remain at the turn baseline.
- Source default values changed concurrently during the investigation (airflow
  gain, water refraction/opacity, trail width/refraction/gradient width). These
  current edits were retained; do not replace them with the initial snapshot.
- Live installed settings also changed during the investigation: active profile,
  profile-1 yaw/offset, four native MRR Visible boxes, and coating retention.
  They were retained. The semantic diff is recorded in
  `concurrent_settings_changes.json`; most material-file byte differences are
  key ordering. No tools copied initial settings back over these live changes.

The installed main source, shaders and other Lua modules already link to this
workspace. The broken `native_glass_occlusion.lua` link was repaired after the
scoped filesystem approval. Link creation was unavailable, so the verified
module was installed as a regular file. Future changes to this module require
updating that installed copy. The final audit finds no missing module or source
hash mismatch. `install_s66_native_module.ps1` handles this one dependency;
settings/profile/material files are not included. Reload the app to clear a
cached missing-module error and activate the startup changes.

Actual game load responsiveness, FPS recovery, FX visibility and sunlight
are still awaiting visual/runtime confirmation. Do not mark them verified
from these offline results.
