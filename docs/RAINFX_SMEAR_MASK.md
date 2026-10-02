# Smear mask: fingerprint-like turbid patches (2026-10-01)

Status: implemented behind `RAIN_DYNAMIC_SMEAR_ENABLED` (default `true`).
This is the procedural **test** version. DXC (ps_6_0) compiles the main
shader and the Lua block/bracket check passes. **Not yet seen in game.**

## Context

The flow layer (`RAINFX_FLOW_LAYER.md`) was **rejected** after the in-game
test. Problems:

- The debug view showed the sheet channel filled almost everywhere, even
  with fast drops.
- The normal view was a coarse dot pattern over the whole screen.
- Seen this close to the visor, even 1024² cells stand out.
- It was far from the intended look.

It is now off by default (`RAIN_DYNAMIC_FLOW_LAYER_ENABLED = false`). The
code stays until this approach is confirmed, then it can be deleted.

## Request (user redirection after close observation)

1. Place a masking pattern of irregular shapes, painted here and there,
   over the whole area. Build it in code for the test; if the technique
   works, replace it with a hand-made texture.
2. The fill is not a solid colour. It is a noise fill, as if a fingerprint
   had been pressed once, so only parts show, finely and faintly.
3. The existing pattern drops should also look quite blurred. A little fine
   noise outside the masked areas should affect the overall image quality.
4. Drops and trails crossing the mask are removed or mixed turbid by the
   mask density (turbidity to be tested). The noise makes this evaluation
   irregular, so it reads as foam.
5. Micro drops inside the mask follow the same rule.
6. The whole mask shows more as an intensity rises and is gradually removed
   as it falls. A trigger and debug views are needed.
7. Important: inside the mask, trails cannot wipe the micro pattern clean.
   Wipe strength drops sharply and recovery becomes dramatically faster.
   Whether the trail film fully covers the noise still needs testing.
   Result: drops and film flow on a clean visor as something blurred,
   noisy and foam-like.

## Design (`rainSmearEval`, evaluated once per visor pixel in `main`)

```
blob mask M  = smoothstep(t ± SOFT, fbm3(uv * MASK_CELLS + warp * MASK_WARP))
               t = 0.80 - 0.65 * MASK_COVERAGE * intensity    # more blobs as intensity rises
fill F       = lerp(1, sat(ridged(uv * FILL_CELLS + warp)^3 * patch(uv * FILL_PATCH_CELLS) * 1.6),
                    FILL_CONTRAST)                            # fingerprint ridges, revealed in patches
base B       = ridged(uv * BASE_CELLS)^4                      # faint specks everywhere
density D    = sat(M * F * MASK_STRENGTH + BASE * B)
turbid C     = lerp(shot(pixel, SMEAR_MIP), fogColor, SMEAR_VEIL)
```

`M`, `D` and `C` are kept in static globals, so the haze and micro helpers
reuse them without evaluating again.

**Threshold.** Measured with the same noise in numpy: median 0.46, std
0.15, p99 0.76. So `t = 0.80` shows almost nothing. At coverage 0.55 and
intensity 1, about 43–55 % of the visor is covered, depending on the region.

| what | rule | request |
|---|---|---|
| Heads and trails (water field) | `color = lerp(color, C, TURBID * D)`, `alpha *= 1 - REMOVE * D`. Switchable with `SMEAR_ON_TRAILS`. | 4 |
| Micro drops (lens path and legacy path) | `visibility *= 1 - REMOVE * D`, colour mixed toward C by `TURBID * D` | 3, 5 |
| Bare glass (haze and gap pixels) | `rainHazeEval` now composites the smear itself, `alpha = D * VISIBLE`, over the haze | 2, 3 |
| Wiping | trail-mask clearance `× (1 - WIPE_BLOCK * M)`, for micro disks, the film branch's disk test and haze wipes | 7 |

**About request 7.** The wipe coverage is scaled down inside the blobs
instead of changing the trail-mask decay. Its effect is equivalent: a weak
wipe crosses the visibility threshold much sooner, so wiped micro drops
reappear almost at once there. This keeps the trail-mask shader untouched.

