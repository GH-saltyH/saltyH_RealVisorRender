"""Read-only critical installation/asset check. Not a full dependency packager."""
import argparse,hashlib,json,re,sys
from pathlib import Path

SOURCE=Path(__file__).resolve().parents[2]
def digest(path):
 h=hashlib.sha256()
 with path.open('rb')as f:
  for block in iter(lambda:f.read(1024*1024),b''):h.update(block)
 return h.hexdigest()
def main():
 p=argparse.ArgumentParser(description=__doc__)
 p.add_argument('--root',type=Path,default=SOURCE,help='App folder containing realvisor.lua')
 p.add_argument('--check-hashes',action='store_true',help='Verify the current installed s152 asset manifest and KN5')
 args=p.parse_args();root=args.root.resolve()
 required=['manifest.ini','realvisor.lua','icon.png','material_settings.lua','native_glass_state.lua','native_glass_occlusion.lua','visor_optics.lua',
  'rain_surface.lua','rain_birth_model.lua','rain_birth_gpu.lua','rain_environment.lua','rain_physics_units.lua','rain_film.lua','rain_trails.lua',
  'shaders/rainVisorDynamicDrop.hlsl','shaders/rainTrailLine.hlsl','shaders/rainSurfaceMetric.hlsl',
  'docs/prototypes/s152/s152_assets.lua','docs/prototypes/s152/s152_context.lua','docs/probes/s151/s151_engine_inputs.lua',
  'docs/prototypes/s278/s278_graph.lua','docs/prototypes/s268/s268_producer.lua','docs/prototypes/s239/s239_packet.lua']
 # Check every current product module, including modules added after an old install.
 required+=['docs/runtime/s282/'+x.name for x in sorted((SOURCE/'docs/runtime/s282').glob('*.lua'))]
 model='visors/visor_lando_2025Champion_maxquality_diet_face.kn5';required.append(model)
 manifest=root/'docs/prototypes/s152/s152_assets.lua'
 expected={};modelHash=None
 if manifest.is_file():
  text=manifest.read_text(encoding='utf-8-sig');expected=dict(re.findall(r'\["([^"]+)"\]\s*=\s*"([0-9a-f]{64})"',text))
  m=re.search(r'modelHash="([0-9a-f]{64})"',text);modelHash=m[1]if m else None
  required+=list(expected)
 missing=[]
 for name in sorted(set(required)):
  path=root/name
  if not path.is_file():missing.append(name)
  elif path.stat().st_size==0:missing.append(name+' (empty)')
 mismatches=[];verified=0
 if args.check_hashes:
  if not expected or not modelHash:mismatches.append('invalid/missing s152 hash manifest')
  for name,sha in {**expected,**({model:modelHash}if modelHash else{})}.items():
   f=root/name
   if f.is_file():
    if digest(f)!=sha:mismatches.append(name)
    else:verified+=1
 report=dict(root=str(root),criticalFilesChecked=len(set(required)),missingOrEmpty=missing,hashesRequested=args.check_hashes,hashesVerified=verified,hashMismatches=mismatches,
  passed=not missing and not mismatches,
  limits='Critical files and installed asset manifest only; not a closed dependency inventory, release attestation, CSP execution or visual/FPS test. Copy complete runtime/prototypes/probes trees.')
 print(json.dumps(report,ensure_ascii=False,indent=2));return 0 if report['passed']else 1
if __name__=='__main__':sys.exit(main())
