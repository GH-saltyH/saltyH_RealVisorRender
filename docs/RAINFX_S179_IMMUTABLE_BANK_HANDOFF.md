# s179 — immutable bank-root ownership handoff

Status: native physical reference verified, 2026-10-20. Main game physics stays
s87; diagnostics stay s89. This step is offline and does not install game code.

## Change

The previous owner copied all eight candidate roots into a fresh bank. Seven
roots already have completed, immutable backing: micro, heads, state, meta,
pose, cumulative ledger and checkpoint. s179 transfers their retained resource
pointers into the pending bank. Completion and explicit old-reader return are
still required before the bank, cache and clock publish together.

Film keeps an **independent End-only copy**: the transport backing contains
End/Mean, while the published bank uses only the End domain. No packed view is
silently substituted for that independent bank texture. The other seven roots
use their exact typed views; no physical equation, shader or output changes.

Pending and published banks protect the direct roots from the free pool.
Failure discards the pending ownership set without releasing still-leased frame
results, so the same completed physical state can retry the bank operation.
The previous bank remains readable. Reusing an already published mutable object
as a new result refuses; an identical immutable pose may be shared across frames.
All same-draw SRV/RTV, writer-order and last-reader guards remain in force.

## Native verification

One native D3D11 WARP context executes the existing13×7 field /8-slot reference,
three source ON/OFF/ON frames and four transport quarters per frame:

- **618 draws /37 real completion events**, unchanged from s178.
- Bank `CopySubresourceRegion` operations fall **32→4**: one film copy for each
  of three successful publications and one deliberately failed preparation.
- 28 direct-root candidates remain protected against recycling;21 publish in
  three banks. Three unchanged-pose handoffs are accepted, including retry.
- All208,388 saved FP32 words across physical imports/roots match s178 bits;
  all eight inventory roots and their saved bank images match exactly.
- Independent head-force, source and water-ledger oracles pass. Published time
  is46.875ms; accepted time equals published time plus active/queued debt.
- Cache/source/bank-completion failures, retry, source replay refusal, old-cache
  readers and premature publication checks still pass. Pending-root protection
  does not implicitly return the caller's old-bank reader.

Native C++ builds with `/W4 /WX`; the D3D debug layer reports zero warnings.
All50 preserved strict shader bodies are hash-verified and reused. No earlier
builder/checker/finalizer runs. Wrong-shaped or ambiguous handoff proposals
refuse without mutating their input plan; a shortened retained lease fails the
independent lifetime certificate.

## Copy bandwidth and memory result

For the full1024×256 field /4096-slot descriptors, the seven avoided copy
destinations total4,391,120B per normal publication. Their minimum logical read
plus write traffic is **8,782,240B /8.375397MiB per publication**. This excludes
driver behavior and diagnostic staging copies; it is a descriptor-derived
bandwidth reduction, not measured target GPU timing or FPS.

The native small reference's texture peak falls only406,336→405,952B. Separate
diagnostic staging remains282,096B. The old exact-shape pool already reused
large bank-copy destinations for working targets, and direct sources now need
longer leases. Consequently the warm full-grid proposal hardly changes:

| Warm descriptor proposal | s178 | s179 |
| --- | ---: | ---: |
| Static inputs |33.850433MiB |33.850433MiB |
| Maximum simultaneous live set |74.992050MiB |74.992050MiB |
| Exact-shape pool reservation |89,975,760B /85.807571MiB |89,975,712B /85.807526MiB |

Only48B of reserved capacity disappears. **Bank-copy removal does not solve the
memory peak.** The next memory work must target simultaneous force/map/gather
buffers and the retained physical inputs/stock. The lifetime plan preserves all
16 quarter-force and2 source-cell reader records, extends each direct root to
cover its former bank-copy readers, and retains the two film-copy destinations.
The independent certificate passes; full64MiB admission still refuses.

The full-grid figures are a recertified warm proposal, not execution of the
complete actual-grid cache/head/source/transport owner. The native recurring
reference remains planar and small. Joint cold construction, pose replacement,
curved physical recurrence, the s177 cache owner, common optics, CSP completion
and target cost are still uncombined/unverified. No alternate memory budget is
adopted. Main app, settings, production shaders/assets and installed game remain
unchanged. No user game test is requested; Git stamping remains with the user.

Evidence: `diagnostics/2026-10-20/s179/bank_checks.json`, native reports,
full saved physical/bank images, `joint_plan.json`, `physical_last_readers.json`,
`numerical_audit.json` and `delivery.json`.
