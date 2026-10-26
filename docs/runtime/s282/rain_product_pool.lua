-- Regional reconstitution, not water removal. An immutable debit plan feeds
-- both birth and source accounting; busy slots leave every source cell intact.
local M={}
M.defaults={bareResidualUM=10,coatResidualUM=2,relaxSeconds=.25,minEquivalentMM=1,maxEquivalentMM=3}
M.excess=[[
float rvPoolExcess(int2 p){
 float4 c=txPoolCells.Load(int3(p,0));float area=txPoolAreas.Load(int3(p,0)).r;
 float water=txPoolFilm.Load(int3(p,0)).r;
 if(c.a!=1||c.g<=0||area<=0||!isfinite(water)||water<=0)return 0;
 float keep=area*lerp(gBareResidualUM,gCoatResidualUM,saturate(c.b))*.001;
 return max(water-keep,0);
}
]]
M.proposal=M.excess..[[
float4 main(PS_IN pin){
 uint tile=min((uint)(pin.Tex.x*gTiles),(uint)gTiles-1u);int2 origin=int2(tile%(uint)gTilesX,tile/(uint)gTilesX)*16;
 precise float total=0,error=0;float peak=0;int2 centre=origin;
 [loop]for(int y=0;y<16;y++)[loop]for(int x=0;x<16;x++){
  int2 p=origin+int2(x,y);float e=rvPoolExcess(p);
  precise float v=e-error,t=total+v;error=(t-total)-v;total=t;
  // Partial edge cells can own water while their centre is outside the mesh.
  // Use exactly the producer boundary at the candidate centre for head birth.
  if(e>peak&&txPoolBoundary.Load(int3(p*2+1,0)).a>=.5){peak=e;centre=p;}
 }
 // Coalescence is an event: once enough water exists for a resolved head,
 // do not require minVolume/fraction and leave a thick threshold reservoir.
 float requested=min(total,min(max(total*gFraction,gMinVolume),gMaxVolume));
 return total>=gMinVolume&&peak>0?float4(centre,total,requested/total):0;
}
]]
M.debit=M.excess..[[
float4 main(PS_IN pin){
 int2 p=min((int2)(pin.Tex*gGrid),(int2)gGrid-1);
 uint tile=((uint)p.y>>4)*(uint)gTilesX+((uint)p.x>>4);
 float4 proposal=txPoolProposal.Load(int3(tile,0,0));
 if(proposal.z<=0)return 0;
 float old=txPoolFilm.Load(int3(p,0)).r;
 precise float remain=old-min(rvPoolExcess(p)*proposal.w,old);
 precise float removed=old-remain;
 return float4(removed,0,0,0);
}
]]
M.candidate=[[
float4 main(PS_IN pin){
 uint tile=min((uint)(pin.Tex.x*gTiles),(uint)gTiles-1u);int2 origin=int2(tile%(uint)gTilesX,tile/(uint)gTilesX)*16;
 precise float total=0,error=0;
 [loop]for(int y=0;y<16;y++)[loop]for(int x=0;x<16;x++){
  precise float v=txPoolDebit.Load(int3(origin+int2(x,y),0)).r-error,t=total+v;error=(t-total)-v;total=t;
 }
 float4 proposal=txPoolProposal.Load(int3(tile,0,0));
 return total>=gMinVolume?float4(proposal.xy,total,1):0;
}
]]
M.transfer=[[
float poolTransfer(int2 padded){
 int2 p=padded-(int)gFilmPad;
 if(any(p<0)||any(p>=(int2)gFilmGrid))return 0;
 uint tile=(uint)p.y/16u*poolTilesX()+(uint)p.x/16u,owner=poolOwner(tile);
 if(owner>=(uint)gPoolCount)return 0;
 // Only an actually accepted birth authorizes the precomputed cell debit.
 float transferred=txFilmBirthEvent.Load(int3(owner,4,0)).z;
 if(transferred<=0)return 0;
 float2 born=txFilmBirthEvent.Load(int3(owner,0,0)).xy;
 int2 source=(int2)floor(float2(born.x,born.y+1)*gFilmGrid);
 if(any((source>>4)!=(p>>4)))return 0;
 return txPoolDebit.Load(int3(p,0)).r;
}
]]
local function replaceFunction(s,name,body)
 local a,b=s:find('float '..name..'%([^)]*%)%s*{');if not a then return s,false end
 local depth,i=1,b+1;while depth>0 do local c=s:sub(i,i);assert(c~='','balanced function');if c=='{'then depth=depth+1 elseif c=='}'then depth=depth-1 end;i=i+1 end
 return s:sub(1,a-1)..body..s:sub(i),true
end
function M.shader(s)
 if not s:find('void sourceCell(',1,true)then return s,false end
 return replaceFunction(s,'poolTransfer',M.transfer)
end
-- Commit modes are fixed recipe topology, not runtime-varying branches.
-- Specialize and bind only the inputs the selected entry can consume. Unused
-- declarations keep dead helper functions parseable and are removed by FXC.
M.commitInputs={
 [0]={'txDecision','txOriginalFilm','txOriginalMicro','txCells','txRaster','txFilmBirthEvent','txSourceHeader','txSourceGuard','txPoolDebit'},
 [1]={'txDecision','txOriginalFilm','txOriginalMicro','txCells','txRaster','txFilmBirthEvent','txSourceHeader','txSourceGuard','txPoolDebit'},
 [2]={'txDecision','txOriginalHeads','txHeads'},
 [3]={'txDecision','txTotals'},
 [4]={'txDecision','txPreviousLedger','txTotals'},
 [5]={'txDecision','txPublished','txSourceHeader','txHeadHeader'}}
