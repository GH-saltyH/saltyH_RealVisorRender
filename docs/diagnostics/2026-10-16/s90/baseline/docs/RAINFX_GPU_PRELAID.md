# RainFX: GPU pre-laid drops (Roadmap R1) — 2026-10-05

Status: **ACTIVE — R1.1 measured; R1.2 birth-site atlas prototype pending in-game validation**, design below. Source:
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

## 7. R1.1 prototype (s58): GPU heads by tile binning

**User requirement.** No visible pattern: no tile seams, no regular
spacing, nothing that reveals the binning.

### Implementation

The feature is behind `RAIN_GPU_HEADS = false`. UI: Water field section →
"GPU heads (R1.1, tile binning)".

1. **Source.** The **live GPU state textures**: `rainStateA/B` holds pos.uv
   and vel.uv, `rainStateMetaA/B` holds radius and packed status
   (generation·4 + status), each N × 1. The readback is not used, so there is
   no prediction lag.
2. **Pass A, tile mask.** One RGBA32F canvas texel per (tile, word). Each
   channel stores 24 exact bits (a float holds integers up to 2²⁴), so one
   texel covers 96 drops.
   - Layout: width = tilesX · ⌈N/96⌉, height = tilesY.
   - Each texel tests its 96 drops with a **conservative circle–rectangle**
     overlap, `reach = R·(1.4·ks + max(maxRadii, 1.1·puddleReach, 0.6) + 0.1) + 2 px`.
   - Cost: tilesX · tilesY · N tests, about 2 M for 32² tiles × 2048.
3. **Pass B, heads.** Each pixel of the head canvas (2048², fp16) walks its
   tile's bits (`firstbitlow`) and evaluates **the same kernels as
   `waterFieldDrawStamps`**, in slot order:
   - the stretched body;
   - two tail kernels (body stretch);
   - the shape-variation lobe;
   - two puddles;
   - 0–2 irregular lobes.

   It uses the same per-life seeds (1-based slot index, generation) and
   the same `ks`, and blends with the same "over" rule:
   rgb = (code, 1, 0)·k + rgb·(1−k), a = k + a·(1−k).
4. **CPU overlay.** The CPU loop still builds the stamps (for the trail and
   the splash). In GPU mode it skips the head kernels (`bq()`) and draws
   only the splash v2 and tear pieces on top. For each tearing head it
   records `(bodyAmp, splashScale)` into an N × 1 override canvas, which
   pass B reads **next frame** (a one-frame lag on the hollow body).
5. **Debug.**
   - `RAIN_GPU_HEADS_DEBUG` 1: tile occupancy (red = number of drops tested,
     green = coverage).
   - `RAIN_GPU_HEADS_DEBUG` 2: GPU only, with no CPU overlay.
   - `RAIN_GPU_HEADS_FLIP_Y`: in case the canvas row order differs from the
     UI drawing.

### Pattern safety

- **No list truncation.** The bitmask holds every drop, so a dense tile
  cannot drop drops.
- **No seams.** The footprint test is conservative, so a kernel crossing a
  tile border is evaluated in both tiles.
- **No new regularity.** The seeds and shapes are the CPU ones.

### Known differences to the CPU path (check in the A/B)

- **Fresh-birth growth.** The CPU grows births over
  `BIRTH_MASK_GROW_SECONDS` (0.12 s) using `birthSeenAt`. GPU heads appear
  at full size. If visible, add an age channel.
- **Positions.** The GPU uses the current state; the CPU uses the readback
  plus prediction. The CPU trail can sit a few ms behind the GPU head.
- **Blend order.** Strict slot order on the GPU; CPU order was "fresh
  first, then a rotating cursor". Only the overlap order differs.

### To measure

With `RAIN_GPU_HEADS` on and off, in heavy rain, report:

- the R1.0 "WF stamps" ms;
- the "GPU heads submit" ms (CPU-side submit only);
- the FPS;
- any visible difference: shape, seams, mirrored heads.

