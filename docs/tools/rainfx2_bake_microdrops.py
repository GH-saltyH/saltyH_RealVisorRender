"""H3-1 micro-drop atlas bake (docs/RAINFX_V2_H3_ATLAS_SPEC.md section 2, user decisions 2026-11-12).

Overlap-and-cut packing (the CSP windscreen output: many small drops of several sizes packed so densely that they
overlap, each overlap resolved by a CLEAR cut, some cuts with a dry gap between the pieces):
  1. drops: Poisson positions on a periodic tile, radius pdf ~ r^-alpha on [rmin, rmax] (many small, few large),
     rmax = a_max (0.3 mm, the cell-drop threshold): a cut never enlarges a drop, so at the top octave (scale 1) no
     piece exceeds a_max -- consistent with the nucleation threshold; alpha 1.5 -> pieces p50 0.07 / p90 0.2 / max 0.29
     (the user's photo range); finer states are smaller octaves of the same tile (self-similar),
     drawn area density D = sum(pi r^2) / tile area (D > 1 -> almost every drop overlaps several others);
  2. ownership: each texel goes to the drop with the highest score
        S_i(x) = r_i^2 (1 + zmix P_i) - d_i(x)^2                  (power distance, P_i ~ U(0, 1) per drop)
     zmix 0 -> power diagram: two overlapping discs split along the straight chord through their intersections; a
     small disc deep inside a big one vanishes (it would have merged) -> no islands; small drops survive at rims / gaps;
     zmix > 0 -> random 'weight' per drop: the chord moves toward the weaker drop -> one piece nearly whole, the other a
     sliver (the CSP cyan / orange and yellow / purple pairs);
  3. gaps: a drop with probability gapP keeps a dry band of gapMM along every cut with another drop
     (one-sided or two-sided gaps, as in the CSP output); pieces smaller than minPieceTex texels are removed;
  4. every remaining PIECE becomes its own drop surface: a liquid cap of constant curvature over the piece -- the
     Poisson problem lap(h) = -kappa_i inside the piece, h = 0 on its edge (small-slope Young-Laplace; a disc gives a
     paraboloid, a cut piece a dome that follows its outline: no facets), kappa_i = 2 rimSlope / R_eq (rim slope of
     the equal-area disc), then h <- H (h / H)^steep (steeper rim, flatter top: a coated, high-contact-angle visor).
     The edge texels between two touching pieces are part of neither (h = 0) -> a V groove = a clear separation;
  5. channels: R, G = normal xy (0.5 + 0.5 n), B = signed distance to the piece outline (0.5 = edge, +-sdfRangeMM), A = rank
     (area share of the pieces sorted largest first; in a gap the rank of the nearest piece -- H3-2c; older text:) (piece id hash: the order in
     which pieces appear as the coverage rises). Own mip chain: normals averaged and renormalised (flatten), coverage
     averaged, rank of the covering piece; written as DDS (DX10 header, R8G8B8A8_UNORM).
Usage:
  python rainfx2_bake_microdrops.py --out DIR [--size 2048 --texel 0.0125 --density 2.2 --zmix 0.5 --gapP 0.5 ...]
  (import: bake(params) -> dict with id, h, nx, ny, cov, rank, stats)"""
import argparse, json, os, struct
import numpy as np
from scipy import ndimage

DEF = dict(size=2048, texel=0.0125, density=2.2, alpha=1.5, rmin=0.03, rmax=0.3, zmix=0.5,
           gapP=1.0, gapMM=0.025, minPieceTex=6, mode='layer', rimSlope=1.6, steep=0.5, sdfRangeMM=0.6, seed=7)


