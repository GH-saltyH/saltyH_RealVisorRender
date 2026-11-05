#!/usr/bin/env python3
"""Compile RainFX v2 shaders the way CSP Lua does, using Microsoft FXC.

CSP compiles Lua shaders by filling templates embedded in dwrite.dll
(internal/shader-tpl/*.fx). A compile error in game terminates the whole Lua
script, so run this after every shader edit:

    python docs/tools/check_rainfx2_shaders.py
    python docs/tools/check_rainfx2_shaders.py --fxc "C:/Program Files (x86)/Windows Kits/10/bin/10.0.22621.0/x64/fxc.exe"
    python docs/tools/check_rainfx2_shaders.py --emit-only   # write assembled HLSL, no FXC

Templates are read from lights-patch-v0.3.0-preview728/dwrite.dll (not redistributed).
Texture/value declarations mirror rainfx2/init.lua (keep VALUE_TYPES in sync).
Output: tmp/rainfx2_shaders/<pass>.hlsl (+ .log on failure).
"""
import argparse, glob, io, os, re, struct, subprocess, sys, zipfile

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
DLL = os.path.join(ROOT, 'lights-patch-v0.3.0-preview728', 'dwrite.dll')
SRC = os.path.join(ROOT, 'rainfx2', 'shaders')
OUT = os.path.join(ROOT, 'tmp', 'rainfx2_shaders')

FLOAT2 = {'gR2MeanderScale', 'gR2Cells', 'gR2FieldSize', 'gR2CellSizeMM', 'gR2InvRT', 'gR2TexMM', 'gR2ScreenUp'}
FLOAT3 = {'gR2AccelW', 'gR2AirW', 'gR2RainDirW', 'gR2VeilColor', 'gR2CamPos', 'gR2CamLook', 'gR2CamSide', 'gR2CamUp'}
MATRIX = {'gR2ObjToWorld'}

# PERF-5 (2026-11-06): the texture lists are READ FROM rainfx2/init.lua (newPass / drawParams tables), not typed here.
# PERF-4 added a texture to init.lua's simulation table that this list did not have: the FXC check passed while the
# game's passes bound 15 textures -> t14, the register CSP's scene include reserves for its shadow array.
INIT = os.path.join(ROOT, 'rainfx2', 'init.lua')


def init_textures(anchor):
    src = open(INIT, encoding='utf-8').read()
    i = src.index(anchor)
    j = src.index('textures = {', i)
    depth, k = 0, j + len('textures = ')
    while True:
        ch = src[k]
        depth += ch == '{'
        depth -= ch == '}'
        k += 1
        if depth == 0:
            break
    body = re.sub(r'--[^\n]*', '', src[j:k])
    return re.findall(r'\b(tx[A-Za-z0-9]+)\s*=', body)


SCENE_TEXTURES = init_textures('local function newPass(self, shader')
VISOR_TEXTURES = init_textures('function R2:drawParams(depth)')
SOURCE_TEXTURES = ['txR2Src', 'txR2Depth']
REC_TEXTURES = init_textures('function R2:recUpdate()')   # PERF-9 drop records (own table)
MSK_TEXTURES = init_textures('  if self.recValid and self.MSK')   # PERF-10 candidate mask (own table)

PASSES = [  # name, template, files, textures, defines
    ('cells', 'ui.fx', ['common.hlsl', 'cells.hlsl'], SCENE_TEXTURES, ''),
    ('predict', 'ui.fx', ['common.hlsl', 'predict.hlsl'], SCENE_TEXTURES, ''),
    ('claim', 'ui.fx', ['common.hlsl', 'claim.hlsl'], SCENE_TEXTURES, ''),
    ('merge', 'ui.fx', ['common.hlsl', 'merge.hlsl'], SCENE_TEXTURES, ''),
    ('seed', 'ui.fx', ['common.hlsl', 'seed.hlsl'], SCENE_TEXTURES, ''),
    ('metrics', 'ui.fx', ['common.hlsl', 'metrics.hlsl'], SCENE_TEXTURES, ''),
    ('field', 'ui.fx', ['common.hlsl', 'field.hlsl'], SCENE_TEXTURES, ''),
    ('trail', 'ui.fx', ['common.hlsl', 'trail.hlsl'], SCENE_TEXTURES, ''),
    ('sheet', 'ui.fx', ['common.hlsl', 'sheet.hlsl'], SCENE_TEXTURES, ''),
    ('sheetcoef', 'ui.fx', ['common.hlsl', 'sheetcoef.hlsl'], SCENE_TEXTURES, ''),
    ('nuc', 'ui.fx', ['common.hlsl', 'nuc.hlsl'], SCENE_TEXTURES, ''),
    ('lam', 'ui.fx', ['common.hlsl', 'lam.hlsl'], SCENE_TEXTURES, ''),
    ('bead', 'ui.fx', ['common.hlsl', 'bead.hlsl'], SCENE_TEXTURES, ''),
    ('big', 'ui.fx', ['common.hlsl', 'big.hlsl'], SCENE_TEXTURES, ''),
    ('sizes', 'ui.fx', ['common.hlsl', 'sizes.hlsl'], SCENE_TEXTURES, ''),
    ('source', 'ui.fx', ['source.hlsl'], SOURCE_TEXTURES, ''),
    ('rec', 'ui.fx', ['cand.hlsl', 'rec.hlsl'], REC_TEXTURES, ''),
    ('msk', 'ui.fx', ['msk.hlsl'], MSK_TEXTURES, ''),
    ('visor', 'mesh.fx', ['cand.hlsl', 'visor.hlsl'], VISOR_TEXTURES, ''),
    ('visor_depth', 'mesh.fx', ['cand.hlsl', 'visor.hlsl'], VISOR_TEXTURES, '#define R2_DEPTH_ONLY 1\n'),
]