## 8. R1.1 first in-game result (user, 2026-10-06)

At heavy rain 0.801 and 2048 slots, with the R1.1 prototype committed as
`621ad60`: 52–61 FPS; birth mask + WF stamps 1.62–6.07 ms, average
4.53 ms; wipe mask 0.60–0.93 ms, average 0.65 ms.

The R1.0 heavy-rain, splash-v2-on run was 50–62 FPS and 3.14–8.92 ms
for birth mask + WF stamps. Those ranges overlap, and R1.0 did not record
an average, so this does **not** establish a measured average speedup.
The maximum observed CPU time is lower by 2.85 ms across these one-lap
runs; it is not a controlled per-frame comparison. FPS is likewise similar.
The user later identified the 51 FPS low point as a scene-complexity peak
(many objects in front of the car), not a RainFX peak; the high end is
scene-dependent too. Do not use the lap FPS range to estimate RainFX cost.
The wipe mask remains around 0.6–0.9 ms and is unaffected by R1.1.

The `WF stamps` timer includes GPU pass submission, CPU stamp-list and
shape construction, the splash overlay, and water-trail work. The GPU mode
still ran the CPU body/tail/lobe/puddle geometry calculations even though
their quads were skipped. The next local revision skips those calculations
in GPU mode and adds separate CPU timings for stamp construction, head
overlay, and water-trail update. This identifies which remaining part should
move to the GPU or receive a splash budget next. GPU execution time is not
measured by these Lua clocks; FPS remains the end-to-end check.

Before raising the slot count, compare CPU and GPU modes at the same rain,
speed and splash settings, and inspect both the head appearance and the new
timings. Do not treat R1.1 as validated solely from this run.

### Follow-up result (user, 2026-10-06; after the CPU geometry skip)

One lap: 51–61 FPS (scene-dependent range). Birth mask + WF stamps CPU
average **2.45 ms**; wipe mask **0.72 ms**. The R1.1 sub-timings are build
**1.03 ms**, head overlay **0.87 ms**, water trail **0.51 ms**. They sum to
2.41 ms, leaving about 0.04 ms for canvas clear, GPU submit and other
overhead in the total timer. The Lua clock around GPU submission does not
measure GPU execution itself.

The new total of 2.45 ms is 2.08 ms lower than the preceding 4.53 ms
average. These are separate laps, so this is an observed difference, not
a controlled A/B speedup. The wipe mask remains secondary. The next CPU
targets are stamp construction and the splash overlay; trail work is about
0.51 ms at 2048 slots.

In the next local revision, GPU mode avoids constructing CPU lobe and
puddle coordinates that only the CPU head renderer reads. The shape-induced
radius adjustment is retained because the CPU trail uses it. Measure the
build and total times again before deciding whether to move trail and
splash work to the GPU or raise the slot count.

### Stationary GPU-head A/B (user, 2026-10-06)

Both runs used 2048 slots, vehicle speed 0 km/h, and the size-triggered
impact splash. The rain value and scene match were not reported for this
pair, so FPS is descriptive only.

| GPU heads | FPS | Birth + WF CPU avg | Wipe CPU avg | Build | Head overlay | Water trail | CPU kernels | Splash heads |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| on | 56 | 1.85 ms | 0.72 ms | 0.59 ms | 0.90 ms | 0.33 ms | 621 | 45 |
| off | 59 | 3.52 ms | 0.77 ms | 0.84 ms | 2.30 ms | 0.38 ms | 4331 | 48 |

Observed CPU saving with GPU heads: **1.67 ms (47%)** in birth + WF;
head overlay accounts for 1.40 ms of that difference, build 0.25 ms,
and water trail 0.05 ms. The wipe mask is effectively unchanged. The
component sum is 1.82 ms (on) / 3.52 ms (off), consistent with the total
within timing and rounding differences.

