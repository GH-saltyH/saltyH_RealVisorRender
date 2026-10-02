import re,sys
lua=open(sys.argv[1],encoding='utf-8').read().replace('\r\n','\n')
name=sys.argv[2]
i=lua.index('local %s = {'%name)
blk=lua[i:]
sh_i=blk.index('shader = [['); sh_j=blk.index(']]',sh_i)
shader=blk[sh_i+len('shader = [['):sh_j]
head=blk[:sh_i]
tex=re.findall(r'^\s*(tx\w+)\s*=',head,re.M)
vals=re.findall(r'^\s*(g\w+)\s*=\s*([^\n]*)',head,re.M)
types={}
for n,v in vals:
    t='float'
    if v.startswith('vec2'): t='float2'
    elif v.startswith('vec3'): t='float3'
    elif v.startswith('vec4') or v.startswith('rgbm'): t='float4'
    elif v.startswith('mat4x4'): t='float4x4'
    types.setdefault(n,t)
cb='cbuffer V:register(b0){'+''.join('%s %s;'%(t,n) for n,t in types.items())+'};'
cb+=''.join('Texture2D %s;'%t for t in dict.fromkeys(tex))
cb+='SamplerState samLinearClamp;struct PS_IN{float4 PosH:SV_POSITION; float2 Tex:TEXCOORD0;};\n'
defs=''.join('#define %s 1\n'%d for d in sys.argv[3:])
src=defs+cb+shader.replace('float4 main(PS_IN pin)','float4 main(PS_IN pin) : SV_TARGET')
open(sys.argv[1]+'.%s.hlsl'%name,'w').write(src)
