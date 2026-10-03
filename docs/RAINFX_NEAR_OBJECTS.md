# RainFX: near objects (wiper zone, steering wheel, KN5 visor parts) — 2026-10-03

Status: s33. v4 rules 1 and 2 implemented (both behind toggles). The
structural fix (§4, post overlay) is proposed and not built yet.

## 1. User observations (after s32)

- The wipe zone (the windscreen area cleared by the car wiper) is still
  drawn **over the haze**. Our drop trails smear it, so it sits **under** the
  trails.
- A steering wheel hidden behind the drops behaves exactly like the KN5
  visor problem. With the wheel between the sky and the visor, the old shot
  sky tone (no CSP clouds) comes back inside the drops.
- The user expects a structural KN5 solution to cover all of these cases.

## 2. Diagnosis: three different mechanisms

### 2a. Wipe zone over the haze: render order plus depth

- Car glass is drawn after **every** stage we can hook (RAINFX_IMPACT_SPLASH
  §7). The CSP windscreen rain/wiper look is part of that glass.
- The exact depth pass writes depth only on `gSolidA` and `gOver.a`. Drops,
  trails and wiped film are included. Haze is **excluded** on purpose, since
  the 2026-10-02 fix: haze writing depth erased the yellow windscreen and
  showed the asphalt.
- Result:
  - Where only haze is drawn, the later glass passes the depth test and
    draws over the haze.
  - Where trails or drops are drawn, depth stops the glass, so the trails
    lie over the wipe zone.
  - This matches the observation exactly. The draw-stage move in s32 cannot
    change it.
- In-scene there is no order in which haze comes after the glass. Any
  in-scene fix is a trade-off:
  - **Haze writes depth:** the glass is gone under the haze, so its tint and
    rain are lost.
  - **Haze writes no depth:** the glass covers the haze.

### 2b. Steering wheel and cockpit: the shot lacks the object

- The geometry shot (`sceneRoot`, near 0.10 m) does not draw the
  interior/wheel the way the main pass does. AC culls cockpit parts in
  extra shots. Behind the wheel the shot shows sky.
- Tone mode 3 compared frame depth (wheel, ~0.5 m) with shot depth (sky),
  found disagreement and fell back to the shot. The visible result was the
  shot sky with the old tone.
- `FRAME_MIN_RATIO` (s32) rejected the dark wheel against a bright shot sky
  in the same way.
- Physically, the drop should refract what is really in front of the visor:
  the wheel, in the frame.

### 2c. KN5 visor parts (< ~0.1 m)

- The frame shows the helmet band. The shot clips it (near 0.10 m), so the
  real background is unknown in both.
- This case is the only one that really needs a fill (push-pull from the
  surrounding frame, the v3.1 idea) or occlusion.
- Several v3.1 side effects (painted trails, film not recovering) were
  later traced to the 8-bit wipe-mask floor fixed in s32. v3.1 can therefore
  be re-evaluated in parts, but only after the s32 and s33 tests.

## 3. v4 rules implemented in s33

### Rule 1: directional disagreement (tone mode 3)

| Case | Meaning | Source |
|---|---|---|
| Depths agree, or both sky | Same surface | frame (as before) |
| Frame farther than shot | Shot has an object the frame lacks at this stage | shot |
| Frame nearer, `frameZ > NEAR_TRUST_MIN` (0.15 m) | Object the shot lacks (wheel, cockpit, hands) | **frame (new)** |
| Frame nearer, closer than that | Helmet / KN5 parts | shot (unchanged; fill is a later step) |

- The colour ratio check is skipped for the new case.
- Settings:
  - `RAIN_DYNAMIC_SHOT_TONE_NEAR_TRUST = true`
  - `RAIN_DYNAMIC_SHOT_TONE_NEAR_TRUST_MIN = 0.15` (m)
- The rule is active only at the `main.root.transparent` draw stage. At the
  track stage, root-object colour is missing from the frame (the black
  regions problem).
- Compose debug colours: blue = near frame trusted, green = frame, red =
  shot.
- UI: "Composite: trust nearer frame", "nearer frame trusted beyond (m)".

### Rule 2: optional depth for dense haze/film

- Setting: `RAIN_DYNAMIC_DROP_HAZE_DEPTH_MIN` (default 0 = off). When it is
  above 0, pixels whose final alpha reaches the value also write depth in
  the exact depth pass, so the later car glass (wipe zone) cannot cover them.
- Recommended test values: 0.5 to 0.7, so that only dense haze writes depth.
- Cost of the trade-off: no glass tint under that haze.
- UI: "Haze/film also writes depth from alpha (0 off)".

## 4. Structural fix: visor layer as a post overlay (RAINFX_VISOR_GLASS §8)

One architecture removes all three mechanisms together:

1. Render the visor mesh (same shader) into an offscreen premultiplied RGBA
   target with the main camera. Use an `ac.GeometryShot({reference, opaque,
   transparent})` whose callbacks call our `render.mesh`, plus the KN5 visor
   parts as depth occluders.
2. Composite that target after post-processing and the upscaler
   (`ui.onExclusiveHUD` full-screen `ui.drawImage`).
3. Use the final frame as the refraction source.

What this fixes:

- Glass, wipers, wipe zone, wheel and clouds are all **under** the visor by
  construction (2a).
- The source is what is really in front (2b).
- Final tone, no DLSS reprojection shake (VISOR_GLASS §8).
- KN5 parts in front are handled by the shot depth (2c, occlusion side).

What must be verified first, with a small probe:

1. That a GeometryShot callback can run our `render.mesh`.
2. Which texture holds the final frame at HUD time, and that it excludes
   our overlay (no feedback).
3. Full-screen coverage of `onExclusiveHUD`.

## 5. Test request for s33

1. Turn on compose debug in the wheel-in-front view. The wheel area should
   be **blue**, and the drops in front of it should show the wheel and
   interior, not the old sky.
2. Raise "Haze/film also writes depth" to 0.6. The wipe zone should go
   under the dense haze. Check how much windscreen tint is lost.
3. Report both results. Rule 2 decides whether the in-scene trade-off is
   acceptable, or whether the overlay probe (§4) should go first.

## 6. s33 result and s34 changes (user, 2026-10-03)

### Result

1. Wheel in front of the **windscreen**: the red wheel texture is shown
   correctly inside the drops. Rule 1 works.
2. Wheel in front of the **dashboard**: still hidden.
3. With haze off, the wheel shows normally there.
4. Over the windscreen a trail bends the wheel itself. Over the dashboard,
   a passing trail erases the wheel and a smeared dashboard frame appears.
5. Correction to §2a: the haze **was** drawn correctly over the
   windscreen area.
6. The thin water film (cleared-path film, not the WF trail) lives far too
   long.

### Reading

- Points 2–4 share one cause. The haze colour and the trail refraction both
  sample the composite source. Over the dashboard the source still came
  from the shot, which shows the dashboard **without** the main-pass wheel.
- The shot's cockpit differs from the main one (LOD or culled wheel), so the
  depth rules land in "agree, partly" or "shot nearer" instead of rule 1.

### Fix 1: frame priority (`RAIN_DYNAMIC_SHOT_TONE_FRAME_PRIORITY = true`)

- At `main.root.transparent` the frame holds every opaque object. It is now
  used wherever it has colour and lies beyond `NEAR_TRUST_MIN` (0.15 m).
- The shot only fills the helmet / KN5 range.
- Trade-off: the drops lose the car-glass tint that the shot's transparent
  pass gave in shot-chosen texels.
- UI: "Composite: frame priority". Turn it off to compare.

### Fix 2: thin film lifetime (`RAIN_DYNAMIC_TRAIL_MASK_FILM_SECONDS = 1.0`)

- The film used mask G directly, so it shared the wipe recovery time
  (`TRAIL_MASK_SECONDS` 3.11).
  - Visible while G > 0.04: about 3.3 s.
  - With fp16 the tail is now real: the 8-bit mask used to stall instead.
- No new channel is needed. G = 0.95·exp(−3t/T_wipe), so
  (G/0.95)^(T_wipe/T_film) = exp(−3t/T_film). The film fades with its own
  T_film, while micro clearing and haze recovery keep T_wipe.
- UI: "Thin film lifetime (seconds)".

### Open

- §2a: the wiper/wipe-zone order is unconfirmed after the correction in
  point 5.

## 7. s34 result: cockpit (F1) camera with CSP Extra FX (user, 2026-10-03)

### Observations

- In the free camera everything now looks solved.
- In the F1 (cockpit) camera, meshes still appear **without texture**
  inside our layer (haze, trail refraction, drops):
  - the whole steering wheel;
  - the front of the car (bonnet).
  - The pattern suggests the parts that carry the car's livery.
- Turning off CSP **Extra FX** fixes it. The wipers are then also covered
  correctly by the haze. The cost is SSLR, fog blur and other effects.
- While driving, the parts become correct for short moments.
- The gloves (driver model) are correct even in the cockpit camera: haze
  and trails show their real white texture.

### Reading: the focused car is drawn LATER in the cockpit camera with Extra FX

All points fit one cause. With Extra FX in the cockpit camera, CSP draws the
focused car's own meshes (wheel, bonnet, wipers, cockpit) in a pass **after**
our drop callback. Their depth may already exist (pre-pass or G-buffer), but
their final colour is not in `dynamic::hdr` yet.

