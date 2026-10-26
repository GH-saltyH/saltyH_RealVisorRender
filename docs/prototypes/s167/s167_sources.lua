local M={}
M.tileStatus=[====[
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
void sourceCell(int2 p,out float4 next,out float4 nextMicro,out float4 wall,out float4 runoff,out float4 raw,out float4 debit,out float code){
 float4 old=txOriginalFilm.Load(int3(p,0)),oldMicro=txOriginalMicro.Load(int3(p,0)),cell=txCells.Load(int3(p,0));
 float4 incoming=txRaster.Load(int3(p,0)),micro=txRaster.Load(int3(p+int2(0,(int)gGrid.y),0));
 next=0;nextMicro=0;wall=0;runoff=0;debit=0;code=1;
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
 raw=incoming+micro;
 if(code!=0){next=0;nextMicro=0;wall=0;runoff=0;raw=0;debit=0;}
}
float4 main(PS_IN pin){
 int2 tile=(int2)floor(pin.Tex*ceil(gStatusSize/16));float status=0;
 [loop]for(int y=0;y<16;y++)[loop]for(int x=0;x<16;x++){
  int2 p=tile*16+int2(x,y);if(any(p>=(int2)gStatusSize))continue;float bad=0;
  if(p.y<(int)gGrid.y){float4 film,micro,wall,runoff,raw,debit;sourceCell(p,film,micro,wall,runoff,raw,debit,bad);}
  else{int i=(p.y-(int)gGrid.y)*(int)gStatusSize.x+p.x;if(i<(int)gCount)bad=txSources.Load(int3(i,7,0)).r;}
  status=max(status,isfinite(bad)?bad:1);
 }return float4(status,0,0,0);
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
void sourceCell(int2 p,out float4 next,out float4 nextMicro,out float4 wall,out float4 runoff,out float4 raw,out float4 debit,out float code){
 float4 old=txOriginalFilm.Load(int3(p,0)),oldMicro=txOriginalMicro.Load(int3(p,0)),cell=txCells.Load(int3(p,0));
 float4 incoming=txRaster.Load(int3(p,0)),micro=txRaster.Load(int3(p+int2(0,(int)gGrid.y),0));
 next=0;nextMicro=0;wall=0;runoff=0;debit=0;code=1;
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
 raw=incoming+micro;
 if(code!=0){next=0;nextMicro=0;wall=0;runoff=0;raw=0;debit=0;}
}
float4 main(PS_IN pin){
 uint bank=min((uint)(pin.Tex.y*11),10u);int2 tile=(int2)(float2(pin.Tex.x,frac(pin.Tex.y*11))*gTotalTiles);float4 sum=0,error=0;
 [loop]for(int y=0;y<16;y++)[loop]for(int x=0;x<16;x++){
  int2 p=tile*16+int2(x,y);if(any(p>=(int2)gStatusSize))continue;float4 v=0;
  if(p.y<(int)gGrid.y){
   if(bank==0u)v=txOriginalFilm.Load(int3(p,0))+txOriginalMicro.Load(int3(p,0));
   if(bank==1u||bank==3u||bank==5u||bank==7u||bank==9u){
    float4 film,micro,wall,runoff,raw,debit;float code;sourceCell(p,film,micro,wall,runoff,raw,debit,code);
    if(bank==1u)v=film+micro;if(bank==3u)v=float4(debit.r,0,0,0);
    if(bank==5u)v=wall;if(bank==7u)v=runoff;if(bank==9u)v=raw;
   }
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
void sourceCell(int2 p,out float4 next,out float4 nextMicro,out float4 wall,out float4 runoff,out float4 raw,out float4 debit,out float code){
 float4 old=txOriginalFilm.Load(int3(p,0)),oldMicro=txOriginalMicro.Load(int3(p,0)),cell=txCells.Load(int3(p,0));
 float4 incoming=txRaster.Load(int3(p,0)),micro=txRaster.Load(int3(p+int2(0,(int)gGrid.y),0));
 next=0;nextMicro=0;wall=0;runoff=0;debit=0;code=1;
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
 raw=incoming+micro;
 if(code!=0){next=0;nextMicro=0;wall=0;runoff=0;raw=0;debit=0;}
}
float4 main(PS_IN pin){
 bool ready=txDecision.Load(int3(0,0,0)).r==1;float4 result=0;
 if(gKind<2){int2 p=min((int2)(pin.Tex*gGrid),(int2)gGrid-1);result=gKind==0?txOriginalFilm.Load(int3(p,0)):txOriginalMicro.Load(int3(p,0));if(ready){float4 film,micro,wall,runoff,raw,debit;float code;sourceCell(p,film,micro,wall,runoff,raw,debit,code);result=gKind==0?film:micro;}}
 else if(gKind==2){uint i=min((uint)(pin.Tex.x*gCount),(uint)gCount-1);result=txOriginalHeads.Load(int3(i,0,0));if(ready)result=head(i,2);}
 else if(gKind==3){if(ready)result=stepRow(min((uint)(pin.Tex.y*8),7u));}
 else if(gKind==4){uint row=min((uint)(pin.Tex.y*8),7u);result=txPreviousLedger.Load(int3(0,row,0));if(ready)result=cumulativeRow(row);}
 else{uint row=min((uint)(pin.Tex.y*2),1u);result=txPublished.Load(int3(0,row,0));if(ready)result=row==0u?txSourceHeader.Load(int3(0,0,0)):float4(1,txSourceHeader.Load(int3(0,0,0)).z,txHeadHeader.Load(int3(0,3,0)).w,1);}
 return result;
}
]====]
return M
