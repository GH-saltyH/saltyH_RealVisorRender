# Micro pattern v2: dense strata, varied radii, outline rims (2026-09-30)

Status: implemented; supersedes the requirements in
`RAINFX_MICRO_PATTERN_NEXT.md`. **Not yet seen in game.** The bake shader and
the draw shader compile with DXC. The bake runs once at load, so bake-time
settings need a Lua reload.

## Bake (`realvisor.lua`, micro pattern canvas, blend Opaque)

- **Strata:** `STRATA` = 4. Each stratum is a jittered grid with a 3×3 search,
  so there are up to 36 candidates per texel.
  - Presence: stratum 0 `FIRST_PRESENCE` 0.55, the others `PRESENCE` 0.80.
  - Radius per disk: 0.35–0.85 cells (`RADIUS_MIN/MAX`). The largest reach
    (0.45 jitter + 0.85) stays inside the 3×3 search.
- **Gate (rain order):** `(stratum + hash) / strata`. Light rain shows only
  stratum 0 as sparse whole drops; heavy rain fills in all strata.
- **Priority = 1 − gate.** The disk that appears first stays on top. Later
  disks only show where uncovered, as crescents, half-moons and dots.
  - Rising rain therefore never cuts a hole into a visible disk, which the
    old "later layer wins" priority would do with per-stratum gating.
- **Outline ring:** the winner keeps a ring `RIM_CELLS` = 0.07 cells wide
  (fixed width in cells) classified as outline. It is no longer punched to the
  background, so boundaries between fragments stay visible.
- **Encoding:**
  - RG = the winner's lens-local coordinates (unit disk).
  - B = gate (4 bit) · 16 + radius (4 bit).
  - A = class: 1 interior, 0.5 outline, 0 empty.
- **Prototype:** `images/micro/v2_bake_rain_025_06_10.png` (colour per disk,
  outline dark), rain 0.25 / 0.6 / 1.0.

## Runtime (`rainVisorDynamicDrop.hlsl`)

- Class, gate and radius are **point-sampled**. Crisp texel steps are
  intentional (the low-res trick). Lens coordinates stay bilinear.
- Disk centre for the wipe and the inversion uses the decoded per-disk radius,
  not the old fixed 0.56 cell.
- Outline pixels use the same optics, darkened by `OUTLINE_DARK` 0.45 (UI:
  "Micro outline darkening"), with half the light accent.
- The highlight rim band moved to `smoothstep(0.70, 0.95, r)`, since interiors
  now reach r ≈ 0.8–0.9.
- The wiped-film branch uses the same decode. Haze composites under disks,
  outlines and film.

## Checks

1. **Micro debug:**
   - Rain 0.2: sparse whole disks with light outlines.
   - Max rain: a dense field of crescents, half-moons and dots, where every
     boundary is a continuous light line.
2. **Normal view, zoomed:** blocky low-res fragments. **Normal distance:**
   glitter and shading without a visible grid.
3. **Bake time at load:** with the 12288² canvas this is roughly 5 G candidate
   tests in one pass. If the load hitches or the driver resets, lower
   `MICRO_PATTERN_TEXTURE_SIZE` (8192 is also in the fallback list).

## In-game result 1 and changes (2026-09-30)

User result:
- Tears: good.
- Haze: now recovers after wipes.
- Micro v2 read as **one merged chrome sheet**.

Reference (CSP capture): many overlapping small lenses, each showing its own
inverted image, separated by thin **invisible** cut lines.

Causes:
1. The v2 outline ring was drawn refracted and darkened (0.45). That gave
   visible dark lines everywhere, and the fragments' images blended into one
   texture.
2. The canvas was 12288² for a ~546-cell grid, about 22 texels per cell. That
   is smooth and high-resolution; the legacy low-res trick came from 2048,
   i.e. 3.75 texels per cell.

Changes:
- **Invisible cut line (default):** the winner's outer ring is now a gap that
  shows the unrefracted scene or haze, like the legacy punched rim.
  - Its width is fixed in **pattern texels**: `RIM_TEXELS` 0.6, so it stays a
    crisp, sometimes broken, sub-2-texel line at any disk size.
  - `OUTLINE_DARK > 0` optionally restores a darkened refracted ring.
