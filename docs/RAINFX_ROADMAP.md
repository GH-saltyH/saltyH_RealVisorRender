# RainFX roadmap (items accepted but not scheduled)

## R1. GPU drops pre-laid like the micro pattern (added 2026-10-02)

The source is review item 1 in `RAINFX_REVIEW_2026-10-02.md`.

**Goal.** Control many more drops smoothly, with birth sites laid out in
advance and selected by intensity, as the micro pattern does.

**Plan, in order.**

1. **GPU-side WF head stamping.** Draw the WF head canvas from the state
   texture (`txRainState` / meta) with an instanced or point-sprite pass.
   This removes the per-drop CPU loop in `waterFieldDrawStamps`, which is
   the real ceiling.
2. **Atlas-driven respawn.**
   - Bake a spawn atlas in visor UV. Each texel holds position jitter, a
     size class and an activation order, like the micro gate.
   - The state shader's respawn reads site
     `(slot + generation × K) mod N` and becomes active only when its order
     is ≤ the rain intensity.
3. **Raise the state texture size** once steps 1 and 2 hold (10k+ slots),
   with the readback kept for the stats only.

**Not before.** The current optimisation and optics work on this branch has
to be finished first.

## R2. Visor glass pass (see `RAINFX_VISOR_GLASS.md`)

This depends on the outcome of the diagnosis in §2 of that document.
