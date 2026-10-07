# RainFX roadmap (accepted items, not scheduled) — updated 2026-10-07

See `docs/README.md` for the document index and working rules.

## R1. GPU drops pre-laid like the micro pattern — accepted for 0.6.0 (2026-10-07) (`RAINFX_GPU_PRELAID.md`)

Source: `RAINFX_REVIEW_2026-10-02.md` §1.

**Goal.** Control many more drops smoothly, with birth sites laid out in
advance and selected by intensity, as the micro pattern does.

**Plan, in order.**
1. **GPU-side WF head stamping.** Draw the WF head canvas from the state
   texture (`txRainState` / meta) with an instanced or point-sprite pass;
   removes the per-drop CPU loop in `waterFieldDrawStamps`.
2. **Atlas-driven respawn.** R1.2 prototype bakes valid visor-UV sites and
   stable activation order on the GPU, behind a toggle. In-game validation
   is pending; size class remains on the existing birth-size path.
3. **Raise the state texture size** (10k+ slots) once 1 and 2 hold. A
   sparse-word GPU head pass is now behind a toggle for scaling tests;
   CPU trail/splash/readback work still needs bounding before 10k+ slots.

**Current result (2026-10-07):** user accepts the current RainFX for release.
R1.1–R1.4, local impact film, sheet tuning and grouped UI form the 4096-slot
baseline. User captures reached roughly 50+ FPS in the demanding scene;
instantaneous captures are variable and are not a universal FPS guarantee.
Further particle-cap increases are not a release requirement.

## Deferred RainFX movement finish — user request, no date scheduled

- Use currently available physical inputs to produce naturally curved paths
  rather than excessively straight movement.
- With no sustained driving force, let water gradually lose speed and stop.
- At Rain or higher intensity, allow appropriate downward flow while parked.
- Separate tuning factors for adhesion, external acceleration, curvature,
  dissipation and rain feed so adjusting one goal does not break another.
- Preserve the accepted trail/film appearance and physical coordinate model.

Do not implement these changes in the 0.6.0 release. No reminder or automatic
execution time was requested; this is a deferred engineering backlog.

## R2. Visor scene stack and glass optics — resumed after 0.6.0 integration

Replaces the former "R2 visor glass pass" (`RAINFX_VISOR_GLASS.md` §3.C/§4).
Work and open items: `RAINFX_VISOR_LAYER.md` §17–§20.
- S2 verification of the scene stack (order, brightness).
- Shadows and local lights for the custom housing.
- Shadow signal for the glass optics (§15.1).
- V3 glass base (E2 relief normal, E3 lens/tear, E4 band transmission).
- V4 light effects (E1 strong-light projection, E6 scratches, E7 interior
  projection).

## Closed / withdrawn
- Post overlay (P0–P4, HUD lift): **archived** 2026-10-04
  (`RAINFX_POST_OVERLAY.md`).
- `RAINFX_WATER_FIELD.md` backlog #3 (metallic non-sky contrast with many
  large drops): **closed 2026-10-05**, not important; re-open if it recurs
  in the latest build.
