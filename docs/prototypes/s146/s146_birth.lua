-- Physical P2 birth trace and retained packets. No live callback/publication.
local S=require('s146_sources');local M={}
function M.recipe(count,gw,gh,sites,w,h,format)
 assert(format=='p2_retained_impact_v1','physical birth format')
 for _,a in ipairs({{count,4096},{gw,4096},{gh,4096},{sites,16384},{w,4096},{h,4096}})do assert(type(a[1])=='number'and a[1]==math.floor(a[1])and a[1]>=1 and a[1]<=a[2],'shape')end
 local r={resources={},passes={},roots={}};local p={passes={}}
 local dims={{count,1},{count,1},{gw,gh},{gw,gh},{gw,gh},{sites,1},{128,2},{32,4},{w,h},{math.ceil(w/16)*math.ceil(h/16),1},{1,18}}
 local names={'txRainState','txRainStateMeta','txRainDu','txRainDv','txRainBoundaryMask','txBirthSites','txBirthDsd','txBirthImpact','txBirthWetHeight','txPoolCandidates','txContext'};local tx={}
 for i,d in ipairs(dims)do assert(d[1]<=16384,'import width');r.resources[i]={width=d[1],height=d[2],format='rgba32f',mips=1,imported=true};tx[names[i]]=i end
 local function add(name,x,y,textures,values)
  local id=#r.resources+1;r.resources[id]={width=x,height=y,format='rgba32f',mips=1};local types={};for k in pairs(values)do types[k]='number'end
  r.passes[#r.passes+1]={kind='shader',target=id,shader=S[name],textures=textures,values=types,cacheKey=146000+S.keys[name]};p.passes[#p.passes+1]=values;return id
 end
 local trace=add('trace',count,8,tx,{gCount=count,gFieldWidth=w,gFieldHeight=h});local packets=add('packets',count,7,{txTrace=trace,txContext=11},{gCount=count,gFieldWidth=w,gFieldHeight=h});local status,n,row=packets,count,6
 repeat local width=math.ceil(n/16);status=add('reduce',width,1,{txInput=status},{gWidth=width,gInputCount=n,gStatusRow=row});n,row=width,0 until n==1
 for kind,name in ipairs({'events','impact','attached','reaction','receipt','sourceHeader'})do local width,height=count,1;if kind==1 then height=5 elseif kind==2 then height=4 elseif kind==5 then width=1 elseif kind==6 then width,height=1,5 end
  r.roots[name]=add('export',width,height,{txTrace=trace,txPackets=packets,txDecision=status,txContext=11},{gCount=count,gKind=kind-1,gFieldWidth=w,gFieldHeight=h})
 end
 r.roots.trace=trace;r.roots.packets=packets;r.roots.decision=status
 r.maxBytes=0;for _,d in ipairs(r.resources)do r.maxBytes=r.maxBytes+d.width*d.height*16 end;assert(r.maxBytes<=256*1024*1024,'byte budget');return r,p
end
return M