- **Pixelation:** the texture size follows the grid,
  `size = grid × TEXELS_PER_CELL`, default 3.75 (the legacy look). The fixed
  `TEXTURE_SIZE` 12288 is no longer used.
- **Live tuning UI (Water field section → "Micro pattern bake"):**
  - disk diameter (mm)
  - pixelation (texels per cell)
  - cut line (texels)
  - strata
  - presence (first and other strata)
  - radius min/max
  - The current size and grid are shown.
  - Any change re-bakes the pattern and the micro normals 0.4 s after the last
    edit. The re-bake runs in `onSceneReady`, not in the UI callback.

## Status after fine-tuning (2026-10-01)

The user fine-tuned the bake values in game and committed them to Git as a
known-good state. The low-resolution, dotted cut edges proved visually very
effective, and careful tuning produced convincing overlapping lines.

## Question: do micro disks use the head optics? No, until now (2026-10-01)

The user observed that removing the legacy rotation parameter leaves the
image un-inverted. That is correct.

| | heads (water field) | micro disks (legacy) |
|---|---|---|
| lens input | height-field slope `∇G · radiusPx` (dimensionless, points to centre) | disk-local offset `centerDelta` in screen UV |
| mapping | `sceneUV + slope · REFRACTION`: looking past the centre inverts the image by construction | `centerUV + rotate(centerDelta, IMAGE_ROTATION 165°) · IMAGE_SCALE · inwardProfile`: inversion exists **only** through the ~180° rotation |
| blur | `SCENE_MIP + SLOPE_MIP·|slope|` | fixed `MICRO_LAYER_SCENE_MIP` |
| rim | energy loss by slope + sky glint on the lower rim | additive blue-white relief/rim accent from baked normals and light |

