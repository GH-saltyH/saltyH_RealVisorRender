# s190 — full-size native allocation and lifetime replay

Status: actual D3D11 texture allocation for the complete two-frame warm schedule
verified, 2026-10-20. This is an allocation milestone; warm water physics is
not executed. Runtime remains physics s87/diagnostics s89. No game test needed.

## Implementation

The frozen s188 schedule now runs in a native owner on one D3D11 WARP context.
It covers all **523 logical resources, 538 schedule events and 35 phases** at
the actual dimensions: 4096 heads, 1024×256 field, 2048×512 geometry index and
4096×1024 boundary. Typed resources include R32F, RGBA32F, exact integer-run
RGBA16F, cell RG32_UINT and R8_UNORM. Existing phase boundaries and lifetimes
are preserved. The independent lifetime certificate is checked before execution.

Bootstrap runs the real s189 geometry/cache shaders, then moves the seven
retained cache/geometry textures into the schedule owner. This transfer keeps
the same GPU objects; it does not upload replacements or copy the cache.
Bootstrap intermediates and unused preview inputs are explicitly retired first.
All **7,668,560 logical FP32 proof words** match the frozen s189 cold proof.

Warm outputs use whole-texture diagnostic clears. At every declared logical
read, three texels (corner, centre, opposite corner) are copied to typed staging
and compared after the phase's real completion event. Actual imported cache
textures retain their sampled bootstrap bytes. Other resources carry exact
logical-owner markers; R8 uses binary markers plus object/lifetime validation.
This checks resource identity, aliasing, typed storage and retention. It does
not validate warm shader bindings, numerical water results or every texel.

The native owner reserves an entire phase before submitting work. It validates
the complete retirement batch, refuses held objects, retires only after the
previous phase completes and then creates missing exact-shape textures. Shared
object destruction decrements the live counter, including final cleanup.

## Results

| Metric | Native result |
| --- | ---: |
| Cold default texture descriptors |37,381,792B /35.650055MiB |
| Combined cold/warm default descriptor peak |66,572,192B /63.488190MiB |
| Retention limit |66,584,576B /63.5MiB |
| Margin to original 64MiB limit |536,672B |
| Warm backing generations, including 7 adopted textures |107 |
| Warm retired generations |29 |
| Warm backing bytes created/adopted cumulatively |86,968,224B |
| Warm retired bytes |20,396,032B |
| Final live default descriptors after cleanup |0B |
| Diagnostic clear writes |520 |
| Three-texel read checks |2,890 |
| Separate sample staging descriptor peak |11,052B |
| Separate full cache audit staging descriptor peak |26,479,936B |

Every phase's resident count and all creation/retirement totals equal the
independently certified s188 plan. The stricter retention limit has only
12,384B of slack. Counts describe allocated texture descriptors, not measured
resident VRAM or process memory. Staging, CPU fixtures, driver padding and
shader allocations are excluded from the default-texture budget.

The experiment uses **68 real cache shader draws and 39 native completion
events**: two 34-draw bootstrap attempts, two bootstrap events, one sample-baseline
event, 35 warm phase events and one diagnostic phase retry. Warm physical shader
draws are **zero**. These are test workload counts, not a proposed game's frame
cost. No GPU speedup or FPS result is claimed.

## Failure, readers and budget controls

- A real completed cache build is deliberately refused by validation. Its outputs
  stay quarantined until explicit discard. Retry reallocates its 34 outputs and
  reproduces the frozen cache, within the same counted bootstrap peak.
- The source-cell adapter phase is completed, deliberately refused and replayed
  using the retained phase allocation. No allocation grows during retry.
- Pending phase preparation refuses. A reader holding a late retirement victim
  refuses the whole batch without releasing earlier victims. Wrong-object and
  duplicate reader returns refuse.
- Each phase also receives an insufficient-capacity request before admission;
  creation, retirement and live-byte counts remain unchanged.
- At the high retained frontier, an additional 8.125MiB geometry revision is
  refused before allocation while both current geometry members remain held.
  The request would exceed even the original 64MiB cap. Concurrent geometry
  replacement therefore still needs a scheduling/backpressure policy.
- Seven corrupted schedule variants (overlap, shape, protected retirement,
  byte count, missing protection, boundary gap and cap) refuse before device
  creation. The independent 63MiB control remains refused.

C++ compiles with `/W4 /WX`; the native debug layer reports zero warnings.
The failures are injected validation decisions after successful completion,
not device loss or driver failure. This bounded replay does not demonstrate
arbitrary geometry mutation or indefinite steady-state memory behaviour.

## Next work and open gates

Replace the warm canary operations with the actual source/head/source-cell/
transport shader graph, using these same native allocations and imported cache
objects. Bind retained bank outputs into the following frame, compare physical
roots and conservation, then enable atomic water-stock and solver-time
publication. Include blocked refresh requests and completed failure/retry in
that physical run.

The **full physical pipeline 64MiB gate remains open**, despite this successful
allocation replay. Native completion does not verify general CSP Canvas
completion/retirement. Target GPU/CPU timing, common optics, long warm runs and
live integration remain open. Main app, settings, production shaders/assets,
installed game and Git HEAD are preserved; stamping remains with the user.

Evidence: `diagnostics/2026-10-20/s190/allocation_checks.json`, native allocation
and phase reports, frozen schedule/certificate, complete cold proof, refusal
records, source diff and `delivery.json`. Earlier builders were not rerun.
