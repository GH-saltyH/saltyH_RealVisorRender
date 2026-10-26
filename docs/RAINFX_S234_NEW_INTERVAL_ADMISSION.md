# s234 — new immutable interval admission (2026-10-22)

## Delivered scope

The new private owner can admit a second captured engine-input generation after
the preceding interval's fourth validated receipt, without seeding water again.
`rain_interval_admission.lua` owns time and immutable CPU admission;
`rain_preview_intervals.lua` owns the same fixed GPU slot across generations.
`prototypes/s234/s234_graph.lua` extends the observed s233 graph at the interval
boundary. The s233 owner, graph, main-app hook and actual evidence are preserved.

This stage is **local integration**. No new main-app switch or installed runtime
is delivered, and no user experiment is needed now. The second input in the
test is a deliberately changed synthetic continuation of the s152 capture,
with new pose, acceleration, air and evaporation. It is not a second actual
engine observation. Visible water remains on s87; s233 remains the newest
actual-CSP-qualified private execution path.

## Admission and time

- One active interval, no hidden input queue. A busy/refused sample remains
  the caller's responsibility. Frames must increase, and accepted samples are
  deep copies. Duplicate admission/completion and a mutated staging ticket
  are refused. Invalid input does not consume time or cache generations.
- Each admitted interval owns a new `{234,1,id,1}` token and private start/end
  tick range. The original capture identity is retained separately; it is never
  reused as the identity of modified rows. Derived rows have a separate exact
  canonical encoding, also covered by the existing GPU input fingerprint.
- Quantize `(raw dt + previous remainder)` to 1/1048576s. Keep the signed
  remainder for the next sample, bounded by half a tick (about0.477µs).
  Kahan accumulation tracks admitted raw time. The invariant is
  `raw admitted = advanced represented + represented debt + signed remainder`.
  Remainder is not silently discarded or independently counted as positive debt.
- Only a validated quarter advances private time. The new checkpoint can be
  armed only from the exact preceding token in phase2 with zero remaining time.
  A GPU handoff audit refuses re-arming an unfinished prior interval.
- This diagnostic owner accepts at most1024 intervals. Pending shaders,
  uncertain submissions, wrong receipts and cancellation preserve the last
  committed progress and stop further admission.

The unchanged transport allows represented dt≤0.05s. Samples whose nearest
quantized interval falls outside its tick range are explicitly refused for
caller subdivision; this stage does not clamp or lose their time. In particular,
raw0.05s can round above that transport bound. Production pause/long-frame
subdivision and complete engine-frame backlog ownership remain future work.

## State and cache generations

Packed End/Mean and the cumulative water/momentum history are copied exactly
before any old output is overwritten. Inside an interval, checkpoint copying
is exact too. At a new interval, the checkpoint is intentionally re-armed;
the audit verifies both the old completed checkpoint and the new token/debt.
No water or loss ledger is reset. Mean remains the last accepted subinterval's
Mean, not a time-weighted full-frame exposure.

Persistent cache is limited to verified file copies/fingerprints, connected-run
topology and zero head/micro inputs. Every dependency of a persistent cached
pass must also be persistent. Frame/header fingerprints, world metric, area,
geometry audit, physics and source header are refreshed on the first quarter
of each new input generation, then reused for its remaining three quarters.
Shader/uniform/texture cache signatures and graph ABI remain guarded.

Rigid pose and material/force changes are accepted. Geometry file identity,
field/head shape, physical scale or diameter calibration changes require a
separate remap/reset policy and are refused before GPU submission. There is
no renderer reader here; admission is reachable only when the private executor
has no active job. A later renderer needs independent leases.

## Local results

The actual1024×256 grid and unchanged s163 packed transport run through the
real new Lua owner, s231 executor/adapter and software D3D WARP draw oracle.
The oracle copies GPU results through CPU arrays between calls: it does not
establish actual CSP persistent-resource lifetime or target timing.

Two input generations complete eight accepted quarters on the same87 canvases,
95,622,608 logical texture bytes (91.193MiB), with seven slot reuses and eight
status reads/releases. There are **518 draw submissions and178 cache hits**
over696 logical passes. Each pump attempts at most one SDK draw. Sixteen
persistent cached passes survive the new generation; eleven input-dependent
cached passes refresh. There is no per-interval GPU allocation.

| Point | Film mm³ | Cumulative evaporation mm³ | Cumulative runoff mm³ |
|---|---:|---:|---:|
| Initial controlled20µm film | 805.772095 | 0 | 0 |
| First interval completed | 805.674805 | 0.014956 | 0.082267 |
| Second interval, first quarter | 805.439392 | 0.034218 | 0.298421 |
| Second interval completed | 804.641296 | 0.092004 | 1.038770 |

All eight full-array inventory and component-wise cumulative ledger checks pass
the existing128-FP32-epsilon/1e−9 budget. The entire first interval's End/Mean
output matches saved s233 local output bit-for-bit. Twenty unchanged state
copies are exact; the one intentional checkpoint re-arm has its own contract.
The new GPU audit rejects unfinished old debt. No transport coefficient or
numerical acceptance tolerance is changed.

Two raw samples total0.0357901237s. Represented time is0.0357904434204s,
remaining represented debt0 and signed remainder−0.319720µs. The owner carries
that remainder into the next admission. A1024-interval time-control run checks
closure and the half-tick bound at every interval. Eight lifecycle controls
cover ordinary/pending/duplicate completion, wrong receipt, GPU boundary
refusal, uncertain copy submission, changed graph ABI and boundary cancellation.

The local bridge initially returned Python tuples without unpacking them into
Lua return values; the harness was corrected before the physical run. The
new generation's source-frame field and derived identity handling were also
tightened during implementation. The final evidence binds the final sources.

## Cost and next integration

These are command counts and logical byte totals, not an optimization or FPS
claim. This diagnostic deliberately spreads proof-heavy graph execution across
callbacks. Its CPU graph is rebuilt and checked at admission; CPU allocation,
capture latency and continuous frame throughput are unmeasured. It cannot yet
serve as the production per-frame scheduler.

Next connect fresh main-app captures to this owner and validate two actual CSP
input generations without extra allocation. Then add complete elapsed-time
admission/subdivision and bounded backlog handling, followed by conserved
incident/head sources, protected renderer leases and common optics. Whole-run
memory, replay/reset, frame-ms and visible continuity remain adoption gates.

Evidence: `diagnostics/2026-10-22/s234/checks.json`, `interval_results.npz`,
`host_checks.json` and `delivery.json`. Git commits/push remain user controlled.
