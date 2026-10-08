# E1 restart after overlay visibility regression

Starting checkout: 0c347e8, restored by user. The failed environment/shell/
lighting experiments are not reintroduced. E1 defaults off.

Restored accepted composition: INT optics, E1, EXT band last. INT band opacity
is zero; EXT owns band masking with GLASS_EXT_BAND_WITH_ALPHAMASK.dds and
GLASS_INT_EXT_4k_txNormal.dds. EXT normal relief has an independent UI strength.

E1 foundation uses mesh outward normal and live camera basis. The forward-image
virtual observer convention reflects toEye about the normal; Schlick uses
polycarbonate IOR1.585 and actual normal/view cosine. No artistic compression,
curvature, thickness, bright-pass or extra scene capture participates. Debug
shows world reflection direction as RGB. Source remains post-rain HDR,
including visible rain effects. Out-of-frustum rays are rejected, so this is
not yet equivalent to environment cubemap reflection or physical internal
two-interface transport. Validate all existing overlay visibility first, then
direction variation with mesh/camera motion; source coverage is a later step.
Whole LuaJIT and strict full shader FXC compilation passed; game validation
remains required. Legacy saved configuration values remain but no longer
control the active foundation; its UI exposes enable/debug/IOR/gain only.

Reference: acc-shaders-master/recreated/include_new/base/utils_ps.fx computes
reflection direction and view-angle Fresnel separately from source lighting.
ksPerPixelMultiMap_emissive's emissive map is not a grazing-light detector.
E6 should reuse calculateLighting_spec/reflectanceModel's light/view/normal
specular response with shadow and material masks at the visor/scratch surface.
Do not mistake optional bounceback retroreflection for grazing incidence.

After user reported that the shared-shader foundation again hid all overlays:
restored rainVisorLayer.hlsl from HEAD, retaining only EXT normal relief.
E1 foundation now has an independent rainVisorE1Foundation.hlsl and minimal
one-texture parameter set. Non-E1 camera bindings are restored to baseline.
E1 render failure is caught and logged locally, and the COATING editor controls
its visibility. Band order/INT band disable remain. LuaJIT and both strict FXC
compiles passed. The exact engine-side cause is still not established; game
verification of all overlays with E1 off/on remains required.

Concrete compiler failure reproduced: the edited common HLSL contained a
UTF-8 BOM. initShaders reads raw bytes and CSP prepends its template, moving
the BOM into the middle of the generated source. FXC then reports X3000
Illegal character. Previous standalone tests decoded utf-8-sig, silently
removing the offending bytes and missing this defect. Removed the file BOM
and added explicit UTF-8 BOM stripping in initShaders. Re-tested both shaders
as raw UTF-8 appended after a template header; strict FXC passes. LuaJIT and
loader BOM handling passed. The earlier E1 isolation/band changes remain;
game reload is required to replace cached source and verify visibility.

INT soft defocus: independent radius/amount controls (defaults4px/1) blend
prefiltered MIP samples around the bent interior coordinate. Existing sparse
blur/hairline controls remain; amount1 replaces their sharp composite with
the smooth defocused view, lower amounts retain some split-image detail.
Normalized nine-tap weights preserve uniform HDR colour. Only interior optical
image is changed; rim weighting/white-mask coverage and final EXT band remain.
Post-rain source allocates6 MIPs only when soft defocus is enabled, updates
them after each HDR copy, and otherwise returns to one level. MIP filtering
is an approximate defocus, not an exact Gaussian PSF. Added MIP generation and
sampling cost require game measurements. Raw-byte template shader compilation
and whole LuaJIT passed without introducing a shader BOM.
