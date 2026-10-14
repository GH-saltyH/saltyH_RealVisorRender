# s63 — bounded Rain paths, surface splash and native glass occlusion

2026-10-12. Implemented and verified offline. Actual new game FPS and appearance
remain unmeasured. Preserve the user's accepted E2/E3 result and physical GPU
movement, and their tuning/profiling changes made after s62.

**s64 correction:** the mask's s63 setup hook was in the archived HUD path and
did not run in the live scene stack. The component checks below did not verify
that integration. s64 moves it to the live path, tests the actual hook/pending
gate and uses exterior ownership coverage. See `RAINFX_S64_BOTTLENECK_AIRFLOW_LIGHTING.md`.

## Evidence and root cause

Both supplied videos were decoded with Windows Media Foundation. The splash
video (6.499 s) contains a visor-wide blurred flash; the wipe video (14.766 s)
shows broadly erased/altered output. Contact sheets are in
`diagnostics/2026-10-12/s63/`. Sources/settings were captured before changes in
that directory's `baseline/`.

The CPU accepted any centre within the UV rectangle, including holes and blank
atlas regions. A blank Jacobian has dP/dU = dP/dV = zero. `metric()` replaced
their lengths with 1e-9, then `offset()` inverted those lengths. At scale 1,
even a 2-reference-texel kernel could reach approximately **682,666,666 virtual
texels**. This concrete defect can explain the whole-surface wipe/trail and
splash flashes; recordings alone cannot prove every observed flash has this cause.

Blank centres occur during linear prediction, a sheet's behind-head offset,
and splash pieces placed past the surface edge. The current bake contains
535,983 unsupported cells. All now reject kernel generation instead of using
an epsilon-sized fictitious surface.

## Wipe width and trails

At the current 2048-wide mask and reference calibration .0029296875/mm:

```
reference texels per mm = 2048 × .0029296875 = 6
wipe width reference px = max(.25, 2 × state_radius × 2048 × .980 + 0 × 6)
wipe width mm = max(.0416667, drop_diameter_mm × .980)
```

The state radius is a physical reference unit, not a raw current UV radius.
The Jacobian maps this width to skewed UV coordinates, and the final UI scaling
maps virtual W×W coordinates to the W×W/4 canvas. This formula does not produce
a visor-wide wipe with current sub-mm birth diameters. Width gains, offsets,
minimum width and user size settings are unchanged.

CPU previews fall back to the supported snapshot position if a short segment
crosses an unsupported region. Wipe history and WF sheet links reject invalid
endpoints and discontinuous segments; they do not connect through a hole or
across a respawn/readback jump. A 20 mm local segment guard bounds stale CPU
links. Interior checks reuse the baked conservative boundary distance; near
boundaries an eight-part check and physical chord validation are used. This is
a bounded rendering preview, not a new physical integrator. The accepted GPU
transport, forces, friction, wetting and actual UV velocities are unchanged.

All CPU kernel/ribbon callers, including the optional GPU splash atlas placement,
check the geometry function's result before submitting UI geometry.

## Splash shape

CPU splash pieces previously added physical-reference distances directly to
actual UV pixel coordinates. Their **positions** therefore retained UV stretch
and skew while their **radii** used physical metric conversion. Positions now
use `surface:shift()` from the frozen impact point. Rings and satellites expand
in its physical tangent plane; unsupported piece centres vanish at boundaries.
Existing energy, timing, spread, scatter, amplitude and residual controls remain.
The optional GPU atlas already describes a local circular physical sprite; its
placement now rejects unsupported centres too. Its backend selection is unchanged.

## Native glass owns exterior pixels

`native_glass_occlusion.lua` captures metric camera distance from visible
`GLASS_EXT_MRR`, `GLASS_COAT_MRR`, `GLASS_INT_MRR`, `GLASS_STICKER_MRR` geometry.
Only camera-facing exterior normals contribute. Native INT and FX INT have
opposite normals, so native rear faces must not suppress inside optics.

Glass-layer output and the complete cached E4/HDR contribution discard pixels
where that native exterior surface is in front (or coincident within 0.1 mm).
Native opacity is deliberately not used as an FX mixing weight: even transparent
native glass owns its covered pixels. Native colours/materials remain authored;
no native colour is copied or blended into the custom pass, and no depth is
written into the main scene by this capture. Rain/mirror water rendering remains
independent. Logical and actual Visible states are honored. Pending captures
do not fall back to an unoccluded custom draw over native glass.

The full-target R32 distance capture is reused when camera-relative model pose,
FOV, target size and native visibility are unchanged. The key uses the local
camera-attached hierarchy, including G-force motion and the model root, to avoid
large-world subtraction noise. Real motion invalidates the capture. It is not
captured in mirror callbacks. Its API/format/custom geometry callbacks were
checked against the installed Assetto Corsa Lua SDK.

## Cost changes

- GPU heads reject empty physical-mask pixels before walking tile masks.
- Each candidate pixel checks the same conservative physical reach used by
  tile binning before seeds, trigonometry, shape/tail/puddle and kernel work.
  D3D11 WARP with production binning produces identical old/new head output.
- When GPU heads own the water canvas, both splash backends use the metadata
  collector. CPU splash mode draws only active splash pieces. Settled heads
  no longer repeat physical velocity/shape calculations on the CPU; a 96-head
  runtime fixture reduces those metric calls from 96 to zero.
- Repeated CPU geometry operations reuse the last texel's metric frame.
- Stable native occlusion uses one capture across 1000 tested frames.

The reported 36 FPS versus 56–60 FPS corresponds to roughly 27.8 ms versus
16.7–17.9 ms of total frame time, not a measured isolated Rain GPU duration.
These changes reduce identifiable work without lowering particle count or
appearance gains. They do not establish a new FPS figure.

## Verification and remaining game check

Passed:

- 16 production Rain/glass variants and 13 optics variants: FXC /Ges /WX;
  at most 11 actual texture bindings. Native distance shader also /Ges /WX.
- `check_s63_runtime.py`: every unsupported cell rejected, 2003 valid kernel
  samples, 1354 bounded splash kernels, circular physical offsets, settled-head
  CPU bypass, capture cache/visibility/pending/failure/disposal.
- `check_s63_gpu.py`: actual native front/behind/missing gates, cached E4 rejection,
  and exact output equivalence for Rain candidate culling.
- Existing flat/bevel E2/E3, EXT alpha, micro-at-60%, signed readback, cached
  optics lifecycle and settings preservation checks.

Results: `diagnostics/2026-10-12/s63/{runtime_checks,gpu_checks}.json`.
The current settings files remain byte-identical to the s63 baseline.

Reload the Lua app so the new module and inline shaders are loaded. In the same
game view compare: wipe on/off; WF trail on/off; splash on/off and its optional
GPU backend; native glass Visible toggles from exterior and interior views; dry
and daytime 60% rain with debug disabled. Measure total frame ms/FPS with RainFX
on/off. User profiling additions are retained for the remaining cost comparison.
