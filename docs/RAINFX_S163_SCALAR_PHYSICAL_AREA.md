# s163 — scalar physical area and recurrent reservation

2026-10-19. Status: ACTIVE, offline candidate. Production physics remains s87,
diagnostics s89. Main app, settings, production shaders and game files unchanged.

## Decision and scoped ABI

The current film force/post/exchange consumers read the old area packet as:
`all(isfinite(cell)) && cell.r > 0 && cell.g == 1`. Only `cell.r` enters the
physical equations; coverage/coating in `cell.ba` are checked for finiteness.
Those two channels do not drive these frozen consumers. This is a scoped film
area contract, not a replacement for general surface/coverage/coating metadata.

The new layout `validated_scalar_mm2_r32f_v1` stores physical area in an R32F
texture. The producer retains the original header, support and finite-cell
validation, the exact `cell.r × worldScale²` expression and binary32 precision.
It writes scalar area directly; it never allocates an intermediate RGBA area
target. Unsupported cells remain zero. Nothing is quantized to half precision.

The checked consumer reconstructs `(area, area>0 ? 1 : 0, 0, 0)` and retains
the old validity predicates. It rejects wrong parent dimensions with a finite
negative-area marker and zeroes logical out-of-range/mip reads. Actual R32F
sampling supplies zero G/B and one A, so an explicit adapter is necessary;
binding it to an unchanged legacy RGBA consumer would not work. The owner must
honour the declared format, as well as the shader's extent checks.

For old test fixtures only, a GPU conversion checks **all four original
channels**, preserves valid area bits and encodes invalid packets as negative
area. This fixture conversion is counted separately; it is not a recipe pass.
Invalid validity, nonfinite coverage/coating, negative area and NaN area still
refuse. The owned cache's immutable-cell audit reconstructs the old metadata
from its cells input, and keeps its original CPU sample/pose/topology checks.
Future head/birth/coating consumers must use their metadata inputs, not infer
those properties from scalar area. The field-centre-only geometry scope remains.

## Native format and physical verification

The new typed single-draw WARP runner really allocates R32F inputs/targets,
uses their four-byte row pitch and reads back single-channel results. Other
targets remain RGBA32F. It is compiled with `/W4 /WX`; shader bodies use
`/WX /Ges`. The final builds are warning-free. The first audit-atlas expression
hit an FXC internal operand mismatch; an equivalent scalar component selection
replaced it, without suppressing warnings or changing physical equations.

- Owned cache:34 native draws /11 strict bodies;19 protocol cases cover
  pending input/shaders, unknown submission, read failures, cancellation,
  malformed observations and stale geometry. Full-grid scalar area bits match
  the old R channel; metric and connected runs match in every component.
  Pose/sample/area/support audits pass. Nominal retained descriptors remain34
  canvases and decrease32.3992→29.3992MiB.
- Transport:34 paired s162/s163 cases,15 accepted/19 refused. All non-injected
  roots, ledgers and intermediate status tiles retain their bits. Tests include
  actual1024×256 geometry, both axis orders, direct packed resume, dry/static
  film, ragged supports, pinned heads, evaporation/viscosity and five malformed
  area packet controls. Existing closure bounds are unchanged.
- Targeted resume:malformed bank/area parent shapes and nonfinite scalar area
  refuse with valid packed stock; an injected failed interval
  preserves water, checkpoint and debt. Retrying the rollback bank matches
  uninterrupted continuation in every root, bit for bit.

Transport2,920 WARP draws /35 strict bodies; targeted resume326 /27; cache34 /11.
Total **3,280 native draws /73 strict shader compilations**. This includes40
legacy-fixture area conversions and244 diagnostic band-consumer draws. The
production candidate itself stays47 passes and58 resources, including11 imports.

The native draws serialize uploads/readbacks. They prove actual typed numerical
behaviour, not a persistent native pool or measured GPU memory/time. The
actual-grid fixture is frozen frame660 geometry with controlled1µm film,
0.1µm pinned micro and4096 empty head slots. Continuous weather, active4096-drop
load, thick/high-Courant accuracy and evolving head/film coupling remain open.
No new CSP/game observation was performed.

## Full recurrent accounting

MiB=2²⁰ bytes. Retain the entire previous packed End/Mean bank and all immutable
input leases; count the shared area exactly once across graph and cache.

| Actual1024×256 /4096 slots | s162 | s163 |
| --- | ---: | ---: |
| Area target |4MiB RGBA32F |1MiB R32F |
| Owned cache descriptors |32.3992 |29.3992 |
| Shared metric/runs/area imports |20 |17 |
| Separate graph, fresh /packed resume |77.8440 /81.8440 |74.8440 /78.8440 |
| Separate graph+cache, packed resume |94.2432 |91.2432 |
| Proposed exact pool+cache, fresh |62.2272 |59.2272 |
| Proposed exact pool+cache, packed resume |66.2272 |**63.2272** |

The recurrent descriptor plan is66,298,512 bytes, leaving810,352 bytes
(0.7728MiB) beneath64MiB. Its35 private slots are unchanged. Status diagnostics
raise this to63.2428MiB; late donor-force/exchange diagnostics reach71.2428MiB
and **do not fit**. The last-read plan checks exact formats, immutable input
leases, no read/write overlap, prefix ownership and physical-root pins.

This passes the **specified recurrent descriptor reservation gate**, not actual
allocation, completion or runtime admission. Current separately retained graph
descriptors still exceed64MiB. Source-image caches, driver overhead, active
head/birth evolution and multiple in-flight graphs are excluded. The margin is
small and must not be used as permission to omit another live lease.

### End-only copy comparison

An explicit alternative adds a checked W×H End-copy pass after packed export,
while retaining the packed output for its Mean consumers. With H-row recurrent
input and a confirmed retired previous Mean lease, its exact-shape proposal is
62.2272MiB. It needs one extra pass, one4MiB output and at least8MiB of extra
read/write traffic per interval. Its End target can reuse an expired map-shaped
slot in the **analysis**; no allocator or cross-interval release is executed.
Keeping a previous packed output for an unfinished reader costs more and cannot
be silently excluded. The comparison is a descriptor plan, not a native timing
or handoff execution result.

Scalar area is selected for the next native-pool candidate:it meets the scoped
reservation gate with no additional transport pass or handoff copy, retains
physical area precision and reduces nominal cache storage. The End-copy option
keeps1MiB more planned headroom but adds bandwidth and an output lease; target
GPU timing could change the eventual choice. No speedup is claimed.

## Next

Execute the selected typed exact-shape pool with immutable input and exported
row-band ownership. Verify pending/failed submission, ordering/completion and
recurrent cache/output leases before permitting reuse or publication. Then
reassess complete input/head/birth costs, common optics and warm-run game
performance. The small descriptor margin is not a complete application budget.
No additional user game test is required for s163.

Evidence: `docs/diagnostics/2026-10-19/s163/field_checks.json`,
`lean_checks.json`, `resume_checks.json`, `cost_checks.json`, `lifetime_plan.json`,
`end_copy_comparison.json`, typed native executable/build log, compiled shaders,
both array archives, generated harnesses and `delivery.json`.
