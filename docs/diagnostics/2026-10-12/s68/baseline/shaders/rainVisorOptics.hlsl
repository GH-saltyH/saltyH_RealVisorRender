float3 optDecode(float2 p) {
    float3 n=float3(p,1-abs(p.x)-abs(p.y));
    if(n.z<0)n.xy=(1-abs(n.yx))*float2(n.x>=0?1:-1,n.y>=0?1:-1);
    return normalize(n);
}
float optSH(float4 coefficients,float3 direction) {
    return saturate(dot(coefficients,float4(.28209479,.48860251*direction)));
}
#if OPT_LIGHTING
float4 main(PS_IN pin) {
    float4 hit=txOptHit.SampleLevel(samPointClamp,pin.Tex,0);
    if(hit.a<.5)return 0;
    float4 surface=txOptSurface.SampleLevel(samPointClamp,pin.Tex,0);
    float4 material=txOptMaterial.SampleLevel(samLinearClamp,pin.Tex,0);
    float ao=saturate(txOptAO.SampleLevel(samPointClamp,pin.Tex,0).a);
    float3 n=optDecode(surface.rg);
    float4 visibilitySH=txOptSH.SampleLevel(samPointClamp,pin.Tex,0);
    float aperture=optSH(visibilitySH,gOptLocalLight);
    // L1 visibility has broad lobes: its reconstructed sun value can leak
    // behind the helmet opening. Use the canonical helmet/camera forward axis,
    // not the surface normal or current screen position, to bound that lobe.
    float3 opening=normalize(gOptOpeningLocal),up=normalize(gOptWorldUpLocal);
    float openingSun=smoothstep(gOptOpeningCosLo,
        max(gOptOpeningCosHi,gOptOpeningCosLo+.001),dot(opening,gOptLocalLight));
    // Integral of L1 visibility against the upper hemisphere cosine kernel.
    // Ground-facing apertures cannot borrow brightness from the front image
    // (wheel/headlights). This is a sky-access estimate, not local-light capture.
    float openingSky=1-smoothstep(.15,.85,-dot(opening,up));
    float skyAccess=saturate(dot(visibilitySH,float4(.28209479,.32573501*up)))*openingSky;
    float openFraction=saturate(visibilitySH.x*.28209479);
    float external=txOptSunVisibility.SampleLevel(samPointClamp,float2(.5,.5),0).r;
    float sunVis=aperture*external*openingSun;
    float3 worldN=normalize(mul(float4(n,0),gOptPose).xyz);
    float hemi=saturate(worldN.y*.5+.5);
    float4 average=txOptScene.SampleLevel(samLinearClamp,float2(.5,.5),gOptSceneMaxMip);
    float frameLum=dot(max(average.rgb,0),float3(.2126,.7152,.0722));
    float3 sky=lerp(gOptHorizon,gOptSky,hemi);
    float skyLum=dot(sky,float3(.2126,.7152,.0722));
    // Night sky can be exactly zero. It supplies chroma, not ambient energy.
    sky=skyLum>.001?sky/max(skyLum,.001):float3(1,1,1);
    // Fill includes unresolved multiple bounces; retain AO contrast without
    // making a fully occluded single-bounce hemisphere extinguish the fill.
    float3 ambient=sky*frameLum*gOptAmbient*skyAccess
        *lerp(1,ao,saturate(gOptAmbientAO))*lerp(.35,1,hemi);
    float nDotL=saturate(dot(n,gOptLocalLight));
    float3 direct=gOptSun*sunVis*nDotL*gOptTint;
    // Specular is viewed from the reflecting visor point, not directly from
    // the player's eye. Reconstruct its canonical local position from the
    // baked glass distance and capture projection, preserving the BVH hit.
    float2 ndc=pin.Tex*float2(2,-2)+float2(-1,1);
    float4 viewPoint=mul(float4(ndc,1,1),gOptBakeProjectionInverse);
    float3 localRay=mul(mul(float4(viewPoint.xyz,0),gOptBakeViewInverse),gOptBakePoseInverse).xyz;
    localRay*=rsqrt(max(dot(localRay,localRay),1e-20));
    float glassDistance=txOptGlass.SampleLevel(samPointClamp,pin.Tex,0).z;
    float3 toVisor=gOptEyeLocal+localRay*glassDistance-hit.xyz;
    float3 viewDirection=toVisor*rsqrt(max(dot(toVisor,toVisor),1e-20));
    float3 halfVector=viewDirection+gOptLocalLight;
    float halfLength=dot(halfVector,halfVector);
    halfVector*=rsqrt(max(halfLength,1e-20));
    float exponent=max(2/max(material.a*material.a,.001)-2,0);
    float specular=halfLength>1e-12 && dot(n,viewDirection)>0
        ? max(surface.a,0)*pow(saturate(dot(n,halfVector)),exponent)*nDotL : 0;
    // The highlight carries light colour rather than diffuse albedo. Use
    // authored ksSpecular/gloss, with the same SH and external shadow masks.
    float3 highlight=gOptSun*sunVis*specular*gOptTint;
    // The indirect base is allowed at a shaded hit with an open hemisphere,
    // but is not an unconditional sunlight floor when the opening faces away.
    float3 bounce=gOptSun*gOptBounce*external*openingSun
        *lerp(saturate(gOptBounceBase)*openFraction,1,aperture)*gOptTint;
    float3 radiance=material.rgb*(ambient+direct+bounce)+highlight;
    float coverage=0;
    if(gOptNativeReady>.5) {
        // Subtract in helmet space before rotating. Subtraction of large
        // track-space positions loses millimetres and breaks the depth test.
        float3 relative=mul(float4(hit.xyz-gOptSourceOriginLocal,0),gOptPose).xyz;
        float3 sourcePoint=mul(float4(relative,0),gOptSourceView).xyz;
        float4 clipPosition=mul(float4(sourcePoint,1),gOptSourceProjection);
        if(clipPosition.w>0) {
            float2 uv=clipPosition.xy/clipPosition.w*float2(.5,-.5)+.5;
            if(all(uv>=0) && all(uv<=1)) {
                // Validate each colour tap against its own ID and depth.
                // Linear colour sampling with only a nearest depth test leaks
                // foreground colours along silhouettes and produces cracks.
                uint width,height;txOptNativeDepth.GetDimensions(width,height);
                float2 size=float2(width,height),grid=uv*size-.5,base=floor(grid),blend=frac(grid);
                float tolerance=clamp(2*fwidth(abs(sourcePoint.z)),.001,.005);
                float3 measured=0;
                [unroll]for(int y=0;y<2;y++)[unroll]for(int x=0;x<2;x++) {
                    int2 pixel=clamp((int2)base+int2(x,y),int2(0,0),(int2)size-1);
                    float4 metric=txOptNativeDepth.Load(int3(pixel,0));
                    float4 native=txOptNative.Load(int3(pixel,0));
                    float weight=(x==0?1-blend.x:blend.x)*(y==0?1-blend.y:blend.y);
                    float confidence=1-smoothstep(tolerance*.5,tolerance,abs(metric.r-abs(sourcePoint.z)));
                    if(metric.a<=.5 || abs(metric.g-hit.a)>=.25 || native.a<=.5)confidence=0;
                    coverage+=weight*confidence;
                    measured+=max(native.rgb,0)*weight*confidence;
                }
                float edge=min(min(uv.x,uv.y),min(1-uv.x,1-uv.y));
                float edgeFade=smoothstep(0,.015,edge);
                measured*=edgeFade;coverage*=edgeFade;
                // A finite capture supplements lighting, never replaces the
                // complete BVH image. Rejected/black taps cannot erase it.
                // Remove the overlapping analytic direct estimate so accepted
                // native lighting is not counted twice. Keep ambient fill.
                float3 analyticDirect=material.rgb*(direct+bounce)+highlight;
                radiance+=max(measured*gOptTint-analyticDirect*coverage,0);
            }
        }
    }
    if((int)gOptDebug==15)radiance=material.rgb*ambient;
    return float4(radiance,coverage);
}
#else
float3 optHDR(float2 uv,float mip) {
    return max(txOptScene.SampleLevel(samLinearClamp,saturate(uv),min(mip,gOptSceneMaxMip)).rgb,0);
}
float3 optBright(float2 uv,float mip) {
    return max(txOptBright.SampleLevel(samLinearClamp,saturate(uv),min(mip,gOptBrightMaxMip)).rgb,0);
}
float3 optPSF(float2 uv) {
    // Normalized heavy-tail approximation. Uniform HDR input remains uniform.
    return optBright(uv,1)*.30+optBright(uv,2)*.24+optBright(uv,3)*.18
        +optBright(uv,4)*.12+optBright(uv,5)*.09+optBright(uv,7)*.07;
}
float4 main(PS_IN pin) {
    float2 screenUV=pin.PosH.xy*gOptInvTarget;
    if(gOptNativeOn>.5) {
        float depth=txOptNativeDepth.Load(int3((int2)(pin.PosH.xy*gOptNativePixelScale),0)).r;
        clip(depth>0 ? -1 : 1);
    }
    float3 n=normalize(pin.NormalW),v=normalize(-pin.PosC);
    float cosine=saturate(abs(dot(n,v))),f=.04+.96*pow(1-cosine,5);
    float2 nXY=float2(dot(n,gOptCameraSide),-dot(n,gOptCameraUp));
    float eyeDistance=max(length(pin.PosC),.01);
    float maskMip=clamp(gOptDefocus+log2(max(gOptPupil/eyeDistance*gOptMaskAngularScale,1)),0,8);
    float4 mask=txOptMask.SampleLevel(samLinearClamp,frac(pin.Tex),maskMip);
    float3 result=0;float2 bakeUV=screenUV;float reflectionMip=0;float4 hit=0;
    if(gOptInteriorReady>.5 && gOptTier>.5) {
        float3 localPoint=mul(float4(pin.PosC+gOptEye,1),gOptPoseInverse).xyz;
        float3 canonical=mul(float4(localPoint,1),gOptBakePose).xyz-gOptBakeEye;
        float3 p=mul(float4(canonical,0),gOptBakeView).xyz;
        float4 projected=mul(float4(p,1),gOptBakeProjection);
        bakeUV=float2(projected.x/projected.w*.5+.5,.5-projected.y/projected.w*.5);
        float4 glass=txOptGlass.SampleLevel(samPointClamp,bakeUV,0);
        float depthTolerance=max(.002,2*fwidth(length(canonical))*gOptBakeScale);
        bool valid=projected.w>0 && all(bakeUV>=0) && all(bakeUV<=1)
            && glass.a>.5 && abs(glass.z-length(canonical))<depthTolerance;
        // Add optics only once on the nearest INT sheet, including glare.
        if(!valid)return 0;
        if(valid) {
            float4 surface=txOptSurface.SampleLevel(samPointClamp,bakeUV,0);
            float2 reflectionUV=bakeUV+gOptEyeDeltaProjection/max(surface.z+eyeDistance,.02);
            hit=txOptHit.SampleLevel(samPointClamp,reflectionUV,0);
            float virtualDistance=max(surface.z+eyeDistance,.02);
            reflectionMip=clamp(gOptReflectionBlur+log2(max(gOptPupil/virtualDistance*gOptReflectionAngularScale,1)),0,gOptRadianceMaxMip);
            float3 reflection=txOptRadiance.SampleLevel(samLinearClamp,reflectionUV,reflectionMip).rgb;
            float2 shift=nXY*gOptThickness/max(virtualDistance*cosine,.01)*gOptProjectionScale;
            float3 doubleImage=txOptRadiance.SampleLevel(samLinearClamp,reflectionUV+shift,min(reflectionMip+.5,gOptRadianceMaxMip)).rgb;
            // Two reflective bounces: F^2, not F. F0=.04 -> .0016.
            result+=max(reflection,0)*f*gOptReflectionGain
                +max(doubleImage,0)*f*f*(1-f)*(1-f)*.8*gOptDoubleGain;
        }
    }
    float3 interior=result;
    float3 psf=optPSF(screenUV);
    float sunVis=txOptSunVisibility.SampleLevel(samPointClamp,float2(.5,.5),0).r;
    float cosTheta=dot(normalize(pin.PosC),gOptLightWorld);
    float g=clamp(gOptAnisotropy,.0,.95);
    float hg=(1-g*g)/(12.5663706*pow(max(1+g*g-2*g*cosTheta,.001),1.5));
    float3 dust=psf*(mask.r*gOptDustGain+mask.a*gOptSmudgeGain)
        +gOptSun*sunVis*hg*(mask.r+mask.a*.25)*gOptSunDustGain;
    dust*=gOptEffectGain;
    result+=dust;
    float3 ghostResult=0,scratchResult=0;
    if(gOptTier>1.5) {
        float2 ghostOffset=nXY*gOptGhostShift*gOptInvTarget/max(cosine,.1);
        float3 ghost=0;
        [unroll]for(int tap=0;tap<3;tap++) {
            float2 off=ghostOffset*(1+.25*tap);
            ghost.r+=optBright(screenUV+off,gOptGhostMip).r;
            ghost.g+=optBright(screenUV+off*1.04,gOptGhostMip).g;
            ghost.b+=optBright(screenUV+off*1.08,gOptGhostMip).b;
        }
        ghostResult=ghost/3*f*f*gOptGhostGain*gOptEffectGain;result+=ghostResult;
        // Fine baked lines retain area energy when defocused; a .02 mask
        // cutoff discarded them at coarser mips. Restrict the fan to regions
        // near extracted lights instead of erasing low-coverage scratches.
        if(mask.g>.0001 && gOptScratchGain>0 && dot(optBright(screenUV,4),float3(.2126,.7152,.0722))>.0001) {
            float angle=txOptMask.SampleLevel(samLinearClamp,frac(pin.Tex),0).b*6.28318531;
            // Rotate the UV tangent into screen space before its normal blur.
            float2 tangent=float2(cos(angle),sin(angle));
            float2 dx=ddx(pin.Tex),dy=ddy(pin.Tex);
            float det=dx.x*dy.y-dx.y*dy.x;
            float2 screenT=abs(det)>1e-10?float2(tangent.x*dy.y-tangent.y*dy.x,dx.x*tangent.y-dx.y*tangent.x)/det:tangent;
            screenT=normalize(screenT+float2(1e-8,0));
            float2 perpendicular=float2(-screenT.y,screenT.x);
            float3 streak=0;float weights=0;
            [unroll]for(int i=-6;i<=6;i++) {
                float weight=exp(-i*i/18.0);weights+=weight;
                streak+=optBright(screenUV+perpendicular*i*gOptScratchStep*gOptInvTarget,.5)*weight;
            }
            scratchResult=streak/max(weights,.001)*mask.g*gOptScratchGain*gOptEffectGain;result+=scratchResult;
        }
    }
    if(gOptDebug>.5) {
        int mode=(int)gOptDebug;float3 debug=0;
        if(mode==1) {int id=(int)hit.a;debug=id==1?float3(1,.1,0):id==2?float3(0,1,0):id==3?float3(0,.2,1):id==4?float3(1,1,0):id==5?float3(1,0,1):0;}
        if(mode==2)debug=txOptAO.SampleLevel(samPointClamp,bakeUV,0).aaa;
        if(mode==3)debug=optSH(txOptSH.SampleLevel(samPointClamp,bakeUV,0),gOptLocalLight).xxx;
        if(mode>=4 && mode<=7)debug=mask[mode-4].xxx;
        if(mode==8)debug=1; // PSF weights sum to one.
        if(mode==9)debug=(reflectionMip/max(gOptRadianceMaxMip,1)).xxx;
        // Radiance is already HDR. Compressing it here causes a second
        // tonemap in the game and hides even bright reflected surfaces.
        if(mode==10)return float4(max(txOptRadiance.SampleLevel(samLinearClamp,bakeUV,0).rgb,0),1);
        if(mode==11)debug=sunVis.xxx;
        if(mode==12)return float4(max(interior,0),1);
        if(mode==13)return float4(max(result-interior,0),1);
        if(mode==14)debug=txOptRadiance.SampleLevel(samPointClamp,bakeUV,0).aaa;
        if(mode==15)return float4(max(txOptRadiance.SampleLevel(samLinearClamp,bakeUV,0).rgb,0),1);
        if(mode==16)return float4(max(dust,0)*gOptDebugGain,gOptDebugOverlay>.5?0:1);
        if(mode==17)return float4(max(ghostResult,0)*gOptDebugGain,gOptDebugOverlay>.5?0:1);
        if(mode==18)return float4(max(scratchResult,0)*gOptDebugGain,gOptDebugOverlay>.5?0:1);
        if(mode==19)return float4(optBright(screenUV,0),1);
        // Unit diagnostic colours must use the scene's HDR energy before
        // game exposure, as in the existing E1 geometry diagnostics.
        float3 average=optHDR(float2(.5,.5),gOptSceneMaxMip);
        debug*=max(1,dot(average,float3(.2126,.7152,.0722)));
        return float4(debug,1);
    }
    // Reject empty contributions, rather than touching every visor pixel
    // with an alpha-zero draw in the temporal pipeline.
    if(!any(result>0))discard;
    return float4(max(result,0),0); // Scene-linear HDR, premultiplied additive.
}
#endif
