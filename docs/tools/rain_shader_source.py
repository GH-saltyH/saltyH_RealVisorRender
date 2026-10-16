"""Test-side composition matching the production Lua shader factories."""
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]

def source(name):
    text=(ROOT/f'shaders/{name}.hlsl').read_text()
    if name=='rainBirthEvent':text=source('rainFilmPoolAddress')+text
    if name in ('rainFilmResolve','rainFilmFlow','rainFilmOptics'):
        text=source('rainFilmPoolAddress')+source('rainFilmPoolAvailable')+text
    return text
