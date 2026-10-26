# s202: optional diagnostic capture policy and cost accounting

2026-10-20. Parent s201. Status: ACTIVE. Offline native D3D11 WARP/debug only.

## Result

The native harness now separates full intermediate capture from a controls-only
archive policy. Both complete the same256 intervals, publishing exactly
4.320556640625s, with1,049 adaptive attempts and seven recovered numerical
refusals. Mandatory read calls/bytes, numerical acceptance, source-once checks,
cache/publication guards, exact time debt and default-texture ownership remain
unchanged. Physical shaders and inputs retain their original bytes.

Optional archive reads fall from1,976,243,488B to442,816B. The two sequential
native wall observations are both approximately192s;this experiment does not
show an end-to-end speedup. Required full-image validation, physical shader work,
waits and CPU traces remain in the path. Target hardware timing is still open.

## Policy and implementation

`full` reproduces every original physical audit capture and the selected/failed
cache archives. `controls` retains the original decision snapshots and every
originally selected image of128B or less. This preserves the source ledgers,
checkpoints and small control evidence. It omits781 larger physical captures,
totaling1,296,256,032B, and selected cache archive serialization/duplicate reads
totaling679,544,640B.

The controls policy does not remove the six-snapshot cache validation, per-bank
stock/ledger checks, adaptive ledger/checkpoint reads, refusal input/output
equality checks, acceptance decisions, completion waits, reader/capacity guards,
or failed-cache/source retry paths. All owner, recovery, stock, phase, index and
inventory text traces remain enabled. This is a first separation of optional
image artifacts, not a diagnostic-free production/timing path.

Both modes additionally export the final published eight-root bank once before
teardown. This proof has its own category and timing scope;its8,585,424B and one
completion event are not hidden in an apparent solver improvement. All eight
roots match s201's saved final bank byte for byte. The forced-stop proof exports
the prior published bank, not the refused candidate.

## Verification

- The full mode preserves every s201 cold-cache, intermediate physical and
  cache archive GPU byte, as well as the complete stock/recovery/owner/phase/
  index traces. The only additional completion event is final proof.
- The controls archive matches an independently filtered full archive byte for
  byte, including phase headers and ordered records. Final eight-root bank bits
  and the stock/recovery/owner/phase/index traces also match. No physical equation, threshold, adaptive
  budget, source amount or display coefficient changes.
- Both complete256 intervals with zero final accepted-time debt, unchanged
  water/momentum ledger bounds, three-request capacity and scoped recurring
  metadata caps. Peak default textures remain66,577,136B(63.492905MiB), with
  zero after teardown. D3D debug validation and strict compilation have zero
  warnings.
- A new controls-mode one-attempt-budget run quarantines interval26, retaining
  26 published/29 accepted intervals and exactly one active plus two waiting
  intervals of debt. Published bank bits and owner/stock/recovery/phase traces
  match the saved s200 budget-stop reference. No partial publication or source
  reapplication occurs. All564 created default-texture generations release.
- Required-read categories have exactly the same call counts and bytes across
  both full runs. Inputs and all compiled physical/cache shaders retain their
  saved hashes. Previous stage builder/checker mains are not run;pure numerical
  saved-data audits are rebound to the new outputs.

Diagnostic IDs are assigned while traversing live shared owners, whose pointer
order can vary across processes. The inventory checker therefore compares every
snapshot's counts, bytes, shapes, logical occupants and last uses with those ID
labels normalized. Independent per-run audits still reject identity reuse,
resurrection, shape mutation, invalid last use and incomplete teardown. Inventory
text is not claimed to match byte for byte across processes.

## Measured categories

Byte counts below cover CPU-visible read results during the native physical
owner's run. They exclude the pre-run cold/bootstrap proof and index generation.
Archive reads include duplicate mappings used solely to serialize artifacts;
they are separate from the same snapshot's mandatory decision/cache reads.

| Read category | Full: calls /bytes | Controls: calls /bytes |
| --- | ---: | ---: |
| Optional image archive | 7,539 /1,976,243,488 | 6,596 /442,816 |
| Acceptance decision | 2,089 /33,424 | 2,089 /33,424 |
| Adaptive validation | 2,133 /58,889,328 | 2,133 /58,889,328 |
| Cache validation | 1,626 /6,820,614,720 | 1,626 /6,820,614,720 |
| Stock validation | 1,280 /2,164,301,824 | 1,280 /2,164,301,824 |
| Final eight-root proof | 8 /8,585,424 | 8 /8,585,424 |

The mandatory categories excluding final proof still read9,043,839,296B during
this4.32s simulated fixture. Cache and stock checks dominate that byte count.
Reducing optional archives alone therefore leaves a substantial validation path
to address. These bytes do not measure actual GPU bandwidth, retained memory,
driver allocations or time spent on individual shader stages.

The full run observes192.009663s including22.6493ms of final proof;controls
observes192.056455s including21.3244ms of proof. Physical archive scopes observe
1,693.0522ms and478.7284ms respectively;full cache serialization observes
712.5202ms. Read-map scopes are nested inside archive scopes and must not be
summed with them. Per-call timers and file flushing also affect this harness.
These single sequential WARP/debug runs are not statistical speedup estimates,
target GPU/FPS results or actual CSP callback latency.

## Next work and scope

Next reduce required validation payload with a compact GPU-check candidate,
checked against the retained full-image reference and failure cases under the
current retention cap. Keep numerical acceptance, real completion, reader
ownership and exact water/time guards. Category counters identify the bytes to
address;they do not authorize weakening checks or treating a sampled fingerprint
as a general completion proof.

Hardware cost, total provider/startup CPU streaming, true long-duration/live-
weather stability, actual CSP scheduling/completion, physical/time accuracy,
common optics and live adoption remain open. Production remains s87,
diagnostics s89. Main script, settings, production shaders, assets and installed
game files are preserved. No user game test, commit or push for this stage.

Evidence: `diagnostics/2026-10-20/s202/diagnostic_checks.json`,
`diagnostic_audit.json`, each case's `run.cost202.json`, reports/traces, final
proofs and full/control GPU captures. Finalization verifies saved evidence and
streams compression without new GPU execution.
