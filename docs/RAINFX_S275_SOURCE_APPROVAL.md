# s275: source approval detail and bounded cold startup

## Actual result and conclusion

s274's first session timed out at20.010s preparing head_9/key274209. The restarted
session accepted36 intervals then refused serial37: reason7, context0, head code0.
Advanced0.658476s, debt0.187680s; incident9.987599, stock5.171661 and exits4.815937mm3.
Nonzero physical supply now works in this run. The three-second gate remains unpassed.
Reason7 includes source approval plus consistency/checkpoint failures which can be
consequences of source fallback. It does not establish three independent errors.
The cause of the cold compilation delay and the precise source refusal remain unproven.

Do not widen physical tolerances speculatively. A native GPU reconstruction of4096
moving supported packets found exact equality; it does not reproduce actual CSP.

## Implementation

Source decision and per-head rejection reasons occupy unused channels without
changing red acceptance, physical equations, bounds or ledger tolerances. The
same160-word audit now targets source approval. Rows0-3 remain the receipt;
rows4-30 are zero; rows31-39 store source decision, first rejected source slot,
original/recomputed old head, initial/final aggregate, previous ledger stock and
source/raster deposition totals. Earlier full head captures remain in s273/s274.

Snapshot bindings drop13 to7; graph maximum remains14. Same128 canvases,
139151152 owned bytes, same readback count. First-bad-slot scans run only when
source approval fails. This temporary classification is not a performance claim.

Source decision mask:

|Bit|Failure|
|---|---|
|1|Context|
|2|Reduced source cell/head status|
|4|Nonfinite totals|
|8|Off-domain deposited packet|
|16|Ledger packet validity|
|32|Previous stock versus initial aggregate|
|64|Step conservation|
|128|Previous cumulative conservation|
|256|Next cumulative conservation|

Source head mask:

|Bit|Failure|
|---|---|
|1|Head status or original packet identity/validity|
|2|Finite decoded rows|
|4|Physical packet validity|
|8|Impact packet validity|
|16|Impact/decode volume agreement|
|32|Structural zeros|
|64|Birth/pool agreement|
|128|Pool origin|
|256|Pool ownership|
|512|Trail support|
|1024|Incident centre/amounts|
|2048|Incident support|

Cold compilation still yields each frame and retains the same job/resources.
Warmup uses the owner's EXISTING60-second overall bound instead of a separate
20-second cutoff. The live5-second pending/audit bounds and panel70-second bound
remain unchanged. This can continue after a shader becomes ready later than20s;
it does not accelerate compilation or identify the earlier underlying delay.
No live inputs/time are accumulated before accepted warmup.

## Local verification and next action

13 native source/snapshot draws preserve red acceptance on normal, packet,
cell-status and mass-closure controls, and extract the correct first source slot.
15 controlled owner cases include25-second cold-ready and never-ready controls.
Seven actual-adapter panel/menu cases and56 strict CSP-header shader variants pass.
These are local checks, not actual CSP acceptance.

Run the same3-second joint transport once as s275. If it refuses, inspect source
mask/head mask and captured numerical values before asking for another test.
A pass requires nonzero supply, observed/drained state and zero retained debt.
Then remove temporary diagnostics, connect optical consumption and measure the
whole app at2048/4096 heads. No further precision study is scheduled.
