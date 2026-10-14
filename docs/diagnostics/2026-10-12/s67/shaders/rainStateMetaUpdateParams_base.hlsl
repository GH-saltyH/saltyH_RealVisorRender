struct PS_IN {float4 PosH:SV_POSITION;float3 PosC:TEXCOORD0;float3 NormalW:TEXCOORD1;float2 Tex:TEXCOORD2;float3 ApplyFog(float3 c){return c;}};
Texture2D txRainBoundaryMask;
Texture2D txRainDu;
Texture2D txRainDv;
Texture2D txRainMergeCmd;
Texture2D txRainSpawnAtlas;
Texture2D txRainState;
Texture2D txRainStateMeta;

float gRainAttractReach;
float gRainMergeEnabled;
float gRainMergeMaxDiameterMM;
float gRainMergeReach;
float gRainMetersPerUnit;
float gRainReferencePerMM;
float gRainSizeBias;
float gRainSizeMaxDry;
float gRainSizeMaxHeavy;
float gRainSizeMaxLight;
float gRainSizeMaxRain;
float gRainSizeMaxRare;
float gRainSizeMinDry;
float gRainSizeMinHeavy;
float gRainSizeMinLight;
float gRainSizeMinRain;
float gRainSizeMinRare;
float gRainSizeRareChanceDry;
float gRainSizeRareChanceHeavy;
float gRainSpawnAtlasEnabled;
float gRainStateAgeMax;
float gRainStateAgeMin;
float gRainStateCount;
float gRainStateDeltaTime;
float gRainStateExposure;
float gRainStateInit;
float gRainStateLifecycle;
float gRainStateRainIntensity;
float gRainStateRespawnGapMax;
float gRainStateRespawnGapMin;
float gRainStateSingleDropTest;
float gRainStateTargetOccupancy;
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

        SamplerState samPointRainMeta {
            Filter = MIN_MAG_MIP_POINT;
            AddressU = CLAMP;
            AddressV = CLAMP;
            AddressW = CLAMP;
        };

        SamplerState samLinearRain {
            Filter = MIN_MAG_MIP_LINEAR;
            AddressU = CLAMP;
            AddressV = CLAMP;
            AddressW = CLAMP;
        };

        float rainStateHash(float n) {
            return frac(sin(n * 127.1 + 311.7) * 43758.5453);
        }

        /*
            Final physical droplet model.
            This pass retains the deterministic 0.5–6.0 mm distribution
            for diagnostic modes; weather-driven mobile births use the
            smaller-biased distribution below.
        */
        float rainStatePhysicalDiameterMM(float index)
        {
            return lerp(
                0.5,
                6.0,
                rainStateHash(index + 101.0)
            );
        }

        float rainStateBirthDiameterMM(float index, float rain)
        {
            float minimum, maximum;
            if (rain <= 0.03)
            {
                float t = saturate(rain / 0.03);
                minimum = lerp(gRainSizeMinDry, gRainSizeMinLight, t);
                maximum = lerp(gRainSizeMaxDry, gRainSizeMaxLight, t);
            }
            else if (rain <= 0.50)
            {
                float t = saturate((rain - 0.03) / 0.47);
                minimum = lerp(gRainSizeMinLight, gRainSizeMinRain, t);
                maximum = lerp(gRainSizeMaxLight, gRainSizeMaxRain, t);
            }
            else
            {
                float t = saturate((rain - 0.50) / 0.50);
                minimum = lerp(gRainSizeMinRain, gRainSizeMinHeavy, t);
                maximum = lerp(gRainSizeMaxRain, gRainSizeMaxHeavy, t);
            }
            float rareChance = lerp(gRainSizeRareChanceDry,
                gRainSizeRareChanceHeavy, saturate(rain));
            if (rainStateHash(index + 307.0) > 1.0 - rareChance)
                return lerp(gRainSizeMinRare, gRainSizeMaxRare, rainStateHash(index + 619.0));
            float randomSize = rainStateHash(index + 101.0);
            return lerp(minimum, max(minimum, maximum),
                pow(randomSize, max(gRainSizeBias, 0.1)));
        }

        float rainStatePhysicalMassProfile(float diameterMM)
        {
            float volumeMin = 0.5 * 0.5 * 0.5;
            float volumeMax = 6.0 * 6.0 * 6.0;
            float volume = diameterMM * diameterMM * diameterMM;

            return lerp(
                1.0,
                9.0,
                saturate(
                    (volume - volumeMin)
                    / (volumeMax - volumeMin)
                )
            );
        }

        /*
            The supplied boundary mask uses the same mesh UV space as the
            visor surface-normal texture:
                A >= 0.5 : valid droplet surface
                A <  0.5 : outside / invalid

            Persistent state position is already raw visor UV. The boundary mask is sampled directly in that coordinate system.
        */
        float rainStateBoundaryMask(float2 position) { return rainValid(position); }
        

        // Mass coalescence + absorption steering (docs/RAINFX_COALESCENCE.md).
        // Compiled only with RAIN_MERGE_CODE (cfg RAIN_GPU_STATE_MERGE_SHADER).
        // Per-slot command texel written by Lua from the async readback:
        // R,G = partner index (hi, lo byte), B = type * 64 + generation % 64
        // of the PARTNER (type 1 = mutual merge, 2 = attract to partner).
        // Straight-line (no early returns): FXC overflowed its stack on the
        // first, branch-heavy version inside the already large state shader.
