# s164 — native typed pool, completion and export leases

2026-10-19. Status: ACTIVE, offline native verification. Production physics
remains s87, diagnostics s89. No main app, production shader, tuning or game
installation changes. No additional user game test is required.

## Implemented execution boundary

The frozen s163 shader binaries run on one D3D11 WARP immediate context with
persistent R32F/RGBA32F textures. A native validator checks typed slot extents,
single writers, ordered reads, exact last-use metadata, no SRV/RTV alias,
generation ownership, retained roots and full-width logical row bounds before
creating a device. No physical shader body or numerical tolerance changes.

An admitted graph reserves all exact-shape private slots before submission.
Every read checks its current logical owner; a write may reuse an expired
owner only after its last command in the same immediate-context order. Imports
never enter writable slots during that flight. Both packed End/Mean views
retain the same physical parent allocation, including the unused input Mean.

After submission, one actual `D3D11_QUERY_EVENT` covers the graph and its audit
copies. Retirement requires `GetData` to return `S_OK` and true. A controlled
Pending or Failed observation cannot fabricate Complete. Failure marks the
candidate abandoned; even a later genuine completion only permits retirement,
not publication. Cancellation and a changed owner generation also suppress
publication. No CPU map, completion wait or resource return occurs inside the
47-pass graph. The runner does wait/read back at its boundary for verification.

On valid completion, one root-map replacement advances the epoch and consumes
one quarter of the interval. GPU film/checkpoint/cumulative-ledger outputs are
borrowed directly by the next flight. Their physical textures are never
reuploaded. Only the48-byte request is updated between completed flights.
No current public result or in-flight import is writable during its lease.

## Observer leases are part of the boundary

The15 exported logical views form a separate observer lease. For example,
`sourceAppliedInput` can retain the preceding bank even after new film has
published. Silently recycling that older bank would invalidate the memory and
ownership argument. This runner therefore refuses a new graph while the
observer lease is held. The caller must explicitly return it after completion.
Core film/checkpoint/ledger roots remain protected for the next flight.

Returning observers makes completed, unbound, unretained surfaces eligible for
the free list. A matching shape/format may then be used in another flight.
This is a deliberately single-flight contract. Overlapping rendering/optics
readers, other contexts and multiple in-flight graphs require additional lease
or ordering work; this implementation does not infer their completion.

## Verification performed

Two fixtures each run in both separate-target and pooled modes:

- Planar13×7 /8 pinned slots.
- Actual1024×256 field /4096 empty head slots, frozen frame660 metric/runs/scalar
  area, controlled1µm film and0.1µm micro. The first two accepted quarters also
  match the saved s163 `actual_physics_yx` and `actual_resume` roots bit for bit.

Each execution submits8 graphs:one cancelled prefix, a completion-status
failure, a stale-generation candidate, four successful quarters and one bad-debt
physical refusal. Shader-ready deferral, capacity refusal and a held observer
lease submit no commands and change no ownership/epoch. Each controlled pending
observation and the injected failure also attempt reentry, which is refused
without allocations or reuse. The ready/pending and failure observations are
test controls, not real shader-compilation or device-loss failures.

All exported parent-image payloads match between separate and pooled modes.
Model refusal restores End into both output bands and preserves checkpoint and
ledger. Accepted inventory and cumulative closure meet the unchanged128-epsilon
and1e−9 packet bounds. GPU checkpoint debt follows3/4,1/2,1/4,0 of the frozen
interval. Cancelled/failed/stale candidates never advance the published roots.

Before/after GPU snapshots verify all11 imports remain unchanged in each
flight. D3D debug layers are available in all four runs and report zero warnings
or errors. No produced physical target uploads after initialization.

Totals:1,258 solver draws,32 submitted/completed GPU event fences,16 successful
publications,16 discards and352 immutable-input comparisons. Six malformed
graphs (slot format, live alias, row-band bounds, forward read, import-in-pool
and trailing data) refuse before device creation.29 existing pixel-shader
binaries are consumed unchanged. The native runner uses `/W4 /WX`; its vertex
shader uses strict/warnings-as-errors flags. Final builds are warning-free.
An initial Windows text-mode binary-dump bug was corrected by opening that
audit file in binary mode; the malformed initial dump is preserved as evidence.

## Allocation result and scope

| Actual fixture, one execution | Separate targets | Typed pool |
| --- | ---: | ---: |
| Default texture descriptor peak |91.2432MiB |**63.2272MiB** |
| Distinct texture allocations |89 |77 |
| Private targets/slots |47 |35 |
| Cross-flight slot assignments reused |329 |245 |
| Published quarters |4 |4 |

The pooled peak is exactly66,298,512 bytes, matching s163's scoped reservation.
After the initial slot allocation, all seven following flights reuse the35
slots with no further texture creation. The margin beneath64MiB remains810,352
bytes (0.7728MiB). Separate mode uses a256MiB reference cap; pooled mode uses
64MiB. The refusal control does not raise either execution's cap.

The count deduplicates shared17MiB metric/runs/R32-area imports. Thirty-one
additional native textures mirror the other retained s163 cache descriptors;
their contents are retention placeholders, are not sampled by the solver and
are not claimed revalidated here. The three consumed cache arrays come from
the verified field archive. All34 cache allocations remain charged, with no
inferred release of an old CSP cache. No game cache was allocated or recycled.

This result is actual native texture creation and reuse, counted by requested
descriptors. It is **not measured hardware VRAM residency or game memory/FPS**.
Driver/shader/constant-buffer costs and source-image caches are outside this
cap. Audit staging reaches78.1887MiB separately in the actual run; host fixtures
and result dumps add CPU storage. The verification process is not a64MiB total
memory application. Active head/birth evolution, new weather/pose snapshots,
accuracy-controller alternatives and concurrent readers remain excluded.

## Limits and next implementation

Native immediate-context order and event completion are exercised for this
runner. General CSP `Canvas:update` completion and cross-context authority are
still unverified; the native event is not a CSP fence. No s91+ solver is added
to the game, and no target-GPU timing or speedup is claimed.

Next connect a scoped input/completion/lease boundary to repeated new frame
snapshots, with bounded cache replacement and backlog. Preserve explicit
observer returns and atomic stock/ledger/debt publication. Then integrate the
head/birth pipeline and common optics budget before deciding actual CSP
admission and requesting game cost/quality tests. The0.7728MiB margin must be
recounted for each additional retained input, diagnostic or in-flight reader.

Evidence: `docs/diagnostics/2026-10-19/s164/pool_checks.json`,
`actual_layout.json`, `cache_descriptors.json`, four native reports/traces and
binary root dumps, six refusal controls, native build artifacts and
`delivery.json`. The prior s163 sources, compiled shaders and evidence are
preserved without rerunning their tools.
