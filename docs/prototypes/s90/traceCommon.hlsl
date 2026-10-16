// OFFLINE: frozen, continuous piecewise-linear Eulerian velocity characteristics.
// Input velocity BA is interval-average UV/s from the s88 predictor.
// Static runs RG/BA: valid connected row/column half-open cell ranges.
int2 trPixel(int lane,int row) {return gTraceAxis<.5 ? int2(lane,row) : int2(row,lane);}
float2 trRun(int2 p) {
    float4 a=txTraceRuns.Load(int3(p,0));return gTraceAxis<.5 ? a.rg : a.ba;
}
float trCell(int lane,int row) {
    int2 p=trPixel(lane,row);float4 run=txTraceRuns.Load(int3(p,0));
    float result=0;
    if(all(p>=0)&&all(p<(int2)gTraceGrid)&&run.x>=0) {
        float4 velocity=txTraceVelocity.Load(int3(p,0));
        result=gTraceAxis<.5 ? velocity.b*gTraceGrid.x : velocity.a*gTraceGrid.y;
    }
    return result;
}
bool trSupported(int lane,int row) {
    int2 p=trPixel(lane,row);
    bool result=false;
    if(all(p>=0)&&all(p<(int2)gTraceGrid))result=txTraceRuns.Load(int3(p,0)).x>=0;
    return result;
}
float trFace(int face,int row) {
    bool left=trSupported(face-1,row),right=trSupported(face,row);
    float result=0;
    if(left&&right)result=.5*(trCell(face-1,row)+trCell(face,row));
    else if(left)result=trCell(face-1,row);
    else if(right)result=trCell(face,row);
    return result;
}
float trPhi(float x) {
    return abs(x)<.01 ? 1+x*.5+x*x/6+x*x*x/24 : (exp(x)-1)/x;
}
// Status: 0 accepted; 1 traversal exhausted; 2 collapsed map; 3 invalid input.
float4 trAdvance(float start,int row,float2 run) {
    float x=start,remaining=max(gTraceDt,0),visits=0;
    [loop]for(int iteration=0;iteration<128;++iteration) {
        if(remaining<=0)return float4(x,0,visits,0);
        if(iteration>=(int)gTraceMaxVisits)break;
        visits+=1;
        // A source belongs to exactly one valid segment. Continue outside it
        // only to account for outflow; deposition is clipped to that segment.
        float edgeVelocity=x<=run.x ? trFace((int)run.x,row) : trFace((int)run.y,row);
        if((x<=run.x&&edgeVelocity<0)||(x>=run.y&&edgeVelocity>0))
            return float4(x+edgeVelocity*remaining,0,visits,0);
        int cell=clamp((int)floor(x),(int)run.x,(int)run.y-1);
        float v0=trFace(cell,row),v1=trFace(cell+1,row);
        float velocity=lerp(v0,v1,x-cell);
        if(!isfinite(velocity))return float4(start,3,visits,0);
        if(velocity==0)return float4(x,0,visits,0);
        bool positive=velocity>0;
        if(!positive && x==(float)cell) {
            cell=max(cell-1,(int)run.x);v0=trFace(cell,row);v1=trFace(cell+1,row);
            velocity=lerp(v0,v1,x-cell);
        }
        float lo=(float)cell,hi=lo+1,slope=v1-v0;
        // Exact affine blocks reduce uniform long travel to O(distance/16).
        int block=cell>>4;
        float4 affine=txTraceBlocks.Load(int3(block,row,0));
        float blockLo=(float)(block*16),blockHi=min(blockLo+16,gTraceLanes);
        if(affine.w>0 && blockLo>=run.x && blockHi<=run.y) {
            lo=blockLo;hi=blockHi;slope=affine.y;
            velocity=affine.x+slope*(x-lo);
        }
        float edge=positive ? hi : lo;
        float endVelocity=velocity+slope*(edge-x);
        float crossing=1e30;
        if(velocity*endVelocity>0) {
            // log(1+z)/z series keeps nearly uniform cells well conditioned.
            float z=(endVelocity-velocity)/velocity;
            float factor=abs(z)<.01 ? 1-z*.5+z*z/3-z*z*z/4 : log(abs(endVelocity/velocity))/z;
            crossing=(edge-x)/velocity*factor;
        } else if(slope==0)crossing=(edge-x)/velocity;
        if(crossing>0 && crossing<=remaining) {
            x=edge;remaining-=crossing;
        } else {
            float move=velocity*remaining*trPhi(slope*remaining);
            x+=move;
            return isfinite(x) ? float4(x,0,visits,0) : float4(start,3,visits,0);
        }
    }
    return float4(start,1,visits,0); // Speculative failure; caller must not publish it.
}
