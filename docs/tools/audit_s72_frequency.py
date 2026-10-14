"""Direction sampling over actual baked UV metrics: resolvable trail waves."""
from pathlib import Path
import numpy as np,json,re
root=Path(__file__).resolve().parents[2];out=root/'docs/diagnostics/2026-10-13/s72'
source=(root/'realvisor.lua').read_text(encoding='utf-8')
saved=Path('D:/Games/Assetto Corsa/apps/lua/realvisor/settings_mats.ini').read_text(encoding='utf-8-sig')
cfg={}
for k,v in re.findall(r'^\s*(RAIN_[A-Z0-9_]+)\s*=\s*([\d.]+)',source,re.M):cfg.setdefault(k,float(v))
cfg.update({k:float(v) for k,v in re.findall(r'^(RAIN_[A-Z0-9_]+)=([\d.eE+-]+)\s*$',saved,re.M)})
def bake(k):return np.frombuffer((root/f'texture/RAIN_GEOMETRY/{k}.dds').read_bytes(),'<f4',offset=148).reshape(512,2048,4)
sites=np.frombuffer((root/'texture/RAIN_GEOMETRY/spawn_sites.dds').read_bytes(),'<f4',offset=148).reshape(8192,4)[:4096]
ix=np.clip((sites[:,0]*2048).astype(int),0,2047);iy=np.clip((sites[:,1]*512).astype(int),0,511)
du=bake('du')[iy,ix];dv=bake('dv')[iy,ix]
unit=.001/cfg['RAIN_GPU_STATE_PHYSICAL_DIAMETER_UV_PER_MM']
a=np.linalg.norm(du[:,:3],axis=1);b=np.sum(du[:,:3]/np.maximum(a[:,None],1e-9)*dv[:,:3],axis=1)
c=np.sqrt(np.maximum(np.sum(dv[:,:3]**2,axis=1)-b*b,1e-18));a/=unit;b/=unit;c/=unit
size=cfg['RAIN_DYNAMIC_WATER_FIELD_TRAIL_SIZE'];r=.65*cfg['RAIN_GPU_STATE_PHYSICAL_DIAMETER_UV_PER_MM']/2
shear=.6;x=np.clip((shear-.3)/.5,0,1);widen=x*x*(3-2*x)
sheet=np.clip((shear-.15)/.5,0,1);sheet=sheet*sheet*(3-2*sheet)
width=max(r*cfg['RAIN_DYNAMIC_WATER_FIELD_TRAIL_WIDTH']*(1+cfg['RAIN_DYNAMIC_WATER_FIELD_SHEET_WIDEN']*widen*sheet),
    cfg['RAIN_NEW_TRAIL_MIN_FOOTPRINT_MM']*cfg['RAIN_GPU_STATE_PHYSICAL_DIAMETER_UV_PER_MM']/2)
angles=np.arange(8)*np.pi/8
along=.5*(np.abs(a[:,None]/size*np.cos(angles))+np.abs(b[:,None]*4/size*np.cos(angles)+c[:,None]*4/size*np.sin(angles)))
valid=(du[:,3]>.5)&(a>1e-7)&(c>1e-7)
ratio=along[valid]/width
report={'sites':int(valid.sum()),'directions_per_site':8,'assumed_display_diameter_mm':.65,'shear':shear,
 'bead_cycles_per_output_footprint':cfg['RAIN_NEW_TRAIL_BEAD_CYCLES_D'],
 'output_trail_width_mm':width*2/cfg['RAIN_GPU_STATE_PHYSICAL_DIAMETER_UV_PER_MM'],
 'unresolved_bead_fraction':float(np.mean(ratio*cfg['RAIN_NEW_TRAIL_BEAD_CYCLES_D']>=.5)),
 'unresolved_ripple_fraction':float(np.mean(ratio>=.5)),
 'ripple_sampling_ratio_percentiles':np.percentile(ratio,[10,50,90]).tolist(),
 'limits':'Actual surface metrics, sampled directions, controlled diameter/shear; not a recorded game velocity distribution.'}
(out/'frequency_audit.json').write_text(json.dumps(report,indent=2));print(json.dumps(report))
