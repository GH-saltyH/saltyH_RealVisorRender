# RainFX: visor layer as a post overlay (2026-10-03)

> **ARCHIVED (2026-10-04, confirmed 2026-10-05).** The scene path is final
> (`RAINFX_VISOR_LAYER.md` §16–§17). The overlay code stays in
> `realvisor.lua` behind `RAIN_VISOR_OVERLAY = false` and is not developed
> further. Reasons: covered HUD/UI with no mouse-safe fix, no mirror
> support, CSP lighting (shadows, local lights, reflections) would have to
> be rebuilt. All items below (P0–P4, HUD lift, resolution, keep-out zones)
> are **closed**.

Status: P0 done, P1 implemented (s37, default off). **Optional path**: the cockpit-camera mesh loss that motivated it is a game issue (RAINFX_NEAR_OBJECTS.md §9). Nothing in the normal path changes
while the probe is off.

## Why

These results show that no in-scene stage can produce the cockpit camera
correctly:

- `RAINFX_NEAR_OBJECTS.md` §7–8 (F1 camera, Extra FX).
- `RAINFX_VISOR_GLASS.md` §8 (DLSS reprojection).

The visor is the surface nearest to the eye, so it can be composited **on
top of the final frame**:

- Wheel, bonnet, wipers, glass and clouds are all under it by construction.
- The final frame is the refraction source, so the tone is exactly the
  final tone.
- There is no temporal reprojection of our pixels.

## Plan

| Phase | Content |
|---|---|
| **P0 probe (s36)** | Verify the three open points below. |
| P1 | Overlay target at render resolution: drops plus haze rendered offscreen every frame (GeometryShot custom callback). Full-screen composite in `ui.onExclusiveHUD`. In-scene draw off. |
| P2 | Refraction source = final frame (`dynamic::screen` at HUD time, if feedback-free), shot only off-screen / near-helmet. Tone helpers switch from HDR to LDR display space. |
| P3 | KN5 visor parts in front: depth of the KN5 parts in the overlay shot (reference = KN5 visor), so our mesh is depth-tested against them. |
| P4 | Analytic AA of rims (DLSS no longer touches our pixels). Cost check. |

## P0 probe (s36)

### Settings

- `RAIN_VISOR_OVERLAY_PROBE` (default false). It runs an `ac.GeometryShot`
  whose `transparent` callback draws the last frame's `dropMeshParams`
  (same shader, setVisible trick, depth off). The target is fp16 RGBA at the
  main render-target size, clear colour (0,0,0,0), main camera
  pos/look/up/FOV, updated in `render.onSceneReady`.
- `RAIN_VISOR_OVERLAY_PROBE_FULLSCREEN` draws that target full-screen in
  `ui.onExclusiveHUD` (`ui.drawImage`, window size).
- `RAIN_VISOR_OVERLAY_PROBE_HIDE_SCENE` skips the in-scene drop draw. The
  depth pass is skipped too.
- In the HUD callback, `dynamic::screen` is copied to a 320 px thumbnail
  **before** the overlay is drawn.

### UI

Trail flow / shot tone section, under the stage probe:

- status: callback calls, mesh drawn, errors;
- the offscreen drops (left);
- `dynamic::screen` at HUD time (right).

### Questions and how to read them

1. **Can a GeometryShot callback run our render.mesh?**
   - Yes: the left thumbnail shows our drops/haze, and the status shows
     `mesh drawn` counting up.
   - No: it is empty, or the status shows FAIL / err.
2. **What is `dynamic::screen` at HUD time?**
   - Turn on hide-scene and fullscreen. The real scene then has no drops,
     only the overlay has them.
   - Right thumbnail **without** drops: the final frame is feedback-free and
     usable as the source (P2).
   - Right thumbnail **with** drops (one frame late): our HUD drawing leaks
     into it. The source then needs the in-scene LDR or the shot.
   - Also check the right thumbnail in the F1 camera with Extra FX: the
     wheel and bonnet must be **textured** there.
3. **Coverage and alignment.**
   - Turn on fullscreen with hide-scene off. The overlay drops should lie
     exactly on the in-scene drops (no offset or scale) and cover the whole
     screen.
   - Then turn hide-scene on. The drops should stay where they are, and
     haze must now lie over the wipers and the wheel.

### Expected limitations of the probe (not bugs)

- The drop shader still samples the in-scene source (tone canvas). In the
  probe, the refraction content is therefore still the old one.
- No depth test against KN5 visor parts yet (P3).
- Drawn with plain alpha blend. Our shader output is straight alpha, which
  matches `ui.drawImage` with the default blend only approximately.