def load_templates():
    data = open(DLL, 'rb').read()
    for m in re.finditer(b'PK\x05\x06', data):
        e = m.start()
        cdsize, cdoff = struct.unpack('<II', data[e + 12:e + 20])
        cd = e - cdsize
        if cd < 0 or data[cd:cd + 4] != b'PK\x01\x02':
            continue
        try:
            z = zipfile.ZipFile(io.BytesIO(data[cd - cdoff:e + 22 + 65536]))
        except zipfile.BadZipFile:
            continue
        names = [n for n in z.namelist() if n.startswith('internal/shader-tpl/')]
        if names:
            return {os.path.basename(n): z.read(n).decode('utf-8', 'replace') for n in names if not n.endswith('/')}
    sys.exit('shader-tpl not found in ' + DLL)


def lua_body(anchor):
    src = open(INIT, encoding='utf-8').read()
    i = src.index(anchor)
    j = src.index('\nend\n', i)
    return re.sub(r'--[^\n]*', '', src[i:j])


def lua_assigned(*anchors):
    names = set()
    for a in anchors:
        body = lua_body(a)
        for lhs in re.findall(r'^\s*((?:v|t\.values|pass\.values)\.gR2\w+(?:\s*,\s*(?:v|t\.values)\.gR2\w+)*)\s*=', body, re.M):
            names |= set(re.findall(r'gR2\w+', lhs))
        names |= set(re.findall(r"v\['(gR2\w+?)'", body))
    return names


# PERF-9: a gR2 value a shader reads but its Lua table never sets is silently 0 in game (no compile error).
# pass -> the Lua functions that fill that pass's values table
VALUE_SOURCES = {
    'rec': ('local function candValues(self, v)',),
    'msk': ('local function candValues(self, v)',),
    'visor': ('local function candValues(self, v)', 'function R2:drawParams(depth)', 'function R2:draw(src, viewKey, depth)'),
    'visor_depth': ('local function candValues(self, v)', 'function R2:drawParams(depth)', 'function R2:draw(src, viewKey, depth)'),
}


def values_used(code):
    names = sorted(set(re.findall(r'\bgR2[A-Za-z0-9]+\b', code)))
    lines = []
    for n in names:
        t = 'float2' if n in FLOAT2 else 'float3' if n in FLOAT3 else 'float4x4' if n in MATRIX else 'float'
        lines.append('  %s %s;' % (t, n))
    return '\n'.join(lines)


def reserved_registers(text):
    # registers the CSP template includes declare (directly or through TX_SLOT_* macros)
    slots = {m.group(1): int(m.group(2)) for m in re.finditer(r'#define\s+(TX_SLOT_\w+)\s+TX_SLOT\((\d+)\)', text)}
    regs = set()
    for m in re.finditer(r'register\((t\d+|TX_SLOT_\w+)\)', text):
        r = m.group(1)
        regs.add(int(r[1:]) if r.startswith('t') and r[1:].isdigit() else slots.get(r, 999))
    return regs


