# s169 — binary boundary storage and independent-resolution consumers

Date: 2026-10-19. Status: ACTIVE (offline native component).

## Implementation

`prototypes/s169/s169_boundary.lua` composes the preserved s146 birth and s148
SI-head recipes with a typed, independently sized boundary input. It changes
boundary reads from alpha to red, replaces metric-indexed support reads with
coordinates calculated from the boundary's own dimensions, and removes the
old requirement that boundary and metric dimensions match. Head metrics remain
full-resolution FP32. The volume, force, contact, impact, merge, trail-transfer,
evaporation, exit ownership and numerical admission equations are unchanged.

The adapter supports R32F and R8 UNorm for the current binary boundary ABI.
Dimensions, domain, format and immutable payload identity are checked before a
recipe is returned. The identity is a provenance reference, not proof that
arbitrary submitted pixels are binary or complete. A resource owner must verify
the payload and retain it through its consumers; this step does not connect a
new live owner. All reads use point `Load`, with explicit clamp and outside
support rejection. No linear-filter or mipmapped equivalence is claimed.

The stage-private native loader validates binary float payloads before encoding
them as bytes 0/255 and creating a real `DXGI_FORMAT_R8_UNORM` texture. Fractional,
negative, above-one, nonfinite and negative-zero inputs are refused. A future
antialiased/fractional boundary requires a different contract and validation;
it must not silently be quantized by this adapter.

## Evidence and controls

The actual `texture/RAINFX_ObjNormal_BoundaryMask.dds` alpha decodes to binary
values. Every one of its **4,194,304 texels** reads back with identical FP32 bits
from native R32F and R8 inputs. The owned boundary descriptor changes from
16,777,216 to 4,194,304 bytes: **12MiB saved**. Source DDS/engine image caches and
CPU upload buffers are separate; their storage is not removed by this result.

Validation includes:

- Eight preserved physical fixtures: birth incidence, occupied slots, pool
  return and stale context; SI force/transfer, full-generation merge, immediate
  exit and missing birth receipt. Every recipe root matches the frozen legacy
  output bits with both R32F and R8 inputs at the original dimensions.
- Birth and head graphs with 13×7 boundary versus 8×4 metrics, both solid and
  holed. Typed red inputs are compared to an expanded RGBA alpha reference that
  independently addresses the same high-resolution mask. This reference is
  explicitly distinct from the old metric-indexed binding.
- Actual 2048×512 du/dv and 4096×1024 boundary point consumers, compared against
  an independent CPU addressing oracle at 8,192 deterministic locations,
  including exact corners and outside-domain points. Geometry is not resampled.
- A one-texel hole in a 256×32 mask crossed using 8×4 metrics. R32F/R8 advance
  results match; the hole causes exit while an otherwise identical clear lane
  moves. The existing adaptive step law and 128-step refusal limit remain.
- A deliberately wrong alpha-channel consumer demonstrates why scalar inputs
  cannot be passed to an unchanged alpha reader. Binary upload checks exist on
  both the Python fixture side and the native loader. Malformed descriptors
  refuse before graph construction.

Strict shader compilation uses `/Ges /WX`; native draws use WARP with the D3D11
debug layer and refuse warning/error messages. Readback synchronizes these
isolated native draws. It does not establish a general CSP Canvas completion
fence, target-device frame time or game behaviour.

Saved layouts, root hashes, numerical outputs and source fingerprints are in
`diagnostics/2026-10-19/s169/`. The actual-mesh test exercises input addressing,
not evolving head/film physics. Full producer comparisons use the specified
small fixtures; 4096 active heads, recurrent curved motion, queue replacement
and common optics remain untested by this component check.

## Budget and remaining work

This validates one of s168's proposed storage changes in an isolated native
component. It does not pass the combined 64MiB gate. Subtracting the verified
12MiB descriptor saving from s168's retained-cache minimal proposal still gives
69.546MiB static, 110.687MiB simultaneously live and 121.501MiB typed reservation.
These are updated descriptor estimates, not measurements of a combined run.
Even static inputs remain above the existing total cap.

Core-cache retirement remains an unimplemented ownership proposal. With that
additional assumption, the existing R8 candidate is still 102.289MiB live and
113.103MiB reserved. The static64+working64/total128 alternative remains
**analysis only, not adopted**. No solver admission or actual resource reuse is
authorized here.

Next implement and verify resolved source cells from the raw coverage and
scalar physical-area cache, then check packed-End view adaptation and recount
joint retention. Full-grid native composition, bounded new-frame ownership,
physical closure, CSP completion, common optics and target-device cost must
still pass before game adoption. Main script, shaders, settings, source textures
and installed game files are unchanged. No user game test is needed for s169.
