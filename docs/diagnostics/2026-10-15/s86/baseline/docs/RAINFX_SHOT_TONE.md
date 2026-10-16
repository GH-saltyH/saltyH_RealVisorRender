# Refraction-source tone pass: removing the "paint" look in the sky (2026-10-02)

> **Status (2026-10-05):** v1 (aerial fog) and v2 (ratio match) are
> superseded by **tone mode 3** (frame-first composite,
> `RAINFX_STAGE_PROBE.md` v3), rated very good by the user and the default.
> Its composite rules (depth agree, colour sanity, near-trust, frame
> priority) are summarised in `RAINFX_NEAR_OBJECTS.md` §10. The veil/glint
> fog chroma 0.35–0.37 (`RAIN_DYNAMIC_FOG_TONE_SATURATION`) stays.

## Review (user, screenshots: CSP vs ours)

The smear is now very close to CSP. The next most important step is more
and denser moving drops: pre-laid GPU drops, `RAINFX_ROADMAP.md` R1.
First, though, the sky tone has to be fixed.

| | Drops in front of the sky look like this |
|---|---|
| CSP | Small, crisp lenses in the sky tone, slightly darker, with a thin dark inverted crescent (the ground). |
| Ours | Brown, hard-edged blobs smeared like paint. Trails pull light "paint" streaks down. |

## Cause

All refraction (WF heads, trails, micro lenses, film, haze, smear facets)
samples `txDynamicSnapshot`, the geometry shot. Two things went wrong:

1. **The shot has no weather fog.** Far geometry (trees, stands, light
   poles, ground near the horizon) keeps its raw, saturated, brown colour.
   In the final frame the same geometry is fogged grey-blue. The drops
   show the inverted ground, so they showed it brown.
2. **The sky fix ran per sample and after blurring.**
   `rainDynamicWeatherSkyTone` replaced a sample with the fog tone only when
   the *sharp* depth at that UV said "sky" (`depth > 0.99999`). The colour,
   however, came from a *blurred* mip, where brown geometry had already bled
   into the sky. The result:
   - sky pixels were swapped to fog, a flat tone;
   - geometry pixels kept a blurred brown halo;
   - the switch between them is binary.

   Every blurred drop and trail therefore showed a hard edge between a flat
   fog tone and a brown smear. That is the "paint" look.

## Fix: tone the source once, then build the mips

`rainDynamicSceneCopyState.shotToneUpdate` runs in `onSceneReady` right
after the shot update. It is a full-screen pass into an fp16 canvas the size
of the shot, with the same mips, followed by `mipsUpdate()`. Per texel:

```
lin    = near*far / (far - d*(far - near))            standard depth -> metres
aerial = sky ? 1 : (1 - exp(-lin*DENSITY)) * AERIAL_MAX
far01  = sky ? 1 : 1 - exp(-lin*DENSITY)
c      = lerp(lum(c), c, lerp(1, SATURATION, far01))  chroma loss with distance
target = fogColor * clamp(1 + (lum/lum(broad) - 1)*CLOUD_CONTRAST, 0.95, 1.12)
c      = lerp(c, target, aerial)
```

`broad` is the shot's last mip. The sky rule is the former one, but it is
now continuous in depth and is applied **before** blurring.

- `txDynamicSnapshot` now binds the toned canvas when it is ready, and the
  raw shot otherwise.
- The per-sample sky swaps (`Birth / Trail / Haze SkyCorrection`) switch
  off automatically while the toned source is active. The shader is
  unchanged; the old path is still the fallback.
- Every consumer gets consistent tones: blur now mixes fogged geometry with
  the fog-toned sky, so no edge can form.
- Near geometry (cockpit, A-pillar) keeps its colour: aerial ≈ 0 at short
  distance.

**Cost.** One extra full-screen pass at shot resolution, plus a mip chain.
The raw shot still builds its mips, because the broad sky sample uses its
last mip.

## Config and UI (Trail flow section → "Refraction source tone")

| Key | Default | Meaning |
|---|---|---|
| `SHOT_TONE_ENABLED` | true | the pass on or off (off = old per-sample path) |
| `SHOT_TONE_AERIAL_DENSITY` | 0.004 /m | 33 % at 100 m, 86 % at 500 m |
| `SHOT_TONE_AERIAL_MAX` | 0.85 | cap for geometry; the sky always gets 1 |
| `SHOT_TONE_SATURATION` | 0.75 | chroma kept on far geometry |
| `SHOT_TONE_CLOUD_CONTRAST` | 0.25 | the former constant |
| `SHOT_TONE_PREVIEW` | false | shows the toned source next to the raw shot in the window |

