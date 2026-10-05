# Trail flow and anti-chrome tone (2026-10-01)

Status: implemented. DXC (ps_6_0) compiles:

- the main drop shader;
- the GPU position-state shader with `RAIN_MERGE_CODE` and
  `RAIN_WETPATH_CODE`;
- the trail decay shader.

The Lua block/bracket check passes. v1 has been reviewed in game; **v2 (§v2
below) has not been seen in game yet.**

## Request (user, after the v3 spray review)

Exclude the spray techniques (v1 covering pattern, v2 noise, v3 wave sim) and
first match the basic drop trails to CSP.

The user reported three problems:

1. **Chrome look.** The CSP drop close-up shows processing that keeps
   contrast from getting too strong.
2. **Lumpy trails.** When many particles flow fast, the trail fragments
   make a lumpy surface. This is the biggest source of unrealism.
3. **No shared path.** The film left by fast drops should be one water body
   flowing along a path, not bumps.

References:

- In-game shot of our trails: `스크린샷` / close-up with a texel grid and lumps.
- CSP close-up: soft, low contrast.
- CSP at rain 0.60 / 1.00 / 1.00 with strong wind:
  `images/trail_flow/csp_r100.png`, `images/trail_flow/csp_wind_r100.png`.
- Real visor footage: `바이저물수막실제사례.mp4`.

## What CSP does (from the references)

- **Tone.** A drop's interior stays close to the background tone. It shows a
  soft, slightly darker upper edge and a slightly brighter lower part. There
  is no mirror-like full-contrast scene. Even in heavy rain the visor reads
  as "the same scene, a bit rippled".
- **Trails with wind.** Drops run diagonally. They leave thin, straight,
  continuous, faint water lines and elongated drops. There are no beads or
  lumps along fast paths, and later drops visibly reuse earlier lines.

## Causes found in our code

| symptom | cause |
|---|---|
| Rectangular grid in drops and trails | Slope taps are 1 head-mask texel (1/2048) apart. On the bilinear 1024 trail canvas that is half a texel, so the slope is constant per trail texel and the refraction shows the texel grid. |
| Chain of bumps on fast paths | Each frame a sheet segment is one dome stretched along the motion (`1 - (along/ax)² - (across/ay)²`). At high speed the segments are longer than the drop radius, so the path becomes a row of domes. |
| Lumpy, beaded film | Noisy per-pixel decay (`TRAIL_NOISE`, ~5-texel cells) breaks films into beads. Nothing levels them. |
| Chrome | The refracted scene is used at full contrast. Edge loss and glint add more contrast on top. |
| Every drop makes its own lane | Nothing couples a drop to existing wet tracks. |

## Changes

1. **Spray off by default.** `RAIN_DYNAMIC_SPRAY_ENABLED = false`. The code
   is kept, and v3 is gated by the same flag.

2. **Anti-chrome tone limiter.** HLSL `rainWaterToneBg/Compress/Clamp`. It is
   used by the water-field heads and trails and by the micro water lens
   (`rainWaterLensColor`).
   ```
   bg     = shot(sceneUV, TONE_BG_MIP) (sky-corrected)   # what lies behind the drop
   color  = bg + (refracted - bg) * TONE_CONTRAST         # before edge loss and glint
   ...edge loss, glint, veil (unchanged)...
   L      = clamp(L, bg_L * RATIO_MIN, bg_L * RATIO_MAX)  # final luminance window
   ```
   - The dark top crescent and the bright lower rim survive, inside the ratio
     window.
   - Cost: 1 extra mip tap per covered pixel, plus 1 depth tap with sky
     correction.

3. **Slope step of at least one trail texel.**
   ```
   gDynamicDropWFNormalStep = max(NORMAL_STEP_TEXELS / birthSize, GRADIENT_TRAIL_TEXELS / trailSize)
   ```
   The slope becomes piecewise linear (continuous), not constant per texel.
   Heads get a 2-head-texel step, which is slightly smoother.

4. **Ribbon sheets** (`SHEET_RIBBON`).
   - A fast-flow segment is drawn exactly from the previous point to the
     current point. It uses an 8×64 ribbon kernel (`h = 1 - v²` across,
     constant along).
   - Consecutive segments abut, so the path is one continuous film.
   - A round cap is drawn only where a path starts.

5. **Surface-tension levelling** (`TRAIL_DIFFUSE`, default 0.05).
   - The trail decay pass adds an explicit 4-neighbour diffusion step on all
     channels, so the R/G and B/G codes are preserved. It is clamped to 0.25,
     the stability limit.
   - Bumps of about 5 texels level out within a few frames, and neighbouring
     tracks merge into one film.
   - Too high values widen and thin tracks below the threshold. 0.20 erased
     most fast trails in the prototype.

