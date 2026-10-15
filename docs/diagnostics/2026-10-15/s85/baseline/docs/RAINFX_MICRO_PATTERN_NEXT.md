# Micro pattern: requirements for the next rework (2026-09-30)

Status: implemented as v2, see `RAINFX_MICRO_PATTERN.md`. Original status: requirements for the next
micro-pattern task.

## User observations (zoomed in-game capture)

- The current pattern is not dense enough for its purpose. Disks must overlap
  **much more**, so that cut-out fragments form varied shapes: half-moons,
  crescents and dots.
- Boundaries between overlapping disks must stay visible. The cut lines must
  not look merged partway along.
- Keep the low-resolution look when zoomed. From a distance it gives a useful
  visual trick: natural glitter and shading instead of a pattern.

## Current bake (for reference, `realvisor.lua` micro pattern shader)

- Jittered grid with 2 strata, a 3×3 neighbour search each, and presence
  0.63.
- One fixed disk radius: 0.56 cell in lens-local units. The visible interior
  is < 0.78 local (`0.81 - EXTRA_RIM_WIDTH`).
- The highest-priority disk owns the pixel and punches out its own thin rim.
  Rims therefore become gaps to the live scene (now haze), not visible
  outlines.
- Per-disk rain gate in B.

## Direction

1. **Density and variety.**
   - 3–4 strata with higher presence, so a point is covered by 2–4 disks.
   - Radius varies per disk (about 0.35–0.85 cell) instead of one size.
   - Newer disks occlude older ones, so older disks survive only as
     crescents, half-moons and small dots.
2. **Visible cut lines.** Keep a thin rim band inside the *winning* disk's
   edge, darker or with a Fresnel accent, instead of punching it to the
   background. This keeps boundaries readable where disks meet. Store "rim
   distance" in the bake so the runtime can shade it without extra search.
3. **Fragment optics.** Each surviving fragment keeps its own disk's lens
   coordinates, so a crescent refracts like the part of a drop it is. Consider
   switching to the water-field refraction rule (slope × field) for
   consistency with the heads.
4. **Low-res trick.** Keep the bake at the current texel density or lower, and
   sample so that texel steps stay visible up close.
5. **Rain gate.** Keep the stable per-disk reveal order, but gate strata
   separately, so light rain shows sparse whole drops and heavy rain shows
   dense fragments.
6. **Validate** with the micro debug view at max rain and at 0.3, zoomed in
   and at normal distance, and with haze on and off.
