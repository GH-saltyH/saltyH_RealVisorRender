# s271 — bounded warmup and earliest refusal (2026-10-24)

## Actual s270 results: neither run passes

1. User-reported first session: warmup fault `bounded shader pending`, no
   submitted/audited interval and128 resources. Its earlier log is unavailable.
2. The preserved second-session log:29 submitted/audited, zero pending,128
   resources. Only14 source slices accepted: advanced0.3039197922s,
   debt0.2703256607s from raw0.5742455982s. Source closure holds. All30 readback
   objects (including warmup) were disposed. Warmup succeeded, max live pump
   4.9059ms, callbacks still10 frames, median169.747ms. Incident/stock/exits are
   all zero. This does **not** qualify supply or continuous combined throughput.

The old limit counts256 failed `updateWithShader` returns, so its allowed waiting
time varies with frame rate. Async shader compilation can still be pending when
that count is exhausted. The second log shows additional compile work during
capture, but does not identify the first run's exact pending shader.

The second result's final receipt belongs to serial29, after the first rejection
and its suffixes. It only reports a generic bad flag; the earliest refusal and
its failing condition were not retained. The zero incident value could reflect
failed source publication, not a physically dry environment. The actual reason
is **unresolved**; no physics/tolerance/queue relaxation is justified by this log.

## Implemented correction and diagnosis

- Replace retry-count exhaustion with elapsed pending time:20s per shader during
  warmup,5s after warmup. Each attempt yields on `false`; no blocking wait or
  extra submissions per frame. Overall startup/run limits remain60/70s. Timeout
  names the cache key/pass and elapsed time. Source-age/audit limits are unchanged.
- Keep the **first** refused serial, receipt and source context while draining
  suffixes. Never replace it with a later propagated rejection.
- In the existing16-float receipt, add a reason bitmask **only for refusal**.
  Accepted output is unchanged. Water/time/momentum validation, selectors and
  rollback rules remain the original s267/s269 rules. No extra GPU canvas or
  readback is allocated; the diagnostic shader is built once and reused.

| Bit | Failed condition |
| ---: | --- |
| 1 | Source decision/token validity |
| 2 | Physical/raw head consistency |
| 4 | Source checkpoint phase/token/dt |
| 8 | Head/physics cohort or dt |
| 16 | Compact transport receipt or clock |
| 32 | Invalid cumulative ledger row |
| 64 | Cumulative conservation residual |
| 128 | Prior accepted receipt/time |
| 256 | Producer frame guard |
| 512 | Source context guard |
| 1024 | Unclassified original refusal |

## Local evidence and limits

The unchanged physical graph was tested natively from **dry initial stocks**,
4096 slots and current full bake with a declared1000/m³ supply fixture. Three
recurrent source intervals accept: cumulative incident22.317835→22.421917→
22.747581mm³; final stock11.007752 and exits11.739829mm³. All293 draws and full
water/momentum checks pass. The controlled density exceeds the recorded input
and is **not** actual engine supply qualification or an FPS test. It demonstrates
nonzero birth/source/transport together, which s269's short zero-arrival native
case did not cover. This does not reproduce the actual game refusal.

Additional verification:18 native receipt draws across nine accepted/refused
cases preserve the original first15 floats exactly and report matching reason
bits;15 controlled owner cases include >256 pending warmup callbacks, a real
elapsed timeout and earliest-refusal retention; six real-adapter panel/menu
cases pass. All55 distinct shader variants compile with the observed CSP sampler
prelude. Original sealed physical sources and s269/s270 evidence are preserved.

## Next action

One fresh unpaused rainy session, other diagnostics OFF:
**Enable s271 joint rain transport → Start s271 joint rain transport** in the
same P0 section. Report State and, if stopped, **First refused / reason mask**
and error text. Submitted/audited/pending and advanced/debt are also useful.
The full first receipt and source summary are logged automatically; no new
standalone app, FPS matrix or imagery is needed. The same128 canvases and about
133+40.13MiB private/file textures remain session-retained. Optics is disconnected.
The elapsed warmup fix is ready, but the second failure still needs this actual
condition code before a specific physical/runtime fix can be selected.
