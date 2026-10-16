# E1 reset

## Current status: stage 1/2 visually verified; stage 3 primary prototype

The accepted design now has a custom surface-output diagnostic, disabled by
default. It tests existing mesh visibility, draw placement and depth without
reflection/source sampling. See E1_STAGE1_TEST.md for concrete in-game checks.
Stage 1 passed user visual evaluation on 2026-10-08. Stage 2 adds an isolated
helmet-housing capture preview (E1_STAGE2_TEST.md). Stage 2 source isolation passed user visual evaluation. Stage 3 adds a
directional INT primary prototype (E1_STAGE3_TEST.md). The user observed
only gradients, not identifiable interior forms. Actual capture matrices and
source-depth parallax now require re-evaluation. Ghost tracing remains deferred.

The user clarified that none of the E1 implementations produced a working
result. Earlier descriptions of a successful first reflection map were based
on a communication error and must not be used as an accepted baseline.
Shader compilation and Lua/API mocks did not prove visible output in the game.

All E1 runtime configuration, UI, shader registrations, dedicated draw entries,
shader code and E1-only capture conditions have been removed. The native
material experiment and its assets were already removed. There is no new E1
optical implementation in this reset. The later surface diagnostic is not E1
reflection and does not reintroduce the removed optical code.

RainFX, INT E2/E3 optics and soft defocus, EXT final band ordering and normal
relief remain. The post-rain HDR copy is retained for INT. UTF-8 BOM protection
is retained because it fixes a reproduced common-shader compile failure.

The new optical design is documented in E1_OPTICAL_DESIGN.md. Its minimal scope
is aperture-lit interior reflection plus an artistic secondary ghost from the
same interior source, with MIP blur, source-edge fade and relative-luminance
selection. Exterior reflection, thin-film interference, scratch glare and RainFX
normal coupling are deferred. Implementation
must start from visible custom geometry and explicit optical paths/source
coverage. Do not restore the opposite-hemisphere camera-HDR workaround, assume
native material output, or label compilation success as rendering success.