**Trigger.** `smearUpdate`:

- Target is `max(SMEAR_INTENSITY, rain * RAIN_GAIN)`.
- It is smoothed with ATTACK 2 s and RELEASE 6 s, and advanced once per
  frame.
- The UI shows "Smear level".
- For a manual test, set `RAIN_GAIN` to 0 and drive `SMEAR_INTENSITY`.

**Debug.** "Smear debug" values:

- **1:** red = blob mask, green = density.
- **2:** density in grey.

**Prototype.** `tools/smear_mask/smear_proto.py` renders the same functions
over a synthetic scene at about 2700 px per visor UV.
`images/smear_mask/prototype_intensity_05_10.png` shows intensity 0.5 at the
top and 1.0 at the bottom: the shaded scene on the left, debug colours on the
right. Irregular blobs grow with intensity, their fill shows fingerprint
ridges in patches, and the smear is faintly visible on bare glass.

## Defaults

- **Trigger:** `RAIN_GAIN` 1, ATTACK 2 s, RELEASE 6 s.
- **Blobs:** MASK_CELLS 5, WARP 0.6, COVERAGE 0.55, SOFT 0.06, STRENGTH 0.9.
- **Fill:** FILL_CELLS 420, PATCH_CELLS 40, FILL_CONTRAST 0.85.
- **Base noise:** BASE 0.18, BASE_CELLS 700.
- **Effect on water:** REMOVE 0.55, TURBID 0.65, ON_TRAILS true.
- **Turbid colour:** VISIBLE 0.35, MIP 5, VEIL 0.35.
- **Wiping:** WIPE_BLOCK 0.85.

## Cost

Smear-enabled visor pixels pay 9 value-noise evaluations and 1 high-mip shot
tap, plus 1 depth tap with sky correction. When intensity is 0, BASE is 0 and
debug is off, a uniform branch skips all of it. No texture or pass is added.

## In-game checks (UI: "Smear mask" under Trail flow)

1. **Debug 1.** Raise the intensity from 0 to 1. Blobs should appear and
   grow, and shrink again slowly as it falls (RELEASE). Green should show
   fingerprint-like partial fill inside the blobs and faint specks outside.
2. **Normal view.**
   - Drops and trails crossing a blob turn partly turbid and foam-like.
   - Micro drops inside a blob are faint and blurred.
   - Outside, everything is slightly degraded by the base noise.
   - Too strong: lower `REMOVE`, `TURBID` or `BASE`. Not visible: raise
     `VISIBLE` or `MASK_STRENGTH`.
3. **Wiping.** Inside blobs, fast drops should no longer clean the micro
   pattern. Outside, wiping is unchanged.
4. **Trail film test (open question 7).** Toggle `SMEAR_ON_TRAILS` to compare
   films that keep or hide the smear noise.
5. **Scale.** The fill is too coarse or too fine at the helmet view distance:
   change `FILL_CELLS` and `BASE_CELLS`.

## Next

- If the technique works, replace `rainSmearEval` with a hand-made texture:
  R = blob mask, G = fill noise, B = base noise. That needs a texture slot,
  for example the `txDynamicWeatherScreen` share as before.
- Coupling the trigger to lead-car spray or speed.

## v2 (2026-10-01): mask actually removes water; every path follows it

### In-game review of v1 (intensity 1, debug 1: red = blob, green = density)

The trigger worked: "Smear level" rose and fell smoothly, and the red blobs
grew and shrank with intensity, while the outside (shown dark/blue) did the
opposite.

| path | v1 result |
|---|---|
| green density | did not act as a zone: micro and GPU drops were neither hidden nor re-toned |
| WF trail | not attenuated in green, not hidden in red, and still erased micro and haze everywhere |
| micro clearing path | correct: hidden in red, weaker in green, normal in blue |
| thin film in cleared paths | correct |
| narrow liquid ridge | not hidden in red, not attenuated in green, still wiped a little |
| overall | the scene looked the same as without the smear |

### Causes

