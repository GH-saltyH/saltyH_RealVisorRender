# RainFX s70: when New Trail actually becomes a visible lens

Date: 2026-10-12. Status: REFERENCE — evaluation followed by s72 sampling and water-model calibration; game confirmation tracked there.

## Follow-up (2026-10-13)

s72 implements carried phase, subpixel integration/bandlimit, derivative support
and a separate water-model diameter/output calibration. Actual deposited normal
film now reaches production refraction in controlled GPU checks. See
`RAINFX_S72_TRAIL_SAMPLING_AND_DIAMETER.md` for changes, cost and verification limits.
The numbers and unchanged-runtime statement below describe the original s70
evaluation; they are retained as the historical diagnosis.

## User result and scope

The user confirms that the G-force FX disappearance and memory leak are
resolved. Those s69 fixes are accepted. The next observation is that the
integrated trail does not visibly refract in any tested environment.

This step evaluates current saved tuning and production shaders. It changes
diagnostics/documentation only. No runtime shader, settings or physics tuning
is changed. The measurements below are D3D11 WARP controlled readbacks, not
in-game trajectories, GPU frame costs or screenshots.

## 1. There is no rain-percentage or elapsed-time refraction switch

The descriptor first requires a live, same-generation moving drop in both
GPU banks, supported segment endpoints/intermediate samples, and completion
of birth hold. Current base hold is 0.6 seconds with per-slot 0.6–1.4 jitter,
so the descriptor gate opens at age 0.36–0.84 seconds. State birth ramp still
affects actual movement after that.

- Speed starts the thickness ramp above **1.3653 mm/s** and reaches full
  `Vn` at **34.1333 mm/s**. This is drop surface speed, not car speed.
- Diameter starts liquid eligibility above **0.20 mm**, reaching full size
  gate at **0.40 mm**. Smaller moving drops can still clear micro drops.
- Coating multiplies thickness by **0.35**, with a further multiplier down
  to **0.20** at low normalized speed. High shear can multiply by **0.40**.
- The separate size enhancement ramps from **0.40 to 2.50 mm**. Ordinary
  birth sizes rarely reach much of this ramp.
- Visor wetness follows supply with a **3-second rise time constant**:
  about 63% of the equilibrium target after 3 seconds, 95% after 9 seconds.
  Equilibrium is supply, not automatically 1.0. It boosts thickness by at
  most 1.6. Wind, facing and density affect supply and sheet width.
- History uses **max**, not additive deposition. Prewet deposition adds
  up to 15% locally, but repeated ordinary drops do not sum their water
  into a thick sheet. Rain does not directly impose a sheet height floor.

Current ordinary birth ranges from the production size function:

| Rain | Ordinary diameter | Approximate mean with current size bias 2 |
|---|---:|---:|
| 60% | 0.466–0.624 mm | 0.519 mm |
| 100% | 0.570–0.760 mm | 0.633 mm |

Rare births are only 0.650–0.930 mm. Coalescence can grow drops toward the
current 2.5 mm cap. Thus the older large synthetic trail tests were not a
good proxy for most ordinary newly born drops.

## 2. Optical thresholds are considerably more restrictive

Canvas G is a **dimensionless rendering height**, not measured micrometres.
It is not physically calibrated film thickness.

The New Trail silhouette threshold is hard-coded at G=0.015, with a narrow
soft band. Output then multiplies opacity by `smoothstep(0.015,0.20,G)`.
For example, before other alpha/coverage factors:

| G | Thickness-dependent opacity multiplier |
|---:|---:|
| 0.015 | 0 |
| 0.020 | about 0.2% |
| 0.050 | about 9.4% |
| 0.100 | about 44% |
| 0.200 | 100% |

Both the image shift and this opacity shrink as G falls. Additionally,
`min(TRAIL_REFRACT_PX, 2*radiusPx*REFRACT_D)` caps the shift gain by the
projected footprint diameter. The saved **34.5 px** is a cap, not a guaranteed
34.5-pixel distortion; raising it will not help when the diameter cap wins.
The saved `REFRACT_D` is approximately 0.73.

Legacy `SHEET_HEIGHT_MIN=0.75`, `SHEET_FORM`, `SHEET_THIN`, and old trail
texel minimum-radius/speed controls are not used to create New Trail liquid
height. They cannot force the old dramatic sheet effect in this mode.

## 3. Production-shader measurements with saved settings

Saved trail width is **0.26 D**, history **1024×256**, height gain **0.74**,
diffusion **0.05**, base lifetime **0.46 s**, sheet widen **1.0**. Tests use
equilibrium wetness, fully coated planar surface, head-free direct rendering,
and a complete 4:1 atlas projected onto a 2048×512 test target. Facing=1.
This isolates the trail from smear, E2/E3 and native occlusion. The optical
probe returns the actual production branch's offset and compositing alpha.

