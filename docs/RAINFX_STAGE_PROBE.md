# Stage probe: what each render stage already contains (2026-10-03)

> **Status (2026-10-05): CLOSED.** v3 (tone mode 3) adopted; v3.1 reverted;
> the probe stays as a diagnostic (`RAIN_DYNAMIC_STAGE_PROBE`, off). F1-camera
> + Extra FX results: `RAINFX_NEAR_OBJECTS.md` §8–§9 (game issue).

Purpose: find where the final-tone scene (clouds, cars, transparents) is
available, so the refraction source can be taken from the real frame
(`RAINFX_REFRACTION_SOURCE.md`). Diagnostic only, off by default.

## Context

- The shimmer inside our mesh is solved (`RAINFX_VISOR_GLASS.md` §7).
- The regional drop shake (§8) persists with the upscaler off and no other
  AA, so it is not reprojection. The user decided to leave it: it makes no
  ghosting or glitch.
- Next goal: the tone. The image the drops refract has to come at the
  final rendered tone.

## What it does

- `RAIN_DYNAMIC_STAGE_PROBE = true` (UI: Trail flow → "Stage probe").
- For each hookable stage, a thumbnail of the chosen source is copied with
  `updateSceneWithShader`, the API for mid-scene passes. The stages are
  `main.track.opaque`, `main.root.opaque`, `main.track.transparent`,
  `main.root.transparent` and `main.smoke`.
- `sceneReady (prev frame)` also copies the source in `onSceneReady` with
  `updateWithShader`, before this frame renders. It shows what the buffer
  holds from the previous frame.
- **Source:**
  - 1 = `dynamic::hdr`, shown as `sqrt(x / (1 + x))` × exposure;
  - 2 = `dynamic::screen` (LDR);
  - 3 = `dynamic::depth`, shown as `(1 − d) × 50` × exposure, so near is
    white and far is black.
- Each thumbnail shows:
  - **order**: the call sequence within the frame, which gives the real
    stage order;
  - **frame**: the frame number;
  - ok / FAIL with the error text.
- The probe callbacks are registered **before** the drop draw callback.
  In the stage where the drops are drawn (marked "[drops drawn here]",
  `main.track.transparent` by default), the thumbnail is therefore the
  frame **before our drops**.

## What to look for (please report per stage)

| Question | Why it matters |
|---|---|
| Is our **car body and cockpit** visible? | v2 tone match cut these, so the source must be taken after the root objects. |
| Are the **CSP weather clouds / storm sky** visible (not the base sunset)? | It decides whether the frame can supply the sky. |
| Are **track transparents and rain streaks** in it? | Streaks inside the refraction source would show up in the drops. |
| Is the **visor glass or the KN5** already in it? | It must not be, or the drops refract their own glass. |
| Is the HDR tone close to the final image? Compare with source 2. | It decides whether HDR needs its own tone mapping later. |
| Does depth (source 3) show the car in white and the sky in black? | Needed for the per-texel frame-first composite. |
| Do **order** numbers match the list order? | Confirms the stage sequence. |

## Decision after the probe

- **A stage has car + clouds before car glass:** take the frame copy there.
  Draw the drops at the same or a later stage, then build the frame-first
  composite with the shot as fallback.
- **The clouds appear only in `sceneReady` (previous final frame):** use
  the previous frame with a small rotation reprojection.
- **Clouds nowhere:** keep the shot plus the fog-tone veil (the current
  tuning) and look for a cloud texture API in WeatherFX.

## Cost

Five small copies per frame, only while the probe is on.

## Result (user, 2026-10-03)

The HDR thumbnails all looked very bright. That is only the preview
mapping: HDR is scene-referred, before the exposure of post-processing.
Their content, however, differs per stage:

| Stage (HDR) | KN5 visor | Our render mesh | Sky | Car wipers |
|---|---|---|---|---|
| sceneReady (prev frame) | yes | yes | yes | yes |
| main.track.opaque | no | no | no | no |
| main.root.opaque | yes | no | no | no |
| main.track.transparent (drops drawn here) | yes | no (captured before drops) | yes | no |
| main.root.transparent | yes | yes | yes | yes |
| main.smoke | yes | yes | yes | yes |

