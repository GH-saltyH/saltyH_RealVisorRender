"""One-time exact-anchor, mtime guarded s65 source edits."""
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
def edit(path,fn):
    p=ROOT/path;t=p.stat().st_mtime_ns;s=p.read_text(encoding='utf-8');s=fn(s)
    assert p.stat().st_mtime_ns==t,path
    p.write_text(s,encoding='utf-8')
def rep(s,a,b):
    assert s.count(a)==1,(a[:90],s.count(a));return s.replace(a,b)
edit('shaders/rainVisorDynamicDrop.hlsl',lambda s:s.replace('txDynamicSmearMask','txDynamicWeatherScreen'))
def lua(s):
    anchor='rainDynamicSceneCopyState.gpuHeadsPassA = rainDynamicSceneCopyState.gpuHeadsCommon .. [['
    bounds='''rainDynamicSceneCopyState.gpuBoundsShader = rainDynamicSceneCopyState.gpuHeadsCommon .. [[
float4 main(PS_IN pin) {
    int i=(int)min(floor(pin.Tex.x*gCount),gCount-1);
    float2 pos,vel;float R,idx,gen,rUV;
    if(!rgDrop(i,pos,R,vel,idx,gen,rUV)) return float4(2e9,2e9,-2e9,-2e9);
    float reach=R*(gKs*1.4+max(gMaxRadii,max(gPuddleReach*1.1,.6))+.1)+2;
    float2 ext=rgExtent(reach);
    return float4(pos-ext,pos+ext);
}
]]
'''
    s=rep(s,anchor,bounds+anchor)
    s=rep(s,'''        float2 pos; float R; float2 vel; float idx; float gen; float rUV;
        if (rgDrop(i, pos, R, vel, idx, gen, rUV))
        {
            float reach = R * (gKs * 1.4 + max(gMaxRadii, max(gPuddleReach * 1.1, 0.6)) + 0.1) + 2.0;
            float2 ext=rgExtent(reach);
            if(all(pos+ext>=tmin)&&all(pos-ext<=tmax))
                bits |= (1u << (uint)b);
        }''','''        // Bounds are evaluated once per slot, rather than in every tile.
        float4 bounds=txRainDropBounds.Load(int3(i,0,0));
        if(all(bounds.zw>=tmin)&&all(bounds.xy<=tmax)) bits|=1u<<(uint)b;''')
    s=rep(s,'    local tile = math.max(16, math.floor(r.RAIN_GPU_HEADS_TILE))',
        '    local tile = math.max(16, math.floor(r.RAIN_GPU_HEADS_TILE))\n    -- At 4:1 this remains square in backing pixels; finer bins reduce\n    -- per-pixel candidate traffic without changing kernels or slot order.\n    tile=math.min(tile,32)')
    a='''    local okA, errA = pcall(function()
        local updated=st.measure('Head tiles',st.gpuMask.updateWithShader,st.gpuMask,{async=false,
            textures = {txRainState=state,txRainStateMeta=meta,txRainDu=st.surface.root..'du.dds',txRainDv=st.surface.root..'dv.dds',txRainBoundaryMask=textureRainBoundaryMask,txRainDropMetric=st.gpuMetric},'''
    b='''    if not st.gpuBounds or st.gpuBoundsCount~=count then
        if st.gpuBounds then st.gpuBounds:dispose() end
        st.gpuBounds=ui.ExtraCanvas(vec2(count,1),1,render.AntialiasingMode.None,render.TextureFormat.R32G32B32A32.Float)
        st.gpuBounds:setName('RainFX per-drop conservative bounds');st.gpuBoundsCount=count
    end
    if st.measure('Head bounds',st.gpuBounds.updateWithShader,st.gpuBounds,{async=false,
        blendMode=render.BlendMode.Opaque,values=values,
        textures={txRainState=state,txRainStateMeta=meta,txRainDropMetric=st.gpuMetric},
        shader=st.gpuBoundsShader})==false then return false end
    local okA, errA = pcall(function()
        local updated=st.measure('Head tiles',st.gpuMask.updateWithShader,st.gpuMask,{async=false,
            textures = {txRainDropBounds=st.gpuBounds},'''
    s=rep(s,a,b)
    # Radius is not a teleport test: a sub-mm drop can cover many radii/frame.
    a='''                    if (state.surface:length(x/size,y/size-1,dx/size,dy/size)*size)^2 < math.max(
                        cfg.RUNTIME.RAIN_DYNAMIC_WATER_FIELD_SHEET_LINK_RADII * R * scale,
                        cfg.RUNTIME.RAIN_DYNAMIC_WATER_FIELD_SHEET_LINK_MIN_TEXELS, 0.0) ^ 2 then
                        fx, fy = lastX[index], lastY[index]
                    end'''
    s=rep(s,a,'''                    fx, fy = lastX[index], lastY[index] -- generation + physical segment validated above''')
    a='''                trailQuad(x,y,r/ks,r/ks,1,0,R*width/32,0)
                lastX[index], lastY[index] = x, y'''
    b='''                -- Slow trails also bridge readback intervals instead of
                -- leaving isolated stamps whose spacing depends on FPS.
                local fx,fy=x,y
                if lastGen[index]==generation and lastX[index]
                    and state.surface:segment(lastX[index]/size,lastY[index]/size-1,x/size,y/size-1) then
                    fx,fy=lastX[index],lastY[index]
                end
                local px,py=state.surface:plane(x/size,y/size-1,(x-fx)/size,(y-fy)/size)
                local len=math.sqrt(px*px+py*py);local ux,uy=1,0
                if len>1e-9 then ux,uy=px/len,py/len end
                if ribbon and len>1e-9 and state.surface:ribbon(q1,q2,q3,q4,fx,fy,x,y,r,ux,uy,size) then
                    ui.drawImageQuad(ribbon,q1,q2,q3,q4,color)
                end
                trailQuad(x,y,r/ks,r/ks,ux,uy,R*width/32,0)
                lastX[index], lastY[index] = x, y'''
    s=rep(s,a,b)
    a="-- phase 'pre'  : housing (opaque, depth write) + glass items before rain"
    b='''-- Combine already available frame depth with native glass distance in
-- one binding. Never sample a DSV which the rain pass is currently writing.
rainDynamicSceneCopyState.rainOcclusionUpdate = function()
    local st=rainDynamicSceneCopyState;local sim=ac.getSim()
    local size=render.getRenderTargetSize();local w,h=math.floor(size.x),math.floor(size.y)
    if not st.rainOcclusion or st.rainOcclusionW~=w or st.rainOcclusionH~=h then
        if st.rainOcclusion then st.rainOcclusion:dispose() end
        st.rainOcclusion=ui.ExtraCanvas(vec2(w,h),1,render.AntialiasingMode.None,render.TextureFormat.R32G32.Float)
        st.rainOcclusion:setName('RainFX stable scene/native occlusion');st.rainOcclusionW,st.rainOcclusionH=w,h
    end
    local native=st.nativeGlass
    local near=math.max(sim.cameraClipNear or .05,.001)
    local ready=st.rainOcclusion:updateSceneWithShader({async=false,blendMode=render.BlendMode.Opaque,
        textures={txSceneDepth='dynamic::depth',txNativeDepth=native and native.ready and native.shot or false},
        values={gNear=near,gFar=math.max(sim.cameraClipFar or 5000,near+1),
            gReversed=cfg.RUNTIME.RAIN_DYNAMIC_SHOT_TONE_FRAME_DEPTH_REVERSED and 1 or 0,
            gNative=native and native.ready and 1 or 0},shader=[[
        float4 main(PS_IN pin) {
            uint w=1u,h=1u;txSceneDepth.GetDimensions(w,h);
            float d=txSceneDepth.Load(int3(clamp(int2(pin.Tex*float2(w,h)),int2(0,0),int2(w-1,h-1)),0)).r;
            if(gReversed>.5)d=1-d;
            float z=d>.99999 ? 10000 : gNear*gFar/max(gFar-d*(gFar-gNear),1e-7);
            float native=gNative>.5 ? txNativeDepth.SampleLevel(samPointClamp,pin.Tex,0).r : 0;
            return float4(z,native,0,1);
        }]]})
    st.rainOcclusionReady=ready~=false
end
'''+a
    s=rep(s,a,b)
    s=rep(s,'            txDynamicShotDepth =\n', '            txDynamicOcclusion = false,\n            txDynamicShotDepth =\n')
    s=rep(s,'            gDynamicDropDepthOnly = 0.0,','            gDynamicDropOcclusionOn = 0.0,\n            gDynamicDropDepthOnly = 0.0,')
    s=rep(s,"    local sceneStackOk = pcall(rainDynamicSceneCopyState.measure,'Glass pre',rainDynamicSceneCopyState.visorSceneStack,'pre')\n    local rainEditor=rainDynamicSceneCopyState.e1SourceEditor('GLASS_RAINFX')",'''    local sceneStackOk = pcall(rainDynamicSceneCopyState.measure,'Glass pre',rainDynamicSceneCopyState.visorSceneStack,'pre')
    if not cfg.RUNTIME.RAIN_DYNAMIC_DROP_DEPTH_OFF and not cfg.RUNTIME.RAIN_DYNAMIC_DROP_UV_DEBUG then
        rainDynamicSceneCopyState.measure('Rain occlusion',rainDynamicSceneCopyState.rainOcclusionUpdate)
        dropMeshParams.textures.txDynamicOcclusion=rainDynamicSceneCopyState.rainOcclusion
        dropMeshParams.values.gDynamicDropOcclusionOn=rainDynamicSceneCopyState.rainOcclusionReady and 1 or 0
    end
    -- Captures/stack draws change state; set it at the actual rain submission.
    render.setCullMode(render.CullMode.None)
    render.setDepthMode((cfg.RUNTIME.RAIN_DYNAMIC_DROP_DEPTH_OFF or cfg.RUNTIME.RAIN_DYNAMIC_DROP_UV_DEBUG)
        and render.DepthMode.Off or render.DepthMode.ReadOnly)
    render.setBlendMode(render.BlendMode.BlendAccurate)
    local rainEditor=rainDynamicSceneCopyState.e1SourceEditor('GLASS_RAINFX')''')
    s=rep(s,"        rainDynamicSceneCopyState.measure('Rain depth',render.mesh,dropMeshParams)",'''        local colourShader=dropMeshParams.shader
        if cfg.RUNTIME.RAIN_DYNAMIC_DROP_DEPTH_OCCLUDE_MODE>=2 then
            dropMeshParams.shader='#define RAIN_DEPTH_ONLY 1\\n'..colourShader
        end
        rainDynamicSceneCopyState.measure('Rain depth',render.mesh,dropMeshParams)
        dropMeshParams.shader=colourShader''')
    return s
edit('realvisor.lua',lua)
print('s65 source anchors applied; saved tuning unchanged')
