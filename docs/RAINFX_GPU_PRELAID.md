# RainFX: GPU pre-laid drops (Roadmap R1) — 2026-10-05

Status: **ACTIVE — R1.0 profiling (s56)**, design below. Source:
`RAINFX_REVIEW_2026-10-02.md` §1, `RAINFX_ROADMAP.md` R1.

## 1. Goal

Many more drops, smoothly controlled:

- birth sites laid out in advance, like the micro pattern;
- selected by rain intensity;
- born, moving and dying on the GPU;
- with the CPU out of the per-drop path.

## 2. Where the ceiling is today (code facts)

| Step | Where | Cost driver |
|---|---|---|
| State update | GPU (`rainStateUpdateParams` / meta), N slots = state texture width (2048–3072) | cheap |
| Readback | async GPU→CPU (`requestRainDynamicStateReadback`), arrays `rainDynamicStateU/V/Velocity*/Radius/Alive` | latency, a few ms of copies |
| **Birth mask + WF heads** | CPU loop in `updateBirthMask`, then `waterFieldDrawStamps`: one or more `ui.drawImageQuad` per drop (body, tail, lobes, splash v2 pieces) | **Lua loop + draw calls per drop** |
| WF trail / wipe mask | CPU loop (`waterFieldUpdateTrail`, `updateTrailMask`, budget `TRAIL_MASK_MAX_STAMPS` 384) | Lua loop + lines |
| Drop shading | GPU (`rainVisorDynamicDrop.hlsl`) reads the WF canvases | cheap per pixel |

The drop count is limited by the **CPU stamping**, not by the GPU state or
the shading. Pre-laid sites alone do not raise the ceiling (REVIEW §1).

## 3. R1.0 (s56): measure first

The RainFX tab → Water field section now shows:

```
R1.0 CPU cost (avg): birth mask + WF stamps X ms | wipe mask Y ms | slots N
```

It is an exponential average of `os.preciseClock()` around
`updateBirthMask`, which covers the birth mask, the WF head stamps and the
WF trail, and around `updateTrailMask` (the wipe mask).

**Please report** X, Y and N:

- in light and heavy rain;
- with splash v2 tearing on and off;
- with the FPS.

This decides how much R1.1 gains, and whether R1.1 must also cover the
trail.

## 4. Design

### R1.1: GPU head stamping by tile binning (no scatter needed)

CSP Lua offers only full-screen pixel passes (`updateWithShader`) and
`render.mesh` with a pixel shader. There is no compute, no instancing and
no vertex-shader control. Scattering one quad per drop on the GPU is
therefore not available. **Gather with tile binning** instead:

1. **Pass A, tile lists.** The canvas is `T × K`: T screen tiles of the WF
   canvas (for example 32×32 tiles) by K list slots (for example 32).
   - Each texel (tile t, slot j) loops over the N state texels and outputs
     the index of the j-th live drop whose kernel bounds overlap tile t,
     or −1.
   - Cost: T·K·N, about 1024 · 32 · 3072 ≈ 100 M cheap iterations. A
     two-level variant (first pass counting, early exit at j) can reduce
     this. **To be measured.**
2. **Pass B, heads.** Each WF canvas pixel reads its tile's K indices,
   fetches those drops' state (position, velocity, radius, generation) and
   evaluates the **same kernel** as `waterKernel` analytically:
   - body;
   - tail kernels;
   - motion stretch.

   It writes the same RGBA contract as today:

   | Channel | Content |
   |---|---|
   | R | radius code |
   | G | coverage |
   | B | energy |
   | A | amplitude |

   It uses max/blend rules equivalent to the current `drawImageQuad` blend.
3. **CPU.** The per-drop loop for heads is removed. Splash v2 tearing stays
   on the CPU at first, because it is rare and complex, and is drawn on top
   only for the few tearing heads.
4. **Validation toggle** (`RAIN_GPU_HEADS`). A CPU vs GPU A/B switch and a
   debug diff view.

### R1.2: atlas-driven respawn (pre-laid sites)

- A spawn atlas in visor UV, baked once like the micro pattern. Each site
  holds:
  - position jitter;
  - size class;
  - **activation order** (as the micro gate B).
- The state respawn reads site `(slot + generation × K) mod S` and becomes
  active only when `order ≤ rain intensity`, so births are ordered by
  intensity and stable.
- Lifecycle, pancake and merge code are unchanged.

### R1.3: raise the slot count

The state texture grows to 10k+ once R1.1 holds. The readback is then used
only for statistics, and for the CPU passes that remain (wipe mask, splash).
Those move to the GPU as well if R1.0 shows they dominate.

## 5. Risks and checks

- **Pass A cost** grows with N·T·K. Measure at N = 3k and 10k. The
  fallback is a coarser tiling, or a two-level hierarchy.
- **Kernel equivalence.** GPU heads must match the baked `waterKernel` look,
  including the radius code that drives the shading. Compare with the A/B
  toggle.
- **Pipeline order.** The trail canvas and the wipe mask read the head
  positions, so CPU and GPU heads must not diverge within a frame.

## 6. R1.0 result (user, 2026-10-06; one lap each, min–max)

Slots: 2048 in every run.

| Rain | Tear | Splash v2 | FPS | Birth + WF stamps | Wipe mask |
|---|---|---|---|---|---|
| light 0.077 | on | on | 55–67 | 0.63–2.27 ms | 0.26–0.91 ms |
| light | on | off | 55–65 | 0.68–1.70 ms | 0.27–0.91 ms |
| light | off | off | 54–66 | 0.65–1.52 ms | 0.28–0.93 ms |
| heavy 0.801 | on | on | 50–62 | **3.14–8.92 ms** | 0.60–2.08 ms |
| heavy | on | off | 53–61 | 3.08–4.99 ms | 0.61–0.99 ms |
| heavy | off | off | 53–61 | 2.84–4.30 ms | 0.53–0.98 ms |

### Reading

1. **Ceiling.** In heavy rain the per-drop CPU stamping costs 2.8–4.3 ms
   with every option off, at only 2048 slots. That is about 17–26 % of a
   60 FPS frame, on the main thread.
   - The cost scales with the number of live drops, so 10k slots on the CPU
     would be roughly 14–21 ms.
   - **R1.3 is impossible without R1.1**, which confirms the design.
2. **Splash v2 is the peak driver.** It adds up to +3.9 ms on the stamps and
   +1.1 ms on the wipe mask, at its maximum in heavy rain.
   - The extra kernel quads per tearing head (press, ring, scatter) explain
     this.
   - The tear on/off difference is small (+0.2–0.7 ms).
3. **FPS barely moves** between the variants (±2–3). The frame is GPU-bound
   or in overlap. The CPU time is still main-thread time that **caps the
   drop count**, which is the goal of R1.
4. **The wipe mask is secondary** (≤ 1 ms without splash v2). It moves to the
   GPU after the heads (R1.3 scope).

### Decision

- **R1.1** goes ahead as designed: GPU head stamping by tile binning, body
  and tail kernels first.
- **Splash v2 pieces** stay on the CPU at first. They get a **per-frame
  budget** of tearing heads, as a cheap cap on the 8.9 ms peak, until they
  move to the GPU as well.
