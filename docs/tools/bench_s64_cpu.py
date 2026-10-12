"""Replay real 4:1 geometry and current merge Lua; CPU time excludes CSP draws."""
from pathlib import Path
import runpy,re,json,time
import numpy as np
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'docs/diagnostics/2026-10-12/s64';OUT.mkdir(parents=True,exist_ok=True)
env=runpy.run_path(str(ROOT/'docs/tools/check_baked_housing.py'));lua=env['lua']
source=(ROOT/'realvisor.lua').read_text(encoding='utf-8')
defaults={}
for key,value in re.findall(r'\b(RAIN_\w+)\s*=\s*([-+\d.]+|true|false)\s*[,\n]',source):
    if key not in defaults:defaults[key]=True if value=='true' else False if value=='false' else float(value)
lua.globals().cfg['RUNTIME']=lua.table_from(defaults)
lua.execute('''
    ffi=require('ffi');rgbm=setmetatable({colors={transparent={}}},{__call=function(_,r,g,b,a) return {r=r,g=g,b=b,mult=a} end})
    function vec2(x,y) return {x=x or 0,y=y or 0} end
    render.TextureFormat={R8G8B8A8={UNorm=1}}
    ui={ExtraCanvas=function()
        return {setName=function(self) return self end,clear=function() end,dispose=function() end,
            update=function(_,fn) fn() end}
    end,drawRectFilled=function() end}
    rainDynamicStateHasSnapshot=true;rainDynamicStateReadbackCount=2000
    rainDynamicStateSnapshotTime=0;rainDynamicStateRenderClock=.05
    rainDynamicStateU={};rainDynamicStateV={};rainDynamicStateVelocityU={};rainDynamicStateVelocityV={}
    rainDynamicStateAlive={};rainDynamicStateRadius={}
''')
surface=lua.execute((ROOT/'rain_surface.lua').read_text(encoding='utf-8'))(ROOT.as_posix(),lua.globals().cfg['RUNTIME'])
lua.globals().rainDynamicSceneCopyState['surface']=surface
sites=np.frombuffer((ROOT/'texture/RAIN_GEOMETRY/spawn_sites.dds').read_bytes(),'<f4',offset=148).reshape(-1,4)[:2000]
du=np.frombuffer((ROOT/'texture/RAIN_GEOMETRY/du.dds').read_bytes(),'<f4',offset=148).reshape(512,2048,4)
dv=np.frombuffer((ROOT/'texture/RAIN_GEOMETRY/dv.dds').read_bytes(),'<f4',offset=148).reshape(512,2048,4)
u=du[(sites[:,1]*512).astype(int),(sites[:,0]*2048).astype(int),:3].astype(float)
v=dv[(sites[:,1]*512).astype(int),(sites[:,0]*2048).astype(int),:3].astype(float)
a=np.sum(u*u,1);b=np.sum(u*v,1);c=np.sum(v*v,1);force=np.array([0,0,-1.])
vel=np.stack((c*(u@force)-b*(v@force),a*(v@force)-b*(u@force)),1)/(a*c-b*b)[:,None]
vel/=np.linalg.norm(u*vel[:,0,None]+v*vel[:,1,None],axis=1)[:,None]
vel*=.001/.0029296875
for key,values in [('U',sites[:,0]),('V',sites[:,1]-1),('Alive',np.ones(2000)),('Radius',np.full(2000,.00085))]:
    lua.globals()['rainDynamicState'+key]=lua.table_from(values.tolist())
anchor='rainDynamicSceneCopyState.updateMergeCommands = function('
end='\nlocal function updateRainGPUState('
report=[]
for label,path in [('s63',OUT/'baseline/realvisor.lua'),('current',ROOT/'realvisor.lua')]:
    code=path.read_text(encoding='utf-8');lua.execute(code[code.index(anchor):code.index(end,code.index(anchor))])
    for scenario,speed in [('stationary',0),('driving',1.4)]:
        lua.globals().rainDynamicStateVelocityU=lua.table_from((vel[:,0]*speed).tolist())
        lua.globals().rainDynamicStateVelocityV=lua.table_from((vel[:,1]*speed).tolist())
        timings=[]
        for i in range(6):
            lua.execute(f'rainDynamicStateSnapshotTime={i};rainDynamicStateRenderClock={i+.05}')
            start=time.perf_counter();lua.globals().rainDynamicSceneCopyState['updateMergeCommands'](2000,True)
            timings.append((time.perf_counter()-start)*1000)
        p=lua.globals().rainDynamicSceneCopyState
        invalid=0
        for i in range(1,2001):
            if p['mergePX'][i] is not None and not surface['valid'](surface,p['mergePX'][i],p['mergePY'][i]):invalid+=1
        row={'source':label,'scenario':scenario,'median_cpu_ms':float(np.median(timings[1:])),
             'unsupported_grid_points':invalid,'pairs':p['mergePairs'],'attracts':p['mergeAttracts']}
        report.append(row);print(json.dumps(row),flush=True)
(OUT/'merge_benchmark.json').write_text(json.dumps(report,indent=2))
