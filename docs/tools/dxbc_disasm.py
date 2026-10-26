#!/usr/bin/env python3
"""Minimal DXBC (SM4/SM5) container reader + disassembler, enough to read CSP shaders.
Usage: dxbc.py file.fxo [-q]
"""
import sys, struct

OPS = """ADD AND BREAK BREAKC CALL CALLC CASE CONTINUE CONTINUEC CUT DEFAULT DERIV_RTX DERIV_RTY DISCARD DIV DP2 DP3 DP4
ELSE EMIT EMITTHENCUT ENDIF ENDLOOP ENDSWITCH EQ EXP FRC FTOI FTOU GE IADD IF IEQ IGE ILT IMAD IMAX IMIN IMUL INE INEG ISHL ISHR ITOF
LABEL LD LD_MS LOG LOOP LT MAD MIN MAX CUSTOMDATA MOV MOVC MUL NE NOP NOT OR RESINFO RET RETC ROUND_NE ROUND_NI ROUND_PI ROUND_Z RSQ
SAMPLE SAMPLE_C SAMPLE_C_LZ SAMPLE_L SAMPLE_D SAMPLE_B SQRT SWITCH SINCOS UDIV ULT UGE UMUL UMAD UMAX UMIN USHR UTOF XOR
DCL_RESOURCE DCL_CONSTANT_BUFFER DCL_SAMPLER DCL_INDEX_RANGE DCL_GS_OUTPUT_TOPOLOGY DCL_GS_INPUT_PRIMITIVE DCL_MAX_OUTPUT_VERTEX_COUNT
DCL_INPUT DCL_INPUT_SGV DCL_INPUT_SIV DCL_INPUT_PS DCL_INPUT_PS_SGV DCL_INPUT_PS_SIV DCL_OUTPUT DCL_OUTPUT_SGV DCL_OUTPUT_SIV DCL_TEMPS
DCL_INDEXABLE_TEMP DCL_GLOBAL_FLAGS RESERVED0 LOD GATHER4 SAMPLE_POS SAMPLE_INFO RESERVED1 HS_DECLS HS_CONTROL_POINT_PHASE HS_FORK_PHASE
HS_JOIN_PHASE EMIT_STREAM CUT_STREAM EMITTHENCUT_STREAM INTERFACE_CALL BUFINFO DERIV_RTX_COARSE DERIV_RTX_FINE DERIV_RTY_COARSE
DERIV_RTY_FINE GATHER4_C GATHER4_PO GATHER4_PO_C RCP F32TOF16 F16TOF32 UADDC USUBB COUNTBITS FIRSTBIT_HI FIRSTBIT_LO FIRSTBIT_SHI
UBFE IBFE BFI BFREV SWAPC DCL_STREAM DCL_FUNCTION_BODY DCL_FUNCTION_TABLE DCL_INTERFACE DCL_INPUT_CONTROL_POINT_COUNT
DCL_OUTPUT_CONTROL_POINT_COUNT DCL_TESS_DOMAIN DCL_TESS_PARTITIONING DCL_TESS_OUTPUT_PRIMITIVE DCL_HS_MAX_TESSFACTOR
DCL_HS_FORK_PHASE_INSTANCE_COUNT DCL_HS_JOIN_PHASE_INSTANCE_COUNT DCL_THREAD_GROUP DCL_UAV_TYPED DCL_UAV_RAW DCL_UAV_STRUCTURED
DCL_TGSM_RAW DCL_TGSM_STRUCTURED DCL_RESOURCE_RAW DCL_RESOURCE_STRUCTURED LD_UAV_TYPED STORE_UAV_TYPED LD_RAW STORE_RAW LD_STRUCTURED
STORE_STRUCTURED ATOMIC_AND ATOMIC_OR ATOMIC_XOR ATOMIC_CMP_STORE ATOMIC_IADD ATOMIC_IMAX ATOMIC_IMIN ATOMIC_UMAX ATOMIC_UMIN
IMM_ATOMIC_ALLOC IMM_ATOMIC_CONSUME IMM_ATOMIC_IADD IMM_ATOMIC_AND IMM_ATOMIC_OR IMM_ATOMIC_XOR IMM_ATOMIC_EXCH IMM_ATOMIC_CMP_EXCH
IMM_ATOMIC_IMAX IMM_ATOMIC_IMIN IMM_ATOMIC_UMAX IMM_ATOMIC_UMIN SYNC DADD DMAX DMIN DMUL DEQ DGE DLT DNE DMOV DMOVC DTOF FTOD
EVAL_SNAPPED EVAL_SAMPLE_INDEX EVAL_CENTROID DCL_GS_INSTANCE_COUNT""".split()