A/B added: `RAIN_DYNAMIC_MICRO_WATER_LENS` (UI "Micro optics: head lens
rule").
- When on, each micro disk (and each crescent fragment, which keeps its own
  disk's lens coordinates) uses **exactly the head rule**:
  - The analytic dome is `h = 1 - (r / KERNEL_SCALE)²` in visor UV, the same
    profile as the head kernel.
  - Its gradient is mapped to screen through the UV Jacobian and multiplied
    by the projected radius.
  - It then goes through the shared `rainWaterLensColor()`: refraction, slope
    blur, edge loss, glint and sky correction.
- It has no rotation parameter.
- Extra controls:
  - "Micro lens refraction" (× WF field, default 1.0)
  - "Micro lens slope scale" (default 1.0)
- The invisible cut lines, haze compositing and wipe visibility are
  unchanged.
- Legacy stays the default until the user confirms, because of the known risk
  that the head rule reads metallic on dense fields.

What to compare: the same view, heavy rain, toggled back and forth.
- Inversion must agree between micro disks and heads.
- Check whether the dense field turns chrome. If so, try a lower micro
  refraction or a higher `WATER_FIELD_SCENE_MIP` / `SLOPE_MIP`.

## Pop-in: random landing of micro drops (2026-10-02)

**Goal.** The baked pattern looks static. Making drops appear would help,
but if too many disks blink in the same frame, the bake becomes visible.
So each disk gets its own clock, and only a picked share takes part.

**Disk id.** `centre = patternUV - (pointSample.xy * 2 - 1) * radius / grid`.
This uses the *point*-sampled local offset, so every pixel of one disk agrees
on the centre. `cell = floor(centre * grid * ID_SCALE)` is hashed with a
PCG-style integer hash into three values `h0`, `h1`, `h2`.

**Schedule.**

| Step | Formula |
|---|---|
| Pick (pickup range) | `h0 < POP_PICK`. Disks that are not picked are always visible. |
| Period | `P = POP_PERIOD × (0.5 + h1)` |
| Phase | `t = frac(time / P + h2)` |
| Absent | `t < POP_OFF`: the disk is clipped, and haze shows. |
| Landing | at `t = POP_OFF` the disk appears at once, with a short flash `POP_FLASH × fog` that lasts 8 % of its life. |
| Fade | for the last `POP_FADE` of its life, visibility goes smoothly to 0. |

`time` is `state.smearTime`, which accumulates `dt` and wraps at 65536 s.

**Rate.** About `disks × PICK / POP_PERIOD` landings per second, spread
evenly over frames. With the defaults (0.35 and 9 s), about 4 % of the disks
land in any second.

**Interaction with other layers.**

- `microVisibility` is multiplied by the pop value, so it combines with the
  wipe and with the smear micro hide.
- The trail-film path treats an absent disk as no disk, so the film is
  drawn there.
- The cheap depth gate (mode 1) ignores pop-in. Exact mode follows it
  through `gSolidA`.

**Config.** `RAIN_DYNAMIC_MICRO_POP_*`:

| Key | Default |
|---|---|
| `ENABLED` | true |
| `PICK` | 0.35 |
| `PERIOD` | 9 s |
| `OFF` | 0.30 |
| `FADE` | 0.15 |
| `FLASH` | 0.25 |
| `ID_SCALE` | 1 |

The controls are in the trail-flow UI section under "Micro pop-in", with
tooltips.

**Known limit.** Two disks whose centres fall into the same id cell pop
together. If that shows, raise `ID_SCALE`. If a disk shows a seam (its
centre sits on a cell border), the fix is to bake a disk id into the
pattern. There is no free channel today: RGB is used and A holds the class.

## Legacy "scene optics" removed; turbidity review (2026-10-02)

### Removed

The micro disks keep only the head lens rule (`rainWaterLensColor`, the
former `MICRO_WATER_LENS = true`). The old mode is gone:

- **Shader:** image scale and rotation around the disk centre, visor-normal
  scene shift (`txDynamicControl`), concave profile, cap normals
  (`txDynamicMicroNormal`), angle light/shadow and rim accent. With them
  went the screen-centre reconstruction, which only that mode used.
- **Lua:**
  - the micro normal bake: a 4096² canvas with 6 mips, baked whenever the
    pattern bakes;
  - the legacy per-disk micro quads (`MICRO_LAYER_COUNT`, `MIN/MAX_DIAMETER`);
  - 12 uniforms and 2 textures;
  - the A/B checkbox and the "Micro droplets: scene optics" UI block;
  - five dead quad-debug uniforms (`DebugUV`, `HDRCopy`, `Refraction`,
    `SceneSource`, `ScreenUV`).
- **Removed cfg:** `MICRO_NORMAL_TEXTURE_SIZE/BUMP/MIP`,
  `MICRO_CONCAVE_OPTICS`, `MICRO_LAYER_COUNT/MIN_DIAMETER_MM/MAX_DIAMETER_MM`,
  `MICRO_PATTERN_IMAGE_SCALE/IMAGE_ROTATION_DEGREES/ANGLE_LIGHT/ANGLE_SHADOW/NORMAL_SCENE_GAIN/RIM_STRENGTH/EXTRA_RIM_WIDTH/SKY_CORRECTION`,
  `MICRO_WATER_LENS`, `MICRO_LAYER_SCENE_MIP`, and
  `DROP_HDR_COPY/REFRACTION/SCENE_SOURCE/SCREEN_UV_DEBUG`.
- **Kept, because the lens path uses them:**
  - `MICRO_LAYER_OPACITY` (now in the WF section as "Micro opacity");
  - `MICRO_LAYER_ENABLED`, which still gates the 10-mip shot;
  - `MICRO_WATER_LENS_REFRACTION` and `MICRO_WATER_LENS_SLOPE`;
  - `MICRO_PATTERN_OUTLINE_DARK`;
  - the WF scene mip, slope mip, edge loss and glint, shared with the
    heads.

**Check made before removing.** Every uniform the shader reads is supplied
by Lua, and Lua supplies nothing the shader does not read (script diff,
both sets empty). The cleanup in §10 removed nothing the lens path used.

### Why the micro pattern looks less sparkly (user, 2026-10-02)

The micro shader code of the lens path did not change between 10-01 and
now. Diffs s5 → s15 show only these additions: the tone floor (it applies
only when `WATER_TONE_MICRO` is on, and it is off), smear terms (region
only), `gSolidA` and pop-in. What did change is **configuration** and the
**refraction source**.

| When | Change | Effect on micro |
|---|---|---|
| between s12 and s14 (fine-tuned values in the committed build) | `MICRO_PATTERN_OUTLINE_DARK` 0.0 → **0.65** | Every disk's outline ring is drawn at 35 % brightness instead of being an invisible cut line. Densely packed disks then carry a dark mesh of rims everywhere, which looks murky. This is the most likely main cause. |
| same | `MICRO_PATTERN_STRATA` 6 → **1** | One stratum instead of six. Fewer small disks on top of larger ones, which gives larger and flatter coverage and less glitter variety. |
| s12 | `DROP_SHOT_TRANSPARENT` = true | The refraction shot now contains car glass and windscreen (tint, dirt, reflections), so the micro images get lower contrast through them. |
| s15 (user) | `visor:setDepthMode(Normal)` + `setMotionStencil(1)` on the whole KN5 | The visor glass now writes depth and uses reduced TAA. It did not help the shimmer. Remove it again to rule out depth interaction with the drop pass. |
| s15 | pop-in (35 % of disks cycle, 30 % of the cycle absent) | About 10 % fewer disks are visible at any moment. |

**Suggested A/B order:**

1. `OUTLINE_DARK` 0;
2. `STRATA` 6 (needs a reload, because it is a bake value);
3. "Refraction source: transparent pass" off;
4. remove the two KN5 lines;
5. pop-in off.

## Point reads: `Load()` instead of the custom point sampler (2026-10-02)

**Problem (latent).**

- `SamplerState samPointMicroMask { Filter = MIN_MAG_MIP_POINT; … }` is an
  effect-syntax state block. Compilers ignore it outside the effects
  framework: DXC warns "effect state block ignored", and FXC ps_5_0 drops
  it the same way.
- The sampler slot then gets whatever is bound there. With nothing bound,
  D3D11 uses its default sampler, which is **linear / clamp**.
- So the reads meant to be "point" (class A, packed gate/radius B) were
  most likely **bilinear**. At every disk border, the codes of neighbouring
  disks were blended:
  - the outline/interior class blurred;
  - mixed gate codes made a disk appear partly at the wrong rain level;
  - mixed radius codes gave a wrong lens slope on the rim.
- The same bug made the smear tiling clamp (`RAINFX_SMEAR_MASK.md`, v8 fix).

**Fix.** `rainMicroPoint(uv)` reads the texel with `GetDimensions` +
`Load(int3(texel, 0))`. That is point-exact whatever samplers are bound.
All three point reads use it:

- the cheap depth gate;
- the trail-film disk test;
- the main micro path (`patternPoint`).

DXC now compiles without the effects warning.

**Possible visible change.** Disk rims, outline rings and gate steps may
look crisper and slightly different. The class and code reads are now what
the bake intended. The local offset `pattern.xy` stays linear on purpose
(a smooth dome inside a disk).

**Other custom samplers checked.** The GPU state shaders in `realvisor.lua`
(`samPointRain`, `samPointRainMeta`, `samLinearRain`) have the same
ignored-state-block issue, but every point read there uses texel centres:
`((i + 0.5) / count, 0.5)`, or the rasterised `pin.Tex` of a count×1
target. At an exact texel centre the bilinear weights are 0/1, so linear
and point give the same value. This is not a bug today. If a read ever
moves off-centre, convert it to `Load()` as well.

**Inner image size of a micro disk.** Since the legacy mode was removed,
the image inside a disk is set by the lens rule:

- `MICRO_WATER_LENS_REFRACTION` (× the WF refraction) sets how far the disk
  looks past its centre, which is the size and inversion of the image.
- `MICRO_WATER_LENS_SLOPE` sets the dome steepness.
- `WATER_FIELD_KERNEL_SCALE` sets the dome profile, shared with the heads.

A dedicated "image scale" can be added on top of the refraction if a
separate control is needed.
