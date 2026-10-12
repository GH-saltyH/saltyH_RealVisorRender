# Smear mask: fingerprint-like turbid patches (2026-10-01)

Status: implemented behind `RAIN_DYNAMIC_SMEAR_ENABLED` (default `true`).

## Whole-visor eligibility and nose exclusion (2026-10-07)

The existing `texture/smear_mask_v7_template_2048.png` is the R/G pattern
texture, not a separate whole-visor eligibility map. Its alpha is uniformly
255. Alpha is now sampled once in non-tiled visor UV and multiplies smear
eligibility, allowing later hand-painted global exclusions without repeating
them with R/G tiling. The current texture remains unchanged.

A soft triangular nose exclusion additionally multiplies eligibility in
non-tiled visor UV. `RAIN_DYNAMIC_SMEAR_NOSE_EXCLUDE` enables it. UI controls
set centre U, tip V, half width, height and feather distance. The apex points
up, with the base below it. This masks smear, including its influence on
water color/visibility, without removing actual WF water from that region.
Use smear region debug 1 to check placement; raw R/G debug retains raw data.

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

## v6 (2026-10-02): G contrast, region water sheet, wind everywhere, tooltips

### Review

Comparison videos: `_비교용_우리프로젝트smear영역.mp4` and
`CSP_RAINFX_Smear영역물흐름레퍼런스.mp4`.

- **Ours.** The region turns turbid well, but the micro pattern and the
  drops stay round and flat. There are no highlights and nothing moves.
- **CSP.** Inside the smear, water forms merged, lobed puddles whose rims
  carry crisp light highlights and a dark embossed side, like relief. The
  shapes creep and change slowly.

### Changes

1. **Region water sheet** (`SMEAR_SHEET_*`, on).
   - Height: a domain-warped fbm in visor UV. It is advected with the
     speed-weighted mean drop flow (readback every 4 frames, smoothed,
     integrated offset) and churns slowly over time. G adds to it, so the
     outlines get dirtier.
   - Puddles: the height is thresholded by `SHEET_COVER` inside the region.
   - Slope: taken from 2 extra height taps and projected to the screen. It
     peaks at the lobe rims, which gives the embossed edges.
   - Shading: `rainWaterLensColor` (refraction, rim loss, lower glint) with
     `SHEET_GLINT` boost, then turbid by `SHEET_TURBID`.
   - Compositing: the sheet goes into the pending water layer (`gOver`).
     WF heads and trails stay on top of it, with their own mix. Micro drops
     and haze stay underneath and blend in by `SHEET_MIX`.
   - Cost inside the region: 9 value noises plus the lens taps.
2. **G processing.** `G' = sat((G - PIVOT) * CONTRAST + PIVOT)^GAMMA`, with
   defaults 1.8, 0.55 and 1.0. Applied to both the texture and the
   procedural mask, so G cuts the micro pattern more raggedly.
3. **Wind.** A shared helper, `windWorldMS` (axes per `SMEAR_WIND_MODE`),
   now feeds:
   - the smear density;
   - the GPU airflow force (`RAIN_FORCE_AIRFLOW_INCLUDE_WIND`, default on;
     air = wind − car velocity). The physics UI shows "Airflow source: car +
     track wind / car only" and the wind vector in m/s;
   - the WF sheet density gate (`RAINFX_WATER_FIELD.md` §9).
4. **Tooltips.** Hovering any smear, region or depth setting in the
   trail-flow section shows its description (`uiHelp` table).

## v7: class facets replace the region water sheet (2026-10-02)

### Review and decision

- The v6 region water sheet is **removed**. CSP does not get its flow feel
  from one sheet. It gets it from much denser, heavily overlapping drops
  and trails.
  - Removed config: all `SMEAR_SHEET_*` keys.
  - Removed uniforms: `gDynamicDropSmearSheet*`.
  - Removed code: the sheet UI, `rainSmearSheetHeight`, and the mean-flow
    readback loop in `smearUpdate`.
  - Kept: `smearTime`, now the shared clock for micro pop-in.
- **What we see in CSP** (reference images and videos):
  - Inside the noise pattern the *tone* changes.
  - Boundaries are laid down blurred, not as micro-pattern reflections.
  - The pattern is a set of a few colour classes. Each class has its own
    brightness and its own refraction image.
  - From far away it reads as noise. Close up it reads as patches of
    differently bent and toned scene.
  - The classes are erased one by one as the state changes.

