# s210: retained metric, CPU reference and shared-selection witnesses

2026-10-21. Parent s209. Status: ACTIVE. Offline native D3D11, RTX 3070.

## Result

The missing frame-7/frame-8 interval now has bounded observations at the frame-7
cache validation, before/after all 17 physical executions and the stock check,
frame-8 CPU configuration and frame-8 cache validation: **21 trace rows**.

The natural release run completes all 256 intervals and matches the s207 parent
in complete saved GPU bytes, final bank proof, stock packets, water/time results,
source/recovery/publication traces and 11,850 typed inventory snapshots after
normalizing process-local diagnostic identities. All 21 witnesses agree with
their immutable references. The debug forced stop retains the original 26
published / 29 accepted intervals, protected prior bank and exact time debt.

The original s208 failure does not recur here and is not declared resolved.
Three deliberate controls prove the new witnesses locate CPU expected-value,
retained GPU-value and CPU shared-selection changes at their first affected row.
They do not reproduce or explain the original failure.

## Observation sequence and meaning

| Point | Observed data | Count |
| --- | --- | ---: |
| Frame 7 cache validation | Existing full metric result against frozen reference; live CPU references/expected value | 1 |
| Frame 7 physical executions | Full GPU metric copy before and after each execution; CPU references/expected value at completion | 17 pairs |
| Frame 7 stock check | Full GPU metric copy before and after stock work; CPU references/expected value at completion | 1 pair |
| Frame 8 configuration | Accepted frame-7 header against live CPU header; independently recomputed pose-sharing decision; CPU references/expected value | 1 |
| Frame 8 cache validation | Existing full metric result against frozen reference; live CPU references/expected value | 1 |

The expected reference selector is recorded explicitly. It is 0 in this frozen
window. Both live reference vectors are compared in full bytes with separately
copied, qualified immutable reference payloads; the current CPU expected vector
is also compared with the selected frozen payload. These are content/logical
identity checks, not a proof of arbitrary pointer or external-writer identity.

The configuration witness retains the actual header that passed frame-7 GPU
validation. It checks that the live CPU accepted header still contains those
bytes, then recomputes the pose-sharing decision from that header and the incoming
context rather than trusting `sharedMetric`. In the successful replay, frame 7
rebuilds its metric and frame 8 shares it, as predicted in s209.

Trace flags are scoped by row kind: GPU before/after fields are actual pairs in
`phase`/`stock` rows and existing validated results in `cache_validated` rows.
Header stability and the sharing decision are measured in `configure` rows only.
Other rows keep those non-applicable guard fields true; they must not be counted
as separate header/sharing measurements. CPU reference/expected checks apply to
every row. The saved audit records these scopes explicitly.

## Completion and resource accounting

The 36 extra 8 MiB copies (301,989,888 B cumulative payload) are ordered before
the **existing** physical/stock completion event. Their reads occur after that
event is observed. No new completion event, wait call, flush, solver draw or
shader is introduced on the normal path. Full/stop event counts remain
7,085 / 725, and the fixed timestamp observer remains 257 query objects under
its 128-pair capacity. Legacy mandatory read purposes/counts/bytes are unchanged;
new reads use the separate `retained_metric_witness` timing category.

Only the frame-7 executions/stock use paired GPU copies. Frame-8 configuration
uses CPU comparisons and cache validation reuses existing read results. The
collector caps trace rows at 96 and copies at 128; this frozen case uses 21/36.
It retains 16 MiB of extra frozen CPU reference payload, at most a 16 MiB GPU
staging pair and a 16 MiB CPU read-result pair, plus the small accepted header
and trace state. These scoped payload bounds do not establish total process
RAM or application VRAM usage. The default-texture cap excludes staging/query
resources. The original scoped default peak remains 66,582,496 B and all counted
default textures retire in successful runs.

Additional copies/reads and CPU reference comparisons perturb timing and memory
layout. No game FPS, performance improvement or absence-of-races inference is
made from the successful instrumented run. Production wait policy is unchanged.

## First-divergence controls

All controls use separate executable-bound receipts and isolated native processes.
The normal executable compiles them out. The original equality predicates and
tolerances remain intact; a new diagnostic tripwire writes full evidence and
stops on the first witness discrepancy before further bank publication.

| Synthetic change | First affected witness | Failed field | Protected published prefix |
| --- | --- | --- | ---: |
| Flip word-0 bit-0 of CPU `metricExpected` at first frame-7 execution | `phase`, frame 7, phase 1875 | `cpuExpectedMatchesFrozen` | 7 intervals |
| Upload the same bit change to the retained GPU metric between that execution's before/after copies | `phase`, frame 7, phase 1875 | `afterMatchesFrozen` | 7 intervals |
| Invert CPU `sharedMetric` after frame-8 configuration | `configure`, frame 8 | `shareDecisionMatchesPose` | 8 intervals |

The independent checker requires all preceding witnesses to pass, exact one-bit
differences for value controls, unchanged live/frozen reference payloads, the
proper captured row/kind and the original stock prefix. Accepted-time closure
holds and the failing frame's bank is not published. The sharing control stops
before reserving/drawing a frame-8 cache candidate. Aborted controls do not have
a successful final bank/teardown report; no such success is inferred.

The fault file contains frame/phase/selector/sharing/MXCSR and complete before,
after, frozen/live reference and current expected payloads. These observations
localize a detected change to a phase boundary. They do not alone identify the
responsible instruction or distinguish every possible CPU/driver/GPU cause.
The validated s209 v2 refusal collector is also retained for original cache
guard failures outside the targeted window.

## Next work and limits

Use this instrumentation in a bounded repeated target-window reproduction
harness, retaining each trial's reference/lease provenance, previous bank/debt
and first divergent observation. A natural discrepancy is still needed before
naming a root cause, choosing a repair or qualifying release recurrence. Finite
successful trials must not replace that missing evidence or erase s208's refusal.

Physical/time accuracy, total CPU/startup streaming, long warm runs, common
head/film optics and CSP callback/completion/live adoption remain open. Main
physics remains s87 and diagnostics s89/s152–s154. Main Lua, settings, assets,
game installation and older source SHA/mtime are preserved. No commit or push;
no user game action is needed for this offline step.

Evidence: `docs/diagnostics/2026-10-21/s210/`; tools in `docs/tools/`:
`build_s210_witness.py`, `run_s210_witness.py`, `check_s210_witness.py`,
`finalize_s210.py` and the generated/companion `s210_*.cpp`/`s210_*.inc`.
