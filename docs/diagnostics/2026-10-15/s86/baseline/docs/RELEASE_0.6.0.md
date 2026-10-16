# RealVisor 0.6.0 — accepted RainFX baseline

Status (2026-10-07): REFERENCE — validated 0.6.0 baseline, main integration authorised by the user.

## Scope

User accepts the current RainFX for publication. Includes the GPU persistent
4096-slot baseline and R1.1–R1.4 head/splash path, birth-size tuning, WF trails,
fast-flow sheet, neutral-refracting impact film, micro/haze/smear layering,
soft smear eligibility, and the grouped RainFX popup UI. Version metadata
is aligned to 0.6.0 in Lua and manifest.ini. Existing tuned effect values are
preserved. Physics refinements are deferred in RAINFX_ROADMAP.md.

## Performance cleanup

- CPU profiling clocks are opt-in via `RAIN_PERFORMANCE_PROFILING`, default
  false. Enable “CPU timing and diagnostic counters (profiling)” in the GPU
  rendering and performance popup to measure; inactive timings are marked.
- Per-drop sheet eligibility counting is skipped when profiling is off.
  Sheet generation and actual shape are unchanged.
- Disabled stage capture does not register six render callbacks. Its toggle
  requires a Lua reload so captures remain registered before the rain draw.
- Mirror/main visibility switching callbacks are registered only for the
  archived overlay path. That optional path now requires a Lua reload.
- Unused tests and shader diagnostics remain available. Their disabled paths
  do not add capture passes. One-time readiness/error logs remain.
- Smoke draw stage, geometry shot/sky correction and the housing shadow probe
  are functional rendering inputs despite historical DEBUG/PROBE names and
  remain active as tuned. Disabling them would change the accepted look.

No FPS gain is claimed without an in-game comparison. The purpose is to
remove diagnostic work from the normal release path.

## Validation and distribution

Validation passed: complete LuaJIT compile (including local count), both
RainFX shaders with FXC ps_5_0 /Ges /WX, all 24 UI panels in default/ON/OFF
states, release flag/version audit, and Git diff checks. In-game
visual acceptance comes from the user's tests; no game performance run is
performed automatically. Existing KN5 assets remain under the repository's
asset/archive arrangement; main integration does not upload a new binary
package or create a GitHub Release.

After main integration, visor E1–E7 work continues on a separate development
branch so experimental glass changes do not alter the released RainFX.
