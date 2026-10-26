# s243 — fuse the small dynamic-header proof into seed audit (2026-10-22)

## Result

A versioned graph replaces the small dynamic-header fingerprint/reduction with
208 direct integer-word comparisons in the existing immutable-seed audit pass.
All three full-field geometry fingerprints remain. The separate frame upload
also remains: a consumer must read back the actual uploaded texture rather than
assume that constructing its uniform values proves the uploaded contents.

The complete two-input/three-slice native continuation matches all six archived
s242 packed End/Mean and ledger arrays bit-for-bit. The same80391 represented
ticks drain with zero debt. Ten executor scheduling/fault cases still pass.
A separate native audit accepts the valid header and rejects low-bit token,
force and calibration changes, positive-to-negative zero, and a geometry digest
change. No numerical or state-identity tolerance is relaxed.

| Work/storage | s242 | s243 |
| --- | ---: | ---: |
| Cold interval submissions | 87 | 85 |
| Each subsequent input generation | 71 | 69 |
| Three-interval native run | 229 | 223 |
| Fixed resources | 87 | 85 |
| Planned bytes | 95,622,608 | 95,622,448 |
| Status reads | 3 | 3 |

The160-byte storage change is negligible and is not a memory optimization
claim. This removes two GPU passes per input generation, not the central
transport/completion throughput limitation. A cold85-pass interval still needs
at least11 pumps with the existing8-call ceiling.

## How the proof changes

The small52×1 RGBA32F frame texture previously passed through a block hash and
its reduction before seed audit checked its8 hash limbs. Seed audit now reads
each row and compares `asuint(actual)` with the supplied expected row. This
preserves exact FP32 representations, including signed zero, and removes the
header digest's collision possibility within this comparison. It is an input
integrity check, not an authenticity/security guarantee.

The seed audit uses52 expected vec4 uniforms in place of the fourth digest's
two vec4 limbs:50 additional vec4 values,800 bytes of logical constant data.
Frame upload itself is unchanged. Real CSP constant preparation, submission
and shader costs could offset the removed dispatches; no CPU/GPU/frame timing
has been measured. The old graph builder also still computes its header hash
before specialization prunes it, so no construction-time CPU saving is claimed.

Only dead header-fingerprint ancestors are pruned. The wrapper remaps resources,
roots, names, private loopback bindings and cache partitions, and retains all
remaining status ancestors. The audit still depends on the frame and all three
geometry digests. Its expected values are independent copied uniforms, not
references into a caller-owned row table. Transport, scalar area, full-field
geometry audits, End/Mean rollback, ledger and checkpoint bodies are unchanged.
The existing paced owner and queue are reused without modification.

## Evidence and qualification

The native full-field test derives the frozen s242 harness, changing only graph
construction and the expected resource count. It retains actual shader draws,
receipts, full-array stock/ledger checks and exact boundary copies. The tiny
native audit tests corruptions separately, while the10 scheduling cases use the
previously documented adapted receipts and do not claim additional physics.

This is a local implementation candidate. Game/main/settings, visible s87,
public stock/time and renderer access are unchanged. It is not a target timing
pass, actual CSP sampler connection, sustainable continuous throughput or final
game adoption. The s239 tail warning and s242 soft-deadline limits remain.

Next measure actual warm dispatch/constant/completion costs and identify the
dominant full-field passes before further proof reduction. Continuous input
must eventually drain without growing debt; merely increasing the call ceiling
does not demonstrate an acceptable frame budget. Conserved incident/head
sources, renderer/common optics, reset/replay and long-run adoption remain open.
No user game test or Git commit/push is requested in this stage.

Evidence: `diagnostics/2026-10-22/s243/gpu_checks.json`,
`continuation_results.npz`, `execution_checks.json`, strict compile artifacts
and `delivery.json`.
