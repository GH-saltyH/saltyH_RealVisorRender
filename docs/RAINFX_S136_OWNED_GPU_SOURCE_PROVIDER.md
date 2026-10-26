# s136 — owned GPU source provider

Date: 2026-10-18
Status: ACTIVE

## 1. Implementation

Replace the six fixed GPU seed passes in the candidate graph with six imported
read leases: packed End/Mean bank, logical End, logical Mean, runs, metric and
interval headers. The 26 downstream passes retain the exact selected mass+face
map bodies, typed uniforms, cache keys, dependencies and six publication roots.
Axis order is selected by topology; source contents no longer come from a seed
shader. Dimensions remain the existing bounded 13×7 test topology and bank ABI.

This is an uninstalled provider/bridge/owner prototype. Production remains s87
physics / s89 diagnostics. Actual CSP immutable input leases and completion are
not established by this stage. Settings, assets and earlier evidence are preserved.

### Files

- `s136_input_recipe.lua`: imports resources1–6 and removes only their seed passes.
- `s136_source_provider.lua`: acquires and retains canonical read leases, validates
  descriptors/revisions, rolls back partial acquisition and returns leases safely.
- `s136_import_bridge.lua`: allocates/disposes only private outputs; borrowed
  inputs remain owned by their provider. Alias validation includes both groups.
- `s136_owned_interval.lua`: composes leases with s135's queue/prefix/publication
  protocol, including source invalidation before preparation, pump and finish.
- `build_s136_provider.py`: derives both bridge/owner extensions using exact
  source anchors and freezes their original and generated hashes. Prior files
  are not edited. Finalization verifies the generated source byte-for-byte.

## 2. Source lease contract

A request binds source identity, source epoch, six resource keys, revisions and
whole-resource descriptors (RGBA32F, one mip, bounded dimensions). Acquisition
must return a stable handle, canonical allocation identity, revision and a read
lease. No subresource views or writable aliases are admitted on this path.
All six acquisitions and validations must succeed before queue acceptance.
Partial failure returns every successful acquisition without allocating outputs.

The **trusted backend contract** must prohibit producer writes while a read
lease is held. Descriptor/revision checks detect reported invalidation; they
cannot detect an unreported GPU write that violates the contract. This stage
does not add a general engine lock, resource hash readback or numerical validity
proof for arbitrary fields. Packed/logical stock coherence and header semantics
remain producer/admission responsibilities; the tested input manifests establish
them for the four specified cases only.

Queued, active and published intervals retain their sources. Once any command
may have been submitted, the provider refuses return until an explicit trusted
completion notification covers the use. Exceptions/non-boolean draw returns
count as unknown submission. Accepted commands, a frame delay or readback are
not used as completion fences. A completed source can be retained for a cancelled
interval's retry; a new submission clears its previous completion state.

On source invalidation, publication is refused. An unsubmitted graph can be
disposed immediately; a submitted graph and its source lease remain held until
completion and discard. The invalid queued record requires reset/replacement,
rather than silently reacquiring newer contents under the old identity. Reset
returns unused queued sources while preserving a submitted old-generation lease.
Reusing sampleId1 in the new generation cannot release or publish the old flight.

The import bridge never disposes a borrowed resource, including failed output
allocation that aliases an input. Canonical allocation checks precede execution.
Release callbacks are trusted and noexcept; acquisition must be transactional
on exceptions. All calls are serialized, and callbacks must not reenter the owner.

## 3. Numerical and lifecycle verification

`check_s136_provider.py` evaluates two real-bake axis orders with baseline and
double-stock inputs. End/Mean mass and momentum and the corresponding packed bank
are scaled together. Geometry, runs, headers and dt remain unchanged.

- **104 WARP draws / 11 strict synthetic shader bodies:** four input-driven
  graphs of 26 passes. Baseline selected outputs match frozen s133 WARP controls
  bit-for-bit. Double-stock inputs preserve map coordinates and scale stocks and
  losses by two, as checked against separately constructed expected fields.
  All **56 selected field checks** pass. Inputs/produced outputs are saved in
  `graph_values.json` for independent final auditing.
- **37 lease/lifecycle cases:** pending/resume, distinct queued inputs, producer
  write refusal, stale results, early source return, cancellation/reset before
  and after submission, reset after publication, unknown submission, allocation
  retry, borrowed/output alias, failed/partial source acquisition, missing
  immutability/capabilities/provider, duplicate offers, and invalid identity,
  revision, descriptor or liveness at multiple phases.
- **4 binding mutations** refuse changed source-request, recipe, typed packet or
  selected-prototype identities before any read lease is acquired.
- Instrumented ownership stays within **26 private canvases and 12 read pins**
  (two six-resource bundles). Every case finishes with no private outputs or
  read pins held. The reset test explicitly overlaps an old flight with a new
  queued input using the same sample ID.

WARP execution uses the existing synthetic adapter, which uploads fixture arrays.
The lifecycle backend replays cached WARP outputs and **mocks** immutable GPU read
leases and physical completion. These tests do not prove persistent GPU input
handoff, zero uploads, game allocator behavior, actual CSP retirement, FPS or
memory savings. The production app has not been changed or installed.

Compared with s135's diagnostic graph, six seed draws/allocations are removed and
six borrowed resources are added. This is a graph-structure result, not a measured
game performance gain. Input validation examines six metadata records per check;
it does not read the full GPU field back to the CPU. Catalogue hashes and output
comparisons belong to the offline harness.

All new-supply accounting remains zero. The fixed test clock is 1,024 ticks at
16,384 ticks/s (dt0.0625). Arbitrary-size live inputs, new birth supply, recurrent
physical closure and arbitrary curved numerical admission are outside this test.
s134's conditional bounds and original exact affine criteria are unchanged.

## 4. Evidence and next implementation

Evidence, per-action lease counts, input/output values, source hashes and final
audit are in `docs/diagnostics/2026-10-18/s136/`. No additional user game test is
needed for this offline step, and no commit or push is performed.

Next exercise imported whole-resource inputs and accepted-prefix behavior on
actual CSP through an isolated probe. Retain all used resources in that probe;
an observation must not grant general completion or repeated reuse. Production
adoption still needs an enforceable producer snapshot contract, live interval
headers/input admission, verified lifetime completion, recurrent accuracy,
unified head/film optics and target-machine cost measurements.