**LDR (`dynamic::screen`) is identical at every stage.** Tone and content
match what the user sees, including the special windscreen effects. So it
is the **previous frame's final, post-processed image**.

### Reading

- **LDR has the ideal tone but cannot be used in-scene as it is.** Our
  drops are drawn into the HDR buffer before post-processing. Refracting
  an already tone-mapped image there would tone-map it twice. It also
  contains our own drops and the visor, a one-frame feedback. It becomes
  the right source only with the post-upscale overlay
  (`RAINFX_VISOR_GLASS.md` §8).
- **HDR at the drop stage (`main.track.transparent`) is the right in-scene
  source.** It is this frame, has the sky, and has no drops and no car
  glass. It stays in scene space, so post-processing gives it exactly the
  tone of the rest of the frame.
- What it lacks are the root objects drawn later (wipers, and evidently
  parts of our car; v2 "cut the meshes in front"). What it has but must not
  refract is the KN5 visor, nearer than 0.1 m.
- Both can be told apart **by depth** against the geometry shot. The shot
  sees the root objects and clips everything nearer than 0.1 m.

## v3: frame-first composite (`SHOT_TONE_MODE = 3`, new default mode)

Inside the drop callback, before the drops:

1. `frameFull` (shot size, fp16) gets RGB = `dynamic::hdr` and A =
   linear depth from `dynamic::depth`. The depth is linearised with the main
   camera near/far; sky is stored as 10000.
2. The tone pass, per texel, without any ratio and without blur, picks:

   ```
   both sky                                  -> frame
   one sky, the other not                    -> shot
   rel = |frameDepth - shotDepth| / shotDepth
   agree = 1 - smoothstep(AGREE_LO 0.04, AGREE_HI 0.12, rel)
   source = lerp(shot, frame, agree × MATCH_STRENGTH)
   ```

   So the frame is used wherever it shows the same surface, and the shot
   wherever the frame shows something nearer (the KN5 visor) or is missing
   something nearer (wipers, root objects).
3. Mips are built from the composite, as in v1/v2. The blur stays
   consistent, with no halos except a soft seam where the frame and the
   shot meet.

**Switches.**

- `SHOT_TONE_ENABLED` must be on. It is currently off in the user's
  tuning, so turn it on to test.
- `COMPOSE_DEBUG` paints frame texels green and shot texels red. Look at
  them through "Preview toned source" or directly in the drops.
- `FRAME_DEPTH_REVERSED`: use it if the debug shows the sky red and near
  objects green, which means `dynamic::depth` is reversed-Z.

**Expected:**

- clouds and the storm sky, and the real HDR tone of track and background,
  both from the frame;
- the car and wipers from the shot where the frame does not have them yet;
- no blur and no cut-off meshes.

**Check the veil value.** With a frame-toned source, the fog-chroma veil
tuning (0.37) may need to be re-checked against CSP.

## v3 result (user, 2026-10-03)

**Tone is solved.** With the tone pass on and mode 3, the water tone is very
clean in all conditions: night and day, blue sky and white sky. Drops and
trails carry the full colour of the refracted image. Nothing reads as
chrome or as painted. This is considered a stable tone for all water
effects.

**Remaining problems (from the debug image: green = frame, red = shot):**

1. The KN5 parts that are **in front** (the visor's top band and frame
   regions, red in the debug) are hidden; our mesh shows over them. The
   more opaque the KN5 part, the more strongly the sky shows there.
2. In those red regions the projected sky is the **shot sky**, which lacks
   the CSP clouds, so it does not match the CSP sky next to it.

### Cause

- In those regions the frame (at the drop stage) already contains a near
  KN5 part: its depth is less than 0.1 m, closer than the shot can see. v3
  therefore rejected the frame and used the shot, hence the base sky.
- The drops did not respect that KN5 part either. They drew over it, and
  the depth pass then blocked whatever KN5 layer came later.

## v3.1 fix

**(1) KN5 in front covers the drops.** The drop shader now receives
`frameFull`, which holds the frame RGB and linear depth.

