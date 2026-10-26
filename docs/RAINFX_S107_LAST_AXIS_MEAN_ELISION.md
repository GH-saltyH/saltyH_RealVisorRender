# s107 — omit unused last-axis mean gathers

2026-10-17. **Status: ACTIVE — offline prototype.** Production remains s87
physics with the s89 diagnostic. No game build is installed at this stage.

## 1. Consumption boundary and implementation

s105's compact coarse post and s106's first-fine post do not consume a final
transported mean. Their last-axis gather still produced one. s107 replaces
that gather with a single-bank end-only shader, retaining the original donor
integral, reconstruction, search, compensated sum and refused-map fallback.

The first axis's full end/mean gather remains essential: its mean drives the
second axis's map and mean runoff. **Both axes' maps, leaves, groups and totals
remain unchanged**, including every mean-dependent loss and refusal check.
The omitted value is a final spatial output, not mean transport or its ledger.

| Candidate | First axis gather | Last axis gather | Final post mean |
|---|---|---|---|
| Compact coarse | end + mean | end | unavailable, as s105 |
| Compact first fine | end + mean | end | unavailable, as s106 |
| Second fine | end + mean | end + mean | full published mean |
| Accuracy-off/publishable coarse | end + mean | end + mean | full |

The last axis is Y for X→Y order and X for Y→X order. Selection uses the
actual axis uniform, rather than a fixed axis or a draw name that occurs twice.
No mean texture is bound to the end-only gather. The inherited axis splitter's
empty unused mean slice is removed before invoking compact post; it is never
uploaded as a texture or returned as a usable final packet. The advance still
reports `mean=None`, with `lastGatherMeanAvailable=False`.

The immutable offline batch flag `gResearchEndOnlyLastGather` defaults to1.
Set0 for full gathers. Eligibility also requires accuracy mode and a compact
post for that candidate: setting `gResearchCompactCoarse=0` or
`gResearchCompactFirstFine=0` independently restores that candidate's full
gather, because its full post consumes mean. The second fine is always full.
These research flags are not new game UI/runtime options.

No physical law, force/post shader, reconstruction/limiter, error tolerance,
source/pool transfer, time debt, cache ownership or publication schema changes.
Both fine candidates retain all six physical total rows and complete ledgers.

## 2. Verification

Strict FXC `/Ges /WX` compilation and D3D11 WARP execution verify:

- **36 axis comparisons** preserve end gather and every upstream map/leaf/
  group/total value bit-for-bit. Coverage includes skew/islands, rotation,
  affine pose, degenerate geometry, actual curved mesh, dry-limit ratios,
  determinant cutoffs, nonadjacent wet-source overtakes and positive/negative
  complete runoff. Shared faces remain identical. Overtake refusal and mean
  runoff remain unchanged; the omitted mean output is explicitly empty.
- Actual curved accepted embedded/accuracy-off, accuracy-only refusal and
  source/pool retry transactions match s106, including every trial total,
  error, decision, time control, final ledger and nonzero published mean.
- Source/pool transfers apply once; resumed and uninterrupted completion,
  full runoff into an empty domain, ownership/cache guards and publication
  fences retain their previous results.
- Actual curved reverse-order, full-gather opt-out and full-coarse-post cases
  match the reference. The inherited full-first-fine-post case also restores
  its mean gather. Captured draw dimensions show full first gathers and full
  second-fine gathers in either axis order, with only eligible last gathers
  reduced from2H toH.
- Interruptions precisely at compact coarse/first-fine last gather preserve
  caller public/private handles. Existing pending cache/map/post/block/snapshot
  checks also remain valid.

Regression fixtures and prior evidence are preserved with hashes. These
specified checks are not universal float32 equivalence, physical calibration
or general nonlinear convergence proofs.

## 3. Cost accounting

| Compiled gather | s106 full | s107 end-only |
|---|---:|---:|
| Static instruction lines | 199 | 191 |
| Static texture-load lines | 12 | 10 |
| Output banks | 2 | 1 |

The compact shader has no `txAdvMean` binding. This also avoids executing the
second packed output invocation and its search, but dynamic cost depends on
occupancy, contributors, travel distance and refusal. Static code/load lines
are not a GPU-time measurement.

At1024x256 RGBA32, two eligible final gathers remove **8 MiB of target output
extent per default embedded attempt**, relative to s106. Combined with s105/
s106, the reduction from the full s104 graph is24 MiB of packet target extent
plus32 KiB of coarse block targets per attempt. These are dimensions, not
measured bandwidth, peak memory or frame-time savings. Diagnostic flags can
restore individual targets.

No draw is removed or added. For `A` attempts, fresh/resumed embedded graphs
remain18+51A /16+51A:69 draws for one fresh attempt,171 for three. Cache remains
12 MiB plus144 receipt bytes at1024x256. **Target game FPS is unmeasured.**

**Decision:** retain the equivalent end-only last gather where the post has
no mean consumer, with complete mean runoff and full fallback behavior.

## 4. Next implementation and adoption gates

The now-removed outputs do not justify further fusion automatically. Fusing
an expensive gather into multiple post banks can repeat its search per bank.
Next build a bounded render-target lifetime/reuse plan for this graph, including
coarse/fine intermediates, retained retry checkpoints and pending publication.
Validate overwrite/alias guards and peak logical target extents for fresh,
resumed, accepted and refused calls before designing live allocation. Keep
this a resource proof; it must not masquerade as measured game memory or FPS.

Triple stepping and economical material error estimation remain substantial
cost gates. Pressure/contact-line/high-shear closure, general convergence,
full live head/source lifecycle, backlog/cache retirement/recovery and target
timing also remain open. Production runtime, user tuning/materials, calibration,
assets and earlier stages remain preserved. No reload/log request, installation,
commit or push.

## 5. Reproduce

```text
docs/tools/check_s107_gather.py
docs/tools/check_s107_transactions.py
docs/tools/check_s107_cost.py
docs/tools/finalize_s107.py
```

Baseline, reports, disassemblies, source diff and delivery audit:
`docs/diagnostics/2026-10-17/s107/`.
