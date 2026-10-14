# RainFX s69: G-force capture phase and accumulating splash work

Date: 2026-10-12. Status: ACTIVE — fixes/replays complete; game visibility, memory plateau and hitch recovery need confirmation.

## User result

The user isolated disappearing FX to **G-Force Motion enabled while the car
moves**. The previous assumption that automatic driving itself was the
trigger is superseded. Periodic multi-second drops to about 5 FPS eventually
ended in a near-zero-frame stall. The supplied profiler shows 2297.72 MB,
58.1% garbage-collector samples, `updateMergeCommands` at 37.2%, birth mask at
7.5%, splash collection at 6.8%, and `waterFieldSplashV2` at 4.3%.

## Findings and fixes

### Moving native-glass captures were inside the main renderer

`native_glass_occlusion.lua` includes real motion in its local-camera cache
key. With G-force moving the helmet, it must refresh. The old scene stack
called its GeometryShot update between main glass/Rain submissions. At a
settled pose the cache hit bypassed that update; moving poses exercised it
continuously. This matches the user's moving-versus-ESC/settled distinction.

The SDK specifies `render.onSceneReady` as the time after shadow/reflection
updates and before main rendering for scene-dependent GeometryShots. Native
mask preparation now runs there. The main stack only consumes a successful
mask prepared for the current frame and never starts a GeometryShot. Pending
or failed preparation does not publish a ready frame or permit unoccluded FX
over native exterior glass. Cached E1 preparation and G-force motion itself
retain their current implementation.

The routing defect and moving-mask update path are confirmed in code. Actual
driver/GPU matrix-state corruption and disappearance recovery have not been
measured in game; the moving replay verifies the safe capture/submission
ordering, not a screenshot of the real engine.

### CPU splashes accumulated without a consumer reset

The GPU splash renderer transferred and reset `gpuSplashList`. The CPU splash
renderer did neither. Each frame's collector appended active events to the
existing list, then the CPU renderer drew the whole history again. It also
looked up a reused slot's current origin for old-generation events, producing
invalid repeated geometry. As the list grew, CPU/GC and graphics command work
grew with it.

The collector now starts a frame-local list; the CPU renderer clears consumed
events and verifies generation. CPU descriptors and New Trail splash-centre
stamps reuse a bounded per-slot pool. GPU double-buffer records retain their
separate frame ownership and are not mutated through the CPU pool.

### Retired persistent splash queue had no New Trail consumer

`pendingSplash` still received completed CPU impact events while New Trail
bypassed the old CPU water-trail renderer. Nothing consumed the queue, which
retained previous generations' origins and cached piece arrays. New Trail no
longer enqueues those retired stamps and clears any leftover queue. Current
transient splashes, head recovery and current GPU liquid/wipe history remain
on their active paths. Legacy mode retains its normal final-stamp consumer.

### Merge broad phase generated many temporary Lua tables

The physical broad phase rebuilt a table per occupied cell and fresh
partner/type arrays on every new readback. It now reuses sparse cell heads,
tails/counts, a per-slot next index, and partner/type scratch arrays. Previous
cell keys are explicitly cleared. Ascending insertion preserves the former
candidate/tie order, and the encoded commands match exactly.

This is an allocation/GC reduction, not a new merge law. No reach, size, speed,
pair budget, force, transport or authored tuning value was changed.

## Verification

Artifacts: `docs/diagnostics/2026-10-12/s69/`.

| Replay | Previous | s69 |
|---|---:|---:|
| 64 active splashes, 300 frames: processed events | 2,889,600 | 19,200 |
| Retained transient events after consumption | 19,200 | 0 |
| Retired New Trail splash queue | 19,200 | 0 |
| Fixture retained Lua memory after collection | 2730.50 KiB | 88.48 KiB |
| 4096 slots, 100 merge snapshots: Lua allocations | 48,262.23 KiB | 157.59 KiB |
| Same merge replay: median CPU time | 7.65 ms | 8.05 ms |

The CPU median is similar/slightly higher in this sample; the important
reduction is **99.67% less allocation** in that merge workload. Both versions
produce exactly the same 256 merge pairs, 289 attraction commands, 3333
candidate checks and encoded output. Timings exclude actual CSP GPU/draw
submission and are not a game-FPS claim.

Additional checks:

- Actual mask module + main stack: 360 varying 20-mm local-eye frames produce
  1080 FX submissions, with zero GeometryShot updates during main rendering.
  Fifty settled frames reuse the mask; pending preparation retries correctly.
- Whole LuaJIT syntax and the existing optics source/cache/UI checks pass,
  including E2/E3 independence and preservation of the current tint value.
- New Trail runtime/lifecycle/publication and existing settings checks pass.
- Old-generation splash records are excluded rather than borrowing new origins.
- Source and installed hashes, settings, scalar tuning, GPU shader/transport
  programs, and the `updateMotion` function are audited in `delivery.json`.

Fixture memory is not the full app's reported 2297.72 MB. The reproductions
confirm unbounded histories and eliminated growth paths; they do not account
for every engine/GPU allocation or prove the eventual game memory plateau.
No forced GC or reduced rain/slot/quality settings are used to hide the issue.

## Diagnostics and applying the build

RainFX performance UI now shows current CPU splash events, retained event
count, retired-trail queue, per-slot pool count and Lua heap MB. These counters
help identify whether work remains bounded. The heap query runs in the UI;
it does not invoke a collection. KN5 shows the native mask's prepared frame.

The changed runtime source is `realvisor.lua`, already linked into the game.
Reload the app to release the old histories and activate the new code. If the
game is still stalled near zero FPS, restart it rather than continuing the
old run. Verify with G-force enabled and the same rain/4096-slot conditions:
FX visibility, several minutes of memory behaviour, retained queues staying
at zero and absence of the multi-second hitch cycle. Real-game recovery is
still pending.
