"""H3 visor micro-layer check (docs/RAINFX_V2_H3_ATLAS_SPEC.md 8h). Replicates the visor.hlsl micro block on the baked
atlas (texture/RAINFX_MicroDrops.dds + .json) for a flat 12 x 12 mm patch at the game pixel size, for a given coarse /
fine haze, and reports the piece opacity distribution (share of partially transparent pixels), the halo and the veil.
Usage: python rainfx2_h3_visor_micro_check.py DDS JSON OUTDIR [sdfRangeOverride]"""
import sys, os, json, struct, math
import numpy as np, cv2
dds, js, out = sys.argv[1], sys.argv[2], sys.argv[3]
J = json.load(open(js))
d = open(dds, 'rb').read()
n = struct.unpack('<I', d[16:20])[0]; nm = struct.unpack('<I', d[28:32])[0]
mips, off = [], 148
for i in range(nm):
    s = n >> i
    mips.append(np.frombuffer(d[off:off + s * s * 4], np.uint8).reshape(s, s, 4).astype(np.float32) / 255); off += s * s * 4
T, TX = J['tileMM'], J['tileMM'] / n
SDF = J.get('sdfRangeMM', 0.1)
HALO = None
hp = dds.replace('.dds', '_halo.dds')
if os.path.exists(hp):
    h = open(hp, 'rb').read(); hn = struct.unpack('<I', h[16:20])[0]; hm = struct.unpack('<I', h[28:32])[0]
    HALO, o = [], 148
    for i in range(hm):
        s_ = hn >> i
        HALO.append(np.frombuffer(h[o:o + s_ * s_ * 4], np.uint8).reshape(s_, s_, 4).astype(np.float32) / 255); o += s_ * s_ * 4
HALO_R = J.get('haloR', [0.03, 0.06, 0.12, 0.24])

def sample(sK, pix, W, nearest=False, bias=-1.0, chain=None):
    # SampleGrad with grads x0.5 -> lod = log2(pix / (sK TX)) - 1
    chain = chain or mips
    tx = T / chain[0].shape[0]
    lod = max(math.log2(pix / (sK * tx)) + bias, 0.0)
    m = min(int(round(lod)), len(chain) - 1)
    a = chain[m]; s = a.shape[0]
    yy, xx = (np.mgrid[0:W, 0:W].astype(np.float32) + 0.5) * pix
    u = ((xx / sK) % T / T * s - 0.5).astype(np.float32); v = ((yy / sK) % T / T * s - 0.5).astype(np.float32)
    return cv2.remap(a, u, v, cv2.INTER_NEAREST if nearest else cv2.INTER_LINEAR, borderMode=cv2.BORDER_WRAP)

def visor(hC, hF, pix=0.1, W=120, mode='old', haloK=0.5, haloPx=1.5, resPx=1.0, sdfMM=SDF, win=0.01):
    sat, a_min, shapeK, phimax = 0.00184, 0.015, 1.0076, 0.55
    aIn = 0.107
    aC = max(aIn, hC * a_min / sat)
    phiC = min(1 - math.exp(-math.pi * hC / (shapeK * aC)), phimax)
    phiF = min(1 - math.exp(-math.pi * hF / (shapeK * a_min)), phimax)
    relC = phiC / phimax
    L = min(max(math.log2(aC / J['pieceR_a50']), -8), 0); L0 = math.floor(L); fL = L - L0
    D = np.zeros((W, W), np.float32); halo = np.zeros_like(D); resSum = 0
    for k in (1, 0):
        sK = 2.0 ** (L0 + k); wk = fL if k == 1 else 1 - fL
        aRes = 1 - min(resPx * pix / (J['pieceR_max'] * sK), 1) ** (1 / J['rankQ'])
        thr = min(relC * wk, aRes); resSum += max(thr, 0)
        if thr <= 0: continue
        m = sample(sK, pix, W)
        rk = sample(sK, pix, W, True)[..., 3] if mode == 'old' else m[..., 3]   # new: one linear sample
        sd = (m[..., 2] - 0.5) * 2 * sdfMM * sK
        ex = np.clip((thr - rk) / win, 0, 1)
        add = ex * np.clip(sd / pix + 0.5, 0, 1) * (1 - D)
        D += add
        hw = haloK * aC if mode == 'old' else max(haloK * aC, haloPx * pix)
        halo = np.maximum(halo, ex * np.clip(1 + sd / hw, 0, 1))
        if mode == 'new' and HALO is not None:                  # distance to the nearest EXISTING piece (halo atlas)
            hl = sample(sK, pix, W, True, 0.0, HALO)
            for i, R in enumerate(HALO_R):
                halo = np.maximum(halo, (hl[..., i] < thr) * max(1 - R * sK / hw, 0))
    phiU = phiC * max(1 - resSum / max(relC, 1e-4), 0)
    veil = (1 - (1 - phiF) * (1 - phiU)) * (1 - halo) * (1 - D)
    part = float(((D > 0.05) & (D < 0.95)).mean()); solid = float((D >= 0.95).mean())
    return D, halo, veil, dict(aC=aC, relC=relC, octave=L, partial=part, solid=solid, veilMean=float(veil.mean()),
                               haloMean=float(halo.mean()))

def tile(img, label):
    im = (np.clip(img, 0, 1) * 255).astype(np.uint8)
    im = cv2.resize(im, (240, 240), interpolation=cv2.INTER_NEAREST)
    im = cv2.cvtColor(im, cv2.COLOR_GRAY2BGR)
    cv2.rectangle(im, (0, 0), (240, 16), (0, 0, 0), -1)
    cv2.putText(im, label, (3, 12), cv2.FONT_HERSHEY_SIMPLEX, 0.36, (255, 255, 255), 1, cv2.LINE_AA)
    return im

if __name__ == '__main__':
    sat = 0.00184
    rows = []
    for mode, sdf, win, rp in (('old', 0.1, 0.01, 1.0), ('new', SDF, 0.003, 2.0)):
        for hC in (2 * sat, 6 * sat, 12 * sat, 20 * sat):
            D, H, V, st = visor(hC, 0.3 * sat, mode=mode, sdfMM=sdf, win=win, resPx=rp)
            print('%s sdf %.2f  G_c %4.1f sat: a %.3f mm octave %+.2f relC %.2f | solid %.3f partial %.3f halo %.3f veil %.3f'
                  % (mode, sdf, hC / sat, st['aC'], st['octave'], st['relC'], st['solid'], st['partial'], st['haloMean'], st['veilMean']))
            rows.append(np.hstack([tile(D, '%s G_c %.1f: pieces' % (mode, hC / sat)), tile(H, 'halo'), tile(V * 2, 'veil x2')]))
    half = len(rows) // 2
    cv2.imwrite(os.path.join(out, 'rainfx2_h3_visor_micro_check.png'),
                np.vstack([np.hstack([rows[i], rows[i + half]]) for i in range(half)]))
