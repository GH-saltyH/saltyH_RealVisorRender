# s272 — source context comparison and replay capture (2026-10-24)

## Actual result and narrowed cause

s271 stopped on **serial15, reason517 =512+4+1**. The source context guard
rejected; source checkpoint/decision then failed as consequences. At that first
refusal the transport/head-consistency/cohort/conservation bits were clear. This
is not evidence of a transport stability or queue-capacity failure. No tolerance,
physical force, diameter, source rate or queue capacity should be changed to
bypass this condition.

Actual report:27 submitted/audited, pending0, resources128;14 accepted slices,
advanced0.2619743347s, retained debt0.2449941635s. All28 CPU readback objects were
disposed. Density59.82/m³, rain0.6, first refused dt0.01767730712890625s,
source frame726. Published incident/stock/exits remained zero. The later final
receipt adds the propagated-prior failure, so the preserved **first** receipt is
the diagnostic authority. Evidence is the unchanged s271 actual observation.

The existing context guard combines token/checkpoint/producer receipt/shape/stamp
checks. Its red output only gave accept/refuse;517 does not identify which of
those comparisons failed. No root-cause fix is claimed yet.

## Focused diagnostic on the same execution path

s272 retains the original context function and **identical red acceptance bit**.
Its unused GBA channels now carry a context mask and head-receipt namespace/serial.
Only a refused joint receipt exposes those values in its former momentum-detail
slots; accepted receipts remain unchanged. No additional target or GPU readback
is introduced. Both diagnostic shader strings are cached once per graph.

| Context bit | Comparison |
| ---: | --- |
| 1 | Source token finite/integer/identity bounds |
| 2 | Previous source token matches published token and current token |
| 4 | Published source checkpoint phase |
| 8 | Physical head producer receipt matches source token |
| 16 | Head header token matches source token |
| 32 | Source/head grid, padding and count |
| 64 | Source stamp/frame and integer bounds |
| 128 | Mode and bounded head timestep |

On first refusal only, retain the **admitted** CPU input and preceding input's
pose. Four bounded log lines hold the52 FP32 header/unit rows without decimal
loss; two more carry provenance and previous pose. The collector reconstructs
the admitted input for local numerical replay. This is intended to avoid another
round of broad environment/visual/FPS measurements: obtain the failed comparison
and the input needed to reproduce it locally. The total report stays below20
lines in a fresh session's log quota.

## Verification and next action

-22 native draws compare the original/new guard at serial14/15/16 and eight
 failed comparisons. Acceptance is identical; injected cases produce their
 expected context masks, including cascading comparisons after token damage.
-15 controlled owner cases include exact current/prior admitted-input retention.
-Seven real-adapter panel cases include refusal, all52 rows reconstructed by the
 collector, previous pose logging and actual main-menu dispatch.
-All55 distinct graph shader variants compile with the observed CSP prelude.

Original sealed physics, s271 elapsed warmup fix,128-resource working set, queue
limits and source-time preservation remain. This is a diagnostic extension, not
successful actual combined execution or measured FPS.

Run a fresh unpaused rainy session with other diagnostics OFF:
**Enable s272 joint rain transport → Start s272 joint rain transport**.
Report State and **First refused / reason mask / context mask**, or successful
advanced/debt/incident values. Detailed replay inputs are automatic. No separate
probe app or FPS/image matrix. After collecting that failed comparison, fix and
test the concrete producer/header condition using the captured input.
