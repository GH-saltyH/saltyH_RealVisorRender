# s186 — retirement policy comparison and typed phase floor

Status: offline policy code, two native recurrence experiments and independent
phase witnesses verified, 2026-10-20. Physical runtime remains s87, diagnostics
s89. No new game test is required.

## Decision

Keep s185's largest-first retirement. Four alternative policies all create more
textures and more cumulative texture bytes in the unchanged two-frame warm plan.
The new selector admits a replacement only if peak bytes, creation bytes and
creation count do not increase. This is a regression guard for this declared
plan, not an adaptive live allocator or a proof of global optimality.

| Modeled policy | Peak bytes | Created objects | Cumulative created bytes | Retired objects |
| --- | ---: | ---: | ---: | ---: |
| Largest first, retained | 67,107,744 | 111 | 87,677,856 | 35 |
| Smallest sufficient single object, otherwise largest | 67,107,744 | 113 | 96,066,464 | 37 |
| Smallest first | 67,099,472 | 156 | 94,255,776 | 90 |
| Oldest request first | 67,101,056 | 145 | 93,574,352 | 77 |
| Least used first | 67,104,112 | 145 | 93,710,320 | 79 |

All five proofs pass the frozen independent 524-resource lifetime certificate.
Each reserves the next phase's exact typed requirements before considering
unreserved free victims. The same original completion boundaries, logical
lifetimes, static inputs and explicit old readers apply. No future pose,
predicted weather or future-request oracle is used. All policies refuse a
63MiB cap. Creation bytes are allocation traffic, not simultaneous residency.

## Native comparison

Both largest-first and best-fit run the same small recurring physical pipeline
at a 224KiB descriptor cap. Each executes **615 draws, 37 completion events,
4 bank copies and 3 publications**. All physical outputs and inventory images
are byte-identical to s185; independent head/source/force/water/time checks pass.
Failed cache/source/copy attempts, retries, replay refusal, old cache readers,
in-flight retirement refusal and atomic insufficient-capacity refusal remain.

| Native policy | Peak bytes | Creates | Reuses | Evictions | Evicted bytes |
| --- | ---: | ---: | ---: | ---: | ---: |
| Largest first | 227,968 | 222 | 406 | 14 | 183,808 |
| Best fit | 229,376 | 224 | 404 | 17 | 175,808 |

Best-fit releases fewer bytes in this small case but creates more textures and
uses the entire cap. It is not adopted. Both builds use `/W4 /WX`, with zero
native debug warnings. Shader bodies, draw count and completion-event count per
experiment are unchanged. The two experiments together execute 1,230 draws and
74 events; they are two runs, not a doubled pipeline.

## Why eviction order cannot provide a practical margin

A new independent calculation ignores the allocator's physical assignments.
For each existing completion phase and each exact typed shape, it finds a set
of logical resources simultaneously alive at a witness event. That shape needs
at least that many backings. Because the owner preallocates the whole phase,
these per-shape requirements must all be reserved even when their respective
witness events differ. Their sum is a lower bound on any policy with this phase
layout, resource lifetimes and typed storage.

The first transport phase, events 55–103, requires at least **67,099,472B**
(63.991043MiB). The independent verifier checks every witness's shape, lifetime,
event and byte count without consulting eviction assignments. Deliberately
duplicated shapes, nonconcurrent resources, out-of-phase events, wrong byte
counts and invalid boundaries are refused.

At 64MiB, the maximum possible descriptor margin in this layout is therefore
**9,392B**. Largest-first currently leaves 1,120B; reordering victims can recover
at most another 8,272B. Smallest-first reaches the bound, at the creation cost
shown above. Continuing to tune eviction order cannot supply substantial room.

The dominant witnesses identify the next structural targets:

- Three 1024×512 RGBA32F backings, **24MiB**: packed world metric plus two
  transport intermediates, jointly alive at event 82.
- Five 1024×256 RGBA32F backings, **20MiB**: initial film/micro bank, source
  film/micro roots and a transport intermediate, jointly alive at event 78.
- Two 1024×151 RGBA32F physical derivative tables, **4.71875MiB**.

The phase floor is specific to preallocation of exact typed backings and the
unchanged schedule. It does not rule out changing shader output layouts,
physical storage, leases proven to have ended, or the allocation schedule.
It is not a general lower bound on all possible RainFX implementations.

## Next implementation

Inspect the two transport intermediates at event 82 and their consumers for an
exact storage/layout reduction, then recompute both phase floor and creation
traffic before constructing full actual-grid joint ownership. Preserve the
internal Mean/End math and established last readers; reducing dimensions alone
has previously increased typed-pool reservation. Add no completion boundary
merely to make the descriptor total fit.

No FPS or target GPU/CPU timing improvement is claimed here. The complete
actual-grid cache/source/head/transport owner, cold and changing-pose overlap,
general CSP completion, common optics and live adoption remain open. Default
texture descriptor counts exclude audit staging, CPU fixtures and driver/shader
allocations. The 64MiB whole-pipeline adoption gate remains false. Main app,
settings, production shaders/assets and installed game are preserved. Git
stamping remains with the user.

Evidence: `diagnostics/2026-10-20/s186/policy_checks.json`, five policy proofs and
certificates, `phase_floor.json`, independent floor certificate and negative
controls, both native output archives/reports, source diff and `delivery.json`.
Earlier frozen builders must not regenerate their evidence.
