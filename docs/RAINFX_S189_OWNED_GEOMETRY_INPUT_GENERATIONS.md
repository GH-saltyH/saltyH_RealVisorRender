# s189 — native owned packed geometry generations

Status: actual-grid native cache/preview and separate paired geometry rebuild
ownership verified, 2026-10-20. Main runtime remains physics s87/diagnostics s89.
No user game test is required.

## Native cache connection

The private s184 native cache now uploads the s188 index and packed geometry
table as its own GPU textures. The two derivative preparation shaders consume
the packed input directly. Existing cell words, exact half runs, packed world
metric, force, source-cell and head preview calculations stay intact. Cache
audit values and all logical outputs match the frozen s184 reference.

The old resource49 table is absent from inputs, bindings, proofs and allocations.
Its unused descriptor slot is a1×1 sentinel solely to preserve existing IDs;
**no texture is allocated for that slot**. Seven actual input resources replace
eight. The packed table and index read back bit-identically; decoding the table
reconstructs both original derivative tables, including metadata and signed
zeros. All9,895,936 reconstructed geometry words match. Other stored comparisons
cover78,645,840 FP32 words, with four independent force-oracle checks passing.

Before device creation, the loader validates input types, dimensions, count,
exact word bounds, finite xyz, integer tags, positive-zero padding and integral
indices. Both derivative consumers must bind the same index/table IDs and agree
on metadata. Nine malformed tag/index/extent/binding/metadata variants refuse
without creating the output owner or submitting GPU work.

## Native ownership scenarios

The four-frame actual-grid cache/preview scenario retains its **83 draws and
13 completion events**, including:

- Weather-only input changes sharing completed geometry/metric data.
- Rigid pose rebuilding the required metric and returning to the original pose.
- Failed candidate completion, quarantine, explicit discard and retry under a
  new generation ID.
- Bounded queue, stale/mutated inputs, pending publication, allocation refusal,
  explicit old readers and whole-batch retirement guards.
- Full-frame/cache/preview images identical to their frozen references.

The frame-reader interface additionally refuses index-only or table-only leases.
A geometry reader owns both together. All original frame guard counters remain
unchanged; no old-reader check or retirement condition was relaxed.

A separate geometry-rebuild component shares the **same context and allocation
counter** as the retained cache. It actually uploads three fresh two-texture
revisions of the same asset:

1. Upload and publish an initial complete, audited pair.
2. Hold an explicit reader on that pair; upload a second revision, inject a
   validation failure, observe native completion and refuse publication.
3. Explicitly discard the failed revision, then rebuild/publish revision3.
4. Keep the first pair intact while its reader remains; refuse another candidate
   and retirement, verify both old GPU images, then return the reader once.
5. Retire both old textures together and release the final component revision.

This adds **four real native completion events and zero shader draws**:
three upload/readback events and one pending old-reader readback. The component
checks eight full input images. Wrong-epoch, duplicate and in-flight reader
returns refuse. One failed pair is discarded and one old pair is retired;
each is **8,519,680B /8.125MiB**. The global live count returns exactly to its
pre-test value, with no remaining candidate, retired revision or reader.

The injected failure is a completed-but-refused validation attempt, not a
deliberately lost D3D device or failed driver operation. These are rebuilds of
the **same asset content**, with distinct GPU objects and revision IDs. The
frame cache continues to reject changed dictionary contents; arbitrary asset
hot replacement has not been accepted or tested.

## Measured descriptor accounting

The total experiment is **83 draws /17 native completion events**. Four events
belong to the separate geometry rebuild test, not new per-frame physics work.
The native debug layer reports zero warnings; C++ builds with `/W4 /WX` and
both adapted shaders compile with warnings as errors.

| Native component metric | s189 |
| --- | ---: |
| Initial cold default textures |37,381,792B /35.650055MiB |
| Combined experiment peak |51,907,088B /49.502457MiB |
| Final retained default textures |26,739,520B /25.500793MiB |
| Separate audit staging peak |39,322,560B /37.500916MiB |
| Packed-bundle test peak with base cache |43,778,880B |

Cold, peak and retained default-texture counts are each **622,592B /608KiB lower**
than the frozen s184 owner. Audit staging also falls by608KiB. The isolated
two-revision geometry test stays below the cache scenario's existing peak.
These counts cover allocated texture descriptors, not measured resident VRAM
or total process memory. Staging, CPU fixtures, driver and shader allocations
are outside the default-texture counter; the staging count is shown separately.

## Remaining gates and next work

The s188 two-frame warm joint proposal remains a descriptor proof: its stricter
63.5MiB retention limit and536,672B margin to64MiB have not been exercised by a
complete actual-grid cache/source/head/transport owner. This83-draw cache
component does **not evolve water stocks or publish solver time**. Native D3D
completion also does not verify CSP Canvas completion or resource retirement.

Next compose these owned inputs and resource leases with the actual-grid
physical source/head/transport schedule, using explicit preflight and retirement
at existing boundaries. Include cold construction, failed/retried preparation
and overlap in the complete count. Preserve refused admission if it exceeds
budget; do not substitute a component peak for the whole pipeline. Target
GPU/CPU timing, common optics and eventual live integration remain open.

Main app, settings, production shaders/assets and installed runtime are preserved.
Git stamping remains with the user.

Evidence: `diagnostics/2026-10-20/s189/owner_checks.json`, complete cache/preview
and geometry input archives, `stream_geometry.json`, native allocation reports,
four program snapshots and frozen references, nine pre-device refusals, shader
hashes, numerical audit, source diff and `delivery.json`. Earlier frozen builders
were not rerun.
