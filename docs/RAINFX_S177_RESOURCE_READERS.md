# s177 — resource-specific readers and completed preview retirement

Status: native reference verified, 2026-10-20. Main game physics remains s87;
diagnostics remain s89. This stage changes the offline cache component only.

## Change and dependency boundary

s176 leases retained a whole generation when an observer needed its header,
world metric and geometry. That also retained the old8MiB force,4MiB resolved
cells, intermediate audit outputs and uploaded preview headers during the next
pose replacement. Those outputs had completed their last consumer and audit.

s177 readers own an explicit immutable set of resource pointers plus an attempt
identity. Geometry observers request only header4, metric5, head lookup50 and
the three dictionary textures35/36/49. Force observers request43 separately.
The original full2048×512 geometry resolution and FP32 dictionary are unchanged.

After native completion and full output audit, an explicit retirement batch
returns39/40 and41–48. The force audit chain44→45→46 and the resolved-cell
receipt47→48 have all executed before this return. The head lookup50 remains
available; cache3/4/5/6/8, dictionary35/36/49, controlled stock38 and positions51
are protected. A held geometry reader does not retain unrelated outputs.

An observer of force43 prevents its retirement. In the tested pose transition,
even after returning every other preview object, that8MiB observer makes the
64MiB preflight refuse the next batch without allocation or submission. Returning
that observer and then its force texture permits the same context to proceed.
The owner does not evict a requested resource to meet a budget. Retired outputs
cannot be acquired again from that generation; a later frame computes fresh
ones. This diagnostic component does not have downstream SI head/film consumers:
their last reads must be incorporated before applying the same policy there.

Retirement validates the entire batch before any mutation. Pending, unaudited,
failed, stale, missing, duplicate, protected and leased requests refuse. Each
reader return is single-use and bound to its attempt. A reader with submitted
copies cannot return until its own real D3D event completes. Previous readers
retain their exact objects across publication. At most two generation identities
and two queued contexts are admitted; an older reader still blocks a third.
Failed preparation is quarantined and explicitly disposed before retry, without
popping its context or changing published stock, header or time.

## Verification

The frozen s176 executable and new s177 executable run the same four encoded
programs on native D3D11 WARP. All new output goes into the s177 evidence folder;
no earlier builder or finalizer runs. Both paths execute83 draws, including the
same full34-pass cold construction and four head-geometry readers. s177 has13
observed completion events versus11: two additional force-observer read audits,
not extra solver work. Native C++ builds with `/W4 /WX`; the debug layer reports
zero warnings. All19 previously strict-compiled shader bodies are hash-verified
and reused; no shader or physical equation changes.

- **89,328,208 FP32 words** match the s176 path bit for bit. Full cache, force,
  resolved-cell, dictionary and head outputs also match the frozen s173 references
  or original full-resolution geometry expectations.
- Four independent double-precision SI force checks pass the inherited32ε gate;
  maximum normalized ratio is0.399833. Weather and rotated-pose outputs still
  differ as expected; failed preparation and retry retain identical inputs.
- Four explicit reader audits cover two force observers and two previous cache/
  geometry observers. All four premature GPU-reader returns refuse.
- Fourteen retirement refusals cover the protected/leased/state/batch cases.
  Forty completed preview objects return over four successful frames. Queue,
  failure/retry, immutable-input and premature publication checks remain active.

## Memory result

| Native cache component | s176 baseline bytes / MiB | s177 bytes / MiB |
| --- | ---: | ---: |
| Cold construction maximum |48,490,144 /46.243805 |48,490,144 /46.243805 |
| Maximum across replacement and retry |73,797,408 /70.378693 |**61,197,008 /58.362015** |
| Final retained set |48,351,120 /46.111221 |**35,750,720 /34.094543** |
| Separate audit staging maximum |48,333,760 /46.094666 |48,333,760 /46.094666 |

The replacement peak and final set each decrease12,600,400B /12.016678MiB.
The scoped default-texture descriptor peak now fits64MiB with5.637985MiB margin;
new-frame allocations and reservation preflights use an actual64MiB component
cap. The unchanged cold builder also stays below that descriptor ceiling.
Dictionary retention remains8.718750MiB and full raw du/dv uploads remain zero.
The held-force case retains42.094543MiB; its explicit return leaves34.094543MiB.

These are texture descriptor bytes, not resident VRAM. CPU fixtures, driver/
shader allocations and **separate46.094666MiB staging** are excluded. This is
not a64MiB total-process or whole-application result. No target GPU time/FPS
improvement is measured. The full source/head/transport/bank/time graph is still
not combined with this cache owner; the frozen89.823166MiB warm whole-plan
proposal remains above its total64MiB gate and is not revised by this result.

## Next integration

Compose the actual-grid physical pipeline's last-reader lifetimes with this
cache policy, reduce disabled-input residency and owner overlap, and verify a
complete allocation/stock/time transaction before runtime adoption. Force and
resolved-cell outputs must survive their actual physical consumers in that
composition. Native D3D events do not establish general CSP Canvas completion.
No solver clock, live physics, installed game files, settings or assets change.
No user game test is requested for s177; Git stamping remains with the user.

Evidence: `diagnostics/2026-10-20/s177/resource_checks.json`, native reports,
full-grid snapshots, `numerical_audit.json`, archive manifest and `delivery.json`.
