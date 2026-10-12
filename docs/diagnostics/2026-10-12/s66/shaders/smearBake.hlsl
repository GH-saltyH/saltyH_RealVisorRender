struct PS_IN {float4 PosH:SV_POSITION;float3 PosC:TEXCOORD0;float3 NormalW:TEXCOORD1;float2 Tex:TEXCOORD2;float3 ApplyFog(float3 c){return c;}};
Texture2D txSmearSource;
SamplerState samLinearClamp;
float2 gSmearTiling;

        float channel(float2 uv,float component) {
            float4 t=txSmearSource.SampleLevel(samLinearClamp,frac(uv),0);
            return component<.5 ? t.r : t.g;
        }
        float filtered(float2 uv,float tiling,float component) {
            float2 d=float2(.003*tiling,0);
            return .2*(channel(uv,component)+channel(uv+d,component)+channel(uv-d,component)
                +channel(uv+d.yx,component)+channel(uv-d.yx,component));
        }
        float4 main(PS_IN pin):SV_TARGET {
            float2 r=pin.Tex*gSmearTiling.x,g=pin.Tex*gSmearTiling.y;
            return float4(channel(r,0),filtered(g,gSmearTiling.y,1),filtered(r,gSmearTiling.x,0),
                txSmearSource.SampleLevel(samLinearClamp,pin.Tex,0).a);
        }