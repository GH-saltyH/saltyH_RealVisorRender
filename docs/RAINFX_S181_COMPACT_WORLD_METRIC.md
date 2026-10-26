# s181 — compact FP32 world metric

Status: offline exact reconstruction and physical recurrence verified, 2026-10-20.
Game physics remains s87; diagnostics remain s89.

## Selected representation

The old metric cache stores three RGBA32F bands: world-space basis vectors
`u`, `v`, their validity flags, then `Guu`, `Guv`, `Gvv`, and the determinant.
At1024×256 this occupies12MiB. The new `packed_world_uv_Guu_Gvv_v1` ABI stores
two bands, `(u.xyz,Guu)` and `(v.xyz,Gvv)`, occupying8MiB. Consumers reconstruct
`Guv=dot(u,v)` and `det=Guu*Gvv-Guv*Guv`. No geometry sample, physical unit,
field resolution or FP32 component is reduced. Pixel coordinates and all
legacy logical3H extents remain checked by the adapter.

Positive Gram diagonals leave their sign bits available for disabled-basis
flags in the synthetic reference. A negative stored diagonal marks that basis
disabled; its magnitude remains the original positive Gram coefficient. The
canonical world-cache producer emits positive coefficients for valid cells and
zero for invalid cells. Invalid zero cells retain zero flags. Host admission
requires exact reconstruction of **every** original FP32 word; arbitrary
inconsistent coefficients, flags or nonfinite inputs refuse. This is a scoped
ABI with verified construction, not a general compression of arbitrary metrics.

The producer derives both bands directly from the canonical physical geometry
and actual controlled frame headers. The downstream adapter checks physical
dimensions and logical read bounds. Legacy three-band imports or incorrect grid
uniforms refuse before native device construction. Inputs are not changed by
failed host admission. Enabled optional feedback and Mean-consumer restrictions
from the previous profiles remain in force.

## Findings retained from rejected approaches

Shrinking only the final force output increases exact-shape reservation by4MiB:
it prevents an existing larger slot from serving both lifetimes. Shrinking that
output together with the final gather still increases reservation. Neither was
selected. Earlier gather Mean remains required by the second-axis map.

An initial decoder marked its reconstructed coefficients `precise`. Although
the decoded metric words matched, the modified consumer compilation produced
small physical output differences. Its retained native results are saved as
`precise_trial.bin.gz`, and the exact differences are reported. That experiment
is rejected. The final ordinary-FP32 helper passes the **same unchanged bit
comparison gates** for reconstruction and physical recurrence. Do not restore
the qualifier based only on a standalone decode test: changes to the compiled
consumer must also pass the physical tests. No tolerance was substituted for
the failed bit gate.

## Verification

- Four actual1024×256 geometry/context cases, including rigid-pose change,
  weather reuse and return, directly construct the two-band metric on GPU and
  reconstruct all12MiB of legacy words with **zero bit mismatches**.
- A separate native decode retains the synthetic disabled-basis flag pattern.
- The persistent13×7 field/8-head physical owner executes **615 draws,37 real
  completion events,4 bank copies** and three cache/stock/time publications.
  All retained physical outputs and eight inventory roots match s180 bits.
  Independent physical/water/time checks, source ON/OFF/ON, failed cache/source/
  bank candidates, retry, replay refusal and held old-cache readers pass.
- Another141 standalone draws exercise accepted/refused/resumed actual1024×256
  transport with4096-head descriptors and the packed metric. All14 retained
  public roots per case match frozen s164 logical outputs. Rejected debt retains
  prior film/checkpoint/ledger; water closure passes.
- Final configuration evidence totals **766 draws**:615 persistent small-chain
  draws plus151 standalone draws (metric proofs, synthetic decode, actual-grid
  metric decode and physical operators). Failed qualifier experiments are
  additional and explicitly unselected.
- C++ `/W4 /WX`, shader `/WX /Ges`, native debug layer and six negative admission
  checks pass. The saved final audit rechecks hashes, exact words, physical
  recurrence, lifetime certificates and previous source SHA/mtime without
  rerunning earlier builders or native tests.

Small native texture peak falls397,216→376,832B; diagnostic staging remains
282,096B. This measured small-reference reduction is distinct from the full-grid
descriptor proposal below. The actual-grid physical passes use host-mediated
readback between shaders; they do not constitute a persistent full-grid joint
owner or a CSP completion proof.

## Full warm descriptor proposal

| Scope | s180 | s181 |
| --- | ---: | ---: |
| Static inputs |33.850433MiB |29.850433MiB |
| Maximum simultaneous live set |70.992050MiB |**66.992050MiB** |
| Exact-shape reservation |77.807526MiB |**73.807526MiB** |

All three counts fall exactly4MiB. Independent lifetime certification passes;
all16 force and2 source-cell last-reader records remain identical. The64MiB
gate still fails, with reservation9.807526MiB over the cap. This warm plan does
not include cold cache construction, changing-pose overlap, CPU fixtures,
readback staging or driver/shader allocations.

Replacing a Gram texture load with a dot product and determinant adds shader
arithmetic. No target GPU milliseconds or FPS benefit is claimed. Actual-grid
cache owner construction/retirement must be composed with this ABI before its
new descriptor count can authorize execution. General CSP completion, joint
actual-grid ownership, common optics and live adoption remain open.

Next implement the packed producer inside the actual-grid immutable cache owner
with old-reader protection and exact downstream reconstruction, then reduce
remaining force/map/gather overlap and compose the complete physical owner.
No user game test is required for this offline step. Main app, settings,
production shaders/assets and installed game are preserved. Git stamps remain
with the user.

Evidence: `diagnostics/2026-10-20/s181/metric_checks.json`, metric/root NPZ files,
native reports and retained outputs, `joint_plan.json`, physical last readers,
rejected precise experiment, `numerical_audit.json`, source diff, archive manifest
and `delivery.json`. Frozen evidence must not be regenerated by old builders.
