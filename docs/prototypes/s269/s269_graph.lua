-- One private producer/source/transport prefix and eight jointly selected stocks.
local M={}
local function cp(t)if type(t)~='table'then return t end;local r={};for k,v in pairs(t)do r[k]=cp(v)end;return r end
M.copy='float4 main(PS_IN pin){return txInput.Load(int3((int2)(pin.Tex*gSize),0));}'
M.initial=[[
float4 main(PS_IN pin){uint row=min((uint)(pin.Tex.y*8),7u);float4 result=0;
 if(gKind==1)result=float4(txAreas.Load(int3((int2)(pin.Tex*gGrid),0)).r*gHeightMM,0,0,0);
 else if(gKind==2&&(row==0u||row==1u))result=float4(gInitialWater,0,0,0);
 else if(gKind==3){uint r=min((uint)(pin.Tex.y*2),1u);result=r==0u?float4(234,1,0,1):float4(2,0,0,1);}
 return result;}
]]
function M.new(d,seed,options)
 local n,w,h=seed.rows[2][4],seed.rows[12][1],seed.rows[12][2];assert(w==1024 and h==256,'actual film bake')
 local initUM=options and options.fixtureInitialFilmUM or 0;assert(initUM==0 or(options.fixtureScope=='native_only'and initUM==20),'dry runtime startup; declared native fixture only')
 local producer=d.Producer.new(d,n,w,h,2048,512,8192);producer:specialize(d.Bindings,d.hashText)
 local mapper=d.Cohort.new(d.Packet,seed)
 local contract={rawDomain='field_local_area_coverage_coating_v1',areaDomain='physical_cell_area_mm2_v1',rawFormat='rgba32f',areaFormat='r32f'}
 for _,k in ipairs({'contextKey','areaContextKey','geometryKey','rawGeometryKey','areaGeometryKey','poseKey','areaPoseKey','rawResourceKey','areaResourceKey'})do contract[k]=seed.geometryKey end
 local sr,sp=d.Cells.source(n,w,h,contract,false);local joint=d.Joint.compile(d.Core,sr,sp,w,h,n)
 local bindingBuild=options and options.buildBindingsScope=='offline_compiler';assert(bindingBuild or d.SourceBindings,'qualified source binding manifest')
 local sourceOverrides={};local sourceGuard;local bindingPasses={}
 for _,p in ipairs(joint:bind(.01,1).passes)do if p.kind=='source'then
  local k=#sourceOverrides+1;local q=cp(p);q.cacheKey=2691000+k
  if not sourceGuard and q.shader:find('bool context%(')then
   local body=d.BindingUtil.replace(q.shader,'dimensions','bool dimensions(Texture2D<float4> t,uint w,uint h){return true;}')
   local a=assert(body:find('float4 main%(PS_IN pin%)'),'source entry');body=body:sub(1,a-1)..'float4 main(PS_IN pin){return float4(context()?1:0,0,0,1);}'
   sourceGuard={kind='sourceGuard',target='sourceGuard',shader=body,textures=cp(q.textures),values=cp(q.values),cacheKey=2691999};bindingPasses[#bindingPasses+1]=cp(sourceGuard)
  end
  local body,replaced=d.BindingUtil.replace(q.shader,'context','bool context(){return txSourceGuard.Load(int3(0,0,0)).r==1;}');q.shader=body
  if replaced then q.textures.txSourceGuard='sourceGuard'end
  bindingPasses[#bindingPasses+1]=cp(q);sourceOverrides[k]=q
 end end
 assert(sourceGuard,'source global validation');if not bindingBuild then
  sourceGuard=d.BindingUtil.apply(sourceGuard,d.SourceBindings,d.hashText)
  for i,p in ipairs(sourceOverrides)do sourceOverrides[i]=d.BindingUtil.apply(p,d.SourceBindings,d.hashText)end
 end
 local resources={};local pr=producer.recipe
 for name,s in pairs(pr.resources)do if not s.imported then resources['p_'..name]=cp(s)end end
 local cache={metric={w,h*3},areas={w,h},scalarAreas={w,h},runs={w,h},leaves={256,128}}
 for name,size in pairs(cache)do resources[name]={width=size[1],height=size[2],format=name=='scalarAreas'and'r32f'or'rgba32f'}end
 local bankShapes={film={w,h},micro={w,h},heads={n,1},state={n,1},meta={n,1},ledger={1,8},checkpoint={1,2},pose={3,1},receipt={4,1}}
 for _,bank in ipairs({'A','B'})do for name,size in pairs(bankShapes)do resources[bank..'_'..name]={width=size[1],height=size[2],format='rgba32f'}end end
 for name,s in pairs(joint.resources)do if not s.imported and not name:find('^committed_')then resources['j_'..name]=cp(s)end end
 resources.j_sourceGuard={width=1,height=1,format='rgba32f'}
 local bytes=0;for _,s in pairs(resources)do bytes=bytes+s.width*s.height*(s.format=='r32f'and 4 or 16)end
 local readonlyBytes=40*1048576+8192*16+128*2*16+32*4*16
 assert(bytes+2048<=192*1048576 and bytes+2048+readonlyBytes<=256*1048576,'complete private descriptor bounds')
 local api={resources=resources,descriptorBytes=bytes,readonlyFileBytes=readonlyBytes,headCount=n,receiptNamespace=267,bindingPasses=bindingPasses,offlineBindingBuild=bindingBuild}
 local function bankName(bank,name)return bank..'_'..name end
 function api:bind(dt,serial,c,certify)
  assert(type(certify)=='function','actual private/image lease certifier')
  assert(certify('fileCells',{width=w,height=h,format='rgba32f'}),'verified raw cells lease')
  for name,s in pairs(resources)do assert(certify(name,s),'verified private allocation '..name)end
  local cohort=mapper:bind(c);assert(cohort.serial==serial and cohort.dt==dt,'admitted input order')
  local old=serial%2==1 and'B'or'A';local new=serial%2==1 and'A'or'B'
  local pmap={areas='areas',oldState=bankName(old,'state'),oldMeta=bankName(old,'meta'),oldPose=bankName(old,'pose'),oldFilm=bankName(old,'film'),oldMicro=bankName(old,'micro')}
  for name in pairs(pr.resources)do pmap[name]=pmap[name]or(pr.resources[name].imported and name or'p_'..name)end
  local leases={};for name,s in pairs(pr.resources)do local role=pmap[name];leases[name]={valid=function(_,expected)return expected.width==s.width and expected.height==s.height and expected.format==s.format and certify(role,expected)end}end
  local pp=producer:bind(cohort,leases);local passes={}
  local function append(p,map)
   local q={kind=p.kind,target=map(p.target),shader=p.shader,cacheKey=p.cacheKey,textures={},values=cp(p.values)}
   for name,role in pairs(p.textures)do q.textures[name]=map(role)end;passes[#passes+1]=q
  end
  local function add(kind,target,shader,tx,v,key)passes[#passes+1]={kind=kind,target=target,shader=shader,textures=tx,values=v,cacheKey=key}end
  for _,p in ipairs(pp.passes)do
   append(p,function(role)return assert(pmap[role],role)end)
   if p.kind=='frameRows'then
    add('metric','metric',d.Cache.metric,{txHeader='p_frameRows',txDu='fileDu',txDv='fileDv',txCells='fileCells'},{gGrid={w,h}},269001)
    add('areas','areas',d.Cache.areas,{txHeader='p_frameRows',txDu='fileDu',txCells='fileCells'},{gGrid={w,h}},269002)
    add('scalarAreas','scalarAreas',M.copy,{txInput='areas'},{gSize={w,h}},269003)
    if serial==1 then
     add('leaves','leaves',d.Cache.leaves,{txCells='fileCells'},{gGrid={w,h},gLeafSize={256,128}},269004)
     add('runs','runs',d.Cache.runs,{txCells='fileCells',txLeaves='leaves'},{gGrid={w,h},gLeafSize={256,128}},269005)
     for name,size in pairs(bankShapes)do
      if name=='pose'then add('initialPose','B_pose',d.Cohort.pose,{txHeader='p_frameRows'},{},269006)
      else local kind=name=='film'and 1 or name=='ledger'and 2 or name=='checkpoint'and 3 or 0
       add('initialize','B_'..name,M.initial,{txAreas='areas'},{gKind=kind,gGrid={w,h},gHeightMM=initUM*.001,gInitialWater=seed.unitRows[1][4]*1e6*initUM*.001},269007)
      end
     end
    end
   end
  end
  local jp=joint:bind(dt,serial);local proot=pp.roots
  local jm={source1=pmap[proot.candidate],source2=pmap[proot.headReceipt],source3='p_headContext',source4=pmap[proot.events],source5=bankName(old,'film'),source6=bankName(old,'micro'),source8=pmap[proot.impact],source9=pmap[proot.sourceHeader],source10=bankName(old,'ledger'),source11=bankName(old,'checkpoint'),source12=bankName(old,'heads'),source13='fileCells',source14='scalarAreas',source15='p_frameRows',source16='p_frameRows',metric='metric',areas='areas',runs='runs',physics='p_physics',priorReceipt=bankName(old,'receipt'),oldState=bankName(old,'state'),oldMeta=bankName(old,'meta'),newState=pmap[proot.state],newMeta=pmap[proot.meta]}
  for name in pairs(jp.resources)do if not jm[name]then local root=name:match('^committed_(.+)$');jm[name]=root and bankName(new,root)or'j_'..name end end
  jm.sourceGuard='j_sourceGuard';local sourceIndex=0;local guardAdded=false
  for _,p in ipairs(jp.passes)do
   if p.kind=='source'then
    sourceIndex=sourceIndex+1
    if not guardAdded and p.shader:find('bool context%(')then append(sourceGuard,function(role)return assert(jm[role],role)end);guardAdded=true end
    local fixed=sourceOverrides[sourceIndex];p.shader=fixed.shader;p.textures=cp(fixed.textures);p.cacheKey=fixed.cacheKey
   end
   append(p,function(role)return assert(jm[role],role)end)
  end
  add('commitPose',bankName(new,'pose'),d.Joint.select,{txReceipt='j_jointReceipt',txCandidate='p_currentPose',txOld=bankName(old,'pose')},{gSize={3,1},gSerial=serial},269008)
  -- Store even a refused receipt, so an already submitted suffix cannot restart.
  add('receiptCopy',bankName(new,'receipt'),M.copy,{txInput='j_jointReceipt'},{gSize={4,1}},269009)
  for _,p in ipairs(passes)do local count=0;for _,role in pairs(p.textures)do assert(role~=p.target,'no SRV/RTV alias');count=count+1 end;assert(bindingBuild or count<=16,'complete CSP binding limit '..p.kind..':'..count)end
  return{passes=passes,receipt=bankName(new,'receipt'),serial=serial,finalBank=new,scope='private_joint_source_transport_v1'}
 end
 function api:validate(...)return d.Joint.validate(...)end
 return api
end
return M
