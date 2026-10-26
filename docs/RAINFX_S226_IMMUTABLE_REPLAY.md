# s226 — immutable ledger arithmetic replay (2026-10-22)

## Result and scope

Eight fresh native GPU processes complete 32 repetitions each: **256 small
arithmetic repetitions and 768 exact output comparisons**, all matching an
independent FP32 CPU oracle. These are not physical solver intervals. Inputs
also match their frozen bytes before and after every process's repetition loop.
Both existing event and sleep completion policies pass all four readiness cases.

The captured s225 input set is reproducible through these three shaders in this
bounded experiment. **The original s223 discrepancy remains unresolved.** Its
actual donor/recipient input bytes were not captured; no result here establishes
what happened in that failed run, general resource safety, or a driver defect.
The separate s208 retained-metric discrepancy remains open as well.

## What executes

The replay uses the original three compiled shader objects, with hashes bound to
each process's receipt; their physical shader sources are not recompiled.

| Original producer | Immutable replay operation | Output |
| --- | --- | --- |
| 1421 | Recipient1420, plus donor1402 rows0/1 into rows4/5 when readiness1417 accepts | 1 |
| 1422 | Commit-kind3 copies the accepted ledger, otherwise its original refused branch | 2 |
| 1425 | Copies the committed ledger and adds inventory1383 row1 into rows0/1 when finish1423 accepts | 3 |

Each case freezes donor, recipient, readiness, inventory and finish from the
s225 capture. Four cases set readiness/finish to accepted/accepted,
refused/accepted, accepted/refused and refused/refused. The CPU oracle evaluates
the sequential chain, with FP32 additions and exact copies. Its nominal outputs
also match the actual s225 captured outputs. Only commit-kind3 is qualified;
other commit-kind bindings are not exercised.

Each repetition clears the three outputs to a canary, executes three shader
draws, copies all three outputs, waits for the existing completion predicate,
then checks all output bytes. Across each healthy process this is96 draws and
34 completion events:32 output groups and two immutable-input groups. Input
owners and staging snapshots remain retained through their completion/read.
The event signal remains a wakeup; GetData completion still authorizes reading.
No general CSP completion fence is established.

Logical default-texture payload is1120 bytes under the4096-byte local cap.
Peak staging payload is384 bytes. These exclude driver allocation/row-pitch
overhead, constant buffers, shader objects, timing queries and other objects;
they are not total VRAM measurements. No full physical source/head/film graph,
stock publication, solver clock or water evolution executes. Timing data is
diagnostic output only; no performance comparison or policy adoption is made.

## Refusal controls and build evidence

Two altered receipts—input SHA and shader SHA—are refused before the GPU owner
is constructed, with zero started completion events. A separate output control
flips bit0 of output1 word17 after the three draws. At the first iteration the
saved output contains exactly that difference, while outputs2/3 remain exact.
The checker/native replay stop with an explicit mismatch report. This is a
private replay stop; it does not demonstrate live CSP rollback or physical
publication quarantine.

Strict initial compilation failed on unused static functions in a frozen helper.
The helper includes are now both inside the existing C4505 suppression scope;
new replay code retains `/W4 /WX /O2 /fp:strict`. Initial source/build script and
raw failed log are preserved. No GPU run preceded this build correction.

The original runner completed all eight healthy processes and the two receipt
controls, then its output-control setup collided with the existing nominal
receipt filename. No output-control folder or native execution existed at that
point. `complete_s226_fault.py` preserves the original controls report and uses
a distinct receipt filename for the single previously unstarted control. No
healthy or failed native result was retried, and no numeric gate was relaxed.
The original runner and execution/build source manifests remain frozen.

## Next implementation

Keep the small replay as a bounded arithmetic reference. Next inspect upstream
donor/recipient production and the full pipeline's backing reuse: trace their
last writes, consumers and alias lifetimes, then design one bounded ownership
control with the original exact gate. Repeating the same full prefixes until a
difference appears would not identify the missing cause. Resume broad CPU
partitioning only after the exact intermediate-result gate is understood.

Live CSP resource/completion integration, physical/time accuracy, unified
head/film optics, full-workload cost and long warm runs remain required before
adoption. s222 remains the last passed cost comparison; game physics is s87.

## Evidence and delivery

Artifacts: `docs/diagnostics/2026-10-22/s226/`. The builder freezes fixtures and
compiles; the runner records eight healthy cases and receipt controls; the
completion helper records the unstarted bit-fault control. The saved-only
`check_s226_replay.py` independently verifies fixtures, full output/input bytes,
completion counts, refusals, hashes, preserved prior files and the delivery seal.
It does not launch another GPU experiment.

No main-app/settings changes, game installation, commit/push or user game test.
