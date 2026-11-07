local P=dofile('rainfx2/physics.lua')
local p={} for k,v in pairs(P.DEFAULTS) do p[k]=v end
for _,kmh in ipairs({60,100,130,180,240,280}) do
  local U=kmh/3.6
  local ue,a,delta=P.aeroScales(p,U)
  local function rc(th)
    local uE=ue*math.sin(th)
    local r=3
    for i=1,40 do local xb=0.6*r/delta; local u=uE*(xb<1 and xb*(2-xb) or 1); local We=1.2*u*u*2e-3*r/0.072; r=r*math.min(12/We,1)^(1/3) end
    return r
  end
  print(string.format('%3d km/h ue %.1f m/s delta %.3f mm  r_c: theta30 %.2f  theta60 %.2f  theta90 %.2f mm', kmh, ue, delta, rc(math.rad(30)), rc(math.rad(60)), rc(math.rad(90))))
end
