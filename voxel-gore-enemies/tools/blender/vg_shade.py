# Bake lighting and surface detail into the voxel colours before export (GZDoom draws IQM models
# with flat sector light, so without this every cube of one material has the same colour).
# Per cube face, in sRGB:
#   key light from front-top-left, local ambient occlusion from the 8 cells around the face,
#   hemisphere ray occlusion (armpits, between legs, under the jaw), dark outlines where two
#   materials meet, a highlight on convex edges, low-frequency tone mottling, grime towards the
#   feet and sparse stains. Works on the exported copies only; the enemy's own .blend is untouched.
import numpy as np

VOX = 0.035
LIGHT = np.array([0.35, -0.55, 0.76]); LIGHT /= np.linalg.norm(LIGHT)   # front is -Y


def face_data(me):
    """Face centers, normals and the first vertex of each face (faces are split, 4 own verts each)."""
    n = len(me.polygons)
    c = np.empty(n * 3, np.float32); me.polygons.foreach_get('center', c)
    nr = np.empty(n * 3, np.float32); me.polygons.foreach_get('normal', nr)
    ls = np.empty(n, np.int32); me.polygons.foreach_get('loop_start', ls)
    lv = np.empty(len(me.loops), np.int32); me.loops.foreach_get('vertex_index', lv)
    return c.reshape(n, 3), nr.reshape(n, 3), lv, ls


def cells_of(me, origin):
    c, nr, _, _ = face_data(me)
    nr = np.round(nr)
    return np.round((c - nr * VOX / 2 - origin) / VOX).astype(np.int32)


class Grid:
    def __init__(self, cells):
        self.lo = cells.min(0) - 14
        self.occ = np.zeros(cells.max(0) - self.lo + 15, bool)
        self.occ[tuple((cells - self.lo).T)] = True

    def at(self, idx):
        i = idx - self.lo
        ok = np.all((i >= 0) & (i < self.occ.shape), axis=1)
        out = np.zeros(len(idx), bool)
        out[ok] = self.occ[tuple(i[ok].T)]
        return out


def value_noise(p, scale, seed):
    """Smooth 3D value noise on cell coordinates, 0..1."""
    q = p / scale
    i = np.floor(q).astype(np.int64); f = q - i
    f = f * f * (3 - 2 * f)

    def h(ix, iy, iz):
        x = (ix * 73856093) ^ (iy * 19349663) ^ (iz * 83492791) ^ (seed * 2654435761)
        x = (x ^ (x >> 13)) * 1274126177
        return ((x ^ (x >> 16)) & 0xFFFF) / 65535.0
    r = 0
    for dx in (0, 1):
        for dy in (0, 1):
            for dz in (0, 1):
                w = (f[:, 0] if dx else 1 - f[:, 0]) * (f[:, 1] if dy else 1 - f[:, 1]) * (f[:, 2] if dz else 1 - f[:, 2])
                r = r + w * h(i[:, 0] + dx, i[:, 1] + dy, i[:, 2] + dz)
    return r


def hemisphere(n=24):
    rng = np.random.default_rng(7)
    d = rng.normal(size=(n * 3, 3)); d /= np.linalg.norm(d, axis=1, keepdims=True)
    return d


DIRS = hemisphere()