1. **Weak effect.** The effect used only the density
   `D = M × fingerprint fill`. That fill is sparse (ridge³ × patch, mean
   ≈ 0.15), so D stayed small and the alpha and colour changes were barely
   visible. The turbid colour is the blurred background, so a weak mix just
   looks like the same drop.
2. **Heads and trails:** a removed or faded WF pixel still returned early,
   so it showed the bare scene instead of the micro pattern beneath. That
   reads as "the trail wipes the micro".
3. **Haze clearing:** the water-trail haze clearing (`HAZE_TRAIL_CLEAR`) was
   not blocked by the mask.
4. **Narrow ridge:** the ridge channel (trail mask R) was neither blocked nor
   removed.

### Changes

- **`rainSmearEval` returns four values:**
  - `mask` (blob coverage);
  - `effect = sat(mask × STRENGTH × lerp(1, evalN, 0.5 × FILL_CONTRAST) + base)`,
    a balanced, strong value inside the blobs;
  - `visual`, the fingerprint film drawn on bare glass (as before);
  - `evalN`, the balanced ridge noise.
- **Noisy removal.** `removeOn = REMOVE × effect > lerp(0.15, 0.95, evalN)`.
  Inside blobs about 44 % of pixels are removed (REMOVE 0.8). The survivors
  follow the fingerprint ridges, which gives the foam look. Outside, nothing
  is removed: base × REMOVE ≤ 0.18 × 0.8 = 0.144, below the 0.15 threshold
  floor.
  Map: `images/smear_mask/removal_map_intensity_10.png`.
- **Every path uses the same rule:**
  - WF heads and trails: a removed pixel skips the WF branch and falls
    through to the micro pattern, haze and smear. Survivors are mixed toward
    the turbid colour by `TURBID × effect`. Toggle: `SMEAR_ON_TRAILS`.
  - Trail-mask film and narrow ridge: skipped on removed pixels. Ridge
    coverage is also scaled by `1 - WIPE_BLOCK × mask`.
  - Micro drops (both optics): a removed pixel shows haze and smear. The
    others get the turbid mix.
  - Haze: both the wipe and the water-trail clearing are scaled by
    `1 - WIPE_BLOCK × mask`.
- **Debug:**
  - 1: red = mask, green = effect;
  - 2: effect in grey;
  - 3: removal map (white = removed, dark red = mask).
- **Defaults changed:** REMOVE 0.55 → 0.80, VEIL 0.35 → 0.45.

### v2 checks

1. **Debug 3.** The blobs should show white fingerprint-like removal with
   survivors in ridges, and none outside them.
2. **Normal view.**
   - Drops, WF trails, films and ridges inside blobs break up and turn
     turbid, and the micro pattern and haze stay visible beneath them.
   - Outside the blobs, everything behaves as before.
   - Too much removed: lower `REMOVE`. Survivors not turbid enough: raise
     `TURBID` or `VEIL`.
3. **Trail film test.** Toggle "Smear also on drops/trails" and compare.

## Texture contract v1 (superseded)

The first contract (R = blob order with bright first, G = visible
fingerprint film, B = survival noise, A = base noise) is replaced by §v3.
The templates under `images/smear_mask/template/smear_mask_template_*` follow
the old contract and are kept only for reference.

## v3 (2026-10-02): user design: density trigger, R reveal order, G blend

**User correction.** The design does not show the fingerprint pattern; it
shows only the fingerprint pattern's region. The visible film on glass and
the noisy removal (v2) are therefore gone.

### Trigger model (Lua `smearUpdate`, per frame)

```
air      = car.velocity - wind                    # incoming air, world, m/s
           wind = sim.windVelocityKmh (vec2) taken as game-space (x, z) km/h, /3.6
A        = rain intensity (engine, or RAIN_GPU_STATE_RAIN_OVERRIDE)
B        = |air| [km/h] / REF_KMH                 # density amplification
density  = A * B
trigger  = TRIGGER_OVERRIDE or density >= TRIGGER
facing   = max(0, dot(sim.cameraLook, normalize(air)))^FACING_POWER
reveal   = REVEAL_OVERRIDE (>= 0) or (trigger ? min(1, density / FULL) * facing : 0)
level    = smoothed reveal (ATTACK 2 s up, RELEASE 6 s down)
```