REG = {0:'r',1:'v',2:'o',3:'x',4:'l',5:'d',6:'s',7:'cb',8:'icb',9:'label',10:'vPrim',11:'oDepth',12:'null',13:'rasterizer',
       14:'oMask',15:'stream',16:'fbody',17:'ftable',18:'iface',19:'fcall',20:'this',21:'vOCP',22:'vICP',23:'vForkInst',
       24:'vJoinInst',25:'vDomain',26:'vOCPid',27:'vCov',28:'vCov?',30:'t',31:'u',32:'vThreadID',33:'vThreadGroupID',
       34:'vThreadIDInGroup',35:'vCoverage',36:'vThreadIDInGroupFlattened',37:'vGSInstanceID',38:'oDepthGE',39:'oDepthLE',
       40:'vCycleCounter'}
# Note: type 30 = resource (t), 31 = UAV (u), 32 tgsm(g)
REG[6]='s'; REG[7]='cb'; REG[30]='t'; REG[31]='u'; REG[32]='g'
REG.update({33:'vThreadID',34:'vThreadGroupID',35:'vThreadIDInGroup',36:'vCoverage',37:'vThreadIDInGroupFlattened',38:'vGSInstanceID',39:'oDepthGE',40:'oDepthLE'})
# correct sm5 operand types (d3d11 tokenized program format)
REG = {0:'r',1:'v',2:'o',3:'x',4:'l',5:'d',6:'s',7:'cb',8:'icb',9:'label',10:'vPrim',11:'oDepth',12:'null',13:'rasterizer',
       14:'oMask',15:'stream',16:'fbody',17:'ftable',18:'iface',19:'fcall',20:'this',21:'vicp',22:'vocp',23:'vForkInstanceID',
       24:'vJoinInstanceID',25:'vDomain',26:'vOutputControlPointID',27:'?27',28:'vPrim?',29:'?29',30:'u',31:'g',32:'vThreadID',
       33:'vThreadGroupID',34:'vThreadIDInGroup',35:'vCoverage',36:'vThreadIDInGroupFlattened',37:'vGSInstanceID',38:'oDepthGE',
       39:'oDepthLE',40:'vCycleCounter'}
SWZ = 'xyzw'
RESDIM = {1:'buffer',2:'texture1d',3:'texture2d',4:'texture2dms',5:'texture3d',6:'texturecube',7:'texture1darray',8:'texture2darray',
          9:'texture2dmsarray',10:'texturecubearray',11:'rawbuffer',12:'structuredbuffer'}

def fmt_imm(v):
    f = struct.unpack('<f', struct.pack('<I', v))[0]
    if v in (0,) : return '0'
    if abs(f) > 1e-6 and abs(f) < 1e8 and (v & 0x7f800000) != 0:
        return ('%g' % f)
    return '%d' % (v if v < 0x80000000 else v - 0x100000000)

class Rd:
    def __init__(s, toks, i): s.t = toks; s.i = i
    def get(s):
        v = s.t[s.i]; s.i += 1; return v

