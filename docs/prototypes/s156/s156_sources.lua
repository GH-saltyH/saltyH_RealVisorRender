local M={}
M.plan=[====[
// One captured frame, without source application or elapsed-time publication.
float4 main(PS_IN pin){
 uint w=0,h=0;txFrame.GetDimensions(w,h);bool ok=w==1u&&h==52u;
 float4 token=txFrame.Load(int3(0,0,0)),frame=txFrame.Load(int3(0,1,0)),grid=txFrame.Load(int3(0,11,0));
 [loop]for(int i=0;i<52;i++)ok=ok&&all(isfinite(txFrame.Load(int3(0,i,0))));
 ok=ok&&all(token==floor(token))&&all(token>0)&&token.w==1&&frame.z>0&&frame.z<=.05&&frame.w==gHeadCount&&all(grid.xy==gGrid)&&grid.z==16&&grid.w==1;
 ok=ok&&all(txFrame.Load(int3(0,18,0))==token)&&all(txFrame.Load(int3(0,28,0))==token)&&all(txFrame.Load(int3(0,34,0))==token)&&all(txFrame.Load(int3(0,39,0))==token);
 ok=ok&&txFrame.Load(int3(0,31,0)).w==frame.z&&txFrame.Load(int3(0,40,0)).x==frame.z&&txFrame.Load(int3(0,42,0)).x==txFrame.Load(int3(0,49,0)).x&&txFrame.Load(int3(0,49,0)).w==1;
 float4 acceleration=txFrame.Load(int3(0,35,0)),air=txFrame.Load(int3(0,36,0)),material=txFrame.Load(int3(0,37,0)),model=txFrame.Load(int3(0,38,0));
 ok=ok&&acceleration.w>0&&air.w>=0&&all(material.xyz>=0)&&material.w>0&&material.w<=1&&frame.z<=material.w&&all(model==float4(1,0,0,0));
 // The existing film operator has no downward-air variant.
 ok=ok&&txFrame.Load(int3(0,51,0)).y==0;
 uint a=0,b=0;txMetric.GetDimensions(a,b);ok=ok&&a==(uint)gGrid.x&&b==(uint)gGrid.y*3u;
 txAreas.GetDimensions(a,b);ok=ok&&a==(uint)gGrid.x&&b==(uint)gGrid.y;
 txRuns.GetDimensions(a,b);ok=ok&&a==(uint)gGrid.x&&b==(uint)gGrid.y;
 txStaged.GetDimensions(a,b);ok=ok&&a==(uint)gGrid.x&&b==(uint)gGrid.y;
 return float4(ok?frame.z:0,ok?1:0,0,0);
}

]====]
M.physics=[====[
float4 main(PS_IN pin){uint row=min((uint)(pin.Tex.y*5),4u);return txFrame.Load(int3(0,row+34u,0));}

]====]
M.consumer=[====[
float4 physicsRow(int row){return txPhysics.Load(int3(0,row,0));}
bool packetValid(float4 p){return all(isfinite(p))&&p.r>=0&&(p.r>0||all(p.yzw==0));}
bool resolvedMetric(int2 p,out float3 n,out float area){
 float3 u=txMetric.Load(int3(p,0)).xyz,v=txMetric.Load(int3(p+int2(0,(int)gGrid.y),0)).xyz;
 float4 cell=txAreas.Load(int3(p,0));float3 c=cross(u,v);float length2=dot(c,c);
 n=0;area=cell.r;
 bool valid=all(isfinite(u))&&all(isfinite(v))&&all(isfinite(cell))&&area>0&&cell.g==1&&
  length2>1e-20&&isfinite(length2);
 if(valid)n=c*rsqrt(length2);return valid;
}
float3 tangent(float3 v,float3 n){return v-dot(v,n)*n;}
// s96/s99 frozen-depth closure, with density explicitly supplied in the snapshot.
void relaxFilm(float3 old,float3 acceleration,float3 tau,float h,float dt,out float3 end,out float3 mean){
 float rho=physicsRow(1).w,mu=physicsRow(3).x;
 end=old;mean=old;
 if(dt<=0)return;
 float3 drive=acceleration*dt+tau*(3*dt/(2*rho*h));
 if(mu==0){end=old+drive;mean=old+drive*.5;return;}
 float relaxation=rho*h*h/(3*mu),x=dt/relaxation,decay=exp(-x);
 if(x<.1){
  float phi1=1-x*.5+x*x/6-x*x*x/24+x*x*x*x/120;
  float phi2=.5-x/6+x*x/24-x*x*x/120+x*x*x*x/720;
  end=old*decay+drive*phi1;mean=old*phi1+drive*phi2;
 }else{
  float3 terminal=acceleration*relaxation+tau*(h/(2*mu));float phi=(1-decay)/x;
  end=old*decay+terminal*(1-decay);mean=old*phi+terminal*(1-phi);
 }
}
void forcePacket(int2 p,float4 old,float fullDt,out float4 halfEnd,out float4 fullMean,out float4 impulse,out float4 wall,out float status){
 halfEnd=old;fullMean=old;impulse=0;wall=0;status=0;
 if(!packetValid(old)){status=1;halfEnd=0;fullMean=0;return;}
 if(old.r==0)return;
 float3 n;float area;if(!resolvedMetric(p,n,area)){status=1;return;}
 float3 v=tangent(old.yzw/old.r,n),air=tangent(physicsRow(2).xyz,n);
 float3 tau=.5*physicsRow(2).w*physicsRow(3).y*length(air)*air;
 float3 a=tangent(physicsRow(1).xyz,n);float h=old.r/area*.001;
 float3 unusedMean,next,average,unusedEnd;
 relaxFilm(v,a,tau,h,fullDt*.5,next,unusedMean);
 relaxFilm(v,a,tau,h,fullDt,unusedEnd,average);
 if(!all(isfinite(next))||!all(isfinite(average))){status=1;return;}
 halfEnd=float4(old.r,next*old.r);fullMean=float4(old.r,average*old.r);
 impulse=float4(0,(next-v)*old.r);wall=float4(0,old.yzw-v*old.r);
}
// Two bands: unchanged half-End/full-Mean. Negative volume is an error marker.
float4 main(PS_IN pin){
 int bank=min((int)(pin.Tex.y*2),1);int2 p=min((int2)(float2(pin.Tex.x,frac(pin.Tex.y*2))*gGrid),(int2)gGrid-1);
 float4 result=float4(-1,0,0,0);
 if(txBasePlan.Load(int3(0,0,0)).y==1){
  float4 e,m,impulse,wall;float status;
  forcePacket(p,txStaged.Load(int3(p,0)),txBasePlan.Load(int3(0,0,0)).x,e,m,impulse,wall,status);
  if(status==0&&packetValid(e)&&packetValid(m))result=bank==0?e:m;
 }
 return result;
}

]====]
M.audit=[====[
bool packetValid(float4 p){return all(isfinite(p))&&p.r>=0&&(p.r>0||all(p.yzw==0));}
bool resolvedMetric(int2 p,out float3 n,out float area){
 float3 u=txMetric.Load(int3(p,0)).xyz,v=txMetric.Load(int3(p+int2(0,(int)gGrid.y),0)).xyz;
 float4 cell=txAreas.Load(int3(p,0));float3 c=cross(u,v);float length2=dot(c,c);
 n=0;area=cell.r;
 bool valid=all(isfinite(u))&&all(isfinite(v))&&all(isfinite(cell))&&area>0&&cell.g==1&&
  length2>1e-20&&isfinite(length2);
 if(valid)n=c*rsqrt(length2);return valid;
}
float3 tangent(float3 v,float3 n){return v-dot(v,n)*n;}
// Readers require the same immutable stock/metric/area used by the producer.
float compactStatus(int2 p){
 uint width=0,height=0;txForce.GetDimensions(width,height);
 float4 old=txStaged.Load(int3(p,0)),e=txForce.Load(int3(p,0)),m=txForce.Load(int3(p+int2(0,(int)gGrid.y),0));
 bool ok=width==(uint)gGrid.x&&height==(uint)gGrid.y*2u&&packetValid(old)&&packetValid(e)&&packetValid(m)&&e.r==old.r&&m.r==old.r;
 return ok?0:1;
}
void compactLoad(int2 p,out float4 e,out float4 m,out float4 impulse,out float4 wall,out float status){
 status=compactStatus(p);e=0;m=0;impulse=0;wall=0;
 if(status!=0)return;
 e=txForce.Load(int3(p,0));m=txForce.Load(int3(p+int2(0,(int)gGrid.y),0));float4 old=txStaged.Load(int3(p,0));
 if(old.r>0){
  float3 n;float area;
  if(resolvedMetric(p,n,area)){
   float3 previous=tangent(old.yzw/old.r,n)*old.r;
   impulse=float4(0,e.yzw-previous);wall=float4(0,old.yzw-previous);
  }else{status=1;e=0;m=0;}
 }
}
float4 compactImpulse(int2 p){float4 e,m,i,w;float status;compactLoad(p,e,m,i,w,status);return i;}
float4 compactWall(int2 p){float4 e,m,i,w;float status;compactLoad(p,e,m,i,w,status);return w;}
float4 inspect(int2 p){
 int h=(int)gGrid.y;float4 old=txStaged.Load(int3(p,0)),area=txAreas.Load(int3(p,0)),run=txRuns.Load(int3(p,0));
 float4 e,m,impulse,wall;float status;compactLoad(p,e,m,impulse,wall,status);wall.x=status;
 bool wet=old.r>0;bool ok=all(isfinite(old))&&all(isfinite(e))&&all(isfinite(m))&&all(isfinite(impulse))&&all(isfinite(wall))&&old.r>=0&&wall.x==0;
 ok=ok&&e.r==old.r&&m.r==old.r&&impulse.r==0;
 float ratio=0;
 if(wet){
  float3 u=txMetric.Load(int3(p,0)).xyz,v=txMetric.Load(int3(p+int2(0,h),0)).xyz,c=cross(u,v);float norm2=dot(c,c);
  ok=ok&&all(isfinite(area))&&area.r>0&&area.g==1&&norm2>1e-20&&isfinite(norm2)&&all(run==floor(run))&&run.x>=0&&run.y<=gGrid.x&&run.z>=0&&run.w<=gGrid.y&&run.x<=p.x&&run.y>p.x&&run.z<=p.y&&run.w>p.y;
  float3 n=c*rsqrt(max(norm2,1e-20));float scale=max(max(length(old.yzw),length(e.yzw))+length(impulse.yzw)+length(wall.yzw),1e-12);
  ratio=length(e.yzw+wall.yzw-old.yzw-impulse.yzw)/(scale*.000004);
  // Projection cancellation is conditioned by the original momentum too.
  float tangentScale=max(length(old.yzw)+length(e.yzw)+length(m.yzw),1e-12);
  ratio=max(ratio,max(abs(dot(e.yzw,n)),abs(dot(m.yzw,n)))/(tangentScale*.000004));
  ok=ok&&ratio<=1;
 }else ok=ok&&all(old==0)&&all(e==0)&&all(m==0)&&all(impulse==0)&&all(wall==0);
 return float4(ok?0:1,wet?1:0,isfinite(old.r)?old.r:0,ratio);
}
float4 main(PS_IN pin){
 int2 base=(int2)floor(pin.Tex*gAuditSize)*16;float4 sum=0;precise float total=0,correction=0;
 [loop]for(int y=0;y<16;y++)[loop]for(int x=0;x<16;x++){
  int2 p=base+int2(x,y);if(all(p<(int2)gGrid)){
   float4 value=inspect(p);sum.xy+=value.xy;sum.w=max(sum.w,value.w);
   precise float delta=value.z-correction,next=total+delta;correction=(next-total)-delta;total=next;
  }
 }
 sum.z=total;return sum;
}

]====]
M.reduce=[====[
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
M.sourceStatus=[====[
bool packetValid(float4 p){return all(isfinite(p))&&p.r>=0&&(p.r>0||all(p.yzw==0));}
bool resolvedMetric(int2 p,out float3 n,out float area){
 float3 u=txMetric.Load(int3(p,0)).xyz,v=txMetric.Load(int3(p+int2(0,(int)gGrid.y),0)).xyz;
 float4 cell=txAreas.Load(int3(p,0));float3 c=cross(u,v);float length2=dot(c,c);
 n=0;area=cell.r;
 bool valid=all(isfinite(u))&&all(isfinite(v))&&all(isfinite(cell))&&area>0&&cell.g==1&&
  length2>1e-20&&isfinite(length2);
 if(valid)n=c*rsqrt(length2);return valid;
}
float3 tangent(float3 v,float3 n){return v-dot(v,n)*n;}
// Readers require the same immutable stock/metric/area used by the producer.
float compactStatus(int2 p){
 uint width=0,height=0;txForce.GetDimensions(width,height);
 float4 old=txStaged.Load(int3(p,0)),e=txForce.Load(int3(p,0)),m=txForce.Load(int3(p+int2(0,(int)gGrid.y),0));
 bool ok=width==(uint)gGrid.x&&height==(uint)gGrid.y*2u&&packetValid(old)&&packetValid(e)&&packetValid(m)&&e.r==old.r&&m.r==old.r;
 return ok?0:1;
}
void compactLoad(int2 p,out float4 e,out float4 m,out float4 impulse,out float4 wall,out float status){
 status=compactStatus(p);e=0;m=0;impulse=0;wall=0;
 if(status!=0)return;
 e=txForce.Load(int3(p,0));m=txForce.Load(int3(p+int2(0,(int)gGrid.y),0));float4 old=txStaged.Load(int3(p,0));
 if(old.r>0){
  float3 n;float area;
  if(resolvedMetric(p,n,area)){
   float3 previous=tangent(old.yzw/old.r,n)*old.r;
   impulse=float4(0,e.yzw-previous);wall=float4(0,old.yzw-previous);
  }else{status=1;e=0;m=0;}
 }
}
float4 compactImpulse(int2 p){float4 e,m,i,w;float status;compactLoad(p,e,m,i,w,status);return i;}
float4 compactWall(int2 p){float4 e,m,i,w;float status;compactLoad(p,e,m,i,w,status);return w;}
float4 main(PS_IN pin){
 int2 p=(int2)floor(pin.Tex*gStatusSize);float status=0;
 if(p.y<(int)gGrid.y){
  if(gStatusMode<.5)status=max(txStaged.Load(int3(p+int2(0,3*(int)gGrid.y),0)).r,compactStatus(p));
  else status=txPost.Load(int3(p+int2(0,4*(int)gGrid.y),0)).r;
 }else if(gStatusMode<.5){
  int slot=(p.y-(int)gGrid.y)*(int)gGrid.x+p.x;
  if(slot<(int)gHeadCount)status=txHeadSource.Load(int3(slot,1,0)).r;
 }
 return float4(isfinite(status)?status:1,0,0,0);
}

]====]
M.ledgerTiles=[====[
bool packetValid(float4 p){return all(isfinite(p))&&p.r>=0&&(p.r>0||all(p.yzw==0));}
bool resolvedMetric(int2 p,out float3 n,out float area){
 float3 u=txMetric.Load(int3(p,0)).xyz,v=txMetric.Load(int3(p+int2(0,(int)gGrid.y),0)).xyz;
 float4 cell=txAreas.Load(int3(p,0));float3 c=cross(u,v);float length2=dot(c,c);
 n=0;area=cell.r;
 bool valid=all(isfinite(u))&&all(isfinite(v))&&all(isfinite(cell))&&area>0&&cell.g==1&&
  length2>1e-20&&isfinite(length2);
 if(valid)n=c*rsqrt(length2);return valid;
}
float3 tangent(float3 v,float3 n){return v-dot(v,n)*n;}
// Readers require the same immutable stock/metric/area used by the producer.
float compactStatus(int2 p){
 uint width=0,height=0;txForce.GetDimensions(width,height);
 float4 old=txStaged.Load(int3(p,0)),e=txForce.Load(int3(p,0)),m=txForce.Load(int3(p+int2(0,(int)gGrid.y),0));
 bool ok=width==(uint)gGrid.x&&height==(uint)gGrid.y*2u&&packetValid(old)&&packetValid(e)&&packetValid(m)&&e.r==old.r&&m.r==old.r;
 return ok?0:1;
}
void compactLoad(int2 p,out float4 e,out float4 m,out float4 impulse,out float4 wall,out float status){
 status=compactStatus(p);e=0;m=0;impulse=0;wall=0;
 if(status!=0)return;
 e=txForce.Load(int3(p,0));m=txForce.Load(int3(p+int2(0,(int)gGrid.y),0));float4 old=txStaged.Load(int3(p,0));
 if(old.r>0){
  float3 n;float area;
  if(resolvedMetric(p,n,area)){
   float3 previous=tangent(old.yzw/old.r,n)*old.r;
   impulse=float4(0,e.yzw-previous);wall=float4(0,old.yzw-previous);
  }else{status=1;e=0;m=0;}
 }
}
float4 compactImpulse(int2 p){float4 e,m,i,w;float status;compactLoad(p,e,m,i,w,status);return i;}
float4 compactWall(int2 p){float4 e,m,i,w;float status;compactLoad(p,e,m,i,w,status);return w;}
// Eight packet sums: initial, final, supply, internal pool, impulse, wall, evap, runoff.
void addPacket(float4 value,inout float4 sum,inout float4 correction){
 precise float4 y=value-correction,next=sum+y;precise float4 error=(next-sum)-y;correction=error;sum=next;
}
float4 main(PS_IN pin){
 if(txDecision.Load(int3(0,0,0)).r!=1)return 0;
 int bank=min((int)(pin.Tex.y*8),7);int2 tile=(int2)(float2(pin.Tex.x,frac(pin.Tex.y*8))*gLedgerTiles);
 float4 sum=0,correction=0;
 [loop]for(int y=0;y<16;y++)[loop]for(int x=0;x<16;x++){
  int2 p=tile*16+int2(x,y);if(any(p>=(int2)gLedgerSize))continue;float4 v=0;
  if(p.y<(int)gGrid.y){
   if(bank==0)v=txOriginalEnd.Load(int3(p,0));
   if(bank==1)v=txPost.Load(int3(p,0));
   if(bank==2)v=txStaged.Load(int3(p+int2(0,(int)gGrid.y),0));
   if(bank==3)v=float4(txStaged.Load(int3(p+int2(0,2*(int)gGrid.y),0)).r,0,0,0);
   if(bank==4)v=compactImpulse(p)+txPost.Load(int3(p+int2(0,3*(int)gGrid.y),0));
   if(bank==5)v=float4(0,txStaged.Load(int3(p+int2(0,2*(int)gGrid.y),0)).yzw+compactWall(p).yzw+txPost.Load(int3(p+int2(0,4*(int)gGrid.y),0)).yzw);
   if(bank==6)v=txPost.Load(int3(p+int2(0,2*(int)gGrid.y),0));
   if(bank==7&&all(p==0))v=txLossL0.Load(int3(0,1,0))+txLossL1.Load(int3(0,1,0));
  }else{
   int slot=(p.y-(int)gGrid.y)*(int)gGrid.x+p.x;
   if(slot<(int)gHeadCount){if(bank==0)v=txOriginalHeads.Load(int3(slot,0,0));if(bank==1)v=txHeadSource.Load(int3(slot,0,0));}
  }
  addPacket(v,sum,correction);
 }return sum;
}

]====]
M.expand=[====[
bool packetValid(float4 p){return all(isfinite(p))&&p.r>=0&&(p.r>0||all(p.yzw==0));}
bool resolvedMetric(int2 p,out float3 n,out float area){
 float3 u=txMetric.Load(int3(p,0)).xyz,v=txMetric.Load(int3(p+int2(0,(int)gGrid.y),0)).xyz;
 float4 cell=txAreas.Load(int3(p,0));float3 c=cross(u,v);float length2=dot(c,c);
 n=0;area=cell.r;
 bool valid=all(isfinite(u))&&all(isfinite(v))&&all(isfinite(cell))&&area>0&&cell.g==1&&
  length2>1e-20&&isfinite(length2);
 if(valid)n=c*rsqrt(length2);return valid;
}
float3 tangent(float3 v,float3 n){return v-dot(v,n)*n;}
// Readers require the same immutable stock/metric/area used by the producer.
float compactStatus(int2 p){
 uint width=0,height=0;txForce.GetDimensions(width,height);
 float4 old=txStaged.Load(int3(p,0)),e=txForce.Load(int3(p,0)),m=txForce.Load(int3(p+int2(0,(int)gGrid.y),0));
 bool ok=width==(uint)gGrid.x&&height==(uint)gGrid.y*2u&&packetValid(old)&&packetValid(e)&&packetValid(m)&&e.r==old.r&&m.r==old.r;
 return ok?0:1;
}
void compactLoad(int2 p,out float4 e,out float4 m,out float4 impulse,out float4 wall,out float status){
 status=compactStatus(p);e=0;m=0;impulse=0;wall=0;
 if(status!=0)return;
 e=txForce.Load(int3(p,0));m=txForce.Load(int3(p+int2(0,(int)gGrid.y),0));float4 old=txStaged.Load(int3(p,0));
 if(old.r>0){
  float3 n;float area;
  if(resolvedMetric(p,n,area)){
   float3 previous=tangent(old.yzw/old.r,n)*old.r;
   impulse=float4(0,e.yzw-previous);wall=float4(0,old.yzw-previous);
  }else{status=1;e=0;m=0;}
 }
}
float4 compactImpulse(int2 p){float4 e,m,i,w;float status;compactLoad(p,e,m,i,w,status);return i;}
float4 compactWall(int2 p){float4 e,m,i,w;float status;compactLoad(p,e,m,i,w,status);return w;}

float4 main(PS_IN pin){int bank=min((int)(pin.Tex.y*4),3);int2 p=min((int2)(float2(pin.Tex.x,frac(pin.Tex.y*4))*gGrid),(int2)gGrid-1);float4 e,m,i,w;float status;compactLoad(p,e,m,i,w,status);return bank==0?e:bank==1?m:bank==2?i:float4(status,w.yzw);}
]====]
return M
