"""V1 / V2 veil prototype (docs/RAINFX_V2_H3_ATLAS_SPEC.md 8j). For haze states from the chase simulation
(docs/tools/rainfx2_h3_chase_sim.lua output), renders a 24 x 24 mm visor patch at ~0.1 mm / px (DLSS internal) with the
visor rules (layered atlas, rank threshold, 2 px resolve limit, halo atlas, R1 lens) and four veil variants:
  now   : veil = 1 - (1 - phiF)(1 - phiU), white (scatter ambient)
  V1    : phiF from the real size of the sub-visible fragments (a_F 0.025 mm instead of a_min 0.015 mm)
  V2    : unresolved coarse water = 70 % blurred scene (lenses below 2 px) + 30 % white scatter
  V1+V2 : both
Usage: python rainfx2_h3_veil_v1v2_proto.py ATLAS_DDS ATLAS_JSON SIM_TXT OUTDIR"""
import sys, os, re, json, math, struct
import numpy as np, cv2
HERE = os.path.dirname(os.path.abspath(__file__))
dds, js, simtxt, OUT = sys.argv[1:5]
J = json.load(open(js))
def load(path):
    d = open(path, 'rb').read(); n = struct.unpack('<I', d[16:20])[0]; nm = struct.unpack('<I', d[28:32])[0]
    ch, o = [], 148
    for i in range(nm):
        s = n >> i; ch.append(np.frombuffer(d[o:o + s * s * 4], np.uint8).reshape(s, s, 4).astype(np.float32) / 255); o += s * s * 4
    return ch
ATL, HAL = load(dds), load(dds.replace('.dds', '_halo.dds') if os.path.exists(dds.replace('.dds', '_halo.dds')) else dds.replace('.dds', '_Halo.dds'))
T = J['tileMM']; SDF = J['sdfRangeMM']; HR = J.get('haloR', [0.03, 0.06, 0.12, 0.24])
PIX, W, shapeK, a_min, phimax = 0.10, 240, 1.0076, 0.015, 0.55
sat = -math.log(1 - phimax) * shapeK * a_min / math.pi
yy, xx = (np.mgrid[0:W, 0:W].astype(np.float32) + 0.5) * PIX
def samp(chain, sK, nearest=False, bias=-1.0):
    tx = T / chain[0].shape[0]
    m = min(int(round(max(math.log2(PIX / (sK * tx)) + bias, 0))), len(chain) - 1)
    a = chain[m]; s = a.shape[0]
    u = ((xx / sK) % T / T * s - 0.5).astype(np.float32); v = ((yy / sK) % T / T * s - 0.5).astype(np.float32)
    return cv2.remap(a, u, v, cv2.INTER_NEAREST if nearest else cv2.INTER_LINEAR, borderMode=cv2.BORDER_WRAP)
# scene: the game screenshot at screen scale (1080 px high), patch = 240 px on the horizon / barrier / car
src = cv2.imread(os.path.join(HERE, 'rainfx2_sheet_bg.png')).astype(np.float32) / 255
H = 1080; SCR = cv2.resize(src, (int(src.shape[1] * H / src.shape[0]), H), interpolation=cv2.INTER_CUBIC)
OY, OX = 330, 900
scene = SCR[OY:OY + W, OX:OX + W]
MIP = {k: cv2.GaussianBlur(SCR, (0, 0), 2 ** k) for k in range(1, 8)}
veilC = np.array([0.82, 0.82, 0.80], np.float32)
amb = 0.55 * MIP[6][OY:OY + W, OX:OX + W] + 0.45 * veilC                       # scatter ambient (visor: scene mip -> sky veil)
blurU = MIP[5][OY:OY + W, OX:OX + W]                                            # V2: unresolved lenses = the scene averaged

