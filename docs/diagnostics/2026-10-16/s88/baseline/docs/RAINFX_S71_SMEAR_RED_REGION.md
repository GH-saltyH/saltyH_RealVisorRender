# RainFX s71: Smear red-region bypasses

Date: 2026-10-13. Status: ACTIVE — corrected and offline verified; game confirmation pending.

## User result and intent

The user reports 100% rain, 220–287 km/h, amp 0.6–1.50 and density
1.00–1.50. Clearly exposed water is in the **red** debug region; blurred
water in the **green** region is accepted. These are observed ranges, not
necessarily simultaneous readings from one frame. The supplied screenshot
does not include exact level/facing or the debug overlay.

Debug 1 outputs R=`region*0.85`, G=`region*processedG`. Red therefore means
strong region/low G, and green means strong region/high G. It is not raw
texture channel display. The v8 user instruction supersedes older v3/v4:
every water feature should fade in low G. The October 7 neutral trail
composition must retain that visibility rule while avoiding a turbid water
overlay in full smear interiors.

With the current trigger 0.30 and full density 0.90, density 1–1.5 already
saturates the density part of reveal; facing and smoothing still affect
actual level. There is no basis to attribute this red/green difference to
insufficient density. Source defaults and texture data were retained.

## Reproduced causes and corrections

### 1. Class erasure bypassed path weakening

Old code used `clearance * CLASS_WIPE` before class presence. In a full
low-G region a fresh 0.95 clearance footprint produced erase=0.76 at the
current CLASS_WIPE 0.80. Class 0's erase order is about 0.309. Its presence
became zero, cancelling the smear region and every visibility/turbidity
effect. Moving water was consequently restored at full alpha on the very
path where the red region should weaken it.

Now class erasure calls `rainSmearWipe(clearance)` **before** class survival.
For full region, G=0 and PATH_WEAKEN=0.85, the erase term is 0.114. The mask
survives and the existing head/micro visibility rules can work. Reveal-driven
class erasure, class order, wipe settings and wind/GPU physics remain.

### 2. Neutral trail coverage ignored G

The legacy water alpha followed `rainSmearVis(TRAIL_HIDE)`, but neutral
trail coverage used only `pureInside * region`. Full region/zero G therefore
still produced full composite coverage, even though water-overlay alpha
was zero. Its refraction offset also survived this independent path.

Neutral coverage now multiplies the same `rainSmearVis(TRAIL_HIDE)`. The
existing slider applies to both the overlay and neutral refraction. The
neutral path retains its scene source/micro/haze composition; no uniform
region sheet or extra turbid overlay is added.

### 3. Colour and class survival chose different boundaries

The s65 colour interpolation straddled class boundaries symmetrically;
class survival/debug still used the older one-sided interpolation. They
could display a blended facet colour while using a different class's
presence for hiding water. A shared `rainSmearClassPair` now selects the
same neighbours and interpolation for colour, presence and debug. The
existing temporal survival feather of 0.15 is retained. Intermediate-G
transition pixels consequently change; this corrects alignment rather
than claiming every green pixel is numerically unchanged.

### 4. Smear UI settings were not saved

The material runtime whitelist contained New Trail and glass controls but
excluded all `RAIN_DYNAMIC_SMEAR_*` keys. Slider changes therefore did not
mark settings dirty or survive reload. Numeric/bool Smear keys now save/load
through the existing module. The two direct integer widgets (class count
and wind mode) also mark dirty safely. Texture-path strings remain source
configuration, consistent with existing persistence support.

## Verification

`docs/tools/check_s71_smear.py` executes the production shader via D3D11
WARP, with controlled G endpoints and separate liquid/clearance inputs.
Bare facet film is disabled in these isolation tests, so they measure
water behavior, not the deliberately faint class film on bare glass.

| Case | Before | After |
|---|---|---|
| G=0, fresh wipe, WF head | region 0; water alpha 1 | region 1; water alpha 0 |
| G=0, neutral WF trail, no wipe | water alpha 1 | water alpha 0 |
| G=1, fresh wipe, WF head | region 0.605; water alpha 1 | identical RGBA |
| G=1, neutral WF trail | water alpha 1 | identical RGBA |
| Smear disabled | normal WF output | identical RGBA |

The shared class helper was also executed over 4096 G samples. Colour and
presence use that helper; class count 1 and the final class remain bounded
by its clamped selection. High-G endpoint/smear-off RGBA differences are
zero in these fixtures. The tests do not establish a final game screenshot
or exact behavior of every intermediate G value under overlapping water.

- `check_material_settings.py`: numeric/bool Smear round trip, existing
  New Trail/glass settings, whole LuaJIT syntax and material rules pass.
- `check_rain_migration_shaders.py`: production colour, depth and packed-UV
  colour/depth wrappers compile with FXC `/Ges /WX`; four variants, no
  warnings; texture bindings remain within the CSP limit of 11.
- Runtime numeric/bool defaults are equal to the staged source.
- Installed main Lua/material module and shader resolve to the workspace;
  content hashes match. Reload the app to load the changed shader/control
  code. No separate missing-module installation is required.

No render pass, canvas, readback or particle count was added. Actual GPU
performance and the user's 100% rain driving view still need in-game
confirmation. The s70 ordinary-trail thickness/subpixel calibration remains
open and is not claimed fixed by this Smear correction.

## Evidence

Artifacts are under `docs/diagnostics/2026-10-13/s71/`: baseline sources,
`smear_baseline.json`, `smear_checks.json`, compiled shaders, delivery hashes
and the step-specific source diff. Runtime changes are in
`shaders/rainVisorDynamicDrop.hlsl`, `material_settings.lua` and UI help/dirty
handling in `realvisor.lua`.
