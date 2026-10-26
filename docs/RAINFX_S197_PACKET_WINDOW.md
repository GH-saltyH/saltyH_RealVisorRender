# s197: bounded interval input and command window

2026-10-20. Parent s196. Status: ACTIVE. Offline D3D11 WARP/debug only.

## Result

Physical input bytes and instantiated draw commands are now held for one interval
at a time. Common shader/binding/constant schemas are stored in56 immutable
templates. A new interval replaces the previous window before cache refresh and
physical work;adaptive retry keeps and edits the current request without reloading
its original bytes. Replacement is refused during flight or an active recovery
cursor. The three-request queue still admits identities and exact time debt;
waiting requests do not require decoded payloads.

All64 intervals pass with the same stock/ledger/checkpoint,owner transitions,
adaptive attempts and1,457,304,640 retained GPU readback bytes as s196,bit for bit.
No physical shader,DSD,size,display gain,source amount,force or timestep changes.

This is a bound on the packet's active payload and command count. The complete
CPU streaming gate remains **open**:resource lifetimes,phase indexes,frame/bank
descriptors,audit sets and the file directory remain unrolled across64 intervals.
There is no longer-duration or target-FPS result in this stage.

## Representation and observed sizes

| Packet component | s196 full packet | s197 active interval |
| --- | ---: | ---: |
| Input payload bytes | 21,420,272 | maximum12,985,328 during initialization |
| Subsequent interval input bytes | retained together | 133,888 each |
| Instantiated draw commands | 14,977 | maximum235;subsequent234 |
| Common command schemas | repeated in every command | 56 immutable templates |

The parser enforces at most16MiB of active input byte-vector payload,32 input
rows,256 commands,1MiB encoded command data and64 templates. Observed maximum
encoded command data is14,904B. These are payload/record bounds,not a measured
C++ heap/RSS limit:map nodes,vector capacities,string storage,shader reflection,
resource indexes,geometry/reference programs and driver allocations are outside
these numbers. The previous window containers are destroyed before loading the
next. Ownership moves the packet into the native owner rather than duplicating
the active payload. CPU staging/readback buffers remain separate.

The stage-private serialized packet shrinks27,080,545→22,422,757B. Schema templates
contain shader paths and ordered texture/uniform names with exact uniform widths;
per-command records carry the unchanged logical IDs and FP32 constant bits.
The initial seed inventory is uploaded only in its original first interval.

An offline preprocessing tool still reads the complete frozen packet/graph to
produce this stream. The native reader also retains64 directory rows. Neither
the packer nor the entire native harness has bounded total memory independently
of interval count. Disk paging is a diagnostic input provider,not a proposed
game-frame filesystem dependency;live inputs need a bounded engine provider.

## Verification

- The native reader reconstructs all1,101 original input arrays(21,420,272 bytes)
  and all14,977 commands. An independent Python reader checks each input byte,
  binding ID,shader name,uniform key and FP32 constant byte against the original
  frozen physical packet,for every interval.
- Six newly executed native parser controls reject template-count overflow,
  wrong interval identity,input-size overflow,command-count overflow,invalid
  command-template ID and invalid output ID. These are parser controls before
  creating a GPU device;they do not prove live transactional recovery from an
  asynchronously changed input file.
- Every upload/phase/transport-role index is identical to s196. The runtime
  reports exactly64 window loads after setup. Main input validation and index
  construction each additionally walk64 windows before execution;the runtime
  window-load count intentionally excludes those setup passes.
- The full64-bank physical audit,water/momentum closure,integer tick debt,
  source-once/retry behavior and dynamic creation/release identities pass.
  All cold,physical and cache readbacks match s196 bits. Strict native compilation
  and D3D debug checks report no warnings.
-265 adaptive attempts:262 accepted and3 refused/recovered. Maximum49 physical
  draws per native pump. Default-texture peak remains66,577,136B(63.492905MiB),
  final owned default textures0B. GPU work/allocation churn is unchanged.

The initialization index now decodes windows while constructing its immutable
indexes. Observed index construction377.554ms,cumulative upload/phase lookup
regions11.693ms,and diagnostic native run44.882s on this host. These are one
run's telemetry,not a paired performance benchmark against s196. Lookup regions
exclude decoding,upload and candidate processing and include timer overhead.
Host wall times include disk I/O,WARP,debug validation,synchronous
readbacks and file output. This change is not evidence of lower CPU latency,
faster game loading or target GPU/FPS improvement. No wall-time callback budget
or general CSP completion fence is established. The legacy near-cancelled UV
component diagnostic from s191–s194 remains a recorded failure;conservation and
bit parity do not reclassify its physical/time-accuracy criterion.

## Evidence and next work

Evidence: `diagnostics/2026-10-20/s197/packet_manifest.json`, `decoded.bin.json`,
`refusal_checks.json`, `run.window.json`, `window_audit.json`, `window_checks.json`,
native traces and complete retained readbacks. The finalizer only audits saved
evidence and streams archives;it does not rerun the solver or earlier builders.

Next compact the unrolled resource/phase/frame metadata into reusable interval
templates with explicit previous/current-bank bindings and generation identities.
Keep the same capacity,reader,cache and adaptive-debt refusal rules. Then extend
continuous duration and measure allocation churn and target CPU/GPU cost with
diagnostic reads separated. Actual CSP scheduling/completion and common optics
remain open. Production is s87,diagnostics s89;main/settings/production shaders,
assets and installed game are unchanged. No user game test,commit or push.
