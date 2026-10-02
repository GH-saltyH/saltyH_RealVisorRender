# Refraction source: how CSP's windscreen gets clouds, and what we can use (2026-10-03)

Status: research only, no code change yet. It follows from
`RAINFX_SHOT_TONE.md` v1 and v2.

## User findings (2026-10-03)

1. The real issue the fog colour was hiding: **WeatherFX sky content
   (CSP clouds, storm cover, the real sky colour) does not reach our drop
   images.**
   - Example: an afternoon thunderstorm in the frame, while our drops show
     a sunset sky.
   - If that could be reflected fully, the frame-match idea would be ideal.
2. The tone pass v2 (frame match) did two things wrong:
   - it **cut away meshes in front** (cars and the cockpit near us);
   - it **blurred everything** in the area;

   and it still did not show the CSP clouds.

## What the references say (preview634, lib.lua and configs)

### 1. The geometry shot cannot contain WeatherFX clouds

- `ac.GeometryShot:setSky(value)`: "Enables sky in the shot." That is the
  sky shader only. There is no cloud switch in the GeometryShot API.
- The GeometryShot methods are: `setTransparentPass`, `setOriginalLighting`,
  `setShadersType`, `setSky`, `setParticles`, `setGrass`,
  `setClippingPlanes`, `setClearColor`, `setAmbientColor`,
  `overrideReflectionCubemap`, `setReflectionColor`,
  `setBestSceneShotQuality`, `setExposure` and others.
- WeatherFX clouds are separate scene objects that the weather script
  manages (`ac.SkyCloudV2`, the `ac.weatherClouds` list,
  `ac.setManualCloudsInvalidation`, cloud maps; see `weather/base/weather.lua`
  and the `ac_wfx_impl` SDK). They are not part of `sceneRoot` geometry.
- So the shot shows the base sky, for example the old sunset gradient,
  under whatever the weather really is. The former sky-tone fix (replace
  sky with fog) hid this, and gave the blue cast.

### 2. The windscreen effect is internal, but its source is clear

- `windscreen_fx.ini` and `rain_fx.ini` expose only switches (G-force
  multiplier, screen-drop styles). The windscreen drop shader is compiled
  into CSP (`shader-tpl` is not shipped either), so its code cannot be
  read.
- What is known about the pipeline: car glass is drawn **after** every
  stage Lua can hook. We tested track, root and smoke; glass blends over
  everything (`RAINFX_IMPACT_SPLASH.md` §7).
- A shader drawn that late can refract the **frame itself**, a screen
  copy of the opaque scene with sky and clouds. That is the standard way
  to do glass refraction, and it matches what we see: CSP drops show the
  exact clouds and storm, and the cars and track as rendered.
- It also matches the DLSS note in `windscreen_fx.ini`: "[REFLECTION]
  ENABLED_WITH_DLSS … because of how DLSS and other temporal upscalers are
  working, it'll look really messy". That is a screen-space effect hitting
  the upscaler.

### 3. What Lua can reach of the frame

- `ui.ImageSource` lists `dynamic::screen` (LDR scene), `dynamic::hdr`
  (HDR scene) and `dynamic::depth` (non-linear scene depth). They "require
  Graphics Adjustment, not very reliable in general".
- `ExtraCanvas:updateSceneWithShader` "can be used in the middle of
  rendering scene, and has access to camera state and some rendering
  pipeline textures" (fullscreen.fx template). It is the right call to copy
  `dynamic::hdr` with mips mid-frame.
- Render stages Lua can hook: `main.track.opaque`, `main.root.opaque`,
  `main.track.transparent`, `main.root.transparent`, `main.smoke`. Their
  order relative to the cloud draw is **not documented**.

### Why v2 failed (explained by the above)

- **Meshes cut away.** v2 copied `dynamic::hdr` inside the drop callback,
  `main.track.transparent`. At that point the frame evidently does not yet
  hold the root objects: our car and its cockpit, other cars. The frame/shot
  ratio then pulled those pixels toward the track behind them.
- **Everything blurred.** The ratio was taken at mip 5 (about 32 px). That
  is fine for a tone, but every edge got a halo, and it reads as blur.
- **No clouds.** A low-mip ratio cannot carry cloud *shapes*, only a
  tint. And if the clouds are not yet drawn at that stage, not even the
  tint.

## Proposed solution: per-texel frame-first composite

Instead of a tone ratio, build the refraction source from the **frame
wherever the frame shows what the shot shows**, and from the shot only
where the frame cannot.

```
frame = dynamic::hdr copied at stage S (with its depth: dynamic::depth)
shot  = geometry shot (complete scene from >= 0.10 m, base sky)
use frame if  frameDepth >= shotDepth - eps      (same surface or sky)
use shot  if  the frame is nearer than the shot  (helmet / visor parts, or
              anything at < 0.10 m that the shot excludes)
source = per texel, then mips
```

What this gives:

- clouds, storm and the real sky colour exactly as in the frame;
- cars and cockpit from the frame, wherever the frame is captured after
  they are drawn;
- the shot only fills what the frame covers with near helmet geometry, so
  no tone hack and no blur.

**What has to be measured first.** At which stage the frame has (a) the
root objects and (b) the clouds. Plan: a **stage probe**, a debug option
that copies `dynamic::hdr` into a small canvas at each of the five hooks
and shows the five thumbnails side by side in the UI.

- The latest stage before car glass that contains clouds and the car is
  where the frame copy goes.
- The drop draw then moves to the same or a later stage. With the shot no
  longer the main source, the smoke-stage streak issue has to be re-checked.
- If no stage contains the clouds before car glass, fall back to the
  **previous frame's** final `dynamic::hdr` (copied in `onSceneReady`, one
  frame old), reprojected for camera rotation. Head-locked drops make the
  error small.

**Cost.** One full-screen copy with mips, plus one composite pass.
`dynamic::depth` is non-linear, but the same linearisation as the shot
depth applies, with the main camera's near/far planes.

**Open risk.** "Not very reliable" (lib.lua) for `dynamic::*`: the probe
also shows whether they are valid with DLSS at the chosen stage.

## Status of the tone pass

- **Mode 2 (frame match)** is superseded by the composite above. Do not
  use it: it cuts meshes and blurs.
- **Mode 1** remains as a fallback when no frame is available.
