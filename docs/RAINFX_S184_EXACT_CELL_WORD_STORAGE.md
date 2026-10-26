# s184 — exact cell words in RG32_UINT

Status: offline actual-grid cache and physical previews verified,2026-10-20.
Game physics remains s87;diagnostics remain s89.

## Representation and admission

The retained raw-cell cache previously held four FP32 channels per field cell:
local physical area,coverage,coating and an active flag. Current baked coverage
is a count of covered samples out of four. Active cells have positive area and
coverage in`{.25,.5,.75,1}`;inactive cells have zero coverage and a zero flag.
The active flag equals`area>0`. Coating is a nonnegative FP32 value at most1.

The selected codec stores **two UINT32 words** per cell:

| Word | Layout |
| --- | --- |
|0 | Original FP32 area bits,unchanged |
|1 bits0–29 | Original FP32 coating bits,unchanged |
|1 bits30–31 | Active coverage code`coverage*4-1` |

FP32 coating from positive zero through1 leaves its upper two bits clear.
The decoder masks the coating bits,extracts the coverage code and derives the
active flag from positive area. It returns the original four logical FP32 words.
Inactive coverage is derived as zero;the encoder uses code zero for those cells.
Area and coating are never rounded or converted to half precision.

This is a scoped codec,not a format for arbitrary physical packets. Host and
native admission require finite nonnegative area/coating,normal positive area
or zero,exact quarter coverage,matching area/active flag and exact roundtrip of
all four words. Negative-zero coating,unsupported coverage,inconsistent flags,
subnormal positive area and out-of-range values refuse. A different bake must
meet this contract or use a separately admitted representation;it is not rounded
into this one.

The private descriptor's storage code3 means **R32G32_UINT**,8B/texel,with four
logical FP32 channels on upload/debug readback. This is not a three-channel float
texture. Both the uploaded immutable raw file37 and retained cache3 use this
format. The producer copies integer words,and ten transformed cache/audit/source
consumer shader bodies use a checked typed integer load plus the logical decoder.
Shapes,field samples and physical equations remain unchanged. The native owner
restricts this format to those two cell resources and checks typed load/render
support before allocation. Other physical fields cannot enter it accidentally.

Integer storage is essential. In the actual field67,031 material words would
look nonfinite if incorrectly interpreted as floats. They remain UINT values
through upload,copy and typed storage;only the masked original coating and area
words are bitcast back to FP32. No NaN payload preservation is assumed.

## Native and numerical evidence

The actual1024×256 cache executes **83 draws /13 real completion events**,with
initial build,weather reuse,rigid-pose replacement,failed preparation,retry and
return to the original pose.

- All79,891,024 saved logical FP32 words match s183 bits. This includes the
  complete raw-cell field,full-input audit fingerprints,world metric,areas,runs,
  force,resolved source cells and receipts,geometry lookup and controlled stock.
- Four independent double-precision SI force checks retain the existing32ε
  accuracy gate;maximum normalized ratio remains0.399833.
- Existing reader,queue,failure and retirement checks remain:14 atomic retirement
  refusals,4 resource-specific reader checks and4 in-flight reader-return
  refusals. The held-force pose remains admitted without evicting its observer.
- Six malformed payloads and two wrong-format cases refuse **before device
  creation**. They cover coverage,alpha,negative-zero coating,coating range,
  nonfinite area,subnormal area,legacy cell storage and format misuse on area6.
- Independent Python and native CPU codec checks cover119 combinations across
  every coverage tag,adjacent FP32 coating values,minimum normal/maximal finite
  area,inactive cells and coating endpoints. All original FP32 words roundtrip.
- The ten referenced transformed shaders compile with`/WX /Ges`;C++ uses
  `/W4 /WX`. Native debug checks report zero warnings. No extra draw is added.

Actual-grid physical force and raw→resolved source-cell previews execute in
this cache component. Water stock and solver time do not evolve here. The
complete actual-grid cache/source/head/transport transaction is not executed;
this stage does not repeat the unrelated615-draw small physical reference.
Native event completion does not verify general CSP Canvas completion.

## Memory and cost

Raw-cell upload and retained cell cache each shrink **4→2MiB**. Both coexist
during cold construction,so the initial cold allocation drops4MiB. The uploaded
file retires after its verified last use;the retained/warm saving is2MiB.

| Actual-grid cache component | s183 | s184 |
| --- | ---: | ---: |
| Initial cold allocation |40.243805MiB |36.243805MiB |
| Replacement/retry maximum |52.096207MiB |50.096207MiB |
| Final retained set |28.094543MiB |26.094543MiB |
| Separate audit staging maximum |40.094666MiB |38.094666MiB |

The initial builder's later post-retirement preview can exceed its initial cold
allocation;its complete build/preview maximum is38.111221MiB. The replacement
maximum in the table covers the whole cache test. These are texture descriptor
bytes,not measured resident VRAM or total process memory. CPU logical readback
still expands the packed field to FP32;CPU fixtures,driver/shader allocations
and separate staging are outside the default-texture count.

| Full warm descriptor proposal | s183 | s184 |
| --- | ---: | ---: |
| Static inputs |27.850433MiB |25.850433MiB |
| Maximum simultaneous live set |64.992050MiB |**62.992050MiB** |
| Exact-shape reservation |71.807526MiB |**69.807526MiB** |

Independent format-aware lifetime certification passes;all18 force/source-cell
last-reader records remain identical. The proposed live maximum now fits64MiB
with1.007950MiB margin. **The overall64MiB gate still fails**:persistent typed
pool reservation exceeds it by5.807526MiB,and complete joint execution remains
unverified. The plan keeps every previous required adapter gate and adds the
packed-cell handoff gate. No execution authorization or alternative cap is granted.
Cold/changing-pose overlap of the whole physical owner remains unexecuted.

The shader change adds fixed bit extraction,masking and coverage reconstruction,
without another texture lookup,scan,loop or draw. Native startup validates and
encodes immutable input on CPU. Target GPU/CPU milliseconds and FPS remain
unmeasured,so no speedup is claimed. Live CSP typed-format support and common
optics remain open.

Next reduce persistent typed-pool reservation and working/bank overlap while
preserving physical outputs and reader leases,then compose actual-grid cache/
source/head/transport ownership with atomic stock/time publication. Main app,
settings,production shaders/assets and installed game are preserved. No user
game test is needed for s184;Git stamping remains with the user.

Evidence:`diagnostics/2026-10-20/s184/cells_checks.json`,native reports and
snapshots,ten referenced compiled bodies,codec contracts,eight pre-device refusal
logs,`numerical_audit.json`,`joint_plan.json`,physical last readers,source diff,
archive manifest and`delivery.json`. Earlier frozen builders must not regenerate
their evidence.
