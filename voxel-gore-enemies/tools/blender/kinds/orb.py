# vg_anims kind "orb": floating balls (Cacodemon; base for the Pain Elemental). Bones: pivot (the parentless
# bone at the centre of the ball, moved by the spec key 'root', which is why it is not named root), body
# (pivot at the bottom of the ball: a squash keeps it on the floor), eye, lid, jaw, tongue, horn.L/R.
# Specs skip bones a skeleton lacks, so smaller orbs reuse this.
# Flyers die in the air: the zone death (death_eye / death_air / death_blast) ends in the limp pose LIMP,
# death_fall loops from LIMP while the body drops, death_land is the splat (squash via body scale keys).
import bpy
from mathutils import Vector

X, Y, Z = Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1))
REST = True


def R(e, off, rots=()):
    """root offset in metres (vg_anims scales root offsets by the enemy's height, undo that here)"""
    return (tuple(v / e.k for v in off), list(rots))


# 2 s float: slow bob, the eye glances, one blink, the jaw breathes (root offsets in metres x height/1.8)
IDLE = [
    (1, {'root': ((0, 0, 0), []), 'jaw': [(X, 6)], 'eye': [(Z, -8)]}),
    (18, {'root': ((0, 0, 0.03), [(Y, 3)]), 'jaw': [(X, 9)], 'eye': [(Z, -8)]}),
    (36, {'root': ((0, 0, 0), [(X, 2)]), 'jaw': [(X, 5)], 'eye': [(Z, 9), (X, 4)]}),
    (40, {'root': ((0, 0, -0.005), [(X, 2)]), 'jaw': [(X, 5)], 'eye': [(Z, 9)], 'lid': [(X, 70)]}),
    (44, {'root': ((0, 0, -0.01), [(X, 2)]), 'jaw': [(X, 5)], 'eye': [(Z, 9)]}),
    (54, {'root': ((0, 0, -0.03), [(Y, -3)]), 'jaw': [(X, 8)], 'eye': [(Z, 0)]}),
    (71, {'root': ((0, 0, 0), []), 'jaw': [(X, 6)], 'eye': [(Z, -8)]}),
]


def spec(e, off=(0, 0, 0), rots=(), **bones):
    s = {k.replace('_L', '.L').replace('_R', '.R'): v for k, v in bones.items()}
    s['root'] = R(e, off, rots)
    return s


def limp(e, extra=()):
    """End pose of every air death: rolled back and to the side, jaw hanging, tongue out, eye rolled up."""
    return spec(e, (0, 0, 0), [(X, -30), (Y, 18)] + list(extra), jaw=[(X, 42)], tongue=[(X, 28)], lid=[(X, 35)], eye=[(X, -25), (Z, 10)])


def add_scale(e, act, keys, bone='body'):
    """Scale keys (frame, (sx, sy, sz)) on one bone; vg_anims itself only keys rotation and location."""
    dp = f'pose.bones["{bone}"].scale'
    ad = e.arm.animation_data
    ad.action = act   # fcurve_ensure_for_datablock wants the action assigned
    if act.slots:
        ad.action_slot = act.slots[0]
    for i in range(3):
        fc = act.fcurve_ensure_for_datablock(e.arm, dp, index=i, group_name=bone)
        for f, s in keys:
            fc.keyframe_points.insert(f, s[i], options={'FAST'})
        fc.update()
    ad.action = None


