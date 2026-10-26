# s172 — fenced native retirement of cache construction outputs

Date: 2026-10-19. Status: ACTIVE (offline native ownership component).

## Implemented ownership boundary

`tools/s172_cache_owner.cpp` executes the unchanged actual-grid cache recipe on
one D3D11 WARP immediate context. After native event completion and full cache
audit, a private owner can retire construction-only textures while preserving
the five core resources: raw cells, captured header, world metric, scalar
physical area and connected runs (cache IDs 3/4/5/6/8).

This is an implementation of the earlier core-cache retention proposal for
**one private native generation**. It does not dispose of CSP Canvas objects
or modify the existing session-retained diagnostic apps. The high-resolution
head du/dv geometry is not the field-centre cache copies being retired and is
not downsampled, reformatted or removed by this operation.

Retirement preflights the entire batch before the first erase. It requires the
current generation, observed real D3D event completion, accepted cache audit,
no failure quarantine and explicit return of every reader of a retiring object.
A reader of a surviving core resource does not block unrelated retirement and
remains valid afterward. Returned capability tokens are single-use; stale
generations and readers for already-retired objects are refused.

GPU bindings are cleared before the completion event. The owner then drops its
COM texture/view references, removing the objects from its descriptor accounting.
No clock or timeout implicitly completes a fence or returns a lease. Pending,
unaudited, stale-generation and failed caches also refuse physical-consumer
submission. A failed generation stays quarantined even after the real event is
observed complete. These are native ownership guarantees, not a general CSP
Canvas completion proof or measured driver residency.

## Actual construction and physical consumers

The unchanged s163 managed recipe is captured as a template, then all 34 cache
passes execute natively. Template capture uses the prior known atlas solely to
complete the mock controller; it provides no new GPU evidence. The native
run independently generates and reads the atlas, verifies its bytes, and checks
every texel of the core cache against the frozen actual-grid cache.

After the optional retirement, the same native context executes:

- s156's compact SI film force/plan/audit with s163's existing scalar-area reader;
- s170's area/header receipt and resolved source-cell conversion.

The actual geometry and captured frame are used with the prior controlled
mixed-depth water inventory. This exercises the physical operators, not a new
weather-driven moving head/film simulation. Every final force packet matches
the preserved s156 result; every resolved source cell matches s170. Surviving
core textures remain bit-identical before and after consumers.

Three runs cover retained reference, successful compaction and injected failure
quarantine. They execute **118 GPU draws / 5 real native completion events**
with 17 strict compiled shader bodies and no D3D debug warnings. Pending,
unaudited, stale, read-held and duplicate retirement attempts leave allocation
unchanged. Consumer attempts in pending/unaudited/stale/failed states submit no
draw and allocate no output. Capacity preflight also refuses the complete
consumer batch before its first allocation or draw. The failed run retains the cache and submits no
physical consumer. Single-generation replacement/rebuild is not implemented.

## Memory results and limits

| Cache-owned descriptors | Retained | Compacted |
| --- | ---: | ---: |
| Textures | 34 | 5 |
| Bytes | 30,827,280 | 22,020,928 |
| MiB | 29.399185 | 21.000793 |

The cache-only saving is **8,806,352 bytes = 8.398392MiB**, with no physical
precision change. Twenty-nine cache textures are retired after audit. The
harness also owns three private source-image upload textures (36MiB), which
are retired after their explicit readers return. These are separate test-owned
builder inputs; their release is **not another 36MiB saving in the whole-app
budget**, which already counts full-resolution head inputs separately.
Borrowed engine or other-owner textures must not be released by this policy.

The private construction/consumer harness starts with 69.400055MiB of default
texture descriptors including those source inputs and controlled water. Its
retained reference reaches 81.415863MiB; compaction keeps its peak at the cold
69.400055MiB stage. It uses an explicit 96MiB **component reference cap**, not a
relaxation of the existing combined 64MiB gate. Upload CPU data, shader/driver
objects and audit staging are separate. Maximum staging is about 33MiB and is
reported independently; resident VRAM or FPS is not measured.

The previous End-only joint proposal changes from 121.502808 to
**113.104416MiB reserved** if this core policy is composed with it. Its warm
live peak changes from 110.687286 to 102.288895MiB. These are still the preserved
descriptor estimates, **not execution of the combined head/source/transport
pipeline**. The warm total 64MiB gate still fails; the static64+working64/total128
alternative remains unadopted. Cold construction, changing-pose replacement,
quarantine overlap, frame/header ownership, queue backlog and common optics
must be charged in their eventual joint owner.

## Delivery and next implementation

Numerical outputs, strict shader provenance, native counters, archive checksums
and the joint-budget link are in `diagnostics/2026-10-19/s172/`. Existing sources
and assets are preserved except the documentation index/roadmap update. Main
script, settings, shaders, textures and installed game files are unchanged.

Next compose the verified core policy with bounded current-frame/cache ownership
and reduce remaining working-buffer lifetimes before full native admission.
Actual-mesh recurrent water/time closure, common optics, CSP completion and
target-device timing remain adoption gates. No user game test is required for
s172.