- **TRIGGER vs FULL.** The user's formula divided by the trigger value
  itself: `min(1, density / trigger)`. That would be 1 as soon as the effect
  triggers, which makes reveal a step. So the trigger (0.30) and the
  full-reveal density (0.90) are separate settings. With 150 km/h airspeed
  as amplification 1, rain 0.6 at 150 km/h gives density 0.6 and reveal 0.67
  when facing the air.
- **Facing.** Driving forward, the air comes from the front, so facing ≈ 1.
  It falls when looking sideways and in crosswind.
- **Unverified: wind axes.** The x/z mapping of `windVelocityKmh` is an
  assumption. With a strong crosswind, facing should drop when looking
  downwind. If it rises instead, the axes or the sign are wrong.
- **Readouts (UI):** rain, airspeed, amplification, density, trigger state,
  facing, target, level, and texture state.

### Texture contract v3

- **Format:** square, 2048² recommended, RGBA8 PNG, linear data (no sRGB or
  colour profile).
- **UV space:** visor UV, the same as the micro pattern.
- **File:** `RAIN_DYNAMIC_SMEAR_TEXTURE`, default `texture/smear_mask.png`
  relative to the app folder.
- **Fallback:** if the file is missing, or "Use mask texture" is off, a
  procedural stand-in with the same R/G meaning is used.

| ch | meaning | rule |
|---|---|---|
| R | **Reveal order.** Low values appear first. | region = `R <= level`, with a soft band `EDGE_SOFT` around the front. At level 0 nothing shows; at level 1 everything shows. Paint value 255 where the effect must appear last. |
| G | **Blend degree inside the region.** | **Micro drops:** visibility = `lerp(1, G, region × MICRO_HIDE)`, so low G hides them and high G keeps them, mixed turbid by `MICRO_TURBID × region × G`. **GPU drops (heads and trails):** turbid by `DROP_TURBID × region × G`. Low G keeps them clear and sparkling. **WF trails:** opacity × `(1 - TRAIL_WEAKEN × region × G)`. The weakened trail is composited over the micro pattern and haze beneath, so it does not wipe them; the haze clearing under trails is weakened by the same factor. **Micro clearing paths, thin film, narrow ridge:** coverage × `(1 - PATH_WEAKEN × region × G)`. |
| B | undecided (unused) | |
| A | undecided (unused). Keep it 255, because some editors drop RGB where A = 0. | |

**Trace at the region border.** It comes from the contrast between sharp,
sparkling micro drops outside and G-modulated, turbid ones inside. A hard
or noisy R edge makes a sharper trace; `EDGE_SOFT` softens it.

**Template.** `images/smear_mask/template/smear_mask_v3_template_2048.png`
(also R and G alone) is the procedural stand-in baked to this contract.

- **Reveal coverage:** level 0.25 → 9 %, 0.5 → 32 %, 0.75 → 59 % of the area.
- **Install:** copy it to `texture/smear_mask.png` to test the texture path.

### Implementation notes

- **Texture slot.** The texture shares the `txDynamicWeatherScreen` slot.
  Priority: spray wave, then flow layer, then smear texture, then weather
  screen. Spray and flow layer are both off by default.
  `gDynamicDropSmearTexture` is 1 only when the slot really holds the mask.
- **Compositing.** A weakened WF trail is stored in `gOver`. Every lower-layer
  return (haze or clip, trail film, micro lens and legacy micro) composites it
  with `rainOver()`. At rain 0 the micro block now returns haze or clip
  instead of `clip`, so a pending trail still draws.
- **Removed:** `MASK_COVERAGE`, `MASK_STRENGTH`, `FILL_CONTRAST`, `BASE*`,
  `REMOVE`, `TURBID`, `ON_TRAILS`, `VISIBLE`, `WIPE_BLOCK`, `INTENSITY`,
  `RAIN_GAIN`.