6. **Wet-path steering.** `RAIN_WETPATH_CODE` in the position-state shader,
   cfg `RAIN_GPU_STATE_WETPATH_*`.
   - The shader reads last frame's trail canvas (`txRainWetPath`, trail UV =
     `(u, v + 1)`, the same mapping as the stamps).
   - Only the slope component across the motion is applied:
     `v += (∇G - (∇G·d)d) * GAIN * dt`, for drops faster than `MIN_SPEED`.
   - Later drops slide into earlier wet lines (rivulets). There is no braking,
     and a drop's own trail behind it is symmetric.
   - The code is straight-line, with no branches or loops. It is a separate
     define, like the merge code, because of the earlier FXC stack overflow
     (`RAINFX_COALESCENCE.md`). If the game crashes in D3DCompiler on load,
     set `RAIN_GPU_STATE_WETPATH_SHADER = false` first.

## Prototype

`tools/trail_flow/trail_proto.py` simulates 9 diagonal fast drops on a
256-texel trail crop over a synthetic scene: 40 frames with noisy decay and the
same lens rule.

`images/trail_flow/before_after.png` compares three settings:

| panel | setup | result |
|---|---|---|
| left (old) | dome segments, half-texel slope step, no tone limiter | broken, high-contrast black/white streaks: chrome |
| middle | ribbon, D 0.05, tone on | soft, continuous, low-contrast lines |
| right | ribbon, D 0.10, tone on | softer still, but trails fade sooner |

`tools/trail_flow/stateshader.py` extracts a Lua-embedded state shader with a
stub cbuffer for DXC.

## Defaults

- Tone: CONTRAST 0.50, RATIO 0.55–1.45, BG_MIP 4.5.
- Trails: TRAIL_DIFFUSE 0.05, SHEET_RIBBON on, GRADIENT_TRAIL_TEXELS 1.0.
- Wet path: SHADER on, ENABLED on, GAIN 0.6, MIN_SPEED 0.004.
- `RAIN_DYNAMIC_SPRAY_ENABLED = false`.

## In-game checks (UI section "Trail flow and anti-chrome tone")

1. **Grid.** The rectangular texel grid on drops and trails must be gone.
   Compare with "Slope step (trail texels)" at 0.
2. **Chrome.** Toggle the tone limiter. Drops should keep the dark top and
   light bottom but no longer show a sharp, contrasty mirror image.
   - Too flat or invisible: raise CONTRAST toward 0.7, or widen the ratio
     window.
   - Still chrome: lower CONTRAST, or lower RATIO_MAX toward 1.25.
3. **Fast paths.** Driving at 150–250 km/h, fast drops should leave
   continuous, smooth lines with no row of bumps.
   - Lines too short or faint: raise `TRAIL_SECONDS` or lower `TRAIL_DIFFUSE`.
   - Still beaded: lower `TRAIL_NOISE`. The user tuned it earlier for slow
     tracks.
4. **Rivulets.** Following drops should merge into existing lines.
   - Drops zig-zag or stick: lower the wet-path gain.
   - No effect: raise it to 1.5–2.
5. **Cost.** The trail pass adds 4 taps on 1024². The state pass adds 4 taps
   on 3072×1. The main shader adds 1–2 taps on covered pixels.

## Next (status 2026-10-05)

- Tune the amount (spawn rate and sizes) against the CSP 0.6 and 1.0
  references — **open**, belongs to the final tuning pass (and R1).
- Decide whether the spray layer returns on top of matched trails —
  **closed**: the spray film was removed 2026-10-02 (`RAINFX_SPRAY.md`).
- The wipe still does not clear the trail canvas (`RAINFX_WATER_FIELD.md` §6)
  — **open, verify** in the current build (the wipe mask was fixed in s32,
  haze/smear trail clearing exists, but the WF trail canvas itself is not
  cleared by the wipe mask).

## v2 (2026-10-01): size-aware tone, glints back, separate micro, large-drop look

**v1 review (user)**

- Good: the trail grid and the lumps are gone. In dark areas a slightly milky
  flow shows. The user applied tuning to the existing path (trail mask)
  feature: FILM_OPACITY 0.11, FILM_PIXELS 2.6, RIDGE_OPACITY 0.22.
- Problems:
  1. GPU drops without enough size render as one flat colour.
  2. Glints are needed but everything is too flat. Outlines practically
     vanished.
  3. The micro pattern looked better before. It needs to be separable for
     A/B tests.
  4. Large drops should blur their whole inner scene into a "low-res",
     imperfect image with a soft boundary. In the CSP close-up the drop
     carries light, but the inner image is not clean and the edge is soft.
     Our GPU drops still show the high-resolution image when zoomed in.

**Causes**

