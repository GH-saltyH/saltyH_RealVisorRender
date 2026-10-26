# s276: CSP preview728 compatibility review and zero-debit identity

## Confirmed build boundary

Actual log: preview728/4263, changed from4184. Restored649 app SDK matches the
recorded649 runtime SHA exactly; installed728 SDK matches the supplied728 archive.
Full package comparison:749 ->755 files;65 modified,7 added,1 removed. Lua.zip is
byte-identical and all packaged shader-library files are unchanged. Native
`dwrite.dll` did change, so these facts do not prove identical internal behaviour.
All23 previously captured critical canvas/render/readback/format API blocks match.
Raw package/API evidence is under diagnostics/2026-10-24/s276.

Official changelog: https://gist.github.com/gro-ove/d2d0f89b50adaa3f94e8f6b8657cda8a
Pinned revision98ab2f0b60156b657fdceccfdaf330e634ff1ead. Its stated coverage is
October7 to October22, not the whole649-to728 interval. Full archive differences
cover both supplied endpoints; unlisted native changes cannot be reconstructed
from SDK definitions or this changelog alone.

## Project response

|Change|Impact and response|
|---|---|
|Angle/cross-vector API corrections and new angle2/setCrossNormalized2|No old calls in root runtime Lua. No replacement required.|
|mat4x4 transform/transformTo now respect w|No affected calls. Existing transformPoint/transformVector calls stay explicit; physics header keeps explicit matrix rows.|
|SceneReference:setMaterialProperty no longer caches values|Ten call sites inspected. Editor apply and probe preparation are explicit or owner/key/value gated. Do not add a stale global cache; repeated explicit Apply must remain effective.|
|Updated LuaJIT, reused captureless arrow closures|Current runtime uses ordinary Lua functions, not new arrows. Keep compatibility and callback identity; no syntax migration for speculative speed.|
|math.seededRandom/table.isArray/os.parseDate changes|No affected root calls. Existing physical deterministic hash/DSD sampling unchanged.|
|applyShaderReplacementsAsync preloads replacements|A different API from ExtraCanvas:updateWithShader. Do not substitute it for numerical canvas compilation. Retain async=true and bounded readiness.|
|DDS loader fix|Physical file hashes/dimensions passed in s275. No format or calibration change; keep texture validation.|
|Extra canvases include dynamic light shadows; ExtraFX/TAA/DLSS adjustments|Numerical updateWithShader textures do not render a lit scene. Optics/GeometryShot and final temporal appearance need the later visual gate; do not infer FPS improvement.|
|Dynamic KN5 render order/culling and VR SPS fixes|Relevant to native glass/FX visibility, but no concrete current failure demanding another render-state workaround. Recheck at the planned optics/VR gate.|
|Exterior wiper trails optimized, puddle artifacts fixed|Built-in RainFX changes do not replace this custom trail/film solver. No new input multipliers or trail retuning without visual evidence.|

No required API rename was found. Keep the narrow stable CSP bridge and the
existing23 API contracts. Do not retest the entire old research matrix merely
because the patch changed. Existing pre728 timings and new728 timings have
separate provenance; FPS/compile speed cannot be compared from these two runs.

## Actual s275 failure

Submitted/audited48, pending0, resources128. Advanced0.681266785s,
debt0.204553604s. Incident9.987599, stock5.258929, exits4.728670mm3.
First refusal37, reason7, context/head0. Source mask330=2+8+64+256:
cell/status failure, deposited tail inconsistency and step/next ledger closure.
Source head status/mask0 means per-head source checks passed. Prior cumulative
closure and previous-stock aggregate are not flagged. CellStatus2 is local
post-input validation, not a general binding/context failure. Deposition and
ledger errors can follow that cell clearing its rejected outputs.
The same serial37/refusal class existed on649 in s274: this evidence does not
support calling it a728 regression. Cold warmup completed in this728 run.

## Fix candidate

Pool return is OFF, so requested film debit is zero. The previous cell function
still evaluated remaining/old.r, rescaled old momentum, then subtracted to make a
zero-volume debit packet. An inexact reciprocal result can leave momentum in
that zero-volume packet; packetValid correctly refuses it. A zero debit must be
the identity without any round trip. s276 uses retained=old and debit=0 directly
when requested==0. Only requested>0 uses the existing division/debit formula.
Apply the same rule to cell status, totals and all six source commits (eight
passes). New shader cache keys prevent using the old cell body.

This fixes a demonstrable numerical vulnerability; actual failure attribution is
not yet proven. Native WARP did not reproduce the unperturbed actual cell error.
The one-ULP reciprocal stress control rejects4096/4096 cells before and0/4096 after.
The ordinary4096-cell identity case and positive0.25mm3 debit both pass; positive
outputs match exactly. No clamping, epsilon widening, water loss or model tuning.

## Delivery and finite validation

-6 native GPU control draws; identity across4096 positive-volume cells.
-15 controlled owner cases;7 real-adapter panel/menu cases.
-56 strict CSP-header shader variants; max14 bindings, source snapshot7.
-Same128 canvases,139151152 owned bytes; same640-byte audit and read count.
-Default-off s276 menu installed through the linked main app. Renderer remains
 disconnected; public stock/time and existing visual effects are unchanged.

Run the same three-second s276 joint transport once, other diagnosticsOFF in a
fresh rainy unpaused session. Need observed/drained, nonzero incident, zero debt.
If refused, use existing source mask/status/slot logs before another experiment.
After acceptance remove temporary capture, connect optics and measure whole-app
2048/4096 head cost and visual behaviour. No additional precision project planned.
