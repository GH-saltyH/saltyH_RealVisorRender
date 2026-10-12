"""Freeze the relevant s65 D3D11 fixtures with s66 comparison and no suppression."""
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
p=ROOT/'docs/tools/check_s66_gpu.py'
assert not p.exists()
s=(ROOT/'docs/tools/check_s65_gpu.py').read_text(encoding='utf-8')
s=s.replace('2026-10-12/s65','2026-10-12/s66')
s=s.replace('a,old_candidates=heads(old,64,False)','a,old_candidates=heads(old,32,True)')
s=s.replace('actual 64px dense to 32px sparse bounds bins: identical water RGB','looped word channels preserve baseline water RGB')
a=s.index('    # FXC issues X4000');b=s.index("    source+='''",a)
s=s[:a]+s[b:]
s=s.replace("coverage=full.replace('    return c;\\n}', '    return float4(1,1,1,1);\\n}')", "coverage=full.replace('    return c;\\n#endif', '    return float4(1,1,1,1);\\n#endif')")
p.write_text(s,encoding='utf-8')
print('Created warning-strict s66 D3D11 fixtures')
