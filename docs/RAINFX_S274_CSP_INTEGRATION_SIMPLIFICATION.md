# s274 — simplify the actual CSP boundary (2026-10-24)

## Assessment of the method

Yes, the workflow contributed to the delay. Many offline producer/transport and
ownership tests preceded the first complete CSP head/source run. They validate
equations and protocol pieces, but do not establish compatibility with CSP's
generated shaders, binding tables or actual callbacks. Missing the built-in
sampler declaration and then repeatedly narrowing a generic refusal were gaps
in the integration workflow. Passing more offline precision checks would not
have resolved those gaps.

This is not evidence that CSP cannot support the intended model: s266 already
completed a real three-second compact film run. It is evidence that actual
head integration needs a simpler, directly supported engine boundary before
further physical tuning or detailed optimizer studies.

## What the actual s273 snapshot establishes

First refusal14, reason517/context8, **head decode code1 at slot0**. The slot has
zero old state/meta, no birth allocation, valid zero ownership flags and a normal
completed empty trace. The global frame guard passes later in the same prefix.
Decode code1 is its entry/context/shape gate, before per-drop physical checks.
This rules out attributing this refusal to diameter, pinning, trail thickness or
a water-budget tolerance. Source publication then stops because its head receipt
is zero. Zero published supply is a consequence, not proof of no actual rain.

The failing decoder was the only producer with **16 bound textures**. Other
combined source passes have at most14. Native replay accepts, so the exact CSP
internal binding/shape failure is still not proven. In particular, **a CSP
16-texture bug is not asserted as fact**. The evidence supports addressing this
boundary instead of changing the physical model or bypassing its guards.

Actual results:26 submitted/audited, pending0,128 resources; advanced0.2418937683s,
debt0.2311468124s, all27 CPU readback objects disposed. Failed observation remains
preserved in `diagnostics/2026-10-24/s273/actual_observation.json`.

## Concrete compatibility changes

1. **Decoder16→14 inputs.** Reuse the original physical head packet already
   produced and validated by the ownership pass, rather than loading its old
   transform and recalculating it. Verify the reused packet is finite, its volume
   equals old metadata, and zero volume has zero momentum. Ownership validity is
   still required. Use the trace directly for new state: the wrapper asserts
   the owned new-state pass is the unchanged exact trace-copy shader and reads
   the same trace resource. Raw new-state commitment remains unchanged.
2. **Stable CSP parameter tables.** Reuse one table and fixed texture/value table
   schema per shader key, updating only bindings and values immediately before
   the draw. Keep `directValuesExchange=false`, so this uses ordinary SDK value
   copying, not a new FFI ABI. Original per-job packets remain immutable. Unknown
   key/body/schema reuse is refused. The installed SDK explicitly documents
   reusing tables for shader submissions; this is a standard integration path.
3. Keep the sampler compatibility adapter. Keep the same physical equations,
   conservation tolerance, actual dimension gates, retained inventory/source
   clock and queue limits. No numerical refusal is changed to acceptance.

The14-input form removes redundant reads and computation, but whole-app FPS or
GPU time improvement is not claimed. Its validity is limited to this owned graph;
arbitrary external new-state or ownership inputs cannot use the copy/packet
invariants. The original reference shaders remain unchanged.

## Verification

-11 native draws compare old/reduced decoders on captured empty inputs and a
 retained moving head: maximum observed output error0. Ownership, debit and
 wrong-size trace controls still refuse with the same codes.
-Stable-table bridge tests prove table identity survives changing inputs, source
 job packets remain unchanged, and body/schema collisions are refused.
-15 controlled owner and seven real-adapter panel cases pass, including actual
 menu dispatch and the retained160-float audit/disposal path.
-56 strict shader variants compile with the actual CSP sampler prelude. Every
 submitted graph pass, including the diagnostic snapshot, binds at most14 textures.

## Finite next step

Run the existing three-second combined gate as **s274 joint rain transport**,
with other diagnostics OFF in a fresh unpaused rainy session. No new standalone
probe or weather/FPS/image matrix. The already available full failure snapshot
stays in this build; no new diagnostic branch is added. This is a compatibility
fix candidate and needs the actual run before it can be called a resolved fault.

On accepted nonzero supply/zero-debt drain, remove the temporary640-byte audit,
then proceed to checked optical consumption and the2048/4096 whole-app frame-time
and visual evaluation. Use game-level physical/visual acceptance and bounded
conservation checks, not additional exhaustive FP32 parity projects. If the same
gate still fails, inspect its existing complete snapshot and this actual adapter
in place before asking for further user runs; do not resume a chain of broad probes.
