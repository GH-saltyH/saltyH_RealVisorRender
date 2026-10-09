"""Compare the actual five-mesh packed BVH against original KN5 triangles."""
from pathlib import Path
import importlib.util, json, hashlib, subprocess, tempfile
import numpy as np

root=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('bake',root/'docs/tools/build_e1_housing_bvh.py')
bake=importlib.util.module_from_spec(spec);spec.loader.exec_module(bake)
folder=root/'texture/GLASS/E1_GEOMETRY'
manifest=json.loads((folder/'manifest.json').read_text())
blob=(root/manifest['model']).read_bytes()
assert hashlib.sha256(blob).hexdigest()==manifest['sha256']

def hits(tri,origin,direction,best):
    a=tri[:,0,:3].astype(float);ab=tri[:,1,:3]-a;ac=tri[:,2,:3]-a
    p=np.cross(direction,ac);det=np.einsum('ij,ij->i',ab,p)
    good=np.abs(det)>=1e-10;inv=np.divide(1.,det,out=np.zeros_like(det),where=good)
    off=origin-a;u=np.einsum('ij,ij->i',off,p)*inv
    q=np.cross(off,ab);v=q@direction*inv;t=np.einsum('ij,ij->i',ac,q)*inv
    valid=good&(u>=0)&(v>=0)&(u+v<=1)&(t>.0005)&(t<best)
    candidates=np.flatnonzero(valid)
    if not len(candidates):return best,None
    i=candidates[np.argmin(t[candidates])]
    return t[i],(i,np.array([1-u[i]-v[i],u[i],v[i]]))

def box(o,d,lo,hi,best):
    first=.0005;last=best
    for axis in range(3):
        if d[axis]==0:
            if o[axis]<lo[axis] or o[axis]>hi[axis]:return False
        else:
            a=(lo[axis]-o[axis])/d[axis];b=(hi[axis]-o[axis])/d[axis]
            first=max(first,min(a,b));last=min(last,max(a,b))
    return last>=first

def trace(nodes,tri,o,d,best):
    node=0;total=int(nodes[1,3]);hit=None;visits=0
    while node<total and visits<65536:
        visits+=1;a,b=nodes[node*2:node*2+2]
        if not box(o,d,a[:3],b[:3],best):node=int(b[3]);continue
        if a[3]<0:node+=1;continue
        meta=int(a[3]);start,count=meta>>4,meta&15
        distance,found=hits(tri[start:start+count],o,d,best)
        if found is not None:best=distance;hit=(start+found[0],found[1])
        node=int(b[3])
    assert node>=total,'traversal budget exceeded'
    return best,hit,visits

rng=np.random.default_rng(19);maximum=0;tested=0
for name,key in bake.MESHES:
    vertices,indices=bake.mesh(blob,name)
    source_tri=np.zeros((len(indices),4,4),dtype=np.float32)
    source_tri[:,:3,:3]=vertices[indices,:3]
    nodes=np.frombuffer((folder/f'{key}_nodes.dds').read_bytes(),'<f4',offset=148).reshape(-1,4)
    tri=np.frombuffer((folder/f'{key}_triangles.dds').read_bytes(),'<f4',offset=148).reshape(-1,4,4)
    tri=tri[:len(indices)]
    assert manifest['meshes'][key]['name']==name
    lo=vertices[:,:3].min(0);hi=vertices[:,:3].max(0);center=(lo+hi)/2
    rays=[]
    for i in range(24):
        target=source_tri[rng.integers(len(indices)),:3,:3].mean(0)
        direction=rng.normal(size=3);direction/=np.linalg.norm(direction)
        origin=target-direction*.5;rays.append((origin,direction))
    rays += [(center-np.eye(3)[i],np.eye(3)[i]) for i in range(3)]
    rays += [(hi+1,np.array([1.,0,0]))]  # parallel outside slabs, guaranteed miss
    for o,d in rays:
        expected,eh=hits(source_tri,o,d,3.)
        actual,ah,visits=trace(nodes,tri,o,d,3.)
        assert (eh is None)==(ah is None),(name,expected,actual)
        assert abs(expected-actual)<2e-6,(name,expected,actual)
        if ah is not None:
            uvx=ah[1]@tri[ah[0],:3,3];uvy=ah[1]@tri[ah[0],3,:3]
            assert np.isfinite([uvx,uvy]).all()
        maximum=max(maximum,visits);tested+=1
