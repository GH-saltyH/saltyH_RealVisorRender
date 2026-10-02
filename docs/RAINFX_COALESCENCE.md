# Coalescence and absorption steering (2026-10-01)

Status: implemented behind `RAIN_GPU_STATE_MERGE_ENABLED` and
`RAIN_GPU_STATE_ATTRACT_ENABLED` (both default `true`). **Not yet seen in
game.** Both GPU state shaders compile with DXC, and a Lua block and bracket
check passes. Both options can be switched off in the UI section
"Coalescence and absorption steering".

## Goal (user)

Real mass merging. A drop flowing down absorbs drops in its path and turns
toward them, so slow drops meander.

## Why a CPU/GPU hybrid

Each GPU state pass updates one texel per slot. A brute-force neighbour search
would be 3072 × 3072 fetches in each of the two passes, serial per thread.
Instead:

1. **CPU (once per readback snapshot).** From the async readback (predicted
   positions, radius, velocity, alive, generation), a uniform grid is built
   with a cell of `2 · maxR · max(reach)`, in O(N).
   - **Merge pairs:** nearest non-paired neighbour with
     `d < MERGE_REACH·(r1+r2)`, greedy and mutually exclusive, at most
     `MERGE_MAX_PAIRS` per snapshot.
   - **Steering:** a moving drop (`speed ≥ ATTRACT_MIN_SPEED`) not in a pair
     targets the nearest drop with `d < ATTRACT_REACH·(r1+r2)` inside the
     forward cone.
   - Commands go into a `count × 1` RGBA8 canvas (`RainFX merge commands`),
     one texel per slot: R, G = partner index (hi/lo byte, exact k/255 values),
     B = `type·64 + partnerGeneration % 64` (type 1 merge, 2 steer).
2. **GPU (every frame, both passes, same read textures).**
   `rainMergeDecode()` re-validates on **current** state:
   - the partner is alive and its generation matches;
   - for merges, both texels point at each other and both generations match;
   - the current distance is within reach.

   Because the state and meta passes run the identical test on identical
   inputs, the survivor grows **exactly when** the victim dies, so there is
   no duplicated or lost mass.
   - Stale commands, a partner that has already merged or respawned, or
     drops that drifted apart are simply rejected.

## Physics

- **Survivor:** the larger radius; on a tie, the lower index.
- **Volume:** `r = (r1³ + r2³)^(1/3)`. At the same contact angle the
  footprint scales with volume^(1/3). It is capped at
  `MERGE_MAX_DIAMETER_MM`. The mass profile is recomputed with the birth
  formula.
- **State pass:** volume-weighted centre and momentum, so the survivor jumps
  slightly toward the absorbed drop and its velocity bends and slows. This is
  the visible "turns toward what it swallowed". The physics step then uses
  the new radius and mass.
- **Meta pass:** the victim is set dead (normal respawn gap later), and the
  survivor's radius and mass are updated.
- **Steering:** `v += dir · ATTRACT_GAIN · (1 - d/reach) · dt`, applied before
  the physics step. Adhesion and drag still apply, so pinned drops stay
  pinned. Only drops that already move are steered, which produces the
  meandering.

## Cost

- CPU: one O(N) grid pass per readback snapshot plus one 1-pixel rect per
  command.
- GPU: up to 5 point fetches per slot per pass (3072 texels).
- Memory: negligible.

## In-game checks

1. The UI readout "Snapshot: N merge pairs, M steering" should be non-zero in
   rain.
   - If pairs stay non-zero but nothing merges, check the command canvas in
     the Lua Debug app ("RainFX merge commands"). UI colours must reach the
     canvas unmodified, as exact k/255 values. If they do not, the GPU
     validation silently rejects every command (a safe failure).
2. Watch a slow drop crossing static drops: it should swallow them, grow, and
   kink toward each one.
3. Tuning:
   - `MERGE_REACH` 0.85 (lower = drops must overlap more before merging)
   - `ATTRACT_GAIN` 0.03 and `ATTRACT_REACH` 1.6
   - `ATTRACT_CONE` 0 = forward half-plane; raise it for a narrower cone
4. Visual: a merged head's radius jumps on the next readback (full redraw
   heads). The absorbed head vanishes and its track stays in the trail
   canvas.

## Crash 1 and fix (2026-10-01)

The game crashed about 60 ms after load (`dmp-6930-41309-0619`).

Minidump analysis:
- Exception `0xC00000FD` (**stack overflow**) on thread "AC: main thread".
- The crashing code is inside `D3DCOMPILER_47.dll+0x541f8`: the same frame
  (+0x545c5) recurses hundreds of times. That is FXC recursing while
  compiling a shader synchronously.
- `rainVisorDynamicDrop.hlsl` is byte-identical to the version that already
  ran; its log size differs only by CRLF. That points to the new merge code
  in the synchronously compiled GPU **state** shaders (`updateWithShader`).

Fix:
1. `rainMergeDecode` is rewritten **straight-line**: no early returns, and
   validity is a product of 0/1 terms. The main-function blocks use one
   branch plus `lerp` by the merge weight. Behaviour is identical.
2. The two existing respawn search loops (128 × 16) are marked `[loop]`, so
   FXC no longer tries to unroll them into the now larger function.
3. **Compile-time guard:** all merge HLSL is inside `#ifdef RAIN_MERGE_CODE`,
   driven by `RAIN_GPU_STATE_MERGE_SHADER` (default `true`) through
   `defines`. Set it to `false` and reload Lua to get exactly the pre-merge
   shaders back, if FXC still has a problem.

Both variants (with and without the define) compile with DXC. FXC itself
cannot be run in the development environment, so the in-game load is the
real test.

## In-game result (2026-10-01)

- The fixed build loads without any extra change: no FXC crash, and the
  default `RAIN_GPU_STATE_MERGE_SHADER = true` is fine.
- Merging was confirmed in game.
- **Total app cost measured by the user:** 65 FPS with the app. The app costs
  about 9 FPS at rain 0.48, i.e. roughly 2 ms per frame around 65–74 FPS.
  This is the baseline for the optimisation pass.

### Suspected cost centres (to verify one by one with toggles)

1. GeometryShot: a second scene render at 1620×936, depth and 10 mips, every
   frame. It is probably the largest single item.
2. Lua per frame:
   - full birth-mask redraw (kernel quads for every live head);
   - trail-canvas stamps;
   - wipe-mask stamps;
   - the merge grid once per readback.
3. Full-visor surface pass: procedural haze (about 32 hashes per pixel), micro
   lens, WF head and trail taps.
4. Canvas passes: clear of the 2048² fp16 birth mask, decay of the 1024² fp16
   trail canvas, and decay of the wipe mask.