`WF kernels` counts only CPU `waterFieldDrawStamps` kernels. With GPU heads
on, it counts the splash overlay, not the GPU body/tail/lobe/puddle
kernels. The 621 vs 4331 values therefore do not mean fewer visible heads.
The UI now says `WF CPU kernels` and names the total CPU timer without
the obsolete R1.0 prefix. The 56 vs 59 FPS difference cannot be assigned
to GPU-head cost from these runs, given the scene-dependent FPS range and
the lack of GPU-time measurement. Confirm head appearance and GPU cost
before raising the slot count.

## 9. R1.2 prototype: pre-laid GPU birth sites (2026-10-06)

Added `RAIN_GPU_PRELAID_SITES` (default off), with a live toggle in the
moving-drop lifecycle UI. When enabled, one RGBA32F `count × 1` GPU atlas
is baked for the allocated slot count. Each site stores visor U (R),
encoded signed V as `V+1` (G), stable activation order (B), and a
validity flag (A). The state shader decodes V before boundary use.
The bake tests up to 64 deterministic candidates against the existing
boundary mask. It runs only when the atlas is first enabled or the slot
count changes; a failed bake leaves the existing respawn path active and
shows an error in the UI. A preview checkbox displays the atlas channels.

At each birth, state slot `i` reads site `(i + generation × 37) mod count`.
The stride is coprime with the supported 512-multiple slot counts, so a
slot visits different sites across generations. The atlas order at `i`
replaces the former per-slot hash in the meta-pass admission gate. This
keeps admission stable per slot while rain intensity changes; varying the
order with generation would eventually strand slots after unlucky rebirths.
An invalid site falls back to the existing boundary/rejection search.
The state texture, physics, lifecycle, and CPU readback are unchanged.

**Validation before R1.3:** A/B the atlas toggle at 2048 slots, inspect
coverage and birth distribution at low and heavy rain, ensure the live
count stays stable over multiple lifetimes, and compare GPU-head appearance
and FPS. Then profile at higher slot counts only after the remaining CPU
trail/splash/readback path has a bounded cost. The atlas removes the
per-respawn candidate search; it does not by itself remove CPU per-slot
work, and no 10k-slot claim is made yet.

### R1.2 user result (2026-10-06)

At the tested slot count, the user saw no problem with birth distribution.
Drop shapes matched the previous path and performance indicators were
similar. This is the expected result of replacing birth-site selection,
not the per-frame renderer. Long-run live-count stability at larger slot
counts has not yet been reported.

## 10. R1.3 preparation: sparse tile words (2026-10-06)

The R1.1 head pixel shader originally loaded every tile-mask word at every
head-canvas pixel. The word count is `ceil(slots/96)`: 22 at 2048 slots,
43 at 4096, and 107 at 10,000. This makes the per-pixel mask-read cost
grow with slots even when a tile contains only a few drops.

The experimental `RAIN_GPU_HEADS_SPARSE_WORDS` toggle (default off) adds a
GPU summary pass. For each tile it marks **every nonempty mask word** in
RGBA32F bit fields, 24 exact bits per channel. One summary texel covers
96 words; two cover up to 192 words (18,432 slots). The head pixel shader
walks the summary bits in ascending word order, then reads and evaluates
only those words. There is no candidate limit and no intentional visual
difference. The summary pass is an extra GPU draw; its gain must be
measured, especially at 2048 slots where the extra pass may cost more than
it saves.

**Next check:** Compare sparse words off/on at 2048 and 4096 slots with
the same camera, rain, GPU-head debug 0, and splash settings. Verify
identical heads and no tile seams. Report FPS and the CPU submit time; the
Lua clocks do not expose GPU execution time. Keep the higher slot count
experimental until this check and CPU trail/splash scaling are understood.

### User result: sparse words and 4096 slots (2026-10-06)

