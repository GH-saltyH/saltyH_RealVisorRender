# E1: bright forward-source image on the curved visor

## Accepted state and mandatory layering

User accepted E2/E3/E4 at ff085b5. Preserve their tuning. All E1–E7 lens
operations are inside the rain surface and must process the rendered drops,
trails and water film as well as the scene. Active scene-stack E2/E3 now uses
an HDR copy after rain colour, before the inner optics. The user confirmed that this capture correctly includes rendered rain.
It adds GPU bandwidth; its performance cost still requires measurement.
Archived overlay experiments are not the accepted execution path.

## What the reference supports

The faint coloured image is consistent with bright forward bodywork, shaped
by visor curvature and off-axis viewing. It could be an internal ghost, an
interior-object reflection, or a mixture. One photo cannot identify the path,
surface curvature, thickness or exact source point. The helmet camera is
right of the usual eye position and looks left: this must follow camera pose,
not a baked right/left shift. E1 forward-source ghosts and E7 interior-object
reflections must remain distinct mechanisms.

## Physical path to evaluate

A single specular reflection seen by the camera samples the direction
reflect(-V,N), where V points surface-to-camera. Near the front-facing visor
this often points back toward the interior, not toward forward bodywork.
A forward image therefore must not be fabricated by simply mirroring the
forward screen image and labelling it one-bounce reflection.

One candidate forward ghost path (not a confirmed mechanism) is:

    bright bodywork -> outer transmission -> inner reflection
       -> outer reflection -> inner transmission -> camera

Reverse tracing from the camera uses the reciprocal path. Intersect the actual
inner and outer curved surfaces, refract at transmission interfaces, reflect
at each bounce, then intersect the forward scene. Normals are evaluated at
EACH hit; using the same normal twice cancels directional change for parallel
surfaces and cannot predict the curved ghost placement.

At IOR about 1.5, normal-incidence Fresnel reflectance is about 4% per
interface. Two reflections give a weak image, roughly R1*R2*T_in*T_out
(about 0.15% under that illustrative IOR). Off-axis incidence can increase it.
This explains why a very bright source is needed for a visible ghost without
requiring uniform white haze. Thickness, curvature and roughness determine
image offset, deformation and blur; gain is an artistic exposure control.
The IOR value is an example, not a measured visor material property.

Source basis: PBRT, Specular Reflection and Transmission:
https://www.pbr-book.org/4ed/Reflection_Models/Specular_Reflection_and_Transmission

## Visibility and radiometry

Evaluate HDR luminance at the RAY HIT before blur, not frame-average colour.
A bright car panel can qualify even when its saturated colour has one low
channel. Fresnel scales the image energy; it does not decide source brightness.
Normal/view alignment decides ray correspondence, not arbitrary screen rows.

Use independent controls for source luminance threshold/soft knee, observer
shadow gate, Fresnel/material IOR, image gain, surface roughness and shell
thickness/curvature. Blur only the eligible image energy, never the whole scene.
The user requests invisibility in shade: add a camera/visor exposure or shadow
gate independently of bright-source gating. Physical reflection does not
strictly cease in shade; that gate is an explicit visibility policy. Global
sun intensity alone is insufficient (sun can exist while the camera is shaded).

## Implementation boundary

The current HDR scene copy supplies source colour including drops. Accurate
ray correspondence also needs camera projection, scene depth and a curved
visor shell model. A forward screen copy cannot supply offscreen or occluded
source geometry. Invalid ray hits must fade out, never clamp to screen edges
or fall back to a centred screen image. Use a projected curved-shell tracer
first; a separate GeometryShot/environment capture is a later option only
if missing geometry materially prevents the reference image.

E1 now has an opt-in screen-based Fresnel prototype (see below). Full scene
intersection and observer-shadow classification are not implemented. Test camera
yaw, bright panel vs sky, shade, invalid direction and rendered rain.

## Additional wall reference and revised hypothesis ranking

The user supplied a wall-reflection frame without the interior reflections
present in the earlier bright-bodywork reference. Use this frame as the E1
validation reference and the earlier frame as a mixed E1/E7 stress case.
The broad orange architectural source and its faint distorted image support
an external-scene source; they do not uniquely determine reflection order.
Do not interpret the duplicated physical Pirelli boards as identified ghost
copies: matching specific source landmarks requires temporal or ray evidence.

