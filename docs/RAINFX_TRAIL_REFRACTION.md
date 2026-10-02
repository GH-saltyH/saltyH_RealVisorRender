# Trail / film refraction: from "painted" to flowing lenses (review, 2026-10-03)

## User result and request

- **Tone is solved.** Tone pass off, plus "Veil / glint fog chroma"
  0.35–0.37, matches the CSP tone. Keep these values.
- **The remaining gap.** Our trails and films only *paint* colour. They
  barely move the image.
- **The reference** is transparent. It bends the real image along the
  direction and thickness of the flowing water, like the refraction of a
  real rivulet. At edges and in places there is dramatic refraction, which
  gives volume.

## Diagnosis (code, current build)

The trail colour comes from the WF branch of `rainVisorDynamicDrop.hlsl`.

| Factor | Current value | Effect |
|---|---|---|
| Base blur `WF_SCENE_MIP` | 3.0 (≈ 8 px) | Every water texel samples a blurred image, so detail is lost: "paint". |
| `+ WF_SLOPE_MIP × slope` | up to +1.5 | more blur at edges |
| `+ WF_SHEET_BLUR × sheet` | +2.25 on fast-flow trails | trails become mip ≈ 5–6 |
| `+ SMEAR_TRAIL_BLUR × region` | +1.5 | mip ≈ 7 in the smear region |
| **Slope source** | gradient of the trail canvas G × head `radiusPx` | The trail canvas is flat-topped (stamped and diffused), so the gradient is about 0 inside a trail and non-zero only at its border. The interior is an *unshifted*, blurred copy. |
| **Slope scale** | head rule (`radiusPx` from the R/G radius code) | No relation to the trail's real width or thickness, so the refraction is either tiny or wrong. |
| **Flow direction** | not used | The image is never stretched or dragged along the flow. |

Together this is exactly "the colour is painted on, the image is not
moved". The offline prototype (`trail_refraction_proto.png`, middle
column) reproduces the look with the same three ingredients: mip 3+, near-
zero inner slope, alpha 0.85.

## Model to implement: a rivulet as a cylindrical lens

A rivulet is a thin water strip with a rounded cross-section. Seen through
it:

1. **The image is shifted toward the thick side, across the flow.** The
   offset is `o = −∇h × K`. The dome profile inverts and compresses the
   strip's background across its width, and along the flow it stays
   almost unchanged. That gives the stretched, "dragged" look.
2. **It stays sharp.** A water lens does not blur; the blur in the
   reference is only out-of-focus *distortion*. So the base mip goes to
   about 0.5–1. Blur grows only with |∇h| (curvature), not by default.
3. **Thickness varies along the flow** (surges, beads), so the distortion
   moves with the water.
4. **Edges:** where |∇h| is large, the contact angle is steep. Refraction
   jumps there (a larger offset, so a dramatic bend), energy is lost (a
   thin dark line), and the edge facing the sky gets a thin bright line.
   This is the volume cue.
5. **Thin film between rivulets:** a low thickness with a flow-stretched
   ripple, giving a gentle wavy shimmer that is sharp, not milky.

## Implementation plan (shader + small Lua part)

| Step | Change |
|---|---|
| T1 Thickness profile | Trail height `h_t = pow(G, TRAIL_PROFILE)` (about 0.5: rounded), gradient over a **wider** step (`TRAIL_GRAD_STEP`, about 2–3 trail texels), so the inner slope is non-zero. Slope in screen px = `∇h_t` mapped through the UV Jacobian (`hoistPatternDx/Dy`, already there) × `TRAIL_REFRACT_PX`. This no longer uses the head `radiusPx`. |
| T2 Sharp sampling | Trail and film mip = `TRAIL_MIP_BASE` (about 0.75) + `TRAIL_MIP_SLOPE × |∇h|`. The `WF_SCENE_MIP`, `SHEET_BLUR` and `TRAIL_BLUR` terms are no longer added for trails; they are kept for heads and for smear turbidity only. |
| T3 Flow ripple | A flow direction in visor UV, from gravity plus airflow projected on the visor (a Lua uniform; the physics already has both), then smoothed. Thickness `+= RIPPLE_AMP × noise(along − t·speed, across)`, a stretched value noise advected along the flow, so the image waves and travels with the water. |
| T4 Edge optics | `rim = smoothstep(a, b, |∇h|)`: offset × (1 + `EDGE_REFRACT_BOOST × rim`), colour × (1 − `EDGE_DARK × rim`), plus `EDGE_LIGHT × rim × facing⁴`, where facing = the edge normal against screen up. The head glint code is reused. |
| T5 Transparency | Trail alpha stays high (0.9–0.97), but the colour is the refracted sharp image, so it reads as clear water. The trail veil and tone compression are disabled for trails (the tone limiter is already off). |
| T6 Film path | The wiped-film branch (`filmScene`) gets the same rule: its offset `FilmPixels` (2.6 px) is replaced by thickness-gradient refraction with the ripple, at sharp mip. |