def operand(r):
    tok = r.get()
    ncomp = tok & 3
    selmode = (tok >> 2) & 3
    cdata = (tok >> 4) & 0xff
    otype = (tok >> 12) & 0xff
    idim = (tok >> 20) & 3
    irep = [(tok >> 22) & 7, (tok >> 25) & 7, (tok >> 28) & 7]
    ext = tok >> 31
    mod = ''
    while ext:
        et = r.get()
        if (et & 0x3f) == 1:
            m = (et >> 6) & 0xff
            mod = {1: '-', 2: '|', 3: '-|'}.get(m, '')
        ext = et >> 31
    if otype in (4, 5):  # immediate
        n = 1 if ncomp == 1 else 4
        vals = [r.get() for _ in range(n)]
        if otype == 5: vals = vals[:n]
        return 'l(' + ', '.join(fmt_imm(v) for v in vals) + ')'
    name = REG.get(otype, '?%d' % otype)
    if otype == 6: name = 's'
    if otype == 7: name = 'cb'
    # resource t is operand type 7? fix: D3D10_SB_OPERAND_TYPE_RESOURCE=7, SAMPLER=6, CONSTANT_BUFFER=8, IMMEDIATE_CONSTANT_BUFFER=9
    name = {6: 's', 7: 't', 8: 'cb', 9: 'icb', 10: 'label', 11: 'vPrim', 12: 'oDepth', 13: 'null', 14: 'rasterizer', 15: 'oMask',
            16: 'stream', 17: 'fbody', 18: 'ftable', 19: 'iface', 20: 'fcall', 21: 'this', 22: 'vicp', 23: 'vocp',
            24: 'vForkInstanceID', 25: 'vJoinInstanceID', 26: 'vDomain', 27: 'vOutputControlPointID', 28: 'vPrim?',
            29: 'vCoverageMask', 30: 'u', 31: 'g', 32: 'vThreadID', 33: 'vThreadGroupID', 34: 'vThreadIDInGroup',
            35: 'vCoverage', 36: 'vThreadIDInGroupFlattened', 37: 'vGSInstanceID', 38: 'oDepthGE', 39: 'oDepthLE',
            40: 'vCycleCounter', 0: 'r', 1: 'v', 2: 'o', 3: 'x', 0x24: 'vThreadIDInGroupFlattened'}.get(otype, '?%d' % otype)
    idx = []
    for d in range(idim):
        rep = irep[d]
        s_ = ''
        if rep in (0, 3):
            s_ = str(r.get())
        elif rep in (1, 4):
            lo = r.get(); hi = r.get(); s_ = str(lo | (hi << 32))
        if rep in (2, 3, 4):
            rel = operand(r)
            s_ = rel + (' + ' + s_ if s_ else '')
        idx.append(s_)
    if idim == 0: s = name
    elif idim == 1:
        s = name + idx[0] if irep[0] == 0 and name in ('r','v','o','t','s','u','g','l','x') else name + '[' + idx[0] + ']'
    else:
        s = name + idx[0] + '[' + idx[1] + ']' if irep[0] == 0 else name + '[' + idx[0] + '][' + idx[1] + ']'
        if idim == 3: s += '[' + idx[2] + ']'
    if name == 'x' and idim == 2: s = 'x%s[%s]' % (idx[0], idx[1])
    if ncomp == 2:
        if selmode == 0:
            m = ''.join(SWZ[k] for k in range(4) if cdata & (1 << k))
            if m and m != 'xyzw': s += '.' + m
        elif selmode == 1:
            sw = ''.join(SWZ[(cdata >> (2 * k)) & 3] for k in range(4))
            if sw != 'xyzw': s += '.' + sw
        elif selmode == 2:
            s += '.' + SWZ[cdata & 3]
    if mod == '-': s = '-' + s
    elif mod == '|': s = '|' + s + '|'
    elif mod == '-|': s = '-|' + s + '|'
    return s

