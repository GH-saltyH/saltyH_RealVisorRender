# s154 — actual-grid world field geometry and consumer audit

Status: ACTIVE — local verification and actual main-app observation passed
Date: 2026-10-19

## Implementation

s153 established immutable copies of physical inputs. s154 derives the field
geometry needed by frame consumers from the actual main-app visor pose and the
existing bake. The field stays **1024×256**. This is a default-off main-app
diagnostic with no water evolution, stock publication or elapsed-time consumption.
Production physics remains s87 and its existing diagnostics remain s89.

The new bundle owns copies of du, dv and cells plus the unchanged s152 context
producer's 52 header rows. Boundary, sites, DSD and impact are outside this
particular consumer's inputs and are not duplicated. All verified input files
and the connected-UV metadata must match the frozen file identities.

| Derived resource | Dimensions / format | Contents |
| --- | --- | --- |
| metric | 1024×768 RGBA32F | Three vertical bands: world U, world V, Gram metric |
| areas | 1024×256 RGBA32F | World area mm², supported flag, coverage, coating |
| leaves | 256×128 R32F | Exact 16-cell support bit masks for both axes |
| runs | 1024×256 RGBA32F | X start/end-exclusive and Y start/end-exclusive |
| audit | 64×16 → 4×1 → 1×1 RGBA32F | Invalid cells, support count, area sum, maximum error ratio |

The U and V bands store world Jacobian XYZ in metres and a supported marker.
The Gram band stores `(U·U, U·V, V·V, (U·U)(V·V)−(U·V)²)`. Unsupported cells
have zero metrics/area and four −1 run endpoints. The local Jacobians are sampled
at the existing field-cell centre convention: raw pixel `(2x+1, 2y+1)`.

Actual KN5 geometry and its world matrix govern the metric. The matrix's uniform
scale squared converts the **authoritative baked cell area** to world area.
The nominal UV-to-mm coefficient and display diameter gain never multiply these
world vectors or areas. Translation has no effect on a Jacobian. The determinant
is evaluated with precise float32 intermediates; reference checks use float64.

## Connected support and cost

Each leaf contains 16 support bits, represented exactly as a float integer
0…65535. The X leaves precede the Y leaves. A supported cell scans its local
block and skips complete neighbouring blocks until a gap or image edge. Partial
edge blocks have zero padding. This avoids retaining a full-resolution texture
at every jump distance. The cache is built once for this immutable context.

The independent consumer checks every supported cell against its four original
cell neighbours: adjacent supported cells must share the same relevant run;
an unsupported or outside neighbour must end that run at the current cell edge.
Together with containment/integer/bounds checks, these constraints establish
the exact connected component on each row/column and reject bridging a hole.
The input is admitted only with the frozen `flowConnectedUV` bake. This is not
a general solution for future UV atlases with disconnected adjacent geometry.

The current full bake contains **123,224 supported cells** and sums to
**40,288.6009595mm²** locally. GPU world vectors are checked by inverse rotation
and scale against raw inputs. Gram/area checks use a relative tolerance of 1e−5;
the single-cell consumer reports the maximum normalized ratio. All cells must
pass. A separate CPU sample oracle uses 16 fixed positions, including dry edges,
with 5e−6 numerical tolerance and exact run endpoints/validity markers.

## Ownership and readback

The unmodified s153 whole-allocation owner supplies private capabilities and one
session-retained read lease. Each output accepts one immutable write. Shader or
image pending retries retain the original parameters, with at most one accepted
draw per scene-ready callback and 256 attempts per pass. Unknown submissions
fault and retain resources. Cancellation cannot start a second allocation cycle.

Successful execution takes **34 accepted passes / 34 canvases**, totalling
**59,336,208 nominal bytes (56.5874MiB)** under the 64MiB owner limit. Driver
overhead and the SDK's source-image cache are additional. Eight full-payload
fingerprints cover the four owned inputs/header and four derived resources.
The four input fingerprints are checked against CPU references. Derived
fingerprints record the consumed cache's numerical identity; they are not an
independent exact-value oracle. Full-grid audits and CPU sample checks supply
the numerical checks.

One 64×10 R32F atlas contains 640 floats:

