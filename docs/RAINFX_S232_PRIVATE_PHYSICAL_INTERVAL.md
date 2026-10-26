# s232 — actual-grid private physical interval (2026-10-22)

## Delivered and current status

The main app now has a default-OFF **private water interval** using the actual
1024×256 visor bake and a captured visor world pose/material/force context.
It runs the existing s163 conservative transport bodies unchanged. The new
graph runs through the s231 executor and SDK adapter, rather than the native
diagnostic runner. Local software-GPU execution and **one actual CSP private
quarter-interval observation pass**. Existing displayed water physics remains s87.

This stage starts with an explicit **20µm controlled physical film**, zero
micro/head inventory and zero initial momentum. It evaluates one quarter of
the captured interval, preserving the remaining three quarters in its private
checkpoint. This exercises force, X→Y conservative remap, evaporation, runoff,
inventory and ledger checks. It does not yet represent incident rain/birth,
head evolution, recurrent game time or the visible optics result.

## Actual CSP observation

At captured frame1538 the main app reports observed, completed1/1,
accepted84/84,84 canvases and87.1614MiB logical texture data. One status readback
and one CPU-data release complete with zero quarantined slots. All21 automatic
log lines were preserved and independently decoded; context and pose hashes,
the exact private receipt, physical area and advanced/retained time match.

| Quantity | Actual CSP result |
|---|---:|
| Initial / final film | 805.772156 / 805.731567mm³ |
| Evaporation / runoff | 0.003107170 / 0.037439175mm³ |
| Mass residual | −0.0000420341mm³, bound0.0245902141mm³ |
| Maximum normalized GPU ledger residual | 0.00318025, limit1 |
| Advanced / retained time | 0.004257441 / 0.012772322s |
| Wet / supported cells | 123,224 / 123,224 |
| Largest output speed | 0.001449353m/s |

The mass change is accounted for by evaporation/runoff within the existing
FP32 budget. This actual check observes GPU reductions and the small status;
the full-array independent CPU comparisons remain local WARP evidence. The
game's captured dt/pose/forces differ from the local fixture, so their final
water values are not expected to be identical. No FPS, continuous reuse,
long-duration memory or renderer-ownership result is inferred from this run.
Evidence: `actual_capture.log` and `actual_observation.json`; the latter binds
the original game-log hash, installed-runtime audit and local checks.

## Main-app operation

RainFX → Weather inputs and physical units (P0):

1. Enable **s232 private water interval**.
2. Press **Run s232 private water interval once** in an unpaused session.
3. Wait for **State: observed**, completed1/1 and accepted84/84.

The run logs 21 bounded lines automatically, including all 52 input rows and
16 status floats as exact hex words. The optional Log button repeats this same
small report. The collector independently checks context/pose identities,
receipt, water totals, advanced/retained time and refusal flags.
Use a fresh game session when the CSP app log limit has already been consumed.
No weather, driving, screenshot or FPS comparison is needed for this admission
check. A fault retains uncertain resources and logs the available status words.

One fixed slot owns **84 canvases / 91,395,392 logical texture bytes
(87.1614MiB for the local 4096-head-capacity capture)**. This excludes image cache,
GPU object/driver overhead and the rest of the app; head capacity can alter the
small head buffer. The private budget is128MiB. Resources remain retained until
app/session end. Toggle OFF/ON does not repeat allocations or reset the one-shot.
The 64MiB optimization target is not treated as a universal total-app limit.

Preparation allocates the fixed graph once on explicit Run; submissions are
limited to one attempt per scene-ready callback with asynchronous compilation.
This is snapshot execution spanning callbacks, **not a demonstrated real-time
frame budget**. Initialization hitch, target timing and warm runtime cost are
unmeasured. No performance improvement is claimed.

## Owned inputs and execution contract

- s152 validates files and captures actual pose, SI forces, air density,
  material, physical scale and dt. Its rain/DSD override refusals remain.
- `rain_preview_file_inputs.lua` accepts only relative file paths with the
  expected context hashes and image dimensions. It imports no mutable GPU handle.
- Du/dv are copied at the exact field-centre domain qualified by s157; cells
  retain the original local physical-area/coverage/coating data.
- Complete integer-word GPU fingerprints check the three owned copies and
  captured header against their expected fingerprints. These are numerical
  fingerprints, not cryptographic GPU authentication. Full-grid geometry audit
  checks world metric, area and connected runs.
- Display diameter gains and texel appearance multipliers do not enter the
  controlled inventory or physical force/transport equations. Track wetness and
  puddles do not silently become visor water.
- The inherited force, remap, positivity, source-once, conservation and debt
  rules are unchanged. Initial history is generated from the controlled GPU
  inventory, not an assumed CPU total.
- Only final status ancestors are retained. Tail validation also reduces the
  entire End/Mean field on GPU, checking finite/nonnegative packets and actual
  inventory against the conserved ledger. The CPU receives only64 bytes.
- The tail receipt uses s231's private generation/sequence/slot contract. No
  general GPU fence, external renderer lease, public water bank or public clock
  publication is supplied.

## Local results

The frozen context is the previously verified s152 fixture, not a new game
measurement. One actual-size graph executes84 draws; four targeted fingerprint
draws and five status-refusal draws avoid repeating the physical graph for faults.
All transport shader bodies are byte-identical to their s163 parents.

| Quantity | Local software-GPU result |
|---|---:|
| Initial film | 805.772095mm³ |
| Final film | 805.748413mm³ |
| Evaporation | 0.003739mm³ |
| Runoff | 0.019864mm³ |
| Advanced / retained time | 0.004166603 / 0.012499809s |
| Cells with changed volume | 123,196 |
| Maximum normalized ledger residual | 0.0032154, limit1 |
| Largest output speed | 0.001613776m/s |

Independent CPU full-array sums and ledger closure pass the existing128-FP32-eps
component bounds with1e−9 floor. No blanket intermediate bit gate was introduced.
One changed immutable Du word is rejected by the exact fingerprint. Ledger,
decision, geometry, nonfinite inventory and immutable-seed refusal flags all
reach the small status. Main-panel mocks cover pending shaders, one-shot resource
retention and bounded logging. Five file-input and five main-host guards pass.
Maximum bound textures is15, below the previous oversized-probe case.

The first local run exposed an X4000 potential-uninitialized-return warning in
the new request initializer. The shader now initializes a result and returns
once. The original failing source/report are preserved under `initial_failure/`;
final bodies compile with warnings treated as errors. An installer hashtable-key
syntax error was fixed before its first successful write.

Evidence: `diagnostics/2026-10-22/s232/checks.json`, `physical_results.npz`,
`graph_layout.json`, `transport_origins.json`, `runtime_audit.json`, `delivery.json`.
The transport bundle is an isolated closure of48 unchanged modules, with no
global package/preload mutation. Prior sources/settings/shaders are preserved.

## Next

Actual CSP admission passes for this one private quarter interval. Next connect
persistent private End/Mean/checkpoint and
immutable context ownership so successive accepted intervals retain physical
time. Then attach the existing conserved incident/head source, followed by a
renderer read lease and common head/film optics. Separate one-time geometry
checks from recurring interval work. Assess same-scene frame milliseconds,
initialization latency, warm memory and visual continuity at that stage.
Smear and local impact-film corrections remain optional later evaluations.
