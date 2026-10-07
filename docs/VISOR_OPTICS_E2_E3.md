# E2/E3 masked visor lens

Development branch: codex/visor-optics-e1-e7; main contains accepted RainFX 0.6.0.

## Mask contract

GLASS_INT_OUTLINE_MASK.png white identifies the ENTIRE optical area:
strong narrow boundary plus rounded lens inside that white area. Black areas,
including holes enclosed by white, receive zero optical output. No hole fill,
UV positioning, resizing or broad enclosure mask is used.

The accepted normal-driven sharp boundary is retained:

    ridge = pow(smoothstep(0.03, normalPeak, length(rawNormalXY)), sharpness)
    rimCoverage = originalMask * ridge
    interiorCoverage = originalMask * (1 - ridge)

Original pin.Tex is used for all textures with repeating texel addresses,
required by the mesh negative-V tile. Repeat addressing is not UV remapping.

## Rounded interior lens

build_visor_lens_field.py derives numeric surface data from the white mask.
It computes distance inward from white/black boundaries, constructs a rounded
height profile and differentiates it into a bounded lens slope. It never
fills black holes and never modifies the source mask.

Output: texture/GLASS/GLASS_INT_LENS_FIELD.dds, 1024-square RGBA16F (8 MiB).
RG = signed convex slope, B = dome height, A = original white support.
The original 4K mask remains the shader's final coverage authority.
This is an artistic convex cross-section, not a calibrated glass simulation.
Rebuild this field with Python, NumPy and Pillow whenever the mask changes:

    python docs/tools/build_visor_lens_field.py

The shader combines lens slope with the authored normal and projects through
the mesh derivative tangent frame onto camera axes. Offsets vary across the
curved surface rather than shifting the whole image equally. Dome thickness
modulates offset strength. Previous sinusoidal warping and neighbour-radius
controls have been removed.

## Blur and controls

KN5 -> GLASS_INT_OVERLAY -> E2/E3 inner glass optics.
Interior controls are independent of the accepted sharp-rim controls:

- Interior refraction: 12 px default.
- Interior normal influence: 1.
- Interior dome thickness: 3 px.
- Interior hairline split: 0.8 px, optional weak asymmetric split.
- Interior blur radius: 2.5 px.
- Interior blur amount: 0.70.

Blur explicitly samples the refracted scene with a nine-tap Gaussian kernel,
weights 0.25 center, 0.125 axes, 0.0625 diagonals, total 1. Blur remains active
at the dome peak where surface slope and displacement approach zero. Radius
and amount control actual defocus independently of refraction and hairline
splitting. Interior has no added tint, transmission loss or lighting contrast.

Accepted screenshot rim defaults remain: normal 0, refraction 18.23 px,
slope gain 0.85, split 1.52 px, sharpness 3.96, peak 0.889, highlight 1.69,
gloss 0.18, shading 0.75, loss 0.53, reflection 0.67, reach 98 px.

Signed alpha-zero scene differences preserve destination rain detail; this
pass does not refract rain itself. Screen reflection is approximate, not a
traced environment reflection. Game visuals and added GPU cost remain to test.

## Validation

Whole LuaJIT compilation, strict FXC /Ges /WX, uniform bindings and UI passed.
DDS header/format, no data outside original white mask, opposing curved slopes,
blur high-frequency attenuation and constant-colour preservation checked.

## Band-aware lens sampling and masked brightness

GLASS_EXT_OVERLAY draws before GLASS_INT_OVERLAY. The lens reconstructs the
band material at every optical sample rather than reading the unoccluded
outside scene. txLayerBand binds the same diffuse/alpha texture as GLASS_EXT.
Scene-sample pixel displacement maps to material UV through the local mesh UV
screen derivatives; this is a local tangent approximation, not a scene copy.
Band colour uses the same ambient and direct-light terms as the outer shader.