## P0 result (user, 2026-10-03)

1. Status ok. Callback calls and mesh drawn count up together, so a
   GeometryShot custom callback **can** run our `render.mesh`.
2. With hide-in-scene on, the in-scene drop mesh disappears.
3. Fullscreen in HUD draws the offscreen layer above every game render,
   including the wipers. Only UI and apps are above it.
   - `dynamic::screen` at HUD time (right thumbnail) shows the final frame
     **without** our layer.
   - In it the F1-camera wheel is red and textured, and the glove is white.
   - So the final frame is feedback-free and complete: the P2 source is
     confirmed.
4. The colours are not the previous tone. That is expected:
   - The probe drew the HDR shader output straight onto the LDR frame.
   - It used plain alpha blend into the shot.

## P1 (s37): overlay-only path (`RAIN_VISOR_OVERLAY`, default false)

When enabled, each HUD frame does the following:

1. **No in-scene draw.** The in-scene drop draw and its depth pass are
   skipped. The drop callback still runs, because state, masks and tone
   are updated there.
2. **Source.** In `ui.onExclusiveHUD`, `dynamic::screen` (final frame of this
   frame, before our layer) is copied into an fp16 canvas at main
   render-target size with `RAIN_VISOR_OVERLAY_SOURCE_MIPS` (9) mips, and
   `mipsUpdate()` is called. This canvas is the drops' `txDynamicSnapshot`,
   and its mips are used for haze and trail blur.
3. **Layer.** The visor overlay GeometryShot is updated **inside the HUD
   callback**, same frame, using the last `dropMeshParams` copied with:
   - `gDynamicDropLDR = 1`;
   - inv screen and RT size = 1/shot size, so `PosH` maps exactly onto the
     source;
   - all three sky corrections off (the final frame is already toned).

   The mesh is drawn **Opaque with depth** into a (0,0,0,0) clear: the
   texel keeps the shader's straight (rgb, a), the nearest visor part wins,
   and clipped pixels stay empty.
4. **Fallback.** If the update fails inside the HUD, it moves to
   `onSceneReady`, one frame late. The status line shows which path is
   active.
5. **Composite.** `ui.renderShader` full-screen with `AlphaBlend`, using the
   saturated rgb and a. The debug option shows alpha as grey.

### Shader LDR mode

- A static `gFogTone` replaces all eight uses of the WeatherFX fog colour:
  veil, glint, sky tone, micro pop flash and smear turbidity.
- **In-scene (HDR):** `gFogTone` = `gDynamicDropWeatherFogColor`, so nothing
  changes.
- **LDR overlay:** `gFogTone` = the source's mean at uv (0.5, 0.4) at mip
  `RAIN_VISOR_OVERLAY_FOG_MIP` (6), desaturated by `FOG_TONE_SATURATION`.
  In LDR the output rgb is saturated.

### Not done yet

- **P3:** KN5 visor parts in front. The overlay is above them now.
  `NEAR_OBJECTS` §2c.
- **P4:** rim AA and cost.
- Tuning constants that were tuned in HDR (glint, rim, veil strength) may
  need LDR re-tuning.

### Notes

- `ui.onExclusiveHUD` holds a single callback. The P0 probe callback calls
  the P1 function first.

## 2026-10-03 status change

- The F1-camera wheel/bonnet loss reproduces without the app. It is a game
  issue (`RAINFX_NEAR_OBJECTS.md` §9).
- The overlay is therefore no longer required. It is kept as an optional
  architecture, judged only on its own merits:
  - haze above wipers and car glass;
  - no DLSS reprojection drag (VISOR_GLASS §8);
  - final-frame tone, clouds included.
- **Decision pending a P1 test:** compare tone, cost and AA with the
  in-scene path.

## s39 fix: shader compile error in s37 (user report)

- **Error:** `error X3004: undeclared identifier 'gFogTone'` (line 449 of the
  compiled source).
- **Cause:** the static `gFogTone` was declared after `gSolidA`, but its
  first use is earlier, in `rainDynamicWeatherSkyTone`. In HLSL a variable
  must be declared before it is used.
- **Fix:** the declaration now comes directly before
  `rainDynamicWeatherSkyTone`.
- **Consequence:** in s37 **both** the in-scene draw and the overlay failed
  to compile, which is why P1 showed `drawn false`. P1 has not been tested
  yet.

## P1 result (user, 2026-10-03, after the s39 fix)

