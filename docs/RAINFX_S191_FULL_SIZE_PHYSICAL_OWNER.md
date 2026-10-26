# s191 — full-size native physical owner and recurrent water inventory

Status: two fixed-context intervals execute the actual physical graph on the
s190 native allocation owner, 2026-10-20. Water stocks and solver time publish
together after completion and explicit reader return. Main runtime remains
physics s87/diagnostics s89; this is an offline D3D11 WARP experiment.
No game test is required.

## Physical connection

The s190 warm canaries are replaced by physical birth, SI head motion and
transfer, resolved source cells, conserved source application and four transport
quarters per interval. Inputs use the frozen s152 actual visor transform,
material, weather, baked geometry and physical assets. The real s189 bootstrap
cache objects move into the same counted owner without replacement uploads.

The graph uses 4096 head slots, a1024×256 water field, the2048×512 geometry
dictionary index, packed derivative table and4096×1024 R8 boundary. Existing
half runs, cell words, packed metric and End-only output adapters are retained.
Disabled wet/pool feedback remains an explicit, checked specialization.
No display-diameter gain, Smear or local impact-film correction enters it.

The explicit initial inventory is a3µm film,0.25µm micro stock and48 attached
0.5mm³ heads with tangential motion, totalling about154.93796mm³. These are
test initial conditions, not new runtime weather tuning. One initial GPU draw
derives head inventory from the same state/geometry/transform arithmetic used
by the head producer. It uses existing textures and the existing entry event;
no lifetime, allocation size or completion boundary grows.

Each interval lasts0.016877174377441406s. Four quarters consume its exact
remaining debt without reapplying incident water. After the first interval,
the next birth/head/source stages consume the retained GPU state, metadata,
film, micro, head packets, ledger, checkpoint and pose. CPU stock reuploads
are absent. Both intervals publish exactly0.033754348754882812s in total.

## Numerical checks

Two runs use identical physical settings and initial stock. One preserves
birth ticks1/2 and has no discrete arrival; the other uses controlled RNG
ticks669/670, selected to exercise an arrival with unchanged weather/supply.
This seed selection is a test condition, not a weather-rate adjustment or a
claim about arrival frequency. The auxiliary CPU tick forecast is diagnostic;
the measured GPU packets are the authority.

The positive-arrival run records one42.85897446mm³ incident packet, partitioned
into approximately21.67050743 attached,11.57034874 film,5.76133490 micro and
3.85678291 bounced water. Both frames produce head-to-film trails; the second
frame transports water created by the first. All eight physical transport
quarters change film values and finish with zero interval debt.

- Independent Float64 clipped-kernel/source calculations compare the complete
  raster, committed film, micro and step ledger. Maximum error/tolerance ratio
  is0.053561 using the preserved32ε relative /1e-9 absolute criterion.
- Independent SI force calculations compare physical world velocities. Maximum
  discrepancy is about1.102e-8m/s; maximum error/tolerance ratio is0.278655
  under32ε times world-speed norm, with a1e-9m/s floor.
- Water and momentum closure is checked at head transfer, source, every
  transport quarter and retained bank. Head tolerances sum only physical
  accounting terms; support coordinates and status indices cannot inflate them.
- In the positive run, the final cumulative water residual is approximately
  -1.614e-5mm³, below its0.006037mm³ FP32 accounting bound. The final retained
  inventory is about186.224178mm³; evaporation, runoff and wall/force terms
  remain explicit in the ledger.
- Both banks' eight fields are bit-identical to their selected producer roots.
  Metadata volume equals retained head-packet volume. Source failure/retry
  outputs are bit-identical and source is not replayed by transport.
- The full cold cache proof remains bit-identical to frozen s189.

### UV-component diagnostic retained

