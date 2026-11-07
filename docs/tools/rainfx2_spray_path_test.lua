vec3=function(x,y,z) return {x=x,y=y,z=z,length=function(s) return math.sqrt(s.x*s.x+s.y*s.y+s.z*s.z) end} end
local cars={}
ac={getCar=function(i) return cars[i+1] end}
-- run from the project root: texlua docs/tools/rainfx2_spray_path_test.lua
local S=dofile('rainfx2/spray.lua')
local p={} for k,v in pairs(S.DEFAULTS) do p[k]=v end
p.sprayWheelWater=true
local function wheels(h) local w={} for k=0,3 do w[k]={waterThickness=h/1000} end return w end
local function mk(x,z,vx,vz,h) local v=math.sqrt(vx*vx+vz*vz); return {position=vec3(x,0,z),look=vec3(vx/v,0,vz/v),velocity=vec3(vx,0,vz),wheels=wheels(h),isConnected=true} end
-- straight: lead at 60 m/s, me 15 m behind, h 0.9 constant
local sim={dt=1/60,focusedCar=0,carsCount=2,rainWater=0.3,rainWetness=0.12}
local out={}
for f=0,240 do
  local t=f/60
  cars[1]=mk(0,60*t,0,60,0.9)
  cars[2]=mk(0,60*t+15,0,60,0.9)
  S.estimate(sim,p,out)
end
local lwcPath=out.spray
p.sprayPath=false
for f=241,300 do local t=f/60; cars[1]=mk(0,60*t,0,60,0.9); cars[2]=mk(0,60*t+15,0,60,0.9); S.estimate(sim,p,out) end
print('straight path / legacy-smoothed', lwcPath, out.spray)
-- puddle off-line: lead drives on x=3 (puddle 2.5 mm at z in [300,303]), I drive x=0 then move into x=3 at z 310..
p.sprayPath=true
for k in pairs(out) do out[k]=nil end
local maxS,maxSplash=0,0
for f=0,600 do
  local t=f/60
  local zl=60*t+20; local zm=60*t
  local hl=(zl>300 and zl<303) and 2.5 or 0.0
  local xm= zm<290 and 0 or math.min(3,(zm-290)/5)
  cars[1]=mk(xm,zm,0,60,0.0)
  cars[2]=mk(3,zl,0,60,hl)
  S.estimate(sim,p,out)
  if out.splash>maxSplash then maxSplash=out.splash end
  if out.spray>maxS then maxS=out.spray end
end
print('off-line puddle: max spray LWC', maxS, 'max splash', maxSplash)
