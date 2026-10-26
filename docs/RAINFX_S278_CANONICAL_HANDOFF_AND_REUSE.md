# s278: canonical old inventory and bounded recipe reuse

## Two actual s277 outcomes, different failure boundaries

First session (user UI report; raw GPU log replaced on restart): accepted prefix
through36, then serial37 refused. Submitted/audited38, advanced0.674663s,
debt0.212800s, incident9.987599mm3. Reason7/context0/head0; source mask322,
aggregate status2; source head2/mask1/slot1538. The old UI label `cell status`
was imprecise: this reduced status covers both cells and source heads.
Mask322=2+64+256; per-head contract failure can cause both conservation failures
by clearing the failed head's source outputs. The earlier tail bit8 is absent.

Second session (actual raw log collected): entry_capacity before incident water,
17 submitted/audited, advanced0.333517075s, debt0.100900650s.23 admitted frames,
seven-frame maximum submit lag. maxBindMS3.5504, maxPacketMS0.1206, maxPumpMS5.1172.
Crucially liveRetries0, warmupRetries76. There is no evidence of live shader
compilation blocking this second run.10-frame audit latency, median155.74ms,
leaves only six entries of the unchanged16-entry FIFO for dispatch lag.

These stops do not constitute a controlled cold-versus-warm numerical mismatch.
One run reaches source validation; the other overloads sooner. Actual inputs,
frame timing and the first log cannot be compared bitwise. Keep both results,
resolve the source contract and CPU construction separately, and do not attribute
both failures to CSP shader caches. Neither run passes the three-second gate.

## Canonical physical handoff

Source head mask1 groups decoded head status, old packet validity and exact
identity against stored original inventory. Upstream head0 passes. Actual numeric
old/recomputed packets from the first run are unavailable, so exact floating point
attribution remains unproven. However, recomputing already stored world momentum
from UV state/pose is an unnecessary second numerical authority.

Ownership now consumes the previous accepted physical-head bank directly for
its original packet. It still validates raw metadata/state, supported geometry,
basis, finite packet, exact volume equality with metadata and zero momentum at
zero volume. Decoder already consumes ownership row5. Source's exact original
packet check remains unchanged: a point-loaded canonical packet is copied
through ownership and decoding, without reintroducing pose arithmetic.

Raw UV state, SI force/trace, birth, radius/display, and volume debit laws remain
unchanged. Existing residual impulse accounts for world momentum relative to the
retained stock. The owned private graph requires its existing empty merge command;
merge and pool return remain OFF. This is not a general external/merged producer.
Ownership gains one input (12 total); maximum graph binding count stays14.
No new canvas, draw, readback, queue entry or shader tolerance is added.

## Retained recipes for CPU throughput

The private executor permits only one active submission and releases its CPU
recipe after its audit draw is accepted. Accepted SDK draws copy values with
`directValuesExchange=false`; owned GPU handles remain retained. Therefore fixed
recipe topology can be borrowed again after submission, while older receipt
callbacks wait. A returned cached recipe is owned by the graph and valid only
until the next bind; it is not an immutable public result for concurrent callers.

Cache by transport substep count(4/8/16), first interval, or A/B parity: at most
nine CPU templates. Cold/missing variants build via the unchanged full binder.
Hits repeat cohort/token/dt/calibration validation and certify every private/file
lease; replace the52 context uniforms and only explicit dt/serial/token fields.
The flow receipt's gHasPrior remains its original constant, distinct from the
joint receipt. First/reset initialization remains a separate variant.

All queue limits stay unchanged. Preparation is still subject to the existing
soft budget, and initial cache misses remain atomic. Actual CSP throughput still
requires verification; do not infer FPS from a local LuaJIT test.

## Local evidence

-Nine native GPU draws over4096 slots: unchanged output when canonical and
 recomputed packets match; controlled1ULP difference preserves canonical packet
 exactly and passes the actual source consumer. Wrong volume and zero-volume
 momentum still refuse. The actual first-session payload was not reproduced.
-25 recipe comparisons,2865 draw descriptors, including all substep counts,
 parity and reset: cached and freshly bound s278 recipes exactly match. Wrong
 file lease, nonfinite context and altered calibration still refuse.
-32 local CPU-only pairs: fresh median about0.594ms, cached about0.050ms. These
 are local LuaJIT preparation timings, not CSP GPU or whole-app performance.
-16 controlled owner cases, seven real-adapter panel/menu cases,56 strict
 CSP-header shader variants. Resource count stays128; owned bytes139151152.

Existing log adds templateHits/templateBuilds beside bind/packet/live-retry cost.
UI now calls the combined reduction `aggregate status`; legacy cellStatus log
field is retained so earlier collectors remain compatible.

## Next and limits

Run the same three-second integrated s278 once in a fresh unpaused rainy session,
other diagnostics OFF. Need observed/drained, nonzero incident, zero debt. Do not
request an additional cold/warm matrix: the existing liveRetries and template
counters cover readiness/construction. Inspect the same retained source details
if rejected. After acceptance remove temporary capture, connect optics, then
measure whole-app2048/4096 performance and visual continuity.
