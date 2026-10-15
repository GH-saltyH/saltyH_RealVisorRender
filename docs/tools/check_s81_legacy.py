"""Existing s80 P2 numeric/wiring gates, with s81 outputs isolated."""
from pathlib import Path
import sys
sys.dont_write_bytecode=True
ROOT=Path(__file__).resolve().parents[2]
path=ROOT/'docs/tools/check_s80_regression.py'
source=path.read_text()
source=source.replace("OUT=ROOT/'docs/diagnostics/2026-10-15/s80'","OUT=ROOT/'docs/diagnostics/2026-10-15/s81/legacy'")
source=source.replace('docs/diagnostics/2026-10-15/s80/s79_', 'docs/diagnostics/2026-10-15/s81/legacy/s79_')
source=source.replace("if kind=='gpu':", "(OUT).mkdir(parents=True,exist_ok=True)\n    if kind=='gpu':")
anchor="    exec(compile(text,str(path),'exec'),{'__file__':str(path)})"
assert source.count(anchor)==1
source=source.replace(anchor,"""    if kind=='binding':
        change('rainDynamicSceneCopyState.birthConfigured=true',
               'rainDynamicSceneCopyState.birthConfigured=true;rainDynamicSceneCopyState.filmConfigured=false')
        change("'docs/README.md','docs/RAINFX_ROADMAP.md','docs/RAINFX_S78_BIRTH_DISTRIBUTION_AND_BUDGET.md',",
               "'docs/README.md','docs/RAINFX_ROADMAP.md','docs/RAINFX_S78_BIRTH_DISTRIBUTION_AND_BUDGET.md','shaders/rainVisorDynamicDrop.hlsl',")
    exec(compile(text,str(path),'exec'),{'__file__':str(path)})""")
exec(compile(source,str(path),'exec'),{'__file__':str(path)})
