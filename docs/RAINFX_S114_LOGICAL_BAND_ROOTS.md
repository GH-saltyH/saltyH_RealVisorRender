# s114 — logical-band GPU roots across calls

2026-10-17. **Status: ACTIVE — offline band-root descriptor and ownership policy.**
Production remains s87 physics with s89 diagnostics; no game build is installed.

## 1. Retain existing bands instead of their packed parents

s113 retained the complete GPU parents behind public/private end, mean and
history views. Consumers in the next call often need separate logical textures,
which caused new materializations. The graph already created the individual
band exports for publication/checkpoint retention and diagnostics.

s114 makes those **existing GPU band exports** the session roots. Every role
records its logical shape, source-resource shape, original parent and row
origin. The source resource must have exactly the logical shape and content,
and must already be a retained export. Selecting it cannot add a graph event.
Cache, headers and other full-resource roles keep their complete logical size.

For the reference graph builder, a new contiguous read-only ndarray represents
each logical band. This CPU copy rebases the oracle's descriptor/owner identity;
it does not upload state to GPU. At the next native call, protected inputs must
link to the corresponding retained GPU role/epoch. Uploading one instead is
still rejected before device creation. A given logical view is normalized once
per bundle, without deduplicating distinct outputs just because values match.

The D3D11 executor, shaders, physical expressions, logical zero-border rules,
completion drain,16-role atomic bundle swap and retirement checks are unchanged.
The `parents` research policy remains an executable fallback. These choices are
offline session metadata, not app settings or UI additions.

## 2. Evidence

- Twelve band-policy native calls retain the refused source/pool checkpoint,
  five aborted candidates, its successful GPU-only resume, and consecutive
  actual curved intervals in both axis orders.
- Eight additional native calls execute the current parent-root fallback with
  the same source/pool abort/retry sequence. All16 logical roles match at every
  corresponding call, including unpublished candidate packets.
- All192 logical roles across the12 band-policy calls match the frozen s113
  parent-root native fixtures byte for byte, using their original row offsets.
- All native graph outputs, imports and incoming roots match their single-draw
  upload oracle. The20 calls execute1722 draws,579 region copies and3251
  readback comparisons, with no checkpoint/produced texture uploads and no D3D
  debug warnings/errors.
- All seven stale-generation/missing-root/extent/partial-publication/upload
  guards remain valid. Complete root bundles and epochs survive every abort;
  both cache parents are reused during same-interval resumes without uploads.
- Source/pool once-only accounting and each curved interval's existing
  water/momentum residual gates remain valid. Final audit reconstructs binary
  graph lifetimes, pools, session epochs and import/root links independently.

MSVC `/W4 /WX` and FXC `/Ges /WX` remain enforced. Root mapping changes do not
widen any s110 unchecked-load proof or change a shader source body.

## 3. Cost comparison

| Complete call | s113 parent roots | s114 logical bands | Symbolic copy output saved |
|---|---:|---:|---:|
| Initial attempt | 23 copies | 23 copies | 0 |
| Later fresh interval | 26 | 23 | 12MiB |
| Two-attempt checkpoint resume | 44 | 38 | 24MiB |

Symbolic sizes use1024×256 RGBA32_FLOAT banks. The resume also avoids three
private-state materializations, beyond the three public-state copies introduced
by s113. Existing output-band copies remain; this does not remove all copies
from the graph. Shader draws and physical work are unchanged.

The12 band-policy calls use319 copies versus358 in the corresponding s113
sessions. Allocation **counts** move in the other direction: the planar stream
creates63 default targets instead of59, and each two-call curved stream creates
58 instead of54. Free-list reuse counts also depend on descriptor size, so they
cannot be treated as a memory-saving metric. Final audit reconstructs nominal
allocated/free/retained target byte extents and checks the native creation/reuse
counters to make this tradeoff inspectable.

In the captured8×32 planar stream, reconstructed default-target extent is
194,000 bytes after eight calls for **both** policies, with37,648 bytes retained
by roots and156,352 bytes free for reuse. All intermediate call boundaries also
agree in nominal bytes. The higher count reflects different texture sizes,
not a measured byte regression. Native creation/reuse/upload counts agree with
the independent free-list replay; these byte values are descriptor sums.

These are finite captured graphs with conservative diagnostic retention and
completion waits. Byte extents exclude imports, staging, buffers and driver
overhead; neither counts nor symbolic sizes establish peak VRAM, application
Memory or game FPS. Performance adoption remains withheld.

## 4. Next implementation

Bound target capacity, retirement and host metadata under longer repeated
accept/refuse/abort/new-interval sequences. Check whether the descriptor mix
reaches a plateau, protect incoming roots during reuse, and define a retirement/
capacity policy before permitting dynamic live workloads. Keep the parent-root
fallback and complete band/epoch/publication checks.

Economical material accuracy, bounded backlog, physical closure/convergence,
full head/source lifecycle, device failure recovery, asynchronous CSP integration
and target GPU timing remain open. Runtime, calibration, INIs/materials,
published assets and prior stages are preserved. No installation, game reload/
log request, commit or push.

## 5. Reproduce

```text
docs/tools/check_s114_bands.py
docs/tools/finalize_s114.py
```

Factory: `docs/tools/s114_band_session_reference.py`. The executor is the frozen
`docs/tools/s113_session_graph.cpp`; no new native shader or runtime module.
Evidence under `docs/diagnostics/2026-10-17/s114/` includes compressed fixtures,
explicit role mappings, parent/fallback comparisons, native logs, source hashes,
baseline and final audit. The archived session execution path is also checked.
