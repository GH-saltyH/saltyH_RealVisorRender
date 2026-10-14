from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];p=ROOT/'shaders/rainVisorDynamicDrop.hlsl'
stamp=p.stat().st_mtime_ns;s=p.read_text(encoding='utf-8')
def one(a,b):
    global s
    assert s.count(a)==1,(a,s.count(a));s=s.replace(a,b)
one('''            float2 physicalDx=rainMetricPlane(float2(patternUV.x,patternUV.y-1),wfDx);
            float2 physicalDy=rainMetricPlane(float2(patternUV.x,patternUV.y-1),wfDy);''','''            // Share one local frame across derivatives and diameter-based
            // offsets: physical UI units do not add baked-metric texture reads.
            float3 metricU,metricV;rainMetric(float2(patternUV.x,patternUV.y-1),metricU,metricV);
            float metricA=max(length(metricU),1e-9),metricB=dot(metricU/metricA,metricV);
            float metricC=sqrt(max(dot(metricV,metricV)-metricB*metricB,1e-18));
            float3 localFrame=float3(metricA,metricB,metricC)/gRainMetersPerUnit;
            float2 physicalDx=float2(localFrame.x*wfDx.x+localFrame.y*wfDx.y,localFrame.z*wfDx.y);
            float2 physicalDy=float2(localFrame.x*wfDy.x+localFrame.y*wfDy.y,localFrame.z*wfDy.y);''')
one('''                float2 p=float2(patternUV.x,patternUV.y-1);
                stepU=rainMetricOffset(p,float2(headPhysicalStep,0));
                stepV=rainMetricOffset(p,float2(0,headPhysicalStep));''','''                stepU=float2(headPhysicalStep/localFrame.x,0);
                float dv=headPhysicalStep/localFrame.z;
                stepV=float2(-localFrame.y*dv/localFrame.x,dv);''')
one('''                        float2 p=float2(patternUV.x,patternUV.y-1);
                        float2 du=rainMetricOffset(p,float2(r,0)),dv=rainMetricOffset(p,float2(0,r));''','''                        float2 du=float2(r/localFrame.x,0);
                        float dvStep=r/localFrame.z;
                        float2 dv=float2(-localFrame.y*dvStep/localFrame.x,dvStep);''')
assert p.stat().st_mtime_ns==stamp;p.write_text(s,encoding='utf-8',newline='\r\n')
print('Reused one physical frame for lens derivatives and D-based offsets')