function M.specializeCommit(p)
 local kind=p.values.gKind;local names=M.commitInputs[kind];assert(names,'fixed source commit mode')
 local tx,decl={},{};for _,n in ipairs(names)do tx[n]=assert(p.textures[n],n)end
 for n in pairs(p.textures)do if not tx[n]then decl[#decl+1]='Texture2D<float4> '..n..';'end end;table.sort(decl)
 local body=p.shader:gsub('%f[%w_]gKind%f[^%w_]','('..kind..')')
 p.shader=table.concat(decl,'\n')..'\n'..body;p.textures=tx;p.values.gKind=nil;p.cacheKey=288100+kind
end
function M.wrap(graph,options)
 if graph.productRegionalPool then return graph end
 local cfg={};for k,v in pairs(M.defaults)do cfg[k]=options and options[k]or v end
 assert(cfg.bareResidualUM>=0 and cfg.coatResidualUM>=0 and cfg.relaxSeconds>0)
 assert(cfg.minEquivalentMM>0 and cfg.maxEquivalentMM>=cfg.minEquivalentMM)
 local minV=math.pi/6*cfg.minEquivalentMM^3;local maxV=math.pi/6*cfg.maxEquivalentMM^3
 graph.resources.rv_poolProposal={width=1024,height=1,format='rgba32f'}
 graph.resources.rv_poolDebit={width=1024,height=256,format='r32f'}
 graph.descriptorBytes=graph.descriptorBytes+1024*16+1024*256*4
 local bind=graph.bind;local cache=setmetatable({},{__mode='k'});local bodies={};local stats
 function graph:bind(dt,serial,c,...)
  local r=bind(self,dt,serial,c,...);local entry=cache[r]
  if not entry then
   local wet,pool
   for _,p in ipairs(r.passes)do
    if p.target=='p_wetHeight'then wet=p end
    if p.target=='p_emptyPools'then pool=p end
   end
   -- Recurring recipes omit the former first-only zero candidate write.
   assert(wet,'leased old film and physical areas')
   local tx={txPoolFilm=wet.textures.txFilm,txPoolAreas=wet.textures.txAreas,txPoolCells='fileCells'}
   local base={gGrid={1024,256},gTiles=1024,gTilesX=64,gBareResidualUM=cfg.bareResidualUM,gCoatResidualUM=cfg.coatResidualUM,gMinVolume=minV,gMaxVolume=maxV}
   local function values()local q={};for k,v in pairs(base)do q[k]=v end;return q end
   local proposalTx={};for k,v in pairs(tx)do proposalTx[k]=v end;proposalTx.txPoolBoundary='p_boundary'
   local proposal={kind='poolProposal',target='rv_poolProposal',shader=M.proposal,cacheKey=287001,textures=proposalTx,values=values()}
   local debitTx={};for k,v in pairs(tx)do debitTx[k]=v end;debitTx.txPoolProposal='rv_poolProposal'
   local debit={kind='poolDebit',target='rv_poolDebit',shader=M.debit,cacheKey=287002,textures=debitTx,values=values()}
   local candidate={kind='poolCandidate',target='p_emptyPools',shader=M.candidate,cacheKey=287003,textures={txPoolProposal='rv_poolProposal',txPoolDebit='rv_poolDebit'},values=values()}
   local out={};local changed=0
   for _,p in ipairs(r.passes)do
    if p~=pool then out[#out+1]=p end
    if p==wet then out[#out+1]=proposal;out[#out+1]=debit;out[#out+1]=candidate end
    if p.shader:find('void sourceCell(',1,true)then
     local body=bodies[p.shader];if not body then local ok;body,ok=M.shader(p.shader);assert(ok);bodies[p.shader]=body end
     p.shader=body;p.cacheKey=p.cacheKey+33000000;p.textures.txPoolDebit='rv_poolDebit';changed=changed+1
     if p.values.gKind~=nil then M.specializeCommit(p)end
     local n=0;for _ in pairs(p.textures)do n=n+1 end;assert(n<=15,'regional source fits CSP texture limit')
    end
   end
   assert(changed==8,'one debit law for status/totals/six commits')
   entry={original=out,proposal=proposal};cache[r]=entry
  end
  entry.proposal.values.gFraction=1-math.exp(-dt/cfg.relaxSeconds)
  -- Change only the producer-owned pool-enable row, never captured engine data.
  for _,p in ipairs(entry.original)do if p.kind=='frameRows'then local row=p.values.gRow10;assert(row and row[2]==graph.headCount);p.values.gRow10={1,row[2],row[3],row[4]}end end
  r.passes=entry.original;stats={extraRecurringDraws=3,extraBytes=1064960,regionCells=16,minimumEquivalentMM=cfg.minEquivalentMM,maximumEquivalentMM=cfg.maxEquivalentMM,
   residualBareUM=cfg.bareResidualUM,residualCoatUM=cfg.coatResidualUM,relaxSeconds=cfg.relaxSeconds,calibration='unmeasured_material_hypothesis',waterDeleted=false}
  return r
 end
 function graph:poolStatus()return stats end
 graph.productRegionalPool=true;return graph
end
return M
