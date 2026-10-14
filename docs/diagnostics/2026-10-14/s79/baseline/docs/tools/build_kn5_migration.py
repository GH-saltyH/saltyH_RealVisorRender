"""Rebuild all KN5-dependent assets in order, without modifying the KN5.

Run with the project's NumPy/Pillow Python. Blender is needed for UV bakes.
"""
from pathlib import Path
import argparse,subprocess,sys
ROOT=Path(__file__).resolve().parents[2]
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--blender',default='C:/Program Files/Blender Foundation/Blender 5.2/blender.exe')
args=parser.parse_args()
assert Path(args.blender).is_file(),'Pass --blender with the Blender executable path'
commands=[
 [sys.executable,str(ROOT/'docs/tools/build_e1_housing_bvh.py')],
 [sys.executable,str(ROOT/'docs/tools/build_visor_optics_assets.py')],
 [args.blender,'--background','--disable-autoexec','--python',str(ROOT/'docs/tools/bake_rain_surface.py')],
 [sys.executable,str(ROOT/'docs/tools/build_rain_step_limits.py')],
 [sys.executable,str(ROOT/'docs/tools/build_fx_atlases.py')],
 [sys.executable,str(ROOT/'docs/tools/build_rain_spawn_sites.py')],
 [sys.executable,str(ROOT/'docs/tools/build_visor_contamination.py')],
 [sys.executable,str(ROOT/'docs/tools/check_kn5_migration.py')],
]
for n,command in enumerate(commands,1):
    print(f'KN5 migration build {n}/{len(commands)}: {Path(command[-1]).name}',flush=True)
    subprocess.run(command,cwd=ROOT,check=True)
print('Complete. Reload the CSP app to replace KN5 references and cached bakes.')
