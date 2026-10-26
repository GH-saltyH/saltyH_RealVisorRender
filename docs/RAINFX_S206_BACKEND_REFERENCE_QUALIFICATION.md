# s206: qualified two-pose backend geometry references

2026-10-21. Parent s205. Status: ACTIVE. Offline native cache component only.

## Result

Both world-metric poses in the frozen fixture now have independently qualified
RTX 3070 cache references. Each capture is initially unqualified. CPU checks of
the complete inputs, support, world transformation, Gram diagonals, area and
connected boundaries must pass before a reference receipt is written.

A separate native invocation consumes that receipt, rebuilds the cache and
compares every byte of all ten proof images. Both poses pass in debug and
release devices: four successful rebuilds, each comparing 30,674,240 logical
readback bytes. The same-backend predicate uses no floating-point tolerance or
digest in place of full image comparison. A one-bit GPU metric corruption is
rejected for each pose. Receipt provenance failures are also refused.

This connects qualification to a standalone native cache consumer. It does not
connect receipts to the complete physical owner or the game. No physical bank,
accepted interval or solver clock is published. The s205 original WARP-reference
failure and all prior WARP fixtures remain preserved.

## Two distinct acceptance steps

### 1. Independent numerical and input qualification

The unchanged initial and refreshed program files supply the actual immutable
geometry dictionary, cells, context and shader paths. Their two poses differ
by the fixture's existing rigid yaw; geometry, scale and support are unchanged.
The native capture runs the unchanged 34 cache shaders and copies the ten proof
images after the existing event completion. Capture alone grants no acceptance.

CPU qualification checks:

- All captured geometry index/table, head positions and source stock match their
  embedded immutable input bytes. Cells and header match their complete inputs.
- The atlas contains the exact complete context header, zero invalid-cell count,
  the correct supported-cell count, a normalized maximum in [0,1], and an area
  sum within the existing relative 1e-5 bound.
- Independent float64 dictionary sampling and matrix multiplication reconstruct
  world u/v at all 1024 x 256 field centres. Stored Gram diagonals are checked
  against independent float64 dot products, with positive supported determinants.
- Existing dimensionless 1e-5 numerical bounds are retained. Unsupported metric
  and area cells remain zero. World area matches local area times world scale
  squared. Independent connected-run reconstruction matches the complete grid.

| Maximum normalized error; acceptance bound 1 | Initial pose | Refreshed pose |
| --- | ---: | ---: |
| World u/v transform | 0.0145600 | 0.0145600 |
| Stored Gram diagonals | 0.0135595 | 0.0141767 |
| World area | 0 | 0 |

Each pose checks 262,144 cells, including 123,224 supported cells. Ten deliberately
invalid CPU qualification cases per pose are refused: world basis, Gram diagonal,
unsupported metric, area, unsupported area, connected run, support, pose, raw
input and atlas invalid-cell count. These bounds qualify this geometry cache;
they do not establish physical solver accuracy or transport sensitivity.

### 2. Immutable provenance and exact native consumption

Only after qualification does Python issue the binary receipt and its readable
JSON provenance. The receipt binds:

- The complete serialized program, including all seven embedded input payloads,
  descriptors, uniform values and command records.
- The complete captured proof file, native executable and every cache-build
  shader binary, using SHA-256 file identities.
- Adapter index, vendor/device, LUID and driver version.

The JSON also records every complete input's shape/hash, context and extracted
metric hashes, numerical qualification and refused controls. The native reader
checks the bounded binary receipt, complete shader coverage, current file hashes
and device identity before any producer draw. Hash checks happen before device
construction; adapter/driver checks necessarily happen after device construction.
Device construction can allocate/upload immutable inputs, so an adapter refusal
is not described as zero GPU work or zero allocation.

The consumer then executes the same cache graph. After event completion, it
checks the ID, typed logical extent and complete bytes of all ten images against
the qualified reference. Hashes establish file provenance; they do not replace
these GPU readback comparisons. References are never replaced with the current
rebuild's output to make a comparison succeed.

Four clean rebuilds pass across both poses and debug/release modes. Two diagnostic
fault runs upload a one-bit change to the rebuilt GPU metric before capture and
fail the exact image comparison. Eight further native refusal cases cover wrong
program hash, reference hash, executable hash, shader hash, adapter, driver,
cross-pose program and changed reference payload. Failed cases write no successful
report or physical publication. All checked debug runs report no warnings.

Receipts are scoped to this private native executable and immutable offline files.
They are not signatures, a hostile-writer protocol, a GPU completion fence, or a
CSP resource lease. The issuance JSON records rebuilds as pending at issuance;
the final audit separately records the four completed exact consumers. Receipt
files stay unchanged during those native consumers.

## Resource and measurement scope

Successful capture/rebuild processes each use 34 cache producer draws and one
existing completion event. Six successful processes total 204 producer draws;
the two GPU corruption controls add 68. There are no physical solver draws.
Each process reports 37,381,792 cold default-texture bytes, within the inherited
private cache builder's 64 MiB cap. Separate processes release their resources
on exit. This is not a new complete-application memory or recurrent-owner bound.

Readback staging, frozen CPU proof/reference images, query storage, executable,
shaders and driver memory are outside that descriptor count. The inherited fixed
timestamp observer is retained only as diagnostics. This stage makes no speedup,
hardware pipeline timing or game FPS claim. C++ compilation uses /O2, /fp:strict,
/W4 and /WX. No new shader is compiled or changed.

## Next implementation and gates

Connect these qualified metric/reference payloads to the private full physical
owner through an explicit consumer-bound receipt version. The current receipts
bind the standalone executable; a different consumer requires its own declared
binding and validation, not an implicit bypass of the executable check.

Retain exact same-backend cache rebuild/preservation predicates, independent
numerical qualification, source retry, held-reader protection, quarantine,
rollback, typed lifetime accounting and the existing scoped texture cap. Then
verify complete hardware shadow/reuse state, ledger and accepted-time parity
over 256 intervals and the forced budget stop before interpreting integrated
performance. Complete measurement coverage for uploads, adaptive bounds/carry
and allocation costs remains necessary.

CSP scheduling/completion, whole CPU/startup streaming, true long duration,
physical/time accuracy, common optics and live adoption remain open. Production
stays s87 and diagnostics s89. Main, settings, production shaders, assets and game
installation are preserved. No user game test, commit or push is needed here.

Evidence: `diagnostics/2026-10-21/s206/reference_checks.json`,
`reference_audit.json`, both immutable receipts, complete captures/rebuild images,
native invocation records and CPU qualification controls. Finalization audits
saved files and archives only this stage's binary payloads without rerunning GPU
work or prior stage mains.
