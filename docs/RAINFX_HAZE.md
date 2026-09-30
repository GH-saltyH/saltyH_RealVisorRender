# Haze / condensation film (2026-09-30)

Status: implemented behind `RAIN_DYNAMIC_HAZE_ENABLED` (default `true`).
**Not yet seen in game.** DXC compiles the main shader and the Lua-embedded
bake shader, and a Lua block and bracket check passes. Turn it off with the
UI checkbox "Haze enabled".

This covers user note 3 from the CSP reference. A noise-like fog layer lies
across the whole screen. Rain intensity reveals it in parts, and water tracks
and wipes clear it.

## Design

**Bake (once, and again only when a cells slider changes).** The canvas is
1024², RGBA8, in visor UV, the same domain as the micro pattern and the water
field. It is built in `onSceneReady`, next to the birth mask.

| channel | content | frequency |
|---|---|---|
| R | mist density (4-octave fBm) | `MIST_CELLS` 10 per UV |
| B | reveal order: coherent fBm plus 15 % per-cell grain, so rising rain grows patches, not salt-and-pepper | `ORDER_CELLS` 6 |
| G, A | speckle refraction vector per condensation cell | `SPECKLE_CELLS` 600 (~0.5 mm) |

**Draw.** No new pass is added. The static micro-pattern branch used to
`clip()` every visor pixel that no micro disk owns: no disk, gate not reached,
or wiped. Those pixels now call `rainHazeOrClip()`:

```
amount  = smoothstep(order ± soft, rain^HAZE_RAIN_POWER) * lerp(1, mist, MOTTLE) * STRENGTH
amount *= 1 - smoothstep(0.05, 0.6, wipe)                 # trail-mask G (wipes)
amount *= 1 - TRAIL_CLEAR * smoothstep(0.03, thr, waterTrail)  # water-field tracks
color   = shot(sceneUV + speckle * SPECKLE_PIXELS, HAZE_MIP)   # scattering blur + tiny beads
color   = lerp(color, fogColor, VEIL)                          # forward-scatter lift
alpha   = amount
```

- Heads return earlier and cover the haze.
- Micro disks keep their own optics.
- Water tracks carve clear lanes in the direction drops travelled (CSP
  behaviour).
- The micro code now uses derivatives hoisted before these early returns, and
  analytic `ddx`/`ddy` for `sceneUV`. The results are the same.

Prototype (numpy harness, rain 0.3 / 0.6 / 1.0 top to bottom):
`images/haze/prototype_rain_03_06_10.png`. Patches grow with rain, and the
moving drop's track stays clear.

## Cost

- GPU: haze-covered pixels do 4 taps (haze, wipe, water trail, blurred shot)
  plus 1 depth tap with sky correction. It runs only where rain has revealed
  haze; the rest is still clipped.
- Memory: 4 MB.
- CPU: none per frame.

## In-game checks

1. **Haze debug** (blue = amount): patches appear in the same places each time
   and grow as the rain override is raised. They vanish along wiper and
   moving-drop paths.
2. **Normal view**: the gaps between micro disks look milky and slightly
   blurred, not like a flat grey overlay.
   - Too dirty or smoky: lower `STRENGTH` or `VEIL`.
   - Too clean: raise `MIP` or `MOTTLE`.
3. **Speckle**: at 2 px it should read as fine condensation grain. Set it to 0
   if it shimmers during camera motion.
4. Whether micro disks should also be dimmed under haze is left for review.
   It is not done now.

## In-game result 1 and fix (2026-09-30)

User observation: haze barely showed, even at maximum rain. What did show
was confined to a few irregular areas (the debug screenshot shows blue only
inside wiped micro regions), and "something else covers the empty space
first".

Cause: haze was drawn only in visor pixels that **no micro disk owns**. At
high rain the baked micro pattern covers nearly the whole visor. The only
free pixels were the thin punched rims and the wiped patches, so the film
could not appear evenly.

Fix:
- Haze is now evaluated for every visor-surface pixel (`rainHazeEval`).
- Micro-disk pixels composite *disk over haze* in the same output (a
  premultiplied "over": `a = aDisk + (1-aDisk)·aHaze`). The film physically
  lies under the drops.
- Gap pixels still draw haze alone.
- Haze debug now shows the film over the whole visor, with disks hidden, so
  its distribution can be judged independently.

Cost: the haze taps now also run on micro-disk pixels, i.e. most of the
visor, but only where rain has revealed haze. The scene tap is skipped where
the haze amount is 0.

## In-game result 2 and fix: procedural haze (2026-09-30)

User observation (haze debug at high rain): blue appeared **only at the live
micro-disk positions**. The gaps stayed empty, so the film still could not be
seen.

Analysis:
- The debug branch runs before the micro-pattern lookup for every visor
  pixel, so the haze *amount itself* was disk-shaped.
- The procedural bake is correct: it was re-evaluated offline, and its
  mist/order fields are smooth fBm.
- A disk-shaped B channel (reveal order) that opens only inside rain-gated
  disks matches the micro **normal** map (B = z·0.5+0.5 is < 1 only inside
  disks) or the micro gate. So `txDynamicHaze` most likely did not receive
  the haze canvas: it was the 12th texture slot of this `render.mesh` call.
- This is an inference; the binding cannot be inspected from here.

Fix:
- The haze field is now **procedural in the draw shader**
  (`rainHazeField(uv)`: the same fBm/hash as the bake). No texture is bound,
  and the bake step and canvas are removed.
- Cost: about 32 hash evaluations per visor pixel (ALU only). There is no
  memory or CPU cost.
- The cells sliders now take effect live.
- `RAIN_DYNAMIC_HAZE_TEXTURE_SIZE` is unused.

If the haze debug is now uniform, the texture-slot theory is confirmed.
Adding any new texture to this draw call should then be treated with care
(limit around 11), and the note should be kept in docs.

## In-game result 3 and fix: wiped areas (2026-09-30)

User observation: the haze is full at first, but once an area has been wiped
it reappears only at micro-disk positions.

Cause: the wiped-film branch (trail mask G > 0.04, which lasts a long time)
returned the film colour directly for gap pixels, without haze. Disk pixels
fell through to the micro branch, which now composites haze. So after a wipe
only the disks carried haze until the wipe mask fully decayed.

Fix: the wiped film is now composited over the (recovering) haze, using the
same premultiplied "over" as the disks. Haze therefore returns evenly as the
wipe mask decays.