The sampler combines scene and band using the original band threshold and
opacity. On an originally opaque band pixel, the band coverage floor keeps
all displaced samples on the band even when a displacement crosses its alpha
boundary. Thus lens, hairline split, blur and reflection cannot reintroduce
outside scene there, while band colour/details can refract. Partially opaque
band settings intentionally permit transmission. Curved UV mapping far from
the original pixel is approximated; large sample offsets require visual QA.
No extra framebuffer copy or full scene render has been added.

Masked optics brightness (0..2, default 1) still multiplies the combined
sharp-rim/interior optical image only within the original mask, now including
its band overlap. Black areas stay unchanged. Lua reload refreshes draw order
and adds the new texture binding to the cached parameters.

Whole Lua / strict FXC / uniform and texture bindings passed. All optical
scene taps use the band-aware sampler. Numeric tests verify no outside-scene
contribution in opaque overlaps and a nonzero refracted band delta.
In-game appearance and extra texture-sampling cost remain unverified.

### Opaque band replacement correction

The previous alpha-zero band delta did not guarantee occlusion if the rendered
destination differed from the reconstructed base. Band overlap now uses a
premultiplied replacement component; clear glass retains the alpha-zero delta.
Any positive origin-band threshold coverage uses a full material sampling
floor, preventing fractional outside-scene contamination at the band boundary.

    block = originBandCoverage > 0 ? bandOpacity : 0
    rgb = mask * lerp(optical - base, optical, block)
    alpha = mask * block

For opaque band and full mask, output after blending is optical, independent
of destination/base contents. Fractional mask preserves antialiasing; the
already rendered outer band remains behind it. Intentionally translucent band
settings retain transmission. Strict FXC and destination-independence blend
checks passed; actual in-game overlap must be checked again.

### EXT/INT UV correspondence correction

The actual KN5 meshes use different atlas islands: INT V=-0.877..-0.627,
EXT V=-0.242..-0.011. Sampling EXT band alpha directly at INT UV detected
zero overlapping opaque band pixels, invalidating the previous floor tests.
`build_visor_band_uv.py` now projects INT vertices onto nearest EXT triangles,
interpolates EXT material UV and rasterizes that lookup on INT's UV island.
Output GLASS_INT_EXT_UV_FIELD.dds is 1024 RGBA16F; source UV is unchanged.
Rebuild when the configured visor geometry/UV changes (the script currently
uses visor_lando_2025Champion_maxquality_diet.kn5).

The shader samples this lookup with pin.Tex; only band material coordinates
and their screen derivatives use mapped EXT UV. Normal, lens and mask retain
INT UV. All optical taps use the mapped band UV, including origin coverage.
Actual texture checks now detect band overlap; strict FXC and whole Lua pass.
Game validation remains necessary, especially near large sample offsets.

EXT material UI: Top band responds to external light (default true).
When false, only the band-alpha portion uses fixed unlit brightness (default
0.15), excluding ambient/direct external lighting. Inner-lens band sampling
uses the same lighting switch and suppresses sun highlights on band overlaps.
Outside-band glass and other materials keep their existing light response.

### Dedicated band texture

Both EXT_OVERLAY draw and INT lens band sampling now use
GLASS_EXT_BAND_WITH_ALPHAMASK.dds instead of the shared glass diffuse.
The same alpha cutoff and external-light controls apply. UV correspondence
and normal/lens textures are unchanged. Reload Lua to refresh cached bindings.

## Mandatory post-rain source (E1–E7)

User accepted E2/E3/E4 at ff085b5, then specified all inner lens effects must
include drops/trails/film. The accepted tuning is preserved. Active scene
stack now copies dynamic::hdr after rain colour and before the post optics;
E2/E3 uses this stable copy for scene refraction, blur and brightness. Copy
failure skips inner optics and records the error rather than using a dry scene.
No change to rain physics. Actual captured content and GPU bandwidth require
in-game verification. Earlier statements that rain itself is not refracted
are superseded by this contract. E1 path analysis is in VISOR_E1_DESIGN.md.
