# s227 — ordered producer-to-consumer lifetime observation (2026-10-22)

## Result and decision

One planned event observation and one sleep observation pass the original exact
physical-prefix gate and all six new relations. Donor1402, recipient1420 and
decision1417 retain identical bytes and native owner identities from production
to their use by combine1421. Their last compensated reductions also match an
independent ordered FP32 CPU calculation. All ten captured images are identical
between the two observations.

**The s223 difference does not reproduce and remains unresolved.** Its actual
upstream inputs are unavailable. These observations narrow the recorded paths;
they do not establish the original cause, general resource safety or a fix.

## Trace and observations

The frozen graph, schedule and backing table are traced together. Seven target
resources have matching producer/birth steps, matching declared consumers, no
overlapping declared lifetimes among their backing aliases, and no intervening
graph write to their backing between production and final declared use. This
is a static target-schedule check, not proof of general runtime ownership.

| Value | Producer step | Captured producer input | Observed consumer step | Native backing / owner in both observations |
| --- | --- | --- | --- | --- |
| Donor1402 | 1466 | Exchange1401, 4×4 RGBA32F | 1485 | 80 / 88 |
| Decision1417 | 1481 | Decision inputs not captured here | 1485 | 58 / 53 |
| Recipient1420 | 1484 | Ledger1419, 4×16 RGBA32F | 1485 | 19 / 25 |

Backing numbers are schedule slots. Owner numbers are native diagnostic object
identities, not physical VRAM addresses or CSP leases. Copy points require the
expected logical occupant, and production/consumption records must identify the
same owner and backing. Combined1421 and terminal1425 are also saved; terminal
bytes must agree with the original phase20022 intermediate archive.

Combined1421 and terminal1425 legally reuse backing61 / owner57: the former is
produced at1485, last read at1486, and the latter is produced at1489. Sharing
this backing therefore does not by itself identify an overlap defect.

The ten image labels, in copy order, are1401,1402,1417,1419,1420,
101402,101417,101420,1421,1425. The100000 offset distinguishes the three
consumer-time snapshots from producer-time snapshots. Each snapshot is an
ordered GPU copy into an independent staging texture; the shader consumer still
uses the original texture. This is not a no-reuse rerouting experiment.

Both final reduction shaders use compensated addition. The CPU checker mirrors
their bank layout and y-then-x order, rounding each subtraction/addition to FP32;
it does not substitute a double-precision or vectorized sum. The donor's invalid
packet guard is included. Six synthetic targeted output-bit mutations are
rejected by the corresponding relation checks. These checker controls are not
new native GPU fault-injection experiments. Earlier first-stage tile generation
and decision physics are not independently recalculated here.

## Cost and unchanged gates

Ten raw CopyResource commands require1888 logical staging bytes:
256+32+16+1024+128+32+16+128+128+128. Source owners and staging copies remain
retained until the existing phase completion, then are read and released before
the next reservation. There is no extra shader draw, timestamp query or
completion event. The copies can still affect timing and driver placement;
non-reproduction under observation does not prove the unobserved run was safe.

Both full-prefix observations preserve9 published /12 accepted intervals,
queued[9,10,11],246 completion events,2260 draws, original exact archives,
bank/stock/clock/debt/lease checks and the original default-texture cap. Scoped
default payload remains66,582,496 bytes under66,584,576. Diagnostic staging is
accounted separately; neither figure is total VRAM usage. No timing comparison,
FPS improvement or default completion-policy adoption is claimed.

## Next implementation

The recorded values are stable across the producer/consumer gap and their final
reductions are correct for the recorded inputs. Next use frozen1401/1419 inputs
to replay the two original compensated-reduction CSOs in a small bounded test,
including cancellation, guard and output-fault controls. This extends the s226
arithmetic reference upstream without another set of full-prefix repetitions.
It still cannot recover missing inputs from the original s223 failure. Broad
CPU partitioning and release qualification remain behind the original exact gate.

Physical/time accuracy, unified head/film optics, live CSP ownership/completion,
whole-workload cost and long warm-run gates remain open. s222 is the last passed
cost comparison; game physics remains s87. No game test is requested.

## Evidence

Artifacts: `docs/diagnostics/2026-10-22/s227/`. `lifetime_trace.json` binds the
static graph/schedule/backing/source hashes. Native capture metadata records
step, logical ID, snapshot label, backing, owner and occupant. The builder and
runner freeze sources/receipts and execute at most one observation per policy,
stopping at the first exact/relation refusal. Saved-only
`check_s227_lifetime.py` checks all relations, original prefix gates, receipts,
unchanged prior sources/settings and the delivery seal. Strict compilation
passes `/W4 /WX /O2 /fp:strict` for both variants without a build correction.

No numerical tolerance change, native retry, game installation, main-app/settings
edit, commit or push.
