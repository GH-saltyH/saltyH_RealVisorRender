"""One-shot, staged-content guarded s71 smear corrections."""
from pathlib import Path
import re,json,hashlib
root=Path(__file__).resolve().parents[2];out=root/'docs/diagnostics/2026-10-13/s71'
paths=['shaders/rainVisorDynamicDrop.hlsl','realvisor.lua','material_settings.lua','docs/tools/check_material_settings.py']
original={p:(root/p).read_bytes() for p in paths}
mtime={p:(root/p).stat().st_mtime_ns for p in paths}
for p in paths:assert original[p]==(out/'baseline'/p).read_bytes(),('staged content changed',p)
sources={p:b.decode('utf-8').replace('\r\n','\n') for p,b in original.items()}
def change(path,old,new):
    s=sources[path];assert s.count(old)==1,(path,old[:100],s.count(old));sources[path]=s.replace(old,new,1)
s='shaders/rainVisorDynamicDrop.hlsl'
change(s,'float4 rainSmearClassHash(float k)', '''// One symmetric class pair drives both facet colour and class survival.
float4 rainSmearClassPair(float g)
{
    float n=clamp(floor(gDynamicDropSmearClasses+.5),1,8);
    float c=g*n;
    float edge=clamp(floor(c+.5),1,max(n-1,1));
    float k0=clamp(edge-1,0,n-1),k1=min(k0+1,n-1);
    float width=max(gDynamicDropSmearClassSoft,.001);
    return float4(k0,k1,smoothstep(edge-width*.5,edge+width*.5,c),n);
}

float4 rainSmearClassHash(float k)''')
change(s,'''    float smearN = clamp(floor(gDynamicDropSmearClasses + 0.5), 1.0, 8.0);
    float smearCls = gSmearG * smearN;
    float smearK0 = min(floor(smearCls), smearN - 1.0);
    float smearK1 = min(smearK0 + 1.0, smearN - 1.0);
    float classWidth=max(gDynamicDropSmearClassSoft,.001);
    float edge=clamp(floor(smearCls+.5),1.0,max(smearN-1.0,1.0));
    smearK0=clamp(edge-1,0,smearN-1);
    smearK1=min(smearK0+1,smearN-1);
    float smearBlend=smoothstep(edge-classWidth*.5,edge+classWidth*.5,smearCls);''', '''    float4 pair=rainSmearClassPair(gSmearG);
    float smearN=pair.w,smearCls=gSmearG*smearN;
    float smearK0=pair.x,smearK1=pair.y,smearBlend=pair.z;''')
change(s,'''            gSmearG = pow(saturate((visibilityRG.y - gDynamicDropSmearGPivot)
                * gDynamicDropSmearGContrast + gDynamicDropSmearGPivot),
                max(gDynamicDropSmearGGamma, 0.05));''','''            gSmearG = gSmearVisibilityG;''')
change(s,'''            float smearN = clamp(floor(gDynamicDropSmearClasses + 0.5),
                1.0, 8.0);
            float smearCls = gSmearG * smearN;
            float smearK0 = min(floor(smearCls), smearN - 1.0);
            float smearK1 = min(smearK0 + 1.0, smearN - 1.0);
            float smearBlend = smoothstep(
                1.0 - max(gDynamicDropSmearClassSoft, 0.001), 1.0,
                smearCls - smearK0);
            float smearWipe = gDynamicDropTrailMaskWipeEnabled > 0.5
                ? rainWipeTap(patternUV).g * gDynamicDropSmearClassWipe : 0.0;''','''            float4 pair=rainSmearClassPair(gSmearG);
            float smearK0=pair.x,smearK1=pair.y,smearBlend=pair.z;
            // Class erasure is a wipe operation too. Apply the pre-erasure
            // region/G rule, or a fresh path cancels the low-G smear and
            // restores opaque drops exactly where they should stay weak.
            float smearWipe = gDynamicDropTrailMaskWipeEnabled > 0.5
                ? rainSmearWipe(rainWipeTap(patternUV).g) * gDynamicDropSmearClassWipe : 0.0;''')
change(s,'''            float smearP0 = smoothstep(smearErase - 0.08, smearErase + 0.08,
                rainSmearClassOrder(smearK0));
            float smearP1 = smoothstep(smearErase - 0.08, smearErase + 0.08,
                rainSmearClassOrder(smearK1));
            float smearPresence = lerp(smearP0, smearP1, smearBlend);
            float visCls = gSmearVisibilityG * smearN;
            float visK0 = min(floor(visCls), smearN - 1.0);
            float visK1 = min(visK0 + 1.0, smearN - 1.0);
            float visBlend = smoothstep(1.0 - max(gDynamicDropSmearClassSoft, 0.15), 1.0, visCls - visK0);
            gSmearMask *= lerp(smoothstep(smearErase - 0.15, smearErase + 0.15, rainSmearClassOrder(visK0)),
                smoothstep(smearErase - 0.15, smearErase + 0.15, rainSmearClassOrder(visK1)), visBlend);''','''            float smearP0 = smoothstep(smearErase - 0.15, smearErase + 0.15,
                rainSmearClassOrder(smearK0));
            float smearP1 = smoothstep(smearErase - 0.15, smearErase + 0.15,
                rainSmearClassOrder(smearK1));
            float smearPresence = lerp(smearP0, smearP1, smearBlend);
            gSmearMask *= smearPresence;''')
