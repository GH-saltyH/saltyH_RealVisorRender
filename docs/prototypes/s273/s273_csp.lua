-- SDK adapter for private session-retained canvases and a 16-float status copy.
-- The callback covers this private graph only; never a renderer/global fence.
local M={}
function M.new(d)
 local retained,descs={},{};local disposed=setmetatable({},{__mode='k'})
 local stats={created=0,readbacks=0,cpuDisposed=0,duplicateCPUObjects=0}
 local backend={scope='private_ordered_status_v1',opaque=d.opaque}
 function backend.create(s,slot,rid)
  local c=assert(d.createCanvas(s),'ExtraCanvas allocation');retained[#retained+1]=c
  local size=c:size();assert(size.x==s.width and size.y==s.height and c:mips()==1,'whole private canvas shape')
  c:setName('RealVisor preview private '..slot..'/'..rid);descs[c]=s;stats.created=stats.created+1;return c
 end
 function backend.make(kind,v)
  if kind=='number'or kind=='boolean'then return v end
  return assert(d[kind],kind)(unpack(v))
 end
 function backend.draw(c,p)assert(descs[c],'foreign private target');return c:updateWithShader(p)end
 function backend.readStatus(c,callback)
  local s=assert(descs[c],'foreign status target');assert(s.width==160 and s.height==1 and s.format=='r32f','private status descriptor')
  stats.readbacks=stats.readbacks+1
  c:accessData(function(err,data)
   if data and disposed[data]then stats.duplicateCPUObjects=stats.duplicateCPUObjects+1;callback('duplicate CPU object');return end
   if data then disposed[data]=true end
   local words;local ok,why=pcall(function()
    assert(not err and data,tostring(err or'missing CPU data'));local size=data:size();assert(size.x==160 and size.y==1,'private status readback shape')
    words={};for x=0,159 do words[#words+1]=data:floatValue(x,0)end
   end)
   if data then
    local freed,e=pcall(function()data:dispose()end);if freed then stats.cpuDisposed=stats.cpuDisposed+1 else ok=false;why=e end
   end
   if ok then callback(nil,words)else callback(tostring(why),nil)end
  end)
 end
 function backend.status()return{created=stats.created,readbacks=stats.readbacks,cpuDisposed=stats.cpuDisposed,duplicateCPUObjects=stats.duplicateCPUObjects,retained=#retained,disposedGPU=0,generalGPUFence=false}end
 return backend
end
return M
