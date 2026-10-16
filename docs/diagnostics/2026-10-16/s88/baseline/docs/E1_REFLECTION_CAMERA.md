# E1 reflected-camera colour experiment

BVH geometry intersection, material ID, hit point, depth validation, Fresnel and INT compositing remain unchanged. Only the colour/depth source camera changes.

## Controls

Enable `Primary actual geometry`, then `BVH reflected camera colour experiment` in the source controls. The experiment defaults off and its settings use the existing `settings_mats.ini` custom parameter persistence.

- `Reflection plane local Z`: representative visor plane point `(0,0,Z)` in the helmet pose coordinates. Initial value 0.10 m is a calibration starting point, not a measurement of the current visor.
- `Reflection plane pitch/yaw`: representative plane normal; initial values zero, normal helmet +Z.
- Source FOV and source quality apply. Source anchor, offset, height, source pitch, side quality and multiview selection are bypassed. The old source configuration is retained for comparison when the experiment is disabled.

Each frame reflects the current eye position, look and up about the transformed plane:

`eye' = eye - 2 dot(eye - planePoint, normal) normal`

`axis' = axis - 2 dot(axis, normal) normal`

One native colour capture and matching metric-depth capture use this camera. The existing native preparation gate, allowlist, authored materials, lighting and capture visibility cleanup apply. BVH colour binding uses this single ready source even when the saved multiview option is enabled; side slots are disposed and never averaged into its colour. Failed captures are not reused as current output.

## Game evaluation

1. Lit source mode 0; actual geometry enabled; reflection blur 0; baseline removal 0 initially.
2. Inspect primary mode 3 (raw colour) and mode 9 (validated colour coverage). Tune plane Z/FOV so useful housing points are visible to the reflected camera.
3. Compare mode 0 against the fixed-anchor source, with the same quality/output width/gain/threshold.
4. Turn the game camera and translate it. Source should follow immediately without anchor reset. Observe source clipping, texture detail, highlight behaviour and frame time.

The planar camera is an approximation for the curved visor. BVH hit geometry stays exact, but captured view-dependent material response does not match every reflected ray on the curved surface. A BVH hit hidden from the single capture remains colour-unavailable; it does not fall back to an unrelated source or fabricate colour. Pitch/yaw controls test a representative region; they do not alter visor geometry or BVH rays.

No additional source passes are added relative to the former single-source path. Compared with three-view capture, this uses one colour/depth pair, but measured GPU cost and image quality still require game verification.

## Automated checks

`check_e1_multiview.py`: actual Lua reflected eye/axes, signed distances under tilted planes, moving-camera response, single-source orchestration overriding multiview, source camera override and existing preparation/disposal regressions.

`check_e1_geometry_runtime.py`: actual BVH binding selects reflected single source and rejects unready output despite multiview being enabled; existing geometry/hash/composite/UI checks retained.
