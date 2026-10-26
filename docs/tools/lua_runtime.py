"""Shared LuaJIT loader for maintained asset builders and syntax checks."""
from pathlib import Path
import sys,zipfile

def load_lua(folder):
 try:
  from lupa.luajit21 import LuaRuntime
  return LuaRuntime()
 except ImportError:
  pass
 # Compatibility with the existing offline development environment. A normal
 # installation should install Lupa in its Python environment instead.
 for wheel in (Path.home()/'AppData/Local/pip/Cache/http-v2').rglob('*.body'):
  try:
   with zipfile.ZipFile(wheel)as z:
    if any('lupa/luajit21'in n for n in z.namelist()):
     z.extractall(folder);sys.path.insert(0,str(folder))
     from lupa.luajit21 import LuaRuntime
     return LuaRuntime()
  except zipfile.BadZipFile:continue
 raise RuntimeError('Install Lupa with LuaJIT2.1: python -m pip install lupa')