```
occl = KN5_OCCLUDE × smoothstep(0, margin, ourZ − frameZ − margin)
ourZ = dot(pin.PosC, cameraLook)        (view depth of our fragment)
```

The output alpha, `gSolidA` and `gOver.a` are all multiplied by
(1 − occl). So the drops vanish behind a KN5 part that is in front, and the
depth pass no longer writes depth there. A later KN5 or glass layer at that
spot can then draw normally.

**(2) Fill from the surrounding frame, not from the shot.**

- A fill canvas (1/4 size, 8 mips) holds the frame colour premultiplied by
  "not a near KN5 part" (frame depth > `NEAR_REJECT` 0.15 m).
- Where the frame shows a near KN5 part, the source is
  `fill.rgb / fill.a` at mip `FILL_MIP` (4). That is a push-pull average of
  the real frame around it, with the CSP clouds and tone, slightly blurred.
- The shot is still used where the frame lacks nearer root objects
  (wipers): the frame is farther there, which is the red case that stays
  correct.
- Debug colours: green = frame, red = shot, **blue = KN5 fill**.

**New keys (UI under the composite settings).**

| Key | Default |
|---|---|
| `SHOT_TONE_KN5_OCCLUDE` | 1.0 |
| `SHOT_TONE_KN5_MARGIN` | 0.004 m |
| `SHOT_TONE_NEAR_REJECT` | 0.15 m |
| `SHOT_TONE_FILL_MIP` | 4 |

**Limit.** Only KN5 parts that are already in the frame at the drop stage
are known. A KN5 layer drawn later, with the car glass and without depth,
is still blocked by our depth pass where drops are. If a band stays hidden,
test with "Drops occlude later car glass" off.

## v3.1 result: reverted to v3 (user, 2026-10-03)

**Observed with v3.1.**

- The blue (KN5 fill) regions appear, but the KN5 parts there still do
  not show *in front of* the drops. The sky is no longer cast there,
  which is a partial success.
- The haze now **covers in white** instead of settling naturally into the
  scene. The smear does the same.
- "Thin water film in cleared paths" looks wrong, and wiped values do not
  recover. This is the same symptom as the old windscreen issue
  (`RAINFX_IMPACT_SPLASH.md` §8).
- **Painted trails** are back in all non-sky regions.

The user asked to go back one step and rethink. The files are reverted
to v3: `realvisor.lua` from s29 and the shader from s26 (no KN5 occlusion,
no fill).

### Analysis for the next attempt (v4)

1. **The painted trails come from v3 itself, not v3.1.**
   - The green (frame) region also covers everything *through the car
     windscreen*. At the drop stage the frame has **no car glass yet**:
     glass is drawn after all stages. So no windscreen tint, dirt or
     reflections are in it, while the final image has them.
   - The shot, built with its transparent pass, contained the glass. That
     is why non-sky water looked right before. Trails now show an
     un-tinted world over a tinted one, which reads as paint.
   - **v4 rule:** take the frame **only where both the frame and the shot
     are sky**. That is the original goal: CSP clouds and the real sky.
     Keep the shot everywhere else.
2. **Haze and smear turning white.**
   - Both sample the source at high mips (haze mip 4.5, smear classes).
     With the frame, the sky in the source is the true HDR sky, much
     brighter than the old fog-toned sky. At those mips it bleeds over
     the ground and covers it in white.
   - **v4:** clamp the luminance of the haze and smear colour to the local
     background at a low mip, × `HAZE_TONE_MAX` (about 1.1), so the veil
     settles into the scene instead of whitening it.
3. **Film / wipe recovery broken, and KN5 not in front.**
   - v3.1 multiplied `gSolidA` by the KN5 occlusion, so it wrote less
     depth; recovering micro drops then lost their depth and the glass
     covered them (the old §8 symptom).
   - The occlusion test itself (`ourZ − frameZ > margin`) barely fired:
     the visor layers in the frame lie at about our own depth.
   - **v4 option:** decide by `frameZ < NEAR_REJECT` (the KN5 visor itself)
     and only *tint or hide* the drops there. Leave `gSolidA` untouched
     outside those regions, and keep KN5-region handling separate from the
     source composite.