1. **Flat small drops.** v1 set the slope step to one trail texel (1/1024),
   which is two head texels, for every pixel. On a 3–5 texel head that central
   difference smears the dome, so the slope comes out small, there is almost
   no refraction, and the drop shows its own background. The tone
   compression then pulled that flat colour further toward the background.
2. **No outline or glint.** The final luminance clamp ran after edge loss and
   glint, so the dark rim and the glint were squeezed back into the
   0.55–1.45 window.
3. **Micro.** v1 put the limiter into the shared `rainWaterLensColor`, so it
   reached the micro water lens.
4. **Sharp interior.** The interior mip was only `SCENE_MIP + slope`, the
   same for every size.

**Changes**

1. **Per-source slope step.**
   - The centre tap reads head and trail separately. The winner picks its
     own step: `gDynamicDropWFHeadStep` = NORMAL_STEP_TEXELS / birthSize,
     `gDynamicDropWFTrailStep` = GRADIENT_TRAIL_TEXELS / trailSize (at least
     the head step).
   - Heads are back to the pre-v1 step, so small domes are not smeared.
   - The trail grid fix is kept. Tap count is unchanged (5 + 1).
2. **Tone limiter v2.** `rainWaterToneLimit(color, bg, weight)` is applied to
   the refracted scene only, before edge loss and glint. The outline and the
   glint therefore survive.
   - The weight is `smoothstep(TONE_SMALL_PX 4, TONE_LARGE_PX 20, radiusPx)`.
     Small drops keep their contrast and read through it. Large drops get
     the full contrast compression and ratio window.
   - The final clamp is removed.
3. **Micro separated.**
   - The micro water lens applies the limiter only when
     `RAIN_DYNAMIC_WATER_TONE_MICRO` is on. The default is off, which equals
     the micro look before trail flow v1.
   - The older micro optics stay available through the existing
     `RAIN_DYNAMIC_MICRO_WATER_LENS` toggle.
4. **Large-drop look.** `largeW = smoothstep(LARGE_START_PX 8, LARGE_FULL_PX
   30, radiusPx)` drives three effects:
   - **Blur:** `wfMip += LARGE_BLUR_MIP (1.5) * largeW` gives a low-res inner
     image.
   - **Warp:** the sample is offset by an irregular value-noise warp in cells
     of `LARGE_WARP_CELLS (0.6)` drop radii, `LARGE_WARP_PIXELS (4) * largeW`
     px. This gives the imperfect, not-clean inner image.
   - **Soft edge:** the silhouette height band widens by `LARGE_EDGE_SOFT
     (0.10) * largeW`. A constant height band is a constant fraction of the
     radius, so the softness is size-proportional.
   - Debug: "Water field debug" = 3 shows `largeW` (red = large, green =
     small).

**Cost.** Same taps as v1, plus 2 value noises on covered pixels.

**v2 checks**

1. **Small drops.** Small GPU drops must show an inverted interior, a dark
   top edge and a lower glint again, not a flat disc.
   - Still flat: lower `TONE_SMALL_PX` or `TONE_LARGE_PX`, or check that
     `NORMAL_STEP_TEXELS` is 1.
2. **Glint and outline.** Rims and glints are back.
   - Too strong again (chrome): raise the limiter's effect by lowering
     `TONE_LARGE_PX`, or lower WF `GLINT` and `EDGE_LOSS`.
3. **Micro.** Toggle "Tone limiter on micro water lens" for A/B. Off is the
   earlier look.
4. **Large drops.** Use debug 3 to confirm which drops count as large, then
   tune the size window `LARGE_START/FULL_PX`. Large drops should show a
   blurred, slightly broken image with a soft edge.
   - Too mushy: lower `LARGE_BLUR_MIP` or `LARGE_WARP_PIXELS`.
   - Edge too vague: lower `LARGE_EDGE_SOFT`.

## v3 (2026-10-01): tone limiter back to v1, micro switch kept

**User review of v2.** In the flowing areas the chrome look is hard to solve
with the v2 limiter. The user asked to keep the micro (small drop) switch and
return to the previous tone limiter.

**Changes**

- **Heads and trails** use the v1 rule again, at full strength for every
  size:
  - compress toward the background before rim loss (`TONE_CONTRAST`);
  - clamp the luminance window (`RATIO_MIN/MAX`) at the end, after edge
    loss, glint and veil.
- **Removed:** the v2 size weighting (`TONE_SMALL_PX`, `TONE_LARGE_PX`,
  `rainWaterToneLimit`).
- **Kept:** `RAIN_DYNAMIC_WATER_TONE_MICRO` (default off). When it is on, the
  micro water lens uses the same v1 rule: compress before the rim, clamp at
  the end.
- **Also kept from v2:**
  - the per-source slope step (head step for heads, trail step for trails);
  - the large-drop look (`LARGE_*`: extra blur, warp, soft edge);
  - debug 3.

