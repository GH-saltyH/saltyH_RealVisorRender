# RainFX local impact film prototype — 2026-10-07

Status: **ACTIVE, opt-in, awaiting in-game visual and performance validation**.

## Goal and reference comparison

The current WF trail already carries plausible direction and refraction, but
its covered area is limited by drop paths and radii. In the supplied real
visor and car-glass clips, a strong water encounter covers a much wider,
irregular patch for a short time, then drains into narrower streams. The
project trail clip has the narrower streams and individual drops; the new
layer supplies only the missing transient area. It must not replace or
retune the trail.

The removed `RAINFX_FLOW_LAYER.md` and `RAINFX_SPRAY.md` attempts used
global/coarse masks and a speed/rain gate. They lacked local impact origins
and moving thick edges. Do not restore a whole-visor blanket or a nose-
centred radial wipe for this feature.

## Continuous influx revision

The user observed patch pop-in/out with the initial defaults; slider tuning
could soften it. The heavy-size-only birth cluster was subsequently rejected:
size does not establish arrival density. This revision removes that gate and
the discrete patch/cooldown source.

`RAIN_DYNAMIC_IMPACT_SHEET_ENABLED` defaults off. The source rate is computed
from rain intensity and frontal relative airflow, independently of slot count:

`influx = rain^3 + rain * max(dot(carVelocity - wind, cameraLook), 0) * 3.6 / 180`

This is a provisional dimensionless curve, not a calibrated rainfall model.
The rain-only term allows extreme rain to feed film at rest. The airflow term
counts the component toward the visor, not the magnitude of side or tail wind.
Wind uses the project's existing axis setting. The 180 km/h reference and
rain exponent are initial experiment values; no realistic detailed curve is
claimed. Front-car spray is explicitly outside this revision's scope.

Excess influx above `RAIN_DYNAMIC_IMPACT_SHEET_FLUX_START` supplies height per
second, scaled by `RAIN_DYNAMIC_IMPACT_SHEET_FEED`. The feed responds over
0.25 s instead of switching a full patch on. Water accumulates continuously
and drains/decays with `RAIN_DYNAMIC_IMPACT_SHEET_SECONDS`.

An 8x8 source texture is refreshed every 0.10 s from all live drop samples,
without a diameter filter. Cell occupancy is divided by the total sample count:
changing 2048 to 4096 slots does not double the modeled water supply. This
texture supplies local spatial variation, not the global arrival rate.

A separate 512² RGBA16F ping-pong state advects the water using the existing
GPU drop physics' mean visor-UV velocity and a small lateral levelling step.
The visor boundary mask clips the state. The rendering-only composite adds softly compressed film thickness over the
pure trail. Alpha stores the original trail height, allowing its narrow and
wide refraction profiles to be differentiated independently of the film.
The persistent trail and GPU wet-path input never receive film deposits.
The final visor shader needs no extra texture binding.

UI: enable, influx threshold, feed gain, lifetime; readouts show influx,
smoothed feed, frontal air speed, and CPU submit time. The latter is included
in the water-trail CPU part and does not measure GPU execution.

## Validation and limits

### Independent opacity and FXC warnings (2026-10-07)

Film previously inherited the common sheet alpha and smear trail hiding /
clearing, causing a ghosted image. `RAIN_DYNAMIC_IMPACT_SHEET_OPACITY` now
controls the film's own alpha, independently of raw-trail alpha. Coverage
is feathered at film edges; interior coverage at opacity 1 fully replaces
the underlying scene. Opacity 0 retains only the original trail alpha.
Smear mix still controls color blending separately from opacity.

FXC X4000 warnings were reproduced locally. Texture reads now use explicitly
initialized single-return values, micro texture dimensions have defaults,
and writable helper state is reset in the shading function. All film/ridge
screen derivatives are evaluated before color/debug returns; coarse depth
shading has its own exit in the entry point. The actual shader body compiled
with SDK FXC `ps_5_0 /Ges /WX` using a harness for CSP-injected uniforms,
textures and PS_IN, with no warnings. Game-side compilation and visuals
still require confirmation.

### Preserve flow and blend with smear (2026-10-07)

User review found a flat film that erased existing trail flow. The previous
height-winner merge wrote film back into the persistent trail, discarding
its lower height variations. The render composite now adds film underlay
without changing trail state. Alpha preserves raw trail height; the final
shader differentiates the trail profile and film contribution independently,
avoiding saturation of their combined profile. Film display height uses
`0.75 * height / (1 + height)` rather than clamping to a uniform plateau.

### Refraction-only composition (2026-10-07)