change(s,'float trailCover = pureInside * gSmearMask;','''// The neutral refraction path must follow the same G
                    // visibility as the legacy water overlay (smear v8).
                    float trailCover = pureInside * gSmearMask
                        * rainSmearVis(gDynamicDropSmearTrailHide);''')
p='material_settings.lua'
change(p,"or key:match('^RAIN_NEW_TRAIL_') or key:match('^RAIN_DYNAMIC_WATER_FIELD_TRAIL_')",
         "or key:match('^RAIN_DYNAMIC_SMEAR_')\n            or key:match('^RAIN_NEW_TRAIL_') or key:match('^RAIN_DYNAMIC_WATER_FIELD_TRAIL_')")
p='realvisor.lua'
change(p,"RAIN_DYNAMIC_SMEAR_TRAIL_HIDE = 'G-dependent legacy WF overlay visibility at smear transition edges; it does not hide neutral refraction in full smear interiors.',",
         "RAIN_DYNAMIC_SMEAR_TRAIL_HIDE = 'G-dependent visibility of WF trails, including neutral refraction inside the smear region.',")
change(p,"RAIN_DYNAMIC_SMEAR_CLASS_WIPE = 'How strongly wiping/flowing water erases classes on its path.',",
         "RAIN_DYNAMIC_SMEAR_CLASS_WIPE = 'How strongly flowing water erases classes; follows the region/G path weakening before class erasure.',")
change(p,"tfSlider('WF trail visibility by G (region transition only)', 'RAIN_DYNAMIC_SMEAR_TRAIL_HIDE'",
         "tfSlider('Region: WF trail visibility by G', 'RAIN_DYNAMIC_SMEAR_TRAIL_HIDE'")
change(p,'''                cfg.RUNTIME.RAIN_DYNAMIC_SMEAR_WIND_MODE = math.floor(value + 0.5)
            end''','''                cfg.RUNTIME.RAIN_DYNAMIC_SMEAR_WIND_MODE = math.floor(value + 0.5)
                local settings=rainDynamicSceneCopyState.materialSettings
                if settings then settings:markDirty() end
            end''')
change(p,'''                cfg.RUNTIME.RAIN_DYNAMIC_SMEAR_CLASSES = math.floor(value + 0.5)
            end''','''                cfg.RUNTIME.RAIN_DYNAMIC_SMEAR_CLASSES = math.floor(value + 0.5)
                local settings=rainDynamicSceneCopyState.materialSettings
                if settings then settings:markDirty() end
            end''')
p='docs/tools/check_material_settings.py'
change(p,'RAIN_DYNAMIC_WATER_FIELD_SHEET_ENABLED=true,RAIN_DYNAMIC_TRAIL_MASK_SECONDS=.69}',
         '''RAIN_DYNAMIC_WATER_FIELD_SHEET_ENABLED=true,RAIN_DYNAMIC_TRAIL_MASK_SECONDS=.69,
        RAIN_DYNAMIC_SMEAR_ENABLED=true,RAIN_DYNAMIC_SMEAR_TRAIL_HIDE=.81,
        RAIN_DYNAMIC_SMEAR_PATH_WEAKEN=.85,RAIN_DYNAMIC_SMEAR_CLASSES=5,
        RAIN_DYNAMIC_SMEAR_WIND_MODE=2}''')
change(p,'    assert(st:load())\n    assert(e.values.f.value==', '''    runtime.RAIN_DYNAMIC_SMEAR_ENABLED=false;runtime.RAIN_DYNAMIC_SMEAR_TRAIL_HIDE=0
    runtime.RAIN_DYNAMIC_SMEAR_PATH_WEAKEN=0;runtime.RAIN_DYNAMIC_SMEAR_CLASSES=1
    runtime.RAIN_DYNAMIC_SMEAR_WIND_MODE=0
    assert(st:load())
    assert(runtime.RAIN_DYNAMIC_SMEAR_ENABLED and runtime.RAIN_DYNAMIC_SMEAR_TRAIL_HIDE==.81)
    assert(runtime.RAIN_DYNAMIC_SMEAR_PATH_WEAKEN==.85 and runtime.RAIN_DYNAMIC_SMEAR_CLASSES==5)
    assert(runtime.RAIN_DYNAMIC_SMEAR_WIND_MODE==2)
    assert(e.values.f.value==''')
for p in paths:
    assert (root/p).stat().st_mtime_ns==mtime[p] and (root/p).read_bytes()==original[p],('changed during patch',p)
for p in paths:
    text=sources[p].replace('\n','\r\n') if b'\r\n' in original[p] else sources[p]
    (root/p).write_bytes(text.encode('utf-8'))
report={p:{'before':hashlib.sha256(original[p]).hexdigest(),'after':hashlib.sha256((root/p).read_bytes()).hexdigest()} for p in paths}
(out/'patch_hashes.json').write_text(json.dumps(report,indent=2))
print('Patched s71 with unique anchors and staged-content/mtime guards; runtime defaults preserved')
