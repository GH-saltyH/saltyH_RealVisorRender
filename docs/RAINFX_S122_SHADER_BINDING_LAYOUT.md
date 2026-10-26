# s122 — prepared shader binding layouts

2026-10-17. **Status: ACTIVE — offline shader metadata and packing path.**
Production remains s87 physics with s89 diagnostics. No CSP integration or
game installation is included. The requested consolidated roadmap/measurement
summary is [RAINFX_S122_PROGRESS_SUMMARY.md](RAINFX_S122_PROGRESS_SUMMARY.md).

## 1. Implementation

`s122_binding_layout.h` prepares constant-buffer slots/sizes, variable names/
offsets/sizes/scalar types and texture names/slots once when a shader enters
the existing bounded shader cache. The shader and a shared immutable layout
live in one cache entry. Admission's temporary cache copy shares that metadata;
it does not copy variable/layout vectors. Eviction releases the associated
layout with the shader. This is scoped to an immutable fixture program key;
hot replacement of file contents under the same key is not supported.

All target/input/shader capacity checks run first. On successful admission,
missing layouts are prepared and every draw in the candidate prefix is checked
against its bound constants and texture names. This happens **before** root
seeding, target/cache swaps, creating the flight or submitting GPU commands.
Failure leaves incoming roots unchanged. Preparing a shader may allocate shader
objects; the failure guarantee is not zero allocation or zero metadata work.

Prepared execution uses only cached layout metadata. Each draw packs its bound
interval values/defaults into zero-filled bytes at the reflected offsets,
preserving the old float bytes and uint conversion. Missing values and unused
padding stay zero; partial vectors also zero-fill their remaining components.
The exercised ABI supports float/uint scalars/vectors and contiguous float4x4
matrices in the existing order. Arrays, other matrix dimensions, other scalar
types and unsupported resource classes refuse instead of guessing a layout.
Finite values, variable extents/overlap, duplicate/out-of-range slots, input
widths and uint conversion range are checked. The cached texture list replaces
the per-draw reflected resource walk.

Constant-buffer creation is deliberately unchanged. The code creates a buffer
per packed constant block and binds it as before. This stage reuses **metadata**;
it does not claim reusable GPU constant-buffer storage or remove allocation,
pipeline setup, explicit Flush, test waits or diagnostics. Preparing and packing
per-flight packets with completion-safe bounded storage is the next step.

## 2. Comparison with the reflected path

The native executable has a `preparedLayouts` option. Both choices use s121's
immutable templates and owned interval/provider snapshots. Fifteen schedules
run reflected/full, reflected/lean, prepared/full and prepared/lean, including
admission recovery, delayed/failed completion, partial abort, cancel/reset,
template clear while pending and clear while in flight.

| Evidence per path | Reflected/full | Reflected/lean | Prepared/full | Prepared/lean |
|---|---:|---:|---:|---:|
| Commands / finalized flights | 526 / 56 | 526 / 56 | 526 / 56 | 526 / 56 |
| Physical draws / region copies | 4789 / 1563 | 4789 / 1563 | 4789 / 1563 | 4789 / 1563 |
| Metadata reflection traversals | 9578 | 9578 | 615 | 615 |
| Prepared layout builds | 0 | 0 | 615 | 615 |
| Preflight draw checks | 0 | 0 | 4789 | 4789 |
| Constant packs / buffer creations | 4714 / 4714 | 4714 / 4714 | 4714 / 4714 | 4714 / 4714 |
| Packed constant bytes, cumulative | 294256 | 294256 | 294256 | 294256 |
| Texture bindings | 22524 | 22524 | 22524 | 22524 |
| Per-flight diagnostic comparisons | 9003 | 0 | 9003 | 0 |
| Provider acquires / returns | 1423 / 1423 | 1423 / 1423 | 1423 / 1423 | 1423 / 1423 |
| D3D warnings/errors | 0 | 0 | 0 | 0 |

The primary matrix totals2104 commands/224 finalized flights. Final actual-GPU
root bytes, every full-mode output/import check, physical work, allocation and
publication match all four paths and s121. Backend expected-array bytes and
outstanding provider views remain zero. Template registration/binding/clear
ownership remains unchanged. A prepared/lean run with absent oracle files
opens zero oracles and its actual root dump matches independently.

One traversal means a complete constant-metadata or texture-metadata walk in
the old draw path, or one combined layout preparation in the new path. These
are not counts of individual COM getters. `D3DReflect` at shader creation still
occurs in both paths. The reduction9578→615 (93.58%) does not measure CPU ms,
GPU ms or FPS. Preflight adds value validation work. No net speedup is claimed.

These schedules reuse frozen8×32 physical candidates, including refused
checkpoints and retries.224 flights are not224 new weather intervals or a
complete live physical-lifecycle test. Shader bytecode/formulas are unchanged.

## 3. Refusal and packing contracts

The16 inherited template/provider malformed cases still refuse before the
affected candidate submits. Case17 registers a schema-valid16-float constant
and supplies it through a valid provider snapshot, but its actual shader slot
is only scalar/vector width. Prepared preflight refuses before root seeding
or any flight: submitted/finalized/epoch0, buffers/packs0, all33 acquired input
views returned. This verifies the shader-specific width check beyond the
template schema's generic limit. Cold layout objects may already be prepared.

A native layout contract compares packed bytes with independent literal uint
word arrays: float values, uint7.9→7, padding, missing values and partial-vector
zero fill. A second pack does not mutate the first. Ten refusal cases cover
invalid variable extent/overlap, buffer extent, scalar type, duplicate texture
slot, missing texture, excess value width, negative/overflow uint and NaN.
The prior distinct-interval/default-fallback/template-lifetime contract also
continues to pass.

MSVC `/W4 /WX` and the actual WARP debug layer pass. The independent audit
decodes graphs, input/oracle sidecars, commands and root dumps, replays
admission/cache ownership and derives layout build/preflight/reflection counts
per action. It checks packing/binding totals against the reflected path and
the separate literal-byte contract. Physical shader compilation/bytecode and
all earlier-stage sources/reports are preserved.

## 4. Delivery and remaining gates

The444-file baseline preserves53 runtime Lua/HLSL, three INIs and305 prior
s91–s121 files. Only the index/roadmap are updated among existing documents.
Eight new source/doc files provide this implementation and the progress
summary/report index. User materials, tuning and assets are unchanged.
No install, reload/log request, commit or push.

Next prepare bounded per-flight constant packets/buffer storage and verify
completion-safe reuse. A verified CSP adapter and live queue/backlog, economical
accuracy/convergence, full head/source lifecycle, common water optics, device
recovery and real target CPU/GPU measurements remain separate adoption gates.

## 5. Reproduce

```text
docs/tools/check_s122_layout.py
docs/tools/summarize_s122_progress.py
docs/tools/finalize_s122.py
```

API: `docs/tools/s122_binding_layout.h`; native engine/fixture:
`docs/tools/s122_layout_backend.cpp`; helper:
`docs/tools/s122_layout_reference.py`. Baseline, build, checks, compressed
fixtures/dumps, measurement index, source diff and independent delivery audit:
`docs/diagnostics/2026-10-17/s122/`.
