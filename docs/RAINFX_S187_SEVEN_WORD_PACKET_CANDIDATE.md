# s187 — exact seven-word End/Mean storage candidate

Status: implemented and verified offline, **not adopted as the default**,
2026-10-20. Runtime physics remains s87, diagnostics s89. No user game test.

## Representation

The two logical packets contain End volume/momentum and Mean volume/momentum.
Their volume bits are equal. Force preserves the same volume in both responses;
the gathers integrate them with the same donor weights and compensated order;
post force explicitly assigns Mean the remaining End volume. This permits
storing seven FP32 words instead of eight without quantizing momentum or
changing the internal Mean model.

The candidate keeps the End image intact and packs the three Mean momentum
components into a dense RGBA32F tail. Readers recover Mean volume from End.
Logical integer Load bounds still return zero outside the two logical banks;
wrong physical extent returns a negative-volume error marker. The physical
image is W×(H+ceil(3H/4)); at1024×256,512 rows become448 and **8MiB becomes7MiB**.
No additional texture binding, GPU draw or completion boundary is introduced.

All four private two-bank intermediates change together: force target26, first
gather38, second gather43 and post-force44, across eight modeled quarter stages.
Changing only force would split the previously shared typed slots and increase
the phase floor to73,390,928B, exceeding64MiB. The implementation preserves exact
typed pooling and never reinterprets a larger backing as a smaller image.

The shader adapters cover direct texture loads/dimensions and the generic
End/Mean row-bank helper. Physical dimensions are distinct from the logical
two-bank dimensions. The native preflight refuses wrong extents or a missing
consumer grid before creating a device. External roots remain in their original
layout; no new Mean consumer is enabled.

## Accuracy and guards

- **615 native recurring draws /37 real completion events /4 bank copies**:
  physical outputs, inventory images, water and time match s185 byte for byte.
  Failed cache/source/copy attempts, retry, replay refusal, pending work, retained
  old readers and insufficient-capacity protections are preserved.
- **153 standalone actual-grid operator draws**: accepted, rejected and accepted
  continuation cases match every frozen s181 root. All12 produced intermediate
  End/Mean images also match their unchanged logical producer bit for bit, with
  equal volume bits verified before packing. Their hashes are recorded and
  complete final root arrays are retained.
- **10 codec draws** cover1×1,13×7,8×4 and1024×256 grids, signed zeros, row and
  word crossings, padded tails, logical outside reads and wrong physical extents.
  Python refuses mismatched volume bits, opposite zero signs, nonfinite data
  and non-FP32 input without mutation.
- Float vector indexing initially canonicalized some negative zeros. Word
  selection now uses unsigned integer bit moves and reconstructs with `asfloat`.
  FXC's wrapper inlining also required explicit result/scratch initialization.
  Every shader used by the final experiment compiles with warnings as errors;
  native code uses `/W4 /WX`, with zero debug warnings.

Total final validation workload is **778 draws**:615 recurring,153 actual
operator and10 codec. Standalone draws are validation work, not extra passes
added to the recurring pipeline. The physical response, integration, projection
and compensated summation formulas remain unchanged.

## Capacity and allocation traffic

Independent typed-shape witnesses reduce the phase floor by **2MiB**:

| Metric | s185/s186 | Seven-word candidate |
| --- | ---: | ---: |
| Phase floor |67,099,472B /63.991043MiB |65,002,320B /61.991043MiB |
| Permanent exact-shape pool reservation |69.807526MiB |75.807526MiB |
| Warm peak with a63MiB retention cap | refuses |65,858,464B /62.807526MiB |
| Margin to the original64MiB descriptor budget |1,120B at64MiB cap |1,250,400B at63MiB cap |
| Cumulative creations over two modeled frames |87,677,856B /111 objects |107,801,504B /106 objects |

The smaller cap is a stricter candidate retention limit, not an increase of the
original64MiB budget. All524-resource lifetime certificates pass; resource
identities, reads, lifetimes, producers, static data and completion boundaries
are unchanged. At64MiB retention the new candidate still creates106,556,320B;
the traffic increase is not solely a consequence of the stricter limit.
The permanent pool grows6MiB because smaller private shapes no longer share
all slots with unchanged8MiB shapes elsewhere. This candidate therefore still
requires explicit retirement and must not replace the permanent-pool fallback.

The small224KiB native owner also worsens:222→226 creates,406→402 reuses,
14→17 evictions and227,968→229,312B peak. Audit staging remains282,096B and is
counted separately. These are default-texture descriptor counts, not total VRAM
or process memory; driver, staging and CPU fixtures are excluded.

## Cost decision and next work

The tail needs two logical Mean-cell evaluations per physical output pixel.
On the aligned actual grid this raises logical producer evaluations from2N to
2.5N, **25% more evaluations** across the packed producers. It is not a claim
of25% greater total frame time: compiler elimination, gathers and memory loads
have different costs. Mean reads also require the End volume and up to two
momentum texels instead of one original packet load. Target GPU/CPU timing has
not been measured.

The candidate supplies useful capacity relief and preserves exact output, but
adds creation traffic and shader work. **Keep the s185 default policy/storage.**
Preserve this codec as an experimental reference. Next evaluate whether paired
End/Mean results can be emitted once per cell through an explicitly supported
output layout, sharing donor traversal and avoiding the tail's repeated
evaluation. Confirm backend/API support and recompute typed-pool traffic before
adoption; do not assume general CSP multi-target support from native D3D alone.

Complete actual-grid joint cache/source/head/transport ownership, cold and
changing-pose overlap, CSP completion, common optics and live adoption remain
open. The whole-pipeline64MiB adoption gate remains false. Main app, settings,
production shaders/assets and installed game are preserved. Git stamping stays
with the user.

Evidence: `diagnostics/2026-10-20/s187/storage_checks.json`, native output and
inventory archives, codec checks, actual-grid roots and intermediate digests,
compiled shader hashes, pre-device refusals, modeled plans/certificates/floors,
source diff, archive manifest and `delivery.json`. Frozen earlier builders were
not rerun.