The old per-component UV force criterion fails one nearly cancelled component
in the first frame:6.7347690e-5 versus6.7346065e-5, about1.625 times its1e-9
absolute floor. The second frame passes that criterion. This failed diagnostic
is explicitly retained, not reported as a pass. On the curved metric, UV
components are coupled; the independent physical world-velocity norm comparison
passes in both frames, with maximum errors8.657e-9 and1.102e-8m/s. No physical
coefficient or shader precision qualifier was changed to obtain that result.
Long-run accumulated error remains to be measured.

## Input and ownership faults found

Two refused attempts are preserved:

1. Separately rounded CPU initial head momentum differed in96 FP32 words from
   the GPU's canonical packet.46 slots failed the exact pair check; source
   correctly returned the old stocks/checkpoint/ledger and zero step ledger.
   The GPU initialization draw fixes the producer mismatch. The exact pairing
   criterion is unchanged.
2. The second frame's transport request still carried the prior birth tick.
   Its boundary gate refused and returned film/history/checkpoint bit-for-bit.
   Request metadata now advances with the immutable source tick. The tick and
   interval-debt guards are unchanged.

Native loader checks also refuse seven malformed programs before device
creation: undeclared reads, wrong viewport, nonfinite input, enabled feedback
against the disabled specialization, nonbinary boundary, stale/wrong bank
generation and missing producer. Bank fields have exact types and retention
windows; consumers must be declared in the lifetime schedule.

## Counted native execution

| Per run metric | Result |
| --- | ---: |
| Physical schedule draws |469, including one initial-inventory draw |
| Physical draws with deliberate source retry |486 |
| Cold cache draws, including deliberate retry |68 |
| Total shader draws |554 |
| Native completion events |38 |
| Bank/time publications |2 |
| Default texture peak |66,572,192B /63.488190MiB |
| Margin to original64MiB cap |536,672B |
| Warm generations, including7 adopted inputs |107 |
| Retired warm generations |29 |
| Final counted default textures |0B |
| Separate warm audit staging peak |17,758,192B |
| Separate cold audit staging peak |26,479,936B |

The peak and all creation/retirement totals match the s190 independent lifetime
certificate. Completed cache validation failure/discard/retry and completed
source failure/retry stay within the cap. Pending work and old published-film
readers block publication. A held retirement victim blocks the whole batch.
An extra8.125MiB geometry revision at the high retained frontier refuses
before allocation. All checks retain accepted = published + active + queued
time, and cleanup leaves no owned texture or reader.

C++ builds with `/W4 /WX`; all56 used shader bodies compile with `/WX /Ges`.
The native debug layer reports zero warnings. Counts concern default texture
descriptors; staging, CPU fixtures, driver/shader allocations and padding are
outside this64MiB scope. Draw/event counts include test faults and audits and
are not a game performance measurement. No FPS or target-GPU speed claim is made.

## Remaining roadmap

The **fixed-context native physical64MiB gate passes**. This is the first full
actual-size cache/source/head/transport run with recurrent water and time
publication. It is two controlled intervals, not a live or long-duration test.

1. Compose pose/weather cache-generation refresh with the physical owner. Schedule
   old/new cache overlap and blocked requests without evicting readers or losing
   accepted time; test failed preparation and return-pose retries.
2. Exercise longer repeated streams and inventory ranges, measure accumulated
   numerical error, retained-object stability and allocation churn.
3. Verify the required CSP completion/retirement mechanism and default-off
   engine bridge. Native D3D events do not prove general Canvas completion.
4. Measure target GPU/CPU cost, connect common head/film optics, then validate
   live appearance and movement. Smear/local film remain optional corrections.

The broader pipeline adoption gate remains open for those unverified paths.
Main script, settings, production shaders/assets, installed game and Git HEAD
are preserved. Git stamping remains with the user.

Evidence: `diagnostics/2026-10-20/s191/physical_checks.json`, positive and
zero-arrival physical/audit programs, phase/owner traces, independent numerical
audit, two refused-input archives, shader hashes and final `delivery.json`.
Earlier frozen builders/checkers were not rerun.