- R1.3 sparse words gained about **1 FPS** at 2048 slots and about
  **1 FPS** at 4096 slots.
- 4096 slots produced excellent maximum visual density, but a scene that
  ran near 52 FPS at the lower count fell to about **25 FPS**. The user
  observed a large hit regardless of the tested R1 option. R1.2 pre-laid
  sites recovered about **1–2 FPS** at 4096 slots.

The density goal is visually plausible, but the 4096-slot cost is not
explained by the existing CPU timings or the small R1.2/R1.3 gains. Do
not infer a GPU-head or state-simulation cause from total FPS alone.

### 4096-slot isolation probes

Two reversible diagnostics were added, both off by default:

1. `GPU heads debug = 2` removes the CPU splash overlay while retaining
   GPU heads; `= 3` also makes the head pixel shader return transparent
   before reading tile masks or evaluating kernels. Comparing 2 → 3
   bounds the cost of per-pixel head work while both still run GPU state,
   tile-mask and optional summary passes. Empty heads also reduce work
   in the downstream visor shader, so the FPS difference is an upper
   bound, not a pure head-pass timing.
2. `Freeze GPU drop state (performance probe)` skips the GPU state and
   meta update passes after the existing 4096-slot state is populated.
   It leaves the readback and rendering path running. Compare it against
   the live state after the image has settled; turn it off to resume.
   Births and their splash workload will also stop, so this is a broad
   state/lifecycle probe rather than an exact GPU state-pass timing.

At the same costly camera spot, record FPS and birth + WF CPU time for
normal, debug 2, debug 3, and frozen state. If debug 2 removes most of the
hit, the CPU splash overlay matters. If 2 → 3 recovers it, head-pixel
evaluation or downstream water shading matters. If freezing recovers it,
state updates or their dependent birth effects matter.
The existing `Birth mask resolution` control can then test 2048 → 1024
for a fill-rate hypothesis, with visual quality checked separately.

### Probe result and freeze safeguard (user, 2026-10-06)

At the tested scene: debug 3 = 59 FPS, debug 2 = 57 FPS, and normal GPU
heads = 57 FPS. Birth + WF CPU averaged 2.1–2.4 ms in debug 2/3 and
2.5–2.9 ms in normal mode. The user also reported that drops stayed
completely still even while driving fast, while the driving FPS was
58–60. Stationary drops are exactly what the `Freeze GPU drop state`
probe does. **First verify that this probe was on; until then, these FPS
figures cannot clear the live 4096-slot performance regression.** If it
was on, the small debug 2→3 difference (~2 FPS) only describes the frozen
state, and the normal→debug 2 CPU difference (~0.4–0.8 ms) is consistent
with skipping the CPU overlay traversal (including splash work when any
new births remain).

The freeze probe now displays a prominent status and automatically resumes
physics after 30 seconds. A persisted freeze setting without a live timer
is cleared at the next state update after Lua reload. Re-run the costly
scene with moving drops and freeze off before attributing the 25 FPS hit.

### Fast driving capture at the costly scene (user, 2026-10-06)

With R1.1/R1.2/R1.3 on and 4096 slots, the user captured separate instants
near the lowest-FPS location. The scene and values change rapidly, so these
are diagnostic snapshots rather than controlled paired measurements:

| Head debug | FPS | CPU kernels | Splash heads | Birth + WF CPU | Wipe | Build | Head overlay | Trail | Speed |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 0 | 38 | 11046 | 666 | 14.66 ms | 0.70 ms | 2.24 ms | 9.09 ms | 3.28 ms | 287 km/h |
| 2 | 56 | 131* | 10* | 4.26 ms | 0.74 ms | 1.68 ms | 0.00 ms | 2.52 ms | 284 km/h |
| 3 | 56 | 131* | 10* | 4.48 ms | 0.83 ms | 1.98 ms | 0.00 ms | 2.45 ms | 287 km/h |

