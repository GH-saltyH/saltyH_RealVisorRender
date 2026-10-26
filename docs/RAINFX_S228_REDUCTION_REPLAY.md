# s228 — immutable compensated-reduction replay (2026-10-22)

## Result and scope

Six fresh native GPU processes pass32 repetitions each: **192 small reduction
repetitions and384 bit-exact output comparisons** against the ordered FP32 CPU
oracle. Both original completion policies pass captured, cancellation and
invalid-packet fixtures. Input bytes match before and after each healthy loop.
Two altered SHA receipts refuse before GPU-owner construction; two injected
output-bit faults stop at the first iteration with the expected saved difference.

The two final reductions are reproducible for these fixed inputs on the admitted
adapter/driver. **The original s223 discrepancy remains unexplained.** This does
not recover its missing inputs or qualify the full upstream graph, resource
reuse, general determinism, performance or live CSP integration. The separate
s208 retained-metric discrepancy also remains unresolved.

## Inputs, shaders and independent expectations

| Output | Immutable input from s227 | Original physical CSO | Operation |
| --- | --- | --- | --- |
| 1, donor1402 | Exchange1401, 4×4 RGBA32F | physical_222fc049fe79af734ae2 | Two banks, each4×2 values; compensated sum with invalid-packet guard |
| 2, recipient1420 | Ledger1419, 4×16 RGBA32F | physical_eb501912947a257fb0c0 | Eight banks, each4×2 values; compensated sum |

The two original physical CSOs are reused without recompiling their sources.
The existing native helper still creates its ordinary vertex shader. Each
process's receipt binds input/expected/executable/CSO hashes and the qualified
adapter/LUID/driver. The saved audit independently reconstructs and compares the
receipt bytes. It does not treat a diagnostic alias hash as input authority.

The three fixtures are:

- **Captured:** exact s227 parent textures. CPU outputs must also match the
  actual donor1402/recipient1420 captured by s227.
- **Cancellation:** every bank has the ordered sequence
  `[100000, .1, .1, .1, .1, .1, .1, -100000]`, with distinct power-of-two bank
  scales and signed component scales. The compensated result differs from a
  plain FP32 sum in all10 banks. Known results are explicitly checked, including
  the base component result0.6015625; mathematical real-number0.6 is not used as
  the exact FP32 expectation.
- **Invalid packet:** the cancellation fixture with the red invalid marker set
  in one donor-bank input. That bank returns `[1,0,0,0]`; the other donor bank and
  every recipient bank retain their prior expected bits.

The CPU oracle mirrors the shader's y-then-x traversal and rounds each
subtraction/addition separately to FP32, including compensation updates. It
does not replace the shader with a double-precision or reordered sum. Input
extents, channel counts and finite values are admitted explicitly. Nonfinite
inputs, overflow, arbitrary extents, subnormal handling and every invalid-data
branch are not qualified by these fixtures.

## Repetition and negative controls

Each healthy process clears both outputs to a canary before each pair of draws,
copies both outputs, waits for the original completion predicate and checks all
bytes. Across32 repetitions that is64 draws,64 canary clears and34 completion
events, including pre/post immutable-input snapshots. These are small arithmetic
repetitions, not physical solver intervals. No stock or solver clock is published.

Each negative control has its own receipt path and fresh process:

- Altered input SHA and altered shader SHA are rejected with zero started GPU
  completion events and no GPU-owner dump.
- Donor output1 word1 and recipient output2 word17 are independently XORed with1
  after both draws. Each control records exactly that single changed word,
  preserves the other output and stops at iteration0 after two completed groups
  (immutable input check plus the faulty output group).

The latter controls prove this private replay's first-mismatch stop. They do not
prove an in-solver water rollback, live CSP quarantine, or an actual device-loss
or timeout response. No failed native observation is retried, and no numerical
tolerance is introduced. Strict `/W4 /WX /O2 /fp:strict` builds and all planned
processes complete without a correction/relaunch.

## Resource and performance limits

Logical default-texture payload is1952 bytes:1280 input bytes,160 output bytes
and512 bytes of unused fixed helper targets. Peak staging payload is1280 bytes,
from the immutable-input snapshots. Default payload is checked under a4096-byte
local cap. Driver allocation/row-pitch overhead, buffers, shader/query objects
and other allocations are excluded, so these numbers are not total VRAM.

The event signal remains a wakeup; the original GetData completion predicate
authorizes readback. Source owners and staging resources remain retained through
their completion/read. This experiment does not qualify a general CSP fence.
Recorded timing metadata is not used for a performance comparison or policy
adoption. Full physical accuracy, complete resource cost and game FPS are not
measured here.

## Next implementation

s224–s228 have now checked the observed terminal/copy/combine chain, its
producer-to-consumer gap and the two final reductions. No observed relation
currently identifies the original s223 cause. Do not keep repeating identical
prefixes or extend toy replays indefinitely to obtain a passing sample.

Next prepare a bounded resumption of the exclusive CPU-partition experiment:
review the scope-only changes against the last passed s222 path, retain the
original exact intermediate/bank/stock/clock/debt/cap criterion and stop at its
first refusal with complete failure evidence. A passing local replay is not
that full-pipeline admission. Keep the s223 failure and release block explicit;
do not waive it based on the small numerical magnitude or call the cause fixed.
No broader CPU bottleneck conclusion is available yet.

s222 remains the last passed cost comparison. Event-policy release, physical
time/accuracy, unified head/film optics, CSP ownership/completion and long warm
runs remain open. Game physics remains s87; no user game test is needed.

## Evidence and delivery

Artifacts: `docs/diagnostics/2026-10-22/s228/`. Fixture/source hashes, receipt
bytes, per-process full dumps, mismatch reports and completion statistics are
retained. `check_s228_reduction.py` verifies saved bytes, independent fixture
regeneration, known cancellation checks, all four negative controls, process
order, prior file preservation and the delivery seal without a new GPU run.

No main-app/settings edit, game installation, commit or push.
