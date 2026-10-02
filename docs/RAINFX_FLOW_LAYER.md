# Flow layer: inferred CSP layer structure and our copy (2026-10-01)

> **REMOVED (2026-10-02).** The flow layer code, config, uniforms and UI were deleted from `realvisor.lua` and `rainVisorDynamicDrop.hlsl`. The high-speed water film is now built on the smear mask (`RAINFX_SMEAR_MASK.md`). This document is kept as a record only.

Status: implemented behind `RAIN_DYNAMIC_FLOW_LAYER_ENABLED` (default
`true`). Both new shaders compile with DXC (ps_6_0): the flow-layer update
shader embedded in Lua, and the main drop shader. The Lua block/bracket check
passes. **Not yet seen in game.**

## Inputs

**References**

- `CSP RAINFX 물흐름 레퍼런스.mp4`
- `CSP RAINFX 물흐름 레퍼런스 거품 처리 및 지워내기 등.mp4`
- Crops: `images/flow_layer/csp_*.png`.
- A close-up of square-ish pixel cells.

**User observations**

1. A micro pattern (fixed).
2. A random pattern that erases the micro pattern.
3. Water flow that erases both the micro pattern and the random pattern.
4. Drops change shape as they move. Parts of a drop turn white like foam,
   either from where it passes or from a mask.
5. Scenes that look like sand being swept away.

## What the footage shows (inference)

| observation | what is visible | most likely mechanism |
|---|---|---|
| Blocky, square-ish cells at erased and flow boundaries; "sand" sweeping | Boundaries step on a fixed grid of roughly 4–8 screen px. Cells flip on and off individually as a front passes. | A **low-resolution state texture in visor UV**, sampled with **point filtering** and thresholded against a **per-cell random value** (dissolve). As the stored amount rises or falls, cells flip one by one. When the field is advected, the cells appear to stream, which reads as sand. |
| Micro pattern disappears in irregular blotches | Patches of fine condensation vanish without a moving drop, then slowly come back. | A **random "erase" channel** in the same state texture. Rain hits write random values into it, and it decays as the glass re-wets. |
| Large flowing areas clear everything | Smooth, transparent, slightly distorted regions move down and across. Micro, erase blotches and haze are all gone inside them. | A **sheet-water channel**, fed by drop trails and rain, **advected by the flow**. It is drawn as its own layer over the pattern. |
| Parts of drops and sheets turn milky white | White patches are concentrated at advancing water fronts and fast flow, on top of normal refraction. | A **foam channel**, generated where the sheet amount changes steeply (fronts) and moves fast, then decaying. Drops and sheets blend toward a bright fog tone where foam exceeds the per-cell threshold. |
| Drops keep changing shape | Silhouettes deform as they cross wet and dry areas. | Drop silhouettes come from a union field. Ours already does this (water-field heads, trails, merges). |

All of this needs only **one small ping-pong canvas**, one cheap pass per
frame, and a point-sampled read in the drop shader. That fits the low cost
CSP shows, and the blockiness is a side effect of that cheapness.

## Our structure

Our existing layers map onto the observations:

| CSP layer | ours |
|---|---|
| 1. Micro pattern (fixed) | Micro pattern v2 (baked). Unchanged. |
| 2. Random erase | **Flow layer G** (new) |
| 3. Water flow erasing 1 and 2 | **Flow layer R** (new) sheet. The water-field trails and trail-mask wipe still clear as before. |
| 4. Shape-changing drops, foam | Water-field heads plus **flow layer B** foam (new) |
| 5. Sand sweep | Point-sampled flow layer plus per-grain dissolve (new) |

**Canvas.** `RAIN_DYNAMIC_FLOW_LAYER_SIZE` (default 256²), RGBA16F, visor UV
with the trail-canvas mapping `(u, v + 1)`. It is updated in onSceneReady
right after the water-field trail update.

```
flow    = meanDropVelocity * FLOW_GAIN * (1 - var + 2 var n1) + perp * (n2 - .5) * var
          # speed-weighted mean of moving drops (readback, every 4 frames, smoothed)
src     = uv - flow * dt                                  # semi-Lagrangian advection
R sheet = (R(src) + trail.g * TRAIL_FEED * dt
           + rain * RAIN_FEED * dt * noise(uv - ∫flow)) * exp(-dt / SHEET_SECONDS)
           # rain patches travel with the flow
G erase = max(G(src), smoothstep(sheet ≈ threshold), randomHit(rate * dt * rain))
          - ERASE_RECOVER * dt
B foam  = B(src) * exp(-dt / FOAM_SECONDS) + FOAM_GAIN * dt * front(|∇R|) * speed * sheet
```

