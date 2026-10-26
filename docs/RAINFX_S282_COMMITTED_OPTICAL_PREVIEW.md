# s282: continuous physical RainFX optical preview

**Current mode,2026-10-25:** [deposit + drying baseline](RAINFX_PRODUCT_DEPOSIT_BASELINE.md)
replaces optional active film transport in this same P0 entry. UI shows the mode;
119 owned resources plus optical snapshots, rather than128. Drops move and leave
paths; the film reservoir is stationary and dries. Source/state/time checks remain.
Actual CSP validation is pending. Earlier transport descriptions below are history.

The main app now contains a default-OFF product preview. It connects actual input
capture, the s281 fixed 32 Hz owner and the accepted s278 solver to the existing
visor head raster and physical film optics. There is no three-second run limit.
This is a visible candidate, not a new invisible diagnostic app.

**Feature/visual scope correction,2026-10-25:** field evaporation and micro→film
conversion are now [connected and locally verified](RAINFX_PRODUCT_FIELD_LIFECYCLE.md)
after the audit found them missing. Actual CSP validation remains pending.
It still publishes completed32Hz head positions without render interpolation,
and display gains shrink only heads. Shared water accounting does not establish
final visual consistency. See [preview visual contract](RAINFX_PREVIEW_VISUAL_CONTRACT.md).

Background throttling now uses an explicit model pause with retained stock and
current-pose preparation on return. Background rain time is excluded and reported;
see [policy and validation](RAINFX_S282_BACKGROUND_SUSPENSION.md). Actual CSP resume
is unverified. Foreground source conservation failures 64/288 are still open.
The later outside-source mask8 has a locally validated absolute deposition scale
[amendment](RAINFX_S282_DEPOSITION_CANCELLATION.md); actual CSP success is pending.
The head walk now retains its last valid position on bounded-work exhaustion;
[very fast drops can under-travel](RAINFX_S282_BOUNDED_HEAD_TRAVEL.md). The
iteration cap and physical water stock are retained. Actual CSP acceptance of
this amendment is pending.

## Activation and one useful evaluation

Use a fresh rainy game/replay session; leave the older diagnostic apps/panels OFF.
In Real Visor Overlay → RainFX → Weather inputs and physical units (P0):

1. Enable **continuous physical RainFX preview**.
2. Press **Start continuous physical RainFX** and wait for `running`.
3. Observe stationary and driving output, head/film relationship, visible steps,
   disappearing layers and sustained performance. A single representative run is
   sufficient before deciding the next work; do not repeat invisible three-second
   sessions. `Log physical RainFX summary` records counters if needed.

This path starts dry. Existing `Display diameter gain` and birth display scale
change rendered heads only. Film optical gain, maximum offset and `P3 view` remain
the existing controls; view 0 is normal optics. P1/P2/P3 toggles need not be enabled
for this preview. Keep rain/DSD overrides off, as required by captured input scope.
Changing physical material/calibration, replay seek or focused-car ownership
requires a fresh runtime. Disable returns rendering to the existing path; resources
remain retained until app/session ends. Only one start per app reload is allowed.
Stop drains accepted work and freezes its final optical snapshot. Disable hides it.

The preview requires the existing RainFX rendering/layer configuration to be
enabled. It does not change saved material or renderer configuration. On owner
fault or overload, physical publication stops and legacy rendering resumes; the
error and retained time debt remain visible in the panel.

## Specific GPU publication contract

CPU receipt callbacks arrive several render frames after submission. Selecting a
bank by the last CPU-audited serial would therefore read a reused bank. Instead:

- The existing graph selects all committed roots before its last `receiptCopy`.
- A new read-only executor export is unavailable during warmup and until a live
  accepted audit. Warmup serial reuse cannot open the optical path.
- A 1×1 GPU selection pass chooses the larger valid A/B receipt serial. During a
  partial A write, A's old receipt is older than complete B, and conversely.