Cost: about 4 extra taps per trail pixel (gradient + noise) and one uniform
vec2 for the flow. No new textures, and the physics is unchanged.

**Smear region (v8 rules).** These still apply on top: trail visibility
follows G, and the turbid colour is mixed in. In the region the trail is
therefore still turbid but bends the image.

## Evidence

`trail_refraction_proto.py` / `.png` (offline numpy, the user's CSP
screenshot as background; left = background, middle = current model,
right = the proposed T1/T2/T4/T5):

- **Middle:** grey painted bands, and the white line and banner under them
  are lost.
- **Right:** the water is clear, the track line and fence visibly bend
  where a rivulet crosses them, and the edges carry thin dark and light
  lines.

## Feasibility

**Yes.** Everything needed is already in the pipeline:

- the trail thickness canvas;
- the UV Jacobian;
- the toned or untoned shot with mips;
- gravity and airflow in Lua.

The risk lies in tuning, not in the API.

1. With too large `TRAIL_REFRACT_PX`, trails read as glass rods. Start
   around 12–20 px and compare with the CSP video.
2. Fast-flow sheets (B/G) still need a softer edge, or wide films outline
   themselves. The existing `SHEET_EDGE_SOFT` is kept.

**Suggested order.**

1. T1 + T2 (the biggest visible change);
2. T4;
3. T3;
4. T6.

Each step can be checked in game behind its own toggle.

## Implemented: T1 + T2 (2026-10-03)

Switch: `RAIN_DYNAMIC_TRAIL_REFRACT_V2` (default on). UI: Water field
section → "Trail refraction v2". Applies only where the trail canvas wins
over the head canvas (`trailWins`); heads are unchanged.

**T1: thickness gradient at two scales**

```
t(uv)   = sat((G(uv) - WF_THRESHOLD) / PROFILE_RANGE)     thickness above the silhouette
gNarrow = central diff of t, step = WF trail step (1 texel)    steep contact edge
gWide   = central diff of t, step s2 = GRAD_WIDE_TEXELS        interior slope
gT      = lerp(gNarrow, gWide, GRAD_MIX)                  per visor UV
slope   = (gT·dUV/dx, gT·dUV/dy) × s2Px     dimensionless, ~1 at the edge of a trail of half-width s2
slope   = clamp |slope| ≤ SLOPE_MAX
offset  = slope × REFRACT_PX   (render px, toward the thick side: the image inverts across the flow)
```

No head radius code and no large-drop warp are used for trails. `slope` also
feeds the existing edge loss and glint, so trail edges now get the same
steep-rim darkening and sky glint as heads. That is part of T4 for free.

**T2: sharp sampling**

```
mip = MIP_BASE + MIP_SLOPE × |slope|/SLOPE_MAX + SHEET_BLUR × sheet + SMEAR_TRAIL_BLUR × region
```

The head base mip (`WF_SCENE_MIP` 3), `WF_SHEET_BLUR` 2.25 and the
large-drop blur no longer apply to trails. The smear-region blur is kept,
because turbidity is intended there.

**Defaults**

| Key | Default | Meaning |
|---|---|---|
| `REFRACT_PX` | 14 | image shift at slope 1 (render px) |
| `GRAD_WIDE_TEXELS` | 3.5 | about half a trail width on the 1024 trail canvas |
| `GRAD_MIX` | 0.65 | 0 = edges only, 1 = interior only |
| `PROFILE_RANGE` | 0.35 | G above the threshold that counts as full thickness |
| `SLOPE_MAX` | 1.5 | slope clamp |
| `MIP_BASE` | 0.75 | base sharpness |
| `MIP_SLOPE` | 1.0 | defocus with curvature |
| `SHEET_BLUR` | 0.5 | fast-flow sheet blur (was 2.25 through the WF setting) |

**Cost.** 4 extra trail taps per trail pixel.

**In-game check order**