The earlier two-reflection hypothesis must not become a hard-coded assumption.
A curved off-axis visor can offer a strongly tilted facet, including an
opposite inner facet viewed by the right-mounted, left-looking camera.
A single internal reflection there, with transmission through another visor
facet on the way to the source, is also a candidate. Its energy can be larger
than a thin-shell two-bounce ghost. This full-visor path cannot be reproduced
by reflecting twice at one pixel with the same normal.

For source point Q, surface point P and camera C:

    L = normalize(Q-P)
    V = normalize(C-P)
    requiredSpecularNormal = normalize(L+V)
    reflectedDirection = reflect(-V, actualSurfaceNormal)

Accept correspondence only when the actual curved facet normal agrees with
the bisector and the reflected ray reaches Q. Check orientation, refraction
at entry/exit facets, visibility/occlusion and surface boundaries. Near-normal
facets may point the reflected direction toward the interior; strongly tilted
facets can point toward a lateral/front exterior wall. For a collimated
forward camera ray, the reflected forward component switches sign at 45
 degrees incidence in a simplified planar example. This is a diagnostic of
geometry, not a universal visor activation threshold.

Implementation order revised:
1. Debug one-bounce curved-facet source hits, including transmitted exit path.
2. Evaluate two-bounce shell ghosts where the first path has no valid source
   or where displacement/energy better matches the reference.
3. Compare recovered wall corners/window edges against the source. A source
   need not be visible in the direct camera frame, so screen-only sampling
   must mark unavailable hits rather than invent them.
4. Sample eligible HDR source radiance including rain; preserve colour and
   low-frequency architectural structure while applying optical blur.
5. Separate source brightness, Fresnel energy, geometric hit confidence,
   roughness blur and the requested shade visibility policy.

Do not key E1 to vehicle speed, bodywork colour, a fixed screen strip, or
presence of E7 facial/housing reflections. The wall case must also qualify.
Specular correspondence comes from geometry, not merely a bright-pixel mask.

Physics source for reflection law and angle-dependent Fresnel weighting:
https://www.pbr-book.org/4ed/Reflection_Models/Specular_Reflection_and_Transmission

The optical design above remains the evaluation basis for the prototype.
Accepted E2/E3/E4 tuning and the validated post-rain capture are preserved.

## E1 Schlick prototype

Enable in KN5 -> GLASS_COATING_OVERLAY -> E1 forward bright-image prototype.
Default off. One additional mesh draw occurs only while E1 is enabled; the
post-rain HDR copy is shared with E2/E3. No new full GeometryShot is required.
E1 is drawn after rain and the existing post optics; source includes rain.

F0=((IOR-1)/(IOR+1))^2 is calculated in Lua. Pixel Fresnel uses
F=F0+(1-F0)*(1-|N.V|)^5 with x*x*x*x*x multiplications. Two-reflection energy
uses F1*F2*(1-F_entry)^2. Material IOR default 1.5 is illustrative.
Single reflection uses the actual mesh normal. Double reflection refracts
into a virtual offset shell anchored to the interpolated mesh normal.
Successive bounce normals use continuous horizontal/vertical curvature,
not screen derivatives of mesh normals. It then refracts out.
Zero/TIR rays, backward rays and directions outside camera FOV are rejected.

This is a local curved-shell plus far-field projection approximation, not a
scene-depth ray tracer. It cannot confirm finite-distance wall hits, occlusion,
full-visor opposite-facet paths or offscreen sources. No fixed source strip,
UV mirror or invalid-hit fallback is used. These limitations must stay visible
when comparing the reference; missing images may be missing ray coverage.

Each of five source taps samples the post-rain HDR image, multiplies Fresnel
energy, evaluates reflected luminance threshold/soft knee, THEN blurs eligible
energy. This avoids blurring the ordinary scene into a uniform fog. Image gain
is applied after gating and does not change eligibility. Very bright sources
can remain visible even if the observer is shaded; a separate observer shadow
policy is not yet implemented.

Controls: enable, one/two reflection, IOR, thickness metres, reflected HDR
threshold, soft knee, image gain, optical blur pixels and ray debug.
Defaults: double reflection, IOR 1.5, thickness .002 m, threshold .003,
knee .003, gain 12 and blur 5 px. Debug: red invalid direction; green valid
forward projection with brightness proportional to Fresnel energy. It does
not indicate validated scene-depth intersections.

Whole LuaJIT, strict FXC /Ges /WX, all uniforms, E1 UI and numeric Fresnel
monotonicity/bright-source eligibility passed. Actual appearance and GPU cost
have not been measured. Reference equation:
https://learnopengl.com/PBR/Theory

## Revision after the first in-game test

