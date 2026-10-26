# s106 — omit the unused first-fine final mean

2026-10-17. **Status: ACTIVE — offline prototype.** Production remains s87
physics with the s89 diagnostic. No game build is installed at this stage.

## 1. Consumption invariant and implementation

The embedded controller computes a coarse advance and two fine half advances.
The second fine advance receives only the first advance's **end** packet. Its
travel mean is freshly computed by donor force. The first fine final mean is
neither an input to the next advance nor part of error/admission/publication.
Both fine advances' complete physical totals are combined before publication.

s106 therefore changes only the first fine recipient/post output:

| First fine post bank | Full s105 | s106 |
|---|---|---|
| 0 | end | end |
| 1 | final mean | evaporation |
| 2 | evaporation | status + wall impulse |
| 3 | status + wall impulse | applied impulse |
| 4 | applied impulse | omitted |

The first fine block reducer changes its addresses to this four-bank layout,
while retaining all four reduction banks. All six global total rows remain
available, including applied impulse, wall impulse, evaporation, failure/axis
status, end runoff and mean runoff. Operation and compensated-sum order are
unchanged. The first advance reports `mean=None` rather than exposing the
inherited slice, which now contains evaporation.

Its full donor force, donor travel mean and both transport axes are unchanged.
Recipient force still computes/validates its own mean internally. Final post
does not load the transported mean texture; that value does not enter end,
evaporation, wall, applied impulse or status. Independent force/post validity
from s104 remains intact.

The second fine advance retains its full five-bank post and published mean.
s105's coarse specialization and full coarse diagnostic option remain intact.
Sources, pool transfers, error tolerances, dyadic time debt, cache ownership,
publication and SI/display calibration are unchanged.

The offline immutable batch flag `gResearchCompactFirstFine` defaults to1.
Set0 to restore full first-fine output. Specialization requires embedded
accuracy mode and the `fine_first` label; accuracy-off/publishable coarse and
second-fine paths remain full. This is not a new runtime/UI setting.

## 2. Verification

Strict FXC `/Ges /WX` compilation and D3D11 WARP execution verify:

- **22 component conditions** preserve first-fine end, evaporation, applied
  impulse, wall impulse and failure status bit-for-bit against s105. All four
  block banks and all six global total rows match. Cases include dry/microfilm,
  zero dt/full evaporation, airflow, affine/reflected poses, Gram overflow,
  normal cutoffs and invalid geometry/force/evaporation parameters.
- Synthetic runoff and axis-refusal inputs exercise the reduction interface.
  They are not a physical conservation claim.
- Actual curved-mesh accuracy-off and accepted embedded publications match,
  including nonzero published mean, stocks, complete fine ledger and clock.
  All coarse/fine totals, errors, decisions and control match for accepted,
  accuracy-only refused and source/pool retry trials.
- Source/pool refusal/resume matches uninterrupted completion with transfers
  applied once. Full runoff into an empty final domain retains its complete
  volume/momentum ledger. The first-fine opt-out reproduces the full reference.
- Direct advance output verifies four first-fine post banks, unchanged donor/
  block extents, all total rows available and explicit unavailable final mean.
  Existing owner/cache/map/snapshot fences and new first-fine post/block
  interruption points leave caller arrays unchanged.

Reused fixtures are hashed and prior evidence remains unchanged. These scoped
checks do not prove universal float32 equivalence, physical closure or general
nonlinear convergence.

## 3. Cost

| Compiled shader | s105 static instruction lines | s106 static instruction lines |
|---|---:|---:|
| First fine recipient/post | 271 | 260 |
| First fine block reduction | 70 | 70 |

The first post no longer binds `txCouplingMean`. Donor, second-fine, coarse,
global total, transport and projection/cache shader sources remain unchanged.

At1024x256 RGBA32 the omitted first-fine post bank reduces its target output
extent by **4 MiB per embedded attempt**. Together with s105's coarse change,
the reduction from the full s104 graph is16 MiB of packet targets plus32 KiB
of coarse block targets per attempt. These are output dimensions, not measured
bandwidth, peak memory or GPU-time savings.

No draw is removed or added. For `A` attempts, fresh/resumed embedded graphs
remain18+51A /16+51A:69 draws for one fresh attempt and171 for three. Cache
remains12 MiB plus144 receipt bytes at1024x256. Both transport means, complete
fine ledgers and triple physical stepping still have costs. **Game FPS benefit
is unmeasured.**

**Decision:** retain the smaller first-fine post path with its explicit full
fallback. No discarded final mean may be mistaken for a usable packet.

## 4. Next implementation and adoption gates

Next evaluate omitting the **last axis's gathered mean output** in coarse and
first-fine advances, whose final post no longer consumes it. Preserve the first
axis's mean, all mean-dependent maps/leaf/runoff calculations and complete fine
loss ledger. Keep full gather for the second fine/publication path, diagnostic
fallbacks and either axis order. Compare axis refusal and transaction results
against this reference before retaining the optimization.

Economical material error estimation, pressure/contact-line/high-shear closure,
general convergence, full live head/source lifecycle, backlog/cache retirement/
recovery and target timing remain adoption gates. Production runtime, user
tuning/materials, assets and earlier stages remain preserved. No game reload/
log request, installation, commit or push.

## 5. Reproduce

```text
docs/tools/check_s106_components.py
docs/tools/check_s106_transactions.py
docs/tools/check_s106_cost.py
docs/tools/finalize_s106.py
```

Baseline, reports, disassemblies, source diff and delivery audit:
`docs/diagnostics/2026-10-17/s106/`.
