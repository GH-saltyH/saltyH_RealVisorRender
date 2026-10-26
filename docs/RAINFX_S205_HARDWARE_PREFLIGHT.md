# s205: hardware preflight and isolated cache transfer cost

2026-10-21. Parent s204. Status: ACTIVE. Offline native D3D11 only.

## Result

The detected adapter 0 is an NVIDIA GeForce RTX 3070, vendor/device 4318/9348,
LUID 0:67676, with D3D feature level 11.0 and FP64 shader operations. The selected
device is explicitly created from that hardware adapter. Software devices and
automatic WARP fallback are refused. Two RTX 3070 adapter entries were enumerated;
this test uses index 0 only. Its identity is recorded, but the adapter used by the
running game has not been established.

Hardware exact byte-predicate controls pass, including signed-zero and NaN-payload
mutations. An isolated 8 MiB duplicate-copy/read benchmark completes an ABBA
sequence. The complete physical owner does **not** pass its hardware startup gate:
its WARP-derived expected metric atlas differs from the hardware result. The
strict predicate is retained and rejects both debug and release runs before
physical execution, bank publication or solver clock advancement.

This is a completed hardware preflight and component measurement. It is not a
256-interval hardware result, a complete pipeline benchmark, a game integration,
or evidence of game FPS improvement.

## Portability failure and diagnosis

Both final runs execute the same 34 bootstrap cache shaders and 10 staging copies.
All 640 atlas words are saved, along with every existing bootstrap proof image.
Debug and release outputs match each other in full bytes. Against the frozen
WARP output:

- 30 of 640 atlas words differ: eight metric fingerprint words, the normalized
  audit maximum, and 21 sampled Gram-matrix values.
- The complete packed metric differs in 52,937 of 2,097,152 FP32 words. Its maximum
  absolute difference is 1.1920928955078125e-7.
- Cells/support, context header, areas, connected runs, geometry index/table,
  head positions and source stock match their full expected bytes.
- The cell-audit failure count remains zero. Its normalized maximum is
  0.0234149359 on hardware versus 0.0243627094 in the WARP reference, both below 1.

An independent float64 diagnostic reconstructs field-centre geometry from the
immutable seven-word dictionary, applies the context pose using CPU matrix
multiplication, and checks the full 1024 x 256 field. The existing cache audit's
dimensionless 1e-5 bounds are retained for this diagnostic:

| Diagnostic over all 262,144 cells, 123,224 supported | Maximum normalized error | Bound |
| --- | ---: | ---: |
| World u/v transformation | 0.0145600 | 1 |
| Stored Gram diagonals | 0.0135595 | 1 |
| World area | 0 | 1 |

Connected-support boundaries independently reconstructed on the CPU match every
cell. All unsupported metric cells remain zero and supported determinants remain
positive. These observations locate the difference in world-metric arithmetic,
with unchanged source data and topology. They are consistent with FP32 backend
rounding differences. The exact compiler instruction responsible has not been
isolated, and full transport sensitivity has not been measured.

The independent numerical diagnostic does not waive the exact atlas gate or
replace the full-byte reference. No hardware-generated reference is adopted.
The old WARP fixture, shader binaries, tolerances and all prior evidence remain
unchanged. Preliminary failed attempts are retained separately; only the final
`portability_debug` and `portability_release` runs are authoritative and bind the
execution to the final executable SHA.

## Isolated duplicate-copy/read measurement

The component creates one 1024 x 512 RGBA32_FLOAT texture (8 MiB), initialized
with deterministic raw words including signed zero, NaN, infinity and subnormal
patterns. The before/after physical cache graph is outside this experiment. It
measures just the duplicate post-metric copy/read eliminated by s204:

- A: two staging copies, two complete CPU reads, two complete byte predicates.
- B: one staging copy/read, reused by both complete byte predicates.

Both 8 MiB staging allocations remain retained in both modes. The experiment
claims cumulative transfer reduction, not an 8 MiB retained-memory saving.
Initialization uploads are outside the repeated measurements. Eight warmup
trials precede four blocks A/B/B/A, each with 64 trials. All 256 measured trials
pass both exact predicates; the separate hardware probe passes ten witness
controls and six actual-copy/mutation cases.

| Mean of the two blocks for each mode | A: duplicate reads | B: reuse |
| --- | ---: | ---: |
| Copy/read bytes per trial | 16 MiB | 8 MiB |
| GPU copy timestamp intervals per trial | 1.149 ms | 0.396 ms |
| CPU allocate + row copy per trial | 4.799 ms | 2.529 ms |
| CPU completion wait per trial | 8.871 ms | 10.201 ms |
| Mean block wall time, 64 trials | 1.087 s | 1.000 s |

The GPU timestamps are intervals around copy commands, not hardware busy counters
or pure memory-engine bandwidth. The observer adds timestamp commands and uses
a fixed capacity of 128 query pairs plus one disjoint query (257 retained query
objects). It creates no default textures and adds no completion event. Measured
blocks use at most two pairs per completion and report no invalid/disjoint batch.
Existing event completion and 1 ms polling sleeps remain; this scheduling and
other machine load can dominate observed wall time, as the wait column shows.
These four short blocks do not establish a statistically reliable end-to-end
speedup. They cannot be extrapolated to FPS or to the cost of the physical owner.

The component's 8 MiB default texture and 16 MiB staging retention are separate
from the s204 physical owner's scoped descriptor budget. Query/driver/CPU memory
are also outside that budget. Native C++ builds use /O2, /fp:strict, /W4 and /WX;
the component timing uses a release device, while adversarial controls and one
startup run use the debug layer. The checked debug runs report no warnings.

## Next implementation and acceptance criteria

Before further complete-pipeline timing, introduce an explicit backend reference
qualification path:

1. Qualify both pose-dependent world metrics against independent CPU geometry,
   units, support, Gram and area checks. Bind the receipt to adapter identity,
   complete immutable inputs, context and shader binaries. This stage checks
   only the initial pose and does not yet provide that two-pose receipt.
2. Separate cross-backend numerical qualification from same-backend corruption
   detection. A qualified, immutable hardware reference may then be proposed;
   every subsequent rebuild must still match its full bytes. Do not silently
   replace the expected image with the current unqualified output.
3. Retain source retry, pending-reader protection, failure quarantine, rollback,
   exact accepted-time accounting and the existing scoped texture cap. Verify
   hardware shadow/reuse state, ledger and clock parity over all 256 intervals
   and the forced budget stop before interpreting integrated cost.
4. Complete instrumentation coverage for uploads, adaptive bounds/carry and
   allocations, then measure complete execution, validation reads and completion
   costs with optional archives disabled. The unexecuted continuation code in
   this experimental owner is not a qualified full-pipeline timing tool.

CSP scheduling/completion, physical/time accuracy, whole CPU/startup streaming,
true long duration, common optics and live adoption remain open. Production stays
s87 and diagnostics s89. Main, settings, production shaders, assets and installed
game files are preserved. No new user game test, commit or push is needed here.

Evidence: `diagnostics/2026-10-21/s205/target_checks.json`, `target_audit.json`,
adapter inventory, full bootstrap images, exact-byte probe, ABBA trial records
and timing reports. Finalization rechecks saved data and archives only this
stage's own binary payloads, without another GPU run.
