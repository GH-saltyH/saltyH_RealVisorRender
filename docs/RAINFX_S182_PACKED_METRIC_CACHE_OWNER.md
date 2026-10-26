# s182 — packed metric inside the actual-grid native cache owner

Status: offline native construction/replacement and physical readers verified,
2026-10-20. Game physics remains s87; diagnostics remain s89.

## Implementation

The s181 two-band FP32 metric is now generated and retained by a private native
fork of the s177 actual-grid cache owner. This connects the real1024×256 metric
producer to immutable cache generations, resource-specific reader leases,
completed-preview retirement, failure quarantine and retry. The producer writes
8MiB directly; there is no12MiB decoded texture or host metric upload in this
path. Field-centre geometry still comes from the full-resolution lossless
dictionary, and the separate head lookup preserves its full-resolution inputs.

Seven strict shader bodies change: metric construction, cache cell audit,
metric fingerprint, cache audit atlas, physical base-plan validation, film force
and force audit. Every metric consumer receives the checked s181 logical reader.
The fingerprint still covers the complete original three-band logical image;
its old expected digest and audit atlas remain unchanged. The native owner also
compares raw packed payloads against independently encoded frozen metric images.
Audit output equality is not used as a general GPU completion fence.

The initial builder and replacement allocator enforce a64MiB component texture
descriptor cap. Legacy metric dimensions, wrong producer extent, wrong consumer
grid and fractional dictionary indices refuse before device construction. All
queued frame descriptors, immutable payloads, shader recipes and captured
header permissions retain the previous checks. No earlier source or evidence
builder is modified or rerun.

## Ownership and numerical verification

Four controlled contexts cover initial construction, weather-only reuse,
rotated-pose rebuilding, failed attempt/retry and return to the original pose.
The native D3D11 WARP path executes **83 draws /13 real completion events**:

- Stored outputs compare79,891,024 FP32 words with the s177 reference. The packed
  metric equals the exact encoding of the original metric, and28,311,552 legacy
  metric words reconstruct exactly across all saved phases. All other retained
  cache, force, dictionary, head lookup, stock and audit outputs preserve bits.
- Four independent double-precision SI force checks retain the existing32ε
  accuracy gate; maximum normalized ratio remains0.399833. Weather and rigid
  pose change force outputs as expected. Failed/retried metric inputs match.
- Four resource-specific read audits protect two force observers and two old
  cache/geometry observers. All four attempted returns before their own native
  completion refuse. Old objects remain bit-identical across publication.
- Fourteen invalid retirement requests refuse atomically. Forty completed
  preview objects return over four successful contexts; protected geometry,
  leased force and pending/failed/unaudited resources cannot be evicted.
- Queue limits, stale frames, immutable payload changes, premature publication,
  failed-candidate quarantine, explicit disposal and new-identity retry pass.
  The final owner has no outstanding reader, retired generation or queued work.

The previous held-force test changes outcome for a concrete reason: retaining
the8MiB force observer through the next pose no longer exceeds this component's
64MiB preflight. The new test admits that pose, retains the observer through a
failed build, confirms the failed cache returns exactly to its prior allocation,
then audits and explicitly returns the observer before retry. Retirement still
refuses while that observer exists. This is added capacity, not a weaker lease
or a forced eviction. The explicit forced-capacity refusal remains tested.

C++ uses `/W4 /WX`; the seven changed pixel shader bodies use `/WX /Ges`.
Native debug checks report zero warnings. Thirteen distinct unchanged shader
bodies remain hash-verified frozen inputs;the generic fingerprint shader still
serves other unmodified resources. Saved finalization checks shader/
program transformations, frozen reference encodings, exact outputs, SI oracles,
admission controls, source SHA/mtime and archive integrity without new GPU work.

## Measured component descriptor allocation

| Native cache component | s177 | s182 |
| --- | ---: | ---: |
| Cold construction |46.243805MiB |**42.243805MiB** |
| Maximum across replacement/retry |58.362015MiB |**54.096207MiB** |
| Final retained set |34.094543MiB |**30.094543MiB** |
| Separate audit staging maximum |46.094666MiB |**42.094666MiB** |

Cold/final/staging each decrease4MiB. The measured replacement maximum decreases
4.265808MiB, **not8MiB**: this run exercises a different admitted lifetime by
holding the force observer through failed pose construction. The peak is exactly
the pinned39,945,024B set plus newly allocated pose resources1/2/4/5/39/40,
totalling56,723,984B. It leaves9.903793MiB below the local64MiB cap. These are
default-texture descriptor bytes, not resident VRAM or total process memory;
CPU fixtures, driver/shader memory and the separate staging allocation are
outside the default-texture count.

## Remaining scope

This composes the packed metric **cache component** at actual grid size and
executes its physical force/resolved-cell previews. It does not evolve water
stock, advance a solver clock or execute the complete actual-grid source/head/
transport/bank transaction. The shared head reader is a geometry lookup, not
an integrated SI head lifecycle. Native event completion proves this private
D3D path; general CSP Canvas ownership/completion remains unverified.

The full warm proposal is still66.992050MiB live /73.807526MiB reserved. This
step realizes the cache-side saving already counted by s181; it does not subtract
another4MiB from that proposal. All18 physical last-reader records remain
unchanged. The full64MiB gate still fails, and no alternate cap is adopted.
Cold/changing-pose overlap of the complete physical owner remains unexecuted.
Target GPU milliseconds/FPS and the cost of reconstructed Gram reads remain
unmeasured.

Next reduce remaining force/map/gather residency while preserving physical
closure, then join actual-grid cache and source/head/transport ownership with
explicit last-reader leases and atomic stock/time publication. Main app,
settings, production shaders/assets and installed game are preserved. No user
game test is needed for s182; Git stamping remains with the user.

Evidence: `diagnostics/2026-10-20/s182/cache_checks.json`, native reports and
phase snapshots, compiled bodies, four pre-device refusal logs,
`numerical_audit.json`, `joint_plan.json`, physical last readers, source diff,
archive manifest and `delivery.json`. Frozen evidence must not be regenerated
by old builders.
