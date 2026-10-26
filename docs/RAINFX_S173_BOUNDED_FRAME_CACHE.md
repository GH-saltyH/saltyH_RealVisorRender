# s173 — bounded native frame cache replacement

Date: 2026-10-19. Status: ACTIVE (offline native cache/force component).

## Implemented

`tools/s173_frame_cache.cpp` composes s172 core-cache retirement with a bounded
immutable frame owner on one D3D11 WARP immediate context. Four controlled
contexts use the captured actual visor geometry: original frame660, changed
weather forcing, a rigid90-degree pose change, and return to the original pose
with different forcing. They are controlled inputs derived from the capture,
not four newly captured game frames.

There are at most two cache generations and two waiting CPU contexts. A reader
holds its generation and outputs until explicitly returned. Publishing a new
generation can leave the old one retained; another preparation then refuses
before allocation or drawing. Wrong-generation and duplicate reader returns
fail. Old header, metric and force images remain bit-identical while the next
generation is prepared, including across the pose change.

Every generation owns its header, expected-header/source receipt inputs and
physical preview outputs. Shared raw cells, scalar area, connected runs and
controlled water stock are immutable. Weather-only changes share the metric;
pose changes rebuild it. Recipe, resource shapes, geometry input bytes, scale
and frame/header correspondence are checked before preparation. Mutated
geometry and a mismatched scale/header are refused without GPU allocation or
draw. This reference admits the unchanged geometry/topology/scale family only;
it does not implement arbitrary replacement assets or rescaling.

Pending construction, unaudited caches and incomplete physical previews cannot
publish. An injected failure after construction submission stays quarantined
after the real event completes. It does not pop the waiting context or replace
the published cache. Explicit completed-failure disposal permits retry with a
new attempt identity and the same queued input. The tested failure is deliberate
post-submit quarantine; arbitrary device loss and allocation exceptions remain
outside this recovery demonstration.

## Numerical verification

The suite performs **247 native GPU draws /19 observed D3D completion events**:

- Four full34-pass cache builds plus eight-pass physical previews provide
  independent execution references:168 draws/eight events.
- The bounded stream performs79 draws/11 events, including its initial full
  build, successful weather/pose changes, one failed preparation and retry.

All runs use the same17 preserved strict shader bodies. New C++ compilation
uses `/W4 /WX`; the D3D debug layer reports no warnings. Every surviving core
texel, compact force packet and resolved source cell matches its full-build
reference. Original-pose metric bits match s163; rotated metric bits match the
preserved s165 native rotation. Four independent double-precision force checks
pass the existing32-float-epsilon velocity gate; the maximum normalized error
is0.399833, with1 being the limit. Changed weather also changes the force result.

Rigid rotation changes the atlas's dimensionless inverse/Gram error statistic
(about0.024363 to0.025820). It is checked against the original0..1 admission
criterion, rather than requiring that diagnostic to retain its old scalar bits.
All other atlas values are compared bitwise, and full metric images are checked
against the independent preserved rotation. No physical tolerance is widened.

Whole water-stock images retain their original bits through every successful
and failed preparation. This is a **cache/force preview owner**, not evolving
film inventory: no water bank or solver clock is published. It therefore proves
that preparation preserves supplied stock, not recurrent water/time closure.
The earlier source/head/transport/time owner is not yet composed into this run.

## Cost and remaining limits

| Successful warm preparation | Cache build draws | Physical preview draws |
| --- | ---: | ---: |
| Weather only, same rigid pose | 1 | 8 |
| Changed rigid pose | 4 | 8 |
| Full reference build | 34 | 8 |

Pose changes temporarily upload private du/dv sources and field-centre copies;
they are released after completion and audit, before preview output allocation.
The native owner accounts unique shared textures once and preflights the peak
of these separate phases. The fixture's default-texture descriptor peak is
**93,343,328 bytes =89.019135MiB**, including old cache/output overlap and
construction scratch. Final descriptors are38,815,632 bytes =37.017471MiB.
Separate audit staging peaks at38,798,272 bytes =37.000916MiB. These are
descriptor counts, not measured resident VRAM, GPU time or FPS. CPU copies of
input fixtures/reference arrays and driver objects are outside these numbers.

The explicit96MiB local component cap is preserved. The combined64MiB application
gate still fails; s172's113.104416MiB warm joint proposal is not updated or
claimed as execution of the complete pipeline. Full-resolution head geometry is
unchanged. Native D3D completion does not establish a general CSP Canvas fence.

Next: compose this bounded cache owner with the retained nonzero source/head,
transport and inventory/time owner, charging replacement overlap and working
lifetimes together. Then close the whole-pipeline budget before live admission,
common optics and target-device timing. Main app, shaders, settings and installed
game are unchanged; no user game test is requested for this offline stage.

Evidence: `diagnostics/2026-10-19/s173/frame_checks.json`, `stream.json`, saved
full-grid images and `delivery.json`. The finalizer audits saved results and
parent hashes without rerunning frozen stage builders or GPU experiments.
