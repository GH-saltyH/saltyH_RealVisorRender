-- rev48 wind source test: texlua docs/tools/rainfx2_mock/wind_source_test.lua <repo root>
local root=arg and arg[1] or "."
dofile(root..'/docs/tools/rainfx2_mock/mock_csp.lua')
-- compass: north = +Z rotated by 30 deg track heading, clockwise = toward +X
ac.getCompassAngle=function(d) return (math.deg(math.atan2(d.x, d.z)) + 30) % 360 end
local P=dofile(root..'/rainfx2/physics.lua')
local p={terminalSpeed=7, windK=1}
for k,v in pairs(P.DEFAULTS) do if p[k]==nil then p[k]=v end end
-- live: wind blowing toward +X at 36 km/h; meteorological 'from' direction compass = compass(-X)
local from=( -90 + 30) % 360
for i=1,60 do P.inputs({focusedCar=0, windVelocityKmh=vec2(36,0), windSpeedKmh=36, windDirectionDeg=from}, p, {}) end
print('calibrated offset', p.windDirOffsetDeg)
local o=P.inputs({focusedCar=0, isReplayActive=true, windVelocityKmh=vec2(0,0), windSpeedKmh=0,
  weatherConditions={wind={direction=from, speedFrom=36, speedTo=36}}}, p, {})
print(o.windSource, o.airW.x, o.airW.z)