### Inferred model (implemented)

G' is the contrast-processed G from v6. N is the number of classes
(`SMEAR_CLASSES`, 5). For each pixel:

1. Class position: `c = G' × N`, `k = min(floor(c), N - 1)`, `f = c - k`.
2. Per-class hash: `h = frac(sin(k·(12.99, 78.23, 37.72, 93.99) + …) × 43758.5)`,
   with the seed added to k.
3. Facet colour C(k):
   - offset `o_k = (h.xy·2 - 1) × FACET_PIXELS` render pixels: a
     different refraction image per class;
   - mip `m_k = SMEAR_MIP + (h.z·2 - 1) × CLASS_MIP_RANGE`: a different
     blur per class;
   - tone `t_k = (h.w·2 - 1) × TONE_RANGE`: a different brightness per
     class;
   - `C(k) = skyTone(scene(sceneUV + o_k, m_k)) × (1 + t_k)`.
4. Soft boundary: `colour = lerp(C(k), C(k+1), smoothstep(1 - CLASS_SOFT, 1, f))`.
   This blurs the boundary and does not draw a reflection line.
5. Faint line: on internal boundaries only, where `c` is near an integer
   in 1..N-1, the colour is multiplied by
   `1 - LINE_STRENGTH × (1 - smoothstep(0, LINE_WIDTH, d))`.
6. Erase order: `order_k = frac((k + 0.5) × 0.618034 + seed)`. The golden
   ratio gives a fixed permutation that is evenly spread.
7. Erase level: `e = max(1 - reveal / ERASE_SPAN, wipe × CLASS_WIPE)`.
   - Here `wipe` is the trail mask G at the pixel.
   - Presence is `smoothstep(e - 0.08, e + 0.08, order_k)`, blended between
     k and k+1 like the colour.
   - So when the reveal level drops below `ERASE_SPAN`, or water wipes the
     spot, the classes disappear one by one.
8. Presence multiplies the region mask `gSmearMask` (and so `gSmearK`).
   An erased class cancels every region effect there: micro hide, turbid,
   mix and path weaken.
9. `gSmearColor = lerp(colour, fog, VEIL)` is now the per-class facet
   colour. Drops, trails and micro disks turn turbid *toward their class
   facet*, so the class tone shows inside them as well (soft contrast).
10. Facet film on bare glass: in `rainHazeEval`, the facet is composited
    over the haze with alpha `FACET_ALPHA × gSmearMask × lerp(0.5, 1, G')`.
    It belongs to the veil layer, so it writes no depth
    (`RAINFX_IMPACT_SPLASH.md` §9).

Cost inside the region: 2 extra scene taps (2 more with sky correction),
plus 1 trail-mask tap when wiping is enabled.

### Config and UI

| Key | Default |
|---|---|
| `SMEAR_CLASSES` | 5 |
| `CLASS_SOFT` | 0.35 |
| `CLASS_SEED` | 0 |
| `FACET_PIXELS` | 10 |
| `TONE_RANGE` | 0.18 |
| `CLASS_MIP_RANGE` | 1.5 |
| `ERASE_SPAN` | 0.60 |
| `CLASS_WIPE` | 0.80 |
| `LINE_STRENGTH` | 0.12 |
| `LINE_WIDTH` | 0.06 |
| `FACET_ALPHA` | 0.18 |

- The controls are under "Class facets v7" in the trail-flow section, with
  tooltips.
- Smear debug 4: R = class code, G = presence, B = boundary blend.

### Tuning hints

- If it reads too much like noise from far away, lower `FACET_PIXELS` and
  `TONE_RANGE`.
- If close up it is too uniform, raise them, or lower `CLASS_SOFT`.
- If the classes vanish too early when the rain weakens, lower
  `ERASE_SPAN`.

### Texture contract v7 (2026-10-02)

v7 quantises G into classes, so **G is no longer a gradient but a patch
map**. A smooth G gradient would come out as contour bands (onion rings)
instead of patches. R keeps its v3 meaning.

**File.** Square, 2048² in visor UV (the same UV as the micro pattern),
linear data.

