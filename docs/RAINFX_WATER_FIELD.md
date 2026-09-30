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

## 6. Not done yet / next

- Fog/haze noise layer (user note 3). Planned as a static baked noise canvas
  revealed by rain intensity and wiped by the trail mask.
- Using the same refraction rule on the micro pattern, for full consistency.
  It is deliberately left untouched for now.
- The wipe (trail mask G) does not clear the water-field trail canvas yet.
- The visual union is not mass transfer. True coalescence in GPU state is
  still a separate task.
- Parameter values come from the synthetic harness scene. Absolute tone must
  be tuned in game.
