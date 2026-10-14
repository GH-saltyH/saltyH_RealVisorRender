"""Guarded s72 model/output calibration and trail sampling/phase changes."""
from pathlib import Path
import re,json,hashlib
root=Path(__file__).resolve().parents[2];out=root/'docs/diagnostics/2026-10-13/s72'
paths=['realvisor.lua','rain_trails.lua','shaders/rainTrailDescriptor.hlsl','shaders/rainTrailResolve.hlsl']
raw={p:(root/p).read_bytes() for p in paths};mt={p:(root/p).stat().st_mtime_ns for p in paths}
for p in paths:assert raw[p]==(out/'baseline'/p).read_bytes(),('Stage changed',p)
s={p:b.decode('utf-8').replace('\r\n','\n') for p,b in raw.items()}
def edit(p,a,b):
    assert s[p].count(a)==1,(p,a[:110],s[p].count(a));s[p]=s[p].replace(a,b,1)
p='realvisor.lua'
edit(p,'        RAIN_NEW_TRAIL_HEIGHT = 0.75,','''        RAIN_NEW_TRAIL_HEIGHT = 0.75,
        -- Response diameter is a calibrated water-model input, separate from
        -- the accepted motion/reference footprint and visible head/micro size.
        RAIN_NEW_TRAIL_MODEL_DIAMETER_SCALE = 3.0,
        RAIN_NEW_TRAIL_OUTPUT_DIAMETER_SCALE = 0.3333333333333333,
        RAIN_NEW_TRAIL_PIXEL_INTEGRATION = true,
        RAIN_NEW_TRAIL_BANDLIMIT = true,''')
edit(p,"    sl('Reference film height','RAIN_NEW_TRAIL_HEIGHT',.1,1,'%.2f')",'''    sl('Film height at 1 model mm','RAIN_NEW_TRAIL_HEIGHT',.1,1,'%.2f')
    sl('Water-model diameter multiplier','RAIN_NEW_TRAIL_MODEL_DIAMETER_SCALE',1,6,'%.2f x')
    sl('Trail output diameter multiplier','RAIN_NEW_TRAIL_OUTPUT_DIAMETER_SCALE',.1,1,'%.3f x')
    if ui.button('Keep current trail width (output = 1 / model)') then
        r.RAIN_NEW_TRAIL_OUTPUT_DIAMETER_SCALE=1/math.max(r.RAIN_NEW_TRAIL_MODEL_DIAMETER_SCALE,1)
        rainDynamicSceneCopyState.materialSettings:markDirty()
    end
    ui.text(string.format('100%% rain: output %.2f-%.2f mm; water model %.2f-%.2f mm; micro output %.2f mm',
        r.RAIN_GPU_SIZE_MIN_HEAVY,r.RAIN_GPU_SIZE_MAX_HEAVY,
        r.RAIN_GPU_SIZE_MIN_HEAVY*r.RAIN_NEW_TRAIL_MODEL_DIAMETER_SCALE,
        r.RAIN_GPU_SIZE_MAX_HEAVY*r.RAIN_NEW_TRAIL_MODEL_DIAMETER_SCALE,
        r.RAIN_DYNAMIC_MICRO_PATTERN_DIAMETER_MM))
    ck('Integrate pixel footprint (thin path support)','RAIN_NEW_TRAIL_PIXEL_INTEGRATION')
    ck('Filter unresolved bead/ripple frequencies','RAIN_NEW_TRAIL_BANDLIMIT')''')
p='rain_trails.lua'
edit(p,"{'descriptors','mask','summary','a','b'}","{'descriptorsA','descriptorsB','mask','summary','a','b'}")
edit(p,'self.ready=false;self.read=nil;self.frame=nil;self.key=nil','self.ready=false;self.read=nil;self.descriptors=nil;self.descriptorRead=nil;self.frame=nil;self.key=nil')
edit(p,"self.descriptors=canvas(count,4,render.TextureFormat.R32G32B32A32.Float,'New Trail slot descriptors')",'''self.descriptorsA=canvas(count,5,render.TextureFormat.R32G32B32A32.Float,'New Trail slot descriptors A')
            self.descriptorsB=canvas(count,5,render.TextureFormat.R32G32B32A32.Float,'New Trail slot descriptors B')
            self.descriptorRead=self.descriptorsA''')