The 0 capture is [sample 1](images/gpu_prelaid_perftest_sample1.png).
`*` The debug 2/3 kernel and head counters were stale because the CPU
overlay was skipped; they are now reset to zero when that pass is skipped.
The 9.09 ms CPU head overlay and 666 simultaneous splash heads in debug 0
point to speed-triggered splash density as a substantial cost. Debug 2 and
3 matching at 56 FPS does not support blaming the GPU head pixel shader
for this capture, but the changing scene prevents an exact FPS attribution.

`Speed-only splash birth share` now defaults to 0.12, using a stable hash
per drop life to reduce the number of small speed-only impacts. Drops above
the heavy-size threshold still splash at any speed. A value of 1.00 restores
the previous all-speed-birth behavior. Compare 0.12 and 1.00 during the
same fast-driving run, with debug 0, and record splash heads, overlay ms,
trail ms and FPS in addition to visual density.

### Speed-only splash share sweep (user, 2026-10-06)

All captures used 4096 slots, debug 0, and about 284–287 km/h at the
costly scene. They are separate instants rather than synchronized frames.

| Share | FPS | CPU kernels | Splash heads | Birth + WF CPU | Wipe | Build | Head overlay | Trail |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 0.12 | 53 | 1643 | 107 | 5.22 ms | 0.80 ms | 1.88 ms | 2.22 ms | 1.07 ms |
| 0.50 | 45 | 6769 | 404 | 7.74 ms | 0.71 ms | 2.13 ms | 4.41 ms | 1.15 ms |
| 1.00 | 41 | 12043 | 716 | 10.74 ms | 0.80 ms | 1.90 ms | 7.36 ms | 1.43 ms |

The monotonic rise in CPU kernels and overlay time as splash share rises
supports CPU splash density as the main cost being changed by this control.
The FPS values are consistent with that trend, but scene variation makes
the exact FPS gain uncertain. The 0.12 setting reaches 53 FPS in this
sample; it does not by itself establish a stable worst-case floor or prove
that the visual splash density is acceptable. For the pre-laid design,
judge visual drop density separately from splash density, then measure
repeatable low-FPS segments with live physics and the intended effects on.

### Splash CPU optimization after the share sweep

The splash shape and kernel count remain unchanged. Per-drop rim and
satellite random factors and directions are now cached on the impact
origin and reused across animation frames and its persistent-trail stamp.
This targets Lua math overhead; every visible piece
still submits a `ui.drawImageQuad`, so a large gain is not assumed.
Measure with the same 4096-slot driving segment and share 0.12 first;
compare head overlay time, CPU kernels, splash heads, and FPS. If the
overlay still scales primarily with kernel count, move splash geometry
generation to the GPU rather than thinning the effect further.

### First capture after per-life splash caching (user, 2026-10-06)

At 4096 slots and 283 km/h: 51 FPS, 2173 CPU kernels, 127 splash heads,
5.84 ms birth + WF CPU (build 2.37, head overlay 2.36, trail 1.08 ms),
and 0.81 ms wipe. The earlier 0.12-share capture was 53 FPS, 1643
kernels, 107 heads, and 2.22 ms head overlay. Because the captures have
different head counts and rapidly changing scenes, they do not establish
a cache speedup or regression. Overlay remains around 2 ms for roughly
100–130 splash heads. Do not optimize the cached random math further
without a controlled CPU profile.

Next implementation direction: keep splash birth selection and persistent
trail semantics, but move the animated ring and satellite kernel evaluation
out of Lua `ui.drawImageQuad` calls. The current GPU head pass runs before
CPU splash origins are built and its tile mask only covers the live body
radius, not the expanded splash ring. A GPU prototype therefore needs
splash origin metadata available before head rendering and tile coverage
that includes the full animated radius; adding splash math only inside
the existing head pixel shader would clip pieces at tile boundaries.

