# s188 — output capability gates and exact static geometry words

Status:119 native standalone draws and independent warm descriptor proofs pass,
2026-10-20. New input representation selected for the **next offline owner**.
Main runtime remains physics s87/diagnostics s89. No user game test.

## Paired-output decision

Both the reference and installed CSP app SDKs document a single ExtraCanvas
receiver and a `float4 main(PS_IN pin)` entry for `updateWithShader` and
`updateSceneWithShader`. Their declared parameters expose no target list; the
audited app API declarations expose no matching compute-dispatch entry point.
This does **not** prove undocumented support is impossible. It supplies no
verified route for publishing paired End/Mean outputs in one cell evaluation.
No MRT/compute execution or general CSP completion is claimed.

A descriptor-only alternative splits each private End/Mean image into two
ordinary targets, adding two ordered single-target draws in place of one.
All original readers and completion boundaries are conservatively preserved.
The certified proposal has556 logical resources instead of524, adds32 draws
over the two modeled frames, and introduces no extra completion boundary.
It **does not lower the67,099,472B phase floor**. Permanent reservation instead
grows8MiB to81,587,104B, and creation traffic also grows. Reject this alternative
before GPU implementation. Its code is a pure planner, not an executed shader
or an allocation authorization. The s187 seven-word dynamic packet is also
still experimental; neither alternative replaces s185 dynamic storage.

## Static input implementation

The immutable s175 geometry dictionary contains six arbitrary FP32 derivative
components and two special fourth components. In the actual retained table,
`du.w` is a nonnegative integer no larger than319 and `dv.w` is0 or1. The new
encoder validates the wider exact domain `du.w=0..511`, `dv.w=0..1`, combining
them as `du.w + 512*dv.w`, an exactly representable integer0..1023. It keeps all
six xyz FP32 words unchanged, including signed zeros.

Seven words per entry are densely stored in one RGBA32F texture. The original
153,990 dictionary entries, full2048×512 index, geometry resolution and point
sampling remain unchanged. Two1024×151 tables become one1024×264 table:

- Tables: **4,947,968→4,325,376B**, saving **622,592B /608KiB**.
- Geometry input bindings: **three→two** (index plus packed data).
- Index payload stays bit-identical; the encoder owns a CPU copy for its result.
- No new GPU pass, floating-point quantization or repeated physical producer
  evaluation is added. Metadata tags are decoded exactly; unsigned word moves
  preserve xyz bits. The old helper's logical bounds and point clamping remain.

Encoding refuses fractional/oversized tags, nonbinary dv tags, negative-zero
tags, nonfinite/non-FP32 tables and noncanonical padding before upload. It also
limits physical extent and word counts to the exact supported host domain.
This is a conditional codec, not an assertion that every future geometry bake
will fit the tag domain. Future inputs outside it must be refused or use the
preserved original representation.

## Verification

**119 standalone WARP draws**, using the frozen strict native renderer and
warning-as-error shader compilation:

- Both full-resolution derivative images match all original bits; field-grid
  samples and8192 point samples per component match frozen s175 results.
- All1024 tag combinations and signed-zero xyz cases round-trip through actual
  shader loads. Wrong packed extent fails the geometry-validity guard.
- Eight frozen birth/head scenarios plus actual-bake birth and actual-bake
  head scenarios match every saved root. Physical equations are unchanged.
- Seven malformed CPU payload cases refuse without mutation. Codec table and
  final image/graph outputs are saved for independent checks.

These are standalone input/consumer tests, not execution of a persistent joint
cache/source/head/transport owner. No new recurring owner, completion events,
game FPS or target GPU/CPU timing has been tested in s188.

## Warm memory and lifetime proof

The two immutable tables merge into one generation member with the **union of
their readers**. The index and packed table must remain leased as one immutable
generation. All other resources retain their shapes, births, last uses, readers
and producers. All18 force/source-cell last-reader records remain after ID
remapping, and no completion boundary is added or removed.

| Warm descriptor metric | s185 baseline | s188 geometry proposal |
| --- | ---: | ---: |
| Static bytes |27,106,144 |26,483,552 |
| Live frontier bytes |66,051,952 |65,429,360 |
| Permanent typed reservation bytes |73,198,496 |72,575,904 |
| Phase floor bytes |67,099,472 |66,476,880 |
| Retention limit |64MiB |**63.5MiB** |
| Bounded modeled peak bytes |67,107,744 |**66,572,192** |
| Margin to original64MiB budget |1,120B |**536,672B** |
| Cumulative creation bytes |87,677,856 |86,968,224 |
| Created generations /retirements |111 /35 |107 /29 |

The63.5MiB limit is stricter than the original64MiB budget. A63MiB control still
refuses. The modeled lifetime/typed-allocation certificates pass for both63.5
and64MiB limits. Even at64MiB, the proposal creates fewer bytes and generations
than the baseline. The permanent pool remains over64MiB; explicit retirement
is still required. These counts exclude CPU fixtures/staging/driver memory and
do not measure total VRAM or process memory.

The helper adds word addressing, tag unpacking and potentially more table loads
than the original two simple table reads. Reducing retained bytes and bindings
does not establish a speedup. Target timing and cache behavior remain open.

## Next implementation

Connect the packed index/table generation to a private native retained-input
owner. Validate actual uploads, exact consumer results, failed preparation,
retry, old readers, generation replacement and complete retirement accounting.
Then compose with the actual-grid joint physical owner and account for cold or
changing-pose overlap. Do not publish the new representation in the main app
before these ownership and timing gates pass.

Whole-pipeline64MiB adoption, CSP completion, target timing, common optics and
live integration remain false/open. Main app, settings, production shaders and
assets, and installed game are preserved. Git stamping stays with the user.

Evidence: `diagnostics/2026-10-20/s188/geometry_checks.json`, SDK declaration
audit, refused split-output plan, packed geometry/result arrays,119-draw graph
checks, lifetime/phase certificates and capacity controls, source diff and
`delivery.json`. No frozen builder was rerun.
