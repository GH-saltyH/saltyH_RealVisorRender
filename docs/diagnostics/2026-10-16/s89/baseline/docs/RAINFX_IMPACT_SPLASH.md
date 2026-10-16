# Impact splash v2, birth hold, worm fix, black-area fix (2026-10-02)

Status: implemented. DXC (ps_6_0) compiles:

- the main drop shader;
- the position-state shader with `RAIN_MERGE_CODE` and `RAIN_WETPATH_CODE`.

The Lua block/bracket check passes. **Not yet seen in game.**

## 1. Impact splash v2 (`RAIN_DYNAMIC_WATER_FIELD_SPLASH_V2`, default on)

**2026-10-06 trigger control (revised).** Splash v2 is the only impact
renderer. On a new drop, it activates if the drop diameter reaches the
configured heavy birth-size threshold, or if vehicle speed is above
`TEAR_MIN_KMH` and that drop is selected for a speed-only splash. The UI
slider `WF torn impact: heavy size range (%)`
places that threshold between `Heavy minimum` (0%) and `Heavy maximum`
(100%); the default is 50%. The splash strength is the larger of the speed
strength and the size strength. Size-only activation starts at 0.35 strength
and increases toward the heavy maximum, so it remains visible at zero speed.
The splash remains at its frozen impact position. Birth-size keyframe edits
affect new births only; the threshold slider applies live.

After the 4096-slot fast-driving capture showed 666 simultaneous splash
heads and 9.09 ms in the CPU head overlay, `Speed-only splash birth share`
was added. It defaults to 0.12 and selects a stable fraction of drop lives
by slot and generation. It changes splash density, not the size threshold:
large drops always qualify, including at 0 km/h. Set it to 1.00 to restore
the earlier behavior where every drop above the speed threshold splashes.
The capture is a transient sample, so the FPS effect needs an in-game A/B
test under the same moving scene.

The earlier requirement that **both** speed and size pass, and the coupling
to `WF torn impacts at speed`, are withdrawn. The legacy staged-pancake
renderer, its toggle, duration and minimum-diameter setting were removed.
`Impact splash v2` now controls all torn impacts. In GPU-head mode its
kernels draw as a CPU overlay on the GPU head canvas; GPU-head debug 2
intentionally hides that overlay. The GPU body override applies one frame
later. In-game visual and performance verification is pending.

**Request.** The burst at high-speed drop birth should animate like the
reference shapes. The bigger the drop and the harder the impact, the bigger
the effect:

- the centre is pressed down and the water is pushed out to the edge;
- over time the centre is pressed harder while the outside grows;
- finally the centre loses all relief and becomes empty;
- the water pushed to the edge breaks up and scatters.

Overall, mass and relief move from the centre outward.

**Model.** The function is `waterFieldSplashV2`. It draws into the head canvas
every frame at the frozen impact point.

```
E   = tearAmount(speed) * (0.55 + 0.45 * size)      size = sat(Rf / SIZE_REF), Rf = head texels
T   = SPLASH_SECONDS * (0.6 + 0.8 * size)           lifetime; t = age / T
s   = 1 - (1 - t)^2                                 fast spread, then slows
Rp  = Rf * (1 + SPREAD * E * s)                     rim radius
centre kernel: radius 0.8 Rp, amplitude (1 - smoothstep(0.05, HOLLOW_AT, t)) * (1 - 0.45 s)
               -> pressed flat, then below the threshold = empty
rim:  10..22 kernels (scaled by E) on the ring at Rp * (0.88..1.12), stretched along the rim
      brk = (t - BREAK_AT) / (1 - BREAK_AT)
      pieces fly out by Rf * SCATTER * E * brk, shrink, and vanish one by one (h3 < 0.6 brk)
satellites: 2..8 small beads thrown beyond the rim after t 0.25
body: hidden during the splash, back as a residual drop (RESIDUAL 0.65 of R) from t 0.7;
      grows back to full size over 2 T
end:  the final scattered state is stamped once into the persistent trail canvas (amp 0.85)
```