### R1.4 first GPU integration: startup stall (user result)

The initial R1.4 switch put the full splash piece loops inside the R1.1
head pixel shader and widened its tile mask. With R1.4 on, the game froze
as the base meshes appeared, including when the switch was true at game
start. No FPS or visual comparison was possible. This path is no longer
selected; the R1.1 head shader and tile mask have been restored. The exact
cause (shader compilation versus execution) is not yet observable, but
running the nested splash loops over the head canvas is too risky.

### R1.4 bounded splash atlas revision (implemented, unverified in game)

`GPU splash pieces (R1.4 prototype)` is **off by default**. R1.1 GPU heads
remain required. Lua keeps birth selection, frozen origin, body residual
override and final persistent-trail stamp. Active splash metadata goes to
a compact two-row texture. A separate shader renders each splash into a
64×64 atlas cell. The atlas is allocated in 128/256/512/1024-head capacity
buckets, so shader work is bounded by active splashes instead of every
head-canvas pixel. One textured quad per splash places the result over the
GPU heads in the same frame. The existing R1.1 head shader is unchanged.

The atlas has a 1024-head safety limit; exceeding it disables R1.4 and
returns to the CPU path on the next frame with an error in the UI. The
64×64 sampling can soften small beads, and atlas compositing may differ
from the CPU kernel blend. Verify game startup, splash shape, fading,
residual-body timing, atlas edges and persistent-trail handoff before an
FPS comparison. Then compare R1.4 off/on at 4096 slots with R1.1–R1.3,
debug 0 and splash birth share 0.12 held fixed. Report FPS, splash heads,
CPU head overlay, GPU splash atlas submit time and any UI error. No local
Lua/HLSL compiler is available, so compilation was left to the in-game test.

### R1.4 atlas first in-game result (user, 2026-10-06)

The revised build no longer freezes when R1.4 is enabled. The CPU head
kernel counter falls to zero and the splash atlas reports active heads.
This confirms the R1.4 path runs and removes per-piece CPU head submissions.
It does not yet establish that the atlas is visually correct or faster in
total frame time. Next compare R1.4 off/on in the same moving 4096-slot
scene with identical splash share and R1.1–R1.3 settings. Capture FPS,
CPU head overlay, GPU splash atlas submit time, active splash heads, and
a close view of splash shape and fade.

### R1.4 atlas comparison and animation defect (user, 2026-10-06)

At the usual costly scene, with R1.1–R1.3 on and 4096 slots:

| R1.4 | FPS | CPU kernels | Splash heads | Birth + WF CPU | Build | Head overlay | Trail | Atlas submit |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| On | 52 | 0 | 133 | 4.46 ms | 1.61 ms | 1.67 ms | 1.13 ms | 0.37 ms |
| Off | 53 | 1730 | 106 | 5.56 ms | 2.34 ms | 2.11 ms | 1.05 ms | stale 0.23 ms |

Speeds were 287/286 km/h and wipe 0.79/0.86 ms. The R1.4-on capture
reduced measured CPU work, but the transient 52 versus 53 FPS result does
not show a total-frame gain. Visually, R1.4 splashes were larger and
flickered, appearing and disappearing or seeming to replay multiple times
at staggered offsets. The off-state atlas count (77) and submit value
were stale UI values, now reset when R1.4 is off.

The first atlas version used a compact list whose order changes each
frame, then updated and sampled the same atlas in that frame. If canvas
updates become visible later, a sprite can be paired with another drop's
position and radius. This is a plausible cause, not yet confirmed. The
atlas now uses two textures: composite the previously completed atlas
with its matching saved draw list, then render the current list into the
other texture. Capacity only grows while active, avoiding repeated
reallocations near the 128-head boundary. This adds one frame of visual
latency, matching the existing GPU body override. Repeat the shape/fade
check before another FPS comparison. The atlas also converts its combined
kernel colour to straight alpha before UI image blending, avoiding a second
alpha multiplication at splash edges. R1.4 remains experimental and off
by default.