| Rain / air speed | Drop diameter / surface speed | Deposited G peak | Maximum alpha | Maximum image shift |
|---|---|---:|---:|---:|
| 60% / 120 km/h | 0.65 mm / 35 mm/s, aligned with atlas row | 0.0512 | 4.32% | 0.0124 px |
| 100% / 200 km/h | 0.76 mm / 35 mm/s, aligned with atlas row | 0.0349 | 0.97% | 0.0170 px |
| 60% / 120 km/h | 1.50 mm / 35 mm/s, between atlas rows | 0.0649 | 16.35% | 0.0742 px |
| 60% / 120 km/h | 2.50 mm / 35 mm/s, between atlas rows | 0.1771 | 94.38% | 0.4663 px |

Alpha and shift maxima are separate maxima, not necessarily the same pixel.
Their product is a diagnostic proxy for suppression, not an exact physical
or perceptual measurement. In the first case its maximum is 0.000535 px.
Changing screen projection changes the pixel numbers; these are not the
user's measured game-view shifts. They show that the production branch is
functioning but strongly suppresses ordinary narrow films.

With actual baked du/dv/support/coating maps, 96 ordinary 0.65 mm slots all
produced valid liquid descriptors. At 35 mm/s, aN=0.6 and W=0.65, coated atlas
G peaked at 0.0571. Direct optical output over fully coated pixels peaked at
5.64% alpha and 0.0331 px shift on the same test target. Their product peaked
at 0.00103 px. Other uncoated regions reach higher G; do not interpret this
as a proof that every possible surface position produces zero refraction.

## 4. Confirmed additional sampling and history problems

### Subpixel deposition is not translation invariant

The ordinary 0.65 mm case above has a physical full footprint width of
0.275 mm after sheet widening. On the controlled plane one vertical history
texel spans 0.781 mm. The current radius expansion uses `aa*0.5`, followed
by amplitude attenuation `width / sampledRadius`. It does not integrate
the full pixel footprint as its comment implies.

At exactly halfway between atlas rows the same 0.65 mm, 35 mm/s trail writes
**zero liquid G along the entire straight path**, despite descriptor G=0.1194.
At a row centre it writes G=0.0512. This is a reproducible sampling defect,
not a birth-hold, missing-generation or supply gate. The clearance A channel
uses a wider footprint and can remain present, so micro clearing does not
prove that liquid refraction is present.

### Diffusion removes narrow ridge height rapidly

At 60 Hz the saved 0.05 diffusion becomes **18.13% neighbor mixing each
frame**. The aligned ordinary path falls from G=0.0512 to **0.000584 after
0.5 seconds** without further deposition, well below the optical threshold.
This measured attenuation includes production exponential decay and
diffusion. Base lifetime alone is not a guaranteed visible trail duration.

### Prior validation did not establish ordinary-drop visibility

s67's descriptor/continuity fixture used a **2.4 mm drop, 0.70 D width**.
Its full optical fixture supplied a preconstructed **G=0.70** continuous
sheet. Those checks demonstrated functioning code paths, channel separation
and no bare-visor ghosting. They did not validate visible refraction for the
current 0.5–0.7 mm births, 0.26 D widths and lower coated G.

## 5. Recommended correction order

1. Correct subpixel path deposition with conservative support and a genuine
   pixel-footprint integral or bounded approximation. Preserve physical
   width and separate clearance A; test half-row, centred, diagonal and
   skewed real UV metrics. Increasing history size alone is not the first
   remedy because it increases per-frame resolve cost.
2. Separate liquid footprint coverage from thickness-dependent optical
   strength. Retain weak thin-film curvature without suppressing the same
   signal through both gradient and near-zero opacity. Calibrate against
   ordinary births and actual camera projections, with an untouched bare
   visor and no full-visor ghosting as required checks.
3. Revisit narrow-film diffusion/lifetime and the size enhancement range.
   A width-independent four-neighbor coefficient overwhelms subpixel
   ridges. Do not use an unconditional high thickness floor or additive
   overdrawing to manufacture a thick sheet.
4. If supply-driven rivulet accumulation is desired, specify a bounded
   thickness evolution separate from coverage. Current `max` history has
   no cumulative water-mass model; the earlier design description should
   not be read as an implementation of that model.

There is no evidence here that more full-size passes, CPU readbacks, increased
slot counts or GPU canvas resolution are needed to correct ordinary trail
visibility. The suggested first changes stay within existing descriptor,
resolve and optical passes. Their actual performance and final game look
must be verified after implementation.

## Evidence

- `docs/tools/evaluate_s70_trail.py`: current tuning, production descriptor /
  sparse history / optical branch; warning-as-error shader compilation.
- `docs/diagnostics/2026-10-12/s70/trail_visibility.json`: exact tuning,
  source/settings hashes, controlled cases and actual-bake samples.
- `docs/diagnostics/2026-10-12/s70/baseline/`: unchanged runtime and staged docs
  before documenting this evaluation.
