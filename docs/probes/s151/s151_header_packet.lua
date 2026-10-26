-- Common frame stamp for diagnostic P2/SI/head/field/request headers.
-- Car-reference pose packets never authorize the visor solver.
local M={rows=50};local function cp(t)if type(t)~='table'then return t end;local o={};for k,v in pairs(t)do o[k]=cp(v)end;return o end
local function finite(x)return type(x)=='number'and x==x and math.abs(x)<math.huge end
local function roundEven(x)local n=math.floor(x);local f=x-n;return n+((f>.5 or(f==.5 and n%2==1))and 1 or 0)end
function M.f32(v)
 assert(finite(v),'finite float');local negative=v<0 or(v==0 and 1/v<0);v=math.abs(v);local result=0
 if v>0 then if v<2^-126 then result=roundEven(v*2^149)*2^-149 else local m,e=math.frexp(v);result=roundEven(m*2^24)*2^(e-24)end end
 assert(result<2^128,'float overflow');return negative and -result or result
end
function M.hex32(v)
 v=M.f32(v);local sign=(v<0 or(v==0 and 1/v<0))and 2147483648 or 0;v=math.abs(v);local word=0
 if v>0 then if v<2^-126 then word=v*2^149 else local m,e=math.frexp(v);word=(e+126)*8388608+(m*2-1)*8388608 end end
 word=word+sign;local a={};for i=8,1,-1 do local n=word%16;a[i]=('0123456789abcdef'):sub(n+1,n+1);word=math.floor(word/16)end;return table.concat(a)
end
function M.compose(observation,config,checksum)
 local s,c=cp(observation),cp(config);assert(s.scope=='engine_observation_v1'and s.frame==s.frameAfter,'engine snapshot')
 assert(type(checksum)=='function','content checksum');local dt=s.rawDt;assert(finite(dt)and dt>0 and dt<=.05,'bounded raw dt')
 local ticks=math.floor(dt*1048576+.5);assert(ticks>=1 and ticks<=52428,'representable dt');local represented=ticks/1048576
 local e=s.environment;local n=c.headCount or 8;local w,h=c.fieldWidth or 13,c.fieldHeight or 7;local pad=16
 assert(n>=1 and n<=4096 and n==math.floor(n)and w>=1 and w<=4096 and h>=1 and h<=512 and w==math.floor(w)and h==math.floor(h),'shape')
 local start=c.startTick or 0;assert(start>=0 and start==math.floor(start)and start+ticks<2^40,'clock')
 local epoch=c.epoch or 151;local id=c.intervalId or 1;assert(epoch>=1 and epoch<=1048575 and id>=1 and id<=1048575 and epoch==math.floor(epoch)and id==math.floor(id),'token')
 local token={epoch,1,id,1};local previous={epoch,1,id-1,1};local frame=s.frame;local tick=c.sourceTick or 1;assert(tick>=0 and tick<=1048575 and tick==math.floor(tick),'source tick')
 local theta=c.theta or 90;assert(theta>0 and theta<180,'contact angle');local area=c.localAreaM2 or .040289;assert(area>0 and finite(area),'area')
 local airFraction=c.airFraction or .3;assert(airFraction>=0 and airFraction<=1,'air fraction')
 local mask=c.forceMask or 7;assert(mask>=0 and mask<=7 and mask==math.floor(mask),'force mask');local function on(bit)return math.floor(mask/bit)%2 end
 local density=s.supply.numberDensityM3;assert(density>=0 and finite(density),'supply')
 local b={token,{frame,tick,represented,n},{math.floor(start/65536),start%65536,math.floor((start+ticks)/65536),(start+ticks)%65536},{1,1,1,1},{density,area*s.physicalScale^2,c.exposure or 1,1},cp(s.supply.weights),{e.airX,e.airY,e.airZ,.25},{998.2,.0728,.001002,.25},{0,0,20,1},{math.min(theta+6,179.9),math.min(theta+2,179.9),theta,0},{0,n,tick,0},{w,h,pad,1},{.2,.8,.25,1},cp(s.pose.rows[1]),cp(s.pose.rows[2]),cp(s.pose.rows[3]),cp(s.pose.rows[4]),previous}
 local si={token,{e.inertiaX,e.inertiaY,e.inertiaZ,mask},{e.airX,e.airY,e.airZ,airFraction},{998.2,.001002,.0728,e.airDensity},{theta,12,4,.7},{4,2,1,0},{1,.05,1,0},{.35,.05,.001,.5},{.2,math.sqrt(e.airX^2+e.airY^2+e.airZ^2),1,0},{1,1,1,tick}}
 local head={token,previous,{frame-1,frame,frame,frame},{1,1,1,represented},{w,h,pad,5},{1,1,1,1}}
 local physics={token,{e.inertiaX*on(2),-9.80665*on(1)+e.inertiaY*on(2),e.inertiaZ*on(2),998.2},{e.airX*airFraction*on(4),e.airY*airFraction*on(4),e.airZ*airFraction*on(4),e.airDensity},{.001002,.005,.2,.05},{1,0,0,0}}
 local request={token,{represented,1048576,524288,0},{tick,n,1,1}}
 local telemetry={{frame,s.carIndex,dt,dt-represented},{e.intensity,e.trackWetness,e.trackWater,e.humidity},{e.temperatureC,e.pressurePa,e.airDensity,e.liquidFraction},{e.windX,e.windY,e.windZ,e.carSpeedMS},{e.velocityX,e.velocityY,e.velocityZ,e.liquidIntensity},{e.inertiaX,e.inertiaY,e.inertiaZ,1},{e.currentType,e.upcomingType,e.transition,e.invalidMask},{s.frameAfter,e.clampedMask,1,s.pose.scope=='visor_model_world_v1'and 1 or 0}}
 local rows={};for _,group in ipairs({b,si,head,physics,request,telemetry})do for _,r in ipairs(group)do assert(#r==4,'row');local v={};for i,x in ipairs(r)do v[i]=M.f32(x)end;rows[#rows+1]=v end end;assert(#rows==M.rows)
 local all={};for _,r in ipairs(rows)do for _,v in ipairs(r)do all[#all+1]=M.hex32(v)end end
 local canonical='RealVisor/s151/header_rows_v1\n'..table.concat(all);local key=checksum(canonical);assert(type(key)=='string','SHA256 result')
 if #key==32 then key=key:gsub('.',function(byte)return string.format('%02x',string.byte(byte))end)else key=key:lower()end
 assert(#key==64 and not key:find('[^0-9a-f]'),'SHA256 result')
 return{scope='diagnostic_engine_headers_v1',rows=rows,canonical=canonical,contentKey=key,frame=frame,carIndex=s.carIndex,rawDt=dt,representedDt=represented,unrepresentedSeconds=dt-represented,startTick=start,endTick=start+ticks,token=cp(token),poseScope=s.pose.scope,materialSource='probe_reference_v1',strictCompletion=false,solverAdmission=false,publicClockAdvanced=false}
end
function M.shader()
 local a={'float4 main(PS_IN pin){uint row=min((uint)(pin.Tex.y*50),49u);'}
 for i=0,49 do a[#a+1]=string.format('if(row==%du)return gS151Row%02d;',i,i)end;a[#a+1]='return 0;}';return table.concat(a,'\n')
end
M.reader='float4 main(PS_IN pin){uint2 p=(uint2)floor(pin.Tex*float2(64,4));uint k=p.y*64u+p.x;float v=0;if(k<200u){float4 r=txS151ImmutableRows.Load(int3(0,k/4u,0));v=r[k%4u];}return float4(v,0,0,1);}'
return M