def shade_mesh(me, grid, origin, height, strength=1.0):
    c, nr, lv, ls = face_data(me)
    nr = np.round(nr).astype(np.int32)
    cell = np.round((c - nr * VOX / 2 - origin) / VOX).astype(np.int32)
    air = cell + nr
    nf = len(c)
    col = me.attributes['Col']
    rgba = np.empty(len(col.data) * 4, np.float32); col.data.foreach_get('color_srgb', rgba)
    rgba = rgba.reshape(-1, 4)
    base = rgba[lv[ls], :3].copy()            # one colour per face (its 4 verts share it)
    is_bone = np.zeros(len(me.vertices), bool)
    if 'is_bone' in me.attributes:
        me.attributes['is_bone'].data.foreach_get('value', is_bone)
    bone_f = is_bone[lv[ls]]
    # tangent axes per face
    ax = np.abs(nr).argmax(1)
    t1 = np.zeros_like(nr); t2 = np.zeros_like(nr)
    t1[np.arange(nf), (ax + 1) % 3] = 1; t2[np.arange(nf), (ax + 2) % 3] = 1

    f = np.ones(nf)
    # key light
    ndl = (nr * LIGHT).sum(1)
    f *= np.clip(0.80 + 0.30 * ndl, 0.58, 1.12)
    # local AO: occupied cells around the air cell in front of the face
    occ_n = np.zeros(nf)
    for i in (-1, 0, 1):
        for j in (-1, 0, 1):
            if i == 0 and j == 0:
                continue
            w = 0.075 if i == 0 or j == 0 else 0.04
            occ_n += w * grid.at(air + t1 * i + t2 * j)
    f *= 1 - occ_n
    # hemisphere ray occlusion
    hits = np.zeros(nf); cnt = np.zeros(nf)
    for d in DIRS:
        cosv = nr @ d
        use = cosv > 0.15
        if not use.any():
            continue
        p0 = air[use].astype(np.float64) + 0.5
        hit = np.zeros(use.sum(), bool)
        for step in (1, 2, 3, 4, 6, 8, 11):
            hit |= grid.at(np.floor(p0 + d * step).astype(np.int32))
        hits[use] += hit * cosv[use]; cnt[use] += cosv[use]
    occ = hits / np.maximum(cnt, 1e-6)
    f *= 1 - 0.34 * occ
    # material outlines and convex edges, looking at in-plane neighbours on the same surface
    key = {tuple(k): idx for idx, k in enumerate(np.concatenate([cell, nr], 1))}
    lum = base @ np.array([0.3, 0.59, 0.11])
    outline = np.zeros(nf); edge = np.zeros(nf)
    for t in (t1, -t1, t2, -t2):
        nb = cell + t
        nb_occ = grid.at(nb)
        nb_air = grid.at(nb + nr)
        edge += (~nb_occ & ~nb_air)                 # surface turns away here: convex edge
        for k in np.nonzero(nb_occ & ~nb_air)[0]:
            o = key.get((*nb[k], *nr[k]))
            if o is None:
                continue
            dc = np.abs(base[k] - base[o]).sum()
            if dc > 0.22 and lum[k] <= lum[o] + 0.02:
                outline[k] = 1
    f *= np.where(outline > 0, 0.80, 1.0)
    f *= 1 + 0.06 * np.minimum(edge, 2)
    # tone variation, grime towards the floor, sparse stains
    pc = cell.astype(np.float64)
    f *= 1 + 0.10 * (value_noise(pc, 3.0, 1) - 0.5) * 2
    f *= 1 + 0.03 * (value_noise(pc, 1.3, 2) - 0.5) * 2
    z = (c[:, 2] - 0.0) / height
    f *= 0.86 + 0.14 * np.clip(z / 0.45, 0, 1)
    stain = np.clip((value_noise(pc, 2.2, 3) - 0.68) / 0.12, 0, 1) * ~bone_f
    f *= 1 - 0.16 * stain
    f = 1 + (f - 1) * strength
    out = np.clip(base * f[:, None], 0, 1)
    # occluded faces drift slightly cooler, lit faces slightly warmer
    shade = np.clip(1 - f, -0.2, 0.5)[:, None]
    out = np.clip(out + shade * np.array([-0.02, -0.005, 0.025]) * out.mean(1, keepdims=True), 0, 1)
    per_vert = np.empty((len(me.vertices), 3), np.float32)
    for k in range(4):
        per_vert[lv[ls + k]] = out
    rgba[:, :3] = per_vert
    col.data.foreach_set('color_srgb', rgba.ravel())
    me.update()
    return dict(faces=nf, occ=float(occ.mean()), outline=int((outline > 0).sum()))


def shade_enemy(P, zones=('head', 'torso', 'arm_l', 'arm_r', 'legs'), height=1.8):
    """Body uses its own cells; a zone model uses its own cells plus the other zones intact,
    so wound holes stay open to the light while the joints to neighbouring zones stay occluded."""
    import bpy
    body = bpy.data.objects[f'{P}_Body']
    c, nr, _, _ = face_data(body.data)
    origin = c[0] - np.round(nr[0]) * VOX / 2
    cells0 = {z: cells_of(bpy.data.objects[f'{P}_{z}_0'].data, origin) for z in zones}
    stats = {f'{P}_Body': shade_mesh(body.data, Grid(cells_of(body.data, origin)), origin, height)}
    for z in zones:
        others = [cells0[o] for o in zones if o != z]
        for s in (0, 1):
            ob = bpy.data.objects[f'{P}_{z}_{s}']
            own = cells0[z] if s == 0 else cells_of(ob.data, origin)
            stats[ob.name] = shade_mesh(ob.data, Grid(np.concatenate([own] + others)), origin, height)
    return stats
