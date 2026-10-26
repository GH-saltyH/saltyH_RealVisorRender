# s121 — immutable graph templates and interval bindings

2026-10-17. **Status: ACTIVE — offline template/provider boundary.**
Production remains s87 physics with s89 diagnostics. The s91+ transport model
is still an offline prototype; this stage adds no game installation or CSP path.

## 1. Registered topology, owned interval data

`s121_graph_template.h` registers a private copy of resource extents, target
slots, pass dependencies, shader/texture bindings, copy regions, lifetimes,
exports, uniform defaults/schema and the complete outgoing root mapping.
Registration runs the full s120 topology validator once. The registry is
noncopyable and bounded to three resident templates in the fixture, with a
16MiB logical metadata charge limit. These charges exclude allocator overhead
and are not measurements of RSS or VRAM.

Each registration returns an owner-identity/generation/ID handle. An identity
token prevents a foreign registry or a replacement at the same address from
accepting an old handle. Clearing the registry invalidates handles for new
bindings. A bound call owns a shared pointer to its immutable template, so a
pending or in-flight call keeps the old topology until retirement. Clear does
not cancel GPU work, change GPU roots or grant early resource reuse.

Per-interval binding accepts a name, epoch, stop/publication choice, links,
sparse uniform overrides, receipt and external-input provider. It checks only
the changing data against the registered schema, then copies uniforms, links,
receipt and external payloads into an owned call. Omitted uniforms use immutable
registered defaults. Unknown pass/name, wrong width or nonfinite values refuse;
bindings cannot change shaders, resource sizes, dependency topology or roots.
Retained inputs still resolve through the engine's GPU-root/epoch guards and
never acquire a CPU view. Every acquired view has a scoped return on success or
failure. Retry uses the existing snapshot without rebinding or reacquiring.

The execution path reads shared resource/pass metadata directly. Constant
packing resolves bound overrides/defaults without copying an `Event`. Shader
reflection and constant-buffer creation still occur per draw; reducing that
work is the next implementation.

## 2. Mutation and lifecycle evidence

The fixture adapter parses a graph once per registration. It saves the actual
uniform values as producer data, registers zero-valued defaults with the same
schema, and immediately destroys/mutates the original graph. Each binding
supplies the actual constants, then its producer uniforms, links, receipt and
input storage are deliberately invalidated. Matching GPU outputs therefore
requires the owned bound values, rather than the zero defaults or producer
storage. The bound call asserts an empty private graph and pointer identity
with its registered topology.

A native contract probe binds two different uniform/input values to one
template, checks independent snapshots and omitted-uniform default fallback,
clears registration, and checks that both calls still own the old graph. A new
registration has a separate identity; stale and unknown handles refuse.
Two additional GPU schedules clear registration while a call is pending and
while its query is in flight. Completion, retry, publication and final roots
remain unchanged. Registry clearing is a test command, not a new CSP API.

The fixture's path-to-handle cache is an offline adapter convention. The typed
API itself accepts no filename or caller-supplied replacement topology on bind.
Static changes require explicit registration; no file-watching or content
authentication is claimed. As in s120, identity labels are not cryptographic
proof of provider data. Producers must keep views stable during synchronous
registration/binding and may mutate them after return.

## 3. Actual WARP comparison

Fifteen schedules run through existing owned snapshots and new templates, each
with full and lean diagnostics:

| Evidence per path | Snapshot/full | Snapshot/lean | Template/full | Template/lean |
|---|---:|---:|---:|---:|
| Host commands | 526 | 526 | 526 | 526 |
| Submitted/finalized flights | 56 | 56 | 56 | 56 |
| Physical draws / region copies | 4789 / 1563 | 4789 / 1563 | 4789 / 1563 | 4789 / 1563 |
| Static template validations | 0 | 0 | 45 | 45 |
| Owned interval snapshots | 56 | 56 | 56 | 56 |
| Provider acquires / returns | 1423 / 1423 | 1423 / 1423 | 1423 / 1423 | 1423 / 1423 |
| Per-flight diagnostic comparisons | 9003 | 0 | 9003 | 0 |
| Outstanding views / backend expected-array bytes | 0 / 0 | 0 / 0 | 0 / 0 | 0 / 0 |
| D3D debug warnings/errors | 0 | 0 | 0 | 0 |

The primary matrix totals2104 commands/224 flights. Physical work, allocator
decisions, root epochs/publication and final actual-GPU bytes agree across all
four paths and with s120. Delayed/failed completion, abort, cancel/reset and
admission recovery remain covered. Reuse removes topology validation/copy from
binding;45 registrations serve56 bindings per template path in these schedules.
These counts are not a measured CPU/FPS improvement.

A template/lean run with absent oracle files opens zero oracles and produces
the same actual final GPU roots. Explicit boundary audits and final GPU dumps
remain test work. The frozen8×32 physical candidates include a refused checkpoint;
224 flights do not represent224 distinct accepted weather intervals. Physical
shader bytecode and formulas are unchanged.

Sixteen negative runs refuse before the candidate submits: invalid resource,
slot, copy region or root schema; foreign/stale handle; undeclared pass/uniform,
wrong width or nonfinite uniform; missing provider input, wrong lease identity,
receipt mismatch, protected checkpoint upload, registry capacity and metadata
budget exhaustion. Partial input failure returns32 earlier acquisitions; the
post-commit upload guard preserves epoch1 GPU roots. An unknown handle is also
covered by the native contract probe.

## 4. Delivery and remaining work

MSVC `/W4 /WX`, the WARP debug layer, independently decoded binary graph/input/
oracle/command/dump data and CPU ownership/publication replay pass. The audit
reconstructs template registration/binding/resident counts for every action,
including clear while pending/in flight. Resident registrations stay within
three. An active binding can retain a cleared template separately; the registry
charge limit is not a total process-memory bound.

Runtime53 Lua/HLSL files, three INIs and299 prior s91–s120 files are preserved
against the438-file baseline. User tuning, materials and assets are preserved.
No installation, reload, repeated game logs, commit or push.

Next prepare reusable shader reflection/constant packing layouts for these
templates, with equivalent ownership and GPU bytes. Live CSP geometry/weather/
head lifecycle, economical physical accuracy/convergence, device recovery and
target CPU/GPU timing remain open. No game FPS or peak-memory result is claimed.

## 5. Reproduce

```text
docs/tools/check_s121_template.py
docs/tools/finalize_s121.py
```

API: `docs/tools/s121_graph_template.h`. Native fixture/engine adapter:
`docs/tools/s121_template_backend.cpp`. Build/helper:
`docs/tools/s121_template_reference.py`. Evidence, compressed split fixtures,
GPU dumps, baseline, diff and independent audit:
`docs/diagnostics/2026-10-17/s121/`.
