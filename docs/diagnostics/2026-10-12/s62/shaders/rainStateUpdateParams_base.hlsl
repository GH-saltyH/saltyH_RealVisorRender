struct PS_IN {float4 PosH:SV_POSITION;float3 PosC:TEXCOORD0;float3 NormalW:TEXCOORD1;float2 Tex:TEXCOORD2;float3 ApplyFog(float3 c){return c;}};
Texture2D txRainBoundaryMask;
Texture2D txRainDu;
Texture2D txRainDv;
Texture2D txRainMergeCmd;
Texture2D txRainPhysicalSites;
Texture2D txRainSpawnAtlas;
Texture2D txRainState;
Texture2D txRainStateMeta;
Texture2D txRainSurfaceNormal;
Texture2D txRainWetPath;

float3 gRainAcceleration;
float gRainAirDensity;
float gRainAirDragCoeff;
float3 gRainAirVelocityWorld;
float gRainAirflowDownwardGain;
float gRainAirflowDownwardMode;
float gRainAirflowGain;
float gRainAttractGain;
float gRainAttractReach;
float gRainBirthHold;
float gRainBirthRamp;
float gRainCoatAdhesion;
float gRainForceMask;
float gRainGlassExtraDrag;
float gRainGravityGain;
float gRainInertiaGain;
float gRainMergeEnabled;
float gRainMergeMaxDiameterMM;
float gRainMergeReach;
float gRainMetersPerUnit;
float4x4 gRainObjectToWorld;
float gRainPhysicsAccelScale;
float gRainReferencePerMM;
float gRainSpawnAtlasEnabled;
float gRainStateAdhesionMax;
float gRainStateAdhesionMin;
float gRainStateCount;
float gRainStateDeltaTime;
float gRainStateFlowAcceleration;
float gRainStateFlowDrag;
float gRainStateFlowSpeedScale;
float gRainStateGravity;
float gRainStateInit;
float gRainStateKineticAdhesionFraction;
float gRainStateLifecycle;
float gRainStateMobileDrag;
float gRainStateMobileSpeedMultiplier;
float gRainStateMobileThresholdUV;
float gRainStateMovingForceGain;
float gRainStatePhysicalDiameterUVPerMM;
float gRainStatePhysicalGridTest;
float gRainStatePhysicalMaxSpeed1MM;
float gRainStatePhysicalMaxSpeedExponent;
float gRainStatePhysicalTest;
float gRainStatePhysics;
float2 gRainStateSingleDropPosition;
float gRainStateSingleDropTest;
float gRainStateTravelMix;
float gRainSteerTurnRate;
float gRainWetPathAhead;
float gRainWetPathGain;
float gRainWetPathMinSpeed;
float2 gRainWetPathTexel;
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
    [loop] for(int step=0;step<128;++step) {
        if(remaining<=1e-7)break;
        float speed=rainMetricLength(position,velocity);
        if(speed<1e-9)break;
        float texelSpeed=max(abs(velocity.x)*maskSize.x,abs(velocity.y)*maskSize.y);
        float safe=rainMetricTap(txRainDu,float2(position.x,position.y+1)).a;
        float safePixels=max(.5,(safe-1)*.75);
        float h=min(remaining,min(safePixels/max(texelSpeed,1e-9),gRainReferencePerMM/max(speed,1e-9)));
        float2 next=position+velocity*h;
        if(rainValid(next)<.5)return float4(2,2,0,0);
        float3 u,v;rainMetric(position,u,v);
        float3 momentum=(u*velocity.x+v*velocity.y)/gRainMetersPerUnit;
        float2 transported=rainMetricProject(next,momentum);
        float movedSpeed=rainMetricLength(next,transported);
        velocity=movedSpeed>1e-9 ? transported*(speed/movedSpeed) : float2(0,0);
        position=next;remaining-=h;
    }
    if(remaining>1e-7 && rainMetricLength(position,velocity)>1e-9)return float4(2,2,0,0);
    return float4(position,velocity);
}

        SamplerState samPointRain {
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

        float2 rainStateSpawnHash(float seed)
        {
            float n = fmod(seed, 4096.0);
            float3 p = frac(float3(n, n + 19.19, n + 71.71)
                * float3(0.1031, 0.11369, 0.13787));
            p += dot(p, p.yzx + 33.33);
            return frac((p.xx + p.yz) * p.zy);
        }

        /*
            The supplied boundary mask uses the same mesh UV space as the
            visor surface-normal texture:
                A >= 0.5 : valid droplet surface
                A <  0.5 : outside / invalid

            Persistent state position is already raw visor UV. The boundary mask is sampled directly in that coordinate system.
        */
        float rainStateBoundaryMask(float2 position) { return rainValid(position); }

        /*
            Spread initial positions across the visor. On later births,
            compare valid candidates against a bounded sample of living
            drops, so short lifetimes do not repeatedly fill a few spots.
            Only births pay for the additional texture reads.
        */
        float2 rainStateFindValidPosition(
            float stateIndex,
            float cycleSeed,
            float2 previousPosition
        )
        {
            // Offline sites already satisfy alpha and real-area coverage.
            // One deterministic permutation avoids 128 candidate searches
            // and 16 live-state probes per candidate on every wet birth.
            uint site=((uint)stateIndex*73u+(uint)cycleSeed*211u)&8191u;
            float4 physicalSite=txRainPhysicalSites.Load(int3(site,0,0));
            float2 candidate=float2(physicalSite.x,physicalSite.y-1);
            float2 result=float2(2,2);
            if(physicalSite.a>.5 && rainStateBoundaryMask(candidate)>=.5)
                result=candidate;
            else if(rainStateBoundaryMask(previousPosition)>=.5)
                result=previousPosition;
            return result;
        }

        /*
            Stage 7C physical max-speed model.

            Research reference:
                V_terminal(D) ~= 3.778 * D^0.67

            D is diameter in millimeters and V is free-fall speed in m/s.
            That relationship is NOT copied as an absolute visor speed.
            Only the observed size dependence is retained. The 1 mm surface
            speed is calibrated independently in Lua as UV/s.

            Radius uses the retained reference unit (default 0.0029296875
            per 1 mm diameter), independent of the current KN5 UV scale.
            The geometry metric supplies the real metres-to-UV conversion.
        */
        float rainStatePhysicalMaxSpeed(
            float radius
        )
        {
            if (radius <= 0.000001)
            {
                return 0.0;
            }

            float diameterUV =
                radius * 2.0;

            float diameterMM =
                diameterUV
                / max(
                    gRainStatePhysicalDiameterUVPerMM,
                    0.000001
                );

            diameterMM =
                clamp(
                    diameterMM,
                    0.5,
                    6.0
                );

            float sizeFactor =
                pow(
                    diameterMM,
                    gRainStatePhysicalMaxSpeedExponent
                );

            return
                max(
                    gRainStatePhysicalMaxSpeed1MM,
                    0.0
                )
                * sizeFactor;
        }

        float rainStateMaxSpeedValue(
            float radius
        )
        {
            return rainStatePhysicalMaxSpeed(radius);
        }

        float3 rainStateNormalWorld(float2 p) {
            float3 n = txRainSurfaceNormal.SampleLevel(
                samLinearRain, float2(p.x,p.y+1.0), 0.0
            ).rgb * 2.0 - 1.0;

            n = normalize(n);
            return normalize(mul(n, (float3x3)gRainObjectToWorld));
        }

        float2 rainStateProjectForce(float3 forceWorld, float2 position) {
            float scale=max(length(gRainObjectToWorld[0].xyz),1e-6);
            return rainMetricProject(position,mul(forceWorld,transpose((float3x3)gRainObjectToWorld))/scale);
        }

        /*
            Consolidated baseline external force entry point.

            Gravity and vehicle acceleration are part of the persistent
            physics baseline. Air drag is intentionally kept outside this
            function because the verified Debug 31 airflow value is an
            incoming relative-air velocity, not a complete drag force.
            Production drag must oppose the droplet's surface velocity.
        */
        /*
            s61: velocity is raw KN5 UV per second. Radius and speed
            controls retain the legacy reference unit; baked dP/dU and
            dP/dV convert through metres. No UV axis is assumed to be
            horizontal, vertical or orthogonal.
        */
        /*
            Unified external-force pipeline.

            Source domains:
              Gravity  : world m/s^2, directed by the simulation gravity.
              Inertia  : world m/s^2, already sign-inverted in Lua from the
                         vehicle's car-local G acceleration.
              Airflow  : world-relative air velocity, converted here to an
                         aerodynamic acceleration using SI water-drop mass.

            Bitmask:
              1 = gravity
              2 = vehicle inertia
              4 = airflow

            All enabled sources are summed in WORLD space first. Only then is
            the single surface-normal/tangent projection performed.
        */
        float3 rainStateAirflowAccelerationWorld(
            float3 normalWorld,
            float radius
        )
        {
            float speed = length(gRainAirVelocityWorld);
            if (speed < 0.0001)
                return float3(0.0, 0.0, 0.0);

            float diameterMM =
                max(
                    (radius * 2.0)
                    / max(gRainStatePhysicalDiameterUVPerMM, 0.000001),
                    0.0
                );

            float diameterM = diameterMM * 0.001;
            float radiusM = diameterM * 0.5;
            float area = 3.14159265 * radiusM * radiusM;
            float volume = (4.0 / 3.0) * 3.14159265 * radiusM * radiusM * radiusM;
            float massKg = max(volume * 1000.0, 0.000000000001);

            float3 airDir = gRainAirVelocityWorld / speed;

            /*
                One-sided surface incidence:
                the air must travel into the surface normal side.
                The normal component is ultimately cancelled by the rigid
                visor; the incidence factor controls aerodynamic pressure.
            */
            float incidence =
                saturate(
                    -dot(
                        airDir,
                        normalWorld
                    )
                );

            if (incidence <= 0.000001)
                return float3(0.0, 0.0, 0.0);

            float dragForce =
                0.5
                * max(gRainAirDensity, 0.0)
                * speed
                * speed
                * max(gRainAirDragCoeff, 0.0)
                * area
                * incidence;

            return
                (gRainAirVelocityWorld / speed)
                * (dragForce / massKg);
        }

        float3 rainStateExternalForceWorld(
            float3 normalWorld,
            float radius,
            out float3 airWorld
        )
        {
            float3 forceWorld = float3(0.0, 0.0, 0.0);
            airWorld = float3(0.0, 0.0, 0.0);

            if (fmod(floor(gRainForceMask), 2.0) >= 0.5)
                forceWorld +=
                    float3(0.0, -gRainStateGravity, 0.0)
                    * gRainPhysicsAccelScale * gRainGravityGain;

            if (fmod(floor(gRainForceMask / 2.0), 2.0) >= 0.5)
                forceWorld +=
                    gRainAcceleration
                    * gRainPhysicsAccelScale * gRainInertiaGain;

            if (fmod(floor(gRainForceMask / 4.0), 2.0) >= 0.5)
            {
                airWorld =
                    rainStateAirflowAccelerationWorld(
                        normalWorld,
                        radius
                    )
                    * gRainPhysicsAccelScale * gRainAirflowGain;
                forceWorld += airWorld;
            }

            return forceWorld;
        }

        float2 rainStateSurfaceForce(float2 position,float radius,out float forceMagnitude) {
            float3 normalWorld=rainStateNormalWorld(position),airWorld;
            float3 forceWorld=rainStateExternalForceWorld(normalWorld,radius,airWorld);
            // Optional downward airflow is a physical gravity-tangent component.
            // UV V can face any direction; never force a signed V movement.
            if(gRainStateLifecycle>.5 && gRainAirflowDownwardMode>.5) {
                float3 down=float3(0,-1,0);down-=normalWorld*dot(down,normalWorld);
                float l=length(down);
                if(l>1e-6) forceWorld+=down/l*min(length(airWorld)*.30*gRainAirflowDownwardGain,
                    max(gRainStateGravity*gRainPhysicsAccelScale,.1)*(1+min(length(gRainAirVelocityWorld)/20,4)*gRainAirflowDownwardGain));
            }
            forceWorld-=normalWorld*dot(forceWorld,normalWorld);
            forceMagnitude=length(forceWorld);
            return rainStateProjectForce(forceWorld,position);
        }

        float rainStateAdhesion(
            float stateIndex,
            float mass
        )
        {
            float adhesionBase =
                lerp(
                    gRainStateAdhesionMin,
                    gRainStateAdhesionMax,
                    rainStateHash(stateIndex + 211.0)
                );

            return
                adhesionBase
                / sqrt(max(mass, 0.000001));
        }

        float2 rainStateFlowAcceleration(
            float2 tangentForce,
            float forceMagnitude,
            float adhesion,
            float dt
        )
        {
            float excess =
                max(
                    forceMagnitude - adhesion,
                    0.0
                );

            if (
                excess <= 0.000001
                || forceMagnitude <= 0.000001
            )
            {
                return float2(0.0, 0.0);
            }

            float2 direction =
                tangentForce
                / forceMagnitude;

            /*
                Flow acceleration is already expressed in normalized
                persistent-state coordinates. Do not divide it by the
                procedural UV cell scale: that scale describes the rain
                pattern density, not the physical state coordinate unit.

                Keeping these domains separate is important because an
                increase in procedural cell density must not make a real
                droplet physically slower.
            */
            float acceleration =
                excess
                * gRainStateFlowAcceleration
                * max(gRainStateFlowSpeedScale, 0.0);

            return
                direction
                * acceleration
                * dt;
        }

        float2 rainStateApplyDrag(
            float2 velocity,
            float forceMagnitude,
            float adhesion,
            float dt,
            float mobile
        )
        {
            // Ordinary flow drag and kinetic adhesion apply from birth.
            float drag = lerp(gRainStateFlowDrag,
                max(gRainStateMobileDrag, 0.0), mobile);

            if (forceMagnitude <= adhesion && mobile < 0.5)
            {
                velocity *=
                    exp(
                        -drag
                        * 2.0
                        * dt
                    );
            }

            velocity *=
                exp(
                    -max(drag, 0.0)
                    * dt
                );

            return velocity;
        }

        float2 rainStateClampSpeed(
            float2 velocity,
            float radius,
            float mobile, float2 position
        )
        {
            float speed =
                rainMetricLength(position,velocity);

            float maxSpeed =
                rainStateMaxSpeedValue(radius)
                * lerp(1.0,
                    max(gRainStateMobileSpeedMultiplier, 1.0),
                    mobile * gRainStateTravelMix);

            if (
                speed
                > maxSpeed
            )
            {
                velocity =
                    velocity
                    / max(
                        speed,
                        0.000001
                    )
                    * maxSpeed;
            }

            return velocity;
        }

        float2 rainStateIntegratePosition(
            float2 position,
            float2 velocity,
            float dt
        )
        {
            /*
                Persistent state coordinates are raw visor UV coordinates.
                Boundary lifecycle owns exit/death/respawn explicitly, so
                this integration function never wraps or clamps the result.
            */
            return position + velocity * dt;
        }

        float2 rainStateRespawnPosition(
            float stateIndex,
            float respawnCycle,
            float2 previousPosition
        )
        {
            float2 result=rainStateFindValidPosition(stateIndex,respawnCycle,previousPosition);
            if(gRainSpawnAtlasEnabled>.5) {
                uint count=(uint)max(gRainStateCount,1.0);
                uint site=((uint)stateIndex+(uint)respawnCycle*37u)%count;
                float4 prelaid=txRainSpawnAtlas.Load(int3(site,0,0));
                float2 pos=float2(prelaid.r,prelaid.g-1);
                if(prelaid.a>.5 && rainStateBoundaryMask(pos)>=.5)result=pos;
            }
            return result;
        }

        float4 rainStateUpdatePhysics(
            float2 position,
            float2 velocity,
            float radius,
            float mass,
            float stateIndex,
            float dt
        )
        {
            float forceMagnitude = 0.0;

            float2 tangentForce =
                rainStateSurfaceForce(
                    position,
                    radius,
                    forceMagnitude
                );

            float adhesion =
                rainStateAdhesion(
                    stateIndex,
                    mass
                ) * lerp(1.0,gRainCoatAdhesion,rainCoating(position));

            // Motion overcomes static pinning: rolling water sees a much
            // smaller resistance until it actually slows to a stop.
            float mobile = gRainStateLifecycle > 0.5
                ? smoothstep(0.001,
                    max(gRainStateMobileThresholdUV, 0.0011),
                    rainMetricLength(position,velocity)) : 0.0;
            float movingAdhesion = lerp(adhesion,
                adhesion * saturate(gRainStateKineticAdhesionFraction),
                mobile);
            float movingForce = forceMagnitude;

            velocity +=
                rainStateFlowAcceleration(
                    tangentForce,
                    movingForce,
                    movingAdhesion,
                    dt
                ) * lerp(1.0,
                    max(gRainStateMovingForceGain, 0.0), mobile);

            velocity =
                rainStateApplyDrag(
                    velocity,
                    forceMagnitude,
                    movingAdhesion,
                    dt,
                    mobile
                );

            velocity =
                rainStateClampSpeed(
                    velocity,
                    radius,
                    mobile, position
                );

            velocity *= exp(-gRainGlassExtraDrag*(1-rainCoating(position))*dt);
            return rainAdvance(position,velocity,dt);
        }


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
            float4 cmd = txRainMergeCmd.SampleLevel(samPointRain,
                float2((index + 0.5) / count, 0.5), 0.0);
            float code = floor(cmd.b * 255.0 + 0.5);
            float type = floor(code / 64.0);
            float genLow = code - type * 64.0;
            float partner = clamp(rainMergePartner(cmd), 0.0, count - 1.0);
            float2 puv = float2((partner + 0.5) / count, 0.5);
            pMeta = txRainStateMeta.SampleLevel(samPointRain, puv, 0.0);
            pState = txRainState.SampleLevel(samPointRain, puv, 0.0);
            float4 pCmd = txRainMergeCmd.SampleLevel(samPointRain, puv, 0.0);
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

        float rainMergeMassProfile(float diameterMM)
        {
            float volumeMin = 0.5 * 0.5 * 0.5;
            float volumeMax = 6.0 * 6.0 * 6.0;
            float volume = diameterMM * diameterMM * diameterMM;
            return lerp(1.0, 9.0, saturate((volume - volumeMin)
                / (volumeMax - volumeMin)));
        }
#endif

        float4 main(PS_IN pin):SV_TARGET {
            float count = max(gRainStateCount, 1.0);
            float index = min(floor(pin.Tex.x * count), count - 1.0);
            float2 suv = float2((index + 0.5) / count, 0.5);

            if (gRainStateInit > 0.5) {

                if (gRainStateSingleDropTest > 0.5) {
                    return float4(gRainStateSingleDropPosition.x, gRainStateSingleDropPosition.y , 0.0, 0.0);
                }

                if (gRainStatePhysicalTest > 0.5 && index < 9.0)
                {
                    float u = lerp(0.250, 0.750, index / 8.0);

                    return float4(
                        u,
                        -0.500,
                        0.0,
                        0.0
                    );
                }

                if (gRainStatePhysicalGridTest > 0.5 && index < 9.0) {
                    const float measuredX[3] = {
                        0.250, 0.500, 0.750
                    };

                    const float measuredY[3] = {
                        -0.600, -0.500, -0.450
                    };

                    uint i = (uint)index;
                    uint ix = i % 3u;
                    uint iy = i / 3u;

                    // Debug 36 test points are raw visor UV values.
                    // Legacy calibration values only constrain this fixed
                    // measurement set; they do not remap state coordinates.
                    return float4(measuredX[ix], measuredY[iy], 0.0, 0.0);
                }

                float2 p =
                    rainStateRespawnPosition(
                        index,
                        0.0,
                        float2(0.5, -0.5)
                    );

                return float4(p, 0.0, 0.0);
            }

            float4 state =
                txRainState.SampleLevel(
                    samPointRain,
                    suv,
                    0.0
                );

            float4 meta =
                txRainStateMeta.SampleLevel(
                    samPointRain,
                    suv,
                    0.0
                );

            float2 p = state.rg;
            float2 v = state.ba;
            float radius = meta.r;
            float mass = max(meta.g, 1.0);
            float dt = max(gRainStateDeltaTime, 0.0);

            /*
                Lifecycle flags in Meta.A modulo 4; the integer quotient
                identifies the current birth generation:
                    0 = dead / waiting for respawn gap
                    1 = alive
                    2 = respawn pending; consume on this state pass

                Meta.B remains the accumulated age/waiting timer.
                The respawn cycle comes from the packed generation.
            */
            if (gRainStateLifecycle > 0.5)
            {
                float generation = floor(meta.a * 0.25);
                float status = meta.a - generation * 4.0;
                if (status > 1.5)
                {
                    if (gRainStatePhysicalTest > 0.5 && index < 9.0)
                    {
                        float u = lerp(
                            0.250,
                            0.750,
                            index / 8.0
                        );

                        return float4(
                            u,
                            -0.500,
                            0.0,
                            0.0
                        );
                    }

                    float2 respawn =
                        rainStateRespawnPosition(
                            index,
                            generation + 1.0,
                            p
                        );

                    // A new lifetime begins at rest. The normal surface
                    // forces take over on the next physics update; its
                    // visual birth streak belongs to the shared UV mask.
                    return float4(respawn, 0.0, 0.0);
                }

                if (status < 0.5)
                {
                    return float4(
                        p,
                        0.0,
                        0.0
                    );
                }
            }

            // Birth hold (docs/RAINFX_IMPACT_SPLASH.md): a fresh drop rests
            // for a jittered HOLD, then its time step ramps in over RAMP, so
            // it accelerates gradually. Meta.B is the age while alive.
            {
                float holdJitter = frac(sin(index * 12.9898 + 78.233)
                    * 43758.5453);
                float holdT = gRainBirthHold * (0.6 + 0.8 * holdJitter);
                float holdK = gRainStateLifecycle > 0.5
                    ? saturate((meta.b - holdT) / max(gRainBirthRamp, 1e-3))
                    : 1.0;
                holdK = holdK * holdK * (3.0 - 2.0 * holdK);
                dt *= holdK;
                v *= holdK > 0.0 ? 1.0 : 0.0;
            }

#ifdef RAIN_MERGE_CODE
            if (gRainMergeEnabled > 0.5 && gRainStateLifecycle > 0.5)
            {
                float4 pState, pMeta;
                float4 merge = rainMergeDecode(index, count,
                    floor(meta.a * 0.25), p, radius, pState, pMeta);
                float isMerge = merge.z * (merge.x < 1.5 ? 1.0 : 0.0);
                float isAttract = merge.z * (merge.x > 1.5 ? 1.0 : 0.0);
                if (isMerge > 0.5 && merge.w < 0.5)
                    return float4(p, 0.0, 0.0); // absorbed
                // Survivor: volume-weighted centre and momentum (weights are
                // zero when not merging), so it is pulled toward the drop it
                // swallowed and changes course.
                float selfV = radius * radius * radius;
                float otherV = pMeta.r * pMeta.r * pMeta.r * isMerge;
                float total = max(selfV + otherV, 1e-15);
                float3 momentum=(rainMomentum(p,v)*selfV
                    +rainMomentum(pState.rg,pState.ba)*otherV)/total;
                p = (p * selfV + pState.rg * otherV) / total;
                if(rainValid(p)<.5)return float4(2,2,0,0);
                v = rainMetricProject(p,momentum);
                radius = lerp(radius, rainMergeRadius(radius, pMeta.r),
                    isMerge);
                mass = lerp(mass, max(rainMergeMassProfile(
                    radius / 0.00146484375), 1.0), isMerge);
                // Absorption steering toward a drop ahead.
                float2 toOther = pState.rg - p;
                float dist = rainMetricLength(p,toOther);
                float reach = max((radius + pMeta.r) * gRainAttractReach,
                    1e-7);
                float2 attractDv = toOther / max(dist, 1e-7)
                    * gRainAttractGain * saturate(1.0 - dist / reach) * dt
                    * isAttract;
                // Worm fix: at most TURN_RATE rad/s of course change.
                float attractMax = rainMetricLength(p,v) * gRainSteerTurnRate * dt;
                v += attractDv * min(1.0, attractMax
                    / max(rainMetricLength(p,attractDv), 1e-9));
            }
#endif

#ifdef RAIN_WETPATH_CODE
            // Wet-path steering (docs/RAINFX_TRAIL_FLOW.md): a pre-wetted
            // track has lower contact-angle hysteresis, so a moving drop
            // slides into it. Only the component across the motion is
            // applied (no braking, and a drop's own trail behind it is
            // symmetric). Straight-line code: no branches, no loops.
            {
                float wsp0 = rainMetricLength(p,v);
                float2 wdir0 = v / max(wsp0, 1e-7);
                // Read AHEAD of the drop: its own fresh trail lies behind.
                float2 wt = gRainWetPathTexel;
                float2 wuv = float2(p.x, p.y + 1.0) + wdir0
                    * (radius * gRainWetPathAhead + 2.0 * wt);
                float2 wg = float2(
                    txRainWetPath.SampleLevel(samLinearRain,
                        wuv + float2(wt.x, 0.0), 0.0).g
                    - txRainWetPath.SampleLevel(samLinearRain,
                        wuv - float2(wt.x, 0.0), 0.0).g,
                    txRainWetPath.SampleLevel(samLinearRain,
                        wuv + float2(0.0, wt.y), 0.0).g
                    - txRainWetPath.SampleLevel(samLinearRain,
                        wuv - float2(0.0, wt.y), 0.0).g) * 0.5;
                float wsp = rainMetricLength(p,v);
                float2 planeV=rainMetricPlane(p,v);
                float3 ju,jv;rainMetric(p,ju,jv);
                float aa=dot(ju,ju),bb=dot(ju,jv),cc=dot(jv,jv);
                float2 covector=wg/max(wt,1e-9);
                float2 gradUV=float2(cc*covector.x-bb*covector.y,aa*covector.y-bb*covector.x)
                    /max(aa*cc-bb*bb,1e-20)*gRainMetersPerUnit*gRainMetersPerUnit;
                float2 grad=rainMetricPlane(p,gradUV);
                float2 direction=planeV/max(wsp,1e-7);
                float2 lateral=grad-dot(grad,direction)*direction;
                float on=saturate(wsp/max(gRainWetPathMinSpeed,1e-6)-1);
                float2 change=lateral*(gRainWetPathGain*dt*on);
                change*=min(1,wsp*gRainSteerTurnRate*dt/max(length(change),1e-9));
                v+=rainMetricOffset(p,change);
            }
#endif

            if (gRainStatePhysics > 0.5) {
                return rainStateUpdatePhysics(
                    p,
                    v,
                    radius,
                    mass,
                    index,
                    dt
                );
            }

            return float4(p, v);
        }
    