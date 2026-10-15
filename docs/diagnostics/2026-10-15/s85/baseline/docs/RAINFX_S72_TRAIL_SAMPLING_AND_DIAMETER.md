# RainFX s72: trail roughness, diameter calibration and cost

Date: 2026-10-13. Status: ACTIVE — low-cost corrections and model calibration
implemented and offline verified; game appearance/performance confirmation pending.

## User observation and constraints

The screenshot shows irregular water traces rather than smooth curves. The
user confirms WF Trail was **on when captured**; its saved off state is a
temporary test change. Current mobile birth-size profiles and micro pattern
size look appropriate. The requested correction must retain those visible
sizes while allowing the new trail model to produce thick flowing film.

## 1. Confirmed sources of roughness

### Segment-local phase restarted every frame

Old `rgEval` measured bead/ripple position from each segment's start. Adjacent
segments consequently started their sine patterns again at zero. Even a
straight, constant-speed path received mismatched thickness patterns. Slot
seed did not fix this because it stayed constant while the segment origin
moved. Such thickness seams alter refraction without a kink in drop motion.

New descriptors retain accumulated distance in footprint-diameter units,
paired with generation. A fifth row stores begin/end phase and generation.
Descriptor banks publish with the same successful history as heads/trails.
Pinned/suppressed live drops retain phase without stamping liquid; rebirth
and unsupported exits reset it. Pending retries cannot publish stale banks.

In the controlled GPU descriptor test, the old unit-amplitude ripple seam
jump was **0.5285**; carried phase produced **0**. This is a phase fixture,
not a recorded gameplay trajectory or a claim about every screenshot pixel.

### Bead/ripple periods were below the atlas sampling limit

Saved tuning during this investigation: 1024×256 history, width 0.21 D,
bead cycles 5/D, noise 0.75, ripple 0.08, minimum footprint 0.147 mm. A
0.65 mm output drop produced a developed old-size film only about 0.222 mm
wide. Its bead period was about 0.0445 mm and its ripple period 0.222 mm.

Sampling actual baked UV metrics at 4096 valid sites in eight directions,
for this controlled diameter/shear, both frequencies were unresolved in
all sampled cases. Directions are sampled, not actual recorded velocities.
These waves became alias patterns; increasing noise frequency could not
increase meaningful detail.

The existing resolve now attenuates unresolved ripple amplitude and replaces
unresolved bead modulation with its analytic mean (0.46875). Resolved detail
retains the artist controls and uses carried phase. Unresolved candidates
skip sine evaluation and the extra phase-row fetch.

### Thin paths were inadequately sampled, then differentiated below a texel

The old radius expansion did not integrate the pixel footprint; some paths
between rows wrote zero liquid despite a valid descriptor (s70). The new
resolve integrates a transverse parabolic profile over pixel support with
bounded endpoint support. Translation from between rows to a row centre
preserved total deposited thickness exactly in the controlled test. Peak
height legitimately changes as subpixel coverage is split between rows.

New Trail lens derivatives now have a half-history-texel support floor in
physical units. This avoids cell-to-cell slope steps when the diameter-based
tap is much smaller than one history texel. It reuses the same four height
taps; no new texture or render pass is required. Head/micro derivative code
is unchanged.

### What remains a trajectory question

Each frame still deposits a straight **UV segment** between current/previous
GPU positions. Geometry transport, steering, coalescence and coating can
change actual velocity; coalescence also changes the centre. A single image
cannot establish whether every remaining corner is a real motion turn or
an optical/sampling seam. No delayed CPU trail stamps or 384-stamp budget
were reintroduced. The new fixes target demonstrated artefacts that occur
even with a smooth input path.

## 2. Diameter audit

The accepted output-reference profile gives the following ordinary births:

| Rain | Accepted output/reference diameter | New water-model diameter, ×3 |
|---|---:|---:|
| 3% | 0.35–0.45 mm | 1.05–1.35 model mm |
| 50% | 0.44–0.59 mm | 1.32–1.77 model mm |
| 60% | 0.466–0.624 mm | 1.398–1.872 model mm |
| 100% | 0.57–0.76 mm | 1.71–2.28 model mm |

Rare output births remain 0.65–0.93 mm, corresponding to 1.95–2.79 model mm.
The reference-state radius, original mobile birth profiles, head kernels and
micro bake spacing/size are retained. **Model mm are calibrated water-response
units, not a claim that SI mass/contact radius were enlarged threefold.**

| Mechanism | Actual restriction / domain |
|---|---|
| New Trail size response, 0.4–2.5 mm | At the mean birth diameter, response was only 0.0092 at 60% and 0.0343 at 100%. The new model maps these to 0.5755 and 0.8017. These are response values evaluated at the mean diameter, not averages of nonlinear responses. This was a major active restriction. |
| New Trail minimum diameter, 0.2–0.4 mm | Some smallest dry/light moving drops previously received partial presence. It does not gate the separate static micro layer. |
| Head puddle lobes, minimum 1.4 output/reference mm | Ordinary and rare births cannot qualify directly; coalesced drops can. This controls head shape/size, so it retains the accepted head profile rather than enabling lobes on nearly every birth. |
| Legacy impact shape, fast 1.4 / large 3.0 mm | Initial births are below these fixed thresholds. The legacy feature defaults off and is distinct from active splash v2. These are not New Trail sheet gates. |
| Active splash v2 | Heavy-size percentile (default 50%, about 0.665 reference mm at full rain) and speed selection; current profiles can qualify. It is not blocked by the legacy 1.4/3.0 mm thresholds. |
| Large-head optics | Projected pixel-radius gates, 8–30 px; enlarging a model label cannot substitute for a larger apparent head. |
| Reference motion / mass | Speed curve clamps diameter below 0.5 mm; normalized mass profile is almost 1 for these small births. The accepted core motion shaders and parameters are unchanged. Wet-path feedback can respond to the stronger new film. |
| Static micro pattern | Nominal 0.46 mm controls bake grid/spacing and disk radius distribution. Micro disks have no mobile slot trajectory and cannot deposit mobile trails. Increasing this input without compensating spacing would change both visible size and density. Its current output remains unchanged. |

