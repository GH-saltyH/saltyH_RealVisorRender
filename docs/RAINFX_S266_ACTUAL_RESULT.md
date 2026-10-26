# s266 actual CSP result — 2026-10-24

The controlled-film continuous execution gate **passes**. User ran a fresh,
unpaused session and reported observed, 171 submitted/audited, pending zero,
50 resources, 3.012811 seconds advanced and zero retained debt. Automatic log
collection independently matches those values. The original local delivery and
implementation document remain sealed as the pre-run record.

| Actual measurement | Value |
| --- | ---: |
| Source frames / accepted slices | 171 / 171 |
| Original source time | 3.01281030010432 s |
| Advanced Q20 time | 3.0128107070922852 s |
| Retained debt | 0 s |
| Quantization remainder | -0.406987965 µs |
| Source = advanced + debt + remainder residual | 0 s |
| Captured but unadmitted source time | 0 s |
| Draws including warmup | 6,190 |
| Private resources / descriptor bytes | 50 / 109,678,064 |
| Readbacks / disposed CPU data objects | 172 / 172 |
| Reuses / shader-pending retries | 160 / 33 |
| File hash checks | 40 |
| Graph/context executor construction | 4.6019 ms |
| Maximum allocation preparation callback | 1.1136 ms |
| Maximum live owner pump | 7.2193 ms |
| Maximum unsubmitted source age / frame lag | 0 s / 1 frame |
| Peak audited time debt during run | 0.241226196 s |
| Audit median / p95 / maximum | 163.3063 / 189.5626 / 211.2433 ms |
| Audit latency in frames | 10 for all 172 callbacks |

The warmup contributes one readback and is excluded from live input counts/time.
Final GPU receipt identifies serial 171, accepted. Initial water 805.7722778320312
mm³; final water 774.2756958007812 mm³; accumulated exit 31.49649429321289 mm³.
Their difference is 0.000087738037109375 mm³, about 0.0000109% of initial stock.
The reported ledger residual is -0.00006103515625 mm³. Both fit the existing
FP32 mass tolerance. Invalid state/flux diagnostics are zero.

## Decision and remaining limits

Keep the compact execution route. Unlike the failed s262 CPU-recovery path,
this actual run finishes all captured source time without growing the queues,
losing stock/time, or retaining final debt. Private commits and bounded small
audit reuse operate recurrently in this scoped actual CSP run.

The 10-frame audit callback latency is unchanged; submission now overlaps it.
This does not establish that a renderer can wait for an audit without visual lag,
nor establish a general GPU completion fence. Public optical publication still
needs its own consumption/ownership contract. The 7.2193 ms CPU maximum exceeds
the 3 ms soft pump budget: non-preemptible preparation/SDK work can overrun a
deadline. It is a performance concern for the later frame-time check, not a
reason to reject this source-time/ownership gate. No per-pump distribution or GPU
execution time was measured here, so no average cost/FPS projection is inferred.

This is one three-second controlled 20 µm film run. Rainfall supply, new heads,
micro water, impact, pool return and optical rendering are not connected to it.
It does not qualify sustained full-app throughput, 2048/4096-drop cost, the
complete startup experience or visual fidelity. No additional repetition of this
same probe is required. Next work is conserved source/head coupling, then optical
consumption and a focused full-pipeline frame-time/visual check.

Evidence: `diagnostics/2026-10-24/s266/actual_observation.json` and
`actual_delivery.json`. Main solver code was not changed to process this result.