#ifdef RAIN_MERGE_CODE
        float rainMergePartner(float4 cmd)
        {
            return floor(cmd.r * 255.0 + 0.5) * 256.0
                + floor(cmd.g * 255.0 + 0.5);
        }

        // Returns x = type (0 none), y = partner, z = valid, w = survivor.
        float4 rainMergeDecode(float index, float count, float selfGen,
            float2 selfP, float selfR, out float4 pState, out float4 pMeta)
        {
            float4 cmd = txRainMergeCmd.SampleLevel(samPointRainMeta,
                float2((index + 0.5) / count, 0.5), 0.0);
            float code = floor(cmd.b * 255.0 + 0.5);
            float type = floor(code / 64.0);
            float genLow = code - type * 64.0;
            float partner = clamp(rainMergePartner(cmd), 0.0, count - 1.0);
            float2 puv = float2((partner + 0.5) / count, 0.5);
            pMeta = txRainStateMeta.SampleLevel(samPointRainMeta, puv, 0.0);
            pState = txRainState.SampleLevel(samPointRainMeta, puv, 0.0);
            float4 pCmd = txRainMergeCmd.SampleLevel(samPointRainMeta, puv, 0.0);
            float pGen = floor(pMeta.a * 0.25);
            float pStatus = pMeta.a - pGen * 4.0;
            float pCode = floor(pCmd.b * 255.0 + 0.5);
            float pType = floor(pCode / 64.0);
            float pGenLow = pCode - pType * 64.0;
            float dist = rainMetricLength(selfP,pState.rg - selfP);
            float sumR = selfR + pMeta.r;
            float ok = (type > 0.5 ? 1.0 : 0.0)
                * (abs(partner - index) > 0.5 ? 1.0 : 0.0)
                * (abs(pStatus - 1.0) < 0.5 ? 1.0 : 0.0)
                * (abs(fmod(pGen, 64.0) - genLow) < 0.5 ? 1.0 : 0.0)
                * (gRainMergeEnabled > 0.5 ? 1.0 : 0.0);
            float mutual = (abs(pType - 1.0) < 0.5 ? 1.0 : 0.0)
                * (abs(rainMergePartner(pCmd) - index) < 0.5 ? 1.0 : 0.0)
                * (abs(fmod(selfGen, 64.0) - pGenLow) < 0.5 ? 1.0 : 0.0);
            float mergeValid = ok * mutual
                * (type < 1.5 ? 1.0 : 0.0)
                * (dist <= sumR * gRainMergeReach ? 1.0 : 0.0);
            float attractValid = ok
                * (type > 1.5 ? 1.0 : 0.0)
                * (dist > 1e-7 ? 1.0 : 0.0)
                * (dist < sumR * gRainAttractReach ? 1.0 : 0.0);
            float survivor = (selfR > pMeta.r
                || (selfR == pMeta.r && index < partner)) ? 1.0 : 0.0;
            return float4(type, partner, max(mergeValid, attractValid),
                survivor);
        }

        float rainMergeRadius(float selfR, float partnerR)
        {
            // Same contact angle: footprint radius scales with volume^(1/3).
            float merged = pow(max(selfR * selfR * selfR
                + partnerR * partnerR * partnerR, 1e-15), 1.0 / 3.0);
            return min(merged, gRainMergeMaxDiameterMM * 0.00146484375);
        }