def assemble(tpl, name, files, textures, defines):
    code = defines + ''.join(open(os.path.join(SRC, f), encoding='utf-8').read() + '\n' for f in files)
    tex = '\n'.join('Texture2D %s : register(t%d);' % (t, i) for i, t in enumerate(textures))
    text = tpl[name]
    rep = {
        '$DEFINES~': '', '$TEXTURES~': tex,
        '$INCLUDE_TEXTURES~': tpl['include_textures.fx'], '$INCLUDE_GENERIC~': tpl['include_generic.fx'],
        '$INCLUDE_SCENE~': tpl['include_scene.fx'], '$VALUES~': values_used(code),
        '$INCLUDE_PIN_METHODS~': tpl['include_pin_methods.fx'],
        '$INCLUDE_PIN_METHODS_GEOMETRY~': tpl['include_pin_methods_geometry.fx'],
        '$CODE~': code, '$INCLUDE_ENTRY~': tpl['include_entry.fx'],
    }
    for k, v in rep.items():
        text = text.replace(k, v)
    return text


def find_fxc(explicit):
    if explicit:
        return explicit
    for pattern in [r'C:/Program Files (x86)/Windows Kits/10/bin/*/x64/fxc.exe',
                    r'C:/Program Files (x86)/Windows Kits/8.1/bin/x64/fxc.exe']:
        hits = sorted(glob.glob(pattern))
        if hits:
            return hits[-1]
    return 'fxc'


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--fxc')
    ap.add_argument('--emit-only', action='store_true')
    ap.add_argument('--dxc', help='use DXC (ps_6_0) instead of FXC, e.g. on Linux: syntax/semantics check only')
    a = ap.parse_args()
    tpl = load_templates()
    os.makedirs(OUT, exist_ok=True)
    fxc = None if a.emit_only else (a.dxc or find_fxc(a.fxc))
    failed = 0
    # rev45: FXC (effects syntax) reserves words DXC accepts (rev45 'float pass' broke field only in FXC)
    reserved = r'pass|technique|technique10|technique11|pixelshader|vertexshader|compile|sampler_state|stateblock|string|shared|half|double|min16float|vector|matrix|texture|sampler'
    for f in sorted(glob.glob(os.path.join(SRC, '*.hlsl'))):
        code = re.sub(r'//[^\n]*', '', open(f, encoding='utf-8').read())
        for m in re.finditer(r'\b(?:float|half|int|uint|bool)[1-4]?(?:x[1-4])?\s+(' + reserved + r')\b', code):
            print('%-12s FAILED  reserved FXC identifier %r in %s' % ('names', m.group(1), os.path.basename(f)))
            failed += 1
    for name, template, files, textures, defines in PASSES:
        path = os.path.join(OUT, name + '.hlsl')
        text = assemble(tpl, template, files, textures, defines)
        open(path, 'w', encoding='utf-8').write(text)
        # PERF-5: user textures take t0..t(n-1); none may reach a register the CSP template reserves (shadow array,
        # reflection cubemap, depth, ...): a collision rebinds a CSP global for the draws that follow.
        if name in VALUE_SOURCES:
            code = re.sub(r'//[^\n]*', '', ''.join(open(os.path.join(SRC, f), encoding='utf-8').read() for f in files))
            used = set(re.findall(r'\bgR2[A-Za-z0-9]+\b', code))
            have = lua_assigned(*VALUE_SOURCES[name])
            have |= {'gR2DQ%d' % i for i in range(16)} if 'function R2:drawParams(depth)' in VALUE_SOURCES[name] else set()
            missing = sorted(used - have)
            if missing:
                print('%-12s FAILED  values read but never set in init.lua: %s' % (name, ', '.join(missing)))
                failed += 1
                continue
        res = reserved_registers(assemble(tpl, template, files, [], defines))
        limit = min(res | {999})
        if len(textures) > limit:
            print('%-12s FAILED  %d user textures reach reserved register t%d (%s allows %d)'
                  % (name, len(textures), limit, template, limit))
            failed += 1
            continue
        if not fxc:
            print('emitted', path)
            continue
        cmd = ([a.dxc, '-T', 'ps_6_0', '-E', 'entryPoint', '-HV', '2018', '-Wno-effects-syntax', '-Fo', path[:-5] + '.dxil', path]
               if a.dxc else [fxc, '/nologo', '/T', 'ps_5_0', '/E', 'entryPoint', '/O3', '/Fo', path[:-5] + '.cso', path])
        r = subprocess.run(cmd, capture_output=True, text=True)
        ok = r.returncode == 0
        failed += not ok
        log = (r.stdout or '') + (r.stderr or '')
        warnings = [l for l in log.splitlines() if 'warning' in l.lower()]
        print('%-12s %s%s' % (name, 'OK' if ok else 'FAILED', ('  (%d warnings)' % len(warnings)) if warnings else ''))
        if not ok or warnings:
            open(path[:-5] + '.log', 'w', encoding='utf-8').write(log)
            for l in log.splitlines()[:12]:
                print('   ', l)
    sys.exit(1 if failed else 0)


if __name__ == '__main__':
    main()
