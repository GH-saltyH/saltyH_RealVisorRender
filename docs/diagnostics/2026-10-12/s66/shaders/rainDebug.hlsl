struct PS_IN {float4 PosH:SV_POSITION;float3 PosC:TEXCOORD0;float3 NormalW:TEXCOORD1;float2 Tex:TEXCOORD2;float3 ApplyFog(float3 c){return c;}};
Texture2D txRainBoundaryMask;
Texture2D txRainDu;
Texture2D txRainDv;
Texture2D txRainState;
Texture2D txRainStateMeta;
Texture2D txRainSurfaceNormal;

float3 gRainAcceleration;
float gRainAirDensity;
float gRainAirDragCoeff;
float3 gRainAirVelocityWorld;
float gRainDebug;
float gRainDebugForceArrowScale;
float gRainDebugPredictionTime;
float gRainDebugStateSpeedScale;
float gRainForceMask;
float gRainMetersPerUnit;
float4x4 gRainObjectToWorld;
float gRainPhysicsAccelScale;
float gRainReferencePerMM;
float gRainStateCount;
float gRainStateGravity;
float gRainStatePhysicalDiameterUVPerMM;
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
SamplerState samPointRain
{
    Filter = MIN_MAG_MIP_POINT;
    AddressU = CLAMP;
    AddressV = CLAMP;
    AddressW = CLAMP;
};

SamplerState samLinearRain
{
    Filter = MIN_MAG_MIP_LINEAR;
    AddressU = CLAMP;
    AddressV = CLAMP;
    AddressW = CLAMP;
};

/*
    RealVisor canonical RainFX renderer.

    Physics is no longer evaluated in this render shader.
    The authoritative persistent GPU state is produced by the Lua-managed
    RainFX state update pass:

        external forces
            -> surface projection
            -> adhesion
            -> flow acceleration
            -> surface drag
            -> physical size-dependent max speed
            -> position integration
            -> txRainState / txRainStateMeta

    This shader is display-only. It consumes that state directly.

    State:
        R,G = signed visor UV position
        B,A = surface velocity in UV/s

    Meta:
        R = physical droplet radius in visor UV
        G = physical normalized mass profile
        A = generation * 4 + lifecycle state
            0 = dead/waiting
            1 = alive
            2 = respawn pending
*/

float rainStateLifecycleStatus(float packedStatus)
{
    return packedStatus - floor(packedStatus * 0.25) * 4.0;
}

float rainCanonicalDrop(
    PS_IN pin,
    float2 position,
    float radius
)
{
    float distanceToDrop = rainMetricLength(position,pin.Tex-position);

    return 1.0 - smoothstep(
        radius * 0.30,
        radius,
        distanceToDrop
    );
}

float4 rainPersistentStateRender(
    PS_IN pin
)
{
    float count = max(gRainStateCount, 1.0);
    float result = 0.0;

    [loop]
    for (int i = 0; i < 256; ++i)
    {
        if ((float)i >= count)
            break;

        float stateIndex = (float)i;
        float2 stateUV = float2(
            (stateIndex + 0.5) / count,
            0.5
        );

        float4 state = txRainState.SampleLevel(
            samPointRain,
            stateUV,
            0.0
        );

        float4 meta = txRainStateMeta.SampleLevel(
            samPointRain,
            stateUV,
            0.0
        );

        if (abs(rainStateLifecycleStatus(meta.a) - 1.0) > 0.5)
            continue;

        result = max(
            result,
            rainCanonicalDrop(
                pin,
                state.rg,
                max(meta.r, 0.000001)
            )
        );
    }

    return float4(
        0.82,
        0.90,
        1.0,
        result * 0.35
    );
}

float3 rainDebugNormalWorld(float2 p)
{
    float3 n = txRainSurfaceNormal.SampleLevel(
        samLinearRain,
        float2(p.x,p.y+1),
        0.0
    ).rgb * 2.0 - 1.0;

    n = normalize(n);
    return normalize(mul(n, (float3x3)gRainObjectToWorld));
}

float2 rainDebugProjectWorldVector(float3 forceWorld,float2 position)
{
    float scale=max(length(gRainObjectToWorld[0].xyz),1e-6);
    return rainMetricProject(position,mul(forceWorld,transpose((float3x3)gRainObjectToWorld))/scale);
}

float3 rainDebugAirflow(float3 normalWorld, float radius)
{
    float3 air = gRainAirVelocityWorld;
    float speed = length(air);

    if (speed < 0.0001)
        return float3(0.0, 0.0, 0.0);

    float diameterMM =
        (radius * 2.0)
        / max(gRainStatePhysicalDiameterUVPerMM, 0.000001);

    float diameterM = diameterMM * 0.001;
    float radiusM = diameterM * 0.5;
    float area = 3.14159265 * radiusM * radiusM;
    float volume =
        (4.0 / 3.0)
        * 3.14159265
        * radiusM * radiusM * radiusM;
    float massKg = max(volume * 1000.0, 0.000000000001);

    float3 airDir = air / speed;
    float incidence = saturate(-dot(airDir, normalWorld));

    if (incidence <= 0.000001)
        return float3(0.0, 0.0, 0.0);

    float dragForce =
        0.5
        * max(gRainAirDensity, 0.0)
        * speed * speed
        * max(gRainAirDragCoeff, 0.0)
        * area
        * incidence;

    return airDir * (dragForce / massKg);
}

