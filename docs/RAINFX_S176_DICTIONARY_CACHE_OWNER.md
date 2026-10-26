# s176 — dictionary-backed cache construction and replacement

Date: 2026-10-20. Status: ACTIVE (native cache/geometry component).

## Connected implementation

The s175 prebuilt geometry dictionary now supplies the actual-grid native cache
owner. `tools/s176_cache_owner.inc` and `s176_frame_cache.cpp` privately extend
the preserved s172/s173 execution and ownership paths. Existing sources and
production code remain unchanged. The new fixture ABI has a distinct magic.

The old du/dv image uploads are replaced by the2048×512 R32F index and two
1024×151 RGBA32F tables, totaling8.71875MiB. There are **no full-resolution
RGBA du/dv input allocations or uploads** in the new native programs. Original
DDS data is decoded on the CPU only to construct independent references.

Cold construction executes all34 cache passes. Its first two passes read the
dictionary at the exact original field-centre coordinates. Raw cells, world
metric, scalar area, connected runs, complete cache audit and compact SI force/
resolved-cell consumers retain their prior shaders/equations. The two4MiB
field du/dv copies remain construction scratch and retire after completion/audit.

Unlike the old private builder uploads, the dictionary bundle stays retained
for both cache and head-geometry readers. Each candidate generation shares
the same three immutable GPU objects. A pose change rebuilds field copies,
header and world metric without uploading geometry again; weather-only changes
share the metric and draw the new header. Geometry/table/position changes outside
this frozen geometry family are refused. This does not implement arbitrary
bake replacement, rescaling or changing topology.

## Head-geometry reader and ownership

Every successful frame also runs a native head-geometry reader over8,192
controlled positions. It uses the original full-resolution point-clamp domain
and reads both du/dv packets into a probe output. The results match the original
CPU source bits, including edge/outside positions. This executes alongside the
cache/physical preview on the same native context and shared input bundle.
It is a **geometry reader, not the SI head solver or birth/source pipeline**.

The dictionary is held through cache retirement and the head-reader batch.
Explicit old-generation readers retain their header, metric, force, geometry
probe and all three dictionary resources across later publication. These images
remain unchanged after weather and pose replacement. All dictionary/position
inputs are compared in full before/after the tested work; no table is released
independently while a generation still owns the bundle.

Two generations and two pending CPU contexts remain the bounds. Native event
completion is required before audit, retirement, disposal or publication.
A failed pose preparation remains quarantined even after completion; explicit
disposal permits retry with the same queued input and a new attempt identity.
The previous published generation and controlled water stock stay intact.
Reader returns are explicit and single-use; pending, stale, held-reader,
capacity, scale/header, foreign-table and foreign-position cases refuse unsafe
work. Fractional index and incompatible table shapes also refuse during native
program loading, before owner/device construction.

The injected failure tests a completed preparation's quarantine latch. Arbitrary
device loss and allocation-exception recovery are not demonstrated by this run.

## Results

The final suite executes **83 native WARP draws /11 observed completion events**
with19 strict shader bodies (two new,17 preserved). C++ builds with `/W4 /WX`;
the D3D debug layer reports no warnings.

- One complete cold build plus four successful geometry reads; one weather
  update, one failed rotated preparation/retry and return to the original pose.
- Every cache core and physical preview texel matches the frozen s173 full-build
  references for all four controlled frames. Headers, original/rotated world
  metrics and source-cell outputs retain their bits.
- Four independent double SI force checks pass the inherited32ε velocity gate.
- Shared dictionary inputs and head lookup results retain their bits throughout;
  previous-reader images stay valid through replacement.
- Queue saturation, stale/duplicate reader return and completed failure cannot
  pop a context or authorize early publication.
- Actual64MiB preflight refuses the replacement batch before allocation/draw.
  The existing96MiB local component reference cap remains the execution limit.

There is no water evolution or solver-clock publication in this component.
The source/head/transport/inventory owner verified separately in s174 is not
composed here. The four contexts are controlled derivatives of captured
frame660, not four new engine captures. Native events are not a general CSP
Canvas completion fence; no actual runtime provider is installed.

## Descriptor accounting

| New native component | Bytes | MiB |
| --- | ---: | ---: |
| Cold construction |48,490,144 |46.243805 |
| Core/dictionary after construction retirement, before previews |35,489,488 |33.845413 |
| Final core/dictionary/probes/physical preview |48,351,120 |46.111221 |
| Maximum across replacement/retry |**73,797,408** |**70.378693** |
| Separate audit staging maximum |48,333,760 |46.094666 |

Thirty construction-only objects retire after cold audit:29 cache intermediates
and the private raw-cell upload. The five core objects remain21.000793MiB;
the dictionary remains8.718750MiB. Full raw du/dv upload bytes are zero. CPU
fixtures/receipts, shader/driver allocations and staging are outside default
texture counts. These are actual native texture descriptor counters, not
resident VRAM or target-device timing measurements.

s173's reference peak was89.019135MiB. The new reference peaks at70.378693MiB,
18.640442MiB lower while additionally retaining the dictionary for head readers
and adding one head-probe output per successful frame. Final retained bytes are therefore
higher than s173's cache-only final set. The peak has moved from private raw
geometry upload overlap to concurrent old/new metrics and preview outputs.
The two workloads differ by those explicit reader resources; this is not a
claim of a23.28125MiB reduction in every phase or faster GPU execution.

Both the native component's70.379MiB peak and the preserved89.823166MiB warm
whole-pipeline proposal still exceed64MiB. Whole joint allocation, common optics,
curved SI head/source/film recurrence and measured target cost remain open.
The dictionary's extra dependent reads remain a timing risk from s175.

Next reduce per-resource preview/working retention and disabled-input storage,
keeping readers and retry stock valid, then compose an admitted actual-grid
source/head/transport/bank/time execution. Main app, settings, shaders, assets
and installed game are unchanged. No user game test is requested.

Evidence: `diagnostics/2026-10-20/s176/cache_checks.json`, native reports,
full-grid binary snapshots, head reference, numerical audit and `delivery.json`.
