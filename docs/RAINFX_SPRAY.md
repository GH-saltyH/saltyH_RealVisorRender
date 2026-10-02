# Spray film (물보라) (2026-10-01)

> **REMOVED (2026-10-02).** The spray film v1–v3 (covering pattern, noise relief, impact wave simulation) code, config, uniforms and UI were deleted from `realvisor.lua` and `rainVisorDynamicDrop.hlsl`. The high-speed water film is now built on the smear mask (`RAINFX_SMEAR_MASK.md`). This document is kept as a record only.

Status: implemented behind `RAIN_DYNAMIC_SPRAY_ENABLED` (default `true`).
v1 and v2 have been reviewed in game (2026-10-01). **v3 (the impact wave
simulation, §v3 below) has not been seen in game yet.** DXC (ps_6_0) compiles the main shader, and a Lua
block/bracket check (`docs/tools`-style checker, now counts bare `do` blocks)
passes. UI section: "Spray film (rain x speed)".

## Request (user, 2026-10-01)

1. A spray threshold that mixes rain amount and speed. Above it, a
   full-visor water film grows with the spray value. It shows flow speed and
   direction (speed, headwind), a blurred forward scene, tone, and visible
   water flow. Low cost. Smooth recovery when the value drops.
2. Hide existing drops wherever the spray is drawn.
3. Later: drive the value from lead-car distance and weather (momentary spray).
4. Growth covers the centre area touching the nose **last**.
5. Optional: pick the spray area from the motion direction.

## Design

**Lua (per frame, once per `sim.frame`):
`rainDynamicSceneCopyState.sprayUpdate(state, sim)`**

```
rainTerm  = sat((rain - RAIN_MIN) / (RAIN_FULL - RAIN_MIN))       rain honours RAIN_GPU_STATE_RAIN_OVERRIDE
speedTerm = sat((kmh - SPEED_MIN) / (SPEED_FULL - SPEED_MIN))
index     = speedTerm * (1 - w + w * rainTerm) * [rain > RAIN_MIN]     w = RAIN_WEIGHT (1 = product)
target    = max(0, (index - THRESHOLD) / (1 - THRESHOLD))
target    = min(MAX_LEVEL, max(target, sprayImpulse))              impulse decays 0.5 / s
level    += (target - level) * (1 - exp(-dt / tau))                tau = ATTACK (rising) or RELEASE
phase    += dt * FLOW_SPEED * max(speedTerm, 0.15)                 integrated, so no jumps
```

- **Hook for item 3:** set `rainDynamicSceneCopyState.sprayImpulse = 0..1`
  (for example from lead-car distance times weather). It lifts the target and
  decays by itself; the level smoothing makes it a momentary burst. The UI
  button "Test spray burst" sets it to 1.
- Readouts: spray index and level.

**Shader: `rainSprayEval()`, a screen-space layer, called first in the
`surfaceMicroPattern` block.**

```
q      = (screenUV - nose) * (aspect, 1)                  nose = (NOSE_X, NOSE_Y), default (0.5, 1.05)
order  = sat((1 - sat(|q| / REACH)) * (1 - FRONT_NOISE) + noise(screenUV * FRONT_CELLS) * FRONT_NOISE)
mask   = smoothstep(order - soft, order + soft, level * (1 + 2 soft))
flow   = normalize(q/|q| + (0, -UP_BIAS))                 outward and up from the nose (headwind)
s      = (dot(q, perp) * STREAK_ACROSS, dot(q, flow) * STREAK_ALONG - phase)
streak = 0.65 noise(s) + 0.35 noise(2.13 s + 7.31)        long along flow, narrow across it, advected
uv     = sceneUV + (perp (n1-.5)*2 + flow (n2-.5)) * DISTORT_PIXELS
color  = shot(uv, MIP + streak)  (sky-corrected when haze sky correction is on)
color  = lerp(color, fogColor, VEIL * (0.6 + 0.4 streak)) + fogColor * SHEEN * ridge(n1)^3
alpha  = mask * OPACITY * (0.75 + 0.25 streak)
```

