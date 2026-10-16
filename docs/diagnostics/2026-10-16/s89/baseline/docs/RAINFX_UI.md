# RainFX tuning menu

Updated 2026-10-07. The RainFX tab is a two-column button menu. Each button
opens a separately scoped, scrollable popup. Closing a popup stops drawing
its widgets; runtime values and enabled effects remain active. Popups use
the same tab/column ID scope for open and begin calls. No tuning defaults
were reset by this reorganisation.

## Groups

| Category | Popups |
|---|---|
| Simulation and births | Population and GPU birth sites; Birth sizes and weather ranges; Rain exposure and lifetime; Forces and water physics; Coalescence and steering |
| Water layers | Moving drop shape and growth; WF heads and optics; Impact splash and tearing; Trail flow and optics; Fast-flow sheet; Local impact film; Micro pattern and landing; Wipe paths, film and ridge; Haze and condensation; Smear mask and facets |
| Scene and colour | Large-drop optics; Water tone; Refraction source and tone; Depth and shimmer; Visor scene stack |
| Diagnostics | GPU rendering and performance; Debug modes and single-drop probe; Render stage probe; Archived overlay experiments |

## Usage audit

The old and new UI setting-key inventories match: no previous parameter
was lost. Runtime reads, shader inputs and UI-only preview consumers were
checked. No entirely unreferenced tuning setting was found in this UI.
Conditional effects are retained and labelled rather than mistaken for
unused settings.

| Finding | Treatment |
|---|---|
| Trail/sheet minimum radius and minimum motion were edited twice | One editor in Trail flow and optics; sheet popup displays the values and points there |
| Impact-film smear refraction strength was edited in smear and film | One editor in Local impact film |
| Legacy WF trail turbidity, blur, clearing and G visibility do not control neutral refraction in full smear interiors | Labels and help explain they affect region transition overlays; trail refraction strength remains the active interior control |
| WF sheet blur is bypassed by cylindrical trail refraction | Moved to WF heads and optics; sheet popup points to the dedicated trail sheet blur in Trail flow and optics |
| Wet-path steering requires shader code | Available/OFF status shown in Forces and water physics |
| Overlay P0/P1 and HUD lift are optional/archived rendering experiments | Dedicated diagnostic popup; overlay-specific widgets now require that actual optional path to be enabled |
| Pre-laid birth debug only previews the atlas in UI | Retained as a valid UI consumer, rather than deleting it for lacking a renderer read |
| Freeze probe and R1 toggles are diagnostic/performance tools | Freeze moved to GPU rendering and performance; restart/reload requirements retained |
| ResetTime11 and stale default-airflow/debug captions | Clear reset label and current-state explanations |

Performance smoothing and timing range sampling remain at the RainFX tab
cadence even when the performance popup is closed. Only drawing of the
profiler widgets is conditional on the popup.

## Verification

- Entire realvisor.lua compiled with LuaJIT 2.1, including its local-variable
  limit. Callback scopes keep individual panel locals isolated.
- All 24 panel callbacks executed against a mock of the installed CSP UI
  APIs with default values, all feature switches enabled, and all disabled;
  the single-drop mode branch was also exercised.
- Open-panel wrappers returned with balanced popup and child-window stacks.
- Original RainFX key inventory preserved; configuration defaults unchanged.
- Installed CSP SDK confirmed beginPopup/endPopup, columns/nextColumn,
  availableSpaceX and childWindow signatures used here.
- Actual in-game popup sizing, scrolling and widget appearance still need
  confirmation; the mock does not render the game UI.
