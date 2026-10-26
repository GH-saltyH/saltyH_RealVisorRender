# s140 — same-backend source reference and actual s139 v2 assessment

Date: 2026-10-18
Status: ACTIVE

## 1. Actual result

The user completed s139 v2 in a fresh game session and reported `observed`.
All 296 tagged log lines were collected: **53,312 float words**, 255 accepted
calls in 319 attempts, with a maximum of nine attempts for one call. The paged
capture completes without the original 40-texture binding fault.

The original evaluator classified all five positive cases as mismatched while
all three negative cases passed. This first classification, source code,
installed package, raw capture and s139 v2 delivery are preserved byte for byte.
The correction and separate assessment live in s140. No shader or game app
update and no new game run are needed.

## 2. Evaluator cause and correction

The positive-case **input source control** always selected the s138 WARP input,
even when evaluating actual CSP. The geometry metric is calculated by the GPU
producer, so that comparison mixed two backends. Each positive metric differs
from WARP in 110 float words, maximum absolute difference **2⁻³⁰**
(9.313225746154785e-10). The other four source fields match WARP exactly.

All five metric inputs, along with the other twenty source controls, match the
**pre-existing s137 actual CSP source capture bit for bit**, including both
stock scales and both axis orders. The s137 capture/delivery existed before this
experiment, and its immutable provenance is checked; it is not a reference fitted
to this new result.

`s140_observation.py` changes exactly one evaluator block: actual source controls
select the matching s137 actual source case via the existing sourceVariant;
WARP source controls continue to use s138 WARP. Comparison stays bit-exact.
No epsilon, tolerance, physics, parsing, header/plan check, transport expression,
conservation bound or conditional map model changes. Original and corrected
results are compared field by field to prove every non-source-control diagnostic
is unchanged. The original WARP assessment is also unchanged.

## 3. Scoped pass

The saved actual capture passes under the corrected source-reference contract:

- **25 bit-exact source controls**, including every metric, against the existing
  actual CSP source reference.
- **64 bit-exact header controls**; five exact active plans at their intended
  full/partial dt; three intentionally invalid contexts refuse with zero dt and
  inactive flag.
- **60 bit-identical logical/bank pairs and 20 end-only/full-gather checks**,
  intermediate copies, admission, nonnegative mass and zero invalid recipients.
- Per-axis and cumulative End/Mean conservation under the original 64/128-ULP
  bounds; **3,640 map endpoints** inside the existing s134 conditional enclosure.
- All **52 full-time same-backend control fields** match the earlier actual
  control. Partial-time WARP pointwise differences remain visible diagnostics;
  their gate remains the previously defined invariants and source-graph bounds.
- All eight accepted-prefix write/early-return guards pass; cumulative read pins
  reach 104. All 255 calls are accepted once despite shader compilation retries.

Thirteen mutation controls detect source/header/plan/copy/counter changes. A
single-bit actual metric change is rejected. Replacing the actual metric by the
WARP metric is also rejected by the corrected strict actual-source control.

The assessment rechecks the fresh raw-log boundary and installed hashes. It does
not infer a resource completion fence from shader acceptance or readback. Used
probe allocations remain retained; game roots and host time are not published.

## 4. Remaining implementation

This closes the isolated actual header/partial-plan observation gate under the
corrected same-backend source contract. It does not establish arbitrary runtime
numerical admission, full recurrent physics, production ordering/lifetime
authority or measured game cost. Main gameplay physics stays s87/s89.

Next implement the true End/Mean/force/source/head-ledger producer handoff.
Production P3's film/micro/evap/runoff channels must not be relabelled as temporal
End/Mean world momentum. No additional s139 v2 game experiment is required.
