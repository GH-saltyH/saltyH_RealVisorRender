# s138 — interval snapshots and genuine GPU protocol headers

Date: 2026-10-18
Status: ACTIVE

## 1. Implemented scope

The uninstalled s138 adapter freezes dynamic interval metadata, borrows thirteen
source resources, computes an eligible substep with the s95 GPU protocol, and
runs the unchanged twenty-six selected transport passes. The retained owner
publishes roots and the host clock together only after complete prefix, trusted
completion, immutable sources, a matching GPU plan and trusted output validation.
All runtime capability defaults remain disabled. Production stays s87/s89.

This replaces s136's fixed dt/dummy header input for the offline adapter. It does
not yet supply live production stocks, apply new incident water, advance physical
heads, or commit the full s95 water ledger. The five numerical cases reuse frozen
stocks; sequential metadata replay is not a recurrent physical trajectory.

## 2. Important production format mismatch

`shaders/rainFilmResolve.hlsl`, `pfResolve`, reads `old.rg` as film and micro water
and returns `float4(next, old.b+removed, old.a+runoff)`. Thus its RGBA is film,
micro, cumulative evaporation and cumulative runoff. `rain_film.lua` publishes
these fields. They cannot serve as the new transporter's End/Mean resources.

The new explicit tag is `end_mean_mm3_world_v1`: R is volume in mm³; GBA is
volume-weighted world velocity in mm³·m/s. At fixed water density this is
proportional to momentum, but it is not stored in kg·m/s. End/Mean describe
temporal stocks; a producer must actually construct them and the matching bank.
Legacy `rain-film-v1`, unknown schemas and incompatible descriptors are refused.
A format label or seal is not evidence that arbitrary GPU payloads have these
units: numerical validation and trusted producer ownership are still required.

## 3. Snapshot and clock contract

`s138_snapshot.lua` accepts an exact schema: stock format, axis order, epoch,
generation, previous/new interval IDs, absolute start tick, total interval ticks,
normalized remaining/cap ticks, source tick, head count, accepted/rejected counts,
fresh flag, geometry/pose/settings identities and five stock/geometry descriptors.
It deep-copies inputs before calling the trusted producer seal callback.

- Absolute host clock: **2²⁰ ticks per second**, integer arithmetic, no rounding.
  This differs from the earlier s135 diagnostic replay's 16,384 ticks/s.
- Total interval: 1…2²⁰ host ticks. Normalized debt/cap: 1…2²⁰.
- Step = `min(remaining, cap)`. Total×remaining/2²⁰ and total×step/2²⁰
  must be exact positive host integers; unrepresentable fractions are refused.
- The offered sample is precisely the current substep window, not the whole
  outstanding interval. Generation and all four identities must match.
- IDs are bounded exact float integers with no wrapping/ABA; interval ID must
  increase. The owner defaults to two slots and one second of queued time.
- The published header's second-row start time is diagnostic float data. The
  authoritative absolute clock stays in host integers; long-time float rounding
  in that unused diagnostic row cannot advance the queue.

The producer seam seals the copied metadata and eight header resource identities.
It must produce immutable whole resources corresponding to those rows. The test
callback uses canonical JSON SHA-256; this is not a new engine hash API or a
general GPU payload checksum.

## 4. Resource and plan topology

| IDs | Meaning | Ownership |
| --- | --- | --- |
| 1–5 | Packed bank, End, Mean, runs, metric | Borrowed read leases |
| 6–13 | Published, batch, supply, event, field, history, head, control headers | Borrowed read leases |
| 14 | GPU substep plan | Private |
| 15–40 | Original twenty-six consumer outputs | Private |

Published and batch headers are 1×2; control is 1×4; the other headers are 1×1.
The thirteen-resource bundle is acquired transactionally; aliased handles or
partial acquisition return every successful temporary lease. Two slots hold at
most twenty-six read pins. A graph owns twenty-seven outputs; the bridge's bounded
schema ceiling increases from 32 to 48. Original consumers, cache schemas and
typed values are preserved; only resource bindings shift.

The GPU plan reuses frozen s95 common/plan code and additionally checks the
field/history/head previous IDs, finite integral normalized debt, remaining plus
consumed equals 2²⁰, bounded cap, unfinished checkpoint, fresh flag and counters.
It returns `(dtSeconds, active, remainingSeconds, normalizedStep)`.
Invalid plans may retain a diagnostic remainingSeconds value; dt and active must
be zero. Some original consumers would simply perform a stationary dt=0 step.
Therefore publication separately requires all four plan components to match the
sealed snapshot and the source identity, before the trusted result verifier.

Host queue publication epoch/token and physical snapshot epoch/interval ID are
separate domains. This adapter does not claim a full physical ledger commit.
Bridge packet IDs are local lifetime tokens, not substituted physical IDs.

## 5. Verification

`check_s138_snapshot.py` and `finalize_s138.py` record:

- **282 WARP draws, 13 /WX /Ges synthetic shader bodies**, no warnings.
- Five dynamic intervals: both axis orders, baseline/double stock, 15.625–62.5ms
  substeps, partial debt, changed IDs/generations/head counts and a queued interval.
- All 130 consumer comparisons match bit for bit: 52 against frozen full-step
  outputs, 78 against separately supplied constant-plan wiring controls.
- Sixty logical/bank pairs, twenty end-only checks, per-axis and cumulative
  End/Mean conservation with existing 64/128-ULP bounds, nonnegative mass,
  zero invalid recipients and matching intermediate copies. Float64 map
  differences are reported separately; no criterion is relaxed.
- **29 snapshot guards and 29 GPU header rejections**, including legacy layout,
  fractional host ticks, nonfinite inputs, stale/mismatched IDs and blocked debt.
- **19 ownership/lifecycle cases**: shader pending retains accepted prefixes;
  early return/writes refuse; partial steps advance only their own duration;
  bad/missing plans cannot publish; reset retains submitted headers; changed
  header resources invalidate execution; acquisition rollback releases pins.

WARP uploads test arrays between draws. Lifecycle replay uses those cached outputs
with mocked immutable sources and mocked physical completion. This gives neither
zero-upload performance evidence nor actual CSP completion/retirement authority.
Previous s137 actual CSP evidence remains frozen and independently scoped.
No s138 game app is installed; no new gameplay test is required at this stage.

## 6. Next gate

Exercise genuine GPU-produced headers, partial interval plans and imported
consumers together in an isolated CSP probe, retaining used allocations without
claiming a fence. Then connect an actual End/Mean producer with force/source and
head/ledger semantics. Live adoption still requires numerical admission,
completion ownership, recurrent physical accuracy and measured target cost.