**Lesson (user observation).** The flowing areas need the full limiter,
including the end clamp. With size weighting and no end clamp, the rim loss
and glint on thin trails (small radius codes) brought the chrome look back. If
small heads look flat again, address it outside the limiter: raise `GLINT`,
or adjust the ratio window.

## Pipeline check after the v3 revert (2026-10-03)

### User observations (reverted code = v3)

1. "Painted" trails appear after a session of toggling and fine-tuning:
   wipe paths, WF trail, haze, smear, KN5 part visibility. A reload fixes
   it. It is hard to reproduce; first seen in the free camera.
2. After (1), the **thin water film** and the **narrow ridge** in wiped
   paths no longer fade away after their seconds. They stay, and over
   time they paint over the whole visor. Their stepwise drawing also looks
   too fast or jerky.
3. Wipers and similar parts are drawn **after** the haze.
4. In the interior view with haze off, some areas (glove, car glass rim,
   steering wheel) render black or broken, exactly like the HDR probe
   thumbnails. In the free camera they are fine.
5. Those areas become normal or vanish within a very short distance from
   the camera.
6. The brightness jump when entering the cockpit also happens without the
   visor, so it is engine behaviour.

### Findings and fixes

**(2) Wipe mask could not decay: 8-bit quantisation (fixed).**

- The wipe mask (`trailMaskA/B`) was `R8G8B8A8.UNorm`, decayed by ×`decay`
  every frame.
- In 8 bit, `round(v × decay) == v` as soon as `v < 0.5 / (1 − decay)`.
  At 60 fps with `TRAIL_MASK_SECONDS` 3.11, decay = 0.984, so every value
  below about **31/255 (12 %) never decays**. The film threshold is 0.04,
  so the film and ridge stay forever, and every new stamp adds to the
  floor.
- Longer seconds or a higher frame rate raise the floor (about 40 % at
  10 s). That is why it "always" appears after tuning sessions.
- **Fix:** the canvas is now `R16G16.Float` (only R and G are read), with an
  explicit cutoff at 0.004.
- **Smoother drawing:** `TRAIL_MASK_MAX_STAMPS` goes from 64 to 384 per
  frame. With about 2k drops, each drop was re-stamped only every
  ~0.5 s, as long straight segments.

**(3) Root objects drawn over the haze (stage change).**

- The drops were drawn at `main.track.transparent`. The stage probe shows
  that the wipers, cockpit and driver are drawn later, so they land on
  top of the haze.
- **Now** `RAIN_DYNAMIC_DROP_DRAW_AT_TRACK = false`, which means
  `main.root.transparent`. A **Lua reload** is required, because the stage
  is chosen at load. If rain streaks show inside the drops at this stage,
  set it back.

**(4), (5) Black regions.**

- With tone mode 3 at the track stage, the frame has **depth but not yet
  the colour** of root objects (glove, wheel, glass rim). The depth agreed
  with the shot, so their missing (black) colour was used.
- This also explains why haze on or off changes their look, and why they
  go normal within the very short range where the shot (near 0.10 m) and
  the frame stop agreeing.
- **Fixes:**
  - the draw-stage move above, since the frame then contains those
    objects;
  - a **colour sanity check**: a frame texel is rejected when it is more
    than `FRAME_MIN_RATIO` (0.25) times darker than the shot.

**(1) Painted trails after toggling.** The most likely cause is the same
pair:

- the source picking up undrawn (black or stale) frame texels, as in (4);
- the wipe-mask floor, as in (2), weakening the haze and film rules
  across the visor.

If it still appears after this build, note which toggle came last.


## Thin water film lifetime (s34, 2026-10-03)

The cleared-path thin film (wipe mask G channel, not the WF trail) used the
wipe recovery time directly (`RAIN_DYNAMIC_TRAIL_MASK_SECONDS`), so it stayed
visible ~3.3 s, and after the s32 fp16 fix its tail really decayed (the 8-bit
mask used to stall). The film now has its own lifetime without a new channel:

- G decays as `0.95 · exp(−3t / T_wipe)` (stamp 0.95, per-frame decay
  `exp(−dt · 3 / T_wipe)`, cutoff 0.004).
- The shader remaps `filmG = 0.95 · (G / 0.95)^(T_wipe / T_film)` =
  `0.95 · exp(−3t / T_film)`, i.e. the film fades with `T_film` while micro
  clearing and haze recovery keep `T_wipe`.
- Config: `RAIN_DYNAMIC_TRAIL_MASK_FILM_SECONDS` (default 1.0; uniform
  `gDynamicDropTrailFilmAgeExp` = T_wipe / T_film). UI: "Thin film lifetime
  (seconds)". Source: `RAINFX_NEAR_OBJECTS.md` §6.