def bake(prm=None):
    p = dict(DEF, **(prm or {}))
    rng = np.random.default_rng(p['seed'])
    n, tx = p['size'], p['texel']
    T = n * tx
    a, lo, hi = p['alpha'], p['rmin'], p['rmax']
    # radius law pdf ~ r^-a on [lo, hi]: inverse CDF; mean area for the count
    u = rng.random(200000)
    rs = (lo ** (1 - a) + u * (hi ** (1 - a) - lo ** (1 - a))) ** (1 / (1 - a))
    N = int(p['density'] * T * T / (np.pi * np.mean(rs ** 2)))
    r = (lo ** (1 - a) + rng.random(N) * (hi ** (1 - a) - lo ** (1 - a))) ** (1 / (1 - a))
    cx, cy = rng.uniform(0, T, N), rng.uniform(0, T, N)
    P = rng.random(N)
    gap = np.where(rng.random(N) < p['gapP'], p['gapMM'], 0.0)
    # 2. ownership (periodic)
    if p['mode'] == 'layer':
        # LAYERS (user 2026-11-13): every drop has its own level; where two discs overlap the UPPER one keeps its whole
        # outline and the lower one is hidden under it (cut along the upper's arc), so one can always tell which drop
        # lies on top. A drop whose centre lies inside a larger drop is put below it (a small drop cannot sit on a
        # big one: no islands); the gap is a dry band of gapMM just outside the upper drop's rim (on the lower one).
        from scipy.spatial import cKDTree
        key = P.copy()
        tr = cKDTree(np.c_[cx, cy], boxsize=T)
        for i, j in tr.query_pairs(hi):
            dx = (cx[i] - cx[j] + T / 2) % T - T / 2; dy = (cy[i] - cy[j] + T / 2) % T - T / 2
            d = np.hypot(dx, dy)
            if r[i] > r[j] and d < r[i]: key[j] = min(key[j], key[i] - 1e-3 - 1.0)
            if r[j] > r[i] and d < r[j]: key[i] = min(key[i], key[j] - 1e-3 - 1.0)
        S = np.full((n, n), -np.inf, np.float32)
        ID = np.full((n, n), -1, np.int32)
        for i in range(N):
            rr = r[i]; k = int(np.ceil((rr + gap[i]) / tx)) + 1
            i0, j0 = int(cy[i] / tx) - k, int(cx[i] / tx) - k
            ys, xs = np.mgrid[i0:i0 + 2 * k + 1, j0:j0 + 2 * k + 1]
            d2 = ((xs + 0.5) * tx - cx[i]) ** 2 + ((ys + 0.5) * tx - cy[i]) ** 2
            yi, xi = ys % n, xs % n
            win = (d2 < rr * rr) & (key[i] > S[yi, xi])
            S[yi[win], xi[win]] = key[i]; ID[yi[win], xi[win]] = i
        DRY = np.zeros((n, n), bool)
        for i in np.where(gap > 0)[0]:                         # dry ring outside each drop, on lower drops only
            rr = r[i]; g = gap[i]; k = int(np.ceil((rr + g) / tx)) + 1
            i0, j0 = int(cy[i] / tx) - k, int(cx[i] / tx) - k
            ys, xs = np.mgrid[i0:i0 + 2 * k + 1, j0:j0 + 2 * k + 1]
            d2 = ((xs + 0.5) * tx - cx[i]) ** 2 + ((ys + 0.5) * tx - cy[i]) ** 2
            yi, xi = ys % n, xs % n
            ring = (d2 >= rr * rr) & (d2 < (rr + g) ** 2) & (S[yi, xi] < key[i]) & (ID[yi, xi] >= 0)
            DRY[yi[ring], xi[ring]] = True
        ID = np.where(DRY, -1, ID)
        pad = int(np.ceil(max(p['gapMM'], p['rmax']) / tx)) + 4
    else:
        S = np.full((n, n), -np.inf, np.float32)
        ID = np.full((n, n), -1, np.int32)
        for i in np.argsort(-r):
            rr = r[i]; k = int(np.ceil(rr / tx)) + 1
            i0, j0 = int(cy[i] / tx) - k, int(cx[i] / tx) - k
            ys, xs = np.mgrid[i0:i0 + 2 * k + 1, j0:j0 + 2 * k + 1]
            d2 = ((xs + 0.5) * tx - cx[i]) ** 2 + ((ys + 0.5) * tx - cy[i]) ** 2
            sc = (rr * rr * (1 + p['zmix'] * P[i]) - d2).astype(np.float32)
            inside = d2 < rr * rr
            yi, xi = ys % n, xs % n
            cur = S[yi, xi]
            win = inside & (sc > cur)
            S[yi[win], xi[win]] = sc[win]
            ID[yi[win], xi[win]] = i
        # 3. gaps along drop-drop cuts (wrap-padded distance transform)
        pad = int(np.ceil(max(p['gapMM'], p['rmax']) / tx)) + 4
        IDp = np.pad(ID, pad, mode='wrap')
        cut = np.zeros_like(IDp, bool)
        for sh in ((0, 1), (1, 0), (0, -1), (-1, 0)):
            nb = np.roll(IDp, sh, (0, 1))
            cut |= (IDp >= 0) & (nb >= 0) & (nb != IDp)
        dcut = ndimage.distance_transform_edt(~cut)[pad:-pad, pad:-pad] * tx
        own_gap = np.where(ID >= 0, gap[np.maximum(ID, 0)], 0.0)
        ID = np.where(dcut < own_gap, -1, ID)
    # tiny pieces out
    cnt = np.bincount(ID[ID >= 0], minlength=N)
    ID = np.where((ID >= 0) & (cnt[np.maximum(ID, 0)] < p['minPieceTex']), -1, ID)
    # 4. piece surfaces: constant-curvature caps (Poisson, Dirichlet 0 on the piece edge), all pieces in one CG solve
    from scipy.sparse import coo_matrix
    from scipy.sparse.linalg import cg
    cnt = np.bincount(ID[ID >= 0], minlength=N)
    inner = ID >= 0
    for sh in ((0, 1), (1, 0), (0, -1), (-1, 0)):          # a texel touching another owner / dry is the edge (h = 0)
        inner &= np.roll(ID, sh, (0, 1)) == ID
    idx = np.full((n, n), -1, np.int64)
    m = int(inner.sum()); idx[inner] = np.arange(m)
    rows, cols, vals = [np.arange(m)], [np.arange(m)], [np.full(m, 4.0)]
    for sh in ((0, 1), (1, 0), (0, -1), (-1, 0)):
        nb = np.roll(idx, sh, (0, 1))
        ok = inner & (nb >= 0)
        rows.append(idx[ok]); cols.append(nb[ok]); vals.append(np.full(int(ok.sum()), -1.0))
    A = coo_matrix((np.concatenate(vals), (np.concatenate(rows), np.concatenate(cols))), shape=(m, m)).tocsr()
    req_t = np.sqrt(np.maximum(cnt, 1) / np.pi)                  # equal-area radius (texels)
    kap = (2 * p['rimSlope'] / req_t)[ID[inner]]                 # per texel^2 units (h in texels)
    sol, info = cg(A, kap, maxiter=3000, rtol=1e-5) if 'rtol' in cg.__code__.co_varnames else cg(A, kap, maxiter=3000, tol=1e-5)
    h = np.zeros((n, n), np.float64); h[inner] = np.maximum(sol, 0)
    lab = ID + 1
    present = np.unique(lab[lab > 0])
    hm = np.zeros(N + 1); hm[present] = ndimage.maximum(h, lab, present)
    H = np.where(ID >= 0, hm[lab], 1.0)
    h = np.where(ID >= 0, H * (h / np.maximum(H, 1e-9)) ** p['steep'], 0.0)
    h = (h * tx).astype(np.float32)                              # texels -> mm
    gx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) / (2 * tx)
    gy = (np.roll(h, -1, 0) - np.roll(h, 1, 0)) / (2 * tx)
    l = np.sqrt(1 + gx * gx + gy * gy)
    nx, ny = (-gx / l).astype(np.float32), (-gy / l).astype(np.float32)
    cov = (ID >= 0).astype(np.float32)
    cnt = np.bincount(ID[ID >= 0], minlength=N)
    # 5a. signed distance to the piece outline (mm, + inside) and, in the dry gaps, the id of the NEAREST piece
    #     (H3-2c: crisp edges at any magnification + each piece's own wipe halo just outside its rim)
    rng_mm = p['sdfRangeMM']
    padS = int(np.ceil(rng_mm / tx)) + 4
    IDp = np.pad(ID, padS, mode='wrap')
    border = np.zeros_like(IDp, bool)
    for sh in ((0, 1), (1, 0), (0, -1), (-1, 0)):
        border |= np.roll(IDp, sh, (0, 1)) != IDp
    border &= IDp >= 0
    din = ndimage.distance_transform_edt(~border)
    dout, idx = ndimage.distance_transform_edt(IDp < 0, return_indices=True)
    near = IDp[idx[0], idx[1]]
    sdp = np.where(IDp >= 0, din + 0.5, -(dout - 0.5)) * tx
    sd = np.clip(sdp[padS:-padS, padS:-padS], -rng_mm, rng_mm).astype(np.float32)
    IDn = np.where(ID >= 0, ID, near[padS:-padS, padS:-padS])
    # 5b. rank = cumulative AREA share of the pieces sorted by size, largest first (H3-2c): a piece exists when its
    #     rank < threshold, so (1) the covered share grows linearly with the threshold, (2) the pieces too small to be
    #     resolved are exactly the ranks above A_res = 1 - (k R_res / (r_max s))^(1 / q)  (radius(rank) ~ r_max (1 - rank)^q)
    ids = np.where(cnt > 0)[0]
    area = cnt[ids].astype(np.float64)
    order = np.argsort(-area * np.exp(rng.normal(0, 0.08, len(ids))))
    cum = np.cumsum(area[order]); tot = cum[-1]
    rk_piece = np.ones(N + 1, np.float32)
    rk_piece[ids[order]] = ((cum - 0.5 * area[order]) / tot).astype(np.float32)
    rank = rk_piece[np.maximum(IDn, 0)]
    req = np.sqrt(cnt[cnt > 0] * tx * tx / np.pi)
    rr = np.sqrt(area[order] * tx * tx / np.pi); aa = (cum - 0.5 * area[order]) / tot
    fit = (aa > 0.02) & (aa < 0.98)
    q = float(np.polyfit(np.log(1 - aa[fit]), np.log(rr[fit] / rr.max()), 1, w=np.sqrt(area[order][fit]))[0])
    st = dict(drops=int(N), pieces=int((cnt > 0).sum()), coverage=float(cov.mean()),
              pieceR_p10=float(np.percentile(req, 10)), pieceR_p50=float(np.percentile(req, 50)),
              pieceR_p90=float(np.percentile(req, 90)), pieceR_max=float(req.max()),
              piecesPerCm2=float((cnt > 0).sum() / (T * T) * 100), tileMM=T, rankQ=q, sdfRangeMM=rng_mm,
              pieceR_a50=float(np.interp(0.5, aa, rr)),   # area-weighted median radius = the octave reference a50
              rankRadius=[float(np.interp(x, aa, rr)) for x in (0.05, 0.25, 0.5, 0.75, 0.95)])
    return dict(id=ID, h=h, nx=nx, ny=ny, cov=cov, rank=rank, sd=sd, stats=st, prm=p)


