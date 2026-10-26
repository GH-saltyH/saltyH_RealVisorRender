# s209: qualify exact cache-refusal capture and narrow the missing interval

2026-10-21. Parent s208. Status: ACTIVE. Offline native D3D11, RTX 3070.

## Result

The original s208 release refusal is retained and remains unexplained. Four new
complete 256-interval observations do not reproduce it: two preliminary release
runs, one AddressSanitizer release run and one corrected-capture release run.
All four match s207's complete GPU images, final bank proof, stock packets,
source/recovery/publication traces, water/time results and 11,850 typed inventory
snapshots per run after normalizing process-local diagnostic identities.

The corrected capture's debug forced stop also preserves the original 26
published / 29 accepted intervals, prior bank and exact active/queued time debt.
Successful runs retain 7,085 completion events, a 66,582,496 B scoped default
texture peak and zero counted default textures at teardown. Neither solver
shaders, comparison tolerances nor wait policy change.

The failure collector is now qualified by two deliberate one-bit controls. It
distinguishes a changed CPU result from a change present in the GPU resource and
staging/fresh-copy observations. Both controls refuse before cache publication
and retain the original first eight stock publications. These are synthetic
controls, not reproductions or explanations of the original failure.

## What is narrowed

The original failed s208 process passed the new-metric comparison at frame 7 and
refused it at frame 8. Its 370 saved inventory snapshots match the successful
original-executable replay prefix after normalizing diagnostic identities.

An independent parser recovers the frozen frame-7/frame-8 contexts. Their 64
pose bytes used by the sharing decision and metric-relevant header rows 11,
13–15 and 50 match. Both expected metric selectors are 0. With those inputs and
uncorrupted retained CPU context, frame 8 takes the shared-metric path; that path
draws a new header but no geometry or metric producer.

This narrows the unobserved interval to **after frame-7 cache validation through
the frame-8 metric read/reference comparison**. Retained GPU contents, CPU
reference identity and readback are still candidates. The actual failed process
did not record its shared flag or differing words, so this is a source/input
inference, not direct proof of its live branch or the cause. Successful replays
cannot reconstruct the missing bytes from that process.

## Corrected capture v2

The collector executes only after the existing complete metric equality check
has failed. It first writes:

- Actual CPU result, expected reference, previous metric result, current header
  and both independently qualified reference payloads.
- Frame, cache lease, shared/reused/alias flags and CPU MXCSR.
- Three rereads of the same completed staging texture.

It then makes diagnostic-only fresh copies of the refused GPU metric/header and
immutable geometry index/word inputs, observes a new diagnostic completion and
saves them. Non-shared cases also copy the temporary geometry components.
The extra copy/event occurs after the original discrepancy is saved and cannot
explain its earlier cause. It is excluded from normal event/retention/timing
claims. The refused candidate is never admitted to the solver.

Source review found two problems in the preliminary v1 collector: shared cases
do not own temporary geometry outputs 1/2, and the geometry index is R32F while
the old convenience reader accepts only RGBA32F. V2 skips absent temporaries and
uses explicit typed staging for the index. V1 is retained as preliminary source
and its successful normal-path evidence; its failure collection is unqualified.
The active collector and controls are built by `build_s209_controls.py`.

## Deliberate controls and independent checks

| Isolated control | Change | Observations | Classification |
| --- | --- | --- | --- |
| CPU result | Flip bit 0 of word 0 after the completed read at frame 8 | Actual differs; all three staging rereads and fresh GPU copy match expected | `CPU_result` |
| Retained GPU cache | Upload the same one-bit change before the frame-8 shared refresh | Actual, three staging rereads and fresh GPU copy contain the same changed word | `GPU_resource_or_earlier` |

Each capture has 84,019,124 bytes before compression. The independent checker
requires exactly one differing word with XOR 1, unchanged immutable GPU inputs,
exact reference payload hashes, matching current header, eight unchanged stock
publications, accepted-time debt closure and no frame-8 cache publication.
The classification describes where the difference is observable; it is not a
general GPU hardware/driver root-cause classifier.

Five executable-bound v2 receipts bind preliminary, sanitizer, corrected and
two isolated control consumers separately to the same immutable qualified
programs, inputs, shaders, adapter and driver. Old receipts are not silently
reassigned. No shader is rebuilt and no game files are written.

## Sanitizer and limits of repeated success

The separate MSVC `/fsanitize=address` build completes all 256 intervals without
a reported sanitizer finding and retains complete parent bit/state/stock/time
parity. This checks instrumented native CPU memory accesses in that run. It
does not prove all CPU memory safety, driver/GPU safety or the absence of a rare
error. The sanitizer build uses the preliminary collector; its failure path was
not exercised or qualified by that success.

The four completed processes publish 1,024 intervals in total and compare
47,400 inventory snapshots. Each process is the same short frozen 4.320556640625 s
simulation workload, not a long warm run or a statistical reliability estimate.
Wall times include instrumentation/startup/diagnostics and the sanitizer changes
CPU cost; this stage makes no performance comparison or game FPS claim.

`originalS208FailureReproduced`, `originalFailureRootCauseEstablished`,
`releaseRecurrenceQualified` and `wholeProgramMemorySafetyProved` remain false.
The first refusal is not discarded, hidden by a tolerance or declared fixed
because subsequent runs passed.

## Next implementation

Add bounded per-phase witnesses across the narrowed interval for the retained
metric, CPU reference identity and shared-candidate selection. Reuse the validated
v2 collector when a natural discrepancy occurs. Keep the exact guards, previous
published bank, accepted debt, event accounting and scoped cap. Establish the
first natural divergence before selecting a repair or releasing a wait-policy
optimization. Avoid another broad weather/FPS test at this point.

Physical/time accuracy, total CPU/startup streaming, long warm runs, common
head/film optics and actual CSP scheduling/completion/live adoption remain open.
Production remains s87, diagnostics s89/s152–s154. Older source SHA/mtime, main
Lua, three settings INIs, assets and game installation are preserved. No commit
or push. No user game action is needed for this offline step.

Evidence: `docs/diagnostics/2026-10-21/s209/`; tools:
`build_s209_capture.py`, `build_s209_controls.py`, `run_s209_capture.py`,
`check_s209_capture.py`, `finalize_s209.py` in `docs/tools/`.
