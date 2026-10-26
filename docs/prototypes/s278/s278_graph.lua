-- Reuse fixed recipes; retained physical inventory is the momentum authority.
local M={}
local function once(s,a,b)local i,j=s:find(a,1,true);assert(i,'owned merge packet expression');return s:sub(1,i-1)..b..s:sub(j+1)end
function M.ownership(s)
 s=once(s,'original=packet(m.g,v);','original=retained;')
 s=once(s,'bool valid=all(isfinite(s))&&metaValid(m);',
  'float4 retained=txPhysicalOld.Load(int3(i,0,0));bool valid=all(isfinite(s))&&metaValid(m)&&all(isfinite(retained))&&retained.r==m.g&&retained.r>=0&&(retained.r>0||all(retained.yzw==0));')
 return s
end
function M.new(d,seed,options)
 local g=d.RetentionGraph.new(d,seed,options);local reference=g.bind;local mapper=d.Cohort.new(d.Packet,seed)
 local templates={};local hits,builds=0,0;local shader
 local files={fileDu={2048,512,'rgba32f'},fileDv={2048,512,'rgba32f'},fileMask={4096,1024,'bc3_unorm'},fileCells={1024,256,'rgba32f'},fileSites={8192,1,'rgba32f'},fileDsd={128,2,'rgba32f'},fileImpact={32,4,'rgba32f'}}
 local function build(self,dt,serial,c,certify)
  local r=reference(self,dt,serial,c,certify);local changed=0
  for _,p in ipairs(r.passes)do if p.cacheKey==268202 then
   assert(p.textures.txMergeCommand=='p_emptyCommand','canonical handoff currently requires disabled merge');shader=shader or M.ownership(p.shader);p.shader=shader;p.cacheKey=278202;p.textures.txPhysicalOld=r.audit.textures.txSourceOriginal;changed=changed+1
   local n=0;for _ in pairs(p.textures)do n=n+1 end;assert(n<=14,'canonical ownership binding margin')
  end end
  assert(changed==1,'single canonical old-inventory producer');return r
 end
 function g:bind(dt,serial,c,certify)
  if options and options.disableRecipeCache then return build(self,dt,serial,c,certify)end
  local n=dt<=1/60 and 4 or dt<=1/30 and 8 or 16;local key=n..':'..(serial==1 and 'first'or tostring(serial%2))
  local r=templates[key]
  if not r then r=build(self,dt,serial,c,certify);templates[key]=r;builds=builds+1;assert(builds<=9,'bounded fixed recipe variants');return r end
  -- Same mandatory input and allocation contract as the full producer binder.
  assert(type(certify)=='function','lease certifier');for name,s in pairs(self.resources)do assert(certify(name,s),'private lease '..name)end
  for name,s in pairs(files)do assert(certify(name,{width=s[1],height=s[2],format=s[3]}),'file lease '..name)end
  local cohort=mapper:bind(c);assert(cohort.serial==serial and cohort.dt==dt,'admitted input order')
  for _,p in ipairs(r.passes)do
   local v=p.values
   if p.kind=='frameRows'then p.values=cohort.values
   else
    if v.gSerial then v.gSerial=serial end
    if v.gDt then v.gDt=(p.kind=='force'or p.kind=='flux')and dt/n or dt end
    if v.gToken then v.gToken={264,1,serial,1}end
    if v.gPrevious then v.gPrevious={264,1,serial-1,1}end
   end
  end
  r.serial=serial;hits=hits+1;return r
 end
 function g:cacheStatus()return{hits=hits,builds=builds}end
 return g
end
return M
