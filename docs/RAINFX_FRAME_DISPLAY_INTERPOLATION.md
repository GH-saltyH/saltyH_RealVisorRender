# 32Hz physical state → frame-rate display — 2026-10-25

## Latest game evidence and acceptance

User video: `격자찢김개선_트레일관찰_이동갱신품질떨어짐.mp4`, 114.067s.
Sixteen sampled timestamps show that fine trails can now be inspected after the
grid correction. The user still reports bouncing updates and broad undulating
film, including Light rain. **Game quality remains FAILED.**

The first sampled frame (2.3s) shows P0 idle. This is not sufficient evidence to
attribute the whole clip to old heavy-rain inventory. One later sample (38.433s)
shows Heavy Thunderstorm /100% rain; it does not verify the user's Light rain
condition. Keep weak-rain oversupply/persistent film as an open reported defect;
do not infer a measured weak-rain source rate from those screenshots.

## Concrete motion cause and implemented correction

Previously, the optical consumer replaced accepted states with no intermediate
positions. Physical steps remain32Hz. The new display module retains the previous
complete optical snapshot before rebuilding the current one. It interpolates:

- Surviving heads of the same slot generation: position, velocity and display volume.
- Contact radius: recomputed from interpolated volume and the existing contact angle.
- New/dead heads: volume fade at their valid endpoint, without joining reused slots.
- Film/micro heights: linear crossfade of the two complete reconstructed optical fields.

Head and field use one fraction from the paired GPU receipt end times. The host
advances display time with `sim.dt`, once per render frame, including frames when
the physics snapshot is reused. Pause therefore does not animate on wall time.
The display is delayed approximately one physics interval (31.25ms at normal
cadence); it does not extrapolate unaudited physical motion. Invalid intermediate
mesh support falls back to a valid endpoint. Publication gaps larger than four
steps snap rather than inventing long motion.

This is connected to the existing **P0 continuous physical RainFX preview**.
No new probe or menu is needed. App reload applies the shared runtime modules.
UI now reports `Display interpolation: frame-rate heads + film`.

## What this does not solve

This is presentation interpolation, not higher-rate physical integration or
advective film transport. A newly deposited segment fades into the optical field
as a whole: its visible tip is not rerasterized at an interpolated head position.
It reduces zero-order popping, but is not proof of perfect head/trail coherence.
Sharp32Hz force/path changes, long GPU publication gaps and the existing audit
latency can still limit quality. Actual CSP visual smoothness remains unverified.

Broad film remains physically pinned in this product path. Supply continues while
only evaporation/micro conversion remove or redistribute it. Bulk drainage/pool
return remains the next required model change; interpolation does not remove water
or make the weak-rain complaint acceptable. Impact allocation/material response
also remain possible contributors until evaluated with actual low-rain inputs.

## Cost and bounded evidence

Added seven RGBA32F canvases:128.25MiB at4096 heads /4096×1024 optics (128.125MiB
at2048 heads). Four archive draws per new snapshot and up to three display draws
per render frame; two of the display draws are only N×1 head data. No readbacks,
solver changes, source tolerance changes or physical display-gain feedback.

The full field blend reads two64MiB fields and writes one64MiB field. At60Hz
that is about11.25GiB/s nominal image traffic; archive read/write at32Hz adds
about4GiB/s. These are traffic estimates, not GPU timings or guaranteed costs.
Do not call it free or double the physical simulation rate to conceal it.

Local verification:7 native D3D11 WARP draws, four strict-compiled programs;
endpoints/midpoint, contact radius, birth/death, generation reuse, boundary fallback,
gap fallback and field phase pass. Actual visual-module lifecycle test verifies
async archive retry, cached-frame interpolation and same-frame deduplication.
Product regression:13 groups and8 existing native optical draws pass; deployed
game path resolves the same module bytes. Engine/solver calls in lifecycle tests
are mocked. These checks do not qualify hardware cost or game quality.

One implementation approach; no additional user game run requested this turn.
Next: one bounded bulk-pool/drainage candidate against existing flooded stock and
dry-start low-rain input, before another bundled in-game quality evaluation.
