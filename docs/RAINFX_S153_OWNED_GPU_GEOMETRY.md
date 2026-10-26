# s153 — retained GPU geometry and physical input identity

Status: ACTIVE — local verification and actual main-app GPU observation passed
Date: 2026-10-19

## Connection and scope

s152 captured an actual main-app CPU context. s153 freezes the same context
through the unchanged s152 producer, then creates private GPU allocations for
the physical inputs below and its 52 header rows. A full-payload fingerprint is
computed from every base-level texel of each owned allocation and checked against
the CPU reference. This is connected to a default-off main-app diagnostic; the
current s87 solver, water stocks and production shaders are unchanged.

| Owned input | Dimensions | Format / role |
| --- | --- | --- |
| du | 2048×512 | RGBA32F local Jacobian/support |
| dv | 2048×512 | RGBA32F local Jacobian/coating |
| boundary | 4096×1024 | R32F boundary alpha |
| cells | 1024×256 | RGBA32F physical field cells |
| sites | 8192×1 | RGBA32F physical birth sites |
| dsd | 128×2 | RGBA32F existing DSD LUT |
| impact | 32×4 | RGBA32F existing estimated impact LUT |
| header | 1×52 | RGBA32F immutable s152 physical context |

The seven static inputs occupy **54,663,168 nominal bytes (52.130859MiB)**.
Including header, fingerprint intermediates and readback atlas, the one-shot
bundle owns **31 canvases / 55,505,088 nominal bytes (52.934MiB)**, below its
64MiB / 64-allocation limit. These are descriptor-based texel sizes, not a measured
driver residency/pitch footprint. Source-image cache memory is additional and
may already be present in the current app.

## Exact boundary-alpha layout

The production physical helper reads boundary alpha; coating comes from dv.A.
The existing BC3 boundary's decoded base-level alpha contains only 0 and 255.
The copy shader preserves the engine-loaded alpha as R32F, avoiding 48MiB of
unused RGB storage versus an RGBA32F copy. No texture is rebuilt or substituted
in the current renderer.

The prototype `surfaceR32` explicitly replaces the two boundary `.a` reads in
`rainSurfaceMetric.hlsl` with `.r`. Dimensions and point reads remain unchanged.
Original and adapted helpers give bit-identical local WARP results for validity,
coating and movement across supported/unsupported points. This is a new explicit
input ABI; an old consumer cannot bind the R32 boundary as if its alpha existed.
Other consumers must receive the same audited adaptation before adoption.

## Identity and lifetime

The s152 asynchronous file checks and pose/material/frame guards precede GPU
allocation. Each static descriptor must match that verified file set. The header
and all subsequent retries keep the captured context; changing the live weather
or transform cannot replace values inside a pending upload.

The owner creates whole one-mip allocations and assigns private opaque resource
and read capabilities. Backend allocation/draw callbacks are trusted seams. No
subresource view, clone or foreign handle can enter this namespace. Duplicate
keys/aliases, forged capabilities, unsealed reads and writes after acceptance
are refused. Here **sealed means no subsequent program write**; it does not mean
physical GPU completion.

One long-lived read lease covers inputs and subsequently consumed intermediates.
An unsubmitted lease may be released. Once any read is attempted, release and
disposal are refused and every canvas stays retained for the app/session. No
timer, frame count, `copyFrom()` or readback callback authorizes reuse/disposal.
Unknown submissions stop all retries and retain their resources. Cancel also
retains already allocated resources. There is one attempt per app instance, not
an accumulating per-frame allocation path.

This establishes a bounded immutable diagnostic input domain. It does not supply
a general completion fence, a resource-recycling strategy, an engine-wide native
allocation identifier or permission to mutate/share externally owned textures.

## Fingerprint and execution

Eight copy/upload passes are followed by full-texel fingerprint blocks and
associative reductions, then a 64×2 R32F readback atlas. Four uint32 words combine
bit patterns with their absolute element indices using XOR/modular addition.
Each word is encoded as two exact 16-bit float limbs. This is a deterministic
numerical fingerprint, **not a cryptographic authentication hash**. File SHA256,
role, dimensions and context identity are recorded separately.

The controller attempts at most one shader pass per scene-ready callback and
accepts each target once. Pending texture/shader work retains its prefix and
parameters; each pass has a 256-attempt limit. There are 31 accepted passes in a
successful run, at most eight bound textures, and no physical time consumption.
The CPU atlas object is disposed once; duplicate callbacks cannot dispose it
again. GPU canvases are never manually disposed.

Shaders compile asynchronously. SDK local image loading can be synchronous on
first use; the code checks one source at a time and does not change the app's
image-loading policy. This one-shot diagnostic does not establish cold-load or
steady-state solver performance.

## Local verification

- 14 managed/controller cases: successful/pending/image-pending, unknown
  submission, read error, mismatch, padding corruption, duplicate callback,
  cancellation, stale file identity, CPU refusal, readiness limit and wrong size,
  plus the actual WARP execution path.
- Direct owner checks cover immutable writes, opaque capability/lease refusal,
  unsubmitted/submitted release, capacity/format, pending/unknown and alias cases.
- Seven log-decoder cases and five actual main-hook checks, including zero helper
  loads while disabled and offscreen/native capture exclusion.
- **33 WARP draws / 8 strict FXC bodies**: all eight full copies/uploads match
  their CPU bits; all complete fingerprints agree; the explicit R32 boundary
  consumer matches the original helper. Last/interior/first texel and signed-zero
  mutations change the independent CPU fingerprint.
- SDK declarations for loading/readiness, whole-canvas allocation, shape/mips,
  shader updates and readback were audited. Existing game links expose the exact
  checked code and 20 unchanged input files. No installation/settings write.

## Actual user result

The user ran the main-app diagnostic in a fresh session and reported:
`observed`, `matched`, 31/31 passes, 31 retained canvases and 52.934MiB.

The collector independently parsed all **18 lines at frame939**. All **eight
full-input fingerprints / 64 limbs match**, including the current 52-row header;
there are zero mismatches. Static file identities and expected fingerprints match
the frozen CPU manifest, and the reported pass count and nominal bytes match the
locally verified allocation plan. Geometry and material keys match s152's actual
capture; pose/context keys differ, as expected for a new captured frame.

This actual run verifies GPU loading, alpha extraction, owned copy consumption,
full-input reductions and the closed-template readback path for this bundle.
It does not prove collision-free equivalence of all GPU bytes or general GPU
completion. `strictCompletion`, solver admission and public-clock advancement
remain false; no production physics adoption is made from this result.

Evidence: `docs/diagnostics/2026-10-19/s153/`, including `actual_capture.log`,
`actual_observation.json`, `geometry_checks.json` and `runtime_audit.json`.

## UI and remaining implementation

RainFX → Weather inputs and physical units (P0) → **Enable s153 owned GPU geometry
probe** → **Run s153 owned geometry probe once**. A fresh game session avoids the
known per-session logging cap. `observed` means all 18 lines were written.
The diagnostic is default-off. Its used resources remain retained; another run
requires a fresh session. This actual observation gate is complete.

Next connect the typed immutable input domain to derived world-space field
metrics/run data and frame consumers. The persistent main-app state is not
leased here, and the old RGBA-only import provider cannot accept the new boundary
layout unchanged. A bounded graph resource/completion strategy is still needed
before recurrent live solver adoption. Curved/feedback accuracy, elapsed-time
debt, common optics and measured cost remain adoption gates.