print(f'PASS: SHA256, five exact mesh names, {tested} KN5 vs packed BVH rays within 2um; max visits {maximum}')

header='struct PS_IN {float4 PosH:SV_POSITION;float3 PosC:TEXCOORD0;float3 NormalW:TEXCOORD1;};\n'
for key in ['Frame','Rubber','Fabric','Face','Balaklava']:
    header+=f'Texture2D txE1{key}Nodes,txE1{key}Triangles;float4x4 gE1{key}Inverse;float gE1{key}Visible;\n'
header+='Texture2D txE1FrameDiffuse,txE1FabricDiffuse;float3 gE1Eye,gE1LocalOrigin;float gE1Range,gE1Mode,gE1Checker,gE1RubberGrey;\n'
header+='float gE1ColourTolerance,gE1MeanFloor,gE1Threshold,gE1Knee,gE1Gain,gE1FixedReference,gE1Isolation;\n'
for i in range(3):
    header+=f'Texture2D txE1Colour{i},txE1Depth{i};float4x4 gE1View{i},gE1Projection{i};float3 gE1EyeToSource{i};float gE1SourceActive{i};\n'
shader=(root/'shaders/e1HousingGeometry.hlsl').read_text(encoding='utf-8-sig').replace('main(PS_IN pin)','main(PS_IN pin):SV_TARGET')
with tempfile.TemporaryDirectory(prefix='e1_geometry_',dir=root/'docs/tools') as tmp:
    path=Path(tmp)/'geometry.hlsl';path.write_text(header+shader,encoding='utf-8')
    subprocess.run(['C:/Program Files (x86)/Windows Kits/10/bin/10.0.19041.0/x64/fxc.exe',
        '/nologo','/T','ps_5_0','/E','main','/Ges','/WX','/Fo',str(Path(tmp)/'geometry.cso'),str(path)],check=True)
    lua=(root/'realvisor.lua').read_text(encoding='utf-8-sig')
    start=lua.index('rainDynamicSceneCopyState.e1GeometryDraw = function()')
    a=lua.index('shader=[[',start)+len('shader=[[');b=lua.index(']]}',a)
    composite=lua[a:b].replace('main(PS_IN pin)','main(PS_IN pin):SV_TARGET')
    header='struct PS_IN {float4 PosH:SV_POSITION;float3 PosC:TEXCOORD0;};Texture2D txE1Geometry;SamplerState samLinearClamp,samPointClamp;float2 gE1InvTarget,gE1InvBuffer;float gE1Final,gE1Blur,gE1Scale;\n'
    path.write_text(header+composite,encoding='utf-8')
    subprocess.run(['C:/Program Files (x86)/Windows Kits/10/bin/10.0.19041.0/x64/fxc.exe',
        '/nologo','/T','ps_5_0','/E','main','/Ges','/WX','/Fo',str(Path(tmp)/'composite.cso'),str(path)],check=True)
    start=lua.index('rainDynamicSceneCopyState.e1PrimaryUI = function()')
    a=lua.index('shader=[[',start)+len('shader=[[');b=lua.index(']]}',a)
    preview=lua[a:b].replace('main(PS_IN pin)','main(PS_IN pin):SV_TARGET')
    header='struct PS_IN {float4 PosH:SV_POSITION;float2 Tex:TEXCOORD0;};Texture2D txGeometryPreview;SamplerState samLinearClamp;float gPreviewHDR;\n'
    path.write_text(header+preview,encoding='utf-8')
    subprocess.run(['C:/Program Files (x86)/Windows Kits/10/bin/10.0.19041.0/x64/fxc.exe',
        '/nologo','/T','ps_5_0','/E','main','/Ges','/WX','/Fo',str(Path(tmp)/'preview.cso'),str(path)],check=True)
print('PASS: actual five-mesh geometry HLSL FXC ps_5_0 /Ges /WX')
