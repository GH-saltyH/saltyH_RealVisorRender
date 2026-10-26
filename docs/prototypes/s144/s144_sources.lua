local M={keys={bin=1,cells=2,commit=3,decision=4,gather=5,reduceStatus=6,reduceTotals=7,sources=8,status=9,summary=10,totals=11}}
M.bin=[====[
float pfBits(uint base,float2 low,float2 high) {
    uint bits=0u;
    [loop] for(uint b=0u;b<24u;++b) {
        uint i=base+b;if(i>=(uint)gCount)break;
        float4 box=txSources.Load(int3(i,6,0));
        if(all(box.zw>=low)&&all(box.xy<=high))bits|=1u<<b;
    }
    return float(bits);
}
float4 main(PS_IN pin) {
    uint x=(uint)floor(pin.Tex.x*gMaskW),y=(uint)floor(pin.Tex.y*gTilesY);
    uint tile=x/(uint)gWords,word=x-tile*(uint)gWords,base=word*96u;
    float2 low=float2(tile,y)*gTile-.5,high=low+gTile;
    return float4(pfBits(base,low,high),pfBits(base+24u,low,high),
                  pfBits(base+48u,low,high),pfBits(base+72u,low,high));
}
]====]
M.cells=[====[
bool packetValid(float4 p){return all(isfinite(p))&&p.r>=0&&(p.r>0||all(p.yzw==0));}
bool integerValue(float x){return isfinite(x)&&x>=0&&x<=16777215&&floor(x)==x;}
bool dimensions(Texture2D<float4> t,uint w,uint h){uint a,b;t.GetDimensions(a,b);return a==w&&b==h;}
float4 head(uint i,uint row){return txHeads.Load(int3(i,row,0));}
bool context(){
 float4 token=txSourceHeader.Load(int3(0,0,0)),shape=txSourceHeader.Load(int3(0,1,0)),stamp=txSourceHeader.Load(int3(0,2,0));
 float4 mode=txSourceHeader.Load(int3(0,3,0)),previous=txSourceHeader.Load(int3(0,4,0));
 float4 published=txPublished.Load(int3(0,0,0)),phase=txPublished.Load(int3(0,1,0));
 float4 hh=txHeadHeader.Load(int3(0,0,0)),hg=txHeadHeader.Load(int3(0,4,0)),hf=txHeadHeader.Load(int3(0,2,0));
 bool ok=all(isfinite(token))&&integerValue(token.x)&&token.x>0&&integerValue(token.y)&&token.y>0&&integerValue(token.z)&&token.z>0&&token.w==1;
 ok=ok&&all(previous==published)&&all(previous.xy==token.xy)&&previous.z+1==token.z&&previous.w==1;
 ok=ok&&all(phase==float4(2,previous.z,0,1))&&all(txHeadReceipt.Load(int3(0,0,0))==token)&&all(hh==token);
 ok=ok&&all(shape==float4(gGrid,hg.z,gCount))&&all(hg.xy==gGrid)&&hg.z>=1&&hg.z<=16&&floor(hg.z)==hg.z;
 ok=ok&&all(isfinite(stamp))&&integerValue(stamp.x)&&stamp.x<=1048575&&stamp.y==hf.y&&integerValue(stamp.z)&&stamp.z>0&&stamp.w==1;
 ok=ok&&all(mode==float4(1,1,16,0))&&txHeadHeader.Load(int3(0,3,0)).w>0&&txHeadHeader.Load(int3(0,3,0)).w<=.05;
 ok=ok&&dimensions(txHeads,(uint)gCount,20)&&dimensions(txOriginalHeads,(uint)gCount,1)&&dimensions(txHeadReceipt,1,1)&&dimensions(txHeadHeader,1,6)&&dimensions(txFilmBirthEvent,(uint)gCount,5);
 ok=ok&&dimensions(txOriginalFilm,(uint)gGrid.x,(uint)gGrid.y)&&dimensions(txOriginalMicro,(uint)gGrid.x,(uint)gGrid.y)&&dimensions(txCells,(uint)gGrid.x,(uint)gGrid.y);
 return ok&&dimensions(txImpact,(uint)gCount,4)&&dimensions(txSourceHeader,1,5)&&dimensions(txPreviousLedger,1,8)&&dimensions(txPublished,1,2);
}
void addPacket(float4 v,inout float4 total,inout float4 error){precise float4 y=v-error,next=total+y;error=(next-total)-y;total=next;}
#define gFilmGrid gGrid
#define gFilmPad 0
#define gPoolOn 1
#define gPoolCount gCount
#define gPoolTick txSourceHeader.Load(int3(0,2,0)).x
#define txFilmPrevious txOriginalFilm
// P4b bounded, unique region -> slot ownership. Counts and tick are integers.
uint poolTilesX() {return ((uint)gFilmGrid.x+15u)/16u;}
uint poolTileCount() {return poolTilesX()*(((uint)gFilmGrid.y+15u)/16u);}
uint poolRotation() {
    uint groups=((uint)max(gPoolCount,1)+poolTileCount()-1u)/poolTileCount();
    // Advance region rotation after a complete slot-group cycle. Using tick
    // directly aliases groups/regions at common counts such as 4096 slots.
    return ((uint)gPoolTick/groups)%poolTileCount();
}
uint poolOwner(uint tile) {
    uint tiles=poolTileCount(),count=(uint)max(gPoolCount,1),tick=(uint)gPoolTick;
    uint group=tick%((count+tiles-1u)/tiles);
    return group*tiles+(tile+tiles-poolRotation())%tiles;
}
// Same immutable P2 event used by head birth, donor flux, field debit and optics.
float poolTransfer(int2 padded) {
    if(gPoolOn<.5)return 0;
    int2 p=padded-(int)gFilmPad;
    if(any(p<0)||any(p>=(int2)gFilmGrid))return 0;
    uint tile=(uint)p.y/16u*poolTilesX()+(uint)p.x/16u,owner=poolOwner(tile);
    if(owner>=(uint)gPoolCount)return 0;
    float transferred=txFilmBirthEvent.Load(int3(owner,4,0)).z;
    if(transferred<=0)return 0;
    float2 born=txFilmBirthEvent.Load(int3(owner,0,0)).xy;
    int2 source=(int2)floor(float2(born.x,born.y+1)*gFilmGrid);
    return all(source==p) ? transferred : 0;
}
float poolAvailable(int2 p) {
    return max(txFilmPrevious.Load(int3(p,0)).r,0)-poolTransfer(p);
}
// Film, pinned micro, wall, coverage runoff, raw deposited packet, pool debit,
// status. Existing inventory is not multiplied by boundary coverage again.
float4 main(PS_IN pin){
 uint bank=min((uint)(pin.Tex.y*7),6u);int2 p=min((int2)(float2(pin.Tex.x,frac(pin.Tex.y*7))*gGrid),(int2)gGrid-1);
 float4 old=txOriginalFilm.Load(int3(p,0)),oldMicro=txOriginalMicro.Load(int3(p,0)),cell=txCells.Load(int3(p,0));
 float4 incoming=txRaster.Load(int3(p,0)),micro=txRaster.Load(int3(p+int2(0,(int)gGrid.y),0));
 float4 next=0,nextMicro=0,wall=0,runoff=0,debit=0;float code=1;
 bool ok=context()&&packetValid(old)&&packetValid(oldMicro)&&packetValid(incoming)&&packetValid(micro);
 ok=ok&&all(isfinite(cell))&&cell.r>=0&&cell.g>=0&&cell.g<=1&&cell.b==1&&cell.a==1&&(cell.r>0||cell.g==0);
 ok=ok&&((cell.r>0&&cell.g>0)||(old.r==0&&oldMicro.r==0));
 if(ok){
  float requested=poolTransfer(p);precise float remaining=old.r-requested;precise float removed=old.r-remaining;
  ok=isfinite(requested)&&requested>=0&&requested<=old.r&&removed==requested&&(requested==0||remaining<old.r);
  if(ok){
   float fraction=old.r>0?remaining/old.r:0;float4 retained=float4(remaining,old.yzw*fraction);debit=old-retained;
   next=retained+incoming*cell.g;nextMicro=float4(oldMicro.r+micro.r*cell.g,0,0,0);
   wall=float4(0,debit.yzw+oldMicro.yzw+micro.yzw*cell.g);runoff=(incoming+micro)*(1-cell.g);
   ok=packetValid(next)&&packetValid(nextMicro)&&packetValid(runoff)&&all(isfinite(wall))&&packetValid(debit);
  }
  code=ok?0:2;
 }
 float4 result=0;
 if(code==0){if(bank==0u)result=next;else if(bank==1u)result=nextMicro;else if(bank==2u)result=wall;else if(bank==3u)result=runoff;else if(bank==4u)result=incoming+micro;else if(bank==5u)result=debit;}
 if(bank==6u)result=float4(code,0,0,0);return result;
}
]====]
M.commit=[====[
bool packetValid(float4 p){return all(isfinite(p))&&p.r>=0&&(p.r>0||all(p.yzw==0));}
bool integerValue(float x){return isfinite(x)&&x>=0&&x<=16777215&&floor(x)==x;}
bool dimensions(Texture2D<float4> t,uint w,uint h){uint a,b;t.GetDimensions(a,b);return a==w&&b==h;}
float4 head(uint i,uint row){return txHeads.Load(int3(i,row,0));}
bool context(){
 float4 token=txSourceHeader.Load(int3(0,0,0)),shape=txSourceHeader.Load(int3(0,1,0)),stamp=txSourceHeader.Load(int3(0,2,0));
 float4 mode=txSourceHeader.Load(int3(0,3,0)),previous=txSourceHeader.Load(int3(0,4,0));
 float4 published=txPublished.Load(int3(0,0,0)),phase=txPublished.Load(int3(0,1,0));
 float4 hh=txHeadHeader.Load(int3(0,0,0)),hg=txHeadHeader.Load(int3(0,4,0)),hf=txHeadHeader.Load(int3(0,2,0));
 bool ok=all(isfinite(token))&&integerValue(token.x)&&token.x>0&&integerValue(token.y)&&token.y>0&&integerValue(token.z)&&token.z>0&&token.w==1;
 ok=ok&&all(previous==published)&&all(previous.xy==token.xy)&&previous.z+1==token.z&&previous.w==1;
 ok=ok&&all(phase==float4(2,previous.z,0,1))&&all(txHeadReceipt.Load(int3(0,0,0))==token)&&all(hh==token);
 ok=ok&&all(shape==float4(gGrid,hg.z,gCount))&&all(hg.xy==gGrid)&&hg.z>=1&&hg.z<=16&&floor(hg.z)==hg.z;
 ok=ok&&all(isfinite(stamp))&&integerValue(stamp.x)&&stamp.x<=1048575&&stamp.y==hf.y&&integerValue(stamp.z)&&stamp.z>0&&stamp.w==1;
 ok=ok&&all(mode==float4(1,1,16,0))&&txHeadHeader.Load(int3(0,3,0)).w>0&&txHeadHeader.Load(int3(0,3,0)).w<=.05;
 ok=ok&&dimensions(txHeads,(uint)gCount,20)&&dimensions(txOriginalHeads,(uint)gCount,1)&&dimensions(txHeadReceipt,1,1)&&dimensions(txHeadHeader,1,6)&&dimensions(txFilmBirthEvent,(uint)gCount,5);
 ok=ok&&dimensions(txOriginalFilm,(uint)gGrid.x,(uint)gGrid.y)&&dimensions(txOriginalMicro,(uint)gGrid.x,(uint)gGrid.y)&&dimensions(txCells,(uint)gGrid.x,(uint)gGrid.y);
 return ok&&dimensions(txImpact,(uint)gCount,4)&&dimensions(txSourceHeader,1,5)&&dimensions(txPreviousLedger,1,8)&&dimensions(txPublished,1,2);
}
void addPacket(float4 v,inout float4 total,inout float4 error){precise float4 y=v-error,next=total+y;error=(next-total)-y;total=next;}
float4 total(uint row){return txTotals.Load(int3(0,row,0));}
float4 outsidePacket(){
 float4 tail=total(8)-total(9),bound=max((abs(total(8))+abs(total(9)))*128*1.1920928955078125e-7,1e-9);
 if(abs(tail.r)<=bound.r&&all(abs(tail)<=bound))tail=0;
 return tail;
}
float4 stepRow(uint row){float4 v=total(row);if(row==7u)v+=outsidePacket();return v;}
float4 cumulativeRow(uint row){
 float4 result=txPreviousLedger.Load(int3(0,row,0));
 if(row==1u)result=total(1);else if(row>1u)result+=stepRow(row);
 return result;
}
bool ledgerPacket(uint row,float4 p){
 bool result=packetValid(p);
 if(row==3u)result=all(isfinite(p))&&p.r>=0&&all(p.yzw==0);
 else if(row==4u||row==5u)result=all(isfinite(p))&&p.r==0;
 return result;
}
bool ledgerAdmission(){
 if(!context()||txStatus.Load(int3(0,0,0)).r!=0)return false;
 bool ok=true;[unroll]for(uint totalIndex=0;totalIndex<11u;totalIndex++)ok=ok&&all(isfinite(total(totalIndex)));
 float4 tail=outsidePacket(),bound=max((abs(total(8))+abs(total(9)))*128*1.1920928955078125e-7,1e-9);
 ok=ok&&packetValid(tail)&&tail.r<=total(10).r+bound.r;
 float4 sum=0,oldSum=0,newSum=0,scale=0,oldScale=0,newScale=0;
 [unroll]for(uint i=0;i<8u;i++){
  float4 v=stepRow(i),old=txPreviousLedger.Load(int3(0,i,0)),next=cumulativeRow(i);
  ok=ok&&ledgerPacket(i,v)&&ledgerPacket(i,old)&&ledgerPacket(i,next);float sign=(i==0u||i==2u||i==4u)?-1:((i==3u)?0:1);
  sum+=v*sign;oldSum+=old*sign;newSum+=next*sign;scale+=abs(v);oldScale+=abs(old);newScale+=abs(next);
 }
 float4 inventoryError=txPreviousLedger.Load(int3(0,1,0))-total(0);
 ok=ok&&all(abs(inventoryError)<=max((abs(txPreviousLedger.Load(int3(0,1,0)))+abs(total(0)))*128*1.1920928955078125e-7,1e-9));
 return ok&&all(abs(sum)<=max(scale*128*1.1920928955078125e-7,1e-9))&&all(abs(oldSum)<=max(oldScale*128*1.1920928955078125e-7,1e-9))&&all(abs(newSum)<=max(newScale*128*1.1920928955078125e-7,1e-9));
}
// Immutable candidate roots only. Physical completion remains an external gate.
float4 main(PS_IN pin){
 bool ready=txDecision.Load(int3(0,0,0)).r==1;float4 result=0;
 if(gKind<2){int2 p=min((int2)(pin.Tex*gGrid),(int2)gGrid-1);result=gKind==0?txOriginalFilm.Load(int3(p,0)):txOriginalMicro.Load(int3(p,0));if(ready)result=txStaged.Load(int3(p+int2(0,(int)gKind*(int)gGrid.y),0));}
 else if(gKind==2){uint i=min((uint)(pin.Tex.x*gCount),(uint)gCount-1);result=txOriginalHeads.Load(int3(i,0,0));if(ready)result=head(i,2);}
 else if(gKind==3){if(ready)result=stepRow(min((uint)(pin.Tex.y*8),7u));}
 else if(gKind==4){uint row=min((uint)(pin.Tex.y*8),7u);result=txPreviousLedger.Load(int3(0,row,0));if(ready)result=cumulativeRow(row);}
 else{uint row=min((uint)(pin.Tex.y*2),1u);result=txPublished.Load(int3(0,row,0));if(ready)result=row==0u?txSourceHeader.Load(int3(0,0,0)):float4(1,txSourceHeader.Load(int3(0,0,0)).z,txHeadHeader.Load(int3(0,3,0)).w,1);}
 return result;
}
]====]
M.decision=[====[
bool packetValid(float4 p){return all(isfinite(p))&&p.r>=0&&(p.r>0||all(p.yzw==0));}
bool integerValue(float x){return isfinite(x)&&x>=0&&x<=16777215&&floor(x)==x;}
bool dimensions(Texture2D<float4> t,uint w,uint h){uint a,b;t.GetDimensions(a,b);return a==w&&b==h;}
float4 head(uint i,uint row){return txHeads.Load(int3(i,row,0));}
bool context(){
 float4 token=txSourceHeader.Load(int3(0,0,0)),shape=txSourceHeader.Load(int3(0,1,0)),stamp=txSourceHeader.Load(int3(0,2,0));
 float4 mode=txSourceHeader.Load(int3(0,3,0)),previous=txSourceHeader.Load(int3(0,4,0));
 float4 published=txPublished.Load(int3(0,0,0)),phase=txPublished.Load(int3(0,1,0));
 float4 hh=txHeadHeader.Load(int3(0,0,0)),hg=txHeadHeader.Load(int3(0,4,0)),hf=txHeadHeader.Load(int3(0,2,0));
 bool ok=all(isfinite(token))&&integerValue(token.x)&&token.x>0&&integerValue(token.y)&&token.y>0&&integerValue(token.z)&&token.z>0&&token.w==1;
 ok=ok&&all(previous==published)&&all(previous.xy==token.xy)&&previous.z+1==token.z&&previous.w==1;
 ok=ok&&all(phase==float4(2,previous.z,0,1))&&all(txHeadReceipt.Load(int3(0,0,0))==token)&&all(hh==token);
 ok=ok&&all(shape==float4(gGrid,hg.z,gCount))&&all(hg.xy==gGrid)&&hg.z>=1&&hg.z<=16&&floor(hg.z)==hg.z;
 ok=ok&&all(isfinite(stamp))&&integerValue(stamp.x)&&stamp.x<=1048575&&stamp.y==hf.y&&integerValue(stamp.z)&&stamp.z>0&&stamp.w==1;
 ok=ok&&all(mode==float4(1,1,16,0))&&txHeadHeader.Load(int3(0,3,0)).w>0&&txHeadHeader.Load(int3(0,3,0)).w<=.05;
 ok=ok&&dimensions(txHeads,(uint)gCount,20)&&dimensions(txOriginalHeads,(uint)gCount,1)&&dimensions(txHeadReceipt,1,1)&&dimensions(txHeadHeader,1,6)&&dimensions(txFilmBirthEvent,(uint)gCount,5);
 ok=ok&&dimensions(txOriginalFilm,(uint)gGrid.x,(uint)gGrid.y)&&dimensions(txOriginalMicro,(uint)gGrid.x,(uint)gGrid.y)&&dimensions(txCells,(uint)gGrid.x,(uint)gGrid.y);
 return ok&&dimensions(txImpact,(uint)gCount,4)&&dimensions(txSourceHeader,1,5)&&dimensions(txPreviousLedger,1,8)&&dimensions(txPublished,1,2);
}
void addPacket(float4 v,inout float4 total,inout float4 error){precise float4 y=v-error,next=total+y;error=(next-total)-y;total=next;}
float4 total(uint row){return txTotals.Load(int3(0,row,0));}
float4 outsidePacket(){
 float4 tail=total(8)-total(9),bound=max((abs(total(8))+abs(total(9)))*128*1.1920928955078125e-7,1e-9);
 if(abs(tail.r)<=bound.r&&all(abs(tail)<=bound))tail=0;
 return tail;
}
float4 stepRow(uint row){float4 v=total(row);if(row==7u)v+=outsidePacket();return v;}
float4 cumulativeRow(uint row){
 float4 result=txPreviousLedger.Load(int3(0,row,0));
 if(row==1u)result=total(1);else if(row>1u)result+=stepRow(row);
 return result;
}
bool ledgerPacket(uint row,float4 p){
 bool result=packetValid(p);
 if(row==3u)result=all(isfinite(p))&&p.r>=0&&all(p.yzw==0);
 else if(row==4u||row==5u)result=all(isfinite(p))&&p.r==0;
 return result;
}
bool ledgerAdmission(){
 if(!context()||txStatus.Load(int3(0,0,0)).r!=0)return false;
 bool ok=true;[unroll]for(uint totalIndex=0;totalIndex<11u;totalIndex++)ok=ok&&all(isfinite(total(totalIndex)));
 float4 tail=outsidePacket(),bound=max((abs(total(8))+abs(total(9)))*128*1.1920928955078125e-7,1e-9);
 ok=ok&&packetValid(tail)&&tail.r<=total(10).r+bound.r;
 float4 sum=0,oldSum=0,newSum=0,scale=0,oldScale=0,newScale=0;
 [unroll]for(uint i=0;i<8u;i++){
  float4 v=stepRow(i),old=txPreviousLedger.Load(int3(0,i,0)),next=cumulativeRow(i);
  ok=ok&&ledgerPacket(i,v)&&ledgerPacket(i,old)&&ledgerPacket(i,next);float sign=(i==0u||i==2u||i==4u)?-1:((i==3u)?0:1);
  sum+=v*sign;oldSum+=old*sign;newSum+=next*sign;scale+=abs(v);oldScale+=abs(old);newScale+=abs(next);
 }
 float4 inventoryError=txPreviousLedger.Load(int3(0,1,0))-total(0);
 ok=ok&&all(abs(inventoryError)<=max((abs(txPreviousLedger.Load(int3(0,1,0)))+abs(total(0)))*128*1.1920928955078125e-7,1e-9));
 return ok&&all(abs(sum)<=max(scale*128*1.1920928955078125e-7,1e-9))&&all(abs(oldSum)<=max(oldScale*128*1.1920928955078125e-7,1e-9))&&all(abs(newSum)<=max(newScale*128*1.1920928955078125e-7,1e-9));
}
float4 main(PS_IN pin){return float4(ledgerAdmission()?1:0,0,0,0);}
]====]
M.gather=[====[
bool packetValid(float4 p){return all(isfinite(p))&&p.r>=0&&(p.r>0||all(p.yzw==0));}
bool integerValue(float x){return isfinite(x)&&x>=0&&x<=16777215&&floor(x)==x;}
bool dimensions(Texture2D<float4> t,uint w,uint h){uint a,b;t.GetDimensions(a,b);return a==w&&b==h;}
float4 head(uint i,uint row){return txHeads.Load(int3(i,row,0));}
bool context(){
 float4 token=txSourceHeader.Load(int3(0,0,0)),shape=txSourceHeader.Load(int3(0,1,0)),stamp=txSourceHeader.Load(int3(0,2,0));
 float4 mode=txSourceHeader.Load(int3(0,3,0)),previous=txSourceHeader.Load(int3(0,4,0));
 float4 published=txPublished.Load(int3(0,0,0)),phase=txPublished.Load(int3(0,1,0));
 float4 hh=txHeadHeader.Load(int3(0,0,0)),hg=txHeadHeader.Load(int3(0,4,0)),hf=txHeadHeader.Load(int3(0,2,0));
 bool ok=all(isfinite(token))&&integerValue(token.x)&&token.x>0&&integerValue(token.y)&&token.y>0&&integerValue(token.z)&&token.z>0&&token.w==1;
 ok=ok&&all(previous==published)&&all(previous.xy==token.xy)&&previous.z+1==token.z&&previous.w==1;
 ok=ok&&all(phase==float4(2,previous.z,0,1))&&all(txHeadReceipt.Load(int3(0,0,0))==token)&&all(hh==token);
 ok=ok&&all(shape==float4(gGrid,hg.z,gCount))&&all(hg.xy==gGrid)&&hg.z>=1&&hg.z<=16&&floor(hg.z)==hg.z;
 ok=ok&&all(isfinite(stamp))&&integerValue(stamp.x)&&stamp.x<=1048575&&stamp.y==hf.y&&integerValue(stamp.z)&&stamp.z>0&&stamp.w==1;
 ok=ok&&all(mode==float4(1,1,16,0))&&txHeadHeader.Load(int3(0,3,0)).w>0&&txHeadHeader.Load(int3(0,3,0)).w<=.05;
 ok=ok&&dimensions(txHeads,(uint)gCount,20)&&dimensions(txOriginalHeads,(uint)gCount,1)&&dimensions(txHeadReceipt,1,1)&&dimensions(txHeadHeader,1,6)&&dimensions(txFilmBirthEvent,(uint)gCount,5);
 ok=ok&&dimensions(txOriginalFilm,(uint)gGrid.x,(uint)gGrid.y)&&dimensions(txOriginalMicro,(uint)gGrid.x,(uint)gGrid.y)&&dimensions(txCells,(uint)gGrid.x,(uint)gGrid.y);
 return ok&&dimensions(txImpact,(uint)gCount,4)&&dimensions(txSourceHeader,1,5)&&dimensions(txPreviousLedger,1,8)&&dimensions(txPublished,1,2);
}
void addPacket(float4 v,inout float4 total,inout float4 error){precise float4 y=v-error,next=total+y;error=(next-total)-y;total=next;}
// Integer-width tent basis has exact partition of unity on the cell lattice.
// The line integral is quadratic on at most seven intervals; Simpson is exact
// on each. No per-frame normalization loop or CPU stamps.
float pfBasis(float2 p,float2 cell,float2 support) {
    float2 tent=saturate(1-abs(p-cell)/support);
    return tent.x*tent.y/(support.x*support.y);
}
float pfLine(float2 a,float2 b,float2 cell,float2 support) {
    if(any(max(a,b)+support<cell)||any(min(a,b)-support>cell))return 0;
    float2 d=b-a;
    float3 rx=abs(d.x)>1e-9 ? saturate((cell.x+float3(-support.x,0,support.x)-a.x)/d.x) : 1;
    float3 ry=abs(d.y)>1e-9 ? saturate((cell.y+float3(-support.y,0,support.y)-a.y)/d.y) : 1;
    float t=0,total=0;
    [loop] for(uint j=0u;j<7u;++j) {
        float next=1;
        next=min(next,rx.x>t ? rx.x : 1);next=min(next,rx.y>t ? rx.y : 1);next=min(next,rx.z>t ? rx.z : 1);
        next=min(next,ry.x>t ? ry.x : 1);next=min(next,ry.y>t ? ry.y : 1);next=min(next,ry.z>t ? ry.z : 1);
        float mid=(t+next)*.5;
        total+=(next-t)*(pfBasis(a+d*t,cell,support)+4*pfBasis(a+d*mid,cell,support)
            +pfBasis(a+d*next,cell,support))/6;
        t=next;if(t>=1)break;
    }
    return total;
}
// Production integer-tent and swept-line kernels precede this bounded sparse walk.
void evaluate(int i,float2 cell,uint bank,inout float4 total,inout float4 error){
 float4 bounds=txSources.Load(int3(i,6,0));if(any(cell<bounds.xy)||any(cell>bounds.zw))return;
 // Translation leaves the original kernel unchanged mathematically, while
 // avoiding a+delta*t rounding at large absolute atlas coordinates.
 float4 site=txSources.Load(int3(i,5,0));float w=pfBasis(site.xy-cell,0,max(site.zw,1));
 float4 v=txSources.Load(int3(i,bank==0u?3:4,0))*w;
 if(bank==0u){float4 path=txSources.Load(int3(i,1,0)),s=txSources.Load(int3(i,2,0));v+=txSources.Load(int3(i,0,0))*pfLine(path.xy-cell,path.zw-cell,0,max(s.yz,1));}
 addPacket(v,total,error);
}
float4 main(PS_IN pin){
 uint bank=min((uint)(pin.Tex.y*2),1u);int2 cell=min((int2)(float2(pin.Tex.x,frac(pin.Tex.y*2))*gGrid),(int2)gGrid-1);
 uint2 tile=(uint2)cell/(uint)gTile;float4 total=0,error=0;
 float4 summary=txSummary.Load(int3(tile.x,tile.y,0));
 [loop]for(uint channel=0u;channel<4u;channel++){
  uint words=(uint)summary[channel];
  [loop]while(words!=0u){uint b=firstbitlow(words);words&=words-1u;uint word=channel*24u+b;
   if(word<(uint)gWords){float4 mask=txMask.Load(int3(tile.x*(uint)gWords+word,tile.y,0));
    [loop]for(uint c=0u;c<4u;c++){uint bits=(uint)mask[c];
     [loop]while(bits!=0u){uint k=firstbitlow(bits);bits&=bits-1u;uint slot=word*96u+c*24u+k;if(slot<(uint)gCount)evaluate((int)slot,(float2)cell,bank,total,error);}
    }
   }
  }
 }
 return all(isfinite(total))?total:float4(-1,0,0,0);
}
]====]
M.reduceStatus=[====[
float4 main(PS_IN pin){
 int2 tile=(int2)floor(pin.Tex*ceil(gReduceSize/16));float status=0;
 [loop]for(int y=0;y<16;y++)[loop]for(int x=0;x<16;x++){
  int2 p=tile*16+int2(x,y);if(any(p>=(int2)gReduceSize))continue;
  float v=txStatus.Load(int3(p,0)).r;status=max(status,isfinite(v)?v:1);
 }return float4(status,0,0,0);
}
]====]
M.reduceTotals=[====[
bool packetValid(float4 p){return all(isfinite(p))&&p.r>=0&&(p.r>0||all(p.yzw==0));}
bool integerValue(float x){return isfinite(x)&&x>=0&&x<=16777215&&floor(x)==x;}
bool dimensions(Texture2D<float4> t,uint w,uint h){uint a,b;t.GetDimensions(a,b);return a==w&&b==h;}
void addPacket(float4 v,inout float4 total,inout float4 error){precise float4 y=v-error,next=total+y;error=(next-total)-y;total=next;}
float4 main(PS_IN pin){
 uint bank=min((uint)(pin.Tex.y*11),10u);int2 p=(int2)(float2(pin.Tex.x,frac(pin.Tex.y*11))*ceil(gTotalTiles/16));float4 sum=0,error=0;
 [loop]for(int y=0;y<16;y++)[loop]for(int x=0;x<16;x++){int2 q=p*16+int2(x,y);if(all(q<(int2)gTotalTiles))addPacket(txTotals.Load(int3(q+int2(0,(int)bank*(int)gTotalTiles.y),0)),sum,error);}
 return sum;
}
]====]
M.sources=[====[
bool packetValid(float4 p){return all(isfinite(p))&&p.r>=0&&(p.r>0||all(p.yzw==0));}
bool integerValue(float x){return isfinite(x)&&x>=0&&x<=16777215&&floor(x)==x;}
bool dimensions(Texture2D<float4> t,uint w,uint h){uint a,b;t.GetDimensions(a,b);return a==w&&b==h;}
float4 head(uint i,uint row){return txHeads.Load(int3(i,row,0));}
bool context(){
 float4 token=txSourceHeader.Load(int3(0,0,0)),shape=txSourceHeader.Load(int3(0,1,0)),stamp=txSourceHeader.Load(int3(0,2,0));
 float4 mode=txSourceHeader.Load(int3(0,3,0)),previous=txSourceHeader.Load(int3(0,4,0));
 float4 published=txPublished.Load(int3(0,0,0)),phase=txPublished.Load(int3(0,1,0));
 float4 hh=txHeadHeader.Load(int3(0,0,0)),hg=txHeadHeader.Load(int3(0,4,0)),hf=txHeadHeader.Load(int3(0,2,0));
 bool ok=all(isfinite(token))&&integerValue(token.x)&&token.x>0&&integerValue(token.y)&&token.y>0&&integerValue(token.z)&&token.z>0&&token.w==1;
 ok=ok&&all(previous==published)&&all(previous.xy==token.xy)&&previous.z+1==token.z&&previous.w==1;
 ok=ok&&all(phase==float4(2,previous.z,0,1))&&all(txHeadReceipt.Load(int3(0,0,0))==token)&&all(hh==token);
 ok=ok&&all(shape==float4(gGrid,hg.z,gCount))&&all(hg.xy==gGrid)&&hg.z>=1&&hg.z<=16&&floor(hg.z)==hg.z;
 ok=ok&&all(isfinite(stamp))&&integerValue(stamp.x)&&stamp.x<=1048575&&stamp.y==hf.y&&integerValue(stamp.z)&&stamp.z>0&&stamp.w==1;
 ok=ok&&all(mode==float4(1,1,16,0))&&txHeadHeader.Load(int3(0,3,0)).w>0&&txHeadHeader.Load(int3(0,3,0)).w<=.05;
 ok=ok&&dimensions(txHeads,(uint)gCount,20)&&dimensions(txOriginalHeads,(uint)gCount,1)&&dimensions(txHeadReceipt,1,1)&&dimensions(txHeadHeader,1,6)&&dimensions(txFilmBirthEvent,(uint)gCount,5);
 ok=ok&&dimensions(txOriginalFilm,(uint)gGrid.x,(uint)gGrid.y)&&dimensions(txOriginalMicro,(uint)gGrid.x,(uint)gGrid.y)&&dimensions(txCells,(uint)gGrid.x,(uint)gGrid.y);
 return ok&&dimensions(txImpact,(uint)gCount,4)&&dimensions(txSourceHeader,1,5)&&dimensions(txPreviousLedger,1,8)&&dimensions(txPublished,1,2);
}
void addPacket(float4 v,inout float4 total,inout float4 error){precise float4 y=v-error,next=total+y;error=(next-total)-y;total=next;}
#define gFilmGrid gGrid
#define gFilmPad 0
#define gPoolOn 1
#define gPoolCount gCount
#define gPoolTick txSourceHeader.Load(int3(0,2,0)).x
#define txFilmPrevious txOriginalFilm
// P4b bounded, unique region -> slot ownership. Counts and tick are integers.
uint poolTilesX() {return ((uint)gFilmGrid.x+15u)/16u;}
uint poolTileCount() {return poolTilesX()*(((uint)gFilmGrid.y+15u)/16u);}
uint poolRotation() {
    uint groups=((uint)max(gPoolCount,1)+poolTileCount()-1u)/poolTileCount();
    // Advance region rotation after a complete slot-group cycle. Using tick
    // directly aliases groups/regions at common counts such as 4096 slots.
    return ((uint)gPoolTick/groups)%poolTileCount();
}
uint poolOwner(uint tile) {
    uint tiles=poolTileCount(),count=(uint)max(gPoolCount,1),tick=(uint)gPoolTick;
    uint group=tick%((count+tiles-1u)/tiles);
    return group*tiles+(tile+tiles-poolRotation())%tiles;
}
// Eight rows: trail packet/path/support, film/micro impact packets, incident
// centre/support, union bounds, status/possible off-domain support.
float4 main(PS_IN pin){
 uint i=min((uint)(pin.Tex.x*gCount),(uint)gCount-1),row=min((uint)(pin.Tex.y*8),7u);float code=1;
 float4 result=0,trail=0,path=0,support=0,film=0,micro=0,site=0;float2 low=1e9,high=-1e9;
 if(context()){
  bool ok=all(head(i,13)==float4(0,(float)i,0,0))&&packetValid(txOriginalHeads.Load(int3(i,0,0)))&&all(head(i,0)==txOriginalHeads.Load(int3(i,0,0)));
  [unroll]for(uint dataRow=0;dataRow<20u;dataRow++)ok=ok&&all(isfinite(head(i,dataRow)));
  [unroll]for(uint packetRow=0;packetRow<8u;packetRow++)ok=ok&&packetValid(head(i,packetRow));
  float4 input=txImpact.Load(int3(i,0,0)),bounce=txImpact.Load(int3(i,3,0));film=txImpact.Load(int3(i,1,0));micro=txImpact.Load(int3(i,2,0));
  ok=ok&&packetValid(input)&&packetValid(bounce)&&packetValid(film)&&packetValid(micro);
  ok=ok&&input.r==head(i,11).r&&film.r==head(i,8).r&&micro.r==head(i,9).r&&bounce.r==head(i,10).r;
  ok=ok&&head(i,12).r==0&&head(i,19).r==0&&all(head(i,4).yzw==0);
  float4 born=txFilmBirthEvent.Load(int3(i,0,0)),pool=txFilmBirthEvent.Load(int3(i,4,0));
  ok=ok&&all(isfinite(born))&&all(isfinite(pool))&&pool.z==head(i,4).r&&born.z==head(i,3).r+head(i,4).r;
  if(pool.z>0){
   int2 p=(int2)floor(float2(born.x,born.y+1)*gGrid);
   ok=ok&&head(i,0).r==0&&all(p>=0)&&all(p<(int2)gGrid);
   uint tile=(uint)p.y/16u*poolTilesX()+(uint)p.x/16u;ok=ok&&poolOwner(tile)==i;
  }
  trail=head(i,5);path=head(i,14)-txSourceHeader.Load(int3(0,1,0)).z;
  support=head(i,15);site=head(i,16);site.xy-=txSourceHeader.Load(int3(0,1,0)).z;site.zw=head(i,17).xy;
  if(trail.r>0){ok=ok&&all(support.yz>=1)&&all(support.yz<=16)&&all(floor(support.yz)==support.yz);low=min(path.xy,path.zw)-support.yz;high=max(path.xy,path.zw)+support.yz;}
  if(film.r+micro.r>0){
   float pad=txSourceHeader.Load(int3(0,1,0)).z;float2 incident=float2(pool.x,pool.y+1)*gGrid+pad-.5;
   ok=ok&&all(head(i,16).xy==incident)&&all(head(i,16).zw==float2(film.r,micro.r));
   ok=ok&&all(site.zw>=1)&&all(site.zw<=16)&&all(floor(site.zw)==site.zw);low=min(low,site.xy-site.zw);high=max(high,site.xy+site.zw);
  }
  code=ok?0:2;
 }
 if(code==0){if(row==0u)result=trail;else if(row==1u)result=path;else if(row==2u)result=support;else if(row==3u)result=film;else if(row==4u)result=micro;else if(row==5u)result=site;}
 if(row==6u)result=code==0?float4(low,high):float4(1e9,1e9,-1e9,-1e9);
 if(row==7u)result=float4(code,code==0&&(any(low<0)||any(high>gGrid-1))?1:0,0,0);
 return result;
}
]====]
M.status=[====[
float4 main(PS_IN pin){
 int2 p=min((int2)(pin.Tex*gStatusSize),(int2)gStatusSize-1);float bad=0;
 if(p.y<(int)gGrid.y)bad=txStaged.Load(int3(p+int2(0,6*(int)gGrid.y),0)).r;
 else{int i=(p.y-(int)gGrid.y)*(int)gStatusSize.x+p.x;if(i<(int)gCount)bad=txSources.Load(int3(i,7,0)).r;}
 return float4(bad,0,0,0);
}
]====]
M.summary=[====[
float4 main(PS_IN pin)
{
    uint x = (uint)floor(pin.Tex.x * gSummaryW);
    uint ty = (uint)floor(pin.Tex.y * gTilesY);
    uint tx = x / (uint)gSummaryWords;
    uint block = x - tx * (uint)gSummaryWords;
    uint bx = 0u, by = 0u, bz = 0u, bw = 0u;
    [loop] for (uint j = 0u; j < 96u; ++j)
    {
        uint word = block * 96u + j;
        if (word >= (uint)gWords) break;
        float4 m = txMask.Load(int3(tx * (uint)gWords + word, ty, 0));
        if (m.x > 0.0 || m.y > 0.0 || m.z > 0.0 || m.w > 0.0)
        {
            uint bit = 1u << (j % 24u);
            if (j < 24) bx |= bit;
            else if (j < 48) by |= bit;
            else if (j < 72) bz |= bit;
            else bw |= bit;
        }
    }
    return float4((float)bx, (float)by, (float)bz, (float)bw);
}
]====]
M.totals=[====[
bool packetValid(float4 p){return all(isfinite(p))&&p.r>=0&&(p.r>0||all(p.yzw==0));}
bool integerValue(float x){return isfinite(x)&&x>=0&&x<=16777215&&floor(x)==x;}
bool dimensions(Texture2D<float4> t,uint w,uint h){uint a,b;t.GetDimensions(a,b);return a==w&&b==h;}
float4 head(uint i,uint row){return txHeads.Load(int3(i,row,0));}
bool context(){
 float4 token=txSourceHeader.Load(int3(0,0,0)),shape=txSourceHeader.Load(int3(0,1,0)),stamp=txSourceHeader.Load(int3(0,2,0));
 float4 mode=txSourceHeader.Load(int3(0,3,0)),previous=txSourceHeader.Load(int3(0,4,0));
 float4 published=txPublished.Load(int3(0,0,0)),phase=txPublished.Load(int3(0,1,0));
 float4 hh=txHeadHeader.Load(int3(0,0,0)),hg=txHeadHeader.Load(int3(0,4,0)),hf=txHeadHeader.Load(int3(0,2,0));
 bool ok=all(isfinite(token))&&integerValue(token.x)&&token.x>0&&integerValue(token.y)&&token.y>0&&integerValue(token.z)&&token.z>0&&token.w==1;
 ok=ok&&all(previous==published)&&all(previous.xy==token.xy)&&previous.z+1==token.z&&previous.w==1;
 ok=ok&&all(phase==float4(2,previous.z,0,1))&&all(txHeadReceipt.Load(int3(0,0,0))==token)&&all(hh==token);
 ok=ok&&all(shape==float4(gGrid,hg.z,gCount))&&all(hg.xy==gGrid)&&hg.z>=1&&hg.z<=16&&floor(hg.z)==hg.z;
 ok=ok&&all(isfinite(stamp))&&integerValue(stamp.x)&&stamp.x<=1048575&&stamp.y==hf.y&&integerValue(stamp.z)&&stamp.z>0&&stamp.w==1;
 ok=ok&&all(mode==float4(1,1,16,0))&&txHeadHeader.Load(int3(0,3,0)).w>0&&txHeadHeader.Load(int3(0,3,0)).w<=.05;
 ok=ok&&dimensions(txHeads,(uint)gCount,20)&&dimensions(txOriginalHeads,(uint)gCount,1)&&dimensions(txHeadReceipt,1,1)&&dimensions(txHeadHeader,1,6)&&dimensions(txFilmBirthEvent,(uint)gCount,5);
 ok=ok&&dimensions(txOriginalFilm,(uint)gGrid.x,(uint)gGrid.y)&&dimensions(txOriginalMicro,(uint)gGrid.x,(uint)gGrid.y)&&dimensions(txCells,(uint)gGrid.x,(uint)gGrid.y);
 return ok&&dimensions(txImpact,(uint)gCount,4)&&dimensions(txSourceHeader,1,5)&&dimensions(txPreviousLedger,1,8)&&dimensions(txPublished,1,2);
}
void addPacket(float4 v,inout float4 total,inout float4 error){precise float4 y=v-error,next=total+y;error=(next-total)-y;total=next;}
// Initial/final/external/pool/impulse/wall/evap/base-runoff/source/raster/edge-cap.
float4 main(PS_IN pin){
 uint bank=min((uint)(pin.Tex.y*11),10u);int2 tile=(int2)(float2(pin.Tex.x,frac(pin.Tex.y*11))*gTotalTiles);float4 sum=0,error=0;
 [loop]for(int y=0;y<16;y++)[loop]for(int x=0;x<16;x++){
  int2 p=tile*16+int2(x,y);if(any(p>=(int2)gStatusSize))continue;float4 v=0;
  if(p.y<(int)gGrid.y){
   if(bank==0u)v=txOriginalFilm.Load(int3(p,0))+txOriginalMicro.Load(int3(p,0));
   if(bank==1u)v=txStaged.Load(int3(p,0))+txStaged.Load(int3(p+int2(0,(int)gGrid.y),0));
   if(bank==3u)v=float4(txStaged.Load(int3(p+int2(0,5*(int)gGrid.y),0)).r,0,0,0);
   if(bank==5u)v=txStaged.Load(int3(p+int2(0,2*(int)gGrid.y),0));
   if(bank==7u)v=txStaged.Load(int3(p+int2(0,3*(int)gGrid.y),0));
   if(bank==9u)v=txStaged.Load(int3(p+int2(0,4*(int)gGrid.y),0));
  }else{
   uint i=(uint)((p.y-(int)gGrid.y)*(int)gGrid.x+p.x);
   if(i<(uint)gCount){
    if(bank==0u)v=txOriginalHeads.Load(int3(i,0,0));if(bank==1u)v=head(i,2);
    if(bank==2u)v=txImpact.Load(int3(i,0,0));if(bank==4u)v=head(i,12);
    if(bank==5u){float4 impactWall=txImpact.Load(int3(i,0,0))-head(i,3)-txImpact.Load(int3(i,1,0))-txImpact.Load(int3(i,2,0))-txImpact.Load(int3(i,3,0));impactWall.r=0;v=head(i,19)+impactWall;}
    if(bank==6u)v=head(i,6);if(bank==7u)v=head(i,7)+txImpact.Load(int3(i,3,0));
    if(bank==8u||bank==10u){v=txSources.Load(int3(i,0,0))+txSources.Load(int3(i,3,0))+txSources.Load(int3(i,4,0));if(bank==10u&&txSources.Load(int3(i,7,0)).g==0)v=0;}
   }
  }
  if(!all(isfinite(v)))v=0;addPacket(v,sum,error);
 }return sum;
}
]====]
return M