**Tuning.**

- In heavy rain or fog, raise the density (0.008–0.015).
- If drops over the sky are still too dark or brown, lower the saturation
  and raise `AERIAL_MAX`.
- If they turn too flat, lower the density.

**Assumption to check.** The shot depth is standard Z with 1 = far, the same
assumption as the former sky test. If the preview shows near geometry
fogged and far geometry clear, the depth is reversed. Then
`lin = near*far / (near + d*(far - near))`.

## v2: match the shot to the real frame; neutral veil colour (2026-10-03)

### User review of v1

v1 removed the paint edges, but everything reads **far too blue**, a pastel
blue over the whole visor. In the ideal (CSP windscreen):

- the sky is a neutral grey-white;
- the drops hold that sky tone, with dark refracted bits and crisp
  highlights;
- the water is never tinted blue.

### Cause

v1 and every veil used `sim.fogColor` as "the sky":

- the sky and aerial-fog target;
- the haze veil and the smear turbid veil;
- the WF sheet veil and the glints;
- the pop flash.

The fog colour is the fog *parameter*, not the colour the sky ends up with
in the frame, and in this weather it is clearly blue. Wherever it replaced
or veiled the shot, the visor turned blue.

### Fix 1: frame match (`SHOT_TONE_MODE = 2`, default)

The tone pass moved from `onSceneReady` into the drop draw callback
(`main.track.transparent`), and both passes use `updateSceneWithShader`.
That is the API for passes in the middle of the scene render (lib.lua:
"can be used in the middle of rendering scene"). At that point
`dynamic::hdr` holds **this** frame, before car glass and before our drops.

1. `toneFrame`: `dynamic::hdr` resampled into a 1/4-size fp16 canvas with
   8 mips.
2. Tone pass, per texel:

   ```
   sLow  = shot mip MATCH_MIP           fLow = frame mip MATCH_MIP-2 (same footprint)
   ratio = clamp(fLow / sLow, RATIO_MIN, RATIO_MAX)       per channel
   lr    = clamp(lum(fLow) / lum(sLow), ...)              luminance only
   m     = lerp(lr, ratio, MATCH_CHROMA)
   c     = shot * lerp(1, m, MATCH_STRENGTH)
   ```

   The low frequencies (hue, fog, exposure, the sky's real colour) come
   from the frame. The high frequencies (the sharp image to refract) come
   from the shot.
3. Mips are built from the result, so the blur stays consistent, as in v1.

If the frame sample is black, as on the first frames or with an invalid
target, the ratio is 1 and the shot is used as it is. `async = true`: until
both shaders are compiled, the raw shot is used. Mode 1 (v1 aerial fog)
stays available.

### Fix 2: neutral veil colour

`gDynamicDropWeatherFogColor` is now
`fogTone = lum + (fog - lum) × FOG_TONE_SATURATION`, with default 0.30.
Luminance is kept and most of the blue chroma removed. It is used by the
veils, glints, smear turbid colour and pop flash, and by the mode-1 target.

### New keys (UI: Trail flow → Refraction source tone)

| Key | Default |
|---|---|
| `SHOT_TONE_MODE` | 2 |
| `SHOT_TONE_MATCH_MIP` | 5 |
| `SHOT_TONE_MATCH_STRENGTH` | 1.0 |
| `SHOT_TONE_MATCH_CHROMA` | 1.0 |
| `SHOT_TONE_RATIO_MIN` / `MAX` | 0.25 / 4.0 |
| `FOG_TONE_SATURATION` | 0.30 |

### Risks to check in game

- **Feedback.** `dynamic::hdr` is read before our drop draw, so there is no
  loop.
- **Callback state.** `mipsUpdate()` on canvases inside a render callback
  is untested. It is wrapped in `pcall`, falls back to the raw shot, and
  logs "Shot tone pass: …" once. Report the log if the toned preview stays
  "not ready".
- **Halos.** The ratio at mip 5 is local (about 32 px). A small, very
  bright or dark object that differs between frame and shot can leave a
  soft halo. If so, raise `MATCH_MIP`, or lower `MATCH_CHROMA` to transfer
  luminance only.

### Note on the drop shape in the comparison

The dark *rings* around every micro disk in our screenshot are
`MICRO_PATTERN_OUTLINE_DARK = 0.65` (`RAINFX_MICRO_PATTERN.md`, turbidity
review). In the CSP image there is no outline; each drop is a crisp lens
with its own bright and dark parts. 0–0.15 is recommended.

The irregular, elongated, merged drop shapes of the CSP image come from many
moving and merging drops, the pre-laid GPU drops of the roadmap (R1), not
from the micro pattern.
