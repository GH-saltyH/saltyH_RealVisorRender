# s104 — shared local geometry for recipient force and post

2026-10-17. **Status: ACTIVE — offline prototype.** Production remains s87
physics with the existing s89 diagnostic; this stage does not install a build.

## 1. Implementation and reuse invariant

The fused recipient/post shader previously called `stepMetric` separately for
force relaxation and post projection/evaporation. Both calls read the same
immutable cell and format2 cache. Recipient force changes momentum while
retaining the cell and volume, so the geometry metric is identical at both
points in this shader.

s104 computes normal, area and geometry validity once per wet output invocation
and passes them into `stepForceMetric` and `stepPostMetric`. The original donor
and standalone-post entry points remain as wrappers. The unchanged physical
function bodies are adapted with exact asserted anchors; SI relaxation, full
travel mean, end-force halves, force/wall summation order and evaporation
expressions remain intact. Input packets and output packets use separate local
variables to avoid input/output argument aliasing.

`metricValid` describes geometry only. The force helper adds its own checks for
viscosity, air, force coefficients and research depth, without changing the
shared flag. Post still checks geometry and evaporation independently. Thus a
valid surface can still project and evaporate when a force-only parameter is
invalid, matching the previous behavior and failure statuses.

Dry packets skip metric evaluation. Format2 cache preparation, lifetime,
pose/receipt checks, projection maps, interval clock and publication schemas
are unchanged. The reuse invariant must be revisited if a future recipient
operation changes its cell or volume before post processing.

## 2. Verification

Strict FXC `/Ges /WX` compilation and D3D11 WARP execution pass.

- **20 physical cases** produce bit-identical normal/area, four-bank donor
  force and five-bank recipient/post outputs against s103. Coverage includes
  airflow, full evaporation, zero dt, disabled recipient force, affine/reflected
  transforms, invalid area/geometry, independent Gram validity and normal
  support cutoffs. Added cases exercise invalid air density/Cf/evaporation/
  research depth and valid zero-viscosity motion.
- Invalid viscosity, air density, Cf or research depth gives two force-failure
  statuses while valid post still evaporates: the combined status is2. Invalid
  evaporation gives zero evaporated packet, unchanged end packet and status3.
  These explicit checks guard the separation of force and geometry validity.
- Standalone post wrappers match bit-for-bit in ordinary and invalid-viscosity
  cases. The donor wrapper also retains its old output and compiled work.
- The actual curved-mesh uncontrolled publication and an **accepted embedded
  interval** match s103, including end/head/ledger/clock/snapshot and error
  indicators. Embedded volume residual is-6.722e-7 mm3 and maximum momentum
  residual1.150e-7 mm3 m/s.
- A force-free fractional packet trial is geometrically eligible but fails
  accuracy. Its error indicators and private progress match s103; public
  stocks and the full unspent interval remain unchanged.
- Source/pool refusal, resumed/together completion and old/new joint publication
  match, with source and pool transfer applied once. Volume residual5.079e-8
  mm3. Existing pose/version/grid/format/readiness/interval ownership and pending
  cache/map/snapshot fences pass using the preserved regression fixtures.

Projection, cache preparation/receipt and context source are checked unchanged
against s103. Regression adapters retain fixture hashes; prior fixtures and
evidence remain unchanged. These specified checks do not establish universal
float32 equivalence or physical accuracy.

## 3. Cost

| Compiled shader | s103 static instruction lines | s104 static instruction lines |
|---|---:|---:|
| Donor force | 221 | 221 |
| Fused recipient/post | 302 | 271 |
| Cache preparation | 65 | 65 |

Static texture-load lines in the fused shader decrease12 to9: the repeated
two-basis and area reads disappear. The source has one local metric evaluation
in its fused main, and neither shared helper evaluates it again. This is **once
per output invocation**; the packed five output banks still repeat invocations
for each cell. Cross/normalization, area read, physical relaxation and packed
outputs still have costs.

No draw or retained cache bank is added. At1024x256, cache extent remains12 MiB
plus144 receipt bytes. With `A` attempted steps per host call, including refused
attempts, fresh/resumed embedded graphs remain18+51A /16+51A. One fresh attempt
uses69 draws; three use171. The original tolerances are unchanged.

Static code/load counts are not dynamic instructions, memory traffic, peak
allocation or GPU time. Target-game FPS benefit is unmeasured.

**Decision:** keep the shared local geometry path; specified semantics and
physical outputs are preserved with reduced compiled work and unchanged cache/
pass counts.

## 4. Next implementation and adoption limits

Specialize the unpublished coarse candidate used by embedded accuracy. Retain
its end packet, evaporation/runoff and status required by error comparison;
keep the complete fine-candidate ledger used for publication. Compare error
indicators, decisions, refused-time retention and final stocks against this
full reference while removing unused coarse outputs/ledger work. Keep the
existing tolerances and prior counterexamples.

The triple physical candidate, economical material error estimation, pressure/
contact-line/high-shear closure, general nonlinear convergence, full head/source
lifecycle, live backlog/cache retirement/recovery and actual game timing remain
adoption gates. Production Lua/HLSL, calibration, user INIs/materials, published
assets and earlier stages are preserved. No reload/log request, installation,
commit or push.

## 5. Reproduce

```text
docs/tools/check_s104_physics.py
docs/tools/check_s104_transactions.py
docs/tools/check_s104_cost.py
docs/tools/finalize_s104.py
```

Baseline, reports, strict disassemblies, source diff and delivery audit:
`docs/diagnostics/2026-10-17/s104/`.