Film and WF trails on smear now shift the scene reads used by the existing
smear, haze and micro layers. Film adds no WF tone compression, rim loss,
glint, veil or extra blur. Smear class colours, class boundaries and original
haze blending remain their existing definitions, evaluated at the shifted
scene coordinates. Film no longer clears haze using its composite height.

`RAIN_DYNAMIC_IMPACT_SHEET_SMEAR_MIX` now controls film refraction strength
on smear, rather than colour blending. `RAIN_DYNAMIC_SMEAR_TRAIL_MIX`
controls trail refraction strength there. Their saved values are preserved.
Opacity controls coverage independently: at opacity 1 and full film coverage,
the uncovered portion of the layer is filled with the refracted snapshot,
so an unshifted background cannot create a second image. Edge coverage and
opacity below 1 intentionally blend with the background.

The entry point initializes all helper state and its output before either
depth or colour branch, and has one return. SDK FXC ps_5_0 /Ges /WX passes;
CSP compilation, reference tone matching and performance need game testing.

### Boundary sampling fix (2026-10-07)

The user reported no visible film despite influx above 2 and threshold below
1. The film pass sampled the boundary mask at signed V (`canvasV - 1`) using
`samLinearClamp`. Every sample therefore landed on the top row, which is
entirely black in the actual DDS, and multiplied the water height by zero.
The pass now samples the mask in the canvas's encoded `V+1` coordinates
(0–1). A 64×64 CPU sampling check against the DDS confirms the old mapping
has zero valid samples and the corrected mapping has nonzero visor coverage.
The UI now exposes film readiness and the live source sample count. In-game
visual confirmation remains required.

- Compare at rest, with frontal wind, at speed, and with low/high rain.
  Increasing frontal airflow or rain should increase influx; dry conditions
  should supply no water. Side/tail wind should not receive a speed-magnitude
  bonus.
- Compare 2048/4096 slots with identical weather and direction. Influx/feed
  should match; local sampling noise can differ.
- Observe gradual accumulation, moving edges, drainage, and the transition
  back to the existing trail. Compare FPS and the film CPU submit time.
- Check wipe clearing and visor boundary alignment in-game. Wipe-mask removal
  from the separate film state is not yet implemented.

The source distribution still reflects simulated drop occupancy, not a measured
external impact field. Mean drop velocity supplies transport direction; a local
momentum solver and front-car splash classification are deferred. No in-game
visual or performance result is claimed for this revision.

### Film coverage and interior waves (2026-10-07)

User review: retaining micro details everywhere made film unable to cover the
clean visor, and strength-dependent alpha produced double images. Full film
coverage now replaces the lower scene details outside smear; within smear,
micro/facet/haze details remain part of the refracted material. Film detection
is independent of whether a head or trail wins the WF height comparison.

Coverage transitions only at the film surface boundary (render height
0.0005–0.004). Thickness instead increases lens intensity using h/(h+0.08).
Opacity remains an explicit user transparency control; keep it at 1 to avoid
intentional background crossfade. Local film thickness gradients and two
advected noise scales produce interior waves even on broad, uniformly wet
areas. Direction and advective phase follow existing physical flow; a small
time-varying secondary component prevents a frozen noise pattern. No extra
colour, veil, glint or blur is introduced.

`Impact film wave refraction (px)` controls film-only displacement (default
14); existing trail refraction settings remain independent. Smear refraction
share still scales film lens strength inside smear. Four extra height taps
and procedural ripple evaluations run only where film exists; measure GPU
cost and inspect thin edges, medium/full film, smear on/off in game. SDK FXC
ps_5_0 /Ges /WX passes, but in-game appearance has not been verified.

### Correct layer separation (2026-10-07)

Follow-up review found that covering the final shaded output also erased WF
heads, trails and wiped film/ridge. Film coverage now composites in the lower
haze/smear stage, before wiped film/ridge and WF overlays. Only micro lens
alpha is attenuated by impact coverage outside smear; within smear it is
preserved. The final entry point only fills uncovered background and no
longer replaces the complete shaded result.

The render composite contains additive film in RGB and raw trail height in A.
WF winner selection, radius/energy and slope sampling now reconstruct the
pure trail RGB before comparison with heads. This prevents a broad film
from replacing head/trail shapes. Pure trails outside smear no longer lose
alpha to impact coverage. Film flow and coverage are still evaluated from
the composite independently. Wiped film/ridge remain above the impact film.

SDK FXC ps_5_0 /Ges /WX passes. Numerical checks cover pure-trail recovery,
head winner preservation and foreground retention over fully opaque film.
In-game confirmation of the layer order remains required.