def disasm(shex):
    toks = struct.unpack('<%dI' % (len(shex) // 4), shex)
    ver = toks[0]; prog = (ver >> 16) & 0xffff
    kind = {0: 'ps', 1: 'vs', 2: 'gs', 3: 'hs', 4: 'ds', 5: 'cs'}.get(prog, '?')
    out = ['%s_%d_%d' % (kind, (ver >> 4) & 0xf, ver & 0xf)]
    i = 2; n = toks[1]
    stats = {}
    while i < n:
        t = toks[i]
        op = t & 0x7ff
        ln = (t >> 24) & 0x7f
        if op == 53:  # customdata
            ln = toks[i + 1]
            cls = (t >> 11)
            if cls == 3:  # icb
                vals = toks[i + 2:i + ln]
                out.append('dcl_immediateConstantBuffer { %s }' % ', '.join(fmt_imm(v) for v in vals[:64]) + (' ...' if len(vals) > 64 else ''))
            i += ln; continue
        if ln == 0: break
        name = OPS[op] if op < len(OPS) else 'OP%d' % op
        stats[name] = stats.get(name, 0) + 1
        r = Rd(toks, i + 1)
        ext = t >> 31
        sat = '_sat' if (t >> 13) & 1 and not name.startswith('DCL') else ''
        aoff = ''
        while ext:
            et = r.get(); ext = et >> 31
            if (et & 0x3f) == 1:
                def s4(x): return x - 16 if x & 8 else x
                aoff = '_aoff(%d,%d,%d)' % (s4((et >> 9) & 15), s4((et >> 13) & 15), s4((et >> 17) & 15))
        try:
            if name == 'DCL_TEMPS':
                txt = 'dcl_temps %d' % r.get()
            elif name == 'DCL_GLOBAL_FLAGS':
                txt = 'dcl_globalFlags 0x%x' % ((t >> 11) & 0x1fff)
            elif name == 'DCL_CONSTANT_BUFFER':
                txt = 'dcl_constantbuffer ' + operand(r) + (' dynamicIndexed' if (t >> 11) & 1 else '')
            elif name == 'DCL_RESOURCE':
                dim = (t >> 11) & 0x1f
                o = operand(r); rt = r.get()
                rts = {1:'unorm',2:'snorm',3:'sint',4:'uint',5:'float'}.get(rt & 0xf, '?')
                txt = 'dcl_resource_%s (%s) %s' % (RESDIM.get(dim, dim), rts, o)
            elif name == 'DCL_UAV_TYPED':
                dim = (t >> 11) & 0x1f
                o = operand(r); rt = r.get()
                txt = 'dcl_uav_typed_%s %s' % (RESDIM.get(dim, dim), o)
            elif name in ('DCL_RESOURCE_STRUCTURED', 'DCL_UAV_STRUCTURED'):
                o = operand(r); stride = r.get()
                txt = '%s %s stride=%d' % (name.lower(), o, stride)
            elif name in ('DCL_TGSM_STRUCTURED',):
                o = operand(r); stride = r.get(); cnt = r.get()
                txt = 'dcl_tgsm_structured %s %d x %d' % (o, stride, cnt)
            elif name in ('DCL_TGSM_RAW',):
                o = operand(r); cnt = r.get(); txt = 'dcl_tgsm_raw %s %d' % (o, cnt)
            elif name == 'DCL_THREAD_GROUP':
                txt = 'dcl_thread_group %d, %d, %d' % (r.get(), r.get(), r.get())
            elif name == 'DCL_INDEXABLE_TEMP':
                txt = 'dcl_indexableTemp x%d[%d], %d' % (r.get(), r.get(), r.get())
            elif name in ('DCL_INPUT_SIV', 'DCL_INPUT_SGV', 'DCL_OUTPUT_SIV', 'DCL_OUTPUT_SGV', 'DCL_INPUT_PS_SIV', 'DCL_INPUT_PS_SGV'):
                o = operand(r); sv = r.get(); txt = '%s %s sv%d' % (name.lower(), o, sv)
            elif name == 'DCL_INPUT_PS':
                interp = (t >> 11) & 0xf
                txt = 'dcl_input_ps %s %s' % ({1:'constant',2:'linear',3:'linear centroid',4:'linear noperspective'}.get(interp, interp), operand(r))
            elif name == 'DCL_SAMPLER':
                txt = 'dcl_sampler ' + operand(r) + (' comparison' if ((t >> 11) & 0xf) == 1 else '')
            elif name in ('DCL_RESOURCE_RAW', 'DCL_UAV_RAW', 'DCL_INPUT', 'DCL_OUTPUT'):
                txt = name.lower() + ' ' + operand(r)
            elif name in ('DCL_GS_INPUT_PRIMITIVE', 'DCL_GS_OUTPUT_TOPOLOGY'):
                txt = name.lower()
            elif name == 'DCL_MAX_OUTPUT_VERTEX_COUNT':
                txt = 'dcl_maxout %d' % r.get()
            else:
                ops = []
                end = i + ln
                if name in ('SAMPLE_L','SAMPLE','SAMPLE_B','SAMPLE_D','SAMPLE_C','SAMPLE_C_LZ','LD','GATHER4','LD_STRUCTURED','RESINFO'):
                    pass
                while r.i < end:
                    ops.append(operand(r))
                txt = name.lower() + aoff + sat + ' ' + ', '.join(ops)
                if name in ('IF', 'BREAKC', 'CONTINUEC', 'RETC', 'DISCARD', 'CALLC', 'MOVC') and name != 'MOVC':
                    txt = name.lower() + ('_nz ' if (t >> 18) & 1 else '_z ') + ', '.join(ops)
        except Exception as e:
            txt = name.lower() + ' <decode err %s>' % e
        out.append(txt)
        i += ln
    return out, stats

def chunks(data):
    assert data[:4] == b'DXBC', 'not dxbc'
    n = struct.unpack('<I', data[28:32])[0]
    offs = struct.unpack('<%dI' % n, data[32:32 + 4 * n])
    res = {}
    for o in offs:
        tag = data[o:o + 4].decode('latin1'); sz = struct.unpack('<I', data[o + 4:o + 8])[0]
        res[tag] = data[o + 8:o + 8 + sz]
    return res

def cstr(b, off):
    e = b.index(b'\0', off); return b[off:e].decode('latin1')

def rdef(b):
    ncb, cboff, nres, resoff = struct.unpack('<IIII', b[:16])
    out = []
    for k in range(nres):
        o = resoff + k * 32
        nm, typ, rtype, dim, samples, bp, bc, flags = struct.unpack('<IIIIIIII', b[o:o + 32])
        out.append('res %s type=%d dim=%d bind=%d count=%d' % (cstr(b, nm), typ, dim, bp, bc))
    for k in range(ncb):
        o = cboff + k * 24
        nm, nv, voff, size, flags, typ = struct.unpack('<IIIIII', b[o:o + 24])
        out.append('cbuffer %s size=%d' % (cstr(b, nm), size))
        for j in range(nv):
            vo = voff + j * 40
            vn, sofs, vsz, vfl, vt, dv = struct.unpack('<IIIIII', b[vo:vo + 24])
            out.append('   +%d %s (%d)%s' % (sofs, cstr(b, vn), vsz, '' if vfl & 2 else ' unused'))
    return out

def sig(b, tag):
    n, _ = struct.unpack('<II', b[:8]); out = []
    step = 32 if tag in ('OSG5',) else (28 if tag.endswith('1') else 24)
    for k in range(n):
        o = 8 + k * step
        if tag.endswith('1'): o += 4
        nm, idx, sv, ct, reg, mask = struct.unpack('<IIIIIB', b[o:o + 21])
        out.append('%s%d r%d sv%d mask%x' % (cstr(b, nm), idx, reg, sv, mask))
    return out

if __name__ == '__main__':
    data = open(sys.argv[1], 'rb').read()
    c = chunks(data)
    print('// chunks:', list(c.keys()))
    if 'RDEF' in c:
        for l in rdef(c['RDEF']): print('//', l)
    for t in ('ISGN', 'OSGN', 'ISG1', 'OSG1', 'OSG5'):
        if t in c:
            try:
                print('//', t, '|', '; '.join(sig(c[t], t)))
            except Exception as e:
                print('//', t, 'err', e)
    body = c.get('SHEX') or c.get('SHDR')
    lines, stats = disasm(body)
    if '-q' not in sys.argv:
        for l in lines: print(l)
    tex = sum(v for k, v in stats.items() if k.startswith(('SAMPLE', 'LD', 'GATHER')))
    alu = sum(v for k, v in stats.items() if not k.startswith('DCL'))
    print('// instr=%d tex/ld=%d' % (alu, tex))
