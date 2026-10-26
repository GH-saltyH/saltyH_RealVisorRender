# s231 — main-app private execution boundary (2026-10-22)

## Result and scope

The actual CSP main-app run reached **observed: 16/16 completed, 14 reuses**.
Its automatic log also records 48 accepted draws, six retained canvases,
16 status readbacks, 16 CPU-data releases and zero quarantined slots.
This passes the private packet-echo execution/reuse check. It does not qualify
a general GPU fence, a renderer lease, water evolution or the new physical solver.
Existing game water physics remains s87. No FPS or memory-plateau claim follows.

Evidence: `diagnostics/2026-10-22/s231/actual_observation.json`,
`actual_capture.log`, `runtime_checks.json`, `runtime_audit.json`, `delivery.json`.
The observation retains the exact tested source copies and installation hashes
under `observed_runtime/`; the live game log can subsequently rotate.

## Implemented runtime

- `rain_preview_executor.lua`: two fixed private slots, bounded admission,
  stable per-slot shader parameters, submission retries and status validation.
- `rain_preview_csp.lua`: SDK adapter for owned ExtraCanvas inputs and a small
  asynchronous CPU status copy; CPU data is released once, GPU resources retained.
- `docs/prototypes/s231/s231_sources.lua`: three-pass seed/copy/status graph.
- `docs/prototypes/s231/s231_panel.lua`: one immutable s152 context capture,
  16 jobs and a one-shot main-app UI. No per-job GPU allocation.
- `realvisor.lua`: lazy, default-OFF UI hook in RainFX → P0. Scene-ready execution
  excludes the existing offscreen/native capture views. No saved-setting migration.

Each slot has two 8×1 RGBA32F images and one 16×1 R32F status image. Together
the two slots contain **640 logical texture bytes**; each readback is 64 bytes.
These numbers exclude GPU objects, driver allocation granularity, context
validation and the rest of the app. They are not total VRAM measurements.

The status carries an exact magic/generation/sequence/slot receipt, a refusal
flag and the echoed FP32 weather/air/inertia payload. Every written graph
resource must be an ancestor of the private status tail. The approved shader
reads its complete tiny input. A validated tail permits reuse only within this
owned graph; it grants no authority over unrelated or externally rendered data.

Shader-pending returns preserve the same job, bindings and cursor. Exceptions,
unknown submission results, invalid receipts, timeout or clock regression stop
admission and retain uncertain resources. Duplicate/late callbacks cannot free
a newer job's slot. Cancellation invalidates the generation; partial submitted
jobs must drain before reuse. If the panel is disabled and stops pumping, those
bounded resources remain retained until app/session end. There is no explicit
GPU destruction or unbounded per-toggle allocation.

## Verification and follow-up correction

The actual game result is separate from local verification:

| Check | Evidence |
|---|---|
| Actual CSP, main UI | 16 completed / 48 draws / 14 reuses; six canvases |
| Local executor and adapter | 23 controller/error/cancellation cases |
| Software D3D WARP | 48 draws, three strictly compiled shader bodies; exact payload |
| Real panel with mocked context/SDK | 16 completed, 14 reuses, one summary |
| Host and graph guards | Five host checks; six invalid recipes rejected |
| Optional false texture binding | Three local submitted-pass assertions |

After preserving the actual observation, review found that Lua's
`condition and false or other` idiom removed an optional `false` texture key.
An explicit branch now preserves it. The observed graph uses no such bindings;
its panel, shader sources and adapter are unchanged. The corrected executor
passed the local suite and was installed after checking the previous installed
hash. **The actual observation applies to the saved pre-correction source**;
no second CSP observation is claimed for the unused optional-input branch.

The local SDK audit checks nine relevant declarations against the bundled
reference. The audit itself never claims actual execution; the independent
observation report supplies that evidence. Main changes are limited to the lazy
diagnostic hook; existing settings, physical shaders and historical evidence
are preserved by the delivery check.

## Next implementation and acceptance

Use this executor to connect the physical source/head/transport work, beginning
with owned real geometry/context and a bounded private water interval. The
current single-write graph contract needs explicit persistent state-bank and
reader ownership before recurrent physics or render export is admitted.

Keep exact identity, stale-generation rejection, ownership, invalid-cache,
water-budget and clock/debt contracts. Apply the s229 numerical/visual budgets
to recalculated physics instead of imposing blanket intermediate bit equality.
Full-image proof and archives remain optional diagnostic work. Once an actual
water preview is connected, assess same-scene frame milliseconds, warm memory,
head/film continuity and common optics. A tiny packet echo cannot substitute
for those product checks.