Union kernels carry the slope, so the refraction and highlight ring moves
outward with the mass. The older staged "pancake" was removed on
2026-10-06; `SPLASH_V2 = false` disables impact splashes.

Prototype: `images/impact_splash/splash_v2_E04_E10.png`, energy 0.4 (top) and 1.0
(bottom), at t = 0.05, 0.2, 0.4, 0.6, 0.8 and 1.0. Script:
`tools/impact_splash/splash_proto.py`.

**Defaults.** SECONDS 0.45, SIZE_REF 8, SPREAD 1.8, HOLLOW_AT 0.45,
BREAK_AT 0.55, SCATTER 1.4, RESIDUAL 0.65. It triggers under the speed
and size conditions described above.

## 2. Birth hold (`RAIN_GPU_STATE_BIRTH_HOLD_SECONDS 0.6`, `RAMP 1.2`)

In the position-state shader, a live drop's time step is scaled by:

```
holdK = smoothstep(sat((age - hold) / ramp))
hold  = HOLD * (0.6 + 0.8 * hash(index))
```

`age` is Meta.B. While `holdK = 0` the velocity is held at 0. A fresh drop
therefore rests, then accelerates gradually. The hold also covers the
splash, so the residual drop reforms where the splash happened.

## 3. Worm bug

**Symptom.** Without a downward force, drops crawl in small circles up,
down and sideways.

**Cause.** Wet-path steering sampled the trail gradient at the drop centre.
That point lies on the drop's own fresh trail. At low speed the velocity
direction is noisy, so the "lateral" component of that strong gradient
kept turning the drop. Attraction steering could also turn slow drops
sharply.

**Fixes**

- The wet-path gradient is read **ahead** of the drop, at
  `radius × WETPATH_AHEAD (1.5) + 2 texels` along its motion.
- Wet-path and attraction steering are capped at `STEER_TURN_RATE`
  (1.5 rad/s): |Δv| ≤ |v| × rate × dt. A slow drop can no longer be turned
  quickly.
- The default `WETPATH_MIN_SPEED` rises from 0.004 to 0.010 UV/s.

**If it persists:**

1. Turn off "Wet-path steering".
2. Then turn off attraction ("Coalescence and absorption steering").

That tells which force is left. Report it, and the physics shader is
next.

## 4. Effect missing over black areas (windscreen, parts of the interior)

Two causes are addressed. Both have toggles.

1. **Tone limiter.**
   - The final luminance window was `bg × [0.55, 1.45]`. Over a near-black
     background it collapsed to about 0, which removed refraction, rim and
     glint.
   - The upper bound now uses `max(bg, fogLum × TONE_FLOOR 0.25)`. UI:
     "Tone window floor".
2. **Depth test.**
   - Drops were drawn with `DepthMode.ReadOnly` at `main.smoke`. Any car
     glass or cockpit mesh that wrote depth could hide them.
   - The visor is the surface nearest to the eye, so `DEPTH_OFF = true`
     (default) draws drops without a depth test. UI: "Drops ignore scene
     depth".

**Diagnosis.** If the black area still shows nothing, toggle each fix
separately:

- Floor at 0 brings the problem back → the tone window was the cause.
- Depth off back to off brings it back → the depth test was the cause.
- If neither does, the cause is likely the geometry shot itself rendering
  black there. That needs a separate investigation.

## 5. Removed

- The spray film (`RAINFX_SPRAY.md`) and the flow layer
  (`RAINFX_FLOW_LAYER.md`) are deleted: config, Lua helpers, onSceneReady
  calls, uniforms, UI and HLSL.
- The shared texture slot now holds only the smear mask, or the weather
  screen canvas.

## 6. Follow-up on §4 (2026-10-02, after the in-game test)

### Depth test off is rejected

The visor has overlapping parts, and with no depth test the drops on the
back part showed through the front part. `RAIN_DYNAMIC_DROP_DEPTH_OFF` is
back to `false` (ReadOnly) and kept only as a diagnostic toggle.

