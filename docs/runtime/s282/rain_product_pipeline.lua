-- Host seam for the fixed-cadence product owner. No new menu or automatic start.
-- Host retains the existing graph, backend, verified files and initial context.
local M={}
local function cp(t)if type(t)~='table'then return t end;local r={};for k,v in pairs(t)do r[k]=cp(v)end;return r end
function M.new(host)
 local d={};for k,v in pairs(host)do d[k]=v end;d.seed=cp(host.seed)
 local function root(n)return dofile(d.folder..'/docs/runtime/s282/'..n..'.lua')end
 local function load(stage,n)return dofile(d.folder..'/docs/prototypes/'..stage..'/'..n..'.lua')end
 d.Cadence=root('rain_fixed_cadence_v2');d.Pose=root('rain_rigid_pose');d.Input=root('rain_fixed_input')
 d.Packet=load('s239','s239_packet');d.Executor=root('rain_product_executor')
 d.snapshot=root('rain_product_snapshot');d.warmup=load('s273','s273_owner').warmup
 -- Callable CSP cdata is valid; normalize the boundary to an ordinary Lua fn.
 local rawClock=d.clock or os.preciseClock;d.clock=function()return rawClock()end
 if not d.hashText then
  function d.hashText(s)
   local h=d.api.checksumSHA256(s);if #h==32 then return h:gsub('.',function(c)return string.format('%02x',c:byte())end)end;return h:lower()
  end
 end
 if not d.createCapture then
  function d.createCapture()return root('rain_product_capture').new(d,{epoch=d.epoch or 1})end
 end
 assert(d.seed and d.graph and d.backend and d.files and d.fileDescriptors,'owned graph and verified input bundle')
 d.graph=root('rain_product_inventory').wrap(d.graph)
 d.graph=root('rain_product_deposition').wrap(d.graph)
 d.graph=root('rain_product_trace').wrap(d.graph)
 d.graph=root('rain_product_field').wrap(d.graph)
 d.graph=root('rain_product_deposit').wrap(d.graph)
 d.graph=root('rain_product_diagnostics').wrap(d.graph)
 d.graph=root('rain_product_pool').wrap(d.graph)
 d.graph=root('rain_product_trail_export').wrap(d.graph)
 return root('rain_product_runtime').new(d)
end
return M
