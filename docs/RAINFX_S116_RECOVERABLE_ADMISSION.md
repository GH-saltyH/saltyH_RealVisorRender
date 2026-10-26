# s116 — recoverable admission with one immutable pending call

2026-10-17. **Status: ACTIVE — offline resource-admission recovery.**
Production remains s87 physics with s89 diagnostics. This stage does not install
or connect the s91+ model to CSP.

## 1. What changed

s115 terminated when one graph could not fit its resource limits. s116 retains
one owned call, including its graph, immutable inputs, source/interval labels,
base bundle epoch and unique serial. A retry carries only serial, admission
generation and new limits. It cannot replace the graph or sample new weather.

Admission now plans on copies of cache/free-list metadata. It reserves matching
completed targets, plans evictions and checks all target, immutable-input and
shader limits before changing live ownership or allocating/uploading resources.
Failure leaves the previous caches, free targets and GPU root bundle unchanged.
No physical draw, interval publication or water/time consumption occurs while
pending. Diagnostic root readbacks are separate and still run in these tests.

Limits supplied with a retry are prospective admission constraints. Lowering a
limit below retained storage does not destroy live roots or promise that current
resident bytes immediately satisfy that new limit. Work waits until it can fit.

The implementation remains a drained, single-context D3D11 WARP executor. The
pending graph holds frozen oracle arrays for validation; production would use
owned GPU/input references instead of this fixture transport.

## 2. Command contract

| Operation | Behavior |
|---|---|
| Submit | Accepted only with an empty pending slot, current generation, strictly increasing nonzero serial and matching bundle epoch. Decode/load one graph. |
| Retry | Same pending serial and generation; no replacement body. Re-run admission against the retained graph. |
| New submit while pending | Reject before decoding its body or loading its graph. No queue, overwrite or later-source accumulation. |
| Cancel | Matching serial releases the pending call; published physical state remains. The consumed serial cannot be reused. |
| Reset admission | Release pending work and increment the admission generation. Keep published physical state, caches, bundle epoch and serial high-water mark. |
| Stale generation, serial, identity or epoch | Reject; no candidate publication. |

Reset here deliberately means an **admission-session invalidation**, not a
simulation-clock reset, device recreation or game-session restart. Those need
their own lifecycle contract. Dropped pending work has not consumed source/time;
the upstream owner is responsible for a replacement interval, under a new serial
and current generation. The native runner does not silently advance the clock.

Source and interval labels are frozen diagnostic receipts, not authenticated
content hashes checked by a production API. Actual retained import links,
epochs, dimensions and byte-exact GPU readbacks establish content ownership in
these fixtures. Retry accepts no data capable of changing either receipt.

After complete execution, completion-event drain and verification, all16 root
roles swap together. A physically refused checkpoint is still a valid complete
bundle; its host epoch can advance while the physical controller retains time
debt. Admission failure itself never advances either representation.

## 3. Verified recovery

Nine native schedules execute the same three frozen s114 physical candidates:
checkpoint, two-attempt resume, then a fresh interval. The pending-at-EOF case
intentionally stops after the first published checkpoint.

- Four initial capacity failures: target bytes, immutable-input bytes,
  immutable-input entries and shader entries. Each tolerates repeated refusal,
  then recovers when limits are restored.
- After a committed checkpoint,64 repeated retries and64 newer submissions
  leave the same pending graph, roots, caches and epoch intact. New bodies are
  deliberately malformed to prove that busy rejection occurs before decoding.
- Wrong retry/cancel identities, old generations, duplicate consumed serials,
  stale bundle epochs, pending cancellation and admission reset are exercised.
- Cancel/reset before the first GPU bundle also recover. An unfinished pending
  call can remain at EOF without partial publication.
- A separate malformed retry carrying a replacement body fails closed. Its
  previously published checkpoint is read back unchanged in the failure path.

Every completed output/import/incoming root matches its frozen physical oracle.
The eight complete schedules finish with byte-identical public/private/cache
roots, including ledger, clock/control and source snapshot arrays. Waiting does
not change the number of physical calls, draws or region copies.

| Evidence across the nine schedules | Count |
|---|---:|
| Commands | 190 |
| Pending admission results | 86 |
| Protocol rejections | 75 |
| Completed physical calls | 25 |
| Physical shader draws / region copies | 2117 / 695 |
| Output/import/incoming-root comparisons | 3980 |
| Additional per-command root comparisons | 2688 |
| D3D debug warnings/errors | 0 |

The separate malformed replacement-body guard adds one checkpoint execution;
it is excluded from this table. Eight schedules publish three bundles each;
the pending-at-EOF schedule publishes one. Bundle epoch3 is not a claim of three
accepted physical intervals, since the first bundle is a refused checkpoint.

These are recovery/control schedules over a small8×32 source/pool fixture, not
new continuous weather calibration. The unchanged shaders retain the previous
accuracy limits. The nominal200000 target-byte,65536 input-byte/24-entry and
64-shader limits are fixture budgets, not game defaults or VRAM/RSS bounds.

## 4. Audit and limits

MSVC `/W4 /WX` and the actual WARP debug layer pass without warnings. Existing
compiled physical shaders are copied byte for byte; no shader source changed.
An independent binary command/graph decoder reconstructs every admission plan,
cache/free-list decision, retained root, epoch and pending receipt. Its symbolic
ownership/counter replay matches native statistics. Final GPU roots are also
compared against uninterrupted execution through their exact oracle hashes.

Statistics append to JSONL files. One pending graph and bounded current roots/
caches survive between actions; no native action-history vector is retained.
Oracle generation and independent audit may load aggregate evidence on the CPU.
Per-action root verification adds diagnostic staging copies and drains. No claim
of GPU speedup, measured memory improvement or CSP asynchronous safety follows.

Runtime Lua/HLSL, settings/material INIs, published assets and s91–s115 work are
preserved. No game install, reload/log request, commit or push.

## 5. Next implementation

Separate GPU submission from completion/publication with one bounded in-flight
candidate. Prove that targets cannot be reused and roots cannot publish before
completion, including cancel/reset around that boundary. This is needed before
connecting a live CSP adapter. Economical physical accuracy, full head/source
lifecycle, convergence, device recovery and target GPU timing remain open.

## 6. Reproduce

```text
docs/tools/check_s116_pending.py
docs/tools/finalize_s116.py
```

Executor: `docs/tools/s116_pending_stream.cpp`. Build/fixture helper:
`docs/tools/s116_pending_reference.py`. Native JSON/JSONL results, compressed
fixtures, shader/build hashes, independent audit and preserved baseline:
`docs/diagnostics/2026-10-17/s116/`.
