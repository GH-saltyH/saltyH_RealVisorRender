# s252 — last-use storage for bounded GPU continuation (2026-10-23)

## Purpose and scope

s251 lowers preparation cost,but each two-input batch still waits10 engine
frames for CPU confirmation. Longer GPU continuation must avoid multiplying
the162.104MiB working storage. s252 supplies the storage prerequisite:retain
the single-write logical DAG while recycling physical intermediate textures
after their final ordered read. It does not yet increase inputs per GPU batch,
remove a readback or qualify continuous throughput.

## Implementation

`s252_storage.lua` computes first write and last read for each logical resource.
It assigns exact width/height/format matches to a physical slot only when the
previous resource's final read is strictly before the next write. A same-pass
read and write can never share storage. Physical slot selection is deterministic.

The next submission's film/history/checkpoint roots and external dummy frame
are exclusive for the full submission. The final readback texture is exclusive
as well. These five pins cannot be overwritten by intermediate work. In-flight
jobs keep all allocations;the prior receipt still must validate before a new
CPU submission can bind or reuse the owned slot.

The versioned executor rederives and checks the entire storage plan before
allocating. It retains logical single-writer,ordered-input and final-status
ancestry checks. Duplicate handles returned by the backend remain errors;only
the verified map may share an internally allocated handle. Parameters remain
separate per logical pass,including uniform snapshots and receipt values.
Preparation caching,32-call/1ms pre-call dispatch pacing,adaptive retries,
callback validation,time accounting and quarantine rules are unchanged.

| Allocation estimate,one private working set | Previous | Candidate |
| --- | ---: | ---: |
| Logical resources | 155 | 155 |
| Actual owned textures | 155 | 64 |
| Descriptor bytes | 169978048 | 74434528 |
| MiB | 162.104 | 70.986 |
| Draws per two-input batch | 155 | 155 |
| CPU readbacks per batch | 1 | 1 |

This is a56.21% descriptor-byte reduction,not a measured VRAM/frame-time/FPS
gain. Forty-eight physical slots have multiple logical lifetimes. Shader
bodies,uniform words,files,physical model,queue and receipt schema are unchanged.

## Verification

- Independent Python reconstruction checks every alias group's lifetimes,
  shapes,exclusive retained roots and total allocation bytes.
- Eight full-owner/executor command comparisons cover normal,pending,retry,
  slow SDK,synchronous receipt,bad receipt,timeout and cancellation. Accepted
  shaders,uniforms and logical input producers match the old path exactly.
- Eight unsafe controls cover forged mapping/summary/keys,removed retention,
  changed shape,read/write alias and backend duplicate handles. Invalid plans
  fail before allocation;unknown backend allocation quarantines as before.
- Native shader calculations execute1455 draws across changed-input recurrence
  and refused-second-input recovery. Every resulting retained root matches the
  independently executed sequential solver word for word. Storage overwrite is
  simulated with the actual native per-pass arrays. The harness uses separate
  D3D draw invocations;it does **not** establish continuous D3D resource hazard
  handling or actual CSP alias execution.
- Seven actual-adapter mocked panel cases,five lazy default-OFF main host
  guards and three decoder rejection controls pass. Symlinked game sources
  match the workspace. No extra root game helper copy is needed.

## Actual CSP gate

The main app has a default-OFF panel under RainFX → Weather inputs and physical
units (P0):**Enable s252 last-use storage reuse** →
**Run s252 last-use storage reuse once**. Use a fresh unpaused game/replay
session with other diagnostics OFF. Expected normal result:

- observed;2 batches;4/4 inputs;310 draws;64 resources;zero retained debt.
- Two readbacks/disposals;74434528 descriptor bytes retained until session end.
- Four frozen copies of one actual engine context;no continuous-input claim.

## Actual CSP result

Collected with `docs/tools/collect_s252_observation.py`. The actual run is
observed:2 batches,4 inputs,310 draws,64 owned allocations,74434528 descriptor
bytes,2 readbacks and2 CPU-data disposals. Advanced0.0657958984375s;retained
debt0. Both receipts pass the existing GPU header/time/water audit path and
decode as accepted prefix2 with action flags7.

| Receipt | Retained water (mm3) | Cumulative evaporation (mm3) | Cumulative runoff (mm3) |
| --- | ---: | ---: | ---: |
| Initial | 805.772095 | 0 | 0 |
| Batch1 | 805.446899 | 0.023873 | 0.301240 |
| Batch2 | 805.100098 | 0.047747 | 0.624228 |

The captured fields use the unchanged solver receipt schema. This qualifies
the64-allocation reuse path for this bounded private workload;it is not a
full-field bit comparison in CSP or a general GPU completion fence. Native
root comparisons remain the separate evidence for full-field equivalence.
Actual refused-input recovery and longer runs remain outside this capture.

Both callbacks still arrive10 engine frames after request:155.6204ms and
164.1538ms. The warm second batch submits between callback frame1004 and
request frame1009,consistent with the unchanged5-frame32-call cadence.
Readback count/cadence has not improved. Actual CPU/GPU time,FPS and total
driver VRAM are unmeasured;the70.986MiB is the created texture descriptor sum.
The physical storage reuse gate passes without qualifying continuous intake
or visible renderer adoption.

Evidence:`diagnostics/2026-10-23/s252/actual_capture.log`,
`actual_observation.json` and `delivery.json`. Pending source/delivery versions
are archived separately before recording actual results.

## Next

With the bounded actual storage path qualified,extend the GPU-gated continuation window
while keeping this bounded storage model. A refusal must stop the accepted
prefix and retain all unadvanced input time;receipt validation still precedes
CPU publication/reuse. Then connect bounded continuous intake and measure
whether receipt amortization covers incoming time. Public head/film/optics
adoption and representative frame-time/stability gates follow. Current visible
physics remains s87. Git stamping belongs to the user.
