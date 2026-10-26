# s270 — CSP sampler declaration compatibility (2026-10-24)

## Actual s269 failure

The user run failed during warmup: 128 resources, 25 accepted draws, zero
submitted/audited live intervals, one unfinished private job. CSP rejected
`SamplerState samLinearClamp;` in the physical birth shader with X3003 because
its generated header already defines that sampler at register s8. No actual
three-second source run began. The earlier local compile wrapper had omitted
the engine-provided sampler header, so it could not catch this integration bug.

The complete terminal report is preserved in
`diagnostics/2026-10-24/s269/actual_observation.json`. It is a failed actual gate,
not evidence of successful continuous supply or new physics performance. Startup
measurements were graph construction19.4872ms and allocation pump max2.0735ms;
they do not measure steady execution cost.

## Narrow correction

The new default-off **s270 joint rain transport** menu uses the unchanged s269
graph, executor and source-time owner. Its CSP submission adapter removes only
the redundant plain `SamplerState samLinearClamp;` declaration and uses CSP's
existing linear-clamp sampler. Sampling operations, physical equations, resource
bindings, joint decisions and time/queue limits remain unchanged. An unexpected
alternative declaration is refused rather than guessed. Changed shader packets
receive distinct cache keys and are retained across shader-pending retries.

Original s146/s268 producer sources, compiler binding witnesses and sealed s269
local evidence are preserved. No per-drop work or new GPU resource is added;
adapted strings/packets are cached. The original s269 menu remains available for
historical reference and must stay OFF for the new run.

## Verification and remaining gate

- Captured CSP's actual sampler prelude from the failure log.
- Compiled **all55 distinct combined shader variants** from three interval
  descriptors with that prelude under `/WX /Ges ps_5_0`.
- Reproduced the original duplicate declaration failure, then compiled the
  adapted shader successfully. The sole change is declaration removal; sample
  expressions remain unchanged. No new numerical/GPU performance claim is made.
- Six panel/real-adapter cases, actual main-menu dispatch, lazy host guards,
  shader-pending packet reuse and linked installed files pass.
- Same128 canvases:132.69MiB private plus40.13MiB verified read-only images at
  4096 slots. Allocation remains session-retained; no queue expansion.

Run one fresh unpaused rainy session with other diagnostics OFF. Select
**Enable s270 joint rain transport → Start s270 joint rain transport**. Report
State, Submitted/audited/pending/resources, advanced/debt and Incident/stock/exits,
or the error. Detailed bounded logs are automatic. A fresh session clears the
failed warmup resources and engine log quota. No FPS comparison or image matrix
is needed. Optical output is still disconnected. The actual combined gate remains
pending; nonzero incident supply and accepted zero-debt drain are required.

Tools: `docs/tools/check_s270_sdk.py`, `check_s270_panel.py`,
`collect_s270_observation.py`, `finalize_s270.py`.