A full SI/contact-size remap would also change aerodynamic acceleration,
mass, merge/contact reach and speed calibration. It is not necessary for this
water-response correction. This implementation deliberately separates the
new film model from already accepted motion/visible grain sizes.

## 3. Implemented diameter/output calibration

- `RAIN_NEW_TRAIL_MODEL_DIAMETER_SCALE = 3` feeds model diameter into size
  response, presence and radius-proportional deposition.
- `RAIN_NEW_TRAIL_OUTPUT_DIAMETER_SCALE = 1/3` retains thin-trace and clearing
  footprints. Heads/micro retain their original profile automatically.
- Developed sheets blend from compensated thin width toward **model width**.
  Applying output compensation to the entire developed sheet would retain
  the very narrow footprint that starved the previous model.
- Film height now scales with model radius (diameter normalised at 1 model
  mm). The existing height slider is labelled accordingly; coating, shear,
  wetness, hold, support and max-history restrictions remain.
- Lifetime diameter is decoded with the same sheet/output compensation and
  shear widening used for deposition.

Model factors 1, 3 and 4 were tested. Factor 3 places normal heavy births
inside the response ramp while retaining variation; factor 4 puts part of
the ordinary heavy profile beyond its 2.5 mm full-response limit. Factor 3
is the selected starting calibration, exposed in UI rather than hidden in
fixed birth-size edits.

For a controlled coated 0.65 mm output drop, wet=0.8, shear=0.6, full speed:

| Test under the corrected sampler | Model ×1 | Model ×3 |
|---|---:|---:|
| Film descriptor G | 0.0889 | 0.6319 |
| Deposited G peak between rows | 0.00835 | 0.17586 |
| Developed film full width | 0.2225 mm | 0.6550 mm |
| Production lens maximum alpha | 0 | 0.95335 |
| Refraction RGB difference against zero lens | 0 | 0.09375 |

The lens test feeds **actual deposited history** into the current production
shader on D3D11 WARP, using a controlled checker scene and screen projection.
Bare-visor contribution is zero. These are not gameplay screenshots or GPU
hardware timings; RGB difference is not a physical pixel displacement.

## 4. Cost comparison

| Option | Cost evidence / assessment |
|---|---|
| Implemented phase carry | Four existing passes retained. Two 4096×5 RGBA32F descriptor banks replace one 4096×4 bank: **+384 KiB**. Descriptor pass adds 4096 output pixels, not a whole atlas pass. Resolved candidates add at most one phase fetch; unresolved ones skip it. Low fixed cost. |
| Implemented pixel integral and frequency filtering | Additional bounded arithmetic inside the existing resolve; no extra full-size reads/pass/canvas. Sine/phase work is skipped for unresolved detail. Wipe-only work exits before liquid math. Low relative cost, not a measured FPS guarantee. |
| Implemented derivative support floor | One physical texel-span calculation in the trail branch, same four height taps. Low cost. |
| Wider model sheets | Actual baked 4096-slot, 100% birth-range fixture: tile candidates **6747→6757**, about **+0.148%**. Wider rendered water can also change colour-pass coverage; this count alone does not measure total GPU time. |
| 2–3 segment/Hermite curve approximation | About **2–3× closest-segment arithmetic per affected candidate**, additional control data/bounds and hole checks. Does not imply 2–3× whole-app cost. Moderate; reserve for confirmed trajectory/chord corners after these fixes. |
| Double history width and height | 1024×256→2048×512 means **4× history pixels and memory**. Resolve/diffusion work grows accordingly. Higher cost; not selected. |

Current history resolution stays 1024×256. No full UV conversion, CPU trail
readback, per-drop UI stamping, new scene capture or forced GC is added.
Descriptor/history allocation is bounded; count changes dispose old banks.
Actual game GPU ms/FPS still needs confirmation at 60% and 100% rain.

## Verification and review

- `check_s72_trail.py`: size mapping, output compensation, integrated thickness,
  phase continuity, pinned phase retention, generation reset, preserved mobile/
  micro profiles and core physics shader text.
- `check_s72_lens.py`: deposited normal film visibly refracts the controlled
  scene; substantial alpha and zero bare-visor ghost contribution.
- `audit_s72_frequency.py`: actual baked metric sampling / frequency audit.
- `bench_s72_tiles.py`: actual baked 4096-slot candidate work comparison.
- Updated `check_s67_runtime.py`: six bounded allocations, pending retries,
  phase-bank publication, resize disposal and existing pending/migration gates.
- Updated `check_s67_gpu.py`: connected paths, eligibility, clearance-only
  micro, no additive thickening, decay, coating/shear, skew and hole clipping.
- Actual descriptor/resolve and colour/depth wrappers compile with FXC
  `/Ges /WX`. Descriptor has one initialized return, including held phase,
  to avoid the wrapper's X4000 false-positive path.

Reload the app and **enable WF trails** for review; the user's saved temporary
off state was retained. Check smoothness with Bandlimit and Pixel integration
on, first without smear, then with the accepted smear. Review the model factor
3/output compensation 1/3 before moving to expensive curve subdivision.

Artifacts and step-specific source diff:
`docs/diagnostics/2026-10-13/s72/`. No actual gameplay trajectory trace has
been recorded, so remaining physical turns are not claimed eliminated.
