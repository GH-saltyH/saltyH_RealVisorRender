# s183 — exact integer connected-run storage

Status: offline native cache and physical recurrence verified,2026-10-20.
Game physics remains s87;diagnostics remain s89.

## Working-buffer investigation

The remaining working maximum includes the original physical stock,an8MiB
End/Mean input,the4MiB interval map,bounds and the next8MiB gather output.
End/Mean have distinct consumers inside the two-axis transport. Removing either
without changing those consumers would change the model or its failure checks.

Three simpler descriptor candidates were evaluated against the actual joint
lifetimes. None was implemented or adopted:

| Candidate | Proposed live maximum | Exact-shape reservation |
| --- | ---: | ---: |
| s182 baseline |66.992050MiB |73.807526MiB |
| Half-sized maps,storage-size equivalent only |64.992050MiB |75.807526MiB |
| Final gather End-only |66.992004MiB |77.807526MiB |
| Final force End-only |66.992050MiB |77.807526MiB |

Smaller textures break reuse of larger slots and add another reserved shape.
The map calculation above is only a size-equivalent descriptor experiment;
it does not establish a lossless two-channel map or error encoding. These
candidates are rejected before physical implementation. Internal force/gather
Mean equations and the unchanged external End-only profile remain intact.

## Selected change: discrete topology storage

The connected-support cache contains integer cell-edge coordinates
`(xBegin,xEnd,yBegin,yEnd)` or the invalid sentinel`-1`. For the actual1024×256
field these values fit exactly in binary16. The representation is restricted
to integer values from`-1`through`2048`,with field dimensions at most2048.
Every integer in that range is exactly representable,so this saves memory
without quantizing topology or physical data.

The native cache now renders resource8 directly to **R16G16B16A16_FLOAT**:
**4→2MiB** at1024×256. Shaders still read`Texture2D<float4>`;the typed texture
load returns the same FP32 words. Metric,basis,area,mass,momentum,force and
physical settings remain in their previous precision and units. No shader body,
field sample or physical equation changes,and no new draw is added. Format
load/render support is checked before resource creation;both native paths use
matching typed staging textures.

The private binary descriptor uses storage code2 for this four-channel half
format;it does not mean a two-channel RG32 texture. Allocation accounting uses
8B/texel. Logical uploads/readback still contain four FP32 channels. Half
uploads are permitted only after exact integer/range/bit-roundtrip validation;
the physical pipeline restricts this storage to its run input. The cache owner
restricts it to connected-run resource8. Other physical resources cannot silently
enter this format. Out-of-domain/noninteger/nonfinite inputs refuse before
device creation. Debug readback conversion is outside the GPU solver path.

## Native verification

- The actual-grid cache executes83 draws/13 real completion events across
  initial construction,weather reuse,pose replacement,failure,retry and return.
  All79,891,024 saved logical FP32 words match s182 bits,including full runs,
  cache audit fingerprints,force,resolved cells,geometry and controlled stock.
  Old-reader leases,14 retirement refusals,4 in-flight reader-return refusals,
  bounded queues and held-force behavior remain intact.
- The persistent13×7 field/8-head physical reference executes615 draws/37 real
  events with source ON/OFF/ON,heads,four transport quarters,bank publication,
  failed cache/source/bank candidates,retry and replay refusal. Every retained
  output and inventory image is byte-identical to s181. Independent head/source/
  water/time oracles pass;three publications advance46.875ms without losing debt.
  This physically uploads and samples half-format run inputs on GPU.
- Total evidence is **698 draws /50 completion events**. Draw count is unchanged;
  cache shaders and physical shaders are frozen,hash-verified bodies. C++ builds
  with`/W4 /WX`,and native debug checks report zero warnings.
- Native CPU format checks exhaust all2050 integers from`-1`through`2048`,retain
  signed zero and reject fractional/out-of-domain controls. NumPy independently
  verifies the full integer roundtrip. Three malformed physical inputs also
  refuse before native device construction,without changing the supplied array.

Actual-grid cache and small recurring physics are separate component tests.
They do not execute the complete actual-grid cache/source/head/transport owner.
Native D3D completion does not establish general CSP Canvas completion.

## Allocation and cost

| Actual-grid cache component | s182 | s183 |
| --- | ---: | ---: |
| Cold construction |42.243805MiB |40.243805MiB |
| Replacement/retry maximum |54.096207MiB |52.096207MiB |
| Final retained set |30.094543MiB |28.094543MiB |
| Separate audit staging maximum |42.094666MiB |40.094666MiB |

All four component counts decrease exactly2MiB. Small physical-reference texture
peak remains376,832B;it is not claimed to save another2MiB. Its audit staging
remains282,096B. Descriptor bytes are not measured resident VRAM or total-process
memory;CPU fixtures,driver/shader allocations and separate staging are excluded.

| Full warm descriptor proposal | s182 | s183 |
| --- | ---: | ---: |
| Static inputs |29.850433MiB |27.850433MiB |
| Live maximum |66.992050MiB |**64.992050MiB** |
| Exact-shape reservation |73.807526MiB |**71.807526MiB** |

Independent format-aware lifetime certification passes and all18 physical
force/source-cell last-reader records remain unchanged. The full64MiB gate
still fails:live exceeds it by0.992050MiB and reservation by7.807526MiB.
Cold/changing-pose overlap of the full physical owner remains unexecuted.

This is a low-overhead storage change:half the run-cache bytes,automatic typed
loads,no extra shader arithmetic or draws. Actual bandwidth/GPU milliseconds/FPS
have not been measured,so no speedup is claimed. Future dimensions above2048 or
noninteger run representations require a different admitted format.

Next reduce remaining physical working/bank overlap or other exactly
representable static inputs,then compose actual-grid cache/source/head/transport
ownership with explicit last-reader leases and atomic stock/time publication.
Common optics,live CSP completion and target timing remain open. Main app,
settings,production shaders/assets and installed game are preserved. No user
game test is needed for s183;Git stamping remains with the user.

Evidence:`diagnostics/2026-10-20/s183/runs_checks.json`,native cache/physical
reports and snapshots,`half_contract.json`,negative controls,
`allocation_alternatives.json`,`joint_plan.json`,physical last readers,
`numerical_audit.json`,source diff,archive manifest and`delivery.json`.
Frozen evidence must not be regenerated by earlier builders.
