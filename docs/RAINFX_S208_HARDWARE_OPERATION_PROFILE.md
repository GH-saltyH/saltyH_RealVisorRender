# s208: explicit hardware operation profile and a release recurrence refusal

2026-10-21. Parent s207. Status: ACTIVE. Private native D3D11 on RTX 3070.

## Result

The admitted physical consumer now records the modeled explicit draws, uploads,
copies, allocation APIs, readback stages and event polling/sleep separately.
The solver, shader binaries, exact predicates, event schedule and wait policy
are unchanged. Bootstrap/input preparation is separated from recurrent work.

The debug run publishes all 256 intervals (4.320556640625 simulation seconds)
and matches the s207 hardware reference in complete saved GPU bytes, stocks,
ownership traces and time. All 11,850 typed inventory snapshots match after
normalizing process-local diagnostic identities. The forced stop still publishes
26 intervals, retains 29 accepted intervals and protects the prior bank and debt.
The scoped default-texture peak remains 66,582,496 B under the 66,584,576 B cap;
all counted default textures retire in the completed runs.

An initial release run refuses a new metric cache at frame index 8. This is a
correctness failure, excluded from full-run timing. A separate executable with
a CPU-only failure capture branch subsequently completes and matches all parent
bits. A repeat of the original release executable also completes with full-byte
parity. These passing observations do not erase or explain the first refusal.
Release recurrence qualification remains open. No tolerance or acceptance guard
is relaxed; no failing metric is published. See the saved audit for every run.

## Measured debug costs

These are instrumented, ordered native observations of the frozen workload,
not game FPS or a real-time throughput promise. GPU intervals overlap CPU waits
and must not be added to them. Timestamp intervals are not GPU busy counters.

| Measurement | Debug full run |
| --- | ---: |
| Recurrent host wall time, including proof/diagnostics | 123.3614 s |
| Event completion wait blocks | 113.3217 s |
| Actual elapsed time in requested 1 ms sleeps | 113.2099 s |
| Sleep calls / mean observed duration | 7,957 / 14.2277 ms |
| Sleep fraction of recurrent host wall | 91.771% |
| Actual `GetData` event-poll API blocks | 0.1015 s |
| Explicit GPU command interval sum | 24.1572 s |
| Adaptive bound draws, previously omitted | 11.0862 s |
| Remaining physical draws | 11.1959 s |
| Stock reduction draws | 1.1813 s |
| All explicit uploads | 0.0170 s |
| Typed inventory serialization/flush blocks | 3.2913 s |
| Startup through index/owner preparation | 12.3868 s |
| Startup input decode, validation and file hashing block | 10.8105 s |

The unchanged sleep request is measured directly; the results establish elapsed
oversleep in this process. They do not establish the OS/driver root cause, GPU
idle duration or equivalent behavior inside CSP. No timer-resolution setting,
extra flush, spin loop or completion wait is introduced.

The largest individual shader interval is adaptive-bound producer
`physical_2489be82940ff10a647d.cso`: 1,051 draws / 10.8192 s. Its paired reduction
brings the adaptive-bound group to 11.0862 s. This was absent from the old coarse
GPU totals. Per-shader tables, CPU API counts/bytes and startup measurements are
saved in each `run.timing205.json` and `run.startup208.json`; the filename suffix
is retained for reader compatibility, while their new fields identify coverage.

The successful release diagnostic observation has 123.3432 s recurrent wall,
114.0693 s sleep, a 14.3700 ms mean requested-1-ms sleep and 23.8404 s explicit GPU
intervals. It corroborates the cost pattern only. It is a different executable,
not evidence that the original release refusal is resolved or a speedup sample.

The repeated original release executable (`release2`) completes in 122.1532 s,
with 113.1808 s sleep (14.3959 ms mean) and 23.3751 s explicit GPU intervals.
It matches the debug/parent outputs and all 11,850 inventory snapshots. The
initial failure is therefore intermittent across the original consumer's runs;
the available observations cannot attribute it specifically to debug-device mode
or to the diagnostic branch. No controlled debug/release speedup is claimed.

## Coverage and parity gates

- Per-logical-shader intervals cover physical, adaptive-bound, cache, stock and
  bootstrap draws. Frozen s207 shader replacements remain bound to their actual
  binary hashes. No shader is rebuilt in this stage.
