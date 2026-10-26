-- Bounded DISPLAY history. No solver stock, time queue, GPU reads or resources.
-- Caller supplies accepted immutable cohort handles; this is not a GPU fence.
-- Not yet called by rain_product_visual: source separation must be connected.
local M={}
local function finite(x)return type(x)=='number'and x==x and math.abs(x)<math.huge end
function M.new(o)
 o=o or{};local capacity=o.capacity or 16;local lifetime=o.lifetime or .5;local fade=o.fade or .15
 assert(capacity>=1 and capacity<=32 and capacity==math.floor(capacity),'bounded cohort count')
 assert(finite(lifetime)and lifetime>0 and lifetime<=2 and finite(fade)and fade>0 and fade<=lifetime,'display lifetime')
 local ring={};local first,count=1,0;local now,last,epoch,geometry;local evicted,expired,resets,duplicates=0,0,0,0
 local function clear()ring={};first=1;count=0 end
 local function pop()ring[first]=nil;first=first%capacity+1;count=count-1 end
 local function expire()
  while count>0 and now-ring[first].endSeconds>=lifetime do pop();expired=expired+1 end
 end
 local api={}
 function api:accept(c)
  -- Malformed/declined display input does not invalidate physical simulation.
  if type(c)~='table'or c.accepted~=true then return false,'unaccepted'end
  if not finite(c.serial)or c.serial<1 or c.serial%1~=0 or not finite(c.endSeconds)or c.endSeconds<0
   or not finite(c.count)or c.count<0 or c.count>4096 or c.count%1~=0
   or type(c.epoch)~='string'or type(c.geometry)~='string'or c.payload==nil then return false,'invalid cohort'end
  local changed=epoch~=nil and(epoch~=c.epoch or geometry~=c.geometry)
  if not changed and last and c.serial<=last then duplicates=duplicates+1;return false,'duplicate or stale'end
  if not changed and now and c.endSeconds<now then return false,'backward display time'end
  if changed or(last and c.serial~=last+1)then clear();resets=resets+1 end
  epoch=c.epoch;geometry=c.geometry;last=c.serial;now=c.endSeconds;expire()
  if c.count>0 then
   if count==capacity then pop();evicted=evicted+1 end
   local at=(first+count-1)%capacity+1
   ring[at]={serial=c.serial,endSeconds=c.endSeconds,count=c.count,payload=c.payload};count=count+1
  end
  return true
 end
 function api:plan()
  local result={};for n=0,count-1 do
   local c=ring[(first+n-1)%capacity+1];local age=math.max(now-c.endSeconds,0)
   local t=math.max(0,math.min(1,(age-(lifetime-fade))/fade));local w=1-t*t*(3-2*t)
   if w>0 then result[#result+1]={serial=c.serial,weight=w,payload=c.payload,count=c.count}end
  end;return result
 end
 function api:status()return{cohorts=count,capacity=capacity,maxEvents=capacity*4096,seconds=now,
  evicted=evicted,expired=expired,resets=resets,duplicates=duplicates,readonly=true,
  fallback='coarse film keeps all water; only display claim expires',resources=0,readbacks=0}end
 return api
end
return M