The reciprocal two-bounce path in a nearly parallel shell returns close to
the original view. Amplifying pixel-normal derivatives with thickness also
risks triangle seams/vertical streaks. Replace that estimate with a continuous
virtual curved shell. Material IOR controls Schlick energy only; virtual IOR
controls refraction, and thickness times virtual path gain controls bounce
separation. Curve radii set independent horizontal/vertical curvature.
Angular source-coordinate compression above 1 narrows the reflected image.
These are explicit artistic approximations, not a calibrated physical visor.
Changing IOR alone does not guarantee a stronger or visible forward ghost: TIR
and rays outside the captured view remain rejected.

E1 uses its own post-rain HDR bright-pass canvas with five MIP levels. Source
luminance gate defaults to 1.0 with a soft knee, before MIP generation. Then
projected footprint/optical blur selects the MIP and five taps apply Fresnel
energy and the reflected-energy gate. Dim ordinary scene content is excluded
first. This reduces aliasing and literal full-scene copying, but cannot create
offscreen geometry, depth-dependent reflection or missing light information.
The accepted E2/E3 source and texture sampling are unchanged. E1 disabled
skips prefilter, MIP generation and extra mesh draw. Enabled E1 adds one
full-resolution HDR prefilter and MIP generation; GPU cost needs measurement.
Async prefilter not ready: skip E1 until a valid source exists.

New defaults: virtual IOR 1.25, path gain 16, radii .12/.20 m, compression
1.15/1.8. Start with two internal reflections on. Tune path gain and curve
radii for shape, compression for image scale, source minimum for bright-only
eligibility, then reflected threshold/gain for visibility. Raising gain does
not change eligibility. Higher virtual IOR can increase TIR; it is not a
monotonic visibility control. Existing screenshot values are runtime tuning
and may need Reset/reload to use these defaults.

Revision verification: whole-file LuaJIT compile, strict FXC /Ges /WX for both
shaders, uniform bindings, material UI defaults, continuous-curvature numeric
check and async source guard passed. In-game appearance/FPS unverified.

## E1 coverage/UV audit

E1 ray projection and its validity mask do not read pin.Tex. Mesh UV placement
cannot create a split in this green debug region. Active diet KN5 coating mesh
(9008 vertices) has normalized normals and consistent face orientation. Four
coincident-position normal discontinuities exist near lateral edges, not at
the centre (local X about +.1006 and -.1185 m). Original mesh/UV left intact.
A screenshot alone cannot distinguish a projected screen boundary from TIR.
Debug now separates: green valid ray, blue projected U outside capture, purple
projected V outside capture, red backward ray, yellow TIR. Green does not mean
the HDR source passes brightness gating. Its minimum display brightness is
.35 so low Fresnel energy no longer hides valid coverage. The actual reflection
still uses unchanged Fresnel energy and strict valid-source rejection.

## Source boundary blending

The reported floating patch aligns with projected U/V leaving the captured
HDR view. Remove the hard centre-sample screen-bound rejection in colour
rendering: only backward/TIR rays reject the whole footprint. Each optical
blur tap individually rejects out-of-screen coordinates and fades through a
smoothstep inside the capture edge. New source edge fade control defaults
to .15 of source screen dimensions. Debug retains crisp ray rejection colours
for diagnosis; its green area is not the final reflection opacity. This
softens capture borders but cannot supply missing offscreen scene radiance.
Strict FXC and uniform binding checks passed; in-game appearance unverified.

## Exterior reflection visible from inside (experimental)

New mode E1_EXTERIOR defaults true. Keep the authored outward mesh normal
for E1, independently of camera-facing normals used by other glass layers.
Use an opposite-side virtual observer (incident direction = surface-to-interior
camera vector), then reflect at the continuous virtual curved exterior surface.
This produces a forward frontal source ray. It is an explicit visual model, not
the physical reflection of the real interior observer. Merely flipping N or
enabling two-sided drawing cannot change reflect(I,N) to the forward direction.
Virtual IOR controls shell travel/refraction for curvature; material IOR still
controls single-interface Fresnel energy. Exterior mode bypasses the two-bounce
internal model; disable it to compare the retained internal model.

Available SDK documents HDR/depth dynamic textures but no supported binding
for engine reflection cubemap as render.mesh shader input was found. This build
therefore samples the existing post-rain HDR bright-pass source, includes rain,
and still has screen coverage limits. No invented cubemap identifier or silent
fallback. Full environment support remains pending an actual supported API.
No additional render capture or prefilter pass beyond the existing E1 source.
Strict FXC, uniform binding and frontal-ray sign checks passed; game imagery
and cost need testing.