- **Item 4:** `order` is highest at the nose point, so the nose region is
  reached last. At level 1 the whole screen is covered (level is scaled by
  `1 + 2·soft`).
- **Item 2:** a pixel returns the spray and skips heads, trails, micro disks and
  haze when `mask > dither`. `dither` is a per-pixel hash in 0.15–0.85, so the
  front hands over pixel by pixel instead of along a hard cut line.
- **FXC safety:** the water-field `fwidth(G)` and the `ddx/ddy(patternUV)`
  derivatives are hoisted above the spray return, and the WF branch now
  reuses them. The spray code itself is straight-line, with two early returns
  and no loops.

Prototype (numpy, levels 0.25 / 0.5 / 0.8 / 1.0; the reference photo already
contains drops, so hiding cannot be shown there):
`images/spray/prototype_levels.png`.

## Cost

- **CPU:** a few arithmetic operations per frame.
- **GPU** (visor pixels inside the spray): 3 value-noise evaluations and 1
  mip-blurred shot tap, plus a depth tap with sky correction. Covered pixels
  then skip all drop, trail and haze work, so heavy spray should be **cheaper**
  than the drops it hides.
- Pixels outside the spray pay about 1 noise evaluation plus the mask math
  while level > 0, and nothing when level = 0 (uniform branch).
- Memory: none.

## Defaults

- Spray index: RAIN_MIN 0.25, RAIN_FULL 0.80, SPEED 120 → 260 km/h,
  RAIN_WEIGHT 0.5, THRESHOLD 0.15.
- Smoothing: ATTACK 1.5 s, RELEASE 3.0 s.
- Look: OPACITY 0.75, MIP 4.0, VEIL 0.18, SHEEN 0.25, DISTORT 6 px.
- Streaks: ACROSS 60, ALONG 5, FLOW_SPEED 8.
- Coverage front: FRONT_NOISE 0.35, FRONT_CELLS 6, EDGE_SOFT 0.08, REACH 1.2.
- Geometry: NOSE (0.5, 1.05), UP_BIAS 0.6.

## In-game checks

1. **Spray debug** (orange = coverage).
   - Raise the rain override to about 0.8 and drive past about 150 km/h, or
     press "Test spray burst".
   - Coverage must start at the upper corners and outer edges and close in
     on the bottom centre last.
   - It must recede smoothly after braking.
2. **Normal view.**
   - The film is a blurred, slightly milky forward view with faint streaks
     running outward and up.
   - The streaks speed up with car speed.
   - No drops, trails or haze may show through covered areas.
   - Too opaque or grey: lower `OPACITY` or `VEIL`. Too clean: raise `MIP`.
3. **Front edge.** The dithered hand-over should read as soft at 1080p. If it
   shimmers, lower `EDGE_SOFT`, or ask for a spatially stable blue-noise
   dither.
4. **Nose point.** In other cameras (helmet FOV or position), move
   `NOSE_X/Y` to where the visor meets the nose.

## Not done / next

- **Item 5 (motion-direction area).** Not implemented. The planned approach:
  offset the nose point and flow direction by the lateral velocity and yaw
  rate in camera space (`car.localVelocity.x`, `car.localAngularVelocity.y`),
  so crosswind or cornering spray builds on the upwind side first. It needs
  only 2 more uniforms, and the shader is unchanged apart from the nose and
  flow terms.
- **Item 3 driver.** Lead-car distance and weather → `sprayImpulse`. The API
  still needs to be confirmed (e.g. `ac.getCar(i).position` and the distance
  of the car ahead along the track spline).
- The spray is screen-space, so it does not follow visor geometry. That is
  acceptable for a first-person visor, where the visor fills the view.

## v2 (2026-10-01): thick flowing water, air-gun blasts, centring, sky tone

In-game review of v1 raised four points:

1. **Flow.** The v1 streak distortion only smeared ghost images of the
   forward view. Water piling up on the visor should instead form an
   irregular, thick, fast-animated relief that twists the image in several
   directions at once.
2. **Air-gun look.** The film is many droplets hitting at irregular density,
   so local "air-gun" shapes pushing water aside should appear.
3. **Centring.** The centre was biased to the left.
4. **Sky tone.** The film needs sky tone-mapping.

**Changes**

- **Height field (1).** The streak noise and `DISTORT_PIXELS` are removed.
  - The film is now a water height field in the flow frame:
    ```
    p     = (across * FLOW_ACROSS, along * FLOW_ALONG - phase)
    p    += WARP * 2 * (noise(0.37p + (0, t*WARP_SPEED)), noise(0.37p + (5.2, -0.8 t*WARP_SPEED))) - 0.5
    h, ∇h = 0.65 noiseD(p) + 0.35 noiseD(2.07 p + (3.1, -1.3 t*WARP_SPEED))
    ```
    The phase advects the relief outward and upward. The warp term makes it
    churn irregularly.
  - `rainSprayNoiseD` returns analytic value-noise derivatives, so the
    gradient needs no extra taps.
  - The gradient is weighted by `thick = smoothstep(0.25, 0.85, h)` and
    drives the same refraction rule as the water field:
    ```
    uv = sceneUV + slope * REFRACTION_PIXELS
    mip = MIP + SLOPE_MIP * |slope| / 1.5
    ```
    Edge loss at steep slopes, a lower glint facing screen-up, and a veil
    scaled by thickness are added.
- **Air-gun blasts (2).** Each cell of a `BLAST_CELLS` grid is placed in the
  space around the nose. `BLAST_DENSITY` sets the share of active cells,
  scaled by the level.
  - An active cell runs a life cycle at `BLAST_RATE` with a random phase. The
    radius grows fast (`1 - e^(-10 life)`) and the strength fades as
    `(1 - life)²`.
  - The blast is an ellipse stretched along the flow (`BLAST_ELONGATION`).
  - Its core thins the film: alpha drops by `BLAST_CLEAR`, blur goes down,
    and the relief flattens, so a clearer view shows through.
  - A Gaussian ring at `r ≈ 1.05` piles water up. Its radial slope
    (`BLAST_PILE`) refracts strongly.
  - There is one blast per cell and no neighbour search. The radius is capped
    at `0.5·min(elong, 1)/1.35` of a cell, and a window fades anything that
    reaches the cell edge. The first prototype showed hard cell seams, which
    this fixes.
- **Centring (3).**
  - The mask used `posH / window size`, but `PosH` is in render-target
    pixels. When the render target differs from the window, x = 0.5 fell
    left of centre.
  - The mask now uses the same calibrated `sceneUV` mapping as every scene
    tap, with render-target aspect. `NOSE_X` stays at 0.5 and remains
    adjustable.
- **Sky tone (4).**
  - v1 applied `rainDynamicWeatherSkyTone` only when the haze sky correction
    was on. That helper also tests depth at one point, so blurred sky
    bled through.
  - The new `rainSpraySkyTone` gets its own switch, "Spray sky tone",
    default on. It takes 5 depth taps across the mip footprint and swaps
    that sky fraction for the WeatherFX tone.

Prototype (synthetic scene; clean scene, then three times at full coverage):
`images/spray/v2_flow_blast.png`.

**v2 defaults**

- Flow: FLOW_ACROSS 18, FLOW_ALONG 5, FLOW_SPEED 8, WARP 0.8, WARP_SPEED 3.
- Optics: REFRACTION_PIXELS 18, SLOPE_MIP 1.5, EDGE_LOSS 0.35, GLINT 0.30.
- Blasts: BLAST_CELLS 3.5, DENSITY 0.35, RATE 0.9, RADIUS 0.42 (capped to
  0.22 at elongation 0.6), ELONGATION 0.6, CLEAR 0.6, PILE 0.9.