- Format: RGBA8 PNG, or a DDS without block compression (R8G8B8A8).
- Avoid BC1 and BC3. Their 4×4 blocks bleed between patches and create
  one-texel fringes of a wrong class. BC7 is acceptable.
- No mips are needed; the shader reads mip 0 with linear filtering.
- `RAIN_DYNAMIC_SMEAR_TEXTURE` points to it.

| ch | content | how to paint it |
|---|---|---|
| R | **Reveal order** (unchanged since v3). The region is where `R ≤ reveal`. | Large, smooth, low-frequency blobs, with values spread evenly over 0..1 (histogram-equalised). Low values appear first, and 255 appears last. Soft gradients are fine: they become the region front. |
| G | **Class patch map.** Each patch holds one flat level: the centre of a class. | Irregular cellular patches (cracked mud, dried water stains, fingerprint lobes), each filled with **exactly one** of N levels. Borders are sharp or slightly blurred (≤ 2 texels). A sparse speckle of other levels inside patches (about 2–5 % of texels, 1–3 px) reads as noise from far away. |
| B | unused, keep 0 | Reserved, for example for an explicit class id later. |
| A | 255 | |

**G levels.** The shader applies the G processing first:
`G' = sat((G - PIVOT) × CONTRAST + PIVOT)^GAMMA`, then
`class = floor(G' × N)`. Paint G so that G' falls on the class centres
`(k + 0.5) / N`.

| Settings | k=0 | k=1 | k=2 | k=3 | k=4 |
|---|---|---|---|---|---|
| Identity (CONTRAST 1, GAMMA 1), N=5 | 25 | 76 | 128 | 178 | 230 |
| Current tuning (CONTRAST 1.8, PIVOT 0.55, GAMMA 1), N=5 | 76 | 105 | 133 | 162 | 190 |

The general formula (GAMMA 1) is
`G = PIVOT + ((k + 0.5) / N - PIVOT) / CONTRAST`.

**Recommendation.** For a v7 texture, set `G_CONTRAST 1, G_PIVOT 0.5,
G_GAMMA 1` and paint the identity levels. The contrast knob then has no
effect, and the classes are exactly what you painted.

**What a level also controls.** G' is still the blend degree from v3–v6:

- micro visibility is `lerp(1, G', region × MICRO_HIDE)`;
- drop turbidity scales with `region × G'`.

So a **low class also hides more micro drops**, and a high class keeps them
and makes them turbid. Choose the area share of each class with that in
mind. A good start is about 20 % each, with slightly less of class 0 if the
region should not look too empty.

**What the classes look like is not painted.** The facet look of each class
is not in the texture. Its image offset, tone, blur and erase order come
from the class hash in the shader (`CLASS_SEED` reshuffles them), so the
texture only decides *where* each class is.

**Patch size.** Patches decide the close-up look and speckle decides the
far look.

- Visor UV 2048: patches 30–80 texels (about 1.5–4 % of the visor width).
- Smaller patches turn into noise and lose the "facet" read. Bigger ones
  look like stains.

**Borders between non-neighbouring classes.** A blurred border from k=0 to
k=4 passes through k=1..3, so a thin rim of the intermediate classes
appears. Keep these borders sharp. Use the blur only between neighbouring
levels, or rely on `CLASS_SOFT`, which already softens every boundary in
the shader.

**Template.** The generator is `docs/tools/smear_v7_template.py`. It writes
cellular patches with warped borders, speckle, a 1.5 px border blur and an
equalised fbm R:

- `docs/images/smear_mask/template/smear_mask_v7_template_2048.png` uses the
  identity levels;
- `smear_mask_v7_template_2048_c1.8.png` is pre-inverted for CONTRAST 1.8
  and PIVOT 0.55;
- `_R` / `_G` hold the single channels.

Options: `--classes`, `--cell` (mean patch texels), `--warp`, `--speckle`,
`--blur`, `--contrast`, `--pivot`, `--seed`.

## v8: everything follows G, denser pattern (2026-10-02)

### User review of v7

- Micro drops separate the G areas clearly, but WF trails and moving drops
  stay just as strong where G is low. So the trails show no region split.
- "Clear micro circle along drop path" acts *more* strongly in low-G
  areas, which is the opposite of the intent.
