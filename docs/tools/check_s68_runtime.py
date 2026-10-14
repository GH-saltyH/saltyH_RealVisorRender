"""Production view ownership, partial retries and native UI callback regression."""
from pathlib import Path
import runpy,json,hashlib
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'docs/diagnostics/2026-10-12/s68';OUT.mkdir(parents=True,exist_ok=True)
env=runpy.run_path(str(ROOT/'docs/tools/check_visor_optics.py'));lua=env['lua']
source=(ROOT/'realvisor.lua').read_text(encoding='utf-8');report=[]
lua.execute('''
    local s=rainDynamicSceneCopyState
    sim.frame=101;target={x=1280,y=720};render.getRenderTargetSize=function() return target end
    s.offscreenCaptureActive=0;s.beginMainView();firstView=s.renderViewKey()
    s.lastSmokeDrawFrame=sim.frame;s.lastSmokeDrawViewKey=firstView
    -- Another real view in the same simulation frame must draw again.
    s.beginMainView();assert(firstView~=s.renderViewKey() and sim.frame==101)
    -- Captures cannot publish a main-view identity; unrelated targets cannot win.
    local serial=s.mainViewSerial;s.offscreenCaptureActive=1;s.beginMainView()
    assert(s.mainViewSerial==serial and not s.renderViewKey())
    s.offscreenCaptureActive=0;target={x=256,y=256};assert(not s.renderViewKey())
    target={x=1280,y=720};assert(s.renderViewKey())
''')
a=source.index('    if cfg.RUNTIME.RAIN_DYNAMIC_DROP_DRAW_AT_SMOKE_DEBUG\n        and rainDynamicSceneCopyState.lastSmokeDrawViewKey')
b=source.index('\n    if not rainDynamicRootCallbackLogged',a)
lua.execute('function checkRainView() local sim=ac.getSim() '+source[a:b]+' return true end')
lua.execute('''
    cfg.RUNTIME.RAIN_DYNAMIC_DROP_DRAW_AT_SMOKE_DEBUG=true
    local s=rainDynamicSceneCopyState
    assert(checkRainView()==true,'Previous view must not suppress this view')
    s.lastSmokeDrawViewKey=s.renderViewKey();assert(checkRainView()==nil)
    s.beginMainView();assert(checkRainView()==true,'Pause/redraw with equal sim.frame must render')
''')
report.append('Reproduced old same-frame suppression; new main-view epoch permits another view/redraw, excludes owned captures and mismatched targets')
lua.execute('''
    local s=rainDynamicSceneCopyState;local r=cfg.RUNTIME
    r.RAIN_VISOR_OPTICS_ENABLED=false;r.RAIN_VISOR_LAYER_OPTICS=true
    meshes.GLASS_COAT_FX={targetMesh=meshes.GLASS_EXT_FX.targetMesh,visible=true}
    s.visorLayer={shader='test layer shader',defs={housing={},glass={
        {mesh='GLASS_COAT_FX',kind=2},{rain=true},
        {mesh='GLASS_EXT_FX',kind=1},{mesh='GLASS_INT_FX',kind=3}}}}
    s.nativeGlass={ready=true,updates=0,update=function() return nativeReady end,
        bind=function(_,p,prefix)
            p.textures['tx'..prefix..'NativeDepth']=false;p.values['g'..prefix..'NativeOn']=0
            p.values['g'..prefix..'NativePixelScale']=vec2(1,1)
        end,error='pending test'}
    nativeReady=true;extPending=true;kindCalls={};render.mesh=function(p)
        local k=p.values.gLayerKind;kindCalls[k]=(kindCalls[k] or 0)+1
        assert(p.async==true and p.values.gLayerOpticsConvexTint==r.RAIN_VISOR_LAYER_OPTICS_CONVEX_TINT)
        return not (k==1 and extPending)
    end
    assert(s.nativeGlassPrepare(),tostring(initialized)..'/'..tostring(visor)..'/'..tostring(activeEnableMode)
        ..'/'..tostring(r.RAIN_VISOR_LAYER)..'/'..tostring(r.RAIN_VISOR_SCENE_STACK)..'/'..tostring(r.RAIN_VISOR_OVERLAY)
        ..'/'..tostring(s.visorLayer.err))
    s.beginMainView();assert(s.visorSceneStack('pre'))
    assert(s.visorSceneStack('post')==false and not s.visorLayer.postViewKey)
    assert(kindCalls[1]==1 and kindCalls[2]==1 and kindCalls[3]==1,
        tostring(kindCalls[1])..':'..tostring(kindCalls[2])..':'..tostring(kindCalls[3]))
    extPending=false;assert(s.visorSceneStack('post'))
    assert(kindCalls[1]==2 and kindCalls[2]==1 and kindCalls[3]==1,'Successful INT must not composite twice on partial retry')
    assert(s.visorLayer.postViewKey==s.renderViewKey())
    s.beginMainView();assert(s.visorSceneStack('pre') and s.visorSceneStack('post'))
    assert(kindCalls[2]==2 and kindCalls[3]==2,'A new view must draw each visible FX again')
    nativeReady=false;assert(not s.nativeGlassPrepare());s.beginMainView();local completed=s.visorLayer.postViewKey
    assert(s.visorSceneStack('post')==false and s.visorLayer.postViewKey==completed)
    nativeReady=true;assert(s.nativeGlassPrepare());assert(s.visorSceneStack('post') and s.visorLayer.postViewKey==s.renderViewKey() and not s.visorLayer.err)
''')
report.append('Production stack retries pending EXT/native mask; successful INT/COAT are not doubled; completion is published only on success per view')
factory=lua.execute((ROOT/'native_glass_state.lua').read_text(encoding='utf-8'));lua.globals().nativeFactory=factory
lua.execute('''
    expanded=true;texts={};queries=0;dirty=0
    ui.checkbox=function() return false end
    ui.textWrapped=function() end;ui.text=function(s) texts[#texts+1]=s end
    ui.treeNode=function(label,content)
        assert(label=='Native glass render states' and type(content)=='function')
        if expanded then content() end -- wrapper returns no boolean and owns pop
    end
    ui.treePop=nil
    local m={isTransparent=function() queries=queries+1;return true end,
        blendMode=function() return 2 end,depthMode=function() return 1 end,
        cullMode=function() return 0 end,isCastingShadows=function() return false end}
    nativeUI=nativeFactory({runtime=cfg.RUNTIME,dirty=function() dirty=dirty+1 end})
    for _,name in ipairs(nativeUI.names) do nativeUI.items[name]={ref=m} end
    nativeUI:ui();assert(queries==4 and #texts==4 and dirty==0)
    expanded=false;nativeUI:ui();assert(queries==4 and dirty==0)
''')
report.append('Native render-state UI uses the actual callback contract; expanded/collapsed nodes work without treePop or material mutation')
for name in ('settings.ini','settings_mats.ini','rain_trails.lua','shaders/rainTrailDescriptor.hlsl',
 'shaders/rainTrailResolve.hlsl','shaders/rainSurfaceMetric.hlsl'):
    assert (ROOT/name).read_bytes()==(OUT/'baseline'/name).read_bytes(),name
report.append('Settings, New Trail and physical surface transport unchanged for this bug-fix step')
(OUT/'runtime_checks.json').write_text(json.dumps(report,indent=2))
for line in report:print('PASS:',line)
