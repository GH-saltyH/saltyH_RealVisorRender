# RainFX roadmap (accepted items, not scheduled) — updated 2026-10-05

See `docs/README.md` for the document index and working rules.

## R1. GPU drops pre-laid like the micro pattern (added 2026-10-02) — STARTED 2026-10-05 (`RAINFX_GPU_PRELAID.md`)

Source: `RAINFX_REVIEW_2026-10-02.md` §1.

**Goal.** Control many more drops smoothly, with birth sites laid out in
advance and selected by intensity, as the micro pattern does.

**Plan, in order.**
1. **GPU-side WF head stamping.** Draw the WF head canvas from the state
   texture (`txRainState` / meta) with an instanced or point-sprite pass;
   removes the per-drop CPU loop in `waterFieldDrawStamps`.
2. **Atlas-driven respawn.** Spawn atlas in visor UV (jitter, size class,
   activation order); respawn reads site `(slot + generation × K) mod N`,
   active when its order ≤ rain intensity.
3. **Raise the state texture size** (10k+ slots) once 1 and 2 hold; readback
   for stats only.

**Not before** the visor scene stack (R2) is stable.

## R2. Visor scene stack and glass optics — IN PROGRESS

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
