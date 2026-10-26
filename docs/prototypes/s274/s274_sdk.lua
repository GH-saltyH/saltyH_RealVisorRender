-- CSP-documented table reuse: one stable binding schema per shader/cache key.
-- Keep directValuesExchange=false; CSP copies values on each accepted draw.
local M={}
local function keys(t)local k={};for n in pairs(t)do k[#k+1]=n end;table.sort(k);return k end
function M.wrap(backend)
 local out={};for k,v in pairs(backend)do out[k]=v end
 local templates={};local packets=setmetatable({},{__mode='k'})
 out.draw=function(canvas,p)
  local q=packets[p]
  if not q then
   local tx,values=keys(p.textures),keys(p.values);local schema=table.concat(tx,'\n')..'\0'..table.concat(values,'\n')
   local item=templates[p.cacheKey]
   if item then assert(item.body==p.shader and item.schema==schema,'one shader and binding schema per key')
   else
    q={};for k,v in pairs(p)do q[k]=v end;q.textures={};q.values={};q.directValuesExchange=false
    for _,n in ipairs(tx)do q.textures[n]=p.textures[n]end;for _,n in ipairs(values)do q.values[n]=p.values[n]end
    item={body=p.shader,schema=schema,packet=q,tx=tx,values=values};templates[p.cacheKey]=item
   end
   q=item;packets[p]=q
  end
  for _,n in ipairs(q.tx)do q.packet.textures[n]=p.textures[n]end
  for _,n in ipairs(q.values)do q.packet.values[n]=p.values[n]end
  return backend.draw(canvas,q.packet)
 end
 return out
end
return M
