-- RainFX v2 control-flow test with CSP API stubs. Needs Lua 5.2+ semantics (__len on tables): texlua docs/tools/rainfx2_mock/run_mock.lua <repo root>
local root=arg and arg[1] or '.'
dofile(root..'/docs/tools/rainfx2_mock/mock_csp.lua')
local factory=dofile(root..'/rainfx2/init.lua')
local core=factory({folder=root,targetMesh=function() return target end,
  surface={root='/x/',validate=function() return true end},maskPath='/x/mask.dds',surfaceOffset=0.0005})
assert(not core.err, core.err)
for f=1,3 do
  core:simulate({frame=f,dt=1/60,focusedCar=0,rainIntensity=0.08,rainWater=0.5,rainWetness=1,carsCount=3,windVelocityKmh=vec2(3,4),fogColor=rgb(.6,.65,.7),lightColor=rgb(2,2,2),cameraUp=vec3(0,1,0),cameraSide=vec3(1,0,0)})
end
print('status',core.status, 'opticsReady',core.opticsReady)
print('draw colour',core:draw({name='src'},'k1',false),'again',core:draw({name='src'},'k1',false),'depth',core:draw({name='src'},'k1',true))
local st=core.stats
print(string.format('R=%.1f mm/h D=%.2f impacts=%.0f /m2/s stick=%.2f micro=%.3f speedRel=%.1f',st.rateMMh,st.meanDiamMM,st.impactRate,st.stickFrac,st.microRate,st.speedRel))
print(table.concat(calls,' | '))
core:ui()
calls={}
core:simulate({frame=4,dt=1/60,focusedCar=0,rainIntensity=0.08,rainWater=0.5,rainWetness=1,carsCount=3,windVelocityKmh=vec2(3,4),fogColor=rgb(.6,.65,.7),lightColor=rgb(2,2,2),cameraUp=vec3(0,1,0),cameraSide=vec3(1,0,0)})
assert(calls[1]=='RainFX2 cells B' or calls[1]=='RainFX2 cells A', 'seed pass expected first: '..tostring(calls[1]))
local d,i=core.diag,core.inp
print(string.format('after ladder: %s | substeps %d | rc grav coat %.2f glass %.2f air %.2f mm | v r0.5 %.2f r1 %.2f r2 %.2f | step limit %.2f m/s | car %.1f air %.1f',
  table.concat(calls,' '),core.p.substeps,d.rcGravCoat,d.rcGravGlass,d.rcAllCoat,d.v05,d.v10,d.v20,d.vGather,i.carSpeed,i.airSpeed))
print(string.format('spray %.3f cars %d nearest %.1f filmRate %.3f mm/s splash %.3f mm eq %.3f mm flow %.3f m/s',core.stats.spray,core.sprayInfo.cars,core.sprayInfo.nearestM,core.stats.filmRate,core.stats.filmSplashMM,core.diag.filmEqMM,core.diag.filmVel))
core.store.metrics=true
core:simulate({frame=5,dt=1/60,focusedCar=0,rainIntensity=0.08,rainWater=0.5,rainWetness=1,carsCount=3,windVelocityKmh=vec2(3,4),fogColor=rgb(.6,.65,.7),lightColor=rgb(2,2,2),cameraUp=vec3(0,1,0),cameraSide=vec3(1,0,0)})
assert(core.metrics and math.abs(core.metrics.film-0.5)<1e-6, 'metrics readback')
print(string.format('metrics film %.2f drops %.2f haze %.2f', core.metrics.film, core.metrics.drops, core.metrics.haze))
core.offscreenTest='pending'; core.colourViewKey=nil
core:draw({name='src'},'k9',false)
print('offscreen test: '..tostring(core.offscreenTest))
assert(core.camPos and core.camPos.x==1, 'camera position at draw time')
core:ui()
core:dispose(); print('ok')