- **Debug:** 1 = region (red) and region × G (green); 2 = raw R; 3 = raw G.

### v3 checks

1. **Trigger chain.** In heavy rain, raise speed and watch density cross
   TRIGGER. The trigger must turn ON and the level rise. Turn the head
   sideways: facing and level fall.
2. **Region.** With debug 1 and "Reveal override" 0 → 1, the region grows
   from the low-R areas.
3. **Micro.** Inside the region, micro drops show only where G is high and
   look turbid there. Outside they stay sharp. The border reads as a trace.
4. **Drops and trails.** In high-G areas, drops look turbid and trails weak,
   with the micro pattern visible through them. In low-G areas, drops stay
   clear and sparkling.
5. **Paths.** Micro clearing paths, thin film and ridge are weaker in
   high-G areas.

## v4 (2026-10-02): fixed region rules, drops over micro, fixes

The smear mask is now the confirmed approach for the high-speed water film.
The spray film and flow layer were removed (see those documents).

### User review of v3

- Region detection: correct.
- Trails should not use G. Inside the region they get a fixed strength and
  composition.
- Drops do not mix with the micro pattern; they stay as crisp as before.
- The texture looks dry; it is hard to see a fluid flow.
- The readout showed `trigger ON facing 0.42 target -0.00 level 0.00`.

### Changes

- **Reveal override fix.** The slider at "-0.00" counted as `>= 0` and forced
  the reveal to zero. There is now an explicit checkbox, "Reveal override
  on", plus a value slider from 0 to 1.
- **Facing diagnosis.** At 162 km/h the facing was only 0.42. The likely
  cause is the wind axes or the cameraLook pitch. The UI now shows car km/h,
  the raw wind vector, and the facing without wind, and adds a wind-axes
  mode:
  - 0: ignore wind;
  - 1: (x, z), the default;
  - 2: (x, −z);
  - 3: (−x, −z).
  If the facing without wind is about 1 and drops with wind, try the other
  modes.
- **Fixed region rules.** Region is the R mask, without G. G is still used
  for the micro pattern and for head turbidity.

  | water | inside the region |
  |---|---|
  | WF trail | opacity × `(1 − TRAIL_FADE 0.55)`, turbid by `TRAIL_TURBID 0.45`, `+TRAIL_BLUR 1.5` mip, composited **over** micro and haze |
  | WF head | opacity × `(1 − HEAD_FADE 0.30)`, composited over micro and haze; turbid by `DROP_TURBID × G` (as before) |
  | Micro clearing path, thin film, narrow ridge | coverage × `(1 − PATH_WEAKEN × region)` |
  | Haze clearing under trails | × `(1 − TRAIL_FADE × region)` |

  Heads composited over the micro pattern answer "drops do not mix". The
  blurred, faded trails laid over the noisy micro pattern are meant to read
  as water flowing over it.
- **Removed:** `TRAIL_WEAKEN` (it was G-based).

## v5 (2026-10-02): water mixes instead of fading

**User review of v4.** The intended blending works. But lowering the water
by a fixed strength makes it look dry. Trails should mix with each other the
way the GPU drops do, so the flow stays visible.

**Change.** Inside the region, water (WF trails and heads) keeps its full
alpha, so silhouette, rim and glint stay. Its colour is mixed with the
layer beneath (micro and haze):

```
waterRgb = lerp(waterRgb, beneath.rgb, MIX * region * beneath.a)
out      = over(float4(waterRgb, waterAlpha), beneath)
```

- `TRAIL_FADE` is renamed to `TRAIL_MIX` (0.55), and `HEAD_FADE` to
  `HEAD_MIX` (0.35).
- `TRAIL_TURBID`, `TRAIL_BLUR` and `DROP_TURBID × G` are unchanged.
- The haze clearing under trails inside the region is reduced by
  `TRAIL_MIX`.
- Ghosting with the smear on: see `RAINFX_IMPACT_SPLASH.md` §7 (depth pass,
  motion stencil).
