# s261 — refusal provenance before bounded recovery (2026-10-23)

## Implemented

`prototypes/s261/s261_graph.lua` wraps the sealed s260 graph. The decision used
by the final receipt is the **source-applied finish decision**, not the inner
flow decision. Accepted z/w already carry continuation state and must not be
repurposed. All accepted channels remain unchanged. On rejection only, decision.g
carries a bit mask. Existing receipt word14 exports it; blocked suffix receipts
preserve the first failure code rather than replacing it with zero.

No added passes, textures, bindings, allocation, or relaxed acceptance conditions.
The diagnostic branches run only on rejection. They reuse the original helpers
and arithmetic, including packet/ledger tolerances.

| Bit | Failed condition |
| ---: | --- |
| 1 | Boundary admission |
| 2 | Inner flow decision |
| 4 | Flow/admission interval agreement |
| 8 | Flow ledger packet validity or balance |
| 16 | Flow initial stock / input inventory agreement |
| 32 | Unexpected flow source row |
| 64 | Unexpected flow reserve row |
| 128 | Cumulative ledger packet validity |
| 256 | Cumulative ledger balance |

Bits may combine. Bit2 does not prove CFL: the inner decision includes several
checks. These codes identify a failed condition, not its physical cause. Original
s260 logs cannot retrospectively recover this information.

## Verification and scope

`tools/check_s261_refusal.py` executes21 native D3D WARP draws: nine paired
decision fixtures and three receipt cases. Accepted decision bits, rejection
classification, receipt export and blocked-suffix propagation pass. Both changed
shader bodies compile through the native harness. Recipe resources and storage
maps remain identical. Evidence: `diagnostics/2026-10-23/s261/checks.json`.

This wrapper is not installed in the main app. No new probe or user test is
requested. Runtime performance and actual cause of the s260 refusal remain
unmeasured. This is supporting implementation, not a transport-fix claim.

## Remaining recovery work

The existing s241 dyadic retry controller is bounded and retains unaccepted time.
It cannot simply be enabled in s260: suffixes have already been submitted and
their projected headers have advanced. Recovery must first drain those receipts,
retain the last accepted film/checkpoint/history, reset the private projection
to that accepted boundary, then replay original queued inputs with bounded
subdivision. Unknown/invalid input or ledger faults must stop; they must not be
treated as evidence that a smaller step is safe. Retry caps retain debt on
exhaustion. This wiring and staged/cached startup remain to implement before
another integrated game gate. Do not repeat isolated latency probes.