edit(p,'        local v=self.values or {};for k,value in pairs(headValues) do v[k]=value end','''        self.descriptors=self.descriptorRead==self.descriptorsA and self.descriptorsB or self.descriptorsA
        local v=self.values or {};for k,value in pairs(headValues) do v[k]=value end
        v.gNewTrailModelDiameterScale=math.max(r.RAIN_NEW_TRAIL_MODEL_DIAMETER_SCALE or 1,1)
        v.gNewTrailOutputDiameterScale=math.max(r.RAIN_NEW_TRAIL_OUTPUT_DIAMETER_SCALE or 1,.01)
        v.gNewTrailPixelIntegration=r.RAIN_NEW_TRAIL_PIXEL_INTEGRATION and 1 or 0
        v.gNewTrailBandlimit=r.RAIN_NEW_TRAIL_BANDLIMIT and 1 or 0''')
edit(p,'            txTrailPrevious=self.read}','            txTrailPrevious=self.read,txTrailPreviousDescriptors=self.descriptorRead}')
edit(p,'        self.read=self.write;self.ready=true;self.frame=sim.frame;self.updates=self.updates+1',
     '        self.read=self.write;self.descriptorRead=self.descriptors;self.ready=true;self.frame=sim.frame;self.updates=self.updates+1')
p='shaders/rainTrailDescriptor.hlsl'
edit(p,'uint row=(uint)floor(pin.Tex.y*4);','uint row=(uint)floor(pin.Tex.y*5);')
edit(p,'    float radius=max(m.r,0),diameter=2*radius/max(gRainReferencePerMM,1e-8);','''    float modelScale=max(gNewTrailModelDiameterScale,1);
    float outputScale=gNewTrailOutputDiameterScale>0 ? gNewTrailOutputDiameterScale : 1;
    float radius=max(m.r,0)*modelScale;
    float diameter=2*radius/max(gRainReferencePerMM,1e-8);
    float outputRadius=radius*outputScale;''')
edit(p,'float width=radius*gNewTrailWidthD*','float width=outputRadius*gNewTrailWidthD*')
edit(p,'float wipeRadius=max(radius*gNewTrailWipeD,','float wipeRadius=max(outputRadius*gNewTrailWipeD,')
edit(p,'    height=max(height,gNewTrailHeight*rivulet*lerp(1,.35,coat));','''    height=max(height,gNewTrailHeight*rivulet*lerp(1,.35,coat));
    // h0 is calibrated at 1 model-mm. Film deposition scales with the
    // model radius while output footprint compensation retains head size.
    height*=diameter;''')
edit(p,'    float reach=max(width,wipeRadius);','''    if(row==4u) {
        float4 previous=txTrailPreviousDescriptors.Load(int3(i,4,0));
        float generation=floor(m.a/4);
        float begin=previous.a>.5 && previous.b==generation ? previous.g : 0;
        // Integrated distance in local footprint diameters, not an origin
        // reset on each segment. Changing width preserves phase continuity.
        return float4(begin,begin+moved/max(2*width,1e-8),generation,1);
    }
    float reach=max(width,wipeRadius);''')
p='shaders/rainTrailResolve.hlsl'
edit(p,'    float sampledRadius=shape.x+aa*.5;','''    float2 tangent=normalize(travel+float2(1e-15,0));
    float2 normal=float2(-tangent.y,tangent.x);
    float2 pixelU=float2(frame.x/gSize,0);
    float2 pixelV=float2(frame.y*4/gSize,frame.z*4/gSize);
    float aaAcross=max(.5*(abs(dot(normal,pixelU))+abs(dot(normal,pixelV))),1e-9);
    float aaAlong=max(.5*(abs(dot(tangent,pixelU))+abs(dot(tangent,pixelV))),1e-9);
    float sampledRadius=shape.x+(gNewTrailPixelIntegration>.5 ? aa : aa*.5);''')
