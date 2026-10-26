# s174 — bounded cached context and nonzero physical handoff

Date: 2026-10-20. Status: ACTIVE (small native physical reference).

## Scope and implementation

The bounded immutable-generation policy from s173 now surrounds the existing
nonzero birth/head/source/transport chain in one native D3D11 WARP context.
This is the preserved **13×7 planar film /8 head-slot** fixture from s166,
with source ON→OFF→ON. It is not the1024×256 actual visor or4096-head chain.

`tools/s174_joint_owner.cpp` caches each frame's unbound physical input packets
and geometry/metric inputs as immutable native textures. Imports from the
previous GPU inventory or earlier stages continue to bind those retained GPU
resources directly. Complete CPU payload equality and exact texture shapes
permit sharing unchanged cached inputs; each prepared GPU payload is read back
after real completion and checked against its immutable receipt. Display gains
never enter these inputs. Physical shaders, coefficients and tolerances are
unchanged.

The cache contains the existing planar fixture inputs. **s173's full actual-grid
cache builder is not embedded in this physical stream.** Changing-pose curved
physical recurrence, bake replacement and production head geometry remain
outside this test. The established actual-geometry cache results stay preserved.

`s174_retained_runner.inc` is a private fork of the s166 native executor. Its
changes add external cache leases, preflight bank-copy allocations, and split
bank preparation from publication. The original s166 sources remain unchanged.

## One publication boundary

There are at most two cache generations and two pending contexts. The active
context stays at the queue front until publication, so that queue capacity
includes the active context. A held retired cache blocks preparation of a third
generation. Wrong-frame enqueue and wrong-generation/duplicate reader returns
are refused. Explicit cache readers and pending inventory copies are excluded
from the native free-target pool.

Each frame follows:

```
prepare immutable context → birth → SI head/merge → conserved source
  → packed film → four transport quarters → prepare eight bank copies
  → validate completion/checkpoint → return old bank reader
  → publish bank + cache generation + whole-frame clock
```

Source, quarter and copy candidates do not update the published bank or clock.
The final checkpoint must have phase2, zero remaining ticks and accepted status.
All eight independent bank copies retain their bits, including the End-only
film copy from its2H backing. A direct bank-publication attempt also refuses
while the old bank reader is held. Cache and bank exchange occur within one
serialized owner operation; this is not a multithreaded lock-free transaction.

Time is accounted at this **whole-frame publication boundary**:

`accepted = published + active unpublished interval + queued intervals`.

Every recorded owner transition satisfies this identity exactly for the dyadic
fixture dt=15.625ms. The four quarters still consume their internal checkpoint
debt, but no quarter is exposed as a separately published bank/time state.
Three frame commits publish46.875ms. This does not demonstrate arbitrary real
frame cadence, cancellation, device removal or allocation-exception recovery.

## Failures and numerical evidence

The final native suite executes **618 draws /37 real completion events /
32 bank copy operations** with no D3D debug warnings. Fifty preserved strict
shader bodies are reused; new C++ compiles with `/W4 /WX`.

- One cache preparation is quarantined after an injected failed completion
  latch. The real event is still observed before explicit disposal. The queued
  input remains available for retry under a new generation identity.
- One failed source candidate preserves the published bank/cache/clock. Retry
  retains the original candidate bits. All three source-replay controls refuse
  reapplication and preserve rollback stock and ledger.
- One failed final bank-copy batch leaves the bank/cache/clock unchanged.
  Its eight completed copies are discarded; retry copies match the sources.
- A held previous-generation reader is verified after the next frame publishes:
  all50 cached inputs retain their original GPU bits. The next preparation
  waits until that reader explicitly returns.
- Capacity refusals precede cache preparation and source-stage submission;
  the bank-copy path also preflights the complete missing allocation batch.

The entire28-record stream of physical imports/public roots and all24 committed
bank payloads match the frozen s166 pooled run **bit-for-bit**. The pure birth/
head/source/transport oracles and inherited32ε force/source and128ε closure
gates are reapplied to these new outputs. Cumulative source is1.150346518,
1.150346518 and2.300693035mm³; no incoming water is applied in the middle frame
or repeated during transport. Final physical head volume and raw metadata agree.

Four cache preparation attempts perform180 full input checks,129 uploads and
51 payload-sharing decisions. These uploads use `UpdateSubresource`; they are
not counted as the32 GPU bank-copy operations. The three successful cached
contexts publish with the three bank/time commits.

## Cost gate and next work

Native default-texture allocation peaks at409,232 bytes (0.390274MiB), including
the cache generations, failed preparation allocations retained in the pool,
working targets, old inventory and pending copy targets. This exceeds s166's
small pooled reference216,892 bytes because the new owner retains additional
immutable inputs and overlapping copies. Solver/copy audit staging peaks at
284,976 bytes separately; cache/old-reader staging peaks at173,232 bytes. CPU
receipts, fixtures, shaders and driver allocations are outside these counts.
These small-fixture numbers do not predict whole-app memory or FPS.

The preserved End-only actual-grid plan still declares118,598,576 bytes
(113.104416MiB) of warm exact-shape reservation, before integrating cold cache
construction/replacement. Its lifetime certificate is rechecked. The native
admission preflight refuses that declared plan against64MiB **before creating
a device or submitting a draw**. This is a refusal of the current declared
plan, not proof of a universal physical memory minimum. No alternate split or
128MiB budget is adopted, and no full-grid execution is claimed.

Next reduce the combined static/working lifetimes or input representation while
preserving physical precision and inherited accuracy gates. Recompute complete
cache/source/head/transport/bank overlap, then execute the actual-grid chain
when admitted. Actual curved coupling, common optics, general CSP completion,
target-device timing and long warm-run checks remain before runtime adoption.

Main/game physics remains s87, diagnostics s89. Production script, settings,
shaders, assets and installed game are unchanged. No game test is requested.
Evidence: `diagnostics/2026-10-20/s174/joint_checks.json`, native owner timeline,
physical/inventory archives, actual-grid refusal and `delivery.json`.
