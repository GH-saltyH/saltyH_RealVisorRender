"""H3 overlap-and-cut variants for the decision (docs/RAINFX_V2_H3_ATLAS_SPEC.md section 2.2, 2026-11-12).
Bakes 12.8 mm tiles with docs/tools/rainfx2_bake_microdrops.py at several overlap settings and shows per variant:
  owner map (CSP debug style: one flat colour per piece, 2.5 mm), lit relief (2.5 mm), game scale (12.8 mm at
  ~50 um / px, dark road under a bright sky, CSP windscreen shading) + piece size statistics.
Usage: python rainfx2_h3_overlap_variants.py OUTDIR"""
import os, sys, json
import numpy as np, cv2
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', 'tools'))
from rainfx2_bake_microdrops import bake
OUT = sys.argv[1] if len(sys.argv) > 1 else '.'

VARIANTS = [   # 2026-11-13: F (power cuts, the current atlas) vs LAYER ownership (upper drop keeps its whole outline)
    ('F  power cuts D2.2 (current atlas)', dict(mode='power', density=2.2, zmix=0.5, gapP=1.0)),
    ('L1 layers D1.5, gaps', dict(mode='layer', density=1.5)),
    ('L2 layers D2.2, gaps', dict(mode='layer', density=2.2)),
    ('L3 layers D3.0, gaps', dict(mode='layer', density=3.0)),
]
P = 300
SKY, ROAD = np.array([0.92, 0.93, 0.95], np.float32), np.array([0.13, 0.14, 0.14], np.float32)


def scene(gy, h):
    t = np.clip(gy / h, -2, 1.5)
    return SKY * np.clip(0.35 - t, 0, 1)[..., None] + ROAD * np.clip(t + 0.65, 0, 1)[..., None]


def shade(nx, ny, cov, refr):
    nz = np.sqrt(np.clip(1 - nx * nx - ny * ny, 0, 1))
    n = nx.shape[0]
    Y = np.arange(n, dtype=np.float32)[:, None] * np.ones((1, n), np.float32)
    scr = scene(Y - ny * refr, n) * (1 + 0.15 * nx[..., None])
    up = np.clip(-ny * 1.6 + 0.5, 0, 1)[..., None]
    env = (SKY * up + ROAD * (1 - up)) * 0.7
    wS = np.clip((nz - 0.3) * 10, 0, 1)[..., None]
    c = env * (1 - wS) + scr * wS + np.float32(1.0) * ((1 - nz) ** 3 * np.clip(-ny, 0, 1) * 1.2)[..., None]
    a = cov[..., None]
    return scene(Y, n) * (1 - a) + c * a


def owner(ID):
    rng = np.random.default_rng(1)
    pal = (rng.random((ID.max() + 2, 3)) * 0.75 + 0.25).astype(np.float32)
    return np.where(ID[..., None] >= 0, pal[np.maximum(ID, 0)], np.float32(0.28))


def put(img, lines):
    img = (np.clip(img, 0, 1) * 255).astype(np.uint8).copy()
    cv2.rectangle(img, (0, 0), (P, 8 + 14 * len(lines)), (0, 0, 0), -1)
    for k, t in enumerate(lines):
        cv2.putText(img, t, (4, 16 + 14 * k), cv2.FONT_HERSHEY_SIMPLEX, 0.38, (255, 255, 255), 1, cv2.LINE_AA)
    return img


rows, stats = [], {}
for name, prm in VARIANTS:
    r = bake(dict(prm, size=1024))
    st = r['stats']; stats[name] = st
    c = slice(300, 500)                                           # 200 texels = 2.5 mm
    own = cv2.resize(owner(r['id'][c, c]), (P, P), interpolation=cv2.INTER_NEAREST)
    rel = cv2.resize(shade(r['nx'][c, c], r['ny'][c, c], r['cov'][c, c], 0.3 * 1080 * 4), (P, P), interpolation=cv2.INTER_AREA)
    game = cv2.resize(shade(r['nx'], r['ny'], r['cov'], 0.3 * 1080 * 4), (256, 256), interpolation=cv2.INTER_AREA)
    game = cv2.resize(game, (P, P), interpolation=cv2.INTER_NEAREST)
    lab = ['%s' % name, 'pieces r p10 %.3f p50 %.3f p90 %.3f max %.3f mm' % (st['pieceR_p10'], st['pieceR_p50'], st['pieceR_p90'], st['pieceR_max']),
           'cover %.2f  %.0f pieces / cm2' % (st['coverage'], st['piecesPerCm2'])]
    rows.append(np.hstack([put(own, lab[:1] + ['owner map 2.5 mm']), put(rel, ['lit relief 2.5 mm']),
                           put(game, ['game scale 12.8 mm (~50 um/px, 1.17x)'] + lab[1:])]))
    print(name, json.dumps(st))
half = (len(rows) + 1) // 2
sheet = np.vstack([np.hstack([rows[i], rows[i + half]]) if i + half < len(rows) else rows[i] for i in range(half)])
cv2.imwrite(os.path.join(OUT, 'rainfx2_h3_overlap_variants.png'), sheet)
json.dump(stats, open(os.path.join(OUT, 'rainfx2_h3_overlap_variants.json'), 'w'), indent=1)