- The selection is frozen for all three subsequent optical copy passes in the
  same main scene-ready callback. Solver submission does not interleave these
  copies. A newer refused receipt hides output rather than displaying its candidate.
- Both banks and optical targets remain owned for the session. No CPU-selected
  stale bank, additional readback or general GPU-completion-fence claim is used.

The exported views are read-only by contract; the renderer never owns solver
storage. The existing callback guard excludes recursive offscreen/native captures.
Repeated callbacks in the same simulation frame do not advance the owner twice.

## Units, rendering and cost

Four additional reusable RGBA32F targets: selection 1×1, state N×1, meta N×1,
film 1024×256. Their total payload is `4 MiB + 32*N + 16 bytes` (4.125 MiB at
4096 heads). They cost four draws per rendered frame and zero extra CPU readbacks.
The existing head raster is reused with explicit state/meta/count inputs; its
tiling/metric passes are not a new all-heads-per-pixel algorithm. A separate fp16
birth target uses the configured resolution, about 8 MiB at 2048×512. These are
descriptor payloads, not measured driver allocation or whole-app memory.

- Raw state XY is visor UV with Y in [-1,0]; ZW remains UV velocity.
- Authoritative meta G is mm³. Optical meta R is recomputed as spherical-cap
  contact radius from that volume and the captured material contact angle, then
  multiplied by the captured reference UV/mm. The old opaque radius codec is not
  interpreted as physical size. Display gains apply later in head rasterization.
- Film/micro mm³ divided by scalar cell mm², multiplied by 1000, yields R/G µm.
  Zero-area cells produce zero. The 60000 µm optical cap changes no inventory.
- Head and film snapshots share the same selected GPU commit. No extrapolation
  or render interpolation is added; possible 32 Hz stepping remains a visual gate.
- Legacy New Trail, wipe/micro-pattern, Smear, haze and local impact-film overlays
  are suppressed in this path. Physical micro coverage is provided by the film
  optics. No saved switches are overwritten. Merge and localized pool return are
  still OFF in the integrated solver and belong to s283.

## Evidence and limits

`docs/tools/check_s282_product.py` checks the deployed host/menu startup, real
capture/typed binding and continuous owner using mocked engine/GPU services,
same-frame reentry, OFF behavior, warmup/accepted-audit export gating, fault
revocation and the actual main head-raster function's input/display-gain seam.
Prior fixed-step cases cover 30/60 FPS, long frames, pause, refusal and scale reset.

Three new optical programs compile with FXC `/WX /Ges` and execute eight native
D3D11 WARP draws: A/B commit selection, refused output, volume/contact-radius
conversion, film/micro µm and zero-area handling. WARP is a software D3D11 oracle,
not actual CSP or hardware timing. Main Lua and all deployed modules parse, and
the game's existing docs symlink resolves every deployed file.

Actual CSP appearance, throughput and full-app 2048/4096 performance have not yet
been measured. Local checks do not establish FPS or claim the final RainFX model
is complete. The next game evaluation must inspect the visible candidate once;
only a concrete rendering/safety failure should interrupt the remaining essential
interaction work. Source modules from s280/s281 and sealed old prototypes remain
unchanged; new derivatives are under `docs/runtime/s282` to use existing deployment.

## First CSP entry correction

The first actual entry failed before product GPU allocation at the clock type
check. CSP exposes `os.preciseClock` as callable cdata; the established s245 Lua
wrapper was missing from the new host. Both host and pipeline now normalize it.
The deployed-host test now uses a real LuaJIT ffi cdata callback. This is a host
compatibility correction, not a physical or tolerance change. The first game run
does not qualify visuals. Main-app reload permits retry in the same game session.


현재 deposit+drying 경로의 날씨 연결 범위와 누적 진단 정책은
[날씨 반응 기록](RAINFX_WEATHER_RESPONSE_AND_DIAGNOSTICS.md)을 따른다.