- SHEEN, DISTORT_PIXELS and STREAK_* are removed.

**v2 cost.** Covered pixels do 5 noise evaluations (2 with derivatives), 4
blast hashes, 1 shot tap and 6 depth taps plus 1 mip-9 tap for sky tone. They
still skip all drop, trail and haze work.

**v2 checks**

1. **Flow.** Freeze the car at about 200 km/h with the rain override at 0.8.
   The relief must move outward and up, keep changing shape (warp) and twist
   the image locally in several directions, not smear ghost copies. The
   pattern is too busy → lower `WARP_SPEED` or `REFRACTION_PIXELS`. It is too
   smooth → raise `FLOW_ACROSS`.
2. **Blasts.** Clearer elliptical patches should open fast, get ringed by
   piled water, and refill. No square cell edges may appear.
3. **Centring.** With "Spray debug" on, the last uncovered area must sit
   centred above the nose.
4. **Sky.** Over sky the film should take the WeatherFX tone, with no bright
   blurred shot sky.

## v3 (2026-10-01): impact wave simulation

**v2 review (user).** v2 distorts the view but does not reach the target
scene. The thick water flow in the reference video
(`images/spray/reference_video_sheet.png`, from `차유리물보라예제.mp4`) must be
reproduced, and the waves come from the impulse of hard-hitting drops.

**What the reference shows**

- The whole screen reads like rippled glass. Many small wavelets, wider
  across the flow than along it, travel fast.
- Object outlines (the car ahead, the road) shake and tear up locally. The
  image itself is not very blurred.
- Wave crests near the bottom catch the sky and give dense, small bright
  glints.
- Large-scale wobble comes from uneven film thickness.

Noise relief (v2) has no cause-and-effect: no impact makes a wave and no wave
spreads. So v3 drives the effect with a real wave equation.

**Simulation** (`rainDynamicSceneCopyState.sprayWaveUpdate`, in onSceneReady
after the birth mask)

- The canvas is screen space, `WAVE_SIZE` wide (default 640×360), RGBA16F,
  ping-pong A/B: R = height h, G = vertical velocity v, B = film thickness T.
- It runs `SUBSTEPS` passes per frame (default 2), only while the spray level
  is above 0. When the level reaches 0 the canvas is cleared once and the
  passes stop.
- Each pass:
  ```
  src  = uv - flow(uv) * DRIFT * max(speedTerm, 0.15) * dt     # headwind advection (semi-Lagrangian)
  v    = (v + C2 * ∇²h - RESTORE * h) * DAMPING                # wave equation, symplectic Euler (stable for C2 <= 0.5)
  h    = h + v
  T    = T * THICK_DECAY
  # Impacts: one jittered drop per IMPACT_CELL cell, probability IMPACT_RATE * dt * level * density
  #          density = 1 + DENSITY_NOISE * (2 noise(screen * DENSITY_CELLS + 0.3t) - 1)   (irregular hit density)
  v   -= IMPACT_STRENGTH * mass * (e^(-r²) - 0.5 e^(-r²/2))     # mass-conserving crater (zero net impulse)
  T   += THICK_GAIN * mass * e^(-r²)
  #   r is measured in the flow frame; the crater is ANISO times wider across the flow
  # Gusts (air gun): GUST_CELL cell, probability GUST_RATE * dt * level
  v   += GUST_STRENGTH * (ring(r ≈ R) - 2.46 core)              # large ring wave, zero net impulse
  T   *= 1 - 0.8 core                                           # the core is blown clear
  ```
- **Why zero net impulse:** the first version used a one-sided impulse. h
  then drifted down without limit, clamped at -4, and froze as a flat
  field. Pairing the crater with a wide rim, plus a small `RESTORE` pull,
  keeps the film stable.

**Shading** (main shader, `gDynamicDropSprayWave = 1`)

```
slope = ∇h * WAVE_SLOPE * (0.5 + 0.5 T) + ∇T * WAVE_THICK_SLOPE     # 5 taps, central differences
```

