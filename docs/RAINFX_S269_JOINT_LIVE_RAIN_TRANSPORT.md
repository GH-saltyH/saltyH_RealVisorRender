# s269 — retained birth/head/source/film runtime (2026-10-24)

## Implemented scope

The default-off main-app path now joins the s268 physical producer, s170/s167
conserved source, s267 joint transaction and compact s264 transport to the
observed s266 asynchronous input/time owner. It starts **dry**, warms its shaders
and allocations, resets the private inventory, then captures three seconds of
actual inputs. This is private inventory execution: optical output/public RainFX
adoption remains a later gate. Existing game rendering is unchanged.

Births use the admitted rain/DSD/impact/material context. Heads use the SI motion
model and previous/current visor pose; physical film/micro stocks provide wet
feedback. Merge commands and localized pool return remain explicitly disabled.
Smear/local impact film are not added as substitutes. Display gain is excluded
from the physical context and conserved volume.

## Execution and ownership

- Build producer/source/transport plans once; bind new immutable headers and
  uniforms per admitted interval. No CPU per-drop stamps or simulation readback.
- Two inventory banks select film, micro, physical heads, raw state, metadata,
  cumulative ledger, checkpoint **and previous pose** under one joint decision.
- Copy the joint receipt even after refusal. Already submitted suffixes inherit
  that refusal; no suffix can restart time advancement from the rejected bank.
- Submit every selector and pose/receipt copy before the immutable audit copy.
  The early joint decision alone does not retire resources or input leases.
- Keep the existing 32 audit slots, 16-entry source queue, 0.25 s source-age and
  0.5 s audit-debt limits. No increased queue hides a throughput deficit. An
  overload/refusal stops intake and retains unadvanced source time.
- Every private allocation and all seven verified file images require matching
  dimensions/formats. The mask is the hash-verified authored BC3 image, not a
  fictitious RGBA32 allocation. CPU objects from readback are disposed once.

Source-global numeric/header/checkpoint validation is evaluated once into a
1×1 guard, following the already tested head-frame guard technique. Shape tests
are covered by the typed resource leases. Per-cell/source funding and the joint
water/momentum checks remain. Strict FXC active-texture reflection, tied to shader
body hashes, removes only inactive API bindings; maximum bindings are **16**.
No extra texture slot allowance or weaker numerical tolerance is introduced.

## Working set and local evidence

At **4096 slots**, 1024×256 film and current 2048×512 geometry:

| Item | Measured descriptor count/size |
| --- | ---: |
| Private canvases including 32 audit slots | 128 |
| Private texture bytes | 139,132,720 (132.69 MiB) |
| Read-only file texture bytes | 42,080,256 (40.13 MiB) |
| Combined texture estimate | 172.82 MiB |
| First interval draws, excluding audit copy | 107 |
| Steady interval draws at dt ≤ 1/60 | 93 |

Longer admitted intervals use the inherited 8/16-substep compact transport and
therefore more draws. These are texture descriptor estimates; driver allocation,
staging, CPU/Lua memory and existing app resources are additional. This stage
does not provide whole-app memory or FPS claims for 2048/4096 populated heads.

Local checks:

- **293 native GPU draws**: current full bake, 4096-slot shapes, two accepted
  intervals and one late injected refusal. Every read has an initialized input;
  all eight roots retain their previous bits after refusal, including pose.
- A declared **20 µm native-only initial film** exercises nonzero transport. The
  short admitted recorded slices have **zero incident water and no initial
  heads**. Nonzero producer motion/source were checked separately in s267/s268;
  this combined test does not claim populated-rain throughput or live supply.
  Runtime has no access to this fixture option and starts dry.
- Full cumulative water/momentum closure uses inherited FP32 tolerances, not a
  universal bit-equality criterion. Bit preservation is required only for the
  rejected roots that must select the original values.
- **13 controlled owner cases** use real capture/admission/time queues and delayed
  or synchronous SDK callbacks: pause, long frame, display changes, shader pending,
  refusal, pressure, scale reset, bad receipt, timeout and cancellation.
- **Six real-adapter panel cases**, actual main-menu dispatcher, lazy callback
  guards, Lua parsing and linked installed-file checks pass. They simulate SDK
  completion and are not actual CSP numerical/performance measurements.

Commands: `docs/tools/check_s269_graph.py`, `check_s269_owner.py`,
`check_s269_panel.py`, `finalize_s269.py`. Evidence:
`docs/diagnostics/2026-10-24/s269/`.

## One actual continuous gate — pending

Start a fresh unpaused game/replay session with rain present. Keep other
diagnostics OFF. In RainFX → Weather inputs and physical units (P0), enable
**s269 joint rain transport**, then **Start s269 joint rain transport**.
The run ends after warmup and three seconds of admitted actual inputs.

Report State, Submitted/audited/pending/resources, advanced/debt and Incident /
stock / exits, or the error text. The detailed report is automatically logged;
no extra FPS comparison or image matrix is needed for this gate. Textures remain
retained until app/session ends. The eight-line bounded report fits the fresh
session log quota. Collect with `docs/tools/collect_s269_observation.py`.

Passing requires ordered accepted receipts, zero pending/debt at drain, source
time closure, no retained resource growth, and nonzero incident water for supply
qualification. An observed dry run alone cannot qualify physical rain supply.
Actual CSP bindings, BC3 sampling, overlapping inventory execution and continuous
combined throughput remain unverified until this run. After it passes, connect
checked inventory to optics and evaluate common visuals/frame time; do not create
another standalone probe series by default.