- **Source.** The frame copy has depth there but dark or untextured colour.
  s34's frame priority, and rule 1, deliberately skip the colour check, so
  they now trust exactly that wrong colour. The s32 `FRAME_MIN_RATIO` was
  guarding this case. In the free camera the car is drawn earlier, so it
  is fine there.
- **Order.** The later car pass draws over haze-only pixels, which have no
  depth, so the wiper appears over the haze. Pixels where the depth pass
  wrote depth (drops, trails) block it, so the trails lie over the wiper.
  This is the §2a mechanism, but for the car's own meshes, not for car
  glass.
- **Gloves.** The driver model is not part of that late pass, which is why
  it is correct.
- **Brief correct moments.** CSP's ordering or splitting of the cockpit
  draw changes, or the async copy timing shifts.

### s35

Rule 1 and frame priority now also work when the drops are drawn at
`main.smoke` (`RAIN_DYNAMIC_DROP_DRAW_AT_SMOKE_DEBUG = true`, needs a reload).
smoke is the latest in-scene stage. Whether the focused car is complete
there in the cockpit camera is the open question.

### Test (F1 camera, Extra FX on)

1. Run the stage probe (source 1 hdr, then 3 depth). In which stage is the
   steering wheel/bonnet present **with texture**?
2. Set `RAIN_DYNAMIC_DROP_DRAW_AT_SMOKE_DEBUG = true` and reload. Are the
   wheel and bonnet correct inside haze and trails, and does the haze now
   cover the wipers?

### Decision

- If smoke contains the textured car: keep drawing at smoke. Rain streaks
  are no longer a reason against it, because the drops refract the shot
  composite (IMPACT_SPLASH §7).
- If no stage contains it: no in-scene stage can fix the order. Only the
  post overlay (§4) can, so it becomes the next step.

## 8. Stage probe in the F1 camera with Extra FX (user, 2026-10-03)

### Results

1. **HDR.**
   - Every stage shows the same pattern.
   - `main.root.transparent` is **always black**. It also runs **after**
     `main.smoke` (order 6, smoke is 5). This differs from the free camera.
   - All other stages show the wheel/bonnet in their real colour only during
     the "good" stretches, and all together.
2. **Depth.** Wheel and bonnet are present at every stage, in good and bad
   stretches alike.
3. **Regularity.** The good stretches are at fixed places on the circuit and
   repeat exactly every lap (3 laps observed).
4. **Smoke stage.** `DRAW_AT_SMOKE_DEBUG = true` changes nothing. The wipers
   are still not covered.

### Conclusion

- In the cockpit camera with Extra FX, the focused car's colour (wheel,
  bonnet, wipers: the livery meshes) is **not** in `dynamic::hdr` at any
  stage we can hook. Its depth is.
- The final colour is produced later, in a pass we cannot hook. This is
  most likely a split near/far rendering of the cockpit: the black
  root.transparent after smoke points to a separate near pass with its own
  target.
- Track-position regularity fits a CSP decision that depends on the place:
  lighting zones, reflections or LOD.
- No in-scene stage can therefore deliver either:
  - the refraction source for these meshes; or
  - the correct order (haze over the wipers).
- **The post overlay becomes the required path** (`RAINFX_POST_OVERLAY.md`).

### Consequences for the current path

- In-scene, the source for those texels can only come from the shot. The
  shot lacks the livery or cockpit too, which gives the untextured look.
- s34's frame priority and rule 1 remain correct for the free camera.

## 9. Correction: the missing wheel/bonnet is a game issue (user, 2026-10-03)

The missing steering wheel and bonnet meshes in the F1 camera with Extra FX
**reproduce with the RealVisor app removed entirely**. This is CSP/game
behaviour, not caused by our pipeline, and it is **out of scope**. No further
work on it.

### What this changes in §7–8

- The "black / untextured HDR at every stage, correct at fixed track
  places" pattern is the game's own render state. Our stage probe recorded
  it faithfully, and the stage-probe facts themselves remain valid.
- The conclusion "post overlay is *required* for the cockpit camera" is
  withdrawn. The overlay (RAINFX_POST_OVERLAY.md) stays an **option** for
  its other benefits:
  - layer above everything (wiper order);
  - no DLSS reprojection;
  - final-frame tone.

  It is no longer forced by this issue.

### What stays as is

- §3 rule 1 (trust a nearer frame) and s34 frame priority. They fixed the
  free-camera wheel and dashboard case, which was ours.
- s34 thin film lifetime.
- Defaults are unchanged:
  - in-scene path;
  - `RAIN_VISOR_OVERLAY = false`;
  - `RAIN_DYNAMIC_DROP_DRAW_AT_SMOKE_DEBUG` as set by the user.

### Test rule from now on

Before attributing a render artefact to RainFX, compare with the app
removed (or with RainFX disabled), at the same place on the track.
