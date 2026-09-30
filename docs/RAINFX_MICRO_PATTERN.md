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