The pass costs 6 taps plus a few hashes and noises on 256².

**Drawing** (`surfaceMicroPattern` block, sampled once per pixel)

- **Sampling.** `PIXEL = true` reads the state with point sampling, which
  gives CSP's blocky cells. Each grain has its own hashes (`grain`,
  `grain2`); `GRAIN_SCALE` sets grains per texel.
- **Sheet.** A pixel is covered when
  `sat((R - SHEET_THRESHOLD) / SHEET_SOFT) > grain`.
  - It is drawn after the water-field heads, so drops stay on top. It hides
    the micro pattern and the haze.
  - Shading (`rainFlowSheetColor`): slope from the R gradient, then
    refraction (`SHEET_REFRACTION_PIXELS`), blur (`SHEET_MIP`), the
    anti-chrome tone limiter, veil, foam, and alpha `SHEET_ALPHA`.
- **Erase.** A micro disk is hidden when `G > grain2`. The haze remains.
- **Foam.** Where `B > grain2`, heads and sheets blend toward
  `fogColor * FOAM_BRIGHT` by `FOAM_MIX`.
- **Debug.** "Flow layer debug" shows the raw state (red sheet, green erase,
  blue foam).

**Texture slot.** No 12th texture is added. The flow layer shares the
`txDynamicWeatherScreen` slot (`#define txDynamicFlowLayer`), as the spray
wave did. The spray wave wins if it is active, so the flow layer is off
while the spray wave runs (spray is off by default).

**Prototype.** `tools/flow_layer/fl_proto.py` runs the same equations in
numpy on 256² for 1, 3 and 6 s at rain 1, with 14 moving drops as the trail
stand-in. Output: `images/flow_layer/prototype_layers.png`.

- Grey dots: micro stand-in.
- Blue: sheet.
- White: foam.

The result shows rain-fed sheets drifting with the flow, with granular
("sand") edges, micro erased beneath them, foam at the fronts behind moving
drops, and micro recovering after a sheet passes.

## Defaults

| group | values |
|---|---|
| canvas and sampling | SIZE 256, PIXEL true, GRAIN_SCALE 2 |
| flow | FLOW_GAIN 0.8, MIN_SPEED 0.004, SMOOTH 0.5 s, VARIATION 0.6, VARIATION_CELLS 9 |
| sheet feed and life | TRAIL_FEED 3, RAIN_FEED 0.2, SHEET_SECONDS 1.6, SHEET_THRESHOLD 0.35, SHEET_SOFT 0.3 |
| erase | ERASE_RATE 0.04, ERASE_RECOVER 0.2 |
| foam | FOAM_GAIN 2, FOAM_SECONDS 0.6, FOAM_MIX 0.55, FOAM_BRIGHT 1.05 |
| sheet look | SHEET_ALPHA 0.55, SHEET_MIP 3, SHEET_REFRACTION_PIXELS 10, SHEET_SLOPE 6, SHEET_VEIL 0.1 |

## In-game checks (UI: "Flow layer" under Trail flow)

1. **Debug view.**
   - The readout `Flow …` must show the mean drop flow, and its direction
     must match where drops run.
   - Red sheet areas should grow behind moving drops and in heavy rain, and
     drift with the flow.
   - Green erase spots should appear randomly and fade.
   - Blue foam should appear at sheet fronts.
2. **Sand.** With blocky cells on and GRAIN_SCALE 1–2, sheet and erase edges
   should break up into flipping cells that stream with the flow.
   - Too coarse: raise `SIZE` or `GRAIN_SCALE`.
   - Too clean: set `PIXEL` on and GRAIN_SCALE 1.
3. **Coverage.**
   - Too much sheet: lower `TRAIL_FEED` or `RAIN_FEED`, shorten
     `SHEET_SECONDS`, or raise `SHEET_THRESHOLD`.
   - Micro erased too much: lower `ERASE_RATE` or raise `ERASE_RECOVER`.
4. **Foam.** White patches should be partial and short-lived.
   - Too white: lower `FOAM_MIX` or `FOAM_GAIN`.
5. **Unverified assumption: flow sign.** The flow uses the readback velocity
   directly in canvas UV, with the same mapping as the trail stamps. If
   sheets drift opposite to the drops, set `FLOW_GAIN` negative
   (the slider allows -3..3).

## Not done / next

- Wipers do not clear the flow layer yet. The trail-mask G could be fed in.
- The flow is one global mean with noise. A per-region flow (e.g. a coarse
  flow grid from the drop readback) would let sheets follow local curvature.