After that, the v2 rule is unchanged (refraction, slope blur, edge loss,
lower glint, veil). The noise relief and the procedural blasts run only
while the simulation is off or not ready yet, as a fallback.

**Binding.** A 12th texture is avoided (`RAINFX_HAZE.md`). The wave canvas
takes the `txDynamicWeatherScreen` slot while it is active (HLSL
`#define txDynamicSprayWave txDynamicWeatherScreen`). That slot is otherwise
read only by the screen-source compare debug, which is therefore invalid
while the spray is active.

**Changed defaults:** `MIP` 4.0 → 2.5 (the reference stays fairly sharp),
`REFRACTION_PIXELS` 18 → 24.

**v3 parameters**

- Canvas and stepping: SIZE 640, SUBSTEPS 2, FLIP_Y false.
- Wave equation: C2 0.45, DAMPING 0.975, RESTORE 0.02, DRIFT 0.35.
- Impacts: IMPACT_CELL 8, RATE 40, STRENGTH 1.6, RADIUS 1.5, ANISO 1.8.
  Density: DENSITY_NOISE 0.6, DENSITY_CELLS 3.
- Gusts: GUST_CELL 60, RATE 0.08, STRENGTH 2.5.
- Film: THICK_GAIN 0.08, THICK_DECAY 0.996.
- Shading: WAVE_SLOPE 3.0, WAVE_THICK_SLOPE 10.

**Prototype.** `tools/spray/wave_proto.py` uses the same equations in numpy:
480×270, 2 substeps, 150 frames at level 1. The image is
`images/spray/v3_impact_wave.png`, at frames 60, 62, 64 and 149.
- It shows rippled glass, wavelets wider across the flow, dense lower
  glints, irregular density (strong on the right, weaker on the left), and a
  gust ring.
- Statistics: h std ≈ 1.0, T mean ≈ 1.0, slope p50/p95 ≈ 0.7 / 1.8.

**v3 cost**

- Simulation: 640×360 × 2 passes ≈ 0.46 M px/frame. Each pixel does 5 taps
  plus about 9 hashes and 1 value noise. This is far below one fullscreen
  pass.
- Main shader, covered pixels: 5 wave taps instead of 5 noise evaluations.
  The rest is the same as v2.
- Memory: 2 × 640×360 × 8 B ≈ 3.7 MB.
- CPU: 2 `updateWithShader` calls per frame while the spray is active.

**v3 checks**

1. **Direction.** The "Wave sim" readout must say `active`. Ripples must
   drift up and outward. If they drift down, the canvas Tex is y-flipped:
   turn on "Wave flip Y". This is an unverified assumption: that
   `updateWithShader`'s `pin.Tex` follows the same top-left convention as
   screen UV.
2. **Look.** Compare with the reference sheet: the image is mostly sharp,
   with jagged, wobbling outlines and dense small glints at the bottom.
   - Too weak: raise `WAVE_SLOPE` or `REFRACTION_PIXELS`.
   - Too busy: lower `IMPACT_RATE` or raise `DAMPING` loss (lower value).
   - Too fine: raise `IMPACT_CELL` and `IMPACT_RADIUS`, or lower
     `WAVE_SIZE`.
   - Large-scale wobble comes from `WAVE_THICK_SLOPE`.
3. **Stability.** Keep `C2` at 0.5 or below. If the film freezes flat or
   saturates (ripples vanish, a uniform offset remains), raise `RESTORE`.
4. **Gusts.** Occasional large rings should open a clear core and send out
   a ring wave. Their frequency is `GUST_RATE`.
5. **Recovery.** After slowing down, ripples must calm and the film must
   recede. The canvas is cleared at level 0.

**Next**

- Lead-car spray (`sprayImpulse`) can simply raise the impact rate through
  the level.
- A drop-heavy burst could inject a single large gust.
- If the reference's horizontal crest structure is still missing, consider
  an anisotropic Laplacian: faster wave speed across the flow.