def mips(res):
    """own mip chain: average normal (renormalised xy of the averaged vector), coverage / height / signed distance mean,
    rank of the texel with the largest signed distance (the piece that owns most of the block; in a gap the nearest)."""
    nx, ny, h, cov, rank, sd = res['nx'], res['ny'], res['h'], res['cov'], res['rank'], res['sd']
    nz = np.sqrt(np.clip(1 - nx * nx - ny * ny, 0, 1)) * cov + (1 - cov)   # dry texels count as flat
    nx, ny = nx * cov, ny * cov
    out = []
    while True:
        out.append((nx / np.maximum(np.sqrt(nx * nx + ny * ny + nz * nz), 1e-6),
                    ny / np.maximum(np.sqrt(nx * nx + ny * ny + nz * nz), 1e-6), h, cov, rank, sd))
        if nx.shape[0] == 1:
            break
        def dn(x): return 0.25 * (x[0::2, 0::2] + x[1::2, 0::2] + x[0::2, 1::2] + x[1::2, 1::2])
        def blk(x): return x.reshape(x.shape[0] // 2, 2, x.shape[1] // 2, 2).transpose(0, 2, 1, 3).reshape(-1, 4)
        rk, sv = blk(rank), blk(sd)
        rank = rk[np.arange(len(rk)), np.argmax(sv, 1)].reshape(nx.shape[0] // 2, -1)
        nx, ny, nz, h, cov, sd = dn(nx), dn(ny), dn(nz), dn(h), dn(cov), dn(sd)
    return out


def write_dds(path, chain, hmax):
    """DX10 DDS, DXGI_FORMAT_R8G8B8A8_UNORM (28), full mip chain."""
    n = chain[0][0].shape[0]
    hdr = bytearray(124)
    flags = 0x1 | 0x2 | 0x4 | 0x1000 | 0x20000 | 0x8
    struct.pack_into('<7I', hdr, 0, 124, flags, n, n, n * 4, 0, len(chain))
    struct.pack_into('<8I', hdr, 72, 32, 0x4, struct.unpack('<I', b'DX10')[0], 0, 0, 0, 0, 0)
    struct.pack_into('<I', hdr, 104, 0x1000 | 0x400000 | 0x8)              # caps: texture | mipmap | complex
    dx10 = struct.pack('<5I', 28, 3, 0, 1, 0)
    with open(path, 'wb') as f:
        f.write(b'DDS ' + bytes(hdr) + dx10)
        for nx, ny, h, cov, rank, sd in chain:
            px = np.dstack([0.5 + 0.5 * nx, 0.5 + 0.5 * ny, 0.5 + 0.5 * sd / hmax, rank])   # B = signed distance / range
            f.write(np.clip(np.round(px * 255), 0, 255).astype(np.uint8).tobytes())


HALO_R = (0.03, 0.06, 0.12, 0.24)   # mm (atlas scale 1): radii of the 'nearest existing piece' tests


def write_halo(path, res):
    """H3-2d HALO ATLAS (docs/RAINFX_V2_H3_ATLAS_SPEC.md 8h): half-resolution RGBA8, channel i = the smallest piece rank
    within HALO_R[i] (square window) of the texel. In the visor a piece exists when rank < threshold, so 'an EXISTING
    piece lies within R_i' is minRank_i < threshold -> distance to the nearest existing piece, also across the area of
    pieces that do not exist yet (the per-texel SDF / rank only knows the nearest piece, whatever its state: the halo
    reached only the 0.025 mm gaps). Mips: min of the 2 x 2 block."""
    from scipy.ndimage import minimum_filter
    rank, tx = res['rank'], res['prm']['texel']
    r2 = rank.reshape(rank.shape[0] // 2, 2, rank.shape[1] // 2, 2).min(axis=(1, 3))
    tx2 = 2 * tx
    ch = [minimum_filter(r2, size=2 * int(round(R / tx2)) + 1, mode='wrap') for R in HALO_R]
    img = np.dstack(ch).astype(np.float32)
    n = img.shape[0]
    hdr = bytearray(124)
    chain = [img]
    while chain[-1].shape[0] > 1:
        a = chain[-1]
        chain.append(a.reshape(a.shape[0] // 2, 2, a.shape[1] // 2, 2, 4).min(axis=(1, 3)))
    struct.pack_into('<7I', hdr, 0, 124, 0x1 | 0x2 | 0x4 | 0x1000 | 0x20000 | 0x8, n, n, n * 4, 0, len(chain))
    struct.pack_into('<8I', hdr, 72, 32, 0x4, struct.unpack('<I', b'DX10')[0], 0, 0, 0, 0, 0)
    struct.pack_into('<I', hdr, 104, 0x1000 | 0x400000 | 0x8)
    with open(path, 'wb') as f:
        f.write(b'DDS ' + bytes(hdr) + struct.pack('<5I', 28, 3, 0, 1, 0))
        for a in chain:
            f.write(np.clip(np.round(a * 255), 0, 255).astype(np.uint8).tobytes())


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--out', required=True)
    for k, v in DEF.items():
        ap.add_argument('--' + k, type=type(v), default=v)
    a = vars(ap.parse_args())
    out = a.pop('out')
    os.makedirs(out, exist_ok=True)
    res = bake(a)
    hmax = float(res['h'].max())
    write_dds(os.path.join(out, 'microdrops.dds'), mips(res), res['prm']['sdfRangeMM'])
    write_halo(os.path.join(out, 'microdrops_halo.dds'), res)
    st = dict(res['stats'], heightMaxMM=hmax, haloR=list(HALO_R), params=res['prm'])
    json.dump(st, open(os.path.join(out, 'microdrops.json'), 'w'), indent=1)
    print(json.dumps(st, indent=1))


if __name__ == '__main__':
    main()