- offsets 0…63: eight fingerprints, eight 16-bit limbs each;
- 64…67: the full-field consumer audit;
- 68…275: all 52 frozen header rows;
- 276…595: 16 samples, each U/V/Gram/area/runs (20 floats);
- 596…639: zero padding.

The CPU object is disposed once, including duplicate-callback protection.
Every GPU allocation stays retained until the app/session ends. The readback
is not used as a general GPU completion fence and never authorizes reuse.
`strictCompletion`, solver admission and public-clock advancement remain false.

The complete dump is **42 lines**: begin, forty 16-float binary32 hex rows, end.
At most eight lines are logged per tick; `observed` is shown after logging ends.
The independent decoder verifies header/pose SHA256, input fingerprints, the
audit and all sample values before accepting `matched`. It refuses incomplete,
duplicated, reordered and falsely completion-enabled captures.

## Verification and current result

- **35 WARP draws / 6 strict FXC shader bodies:** actual bake, rotated/scaled
  bake, ragged holes, all-supported and all-dry fixtures. Every run endpoint
  agrees exactly with an independent CPU connected-component oracle. Whole-field
  numerical errors are below 2e−6. Deliberately corrupted run/metric/area values
  are detected by the consumer.
- **34 additional WARP draws / 11 strict bodies:** the exact Lua-managed graph,
  all derived arrays bit-identical to the independently driven field test,
  complete atlas extraction and full-payload fingerprints verified.
- **19 controller cases:** successful, pending/image-pending, unknown submission,
  read error, input/audit/sample mismatch, padding/nonfinite/shape errors,
  duplicate callback, cancel, stale files/topology, CPU refusal, image readiness
  limit and wrong file shape, including the WARP graph.
- Five main-hook checks confirm lazy/default-off loading and capture exclusion.
  The main Lua chunk and new helpers compile. Nine unchanged SDK declarations,
  game links and all twenty physical input hashes are verified.
- **Actual CSP observation passed**, as detailed below. WARP timings are not
  target GPU performance results; no current solver quality or frame-cost claim
  is made.

Evidence: `docs/diagnostics/2026-10-19/s154/`, including `field_checks.json`,
`controller_checks.json`, `runtime_audit.json`, both GPU result archives and
`warp_capture.log`, `actual_capture.log` and `actual_observation.json`.
No existing texture, physical tuning or production shader
was changed.

## Actual main-app result

The user reported `matched`, 34 passes and 56.587MiB. The collector independently
decoded all **42 lines / 640 values at frame660** from the game log, with zero
mismatches. The recorded 34 accepted passes and 59,336,208 nominal retained bytes
match the locally checked immutable allocation plan.

- All four input/header fingerprints match the CPU references. All 52 header
  rows pass the context and pose SHA256 checks. Geometry and material identities
  match the preceding s153 observation; the new frame has its own pose/context.
- The full-grid consumer reports **0 invalid cells / 123,224 supported cells**.
  World area sums to **40,288.59765625mm²**, within tolerance of the independently
  summed bake at the captured unit scale.
- The maximum full-grid normalized error ratio is **0.02341494**, below the
  acceptance limit of 1. The independent 16-sample CPU oracle's maximum ratio
  is **0.07262640**, also below 1; run endpoints and supported markers match
  exactly. All atlas padding is zero.
- Four derived cache fingerprints identify the consumed outputs. They retain
  their stated numerical-identity scope; this observation does not turn them
  into a collision-free proof of all output bytes.

This verifies the actual CSP world metric/area/run construction and its audited
consumer/readback path for this context. The observation gate is complete.
General GPU completion, recurrent reuse and live solver adoption remain open.

## Game procedure and next step

In a fresh, unpaused game session, open RainFX → Weather inputs and physical
units (P0) → **Enable s154 world field cache probe** → **Run s154 world field
cache once**. Other diagnostics need not be enabled. Report `observed` and the
classification or the displayed error. Driving/weather/FPS comparisons are not
required. A fresh session also avoids the known per-session logger cap. This
procedure has passed; no repeat is requested for s154.

Next bind this actual-grid input ABI to the frame consumers and examine their
resource cost before a bounded frame candidate is submitted. Earlier complete
solver graphs use small fixtures; this step does not make them 1024×256 live
solvers. Recurrent allocation/completion, curved feedback accuracy, bounded
elapsed-time debt, common optics and target performance remain adoption gates.
