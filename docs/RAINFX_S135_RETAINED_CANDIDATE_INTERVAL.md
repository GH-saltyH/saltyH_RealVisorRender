# s135 — retained candidate interval composition

Date: 2026-10-18
Status: ACTIVE

## 1. Implementation and limits

Connect the exact s133 mass+face candidate to the existing s124 interval queue
and s125 managed-pass bridge through a new Lua owner. This is an uninstalled
prototype for the two frozen curved fixtures (YX and sparse XY), not a live
RainFX solver, arbitrary-input numerical admission or general CSP completion proof.
Production stays s87 physics / s89 diagnostics; settings and prior sources stay
unchanged. No additional game test is requested at this stage.

`s135_interval_candidate.lua` imports the frozen s133 recipes and selected source
export. Both map bodies must match byte-for-byte before binding. Only the public
root bundle changes: logical/bank final End+Mean stock banks and each branch's
two axis loss totals. Seed bodies, pass order, dependencies, uniforms, cache keys,
axis dt and all transport consumers remain identical to the selected recipe.

`s135_retained_interval.lua` owns the accepted binding, queue token, bridge,
accepted command prefix and unpublished root bundle. The producer's tables and
returned metadata are copied. At most one bridge exists at a time. The default
owner admits at most two records, including a published root still awaiting
release or an old-generation flight held after reset.

## 2. Input identity and trust boundary

Each fixed catalogue entry binds:

- The exact selected prototype SHA256, whole recipe and typed packet identities.
- Four s134 offline input receipts (two axes, logical/bank) and their parent
  delivery identity. These are provenance records, not runtime permission.
- Source, geometry, pose and settings keys; the immutable geometry includes
  the captured metric and sparse runs.
- A 1,024-tick interval at 16,384 ticks/s, matching the fixed 0.0625-second
  transport dt. The two axis sweeps do not count as two elapsed intervals.
- The six expected output roots and their combined frozen WARP output identity.

This stage replays existing stocks. Incoming supply is exactly zero, and no birth
stage is present. Queue supply accounting stays zero; it does not prove nonzero
water injection through this composition. Forcing is copied as queue provenance
but the fixed seed does not consume a live weather snapshot. Repeated intervals
restart from the frozen seed, so they are lifecycle tests, not recurrent physics.

Input and result verifiers are explicit **trusted offline seams**. The supplied
test verifier compares against its private frozen catalogue; no SHA implementation,
new CSP API or per-frame CPU field readback is added to the Lua owner. A result
must match the current token and expected root output identity. The test backend
also checks that every accepted request used the exact shader, typed values and
already-produced, live dependencies in the current allocation cycle. None of
this turns s134's conditional enclosure into a generic runtime admission check.

## 3. Submission, publication and retirement

1. Offer validates identity and capacity before adding queue work. A paused,
   mismatched or over-capacity request does not allocate canvases.
2. Prepare requires explicit offline replay, ordered execution and a trusted
   physical-completion capability. Defaults refuse. Allocation failure cleans
   allocated canvases and leaves the queue interval retryable.
3. Pump retains the exact accepted prefix across shader-pending returns. Only
   accepted calls advance it. An exception or non-boolean return marks unknown
   submission and retains resources until trusted completion.
4. Finish refuses an incomplete graph, missing completion or result verifier,
   changed result, cancelled flight and stale token. Only after these checks
   does it publish all six roots and advance the queue clock/epoch together.
   Backend calls and verifiers must obey their documented trusted contracts;
   this is serialized host publication, not a cross-thread atomic primitive.
5. Published roots remain owned until explicit release. Repeated finish does not
   advance time; cancel cannot silently undo a published interval. Completion
   is monotonic: a later pending/failure report cannot revoke a completed root.
6. Cancel/reset before submission disposes the graph immediately. Afterwards,
   they retain it until completion and discard it without new publication.
   Reset invalidates old tokens for future publication while retaining the
   cancelled flight's resource lease. Retry uses a new queue token.

The owner never infers physical completion from accepted shader calls, ordered
submission, a frame delay or a readback callback. Existing CSP capability defaults
remain unchanged. In these tests completion is deliberately mocked. Root handles
are not exported to game rendering; public metadata names the retained bundle.

## 4. Verification

Run `docs/tools/check_s135_interval.py` with the bundled Python runtime.

- **64 actual WARP draws / 12 strict synthetic shader bodies** execute both
  32-pass graphs. All 28 selected output fields match the frozen s133 WARP
  controls bit-for-bit, including final stock/loss outputs and explicit copies.
  Actual s133 CSP evidence remains unchanged; this is not a new CSP observation.
- **17 lifecycle cases** cover accepted-prefix pending/resume, producer/returned
  metadata mutation, capacity, premature completion/publication, stale result
  receipts, duplicate finish, explicit root release, cancel/reset before and
  after submission, reset after publication, failed/unknown submission, missing
  capabilities/verifiers and allocation-failure retry.
- **12 binding guards** reject changed prototype, s134 receipt, packet, recipe,
  unsupported admission claim, fixture, source/pose/geometry/settings identity,
  interval duration and incoming supply before queue acceptance/allocation.
- A 16-interval fixed replay releases each graph before the next allocation.
  It commits 16,384 protocol ticks, retains no graph after release, and peaks at
  **32 instrumented canvases**. This checks bounded ownership in the test backend;
  it is not a measured GPU-memory plateau, allocator reuse or game leak test.

WARP numerical execution and lifecycle replay are distinct. Lifecycle replay
returns cached WARP outputs after checking every submitted descriptor/dependency;
it does not execute persistent GPU textures under each cancellation schedule.
Completion notifications are synthetic. No FPS/GPU-time/CPU-time improvement or
actual CSP resource retirement is established. Existing exact affine criteria,
curved counterexamples and conditional roundoff scopes remain unchanged.

Full action traces, catalogue identities, compile hashes and verification reports
are under `docs/diagnostics/2026-10-18/s135/`. A Lupa conversion issue with repeated
Python dict references is isolated in the harness by JSON tree normalization;
it does not change the Lua queue or shader numerical semantics.

## 5. Next implementation

Replace the fixed seed with an owned source-provider contract for End/Mean,
metric/runs and interval headers, then test exact source handoff and stale-input
refusal. Actual CSP prefix execution needs its own observation, and retirement
must continue to refuse without a completion contract covering all submitted
uses. General runtime admission, recurrent force/remap accuracy, shared head/film
optics and actual target-machine cost remain adoption gates.
