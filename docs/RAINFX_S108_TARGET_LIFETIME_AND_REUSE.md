# s108 — explicit bank copies and bounded target lifetimes

2026-10-17. **Status: ACTIVE — offline resource proof.** Production remains
s87 physics with s89 diagnostics. No runtime allocator or game build is added.

## 1. Why bank views need an explicit contract

s107's CPU reference slices packed output arrays and uploads those slices as
separate input textures. A NumPy row-band view is not automatically a D3D11
Texture2D SRV with a shifted coordinate origin. Treating that view as a free
GPU alias would undercount work and permit incorrect bindings.

s108 records every supplied texture binding and generated target. It identifies
full-width contiguous row-band aliases by owner, byte offset, shape and stride.
Each needed band is **materialized once as an explicit logical copy target**;
subsequent consumers of that immutable band share the copy. Exported state/
diagnostic bands are also materialized before the joint publication fence.
Unsupported column/strided views are rejected. This copy graph is a conservative
future binding strategy, not an implementation of GPU copy commands.

Bindings are conservative: even supplied textures later removed by shader
compilation count as reads. A future active-binding audit can reduce that work.
No missing offsets, free subrect SRVs or zero-cost materializations are assumed.

## 2. Lifetime and reuse rules

- A generated target lives from its write through its **last read, inclusive**.
  Copy sources and destinations also overlap in lifetime at the copy event.
- Public input state, incoming retry checkpoints and incoming cache owners
  remain protected through the complete call/publication fence. They are
  immutable imports and never enter the writable reuse pool.
- All returned public/checkpoint/cache targets remain live through the fence.
  Direct GPU-valued diagnostic exports are pinned too. Existing `.copy()`
  diagnostic arrays are detached CPU captures and are reported separately.
- Reuse requires an exactly matching width, height, RGBA32_FLOAT format, one
  mip, one sample and SRV/RTV usage. The previous owner must have expired
  **strictly before** the new write. Same-draw input/output aliasing is rejected.
- Each pool slot has a generation. Replay rejects stale-generation reads and
  verifies every consumer's full input contents plus every retained export.

The allocation plan uses deterministic first-fit coloring independently per
exact descriptor. The sum of all reserved slots is a conservative logical
arena size; the maximum simultaneously live bytes is a separate lower bound.
These values differ because descriptors cannot be freely combined.

## 3. Evidence and failure checks

The unchanged s107 shaders run under strict FXC and D3D11 WARP. Captures cover
six calls: stationary accepted, reverse-axis accepted, source/pool first-attempt
refused, a two-attempt resumed completion, uninterrupted three-attempt completion
and an accepted actual curved-mesh packet. Complete output values are recorded.

The pool replayer writes those captured outputs into reused **CPU** backing
slots. Before each write it checks every logical input against the capture;
copy events check their actual row-band contents. Final exported targets must
also match. This is an ownership/dataflow check, not a second GPU physics run
using a new allocator. The production shaders and the reference graph are
unchanged.

Every event prefix, including copy events, is replayed to verify that failure
cannot write caller-owned state. Real `PendingPass` checks cover cache receipt,
coarse gather, ledger publication and final snapshot. Caller public/private
arrays remain unchanged. Source/pool transfers occur once, and resumed versus
uninterrupted publications match with the previous conservation tolerances.

Six mutation checks reject live/retained overwrite, same-draw aliasing,
incompatible extent, missing target assignment, caller input entering the
writable pool and unsupported column strides. Graph JSON files expose every
resource, copy/draw edge, lifetime and export for review.

## 4. Conservative target budget

The table symbolically evaluates the captured shape rules at1024x256 with4096
head entries. It does **not** run that resolution or count the whole app.
Actual captures use8x32 and the90x160 curved patch. Exact descriptor compatibility
is recomputed at the requested dimensions; small-grid coincidences are not
scaled as though they stayed compatible.

| Call | Draws | Logical bank copies | Pool slots | New target pool, MiB | Pool + immutable imports, MiB |
|---|---:|---:|---:|---:|---:|
| Fresh accepted or refused, one attempt | 69 | 29 | 44 | 141.89 | 202.33 |
| Resumed, two attempts | 118 | 53 | 47 | 137.89 | 214.33 |
| Fresh, three attempts | 171 | 71 | 54 | 157.89 | 226.33 |
| Actual curved capture, one attempt | 69 | 29 | 44 | 141.89 | 195.60 |

The fresh one-attempt no-reuse total is333.08 MiB of generated targets including
the conservative copies; the exact-size pool reserves141.89 MiB. Three fresh
attempts generate846.61 MiB cumulatively and reserve157.89 MiB. These compare
logical allocation policies, **not measured GPU memory savings**.

Copies add substantial work: the one-attempt graph contains116 MiB of logical
copy output extent, before counting source reads. A bank-offset shader binding
ABI or a different packed layout may avoid many copies; that must be verified
separately. Pooling alone does not remove these operations or the69/118/171
shader draws. Direct diagnostic exports grow with attempts; the proof does not
claim a constant bound for an unbounded attempt count or retained debug history.

Imports include caller state, frozen sources, geometry and any local CPU-upload
inputs. They are counted separately from new targets and kept conservatively
alive through the call. Their values differ between planar and curved fixtures.
Incoming resume cache is counted as an import; fresh cache is a new protected
target. These totals omit driver alignment/overhead, readback/staging storage,
constant buffers and all other app/game resources. The app's Lua Memory display
is not this quantity. **No game memory/FPS improvement is measured.**

## 5. Decision and next implementation

Retain this explicit-copy lifetime model as a resource oracle. It shows a safe
reuse opportunity while exposing integration costs hidden by CPU array views.
It does not approve runtime adoption. A shader with bank-offset access must
preserve texture coordinate origin, physical grid dimensions, filtering and
all integer loads; a resource cannot be reused merely because its CPU slice
has expired.

Next define and verify a bank-aware input binding contract against these
explicit copies, starting with a bounded set of integer-load consumers. Retain
full fallback, retry/publication ownership and complete physical ledgers. Only
then design live allocation and resource retirement. Asynchronous/in-flight
completion, API binding/unbinding, bounded work/backlog and diagnostic retention
policies remain open; current replay assumes ordered synchronous consumers.

Triple physical stepping, economical material error estimation, physical
closure/general convergence and full live head/source integration remain gates.
Runtime Lua/HLSL, calibration, INIs/materials, assets and earlier stages are
preserved. No reload/log request, installation, commit or push.

## 6. Reproduce

```text
docs/tools/check_s108_lifetimes.py
docs/tools/finalize_s108.py
```

The proof implementation is `docs/tools/s108_target_lifetime.py`. Baseline,
per-case resource DAGs, numerical/ownership report, source diff and delivery
audit are in `docs/diagnostics/2026-10-17/s108/`.
