# s265 — private validated stock/time execution (2026-10-24)

## Implemented

The s264 numeric plan now has an explicit private transactional wrapper and an
ordered executor. Provisional work and last accepted stock are separate resources.
There is no main-app change or public renderer access in this stage.

`s265_transaction.lua`:

- Bind fresh cached s264 pass parameters with a bounded265/epoch1/serial identity.
- Preserve two dedicated committed End/runoff/impulse/wall banks outside work
  storage. They alternate by serial;each interval reads the previous bank.
- After the numeric ledger/time receipt,one GPU selector copies all candidate
  state bands only if receipt identity,acceptance and time are valid. Otherwise
  it copies the previous committed bank without arithmetic. First-input rejection
  retains the original End stock and initializes its accounting bands to zero.
- A rejected receipt makes the following interval's prior receipt invalid for
  advancement. A submitted suffix can calculate provisional work but cannot
  advance accepted time or replace the last good committed stock.
- Copy the final16 receipt words to one immutable16×1 R32F audit canvas. The
  production SDK adapter can read this existing status shape.

`s265_executor.lua`:

- Reserve one compact workspace plus32 small audit slots;allocate at most8
  canvases per preparation callback under a3ms pre-call soft deadline.
- Retain each input lease and its own typed parameter tables. Refuse invalid
  leases before submission;lost ownership before retirement quarantines rather
  than releasing or settling the input. The caller must provide genuinely owned,
  immutable,physically admitted GPU inputs;`lease.valid()` is an ownership
  contract,not a new geometry/header validation implementation.
- Retain an accepted SDK prefix across shader-pending retries. A whole pump has
  a3ms soft deadline/256-call bound. Parameter binding occurs in `submit()` and
  is not included in that pump deadline;no whole-app CPU budget pass is claimed.
- The next interval may start after the previous commit and audit-copy commands
  have been submitted,without waiting for its CPU callback. Mutable receipt and
  stock banks follow ordered GPU dependencies;CPU reads reference only immutable
  small audit copies.
- Hold reordered callbacks until the prefix is available. Only validated FIFO
  results settle the private CPU time counter. Refusal stops intake and drains
  already submitted suffixes. Unknown draw results,bad readback,timeout or lost
  ownership retain/quarantine resources and leases.
- Cancellation cannot retire a late callback or resume intake. Duplicate
  callbacks do not settle time or release a lease twice. No GPU disposal or public
  stock handles are exposed by the executor.

## Verification

`check_s265_transaction.py`:92 strict native D3D WARP draws on the1024×256 visor.
Two intervals accept;the third has an intentionally corrupted ledger and rejects;
the fourth is blocked by that rejection. Approved state matches the provisional
result bit-for-bit. Rejected state and blocked suffix preserve all four last-good
bands bit-for-bit,including accounting. The small snapshot preserves all16 words.
Two additional final-gate faults (momentum closure and invalid diagnostic) also
reject and retain the last good state. Rejected intervals report unadvanced debt.

`check_s265_executor.py`:12 controlled SDK cases exercise the actual compact plan:
normal,synchronous,reordered,pending,duplicate,refusal,bad audit,timeout,SDK throw,
cancellation,invalid initial lease and lease lost while waiting for retirement.
Normal64-input execution audits64 results,returns64 leases,reuses audit slots
and drains to zero debt while submissions precede delayed CPU results. The
controlled rejection stops after its accepted prefix,drains submitted suffixes
and retains debt. Cancellation is tested with callbacks delivered after cancel.
These are simulated scheduling times,not CSP performance measurements.

## Work and memory scope

On the1024×256 grid,the full private numeric plan plus commit and audit copy has
22/38/70 draw submissions for4/8/16 substeps. This excludes live capture,physical
cache preparation,source/head generation and rendering. Small-grid executor
fixtures have fewer ledger reduction levels and therefore different pass counts.

The two committed banks cost32MiB in addition to s264 work storage. Full-grid
working descriptors plus32 audits reserve83,987,040 bytes (about80.096MiB),with
43 private textures. This is one workspace and two stock roots,not two full
solver workspaces. External immutable initial stock,metric/area/run caches,
physics inputs,driver/staging memory and the existing app are excluded. The
96MiB check applies to owned workspace/audit reservations only;it is not a total
application memory qualification. Complete input/cache lifetime cost remains to
be counted during the engine connection.

## Limits and next connection

Native validation performs readbacks between draws. It proves selector/rollback
arithmetic and snapshot copying,not continuous CSP alias safety. The scheduling
fixtures are controlled. Actual driver order,lease creation from engine inputs,
warm source age,CPU cost,whole-app memory and startup remain unqualified. Receipt
time tests cover bounded intervals;they do not qualify long-run FP32 cumulative
clock accuracy or replace the existing authoritative source-time FIFO.

The GPU commit is private and follows its GPU receipt;CPU audit can lag. No
renderer may observe these mutable roots under this contract. This is not a
general completion fence. Public s87 effects are unchanged.

Next connect physically admitted engine snapshots and immutable metric/cache
leases to this executor and the existing source-time queue. Cache/stage startup
before live intake. Then run one default-OFF integrated actual continuous/startup
gate,including exact debt retention on refusal/overload. Do not add a standalone
probe or repeat isolated callback-latency tests. Head/source/optics and whole-app
2048/4096-slot costs remain later integration gates.
