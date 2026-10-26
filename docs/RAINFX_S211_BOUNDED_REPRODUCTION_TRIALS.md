# s211: bounded fresh-process reproduction trials and first-refusal stop

2026-10-21. Parent s210. Status: ACTIVE. Offline native D3D11, RTX 3070.

## Result

A bounded runner now executes the original frame-7/frame-8 window in independent
processes and stops immediately at the first failed trial. Four natural trials
each publish the same nine intervals. Their complete final eight-bank proofs
match, all 21 targeted witnesses pass, and saved GPU/stock/source/recovery bytes
match the corresponding prefix of the validated full hardware run.

A controlled batch requests three trials: clean prefix, GPU-value fault, clean
prefix. It executes the first two, preserves the second trial's first divergent
witness and complete raw fault payload, and does not create/start trial 3.
The deliberately injected fault is not the original natural s208 failure.

The non-prefix consumer also retains complete 256-interval parent parity and the
original 26-published/29-accepted forced-stop gate. The natural s208 discrepancy
does not recur and is not declared repaired or qualified away.

## Prefix frontier and debt semantics

The prefix executable processes through frame 8 and publishes nine intervals.
The existing bounded admission queue has already accepted 12 intervals. At the
administrative cutoff, the three contexts `[9, 10, 11]` have not started. They
remain queued; they are not dropped, processed or counted as published time.

| Frontier field | Value |
| --- | ---: |
| Requested diagnostic prefix / published intervals | 9 / 9 |
| Accepted intervals | 12 |
| Published simulation time | 0.15189456939697266 s |
| Accepted time | 0.20252609252929688 s |
| Active physical debt | 0 |
| Unstarted queued debt | 0.050631523132324219 s |
| Next phase / cache context / cache lease | 153 / 9 / 10 |
| Cache publications | 8 |

Before freezing, the older generic owner trace reserves the queue front in its
active-debt bucket. The explicit administrative frontier reclassifies that
unstarted front with the other two queued intervals. Total debt and both clocks
are unchanged. No active solver cursor, pending work, readers or cache candidate
may remain at this cutoff.

The cutoff freezes physical reservation, bank/cache publication and admission.
The runner attempts these operations and checks that bank references, clocks,
allocations and retirement counts remain unchanged. It then saves the complete
published bank proof and retires all counted textures. This is a terminal native
diagnostic capture, not a live pause/resume implementation. Queued debt remains
recorded as unprocessed; this stage does not resume those contexts after teardown.

The legacy native report still states that its full requested workload is 256
intervals and correctly leaves that gate false for a nine-interval trial. The
separate `run.witness210.prefix211.json` reports the nine-interval diagnostic
request and its frontier explicitly. Administrative cutoff is not solver
quarantine, a numerical refusal or a successful 256-interval run.

## Repeated observations and scope

Each prefix trial starts a fresh process, device/owner and frozen initial bank.
It consumes a new executable-bound receipt for the unchanged qualified inputs,
shader files, adapter and driver. A batch manifest is saved before execution and
records the requested variants, maximum trials, immutable window/reference
hashes, each launch's executable/binding hashes, outcome and first refusal.
Saved batches/trials are not overwritten or automatically retried.

The runner accepts at most eight planned trials; this natural batch requests four.
Its four independent nine-interval prefixes publish 36 intervals in total. This
is not 36 consecutive intervals, an advancing replay, a warm long run or a
statistical reliability qualification. Startup still validates the complete
frozen program/window schema; this is not a minimal-loader or startup-cost fix.

Each successful prefix executes 2,260 total draws and 246 completion events,
including bootstrap/final proof. All 36 targeted diagnostic copies use existing
phase/stock events. The administrative final proof occurs at the earlier
stable bank rather than at the full-run end. The original full and forced-stop
event counts remain 7,085 and 725.

Each prefix's 416 typed inventory snapshots account for 266 created/released
generations and 288,445,088 cumulative default-texture bytes. Its scoped peak
is 66,582,496 B under the 66,584,576 B cap, with zero counted default textures at
teardown. Cumulative allocations are not peak memory; staging/query/CPU overhead
is not included in that default-texture cap.

## Independent saved-evidence checks

- Exact original owner trace prefix up to the administrative cutoff, with
  accepted = published + active + queued time checked for every saved row.
- Exact first-nine stock/phase/recovery/cache traces and complete saved GPU audit
  and compact stock-packet byte prefixes of the validated full run.
- Full water/momentum ledger balance and unchanged index/provenance data.
- Every typed inventory occupant, shape, reclamation and final zero-byte state;
  process-local diagnostic IDs are normalized only for cross-run comparisons.
- Identical complete final bank proofs across the four natural trials and the
  successful control-batch prefix. These repeated proofs establish repeat parity,
  not a new independent physical-accuracy oracle at frame 8.
- All 21 targeted witness rows match s210, with their existing measurement scopes.
- Original complete 256-interval GPU/state/stock/time parity and the 26/29 stop
  are retained with the prefix switch disabled.

The full and budget-stop process lifetimes overlap by 29.7134 s. They use separate
private contexts and output paths with immutable shared input files. GPU command
overlap is not isolated. This stage makes no isolated timing comparison, GPU busy
claim, speedup or game FPS claim; the audit retains that overlap explicitly.

## Controlled first refusal

In the second trial of the controlled batch, a known one-bit retained-GPU metric
change is injected between the before/after copies at frame 7, phase 1875. The
first affected witness reports `afterMatchesFrozen=false`; earlier witnesses
pass and CPU expected/reference bytes stay unchanged. The seven prior stock
publications match the parent and accepted-time debt remains protected.

The manifest records native reason `retained metric witness mismatch`, the first
divergent row and SHA/size of the raw fault artifact. The checker reads this
trial's actual capture, verifies the one-bit discrepancy and verifies that the
scheduled third trial directory does not exist. An aborted trial has no successful
final bank/teardown report; no such success is inferred.

The bounded runner also stops on other nonzero native exits without discarding
the logs or silently retrying. A failure without a metric capture is not labelled
as an explained cache fault. The positive controlled case validates batch halt
and artifact retention only, not the original intermittent cause.

## Next implementation and unresolved gates

The reproduction/capture tool is now available for the first natural discrepancy.
The finite successful trials do not resolve s208 or qualify release recurrence.
Keep that issue open and preserve the exact guards.

The measured completion oversleep can be characterized independently on an
immutable private command stream, including host wall and process CPU cost.
That would be a separate, non-adopted performance experiment, with the existing
completion predicate and no global timer changes. It must not be presented as
the cache repair or release qualification. Any later candidate adoption still
needs full/prefix/stop state, stock, debt, retention and witness gates.

Physical/time accuracy, total CPU/startup streaming, long duration, common
head/film optics and actual CSP scheduling/completion/live adoption remain open.
Production remains s87 and diagnostics s89/s152–s154. Older source SHA/mtime,
main Lua, settings, assets and game installation are preserved. No commit or push;
no user game action is required for this offline step.

Evidence: `docs/diagnostics/2026-10-21/s211/`; tools in `docs/tools/`:
`build_s211_trials.py`, `run_s211_trials.py`, `check_s211_trials.py`,
`finalize_s211.py`, `s211_cutoff.inc`, `s211_owner.inc`, `s211_physical.cpp`.
