-- Real SI force/advance/meta/P3 transfer producer; no engine callback.
local S=require('s148_sources');local M={}
function M.recipe(count,gw,gh,format)
 assert(format=='si_head_producer_v1','physical SI head format')
 for _,x in ipairs({count,gw,gh})do assert(type(x)=='number'and x==math.floor(x)and x>=1 and x<=4096,'shape')end
 local r={resources={},passes={},roots={}};local p={passes={}}
 local names={'txOldState','txOldMeta','txEvents','txDu','txDv','txBoundary','txOldTransform','txNewTransform','txHeader','txMergeCommand','txMergeGeneration','txMergeConfig','txSI','txBirthReceipt','txBirthHeader'}
 local dims={{count,1},{count,1},{count,5},{gw,gh},{gw,gh},{gw,gh},{3,1},{3,1},{1,6},{count,1},{count,1},{1,3},{1,10},{1,1},{1,5}};local base={}
 for i,d in ipairs(dims)do r.resources[i]={width=d[1],height=d[2],format='rgba32f',mips=1,imported=true};base[names[i]]=i end
 local function merge(a,b)local t={};for k,v in pairs(a)do t[k]=v end;for k,v in pairs(b)do t[k]=v end;return t end
 local function add(name,w,h,tx,values)
  local id=#r.resources+1;r.resources[id]={width=w,height=h,format='rgba32f',mips=1};local types={};for k in pairs(values)do types[k]='number'end
  r.passes[#r.passes+1]={kind='shader',target=id,shader=S[name],textures=merge(tx,{}),values=types,cacheKey=148000+S.keys[name]};p.passes[#p.passes+1]=values;return id
 end
 local v={gCount=count};local root=r.roots
 local zero=add('zero',count,5,{},v)
 local b=merge(base,{txNewState=1,txPreMeta=2,txFinalMeta=2,txDescriptors=zero,txPostForce=1})
 root.ownership=add('merge',count,6,b,v);b.txOwnership=root.ownership
 root.postForce=add('motion',count,1,b,v);b.txPostForce=root.postForce
 root.trace=add('trace',count,4,b,v);b.txTrace=root.trace
 root.newState=add('state',count,1,{txTrace=root.trace},v);b.txNewState=root.newState
 root.preMeta=add('meta',count,1,b,v);b.txPreMeta=root.preMeta
 root.descriptors=add('descriptor',count,5,merge(b,{txFilmNewState=root.newState,txFilmNewMeta=root.preMeta,txFilmOldState=1,txFilmOldMeta=2,txFilmBirthEvent=3}),v);b.txDescriptors=root.descriptors
 root.finalMeta=add('filmMeta',count,1,merge(b,{txFilmNewMeta=root.preMeta,txFilmDescriptors=root.descriptors}),v);b.txFinalMeta=root.finalMeta
 root.decoded=add('decode',count,20,b,v)
 local prev,n,row=root.decoded,count,13
 repeat local width=math.ceil(n/16);prev=add('reduce',width,1,{txInput=prev},{gWidth=width,gInputCount=n,gStatusRow=row});n,row=width,0 until n==1
 root.decision=prev
 for k,name in ipairs({'candidate','receipt','physicalHeads'})do local w,h=count,20;if k==2 then w,h=1,1 elseif k==3 then h=1 end;root[name]=add('export',w,h,{txDecoded=root.decoded,txDecision=prev,txHeader=9},{gCount=count,gReceipt=k-1})end
 r.maxBytes=0;for _,d in ipairs(r.resources)do r.maxBytes=r.maxBytes+d.width*d.height*16 end;assert(r.maxBytes<=256*1024*1024 and #r.resources<=96,'head budget');return r,p
end
return M
