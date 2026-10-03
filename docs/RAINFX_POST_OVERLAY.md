# RainFX: visor layer as a post overlay (2026-10-03)

Status: **P0 probe implemented (s36)**. Nothing in the normal path changes
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
