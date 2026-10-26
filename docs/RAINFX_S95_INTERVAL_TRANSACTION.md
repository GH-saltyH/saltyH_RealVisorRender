# RainFX s95 — generation-bound interval transaction and retained time

Date: 2026-10-16
Status: ACTIVE — offline GPU protocol prototype; production remains s87

## 1. Scope

Extend local s94 from a post-source two-axis transport transaction to an
immutable **whole input interval**. Stage field supply, evaporation and P4b
return once, advance private transport checkpoints, and export field, head
packets, cumulative budget and interval clock only after all interval time has
been processed. This closes specified protocol counterexamples. It does not
integrate the new transport into the game or complete its physical convergence.

Production Lua/shaders, textures, tuning and user materials are unchanged.
No game install, reload/test request, commit or push.

## 2. Identity, immutable input and publication

The interval header is `(epoch, baseGeneration, intervalId, seconds)` plus a
second row `(poolTick, headCount, ready, reserved)`. Supply and event headers must
match the complete interval token; field, position history and heads must match
the published epoch/base generation. The ID must be newer than the last
published ID. Counts and IDs are exactly represented bounded integers.

The standalone `batch()` copies and freezes NumPy inputs once. A real app must
hold the corresponding immutable texture handles and weather/force snapshot
while the interval is pending. Headers express ownership, not GPU content hashes;
mutating a texture in place while retaining its header violates this contract.
Do not regenerate stochastic birth events on transport retries.

Stale or mismatched inputs cannot advance any exported bank or its clock.
An unfinished checkpoint prevents a newer interval from replacing its debt.
The checkpoint also binds interval seconds, pool tick and head count: reusing
an ID with altered scheduling metadata cannot retime already staged water.
An explicit reset epoch retires the old checkpoint. ID/generation exhaustion
requires epoch retirement rather than wrapping and accepting an old token.

All exported outputs read one GPU finish decision. The host must swap their
handles only after **every** output draw is ready. The Python factory returns
new public/private handles only after all draws complete; injected pending/error
paths at the attempt update and last publication draw retain the caller's old
handles. This host fence is part of the protocol, not replaced by a GPU flag.

## 3. Water ownership and source staging

The prototype uses the unchanged production `rainFilmPoolAddress.hlsl` and
`rainFilmPoolAvailable.hlsl` decoder:

- P4b event row 0 supplies the UV position; row 4 Z supplies transferred mm³.
- The same immutable event and pool tick identify its unique source cell/slot.
- Debit the original film first; deposit the transferred volume into an empty
  head packet at rest. Occupied slots and excessive debits refuse the interval.
- Record the removed film momentum as a wall reaction, because a returned head
  starts at rest. Internal pool volume is recorded separately from external
  input and external losses.
- Add the frozen accepted field supply rate times the original interval dt.
  Then apply the prescribed evaporation loss, proportionally to packet momenta.
- Validate s94 complete-image histories against these source edits. Preserve
  unchanged/coherently removed images; clear incompatible images.

The source result, staged head packets and source budget initialize a private
checkpoint **once**. Repeated source preparation draws deterministically read
the same immutable public base; resuming work selects the existing checkpoint
and does not apply those amounts again. Private staged heads persist too.

The physical fixture packets are `(V_mm3, V*worldVelocity.xyz)`. They are not the
full production P1 state/meta/position/lifecycle banks. Field supply here is
already accepted liquid, not the entire P2 DSD/source/reservoir pipeline. Head
motion and evaporation are held during the transport interval in this prototype.
This operator ordering must be coupled to full P1/P2/P3 evolution before adoption.

The cumulative ledger has five four-component sums and five correction rows:

| Bank | Value |
| --- | --- |
| 0 | external field input packet |
| 1 | evaporated physical end packet |
| 2 | end-packet runoff |
| 3 | internal returned volume, then wall impulse XYZ |
| 4 | interval-mean runoff packet, diagnostic |

End and mean volumes remain shared; the end packet supplies the physical
momentum ledger. A separate complete mean-force/evaporation budget is not claimed.
The conservation check includes final film + staged heads + evaporation + runoff
+ wall momentum − external input − initial stock. Internal pool volume is not
subtracted as an external water loss. Display diameter/gain never enters this
path.

## 4. Rejection and exact interval debt

The host submits a fixed number of attempts. Each attempt uses a GPU plan
texture in `ctTravel()`, replacing the old uniform dt at compile time in the
offline adapter. The host does not choose draws by reading admission/debt.
Current transported mean momentum produces the next planar-axis velocity on GPU.

An admitted X/Y pair updates private end/mean/history and its runoff budget.
A rejected pair changes neither; it halves the next attempted interval. Prior
accepted private substeps survive subsequent rejections and host-call boundaries.
The public state and public clock still remain at the original interval boundary.
Only zero remaining debt permits the whole interval to publish once.

Remaining time uses **2²⁰ exact ticks per original interval**. Attempt caps are
halved powers of two. Consumed ticks + remaining ticks stay exactly 2²⁰ in
float32 integer range; attempted physical dt is the original float32 seconds
times the dyadic fraction. Tiny accepted durations therefore cannot disappear
when subtracted from a much larger floating-point debt value.

