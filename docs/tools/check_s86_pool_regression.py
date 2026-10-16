"""P3/P4 numerical gates with current shader composition; isolate s86 output."""
from pathlib import Path
import sys,shutil
sys.dont_write_bytecode=True
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'docs/diagnostics/2026-10-15/s86'
for stage,name in [('s81','check_s81_film_gpu.py'),('s83','check_s83_flow_gpu.py')]:
    path=ROOT/'docs/tools'/name;text=path.read_text()
    original=f"OUT=ROOT/'docs/diagnostics/2026-10-15/{stage}'"
    assert original in text;text=text.replace(original,"OUT=ROOT/'docs/diagnostics/2026-10-15/s86'")
    if stage=='s81':
        # The baseline is the user stamp with P4a. This test's old shader is
        # referenced only by other stages, not these P3 numerical fixtures.
        pass
    else:
        # These historical comparisons intentionally target pre-P4 and pre-Kahan
        # shaders; preserve their exact old references rather than s85 versions.
        anchor="baseline=(OUT/'baseline/shaders/rainFilmResolve.hlsl').read_text()"
        assert text.count(anchor)==1
        text=text.replace(anchor,"baseline=(ROOT/'docs/diagnostics/2026-10-15/s83/baseline/shaders/rainFilmResolve.hlsl').read_text()")
        anchor="(OUT/'baseline/shaders/rainFilmBlocks.hlsl').read_text()";assert text.count(anchor)==1
        text=text.replace(anchor,"(ROOT/'docs/diagnostics/2026-10-15/s83/baseline/shaders/rainFilmBlocks.hlsl').read_text()")
    exec(compile(text,str(path),'exec'),{'__file__':str(path)})
    shutil.copy2(OUT/'gpu_checks.json',OUT/f'{stage}_gpu_regression.json')
print('s86 regression: production P3/P4 numerical fixtures passed')