def build(e):
    acts = []
    k = lambda f, off=(0, 0, 0), rots=(), **b: (f, spec(e, off, rots, **b))
    # fly (See, A_Chase every 3 tics): leaning into the flight, faster heavier bob
    acts.append(e.make('fly', [k(1, (0, 0, 0), [(X, 8)], jaw=[(X, 8)]), k(10, (0, 0, 0.04), [(X, 10), (Y, 4)], jaw=[(X, 12)]),
                               k(19, (0, 0, 0), [(X, 8)], jaw=[(X, 8)]), k(28, (0, 0, -0.04), [(X, 6), (Y, -4)], jaw=[(X, 6)]),
                               k(36, (0, 0, 0), [(X, 8)], jaw=[(X, 8)])], cyclic=True))
    # attack (vanilla 5+5+5 tics, A_HeadAttack on tic 10): rears back, the maw gapes, the eye narrows, then spits
    acts.append(e.make('attack', [k(1), k(6, (0, 0.03, 0), [(X, -10)], jaw=[(X, 22)], lid=[(X, 12)]),
                                  k(10, (0, 0.05, 0.02), [(X, -14)], jaw=[(X, 52)], lid=[(X, 25)], tongue=[(X, -15)]),
                                  k(12, (0, -0.07, 0), [(X, 8)], jaw=[(X, 58)], lid=[(X, 20)], tongue=[(X, -5)]),
                                  k(17, (0, -0.02, 0), [(X, 2)], jaw=[(X, 28)]), k(20)]))
    # melee (same frames, A_HeadAttack bites in range): rear, lunge, snap the jaw shut
    acts.append(e.make('melee', [k(1), k(5, (0, 0.08, 0.02), [(X, -12)], jaw=[(X, 50)], lid=[(X, 20)]),
                                 k(10, (0, -0.32, -0.02), [(X, 12)], jaw=[(X, 2)], lid=[(X, 25)]),
                                 k(13, (0, -0.25, 0), [(X, 8)], jaw=[(X, 20)]), k(20)]))
    # pains (vanilla 3+3+6 tics), one per zone
    acts.append(e.make('pain_eye', [k(1), k(3, (0, 0.06, 0.02), [(X, -16)], lid=[(X, 80)], eye=[(X, 12)], jaw=[(X, 24)]), k(12)]))
    acts.append(e.make('pain_shell', [k(1), k(3, (0, -0.05, -0.03), [(X, 12), (Z, 8)], jaw=[(X, 18)], lid=[(X, 30)]), k(12)]))
    acts.append(e.make('pain_horn_l', [k(1), k(3, (-0.06, 0, 0.01), [(Y, -16), (Z, -6)], jaw=[(X, 16)], lid=[(X, 30)]), k(12)]))
    acts.append(e.make('pain_horn_r', [k(1), k(3, (0.06, 0, 0.01), [(Y, 16), (Z, 6)], jaw=[(X, 16)], lid=[(X, 30)]), k(12)]))
    acts.append(e.make('pain_mouth', [k(1), k(3, (0, 0.05, 0.03), [(X, -20)], jaw=[(X, 34)], tongue=[(X, 20)], lid=[(X, 20)]), k(12)]))
    L = limp(e)
    # air deaths: each ends in LIMP; the ZScript switches to death_fall while the body is still in the air
    acts.append(e.make('death_eye', [k(1), k(2, (0, 0.08, 0.05), [(X, -28)], jaw=[(X, 36)], lid=[(X, 45)], eye=[(X, -30)]),
                                     k(6, (0, 0.05, 0.02), [(X, -34), (Y, 10)], jaw=[(X, 46)], tongue=[(X, 20)], lid=[(X, 40)]), (14, L)]))
    acts.append(e.make('death_air', [k(1), k(3, (0, -0.04, 0.03), [(X, 18), (Z, 14)], jaw=[(X, 30)], lid=[(X, 50)]),
                                     k(8, (0, 0, 0.01), [(X, -10), (Y, 12)], jaw=[(X, 45)], tongue=[(X, 15)]), (14, L)]))
    # blast: thrown over backwards, one and a bit turns, ends in LIMP (-390 = -30 turned once)
    acts.append(e.make('death_blast', [k(1), k(4, (0, 0.2, 0.25), [(X, -80), (Y, 10)], jaw=[(X, 40)], lid=[(X, 60)]),
                                       k(8, (0, 0.35, 0.3), [(X, -170), (Y, 15)], jaw=[(X, 50)], tongue=[(X, 30)]),
                                       k(12, (0, 0.3, 0.15), [(X, -260), (Y, 18)], jaw=[(X, 45)], tongue=[(X, 30)]),
                                       (16, limp(e, [(X, -360)]))]))
    # falling: a lurching tumble around LIMP (no full turn, so the loop seam never flips a quaternion)
    acts.append(e.make('death_fall', [(1, L), (10, limp(e, [(X, -55), (Y, 15)])), (19, limp(e, [(X, -95), (Y, -8)])),
                                      (28, limp(e, [(X, -50), (Y, -22)])), (36, L)], cyclic=True))
    # landing: slams onto the floor, squashes flat, rebounds, settles face down with the tongue out
    lie = lambda jaw, tongue, lid: spec(e, (0, 0, 0), [(X, 38), (Y, 22)], jaw=[(X, jaw)], tongue=[(X, tongue)], lid=[(X, lid)], eye=[(X, -30)])
    land = e.make('death_land', [(1, lie(50, 30, 50)), (3, lie(56, 42, 60)), (7, lie(30, 30, 55)), (11, lie(46, 45, 50)),
                                 (15, lie(42, 48, 52)), (24, lie(42, 48, 52))], ground=True, ground_from=1)
    add_scale(e, land, [(1, (1, 1, 1)), (3, (1.32, 1.32, 0.58)), (7, (0.94, 0.94, 1.08)), (11, (1.18, 1.18, 0.78)),
                        (15, (1.14, 1.14, 0.8)), (24, (1.14, 1.14, 0.8))])
    acts.append(land)
    acts.append(death_explode(e))
    return finish(e, [bpy.data.actions['idle']] + acts)[1:]


