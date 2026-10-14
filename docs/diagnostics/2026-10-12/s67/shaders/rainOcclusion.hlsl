struct PS_IN {float4 PosH:SV_POSITION;float3 PosC:TEXCOORD0;float3 NormalW:TEXCOORD1;float2 Tex:TEXCOORD2;float3 ApplyFog(float3 c){return c;}};
Texture2D txNativeDepth;
Texture2D txSceneDepth;
SamplerState samPointClamp;
float gFar;
float gNative;
float gNear;
float gReversed;

        float4 main(PS_IN pin):SV_TARGET {
            uint w=1u,h=1u;txSceneDepth.GetDimensions(w,h);
            float d=txSceneDepth.Load(int3(clamp(int2(pin.Tex*float2(w,h)),int2(0,0),int2(w-1,h-1)),0)).r;
            if(gReversed>.5)d=1-d;
            float z=d>.99999 ? 10000 : gNear*gFar/max(gFar-d*(gFar-gNear),1e-7);
            float native=gNative>.5 ? txNativeDepth.SampleLevel(samPointClamp,pin.Tex,0).r : 0;
            return float4(z,native,0,1);
        }