#endif

        float4 main(PS_IN pin):SV_TARGET {
            float count = max(gRainStateCount, 1.0);
            float index = min(floor(pin.Tex.x * count), count - 1.0);
            float2 suv = float2((index + 0.5) / count, 0.5);
            
            float4 singdroptest = float4(0.0735, 3.0, 0.0, 1.0);

            if (gRainStateInit > 0.5) {
                

                if (gRainStateSingleDropTest > 0.5) {
                    // cause crashing if returning anything here
                }


                float diameterMM = gRainStateLifecycle > 0.5
                    ? rainStateBirthDiameterMM(index,
                        gRainStateRainIntensity)
                    : rainStatePhysicalDiameterMM(index);
                float radius = diameterMM * 0.00146484375;
                float mass = rainStatePhysicalMassProfile(diameterMM);

                // Rain-dependent initial population prevents a dry startup
                // from filling every slot with permanent visible drops.
                float occupancy = gRainStateTargetOccupancy;
                float allowed = rainStateHash(index + 419.0);
                float initialStatus = gRainStateLifecycle > 0.5
                    && allowed >= occupancy ? 0.0 : 1.0;
                return float4(radius, mass, 0.0, initialStatus);
            }

            float4 meta = txRainStateMeta.SampleLevel(
                samPointRainMeta, suv, 0.0
            );

            float dt = max(gRainStateDeltaTime, 0.0);

            if (gRainStateLifecycle > 0.5)
            {
                // Meta.A packs generation * 4 + status, preserving the
                // existing single-channel state and readback footprint.
                float generation = floor(meta.a * 0.25);
                float status = meta.a - generation * 4.0;
                float rain = saturate(gRainStateRainIntensity);
                if (status > 1.5)
                {
                    float nextGeneration = fmod(generation + 1.0, 4096.0);
                    meta.a = nextGeneration * 4.0 + 1.0;
                    meta.b = 0.0;

                    float diameterMM = rainStateBirthDiameterMM(
                        index + nextGeneration * 17.123, rain);

                    meta.r = diameterMM * 0.00146484375;
                    meta.g = rainStatePhysicalMassProfile(diameterMM);

                    return meta;
                }

                if (status < 0.5)
                {
                    meta.b += dt;

                    float gap01 = rainStateHash(index
                        + generation * 23.71 + 701.0);
                    float respawnGap = lerp(
                        gRainStateRespawnGapMin,
                        gRainStateRespawnGapMax, gap01);
                    // Use a stable eligibility per slot. With a new random
                    // admission for each generation, rejected slots could
                    // never retry and the alive count converged to zero.
                    float admission = gRainSpawnAtlasEnabled > 0.5
                        ? txRainSpawnAtlas.Load(int3((int)index, 0, 0)).b
                        : rainStateHash(index + 419.0);
                    float gapScale = lerp(3.0, 0.5, sqrt(rain))
                        / max(gRainStateExposure, 1.0);
                    if (rain > 0.001
                        && admission < gRainStateTargetOccupancy
                        && meta.b >= respawnGap * gapScale)
                    {
                        meta.a = generation * 4.0 + 2.0;
                    }

                    return meta;
                }

                float4 state = txRainState.SampleLevel(
                    samPointRainMeta,
                    suv,
                    0.0
                );

                float2 p = state.rg;
                float2 v = state.ba;
#ifdef RAIN_MERGE_CODE
                if (gRainMergeEnabled > 0.5
                    && txRainMergeCmd.Load(int3((int)index,0,0)).b >= (64.0/255.0)
                    && txRainMergeCmd.Load(int3((int)index,0,0)).b < (128.0/255.0))
                {
                    float4 pState, pMeta;
                    float4 merge = rainMergeDecode(index, count, generation,
                        p, meta.r, pState, pMeta);
                    float isMerge = merge.z * (merge.x < 1.5 ? 1.0 : 0.0);
                    if (isMerge > 0.5 && merge.w < 0.5)
                    {
                        // Absorbed: dead now, normal respawn gap later.
                        meta.a = generation * 4.0;
                        meta.b = 0.0;
                        return meta;
                    }
                    meta.r = lerp(meta.r, rainMergeRadius(meta.r, pMeta.r),
                        isMerge);
                    meta.g = lerp(meta.g, rainStatePhysicalMassProfile(
                        meta.r / 0.00146484375), isMerge);
                }
#endif
                // State pass checks the entire movement path and writes an
                // invalid sentinel on exit. Retire it on this pass's next
                // input without running physical integration a second time.
                bool exits=rainStateBoundaryMask(p)<.5;

                if (exits)
                {
                    meta.a = generation * 4.0;
                    meta.b = 0.0;
                    return meta;
                }

                float ageRange = lerp(gRainStateAgeMin,
                    gRainStateAgeMax,
                    rainStateHash(index + generation * 5.197 + 211.0));
                if (rain <= 0.001)
                    ageRange = min(ageRange, 2.0);
                if (meta.b + dt >= ageRange)
                {
                    meta.a = generation * 4.0;
                    meta.b = 0.0;
                    return meta;
                }
            }

            meta.b += dt;
            return meta;
        }
    