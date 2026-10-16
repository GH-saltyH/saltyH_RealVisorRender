# RainFX s65: layer order, smear, continuous paths and cost

Date: 2026-10-12. Status: REFERENCE — source/offline verification; game GPU/FPS result pending.

**s66 correction:** the installed occlusion module was still missing. The
packed-UV X4000 is reproducible and has now been fixed in separate diagnostic
and depth programs, without the s65 fixture suppression. See
`RAINFX_S66_STARTUP_AND_GLASS_DIAGNOSIS.md` for measured compiler stalls and the
current independent glass/test routing. Earlier game success is not established.

## User evidence and correction to previous results

The first report described a 15–20 FPS gain and corrected sunlight, but still
62 FPS without the app versus 29 FPS with it, Rain covering meshes, jagged smear
and disconnected trail/wipe paths. Surface movement and sticker-edge retention
were accepted.

The follow-up states that `native_glass_state.lua` and
`native_glass_occlusion.lua` were omitted from the previous experiment. Those
measurements/appearance cannot establish the behaviour of the complete s64
runtime. With the current files, ordinary mesh occlusion is fixed; other FX
were still reported hidden. Do not reinterpret the earlier lighting/FPS report
as a controlled complete-runtime comparison.

Supplied CPU profiling: scene-ready callback 3.1824 ms, update and more
0.6434 ms, render callback 0.1675 ms, UI drawing 0.1513 ms. Sampling hotspots
included merge 26.4%, surface `tap` 14.2%, geometry-shot submission 5.8%, and GC
7.5%. These percentages are sampling-window data, not percentages of a game
frame or GPU time. The pasted log does not contain per-pass `render.measure`
GPU intervals. Alive counts range about 1500–3400, stamp budget stays 384, and
recovery is shown as both .69 and .09 seconds.

## Layer order

- Rain colour/depth reject nearer geometry using a stable full-resolution
  scene-depth/native-distance RG32 buffer. Scene depth is linear forward
  distance; native depth is radial distance. Neither is compared with UV or
  an unrelated capture's non-linear depth. Reads are point sampled. Native
  glass behind the rain does not reject the water. Hardware depth remains
  read-only in the colour submission.
- Set depth/blend/cull immediately before the actual Rain draw, after captures.
  A pending occlusion buffer prevents an unguarded colour draw.
- **INT draw gate defect:** `visorSceneStack` checked `vl.opticsReady` without
  assigning it from the post-rain source capture. It now resets/sets that flag
  from capture success. INT/E2/E3, cached E4 and the final EXT band follow rain
  colour and precede the water depth write. E2/E3 still samples post-rain HDR;
  it does not erase drops to simulate a priority fix. Captures failing in the
  pre-stack now expose their actual error in the layer error field.
- The accepted native-shadow policy and native visibility remain unchanged.
  Mirrors retain their separate water-only shader and do not run these captures.

## Smear

The colour classes previously used raw G while their visibility used filtered
G. This made the visible class borders ragged despite the smoothing controls.
Both now use filtered G. Class colour transitions straddle the integer boundary
symmetrically. Existing reveal, turbidity, head/trail mixing, veil and controls
remain.

The R reveal order, filtered G, filtered R and untiled eligibility alpha are
cached in one 2048×512 FP16 mask. It rebakes only when texture path or either
tiling value changes. Reveal/intensity, class settings and water continue live.
Colour and depth share the mask instead of each doing eleven mask taps per
screen pixel. Procedural/missing/pending paths retain the direct evaluator.
The source PNG is unchanged.

## Path continuity and sticker corners

- The old CPU preview rejected >20 mm and returned the source point, then
  jumped when a new readback arrived. Visual preview now transports momentum
  through two local surface frames and caches per-slot results. Unsupported
  segments stop at the last supported sample. Actual GPU forces, transport,
  boundaries, friction, wetting and downward airflow are byte unchanged.
