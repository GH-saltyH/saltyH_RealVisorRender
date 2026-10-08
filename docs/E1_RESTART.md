# E1 reset

## Current status: fully removed; design only

The user clarified that none of the E1 implementations produced a working
result. Earlier descriptions of a successful first reflection map were based
on a communication error and must not be used as an accepted baseline.
Shader compilation and Lua/API mocks did not prove visible output in the game.

All E1 runtime configuration, UI, shader registrations, dedicated draw entries,
shader code and E1-only capture conditions have been removed. The native
material experiment and its assets were already removed. There is no new E1
implementation in this reset.

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
