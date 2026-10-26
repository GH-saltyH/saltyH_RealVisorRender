# s273 — first failed head snapshot (2026-10-24)

## Actual s272 result

First refusal14, reason517, context8: the physical head producer did not export
its current token. Its receipt namespace/serial were both zero. Source tokens,
previous checkpoint, source stamp, head header and source dimensions passed the
context comparisons. A producer decision blocked source publication; this is
not a reason to loosen the source guard.

Actual run:25 submitted/audited, pending0,128 resources;13 accepted slices,
advanced0.25186824798583984s and debt0.24518966674804688s. All26 CPU readback
objects were disposed. Captured input/frame756/density59.82/rain0.6, prior pose
and all52 admitted FP32 rows were recovered. The actual observation is preserved
under `diagnostics/2026-10-24/s272/actual_observation.json`.

## Local replay and its limit

Replaying the captured header, prior pose and current bake at4096 slots produces
an accepted head receipt. The short input has no native incident packet. An
additional declared1000/m³ supply check also accepts. These do **not** reproduce
the actual GPU failure. Prior raw state/meta were reconstructed as canonical
empty because the accepted source inventory is zero; their actual GPU bits were
not captured. The CPU input alone therefore cannot establish full GPU replay
equivalence. The discrepancy must be diagnosed from the actual first bad head.

## Temporary integrated snapshot

The head status reduction keeps the same red acceptance rule, and propagates the
first nonzero decode code and slot through its previously unused channels. The
source guard still calls its original context function. On rejection, existing
detail words expose context/code/slot. No admission gate is removed or relaxed.

Before a subsequent input can overwrite scratch resources, the existing audit
copy now stores160 R32F values rather than16. Its first16 floats are the original
joint receipt. The remainder selects the first failed head:

| Float4 rows | Contents |
| --- | --- |
| 0–3 | Original joint receipt |
| 4 | Head decision: bad flag, code, slot |
| 5–6 | Old raw state and metadata |
| 7–11 | Birth spawn, motion, allocation, ledger, pool |
| 12–17 | Ownership state/meta/pair/wall/flags/original packet |
| 18 | Post-force state |
| 19–22 | Trace state, last state, exit packet, trace status |
| 23 | Provisional metadata |
| 24–28 | Path, transfer, incident, support, union bounds |
| 29–30 | Final metadata and decoded status |
| 31–33 | Merge/unit/material config |
| 34–39 | Reserved zeros |

Nonfinite diagnostic details become FLT_MAX sentinels to keep the bounded log
serializable; the primary16-float receipt is copied unaltered. This is diagnostic
encoding, not normalization of physical stocks or acceptance. Actual used
intermediate rows can now be compared with the captured CPU input/current bake.

Per-head codes:1 context/dimensions;2 finite/meta/input validity;3 ownership,
lifetime or support transition;4 final debit/meta;5 field geometry/support;
6 water budget;7 nonfinite derived packet. These codes originate in the existing
decoder; the new reduction only retains them.

One readback/API callback per interval remains. Payload64→640 bytes and32 audit
buffers increase18,432 bytes, keeping128 canvases. At4096 slots, owned descriptor
bytes are139,151,152; file images add42,080,256 bytes. CPU serialization/readback
cost is not claimed identical. This is a short diagnostic and should return to
the small receipt after the bug is fixed.

## Local checks and actual capture

-38 native producer draws using the captured input/prior pose: no reproduction.
-Seven native reduction/snapshot draws verify unchanged red decisions, first
 failed slot selection, all160 output words and the nonfinite-detail sentinel.
-15 controlled owner cases verify exact current/prior input and immutable full
 snapshot retention; seven panel cases exercise actual menu dispatch,160-word
 readback/disposal, failure logs and collector reconstruction.
-56 distinct shader variants, including the13-texture snapshot, compile strictly
 with the captured CSP sampler prelude. Original physical shader files remain.

Actual cause is **not fixed**. In a fresh unpaused rainy session, other
diagnostics OFF, run **Enable s273 joint rain transport → Start s273 joint rain
transport** in the same P0 menu. Report State and **First refused / context /
head code / slot** or success stats. Complete GPU/CPU failure data are automatic;
no new app, FPS matrix or screenshots. Use this one integrated failure capture
to fix the concrete head condition, rather than adding more broad input probes.
