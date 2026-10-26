-- Actual s239 engine capture with its bootstrap reference exposed to the owner.
-- No new API probe, image allocation or physical interpretation of track water.
local M={}
function M.new(d,options)
 local function load(stage,name)return dofile(d.folder..'/docs/prototypes/'..stage..'/'..name..'.lua')end
 local Context,Assets=load('s152','s152_context'),load('s152','s152_assets')
 local reference
 local function pose(mesh)
  assert(#mesh==1,'one visor mesh');local m=mesh:getWorldTransformationRaw();local r={}
  for i=1,4 do local v=m['row'..i];r[i]={v.x,v.y,v.z,v.w}end;return r
 end
 local capture=load('s239','s239_capture').new({api=d.api,Inputs=load('s238','s238_inputs'),Packet=load('s239','s239_packet'),
  Compose=load('s239','s239_compose'),assets=Assets,live=d.live,poseRows=pose,clock=d.clock,
  bootstrap=function()
   local boot=Context.new({api=d.api,Inputs=dofile(d.folder..'/docs/probes/s151/s151_engine_inputs.lua'),
    Packet=dofile(d.folder..'/docs/probes/s151/s151_header_packet.lua'),assets=Assets,live=d.live,poseRows=pose,hashFile=d.hashFile})
   local result=boot.result
   function boot:result()
    local c=result(self);if c then local live=d.live();c.configuredScale=live.configuredScale;c.appliedScale=live.appliedScale;reference=c end;return c
   end
   return boot
  end},options)
 function capture:reference()return reference end
 return capture
end
return M
