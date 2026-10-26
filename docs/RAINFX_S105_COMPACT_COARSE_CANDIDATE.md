# s105 — compact unpublished coarse candidate

2026-10-17. **Status: ACTIVE — offline prototype.** Production remains s87
physics with the s89 diagnostic. This stage does not install a game build.

## 1. What is removed and what must remain

Embedded accuracy computes one coarse advance and two fine half advances.
Only the combined fine result can publish. The coarse result supplies its end
packet, evaporation/runoff and failure status to the error/admission checks.
Its final mean, applied impulse and wall impulse are not consumed there.

s105 specializes only that unpublished coarse path:

| Target | Full reference | Compact coarse |
|---|---|---|
| Donor force | end, travel mean, impulse, status/wall | end, travel mean, status |
| Recipient/post | end, final mean, evaporation, status/wall, impulse | end, evaporation, status |
| Block reduction | applied impulse, wall, evaporation, status | evaporation, status |
| Global totals | six rows | six rows; rows0/1 unavailable and zero |

Coarse total rows2–5 retain evaporation, combined status/axis admission, end
runoff and mean runoff, with the original operation and compensated-sum order.
The donor travel mean still drives both transport axes. Removing final mean
does not remove mean transport. The result explicitly reports `mean=None`,
`availableTotalRows=(2,3,4,5)`; omitted rows are not valid zero-impulse budgets.
Use the full fallback to inspect a complete coarse momentum budget.

Recipient force still computes and validates its own mean internally. The
transported mean texture is no longer loaded by compact final post; its output
does not enter coarse end, evaporation or status. Force/post validity remains
independent as in s104, and the compiler eliminates unused diagnostics.

Both fine advances retain all output banks and all ledger rows, including
applied/wall impulses and mean runoff. The actual published mean comes from
the second fine advance. Sources, pool transfers, water/time ownership,
cache format/receipt and error tolerances are unchanged.

An offline immutable batch flag, `gResearchCompactCoarse`, defaults to1. Set0
for the complete reference. With `gAccuracyMode=0`, the coarse candidate can
publish, so specialization is disabled regardless of that flag. This flag is
not a new game UI/runtime setting.

## 2. Verification and limits

Strict FXC `/Ges /WX` compilation and D3D11 WARP execution verify:

- **22 component cases** match the full s104 oracle bit-for-bit for donor
  end/travel mean/status, final end/evaporation/status, block sums and total
  rows2–5. They include ordinary/zero-dt/full-evaporation/dry/microfilm inputs,
  affine/reflected poses, independent Gram validity, normal cutoffs and invalid
  geometry/force/evaporation parameters. Synthetic axis losses/refusal test the
  reduction interface; those synthetic packets are not a conservation claim.
- Actual curved-mesh accuracy-off publication remains full and identical.
  Accepted embedded and accuracy-only refused trials retain identical error
  indicators, admission/control, private time debt and public stocks. Fine
  physical totals remain identical in every row; coarse rows2–5 match.
- A source/pool refusal followed by resume matches uninterrupted and full
  reference completion. Source/pool water is transferred once. Fine ledgers
  and final publication are unchanged.
- Explicit compact-off fallback preserves the complete coarse diagnostics.
  A full-runoff case with an empty final domain retains the complete fine
  runoff ledger and matches the full oracle.
- Pose/version/grid/format/readiness/interval guards and pending cache/map/
  snapshot fences remain valid. Added pending compact-post/totals checks leave
  the caller's public/private arrays unchanged.

Regression adapters hash the reused fixtures. These specified comparisons do
not prove all-input float32 equivalence, physical closure or general convergence.

## 3. Cost accounting

| Compiled shader | s104 static instruction lines | s105 static instruction lines |
|---|---:|---:|
| Donor force | 221 | 216 |
| Recipient/post | 271 | 240 |
| Block reduction | 70 | 51 |
| Global totals | 56 | 63 |

The six-pixel global total shader adds conditional branching while reducing
the number of block-sum rows from four to two. Its static code increase is
included above. Compact post has no `txCouplingMean` binding. Full fine and
projection/cache shaders are unchanged.

At1024x256 RGBA32, each coarse trial reduces force/post target extent by
three full banks: **12 MiB** of target output extent. Two omitted block banks
reduce the block target by **32 KiB**. These are per-trial target dimensions,
not measured bandwidth, peak allocation or frame-time savings. Global totals
remain six rows; cache remains12 MiB plus144 receipt bytes.

The graph still computes three physical candidates. With `A` attempts,
fresh/resumed embedded draws remain18+51A /16+51A:69 draws for one fresh
attempt,171 for three. No passes or retained cache bytes are added. Static
instruction/load lines do not measure dynamic execution or target GPU time.
**No game FPS benefit has been measured.**

**Decision:** retain this equivalent compact coarse option for the offline
controller. Preserve the full diagnostic fallback and complete fine ledger.

## 4. Next implementation and adoption gates

Next specialize the first fine advance's final mean, which the second fine
advance does not consume. Keep both fine advances' full impulse/wall/evaporation/
runoff ledger and the second advance's published mean. Validate the same error,
admission, retry/time and publication invariants against the full reference.

Triple stepping, economical material error estimation, pressure/contact-line/
high-shear closure, general nonlinear convergence, full live head/source
lifecycle, backlog/cache retirement/recovery and target-game timing remain
open. Production Lua/HLSL, calibration, tuning/material INIs, published assets
and all prior stages are preserved. No reload/log request, installation,
commit or push.

## 5. Reproduce

```text
docs/tools/check_s105_components.py
docs/tools/check_s105_transactions.py
docs/tools/check_s105_cost.py
docs/tools/finalize_s105.py
```

Baseline, reports, strict disassemblies, source diff and delivery audit:
`docs/diagnostics/2026-10-17/s105/`.
