-- Actual-context producer binding. No allocator, public publication or audit fence.
local M={}
local function cp(t)if type(t)~='table'then return t end;local r={};for k,v in pairs(t)do r[k]=cp(v)end;return r end
local function replaceFunction(body,name,replacement)
 local a,b=body:find('bool '..name..'%([^)]*%)%s*{');if not a then return body,false end
 local depth=1;local i=b+1;while depth>0 do local ch=body:sub(i,i);assert(ch~='','balanced function');if ch=='{'then depth=depth+1 elseif ch=='}'then depth=depth-1 end;i=i+1 end
 return body:sub(1,a-1)..replacement..body:sub(i),true
end
function M.new(d,count,w,h,gw,gh,sites)
 assert(w==1024 and h==256 and gw==2048 and gh==512 and sites==8192,'verified current bake shapes')
 local r={resources={},passes={},roots={},imports={},scope='actual_context_physical_producer_v1'}
 local function resource(n,x,y,imported)r.resources[n]={width=x,height=y,format='rgba32f',imported=imported or nil}end
 for n,v in pairs({fileDu={gw,gh},fileDv={gw,gh},fileMask={gw*2,gh*2},fileSites={sites,1},fileDsd={128,2},fileImpact={32,4},oldState={count,1},oldMeta={count,1},oldPose={3,1},oldFilm={w,h},oldMicro={w,h},areas={w,h}})do resource(n,v[1],v[2],true);r.imports[n]=true end
 -- The verified authored boundary is DXT5/BC3, sampled as normalized float4.
 -- Its descriptor must not pretend to be a native RGBA32F allocation.
 r.resources.fileMask.format='bc3_unorm'
 local function add(n,x,y,body,tx,values,key,firstOnly)
  resource(n,x,y);r.passes[#r.passes+1]={kind=n,target=n,shader=body,textures=tx,values=values,cacheKey=key,firstOnly=firstOnly}
 end
 add('frameRows',1,52,d.Cohort.header,{}, {},268001)
 for i,v in ipairs({{'birthContext',0,18},{'siContext',18,10},{'headContext',28,6},{'physics',34,5}})do add(v[1],1,v[3],d.Cohort.slice,{txHeader='frameRows'},{gOffset=v[2],gRows=v[3]},268002)end
 add('currentPose',3,1,d.Cohort.pose,{txHeader='frameRows'},{},268003)
 add('mergeConfig',1,3,d.Cohort.merge,{txHeader='frameRows'},{},268004)
 add('boundary',gw,gh,d.Cohort.boundary,{txDu='fileDu',txMask='fileMask'},{},268005,true)
 add('wetHeight',w,h,d.Cohort.wet,{txFilm='oldFilm',txMicro='oldMicro',txAreas='areas'},{gGrid={w,h}},268006)
 add('emptyCommand',count,1,d.Cohort.zero,{}, {},268007,true)
 add('emptyPools',math.ceil(w/16)*math.ceil(h/16),1,d.Cohort.zero,{}, {},268007,true)
 local br,bp=d.Birth.recipe(count,gw,gh,sites,w,h,'p2_retained_impact_v1')
 local hr,hp=d.Heads.recipe(count,gw,gh,'si_head_producer_v1')
 local function append(prefix,recipe,packet,bindings,keyBase)
  for i,s in ipairs(recipe.resources)do if not s.imported then resource(prefix..i,s.width,s.height)end end
  local function id(i)return bindings[i]or prefix..i end
  for i,p in ipairs(recipe.passes)do local tx={};for n,j in pairs(p.textures)do tx[n]=id(j)end
   r.passes[#r.passes+1]={kind=prefix..i,target=id(p.target),shader=p.shader,textures=tx,values=cp(packet.passes[i]),cacheKey=keyBase+i}
  end
  local roots={};for n,i in pairs(recipe.roots)do roots[n]=id(i)end;return roots
 end
 local birth=append('birth_',br,bp,{'oldState','oldMeta','fileDu','fileDv','boundary','fileSites','fileDsd','fileImpact','wetHeight','emptyPools','birthContext'},268100)
 local bindings={'oldState','oldMeta',birth.events,'fileDu','fileDv','boundary','oldPose','currentPose','headContext','emptyCommand','emptyCommand','mergeConfig','siContext',birth.receipt,birth.sourceHeader}
 -- The global context is immutable and independent of per-slot head work.
 -- Shape checks move to the mandatory typed-lease validator; numerical/header
 -- checks execute once on GPU. No force or per-head admission law is changed.
 local guard=d.HeadSources.motion
 guard=replaceFunction(guard,'dimensions','bool dimensions(Texture2D<float4> t,uint w,uint h){return true;}')
 local a,b=guard:find('float4 main%(PS_IN pin%)%s*{');assert(a,'known motion entry');guard=guard:sub(1,a-1)..'float4 main(PS_IN pin){return float4(headContext()?1:0,0,0,1);}'
 local guardTx={};for n,i in pairs(hr.passes[3].textures)do guardTx[n]=bindings[i]or'head_'..i end
 add('frameGuard',1,1,guard,guardTx,{gCount=count},268299)
 local start=#r.passes+1;local head=append('head_',hr,hp,bindings,268200)
 for i=start,#r.passes do
  local p=r.passes[i];for _,name in ipairs({'context','extraContext','headContext'})do p.shader=replaceFunction(p.shader,name,'bool '..name..'(){return txFrameGuard.Load(int3(0,0,0)).r==1;}')end
  p.textures.txFrameGuard='frameGuard'
 end
 r.roots={events=birth.events,impact=birth.impact,sourceHeader=birth.sourceHeader,birthReceipt=birth.receipt,headReceipt=head.receipt,heads=head.physicalHeads,candidate=head.candidate,state=head.newState,meta=head.finalMeta,pose='currentPose',frameRows='frameRows',headContext='headContext',physics='physics',frameGuard='frameGuard'}
 local api={recipe=r};local specialized=false
 function api:specialize(manifest,hash)
  assert(not specialized,'specialize once')
  for _,p in ipairs(r.passes)do
   local entry=manifest[tostring(p.cacheKey)]
   if entry then
    assert(hash(p.shader)==entry.shaderSha256,'compiled binding witness changed')
    local keep={};for _,n in ipairs(entry.active)do assert(p.textures[n],n);keep[n]=p.textures[n]end
    local declarations={};for n in pairs(p.textures)do if not keep[n]then declarations[#declarations+1]='Texture2D<float4> '..n..';'end end;table.sort(declarations)
    p.shader=table.concat(declarations,'\n')..'\n'..p.shader;p.textures=keep
   end
   local count=0;for _ in pairs(p.textures)do count=count+1 end;assert(count<=16,'CSP texture binding limit')
  end
  specialized=true
 end
 function api:bind(cohort,leases)
  -- Every externally owned image/bank must be checked before using the hoisted
  -- context. A declarative shape without an owner validation is insufficient.
  assert(specialized,'compiled binding witness required')
  assert(type(leases)=='table','typed immutable input leases')
  for n,s in pairs(r.resources)do assert(leases[n]and leases[n]:valid(s),'unverified image/bank/target '..n)end
  local out={};for _,p in ipairs(r.passes)do if not p.firstOnly or cohort.serial==1 then local q=cp(p);if q.kind=='frameRows'then q.values=cp(cohort.values)end;out[#out+1]=q end end
  return{passes=out,resources=r.resources,roots=r.roots,sourceFrame=cohort.engineFrame,serial=cohort.serial,dt=cohort.dt,publicClockAdvanced=false}
 end
 return api
end
return M