- Explicit `UpdateSubresource`, staging/validation/stock copies and adaptive carry
  copies receive timestamp pairs. CPU submission bytes are recorded independently.
- Texture/buffer creation API wall time and descriptor bytes, view/shader/query
  creation, and counted owned-texture release blocks are recorded.
- `Map`, result allocation/copy/conversion and `Unmap` are separated by archive,
  decision, adaptive/cache/stock validation and final-proof purpose.
- Event `GetData`, requested sleep and inclusive wait are distinct counters.
  Existing completion event counts remain 7,085 full / 725 stopped, including
  bootstrap. New timestamp pairs resolve only after existing completion.
- Observer query storage stays fixed at 128 pairs plus one disjoint query
  (257 objects). CPU/GPU statistic key counts are checked against this fixture's
  bounded shader/purpose domains. This is not a general CPU memory bound.
- Draw/upload/allocation/read counts are reconciled with the original owner's
  independent counters. Complete parent GPU proofs, stock packets and traces
  are compared, not selected pixels or timing-only checks.
- Full debug conservation/accepted-time debt validation and the forced stop use
  the existing pure saved-output validators. Release successes additionally
  require complete parity with that validated debug state; debug-device selection
  is the only normalized report field. Diagnostic object IDs are normalized
  solely for comparing inventory shapes, occupants and last uses.

Recurrent full-run counters reconcile to 64,459 draws plus 34 startup draws,
4,419 explicit uploads / 47,130,224 bytes, 19 adaptive carries / 57 copies,
5,463 newly allocated counted default textures / 6,943,505,712 cumulative bytes,
11,517 staging allocations and 5,699,010,624 CPU read-result bytes. Cumulative
allocation/transfer traffic is distinct from the scoped peak live memory above.

CPU values are elapsed wall time in instrumented blocks, not thread CPU cycles.
Implicit driver transfers from initial-data allocations, driver-internal work,
every COM release, general command-state setup, all file operations and all
process CPU residuals are not isolated. Observer query construction is outside
the allocation categories. The scoped default-texture cap excludes query/driver
overhead; it is not complete application VRAM accounting. Thus
`completeTimingCoverageVerified`, `wholeProcessCpuAccounted` and
`totalCpuStreamingBounded` remain false despite explicit modeled coverage passing.

## Release refusal and evidence preservation

`release1` is the original profiling executable, with the D3D debug device flag
disabled. Its bootstrap and first eight stock publications match the parent.
The exact new-cache metric guard refuses frame 8 before publishing that candidate.
The last owner record retains accepted time = published time + active/queued debt.
There is no successful end report, final bank proof or full-run timing for this
aborted process; counted teardown and full recurrence must not be inferred.

`diagnose.exe` differs only by a CPU failure dump immediately before the same
metric equality guard. It has its own consumer-bound v2 binding. It does not add
GPU work, waits or a relaxed predicate. The first diagnostic run passed, so no
mismatch dump was produced. Its launch harness had expected a repeated refusal
and reported an assertion after the native process succeeded; the saved native
return code is 0 and the successful proofs are independently audited.
The runner now also accepts a complete successful diagnostic outcome, so a later
pass does not produce that misleading harness assertion.

Retain all observations rather than selecting only successful release samples.
The exact refused words and a general root cause remain unestablished. The
diagnostic executable is preparation to capture a recurrence, not a repair.

## Next work and limits

First isolate the intermittent release cache-reference refusal with exact-byte
evidence and qualify recurrent rebuild correctness. Then evaluate a bounded
completion polling/yield policy against the measured oversleep, preserving all
state/stock/time, forced-stop, event and retention gates. The adaptive-bound
producer is a separate measured GPU optimization candidate. Avoid mixing those
changes into a correctness experiment or extrapolating native timing to game FPS.

Physical/time accuracy, total CPU/startup streaming, long warm runs, common
head/film optics and CSP callback/completion/live adoption remain open. Production
physics remains s87 and main diagnostics s89/s152–s154. Main Lua, settings, assets,
game installation and older source SHA/mtime are preserved. No commit or push.

Evidence: `docs/diagnostics/2026-10-21/s208/`; entry tools:
`docs/tools/build_s208_profile.py`, `run_s208_profile.py`,
`build_s208_diagnose.py`, `check_s208_profile.py`, `finalize_s208.py`.
