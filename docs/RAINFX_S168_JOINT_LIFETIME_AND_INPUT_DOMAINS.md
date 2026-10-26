# s168 — joint lifetimes and physical input domains

Date: 2026-10-19. Status: ACTIVE (offline descriptor planning only).

## Result and scope

The source-only s167 result of 60.210MiB does not establish the combined
birth/head/source/transport budget. A two-frame warm plan now includes the actual
input dimensions, old and new inventory, four transport quarters, independent
inventory copies and explicit completion/observer boundaries. **The existing
64MiB total descriptor gate fails in every variant.** This step executes zero
GPU draws and allocates no native GPU resources. These are descriptor estimates,
not measured VRAM residency, frame time or game performance.

Recipes are loaded from the preserved s146 birth, s148 SI heads, s167 compact
source and s163 packed/scalar-area transport. The reference profile has 4096
head slots, a 1024×256 field, 2048×512 head metrics and a 4096×1024 boundary.
Wet-field feedback and pool return remain disabled, as in the preceding native
chain. Recipe-sized immutable zero images are conservatively charged; a 1×1
specialization has not been verified.

## Sharing must preserve the physical sampling domain

| Proposed sharing | Finding / required action |
| --- | --- |
| Field-centre du/dv as head geometry | Refused. s157 explicitly excludes head consumers. Its 1024×256 point-centre samples cannot replace arbitrary-position 2048×512 head sampling. |
| s153 boundary as a legacy birth/head input | Requires an adapter. Actual boundary is 4096×1024 R32F with alpha decoded into red. Existing recipes assume the metric dimensions and read alpha; independent boundary addressing and red-channel reads must be verified. |
| Raw cache cells as resolved source cells | Refused. Raw channels contain local area/coverage/coating; source cells require physical area/coverage/resolved support/version. Budget a separate adapter using the scalar physical area and raw coverage. |
| Packed End/Mean as an H-high source film | Refused without a checked consumer adapter. An explicit End copy is the current planning baseline. |

The planner changes the proposed boundary descriptors to the native dimensions
and charges those bytes, but records the adapter as **unverified**. It does not
claim the old shaders already support this binding. The proposed source-cell
adapter and optional packed-End consumer are likewise not implemented here.
The admission result refuses these missing adapters even if a budget would fit.

The original full-resolution FP32 head geometry is retained. Reducing its
sampling resolution or physical precision to satisfy a memory cap would require
separate physical validation; this plan does not make that change.

## Joint allocation estimates

All values below are MiB (1MiB = 1,048,576 bytes).

| Two-frame warm variant | Immutable/static | Largest simultaneous live set | Exact-shape pool reservation |
| --- | ---: | ---: | ---: |
| Retained cache, diagnostic roots held | 81.545670 | 209.379059 | 215.755737 |
| Retained cache, minimal roots, End copies | **81.545670** | **122.687286** | **133.501221** |
| Retained cache, packed bank + source End copy | 81.545670 | 126.687286 | 141.501221 |
| Retained cache, proposed direct packed source | 81.545670 | 126.687286 | 137.501221 |
| Proposed core cache, End copies | 73.147278 | 114.288895 | 125.102829 |
| Proposed core cache, direct packed source | 73.147278 | 118.288895 | 129.102829 |
| Proposed core cache + R8 boundary, End copies | 61.147278 | 102.288895 | 113.102829 |
| Retained cache, delayed transport readers | 81.545670 | 190.753281 | 201.567459 |

The minimal retained-cache plan has 534 events, 562 logical resources and 34
required completion boundaries. Its simultaneous live peak occurs in transport
gather, while the previous published inventory remains available for rollback.
The exact-shape reservation is larger because differently sized textures cannot
share backing even when they do not overlap. The plan does not assert that this
greedy reservation is the globally smallest possible allocator.

The retained cache contributes 29.399185MiB. Actual full-resolution du/dv and
R32 boundary add 48MiB; sites/DSD/impact tables and disabled-feedback images are
also retained. Raw field cells share the canonical cache input only; semantically
different resolved source cells do not. Thus even the static inputs exceed the
64MiB total gate before adding dynamic inventory and transport.

The **core-cache candidate** retains cache descriptors 3/4/5/6/8 (raw cells,
header, world metric, physical areas, connected runs). Retiring the other
diagnostic/cache-build outputs is a proposed private native ownership policy,
not authorization to dispose of existing retained CSP diagnostic resources.
The cold cache-building peak and replacement/quarantine are not included.

The **R8 candidate** would save 12MiB for a binary boundary. The local SDK lists
`render.TextureFormat.R8.UNorm`; prior input evidence describes binary alpha.
Exact upload/sample values, supported consumers and independent-resolution
addressing have not been tested in this step. R8 alone cannot satisfy the
combined 64MiB gate: this candidate still needs a 102.289MiB live set.

An alternative *static 64MiB + reusable working 64MiB, total 128MiB* policy is
recorded solely for comparison. Core cache + R8 + End copies numerically fits
at 113.103MiB reserved. **This alternative is not adopted.** The original total
64MiB gate remains failed, all solver admission stays false, and no execution
or resource reuse is authorized by the proposal.

## Lifetime and admission checks

The published eight-resource inventory is pinned until the next atomic bank
exchange; all copied candidates coexist until that exchange. Imported immutable
packets and required roots survive their stage completion. Private intermediate
textures may reuse exact-shape slots after their last ordered native draw;
this requires the future native execution owner and recorded completion
boundaries. A native event is not a general CSP Canvas completion guarantee.

Diagnostic roots and delayed readers extend lifetimes until explicit return.
Timeouts never return a lease. A bounded owner must apply backpressure rather
than overwrite a reader's input. The delayed-reader result demonstrates why
ignoring observers understates the cost.

Eight plans have independent typed-slot/lifetime certificates. Sixteen refusal
controls cover semantic aliases, premature release, missing observer return,
same-draw read/write aliasing, duplicate outputs, invalid copy views/formats,
mutation after closure and a corrupted static allocation certificate. Refused
admission leaves inventory, checkpoint, published time and time debt unchanged.
No simulation equation, water tolerance, shader or game setting changes here.

Evidence: `diagnostics/2026-10-19/s168/joint_checks.json`, individual plan JSONs,
`joint_layouts.json` and `delivery.json`. The plan retains all actual descriptor
shapes and counts, but does not execute the proposed adapters, head motion or
actual-mesh film evolution. Driver objects, source-image/file caches, audit
staging, common optics, queue/cache replacements, cold cache builds and dense
storm throughput remain outside these estimates.

## Next implementation

Verify a lossless binary boundary representation and explicit independent-size
red-channel consumers against the original physical geometry. Verify resolved
source-cell and any packed-End adapters separately. Then recount joint
lifetimes, optimize retained geometry/working buffers and resolve the explicit
whole-pipeline budget before native combined execution. Keep the present game
physics unchanged until ownership/completion, physical closure, common optics
and target-device cost pass. No user game test is needed for s168.
