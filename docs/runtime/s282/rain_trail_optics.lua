-- Fine display reconstruction from accepted GPU cohorts. No CPU readback or SI
-- stock update. Same selection texture as head/coarse snapshots fixes the phase.
local M={}
M.grid=[[
#ifndef RV_TRAIL_GRID
#define RV_TRAIL_GRID float2(1024,256)
#endif
#define RV_TRAIL_FINE_GRID (RV_TRAIL_GRID*4)
]]
M.weight=[[
float trailWeight(float4 marker,float4 selected){
 if(selected.z!=1||marker.w!=1||marker.x<1||marker.x>selected.y||!all(isfinite(marker)))return 0;
 float age=selected.w-marker.y;if(age<-.00001||age>=gLife)return 0;
 float t=saturate((max(age,0)-(gLife-gFade))/gFade);return 1-t*t*(3-2*t);
}
]]
function M.claimShader()
 local s={M.grid,M.weight,[[float4 main(PS_IN pin){
 int2 p=min((int2)(pin.Tex*RV_TRAIL_GRID),(int2)RV_TRAIL_GRID-1);
 float4 selected=txSelection.Load(int3(0,0,0));
 float value=gFirst>.5?0:txPrevious.Load(int3(p,0)).r;
 ]]}
 for i=0,3 do s[#s+1]=string.format('if(gActive>%d)value+=trailWeight(txMarker%d.Load(int3(0,0,0)),selected)*max(txClaim%d.Load(int3(p,0)).r,0);',i,i,i)end
 s[#s+1]='return float4(value,0,0,0);}';return table.concat(s,'\n')
end
M.sparse=[[
float trailDensity(Texture2D<float4> geometry,Texture2D<float4> mask,
 Texture2D<float4> summary,Texture2D<float4> marker,float2 p,float4 selected){
 float fade=trailWeight(marker.Load(int3(0,0,0)),selected);if(fade<=0)return 0;
 uint2 tile=(uint2)floor((p+.5)/gTile);float4 sum=summary.Load(int3(tile,0));float total=0;
 [loop]for(uint channel=0;channel<4;channel++){
  uint words=(uint)sum[channel];
  [loop]while(words!=0){uint b=firstbitlow(words);words&=words-1;uint word=channel*24+b;
   if(word<(uint)gWords){float4 bits4=mask.Load(int3(tile.x*(uint)gWords+word,tile.y,0));
    [unroll]for(uint j=0;j<4;j++){uint bits=(uint)bits4[j];
     [loop]while(bits!=0){uint k=firstbitlow(bits);bits&=bits-1;uint slot=word*96+j*24+k;
      if(slot<(uint)gCount){float4 path=geometry.Load(int3(slot,0,0)),info=geometry.Load(int3(slot,1,0));
       if(info.w==marker.Load(int3(0,0,0)).x&&info.z>0){
        float2 radius=max(info.xy*gGain,float2(.125,.125));float value=0;
        // Pixel-footprint integration of height, not a replacement for scene AA.
        value+=rainTrailLine(p+float2(-.0625,-.0625),path.xy,path.zw,radius,info.z).x;
        value+=rainTrailLine(p+float2(.0625,-.0625),path.xy,path.zw,radius,info.z).x;
        value+=rainTrailLine(p+float2(-.0625,.0625),path.xy,path.zw,radius,info.z).x;
        value+=rainTrailLine(p+float2(.0625,.0625),path.xy,path.zw,radius,info.z).x;
        total+=value*.25;
       }
      }
     }
    }
   }
  }
 }
 return total*fade;
}
]]
function M.densityShader(line)
 local s={M.grid,line,M.weight,M.sparse,[[float4 main(PS_IN pin){
 int2 pixel=min((int2)(pin.Tex*RV_TRAIL_FINE_GRID),(int2)RV_TRAIL_FINE_GRID-1);
 float2 p=(float2(pixel)+.5)*.25-.5;float4 selected=txSelection.Load(int3(0,0,0));
 float value=gFirst>.5?0:txPrevious.Load(int3(pixel,0)).r;
 ]]}
 for i=0,2 do s[#s+1]=string.format('if(gActive>%d)value+=trailDensity(txGeometry%d,txMask%d,txSummary%d,txMarker%d,p,selected);',i,i,i,i,i)end
 s[#s+1]='return float4(value,0,0,0);}';return table.concat(s,'\n')
end
M.normalize=M.grid..[[
float4 main(PS_IN pin){
 int2 p=min((int2)(pin.Tex*RV_TRAIL_GRID),(int2)RV_TRAIL_GRID-1);
 float4 base=txBase.Load(int3(p,0));float area=txAreas.Load(int3(p,0)).r;
 if(area<=0||!isfinite(area))return 0;
 float stock=max(base.r,0)*area*.001,claim=clamp(txClaim.Load(int3(p,0)).r,0,stock),sum=0;
 [unroll]for(int y=0;y<4;y++)[unroll]for(int x=0;x<4;x++)sum+=txDensity.Load(int3(p*4+int2(x,y),0)).r;
 float coarse=max(stock-claim,0)*1000/area;
 if(sum>1e-30)return float4(coarse,base.g,claim*16000/(area*sum),1);
 return float4(base.r,base.g,0,1); // A marks valid optical support, not water.
}
]]
M.compose=M.grid..[[
// Positive cubic B-spline reconstruction of the coarse optical coefficients.
// Four hardware bilinear fetches implement the16-tap tensor kernel (GPU Gems2,
// ch20). This is an optical surface filter, not a physical stock transport.
float4 trailCubicWeights(float t){
 float t2=t*t,t3=t2*t;
 return float4(1-3*t+3*t2-t3,4-6*t2+3*t3,1+3*t+3*t2-3*t3,t3)/6;
}
float4 trailSmoothCoefficients(float2 uv){
 float2 p=uv*RV_TRAIL_GRID-.5,b=floor(p),f=p-b;
 float4 x=trailCubicWeights(f.x),y=trailCubicWeights(f.y);
 float2 gx=float2(x.x+x.y,x.z+x.w),gy=float2(y.x+y.y,y.z+y.w);
 float2 hx=float2(b.x-1+x.y/gx.x,b.x+1+x.w/gx.y);
 float2 hy=float2(b.y-1+y.y/gy.x,b.y+1+y.w/gy.y);
 float4 a=txNormalization.SampleLevel(samLinearClamp,(float2(hx.x,hy.x)+.5)/RV_TRAIL_GRID,0);
 float4 b0=txNormalization.SampleLevel(samLinearClamp,(float2(hx.y,hy.x)+.5)/RV_TRAIL_GRID,0);
 float4 c=txNormalization.SampleLevel(samLinearClamp,(float2(hx.x,hy.y)+.5)/RV_TRAIL_GRID,0);
 float4 d=txNormalization.SampleLevel(samLinearClamp,(float2(hx.y,hy.y)+.5)/RV_TRAIL_GRID,0);
 return (a*gx.x+b0*gx.y)*gy.x+(c*gx.x+d*gx.y)*gy.y;
}
float4 main(PS_IN pin){
 int2 p=min((int2)(pin.Tex*RV_TRAIL_FINE_GRID),(int2)RV_TRAIL_FINE_GRID-1);
 if(txNormalization.Load(int3(p>>2,0)).a<.5)return 0;
 float4 norm=trailSmoothCoefficients(pin.Tex);norm.rgb/=max(norm.a,1e-9);
 float density=txDensity.Load(int3(p,0)).r;
 return float4(clamp(norm.r+density*norm.b,0,60000),max(norm.g,0),0,0);
}
]]
function M.new(d,v,selection,base)
 assert(v.trails and v.trails.capacity==16,'accepted cohort export')
 local sources=v.trails.cohorts;local passes={};local resources=0;local bytes=0
 local function make(w,h,f)
  resources=resources+1;bytes=bytes+w*h*(f=='r32f'and 4 or 16)
  return d.backend.create({width=w,height=h,format=f},285,100+resources)
 end
 local function packet(body,tx,values,key)
  local vs={};for k,x in pairs(values)do vs[k]=d.backend.make('number',x)end
  local count=0;for _ in pairs(tx)do count=count+1 end;assert(count<=14,'fine optics binding margin')
  return{async=true,directValuesExchange=false,blendMode=d.backend.opaque,cacheKey=key,shader=body,textures=tx,values=vs,defines={}}
 end
 local claims={make(1024,256,'r32f'),make(1024,256,'r32f')}
 local density={make(4096,1024,'r32f'),make(4096,1024,'r32f')}
 local norm=make(1024,256,'rgba32f');local result=make(4096,1024,'rgba32f')
 local claimBody=M.claimShader();local line=assert(d.line,'shared continuous line helper');local fineBody=M.densityShader(line)
 local lastClaim,lastDensity;local gainPackets={}
 for group=1,4 do
  local tx={txSelection=selection,txPrevious=claims[group%2+1]}
  for j=0,3 do local c=sources[(group-1)*4+j+1];tx['txClaim'..j]=c.claim;tx['txMarker'..j]=c.marker end
  local p=packet(claimBody,tx,{gFirst=group==1 and 1 or 0,gActive=4,gLife=.5,gFade=.15},285101)
  lastClaim=claims[(group-1)%2+1];passes[#passes+1]={lastClaim,p}
 end
 for group=1,6 do
  local tx={txSelection=selection,txPrevious=density[group%2+1]};local active=math.min(3,17-(group-1)*3-1)
  for j=0,2 do local c=sources[math.min((group-1)*3+j+1,16)]
   tx['txGeometry'..j]=c.geometry;tx['txMask'..j]=c.mask;tx['txSummary'..j]=c.summary;tx['txMarker'..j]=c.marker
  end
  local p=packet(fineBody,tx,{gFirst=group==1 and 1 or 0,gActive=active,gLife=.5,gFade=.15,
   gGain=.31748021039364,gTile=v.trails.tile,gWords=v.trails.words,gCount=v.headCount},285102)
  gainPackets[#gainPackets+1]=p
  lastDensity=density[(group-1)%2+1];passes[#passes+1]={lastDensity,p}
 end
 passes[#passes+1]={norm,packet(M.normalize,{txBase=base,txAreas=v.areas,txClaim=lastClaim,txDensity=lastDensity},{},285113)}
 passes[#passes+1]={result,packet(M.compose,{txNormalization=norm,txDensity=lastDensity},{},285114)}
 local api={}
 function api:resolve()
  local gain=d.displayGain and d.displayGain()or .31748021039364
  assert(type(gain)=='number'and gain==gain and gain>0 and gain<=4,'display-only diameter gain')
  for _,p in ipairs(gainPackets)do p.values.gGain=d.backend.make('number',gain)end
  for _,p in ipairs(passes)do if not d.backend.draw(p[1],p[2])then return false end end
  return true
 end
 function api:result()return result end
 function api:status()return{resources=resources,descriptorBytes=bytes,draws=#passes,width=4096,height=1024,readbacks=0,physicsChanged=false}end
 return api
end
return M
