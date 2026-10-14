// Explicit, on-demand readback only. A small regular grid separates missing
// geometry, occlusion and HDR energy without altering final optics gains.
float4 main(PS_IN pin) {
    int metric=(int)pin.PosH.x;
    if(metric==3)return txOptSunVisibility.SampleLevel(samPointClamp,float2(.5,.5),0).rrrr;
    if(metric==4)return dot(max(txOptScene.SampleLevel(samLinearClamp,float2(.5,.5),gOptSceneMaxMip).rgb,0),float3(.2126,.7152,.0722)).xxxx;
    float sum=0,count=0;
    [loop]for(int y=0;y<8;y++)[loop]for(int x=0;x<16;x++) {
        float2 uv=(float2(x,y)+.5)/float2(16,8);
        float4 hit=txOptHit.SampleLevel(samPointClamp,uv,0);
        if(metric==0){sum+=hit.a>.5?1:0;count++;continue;}
        if(hit.a<.5)continue;
        count++;
        if(metric==1)sum+=txOptAO.SampleLevel(samPointClamp,uv,0).a;
        if(metric==2)sum+=saturate(dot(txOptSH.SampleLevel(samPointClamp,uv,0),float4(.28209479,.48860251*gOptLocalLight)));
        if(metric==9)sum+=txOptRadiance.SampleLevel(samPointClamp,uv,0).a;
        if(metric>=5 && metric<=8) {
            float mip=metric==6?1:metric==7?2:metric==8?4:0;
            sum+=dot(max(txOptRadiance.SampleLevel(samPointClamp,uv,min(mip,gOptRadianceMaxMip)).rgb,0),float3(.2126,.7152,.0722));
        }
    }
    return (sum/max(count,1)).xxxx;
}