1. Toggle v2 on and off on the same scene. The track line and fences under
   a trail should bend instead of being painted over.
2. WF debug 2 (slope view): the trail interior should now be coloured, not
   only its border.
3. Tune `REFRACT_PX` first, then `GRAD_WIDE_TEXELS` (wider trails need
   more), then `GRAD_MIX` and the mips.
4. If trails look like glass rods, lower `REFRACT_PX` or `SLOPE_MAX`. If
   they look flat, raise `GRAD_MIX` or lower `PROFILE_RANGE`.

**Not yet:** T3 (flow-advected ripple), the full T4 edge boost and light
line, T6 (film path).

## User review of T1 + T2 (2026-10-03)

- The image now visibly changes along the flow. T1 works.
- **Biggest remaining obstacle: the projected image differs in tone from
  the real frame.** Lowering the opacity hides the tone gap, but then the
  distortion is gone too. So the image must be taken at the **final
  rendered tone**. This is the frame-first composite of
  `RAINFX_REFRACTION_SOURCE.md`, next after these steps.
- **Smear:** inside the region, WF trails should be very weak and
  transparent. Only the moving drops stay turbid; moving through the
  region they read as flowing foam. Implemented now (v9 below).

## Implemented: T3, T4, T6, and smear v9 (2026-10-03)

**T3: flowing ripple.**

- Lua (`smearUpdate`): every 4 frames, the speed-weighted mean drop velocity
  in visor UV is taken from the state readback, then smoothed (τ 0.5 s).
  It gives the flow direction (the last valid one is kept when nearly
  still) and a phase:
  `phase += |flow| × dt × RIPPLE_ALONG × RIPPLE_SPEED`.
- Shader: `rainTrailRipple(uv)` is a two-octave value noise in flow
  coordinates, `(along × ALONG − phase, across × ACROSS)`. That makes it
  long along the flow, fine across it, and moving with the water.
- Its gradient (step = the wide trail step) is added to the trail
  thickness gradient, × `RIPPLE_AMP` × `smoothstep(0, 0.35, thickness)`, so
  it acts only inside the water.
- The UI shows the mean drop flow (UV/s).

**T4: dramatic edge refraction.**
`rim = smoothstep(EDGE_START, EDGE_END, |slope|)`, offset × (1 +
`EDGE_BOOST` × rim). The edge loss and the sky glint already follow the
trail slope since T1.

**T6: wiped film and ridge.** With v2 on:

- the film and ridge edge pixels are × `FILM_BOOST`;
- the T3 ripple slope (× film coverage) is added to the offset;
- sampling is sharp: mip = `TRAIL_MIP_BASE` + 0.5 × (1 − ridge), instead of
  2 → 1.

**Smear v9.**

- Inside the region, WF trail opacity is × (1 − `SMEAR_TRAIL_CLEAR` ×
  region), default 0.80.
- `SMEAR_TRAIL_TURBID` 0.45 → **0** and `SMEAR_TRAIL_BLUR` 1.5 → **0**, so
  the remaining trail is clear water that bends the image.
- Heads keep `DROP_TURBID × G` (unchanged) and carry the foam.

| New key | Default |
|---|---|
| `TRAIL_RIPPLE_AMP` | 0.30 |
| `TRAIL_RIPPLE_ALONG` | 45 |
| `TRAIL_RIPPLE_ACROSS` | 160 |
| `TRAIL_RIPPLE_SPEED` | 1.0 |
| `TRAIL_EDGE_BOOST` | 0.8 |
| `TRAIL_EDGE_START` | 0.6 |
| `TRAIL_EDGE_END` | 1.3 |
| `TRAIL_FILM_BOOST` | 2.5 |
| `SMEAR_TRAIL_CLEAR` | 0.80 |

**Cost.** T3 adds 4 ripple evaluations (8 value noises) per trail pixel,
plus 4 per film pixel. Set `RIPPLE_AMP` to 0 to skip them.

**Check.**

1. Ripple off and on: the image under a trail should wave and travel
   downstream.
2. If the ripple moves against the flow, set `RIPPLE_SPEED` negative (the
   UV v sign).
3. Edge boost: the trail border bends the image more strongly than its
   middle.
4. Smear region: the trails are almost invisible; the drops are turbid
   blobs that move.

**Next.** Frame-tone source (`RAINFX_REFRACTION_SOURCE.md`): first the stage
probe, then the per-texel frame-first composite.