def frame(Gf, Gc, aIn, variant):
    aC = max(aIn, Gc * a_min / sat * sat / sat) if False else max(aIn, Gc * sat * a_min / sat / sat * sat / sat)
    aC = max(aIn, Gc * a_min)                                                   # Gc in units of G_sat -> a = a_min Gc
    hC, hF = Gc * sat, Gf * sat
    phiC = min(1 - math.exp(-math.pi * hC / (shapeK * aC)), phimax); relC = phiC / phimax
    aF = 0.025 if variant in ('V1', 'V1+V2') else a_min
    phiF = min(1 - math.exp(-math.pi * hF / (shapeK * aF)), phimax)
    L = min(max(math.log2(aC / J['pieceR_a50']), -8), 0); L0 = math.floor(L); fL = L - L0
    D = np.zeros((W, W), np.float32); halo = np.zeros_like(D); gx = np.zeros_like(D); gy = np.zeros_like(D); res = 0
    for k in (1, 0):
        sK = 2.0 ** (L0 + k); wk = fL if k == 1 else 1 - fL
        aRes = 1 - min(2.0 * PIX / (J['pieceR_max'] * sK), 1) ** (1 / J['rankQ'])
        thr = min(relC * wk, aRes); res += max(thr, 0)
        if thr < 0.002: continue
        m = samp(ATL, sK); sd = (m[..., 2] - 0.5) * 2 * SDF * sK
        ex = np.clip((thr - m[..., 3]) / 0.003, 0, 1)
        add = ex * np.clip(sd / PIX + 0.5, 0, 1) * (1 - D)
        n = m[..., :2] * 2 - 1; nz = np.sqrt(np.clip(1 - (n ** 2).sum(-1), 0, 1))
        gx += add * (-n[..., 0] / np.maximum(nz, 0.15)); gy += add * (-n[..., 1] / np.maximum(nz, 0.15)); D += add
        hw = max(0.5 * aC, 1.5 * PIX)
        halo = np.maximum(halo, ex * np.clip(1 + sd / hw, 0, 1))
        hl = samp(HAL, sK, True, 0.0)
        for i, R in enumerate(HR):
            halo = np.maximum(halo, (hl[..., i] < thr) * max(1 - R * sK / hw, 0))
    gx /= np.maximum(D, 1e-4); gy /= np.maximum(D, 1e-4)
    # R1 lens (2-D stand-in): the image is displaced against the slope (inverted), blurred by the piece size, TIR dims rims
    sl = np.sqrt(gx * gx + gy * gy)
    rPx = max(aC / PIX, 0.5); mip = int(np.clip(math.log2(max(0.6 * H / rPx, 1)) - 1 + 1, 1, 7))
    defl = np.arctan(sl) * 0.33 / np.maximum(sl, 1e-6)                             # small-angle exit deflection per slope
    mx = (np.arange(W)[None, :] + OX + gx * defl * H * 0.9).astype(np.float32)
    my = (np.arange(W)[:, None] + OY + gy * defl * H * 0.9).astype(np.float32)
    cD = cv2.remap(MIP[mip], np.broadcast_to(mx, D.shape).copy(), np.broadcast_to(my, D.shape).copy(), cv2.INTER_LINEAR, borderMode=cv2.BORDER_REFLECT)
    tir = np.clip((sl - 1.6) / 0.6, 0, 1)[..., None]
    cD = cD * (1 - 0.65 * tir) + veilC * (0.45 * np.clip(gy, 0, None) ** 4 * (sl > 1.2))[..., None] * 0.2
    phiU = phiC * max(1 - res / max(relC, 1e-4), 0)
    keep = (1 - halo)[..., None]
    if variant in ('V2', 'V1+V2'):
        Vw = (1 - (1 - phiF) * (1 - 0.3 * phiU)); Vb = 0.7 * phiU
    else:
        Vw = 1 - (1 - phiF) * (1 - phiU); Vb = 0.0
    gap = scene * (1 - keep * (Vw + Vb)) + amb * keep * Vw + blurU * keep * Vb
    Dm = D[..., None]
    out = gap * (1 - Dm) + cD * Dm
    return out, dict(phiF=phiF, phiU=phiU, white=Vw, blur=Vb, pieces=float(D.mean()))

rows = {}
for l in open(simtxt).read().splitlines():
    m = re.match(r'(.+?)\s+(\d+)\s+(\d+)\s+\S+\s+\S+\s+\S+\s+(\S+)\s+\|\s+(\S+)\s+(\S+)', l)
    if m: rows[(m.group(1).strip(), int(m.group(2)))] = (float(m.group(5)), float(m.group(6)), float(m.group(4)))
CASES = [('Rain', 20), ('Thunderstorm', 18), ('Thunderstorm', 20), ('Heavy Thunderstorm', 20), ('Heavy Rain', 20)]
def lab(im, lines):
    im = (np.clip(im, 0, 1) * 255).astype(np.uint8).copy()
    im = cv2.resize(im, (W * 3 // 2, W * 3 // 2), interpolation=cv2.INTER_NEAREST)
    cv2.rectangle(im, (0, 0), (im.shape[1], 6 + 13 * len(lines)), (0, 0, 0), -1)
    for i, t in enumerate(lines):
        cv2.putText(im, t, (3, 13 + 13 * i), cv2.FONT_HERSHEY_SIMPLEX, 0.36, (255, 255, 255), 1, cv2.LINE_AA)
    return im
sheet = []
for nm, t in CASES:
    Gf, Gc, aIn = rows[(nm, t)]
    tiles = [lab(scene, ['%s %d s (%d km/h)' % (nm, t, {14: 110, 16: 160, 18: 200, 20: 240}[t]), 'no water'])]
    for v in ('now', 'V1', 'V2', 'V1+V2'):
        im, st = frame(Gf, Gc, aIn, v)
        tiles.append(lab(im, ['%s' % v, 'white %.2f  blur %.2f  pieces %.2f' % (st['white'], st['blur'], st['pieces'])]))
        print(nm, t, v, {k: round(x, 3) for k, x in st.items()})
    sheet.append(np.hstack(tiles))
cv2.imwrite(os.path.join(OUT, 'rainfx2_h3_veil_v1v2.png'), np.vstack(sheet))