float3 rainDebugExternalForce(
    float3 normalWorld,
    float radius
)
{
    float3 forceWorld = float3(0.0, 0.0, 0.0);

    if (fmod(floor(gRainForceMask), 2.0) >= 0.5)
        forceWorld +=
            float3(0.0, -gRainStateGravity, 0.0)
            * gRainPhysicsAccelScale;

    if (fmod(floor(gRainForceMask / 2.0), 2.0) >= 0.5)
        forceWorld +=
            gRainAcceleration
            * gRainPhysicsAccelScale;

    if (fmod(floor(gRainForceMask / 4.0), 2.0) >= 0.5)
        forceWorld +=
            rainDebugAirflow(normalWorld, radius)
            * gRainPhysicsAccelScale;

    return forceWorld;
}

float4 rainNormalObjectDebug(PS_IN pin)
{
    float3 n =
        txRainSurfaceNormal.SampleLevel(
            samLinearRain,
            float2(pin.Tex.x,pin.Tex.y+1),
            0.0
        ).rgb;

    return float4(n, 1.0);
}

float4 rainNormalWorldDebug(PS_IN pin)
{
    float3 n = rainDebugNormalWorld(pin.Tex);
    return float4(n * 0.5 + 0.5, 1.0);
}

float4 rainPredictedPositionsDebug(PS_IN pin)
{
    float count = max(gRainStateCount, 1.0);
    float result = 0.0;

    [loop]
    for (int i = 0; i < 256; ++i)
    {
        if ((float)i >= count)
            break;

        float2 suv = float2(
            ((float)i + 0.5) / count,
            0.5
        );

        float4 state = txRainState.SampleLevel(
            samPointRain,
            suv,
            0.0
        );

        float4 meta = txRainStateMeta.SampleLevel(
            samPointRain,
            suv,
            0.0
        );

        if (abs(rainStateLifecycleStatus(meta.a) - 1.0) > 0.5)
            continue;

        float2 predicted =
            state.rg
            + state.ba * gRainDebugPredictionTime;

        result = max(
            result,
            rainCanonicalDrop(
                pin,
                predicted,
                max(meta.r, 0.000001)
            )
        );

        result = max(
            result,
            rainCanonicalDrop(
                pin,
                state.rg,
                max(meta.r * 0.55, 0.000001)
            )
        );
    }

    return float4(0.20, 0.85, 1.0, saturate(result));
}

float4 rainForceDirectionDebug(PS_IN pin)
{
    float count = max(gRainStateCount, 1.0);
    float result = 0.0;
    float3 forceColor = float3(1.0, 0.25, 0.05);

    [loop]
    for (int i = 0; i < 256; ++i)
    {
        if ((float)i >= count)
            break;

        float2 suv = float2(
            ((float)i + 0.5) / count,
            0.5
        );

        float4 state = txRainState.SampleLevel(
            samPointRain,
            suv,
            0.0
        );

        float4 meta = txRainStateMeta.SampleLevel(
            samPointRain,
            suv,
            0.0
        );

        if (abs(rainStateLifecycleStatus(meta.a) - 1.0) > 0.5)
            continue;

        float3 normalWorld = rainDebugNormalWorld(state.rg);
        float3 forceWorld =
            rainDebugExternalForce(
                normalWorld,
                max(meta.r, 0.000001)
            );

        float2 forceUV =
            rainDebugProjectWorldVector(
                forceWorld,
                state.rg
            );

        float magnitude = length(forceUV);
        float2 dir =
            magnitude > 0.000001
            ? forceUV / magnitude
            : float2(0.0, 0.0);

        /*
            Render the current drop plus a thin directional arrow.
            Arrow length is visualization-only and never feeds state.
        */
        float2 tip =
            state.rg
            + dir * magnitude * gRainDebugForceArrowScale;

        float2 shaft = tip - state.rg;
        float2 physicalShaft=rainMetricPlane(state.rg,shaft);
        float shaftLength=length(physicalShaft);
        float2 toPoint = rainMetricPlane(state.rg,pin.Tex-state.rg);

        float along =
            shaftLength > 0.000001
            ? dot(toPoint, physicalShaft) / (shaftLength * shaftLength)
            : 0.0;

        float2 closest =
            state.rg
            + shaft * saturate(along);

        float shaftMask =
            1.0
            - smoothstep(
                max(meta.r * 0.20, 0.00015),
                max(meta.r * 0.60, 0.00030),
                rainMetricLength(state.rg,pin.Tex-closest)
            );

        float dropMask =
            rainCanonicalDrop(
                pin,
                state.rg,
                max(meta.r, 0.000001)
            );

        result = max(result, max(dropMask, shaftMask));
    }

    return float4(forceColor, saturate(result));
}