### R1.4 atlas defect persists after paired buffers (user, 2026-10-06)

The user still sees oversized splashes, flicker and apparent repeated
animation after the paired-atlas change. That rules out a simple mismatch
between current CPU list order and the previous atlas frame as a complete
explanation. The two-row metadata texture was another possible row-order
mismatch: reversed rows would make the shader interpret a seed as radius
and reach as animation progress, accounting for both symptoms. Metadata
now uses two adjacent texels in a single row for each splash. This removes
vertical row interpretation from that handoff.

### R1.4 atlas visual result after single-row metadata (user, 2026-10-06)

With the new metadata layout, the R1.4 size difference, broken animation
and flicker are all resolved. Flipping atlas image rows produced an
incorrect shape and appearance, so that diagnostic option was removed;
the normal row orientation is fixed. This strongly implicates the old
two-row metadata handoff, though the exact internal canvas orientation
was not measured. R1.4 is now visually viable in the tested scene.
Repeat the same 4096-slot off/on performance capture before enabling it
by default; the earlier 52 versus 53 FPS comparison was taken while its
visual output was incorrect.

### R1.4 corrected visual, same-scene performance (user, 2026-10-06)

With R1.1–R1.3 on and 4096 slots at the usual costly spot:

| R1.4 | FPS | Speed | CPU kernels | Splash heads | Birth + WF CPU | Build | Head overlay | Trail | Atlas submit | Wipe |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| On | 50 | 284 km/h | 0 | 132 | 4.90 ms | 1.87 ms | 1.90 ms | 1.09 ms | 0.37 ms | 0.81 ms |
| Off | 50 | 286 km/h | 1791 | 112 | 5.30 ms | 1.89 ms | 2.32 ms | 1.04 ms | 0.00 ms | 0.73 ms |

GPU heads remained active with about 0.03 ms submit time in both captures.
The atlas removes 1791 CPU kernel submissions and reduces measured head
overlay by 0.42 ms despite 20 more splash heads in the on capture. The
reported total CPU section falls by 0.40 ms. FPS remains 50 in both
snapshots, so this is a CPU-path improvement but not a demonstrated
frame-rate improvement at this scene. Atlas submit time is CPU call time,
not GPU execution time; GPU cost and changing scene load are unresolved.
Keep R1.4 optional and off by default until a repeated low-FPS comparison
shows a total-frame benefit. Do not spend more CPU tuning on these splash
kernels without evidence that this CPU section is on the critical path.

### R1.4 on versus debug 2, usual costly spot (user, 2026-10-06)

With R1.1–R1.4 on and 4096 slots, separate instant captures at the same
location had closely matched speed and trail/sheet density:

| Debug | FPS | Splash heads | Birth + WF CPU | Build | Head overlay | Trail | Atlas submit | Trail stamps | Sheets |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 0 | 50 | 110 | 5.02 ms | 1.77 ms | 1.97 ms | 1.23 ms | 0.27 ms | 2049 | 1624 |
| 2 | 57 | 0 | 2.78 ms | 1.68 ms | 0.00 ms | 1.04 ms | 0.00 ms | 1956 | 1661 |

The speeds were 286/283 km/h, sheet density 1.56/1.54, and both had
the same sheet gate 1.00 and max head speed 0.177 UV/s. Wipe cost was
0.87/0.73 ms. Both had zero CPU head kernels and active GPU heads at
about 0.03 ms submit time. The 7 FPS and 2.24 ms birth+WF CPU gaps
strongly associate the splash path with the low-FPS scene, although
different capture moments prevent exact attribution. Atlas submit was
only 0.27 ms of the 1.97 ms head overlay; the remainder includes splash
state traversal and GPU body-override upload. New UI timing splits these
two CPU sections in R1.4 mode. Measure them before changing the atlas
shader or GPU head pass again.

