# s158 — selected bank continuation

Status: ACTIVE — offline selected-graph parity and rollback checks passed
Date: 2026-10-19

## Change

The s157 reference continuation calculates both logical and bank transport.
s158 selects the checked bank ABI for both axes and removes unreachable
comparison outputs. It uses the same selected numerical operators, physical
force/recipient bodies, material constants and acceptance bounds. This is an
uninstalled private continuation recipe, not a game solver update.

The reduction does not pool or recycle targets. Each remaining output still has
its own descriptor and retained storage. It reduces the number of outputs that
are created in the first place.

## Selected graph

1. Redirect logical map/leaves/groups/totals/gather references to the matching
   bank results on each axis. Select bank transport for recipient force and
   runoff accounting. Remove the logical branch by dependency reachability.
2. Keep the bank totals and their status checks for **both axes**. The inherited
   decision still requires valid transport and recipient status; no readiness
   flag is forced true. The redundant logical status calculation is removed.
3. Specialize the final step ledger, cumulative ledger and checkpoint selectors
   using the exact parent expressions. Remove texture bindings absent from the
   frozen shader text, then remove outputs with no remaining consumer or root.
4. Write final film/mean directly from recipient data after accepted finish.
   Finish already requires the inner flow decision, so the intermediate
   film/mean selection copies are unnecessary. On refusal both final outputs
   select the original physical film, as before.
5. Expose pinned micro and heads as aliases of immutable input roots5 and4.
   Their contents do not change in a source-applied film continuation, including
   on refusal. The input owner/read lease must remain retained while those
   outputs are consumed. This is not permission to release or overwrite inputs.

Dependencies retain every lexical texture reference, including helper bodies;
there is no speculative branch-readiness analysis. The eleven import positions,
physical force layout and named output meanings are preserved. New cache keys
separate changed binding schemas from the reference graph.

## Verification

The WARP harness executes the frozen s157 graph and selected graph from identical
immutable input packets. All named output roots are compared bit-for-bit,
including inventory, source, eligibility, film/mean, decisions, both ledgers and
the retained-time checkpoint. It also checks physical inventory against ledger
stock using the unchanged128-epsilon closure bound and1e−9 floor.

Coverage includes both orders at13×7 and273×17, a nonempty pinned head,
actual1024×256 dry/static/thin physical film in both orders, and a second
physical quarter using the first result's film/history/debt. Actual geometry
and physical input rows remain the frozen main-app frame660 from s154/s157.
The controlled actual-grid fixture starts with1µm film,0.1µm pinned micro and
4096 empty head slots. This does not test birth/head evolution or active-slot
saturation. The small nonempty-head control only tests pinned ownership.

Wrong debt, source token, material and unbalanced input history must refuse with
exact original film/mean/heads/micro/history/checkpoint restoration. Malformed
history is preserved on refusal; the solver does not silently balance it.
Additional selected-axis status and flow-ledger corruptions must also refuse.
Neither source replay nor public stock/clock publication is introduced.

Sixteen paired executions comprise10 accepted cases and6 refusals. The14
non-injected comparisons match every named root bit-for-bit; the2 injected
faults check selected-path refusal and exact restoration. Eight invalid CPU
recipe requests also refuse. Verification uses1,824 WARP draws and47 strict
shader compilations. The physical actual-grid film/checkpoint/ledger outputs
also match the retained s157 result archive. These are serialized offline
checks, not target GPU timing or a recurrent CSP bank.

An initial harness comparison failed because target-index-based compiler file
names could overwrite a cached shader file when grid dimensions changed the
resource order. Filenames now identify the complete shader/binding schema; the
failed packet archive is retained. A second harness assertion incorrectly
required an intentionally unbalanced input ledger to become balanced on refusal;
the check now requires exact rollback of that malformed history. Neither fix
changes the transport or physical equations.

## Descriptor cost

| Actual1024×256 /4096-slot continuation | s157 reference | s158 selected |
| --- | ---: | ---: |
| Shader passes |73 |50 |
| Resources, including11 imports |84 |61 |
| Nominal retained descriptors |199.9678MiB |130.3114MiB |
| Retained field cache + continuation, shared world inputs counted once |212.3670MiB |142.7106MiB |

Twenty-three private targets disappear, saving69.6563MiB. The removed work
includes logical transport, logical input copies, unused end-only gathers,
unused force input extractions, intermediate film/mean/head commits and final
micro/head copies. All consumed physical force/recipient/exchange/evaporation
outputs remain.

The selected graph still exceeds the64MiB owner budget. Static last-read
accounting gives76.9537MiB as a diagnostic lower frontier, not proof of GPU completion or safe
reuse. Counts exclude the source-image cache, driver overhead and birth/head
evolution. There is no target GPU timing or FPS claim, and no new CSP allocation.

## Next

Reduce the source-applied path's remaining staging/recipient storage while
preserving physical/context validity, runoff/exchange ledgers, rollback and
time debt. Establish a bounded resource lifetime/completion policy and live
inventory authority before adopting recurrent execution. Keep the full graph
as the offline oracle. No additional game test is requested for s158.

Evidence: `docs/diagnostics/2026-10-19/s158/lean_checks.json`, `cost_checks.json`,
`layouts.json`, `results.npz`, `harness_notes.json` and `delivery.json`.