float4 rainPhysicalStateViewerDebug(PS_IN pin)
{
    float count = max(gRainStateCount, 1.0);
    float result = 0.0;
    float3 color = float3(1.0, 0.15, 0.65);

    [loop]
    for (int i = 0; i < 256; ++i)
    {
        if ((float)i >= count)
            break;

        float2 suv = float2(
            ((float)i + 0.5) / count,
            0.5
        );

        float4 state = txRainState.SampleLevel(
            samPointRain,
            suv,
            0.0
        );

        float4 meta = txRainStateMeta.SampleLevel(
            samPointRain,
            suv,
            0.0
        );

        if (abs(rainStateLifecycleStatus(meta.a) - 1.0) > 0.5)
            continue;

        float speed =
            rainMetricLength(state.rg,state.ba);

        float normalizedSpeed =
            saturate(
                speed
                / max(gRainDebugStateSpeedScale, 0.000001)
            );

        float2 probe =
            state.rg
            + float2(
                normalizedSpeed * 0.002,
                0.0
            );

        result = max(
            result,
            rainCanonicalDrop(
                pin,
                probe,
                max(meta.r * (0.65 + 0.35 * normalizedSpeed), 0.000001)
            )
        );
    }

    return float4(color, saturate(result));
}

float4 rainBoundaryMaskDebug(PS_IN pin)
{
    float mask=rainValid(pin.Tex);

    return float4(mask, mask, mask, 1.0);
}

float4 rainLifecycleDebug(PS_IN pin)
{
    float count = max(gRainStateCount, 1.0);
    float result = 0.0;
    float3 color = float3(0.25, 0.95, 1.0);

    [loop]
    for (int i = 0; i < 256; ++i)
    {
        if ((float)i >= count)
            break;

        float stateIndex = (float)i;
        float2 stateUV = float2(
            (stateIndex + 0.5) / count,
            0.5
        );

        float4 state = txRainState.SampleLevel(
            samPointRain,
            stateUV,
            0.0
        );

        float4 meta = txRainStateMeta.SampleLevel(
            samPointRain,
            stateUV,
            0.0
        );

        float marker = rainCanonicalDrop(
            pin,
            state.rg,
            max(meta.r, 0.000001)
        );

        if (marker > result)
        {
            result = marker;

            if (rainStateLifecycleStatus(meta.a) < 0.5)
                color = float3(0.0, 0.0, 0.0);
            else if (rainStateLifecycleStatus(meta.a) > 1.5)
                color = float3(1.0, 0.85, 0.10);
            else
                color = float3(0.25, 0.95, 1.0);
        }
    }

    return float4(color, saturate(result));
}

float4 rainPhysicalStateDebug(PS_IN pin)
{
    /*
        Canonical physical-state viewer.

        The marker radius is the actual physical UV radius stored in Meta.R.
        No legacy visual enlargement or artificial size remapping is applied.
    */
    float count = max(gRainStateCount, 1.0);
    float result = 0.0;
    float moving = 0.0;

    [loop]
    for (int i = 0; i < 256; ++i)
    {
        if ((float)i >= count)
            break;

        float stateIndex = (float)i;
        float2 stateUV = float2(
            (stateIndex + 0.5) / count,
            0.5
        );

        float4 state = txRainState.SampleLevel(
            samPointRain,
            stateUV,
            0.0
        );

        float4 meta = txRainStateMeta.SampleLevel(
            samPointRain,
            stateUV,
            0.0
        );

        if (abs(rainStateLifecycleStatus(meta.a) - 1.0) > 0.5)
            continue;

        moving = max(
            moving,
            step(0.00001, rainMetricLength(state.rg,state.ba))
        );

        result = max(
            result,
            rainCanonicalDrop(
                pin,
                state.rg,
                max(meta.r, 0.000001)
            )
        );
    }

    if (result > 0.0)
    {
        return float4(
            1.0,
            0.15,
            0.65,
            saturate(result)
        );
    }

    return float4(
        1.0,
        1.0,
        1.0,
        moving * 0.5
    );
}

float4 main(PS_IN pin):SV_TARGET
{
    if(gRainDebug==7) {
        float valid=rainValid(pin.Tex);
        return float4(lerp(float3(1,.35,.05),float3(.05,.8,1),rainCoating(pin.Tex))*valid,1);
    }
    if(gRainDebug==8) {
        float3 u,v;rainMetric(pin.Tex,u,v);
        float skew=abs(dot(normalize(u),normalize(v)));
        return float4(saturate(float3(length(u),length(v)*4,skew))*rainValid(pin.Tex),1);
    }
    if (gRainDebug == 1)
        return rainNormalObjectDebug(pin);

    if (gRainDebug == 2)
        return rainNormalWorldDebug(pin);

    if (gRainDebug == 3)
        return rainBoundaryMaskDebug(pin);

    if (gRainDebug == 4)
        return rainPredictedPositionsDebug(pin);

    if (gRainDebug == 5)
        return rainForceDirectionDebug(pin);

    if (gRainDebug == 6)
        return rainPhysicalStateViewerDebug(pin);

    return rainPersistentStateRender(pin);
}
