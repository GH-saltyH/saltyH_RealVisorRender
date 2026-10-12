# Water field: soft-kernel heads, metaball silhouettes, one refraction rule (2026-09-30)

Status: implemented behind `RAIN_DYNAMIC_WATER_FIELD_ENABLED` (default `true`).
**Not yet seen in game.** The shader compiles with DXC (ps_6_0), and a Lua
block and bracket check passes. Set the flag to `false` (UI: "Water field
enabled") to return to the legacy birth-mask optics. The birth mask then goes
back to RGBA8 by itself.

Tone V2 (`RAINFX_DROP_TONE_V2.md`) was tried and reverted by the user. Its
lessons are kept, and this design replaces it for the physical heads. The
static micro pattern is unchanged.

## 1. Research: how the CSP-style windscreen look is achieved cheaply

CSP's windscreen drop shader is not public, so it could not be read directly.
The closest documented technique is the Codrops "Rain & Water Effect" (Lucas
Bebber, 2015, `github.com/codrops/RainEffect`, `water.frag`/`raindrops.js`).
It reproduces the traits seen in the CSP captures:

| CSP observation (user notes) | Documented mechanism |
|---|---|
| Endless shape variety, merging, torn drops | Drops are **soft alpha sprites drawn into one "water map"**. The shader applies `alpha * multiply - subtract`, a threshold. Overlapping soft sprites therefore join like metaballs: merges, bridges, lobes and trails come from composition, not simulation. |
| Consistent refraction for every shape | The water map encodes a normal (RG) and thickness (B). The shader samples the scene at `pixel + normal * (minRefraction + thickness * delta)`. Offsets are large (256–512 px), so every drop shows a strongly minified, **inverted** view, and neighbouring drops agree. |
| Trails, thick film | Moving drops spawn trail droplets. Big drops erase small ones (`destination-out`). |
| Background micro pattern | A separate static droplet canvas is cleared by the paths of big drops. This project already has it (baked micro pattern + wipe). |
| Low resolution looks better | The water map is lower resolution than the screen. Bilinear edges read as natural. |
| Dark outline | A "shadow" samples the map a few px above, giving a darker band at the top edge. |

## 2. Design adopted here

Birth-mask canvas (2048², **RGBA16F** while enabled), redrawn every frame:

- `G` = union height of soft kernels (`h = 1 - r²` sprite, alpha blend). This
  is metaball-like: `a + b - ab`.
- `R/G` = radius code (head-mask texels / 32). Premultiplication by the same
  alpha makes it a **weighted local drop size**.
- `B/G` = impact energy. It brightens the rim glint of torn fragments.

Only RGB colour blending is relied on. Alpha-channel blend behaviour is not
needed.

Per head stamp (positions, radius and velocity from the existing readback plus
prediction):

1. Body kernel, mildly stretched along velocity (`MOTION_STRETCH`).
2. Tapered tail: two shrinking kernels toward the existing tail point.
3. The existing lobe and puddle circles become kernels.
4. 0–2 per-life offset kernels (seeded by slot and generation, so the outline
   does not crawl), for irregular shapes.
5. At car speed ≥ `TEAR_MIN_KMH`, during the first `TEAR_SECONDS` of a head at
   least 1.2 mm across: 3–9 radial, stretched "finger" kernels. They move
   outward and shrink, forming a torn sheet. Because a union plateau is
   nearly flat, the sheet interior is almost undistorted and only its jagged
   rim refracts and glints, as in the CSP capture.

Trail canvas (1024², RGBA16F, ping-pong, persistent):

- Each frame the previous content is multiplied by `decay^(1 + noise·(2n-1))`,
  where n is value noise. A track thins through the threshold and **breaks
  into beads** where the noise keeps water longer.
- Moving heads (speed ≥ `TRAIL_MIN_SPEED`) stamp a thinner kernel
  (`TRAIL_WIDTH` radii) just behind themselves.
- The shader uses whichever tap is higher, head or trail.

Heads must not accumulate onto themselves. A per-frame union with its own
history flattens into a plateau with a transparent centre; the prototype
showed exactly that. This is why heads are fully redrawn and history lives
only in the trail canvas.

## 3. Shading rule (identical for every shape)

```
inside  = smoothstep(thr ± fwidth(G), G)                 # silhouette
slope   = screenGradient(G) * radiusPx                   # dimensionless, points to centre
uv      = sceneUV + slope * REFRACTION * (H/W, 1)        # look past the centre → inverted
color   = shot(uv, SCENE_MIP + SLOPE_MIP * |slope|/1.5)  # cloudy, blurrier at the rim
color  *= 1 - EDGE_LOSS * smoothstep(LOSS_START, LOSS_END, |slope|)
color  += fogColor * GLINT * facing(slope, worldUp)^4 * smoothstep(0.5,1.1,|slope|) * (1+energy)
alpha   = inside * OPACITY
```

- With `h = 1 - (r/1.24R)²`, the slope is 1.3 at the visible edge for every
  radius. The rule is therefore size-independent.
- The top rim samples below (dark ground or car), which gives the dark upper
  crescent. The bottom rim samples above (sky), which gives the bright lower
  rim.
- A torn sheet or a merged pair uses the same rule on its own gradient.

## 4. Prototype evidence (offline numpy harness, `docs/tools/water_field_harness`)

`prototype_still_vs_drive.png`: top is parked, bottom is driving with torn
impacts. It shows:

- beaded, tapering trails behind moving heads;
- metaball merges ("oo" pairs);
- inverted content in every drop, with a dark top and a bright lower rim;
- a torn sheet with a clear interior and a jagged refracting rim.

The first attempt showed hollow rings because heads were accumulating (see
§2). That is fixed by the full-redraw and trail split.

## 5. What to check in game (in order)

1. **Debug 1 (height):** red = height G, green = silhouette. Heads must be soft
   domes. Merging neighbours must bridge, trails must be thin and beaded, and
   no square quad edges may appear. Square edges mean the kernel sprite alpha
   is not straight; check the `waterKernel` bake.
2. **Debug 2 (slope):** colour must rotate smoothly around each drop, with
   equal magnitude for small and large drops. Size-dependent magnitude means
   the radius code is wrong (8-bit vertex colour quantisation is expected and
   acceptable).
3. **Normal view:** every drop inverted, neighbours consistent, a dark top rim,
   a bright lower rim. `REFRACTION` sets how much of the scene a drop sees
   (0.25–0.5).
4. **Driving above 50 km/h:** fresh large heads tear into fingers for about
   0.35 s.
5. **Trails:** lifetime and bead size come from `TRAIL_SECONDS` and
   `TRAIL_NOISE_CELLS` (at a 1024 trail canvas, about 2.3 texels per cell).
6. **Cost:**
   - CPU: roughly 1–4 image quads per live head per frame, replacing
     16-segment circles. Watch app time with many live slots.
   - GPU: 5 head + 5 trail taps on covered pixels.
   - Memory: +16 MB (fp16 birth mask) + 8 MB (trail A/B).

## 6. In-game result (user, 2026-09-30)

- The shape, refracted image and highlights of moving drops all reached the
  goal, at an acceptable cost. The user committed this state to Git.
- **Tears were almost never visible, even above 150 km/h.** Diagnosis from the
  code:
  1. Finger kernels were `R × (0.15–0.40)`. For a 1.2 mm drop on the 2048
     mask (R ≈ 3.6 texels) that is 0.5–1.4 texels. Kernels that small never
     reach the 0.35 threshold on the texel grid, so they were invisible.
  2. Fingers started 0.8–1.9 R away from the body, so they were detached.
  3. They were sized from the *growing* birth stamp (0.28 → 1.0 R over the
     first 0.12 s), which made them smaller still.
  4. The window was only 0.35 s, and only about 30 % of births at rain 0.5 are
     ≥ 1.2 mm.
  The generation change coincides with the pending → alive transition (state
  shader), so the timing clock itself was correct.
- **Fix:**
  - The tear is now a spread, irregular sheet (3 kernels) with attached
    radial fingers and tip beads.
  - Pieces use the full state radius and are clamped to
    `TEAR_MIN_KERNEL_TEXELS = 1.6`.
  - Window 0.55 s, minimum diameter 1.0 mm.
  - The UI shows "WF kernels | tearing heads | km/h" for direct checking.

### Tear follow-up: the "throwing star" artifact (2026-09-30)

The tear pieces were drawn around the *moving head* every frame. After the
impact the head started to flow, and the whole torn shape travelled with it
unchanged, like a spinning throwing star. Physically, the splash fragments
are separate water that stays where it landed; only the main body moves on.

Fix:
- At the first eligible frame, the impact origin (position, full radius,
  seeds, strength, angle) is frozen per slot and generation.
- With trails on (the default), the splash is stamped **once** into the
  persistent trail canvas at that origin. It then thins and breaks into beads
  with the normal trail decay and noise. Its minimum piece size is enforced
  in trail texels.
- With trails off, the pieces are drawn at the frozen origin for the tear
  window.
- The head is never decorated with fingers.

### Impact follow-up: pressed pancake (2026-09-30)

The user found the frozen torn pattern visually poor: fixed and star-like.
The target is a pressed pancake: a wide circle that spreads, with a torn
edge and a little splatter around it, sized to the drop, with random tearing.

Historical implementation (`waterFieldTearPieces`, removed 2026-10-06 in
favour of impact splash v2; see `RAINFX_IMPACT_SPLASH.md`):
- A flat core ellipse of radius
  `P = Rf·(1.4+0.9·amount)·(0.85..1.15 per life)`.
- 14–24 small rim kernels at 0.86–1.08 P, with random angles and sizes. About
  18 % are skipped to make notches, and about 15 % are stretched into short
  tongues.
- 2–7 satellite droplets at 1.2–1.9 P.
- It spreads in 4 stamps over about 0.12 s (P × 0.625 → 1.0). The satellites
  come with the last stamp.
- Everything is stamped at the frozen impact origin into the trail canvas, so
  it then thins and beads there.
- In the offline harness, earlier ratios (a small core with long rim pieces)
  still read as stars. The final ratios read as round, torn-edged pancakes:
  `docs/images/water_field/impact_pancake.png`.

## Future direction (user, 2026-09-30)

After the micro-pattern rework is evaluated: make drops overall **blurrier
and more turbid**. There is still a slightly chrome feel, probably from the
fairly high resolution of the image inside the drops. Available knobs to try
first:
- `WATER_FIELD_SCENE_MIP` 3 → 4–5 and `SLOPE_MIP` 1.5 → 2.5.
- A lower `REFRACTION` (smaller minified field).
- A small milky lift toward the fog tone, like the haze veil.

## 7. Backlog (after the planned order)

- **[IMPLEMENTED 2026-10-01, see below] Fast-flow sheet film (user request, deferred).** Fast runs currently leave
  a noisy beaded track (the bead noise is applied at full strength). For fast
  heads, stamp a wider, lower-amplitude trail kernel and scale the decay noise
  down with the stamping speed. That leaves a thick, blurry, spray-like water
  sheet instead of beads. The speed could be stored in trail B and used in
  the decay shader: `noise *= 1 - saturate(speed / fast)`.
- Using the same refraction rule on the micro pattern.
- The wipe (trail mask G) does not clear the water-field trail canvas yet.
- The visual union is not mass transfer. True coalescence is a separate task.

## 8. Next implemented step

Haze / condensation film: see `RAINFX_HAZE.md`.

## Backlog added by the user (2026-10-01)

1. **[DONE 2026-10-01] Wipe and clear width from the drop size.** "Clear micro circles along
   drop paths" and the related wipe paths currently use a fixed width. Change
   it to the moving drop's own radius plus an additive offset, with the
   offset exposed in the UI for debugging.
2. **[IMPLEMENTED 2026-10-01, see RAINFX_COALESCENCE.md] Direction change by absorption, with the mass-merge stage.** A drop
   flowing down absorbs drops in its path and turns toward them. Slow drops
   therefore meander left and right. Plan and optimise this together with
   true mass coalescence:
   - deterministic survivor, mass/radius update in both GPU state passes,
   - velocity bias toward the absorbed neighbour.
3. **[CLOSED 2026-10-05: not important; re-open if it recurs in the latest build] High contrast outside the sky (detailed tuning stage).** It is not a
   problem in most situations. When many large drops land together, however,
   the refracted non-sky scene reads too metallic. Reserved for the
   detailed-tuning pass, together with the "blurry / turbid" direction above.

### Backlog item 1: implementation notes (2026-10-01)

The wipe mask (`updateTrailMask`, R = liquid ridge, G = wiped film) used a
fixed width:
- a line of 1.5 R and a head circle of R, with a 1.4-texel radius floor;
- a ridge of 0.75 R.

At the default 512 mask (0.67 mm per texel), almost every drop hit the floor
and drew the same width.

The path width now comes from the drop's own diameter:
- `wipe  = diameter × WIPE_WIDTH_SCALE (1.0) + WIPE_WIDTH_OFFSET_MM (0.4)`
- `ridge = diameter × RIDGE_WIDTH_SCALE (0.45) + RIDGE_WIDTH_OFFSET_MM (0)`

Both are floored to `MIN_WIDTH_TEXELS` (1.0), and the head circle uses half
the width. For a 1 mm drop at 512, the wipe is ≈ 2.1 texels, the same as
legacy, so existing tuning carries over.

UI (Trail mask section, under "Micro clearing strength"):
- scale and offset for wipe and ridge, and the minimum width;
- mask resolution (256–2048, powers of two);
- a readout of mm per texel and the mean wipe width in texels.

The drop-size dependence only becomes visible when the mask resolves drop
diameters. Raise the mask to 1024 (0.33 mm/texel) or 2048 when judging it.

### Fast-flow sheet film: implementation (2026-10-01)

The user's request from the earlier review: fast runs left a noisy beaded
track. For fast flow they should leave a thick, blurry, spray-like water
sheet instead.

Trail canvas (`waterFieldUpdateTrail`):
- **Sheet factor** `fast = saturate((speed - SHEET_START_SPEED) /
  (SHEET_FULL_SPEED - SHEET_START_SPEED))`. The defaults are 0.03 and
  0.10 UV/s. The UI shows the current maximum head speed so the thresholds
  can be set from real values.
- **Continuous segment:** fast heads stamp one stretched kernel from their
  previous trail point to the point just behind the head. That leaves no
  gaps at high speed. Teleports above 8 R (respawn, readback jump) are
  ignored.
- **Width:** `R · TRAIL_WIDTH · (1 + SHEET_WIDEN · fast)`.
- **Amplitude:** `1 - SHEET_THIN · fast`. A lower dome gives a smaller slope,
  so the sheet is a flatter film.
- **B/G = sheet factor.** Splash pieces are stamped with `SPLASH_SHEET`
  (0.35) instead of 1, so they still bead partly.

Decay pass:
- Bead noise is scaled by `1 - sheet`.
- The decay rate is scaled by `1 - SHEET_PERSIST · sheet` (0.35), so sheets
  thin smoothly and last longer.

Shading (WF branch):
- Extra mip `SHEET_BLUR · sheet` (2.0).
- A milky lift toward the fog tone, `SHEET_VEIL · sheet` (0.20).
- Heads have B = 0 except during the tear window, so the head look is
  unchanged.

Cost: one quad per moving head, as before, plus one extra division in the
decay pass.

### Sheet follow-up: transparent, blurry spray film (2026-10-01)

User request: render the fast-flow sheet as a transparent, blurry
spray-like film. The user gave a YouTube reference
(`-bpfpJrrJ2o`), but it could not be fetched from the development
environment (the proxy rate-limited it), so the change follows the request
text and the physics.

Physics: a thin sheet of flowing water has no steep contact line, so there is
no dark rim or glint outline. It is mostly transparent. It shows up as a
blurred, slightly milky, gently distorted view of the scene.

Changes (WF shading, all weighted by the sheet factor B/G):
- **Opacity:** `lerp(WF_OPACITY, SHEET_ALPHA 0.35, sheet)`. The live scene
  shows through. The sheet also returns before the micro pattern, so it reads
  as a cleared, wetted lane.
- **Soft silhouette:** the threshold band widens by `SHEET_EDGE_SOFT · sheet`
  (0.15), so the film fades out instead of being outlined.
- **No rim darkening:** the edge loss is scaled by `1 - sheet`, and the lower
  rim glint by `1 - 0.7·sheet`.
- The existing sheet blur (+2 mip) and milky veil (0.20) stay.
- Splash pieces (B = 0.35) become slightly softer and more transparent.
  Heads are unchanged (B = 0).

UI: "Sheet opacity (transparent film)" and "Sheet edge softness".

## 9. Water field is the only drop renderer; legacy birth optics removed (2026-10-02)

The user's instruction: drops are now centred on the water field, and the
old birth implementation that WF overrode and never evaluated is to be
removed.

**What was dead while WF was on.** WF returns before the birth branch is
reached, so none of the following ever ran:

- **HLSL:** the whole `else if (gDynamicDropBirthMaskDebug || BirthMaskOptics)`
  branch, i.e. the old birth-mask optics: image mapping and rotation, wide
  normal, relief/highlight/shadow, cyan debug.
- **Lua `updateBirthMask`:**
  - the RGBA8 canvas format;
  - the non-full-redraw path (a second canvas B plus a decay pass);
  - the stamp budget and the recent-stamp budget;
  - the legacy `drawCircleFilled` / `drawLine` stamp drawing with centre
    encoding.
- **Config, uniforms and UI** that only fed those parts:
  `RAIN_DYNAMIC_BIRTH_MASK_DEBUG / OPTICS / REFRACTION_PIXELS / HIGHLIGHT /
  OPACITY / SCENE_MIP / IMAGE_* / SHADOW / RELIEF / EDGE_GAIN /
  WIDE_NORMAL / NORMAL_REACH_TEXELS / FULL_REDRAW / SECONDS / MAX_STAMPS /
  RECENT_STAMPS`, with their 16 `gDynamicDropBirth*` uniforms and 18 UI
  widgets.

**Kept, still used by WF:**

- `RAIN_DYNAMIC_BIRTH_MASK_ENABLED`, the stamp source switch;
- `ONLY`, mesh build without the old per-drop quads;
- `SIZE`;
- `BODY_STRETCH`, `BODY_LOOKBACK_SECONDS`, `BODY_MAX_RADII` (tails);
- `SHAPE_VARIATION`, `SHAPE_STRENGTH` (lobes);
- `PUDDLE_*`;
- `GROW_SECONDS`, the fresh-birth growth;
- `SKY_CORRECTION`, which `gDynamicDropBirthSkyCorrection` uses for the WF
  lens.

The canvas is always fp16 and fully redrawn every frame. Every live drop is
stamped every frame. `RAIN_DYNAMIC_WATER_FIELD_ENABLED = false` now simply
means no heads.

**Still in the files, next cleanup candidate:** the per-drop quad-head
shader (everything after the visor-surface block in `main`, from
`BirthMaskOnly` clip onward). It has had no vertices since
`BIRTH_MASK_ONLY = true`. Removing it would shrink the shader a lot, which
also lowers FXC risk. It was not removed now because its debug views
(UV/screen/scene source) are still referenced by several diagnostic flags.

### Fast-flow sheet now needs water

`SHEET_DENSITY_GATE` (default on) scales the fast-flow factor by the visor
water density, the same model as the smear mask:

```
density = rain * |car velocity - track wind| / SMEAR_REF_KMH
gate    = sat((density - SHEET_DENSITY_MIN 0.15) / (SHEET_DENSITY_FULL 0.60 - 0.15))
```

Fast drops in light rain, or with little airspeed, keep thin trails. Sheets
form only when enough water reaches the visor. UI "WF fast-flow sheet": a
checkbox and min/full sliders, with a readout of gate and density. The
density comes from the previous frame's `smearUpdate`.

## 10. Legacy per-drop quad shader removed (2026-10-02)

With §9 the water field is the only drop renderer. The quad paths were dead
code, so they are removed.

**HLSL.**

- `rainDropMain` starts with `clip(surfaceMicroPattern ? 1 : -1)`. Only the
  visor surface layer is drawn.
- Removed:
  - the legacy quad-head path;
  - the legacy micro-layer quad path;
  - the DebugUV, HDR-copy, refraction and split diagnostics;
  - the `encodedTex` / `quadTex` / local / r variables;
  - the non-surface depth clip.
- The obsolete "Stage 4A/4B" header comment is replaced by a layer
  contract.
- Size: 1582 → about 1015 lines.

**Lua.**

- 51 unused `gDynamicDrop*` values are removed from `dropMeshParams`. They
  include:
  - Sky, Orb and Wide debugs, SplitCompare, ScreenSourceCompare;
  - GeometryUVScaleA, PixelUV, RefractionPixels, Shape*;
  - MicroLayerEnabled, MicroRefractionPixels, BirthMaskOnly,
    WFNormalStep;
  - Wave*;
  - the v6 sheet values.
- Unused textures removed: `txDynamicScene`, `txDynamicScreen`.
- The legacy optical wave block is removed, together with
  `RAIN_DYNAMIC_DROP_WAVE_ENABLED`. It computed the envelope, phase and
  direction that the shader no longer reads.
- 25 dead cfg keys are removed, with their log lines.

**Debug flags kept**, because they matter for the current stage:

| Flag | Shows |
|---|---|
| WF debug 1-3 | height, slope, large-drop mix |
| Smear debug 1-4 | region, R, G, classes |
| Micro debug | micro disks |
| Haze debug | haze film |
| Trail-mask debug | trail mask coverage |
| `SCREEN_SOURCE_COMPARE`, `UV_DEBUG`, `HDR_COPY_DEBUG`, `REFRACTION_DEBUG` | Lua capture and draw-state paths |
| `IMPACT_SHAPE_*` | impact shape |

**Re-adding a quad.** Do not. New drop visuals go into the WF canvases.

**Addendum (2026-10-02, later).**

- The legacy micro "scene optics" mode, the micro normal bake and the
  legacy micro quads are removed (`RAINFX_MICRO_PATTERN.md`).
- Five dead quad-debug uniforms are removed from Lua, with their cfg keys
  and log fields.
- Shader: about 918 lines.
