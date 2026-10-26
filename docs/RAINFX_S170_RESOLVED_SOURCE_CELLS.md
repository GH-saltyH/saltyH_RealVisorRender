# s170 — resolved source cells from coverage and scalar physical area

Date: 2026-10-19. Status: ACTIVE (offline native source component).

## Input contract and implementation

Raw field cells contain `(local area, coverage, coating, version)`. Conserved
source cells require `(physical area mm², coverage, resolved support, version)`.
They cannot share a texture by changing its descriptor label. The new
`prototypes/s170/s170_cells.lua` implements that conversion and composes it with
the unchanged compact s167 source transaction.

The first of two passes validates dimensions, finite full 52-row area-header
equality against an expected immutable context, source token/frame/grid/count
linkage and positive world-area scale. This is a single-pixel receipt; the full
header comparison is not repeated for every cell. The second pass reads raw
coverage and the R32F physical-area cache and publishes the two resolved tags.
It requires exact `area == raw local area × world scale²`, including a positive
area for active support. Raw coverage and coating remain bounded in [0,1].
Canonical all-zero raw cells with zero area become `(0,0,1,1)`.

Malformed cells publish a finite invalid sentinel, not plausible dry support.
The source's existing full-domain tile status then refuses the entire
transaction. Water, momentum, ledgers and checkpoint remain at their previous
values. No physical law or numerical bound is changed. Coating is validated
as an input channel but is not copied into the resolved-support tag.

The Lua contract refuses wrong raw/area domains, formats, missing identities
and mismatched geometry/context/pose identities before recipe construction.
These identities refer to an independently owned immutable resource bundle;
strings alone do not verify arbitrary GPU pixels or resource completion. The
expected header must be a trusted snapshot rather than an alias of a mutable
producer header. This step does not connect the live ownership provider.

Coverage remains separate from area. The source already applies coverage once
to new film/micro packets and sends the remainder to runoff. Existing water is
not multiplied by coverage again. The area cache is therefore neither weighted
by coverage nor regenerated from display diameter or texel gain.

## Native validation

There are **527 native WARP draws, 36 graphs and 10 strict compiled bodies**.
The byte-verified s169 native runner is reused read-only, with private s170
output paths, D3D11 debug validation and `/Ges /WX` shader compilation.

- The verified actual 1024×256 raw/R32F-area/header cache produces all 262,144
  resolved cells with exact expected FP32 bits. All 1,809 fractional-coverage
  cells preserve their physical area and original coverage independently.
- 23 preserved small source fixtures retain all seven public output bits:
  five admit and 18 refuse. They cover partial coverage/runoff, pool funding,
  receipt/generation/frame/phase/history mismatches and rollback.
- The preceding injected `dropped_interior_mask` bin-shader fault is excluded
  from this rerun: its failure is not present in the cell fixture itself. Its
  existing s167 evidence is preserved. The malformed old resolved-tag fixture
  is represented as an invalid raw version, since a resolved tag is not a raw
  coating value; it remains refused with the same public output bits.
- A world area scale² of four gives the original source outputs exactly when
  local area is converted to the same physical area. An existing partial
  coverage fixture is used; particle/display parameters are untouched.
- Ten added source faults—negative or one-ULP-wrong area, nonfinite raw data,
  fractional version, invalid coverage/coating, stale area header, wrong source
  frame and wrong input dimensions—refuse with exact previous inventory,
  cumulative ledger and checkpoint, plus zero step ledger.
- A deliberate second coverage multiplication changes the admitted film,
  establishing a control that detects the unwanted attenuation. Six host
  descriptor/identity guards also refuse malformed contracts.

Saved numerical results, graph recipes, root/input hashes and provenance are
under `diagnostics/2026-10-19/s170/`. The actual-cache case tests conversion,
not evolving curved head/film physics. The source physics cases use the
preserved small fixtures. There is no dense 4096-head timing measurement or
general CSP Canvas completion claim.

## Joint lifetime recount

Two warm descriptor frames now use the real two-pass adapter recipe instead
of s168's synthetic one-pass conversion. Birth/head descriptors use the s169
independent-resolution R8 contract. This is a planning calculation, not an
execution of the combined pipeline.

| R8 boundary / End-copy source | Static MiB | Largest live set MiB | Typed reservation MiB |
| --- | ---: | ---: | ---: |
| Retained cache | 69.545670 | 110.687286 | **121.502808** |
| Proposed core cache | 61.147278 | 102.288895 | 113.104416 |

The 4MiB resolved output was already charged by s168. The receipt can reuse an
existing scalar-sized slot; two distinct 832-byte current/expected header slots
add **1,664 bytes** of reservation. Neither changes the gather-time live peak.
Independent typed-slot/lifetime certificates pass for both updated plans.

A retained cache's original header cannot stand in for a later source frame's
area receipt. The plan explicitly charges a new immutable area-header lease
and a separate expected snapshot per frame. Producing that receipt while
reusing unchanged geometry needs a verified frame/cache owner and is still
unconnected. Cold builds, changing-pose cache replacement/quarantine, queue
backlog, common optics, driver/image caches and audit staging remain outside
the estimate.

The combined **64MiB gate still fails**. Core-cache retirement and the
static64+working64/total128 alternative remain unimplemented/unadopted proposals.
No actual reuse, solver execution or game integration is authorized by these
descriptor plans.

## Next implementation

Verify checked packed-End source views against explicit End copies, then
optimize joint retention and resolve the whole-pipeline budget. A verified
current-frame cache/header owner, native full-grid physical composition,
physical closure, CSP completion, common optics and measured target cost remain
before adoption. Main script, existing shaders/settings/textures and installed
game files are unchanged. No user game test is required for s170.
