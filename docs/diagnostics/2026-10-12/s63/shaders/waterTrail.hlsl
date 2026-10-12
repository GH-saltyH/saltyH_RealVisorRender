struct PS_IN {float4 PosH:SV_POSITION;float3 PosC:TEXCOORD0;float3 NormalW:TEXCOORD1;float2 Tex:TEXCOORD2;float3 ApplyFog(float3 c){return c;}};
Texture2D txTrailBoundary;
Texture2D txTrailCoat;
Texture2D txTrailPrevious;
SamplerState samLinearClamp;
float gTrailCoatRetention;
float gTrailDecay;
float gTrailDiffuse;
float gTrailNoise;
float gTrailNoiseCells;
float gTrailSheetPersist;
float2 gTrailTexel;

            float trailHash(float2 p)
            {
                p = frac(p * float2(123.34, 456.21));
                p += dot(p, p + 45.32);
                return frac(p.x * p.y);
            }
            float trailNoise(float2 x)
            {
                float2 i = floor(x);
                float2 f = frac(x);
                f = f * f * (3.0 - 2.0 * f);
                float a = trailHash(i);
                float b = trailHash(i + float2(1.0, 0.0));
                float c = trailHash(i + float2(0.0, 1.0));
                float d = trailHash(i + float2(1.0, 1.0));
                return lerp(lerp(a, b, f.x), lerp(c, d, f.x), f.y);
            }
            float4 main(PS_IN pin):SV_TARGET
            {
                float4 previous = txTrailPrevious.SampleLevel(
                    samLinearClamp, pin.Tex, 0.0);
                // Surface-tension levelling: all channels diffuse together,
                // so the R/G and B/G ratio codes are preserved.
                float4 around = txTrailPrevious.SampleLevel(samLinearClamp,
                        pin.Tex + float2(gTrailTexel.x, 0.0), 0.0)
                    + txTrailPrevious.SampleLevel(samLinearClamp,
                        pin.Tex - float2(gTrailTexel.x, 0.0), 0.0)
                    + txTrailPrevious.SampleLevel(samLinearClamp,
                        pin.Tex + float2(0.0, gTrailTexel.y), 0.0)
                    + txTrailPrevious.SampleLevel(samLinearClamp,
                        pin.Tex - float2(0.0, gTrailTexel.y), 0.0);
                previous += (around * 0.25 - previous) * (4.0 * gTrailDiffuse);
                // Spatially varying decay: thinning tracks break into
                // beads where the noise keeps water longer.
                float n = trailNoise(pin.Tex * gTrailNoiseCells);
                // Sheet water (B/G) thins smoothly and lasts longer.
                float sheet = saturate(previous.b / max(previous.g, 1e-3));
                float k = pow(max(gTrailDecay,1e-12),
                    max(0.05, (1.0 + gTrailNoise * (1.0 - sheet)
                        * (n * 2.0 - 1.0))
                        * (1.0 - gTrailSheetPersist * sheet)));
                float coat=txTrailCoat.SampleLevel(samLinearClamp,pin.Tex,0).a;
                k=pow(max(k,1e-12),1/max(lerp(1,gTrailCoatRetention,coat),.05));
                float4 next = previous * k * step(.5,txTrailBoundary.SampleLevel(samLinearClamp,pin.Tex,0).a);
                return next.g < 0.02 ? float4(0.0, 0.0, 0.0, 0.0) : next;
            }
        