local M={}
M.metric=[====[
bool fieldHeader(){
 uint w=0,h=0;txHeader.GetDimensions(w,h);if(w!=1u||h!=52u)return false;
 float4 a=txHeader.Load(int3(0,13,0)),b=txHeader.Load(int3(0,14,0)),c=txHeader.Load(int3(0,15,0));
 float s2=txHeader.Load(int3(0,50,0)).z;float eps=max(s2,1e-20)*.00001;
 return all(isfinite(a))&&all(isfinite(b))&&all(isfinite(c))&&isfinite(s2)&&s2>1e-12&&
  all(float3(a.w,b.w,c.w)==0)&&all(txHeader.Load(int3(0,11,0)).xy==gGrid)&&
  abs(dot(a.xyz,a.xyz)-s2)<=eps&&abs(dot(b.xyz,b.xyz)-s2)<=eps&&abs(dot(c.xyz,c.xyz)-s2)<=eps&&
  abs(dot(a.xyz,b.xyz))<=eps&&abs(dot(a.xyz,c.xyz))<=eps&&abs(dot(b.xyz,c.xyz))<=eps&&dot(a.xyz,cross(b.xyz,c.xyz))>0;
}
float3x3 poseMatrix(){return float3x3(txHeader.Load(int3(0,13,0)).xyz,txHeader.Load(int3(0,14,0)).xyz,txHeader.Load(int3(0,15,0)).xyz);}
bool supported(float4 c){return all(isfinite(c))&&c.r>0&&c.a==1&&c.g>0;}
int2 rawPixel(int2 p){uint w=0,h=0;txDu.GetDimensions(w,h);return min((int2)((float2(p)+.5)*float2(w,h)/gGrid),int2(w-1,h-1));}
float4 main(PS_IN pin){
 uint2 q=(uint2)floor(pin.Tex*float2(gGrid.x,gGrid.y*3));uint band=q.y/(uint)gGrid.y;int2 p=int2(q.x,q.y%(uint)gGrid.y);
 float4 result=0;float4 cell=txCells.Load(int3(p,0));
 if(fieldHeader()&&supported(cell)){
  int2 raw=rawPixel(p);float3 u=mul(txDu.Load(int3(raw,0)).xyz,poseMatrix()),v=mul(txDv.Load(int3(raw,0)).xyz,poseMatrix());
  precise float a=dot(u,u),b=dot(u,v),c=dot(v,v),det=a*c-b*b;
  if(all(isfinite(u))&&all(isfinite(v))&&isfinite(det)&&det>1e-20){
   if(band==0u)result=float4(u,1);else if(band==1u)result=float4(v,1);else result=float4(a,b,c,det);
  }
 }
 return result;
}

]====]
M.areas=[====[
bool fieldHeader(){
 uint w=0,h=0;txHeader.GetDimensions(w,h);if(w!=1u||h!=52u)return false;
 float4 a=txHeader.Load(int3(0,13,0)),b=txHeader.Load(int3(0,14,0)),c=txHeader.Load(int3(0,15,0));
 float s2=txHeader.Load(int3(0,50,0)).z;float eps=max(s2,1e-20)*.00001;
 return all(isfinite(a))&&all(isfinite(b))&&all(isfinite(c))&&isfinite(s2)&&s2>1e-12&&
  all(float3(a.w,b.w,c.w)==0)&&all(txHeader.Load(int3(0,11,0)).xy==gGrid)&&
  abs(dot(a.xyz,a.xyz)-s2)<=eps&&abs(dot(b.xyz,b.xyz)-s2)<=eps&&abs(dot(c.xyz,c.xyz)-s2)<=eps&&
  abs(dot(a.xyz,b.xyz))<=eps&&abs(dot(a.xyz,c.xyz))<=eps&&abs(dot(b.xyz,c.xyz))<=eps&&dot(a.xyz,cross(b.xyz,c.xyz))>0;
}
float3x3 poseMatrix(){return float3x3(txHeader.Load(int3(0,13,0)).xyz,txHeader.Load(int3(0,14,0)).xyz,txHeader.Load(int3(0,15,0)).xyz);}
bool supported(float4 c){return all(isfinite(c))&&c.r>0&&c.a==1&&c.g>0;}
int2 rawPixel(int2 p){uint w=0,h=0;txDu.GetDimensions(w,h);return min((int2)((float2(p)+.5)*float2(w,h)/gGrid),int2(w-1,h-1));}
float4 main(PS_IN pin){
 int2 p=(int2)floor(pin.Tex*gGrid);float4 cell=txCells.Load(int3(p,0));float4 result=0;
 if(fieldHeader()&&supported(cell))result=float4(cell.r*txHeader.Load(int3(0,50,0)).z,1,cell.g,cell.b);
 return result;
}

]====]
M.leaves=[====[
bool supported(float4 c){return all(isfinite(c))&&c.r>0&&c.a==1&&c.g>0;}
float4 main(PS_IN pin){
 uint2 q=(uint2)floor(pin.Tex*gLeafSize);uint k=q.y*(uint)gLeafSize.x+q.x;
 uint nx=((uint)gGrid.x+15u)/16u,ny=((uint)gGrid.y+15u)/16u,xCount=nx*(uint)gGrid.y,total=xCount+ny*(uint)gGrid.x;uint mask=0;
 if(k<total){
  bool axisY=k>=xCount;uint localK=axisY?k-xCount:k;uint blocks=axisY?ny:nx;uint lane=localK/blocks,block=localK%blocks;
  [unroll]for(uint i=0;i<16u;i++){
   uint offset=block*16u+i;uint2 p=axisY?uint2(lane,offset):uint2(offset,lane);
   if(p.x<(uint)gGrid.x&&p.y<(uint)gGrid.y&&supported(txCells.Load(int3(p,0))))mask|=1u<<i;
  }
 }
 return float4(mask,0,0,1);
}

]====]
M.runs=[====[
bool supported(float4 c){return all(isfinite(c))&&c.r>0&&c.a==1&&c.g>0;}
uint leafMask(uint block,uint lane,uint axis){
 uint nx=((uint)gGrid.x+15u)/16u,ny=((uint)gGrid.y+15u)/16u;
 uint k=axis==0u?lane*nx+block:nx*(uint)gGrid.y+lane*ny+block;
 return(uint)txLeaves.Load(int3(k%(uint)gLeafSize.x,k/(uint)gLeafSize.x,0)).r;
}
int2 extent(uint coordinate,uint lane,uint axis){
 int size=axis==0u?(int)gGrid.x:(int)gGrid.y;int block=(int)(coordinate>>4u),offset=(int)(coordinate&15u);
 uint mask=leafMask(block,lane,axis);int left=0,right=size;bool found=false;
 [loop]for(int j=offset-1;j>=0;--j)if(!found&&((mask>>j)&1u)==0u){left=block*16+j+1;found=true;}
 [loop]for(int b=block-1;b>=0&&!found;--b){uint bits=leafMask(b,lane,axis);if(bits!=65535u){
  [unroll]for(int j=15;j>=0;--j)if(!found&&((bits>>j)&1u)==0u){left=b*16+j+1;found=true;}
 }}
 found=false;
 [loop]for(int rj=offset+1;rj<16;++rj)if(!found&&((mask>>rj)&1u)==0u){right=min(size,block*16+rj);found=true;}
 [loop]for(int rb=block+1;rb<(int)(((uint)size+15u)>>4u)&&!found;++rb){uint rbits=leafMask(rb,lane,axis);if(rbits!=65535u){
  [unroll]for(int rbit=0;rbit<16;++rbit)if(!found&&((rbits>>rbit)&1u)==0u){right=min(size,rb*16+rbit);found=true;}
 }}
 return int2(left,right);
}
float4 main(PS_IN pin){
 uint2 p=(uint2)floor(pin.Tex*gGrid);float4 result=-1;
 if(supported(txCells.Load(int3(p,0))))result=float4(extent(p.x,p.y,0u),extent(p.y,p.x,1u));
 return result;
}

]====]
M.audit=[====[
bool fieldHeader(){
 uint w=0,h=0;txHeader.GetDimensions(w,h);if(w!=1u||h!=52u)return false;
 float4 a=txHeader.Load(int3(0,13,0)),b=txHeader.Load(int3(0,14,0)),c=txHeader.Load(int3(0,15,0));
 float s2=txHeader.Load(int3(0,50,0)).z;float eps=max(s2,1e-20)*.00001;
 return all(isfinite(a))&&all(isfinite(b))&&all(isfinite(c))&&isfinite(s2)&&s2>1e-12&&
  all(float3(a.w,b.w,c.w)==0)&&all(txHeader.Load(int3(0,11,0)).xy==gGrid)&&
  abs(dot(a.xyz,a.xyz)-s2)<=eps&&abs(dot(b.xyz,b.xyz)-s2)<=eps&&abs(dot(c.xyz,c.xyz)-s2)<=eps&&
  abs(dot(a.xyz,b.xyz))<=eps&&abs(dot(a.xyz,c.xyz))<=eps&&abs(dot(b.xyz,c.xyz))<=eps&&dot(a.xyz,cross(b.xyz,c.xyz))>0;
}
float3x3 poseMatrix(){return float3x3(txHeader.Load(int3(0,13,0)).xyz,txHeader.Load(int3(0,14,0)).xyz,txHeader.Load(int3(0,15,0)).xyz);}
bool supported(float4 c){return all(isfinite(c))&&c.r>0&&c.a==1&&c.g>0;}
int2 rawPixel(int2 p){uint w=0,h=0;txDu.GetDimensions(w,h);return min((int2)((float2(p)+.5)*float2(w,h)/gGrid),int2(w-1,h-1));}
float4 checkCell(int2 p){
 float4 local=txCells.Load(int3(p,0)),area=txAreas.Load(int3(p,0)),run=txRuns.Load(int3(p,0));
 float4 U=txMetric.Load(int3(p,0)),V=txMetric.Load(int3(p+int2(0,(int)gGrid.y),0)),G=txMetric.Load(int3(p+int2(0,(int)gGrid.y*2),0));
 bool active=supported(local);bool ok=fieldHeader()&&all(isfinite(local))&&local.r>=0&&local.g>=0&&local.g<=1&&local.b>=0&&local.b<=1&&local.a==(local.r>0?1:0);
 float ratio=0;
 if(active){
  ok=ok&&all(isfinite(U))&&all(isfinite(V))&&all(isfinite(G))&&all(isfinite(area))&&all(isfinite(run))&&U.a==1&&V.a==1&&G.w>1e-20;
  float s2=txHeader.Load(int3(0,50,0)).z;int2 raw=rawPixel(p);float3 u=txDu.Load(int3(raw,0)).xyz,v=txDv.Load(int3(raw,0)).xyz;
  float3 inverseU=mul(U.xyz,transpose(poseMatrix()))/s2,inverseV=mul(V.xyz,transpose(poseMatrix()))/s2;
  float scale=max(max(length(u),length(v)),1e-10);ratio=max(length(inverseU-u),length(inverseV-v))/(scale*.00001);
  float3 gram=float3(dot(U.xyz,U.xyz),dot(U.xyz,V.xyz),dot(V.xyz,V.xyz));float norm=max(max(gram.x,gram.z),1e-20);
  ratio=max(ratio,max(max(abs(G.x-gram.x),abs(G.y-gram.y)),abs(G.z-gram.z))/(norm*.00001));
  float expectedDet=G.x*G.z-G.y*G.y;ratio=max(ratio,abs(G.w-expectedDet)/(max(abs(G.x*G.z)+abs(G.y*G.y),1e-20)*.00001));
  ratio=max(ratio,abs(area.r-local.r*s2)/(max(local.r*s2,1e-20)*.00001));
  ok=ok&&ratio<=1&&area.g==1&&all(area.ba==local.gb)&&all(run==floor(run))&&run.x>=0&&run.y<=gGrid.x&&run.z>=0&&run.w<=gGrid.y&&run.x<=p.x&&run.y>p.x&&run.z<=p.y&&run.w>p.y;
  int2 offsets[4]={int2(-1,0),int2(1,0),int2(0,-1),int2(0,1)};
  [unroll]for(uint k=0;k<4u;k++){
   int2 n=p+offsets[k];bool inside=all(n>=0)&&all(n<(int2)gGrid);bool next=inside&&supported(txCells.Load(int3(n,0)));
   if(next){float4 neighbour=txRuns.Load(int3(n,0));ok=ok&&(k<2u?all(run.xy==neighbour.xy):all(run.zw==neighbour.zw));}
   else ok=ok&&(k==0u?run.x==p.x:k==1u?run.y==p.x+1:k==2u?run.z==p.y:run.w==p.y+1);
  }
 }else ok=ok&&all(U==0)&&all(V==0)&&all(G==0)&&all(area==0)&&all(run==-1);
 return float4(ok?0:1,active?1:0,active?area.r:0,ratio);
}
float4 main(PS_IN pin){
 int2 base=(int2)floor(pin.Tex*gAuditSize)*16;float4 result=0;float correction=0;
 [loop]for(int y=0;y<16;y++)[loop]for(int x=0;x<16;x++){
  int2 p=base+int2(x,y);if(all(p<(int2)gGrid)){
   float4 value=checkCell(p);result.xy+=value.xy;result.w=max(result.w,value.w);
   float increment=value.z-correction,next=result.z+increment;correction=(next-result.z)-increment;result.z=next;
  }
 }
 return result;
}

]====]
M.audit_reduce=[====[
float4 main(PS_IN pin){
 int2 base=(int2)floor(pin.Tex*gAuditSize)*16;float4 result=0;float correction=0;
 [loop]for(int y=0;y<16;y++)[loop]for(int x=0;x<16;x++){
  int2 p=base+int2(x,y);if(all(p<(int2)gInputSize)){
   float4 value=txAudit.Load(int3(p,0));result.xy+=value.xy;result.w=max(result.w,value.w);
   float increment=value.z-correction,next=result.z+increment;correction=(next-result.z)-increment;result.z=next;
  }
 }
 return result;
}

]====]
return M