After twenty halvings, rejection of a one-tick attempt marks the interval
explicitly blocked. It retains its complete debt/checkpoint; neither time nor
water is fabricated to force progress. There is no arbitrary-case completion
guarantee. Production still needs an admitted recovery policy and bounded input
backlog management; this prototype never silently drops old weather/force time.

Published seconds and cumulative packet budgets use compensated sums. GPU
testing found that FXC algebraic reassociation eliminated an unqualified clock
correction: adding 32×0.014s at a 1,000,000s base lost 0.448s. `precise`
intermediates now protect both the scalar clock and vector budget compensation.

## 5. Verification

FXC ps_5_0 `/Ges /WX` and D3D11 WARP; reports in
`diagnostics/2026-10-16/s95/`.

### Source, physical budget and duplicate publication

Synthetic planar interval using the production P4b decoder:

- One 1.25mm³ transfer, 0.004mm³ external supply, 0.0002mm³ evaporation and
  0.1mm³ runoff are applied once.
- Water residual about 7.12e-8mm³; physical momentum residual about
  2.40e-11 packet units (mm³·m/s), including the pool wall reaction.
- Replaying the already published interval leaves every bank and clock
  bit-identical; the generation advances only once.

### Real transport rejection, subdivision and checkpoint persistence

Twenty moving cells compress into an unsupported large group at dt=1s.
The actual X gate accepts and Y gate rejects. The GPU retains 1s debt and
selects a 0.5s cap. Two admitted 0.5s substeps then finish the full interval.

- Intermediate public stock/head/budget/clock remain bit-identical.
- Source and P4b head quantities remain one-time amounts across all calls.
- Three one-attempt host calls give bit-identical final exported banks to
  one three-attempt host call.
- Final profile L1 error is 2.39e-7mm³ against the independently specified
  final two-cell mass image; water residual about 2.17e-7mm³.

This is one force-free pressureless compression example, not general nonlinear
film time convergence or a recurrent curved-surface SI force test.

### Guards and arithmetic

Stale supply/event/field/history/head generations cannot consume time. Pending
debt cannot be replaced by a newer interval; resuming the original interval
works. Injected host pending/error paths preserve public/private handles.
Epoch reset and counter exhaustion pass. Excessive source debit, occupied head
and nonfinite supply refuse publication without changing exported stock.

Independent clock-kernel checks use synthetic admission to isolate accounting:
21 forced rejections leave the full 0.014s explicitly blocked. Eight admitted
one-tick steps retain exactly 1,048,568 ticks of debt and record eight consumed
ticks. At a 1,000,000s base, 32×0.014s publication has error below 1e-7s;
the analogous small cumulative-volume additions preserve their correction too.
These checks do not imply that rejected physical transport was admitted.

## 6. Cost and limits

The unoptimized standalone graph submits **14 + 28A draws** for A attempt slots:
42 for one, 70 for two, 98 for three. This includes per-axis loss probes and
all source checks, initialization and publication; unlike s94's estimate,
these loss probes now feed the cumulative transaction budget. Current attempt
slots still draw even when inactive; shader flags prevent state changes.

This graph is deliberately explicit for protocol verification and is too costly
for direct runtime adoption. Source/head/init/publication fusion, reading runoff
directly from existing hierarchy banks, work-target lifetime aliasing and a
bounded practical retry schedule are required before measuring game cost.
`txnSourceTotals` still has a serial final tile/head reduction; it must be
hierarchically reduced/fused for production rather than accepted as a cheap path.

Public field/end/mean/history is 3H (12MiB at 1024×256 RGBA32F); a persistent
private copy needs another 12MiB. Source paired stock is 2H (8MiB) before
temporary reuse; per-attempt 3H gather/commit intermediates need lifetime
aliasing. Header/control/ledger storage is small. These are raw payload sizes,
not measured peak engine memory. No game FPS, GPU ms or leak conclusion follows.

The standalone harness performs readback/upload between isolated shaders;
it proves arithmetic and decision dependency, not production GPU residency or
performance. There is no admission-dependent CPU scheduling branch in the
proposed graph. App integration must implement persistent textures and fences.

## 7. Next implementation gates

1. Couple per-substep SI force/height evolution and full head/source/evaporation
   lifecycle to the interval protocol, on curved geometry. Retain accepted
   events, force snapshots, metric transforms and their generations consistently.
2. Implement a bounded live input queue/backpressure and explicit recovery for
   unresolved one-tick debt. A stale interval must not be overwritten or advanced
   against the latest weather/transform snapshot.
3. Resolve dense-film physical/time convergence and pressure/contact-line
   limitations; successful protocol accounting does not fix those equations.
4. Fuse passes/storage, preserve publication guards, then integrate an opt-in
   runtime path and measure actual game GPU cost. No user test is needed now.

## 8. Reproduce and audit

Bundled Python + NumPy and the existing FXC/WARP harness:

```text
docs/tools/check_s95_transaction.py
docs/tools/check_s95_retry.py
docs/tools/check_s95_guards.py
docs/tools/check_s95_clock.py
docs/tools/finalize_s95.py
```

The final audit binds reports to current prototype/factory hashes, verifies
the staged s94 baseline, production and prior local work, checks published
birth/film asset hashes, and writes a source diff/delivery report. Git stamps
remain user controlled.
