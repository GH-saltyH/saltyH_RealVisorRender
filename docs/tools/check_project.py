"""Small maintained source/dependency/syntax check; not a GPU/game test."""
import argparse,ast,json,re,tempfile,sys
from pathlib import Path
sys.dont_write_bytecode=True
ROOT=Path(__file__).resolve().parents[2]

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--syntax',action='store_true');args=p.parse_args()
 manifest=json.loads((ROOT/'docs/development/runtime_dependencies.json').read_text())
 paths=[ROOT/n for n in manifest['files']];missing=[str(x.relative_to(ROOT))for x in paths if not x.is_file()]
 errors=[];raw=(ROOT/'realvisor.lua').read_bytes();text=raw.decode('utf-8-sig')
 if not raw.startswith(b'\xef\xbb\xbf')or b'\r\r\n'in raw:errors.append('main encoding/newline contract')
 menus=re.findall(r'rainDynamicSceneCopyState\.s(\d+)\w*UI=function',text)
 if any(n!='282'for n in menus):errors.append('retired diagnostic menu remains')
 # Literal stage module references must resolve within the retained tree.
 for path in paths:
  if not path.is_file():continue
  body=path.read_text(encoding='utf-8-sig')
  for stage,name in re.findall(r"(?:load|preload)\(\s*['\"](s\d+)['\"]\s*,\s*['\"]([\w]+)['\"]",body):
   f=ROOT/'docs/prototypes'/stage/(name+'.lua')
   if not f.is_file():errors.append(str(f.relative_to(ROOT)))
 for path in (ROOT/'docs/tools').glob('*.py'):ast.parse(path.read_text(encoding='utf-8-sig'),filename=str(path))
 syntax=0
 if args.syntax and not missing:
  from lua_runtime import load_lua
  scratch=ROOT/'tmp';scratch.mkdir(exist_ok=True)
  with tempfile.TemporaryDirectory(prefix='lua_validation_',dir=scratch,ignore_cleanup_errors=True)as tmp:
   lua=load_lua(tmp);check=lua.eval('function(s,n)local f,e=loadstring(s,n);assert(f,e);return true end')
   for path in paths:check(path.read_text(encoding='utf-8-sig'),str(path));syntax+=1
 report=dict(runtimeFiles=len(paths),missing=missing,errors=sorted(set(errors)),syntaxCompiled=syntax,passed=not missing and not errors,
  limits='No engine execution, shader compile, physics/render parity, GPU timing or dependency-minimality proof.')
 print(json.dumps(report,indent=2));return 0 if report['passed']else 1
if __name__=='__main__':sys.exit(main())
