-- Project one admitted engine slice into a producer-owned immutable cohort.
local M={}
local function cp(t)if type(t)~='table'then return t end;local r={};for k,v in pairs(t)do r[k]=cp(v)end;return r end
function M.new(Packet,seed)
 local shape={seed.rows[12][1],seed.rows[12][2],seed.rows[2][4]};local units=cp(seed.unitRows[1]);local geometryKey=seed.geometryKey
 local api={}
 function api:bind(c)
  assert(c.scope=='main_app_context_diagnostic_v1'and type(c.capturedContentKey)=='string'and #c.capturedContentKey==64 and not c.contentKey,'admitted engine context')
  local serial=c.token[3];assert(c.token[1]==234 and c.token[2]==1 and c.token[4]==1 and serial>=1 and serial<=1048575 and serial==math.floor(serial),'private token')
  assert(#c.rows==50 and #c.unitRows==2 and c.geometryKey==geometryKey,'geometry context')
  assert(c.rows[12][1]==shape[1]and c.rows[12][2]==shape[2]and c.rows[2][4]==shape[3],'fixed field/head shape')
  for i,v in ipairs(units)do assert(v==c.unitRows[1][i],'physical calibration must be admission-aligned')end
  local rows=cp(c.rows);for _,group in ipairs({rows,c.unitRows})do for _,r in ipairs(group)do assert(#r==4,'four component row');for _,v in ipairs(r)do assert(type(v)=='number'and v==v and math.abs(v)<math.huge and Packet.f32(v)==v,'finite FP32 row')end end end
  assert(rows[2][1]==Packet.f32(c.frame),'engine frame provenance')
  for _,i in ipairs({1,19,29,35,40})do for j=1,4 do assert(rows[i][j]==c.token[j],'cohort token')end end
  local dt=rows[2][3];assert(dt>0 and dt<=.05 and dt*1048576==math.floor(dt*1048576),'represented source dt')
  assert((rows[3][3]-rows[3][1])*65536+rows[3][4]-rows[3][2]==dt*1048576,'source clock')
  -- Engine frame remains in telemetry and provenance. Legacy producers need a
  -- strictly increasing internal frame even when one engine frame is sliced.
  rows[2][1]=serial;rows[2][2]=serial;rows[11]={0,shape[3],serial,0}
  rows[9][2]=1 -- Use the leased physical film/micro height, not track wetness.
  rows[28][4]=serial;rows[31]={serial-1,serial,serial,serial}
  for _,i in ipairs({18,30})do rows[i]={c.token[1],c.token[2],serial-1,1}end
  rows[42][1]=serial
  local values={};for i=0,51 do values[string.format('gRow%02d',i)]=cp(i<50 and rows[i+1]or c.unitRows[i-49])end
  return{serial=serial,dt=dt,rows=rows,unitRows=cp(c.unitRows),values=values,
   engineFrame=c.frame,sourceKey=c.capturedContentKey,sourceSlice=cp(c.timeSlice),geometryKey=c.geometryKey,
   displayGainUsed=false,poolEnabled=false,mergeEnabled=false,wetFieldEnabled=true}
 end
 return api
end
M.header=(function()local s={'float4 main(PS_IN pin){uint i=min((uint)(pin.Tex.y*52),51u);float4 result=0;'};for i=0,51 do s[#s+1]=string.format('if(i==%du)result=gRow%02d;',i,i)end;s[#s+1]='return result;}';return table.concat(s,'\n')end)()
M.slice='float4 main(PS_IN pin){return txHeader.Load(int3(0,(uint)(pin.Tex.y*gRows)+(uint)gOffset,0));}'
M.pose='float4 main(PS_IN pin){return txHeader.Load(int3(0,min((uint)(pin.Tex.x*3),2u)+13u,0));}'
M.merge=[[
float4 main(PS_IN pin){uint row=min((uint)(pin.Tex.y*3),2u);float4 result=0;
 if(row==0u)result=txHeader.Load(int3(0,0,0));
 else if(row==1u)result=float4(txHeader.Load(int3(0,22,0)).x,1,txHeader.Load(int3(0,0,0)).z-1,1);
 else{float4 u=txHeader.Load(int3(0,50,0));result=float4(u.xy,txHeader.Load(int3(0,1,0)).z,1);}return result;}
]]
M.boundary=[[
float4 main(PS_IN pin){uint w,h;txDu.GetDimensions(w,h);int2 p=min((int2)(pin.Tex*float2(w,h)),int2(w-1,h-1));
 float a=1;[unroll]for(int y=0;y<2;y++)[unroll]for(int x=0;x<2;x++)a=min(a,txMask.Load(int3(p*2+int2(x,y),0)).a);
 return float4(0,0,0,txDu.Load(int3(p,0)).a>=.5?a:0);}
]]
M.wet=[[
float4 main(PS_IN pin){int2 p=(int2)(pin.Tex*gGrid);float a=txAreas.Load(int3(p,0)).r;
 return a>0?float4(txFilm.Load(int3(p,0)).r,txMicro.Load(int3(p,0)).r,0,0)*1000/a:0;}
]]
M.zero='float4 main(PS_IN pin){return 0;}'
return M
