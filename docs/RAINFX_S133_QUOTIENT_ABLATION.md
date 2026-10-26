# s133 — quotient correction ablation

Date: 2026-10-18
Status: ACTIVE

## 1. Purpose

s132 closes the signed-affine exact-map failure on actual CSP, but adds44
synthetic instruction slots per map. It also raises a near-zero curved endpoint
error from181 to1175 ULP (about1.07e-9 cell absolute). This step tests all eight
combinations of the three correction sites with unchanged physics and criteria.
It prepares a cheaper numerical candidate, not live RainFX adoption.

Mask bits are1=mass normalization,2=Gram projection,4=weighted face velocity.
Mask0 is the unchanged s130v2 native map; mask7 is exactly s132's full correction.
Only those map quotient sites differ. Seed, physical units, elapsed time,
coating, geometry, sparse runs and all remaining solver bodies are preserved.
Each variant is compiled from fixed source, without a new runtime mask uniform.

Four fixed fixtures are repeated for every mask: positive affine runoff,
negative affine runoff, real-bake Y→X (including cell11/0's first Y projection)
and sparse real-bake X→Y. These are parent s131/s132 cases0,1,3,4. The full
eight-mask comparison uses one independent default-OFF app, not eight user runs.

## 2. Capture and numerical scope

Each graph retains its own30 affine or32 curved targets, followed by an R32FLOAT
extraction. The32 graphs submit1024 accepted draws. Only map/totals/full-gather
outputs are captured for both axes and texture branches; curved graphs also
capture explicit End/Mean copies. The six seed resources are captured once per
fixture from mask0. All recipes use the same immutable seed shader and typed
values for that fixture; descriptor checks enforce that fact. Per-variant seed
readback, leaves/groups and end-only outputs are not claimed as observed here.

Selected roots allow192 logical/bank output-pair comparisons. Original exact
signed-affine coordinates are checked without changing their zero-error gate.
End/Mean mass and three momentum components use the existing64-epsilon per-step
and128-epsilon two-step sum-absolute-input bounds, including boundary losses.
Curved copies, admission, invalid recipients and nonnegative mass are checked.
The actual float64 map-reference differences, ULP and absolute error are reported
separately; these measurements do not establish a universal projection bound.

Mask0 and mask7 selected outputs are compared bit-for-bit with the immutable
actual s131 and s132 captures. That controls replay of the original failure and
the full-correction behavior on this new capture path. Intermediate masks are
ranked only after those controls and the scoped map/budget checks are evaluated.
Static shader slots rank eligible candidates; no measured-time selection claim.

## 3. Bounded exact capture

The app uses887 basic-log lines, below the observed1000-call cumulative quota.
Each row contains at most192 float32 words written as eight hexadecimal digits
per word, preserving signed zero and subnormals. The encoder uses standard Lua
arithmetic, string and table operations, without FFI or a new engine API.
Python reconstructs each IEEE754 word directly. Padding, shape, nonfinite values,
duplicate/missing rows and all16 accepted/attempt-counter blocks are guarded.
The largest normal callback emits at most10 log calls.

`State: logging` lasts until the final counter block has been emitted. Only then
does the app show `State: observed`. Disabling pauses both drawing and logging;
resuming preserves the accepted prefix. There is no one-shot replay in a load.
A game-session restart is required if the app's basic log quota was exhausted.

## 4. Verification and result

### Actual user result — fresh game session

All166,784 selected-root float values and1024 once-accepted draw counters were
captured in887 lines. Both native and full-correction controls match their
previous actual CSP captures bit-for-bit. All32 graphs pass the scoped admission,
texture-path equality, copies, boundary and step/cumulative budget checks.
There are192 bit-identical logical/bank output pairs.

| Mask | Corrections | Actual strict signed-affine maps | Synthetic logical/bank slots |
|---:|---|---|---:|
|0 |none |fail |231 /337 |
|1 |mass |fail |247 /353 |
|2 |projection |fail |247 /353 |
|3 |mass + projection |fail |263 /369 |
|4 |face |fail |243 /349 |
|5 |mass + face |pass |259 /365 |
|6 |projection + face |fail |259 /365 |
|7 |mass + projection + face |pass |275 /381 |

Within these actual fixtures, mass and face correction are both required for the
unchanged exact affine-map criterion. Projection division correction can be
removed while preserving the specified gates. **Mask5** is the least-static-cost
eligible combination. Added slots fall44→28, saving16 per map versus s132; this
is not a measured FPS/GPU-time saving or proof of global minimal runtime cost.

Enabling mass correction produces the1175-ULP near-zero maximum in all four
matching masks; the four masks without it retain181 ULP. Worst corrected absolute
error there is1.068503063848144e-9 cell. Projection-only correction does not remove
that counterexample. The maximum absolute curved-map error remains about4.75e-7
cell. Uniform accuracy improvement is not claimed.

Removing projection correction leaves affine selected roots bit-identical to
s132, but changes16 and115 float components in the two curved fixtures. Per-field
and per-channel differences are retained in `candidate_comparison.json`; stocks
and map coordinates use different units. No curved output is silently described
as bit-identical to the full correction.

The tested mask5 map bodies were exported byte-for-byte to the **uninstalled**
prototype `docs/prototypes/s133/s133_selected_sources.lua`. The export record binds
its source hashes to the actual observation, frozen installed package and chosen
mask. It reuses existing helper bodies and is ready for the next scoped analysis.

### Offline verification

1504 WARP draws/31 strict synthetic shader bodies,18 mocked lifecycle cases,
15 decoder controls,1029 exact-bit codec controls and9 scratch installer cases
pass. A separate32-recipe audit proves identical seed descriptors, typed values,
packets, roots and bindings across masks after removing only map source/cache
fields. Nominal app texel payload is1,967,104B; actual GPU allocation/peak memory
and timing are unmeasured. The largest log line is1572 characters.

Offline checks run1024 probe draws plus480 guards: the other two original affine
fixtures (small movement/dry cell and intended overtake refusal) are checked for
each mask, completing all four original WARP cases per mask. Those additional
fixtures are not actual CSP cases in this experiment. Stable schema/cache keys,
mocked compile-pending, accepted-prefix pause/resume, allocation/readback errors,
duplicate callbacks and CPU handle disposal are checked independently.

Hex-codec controls include negative zero, minimum/maximum finite floats,
subnormal limits and seeded random finite words. Actual CSP must still prove
the encoding and expanded graph on its closed shader template. Submitted GPU
targets remain retained; readback does not provide a general completion fence.

## 5. Preservation and next step

`realvisor_s133_probe` contains10 installed files and defaults OFF. Its source
factory imports frozen existing helpers; map cache schemas are distinct and
original consumer bindings stay unchanged. Controller authoring source is
appended at build time and is not installed as a duplicate module.

Reports, input/output layouts, generated-source hashes, WARP roots, static DXBC
costs, decoder/lifecycle controls, installation/log provenance and final audit
are under `docs/diagnostics/2026-10-18/s133/`. Production physics remains s87 and
diagnostics s89. User tuning, prior apps, earlier failures and assets are preserved;
no commit or push is made.

Next carry the least costly supported correction set into scoped curved error
analysis and retained interval ownership. Any near-zero counterexample remains
visible. Full recurrent physical closure, live publication and actual target
GPU/CPU timing remain necessary before production adoption.
