# s178 — disabled feedback inputs and physical consumer lifetimes

Status: offline native component and lifetime proposal verified, 2026-10-20.
Main game physics remains s87; diagnostics remain s89.

## Integration boundary

s177 safely returns a diagnostic force/resolve preview after its own last read.
The actual physical pipeline has longer dependencies. Its two-frame plan records
sixteen quarter-step force buffers and two resolved source-cell buffers. The
X force survives status/map/exchange consumers; the Y force survives status,
post-step and ledger consumers. Source cells survive the complete source stage.
These18 records retain exactly their original readers and completion lifetimes
in `physical_last_readers.json`. The diagnostic preview retirement rule is not
applied to these physical outputs. The s177 cache owner is not yet composed
with the actual-grid physical owner.

Before that composition, this step removes unnecessary storage from the existing
**wet-feedback OFF / pool-return OFF** reference profile. It does not disable
either feature in the game, change water equations or change the core roadmap.

## Neutral-input implementation

The birth kernel reads wet-height feedback only when context row8.y is enabled,
and pool candidates only when row10.x is enabled. For a validated immutable
context with both flags exactly zero, the existing positive-zero images may be
represented by two1×1 RGBA32F images. All original birth, head, source, force,
transport and export shader equations stay unchanged. No shader specialization
or extra per-particle branch is introduced.

The host validates the context schema, frozen OFF flags, input ownership,
binding identities and every original neutral payload before changing recipes
or creating the native device. Nonzero, nonfinite or negative-zero payloads
cannot qualify. Wet/pool enabled contexts refuse this path; they require the
original full physical inputs. Turning either feature on later requires a new
validated input set and memory admission, not changing the flags beside compact
textures. The existing owner keeps contexts immutable through queued execution.

## Native verification

The original bounded physical stream executes with the compact inputs on one
native D3D11 WARP context:13×7 field,8 head slots, three source ON/OFF/ON frames,
birth→head→source→four transport quarters→eight bank copies. It performs
**618 draws /37 observed completion events /32 copy operations**, three atomic
bank/cache publications and46.875ms of published solver time. Cache preparation,
source and copy failures, retry, replay refusal, old readers and time-debt closure
remain verified. Every root and unchanged import matches frozen s174 bits; all
inventory copies match exactly. Independent head-force, source and water-ledger
oracles pass. Only the two neutral import shapes differ.

This small native fixture removes4,320 input bytes across its three recipe
records. Its actual texture-descriptor peak falls409,232→406,336B: retained
generation overlap and pooling determine that measured2,896B decrease. This is
not a measured4MiB full-grid physical-pipeline decrease.

Five native negative cases refuse before device construction: enabled wet,
enabled pool, nonzero neutral data, negative zero and wrong input binding. Host
validation also rejects nonfinite data and leaves caller arrays unchanged.
Native C++ builds with `/W4 /WX`; the D3D debug layer reports zero warnings.

An additional44 native draws compare original and compact inputs for **4096
slots /1024×256 field** with the full-resolution lossless geometry dictionary:

- Planar controlled geometry: accepted birth with nonzero incident volume;
  all nine public roots retain their FP32 bits.
- Canonical curved du/dv geometry with a controlled all-supported boundary:
  all nine roots retain bits and protocol acceptance. Incident volume remains
  zero in both paths for this supplied pose/incident configuration. This is not
  a demonstration of nonzero actual-curved birth or coupled curved recurrence.

Four strict-compiled shader bodies serve those44 draws; original/compact paths
use the same bodies. The total component evidence contains662 draws. Only the
physical stream's37 explicit completion events are counted; the standalone
readback runner does not establish a CSP Canvas completion protocol.

## Full warm plan recount

The frozen dictionary two-frame End-bank plan is independently recertified after
changing only the two disabled input descriptors. Original read lists, force/
source-cell last reads, all working targets, inventory copies and completion
boundaries are preserved.

| Descriptor proposal | Previous MiB | s178 MiB |
| --- | ---: | ---: |
| Static inputs |37.866028 |33.850433 |
| Maximum simultaneous live set |79.007645 |74.992050 |
| Exact-shape reservation |89.823166 |**85.807571** |

The wet image is4,194,304B and pool image16,384B; two16B replacements remove
**4,210,656B /4.015594MiB** in each column. This is a warm declared proposal,
not execution or measured residency of the complete actual-grid owner. Cold
construction, pose replacement, old readers and staging still need a common
accounting/execution boundary. Its64MiB admission still refuses; no alternate
budget or runtime policy is adopted. Actual target GPU time/FPS is unmeasured.

Next reduce the remaining physical force/map/gather/bank overlap and compose
cache/head/source/transport ownership while preserving the recorded last reads.
Then verify complete actual-grid stock/time publication and target cost. Main
app, settings, production shaders/assets and installed game are unchanged.
No user game test is requested; Git stamping remains with the user.

Evidence: `diagnostics/2026-10-20/s178/feedback_checks.json`, native reports,
full-slot reference/compact roots, `physical_last_readers.json`, `joint_plan.json`,
`numerical_audit.json` and `delivery.json`.
