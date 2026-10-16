# Feature reviews requested on 2026-10-02

> **Status (2026-10-05):** §1 open as roadmap R1. §2 implemented and
> closed (`RAINFX_MICRO_PATTERN.md` "Pop-in"). §3 closed here: moved to
> `RAINFX_VISOR_GLASS.md` (render-pass problem), and to be re-evaluated with
> the scene stack (`RAINFX_VISOR_LAYER.md`).

## 1. GPU drops pre-laid like the micro pattern (select, live, die)

**Status: on the roadmap** (`RAINFX_ROADMAP.md`, R1). Not implemented.

**Question.** Could GPU drops be laid out in advance, like the micro
pattern, then selected by an intensity value to be born, act and disappear?
Would that let us control many more drops smoothly?

**Assessment: feasible, and it fits the texel architecture.**

**How it would work**

- Bake a "spawn atlas" texture in visor UV. Each texel holds a candidate
  site: position jitter, size class and an activation order (like the
  micro gate `B` channel).
- The state shader's respawn already picks positions with a hash. It could
  instead read the atlas: slot `i` takes site `(i + generation × K) mod N`,
  and a candidate becomes active only when its order is ≤ the rain
  intensity.
- This gives stable, intensity-ordered births without CPU work. The shape,
  pancake and lifecycle code stay the same.

**What it buys**

- The drop count is still limited by the state texture (2048–3072 slots).
  The cost per drop is GPU state, CPU readback and WF stamp drawing, so
  pre-laying does not raise the ceiling by itself.
- The real scaling step is to stop drawing every head on the CPU: render
  the WF head canvas on the GPU from the state texture, for example with an
  instanced or point-sprite pass that reads `txRainState`.
- With that, 10k+ drops become realistic. It is the larger piece of work.

**Recommendation**

1. First, GPU-side stamping of the WF heads. This removes the CPU per-drop
   loop.
2. Then, an atlas-driven respawn.

## 2. Micro drops randomly vanish and appear (cheap liveliness)

**Status: implemented** with a pickup share and per-disk periods; see
`RAINFX_MICRO_PATTERN.md` "Pop-in".

**Assessment: very cheap. About 1 hash per micro pixel plus 1 time uniform.**

**How it would work**

- Each disk already has a stable centre (`diskCenterUV`).
- Visibility = `hash(diskCenter, floor(time × RATE + hash(diskCenter)))` >
  `DROPOUT`. Each disk then flips on and off instantly at its own random
  times.
- Optionally, gate it by rain (a higher rate when it rains harder), and
  make a flip-on show the existing impact look.
- All pixels of a disk share the same centre, so a disk flips as one piece,
  without flicker inside it.

**Risk.** At high rates it reads as shimmer, especially with DLSS. Keep the
rate below about 2 flips per disk per second. This can be added in one
step whenever wanted.

## 3. Visor base meshes shimmer/noise under DLSS — CLOSED here (see banner)

**Observation.** The original visor parts (KN5 loaded with its own shaders)
shimmer and get noisy under DLSS. Our RainFX mesh does not.

**Likely reason.**

- The visor is a transparent, camera-locked mesh about 3 cm from the eye.
  Temporal upscalers reproject such pixels with the scene motion behind them
  and mix in previous frames, which gives shimmer and ghosting.
- Our drops avoid this because they now write near depth (depth pass) and
  are mostly opaque.

**Quick options, in order of effort**

1. **`visor:setMotionStencil(1)`** ("reduced TAA" in the CSP API). Already
   wired: `RAIN_VISOR_MOTION_STENCIL` (default −1, off). Set it to 1 and
   reload. This is the first thing to test.
2. **Visor depth.** If the visor material is transparent and writes no
   depth, `visor:setDepthMode(render.DepthMode.Normal)` (a SceneReference
   API) makes it write near depth. Camera-locked depth reprojects without
   smear. The risk is hiding particles that are drawn later behind the
   visor, which is correct anyway.
3. **Render-pass control.** Hide the visor KN5 (`setVisible(false)`) and
   draw its meshes ourselves with `render.mesh` in the same callback as the
   drops, using its own textures. This gives full control, including the
   depth pass, but the material look must be rebuilt in our shader. It is
   the most work.

Try 1, then 2, before any refactor.

### Result (user, 2026-10-02)

Options 1 and 2 were tried (`setMotionStencil(1)` plus
`setDepthMode(Normal)` on the whole KN5) and **did not fix** the shimmer.
The next steps (diagnosis, material fix, own glass pass) are in
`RAINFX_VISOR_GLASS.md`.
