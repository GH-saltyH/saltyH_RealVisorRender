"""Read static KN5 assets with bounds checks and exact EOF validation."""
from pathlib import Path
import struct
import numpy as np


class KN5:
    def __init__(self,path):
        self.path=Path(path);self.blob=self.path.read_bytes();self.p=0
        assert self.take(6)==b'sc6969','Invalid KN5 signature'
        self.version=self.u32()
        if self.version>5:self.u32()
        self.textures={}
        for _ in range(self.u32()):
            active=self.u32();name=self.string();size=self.u32()
            self.textures[name]=self.take(size)
        self.materials=[]
        for _ in range(self.u32()):
            name=self.string();shader=self.string();blend=self.byte();test=self.byte();depth=self.u32()
            properties={}
            for _ in range(self.u32()):
                key=self.string();properties[key]=self.floats(10).tolist()
            slots={}
            for _ in range(self.u32()):
                key=self.string();slot=self.u32();slots[key]=self.string()
            self.materials.append(dict(name=name,shader=shader,blend=blend,alpha_test=test,depth=depth,
                properties=properties,slots=slots))
        self.meshes={};self.nodes=[]
        self.node(np.eye(4,dtype=np.float64))
        assert self.p==len(self.blob),(self.p,len(self.blob),'Unsupported KN5 trailer')

    def take(self,n):
        assert 0<=n<=len(self.blob)-self.p,(self.p,n,len(self.blob))
        value=self.blob[self.p:self.p+n];self.p+=n;return value
    def byte(self):return self.take(1)[0]
    def u32(self):return struct.unpack('<I',self.take(4))[0]
    def floats(self,n):return np.frombuffer(self.take(n*4),'<f4').copy()
    def string(self):return self.take(self.u32()).decode('utf-8')
    def node(self,parent):
        kind=self.u32();name=self.string();children=self.u32();active=self.byte()
        if kind==1:
            transform=self.floats(16).reshape(4,4).astype(np.float64)@parent
            self.nodes.append(dict(name=name,transform=transform.tolist()))
        elif kind==2:
            flags=[self.byte() for _ in range(3)]
            vertices=self.floats(self.u32()*11).reshape(-1,11)
            indices=np.frombuffer(self.take(self.u32()*2),'<u2').copy().reshape(-1,3)
            material=self.u32();layer=self.u32();lod=self.floats(2);sphere=self.floats(4);renderable=self.byte()
            assert name not in self.meshes and material<len(self.materials)
            assert np.isfinite(vertices).all() and indices.size and indices.max()<len(vertices)
            transform=parent
            self.meshes[name]=dict(vertices=vertices,indices=indices,material=material,transform=transform,
                flags=flags,active=active,renderable=renderable)
        else:raise ValueError(f'Unsupported node kind {kind}: {name}')
        for _ in range(children):self.node(transform)

    def mesh(self,name):
        data=self.meshes[name];return data['vertices'],data['indices']
    def material(self,name):return self.materials[self.meshes[name]['material']]


if __name__=='__main__':
    import json,sys
    k=KN5(sys.argv[1])
    print(json.dumps({name:dict(vertices=len(m['vertices']),triangles=len(m['indices']),
        material=k.material(name),transform=m['transform'].tolist()) for name,m in k.meshes.items()},indent=2))
