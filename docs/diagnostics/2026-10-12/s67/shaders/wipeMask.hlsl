struct PS_IN {float4 PosH:SV_POSITION;float3 PosC:TEXCOORD0;float3 NormalW:TEXCOORD1;float2 Tex:TEXCOORD2;float3 ApplyFog(float3 c){return c;}};
Texture2D txWipePrevious;
Texture2D txWipeSwept;
SamplerState samLinearClamp;
float gRidgeDecay;
float gWipeDecay;
float gWipeSwept;

            float4 main(PS_IN pin):SV_TARGET
            {
                float4 previous = txWipePrevious.SampleLevel(
                    samLinearClamp, pin.Tex, 0.0);
                float r = previous.r * gRidgeDecay;
                float g = previous.g * gWipeDecay;
                // Current GPU transport segments cover every moving drop,
                // independent of CPU readback age and the 384-stamp budget.
                if(gWipeSwept>.5) {
                    float swept=txWipeSwept.SampleLevel(samLinearClamp,pin.Tex,0).a;
                    g=max(g,.95*smoothstep(0,.1,swept));
                }
                return float4(r < 0.004 ? 0.0 : r, g < 0.004 ? 0.0 : g,
                    0.0, 1.0);
            }
        