### Refraction source was incomplete

The geometry shot is the image every drop refracts. It ran **without its
transparent pass** (`ac.GeometryShot` default), so car glass and
transparent interior parts were missing from it. The refracted image then
no longer matched what is really behind the visor, and quality visibly
dropped as soon as the camera entered the interior.

Two new settings:

- `RAIN_DYNAMIC_DROP_SHOT_TRANSPARENT = true`. Calls
  `geometryShot:setTransparentPass(true)` (CSP API, lib.lua: "Enables or
  disables transparent pass … Disabled by default").
- `RAIN_DYNAMIC_DROP_SHOT_NEAR = 0.10` m. The shot's near clip is
  `max(camera near, 0.10)`, so the helmet visor itself (a few cm from the
  eye) cannot appear in its own refraction source once transparent surfaces
  are drawn. The sky test uses depth ≥ 0.99999 (the far plane), so it is
  unaffected.

UI (Trail flow section): "Refraction source: transparent pass (glass)" and
"Refraction source near clip (m)".

Cost: the shot also draws transparent meshes. Watch FPS when toggling.

### Yellow windscreen tint on the drops: diagnosis first

There are two possible explanations, which need different fixes:

- **Physically correct.** Everything behind the visor is seen through the
  tinted glass, so the image a drop refracts is tinted too. This is more
  consistent now that the shot includes the glass.
- **Render order.** The car glass is drawn after our drops (current stage:
  `main.smoke`) and blends over them.

**Test.** Turn on a flat-colour debug view, e.g. "Smear debug" 1 or "Water
field debug" 2, and look at the windscreen area:

- **Colours stay pure:** our draw is on top. The tint is refraction of the
  tinted glass, which is expected.
- **Colours turn yellow or dim there:** the glass is drawn after us. Then
  try the other draw stage: set `RAIN_DYNAMIC_DROP_DRAW_AT_SMOKE_DEBUG =
  false` (it falls back to `main.track.transparent`, or
  `main.root.transparent` when `RAIN_DYNAMIC_DROP_DRAW_AT_TRACK = false`),
  then reload Lua.
  - The smoke stage was originally chosen because `dynamic::hdr` contained
    rain streaks at the other stages.
  - The drops now refract the geometry shot, which has no particles, so the
    reason may no longer apply. It still needs to be re-checked.

## 7. Car glass over the drops, ghosting (2026-10-02)

### User test results

- With "Smear debug" 1, the car glass is **always drawn on top** of our
  drops. This is a render-order problem. It existed from the start but was
  ignored for open-wheel cars, which can still have glass.
- `DRAW_AT_TRACK = false` (root transparent stage) does not change it. The
  glass is drawn after every stage we can hook: track, root and smoke.
- With `DRAW_AT_SMOKE_DEBUG = false`, rain streaks no longer mix in, because
  the drops refract the geometry shot. The smoke-stage workaround is
  obsolete, and its default is now `false`.
- With the smear on, fast camera motion leaves afterimages. With the smear
  off they do not appear.

### Fix: depth occlusion pass (`RAIN_DYNAMIC_DROP_DEPTH_OCCLUDE`, default on)

- After the normal draw, the same mesh and shader run again with
  `gDynamicDropDepthOnly = 1`, `DepthMode.Normal` (write) and alpha 0
  output, so no colour changes.
- Only the visor surface layer survives, and only where water (WF height
  above threshold) or a visible micro drop is: gated by rain, not wiped.
  Everything else is clipped.
- Car glass is drawn later and lies behind the visor, so it now fails its
  depth test at those pixels and cannot blend over the drops.
- The drops still show the glass tint, because they refract the shot, which
  includes glass (§6).
- Bare visor areas and the haze write no depth, so the glass stays as it
  was there.
- Cost: a second draw with a cheap path (3 taps, no shading).

**Side effect, probably helpful.** Those pixels now carry near,
head-locked depth. If CSP's TAA or DLSS derives camera motion from depth,
visor-fixed content is no longer reprojected with the scene behind it,
which was the likely source of the smear afterimage (a large, smooth,
translucent visor-fixed layer). This is unverified.

**Second anti-ghosting tool.** `RAIN_VISOR_MOTION_STENCIL` (default −1, off)
calls `visor:setMotionStencil(value)` on the visor KN5. Per the CSP API:
1 = reduced TAA, 0.5 = extra TAA. It takes effect when the visor is loaded,
so test 1 with a Lua reload if the afterimage remains.

**Checks**

1. With "Smear debug" 1, the debug colours must now stay pure over the
   windscreen.
2. A toggle in the UI (Trail flow section): "Drops occlude later car glass
   (depth pass)".
3. Watch drop edges over glass. A thin untinted fringe is possible where
   drop alpha is below 1.
4. Afterimage: compare with the depth pass on and off, then with motion
   stencil 1.

**Structural alternative**, if needed later: draw the drops as part of the
visor's scene graph. The project already has a `createMesh` test node.
Transparent scene meshes are depth-sorted, so the visor, being nearest,
would naturally be drawn after the glass. This is a larger refactor
because the custom drop shader would have to move into a material path.

## 8. Depth pass v2: exact mode (2026-10-02)

**User result.** The visor effects now cover the windscreen correctly, with
one exception. With `RAIN_DYNAMIC_TRAIL_MASK_WIPE_ENABLED = true`:

- micro drops that reappear after a wipe are not shown over the
  windscreen;
- even unwiped micro drops do not sit fully on the windscreen.

**Cause.** The cheap gate only approximated what the colour pass draws:

- it used water height and micro class;
- it took the wipe at the pixel instead of at the disk centre;
- it used a hard 0.08 cut, so recovering micro drops (visibility between 0
  and 1) wrote no depth;
- it ignored films, ridges and region sheets.

Wherever no depth was written, the glass blended over our output.

**Fix: `RAIN_DYNAMIC_DROP_DEPTH_OCCLUDE_MODE = 2`, exact (default).**

- The shader entry is now a wrapper. `main()` calls `rainDropMain()`, the
  former `main`.
- In the depth pass it does `clip(alpha - DEPTH_ALPHA_MIN 0.35)` and writes
  depth only. The depth pass therefore shades exactly like the colour pass,
  and every visible element occludes the glass behind it:
  - wipes and recovery;
  - films and ridges;
  - smear sheets and turbid micro drops.
- Cost: a second full shading of the visor layer.
- Mode 1 keeps the cheap gate as a fallback if FPS matters more.

UI: "Depth pass mode (1 cheap, 2 exact)" and "Depth pass alpha min
(exact)". A lower alpha min also lets faint haze occlude the glass.

## 9. Exact depth ignores haze (2026-10-02)

**User result.** After §8, the haze patterns erased the yellow windscreen
and showed the asphalt behind it.

**Cause.** Exact mode clipped on the *final* alpha, and the final alpha
includes the haze. Wherever haze was at least `DEPTH_ALPHA_MIN` opaque, the
visor wrote near depth, so the windscreen behind it failed its depth test
and was never drawn. Our haze refracts the geometry shot, which at that
point holds the asphalt and not the glass, so the asphalt showed through.

**Fix.** The shader keeps a second static next to `gOver`:

- `gSolidA` holds the opacity of the *solid* element of the pixel: the WF
  head or trail (`inside × wfAlpha`), the trail film (`filmAlpha`), and the
  micro disk (`lensAlpha` / `microAlpha`).
- Haze and the smear facet film (`RAINFX_SMEAR_MASK.md` v7) never set it.
- The wrapper clips on `max(gSolidA, gOver.a) - DEPTH_ALPHA_MIN`.

So pixels that hold only haze write no depth. The glass draws over them
(its normal blend order), and water and micro drops still occlude it.

**Rule for new layers.** A layer that should hide car glass behind the
visor sets `gSolidA`. A veil-type layer (haze, film on bare glass) must not.