def death_explode(e, frames=48):
    """Like VGAnims.death_explode, but with one Rigid Body chunk per shell piece (RB_<bone>, tagged vg_bone):
    every bone follows its own chunk, or the chunk of its nearest ancestor."""
    sc = bpy.context.scene
    chunks = {o['vg_bone']: o for o in bpy.data.objects if o.name.startswith('RB_') and 'vg_bone' in o}
    if not chunks:
        return e.death_explode(frames)
    parent = {b.name: (b.parent.name if b.parent else None) for b in e.arm.data.bones}

    def owner(n):
        while n and n not in chunks:
            n = parent[n]
        return n or ('face' if 'face' in chunks else next(iter(chunks)))
    sc.frame_set(1)
    c0 = {b: o.matrix_world.copy() for b, o in chunks.items()}
    R = e.arm.matrix_world
    rest = {b.name: b.matrix_local.copy() for b in e.arm.data.bones}
    track = []
    for f in range(1, frames + 1):
        sc.frame_set(f)
        d = {b: c0[b].inverted() @ o.matrix_world for b, o in chunks.items()}
        track.append({n: R.inverted() @ d[owner(n)] @ R @ rest[n] for n in e.order})
    snaps = []
    for i, mats in enumerate(track):
        e.set_pose(mats)
        snaps.append((i + 1, e.snapshot()))
    sc.frame_set(1)
    return e.write_action('death_explode', snaps)


def finish(e, acts):
    """Every action gets body scale keys: actions without them would inherit a squash left by death_land."""
    for a in acts:
        if not any(fc.data_path == 'pose.bones["body"].scale' for fc in _fcurves(a)):
            add_scale(e, a, [(int(a.frame_range[0]), (1, 1, 1))])
    return acts


def _fcurves(act):
    try:
        return list(act.fcurves)
    except AttributeError:   # slotted actions (Blender 4.4+): curves live in layers/strips/channelbags
        out = []
        for layer in act.layers:
            for strip in layer.strips:
                for bag in strip.channelbags:
                    out += list(bag.fcurves)
        return out
