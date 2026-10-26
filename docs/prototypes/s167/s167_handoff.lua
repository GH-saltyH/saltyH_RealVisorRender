-- Conserved source transaction without the7H materialized cell atlas.
local O=require('s144_sources');local S=require('s167_sources');local M={}
function M.recipe(count,w,h,format,support,diagnostic)
 assert(type(count)=='number'and count==math.floor(count)and count>=1 and count<=4096,'head count')
 assert(w==math.floor(w)and h==math.floor(h)and w>=1 and w<=4096 and h>=1 and h<=512,'field bounds')
 assert(format=='retained_impact_packets_v1'and support=='resolved_film_v1','typed physical inputs')
 assert(diagnostic==nil or type(diagnostic)=='boolean','diagnostic roots')
 local r={resources={},passes={},roots={},rootViews={}};local packet={passes={}}
 local names={'txHeads','txHeadReceipt','txHeadHeader','txFilmBirthEvent','txOriginalFilm','txOriginalMicro','txCells','txImpact','txSourceHeader','txPreviousLedger','txPublished','txOriginalHeads'}
 local dims={{count,20},{1,1},{1,6},{count,5},{w,h},{w,h},{w,h},{count,4},{1,5},{1,8},{1,2},{count,1}};local base={}
 for i,n in ipairs(names)do r.resources[i]={width=dims[i][1],height=dims[i][2],format='rgba32f',mips=1,imported=true};base[n]=i end
 local function merge(a,b)local t={};for k,v in pairs(a)do t[k]=v end;for k,v in pairs(b)do t[k]=v end;return t end
 local function add(name,x,y,tx,values,key)
  assert(x<=4096 and y<=4096,'atlas bound');local id=#r.resources+1;r.resources[id]={width=x,height=y,format='rgba32f',mips=1};local types={}
  for k,v in pairs(values)do types[k]=type(v)=='table'and'vec2'or'number'end
  r.passes[#r.passes+1]={kind='shader',target=id,shader=S[name]or O[name],cacheKey=167000+key,textures=tx,values=types};packet.passes[#packet.passes+1]=values;return id
 end
 local v={gCount=count,gGrid={w,h}};local sources=add('sources',count,8,base,v,1)
 local words=math.ceil(count/96);local tile=w<=32 and 4 or 32;if math.ceil(w/tile)*words>4096 then tile=64 end
 local tx,ty=math.ceil(w/tile),math.ceil(h/tile)
 local mask=add('bin',tx*words,ty,{txSources=sources},{gCount=count,gTile={tile,tile},gTilesY=ty,gWords=words,gMaskW=tx*words},2)
 local summary=add('summary',tx,ty,{txMask=mask},{gSummaryW=tx,gTilesY=ty,gSummaryWords=1,gWords=words},3)
 local raster=add('gather',w,h*2,merge(base,{txSources=sources,txMask=mask,txSummary=summary}),merge(v,{gTile=tile,gWords=words}),4)
 local current=merge(base,{txSources=sources,txRaster=raster});local size={w,h+math.ceil(count/w)};local sw,sh=math.ceil(size[1]/16),math.ceil(size[2]/16)
 local status=add('tileStatus',sw,sh,current,merge(v,{gStatusSize=size}),5)
 while sw>1 or sh>1 do local nw,nh=math.ceil(sw/16),math.ceil(sh/16);status=add('reduceStatus',nw,nh,{txStatus=status},{gReduceSize={sw,sh}},6);sw,sh=nw,nh end
 local tiles={math.ceil(size[1]/16),math.ceil(size[2]/16)}
 local totals=add('totals',tiles[1],tiles[2]*11,current,merge(v,{gStatusSize=size,gTotalTiles=tiles}),7)
 while tiles[1]>1 or tiles[2]>1 do local nextTiles={math.ceil(tiles[1]/16),math.ceil(tiles[2]/16)};totals=add('reduceTotals',nextTiles[1],nextTiles[2]*11,{txTotals=totals},{gTotalTiles=tiles},8);tiles=nextTiles end
 local decision=add('decision',1,1,merge(base,{txStatus=status,txTotals=totals}),v,9);r.roots.decision=decision
 local bound=merge(current,{txTotals=totals,txDecision=decision,txStatus=status})
 for k,n in ipairs({'film','micro','heads','stepLedger','cumulativeLedger','sourceCheckpoint'})do
  local x,y=w,h;if k==3 then x,y=count,1 elseif k==4 or k==5 then x,y=1,8 elseif k==6 then x,y=1,2 end
  r.roots[n]=add('commit',x,y,bound,merge(v,{gKind=k-1}),10)
 end
 if diagnostic then r.roots.raster=raster;r.roots.sources=sources;r.roots.status=status;r.roots.totals=totals end
 r.maxBytes=0;for _,d in ipairs(r.resources)do r.maxBytes=r.maxBytes+d.width*d.height*16 end;assert(r.maxBytes<=256*1024*1024,'byte budget')
 return r,packet
end
return M