edit(p,'    float k=saturate(1-d2/max(sampledRadius*sampledRadius,1e-18))*shape.x/max(sampledRadius,1e-9);','''    float k=saturate(1-d2/max(sampledRadius*sampledRadius,1e-18))*shape.x/max(sampledRadius,1e-9);
    if(gNewTrailPixelIntegration>.5) {
        // Closed-form box integral of the transverse parabolic film profile.
        // Average thickness is conserved as the path crosses atlas rows.
        float width=max(shape.x,1e-9),q=dot(side,normal);
        float lo=clamp(q-aaAcross,-width,width),hi=clamp(q+aaAcross,-width,width);
        k=max(0,(hi-lo-(hi*hi*hi-lo*lo*lo)/(3*width*width))/(2*aaAcross));
        float cap=abs(dot(side,tangent));
        k*=1-smoothstep(max(width-aaAlong,0),width+aaAlong,cap);
    }''')
edit(p,'''    float along=dot(delta,normalize(travel+float2(1e-15,0)))/max(shape.x*2,1e-8);
    // Thin films bead; thick ones stay continuous. No floor or plateau in sheets.
    float bead=.5+.5*sin(along*gNewTrailBeadCycles*6.2831853+float(i)*2.399963);
    float modulation=lerp(1,lerp(.15,1,bead*bead),gNewTrailNoise*(1-saturate(shape.y))*(1-shape.z));
    float ripple=1+gNewTrailSheetRipple*shape.z*sin(along*6.2831853+gNewTrailPhase);''','''    float beadResolved=gNewTrailBandlimit>.5 ? 1-smoothstep(.25,.5,
        gNewTrailBeadCycles*aaAlong/max(shape.x,1e-9)) : 1;
    float rippleResolved=gNewTrailBandlimit>.5 ? 1-smoothstep(.25,.5,
        aaAlong/max(shape.x,1e-9)) : 1;
    float modulationAmount=gNewTrailNoise*(1-saturate(shape.y))*(1-shape.z);
    float modulation=lerp(1,.46875,modulationAmount),ripple=1;
    if(beadResolved*modulationAmount>1e-5 || rippleResolved*gNewTrailSheetRipple*shape.z>1e-5) {
        float4 phase=txTrailDescriptors.Load(int3(i,4,0));
        float along=phase.x+dot(delta,tangent)/max(shape.x*2,1e-8);
        if(beadResolved*modulationAmount>1e-5) {
            float bead=.5+.5*sin(along*gNewTrailBeadCycles*6.2831853+float(i)*2.399963);
            float profile=lerp(.46875,lerp(.15,1,bead*bead),beadResolved);
            modulation=lerp(1,profile,modulationAmount);
        }
        if(rippleResolved*gNewTrailSheetRipple*shape.z>1e-5)
            ripple=1+gNewTrailSheetRipple*shape.z*rippleResolved*sin(along*6.2831853+gNewTrailPhase);
    }''')
edit(p,'    float diameter=2*width/max(gNewTrailWidthD*(1+gNewTrailWiden*sheet)*gRainReferencePerMM,1e-8);','''    float outputScale=gNewTrailOutputDiameterScale>0 ? gNewTrailOutputDiameterScale : 1;
    float diameter=2*width/max(gNewTrailWidthD*(1+gNewTrailWiden*smoothstep(.3,.8,gNewTrailShear)*sheet)
        *gRainReferencePerMM*outputScale,1e-8);''')
for p in paths:assert (root/p).stat().st_mtime_ns==mt[p] and (root/p).read_bytes()==raw[p],('Concurrent edit',p)
for p in paths:(root/p).write_bytes((s[p].replace('\n','\r\n') if b'\r\n' in raw[p] else s[p]).encode('utf-8'))
(out/'patch_hashes.json').write_text(json.dumps({p:hashlib.sha256((root/p).read_bytes()).hexdigest() for p in paths},indent=2))
print('s72 patched with staged-content/mtime guards; current birth and micro profile values retained')
