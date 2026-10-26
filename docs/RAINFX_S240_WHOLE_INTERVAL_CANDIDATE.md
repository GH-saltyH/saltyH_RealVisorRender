# s240 — whole-interval transport candidate (2026-10-22)

## Result and scope

A versioned private graph now supports1/2/4/8 equal dyadic substeps per captured
interval. The one-step candidate advances the entire16.666412353515625ms fixture
with one completion boundary and zero remaining debt. No transport force,
map/loss/gather/decision/commit kernel is changed. Request step size and receipt
time expectations change; this is a time-discretization candidate, not an
algebraically identical optimization of four force evaluations.

The full1024x256 field uses the qualified s152 normal local context and a20µm
controlled initial film, not natural rain/drop stock. The local native WARP
test executes1/4/8 steps at exactly equal total time. Both physical inventories
and existing componentwise FP32 ledger bounds pass at each completed step;
the film is finite and nonnegative. The generalized four-step final End field
is bit-identical to the archived s233 four-step result.

| Substeps | Native submissions | Completion boundaries | Fixed graph storage |
| --- | ---: | ---: | ---: |
| 1 | 87 | 1 | 87 resources /91.193MiB |
| 4 | 267 | 4 | same |
| 8 | 507 | 8 | same |

This removes180 submissions and three intermediate completion boundaries from
this cold interval compared with four steps. It does not reduce graph storage.
These counts are from offline execution; they are not target GPU timing, FPS,
or proof that continuous engine input can be drained in real time.

## Equal-time accuracy assessment

The eight-step field is a comparison reference, not an exact physical solution.
Spatial volume L1 uses the mean total water of both fields. Momentum L1 sums
cellwise vector differences and normalizes by the mean summed momentum-vector
magnitude, avoiding signed-axis cancellation; the near-zero floor is1e-12 in
the stored momentum units. Its denominator here is about0.82143, far above that
floor. All comparisons include boundary cells rather than averaging them away.

| Result versus8 steps | One step | Four steps |
| --- | ---: | ---: |
| Total water relative difference | 0.0001641% | 0.00002175% |
| Spatial volume relative L1 | 0.0103066% | 0.00769369% |
| Spatial momentum-vector relative L1 | 0.0346359% | 0.0242777% |

These values lie within even the initial same-model numeric budgets in the
game acceptance policy. Because time discretization changes, they establish
only a promising local approximation. They do not qualify30/60/144FPS behavior,
long accumulation, sharp fronts, deep pools, large accelerations, visual optics
or the proposed adaptive fallback. No physical tolerance is relaxed.

The controlled one-step water summary is805.772095→805.676025mm³, with
0.0149560mm³ evaporation and0.0811213mm³ runoff (GPU summary rounding applies).
Independent full-array sums and all ledger components, rather than only this
rounded scalar summary, are checked against the existing FP32 bounds.

## Implementation

`docs/prototypes/s240/s240_graph.lua` is generated from the preserved s233 graph.
The normalized request is still1048576 integer ticks; the selected substep has
1048576/count ticks. Initial remaining/completed ticks and checkpoint phase2 at
the final step agree with the selected count. Status validation checks exact
advanced/debt times for that step. Immutable cache ownership, full End/Mean
copies before root overwrite and the status's ledger/geometry checks remain.
All retained copies in the4/8-step runs match prior roots exactly.

The Python harness initially expected the Lua validator to always return a
tuple; its successful return is a single boolean. The harness unpacking was
fixed and the complete run repeated. The initial failure did not indicate a
shader or physics failure.

## Remaining work

1. Add bounded retry from the unchanged unpublished interval input when a whole
   step is refused or a conservative bound requires subdivision. Keep rejected
   time/water unchanged and avoid reapplying birth/impact/source events.
2. Cover demanding force/pool/front and long-dt inputs and compare equal-time
   results before selecting the default step policy.
3. Connect the whole-interval recipe to a bounded batched executor and the
   continuous source queue. The old one-SDK-attempt-per-callback proof owner is
   unchanged and still cannot support real-time intake just by using this graph.
4. Measure actual warm CSP cost/tails, then connect conserved sources and the
   renderer/common optics, with reset/replay and long-run adoption checks.

No game installation, main code/settings/root helper change, public stock/clock
publication or user game test is made in s240. Visible water/optics remains s87.
The s239 CPU-tail warning remains open. Git commit/push remains user-owned.

Evidence: `diagnostics/2026-10-22/s240/interval_checks.json`,
`interval_results.npz`, `accuracy_checks.json`, strict shader compile artifacts
and `delivery.json`.
