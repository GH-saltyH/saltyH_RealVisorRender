# s165 — new-frame queue and native cache replacement

Date: 2026-10-19. Status: ACTIVE (offline native diagnostic).

## Scope

Continue s164's real typed pool across four distinct context snapshots. The
snapshots change frame identity, dt, SI air/acceleration inputs and world pose.
The solver pixel shaders and physical tolerances are unchanged. This step uses
explicit **zero incoming water source**, 1µm initial film, 0.1µm pinned micro and
4096 empty/pinned head slots on the actual1024×256 bake. It does not evolve
birth, impacts, spray or heads, and does not implement a complete new-source
handoff. The inputs are controlled fixtures derived from captured frame660,
not four new engine captures. No display gain enters the physical packet.

## Boundary implementation

`s165_frame_stream.cpp` adds a bounded two-frame waiting queue around the frozen
s164 execution. Admission copies CPU context data and requires the next token;
duplicate, altered, unknown-cache and full-queue inputs are refused. A full
queue leaves the producer owning its unaccepted frame; resubmission succeeds
after space is available. These fixture receipts identify prevalidated test
packets, not authenticated engine input or a general asynchronous scheduler.

For every event, including refusal and failure:

```
accepted time = published time + active dt × remainingTicks / 1048576
                              + sum(waiting frame dt)
```

Each frame publishes four quarters. A next context cannot prepare while a
solver flight is outstanding, an observer holds outputs, or active time debt
remains. Returning the output observer is explicit. A dedicated32-byte pending
checkpoint prevents context preparation from changing the last published
checkpoint. Stock, cumulative ledger and published time advance only after a
valid substep and real native event completion; failure preserves the debt.

### Cache replacement

The private cache has a fixed topology and unit world scale. A90° world-Y
rotation is generated using the existing GPU metric producer and scalar-area
producer. Actual full-grid area bits remain identical; metric U/V and Gram
comparisons pass the inherited bounds. This does not cover scale, topology,
material or resolution changes, which require a different rebuild contract.

After all readers return and the flight completes, the three consumed cache
backings may be updated in place. The cache/context become unavailable during
preparation. Exact payload component comparison skips unchanged connected runs
and R32 area. A failed preparation remains quarantined until a successful retry
and a real event; the solver cannot consume it. An old cache is not available
concurrently during replacement. General cross-context/CSP cache reuse is not
authorized by this native policy.

Two pose replacements plus one injected failed preparation/retry upload the
12MiB metric three times: **36MiB**, rather than51MiB for three full17MiB bundles.
Six unchanged component uploads are skipped. All three consumed arrays are
read back on changed-cache preparations, including failure. The other31 retained
cache textures remain charged descriptor placeholders, not revalidated data.
Two CPU cache receipts occupy34MiB in the actual fixture outside the GPU cap;
this implementation stages replacement bytes on the CPU and makes no transfer
latency or target-GPU performance claim.

## Verification

| Check | Result |
| --- | --- |
| Fixtures / storage modes | Planar13×7 and actual1024×256; separate and typed pool |
| Solver draws | 3,024; existing29 frozen pixel-shader binaries |
| Cache preparation draws | 2, strict warning-free compilations |
| Actual native completions | 72 solver events +16 context-preparation events |
| Published quarters / discarded solver candidates | 64 /8 across four runs |
| Per run | Four frames,16 publications,18 solver submissions, queue peak2 |
| Controlled failures | Completion failure; bad debt; failed cache preparation |
| Input / public-root comparisons | 792 immutable-import and48 preparation-root checks |
| Separate vs pool | All18 root-parent payload sets bit-identical per fixture |
| Prior numerical baseline | First actual frame's four quarters equal s164 root bytes |
| Time closure |59.377173893ms accepted/published; maximum residual0 |
| Water closure | Every published stock/ledger satisfies inherited128ε /1e−9 bounds |
| Malformed stream controls | Scope, cache count, payload extent and trailing bytes refuse before engine construction |
| Debug layer | Enabled in all four runs; no warnings/errors |

The native cache-completion failure is injected into the completion latch; it
is not a simulated GPU device removal. Even on failure, actual completion must
arrive before cleanup/retry. The same restriction applies to solver failure.

## Cost and limits

Actual typed default-texture descriptor peak is **66,298,544 bytes =63.227219MiB**,
32 bytes above s164. The64MiB margin is810,320 bytes. There are78 retained native
textures,35 private slots and595 cross-flight slot assignments reused across18
submissions. The separate reference uses91.243225MiB. No new texture allocation
is needed during context preparation or cache retries.

This is not a64MiB total process or a measured hardware-residency result.
Audit staging separately reaches78.188721MiB; CPU fixture/results, source-image
caches, driver state, shaders and constant buffers are outside the gate. A CPU
poll/readback is used for diagnostics. Rendering throughput, input arrival at
real frame cadence and long warm runs are unmeasured.

Main app, settings, production shaders and game installation remain unchanged.
Native immediate-context events do not establish CSP Canvas completion. Current
game physics remains s87, diagnostics s89; the s91+ solver is still offline.

## Next implementation

Add a bounded nonzero source/head handoff to this retained stream: consume each
new frame's conserved source exactly once, retain birth/head inventory and its
leases, and recount allocations before adding passes or observers. Validate
source-off/on and rejected/retried handoffs before common optics and target
timing. Then choose a supported actual CSP completion/ownership boundary and
request focused game measurements. No additional game test is required for s165.

Evidence: `docs/diagnostics/2026-10-19/s165/stream_checks.json`, four native
reports and traces, strict rotated-cache build, archived binary inputs/roots,
`source.diff`, `archive_manifest.json` and `delivery.json`. Previous sources and
evidence are preserved; no earlier stage's builder/checker was rerun.