- Supported same-generation trail segments no longer restart just because
  displacement exceeds eight tiny drop radii. Slow trails also draw connected
  ribbons. Each ribbon endpoint computes its own physical cross-flow direction;
  interpreting one endpoint's direction in both skewed UV frames twisted paths.
- Blank position-bake neighbours no longer pull a valid bilinear merge position
  towards the object origin; supported weights are renormalized.
- With 1500–3400 records and 384 CPU stamps/frame, refresh takes roughly 4–9
  frames. At 29 FPS, that is .14–.31 s, longer than a .09 s recovery. Increasing
  CPU UI submissions to every particle would reintroduce a large CPU cost.
- Instead, the GPU head pass stores a separate swept wipe footprint in its
  previously unused A channel. It follows current/previous GPU state for matching
  live generations, clips unsupported output, and bounds motion at 128 mm.
  It reuses existing tile traversal; diagonal segments are intersected with
  expanded tiles to avoid enqueuing the entire diagonal bounding rectangle.
  Main/mirror water colour uses the unchanged RGB/G channels. The current sweep
  renews wipe G every frame, independent of readback age/384 CPU stamps. CPU
  stamps still provide the separate liquid-ridge R channel. Water canvases now
  prepare before the wipe update, so the sweep is current-frame data.

These are demonstrated history/rendering defects. Their correction does not
prove that every fast in-game head turn at the sticker boundary is now smooth;
that remaining visual judgement requires the complete-runtime game test.

## Work removed or bounded

- Bounds/frames are evaluated per slot, not in every tile. The bounds atlas has
  three rows: conservative bounds, previous sweep endpoint/radius/validity, and
  current endpoint/extent. The tile pass binds only that atlas.
- Effective tile size is capped at 32 backing pixels (UI displays that cap).
  Sparse word traversal now defaults on; the dense comparison toggle remains.
  Sparse summary signed divides/modulus were converted to uint and compile /WX.
- The exact water depth pass uses a separate `RAIN_DEPTH_ONLY` compilation.
  It retains coverage/clip and optional haze/flow coverage but lets FXC eliminate
  RGB source sampling, refraction and lighting. Coarse mode remains separate.
- Merge broad phase uses a coherent readback snapshot; visual preview belongs
  to rendering. The GPU already rechecks current distance and generations before
  accepting commands. This avoids replaying visual transport inside every merge
  query. Per-render preview results are shared by wipe/head/trail consumers.

## Verification and practical limits

Diagnostics: `docs/diagnostics/2026-10-12/s65/`. Baseline captured before changes.

- Actual LuaJIT syntax and runtime checks: supported fast preview, cache
  invalidation, physical endpoint ribbon width/direction, one smear bake over
  1000 unchanged calls, retry/resize, live occlusion binding/render state.
- Actual production shader /Ges /WX checks, maximum eleven texture bindings.
  Tile-pass helper dependencies are declared from the actual bindings.
- D3D11 WARP: old/new water RGB equality, sparse/finer bins, independent swept
  wipe at zero CPU stamps, filtered-mask/direct evaluator equality, full rain
  nearer opaque/native rejection with behind pixels preserved, specialized
  depth coverage equality including enabled haze/flow. The full-rain artificial
  caller needs fixture-only X4000 suppression after packing constant visor UV;
  the unmodified production entry compiles /WX without suppression.
- Existing complete optics compilation/runtime suite verifies source independence,
  camera/motion caches, visible/native lifecycle and accepted E2/E3 parameters.
- Current 2000-record warmed merge replay remains around 2 ms. This is an offline
  CPU fixture, not a new game frame-time measurement. Early preview prototypes
  which added 8–15 ms were rejected during this turn.
- Saved settings, numeric tuning, GPU physical shader blocks, `rainSurfaceMetric`
  and native-lighting module are unchanged. The source mask/KN5 are unchanged.

The new occlusion copy and swept GPU arithmetic also have costs. Recovery to
the former total game cost is **not yet established**. Compare a complete install,
same camera/track/weather/speed, and collect RealVisor CPU/GPU Render Stats.
Reload the app; copy both native modules as well as the modified source files.
