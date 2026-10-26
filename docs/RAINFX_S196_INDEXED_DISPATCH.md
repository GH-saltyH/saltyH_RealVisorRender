# s196: immutable indexes for native physical dispatch

2026-10-20. Parent s195. Offline native D3D11 WARP/debug backend.

## Result

The counted adaptive owner now indexes upload events, required phase backings
and transport roles once, instead of repeatedly scanning the entire unrolled
graph during execution. The same64 intervals pass. All1,457,304,640 bytes of
retained cold/physical/cache GPU readbacks match s195 bit for bit, as do every
published stock/ledger/checkpoint, owner transition and adaptive recovery record.
Physical operators, weather/source inputs, timestep policy and shaders are unchanged.

This prioritizes recurring CPU dispatch work found while preparing longer tests.
It does not extend simulated duration beyond1.08013916015625s or establish a
target-hardware timing result. The larger continuous recurrence test remains open.

## Implementation and reference checks

- `uploads[tick]` contains only imported packet IDs born at that event. Membership
  uses the physical input packet, including the GPU-derived initial head inventory
  distinction, rather than inferring uploads from producer fields.
- Each phase indexes required physical backings and whether a backing must
  already exist because an older logical input spans the phase. Missing live
  inputs still refuse; the optimization does not authorize resurrection.
- Each flow phase caches its eight film/history/checkpoint/request/output roles.
  Context refresh, capacity preflight, reader protection and adaptive carry are
  unchanged.
- Saved native indexes are checked against an independent exhaustive reconstruction
  for all1088 phases and448 upload-event keys. Aliased backing requirements combine
  with logical OR:one old input is enough to forbid recreating a missing backing.

## Work measurements

| Execution work | Prior exhaustive predicate count avoided | Indexed work observed |
| --- | ---: | ---: |
| Upload resource scan | 284,189,780 | 17,668 lookups;1,119 candidate inputs |
| Phase reservation resource scan | 35,000,960 | 2,176 lookups;87,040 candidate backings |
| Flow detection | Not timed/count-compared | 1,088 cached lookups |
| Transport role discovery | Not timed/count-compared | 256 cached lookups |

Avoided counts reconstruct exactly the old loop bounds at each corresponding
execution point; the old version was not rerun as a paired timing benchmark.
These are different operation kinds and must not be reported as a speedup ratio.

Measured on this host/debug executable: index construction57.1034ms; cumulative
timed upload/phase lookup regions10.1561ms. Lookup timing includes clock-call
overhead and excludes candidate processing, D3D submission, uploads, allocation,
waiting and readback. The diagnostic native execution took43.3364s wall time,
including WARP computation, debug checks, synchronous reads and file output.
None of these values estimates game FPS, target GPU time or callback latency.

Construction still scans the preloaded phase/resource graph once. Index metadata
scales with that unrolled graph; bounded CPU streaming is not established.
Loader validation, metadata retention and GPU allocation churn still need work.

## Physical and ownership gates

- All64 banks and exact solver time publish;265 adaptive attempts include3
  refusals and262 accepted substeps. Maximum adaptive native pump draw count49.
- Per-frame complete GPU stock sums retain their water/momentum ledger bounds.
  Every quarter consumes its exact tick debt; no incident source is repeated.
- Default-texture peak stays66,577,136B(63.492905MiB);final owned textures0B.
  Creation/retirement/cache-release counts and cumulative allocation bytes are
  identical to s195. This optimization does not reduce GPU memory/churn.
- Dynamic ownership snapshots independently reconcile every created/released
  physical generation. The s195 forced-budget control remains preserved evidence;
  it is not represented as a newly executed control in this stage.
- Strict native compilation and D3D debug checks pass with no warnings.

## Evidence and next work

Evidence: `diagnostics/2026-10-20/s196/run.index.jsonl`, `run.index_cost.json`,
`index_audit.json`, `index_checks.json`, native traces and complete readbacks.
The finalizer verifies saved evidence without GPU reruns.

Next remove the dependence on a preloaded unrolled graph with bounded reusable
input/dispatch templates, then increase continuous recurrence duration and assess
allocation churn. Target CPU/GPU measurements must separate diagnostic reads.
Actual CSP inputs/completion/callback scheduling and common optics/live adoption
remain open. Production remains s87 with diagnostics s89. Main/settings/production
shaders/assets and installed game files are preserved;no user game test or commit.
