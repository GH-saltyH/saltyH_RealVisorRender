-- Offline raw-coverage/scalar-area adapter and conserved source composition.
local M={}
M.receipt=[====[
bool shape(Texture2D<float4> t,uint w,uint h){uint x,y;t.GetDimensions(x,y);return x==w&&y==h;}
float4 main(PS_IN pin){
 bool ok=shape(txRawCells,(uint)gGrid.x,(uint)gGrid.y)&&shape(txAreas,(uint)gGrid.x,(uint)gGrid.y)&&
  shape(txAreaHeader,1,52)&&shape(txExpectedHeader,1,52)&&shape(txSourceHeader,1,5);
 [loop]for(uint i=0;i<52u;i++){
  float4 a=txAreaHeader.Load(int3(0,i,0)),b=txExpectedHeader.Load(int3(0,i,0));ok=ok&&all(isfinite(a))&&all(isfinite(b))&&all(a==b);
 }
 float4 token=txAreaHeader.Load(int3(0,0,0)),frame=txAreaHeader.Load(int3(0,1,0));
 float4 source=txSourceHeader.Load(int3(0,2,0));float scale2=txAreaHeader.Load(int3(0,50,0)).z;
 [unroll]for(uint j=0;j<5u;j++)ok=ok&&all(isfinite(txSourceHeader.Load(int3(0,j,0))));
 ok=ok&&all(token==txSourceHeader.Load(int3(0,0,0)))&&token.w==1&&all(token.xyz>0)&&all(floor(token.xyz)==token.xyz)&&
  frame.x==source.y&&frame.x>=0&&floor(frame.x)==frame.x&&frame.w==gCount&&txSourceHeader.Load(int3(0,1,0)).w==gCount&&
  all(txAreaHeader.Load(int3(0,11,0)).xy==gGrid)&&all(txSourceHeader.Load(int3(0,1,0)).xy==gGrid)&&scale2>1e-12;
 return float4(ok?1:0,ok?scale2:0,0,1);
}
]====]
M.cells=[====[
float4 main(PS_IN pin){
 int2 p=(int2)floor(pin.Tex*gGrid);float4 raw=txRawCells.Load(int3(p,0));float area=txAreas.Load(int3(p,0)).r;
 float4 receipt=txReceipt.Load(int3(0,0,0));
 bool ok=receipt.x==1&&all(isfinite(raw))&&isfinite(area)&&area>=0&&raw.r>=0&&raw.g>=0&&raw.g<=1&&raw.b>=0&&raw.b<=1;
 bool active=raw.a==1&&raw.r>0&&raw.g>0;
 bool dry=all(raw==0)&&area==0;
 precise float expected=raw.r*receipt.y;
 ok=ok&&(active||dry)&&isfinite(expected)&&area==expected&&(!active||area>0);
 // Invalid cells must fail global source admission, never become dry support.
 return ok?float4(area,raw.g,1,1):float4(-1,0,0,0);
}
]====]
local function identity(s) return type(s)=='string'and #s==64 and not s:find('[^0-9a-f]') end
local function validate(count,w,h,c)
 for _,d in ipairs({{count,4096},{w,4096},{h,512}})do assert(type(d[1])=='number'and d[1]>=1 and d[1]<=d[2]and math.floor(d[1])==d[1],'shape')end
 assert(type(c)=='table'and c.rawDomain=='field_local_area_coverage_coating_v1'and c.areaDomain=='physical_cell_area_mm2_v1','physical domains')
 assert(c.areaFormat=='r32f'and c.rawFormat=='rgba32f','typed inputs')
 for _,k in ipairs({'contextKey','areaContextKey','geometryKey','rawGeometryKey','areaGeometryKey','poseKey','areaPoseKey','rawResourceKey','areaResourceKey'})do assert(identity(c[k]),'input identity')end
 assert(c.contextKey==c.areaContextKey and c.geometryKey==c.rawGeometryKey and c.geometryKey==c.areaGeometryKey and c.poseKey==c.areaPoseKey,'input ownership mismatch')
end
function M.recipe(count,w,h,c)
 validate(count,w,h,c)
 local r={resources={},passes={},roots={receipt=6,cells=7},contract=c};local p={passes={}}
 for i,d in ipairs({{w,h,'rgba32f'},{w,h,'r32f'},{1,52,'rgba32f'},{1,52,'rgba32f'},{1,5,'rgba32f'},{1,1,'rgba32f'},{w,h,'rgba32f'}})do
  r.resources[i]={width=d[1],height=d[2],format=d[3],mips=1,imported=i<=5 or nil}
 end
 r.passes[1]={kind='shader',target=6,shader=M.receipt,cacheKey=170001,textures={txRawCells=1,txAreas=2,txAreaHeader=3,txExpectedHeader=4,txSourceHeader=5},values={gGrid='vec2',gCount='number'}}
 r.passes[2]={kind='shader',target=7,shader=M.cells,cacheKey=170002,textures={txRawCells=1,txAreas=2,txReceipt=6},values={gGrid='vec2'}}
 p.passes={{gGrid={w,h},gCount=count},{gGrid={w,h}}};return r,p
end
function M.source(count,w,h,c,diagnostic)
 local a,b=M.recipe(count,w,h,c)
 local old,packet=require('s167_handoff').recipe(count,w,h,'retained_impact_packets_v1','resolved_film_v1',diagnostic)
 local r={resources={},passes={},roots={},adapter={cells=7,receipt=17,raw=13,areas=14,areaHeader=15,expectedHeader=16,contract=c}};local p={passes={}}
 for i=1,12 do r.resources[i]=old.resources[i]end;r.resources[7].imported=nil
 local map={[1]=13,[2]=14,[3]=15,[4]=16,[5]=9,[6]=17,[7]=7}
 for i=1,4 do r.resources[12+i]=a.resources[i]end;r.resources[17]=a.resources[6]
 for i=13,#old.resources do r.resources[i+5]=old.resources[i]end
 for i,call in ipairs(a.passes)do
  local tx={};for k,j in pairs(call.textures)do tx[k]=map[j]end
  r.passes[#r.passes+1]={kind=call.kind,target=map[call.target],shader=call.shader,cacheKey=call.cacheKey,textures=tx,values=call.values};p.passes[#p.passes+1]=b.passes[i]
 end
 local function index(i)return i>12 and i+5 or i end
 for i,call in ipairs(old.passes)do
  local tx={};for k,j in pairs(call.textures)do tx[k]=index(j)end
  r.passes[#r.passes+1]={kind=call.kind,target=index(call.target),shader=call.shader,cacheKey=call.cacheKey,textures=tx,values=call.values};p.passes[#p.passes+1]=packet.passes[i]
 end
 for k,i in pairs(old.roots)do r.roots[k]=index(i)end
 r.maxBytes=0;for _,d in ipairs(r.resources)do r.maxBytes=r.maxBytes+d.width*d.height*(d.format=='r32f'and 4 or 16)end
 assert(r.maxBytes<=256*1024*1024,'byte budget');return r,p
end
return M
