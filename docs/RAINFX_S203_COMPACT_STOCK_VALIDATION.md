# s203: compact stock validation in the native owner

Completed2026-10-21;started2026-10-20. Parent s202. Status: ACTIVE.
Offline native D3D11 WARP/debug only;game physics remains s87,diagnostics s89.
Evidence uses the start-date folder `diagnostics/2026-10-20/s203/`.

## Result

Stock validation now reads a complete tiled GPU reduction instead of full film,
micro and head images. The integrated compact run completes the same256
intervals and4.320556640625s with seven recovered transport refusals. Final bank
bits,source/control captures,owner/recovery/phase/index traces and exact time
debt retain their references. Physical shaders,inputs and acceptance tolerance
are unchanged.

The stock-validation category falls from2,164,301,824B to1,626,112B in this
fixture,with no full-image fallback during the compact run. This reduces that
read payload by approximately99.925%. It adds one validation draw per stock
check and6,192B of temporary default textures. Cache validation still reads
6,820,614,720B and is the next payload to address. No target GPU/FPS improvement
is established by these WARP runs.

## Complete reduction and conservative acceptance

Each output group visits up to4,096 consecutive pixels of one stock image.
Every pixel is checked for nonfinite components and negative water;negative
zero remains valid. Three integer MRTs return four FP64 sums and the maximum
FP32 magnitude of each component. FP64 words use RGBA32_UINT targets,so their
bits are not encoded through floating render-target values. FP32 words are
decoded explicitly into FP64,including subnormals. The actual grid requires
129 groups and6,192B of packet payload per check.

The original CPU loop sums all FP32 values sequentially in binary64. A tiled
sum can differ because its addition order changes. Let `N` be the number of
source pixels,`g` the number of groups,and `B[k]` an upper bound on the sum of
absolute input values in component `k`. The CPU constructs `B` from each
group's exact maximum magnitude times its valid pixel count,rounding the
positive accumulation upward with `nextafter`.

For the guarded domain `N <= 2^20`,round-to-nearest binary64 and finite FP32
inputs,the standard sequential-sum error is bounded by `gamma_N * B`;the
tiled sum adds `gamma_4096` and group recombination error. The implementation
uses the conservative envelope

```
E[k] = 4 * epsilon64 * ((N + 4096 + g + 8) * B[k]
                       + abs(tiledSum[k]) + abs(ledgerStock[k]) + tolerance[k])
```

rounded upward. Here `epsilon64 = 2^-52 = 2u`;for this domain the factor4
also covers the smaller recombination and comparison rounding terms. Source
values and sums are far inside binary64's normal exponent/overflow range.
CPU rounding/DAZ/FTZ assumptions and GPU FP64 support are checked explicitly.
Unsupported environments refuse this candidate;the previous full-reader
implementation remains preserved. Target device support is not yet verified.

The original tolerance is retained exactly:

```
max(sum(abs(ledger rows[k])) * 128 * epsilon32, 1e-9)
```

An outward-rounded interval around the tiled distance determines a certain
pass or certain rejection. If it crosses the tolerance,the code reads the
original three GPU images and runs the original CPU predicate. It does not
increase the tolerance or accept an uncertain result. Invalid input flags
reject without relying on a finite aggregate. This is a full-image reduction,
not a sparse fingerprint.

## Component verification

The independent native component passes25 actual/adversarial cases. Saved
final and stopped banks are included,with negative-water,NaN and infinity
mutations. Additional cases cover partial tiles,invalid last pixels,positive
and negative subnormals,signed zero,FP32-range overflow of the aggregate,
near-boundary acceptance/rejection and strong momentum cancellation.

An independent Python audit reconstructs every GPU group from immutable inputs
and compares1,091 groups' FP64 words,invalid flags and maximum words exactly,
covering17,046,348 input channels. All CPU-reference acceptance results match.
Four cases use the original GPU full read:the exact boundary,a point just
outside,a point just inside,and strong cancellation. Actual fallback image
bytes are checked against immutable inputs before the old predicate runs.

## Integrated verification and retention

The shadow run executes both the reduction and original full reads for every
published stock. All256 original stock totals match the s202 reference,and
every aggregate difference stays within its numerical certificate. The compact
run then omits the three full stock images;it has no ambiguous stock checks.
Its complete reduction packets match the shadow packets byte for byte.

Both executions retain1,049 adaptive attempts,1,042 accepted substeps,seven
recovered transport refusals and zero final accepted-time debt. Ledger and
checkpoint rows retain their bits. The stock log now records a certified tiled
total,which is not claimed to be bit-identical to the old sequential CPU sum.
Physical output banks and all small source/control captures remain bit-identical.

The compact one-attempt-budget control still quarantines interval26. Its prior
26 published banks,29 accepted intervals and one active plus two waiting
intervals of debt match s202. The preserved final eight-root bank and recovery/
owner/phase/index traces match;27 compact stock checks include the final
preserved-bank observation. Fault injections for stock values are component
tests;they are not claimed as new integrated solver fault experiments.

The three129x1 RGBA32_UINT scratch targets are admitted together only during
stock validation,after prior GPU work completes. They are unbound,completed,
read and released before recurrence continues. Typed ownership audits account
for768 extra created/released generations in each full run and81 in the stop
control. No scratch is left in the final inventory. Original pool occupancy,
shapes and last uses match after diagnostic ID normalization.

Measured default-texture peak is66,582,496B,under the66,584,576B scoped cap by
2,080B;final default textures are0B. This cap excludes staging,constant buffers,
shaders,CPU/driver allocations and the rest of the app. The compact stock
staging peak is6,352B instead of8,454,304B;the shadow run deliberately retains
both forms. Strict HLSL/C++ compilation and D3D debug checks have zero warnings.

## Cost and next work

| Stock-check measurement | s202 full reader | s203 compact |
| --- | ---: | ---: |
| Checks | 256 | 256 |
| CPU-visible bytes including ledger/checkpoint | 2,164,301,824 | 1,626,112 |
| Read calls | 1,280 | 1,280 |
| Extra validation draws | 0 | 256 |
| Extra default scratch peak | 0 | 6,192B |
| Full-image fallback checks | n/a | 0 |

The shadow run observes184.005375s and the compact run181.975249s,including
final proof. They are single sequential WARP/debug observations with text traces
and substantial cache/adaptive validation remaining. They do not establish
statistical speedup,target GPU timing,frame rate or CSP callback latency.
Physical transport still uses a maximum49 draws per native pump;the new stock
validation draw is additional work outside that pump count.

Next address the remaining full-image cache validation with a compact integrity
candidate under the same retention cap. Preserve complete-reference and corrupt/
stale/held/failure checks,acceptance,completion and exact water/time guards.
Hardware FP64/cost,total provider/startup CPU streaming,true long-duration/live-
weather stability,actual CSP scheduling/completion,physical/time accuracy,
common optics and live adoption remain open. Main,settings,production shaders,
assets and installed game files are preserved. No user game test,commit or push.

Evidence:`stock_checks.json`,`stock_audit.json`,`fixture_manifest.json`,
component GPU packets,and shadow/compact/stop reports,stock packets,cost and
ownership traces and final-bank proofs in the stage folder. Finalization
checks saved evidence and archives it without another GPU execution.
