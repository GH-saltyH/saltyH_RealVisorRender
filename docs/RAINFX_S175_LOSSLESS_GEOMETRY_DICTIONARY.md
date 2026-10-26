# s175 — lossless full-resolution geometry dictionary

Date: 2026-10-20. Status: ACTIVE (offline native input component).

## Implemented storage and reads

The actual2048×512 FP32 du/dv bake contains153,990 distinct pairs of RGBA
values across1,048,576 pixel positions. `tools/s175_geometry_dictionary.py`
encodes the **eight original float bit patterns** as a shared pair dictionary:

| Storage | Shape / format | Bytes |
| --- | --- | ---: |
| Full-resolution pair index |2048×512 R32F |4,194,304 |
| du values |1024×151 RGBA32F |2,473,984 |
| dv values |1024×151 RGBA32F |2,473,984 |
| Total | |**9,142,272 =8.718750MiB** |
| Original two RGBA32F images |2×2048×512 |33,554,432 =32MiB |
| Saving | |**24,412,160 =23.281250MiB** |

Every original pixel still has its own full-resolution address. Repeated values
share table entries; no neighbouring pixel is substituted, averaged or filtered.
Source values and table entries remain FP32, including signed zero. Exact
integer indices fit FP32 without rounding. Integer-key encoding distinguishes
different float bit patterns. Float64-to-FP32 conversion is refused by the
encoder, rather than silently quantizing a different physical source.

`prototypes/s175/s175_geometry_dictionary.hlsl` decodes point loads through the
index and corresponding value table. Table row widths are powers of two, so
addressing uses masking/shifting rather than variable integer division. The
logical head-sampling domain remains2048×512. The adapter replaces the known
birth/head `Load`, dimension and point-tap forms; unrecognized sampling forms
and repeated adaptation are refused. Independent R8 boundary reads stay as
verified in s169. No display gain, diameter, force, coating, support or normal
formula changes.

The index and both tables must be validated and leased as **one immutable
geometry bundle**. Metadata dimensions alone do not prove payload identity or
GPU completion. This step supplies an offline encoder, receipt and read adapter;
it does not add the bundle to the runtime CSP input provider or authorize
independent replacement of a table while another reader holds its index.

## Native verification

The final suite executes **140 native WARP draws /30 strict shader bodies**
using the preserved single-draw debug runner. No warning suppression or physical
tolerance changes are used.

- Both complete decoded2048×512 images match their source bits:2,097,152 RGBA
  texels total. The full-resolution geometry is not replaced by the smaller
  field-centre cache.
- Both1024×256 exact field-centre reads match the original odd-pixel taps.
  This demonstrates the lookup required by the cache copy producer, without
  executing the complete34-pass native cache owner.
- 8,192 random/edge/outside UV positions per component retain the original
  point-clamp addressing and value bits. Signed-zero controls pass on the GPU.
- Eight complete birth/head fixture graphs retain every preserved s169 root,
  covering normal birth, occupied slots, pool return, stale previous token,
  force/merge, full-generation pairing, immediate boundary exit and missing
  receipt refusal. Accepted and refused outcomes remain unchanged.
- Four further graphs compare original versus dictionary reads with the actual
  du/dv and4096×1024 binary boundary. Every physical root matches. The actual
  head post-force candidate is nonzero and bit-identical.

The last head comparison deliberately retains the planar fixture's external
birth/merge packets. Its final head transaction **refuses in both paths**; the
birth comparison accepts its protocol but has zero incident-impact volume in
this fixture. These are geometry-consumer comparisons, not proof of accepted
curved head recurrence or actual rain supply. The accepted moving-head cases
are the preserved planar fixtures. Full actual-grid joint physics remains open.

Host guards reject negative/fractional/out-of-table/NaN/negative-zero indices,
non-FP32 source conversion and unsupported sampler forms. Finite table shapes,
exact index bounds and power-of-two row layout are checked before binding.
The shader also checks bundle dimensions/count where the existing physical
context validates geometry. These checks do not substitute for future immutable
resource receipts and completion ownership in a persistent provider.

## Joint memory recount

The preserved two-frame End-only warm plan is recertified with the three
dictionary inputs replacing its two full images. The index is read wherever
either component was read; each table retains its component's readers. All three
remain immutable static allocations. Inventory, rollback, working targets,
completion boundaries and required physical outputs keep their prior lifetimes.

| Warm declared plan | Previous MiB | Dictionary MiB |
| --- | ---: | ---: |
| Static inputs |61.147278 |**37.866028** |
| Largest simultaneous live set |102.288895 |**79.007645** |
| Exact-shape pool reservation |113.104416 |**89.823166** |

Every column falls by23.281250MiB. The independent lifetime/slot certificate
passes. The full64MiB gate still fails; no alternate budget is adopted. This
is a descriptor proposal following verified native component reads, **not
execution or measured residency of the complete joint pool**.

The saving requires replacing the old GPU geometry backings, not retaining
32MiB of old images beside the encoded bundle. Cold cache construction,
changing-pose replacement, quarantine/old readers and CSP's own image cache must
all be charged when integrating the bundle. The current s173 cache owner still
uses its original builder uploads; this step does not claim to have removed
those copies or lowered its measured cold/replacement peak.

## Processing cost and next implementation

Lookup adds a dependent table read to each geometry component access. The
compiler can share some common index work, but a memory saving is not a timing
improvement. Static disassembly shows a material instruction increase:

| Selected shader | Original slots | Dictionary slots |
| --- | ---: | ---: |
| Birth trace |778 |1038 |
| Head force |773 |899 |
| Head decode |1279 |1601 |

These are approximate static instruction slots, not executed operations or GPU
milliseconds. Data locality, register pressure and divergent paths need target
measurements before adoption. The CPU sort/unique encoder runs offline; it must
not be introduced as synchronous per-load/per-frame work in the game. A runtime
provider should load a prebuilt bundle and validate the canonical source receipt.

Next compose the encoded input provider with native cache construction and
replacement, including shared head/cache leases. Then reduce the remaining
working and disabled-input costs and recount complete overlap before actual-grid
joint admission. Curved coupling, common optics, general CSP completion and
long warm-run/target timing checks remain.

Main app, production shaders/settings/assets and installed game are unchanged.
No game test is requested. Evidence is in `diagnostics/2026-10-20/s175/`:
encoded arrays/receipt, complete GPU outputs, physical graph hashes, recertified
joint plan, static shader costs, numerical audit and `delivery.json`.
