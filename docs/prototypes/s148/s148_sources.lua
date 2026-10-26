local M={keys={decode=1,descriptor=2,export=3,filmMeta=4,merge=5,meta=6,motion=7,originalMotion=8,reduce=9,state=10,trace=11,zero=12}}
M.decode=[====[
// Actual P1/P2/P3 channel adapter. No display radius enters a physical packet.
bool integerValue(float x){return isfinite(x)&&x>=0&&x<=16777215&&floor(x)==x;}
bool inside(float2 p){return all(p>=float2(0,-1))&&all(p<=float2(1,0));}
bool dimensions(Texture2D<float4> t,uint w,uint h){uint a,b;t.GetDimensions(a,b);return a==w&&b==h;}
bool context(){
 float4 token=txHeader.Load(int3(0,0,0)),previous=txHeader.Load(int3(0,1,0));
 float4 frames=txHeader.Load(int3(0,2,0)),mode=txHeader.Load(int3(0,3,0));
 float4 field=txHeader.Load(int3(0,4,0)),revision=txHeader.Load(int3(0,5,0));
 bool ok=all(isfinite(token))&&all(isfinite(previous))&&all(isfinite(frames))&&all(isfinite(mode))&&all(isfinite(field))&&all(isfinite(revision));
 ok=ok&&integerValue(token.x)&&token.x>0&&integerValue(token.y)&&token.y>0&&integerValue(token.z)&&token.z>0&&token.w==1;
 ok=ok&&all(previous.xy==token.xy)&&previous.z+1==token.z&&previous.w==1;
 ok=ok&&integerValue(frames.x)&&integerValue(frames.y)&&frames.y>frames.x&&frames.z==frames.y&&frames.w==frames.y;
 ok=ok&&all(mode.xyz==1)&&mode.w>0&&mode.w<=.05;
 ok=ok&&integerValue(field.x)&&field.x>0&&integerValue(field.y)&&field.y>0&&integerValue(field.z)&&field.z>=1&&field.z<=16&&field.w==5;
 ok=ok&&integerValue(revision.x)&&revision.x>0&&integerValue(revision.y)&&revision.y>0&&integerValue(revision.z)&&revision.z>0&&revision.w==1;
 ok=ok&&dimensions(txHeader,1,6)&&dimensions(txOldState,(uint)gCount,1)&&dimensions(txOldMeta,(uint)gCount,1);
 ok=ok&&dimensions(txNewState,(uint)gCount,1)&&dimensions(txPreMeta,(uint)gCount,1)&&dimensions(txFinalMeta,(uint)gCount,1);
 ok=ok&&dimensions(txEvents,(uint)gCount,5)&&dimensions(txDescriptors,(uint)gCount,5);
 uint w,h;txDu.GetDimensions(w,h);ok=ok&&w>0&&h>0&&dimensions(txDv,w,h)&&dimensions(txBoundary,w,h);
 ok=ok&&dimensions(txOldTransform,3,1)&&dimensions(txNewTransform,3,1);
 float3 a=txOldTransform.Load(int3(0,0,0)).xyz,b=txOldTransform.Load(int3(1,0,0)).xyz,c=txOldTransform.Load(int3(2,0,0)).xyz;
 float3 d=txNewTransform.Load(int3(0,0,0)).xyz,e=txNewTransform.Load(int3(1,0,0)).xyz,f=txNewTransform.Load(int3(2,0,0)).xyz;
 float oldDet=dot(a,cross(b,c)),newDet=dot(d,cross(e,f));
 return ok&&all(isfinite(a))&&all(isfinite(b))&&all(isfinite(c))&&all(isfinite(d))&&all(isfinite(e))&&all(isfinite(f))&&isfinite(oldDet)&&isfinite(newDet)&&abs(oldDet)>1e-20&&abs(newDet)>1e-20;
}
int2 metricCell(float2 p){uint w,h;txDu.GetDimensions(w,h);return clamp((int2)(float2(p.x,p.y+1)*float2(w,h)),int2(0,0),int2(w-1,h-1));}
bool supported(float2 p){int2 c=metricCell(p);return inside(p)&&txDu.Load(int3(c,0)).w>=.5&&txBoundary.Load(int3(c,0)).w>=.5;}
float3 transformVector(float3 p,bool old){
 float3 a=0,b=0,c=0;
 if(old){a=txOldTransform.Load(int3(0,0,0)).xyz;b=txOldTransform.Load(int3(1,0,0)).xyz;c=txOldTransform.Load(int3(2,0,0)).xyz;}
 else{a=txNewTransform.Load(int3(0,0,0)).xyz;b=txNewTransform.Load(int3(1,0,0)).xyz;c=txNewTransform.Load(int3(2,0,0)).xyz;}
 return p.x*a+p.y*b+p.z*c;
}
bool velocity(float4 s,bool old,out float3 v){
 int2 p=metricCell(s.xy);float3 u=transformVector(txDu.Load(int3(p,0)).xyz,old),w=transformVector(txDv.Load(int3(p,0)).xyz,old);
 v=u*s.z+w*s.w;
 float3 normal=cross(u,w);float norm2=dot(normal,normal);
 return all(isfinite(u))&&all(isfinite(w))&&all(isfinite(v))&&all(isfinite(normal))&&isfinite(norm2)&&norm2>1e-20;
}
float generation(float4 m){return floor(m.a*.25);}
float life(float4 m){return m.a-4*generation(m);}
bool metaValid(float4 m){return all(isfinite(m))&&all(m.rgb>=0)&&integerValue(m.a)&&generation(m)<4096&&(life(m)==0||life(m)==1)&&((life(m)==0&&m.g==0)||(life(m)==1&&m.g>0));}
float4 packet(float volume,float3 v){return float4(volume,volume*v);}
bool supportSize(float2 p,float pad){return all(isfinite(p))&&all(p>=1)&&all(p<=pad)&&all(floor(p)==p);}
// A frozen command creator supplies full generations, not reconstructed low bits.
bool extraContext(){
 float4 a=txMergeConfig.Load(int3(0,0,0)),b=txMergeConfig.Load(int3(0,1,0)),c=txMergeConfig.Load(int3(0,2,0));
 float4 token=txHeader.Load(int3(0,0,0));float4 frames=txHeader.Load(int3(0,2,0));
 bool ok=dimensions(txMergeCommand,(uint)gCount,1)&&dimensions(txMergeGeneration,(uint)gCount,1)&&dimensions(txMergeConfig,1,3)&&dimensions(txPostForce,(uint)gCount,1);
 ok=ok&&all(a==token)&&all(isfinite(b))&&all(isfinite(c))&&b.x>0&&b.x<180&&b.y>0&&integerValue(b.z)&&b.z<=frames.x&&frames.x-b.z<4096&&b.w==1;
 ok=ok&&c.x>0&&c.y>0&&c.z==txHeader.Load(int3(0,3,0)).w&&c.w==1;
 // Original transport uses a reference unit. Its product must still mean 1 mm
 // after the physical scale. Neither value is the display-diameter gain.
 float3 x=txNewTransform.Load(int3(0,0,0)).xyz,y=txNewTransform.Load(int3(1,0,0)).xyz,z=txNewTransform.Load(int3(2,0,0)).xyz;
 float scale=length(x);float tol=max(scale*scale*32*1.1920928955078125e-7,1e-12);
 ok=ok&&isfinite(scale)&&scale>0&&abs(dot(y,y)-scale*scale)<=tol&&abs(dot(z,z)-scale*scale)<=tol;
 ok=ok&&abs(dot(x,y))<=tol&&abs(dot(x,z))<=tol&&abs(dot(y,z))<=tol;
 return ok&&isfinite(c.x*c.y*scale)&&abs(c.x*c.y*scale-.001)<=.001*32*1.1920928955078125e-7;
}
float3 worldAt(float2 p,float2 uv,bool old){float4 s=float4(p,uv);float3 v=0;velocity(s,old,v);return v;}
float2 projectAt(float2 p,float3 m){
 int2 q=metricCell(p);float3 u=transformVector(txDu.Load(int3(q,0)).xyz,false),v=transformVector(txDv.Load(int3(q,0)).xyz,false);
 float a=dot(u,u),b=dot(u,v),c=dot(v,v),det=a*c-b*b;
 return float2(c*dot(u,m)-b*dot(v,m),a*dot(v,m)-b*dot(u,m))/max(det,1e-20);
}
bool commandBytes(float4 c,out uint4 b){
 b=(uint4)floor(saturate(c)*255+.5);
 return all(isfinite(c))&&all(c>=0)&&all(c<=1)&&all(abs(c*255-(float4)b)<=255*4*1.1920928955078125e-7);
}
#define txRainDu txDu
#define txRainDv txDv
#define txRainBoundaryMask txBoundary
#define gRainMetersPerUnit txMergeConfig.Load(int3(0,2,0)).x
#define gRainReferencePerMM txMergeConfig.Load(int3(0,2,0)).y
#define gRainObjectToWorld float3x3(txNewTransform.Load(int3(0,0,0)).xyz,txNewTransform.Load(int3(1,0,0)).xyz,txNewTransform.Load(int3(2,0,0)).xyz)
#define gRainForceMask txSI.Load(int3(0,1,0)).w
#define gRainSiInertiaWorld txSI.Load(int3(0,1,0)).xyz
#define gRainSiAirWorld txSI.Load(int3(0,2,0)).xyz
#define gRainSiAirFraction txSI.Load(int3(0,2,0)).w
#define gRainSiRhoWater txSI.Load(int3(0,3,0)).x
#define gRainSiMu txSI.Load(int3(0,3,0)).y
#define gRainSiGamma txSI.Load(int3(0,3,0)).z
#define gRainSiRhoAir txSI.Load(int3(0,3,0)).w
#define gRainSiTheta txSI.Load(int3(0,4,0)).x
#define gRainSiStaticBare txSI.Load(int3(0,4,0)).y
#define gRainSiStaticCoat txSI.Load(int3(0,4,0)).z
#define gRainSiAttachedCd txSI.Load(int3(0,4,0)).w
#define gRainSiDynamicBare txSI.Load(int3(0,5,0)).x
#define gRainSiDynamicCoat txSI.Load(int3(0,5,0)).y
#define gRainSiViscousShape txSI.Load(int3(0,5,0)).z
#define gRainAirflowDownwardMode txSI.Load(int3(0,5,0)).w
#define gRainAirflowDownwardGain txSI.Load(int3(0,6,0)).x
#define gFilmGrid txHeader.Load(int3(0,4,0)).xy
#define gFilmPad txHeader.Load(int3(0,4,0)).z
#define gFilmCount gCount
#define gFilmTheta gRainSiTheta
#define gFilmMu gRainSiMu
#define gFilmGamma gRainSiGamma
#define gFilmDepositBare txSI.Load(int3(0,7,0)).x
#define gFilmDepositCoat txSI.Load(int3(0,7,0)).y
#define gFilmMinSpeedMS txSI.Load(int3(0,7,0)).z
#define gFilmWiden txSI.Load(int3(0,7,0)).w
#define gFilmEvapUMS txSI.Load(int3(0,8,0)).x
#define gFilmAirMS txSI.Load(int3(0,8,0)).y
#define gFilmDt txHeader.Load(int3(0,3,0)).w
#define gFilmMotionDt gFilmDt
#define gPoolOn 1
bool headContext(){
 bool ok=context()&&extraContext()&&dimensions(txSI,1,10)&&dimensions(txBirthReceipt,1,1)&&dimensions(txBirthHeader,1,5);
 [unroll]for(uint k=0;k<10u;k++)ok=ok&&all(isfinite(txSI.Load(int3(0,k,0))));
 float4 t=txHeader.Load(int3(0,0,0)),material=txSI.Load(int3(0,3,0)),angles=txSI.Load(int3(0,4,0)),dynamic=txSI.Load(int3(0,5,0));
 float4 mode=txSI.Load(int3(0,6,0)),film=txSI.Load(int3(0,7,0)),evap=txSI.Load(int3(0,8,0)),rev=txSI.Load(int3(0,9,0));
 float4 source=txBirthHeader.Load(int3(0,2,0)),shape=txBirthHeader.Load(int3(0,1,0));
 return ok&&all(txSI.Load(int3(0,0,0))==t)&&all(txBirthReceipt.Load(int3(0,0,0))==t)&&all(txBirthHeader.Load(int3(0,0,0))==t)&&
  all(txBirthHeader.Load(int3(0,4,0))==txHeader.Load(int3(0,1,0)))&&all(shape==float4(gFilmGrid,gFilmPad,gCount))&&source.y==txHeader.Load(int3(0,2,0)).y&&source.z==1&&source.w==1&&
  all(txBirthHeader.Load(int3(0,3,0))==float4(1,1,16,0))&&gRainForceMask>=0&&gRainForceMask<=7&&floor(gRainForceMask)==gRainForceMask&&
  gRainSiAirFraction>=0&&gRainSiAirFraction<=1&&material.x>0&&material.y>=0&&material.z>0&&material.w>=0&&
  angles.x==txMergeConfig.Load(int3(0,1,0)).x&&angles.x>0&&angles.x<180&&all(angles.yzw>=0)&&
  all(dynamic.xyz>=0)&&(dynamic.w==0||dynamic.w==1)&&mode.x>=0&&mode.y>0&&mode.y<=.05&&gFilmDt<=mode.y&&mode.z==1&&mode.w==0&&
  all(film>=0)&&all(evap.xy>=0)&&evap.z==1&&evap.w==0&&all(rev.xyz==txHeader.Load(int3(0,5,0)).xyz)&&rev.w==source.x;
}
float4 main(PS_IN pin){
 uint i=min((uint)(pin.Tex.x*gCount),(uint)gCount-1);uint row=min((uint)(pin.Tex.y*20),19u);
 float4 result=0;float code=1;
 if(headContext()&&dimensions(txOwnership,(uint)gCount,6)&&dimensions(txTrace,(uint)gCount,4)){
  float4 os=txOldState.Load(int3(i,0,0)),om=txOldMeta.Load(int3(i,0,0)),ns=txNewState.Load(int3(i,0,0));
  float4 pm=txPreMeta.Load(int3(i,0,0)),fm=txFinalMeta.Load(int3(i,0,0));
  float4 spawn=txEvents.Load(int3(i,0,0)),motion=txEvents.Load(int3(i,1,0)),allocation=txEvents.Load(int3(i,2,0)),ledger=txEvents.Load(int3(i,3,0)),pool=txEvents.Load(int3(i,4,0));
  float4 path=txDescriptors.Load(int3(i,0,0)),transfer=txDescriptors.Load(int3(i,1,0)),incident=txDescriptors.Load(int3(i,2,0)),support=txDescriptors.Load(int3(i,3,0));
  bool finite=all(isfinite(os))&&all(isfinite(ns))&&all(isfinite(spawn))&&all(isfinite(motion))&&all(isfinite(allocation))&&all(isfinite(ledger))&&all(isfinite(pool));
  finite=finite&&all(isfinite(path))&&all(isfinite(transfer))&&all(isfinite(incident))&&all(isfinite(support));
  bool ok=finite&&metaValid(om)&&metaValid(pm)&&metaValid(fm)&&all(allocation>=0)&&all(ledger>=0)&&all(spawn.zw>=0)&&pool.z>=0&&pool.w==0&&all(transfer>=0);
  code=2;
  if(ok){
   bool oa=life(om)==1,pa=life(pm)==1;bool birth=!oa&&pa;float attached=ledger.z,poolV=pool.z;
   float4 pair=txOwnership.Load(int3(i,2,0)),wall=txOwnership.Load(int3(i,3,0)),flags=txOwnership.Load(int3(i,4,0));
   float4 traced=txTrace.Load(int3(i,0,0)),exited=txTrace.Load(int3(i,2,0)),traceInfo=txTrace.Load(int3(i,3,0));
   bool immediate=traceInfo.x==1||traceInfo.x==2;float exitV=exited.r;
   float mergedV=txOwnership.Load(int3(i,1,0)).g;
   bool ownership=flags.r==0&&traceInfo.x>=0&&traceInfo.x<=2&&all(ns==traced)&&ledger.y==0&&all(isfinite(pair))&&all(isfinite(wall))&&all(isfinite(exited));
   bool transition=true;
   if(oa){
    transition=spawn.z==0&&spawn.w==0&&attached==0&&poolV==0&&generation(pm)==generation(om);
    // An explicit reciprocal pair moves ownership; an immediate exit retires it.
    transition=transition&&((pa&&pm.g==mergedV&&exitV==0&&!immediate)||(!pa&&((flags.y==-1&&exitV==0&&!immediate)||(immediate&&exitV==mergedV))));
   }else if(birth){
    float expected=fmod(generation(om)+1,4096)+1;
    transition=spawn.w==expected&&pm.a==(expected-1)*4+1&&pm.g==spawn.z&&spawn.z==attached+poolV;
    transition=transition&&(attached>0||poolV>0)&&!(attached>0&&poolV>0)&&exitV==0&&all(ns.xy==spawn.xy)&&all(ns.zw==motion.xy);
    transition=transition&&(poolV==0||all(motion.xy==0));
   }else transition=pm.a==om.a&&spawn.z==0&&spawn.w==0&&attached==0&&poolV==0&&exitV==0;
   transition=transition&&ownership&&(!pa||supported(ns.xy))&&(!oa||supported(os.xy));
   float3 ov=0,nv=0;bool oldVelocity=true,newVelocity=true;
   if(oa)oldVelocity=velocity(os,true,ov);
   if(pa)newVelocity=velocity(ns,false,nv);
   transition=transition&&oldVelocity&&newVelocity;
   code=3;
   if(transition){
    precise float remaining=max(pm.g-transfer.x,0);
    precise float finalV=max(remaining-transfer.w,0);
    float finalLife=finalV>0?1:0;
    bool debit=transfer.x<=pm.g&&transfer.w<=remaining&&fm.g==finalV&&generation(fm)==generation(pm)&&life(fm)==finalLife;
    debit=debit&&(!birth||transfer.x==0)&&((pa)||(transfer.x==0&&transfer.w==0));
    // Final age is reset only on full depletion; radius is an opaque codec.
    debit=debit&&fm.b==(finalV>0?pm.b:0);
    float4 field=txHeader.Load(int3(0,4,0));float2 grid=field.xy;float pad=field.z;
    float film=allocation.y+ledger.x,micro=allocation.z;
    bool geometry=incident.z==film&&incident.w==micro;
    if(film+micro>0){
     float2 centre=float2(pool.x,pool.y+1)*grid+pad-.5;
     geometry=geometry&&inside(pool.xy)&&supported(pool.xy)&&all(incident.xy==centre)&&supportSize(support.xy,pad);
    }
    if(transfer.x>0){
     float4 expectedPath=float4(float2(os.x,os.y+1)*grid+pad-.5,float2(ns.x,ns.y+1)*grid+pad-.5);
     geometry=geometry&&oa&&pa&&supported(os.xy)&&all(path==expectedPath)&&supportSize(transfer.yz,pad);
    }
    float externalOut=attached+film+micro+allocation.w;
    float scale=abs(pair.r)+om.g+fm.g+transfer.x+transfer.w+exitV+film+micro+allocation.w+allocation.x+poolV;
    float residual=fm.g+transfer.x+transfer.w+exitV+film+micro+allocation.w-om.g-allocation.x-poolV-pair.r;
    float limit=max(scale*128*1.1920928955078125e-7,1e-9);
    bool budget=isfinite(externalOut)&&isfinite(scale)&&isfinite(residual)&&isfinite(limit)&&abs(externalOut-allocation.x)<=limit&&abs(residual)<=limit;
    code=debit?(geometry?(budget?0:6):5):4;
    if(code==0){
     float4 oldHead=packet(om.g,ov),preHead=packet(pm.g,nv),finalHead=packet(fm.g,nv),external=packet(attached,nv),returned=packet(poolV,0);
     // This is an observed residual impulse, not an independent force solve.
     float4 impulse=preHead+exited+wall-oldHead-external-returned-pair;impulse.r=0;
     bool packetsFinite=all(isfinite(oldHead))&&all(isfinite(preHead))&&all(isfinite(finalHead))&&all(isfinite(external))&&all(isfinite(returned))&&all(isfinite(exited))&&all(isfinite(impulse));
     packetsFinite=packetsFinite&&all(isfinite(packet(transfer.x,nv)))&&all(isfinite(packet(transfer.w,nv)));
     if(!packetsFinite)code=7;
     if(row==0u)result=oldHead;
     else if(row==1u)result=preHead;
     else if(row==2u)result=finalHead;
     else if(row==3u)result=external;
     else if(row==4u)result=returned;
     else if(row==5u)result=packet(transfer.x,nv);
     else if(row==6u)result=packet(transfer.w,nv);
     else if(row==7u)result=exited;
     else if(row==8u)result=float4(film,0,0,0);
     else if(row==9u)result=float4(micro,0,0,0);
     else if(row==10u)result=float4(allocation.w,0,0,0);
     else if(row==11u)result=float4(allocation.x,0,0,0);
     else if(row==12u)result=impulse;
     else if(row==14u)result=path;
     else if(row==15u)result=transfer;
     else if(row==16u)result=incident;
     else if(row==17u)result=support;
     else if(row==18u)result=pair;
     else if(row==19u)result=wall;
    }
   }
  }
 }
 if(code!=0)result=0;
 if(row==13u)result=float4(code,i,0,0);
 if(!all(isfinite(result)))result=row==13u?float4(7,i,0,0):0;
 return result;
}
]====]
M.descriptor=[====[
// Actual P1/P2/P3 channel adapter. No display radius enters a physical packet.
bool integerValue(float x){return isfinite(x)&&x>=0&&x<=16777215&&floor(x)==x;}
bool inside(float2 p){return all(p>=float2(0,-1))&&all(p<=float2(1,0));}
bool dimensions(Texture2D<float4> t,uint w,uint h){uint a,b;t.GetDimensions(a,b);return a==w&&b==h;}
bool context(){
 float4 token=txHeader.Load(int3(0,0,0)),previous=txHeader.Load(int3(0,1,0));
 float4 frames=txHeader.Load(int3(0,2,0)),mode=txHeader.Load(int3(0,3,0));
 float4 field=txHeader.Load(int3(0,4,0)),revision=txHeader.Load(int3(0,5,0));
 bool ok=all(isfinite(token))&&all(isfinite(previous))&&all(isfinite(frames))&&all(isfinite(mode))&&all(isfinite(field))&&all(isfinite(revision));
 ok=ok&&integerValue(token.x)&&token.x>0&&integerValue(token.y)&&token.y>0&&integerValue(token.z)&&token.z>0&&token.w==1;
 ok=ok&&all(previous.xy==token.xy)&&previous.z+1==token.z&&previous.w==1;
 ok=ok&&integerValue(frames.x)&&integerValue(frames.y)&&frames.y>frames.x&&frames.z==frames.y&&frames.w==frames.y;
 ok=ok&&all(mode.xyz==1)&&mode.w>0&&mode.w<=.05;
 ok=ok&&integerValue(field.x)&&field.x>0&&integerValue(field.y)&&field.y>0&&integerValue(field.z)&&field.z>=1&&field.z<=16&&field.w==5;
 ok=ok&&integerValue(revision.x)&&revision.x>0&&integerValue(revision.y)&&revision.y>0&&integerValue(revision.z)&&revision.z>0&&revision.w==1;
 ok=ok&&dimensions(txHeader,1,6)&&dimensions(txOldState,(uint)gCount,1)&&dimensions(txOldMeta,(uint)gCount,1);
 ok=ok&&dimensions(txNewState,(uint)gCount,1)&&dimensions(txPreMeta,(uint)gCount,1)&&dimensions(txFinalMeta,(uint)gCount,1);
 ok=ok&&dimensions(txEvents,(uint)gCount,5)&&dimensions(txDescriptors,(uint)gCount,5);
 uint w,h;txDu.GetDimensions(w,h);ok=ok&&w>0&&h>0&&dimensions(txDv,w,h)&&dimensions(txBoundary,w,h);
 ok=ok&&dimensions(txOldTransform,3,1)&&dimensions(txNewTransform,3,1);
 float3 a=txOldTransform.Load(int3(0,0,0)).xyz,b=txOldTransform.Load(int3(1,0,0)).xyz,c=txOldTransform.Load(int3(2,0,0)).xyz;
 float3 d=txNewTransform.Load(int3(0,0,0)).xyz,e=txNewTransform.Load(int3(1,0,0)).xyz,f=txNewTransform.Load(int3(2,0,0)).xyz;
 float oldDet=dot(a,cross(b,c)),newDet=dot(d,cross(e,f));
 return ok&&all(isfinite(a))&&all(isfinite(b))&&all(isfinite(c))&&all(isfinite(d))&&all(isfinite(e))&&all(isfinite(f))&&isfinite(oldDet)&&isfinite(newDet)&&abs(oldDet)>1e-20&&abs(newDet)>1e-20;
}
int2 metricCell(float2 p){uint w,h;txDu.GetDimensions(w,h);return clamp((int2)(float2(p.x,p.y+1)*float2(w,h)),int2(0,0),int2(w-1,h-1));}
bool supported(float2 p){int2 c=metricCell(p);return inside(p)&&txDu.Load(int3(c,0)).w>=.5&&txBoundary.Load(int3(c,0)).w>=.5;}
float3 transformVector(float3 p,bool old){
 float3 a=0,b=0,c=0;
 if(old){a=txOldTransform.Load(int3(0,0,0)).xyz;b=txOldTransform.Load(int3(1,0,0)).xyz;c=txOldTransform.Load(int3(2,0,0)).xyz;}
 else{a=txNewTransform.Load(int3(0,0,0)).xyz;b=txNewTransform.Load(int3(1,0,0)).xyz;c=txNewTransform.Load(int3(2,0,0)).xyz;}
 return p.x*a+p.y*b+p.z*c;
}
bool velocity(float4 s,bool old,out float3 v){
 int2 p=metricCell(s.xy);float3 u=transformVector(txDu.Load(int3(p,0)).xyz,old),w=transformVector(txDv.Load(int3(p,0)).xyz,old);
 v=u*s.z+w*s.w;
 float3 normal=cross(u,w);float norm2=dot(normal,normal);
 return all(isfinite(u))&&all(isfinite(w))&&all(isfinite(v))&&all(isfinite(normal))&&isfinite(norm2)&&norm2>1e-20;
}
float generation(float4 m){return floor(m.a*.25);}
float life(float4 m){return m.a-4*generation(m);}
bool metaValid(float4 m){return all(isfinite(m))&&all(m.rgb>=0)&&integerValue(m.a)&&generation(m)<4096&&(life(m)==0||life(m)==1)&&((life(m)==0&&m.g==0)||(life(m)==1&&m.g>0));}
float4 packet(float volume,float3 v){return float4(volume,volume*v);}
bool supportSize(float2 p,float pad){return all(isfinite(p))&&all(p>=1)&&all(p<=pad)&&all(floor(p)==p);}
// A frozen command creator supplies full generations, not reconstructed low bits.
bool extraContext(){
 float4 a=txMergeConfig.Load(int3(0,0,0)),b=txMergeConfig.Load(int3(0,1,0)),c=txMergeConfig.Load(int3(0,2,0));
 float4 token=txHeader.Load(int3(0,0,0));float4 frames=txHeader.Load(int3(0,2,0));
 bool ok=dimensions(txMergeCommand,(uint)gCount,1)&&dimensions(txMergeGeneration,(uint)gCount,1)&&dimensions(txMergeConfig,1,3)&&dimensions(txPostForce,(uint)gCount,1);
 ok=ok&&all(a==token)&&all(isfinite(b))&&all(isfinite(c))&&b.x>0&&b.x<180&&b.y>0&&integerValue(b.z)&&b.z<=frames.x&&frames.x-b.z<4096&&b.w==1;
 ok=ok&&c.x>0&&c.y>0&&c.z==txHeader.Load(int3(0,3,0)).w&&c.w==1;
 // Original transport uses a reference unit. Its product must still mean 1 mm
 // after the physical scale. Neither value is the display-diameter gain.
 float3 x=txNewTransform.Load(int3(0,0,0)).xyz,y=txNewTransform.Load(int3(1,0,0)).xyz,z=txNewTransform.Load(int3(2,0,0)).xyz;
 float scale=length(x);float tol=max(scale*scale*32*1.1920928955078125e-7,1e-12);
 ok=ok&&isfinite(scale)&&scale>0&&abs(dot(y,y)-scale*scale)<=tol&&abs(dot(z,z)-scale*scale)<=tol;
 ok=ok&&abs(dot(x,y))<=tol&&abs(dot(x,z))<=tol&&abs(dot(y,z))<=tol;
 return ok&&isfinite(c.x*c.y*scale)&&abs(c.x*c.y*scale-.001)<=.001*32*1.1920928955078125e-7;
}
float3 worldAt(float2 p,float2 uv,bool old){float4 s=float4(p,uv);float3 v=0;velocity(s,old,v);return v;}
float2 projectAt(float2 p,float3 m){
 int2 q=metricCell(p);float3 u=transformVector(txDu.Load(int3(q,0)).xyz,false),v=transformVector(txDv.Load(int3(q,0)).xyz,false);
 float a=dot(u,u),b=dot(u,v),c=dot(v,v),det=a*c-b*b;
 return float2(c*dot(u,m)-b*dot(v,m),a*dot(v,m)-b*dot(u,m))/max(det,1e-20);
}
bool commandBytes(float4 c,out uint4 b){
 b=(uint4)floor(saturate(c)*255+.5);
 return all(isfinite(c))&&all(c>=0)&&all(c<=1)&&all(abs(c*255-(float4)b)<=255*4*1.1920928955078125e-7);
}
#define txRainDu txDu
#define txRainDv txDv
#define txRainBoundaryMask txBoundary
#define gRainMetersPerUnit txMergeConfig.Load(int3(0,2,0)).x
#define gRainReferencePerMM txMergeConfig.Load(int3(0,2,0)).y
#define gRainObjectToWorld float3x3(txNewTransform.Load(int3(0,0,0)).xyz,txNewTransform.Load(int3(1,0,0)).xyz,txNewTransform.Load(int3(2,0,0)).xyz)
#define gRainForceMask txSI.Load(int3(0,1,0)).w
#define gRainSiInertiaWorld txSI.Load(int3(0,1,0)).xyz
#define gRainSiAirWorld txSI.Load(int3(0,2,0)).xyz
#define gRainSiAirFraction txSI.Load(int3(0,2,0)).w
#define gRainSiRhoWater txSI.Load(int3(0,3,0)).x
#define gRainSiMu txSI.Load(int3(0,3,0)).y
#define gRainSiGamma txSI.Load(int3(0,3,0)).z
#define gRainSiRhoAir txSI.Load(int3(0,3,0)).w
#define gRainSiTheta txSI.Load(int3(0,4,0)).x
#define gRainSiStaticBare txSI.Load(int3(0,4,0)).y
#define gRainSiStaticCoat txSI.Load(int3(0,4,0)).z
#define gRainSiAttachedCd txSI.Load(int3(0,4,0)).w
#define gRainSiDynamicBare txSI.Load(int3(0,5,0)).x
#define gRainSiDynamicCoat txSI.Load(int3(0,5,0)).y
#define gRainSiViscousShape txSI.Load(int3(0,5,0)).z
#define gRainAirflowDownwardMode txSI.Load(int3(0,5,0)).w
#define gRainAirflowDownwardGain txSI.Load(int3(0,6,0)).x
#define gFilmGrid txHeader.Load(int3(0,4,0)).xy
#define gFilmPad txHeader.Load(int3(0,4,0)).z
#define gFilmCount gCount
#define gFilmTheta gRainSiTheta
#define gFilmMu gRainSiMu
#define gFilmGamma gRainSiGamma
#define gFilmDepositBare txSI.Load(int3(0,7,0)).x
#define gFilmDepositCoat txSI.Load(int3(0,7,0)).y
#define gFilmMinSpeedMS txSI.Load(int3(0,7,0)).z
#define gFilmWiden txSI.Load(int3(0,7,0)).w
#define gFilmEvapUMS txSI.Load(int3(0,8,0)).x
#define gFilmAirMS txSI.Load(int3(0,8,0)).y
#define gFilmDt txHeader.Load(int3(0,3,0)).w
#define gFilmMotionDt gFilmDt
#define gPoolOn 1
bool headContext(){
 bool ok=context()&&extraContext()&&dimensions(txSI,1,10)&&dimensions(txBirthReceipt,1,1)&&dimensions(txBirthHeader,1,5);
 [unroll]for(uint k=0;k<10u;k++)ok=ok&&all(isfinite(txSI.Load(int3(0,k,0))));
 float4 t=txHeader.Load(int3(0,0,0)),material=txSI.Load(int3(0,3,0)),angles=txSI.Load(int3(0,4,0)),dynamic=txSI.Load(int3(0,5,0));
 float4 mode=txSI.Load(int3(0,6,0)),film=txSI.Load(int3(0,7,0)),evap=txSI.Load(int3(0,8,0)),rev=txSI.Load(int3(0,9,0));
 float4 source=txBirthHeader.Load(int3(0,2,0)),shape=txBirthHeader.Load(int3(0,1,0));
 return ok&&all(txSI.Load(int3(0,0,0))==t)&&all(txBirthReceipt.Load(int3(0,0,0))==t)&&all(txBirthHeader.Load(int3(0,0,0))==t)&&
  all(txBirthHeader.Load(int3(0,4,0))==txHeader.Load(int3(0,1,0)))&&all(shape==float4(gFilmGrid,gFilmPad,gCount))&&source.y==txHeader.Load(int3(0,2,0)).y&&source.z==1&&source.w==1&&
  all(txBirthHeader.Load(int3(0,3,0))==float4(1,1,16,0))&&gRainForceMask>=0&&gRainForceMask<=7&&floor(gRainForceMask)==gRainForceMask&&
  gRainSiAirFraction>=0&&gRainSiAirFraction<=1&&material.x>0&&material.y>=0&&material.z>0&&material.w>=0&&
  angles.x==txMergeConfig.Load(int3(0,1,0)).x&&angles.x>0&&angles.x<180&&all(angles.yzw>=0)&&
  all(dynamic.xyz>=0)&&(dynamic.w==0||dynamic.w==1)&&mode.x>=0&&mode.y>0&&mode.y<=.05&&gFilmDt<=mode.y&&mode.z==1&&mode.w==0&&
  all(film>=0)&&all(evap.xy>=0)&&evap.z==1&&evap.w==0&&all(rev.xyz==txHeader.Load(int3(0,5,0)).xyz)&&rev.w==source.x;
}
// KN5 local metres / raw signed UV. Discrete reads avoid blending different
// island Jacobians. Source boundary alpha is authoritative; never wrap it.
float4 rainMetricTap(Texture2D tx, float2 uv) {
    uint w=1u,h=1u;tx.GetDimensions(w,h);
    return tx.Load(int3(clamp((int2)(uv*float2(w,h)),int2(0,0),int2(w-1,h-1)),0));
}
void rainMetric(float2 p,out float3 u,out float3 v) {
    float2 uv=float2(p.x,p.y+1);
    u=rainMetricTap(txRainDu,uv).xyz;v=rainMetricTap(txRainDv,uv).xyz;
}
float2 rainMetricProject(float2 p,float3 forceObject) {
    float3 u,v;rainMetric(p,u,v);
    float a=dot(u,u),b=dot(u,v),c=dot(v,v),det=max(a*c-b*b,1e-20);
    return float2(c*dot(u,forceObject)-b*dot(v,forceObject),
        a*dot(v,forceObject)-b*dot(u,forceObject))/det*gRainMetersPerUnit;
}
float3 rainMomentum(float2 p,float2 velocity) {
    float3 u,v;rainMetric(p,u,v);
    return (u*velocity.x+v*velocity.y)/gRainMetersPerUnit;
}
float rainMetricLength(float2 p,float2 delta) {
    float3 u,v;rainMetric(p,u,v);
    return length(u*delta.x+v*delta.y)/max(gRainMetersPerUnit,1e-8);
}
// Orthonormal physical plane, X along dP/dU. UV skew/scale retained exactly.
float2 rainMetricPlane(float2 p,float2 delta) {
    float3 u,v;rainMetric(p,u,v);
    float a=max(length(u),1e-9),b=dot(u/a,v),c=sqrt(max(dot(v,v)-b*b,1e-18));
    return float2(a*delta.x+b*delta.y,c*delta.y)/gRainMetersPerUnit;
}
float2 rainMetricOffset(float2 p,float2 plane) {
    float3 u,v;rainMetric(p,u,v);
    float a=max(length(u),1e-9),b=dot(u/a,v),c=sqrt(max(dot(v,v)-b*b,1e-18));
    float dv=plane.y*gRainMetersPerUnit/c;
    return float2((plane.x*gRainMetersPerUnit-b*dv)/a,dv);
}
float2 rainMetricExtent(float2 p,float radius) {
    float3 u,v;rainMetric(p,u,v);float a=dot(u,u),b=dot(u,v),c=dot(v,v);
    return radius*gRainMetersPerUnit*sqrt(float2(c,a)/max(a*c-b*b,1e-20));
}
float rainCoating(float2 p) {return rainMetricTap(txRainDv,float2(p.x,p.y+1)).a;}
float rainValid(float2 p) {
    float inside=all(p>=float2(0,-1))&&all(p<=float2(1,0)) ? 1 : 0;
    float alpha=rainMetricTap(txRainBoundaryMask,float2(p.x,p.y+1)).a;
    float support=saturate(rainMetricTap(txRainDu,float2(p.x,p.y+1)).a);
    return inside*alpha*support;
}
// Carry inertia through rotated/skewed triangle UV bases. A bounded adaptive
// step is at most 1 mm in the interior, and refines to half a source-mask
// texel at holes and atlas breaks. Excessive jumps die instead of wrapping.
float4 rainAdvance(float2 position,float2 velocity,float dt) {
    float remaining=max(dt,0);
    uint w=1u,h=1u;txRainBoundaryMask.GetDimensions(w,h);
    float2 maskSize=float2(w,h);
    float4 currentU=rainMetricTap(txRainDu,float2(position.x,position.y+1));
    float3 u=currentU.xyz,v=rainMetricTap(txRainDv,float2(position.x,position.y+1)).xyz;
    float speed=length(u*velocity.x+v*velocity.y)/max(gRainMetersPerUnit,1e-8);
    [loop] for(int step=0;step<128;++step) {
        if(remaining<=1e-7)break;
        if(speed<1e-9)break;
        float texelSpeed=max(abs(velocity.x)*maskSize.x,abs(velocity.y)*maskSize.y);
        float safe=currentU.a;
        float safePixels=max(.5,(safe-1)*.75);
        float h=min(remaining,min(safePixels/max(texelSpeed,1e-9),gRainReferencePerMM/max(speed,1e-9)));
        float2 next=position+velocity*h;
        if(any(next<float2(0,-1)) || any(next>float2(1,0)))return float4(2,2,0,0);
        float2 uv=float2(next.x,next.y+1);
        float4 nextU=rainMetricTap(txRainDu,uv);
        if(nextU.a<.5 || rainMetricTap(txRainBoundaryMask,uv).a<.5)return float4(2,2,0,0);
        float3 nextV=rainMetricTap(txRainDv,uv).xyz;
        float3 momentum=(u*velocity.x+v*velocity.y)/gRainMetersPerUnit;
        float a=dot(nextU.xyz,nextU.xyz),b=dot(nextU.xyz,nextV),c=dot(nextV,nextV);
        float det=max(a*c-b*b,1e-20);
        float mu=dot(nextU.xyz,momentum),mv=dot(nextV,momentum);
        float2 transported=float2(c*mu-b*mv,a*mv-b*mu)/det*gRainMetersPerUnit;
        float movedSpeed=length(nextU.xyz*transported.x+nextV*transported.y)/max(gRainMetersPerUnit,1e-8);
        velocity=movedSpeed>1e-9 ? transported*(speed/movedSpeed) : float2(0,0);
        position=next;remaining-=h;
        currentU=nextU;u=nextU.xyz;v=nextV;
        speed=length(u*velocity.x+v*velocity.y)/max(gRainMetersPerUnit,1e-8);
    }
    if(remaining>1e-7 && speed>1e-9)return float4(2,2,0,0);
    return float4(position,velocity);
}
// P1 shared physical primitives. Lengths/velocity/force use m, m/s, N;
// authoritative stored volume is mm^3. No display/texel/reference-size inputs.
// Reduced attached-drop model, not CFD. Material/contact/aero inputs are explicit.
float rainSiVolumeMM3(float equivalentDiameterMM) {
    float d=max(equivalentDiameterMM,0);
    return 0.523598775598299*d*d*d;
}
float rainSiEquivalentDiameterMM(float volumeMM3) {
    return pow(max(volumeMM3,0)*1.90985931710274,1.0/3.0);
}
float rainSiMassKG(float volumeMM3,float rhoWater) {
    return max(volumeMM3,0)*1e-9*max(rhoWater,0);
}
float rainSiContactRadiusMM(float volumeMM3,float thetaDeg) {
    // Valid material input angles are strictly between 0 and 180 degrees.
    float t=tan(clamp(thetaDeg,.1,179.9)*0.00872664625997165);
    return pow(max(volumeMM3,0)*1.90985931710274/(t*(3+t*t)),1.0/3.0);
}
float rainSiCapHeightMM(float radiusMM,float thetaDeg) {
    return max(radiusMM,0)*tan(clamp(thetaDeg,.1,179.9)*0.00872664625997165);
}
float rainSiPinningN(float widthMM,float thetaR,float thetaA,float gamma,float shapeK) {
    // cos(R)-cos(A) in a form stable for small hysteresis spans.
    float middle=(thetaR+thetaA)*0.00872664625997165;
    float halfSpan=(thetaA-thetaR)*0.00872664625997165;
    float hysteresis=max(2*sin(middle)*sin(halfSpan),0);
    return max(shapeK,0)*max(gamma,0)*max(widthMM,0)*.001*hysteresis;
}
float rainSiWeber(float equivalentDiameterMM,float normalImpactMS,float rhoWater,float gamma) {
    return max(rhoWater,0)*normalImpactMS*normalImpactMS*max(equivalentDiameterMM,0)*.001/max(gamma,1e-9);
}
float3 rainSiTangent(float3 v,float3 normal) {
    return v-normal*dot(v,normal);
}
float3 rainSiAirForceN(float3 relativeAirMS,float3 velocityMS,float3 normal,
    float contactRadiusMM,float capHeightMM,float rhoAir,float attachedCd) {
    float3 rel=relativeAirMS-velocityMS;
    float speed=length(rel);
    float a=max(contactRadiusMM,0)*.001;
    float h=max(capHeightMM,0)*.001;
    float incidence=speed>1e-9 ? saturate(abs(dot(rel,normal))/speed) : 0;
    // Projected cap-area approximation: grazing wind still has nonzero exposed area.
    // Caller supplies local surface air (including shielding), not a force gain.
    float area=lerp(2*a*h,3.141592653589793*a*a,incidence);
    return .5*max(rhoAir,0)*max(attachedCd,0)*area*speed*rel;
}
float3 rainSiIntegrateSlip(float3 velocityMS,float3 drivingForceN,float3 normal,
    float massKG,float staticPinN,float kineticPinN,float viscousKGPerS,float dt) {
    float3 v=rainSiTangent(velocityMS,normal);
    float3 force=rainSiTangent(drivingForceN,normal);
    float step=max(dt,0);
    if(massKG<=1e-16) return 0;
    if(step<=0) return v;
    // Numerical rest epsilon is in m/s. No diameter-based arbitrary speed cap.
    if(length(v)<=1e-7 && length(force)<=max(staticPinN,0)) return 0;
    float c=max(viscousKGPerS,0);
    float safeMass=max(massKG,1e-16);
    float x=c*step/safeMass;
    float decay=exp(-x);
    // Same exponential response, stable as x tends to zero.
    float phi1=x<.1 ? 1-x*.5+x*x/6-x*x*x/24+x*x*x*x/120-x*x*x*x*x/720 : (1-decay)/max(x,1e-30);
    float response=c>1e-16 ? step/safeMass*phi1 : step/safeMass;
    float3 freeV=v*decay+force*response;
    float speed=length(freeV);
    // Proximal dry-friction update cannot reverse velocity through zero.
    float remaining=max(speed-max(kineticPinN,0)*response,0);
    return freeV*(remaining/max(speed,1e-16));
}
float3 rainSiSlideWorld(float3 velocityMS,float3 gravityMS2,float3 inertiaMS2,
    float3 localAirMS,float3 normal,float volumeMM3,float theta,float thetaR,float thetaA,
    float dynamicThetaR,float dynamicThetaA,float rhoWater,float mu,float gamma,
    float rhoAir,float attachedCd,float shapeK,float viscousShape,float dt) {
    float radius=rainSiContactRadiusMM(volumeMM3,theta);
    float height=rainSiCapHeightMM(radius,theta);
    float mass=rainSiMassKG(volumeMM3,rhoWater);
    float3 drive=mass*(gravityMS2+inertiaMS2)
        +rainSiAirForceN(localAirMS,velocityMS,normal,radius,height,rhoAir,attachedCd);
    float staticPin=rainSiPinningN(2*radius,thetaR,thetaA,gamma,shapeK);
    float kineticPin=rainSiPinningN(2*radius,dynamicThetaR,dynamicThetaA,gamma,shapeK);
    float c=max(viscousShape,0)*max(mu,0)*2*radius*.001;
    return rainSiIntegrateSlip(velocityMS,drive,normal,mass,staticPin,kineticPin,c,dt);
}
float2 rainSiProjectUV(float3 duWorld,float3 dvWorld,float3 displacementM) {
    float a=dot(duWorld,duWorld),b=dot(duWorld,dvWorld),c=dot(dvWorld,dvWorld);
    float det=a*c-b*b;
    if(det<=1e-20) return 0; // Caller rejects an unsupported/degenerate surface.
    return float2(c*dot(duWorld,displacementM)-b*dot(dvWorld,displacementM),
        a*dot(dvWorld,displacementM)-b*dot(duWorld,displacementM))/max(det,1e-20);
}
float3 rainSiWorldVelocity(float3 duWorld,float3 dvWorld,float2 uvVelocity) {
    return duWorld*uvVelocity.x+dvWorld*uvVelocity.y;
}
float3 rainSiMergedVelocity(float3 a,float3 b,float volumeA,float volumeB) {
    float va=max(volumeA,0),vb=max(volumeB,0),total=va+vb;
    return (a*va+b*vb)/max(total,1e-16); // Same liquid density, no radius/display weights.
}
// Five rows: swept path, actual head transfers/support, incident source,
// source support, union bounds. Volumes are mm3; coordinates are field cells.
float2 pfSupport(float2 p,float radiusMM,out float capped) {
    float2 wanted=max(ceil(rainMetricExtent(p,radiusMM*gRainReferencePerMM)*gFilmGrid),1);
    capped=any(wanted>gFilmPad) ? 1 : 0;
    return min(wanted,gFilmPad);
}
float4 main(PS_IN pin) {
    uint i=min((uint)(pin.Tex.x*gFilmCount),(uint)gFilmCount-1u);
    uint row=min((uint)(pin.Tex.y*5),4u);
    float4 state=txFilmNewState.Load(int3(i,0,0)),meta=txFilmNewMeta.Load(int3(i,0,0));
    float4 oldState=txFilmOldState.Load(int3(i,0,0)),oldMeta=txFilmOldMeta.Load(int3(i,0,0));
    float status=meta.a-4*floor(meta.a*.25),oldStatus=oldMeta.a-4*floor(oldMeta.a*.25);
    float4 path=0,transfer=0,incident=0,support=0;
    float2 low=1e9,high=-1e9;
    if(status==1 && meta.g>0 && rainValid(state.rg)>=.5) {
        // The provisional SI meta already derives this radius at the current
        // contact angle. Avoid repeating a cube root in all five rows.
        float radiusMM=max(meta.r,0)/max(gRainReferencePerMM,1e-12);
        float heightMM=rainSiCapHeightMM(radiusMM,gFilmTheta);
        float trailCandidate=0;
        bool same=oldStatus==1 && floor(oldMeta.a*.25)==floor(meta.a*.25)
            && rainValid(oldState.rg)>=.5 && meta.g<=oldMeta.g*(1+1e-6);
        if(same && gFilmMotionDt>0) {
            float2 delta=state.rg-oldState.rg;
            float distanceMM=rainMetricLength(oldState.rg,delta)/gRainReferencePerMM;
            float speedMS=distanceMM*.001/gFilmMotionDt;
            if(distanceMM>1e-6 && speedMS>gFilmMinSpeedMS) {
                float coat=saturate(rainCoating(state.rg));
                float shear=saturate(gFilmAirMS/30);
                float widthMM=2*radiusMM*(1+gFilmWiden*shear);
                float ca=gFilmMu*speedMS/max(gFilmGamma,1e-9);
                float hMM=lerp(gFilmDepositBare,gFilmDepositCoat,coat)*radiusMM*pow(max(ca,0),2.0/3.0)
                    *(1-.6*smoothstep(.5,1,shear));
                trailCandidate=min(meta.g,max(hMM*widthMM*distanceMM,0));
                float capped=0;float2 kernel=pfSupport(state.rg,widthMM*.5,capped);
                path=float4(float2(oldState.x,oldState.y+1)*gFilmGrid+gFilmPad-.5,
                            float2(state.x,state.y+1)*gFilmGrid+gFilmPad-.5);
                transfer.yz=kernel;support.z=capped;
            }
        }
        // Store the transfer the float32 head can actually lose, not an
        // arbitrarily smaller requested loss that rounds away in the head.
        precise float remaining=meta.g-trailCandidate;
        transfer.x=meta.g-remaining;
        float evapCandidate=min(remaining,3.141592653589793*(radiusMM*radiusMM+heightMM*heightMM)
            *gFilmEvapUMS*.001*gFilmDt);
        precise float afterEvap=remaining-evapCandidate;
        transfer.w=remaining-afterEvap;
        if(transfer.x>0) {low=min(path.xy,path.zw)-transfer.yz;high=max(path.xy,path.zw)+transfer.yz;}
    }
    float4 source=txFilmBirthEvent.Load(int3(i,0,0));
    float4 allocation=txFilmBirthEvent.Load(int3(i,2,0)),ledger=txFilmBirthEvent.Load(int3(i,3,0));
    float film=max(allocation.y,0)+max(ledger.x,0),micro=max(allocation.z,0);
    if(film+micro>0) {
        float2 p=gPoolOn>.5 ? txFilmBirthEvent.Load(int3(i,4,0)).xy : source.xy;
        incident=float4(float2(p.x,p.y+1)*gFilmGrid+gFilmPad-.5,film,micro);
        float beta=max(txFilmBirthEvent.Load(int3(i,1,0)).z,1);
        float radiusMM=rainSiContactRadiusMM(max(allocation.x,0),gFilmTheta)*beta;
        float capped=0;support.xy=pfSupport(p,radiusMM,capped);support.z=max(support.z,capped);
        low=min(low,incident.xy-support.xy);high=max(high,incident.xy+support.xy);
    }
    if(row==0u)return path;
    if(row==1u)return transfer;
    if(row==2u)return incident;
    if(row==3u)return support;
    return float4(low,high);
}
]====]
M.export=[====[
// All exports are diagnostic candidates. No publication or source consumption.
float4 main(PS_IN pin){
 float4 result=0;bool ready=txDecision.Load(int3(0,0,0)).r==0;
 if(ready){
  if(gReceipt>1.5){uint i=min((uint)(pin.Tex.x*gCount),(uint)gCount-1);result=txDecoded.Load(int3(i,2,0));}
  else if(gReceipt>.5)result=txHeader.Load(int3(0,0,0));
  else {uint2 p=min((uint2)(pin.Tex*float2(gCount,20)),uint2((uint)gCount-1,19));result=txDecoded.Load(int3(p,0));}
 }
 return result;
}
]====]
M.filmMeta=[====[
// Actual P1/P2/P3 channel adapter. No display radius enters a physical packet.
bool integerValue(float x){return isfinite(x)&&x>=0&&x<=16777215&&floor(x)==x;}
bool inside(float2 p){return all(p>=float2(0,-1))&&all(p<=float2(1,0));}
bool dimensions(Texture2D<float4> t,uint w,uint h){uint a,b;t.GetDimensions(a,b);return a==w&&b==h;}
bool context(){
 float4 token=txHeader.Load(int3(0,0,0)),previous=txHeader.Load(int3(0,1,0));
 float4 frames=txHeader.Load(int3(0,2,0)),mode=txHeader.Load(int3(0,3,0));
 float4 field=txHeader.Load(int3(0,4,0)),revision=txHeader.Load(int3(0,5,0));
 bool ok=all(isfinite(token))&&all(isfinite(previous))&&all(isfinite(frames))&&all(isfinite(mode))&&all(isfinite(field))&&all(isfinite(revision));
 ok=ok&&integerValue(token.x)&&token.x>0&&integerValue(token.y)&&token.y>0&&integerValue(token.z)&&token.z>0&&token.w==1;
 ok=ok&&all(previous.xy==token.xy)&&previous.z+1==token.z&&previous.w==1;
 ok=ok&&integerValue(frames.x)&&integerValue(frames.y)&&frames.y>frames.x&&frames.z==frames.y&&frames.w==frames.y;
 ok=ok&&all(mode.xyz==1)&&mode.w>0&&mode.w<=.05;
 ok=ok&&integerValue(field.x)&&field.x>0&&integerValue(field.y)&&field.y>0&&integerValue(field.z)&&field.z>=1&&field.z<=16&&field.w==5;
 ok=ok&&integerValue(revision.x)&&revision.x>0&&integerValue(revision.y)&&revision.y>0&&integerValue(revision.z)&&revision.z>0&&revision.w==1;
 ok=ok&&dimensions(txHeader,1,6)&&dimensions(txOldState,(uint)gCount,1)&&dimensions(txOldMeta,(uint)gCount,1);
 ok=ok&&dimensions(txNewState,(uint)gCount,1)&&dimensions(txPreMeta,(uint)gCount,1)&&dimensions(txFinalMeta,(uint)gCount,1);
 ok=ok&&dimensions(txEvents,(uint)gCount,5)&&dimensions(txDescriptors,(uint)gCount,5);
 uint w,h;txDu.GetDimensions(w,h);ok=ok&&w>0&&h>0&&dimensions(txDv,w,h)&&dimensions(txBoundary,w,h);
 ok=ok&&dimensions(txOldTransform,3,1)&&dimensions(txNewTransform,3,1);
 float3 a=txOldTransform.Load(int3(0,0,0)).xyz,b=txOldTransform.Load(int3(1,0,0)).xyz,c=txOldTransform.Load(int3(2,0,0)).xyz;
 float3 d=txNewTransform.Load(int3(0,0,0)).xyz,e=txNewTransform.Load(int3(1,0,0)).xyz,f=txNewTransform.Load(int3(2,0,0)).xyz;
 float oldDet=dot(a,cross(b,c)),newDet=dot(d,cross(e,f));
 return ok&&all(isfinite(a))&&all(isfinite(b))&&all(isfinite(c))&&all(isfinite(d))&&all(isfinite(e))&&all(isfinite(f))&&isfinite(oldDet)&&isfinite(newDet)&&abs(oldDet)>1e-20&&abs(newDet)>1e-20;
}
int2 metricCell(float2 p){uint w,h;txDu.GetDimensions(w,h);return clamp((int2)(float2(p.x,p.y+1)*float2(w,h)),int2(0,0),int2(w-1,h-1));}
bool supported(float2 p){int2 c=metricCell(p);return inside(p)&&txDu.Load(int3(c,0)).w>=.5&&txBoundary.Load(int3(c,0)).w>=.5;}
float3 transformVector(float3 p,bool old){
 float3 a=0,b=0,c=0;
 if(old){a=txOldTransform.Load(int3(0,0,0)).xyz;b=txOldTransform.Load(int3(1,0,0)).xyz;c=txOldTransform.Load(int3(2,0,0)).xyz;}
 else{a=txNewTransform.Load(int3(0,0,0)).xyz;b=txNewTransform.Load(int3(1,0,0)).xyz;c=txNewTransform.Load(int3(2,0,0)).xyz;}
 return p.x*a+p.y*b+p.z*c;
}
bool velocity(float4 s,bool old,out float3 v){
 int2 p=metricCell(s.xy);float3 u=transformVector(txDu.Load(int3(p,0)).xyz,old),w=transformVector(txDv.Load(int3(p,0)).xyz,old);
 v=u*s.z+w*s.w;
 float3 normal=cross(u,w);float norm2=dot(normal,normal);
 return all(isfinite(u))&&all(isfinite(w))&&all(isfinite(v))&&all(isfinite(normal))&&isfinite(norm2)&&norm2>1e-20;
}
float generation(float4 m){return floor(m.a*.25);}
float life(float4 m){return m.a-4*generation(m);}
bool metaValid(float4 m){return all(isfinite(m))&&all(m.rgb>=0)&&integerValue(m.a)&&generation(m)<4096&&(life(m)==0||life(m)==1)&&((life(m)==0&&m.g==0)||(life(m)==1&&m.g>0));}
float4 packet(float volume,float3 v){return float4(volume,volume*v);}
bool supportSize(float2 p,float pad){return all(isfinite(p))&&all(p>=1)&&all(p<=pad)&&all(floor(p)==p);}
// A frozen command creator supplies full generations, not reconstructed low bits.
bool extraContext(){
 float4 a=txMergeConfig.Load(int3(0,0,0)),b=txMergeConfig.Load(int3(0,1,0)),c=txMergeConfig.Load(int3(0,2,0));
 float4 token=txHeader.Load(int3(0,0,0));float4 frames=txHeader.Load(int3(0,2,0));
 bool ok=dimensions(txMergeCommand,(uint)gCount,1)&&dimensions(txMergeGeneration,(uint)gCount,1)&&dimensions(txMergeConfig,1,3)&&dimensions(txPostForce,(uint)gCount,1);
 ok=ok&&all(a==token)&&all(isfinite(b))&&all(isfinite(c))&&b.x>0&&b.x<180&&b.y>0&&integerValue(b.z)&&b.z<=frames.x&&frames.x-b.z<4096&&b.w==1;
 ok=ok&&c.x>0&&c.y>0&&c.z==txHeader.Load(int3(0,3,0)).w&&c.w==1;
 // Original transport uses a reference unit. Its product must still mean 1 mm
 // after the physical scale. Neither value is the display-diameter gain.
 float3 x=txNewTransform.Load(int3(0,0,0)).xyz,y=txNewTransform.Load(int3(1,0,0)).xyz,z=txNewTransform.Load(int3(2,0,0)).xyz;
 float scale=length(x);float tol=max(scale*scale*32*1.1920928955078125e-7,1e-12);
 ok=ok&&isfinite(scale)&&scale>0&&abs(dot(y,y)-scale*scale)<=tol&&abs(dot(z,z)-scale*scale)<=tol;
 ok=ok&&abs(dot(x,y))<=tol&&abs(dot(x,z))<=tol&&abs(dot(y,z))<=tol;
 return ok&&isfinite(c.x*c.y*scale)&&abs(c.x*c.y*scale-.001)<=.001*32*1.1920928955078125e-7;
}
float3 worldAt(float2 p,float2 uv,bool old){float4 s=float4(p,uv);float3 v=0;velocity(s,old,v);return v;}
float2 projectAt(float2 p,float3 m){
 int2 q=metricCell(p);float3 u=transformVector(txDu.Load(int3(q,0)).xyz,false),v=transformVector(txDv.Load(int3(q,0)).xyz,false);
 float a=dot(u,u),b=dot(u,v),c=dot(v,v),det=a*c-b*b;
 return float2(c*dot(u,m)-b*dot(v,m),a*dot(v,m)-b*dot(u,m))/max(det,1e-20);
}
bool commandBytes(float4 c,out uint4 b){
 b=(uint4)floor(saturate(c)*255+.5);
 return all(isfinite(c))&&all(c>=0)&&all(c<=1)&&all(abs(c*255-(float4)b)<=255*4*1.1920928955078125e-7);
}
#define txRainDu txDu
#define txRainDv txDv
#define txRainBoundaryMask txBoundary
#define gRainMetersPerUnit txMergeConfig.Load(int3(0,2,0)).x
#define gRainReferencePerMM txMergeConfig.Load(int3(0,2,0)).y
#define gRainObjectToWorld float3x3(txNewTransform.Load(int3(0,0,0)).xyz,txNewTransform.Load(int3(1,0,0)).xyz,txNewTransform.Load(int3(2,0,0)).xyz)
#define gRainForceMask txSI.Load(int3(0,1,0)).w
#define gRainSiInertiaWorld txSI.Load(int3(0,1,0)).xyz
#define gRainSiAirWorld txSI.Load(int3(0,2,0)).xyz
#define gRainSiAirFraction txSI.Load(int3(0,2,0)).w
#define gRainSiRhoWater txSI.Load(int3(0,3,0)).x
#define gRainSiMu txSI.Load(int3(0,3,0)).y
#define gRainSiGamma txSI.Load(int3(0,3,0)).z
#define gRainSiRhoAir txSI.Load(int3(0,3,0)).w
#define gRainSiTheta txSI.Load(int3(0,4,0)).x
#define gRainSiStaticBare txSI.Load(int3(0,4,0)).y
#define gRainSiStaticCoat txSI.Load(int3(0,4,0)).z
#define gRainSiAttachedCd txSI.Load(int3(0,4,0)).w
#define gRainSiDynamicBare txSI.Load(int3(0,5,0)).x
#define gRainSiDynamicCoat txSI.Load(int3(0,5,0)).y
#define gRainSiViscousShape txSI.Load(int3(0,5,0)).z
#define gRainAirflowDownwardMode txSI.Load(int3(0,5,0)).w
#define gRainAirflowDownwardGain txSI.Load(int3(0,6,0)).x
#define gFilmGrid txHeader.Load(int3(0,4,0)).xy
#define gFilmPad txHeader.Load(int3(0,4,0)).z
#define gFilmCount gCount
#define gFilmTheta gRainSiTheta
#define gFilmMu gRainSiMu
#define gFilmGamma gRainSiGamma
#define gFilmDepositBare txSI.Load(int3(0,7,0)).x
#define gFilmDepositCoat txSI.Load(int3(0,7,0)).y
#define gFilmMinSpeedMS txSI.Load(int3(0,7,0)).z
#define gFilmWiden txSI.Load(int3(0,7,0)).w
#define gFilmEvapUMS txSI.Load(int3(0,8,0)).x
#define gFilmAirMS txSI.Load(int3(0,8,0)).y
#define gFilmDt txHeader.Load(int3(0,3,0)).w
#define gFilmMotionDt gFilmDt
#define gPoolOn 1
bool headContext(){
 bool ok=context()&&extraContext()&&dimensions(txSI,1,10)&&dimensions(txBirthReceipt,1,1)&&dimensions(txBirthHeader,1,5);
 [unroll]for(uint k=0;k<10u;k++)ok=ok&&all(isfinite(txSI.Load(int3(0,k,0))));
 float4 t=txHeader.Load(int3(0,0,0)),material=txSI.Load(int3(0,3,0)),angles=txSI.Load(int3(0,4,0)),dynamic=txSI.Load(int3(0,5,0));
 float4 mode=txSI.Load(int3(0,6,0)),film=txSI.Load(int3(0,7,0)),evap=txSI.Load(int3(0,8,0)),rev=txSI.Load(int3(0,9,0));
 float4 source=txBirthHeader.Load(int3(0,2,0)),shape=txBirthHeader.Load(int3(0,1,0));
 return ok&&all(txSI.Load(int3(0,0,0))==t)&&all(txBirthReceipt.Load(int3(0,0,0))==t)&&all(txBirthHeader.Load(int3(0,0,0))==t)&&
  all(txBirthHeader.Load(int3(0,4,0))==txHeader.Load(int3(0,1,0)))&&all(shape==float4(gFilmGrid,gFilmPad,gCount))&&source.y==txHeader.Load(int3(0,2,0)).y&&source.z==1&&source.w==1&&
  all(txBirthHeader.Load(int3(0,3,0))==float4(1,1,16,0))&&gRainForceMask>=0&&gRainForceMask<=7&&floor(gRainForceMask)==gRainForceMask&&
  gRainSiAirFraction>=0&&gRainSiAirFraction<=1&&material.x>0&&material.y>=0&&material.z>0&&material.w>=0&&
  angles.x==txMergeConfig.Load(int3(0,1,0)).x&&angles.x>0&&angles.x<180&&all(angles.yzw>=0)&&
  all(dynamic.xyz>=0)&&(dynamic.w==0||dynamic.w==1)&&mode.x>=0&&mode.y>0&&mode.y<=.05&&gFilmDt<=mode.y&&mode.z==1&&mode.w==0&&
  all(film>=0)&&all(evap.xy>=0)&&evap.z==1&&evap.w==0&&all(rev.xyz==txHeader.Load(int3(0,5,0)).xyz)&&rev.w==source.x;
}
// P1 shared physical primitives. Lengths/velocity/force use m, m/s, N;
// authoritative stored volume is mm^3. No display/texel/reference-size inputs.
// Reduced attached-drop model, not CFD. Material/contact/aero inputs are explicit.
float rainSiVolumeMM3(float equivalentDiameterMM) {
    float d=max(equivalentDiameterMM,0);
    return 0.523598775598299*d*d*d;
}
float rainSiEquivalentDiameterMM(float volumeMM3) {
    return pow(max(volumeMM3,0)*1.90985931710274,1.0/3.0);
}
float rainSiMassKG(float volumeMM3,float rhoWater) {
    return max(volumeMM3,0)*1e-9*max(rhoWater,0);
}
float rainSiContactRadiusMM(float volumeMM3,float thetaDeg) {
    // Valid material input angles are strictly between 0 and 180 degrees.
    float t=tan(clamp(thetaDeg,.1,179.9)*0.00872664625997165);
    return pow(max(volumeMM3,0)*1.90985931710274/(t*(3+t*t)),1.0/3.0);
}
float rainSiCapHeightMM(float radiusMM,float thetaDeg) {
    return max(radiusMM,0)*tan(clamp(thetaDeg,.1,179.9)*0.00872664625997165);
}
float rainSiPinningN(float widthMM,float thetaR,float thetaA,float gamma,float shapeK) {
    // cos(R)-cos(A) in a form stable for small hysteresis spans.
    float middle=(thetaR+thetaA)*0.00872664625997165;
    float halfSpan=(thetaA-thetaR)*0.00872664625997165;
    float hysteresis=max(2*sin(middle)*sin(halfSpan),0);
    return max(shapeK,0)*max(gamma,0)*max(widthMM,0)*.001*hysteresis;
}
float rainSiWeber(float equivalentDiameterMM,float normalImpactMS,float rhoWater,float gamma) {
    return max(rhoWater,0)*normalImpactMS*normalImpactMS*max(equivalentDiameterMM,0)*.001/max(gamma,1e-9);
}
float3 rainSiTangent(float3 v,float3 normal) {
    return v-normal*dot(v,normal);
}
float3 rainSiAirForceN(float3 relativeAirMS,float3 velocityMS,float3 normal,
    float contactRadiusMM,float capHeightMM,float rhoAir,float attachedCd) {
    float3 rel=relativeAirMS-velocityMS;
    float speed=length(rel);
    float a=max(contactRadiusMM,0)*.001;
    float h=max(capHeightMM,0)*.001;
    float incidence=speed>1e-9 ? saturate(abs(dot(rel,normal))/speed) : 0;
    // Projected cap-area approximation: grazing wind still has nonzero exposed area.
    // Caller supplies local surface air (including shielding), not a force gain.
    float area=lerp(2*a*h,3.141592653589793*a*a,incidence);
    return .5*max(rhoAir,0)*max(attachedCd,0)*area*speed*rel;
}
float3 rainSiIntegrateSlip(float3 velocityMS,float3 drivingForceN,float3 normal,
    float massKG,float staticPinN,float kineticPinN,float viscousKGPerS,float dt) {
    float3 v=rainSiTangent(velocityMS,normal);
    float3 force=rainSiTangent(drivingForceN,normal);
    float step=max(dt,0);
    if(massKG<=1e-16) return 0;
    if(step<=0) return v;
    // Numerical rest epsilon is in m/s. No diameter-based arbitrary speed cap.
    if(length(v)<=1e-7 && length(force)<=max(staticPinN,0)) return 0;
    float c=max(viscousKGPerS,0);
    float safeMass=max(massKG,1e-16);
    float x=c*step/safeMass;
    float decay=exp(-x);
    // Same exponential response, stable as x tends to zero.
    float phi1=x<.1 ? 1-x*.5+x*x/6-x*x*x/24+x*x*x*x/120-x*x*x*x*x/720 : (1-decay)/max(x,1e-30);
    float response=c>1e-16 ? step/safeMass*phi1 : step/safeMass;
    float3 freeV=v*decay+force*response;
    float speed=length(freeV);
    // Proximal dry-friction update cannot reverse velocity through zero.
    float remaining=max(speed-max(kineticPinN,0)*response,0);
    return freeV*(remaining/max(speed,1e-16));
}
float3 rainSiSlideWorld(float3 velocityMS,float3 gravityMS2,float3 inertiaMS2,
    float3 localAirMS,float3 normal,float volumeMM3,float theta,float thetaR,float thetaA,
    float dynamicThetaR,float dynamicThetaA,float rhoWater,float mu,float gamma,
    float rhoAir,float attachedCd,float shapeK,float viscousShape,float dt) {
    float radius=rainSiContactRadiusMM(volumeMM3,theta);
    float height=rainSiCapHeightMM(radius,theta);
    float mass=rainSiMassKG(volumeMM3,rhoWater);
    float3 drive=mass*(gravityMS2+inertiaMS2)
        +rainSiAirForceN(localAirMS,velocityMS,normal,radius,height,rhoAir,attachedCd);
    float staticPin=rainSiPinningN(2*radius,thetaR,thetaA,gamma,shapeK);
    float kineticPin=rainSiPinningN(2*radius,dynamicThetaR,dynamicThetaA,gamma,shapeK);
    float c=max(viscousShape,0)*max(mu,0)*2*radius*.001;
    return rainSiIntegrateSlip(velocityMS,drive,normal,mass,staticPin,kineticPin,c,dt);
}
float2 rainSiProjectUV(float3 duWorld,float3 dvWorld,float3 displacementM) {
    float a=dot(duWorld,duWorld),b=dot(duWorld,dvWorld),c=dot(dvWorld,dvWorld);
    float det=a*c-b*b;
    if(det<=1e-20) return 0; // Caller rejects an unsupported/degenerate surface.
    return float2(c*dot(duWorld,displacementM)-b*dot(dvWorld,displacementM),
        a*dot(dvWorld,displacementM)-b*dot(duWorld,displacementM))/max(det,1e-20);
}
float3 rainSiWorldVelocity(float3 duWorld,float3 dvWorld,float2 uvVelocity) {
    return duWorld*uvVelocity.x+dvWorld*uvVelocity.y;
}
float3 rainSiMergedVelocity(float3 a,float3 b,float volumeA,float volumeB) {
    float va=max(volumeA,0),vb=max(volumeB,0),total=va+vb;
    return (a*va+b*vb)/max(total,1e-16); // Same liquid density, no radius/display weights.
}
float4 main(PS_IN pin) {
    uint i=min((uint)(pin.Tex.x*gFilmCount),(uint)gFilmCount-1u);
    float4 meta=txFilmNewMeta.Load(int3(i,0,0)),transfer=txFilmDescriptors.Load(int3(i,1,0));
    if(meta.a-4*floor(meta.a*.25)==1 && transfer.x+transfer.w>0) {
        precise float remaining=max(meta.g-transfer.x,0);
        meta.g=max(remaining-transfer.w,0);
        meta.r=rainSiContactRadiusMM(meta.g,gFilmTheta)*gRainReferencePerMM;
        if(meta.g<=0) {meta.r=0;meta.b=0;meta.a=4*floor(meta.a*.25);}
    }
    return meta;
}
]====]
M.merge=[====[
// Actual P1/P2/P3 channel adapter. No display radius enters a physical packet.
bool integerValue(float x){return isfinite(x)&&x>=0&&x<=16777215&&floor(x)==x;}
bool inside(float2 p){return all(p>=float2(0,-1))&&all(p<=float2(1,0));}
bool dimensions(Texture2D<float4> t,uint w,uint h){uint a,b;t.GetDimensions(a,b);return a==w&&b==h;}
bool context(){
 float4 token=txHeader.Load(int3(0,0,0)),previous=txHeader.Load(int3(0,1,0));
 float4 frames=txHeader.Load(int3(0,2,0)),mode=txHeader.Load(int3(0,3,0));
 float4 field=txHeader.Load(int3(0,4,0)),revision=txHeader.Load(int3(0,5,0));
 bool ok=all(isfinite(token))&&all(isfinite(previous))&&all(isfinite(frames))&&all(isfinite(mode))&&all(isfinite(field))&&all(isfinite(revision));
 ok=ok&&integerValue(token.x)&&token.x>0&&integerValue(token.y)&&token.y>0&&integerValue(token.z)&&token.z>0&&token.w==1;
 ok=ok&&all(previous.xy==token.xy)&&previous.z+1==token.z&&previous.w==1;
 ok=ok&&integerValue(frames.x)&&integerValue(frames.y)&&frames.y>frames.x&&frames.z==frames.y&&frames.w==frames.y;
 ok=ok&&all(mode.xyz==1)&&mode.w>0&&mode.w<=.05;
 ok=ok&&integerValue(field.x)&&field.x>0&&integerValue(field.y)&&field.y>0&&integerValue(field.z)&&field.z>=1&&field.z<=16&&field.w==5;
 ok=ok&&integerValue(revision.x)&&revision.x>0&&integerValue(revision.y)&&revision.y>0&&integerValue(revision.z)&&revision.z>0&&revision.w==1;
 ok=ok&&dimensions(txHeader,1,6)&&dimensions(txOldState,(uint)gCount,1)&&dimensions(txOldMeta,(uint)gCount,1);
 ok=ok&&dimensions(txNewState,(uint)gCount,1)&&dimensions(txPreMeta,(uint)gCount,1)&&dimensions(txFinalMeta,(uint)gCount,1);
 ok=ok&&dimensions(txEvents,(uint)gCount,5)&&dimensions(txDescriptors,(uint)gCount,5);
 uint w,h;txDu.GetDimensions(w,h);ok=ok&&w>0&&h>0&&dimensions(txDv,w,h)&&dimensions(txBoundary,w,h);
 ok=ok&&dimensions(txOldTransform,3,1)&&dimensions(txNewTransform,3,1);
 float3 a=txOldTransform.Load(int3(0,0,0)).xyz,b=txOldTransform.Load(int3(1,0,0)).xyz,c=txOldTransform.Load(int3(2,0,0)).xyz;
 float3 d=txNewTransform.Load(int3(0,0,0)).xyz,e=txNewTransform.Load(int3(1,0,0)).xyz,f=txNewTransform.Load(int3(2,0,0)).xyz;
 float oldDet=dot(a,cross(b,c)),newDet=dot(d,cross(e,f));
 return ok&&all(isfinite(a))&&all(isfinite(b))&&all(isfinite(c))&&all(isfinite(d))&&all(isfinite(e))&&all(isfinite(f))&&isfinite(oldDet)&&isfinite(newDet)&&abs(oldDet)>1e-20&&abs(newDet)>1e-20;
}
int2 metricCell(float2 p){uint w,h;txDu.GetDimensions(w,h);return clamp((int2)(float2(p.x,p.y+1)*float2(w,h)),int2(0,0),int2(w-1,h-1));}
bool supported(float2 p){int2 c=metricCell(p);return inside(p)&&txDu.Load(int3(c,0)).w>=.5&&txBoundary.Load(int3(c,0)).w>=.5;}
float3 transformVector(float3 p,bool old){
 float3 a=0,b=0,c=0;
 if(old){a=txOldTransform.Load(int3(0,0,0)).xyz;b=txOldTransform.Load(int3(1,0,0)).xyz;c=txOldTransform.Load(int3(2,0,0)).xyz;}
 else{a=txNewTransform.Load(int3(0,0,0)).xyz;b=txNewTransform.Load(int3(1,0,0)).xyz;c=txNewTransform.Load(int3(2,0,0)).xyz;}
 return p.x*a+p.y*b+p.z*c;
}
bool velocity(float4 s,bool old,out float3 v){
 int2 p=metricCell(s.xy);float3 u=transformVector(txDu.Load(int3(p,0)).xyz,old),w=transformVector(txDv.Load(int3(p,0)).xyz,old);
 v=u*s.z+w*s.w;
 float3 normal=cross(u,w);float norm2=dot(normal,normal);
 return all(isfinite(u))&&all(isfinite(w))&&all(isfinite(v))&&all(isfinite(normal))&&isfinite(norm2)&&norm2>1e-20;
}
float generation(float4 m){return floor(m.a*.25);}
float life(float4 m){return m.a-4*generation(m);}
bool metaValid(float4 m){return all(isfinite(m))&&all(m.rgb>=0)&&integerValue(m.a)&&generation(m)<4096&&(life(m)==0||life(m)==1)&&((life(m)==0&&m.g==0)||(life(m)==1&&m.g>0));}
float4 packet(float volume,float3 v){return float4(volume,volume*v);}
bool supportSize(float2 p,float pad){return all(isfinite(p))&&all(p>=1)&&all(p<=pad)&&all(floor(p)==p);}
// A frozen command creator supplies full generations, not reconstructed low bits.
bool extraContext(){
 float4 a=txMergeConfig.Load(int3(0,0,0)),b=txMergeConfig.Load(int3(0,1,0)),c=txMergeConfig.Load(int3(0,2,0));
 float4 token=txHeader.Load(int3(0,0,0));float4 frames=txHeader.Load(int3(0,2,0));
 bool ok=dimensions(txMergeCommand,(uint)gCount,1)&&dimensions(txMergeGeneration,(uint)gCount,1)&&dimensions(txMergeConfig,1,3)&&dimensions(txPostForce,(uint)gCount,1);
 ok=ok&&all(a==token)&&all(isfinite(b))&&all(isfinite(c))&&b.x>0&&b.x<180&&b.y>0&&integerValue(b.z)&&b.z<=frames.x&&frames.x-b.z<4096&&b.w==1;
 ok=ok&&c.x>0&&c.y>0&&c.z==txHeader.Load(int3(0,3,0)).w&&c.w==1;
 // Original transport uses a reference unit. Its product must still mean 1 mm
 // after the physical scale. Neither value is the display-diameter gain.
 float3 x=txNewTransform.Load(int3(0,0,0)).xyz,y=txNewTransform.Load(int3(1,0,0)).xyz,z=txNewTransform.Load(int3(2,0,0)).xyz;
 float scale=length(x);float tol=max(scale*scale*32*1.1920928955078125e-7,1e-12);
 ok=ok&&isfinite(scale)&&scale>0&&abs(dot(y,y)-scale*scale)<=tol&&abs(dot(z,z)-scale*scale)<=tol;
 ok=ok&&abs(dot(x,y))<=tol&&abs(dot(x,z))<=tol&&abs(dot(y,z))<=tol;
 return ok&&isfinite(c.x*c.y*scale)&&abs(c.x*c.y*scale-.001)<=.001*32*1.1920928955078125e-7;
}
float3 worldAt(float2 p,float2 uv,bool old){float4 s=float4(p,uv);float3 v=0;velocity(s,old,v);return v;}
float2 projectAt(float2 p,float3 m){
 int2 q=metricCell(p);float3 u=transformVector(txDu.Load(int3(q,0)).xyz,false),v=transformVector(txDv.Load(int3(q,0)).xyz,false);
 float a=dot(u,u),b=dot(u,v),c=dot(v,v),det=a*c-b*b;
 return float2(c*dot(u,m)-b*dot(v,m),a*dot(v,m)-b*dot(u,m))/max(det,1e-20);
}
bool commandBytes(float4 c,out uint4 b){
 b=(uint4)floor(saturate(c)*255+.5);
 return all(isfinite(c))&&all(c>=0)&&all(c<=1)&&all(abs(c*255-(float4)b)<=255*4*1.1920928955078125e-7);
}
// P1 shared physical primitives. Lengths/velocity/force use m, m/s, N;
// authoritative stored volume is mm^3. No display/texel/reference-size inputs.
// Reduced attached-drop model, not CFD. Material/contact/aero inputs are explicit.
float rainSiVolumeMM3(float equivalentDiameterMM) {
    float d=max(equivalentDiameterMM,0);
    return 0.523598775598299*d*d*d;
}
float rainSiEquivalentDiameterMM(float volumeMM3) {
    return pow(max(volumeMM3,0)*1.90985931710274,1.0/3.0);
}
float rainSiMassKG(float volumeMM3,float rhoWater) {
    return max(volumeMM3,0)*1e-9*max(rhoWater,0);
}
float rainSiContactRadiusMM(float volumeMM3,float thetaDeg) {
    // Valid material input angles are strictly between 0 and 180 degrees.
    float t=tan(clamp(thetaDeg,.1,179.9)*0.00872664625997165);
    return pow(max(volumeMM3,0)*1.90985931710274/(t*(3+t*t)),1.0/3.0);
}
float rainSiCapHeightMM(float radiusMM,float thetaDeg) {
    return max(radiusMM,0)*tan(clamp(thetaDeg,.1,179.9)*0.00872664625997165);
}
float rainSiPinningN(float widthMM,float thetaR,float thetaA,float gamma,float shapeK) {
    float hysteresis=max(cos(thetaR*0.0174532925199433)-cos(thetaA*0.0174532925199433),0);
    return max(shapeK,0)*max(gamma,0)*max(widthMM,0)*.001*hysteresis;
}
float rainSiWeber(float equivalentDiameterMM,float normalImpactMS,float rhoWater,float gamma) {
    return max(rhoWater,0)*normalImpactMS*normalImpactMS*max(equivalentDiameterMM,0)*.001/max(gamma,1e-9);
}
float3 rainSiTangent(float3 v,float3 normal) {
    return v-normal*dot(v,normal);
}
float3 rainSiAirForceN(float3 relativeAirMS,float3 velocityMS,float3 normal,
    float contactRadiusMM,float capHeightMM,float rhoAir,float attachedCd) {
    float3 rel=relativeAirMS-velocityMS;
    float speed=length(rel);
    float a=max(contactRadiusMM,0)*.001;
    float h=max(capHeightMM,0)*.001;
    float incidence=speed>1e-9 ? saturate(abs(dot(rel,normal))/speed) : 0;
    // Projected cap-area approximation: grazing wind still has nonzero exposed area.
    // Caller supplies local surface air (including shielding), not a force gain.
    float area=lerp(2*a*h,3.141592653589793*a*a,incidence);
    return .5*max(rhoAir,0)*max(attachedCd,0)*area*speed*rel;
}
float3 rainSiIntegrateSlip(float3 velocityMS,float3 drivingForceN,float3 normal,
    float massKG,float staticPinN,float kineticPinN,float viscousKGPerS,float dt) {
    float3 v=rainSiTangent(velocityMS,normal);
    float3 force=rainSiTangent(drivingForceN,normal);
    float step=max(dt,0);
    if(massKG<=1e-16) return 0;
    if(step<=0) return v;
    // Numerical rest epsilon is in m/s. No diameter-based arbitrary speed cap.
    if(length(v)<=1e-7 && length(force)<=max(staticPinN,0)) return 0;
    float c=max(viscousKGPerS,0);
    float safeMass=max(massKG,1e-16);
    float decay=exp(-c*step/safeMass);
    float response=c>1e-16 ? (1-decay)/max(c,1e-16) : step/safeMass;
    float3 freeV=v*decay+force*response;
    float speed=length(freeV);
    // Proximal dry-friction update cannot reverse velocity through zero.
    float remaining=max(speed-max(kineticPinN,0)*response,0);
    return freeV*(remaining/max(speed,1e-16));
}
float3 rainSiSlideWorld(float3 velocityMS,float3 gravityMS2,float3 inertiaMS2,
    float3 localAirMS,float3 normal,float volumeMM3,float theta,float thetaR,float thetaA,
    float dynamicThetaR,float dynamicThetaA,float rhoWater,float mu,float gamma,
    float rhoAir,float attachedCd,float shapeK,float viscousShape,float dt) {
    float radius=rainSiContactRadiusMM(volumeMM3,theta);
    float height=rainSiCapHeightMM(radius,theta);
    float mass=rainSiMassKG(volumeMM3,rhoWater);
    float3 drive=mass*(gravityMS2+inertiaMS2)
        +rainSiAirForceN(localAirMS,velocityMS,normal,radius,height,rhoAir,attachedCd);
    float staticPin=rainSiPinningN(2*radius,thetaR,thetaA,gamma,shapeK);
    float kineticPin=rainSiPinningN(2*radius,dynamicThetaR,dynamicThetaA,gamma,shapeK);
    float c=max(viscousShape,0)*max(mu,0)*2*radius*.001;
    return rainSiIntegrateSlip(velocityMS,drive,normal,mass,staticPin,kineticPin,c,dt);
}
float2 rainSiProjectUV(float3 duWorld,float3 dvWorld,float3 displacementM) {
    float a=dot(duWorld,duWorld),b=dot(duWorld,dvWorld),c=dot(dvWorld,dvWorld);
    float det=a*c-b*b;
    if(det<=1e-20) return 0; // Caller rejects an unsupported/degenerate surface.
    return float2(c*dot(duWorld,displacementM)-b*dot(dvWorld,displacementM),
        a*dot(dvWorld,displacementM)-b*dot(duWorld,displacementM))/max(det,1e-20);
}
float3 rainSiWorldVelocity(float3 duWorld,float3 dvWorld,float2 uvVelocity) {
    return duWorld*uvVelocity.x+dvWorld*uvVelocity.y;
}
float3 rainSiMergedVelocity(float3 a,float3 b,float volumeA,float volumeB) {
    float va=max(volumeA,0),vb=max(volumeB,0),total=va+vb;
    return (a*va+b*vb)/max(total,1e-16); // Same liquid density, no radius/display weights.
}
// Six rows: merged state/meta, signed pair transfer, projection wall,
// status/role/partner, and original physical inventory.
float4 main(PS_IN pin){
 uint i=min((uint)(pin.Tex.x*gCount),(uint)gCount-1),row=min((uint)(pin.Tex.y*6),5u);
 float4 result=0;float code=1,role=0,partner=0;float4 mergedState=0,mergedMeta=0,transfer=0,wall=0,original=0;
 if(context()&&extraContext()){
  float4 s=txOldState.Load(int3(i,0,0)),m=txOldMeta.Load(int3(i,0,0));float3 v=0;
  bool valid=all(isfinite(s))&&metaValid(m);if(life(m)==1)valid=valid&&supported(s.xy)&&velocity(s,true,v);
  code=2;
  if(valid){
   mergedState=s;mergedMeta=m;original=packet(m.g,v);uint4 bytes=0;bool bytesOK=commandBytes(txMergeCommand.Load(int3(i,0,0)),bytes);
   uint kind=bytes.z/64u;partner=bytes.x*256u+bytes.y;code=3;
   bool empty=kind==0u&&all(bytes==0u);bool request=bytesOK&&(kind==1u||kind==2u)&&partner<gCount&&partner!=(float)i&&life(m)==1;
   if(empty&&bytesOK)code=0;
   if(request){
    uint j=(uint)partner;float4 ps=txOldState.Load(int3(j,0,0)),pm=txOldMeta.Load(int3(j,0,0));float4 stamp=txMergeGeneration.Load(int3(i,0,0));
    float frame=txMergeConfig.Load(int3(0,1,0)).z;float3 pv=0;
    bool pair=all(isfinite(ps))&&metaValid(pm)&&life(pm)==1&&supported(ps.xy)&&velocity(ps,true,pv);
    pair=pair&&all(isfinite(stamp))&&stamp.x==generation(m)&&stamp.y==generation(pm)&&stamp.z==frame&&stamp.w==1;
    pair=pair&&bytes.z%64u==(uint)generation(pm)%64u;
    if(kind==2u&&pair)code=0; // SI attraction is deliberately inactive.
    if(kind==1u&&pair){
     uint4 pb=0;bool reciprocal=commandBytes(txMergeCommand.Load(int3(j,0,0)),pb);
     float4 pStamp=txMergeGeneration.Load(int3(j,0,0));
     reciprocal=reciprocal&&pb.z/64u==1u&&pb.x*256u+pb.y==i&&pb.z%64u==(uint)generation(m)%64u;
     reciprocal=reciprocal&&all(isfinite(pStamp))&&pStamp.x==generation(pm)&&pStamp.y==generation(m)&&pStamp.z==frame&&pStamp.w==1;
     code=4;
     if(reciprocal){
      float theta=txMergeConfig.Load(int3(0,1,0)).x,reach=txMergeConfig.Load(int3(0,1,0)).y;
      float radius=rainSiContactRadiusMM(m.g,theta)+rainSiContactRadiusMM(pm.g,theta);
      float2 delta=ps.xy-s.xy;float distance=max(length(worldAt(s.xy,delta,true)),length(worldAt(ps.xy,delta,true)));
      float total=m.g+pm.g;float2 centre=(s.xy*m.g+ps.xy*pm.g)/total;
      code=5;
      if(isfinite(total)&&total>max(m.g,pm.g)&&isfinite(distance)&&distance<=radius*.001*reach&&supported(centre)){
       bool winner=m.g>pm.g||(m.g==pm.g&&i<j);role=winner?1:-1;
       if(winner){
        float3 momentum=original.yzw+packet(pm.g,pv).yzw;float2 uv=projectAt(centre,momentum/total);
        float3 mv=0;bool basis=velocity(float4(centre,uv),false,mv);
        mergedState=float4(centre,uv);mergedMeta.g=total;
        transfer=packet(pm.g,pv);wall=float4(0,momentum-total*mv);
        if(!basis)code=6;else code=0;
       }else{
        mergedState=float4(s.xy,0,0);mergedMeta=float4(0,0,0,generation(m)*4);
        transfer=-original;code=0;
       }
      }
     }
    }
   }
   if(!all(isfinite(mergedState))||!all(isfinite(mergedMeta))||!all(isfinite(transfer))||!all(isfinite(wall))||!all(isfinite(original)))code=6;
  }
 }
 if(code==0){
  if(row==0u)result=mergedState;else if(row==1u)result=mergedMeta;else if(row==2u)result=transfer;else if(row==3u)result=wall;else if(row==5u)result=original;
 }
 if(row==4u)result=float4(code,role,partner,0);
 return result;
}
]====]
M.meta=[====[
// Actual P1/P2/P3 channel adapter. No display radius enters a physical packet.
bool integerValue(float x){return isfinite(x)&&x>=0&&x<=16777215&&floor(x)==x;}
bool inside(float2 p){return all(p>=float2(0,-1))&&all(p<=float2(1,0));}
bool dimensions(Texture2D<float4> t,uint w,uint h){uint a,b;t.GetDimensions(a,b);return a==w&&b==h;}
bool context(){
 float4 token=txHeader.Load(int3(0,0,0)),previous=txHeader.Load(int3(0,1,0));
 float4 frames=txHeader.Load(int3(0,2,0)),mode=txHeader.Load(int3(0,3,0));
 float4 field=txHeader.Load(int3(0,4,0)),revision=txHeader.Load(int3(0,5,0));
 bool ok=all(isfinite(token))&&all(isfinite(previous))&&all(isfinite(frames))&&all(isfinite(mode))&&all(isfinite(field))&&all(isfinite(revision));
 ok=ok&&integerValue(token.x)&&token.x>0&&integerValue(token.y)&&token.y>0&&integerValue(token.z)&&token.z>0&&token.w==1;
 ok=ok&&all(previous.xy==token.xy)&&previous.z+1==token.z&&previous.w==1;
 ok=ok&&integerValue(frames.x)&&integerValue(frames.y)&&frames.y>frames.x&&frames.z==frames.y&&frames.w==frames.y;
 ok=ok&&all(mode.xyz==1)&&mode.w>0&&mode.w<=.05;
 ok=ok&&integerValue(field.x)&&field.x>0&&integerValue(field.y)&&field.y>0&&integerValue(field.z)&&field.z>=1&&field.z<=16&&field.w==5;
 ok=ok&&integerValue(revision.x)&&revision.x>0&&integerValue(revision.y)&&revision.y>0&&integerValue(revision.z)&&revision.z>0&&revision.w==1;
 ok=ok&&dimensions(txHeader,1,6)&&dimensions(txOldState,(uint)gCount,1)&&dimensions(txOldMeta,(uint)gCount,1);
 ok=ok&&dimensions(txNewState,(uint)gCount,1)&&dimensions(txPreMeta,(uint)gCount,1)&&dimensions(txFinalMeta,(uint)gCount,1);
 ok=ok&&dimensions(txEvents,(uint)gCount,5)&&dimensions(txDescriptors,(uint)gCount,5);
 uint w,h;txDu.GetDimensions(w,h);ok=ok&&w>0&&h>0&&dimensions(txDv,w,h)&&dimensions(txBoundary,w,h);
 ok=ok&&dimensions(txOldTransform,3,1)&&dimensions(txNewTransform,3,1);
 float3 a=txOldTransform.Load(int3(0,0,0)).xyz,b=txOldTransform.Load(int3(1,0,0)).xyz,c=txOldTransform.Load(int3(2,0,0)).xyz;
 float3 d=txNewTransform.Load(int3(0,0,0)).xyz,e=txNewTransform.Load(int3(1,0,0)).xyz,f=txNewTransform.Load(int3(2,0,0)).xyz;
 float oldDet=dot(a,cross(b,c)),newDet=dot(d,cross(e,f));
 return ok&&all(isfinite(a))&&all(isfinite(b))&&all(isfinite(c))&&all(isfinite(d))&&all(isfinite(e))&&all(isfinite(f))&&isfinite(oldDet)&&isfinite(newDet)&&abs(oldDet)>1e-20&&abs(newDet)>1e-20;
}
int2 metricCell(float2 p){uint w,h;txDu.GetDimensions(w,h);return clamp((int2)(float2(p.x,p.y+1)*float2(w,h)),int2(0,0),int2(w-1,h-1));}
bool supported(float2 p){int2 c=metricCell(p);return inside(p)&&txDu.Load(int3(c,0)).w>=.5&&txBoundary.Load(int3(c,0)).w>=.5;}
float3 transformVector(float3 p,bool old){
 float3 a=0,b=0,c=0;
 if(old){a=txOldTransform.Load(int3(0,0,0)).xyz;b=txOldTransform.Load(int3(1,0,0)).xyz;c=txOldTransform.Load(int3(2,0,0)).xyz;}
 else{a=txNewTransform.Load(int3(0,0,0)).xyz;b=txNewTransform.Load(int3(1,0,0)).xyz;c=txNewTransform.Load(int3(2,0,0)).xyz;}
 return p.x*a+p.y*b+p.z*c;
}
bool velocity(float4 s,bool old,out float3 v){
 int2 p=metricCell(s.xy);float3 u=transformVector(txDu.Load(int3(p,0)).xyz,old),w=transformVector(txDv.Load(int3(p,0)).xyz,old);
 v=u*s.z+w*s.w;
 float3 normal=cross(u,w);float norm2=dot(normal,normal);
 return all(isfinite(u))&&all(isfinite(w))&&all(isfinite(v))&&all(isfinite(normal))&&isfinite(norm2)&&norm2>1e-20;
}
float generation(float4 m){return floor(m.a*.25);}
float life(float4 m){return m.a-4*generation(m);}
bool metaValid(float4 m){return all(isfinite(m))&&all(m.rgb>=0)&&integerValue(m.a)&&generation(m)<4096&&(life(m)==0||life(m)==1)&&((life(m)==0&&m.g==0)||(life(m)==1&&m.g>0));}
float4 packet(float volume,float3 v){return float4(volume,volume*v);}
bool supportSize(float2 p,float pad){return all(isfinite(p))&&all(p>=1)&&all(p<=pad)&&all(floor(p)==p);}
// A frozen command creator supplies full generations, not reconstructed low bits.
bool extraContext(){
 float4 a=txMergeConfig.Load(int3(0,0,0)),b=txMergeConfig.Load(int3(0,1,0)),c=txMergeConfig.Load(int3(0,2,0));
 float4 token=txHeader.Load(int3(0,0,0));float4 frames=txHeader.Load(int3(0,2,0));
 bool ok=dimensions(txMergeCommand,(uint)gCount,1)&&dimensions(txMergeGeneration,(uint)gCount,1)&&dimensions(txMergeConfig,1,3)&&dimensions(txPostForce,(uint)gCount,1);
 ok=ok&&all(a==token)&&all(isfinite(b))&&all(isfinite(c))&&b.x>0&&b.x<180&&b.y>0&&integerValue(b.z)&&b.z<=frames.x&&frames.x-b.z<4096&&b.w==1;
 ok=ok&&c.x>0&&c.y>0&&c.z==txHeader.Load(int3(0,3,0)).w&&c.w==1;
 // Original transport uses a reference unit. Its product must still mean 1 mm
 // after the physical scale. Neither value is the display-diameter gain.
 float3 x=txNewTransform.Load(int3(0,0,0)).xyz,y=txNewTransform.Load(int3(1,0,0)).xyz,z=txNewTransform.Load(int3(2,0,0)).xyz;
 float scale=length(x);float tol=max(scale*scale*32*1.1920928955078125e-7,1e-12);
 ok=ok&&isfinite(scale)&&scale>0&&abs(dot(y,y)-scale*scale)<=tol&&abs(dot(z,z)-scale*scale)<=tol;
 ok=ok&&abs(dot(x,y))<=tol&&abs(dot(x,z))<=tol&&abs(dot(y,z))<=tol;
 return ok&&isfinite(c.x*c.y*scale)&&abs(c.x*c.y*scale-.001)<=.001*32*1.1920928955078125e-7;
}
float3 worldAt(float2 p,float2 uv,bool old){float4 s=float4(p,uv);float3 v=0;velocity(s,old,v);return v;}
float2 projectAt(float2 p,float3 m){
 int2 q=metricCell(p);float3 u=transformVector(txDu.Load(int3(q,0)).xyz,false),v=transformVector(txDv.Load(int3(q,0)).xyz,false);
 float a=dot(u,u),b=dot(u,v),c=dot(v,v),det=a*c-b*b;
 return float2(c*dot(u,m)-b*dot(v,m),a*dot(v,m)-b*dot(u,m))/max(det,1e-20);
}
bool commandBytes(float4 c,out uint4 b){
 b=(uint4)floor(saturate(c)*255+.5);
 return all(isfinite(c))&&all(c>=0)&&all(c<=1)&&all(abs(c*255-(float4)b)<=255*4*1.1920928955078125e-7);
}
#define txRainDu txDu
#define txRainDv txDv
#define txRainBoundaryMask txBoundary
#define gRainMetersPerUnit txMergeConfig.Load(int3(0,2,0)).x
#define gRainReferencePerMM txMergeConfig.Load(int3(0,2,0)).y
#define gRainObjectToWorld float3x3(txNewTransform.Load(int3(0,0,0)).xyz,txNewTransform.Load(int3(1,0,0)).xyz,txNewTransform.Load(int3(2,0,0)).xyz)
#define gRainForceMask txSI.Load(int3(0,1,0)).w
#define gRainSiInertiaWorld txSI.Load(int3(0,1,0)).xyz
#define gRainSiAirWorld txSI.Load(int3(0,2,0)).xyz
#define gRainSiAirFraction txSI.Load(int3(0,2,0)).w
#define gRainSiRhoWater txSI.Load(int3(0,3,0)).x
#define gRainSiMu txSI.Load(int3(0,3,0)).y
#define gRainSiGamma txSI.Load(int3(0,3,0)).z
#define gRainSiRhoAir txSI.Load(int3(0,3,0)).w
#define gRainSiTheta txSI.Load(int3(0,4,0)).x
#define gRainSiStaticBare txSI.Load(int3(0,4,0)).y
#define gRainSiStaticCoat txSI.Load(int3(0,4,0)).z
#define gRainSiAttachedCd txSI.Load(int3(0,4,0)).w
#define gRainSiDynamicBare txSI.Load(int3(0,5,0)).x
#define gRainSiDynamicCoat txSI.Load(int3(0,5,0)).y
#define gRainSiViscousShape txSI.Load(int3(0,5,0)).z
#define gRainAirflowDownwardMode txSI.Load(int3(0,5,0)).w
#define gRainAirflowDownwardGain txSI.Load(int3(0,6,0)).x
#define gFilmGrid txHeader.Load(int3(0,4,0)).xy
#define gFilmPad txHeader.Load(int3(0,4,0)).z
#define gFilmCount gCount
#define gFilmTheta gRainSiTheta
#define gFilmMu gRainSiMu
#define gFilmGamma gRainSiGamma
#define gFilmDepositBare txSI.Load(int3(0,7,0)).x
#define gFilmDepositCoat txSI.Load(int3(0,7,0)).y
#define gFilmMinSpeedMS txSI.Load(int3(0,7,0)).z
#define gFilmWiden txSI.Load(int3(0,7,0)).w
#define gFilmEvapUMS txSI.Load(int3(0,8,0)).x
#define gFilmAirMS txSI.Load(int3(0,8,0)).y
#define gFilmDt txHeader.Load(int3(0,3,0)).w
#define gFilmMotionDt gFilmDt
#define gPoolOn 1
bool headContext(){
 bool ok=context()&&extraContext()&&dimensions(txSI,1,10)&&dimensions(txBirthReceipt,1,1)&&dimensions(txBirthHeader,1,5);
 [unroll]for(uint k=0;k<10u;k++)ok=ok&&all(isfinite(txSI.Load(int3(0,k,0))));
 float4 t=txHeader.Load(int3(0,0,0)),material=txSI.Load(int3(0,3,0)),angles=txSI.Load(int3(0,4,0)),dynamic=txSI.Load(int3(0,5,0));
 float4 mode=txSI.Load(int3(0,6,0)),film=txSI.Load(int3(0,7,0)),evap=txSI.Load(int3(0,8,0)),rev=txSI.Load(int3(0,9,0));
 float4 source=txBirthHeader.Load(int3(0,2,0)),shape=txBirthHeader.Load(int3(0,1,0));
 return ok&&all(txSI.Load(int3(0,0,0))==t)&&all(txBirthReceipt.Load(int3(0,0,0))==t)&&all(txBirthHeader.Load(int3(0,0,0))==t)&&
  all(txBirthHeader.Load(int3(0,4,0))==txHeader.Load(int3(0,1,0)))&&all(shape==float4(gFilmGrid,gFilmPad,gCount))&&source.y==txHeader.Load(int3(0,2,0)).y&&source.z==1&&source.w==1&&
  all(txBirthHeader.Load(int3(0,3,0))==float4(1,1,16,0))&&gRainForceMask>=0&&gRainForceMask<=7&&floor(gRainForceMask)==gRainForceMask&&
  gRainSiAirFraction>=0&&gRainSiAirFraction<=1&&material.x>0&&material.y>=0&&material.z>0&&material.w>=0&&
  angles.x==txMergeConfig.Load(int3(0,1,0)).x&&angles.x>0&&angles.x<180&&all(angles.yzw>=0)&&
  all(dynamic.xyz>=0)&&(dynamic.w==0||dynamic.w==1)&&mode.x>=0&&mode.y>0&&mode.y<=.05&&gFilmDt<=mode.y&&mode.z==1&&mode.w==0&&
  all(film>=0)&&all(evap.xy>=0)&&evap.z==1&&evap.w==0&&all(rev.xyz==txHeader.Load(int3(0,5,0)).xyz)&&rev.w==source.x;
}
// P1 shared physical primitives. Lengths/velocity/force use m, m/s, N;
// authoritative stored volume is mm^3. No display/texel/reference-size inputs.
// Reduced attached-drop model, not CFD. Material/contact/aero inputs are explicit.
float rainSiVolumeMM3(float equivalentDiameterMM) {
    float d=max(equivalentDiameterMM,0);
    return 0.523598775598299*d*d*d;
}
float rainSiEquivalentDiameterMM(float volumeMM3) {
    return pow(max(volumeMM3,0)*1.90985931710274,1.0/3.0);
}
float rainSiMassKG(float volumeMM3,float rhoWater) {
    return max(volumeMM3,0)*1e-9*max(rhoWater,0);
}
float rainSiContactRadiusMM(float volumeMM3,float thetaDeg) {
    // Valid material input angles are strictly between 0 and 180 degrees.
    float t=tan(clamp(thetaDeg,.1,179.9)*0.00872664625997165);
    return pow(max(volumeMM3,0)*1.90985931710274/(t*(3+t*t)),1.0/3.0);
}
float rainSiCapHeightMM(float radiusMM,float thetaDeg) {
    return max(radiusMM,0)*tan(clamp(thetaDeg,.1,179.9)*0.00872664625997165);
}
float rainSiPinningN(float widthMM,float thetaR,float thetaA,float gamma,float shapeK) {
    // cos(R)-cos(A) in a form stable for small hysteresis spans.
    float middle=(thetaR+thetaA)*0.00872664625997165;
    float halfSpan=(thetaA-thetaR)*0.00872664625997165;
    float hysteresis=max(2*sin(middle)*sin(halfSpan),0);
    return max(shapeK,0)*max(gamma,0)*max(widthMM,0)*.001*hysteresis;
}
float rainSiWeber(float equivalentDiameterMM,float normalImpactMS,float rhoWater,float gamma) {
    return max(rhoWater,0)*normalImpactMS*normalImpactMS*max(equivalentDiameterMM,0)*.001/max(gamma,1e-9);
}
float3 rainSiTangent(float3 v,float3 normal) {
    return v-normal*dot(v,normal);
}
float3 rainSiAirForceN(float3 relativeAirMS,float3 velocityMS,float3 normal,
    float contactRadiusMM,float capHeightMM,float rhoAir,float attachedCd) {
    float3 rel=relativeAirMS-velocityMS;
    float speed=length(rel);
    float a=max(contactRadiusMM,0)*.001;
    float h=max(capHeightMM,0)*.001;
    float incidence=speed>1e-9 ? saturate(abs(dot(rel,normal))/speed) : 0;
    // Projected cap-area approximation: grazing wind still has nonzero exposed area.
    // Caller supplies local surface air (including shielding), not a force gain.
    float area=lerp(2*a*h,3.141592653589793*a*a,incidence);
    return .5*max(rhoAir,0)*max(attachedCd,0)*area*speed*rel;
}
float3 rainSiIntegrateSlip(float3 velocityMS,float3 drivingForceN,float3 normal,
    float massKG,float staticPinN,float kineticPinN,float viscousKGPerS,float dt) {
    float3 v=rainSiTangent(velocityMS,normal);
    float3 force=rainSiTangent(drivingForceN,normal);
    float step=max(dt,0);
    if(massKG<=1e-16) return 0;
    if(step<=0) return v;
    // Numerical rest epsilon is in m/s. No diameter-based arbitrary speed cap.
    if(length(v)<=1e-7 && length(force)<=max(staticPinN,0)) return 0;
    float c=max(viscousKGPerS,0);
    float safeMass=max(massKG,1e-16);
    float x=c*step/safeMass;
    float decay=exp(-x);
    // Same exponential response, stable as x tends to zero.
    float phi1=x<.1 ? 1-x*.5+x*x/6-x*x*x/24+x*x*x*x/120-x*x*x*x*x/720 : (1-decay)/max(x,1e-30);
    float response=c>1e-16 ? step/safeMass*phi1 : step/safeMass;
    float3 freeV=v*decay+force*response;
    float speed=length(freeV);
    // Proximal dry-friction update cannot reverse velocity through zero.
    float remaining=max(speed-max(kineticPinN,0)*response,0);
    return freeV*(remaining/max(speed,1e-16));
}
float3 rainSiSlideWorld(float3 velocityMS,float3 gravityMS2,float3 inertiaMS2,
    float3 localAirMS,float3 normal,float volumeMM3,float theta,float thetaR,float thetaA,
    float dynamicThetaR,float dynamicThetaA,float rhoWater,float mu,float gamma,
    float rhoAir,float attachedCd,float shapeK,float viscousShape,float dt) {
    float radius=rainSiContactRadiusMM(volumeMM3,theta);
    float height=rainSiCapHeightMM(radius,theta);
    float mass=rainSiMassKG(volumeMM3,rhoWater);
    float3 drive=mass*(gravityMS2+inertiaMS2)
        +rainSiAirForceN(localAirMS,velocityMS,normal,radius,height,rhoAir,attachedCd);
    float staticPin=rainSiPinningN(2*radius,thetaR,thetaA,gamma,shapeK);
    float kineticPin=rainSiPinningN(2*radius,dynamicThetaR,dynamicThetaA,gamma,shapeK);
    float c=max(viscousShape,0)*max(mu,0)*2*radius*.001;
    return rainSiIntegrateSlip(velocityMS,drive,normal,mass,staticPin,kineticPin,c,dt);
}
float2 rainSiProjectUV(float3 duWorld,float3 dvWorld,float3 displacementM) {
    float a=dot(duWorld,duWorld),b=dot(duWorld,dvWorld),c=dot(dvWorld,dvWorld);
    float det=a*c-b*b;
    if(det<=1e-20) return 0; // Caller rejects an unsupported/degenerate surface.
    return float2(c*dot(duWorld,displacementM)-b*dot(dvWorld,displacementM),
        a*dot(dvWorld,displacementM)-b*dot(duWorld,displacementM))/max(det,1e-20);
}
float3 rainSiWorldVelocity(float3 duWorld,float3 dvWorld,float2 uvVelocity) {
    return duWorld*uvVelocity.x+dvWorld*uvVelocity.y;
}
float3 rainSiMergedVelocity(float3 a,float3 b,float volumeA,float volumeB) {
    float va=max(volumeA,0),vb=max(volumeB,0),total=va+vb;
    return (a*va+b*vb)/max(total,1e-16); // Same liquid density, no radius/display weights.
}
float4 main(PS_IN pin){
 uint i=min((uint)(pin.Tex.x*gCount),(uint)gCount-1u);float4 result=0;
 if(headContext()&&txOwnership.Load(int3(i,4,0)).r==0){
  float4 m=txOwnership.Load(int3(i,1,0)),old=txOldMeta.Load(int3(i,0,0)),birth=txEvents.Load(int3(i,0,0));float reason=txTrace.Load(int3(i,3,0)).x;
  float tag=fmod(generation(old)+1,4096)+1;
  result=float4(0,0,0,generation(m)*4);
  if(life(old)==0&&birth.w==tag&&birth.z>0)result=float4(rainSiContactRadiusMM(birth.z,gRainSiTheta)*gRainReferencePerMM,birth.z,0,(birth.w-1)*4+1);
  else if(life(m)==1&&m.g>0&&reason==0)result=float4(rainSiContactRadiusMM(m.g,gRainSiTheta)*gRainReferencePerMM,m.g,m.b+gFilmDt,m.a);
 }
 return result;
}
]====]
M.motion=[====[
// Actual P1/P2/P3 channel adapter. No display radius enters a physical packet.
bool integerValue(float x){return isfinite(x)&&x>=0&&x<=16777215&&floor(x)==x;}
bool inside(float2 p){return all(p>=float2(0,-1))&&all(p<=float2(1,0));}
bool dimensions(Texture2D<float4> t,uint w,uint h){uint a,b;t.GetDimensions(a,b);return a==w&&b==h;}
bool context(){
 float4 token=txHeader.Load(int3(0,0,0)),previous=txHeader.Load(int3(0,1,0));
 float4 frames=txHeader.Load(int3(0,2,0)),mode=txHeader.Load(int3(0,3,0));
 float4 field=txHeader.Load(int3(0,4,0)),revision=txHeader.Load(int3(0,5,0));
 bool ok=all(isfinite(token))&&all(isfinite(previous))&&all(isfinite(frames))&&all(isfinite(mode))&&all(isfinite(field))&&all(isfinite(revision));
 ok=ok&&integerValue(token.x)&&token.x>0&&integerValue(token.y)&&token.y>0&&integerValue(token.z)&&token.z>0&&token.w==1;
 ok=ok&&all(previous.xy==token.xy)&&previous.z+1==token.z&&previous.w==1;
 ok=ok&&integerValue(frames.x)&&integerValue(frames.y)&&frames.y>frames.x&&frames.z==frames.y&&frames.w==frames.y;
 ok=ok&&all(mode.xyz==1)&&mode.w>0&&mode.w<=.05;
 ok=ok&&integerValue(field.x)&&field.x>0&&integerValue(field.y)&&field.y>0&&integerValue(field.z)&&field.z>=1&&field.z<=16&&field.w==5;
 ok=ok&&integerValue(revision.x)&&revision.x>0&&integerValue(revision.y)&&revision.y>0&&integerValue(revision.z)&&revision.z>0&&revision.w==1;
 ok=ok&&dimensions(txHeader,1,6)&&dimensions(txOldState,(uint)gCount,1)&&dimensions(txOldMeta,(uint)gCount,1);
 ok=ok&&dimensions(txNewState,(uint)gCount,1)&&dimensions(txPreMeta,(uint)gCount,1)&&dimensions(txFinalMeta,(uint)gCount,1);
 ok=ok&&dimensions(txEvents,(uint)gCount,5)&&dimensions(txDescriptors,(uint)gCount,5);
 uint w,h;txDu.GetDimensions(w,h);ok=ok&&w>0&&h>0&&dimensions(txDv,w,h)&&dimensions(txBoundary,w,h);
 ok=ok&&dimensions(txOldTransform,3,1)&&dimensions(txNewTransform,3,1);
 float3 a=txOldTransform.Load(int3(0,0,0)).xyz,b=txOldTransform.Load(int3(1,0,0)).xyz,c=txOldTransform.Load(int3(2,0,0)).xyz;
 float3 d=txNewTransform.Load(int3(0,0,0)).xyz,e=txNewTransform.Load(int3(1,0,0)).xyz,f=txNewTransform.Load(int3(2,0,0)).xyz;
 float oldDet=dot(a,cross(b,c)),newDet=dot(d,cross(e,f));
 return ok&&all(isfinite(a))&&all(isfinite(b))&&all(isfinite(c))&&all(isfinite(d))&&all(isfinite(e))&&all(isfinite(f))&&isfinite(oldDet)&&isfinite(newDet)&&abs(oldDet)>1e-20&&abs(newDet)>1e-20;
}
int2 metricCell(float2 p){uint w,h;txDu.GetDimensions(w,h);return clamp((int2)(float2(p.x,p.y+1)*float2(w,h)),int2(0,0),int2(w-1,h-1));}
bool supported(float2 p){int2 c=metricCell(p);return inside(p)&&txDu.Load(int3(c,0)).w>=.5&&txBoundary.Load(int3(c,0)).w>=.5;}
float3 transformVector(float3 p,bool old){
 float3 a=0,b=0,c=0;
 if(old){a=txOldTransform.Load(int3(0,0,0)).xyz;b=txOldTransform.Load(int3(1,0,0)).xyz;c=txOldTransform.Load(int3(2,0,0)).xyz;}
 else{a=txNewTransform.Load(int3(0,0,0)).xyz;b=txNewTransform.Load(int3(1,0,0)).xyz;c=txNewTransform.Load(int3(2,0,0)).xyz;}
 return p.x*a+p.y*b+p.z*c;
}
bool velocity(float4 s,bool old,out float3 v){
 int2 p=metricCell(s.xy);float3 u=transformVector(txDu.Load(int3(p,0)).xyz,old),w=transformVector(txDv.Load(int3(p,0)).xyz,old);
 v=u*s.z+w*s.w;
 float3 normal=cross(u,w);float norm2=dot(normal,normal);
 return all(isfinite(u))&&all(isfinite(w))&&all(isfinite(v))&&all(isfinite(normal))&&isfinite(norm2)&&norm2>1e-20;
}
float generation(float4 m){return floor(m.a*.25);}
float life(float4 m){return m.a-4*generation(m);}
bool metaValid(float4 m){return all(isfinite(m))&&all(m.rgb>=0)&&integerValue(m.a)&&generation(m)<4096&&(life(m)==0||life(m)==1)&&((life(m)==0&&m.g==0)||(life(m)==1&&m.g>0));}
float4 packet(float volume,float3 v){return float4(volume,volume*v);}
bool supportSize(float2 p,float pad){return all(isfinite(p))&&all(p>=1)&&all(p<=pad)&&all(floor(p)==p);}
// A frozen command creator supplies full generations, not reconstructed low bits.
bool extraContext(){
 float4 a=txMergeConfig.Load(int3(0,0,0)),b=txMergeConfig.Load(int3(0,1,0)),c=txMergeConfig.Load(int3(0,2,0));
 float4 token=txHeader.Load(int3(0,0,0));float4 frames=txHeader.Load(int3(0,2,0));
 bool ok=dimensions(txMergeCommand,(uint)gCount,1)&&dimensions(txMergeGeneration,(uint)gCount,1)&&dimensions(txMergeConfig,1,3)&&dimensions(txPostForce,(uint)gCount,1);
 ok=ok&&all(a==token)&&all(isfinite(b))&&all(isfinite(c))&&b.x>0&&b.x<180&&b.y>0&&integerValue(b.z)&&b.z<=frames.x&&frames.x-b.z<4096&&b.w==1;
 ok=ok&&c.x>0&&c.y>0&&c.z==txHeader.Load(int3(0,3,0)).w&&c.w==1;
 // Original transport uses a reference unit. Its product must still mean 1 mm
 // after the physical scale. Neither value is the display-diameter gain.
 float3 x=txNewTransform.Load(int3(0,0,0)).xyz,y=txNewTransform.Load(int3(1,0,0)).xyz,z=txNewTransform.Load(int3(2,0,0)).xyz;
 float scale=length(x);float tol=max(scale*scale*32*1.1920928955078125e-7,1e-12);
 ok=ok&&isfinite(scale)&&scale>0&&abs(dot(y,y)-scale*scale)<=tol&&abs(dot(z,z)-scale*scale)<=tol;
 ok=ok&&abs(dot(x,y))<=tol&&abs(dot(x,z))<=tol&&abs(dot(y,z))<=tol;
 return ok&&isfinite(c.x*c.y*scale)&&abs(c.x*c.y*scale-.001)<=.001*32*1.1920928955078125e-7;
}
float3 worldAt(float2 p,float2 uv,bool old){float4 s=float4(p,uv);float3 v=0;velocity(s,old,v);return v;}
float2 projectAt(float2 p,float3 m){
 int2 q=metricCell(p);float3 u=transformVector(txDu.Load(int3(q,0)).xyz,false),v=transformVector(txDv.Load(int3(q,0)).xyz,false);
 float a=dot(u,u),b=dot(u,v),c=dot(v,v),det=a*c-b*b;
 return float2(c*dot(u,m)-b*dot(v,m),a*dot(v,m)-b*dot(u,m))/max(det,1e-20);
}
bool commandBytes(float4 c,out uint4 b){
 b=(uint4)floor(saturate(c)*255+.5);
 return all(isfinite(c))&&all(c>=0)&&all(c<=1)&&all(abs(c*255-(float4)b)<=255*4*1.1920928955078125e-7);
}
#define txRainDu txDu
#define txRainDv txDv
#define txRainBoundaryMask txBoundary
#define gRainMetersPerUnit txMergeConfig.Load(int3(0,2,0)).x
#define gRainReferencePerMM txMergeConfig.Load(int3(0,2,0)).y
#define gRainObjectToWorld float3x3(txNewTransform.Load(int3(0,0,0)).xyz,txNewTransform.Load(int3(1,0,0)).xyz,txNewTransform.Load(int3(2,0,0)).xyz)
#define gRainForceMask txSI.Load(int3(0,1,0)).w
#define gRainSiInertiaWorld txSI.Load(int3(0,1,0)).xyz
#define gRainSiAirWorld txSI.Load(int3(0,2,0)).xyz
#define gRainSiAirFraction txSI.Load(int3(0,2,0)).w
#define gRainSiRhoWater txSI.Load(int3(0,3,0)).x
#define gRainSiMu txSI.Load(int3(0,3,0)).y
#define gRainSiGamma txSI.Load(int3(0,3,0)).z
#define gRainSiRhoAir txSI.Load(int3(0,3,0)).w
#define gRainSiTheta txSI.Load(int3(0,4,0)).x
#define gRainSiStaticBare txSI.Load(int3(0,4,0)).y
#define gRainSiStaticCoat txSI.Load(int3(0,4,0)).z
#define gRainSiAttachedCd txSI.Load(int3(0,4,0)).w
#define gRainSiDynamicBare txSI.Load(int3(0,5,0)).x
#define gRainSiDynamicCoat txSI.Load(int3(0,5,0)).y
#define gRainSiViscousShape txSI.Load(int3(0,5,0)).z
#define gRainAirflowDownwardMode txSI.Load(int3(0,5,0)).w
#define gRainAirflowDownwardGain txSI.Load(int3(0,6,0)).x
#define gFilmGrid txHeader.Load(int3(0,4,0)).xy
#define gFilmPad txHeader.Load(int3(0,4,0)).z
#define gFilmCount gCount
#define gFilmTheta gRainSiTheta
#define gFilmMu gRainSiMu
#define gFilmGamma gRainSiGamma
#define gFilmDepositBare txSI.Load(int3(0,7,0)).x
#define gFilmDepositCoat txSI.Load(int3(0,7,0)).y
#define gFilmMinSpeedMS txSI.Load(int3(0,7,0)).z
#define gFilmWiden txSI.Load(int3(0,7,0)).w
#define gFilmEvapUMS txSI.Load(int3(0,8,0)).x
#define gFilmAirMS txSI.Load(int3(0,8,0)).y
#define gFilmDt txHeader.Load(int3(0,3,0)).w
#define gFilmMotionDt gFilmDt
#define gPoolOn 1
bool headContext(){
 bool ok=context()&&extraContext()&&dimensions(txSI,1,10)&&dimensions(txBirthReceipt,1,1)&&dimensions(txBirthHeader,1,5);
 [unroll]for(uint k=0;k<10u;k++)ok=ok&&all(isfinite(txSI.Load(int3(0,k,0))));
 float4 t=txHeader.Load(int3(0,0,0)),material=txSI.Load(int3(0,3,0)),angles=txSI.Load(int3(0,4,0)),dynamic=txSI.Load(int3(0,5,0));
 float4 mode=txSI.Load(int3(0,6,0)),film=txSI.Load(int3(0,7,0)),evap=txSI.Load(int3(0,8,0)),rev=txSI.Load(int3(0,9,0));
 float4 source=txBirthHeader.Load(int3(0,2,0)),shape=txBirthHeader.Load(int3(0,1,0));
 return ok&&all(txSI.Load(int3(0,0,0))==t)&&all(txBirthReceipt.Load(int3(0,0,0))==t)&&all(txBirthHeader.Load(int3(0,0,0))==t)&&
  all(txBirthHeader.Load(int3(0,4,0))==txHeader.Load(int3(0,1,0)))&&all(shape==float4(gFilmGrid,gFilmPad,gCount))&&source.y==txHeader.Load(int3(0,2,0)).y&&source.z==1&&source.w==1&&
  all(txBirthHeader.Load(int3(0,3,0))==float4(1,1,16,0))&&gRainForceMask>=0&&gRainForceMask<=7&&floor(gRainForceMask)==gRainForceMask&&
  gRainSiAirFraction>=0&&gRainSiAirFraction<=1&&material.x>0&&material.y>=0&&material.z>0&&material.w>=0&&
  angles.x==txMergeConfig.Load(int3(0,1,0)).x&&angles.x>0&&angles.x<180&&all(angles.yzw>=0)&&
  all(dynamic.xyz>=0)&&(dynamic.w==0||dynamic.w==1)&&mode.x>=0&&mode.y>0&&mode.y<=.05&&gFilmDt<=mode.y&&mode.z==1&&mode.w==0&&
  all(film>=0)&&all(evap.xy>=0)&&evap.z==1&&evap.w==0&&all(rev.xyz==txHeader.Load(int3(0,5,0)).xyz)&&rev.w==source.x;
}
// KN5 local metres / raw signed UV. Discrete reads avoid blending different
// island Jacobians. Source boundary alpha is authoritative; never wrap it.
float4 rainMetricTap(Texture2D tx, float2 uv) {
    uint w=1u,h=1u;tx.GetDimensions(w,h);
    return tx.Load(int3(clamp((int2)(uv*float2(w,h)),int2(0,0),int2(w-1,h-1)),0));
}
void rainMetric(float2 p,out float3 u,out float3 v) {
    float2 uv=float2(p.x,p.y+1);
    u=rainMetricTap(txRainDu,uv).xyz;v=rainMetricTap(txRainDv,uv).xyz;
}
float2 rainMetricProject(float2 p,float3 forceObject) {
    float3 u,v;rainMetric(p,u,v);
    float a=dot(u,u),b=dot(u,v),c=dot(v,v),det=max(a*c-b*b,1e-20);
    return float2(c*dot(u,forceObject)-b*dot(v,forceObject),
        a*dot(v,forceObject)-b*dot(u,forceObject))/det*gRainMetersPerUnit;
}
float3 rainMomentum(float2 p,float2 velocity) {
    float3 u,v;rainMetric(p,u,v);
    return (u*velocity.x+v*velocity.y)/gRainMetersPerUnit;
}
float rainMetricLength(float2 p,float2 delta) {
    float3 u,v;rainMetric(p,u,v);
    return length(u*delta.x+v*delta.y)/max(gRainMetersPerUnit,1e-8);
}
// Orthonormal physical plane, X along dP/dU. UV skew/scale retained exactly.
float2 rainMetricPlane(float2 p,float2 delta) {
    float3 u,v;rainMetric(p,u,v);
    float a=max(length(u),1e-9),b=dot(u/a,v),c=sqrt(max(dot(v,v)-b*b,1e-18));
    return float2(a*delta.x+b*delta.y,c*delta.y)/gRainMetersPerUnit;
}
float2 rainMetricOffset(float2 p,float2 plane) {
    float3 u,v;rainMetric(p,u,v);
    float a=max(length(u),1e-9),b=dot(u/a,v),c=sqrt(max(dot(v,v)-b*b,1e-18));
    float dv=plane.y*gRainMetersPerUnit/c;
    return float2((plane.x*gRainMetersPerUnit-b*dv)/a,dv);
}
float2 rainMetricExtent(float2 p,float radius) {
    float3 u,v;rainMetric(p,u,v);float a=dot(u,u),b=dot(u,v),c=dot(v,v);
    return radius*gRainMetersPerUnit*sqrt(float2(c,a)/max(a*c-b*b,1e-20));
}
float rainCoating(float2 p) {return rainMetricTap(txRainDv,float2(p.x,p.y+1)).a;}
float rainValid(float2 p) {
    float inside=all(p>=float2(0,-1))&&all(p<=float2(1,0)) ? 1 : 0;
    float alpha=rainMetricTap(txRainBoundaryMask,float2(p.x,p.y+1)).a;
    float support=saturate(rainMetricTap(txRainDu,float2(p.x,p.y+1)).a);
    return inside*alpha*support;
}
// Carry inertia through rotated/skewed triangle UV bases. A bounded adaptive
// step is at most 1 mm in the interior, and refines to half a source-mask
// texel at holes and atlas breaks. Excessive jumps die instead of wrapping.
float4 rainAdvance(float2 position,float2 velocity,float dt) {
    float remaining=max(dt,0);
    uint w=1u,h=1u;txRainBoundaryMask.GetDimensions(w,h);
    float2 maskSize=float2(w,h);
    float4 currentU=rainMetricTap(txRainDu,float2(position.x,position.y+1));
    float3 u=currentU.xyz,v=rainMetricTap(txRainDv,float2(position.x,position.y+1)).xyz;
    float speed=length(u*velocity.x+v*velocity.y)/max(gRainMetersPerUnit,1e-8);
    [loop] for(int step=0;step<128;++step) {
        if(remaining<=1e-7)break;
        if(speed<1e-9)break;
        float texelSpeed=max(abs(velocity.x)*maskSize.x,abs(velocity.y)*maskSize.y);
        float safe=currentU.a;
        float safePixels=max(.5,(safe-1)*.75);
        float h=min(remaining,min(safePixels/max(texelSpeed,1e-9),gRainReferencePerMM/max(speed,1e-9)));
        float2 next=position+velocity*h;
        if(any(next<float2(0,-1)) || any(next>float2(1,0)))return float4(2,2,0,0);
        float2 uv=float2(next.x,next.y+1);
        float4 nextU=rainMetricTap(txRainDu,uv);
        if(nextU.a<.5 || rainMetricTap(txRainBoundaryMask,uv).a<.5)return float4(2,2,0,0);
        float3 nextV=rainMetricTap(txRainDv,uv).xyz;
        float3 momentum=(u*velocity.x+v*velocity.y)/gRainMetersPerUnit;
        float a=dot(nextU.xyz,nextU.xyz),b=dot(nextU.xyz,nextV),c=dot(nextV,nextV);
        float det=max(a*c-b*b,1e-20);
        float mu=dot(nextU.xyz,momentum),mv=dot(nextV,momentum);
        float2 transported=float2(c*mu-b*mv,a*mv-b*mu)/det*gRainMetersPerUnit;
        float movedSpeed=length(nextU.xyz*transported.x+nextV*transported.y)/max(gRainMetersPerUnit,1e-8);
        velocity=movedSpeed>1e-9 ? transported*(speed/movedSpeed) : float2(0,0);
        position=next;remaining-=h;
        currentU=nextU;u=nextU.xyz;v=nextV;
        speed=length(u*velocity.x+v*velocity.y)/max(gRainMetersPerUnit,1e-8);
    }
    if(remaining>1e-7 && speed>1e-9)return float4(2,2,0,0);
    return float4(position,velocity);
}
// P1 shared physical primitives. Lengths/velocity/force use m, m/s, N;
// authoritative stored volume is mm^3. No display/texel/reference-size inputs.
// Reduced attached-drop model, not CFD. Material/contact/aero inputs are explicit.
float rainSiVolumeMM3(float equivalentDiameterMM) {
    float d=max(equivalentDiameterMM,0);
    return 0.523598775598299*d*d*d;
}
float rainSiEquivalentDiameterMM(float volumeMM3) {
    return pow(max(volumeMM3,0)*1.90985931710274,1.0/3.0);
}
float rainSiMassKG(float volumeMM3,float rhoWater) {
    return max(volumeMM3,0)*1e-9*max(rhoWater,0);
}
float rainSiContactRadiusMM(float volumeMM3,float thetaDeg) {
    // Valid material input angles are strictly between 0 and 180 degrees.
    float t=tan(clamp(thetaDeg,.1,179.9)*0.00872664625997165);
    return pow(max(volumeMM3,0)*1.90985931710274/(t*(3+t*t)),1.0/3.0);
}
float rainSiCapHeightMM(float radiusMM,float thetaDeg) {
    return max(radiusMM,0)*tan(clamp(thetaDeg,.1,179.9)*0.00872664625997165);
}
float rainSiPinningN(float widthMM,float thetaR,float thetaA,float gamma,float shapeK) {
    // cos(R)-cos(A) in a form stable for small hysteresis spans.
    float middle=(thetaR+thetaA)*0.00872664625997165;
    float halfSpan=(thetaA-thetaR)*0.00872664625997165;
    float hysteresis=max(2*sin(middle)*sin(halfSpan),0);
    return max(shapeK,0)*max(gamma,0)*max(widthMM,0)*.001*hysteresis;
}
float rainSiWeber(float equivalentDiameterMM,float normalImpactMS,float rhoWater,float gamma) {
    return max(rhoWater,0)*normalImpactMS*normalImpactMS*max(equivalentDiameterMM,0)*.001/max(gamma,1e-9);
}
float3 rainSiTangent(float3 v,float3 normal) {
    return v-normal*dot(v,normal);
}
float3 rainSiAirForceN(float3 relativeAirMS,float3 velocityMS,float3 normal,
    float contactRadiusMM,float capHeightMM,float rhoAir,float attachedCd) {
    float3 rel=relativeAirMS-velocityMS;
    float speed=length(rel);
    float a=max(contactRadiusMM,0)*.001;
    float h=max(capHeightMM,0)*.001;
    float incidence=speed>1e-9 ? saturate(abs(dot(rel,normal))/speed) : 0;
    // Projected cap-area approximation: grazing wind still has nonzero exposed area.
    // Caller supplies local surface air (including shielding), not a force gain.
    float area=lerp(2*a*h,3.141592653589793*a*a,incidence);
    return .5*max(rhoAir,0)*max(attachedCd,0)*area*speed*rel;
}
float3 rainSiIntegrateSlip(float3 velocityMS,float3 drivingForceN,float3 normal,
    float massKG,float staticPinN,float kineticPinN,float viscousKGPerS,float dt) {
    float3 v=rainSiTangent(velocityMS,normal);
    float3 force=rainSiTangent(drivingForceN,normal);
    float step=max(dt,0);
    if(massKG<=1e-16) return 0;
    if(step<=0) return v;
    // Numerical rest epsilon is in m/s. No diameter-based arbitrary speed cap.
    if(length(v)<=1e-7 && length(force)<=max(staticPinN,0)) return 0;
    float c=max(viscousKGPerS,0);
    float safeMass=max(massKG,1e-16);
    float x=c*step/safeMass;
    float decay=exp(-x);
    // Same exponential response, stable as x tends to zero.
    float phi1=x<.1 ? 1-x*.5+x*x/6-x*x*x/24+x*x*x*x/120-x*x*x*x*x/720 : (1-decay)/max(x,1e-30);
    float response=c>1e-16 ? step/safeMass*phi1 : step/safeMass;
    float3 freeV=v*decay+force*response;
    float speed=length(freeV);
    // Proximal dry-friction update cannot reverse velocity through zero.
    float remaining=max(speed-max(kineticPinN,0)*response,0);
    return freeV*(remaining/max(speed,1e-16));
}
float3 rainSiSlideWorld(float3 velocityMS,float3 gravityMS2,float3 inertiaMS2,
    float3 localAirMS,float3 normal,float volumeMM3,float theta,float thetaR,float thetaA,
    float dynamicThetaR,float dynamicThetaA,float rhoWater,float mu,float gamma,
    float rhoAir,float attachedCd,float shapeK,float viscousShape,float dt) {
    float radius=rainSiContactRadiusMM(volumeMM3,theta);
    float height=rainSiCapHeightMM(radius,theta);
    float mass=rainSiMassKG(volumeMM3,rhoWater);
    float3 drive=mass*(gravityMS2+inertiaMS2)
        +rainSiAirForceN(localAirMS,velocityMS,normal,radius,height,rhoAir,attachedCd);
    float staticPin=rainSiPinningN(2*radius,thetaR,thetaA,gamma,shapeK);
    float kineticPin=rainSiPinningN(2*radius,dynamicThetaR,dynamicThetaA,gamma,shapeK);
    float c=max(viscousShape,0)*max(mu,0)*2*radius*.001;
    return rainSiIntegrateSlip(velocityMS,drive,normal,mass,staticPin,kineticPin,c,dt);
}
float2 rainSiProjectUV(float3 duWorld,float3 dvWorld,float3 displacementM) {
    float a=dot(duWorld,duWorld),b=dot(duWorld,dvWorld),c=dot(dvWorld,dvWorld);
    float det=a*c-b*b;
    if(det<=1e-20) return 0; // Caller rejects an unsupported/degenerate surface.
    return float2(c*dot(duWorld,displacementM)-b*dot(dvWorld,displacementM),
        a*dot(dvWorld,displacementM)-b*dot(duWorld,displacementM))/max(det,1e-20);
}
float3 rainSiWorldVelocity(float3 duWorld,float3 dvWorld,float2 uvVelocity) {
    return duWorld*uvVelocity.x+dvWorld*uvVelocity.y;
}
float3 rainSiMergedVelocity(float3 a,float3 b,float volumeA,float volumeB) {
    float va=max(volumeA,0),vb=max(volumeB,0),total=va+vb;
    return (a*va+b*vb)/max(total,1e-16); // Same liquid density, no radius/display weights.
}
float4 headAfterForce(float2 position,float2 velocity,float mass,float dt){
                float3 u,v;rainMetric(position,u,v);
                float3 uw=mul(u,(float3x3)gRainObjectToWorld),vw=mul(v,(float3x3)gRainObjectToWorld);
                float3 crossUV=cross(uw,vw);float norm2=dot(crossUV,crossUV);
                if(norm2>=1e-20 && mass>0) {
                float3 n=crossUV*rsqrt(max(norm2,1e-20));
                float3 speed=rainSiWorldVelocity(uw,vw,velocity);
                float gravityOn=fmod(floor(gRainForceMask),2.0)>=.5 ? 1 : 0;
                float inertiaOn=fmod(floor(gRainForceMask/2.0),2.0)>=.5 ? 1 : 0;
                float airOn=fmod(floor(gRainForceMask/4.0),2.0)>=.5 ? 1 : 0;
                float3 localAir=gRainSiAirWorld*gRainSiAirFraction;
                if(gRainAirflowDownwardMode>.5 && airOn>.5) {
                    float3 down=rainSiTangent(float3(0,-1,0),n);
                    float len=length(down);
                    if(len>1e-6) {
                        down/=len;
                        float along=dot(localAir,down);
                        // Explicit user-selected approximate local surface-flow field.
                        float desired=length(localAir)*.30*max(gRainAirflowDownwardGain,0);
                        localAir+=down*(desired-along);
                    }
                }
                float coat=saturate(rainCoating(position));
                float staticHalf=.5*lerp(gRainSiStaticBare,gRainSiStaticCoat,coat);
                float dynamicHalf=.5*lerp(gRainSiDynamicBare,gRainSiDynamicCoat,coat);
                float3 next=rainSiSlideWorld(speed,float3(0,-9.80665,0)*gravityOn,
                    gRainSiInertiaWorld*inertiaOn,localAir,n,mass,gRainSiTheta,
                    max(gRainSiTheta-staticHalf,.1),min(gRainSiTheta+staticHalf,179.9),
                    max(gRainSiTheta-dynamicHalf,.1),min(gRainSiTheta+dynamicHalf,179.9),
                    gRainSiRhoWater,gRainSiMu,gRainSiGamma,gRainSiRhoAir,
                    gRainSiAttachedCd*airOn,1,gRainSiViscousShape,dt);
                velocity=rainSiProjectUV(uw,vw,next);
                } else velocity=0;

 return float4(position,velocity);
}
float4 main(PS_IN pin){
 uint i=min((uint)(pin.Tex.x*gCount),(uint)gCount-1u);float4 result=0;
 if(headContext()&&txOwnership.Load(int3(i,4,0)).r==0){
  float4 s=txOwnership.Load(int3(i,0,0)),m=txOwnership.Load(int3(i,1,0)),old=txOldMeta.Load(int3(i,0,0)),birth=txEvents.Load(int3(i,0,0));
  result=float4(s.xy,0,0);
  float tag=fmod(generation(old)+1,4096)+1;
  if(life(old)==0&&birth.w==tag&&birth.z>0)result=float4(birth.xy,txEvents.Load(int3(i,1,0)).xy);
  else if(life(m)==1&&m.g>0)result=headAfterForce(s.xy,s.zw,m.g,gFilmDt);
 }
 return all(isfinite(result))?result:0;
}
]====]
M.originalMotion=[====[
// Actual P1/P2/P3 channel adapter. No display radius enters a physical packet.
bool integerValue(float x){return isfinite(x)&&x>=0&&x<=16777215&&floor(x)==x;}
bool inside(float2 p){return all(p>=float2(0,-1))&&all(p<=float2(1,0));}
bool dimensions(Texture2D<float4> t,uint w,uint h){uint a,b;t.GetDimensions(a,b);return a==w&&b==h;}
bool context(){
 float4 token=txHeader.Load(int3(0,0,0)),previous=txHeader.Load(int3(0,1,0));
 float4 frames=txHeader.Load(int3(0,2,0)),mode=txHeader.Load(int3(0,3,0));
 float4 field=txHeader.Load(int3(0,4,0)),revision=txHeader.Load(int3(0,5,0));
 bool ok=all(isfinite(token))&&all(isfinite(previous))&&all(isfinite(frames))&&all(isfinite(mode))&&all(isfinite(field))&&all(isfinite(revision));
 ok=ok&&integerValue(token.x)&&token.x>0&&integerValue(token.y)&&token.y>0&&integerValue(token.z)&&token.z>0&&token.w==1;
 ok=ok&&all(previous.xy==token.xy)&&previous.z+1==token.z&&previous.w==1;
 ok=ok&&integerValue(frames.x)&&integerValue(frames.y)&&frames.y>frames.x&&frames.z==frames.y&&frames.w==frames.y;
 ok=ok&&all(mode.xyz==1)&&mode.w>0&&mode.w<=.05;
 ok=ok&&integerValue(field.x)&&field.x>0&&integerValue(field.y)&&field.y>0&&integerValue(field.z)&&field.z>=1&&field.z<=16&&field.w==5;
 ok=ok&&integerValue(revision.x)&&revision.x>0&&integerValue(revision.y)&&revision.y>0&&integerValue(revision.z)&&revision.z>0&&revision.w==1;
 ok=ok&&dimensions(txHeader,1,6)&&dimensions(txOldState,(uint)gCount,1)&&dimensions(txOldMeta,(uint)gCount,1);
 ok=ok&&dimensions(txNewState,(uint)gCount,1)&&dimensions(txPreMeta,(uint)gCount,1)&&dimensions(txFinalMeta,(uint)gCount,1);
 ok=ok&&dimensions(txEvents,(uint)gCount,5)&&dimensions(txDescriptors,(uint)gCount,5);
 uint w,h;txDu.GetDimensions(w,h);ok=ok&&w>0&&h>0&&dimensions(txDv,w,h)&&dimensions(txBoundary,w,h);
 ok=ok&&dimensions(txOldTransform,3,1)&&dimensions(txNewTransform,3,1);
 float3 a=txOldTransform.Load(int3(0,0,0)).xyz,b=txOldTransform.Load(int3(1,0,0)).xyz,c=txOldTransform.Load(int3(2,0,0)).xyz;
 float3 d=txNewTransform.Load(int3(0,0,0)).xyz,e=txNewTransform.Load(int3(1,0,0)).xyz,f=txNewTransform.Load(int3(2,0,0)).xyz;
 float oldDet=dot(a,cross(b,c)),newDet=dot(d,cross(e,f));
 return ok&&all(isfinite(a))&&all(isfinite(b))&&all(isfinite(c))&&all(isfinite(d))&&all(isfinite(e))&&all(isfinite(f))&&isfinite(oldDet)&&isfinite(newDet)&&abs(oldDet)>1e-20&&abs(newDet)>1e-20;
}
int2 metricCell(float2 p){uint w,h;txDu.GetDimensions(w,h);return clamp((int2)(float2(p.x,p.y+1)*float2(w,h)),int2(0,0),int2(w-1,h-1));}
bool supported(float2 p){int2 c=metricCell(p);return inside(p)&&txDu.Load(int3(c,0)).w>=.5&&txBoundary.Load(int3(c,0)).w>=.5;}
float3 transformVector(float3 p,bool old){
 float3 a=0,b=0,c=0;
 if(old){a=txOldTransform.Load(int3(0,0,0)).xyz;b=txOldTransform.Load(int3(1,0,0)).xyz;c=txOldTransform.Load(int3(2,0,0)).xyz;}
 else{a=txNewTransform.Load(int3(0,0,0)).xyz;b=txNewTransform.Load(int3(1,0,0)).xyz;c=txNewTransform.Load(int3(2,0,0)).xyz;}
 return p.x*a+p.y*b+p.z*c;
}
bool velocity(float4 s,bool old,out float3 v){
 int2 p=metricCell(s.xy);float3 u=transformVector(txDu.Load(int3(p,0)).xyz,old),w=transformVector(txDv.Load(int3(p,0)).xyz,old);
 v=u*s.z+w*s.w;
 float3 normal=cross(u,w);float norm2=dot(normal,normal);
 return all(isfinite(u))&&all(isfinite(w))&&all(isfinite(v))&&all(isfinite(normal))&&isfinite(norm2)&&norm2>1e-20;
}
float generation(float4 m){return floor(m.a*.25);}
float life(float4 m){return m.a-4*generation(m);}
bool metaValid(float4 m){return all(isfinite(m))&&all(m.rgb>=0)&&integerValue(m.a)&&generation(m)<4096&&(life(m)==0||life(m)==1)&&((life(m)==0&&m.g==0)||(life(m)==1&&m.g>0));}
float4 packet(float volume,float3 v){return float4(volume,volume*v);}
bool supportSize(float2 p,float pad){return all(isfinite(p))&&all(p>=1)&&all(p<=pad)&&all(floor(p)==p);}
// A frozen command creator supplies full generations, not reconstructed low bits.
bool extraContext(){
 float4 a=txMergeConfig.Load(int3(0,0,0)),b=txMergeConfig.Load(int3(0,1,0)),c=txMergeConfig.Load(int3(0,2,0));
 float4 token=txHeader.Load(int3(0,0,0));float4 frames=txHeader.Load(int3(0,2,0));
 bool ok=dimensions(txMergeCommand,(uint)gCount,1)&&dimensions(txMergeGeneration,(uint)gCount,1)&&dimensions(txMergeConfig,1,3)&&dimensions(txPostForce,(uint)gCount,1);
 ok=ok&&all(a==token)&&all(isfinite(b))&&all(isfinite(c))&&b.x>0&&b.x<180&&b.y>0&&integerValue(b.z)&&b.z<=frames.x&&frames.x-b.z<4096&&b.w==1;
 ok=ok&&c.x>0&&c.y>0&&c.z==txHeader.Load(int3(0,3,0)).w&&c.w==1;
 // Original transport uses a reference unit. Its product must still mean 1 mm
 // after the physical scale. Neither value is the display-diameter gain.
 float3 x=txNewTransform.Load(int3(0,0,0)).xyz,y=txNewTransform.Load(int3(1,0,0)).xyz,z=txNewTransform.Load(int3(2,0,0)).xyz;
 float scale=length(x);float tol=max(scale*scale*32*1.1920928955078125e-7,1e-12);
 ok=ok&&isfinite(scale)&&scale>0&&abs(dot(y,y)-scale*scale)<=tol&&abs(dot(z,z)-scale*scale)<=tol;
 ok=ok&&abs(dot(x,y))<=tol&&abs(dot(x,z))<=tol&&abs(dot(y,z))<=tol;
 return ok&&isfinite(c.x*c.y*scale)&&abs(c.x*c.y*scale-.001)<=.001*32*1.1920928955078125e-7;
}
float3 worldAt(float2 p,float2 uv,bool old){float4 s=float4(p,uv);float3 v=0;velocity(s,old,v);return v;}
float2 projectAt(float2 p,float3 m){
 int2 q=metricCell(p);float3 u=transformVector(txDu.Load(int3(q,0)).xyz,false),v=transformVector(txDv.Load(int3(q,0)).xyz,false);
 float a=dot(u,u),b=dot(u,v),c=dot(v,v),det=a*c-b*b;
 return float2(c*dot(u,m)-b*dot(v,m),a*dot(v,m)-b*dot(u,m))/max(det,1e-20);
}
bool commandBytes(float4 c,out uint4 b){
 b=(uint4)floor(saturate(c)*255+.5);
 return all(isfinite(c))&&all(c>=0)&&all(c<=1)&&all(abs(c*255-(float4)b)<=255*4*1.1920928955078125e-7);
}
#define txRainDu txDu
#define txRainDv txDv
#define txRainBoundaryMask txBoundary
#define gRainMetersPerUnit txMergeConfig.Load(int3(0,2,0)).x
#define gRainReferencePerMM txMergeConfig.Load(int3(0,2,0)).y
#define gRainObjectToWorld float3x3(txNewTransform.Load(int3(0,0,0)).xyz,txNewTransform.Load(int3(1,0,0)).xyz,txNewTransform.Load(int3(2,0,0)).xyz)
#define gRainForceMask txSI.Load(int3(0,1,0)).w
#define gRainSiInertiaWorld txSI.Load(int3(0,1,0)).xyz
#define gRainSiAirWorld txSI.Load(int3(0,2,0)).xyz
#define gRainSiAirFraction txSI.Load(int3(0,2,0)).w
#define gRainSiRhoWater txSI.Load(int3(0,3,0)).x
#define gRainSiMu txSI.Load(int3(0,3,0)).y
#define gRainSiGamma txSI.Load(int3(0,3,0)).z
#define gRainSiRhoAir txSI.Load(int3(0,3,0)).w
#define gRainSiTheta txSI.Load(int3(0,4,0)).x
#define gRainSiStaticBare txSI.Load(int3(0,4,0)).y
#define gRainSiStaticCoat txSI.Load(int3(0,4,0)).z
#define gRainSiAttachedCd txSI.Load(int3(0,4,0)).w
#define gRainSiDynamicBare txSI.Load(int3(0,5,0)).x
#define gRainSiDynamicCoat txSI.Load(int3(0,5,0)).y
#define gRainSiViscousShape txSI.Load(int3(0,5,0)).z
#define gRainAirflowDownwardMode txSI.Load(int3(0,5,0)).w
#define gRainAirflowDownwardGain txSI.Load(int3(0,6,0)).x
#define gFilmGrid txHeader.Load(int3(0,4,0)).xy
#define gFilmPad txHeader.Load(int3(0,4,0)).z
#define gFilmCount gCount
#define gFilmTheta gRainSiTheta
#define gFilmMu gRainSiMu
#define gFilmGamma gRainSiGamma
#define gFilmDepositBare txSI.Load(int3(0,7,0)).x
#define gFilmDepositCoat txSI.Load(int3(0,7,0)).y
#define gFilmMinSpeedMS txSI.Load(int3(0,7,0)).z
#define gFilmWiden txSI.Load(int3(0,7,0)).w
#define gFilmEvapUMS txSI.Load(int3(0,8,0)).x
#define gFilmAirMS txSI.Load(int3(0,8,0)).y
#define gFilmDt txHeader.Load(int3(0,3,0)).w
#define gFilmMotionDt gFilmDt
#define gPoolOn 1
bool headContext(){
 bool ok=context()&&extraContext()&&dimensions(txSI,1,10)&&dimensions(txBirthReceipt,1,1)&&dimensions(txBirthHeader,1,5);
 [unroll]for(uint k=0;k<10u;k++)ok=ok&&all(isfinite(txSI.Load(int3(0,k,0))));
 float4 t=txHeader.Load(int3(0,0,0)),material=txSI.Load(int3(0,3,0)),angles=txSI.Load(int3(0,4,0)),dynamic=txSI.Load(int3(0,5,0));
 float4 mode=txSI.Load(int3(0,6,0)),film=txSI.Load(int3(0,7,0)),evap=txSI.Load(int3(0,8,0)),rev=txSI.Load(int3(0,9,0));
 float4 source=txBirthHeader.Load(int3(0,2,0)),shape=txBirthHeader.Load(int3(0,1,0));
 return ok&&all(txSI.Load(int3(0,0,0))==t)&&all(txBirthReceipt.Load(int3(0,0,0))==t)&&all(txBirthHeader.Load(int3(0,0,0))==t)&&
  all(txBirthHeader.Load(int3(0,4,0))==txHeader.Load(int3(0,1,0)))&&all(shape==float4(gFilmGrid,gFilmPad,gCount))&&source.y==txHeader.Load(int3(0,2,0)).y&&source.z==1&&source.w==1&&
  all(txBirthHeader.Load(int3(0,3,0))==float4(1,1,16,0))&&gRainForceMask>=0&&gRainForceMask<=7&&floor(gRainForceMask)==gRainForceMask&&
  gRainSiAirFraction>=0&&gRainSiAirFraction<=1&&material.x>0&&material.y>=0&&material.z>0&&material.w>=0&&
  angles.x==txMergeConfig.Load(int3(0,1,0)).x&&angles.x>0&&angles.x<180&&all(angles.yzw>=0)&&
  all(dynamic.xyz>=0)&&(dynamic.w==0||dynamic.w==1)&&mode.x>=0&&mode.y>0&&mode.y<=.05&&gFilmDt<=mode.y&&mode.z==1&&mode.w==0&&
  all(film>=0)&&all(evap.xy>=0)&&evap.z==1&&evap.w==0&&all(rev.xyz==txHeader.Load(int3(0,5,0)).xyz)&&rev.w==source.x;
}
// KN5 local metres / raw signed UV. Discrete reads avoid blending different
// island Jacobians. Source boundary alpha is authoritative; never wrap it.
float4 rainMetricTap(Texture2D tx, float2 uv) {
    uint w=1u,h=1u;tx.GetDimensions(w,h);
    return tx.Load(int3(clamp((int2)(uv*float2(w,h)),int2(0,0),int2(w-1,h-1)),0));
}
void rainMetric(float2 p,out float3 u,out float3 v) {
    float2 uv=float2(p.x,p.y+1);
    u=rainMetricTap(txRainDu,uv).xyz;v=rainMetricTap(txRainDv,uv).xyz;
}
float2 rainMetricProject(float2 p,float3 forceObject) {
    float3 u,v;rainMetric(p,u,v);
    float a=dot(u,u),b=dot(u,v),c=dot(v,v),det=max(a*c-b*b,1e-20);
    return float2(c*dot(u,forceObject)-b*dot(v,forceObject),
        a*dot(v,forceObject)-b*dot(u,forceObject))/det*gRainMetersPerUnit;
}
float3 rainMomentum(float2 p,float2 velocity) {
    float3 u,v;rainMetric(p,u,v);
    return (u*velocity.x+v*velocity.y)/gRainMetersPerUnit;
}
float rainMetricLength(float2 p,float2 delta) {
    float3 u,v;rainMetric(p,u,v);
    return length(u*delta.x+v*delta.y)/max(gRainMetersPerUnit,1e-8);
}
// Orthonormal physical plane, X along dP/dU. UV skew/scale retained exactly.
float2 rainMetricPlane(float2 p,float2 delta) {
    float3 u,v;rainMetric(p,u,v);
    float a=max(length(u),1e-9),b=dot(u/a,v),c=sqrt(max(dot(v,v)-b*b,1e-18));
    return float2(a*delta.x+b*delta.y,c*delta.y)/gRainMetersPerUnit;
}
float2 rainMetricOffset(float2 p,float2 plane) {
    float3 u,v;rainMetric(p,u,v);
    float a=max(length(u),1e-9),b=dot(u/a,v),c=sqrt(max(dot(v,v)-b*b,1e-18));
    float dv=plane.y*gRainMetersPerUnit/c;
    return float2((plane.x*gRainMetersPerUnit-b*dv)/a,dv);
}
float2 rainMetricExtent(float2 p,float radius) {
    float3 u,v;rainMetric(p,u,v);float a=dot(u,u),b=dot(u,v),c=dot(v,v);
    return radius*gRainMetersPerUnit*sqrt(float2(c,a)/max(a*c-b*b,1e-20));
}
float rainCoating(float2 p) {return rainMetricTap(txRainDv,float2(p.x,p.y+1)).a;}
float rainValid(float2 p) {
    float inside=all(p>=float2(0,-1))&&all(p<=float2(1,0)) ? 1 : 0;
    float alpha=rainMetricTap(txRainBoundaryMask,float2(p.x,p.y+1)).a;
    float support=saturate(rainMetricTap(txRainDu,float2(p.x,p.y+1)).a);
    return inside*alpha*support;
}
// Carry inertia through rotated/skewed triangle UV bases. A bounded adaptive
// step is at most 1 mm in the interior, and refines to half a source-mask
// texel at holes and atlas breaks. Excessive jumps die instead of wrapping.
float4 rainAdvance(float2 position,float2 velocity,float dt) {
    float remaining=max(dt,0);
    uint w=1u,h=1u;txRainBoundaryMask.GetDimensions(w,h);
    float2 maskSize=float2(w,h);
    float4 currentU=rainMetricTap(txRainDu,float2(position.x,position.y+1));
    float3 u=currentU.xyz,v=rainMetricTap(txRainDv,float2(position.x,position.y+1)).xyz;
    float speed=length(u*velocity.x+v*velocity.y)/max(gRainMetersPerUnit,1e-8);
    [loop] for(int step=0;step<128;++step) {
        if(remaining<=1e-7)break;
        if(speed<1e-9)break;
        float texelSpeed=max(abs(velocity.x)*maskSize.x,abs(velocity.y)*maskSize.y);
        float safe=currentU.a;
        float safePixels=max(.5,(safe-1)*.75);
        float h=min(remaining,min(safePixels/max(texelSpeed,1e-9),gRainReferencePerMM/max(speed,1e-9)));
        float2 next=position+velocity*h;
        if(any(next<float2(0,-1)) || any(next>float2(1,0)))return float4(2,2,0,0);
        float2 uv=float2(next.x,next.y+1);
        float4 nextU=rainMetricTap(txRainDu,uv);
        if(nextU.a<.5 || rainMetricTap(txRainBoundaryMask,uv).a<.5)return float4(2,2,0,0);
        float3 nextV=rainMetricTap(txRainDv,uv).xyz;
        float3 momentum=(u*velocity.x+v*velocity.y)/gRainMetersPerUnit;
        float a=dot(nextU.xyz,nextU.xyz),b=dot(nextU.xyz,nextV),c=dot(nextV,nextV);
        float det=max(a*c-b*b,1e-20);
        float mu=dot(nextU.xyz,momentum),mv=dot(nextV,momentum);
        float2 transported=float2(c*mu-b*mv,a*mv-b*mu)/det*gRainMetersPerUnit;
        float movedSpeed=length(nextU.xyz*transported.x+nextV*transported.y)/max(gRainMetersPerUnit,1e-8);
        velocity=movedSpeed>1e-9 ? transported*(speed/movedSpeed) : float2(0,0);
        position=next;remaining-=h;
        currentU=nextU;u=nextU.xyz;v=nextV;
        speed=length(u*velocity.x+v*velocity.y)/max(gRainMetersPerUnit,1e-8);
    }
    if(remaining>1e-7 && speed>1e-9)return float4(2,2,0,0);
    return float4(position,velocity);
}
// P1 shared physical primitives. Lengths/velocity/force use m, m/s, N;
// authoritative stored volume is mm^3. No display/texel/reference-size inputs.
// Reduced attached-drop model, not CFD. Material/contact/aero inputs are explicit.
float rainSiVolumeMM3(float equivalentDiameterMM) {
    float d=max(equivalentDiameterMM,0);
    return 0.523598775598299*d*d*d;
}
float rainSiEquivalentDiameterMM(float volumeMM3) {
    return pow(max(volumeMM3,0)*1.90985931710274,1.0/3.0);
}
float rainSiMassKG(float volumeMM3,float rhoWater) {
    return max(volumeMM3,0)*1e-9*max(rhoWater,0);
}
float rainSiContactRadiusMM(float volumeMM3,float thetaDeg) {
    // Valid material input angles are strictly between 0 and 180 degrees.
    float t=tan(clamp(thetaDeg,.1,179.9)*0.00872664625997165);
    return pow(max(volumeMM3,0)*1.90985931710274/(t*(3+t*t)),1.0/3.0);
}
float rainSiCapHeightMM(float radiusMM,float thetaDeg) {
    return max(radiusMM,0)*tan(clamp(thetaDeg,.1,179.9)*0.00872664625997165);
}
float rainSiPinningN(float widthMM,float thetaR,float thetaA,float gamma,float shapeK) {
    float hysteresis=max(cos(thetaR*0.0174532925199433)-cos(thetaA*0.0174532925199433),0);
    return max(shapeK,0)*max(gamma,0)*max(widthMM,0)*.001*hysteresis;
}
float rainSiWeber(float equivalentDiameterMM,float normalImpactMS,float rhoWater,float gamma) {
    return max(rhoWater,0)*normalImpactMS*normalImpactMS*max(equivalentDiameterMM,0)*.001/max(gamma,1e-9);
}
float3 rainSiTangent(float3 v,float3 normal) {
    return v-normal*dot(v,normal);
}
float3 rainSiAirForceN(float3 relativeAirMS,float3 velocityMS,float3 normal,
    float contactRadiusMM,float capHeightMM,float rhoAir,float attachedCd) {
    float3 rel=relativeAirMS-velocityMS;
    float speed=length(rel);
    float a=max(contactRadiusMM,0)*.001;
    float h=max(capHeightMM,0)*.001;
    float incidence=speed>1e-9 ? saturate(abs(dot(rel,normal))/speed) : 0;
    // Projected cap-area approximation: grazing wind still has nonzero exposed area.
    // Caller supplies local surface air (including shielding), not a force gain.
    float area=lerp(2*a*h,3.141592653589793*a*a,incidence);
    return .5*max(rhoAir,0)*max(attachedCd,0)*area*speed*rel;
}
float3 rainSiIntegrateSlip(float3 velocityMS,float3 drivingForceN,float3 normal,
    float massKG,float staticPinN,float kineticPinN,float viscousKGPerS,float dt) {
    float3 v=rainSiTangent(velocityMS,normal);
    float3 force=rainSiTangent(drivingForceN,normal);
    float step=max(dt,0);
    if(massKG<=1e-16) return 0;
    if(step<=0) return v;
    // Numerical rest epsilon is in m/s. No diameter-based arbitrary speed cap.
    if(length(v)<=1e-7 && length(force)<=max(staticPinN,0)) return 0;
    float c=max(viscousKGPerS,0);
    float safeMass=max(massKG,1e-16);
    float decay=exp(-c*step/safeMass);
    float response=c>1e-16 ? (1-decay)/max(c,1e-16) : step/safeMass;
    float3 freeV=v*decay+force*response;
    float speed=length(freeV);
    // Proximal dry-friction update cannot reverse velocity through zero.
    float remaining=max(speed-max(kineticPinN,0)*response,0);
    return freeV*(remaining/max(speed,1e-16));
}
float3 rainSiSlideWorld(float3 velocityMS,float3 gravityMS2,float3 inertiaMS2,
    float3 localAirMS,float3 normal,float volumeMM3,float theta,float thetaR,float thetaA,
    float dynamicThetaR,float dynamicThetaA,float rhoWater,float mu,float gamma,
    float rhoAir,float attachedCd,float shapeK,float viscousShape,float dt) {
    float radius=rainSiContactRadiusMM(volumeMM3,theta);
    float height=rainSiCapHeightMM(radius,theta);
    float mass=rainSiMassKG(volumeMM3,rhoWater);
    float3 drive=mass*(gravityMS2+inertiaMS2)
        +rainSiAirForceN(localAirMS,velocityMS,normal,radius,height,rhoAir,attachedCd);
    float staticPin=rainSiPinningN(2*radius,thetaR,thetaA,gamma,shapeK);
    float kineticPin=rainSiPinningN(2*radius,dynamicThetaR,dynamicThetaA,gamma,shapeK);
    float c=max(viscousShape,0)*max(mu,0)*2*radius*.001;
    return rainSiIntegrateSlip(velocityMS,drive,normal,mass,staticPin,kineticPin,c,dt);
}
float2 rainSiProjectUV(float3 duWorld,float3 dvWorld,float3 displacementM) {
    float a=dot(duWorld,duWorld),b=dot(duWorld,dvWorld),c=dot(dvWorld,dvWorld);
    float det=a*c-b*b;
    if(det<=1e-20) return 0; // Caller rejects an unsupported/degenerate surface.
    return float2(c*dot(duWorld,displacementM)-b*dot(dvWorld,displacementM),
        a*dot(dvWorld,displacementM)-b*dot(duWorld,displacementM))/max(det,1e-20);
}
float3 rainSiWorldVelocity(float3 duWorld,float3 dvWorld,float2 uvVelocity) {
    return duWorld*uvVelocity.x+dvWorld*uvVelocity.y;
}
float3 rainSiMergedVelocity(float3 a,float3 b,float volumeA,float volumeB) {
    float va=max(volumeA,0),vb=max(volumeB,0),total=va+vb;
    return (a*va+b*vb)/max(total,1e-16); // Same liquid density, no radius/display weights.
}
float4 headAfterForce(float2 position,float2 velocity,float mass,float dt){
                float3 u,v;rainMetric(position,u,v);
                float3 uw=mul(u,(float3x3)gRainObjectToWorld),vw=mul(v,(float3x3)gRainObjectToWorld);
                float3 crossUV=cross(uw,vw);float norm2=dot(crossUV,crossUV);
                if(norm2>=1e-20 && mass>0) {
                float3 n=crossUV*rsqrt(max(norm2,1e-20));
                float3 speed=rainSiWorldVelocity(uw,vw,velocity);
                float gravityOn=fmod(floor(gRainForceMask),2.0)>=.5 ? 1 : 0;
                float inertiaOn=fmod(floor(gRainForceMask/2.0),2.0)>=.5 ? 1 : 0;
                float airOn=fmod(floor(gRainForceMask/4.0),2.0)>=.5 ? 1 : 0;
                float3 localAir=gRainSiAirWorld*gRainSiAirFraction;
                if(gRainAirflowDownwardMode>.5 && airOn>.5) {
                    float3 down=rainSiTangent(float3(0,-1,0),n);
                    float len=length(down);
                    if(len>1e-6) {
                        down/=len;
                        float along=dot(localAir,down);
                        // Explicit user-selected approximate local surface-flow field.
                        float desired=length(localAir)*.30*max(gRainAirflowDownwardGain,0);
                        localAir+=down*(desired-along);
                    }
                }
                float coat=saturate(rainCoating(position));
                float staticHalf=.5*lerp(gRainSiStaticBare,gRainSiStaticCoat,coat);
                float dynamicHalf=.5*lerp(gRainSiDynamicBare,gRainSiDynamicCoat,coat);
                float3 next=rainSiSlideWorld(speed,float3(0,-9.80665,0)*gravityOn,
                    gRainSiInertiaWorld*inertiaOn,localAir,n,mass,gRainSiTheta,
                    max(gRainSiTheta-staticHalf,.1),min(gRainSiTheta+staticHalf,179.9),
                    max(gRainSiTheta-dynamicHalf,.1),min(gRainSiTheta+dynamicHalf,179.9),
                    gRainSiRhoWater,gRainSiMu,gRainSiGamma,gRainSiRhoAir,
                    gRainSiAttachedCd*airOn,1,gRainSiViscousShape,dt);
                velocity=rainSiProjectUV(uw,vw,next);
                } else velocity=0;

 return float4(position,velocity);
}
float4 main(PS_IN pin){
 uint i=min((uint)(pin.Tex.x*gCount),(uint)gCount-1u);float4 result=0;
 if(headContext()&&txOwnership.Load(int3(i,4,0)).r==0){
  float4 s=txOwnership.Load(int3(i,0,0)),m=txOwnership.Load(int3(i,1,0)),old=txOldMeta.Load(int3(i,0,0)),birth=txEvents.Load(int3(i,0,0));
  result=float4(s.xy,0,0);
  float tag=fmod(generation(old)+1,4096)+1;
  if(life(old)==0&&birth.w==tag&&birth.z>0)result=float4(birth.xy,txEvents.Load(int3(i,1,0)).xy);
  else if(life(m)==1&&m.g>0)result=headAfterForce(s.xy,s.zw,m.g,gFilmDt);
 }
 return all(isfinite(result))?result:0;
}
]====]
M.reduce=[====[
// Fixed sixteen-way tree; maximum count never becomes a per-pixel slot loop.
float4 main(PS_IN pin){
 uint i=(uint)(pin.Tex.x*gWidth),n=(uint)gInputCount;float bad=0;
 [unroll]for(uint j=0;j<16u;++j){uint k=i*16u+j;if(k<n){float4 v=txInput.Load(int3(k,(int)gStatusRow,0));if(!all(isfinite(v))||v.r!=0)bad=1;}}
 return float4(bad,0,0,0);
}
]====]
M.state=[====[
float4 main(PS_IN pin){uint i=min((uint)(pin.Tex.x*gCount),(uint)gCount-1u);return txTrace.Load(int3(i,0,0));}
]====]
M.trace=[====[
// Actual P1/P2/P3 channel adapter. No display radius enters a physical packet.
bool integerValue(float x){return isfinite(x)&&x>=0&&x<=16777215&&floor(x)==x;}
bool inside(float2 p){return all(p>=float2(0,-1))&&all(p<=float2(1,0));}
bool dimensions(Texture2D<float4> t,uint w,uint h){uint a,b;t.GetDimensions(a,b);return a==w&&b==h;}
bool context(){
 float4 token=txHeader.Load(int3(0,0,0)),previous=txHeader.Load(int3(0,1,0));
 float4 frames=txHeader.Load(int3(0,2,0)),mode=txHeader.Load(int3(0,3,0));
 float4 field=txHeader.Load(int3(0,4,0)),revision=txHeader.Load(int3(0,5,0));
 bool ok=all(isfinite(token))&&all(isfinite(previous))&&all(isfinite(frames))&&all(isfinite(mode))&&all(isfinite(field))&&all(isfinite(revision));
 ok=ok&&integerValue(token.x)&&token.x>0&&integerValue(token.y)&&token.y>0&&integerValue(token.z)&&token.z>0&&token.w==1;
 ok=ok&&all(previous.xy==token.xy)&&previous.z+1==token.z&&previous.w==1;
 ok=ok&&integerValue(frames.x)&&integerValue(frames.y)&&frames.y>frames.x&&frames.z==frames.y&&frames.w==frames.y;
 ok=ok&&all(mode.xyz==1)&&mode.w>0&&mode.w<=.05;
 ok=ok&&integerValue(field.x)&&field.x>0&&integerValue(field.y)&&field.y>0&&integerValue(field.z)&&field.z>=1&&field.z<=16&&field.w==5;
 ok=ok&&integerValue(revision.x)&&revision.x>0&&integerValue(revision.y)&&revision.y>0&&integerValue(revision.z)&&revision.z>0&&revision.w==1;
 ok=ok&&dimensions(txHeader,1,6)&&dimensions(txOldState,(uint)gCount,1)&&dimensions(txOldMeta,(uint)gCount,1);
 ok=ok&&dimensions(txNewState,(uint)gCount,1)&&dimensions(txPreMeta,(uint)gCount,1)&&dimensions(txFinalMeta,(uint)gCount,1);
 ok=ok&&dimensions(txEvents,(uint)gCount,5)&&dimensions(txDescriptors,(uint)gCount,5);
 uint w,h;txDu.GetDimensions(w,h);ok=ok&&w>0&&h>0&&dimensions(txDv,w,h)&&dimensions(txBoundary,w,h);
 ok=ok&&dimensions(txOldTransform,3,1)&&dimensions(txNewTransform,3,1);
 float3 a=txOldTransform.Load(int3(0,0,0)).xyz,b=txOldTransform.Load(int3(1,0,0)).xyz,c=txOldTransform.Load(int3(2,0,0)).xyz;
 float3 d=txNewTransform.Load(int3(0,0,0)).xyz,e=txNewTransform.Load(int3(1,0,0)).xyz,f=txNewTransform.Load(int3(2,0,0)).xyz;
 float oldDet=dot(a,cross(b,c)),newDet=dot(d,cross(e,f));
 return ok&&all(isfinite(a))&&all(isfinite(b))&&all(isfinite(c))&&all(isfinite(d))&&all(isfinite(e))&&all(isfinite(f))&&isfinite(oldDet)&&isfinite(newDet)&&abs(oldDet)>1e-20&&abs(newDet)>1e-20;
}
int2 metricCell(float2 p){uint w,h;txDu.GetDimensions(w,h);return clamp((int2)(float2(p.x,p.y+1)*float2(w,h)),int2(0,0),int2(w-1,h-1));}
bool supported(float2 p){int2 c=metricCell(p);return inside(p)&&txDu.Load(int3(c,0)).w>=.5&&txBoundary.Load(int3(c,0)).w>=.5;}
float3 transformVector(float3 p,bool old){
 float3 a=0,b=0,c=0;
 if(old){a=txOldTransform.Load(int3(0,0,0)).xyz;b=txOldTransform.Load(int3(1,0,0)).xyz;c=txOldTransform.Load(int3(2,0,0)).xyz;}
 else{a=txNewTransform.Load(int3(0,0,0)).xyz;b=txNewTransform.Load(int3(1,0,0)).xyz;c=txNewTransform.Load(int3(2,0,0)).xyz;}
 return p.x*a+p.y*b+p.z*c;
}
bool velocity(float4 s,bool old,out float3 v){
 int2 p=metricCell(s.xy);float3 u=transformVector(txDu.Load(int3(p,0)).xyz,old),w=transformVector(txDv.Load(int3(p,0)).xyz,old);
 v=u*s.z+w*s.w;
 float3 normal=cross(u,w);float norm2=dot(normal,normal);
 return all(isfinite(u))&&all(isfinite(w))&&all(isfinite(v))&&all(isfinite(normal))&&isfinite(norm2)&&norm2>1e-20;
}
float generation(float4 m){return floor(m.a*.25);}
float life(float4 m){return m.a-4*generation(m);}
bool metaValid(float4 m){return all(isfinite(m))&&all(m.rgb>=0)&&integerValue(m.a)&&generation(m)<4096&&(life(m)==0||life(m)==1)&&((life(m)==0&&m.g==0)||(life(m)==1&&m.g>0));}
float4 packet(float volume,float3 v){return float4(volume,volume*v);}
bool supportSize(float2 p,float pad){return all(isfinite(p))&&all(p>=1)&&all(p<=pad)&&all(floor(p)==p);}
// A frozen command creator supplies full generations, not reconstructed low bits.
bool extraContext(){
 float4 a=txMergeConfig.Load(int3(0,0,0)),b=txMergeConfig.Load(int3(0,1,0)),c=txMergeConfig.Load(int3(0,2,0));
 float4 token=txHeader.Load(int3(0,0,0));float4 frames=txHeader.Load(int3(0,2,0));
 bool ok=dimensions(txMergeCommand,(uint)gCount,1)&&dimensions(txMergeGeneration,(uint)gCount,1)&&dimensions(txMergeConfig,1,3)&&dimensions(txPostForce,(uint)gCount,1);
 ok=ok&&all(a==token)&&all(isfinite(b))&&all(isfinite(c))&&b.x>0&&b.x<180&&b.y>0&&integerValue(b.z)&&b.z<=frames.x&&frames.x-b.z<4096&&b.w==1;
 ok=ok&&c.x>0&&c.y>0&&c.z==txHeader.Load(int3(0,3,0)).w&&c.w==1;
 // Original transport uses a reference unit. Its product must still mean 1 mm
 // after the physical scale. Neither value is the display-diameter gain.
 float3 x=txNewTransform.Load(int3(0,0,0)).xyz,y=txNewTransform.Load(int3(1,0,0)).xyz,z=txNewTransform.Load(int3(2,0,0)).xyz;
 float scale=length(x);float tol=max(scale*scale*32*1.1920928955078125e-7,1e-12);
 ok=ok&&isfinite(scale)&&scale>0&&abs(dot(y,y)-scale*scale)<=tol&&abs(dot(z,z)-scale*scale)<=tol;
 ok=ok&&abs(dot(x,y))<=tol&&abs(dot(x,z))<=tol&&abs(dot(y,z))<=tol;
 return ok&&isfinite(c.x*c.y*scale)&&abs(c.x*c.y*scale-.001)<=.001*32*1.1920928955078125e-7;
}
float3 worldAt(float2 p,float2 uv,bool old){float4 s=float4(p,uv);float3 v=0;velocity(s,old,v);return v;}
float2 projectAt(float2 p,float3 m){
 int2 q=metricCell(p);float3 u=transformVector(txDu.Load(int3(q,0)).xyz,false),v=transformVector(txDv.Load(int3(q,0)).xyz,false);
 float a=dot(u,u),b=dot(u,v),c=dot(v,v),det=a*c-b*b;
 return float2(c*dot(u,m)-b*dot(v,m),a*dot(v,m)-b*dot(u,m))/max(det,1e-20);
}
bool commandBytes(float4 c,out uint4 b){
 b=(uint4)floor(saturate(c)*255+.5);
 return all(isfinite(c))&&all(c>=0)&&all(c<=1)&&all(abs(c*255-(float4)b)<=255*4*1.1920928955078125e-7);
}
#define txRainDu txDu
#define txRainDv txDv
#define txRainBoundaryMask txBoundary
#define gRainMetersPerUnit txMergeConfig.Load(int3(0,2,0)).x
#define gRainReferencePerMM txMergeConfig.Load(int3(0,2,0)).y
// KN5 local metres / raw signed UV. Discrete reads avoid blending different
// island Jacobians. Source boundary alpha is authoritative; never wrap it.
float4 rainMetricTap(Texture2D tx, float2 uv) {
    uint w=1u,h=1u;tx.GetDimensions(w,h);
    return tx.Load(int3(clamp((int2)(uv*float2(w,h)),int2(0,0),int2(w-1,h-1)),0));
}
void rainMetric(float2 p,out float3 u,out float3 v) {
    float2 uv=float2(p.x,p.y+1);
    u=rainMetricTap(txRainDu,uv).xyz;v=rainMetricTap(txRainDv,uv).xyz;
}
float2 rainMetricProject(float2 p,float3 forceObject) {
    float3 u,v;rainMetric(p,u,v);
    float a=dot(u,u),b=dot(u,v),c=dot(v,v),det=max(a*c-b*b,1e-20);
    return float2(c*dot(u,forceObject)-b*dot(v,forceObject),
        a*dot(v,forceObject)-b*dot(u,forceObject))/det*gRainMetersPerUnit;
}
float3 rainMomentum(float2 p,float2 velocity) {
    float3 u,v;rainMetric(p,u,v);
    return (u*velocity.x+v*velocity.y)/gRainMetersPerUnit;
}
float rainMetricLength(float2 p,float2 delta) {
    float3 u,v;rainMetric(p,u,v);
    return length(u*delta.x+v*delta.y)/max(gRainMetersPerUnit,1e-8);
}
// Orthonormal physical plane, X along dP/dU. UV skew/scale retained exactly.
float2 rainMetricPlane(float2 p,float2 delta) {
    float3 u,v;rainMetric(p,u,v);
    float a=max(length(u),1e-9),b=dot(u/a,v),c=sqrt(max(dot(v,v)-b*b,1e-18));
    return float2(a*delta.x+b*delta.y,c*delta.y)/gRainMetersPerUnit;
}
float2 rainMetricOffset(float2 p,float2 plane) {
    float3 u,v;rainMetric(p,u,v);
    float a=max(length(u),1e-9),b=dot(u/a,v),c=sqrt(max(dot(v,v)-b*b,1e-18));
    float dv=plane.y*gRainMetersPerUnit/c;
    return float2((plane.x*gRainMetersPerUnit-b*dv)/a,dv);
}
float2 rainMetricExtent(float2 p,float radius) {
    float3 u,v;rainMetric(p,u,v);float a=dot(u,u),b=dot(u,v),c=dot(v,v);
    return radius*gRainMetersPerUnit*sqrt(float2(c,a)/max(a*c-b*b,1e-20));
}
float rainCoating(float2 p) {return rainMetricTap(txRainDv,float2(p.x,p.y+1)).a;}
float rainValid(float2 p) {
    float inside=all(p>=float2(0,-1))&&all(p<=float2(1,0)) ? 1 : 0;
    float alpha=rainMetricTap(txRainBoundaryMask,float2(p.x,p.y+1)).a;
    float support=saturate(rainMetricTap(txRainDu,float2(p.x,p.y+1)).a);
    return inside*alpha*support;
}
// Carry inertia through rotated/skewed triangle UV bases. A bounded adaptive
// step is at most 1 mm in the interior, and refines to half a source-mask
// texel at holes and atlas breaks. Excessive jumps die instead of wrapping.
struct Trace{float4 state;float4 last;float4 info;};
Trace captureTrace(float2 p,float2 v,float remaining,float dt,float code){
 Trace t;t.state=code>0?float4(2,2,0,0):float4(p,v);t.last=float4(p,v);t.info=float4(code,remaining,dt-remaining,1);return t;
}
Trace rainAdvanceTrace(float2 position,float2 velocity,float dt) {
    float remaining=max(dt,0);
    uint w=1u,h=1u;txRainBoundaryMask.GetDimensions(w,h);
    float2 maskSize=float2(w,h);
    float4 currentU=rainMetricTap(txRainDu,float2(position.x,position.y+1));
    float3 u=currentU.xyz,v=rainMetricTap(txRainDv,float2(position.x,position.y+1)).xyz;
    float speed=length(u*velocity.x+v*velocity.y)/max(gRainMetersPerUnit,1e-8);
    [loop] for(int step=0;step<128;++step) {
        if(remaining<=1e-7)break;
        if(speed<1e-9)break;
        float texelSpeed=max(abs(velocity.x)*maskSize.x,abs(velocity.y)*maskSize.y);
        float safe=currentU.a;
        float safePixels=max(.5,(safe-1)*.75);
        float h=min(remaining,min(safePixels/max(texelSpeed,1e-9),gRainReferencePerMM/max(speed,1e-9)));
        float2 next=position+velocity*h;
        if(any(next<float2(0,-1)) || any(next>float2(1,0)))return captureTrace(position,velocity,remaining,dt,1);
        float2 uv=float2(next.x,next.y+1);
        float4 nextU=rainMetricTap(txRainDu,uv);
        if(nextU.a<.5 || rainMetricTap(txRainBoundaryMask,uv).a<.5)return captureTrace(position,velocity,remaining,dt,2);
        float3 nextV=rainMetricTap(txRainDv,uv).xyz;
        float3 momentum=(u*velocity.x+v*velocity.y)/gRainMetersPerUnit;
        float a=dot(nextU.xyz,nextU.xyz),b=dot(nextU.xyz,nextV),c=dot(nextV,nextV);
        float det=max(a*c-b*b,1e-20);
        float mu=dot(nextU.xyz,momentum),mv=dot(nextV,momentum);
        float2 transported=float2(c*mu-b*mv,a*mv-b*mu)/det*gRainMetersPerUnit;
        float movedSpeed=length(nextU.xyz*transported.x+nextV*transported.y)/max(gRainMetersPerUnit,1e-8);
        velocity=movedSpeed>1e-9 ? transported*(speed/movedSpeed) : float2(0,0);
        position=next;remaining-=h;
        currentU=nextU;u=nextU.xyz;v=nextV;
        speed=length(u*velocity.x+v*velocity.y)/max(gRainMetersPerUnit,1e-8);
    }
    if(remaining>1e-7 && speed>1e-9)return captureTrace(position,velocity,remaining,dt,3);
    return captureTrace(position,velocity,remaining,dt,0);
}
// Post-force velocity is an immutable input from the future head producer.
// This pass validates transport/exit ownership, not the force calculation.
float4 main(PS_IN pin){
 uint i=min((uint)(pin.Tex.x*gCount),(uint)gCount-1),row=min((uint)(pin.Tex.y*4),3u);float4 result=0;
 float4 start=txPostForce.Load(int3(i,0,0)),merged=txOwnership.Load(int3(i,0,0)),meta=txOwnership.Load(int3(i,1,0));
 Trace t=captureTrace(float2(.5,-.5),0,0,0,4);float4 exited=0;
 if(context()&&extraContext()&&txOwnership.Load(int3(i,4,0)).r==0&&all(isfinite(start))){
  if(life(meta)==1&&all(start.xy==merged.xy)&&supported(start.xy)){
   float3 v=0;if(velocity(start,false,v))t=rainAdvanceTrace(start.xy,start.zw,txMergeConfig.Load(int3(0,2,0)).z);
  }else if(life(meta)==0)t=captureTrace(start.xy,start.zw,0,0,0);
  if(t.info.x==1||t.info.x==2){
   float3 lastV=0;if(supported(t.last.xy)&&velocity(t.last,false,lastV))exited=packet(meta.g,lastV);else t.info.x=4;
  }
 }
 if(!all(isfinite(t.state))||!all(isfinite(t.last))||!all(isfinite(t.info))||!all(isfinite(exited))){t=captureTrace(float2(.5,-.5),0,0,0,4);exited=0;}
 if(row==0u)result=t.state;else if(row==1u)result=t.last;else if(row==2u)result=exited;else result=t.info;
 return result;
}
]====]
M.zero=[====[
float4 main(PS_IN pin){return 0;}
]====]
return M
