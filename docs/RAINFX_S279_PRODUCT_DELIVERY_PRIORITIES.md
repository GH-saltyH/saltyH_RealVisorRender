# RainFX product delivery priorities: s279 decision

2026-10-24. This decision implements the user's instruction to stop repeated
same-boundary experiments and allocate effort by impact on final RainFX.
It supersedes the requirement in s269-s278 to pass an exact three-second private
probe before any optical integration. It does NOT mark those stopped runs passed,
waive overload, change the existing model's physical thresholds or authorize a
release of an unstable runtime. Prior records and shaders stay intact.

## Evidence sufficient for the next implementation

Actual s278 accepted148 consecutive intervals through2.631315s with nonzero
incident143.763763mm3, stock55.604347mm3 and exits88.159363mm3. Last receipt closure
is -0.000053406mm3, about0.00003715% of incident. No source refusal occurred in
this prefix; canonical handoff has substantially better integration evidence.
This is not proof of arbitrary long-run numerical/physical/visual correctness.

It then stopped at entry_capacity.0.170229s admitted time remains pending;
0.0196255s rejected observation is separately recorded. Live compiler retries0;
all295 retries occurred during warmup.144 template hits/5 builds show topology
reuse is functioning. Audits still arrive after10 frames, median165.51ms.
The run remains unqualified for realtime adoption and release.

Static topology: about94 draws for a recurring4-substep interval,110 for8 and142
for16 (including the audit draw). Source transaction has19 passes, with separate
status/totals/ledger reductions and commits; force/velocity/flux/gather repeat per
substep. These are not all dispensable measurement passes. Some guard commits or
advance conserved stock. Do not delete them indiscriminately or call their cost
pure instrumentation. Actual GPU timestamps and full-app FPS are not measured.

## What is critical versus what is not

|Priority|Final implementation concern|Decision|
|---|---|---|
|P0|Sustained realtime processing without accumulating unbounded lag|Required; current per-engine-frame qualification graph is not an acceptable product runtime. Simplify cadence/execution, rather than grow the16-entry queue.|
|P0|Correct units, canonical water ownership, no duplication/NaN, bounded resource lifetime|Keep the established guards and event/time accounting. These failures can corrupt all effects.|
|P0|Readback latency controlling the simulation/visible state|CPU audit cadence must be separated from GPU-ordered committed visual consumption. This requires an explicit ownership contract, not a guessed generic fence.|
|P1|Visible head/trail/film continuity and refraction|Connect the new committed state to existing optics early enough to assess usefulness. Stop postponing all visible output for a perfect diagnostic completion time.|
|P1|Birth, motion, merging, pooling and physically meaningful diameter|Complete and assess the required interactions. Merge/pool are currently OFF and not qualified. Display scaling must stay separate from mass/forces.|
|P1|Whole-app2048/4096 cost, spikes and stable memory|Evaluate a concrete visual candidate with the old path replaced, recording which old effects remain active. Avoid drawing conclusions from two simultaneous pipelines.|
|P2|Exact intermediate float reconstruction, exhaustive API-boundary permutations|Freeze current evidence. Reopen only for a new concrete corruption or visible error that blocks the candidate.|
|P2|SMEAR, local impact film and decorative compensation|Remain excluded until the physical/optical result demonstrates a specific missing effect.|

## Chosen next implementation, not another diagnostic fork

1. Build the production execution path from the accepted numerical core. Use a
   bounded fixed simulation cadence (initial target30Hz) and accumulate elapsed
   input/supply across render frames. Preserve all elapsed ticks and source
   volume; account time-weighted forces/pose explicitly. The raw graph already
   supports <=0.05s intervals; the old31.25ms diagnostic FIFO is not the product
   time model. Do not merely skip alternating frames or replace dt silently.
   Rendering remains at game cadence, with a separate output interpolation or
   prediction layer that never feeds physical diameter/mass back into the model.
2. Separate expensive qualification capture/global audit from the hot path.
   Keep cheap local guards and canonical committed state. Reuse already owned
   textures and ordered GPU receipt selection. Determine the minimal ledger
   reductions needed for safe commit before removing any pass. CPU diagnosis
   becomes periodic/on-demand and cannot dictate visible-state freshness.
3. Connect that committed state to existing optical consumers in the same
   candidate. Pose and time alignment must keep head/trail/film together. Keep
   the current renderer as fallback until the new path is safe; do not require
   another invisible three-second probe before writing this integration.

For scale only:94 draws x60Hz is5640 submissions/s;110 x30Hz is3300/s. That is a
static submission-count estimate, NOT a promised GPU/FPS gain. Some transport
substeps remain necessary, and input integration/interpolation costs must be
included. If this straightforward cadence/execution route is still too costly,
choose a cheaper game approximation with explicit conservation/visual criteria;
do not start a new precision-research chain by default.

## Testing and stop rules

- No s279 one-shot app, no new test checkbox, no user replay run requested.
- No repeating s278 merely to see whether a favourable frame schedule reaches3s.
- Next user run must either present usable new optical output or verify a
  specific safety blocker essential to that output. Bundle relevant timing and
  water diagnostics automatically in that candidate.
- Local verification is limited to changed input accumulation, ownership and
  optical mapping. Reuse old evidence for unchanged shaders; no matrix of
  equivalent boundary probes.
- A candidate fails adoption if lag continually grows, hard stalls recur,
  memory grows without bound, water is duplicated/lost beyond model budget or
  visible state is stale/incoherent. A larger queue is not an optimization.
- Apply game-level physical/visual tolerances from the existing acceptance
  policy. Stable event/time identities remain strict; recomputed floats need
  meaningful physical/screen error, not universal bit equality.
- Run long stability and representative2048/4096 A/B once a complete candidate
  exists, not after every small source edit. Three seconds of exact diagnostic
  completion is neither a sufficient nor a uniquely required product criterion.

## Status after this review

Physical supply/handoff/transport: nonzero actual accepted prefix observed.
Continuous realtime implementation: blocked by workload/scheduling, nextP0 work.
Optical integration and merge/pool completion: outstanding product work.
Optimization, visual quality and release: unqualified.
No commit/push, GPU probe, new main-app diagnostic or threshold change in s279.