1. Status shows src ok, render HUD, composite ok, drawn true.
2. The tone is close to the in-scene one. It is slightly darker, possibly
   because every effect now reaches the whole area.
3. All in-game render elements are covered (wipers, glass, wheel).
4. **Problem: the basic in-game HUD is covered too.**
   - Lua app windows are not covered. AC / Python apps such as Car Physics
     are covered wherever the layer has alpha.
   - They show only where the layer is empty, which includes the KN5 parts.

### Reading

The original AC HUD and the Python app windows are drawn **before**
`ui.onExclusiveHUD`. Lua IMGUI windows are drawn after it.
`dynamic::screen` contains neither (the haze shows no HUD).

There is no hook between post-processing and the HUD: lib.lua has only
`render.on` stages, `onSceneReady`, `onExclusiveHUD` and `onUIFinale`.

## s40: HUD lift (`RAIN_VISOR_OVERLAY_HUD_LIFT = true`)

- **How it works.** Every second, `ac.getAppWindows()` is scanned. Visible
  windows are moved with `AppWindowAccessor:setRedirectLayer(layer)` to
  redirect layer `RAIN_VISOR_OVERLAY_HUD_LAYER` (7), not duplicated.
  - After our composite, `dynamic::hud::redirected::7` is drawn full-screen
    with `ui.renderShader`. Blend is AlphaBlend, or BlendPremultiplied when
    the toggle is on (to check text edges).
- **Default skip.** Windows whose name starts with `IMGUI` (Lua apps) are
  skipped by default. Our own window ("real visor" in title or name) is
  **never** lifted, so the UI can always switch the lift off.
- **Per-window control.** The UI lists the visible windows with a per-window
  lift checkbox.
- **Release.** Windows are released with `setRedirectLayer(0)` when:
  - the lift or the overlay is switched off;
  - the layer changes;
  - the script unloads (`ac.onRelease`).
- **Limitation (CSP).** Lifted windows get **no mouse input** ("Windows in
  separate layers don't get mouse commands"). To move or click one, turn
  the lift off.
- **To verify.**
  - Whether the redirect layer of the current frame is ready at HUD time.
    A one-frame lag is acceptable for a HUD.
  - Whether the AC native HUD elements (tyres, delta, …) appear in
    `getAppWindows()`.

## s40 result (user, 2026-10-03)

1. In the cockpit view the image **periodically flickers dark**, like a
   faulty light.
2. HUD lift draw shows `ok`, layer 7.
3. Car Physics is lifted. **Still covered:** the pit config and the car
   damage displayer, among others.
4. The HUD and the visor layer look slightly lower in resolution. With the
   premultiplied blend, the HUD becomes sharp.

## s41

### Flicker

- s40 re-applied `setRedirectLayer` every second whenever the reported
  `wnd.layer` differed from ours. The redirect layer is probably reset or
  uninitialised in the frame after such a call. A full-screen draw of it
  then darkens the view: a periodic (1 s) flicker.
- Now a window is redirected **only on change**. After any change, the
  layer draw is skipped for 2 frames ("settling").
- If the flicker remains with HUD lift **off**, it has another source.
  Report it with that information.

### HUD blend

`RAIN_VISOR_OVERLAY_HUD_PREMULTIPLIED = true` is now the default, after the
user test: the redirect layer is premultiplied.

### Resolution (`RAIN_VISOR_OVERLAY_RES_SCALE`, default 1)

- s37 rendered the overlay at the main render-target size, which is the
  DLSS input (2159×1249 → 3238×1872). It was stretched, so it looked soft.
- Now the size goes from 0 = render target to 1 = output (window) size.
- Screen-terms look is preserved:
  - **Pixel-unit params** are multiplied by k = overlay width / main width:
    haze speckle, large start/full/warp px, smear facet px, film px, trail
    refract px, ridge px.
  - **Blur mips:** every source read goes through `rainSnap()`, which adds
    `gDynamicDropMipBias` = log2 k.
- Cost: about k² more pixels (2.25× at DLSS quality).

### Not covered by the lift (open)

- The pit configuration, the damage displayer and the fuel warning are
  **not app windows**. AC draws them before our HUD callback, and they do
  not appear in `ac.getAppWindows()`.
- `ac.redirectVirtualMirror` / `redirectDamageDisplayer` /
  `redirectFuelWarningIndicator` exist, but lib.lua does not document them.
  Only the mirror has a public redraw (`ui.drawVirtualMirror`).
- Candidate next step: **HUD keep-out zones**. These are screen rectangles
  where the overlay alpha is faded out, adjustable in the UI.