### R1.4 splash-state split and GPU-only collector (2026-10-06)

At the same 4096-slot spot with R1.1–R1.4 on, debug 0, 284 km/h and
128 splash heads, the user measured 4.46 ms birth+WF CPU, including
1.54 ms build, 1.83 ms head overlay and 1.03 ms trail. The new R1.4 CPU
split reported **1.31 ms splash state** and **0.13 ms override upload**;
atlas submit was 0.75 ms in that instant. The state traversal is the
largest isolated CPU subsection, while atlas submit varies between
captures. Do not interpret the submission clock as GPU execution time.

R1.4 now uses `waterFieldCollectGpuSplash` for its CPU impact lifecycle
pass. It checks age and existing origin first, computes size and speed
eligibility only for drops without an active origin, and generates seeds
only when a new splash actually starts. It skips velocity normalization,
quad setup and body geometry, which the GPU head pass already owns.
Origin duration, residual-body override and one-shot persistent-trail
handoff retain the prior formulas. The CPU-head path and R1.4-off path
still use `waterFieldDrawStamps`. Compare the same visual behavior and
`R1.4 CPU split` after this change before attributing an FPS difference.

### R1.4 collector first follow-up (user, 2026-10-06)

Under the same conditions, the new collector reported 129 atlas heads,
0.59 ms average splash state, 0.11 ms average override upload, 0.36 ms
atlas submit and 0.03 ms GPU-head submit. The previous capture had 128
heads, 1.31 ms splash state and 0.13 ms override upload. Thus the state
section fell by about 0.72 ms at nearly equal active-head count. Atlas
submit is a momentary CPU call measurement and changed from 0.75 ms;
its variation should not be interpreted as a GPU speedup. The user later
supplied the remaining values for this same capture: 285 km/h, 0 CPU
kernels, 3.87 ms average birth+WF CPU, 0.72 ms wipe, and 1.69/1.05/1.08
ms build/head overlay/trail. Relative to the preceding 128-head capture,
birth+WF CPU fell from 4.46 to 3.87 ms and head overlay from 1.83 to
1.05 ms, while build and trail fluctuated upward slightly. The user's
FPS comparison was approximately 56 before and 54 after, within scene
variability or possibly a small decline. This confirms CPU work was
removed but **does not demonstrate a frame-rate gain**. Visual parity was
not reported for this optimized collector. Avoid further CPU micro-tuning
until repeated total-frame measurements identify the limiting path.

### Optimized R1.4, debug 0 versus debug 2 (user, 2026-10-06)

Both captures used R1.1–R1.4, 4096 slots and 284 km/h at the usual
costly spot:

| GPU-head debug | FPS | Splash heads | Birth + WF CPU | Build | Head overlay | Trail | Splash state | Override upload | Atlas submit | Wipe |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 2 | 56 | 0 | 3.26 ms | 2.13 ms | 0.01 ms | 1.07 ms | 0.00 ms | 0.00 ms | 0.00 ms | 0.75 ms |
| 0 | 54 | 102 | 4.43 ms | 2.16 ms | 1.10 ms | 1.10 ms | 0.62 ms | 0.12 ms | 0.35 ms | 0.86 ms |

CPU kernels were zero in both; GPU heads stayed active with about
0.03 ms submit time. Build and trail nearly match. The 1.09 ms head
overlay difference is explained by 0.62 ms splash state, 0.12 ms body
override upload and 0.35 ms atlas submit in debug 0. The 2 FPS gap is
consistent with a remaining splash cost but is too small and too transient
to assign an exact GPU or CPU frame-time contribution. The no-splash
debug-2 ceiling at this spot is about 56 FPS in this capture. R1.4's
remaining CPU cost is now bounded and understood; improving 4096-slot
performance further requires examining the other frame costs rather than
assuming more splash CPU work will recover the full gap to 60 FPS.