- **Intent:** in a weak (low-G) area, *every* feature fades by that amount.
- The pattern looks magnified compared with the windscreen, so it should be
  denser.

### Cause

From v3 to v7 only the micro drops followed G
(`visibility = lerp(1, G', region × MICRO_HIDE)`). The other features did
not:

- WF trails and heads were only tinted (turbid, colour mix), at full
  alpha;
- wipe paths were weakened *evenly* in the region (`× (1 - PATH_WEAKEN ×
  region)`).

In a low-G area the micro drops vanish, but an even wipe still clears haze
and film there. Against the emptier background, the wipe reads as
stronger.

### Rule v8: one visibility function

`rainSmearVis(hide) = lerp(1, G', region × hide)` is used for:

| Feature | Rule | Key (default) |
|---|---|---|
| Micro disks | visibility × `rainSmearVis(MICRO_HIDE)` (unchanged) | `SMEAR_MICRO_HIDE` 1 |
| WF heads (moving drops) | `wfAlpha × rainSmearVis(HEAD_HIDE)` | `SMEAR_HEAD_HIDE` 1.0 (new) |
| WF trails | `wfAlpha × rainSmearVis(TRAIL_HIDE)`, and the haze clearing under trails × the same factor | `SMEAR_TRAIL_HIDE` 1.0 (new) |
| Wipe paths, thin film, ridge, haze wipe | `clearance × rainSmearVis(PATH_WEAKEN)`: weak where G' is low | `SMEAR_PATH_WEAKEN` 0.85, meaning changed |

The turbid tint and the colour mix stay as they were. The depth pass
follows the reduced alpha through `gSolidA`. These rules are visual only,
so the GPU physics is unchanged.

### Pattern density: separate tiling for R and G

The texture is sampled twice with a wrap sampler (`samLinearWrapSmear`):

- **R** at `patternUV × SMEAR_R_TILING` (default 1.0): the region blobs
  keep their scale;
- **G** at `patternUV × SMEAR_G_TILING` (default 2.5): the class patches
  are 2.5× denser.

The procedural fallback takes the same two UVs.

**The texture must tile.** The v7 templates are now generated fully with
wrap: Voronoi with a periodic box, wrapped fbm and a wrapped border blur.
A hand-painted mask needs seamless edges, at least in G (offset filter
check).

UI tooltips: "Region: moving drops / WF trails follow G", "Mask R tiling",
"Mask G tiling".

### v8 fix: tiling ran off the visor (2026-10-02)

**User report.** With tiling above 1, the pattern drifts off to other
places. The user suspected the visor V range (-1..0).

**Check.**

- V is not the cause. `patternUV = saturate(Tex.x + 4, Tex.y + 1)`
  already maps the surface layer to 0..1, and the tiling multiplies that.
- **The real cause is the sampler.** `SamplerState samLinearWrapSmear {
  AddressU = WRAP … }` is an effect-syntax state block, and the compiler
  ignores it: DXC warns "effect state block ignored". The sampler in that
  slot behaves as clamp, so every UV above 1 read the edge texels, and the
  tiles smeared away from the visor.

**Fix.** The custom sampler is removed. The wrap is now done in code, with
`samLinearClamp` sampling `frac(patternUV × tiling)`. The only side effect
is a possible 1-texel bilinear seam at the tile borders, which is
invisible at mip 0 with a tileable texture.

**Same risk elsewhere (open).** `samPointMicroMask` is declared the same
way, so its POINT filter may also be ignored. Whether it is really
point-sampled in CSP is unverified. If micro decode artefacts ever appear
at disk borders (gate or radius codes mixing), switch those reads to
`Texture.Load(int3(uv × size, 0))` with `GetDimensions`, which is
point-exact by definition.

### Visibility feathering (2026-10-07)

R reveal and G visibility use a five-tap cross filter with 0.003 visor-UV
support (scaled by each channel tiling). Class presence transitions use a
minimum 0.15 band. Original G remains the source of facet colours, so smoothing
the hiding mask does not blur the smear class tone definitions. The alpha
eligibility and nose exclusion retain their existing soft transitions.
WF trail and impact film within smear now refract existing scene layers;
their mix sliders control refraction strength, without an added water tone.
