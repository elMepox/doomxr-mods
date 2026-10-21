# Build one enemy for the combined mod, headless and read-only on the enemy's own .blend:
#   python vg_build.py <enemy> <prefix> <kind> <src.blend> <out_models_dir> <out_game.blend>
# Opens the source, builds the game Actions (vg_anims), bakes the palette and writes the IQMs:
#   <p>_anims.iqm (body + all Actions), <p>_<zone>_<0|1>.iqm, <p>_pal.png. Saves a copy as <out_game.blend>.
import bpy, sys, os, math, importlib.util
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import vg_anims, vg_shade

enemy, P, kind, src, out_dir, out_blend = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else sys.argv[-6:]
TOOLS = os.environ.get('VG_TOOLS', HERE)   # iqm_export.py lies next to this script
SCALE = 56.0 / 1.8          # same world scale for every enemy: 1 m = 31.1 map units, so voxels match in size
BLOCK = 8
p = P.lower()

spec = importlib.util.spec_from_file_location('iqm_export', os.path.join(TOOLS, 'iqm_export.py'))
iqm = importlib.util.module_from_spec(spec); spec.loader.exec_module(iqm)
try:
    iqm.register()
except ValueError:
    pass

bpy.ops.wm.open_mainfile(filepath=src)
e, acts = vg_anims.build_actions(P, kind)
names = [a.name for a in acts]
print('ACTIONS', P, names)


def bake_palette(objs, out_png):
    """zm_export.bake_palette: quantize face colors into 8x8 blocks of a shared texture (GZDoom IQM ignores vertex colors)."""
    keyed, per_obj = {}, []
    for ob in objs:
        me = ob.data
        col = me.attributes['Col']
        n = len(col.data)
        c = np.empty(n * 4, dtype=np.float32)
        col.data.foreach_get('color_srgb', c)
        c = np.clip(c.reshape(n, 4)[:, :3], 0, 1)
        q = np.round(c * 63).astype(np.int32)
        if col.domain == 'CORNER':
            lq = q
        else:
            loops = np.empty(len(me.loops), dtype=np.int32)
            me.loops.foreach_get('vertex_index' if col.domain == 'POINT' else 'vertex_index', loops)
            if col.domain == 'FACE':
                fl = np.empty(len(me.loops), dtype=np.int32)
                for poly in me.polygons:
                    fl[poly.loop_start:poly.loop_start + poly.loop_total] = poly.index
                lq = q[fl]
            else:
                lq = q[loops]
        keys = lq[:, 0] * 4096 + lq[:, 1] * 64 + lq[:, 2]
        for k in np.unique(keys):
            keyed.setdefault(int(k), len(keyed))
        per_obj.append((ob, keys))
    cols = int(math.ceil(math.sqrt(len(keyed))))
    side = 1
    while side < cols * BLOCK:
        side *= 2
    per_row = side // BLOCK
    img = np.zeros((side, side, 4), dtype=np.float32); img[..., 3] = 1
    for k, i in keyed.items():
        x, y = (i % per_row) * BLOCK, (i // per_row) * BLOCK
        img[y:y + BLOCK, x:x + BLOCK, :3] = ((k // 4096) / 63, ((k // 64) % 64) / 63, (k % 64) / 63)
    im = bpy.data.images.new(f'{p}_pal', side, side, alpha=False)
    im.colorspace_settings.name = 'sRGB'
    im.pixels.foreach_set(img.ravel())
    im.filepath_raw = out_png; im.file_format = 'PNG'; im.save()
    mat = bpy.data.materials.new(f'{p}_pal'); mat.use_nodes = True
    nt = mat.node_tree
    bsdf = next(n for n in nt.nodes if n.bl_idname == 'ShaderNodeBsdfPrincipled')
    tex = nt.nodes.new('ShaderNodeTexImage'); tex.image = im; tex.interpolation = 'Closest'
    nt.links.new(tex.outputs['Color'], bsdf.inputs['Base Color'])
    for ob, keys in per_obj:
        me = ob.data
        uv = me.uv_layers.get('PAL') or me.uv_layers.new(name='PAL')
        me.uv_layers.active = uv
        idx = np.array([keyed[int(k)] for k in keys])
        u = ((idx % per_row) * BLOCK + BLOCK / 2) / side
        v = ((idx // per_row) * BLOCK + BLOCK / 2) / side
        uv.data.foreach_set('uv', np.stack([u, v], 1).ravel().astype(np.float32))
        for other in [l for l in me.uv_layers if l.name != 'PAL']:
            me.uv_layers.remove(other)
        me.materials.clear(); me.materials.append(mat)
    return len(keyed), side


os.makedirs(out_dir, exist_ok=True)
zones = [f'{P}_{z}_{l}' for z in e.used for l in (0, 1)]
objs = [e.body] + [bpy.data.objects[n] for n in zones]
if os.environ.get('VG_SHADE', '1') == '1':
    print('SHADE', vg_shade.shade_enemy(P, zones=e.used, height=e.height))
ncol, side = bake_palette(objs, os.path.join(out_dir, f'{p}_pal.png'))
vl = bpy.context.view_layer
for c in bpy.data.collections:
    c.hide_viewport = False
for lc in vl.layer_collection.children:
    lc.exclude = False; lc.hide_viewport = False
for ob in objs + [e.arm]:
    ob.hide_viewport = False; ob.hide_set(False)


def export(path, mesh, anims):
    for o in vl.objects:
        o.select_set(False)
    e.arm.select_set(True); mesh.select_set(True)
    vl.objects.active = e.arm
    # explicit selection context: the interactive Blender runs MCP code from a timer without one
    with bpy.context.temp_override(selected_objects=[e.arm, mesh], active_object=e.arm, object=e.arm):
        bpy.ops.export.iqm(filepath=path, usemesh=True, usemods=False, useskel=True, usebbox=True,
                           usecol=False, usescale=SCALE, animspec=','.join(anims), matfmt='m')


export(os.path.join(out_dir, f'{p}_anims.iqm'), e.body, names)
for n in zones:
    export(os.path.join(out_dir, n.lower() + '.iqm'), bpy.data.objects[n], [])
bpy.ops.wm.save_as_mainfile(filepath=out_blend, copy=True)
for f in sorted(os.listdir(out_dir)):
    print('FILE', f, os.path.getsize(os.path.join(out_dir, f)))
print('DONE', P, 'colors', ncol, 'palette', side, 'height_m', round(e.height, 2), 'frames',
      {a.name: int(a.frame_range[1]) for a in acts})
