# s147 — frame dependency and output lifetime owner

Status: ACTIVE
Date: 2026-10-18
Scope: offline, uninstalled; production physics s87, diagnostics s89.

## Implemented boundary

`s147_frame_owner` owns one active immutable frame interval and the dependency
chain s146 birth → s143 paired heads → s144 source → s145 transport substeps.
It retains original read leases and parent outputs until all dependent uses have
completed. The frame can yield a phase-2 numerical candidate; it **does not
publish a game stock, advance the public clock, transfer inventory ownership to
the next frame or provide a live CSP fence**.

This closes the prototype's cross-stage lifetime/identity gap. It does not claim
that P1 force snapshots, merge commands, source uploads or actual engine callbacks
have been connected. Those inputs still require authentic matched producers.

## Admission and progress

`new(dependencies, options)` requires explicit `offlineReplay`, ordered submission
and a separately enabled completion capability. Completion is usable only if an
injected trusted completion callback exists. Default or missing capabilities
cannot advance the chain. There is no new timer, timeout, frame-delay completion
guess or readback-as-fence shortcut.

The sealed frame identity contains:

- frame/geometry/pose/weather/material keys;
- start/end integer ticks, actual source frame and birth tick;
- epoch/generation/interval plus previous completed token;
- metric/pose/weather/material revision vector.

An exact frame identity and matching source-request epoch are required for every
stage. Identity tables and stage recipes/parameters are privately copied. Caller
edits cannot change an admitted record. Actual upload hashing and identity seals
remain trusted backend seams; matching labels alone cannot authenticate arbitrary
GPU texture contents.

Stage order is fixed. Birth and heads consume no field-time debt; source must
report phase 1 with the entire debt. Each transport stage must consume a positive,
bounded integer number of remaining ticks. Only zero debt can report phase 2.
A repeated source stage, mismatched remaining time or premature phase 2 is refused.
No next stage may prepare until its predecessor has both completed and passed
numerical result verification.

The owner separately handles shader pending, accepted submission, unknown
submission, trusted completion and numerical admission. A completion proof must
match opaque owner/frame/stage capabilities, the latest attempt count, frame key
and stage key. Old, foreign or incomplete proofs cannot approve a stage. These
capabilities identify the exact use; they are not themselves a hardware fence.
The callback must substantiate that all submitted uses are physically complete.

## Exact parent bindings

The derived bridge can pin named private roots only after physical completion.
It refuses imported roots, duplicate aliases, missing names and copied/forged
lease capabilities. While root leases exist, reset, retirement and disposal are
blocked, including after cancellation.

| Child | Required source links |
| --- | --- |
| s143 heads | slot 6 = admitted birth events |
| s144 source | slots 1/2 = head candidate/receipt; 4 = birth events; 8 = birth impact packets; 9 = birth source header |
| first s145 transport | slots 1/4/5/8/10 = source film/heads/micro/checkpoint/cumulative ledger; 9 = birth source header |
| later s145 transport | same stock/ledger slots from previous transport, including its checkpoint; source header remains the original birth root |

The owner first pins each parent output group, then acquires the child's complete
input bundle. Each declared parent import must be the **same canonical handle**
as the pinned root, not merely equal pixels or a matching descriptor. A mismatch,
allocation refusal, parameter refusal or failed source acquisition releases new
leases and pins without disturbing already-admitted parents.

Other imports, including raw old/new P1 states, force snapshots, merge inputs,
geometry and request/header textures, must come from the trusted same-frame stage
verifier. This owner does not manufacture those values or infer provenance from
GPU totals. The head stage remains the existing raw-channel adapter; an actual
P1/merge producer hook is still required.

## Candidate readers and retirement

After phase 2, `candidate()` returns an opaque read lease and a numerical receipt,
not public raw texture handles. `consumeCandidate()` invokes the trusted consumer
with pinned outputs, marking the use before callback entry. Exceptions or unknown
return values are treated as possibly submitted reads. They are not retried.
`false` means no work was submitted and permits a pending retry or unused return.

Submitted readers must pass their **own** matching completion proof through
`pollCandidate()` before release. A preceding transport-stage proof cannot release
a later consumer. The callback may not retain handles or use them outside this
tracked read transaction. There is no renderer hookup yet.

Numerical verification callbacks are synchronous and must not submit GPU work or
retain handles. They run under temporary root pins after stage completion. A
pending numerical result holds the frame and prevents child preparation. An
actual asynchronous verification implementation must add tracked lifetime for its
reads rather than weakening this contract.

Cancellation does not free submitted or unknown work. Retirement first checks
every stage and candidate reader, then disposes children before parents, releases
each child's input leases and only then releases its parent-root pins. The
backend is trusted to make release/dispose noexcept and acquisition transactional.

Bounds: one active interval, 4–16 stages, at most 32 imported textures per stage
bundle, 128MiB per input bundle and a conservative 256MiB frame recipe budget.
That frame budget sums recipe bytes including repeated imports. Reaching a bound
refuses further work; debt is neither dropped nor marked complete. There is no
implicit backlog queue or inter-frame stock handoff. A future publication owner
must verify the external public clock and preserve/transfer final stocks before
retiring them; this module never makes that publication decision.

## Verification

The checker exercises 29 owner scenarios, six frame-schema guards and six direct
root-lease guards. Cases include pending retries, no ordering/authority, cancelled
unsubmitted work, incomplete prefixes, unknown submission, invalid source
revision, wrong/old/foreign completion, failed completion, pending/rejected
numerical result, identity/epoch/parent-handle mismatch, repeated source kind,
time overstep, allocation/parameter failure, stage/byte capacity, unknown/pending
consumer reads and stale proofs after reopening. Successful retirement leaves
zero input readers and disposes each private target exactly once. Missing
completion keeps targets and input leases alive, with no publication.

One frame is also executed through this owner using actual s146, s143, s144 and
two s145 shader graphs: **161 WARP draws / 46 strict `/WX /Ges` bodies**. Birth
events and impact packets feed actual head candidate/receipt outputs; their exact
root handles feed source and two half-interval transport stages. It ends at phase
2 with zero remaining ticks and a balanced cumulative water/momentum ledger.

This physical fixture starts with empty old heads and all newborns. Its raw
newborn state/meta and P3 descriptors are controlled same-frame producer inputs;
it does not exercise an authentic engine P1 force/merge callback, recurrent
interacting heads or a live source hook. The WARP runner uploads arrays between
draws and waits for its subprocess. Lua allocation/lease/completion tests use a
mock backend. This is not live persistent GPU lifetime or CSP ordering evidence.

No new solver shader or force model is introduced. The small frame uses five
graphs with 161 private targets; all are deliberately retained until retirement.
These are diagnostic allocations, not an economical production pipeline. Fusion,
scratch reuse under verified lifetime and actual persistent GPU timing remain
mandatory adoption work.

The old sources, shaders, settings, installed probe and physical assets remain
unchanged. Evidence: `diagnostics/2026-10-18/s147/owner_checks.json`,
`owner_frame_arrays.npz`, `source_freeze.json` and `delivery.json`.

## Next implementation

Provide authentic P1 motion/merge/source snapshot hooks and upload identity, plus
an actual ordered execution/completion and persistent inventory handoff backend.
Then fuse/reuse diagnostic targets, test physical/time accuracy and measure warm
target-game cost before connecting a default-off live preview.
