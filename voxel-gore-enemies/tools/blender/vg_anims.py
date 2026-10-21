# Game animations for every voxel enemy, as Blender Actions on <P>_Rig (35 fps = Doom tics).
# Same method as zombieman/scripts/zm_anims.py: poses are rotations in the parent's frame on top
# of the enemy's own aim pose (its IK baked out), keyed into quaternions. Root offsets are authored
# for the 1.8 m zombie and scaled by the enemy's height; specs naming a bone the skeleton lacks are
# remapped (foot -> hoof on the Hell Knight) or skipped. death_explode comes from the Rigid Body chunks.
# Non-humanoids: the rig may carry a custom property vg_zones = "eye,shell,horn_l,horn_r,mouth" (model slots
# 0..4 in order, "" for an unused slot), and kinds that are not built in here live in kinds/<kind>.py
# with REST (start from the rest pose?) and build(e) -> the Actions after idle (walk, attacks, pains, deaths).
import bpy, math, os, sys, importlib
from mathutils import Matrix, Vector

X, Y, Z = Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1))
ALIAS = {'foot.L': 'hoof.L', 'foot.R': 'hoof.R'}
ZONES = ['head', 'torso', 'arm_l', 'arm_r', 'legs']


class Enemy:
    def __init__(self, prefix, kind):
        self.P, self.kind = prefix, kind
        self.arm = bpy.data.objects[f'{prefix}_Rig']
        self.body = bpy.data.objects[f'{prefix}_Body']
        self.order = [b.name for b in self.arm.data.bones]  # armature bones are stored parent-first
        bones = self.arm.data.bones
        top = [b for b in bones if b.name == 'head' or b.parent and b.parent.name == 'head'] or list(bones)  # no head: whole rig
        self.height = max(b.tail_local.z for b in top)
        zs = self.arm.get('vg_zones')
        self.zones = [z for z in zs.split(',')] if zs else list(ZONES)   # model slot order
        self.used = [z for z in self.zones if z]
        self.k = self.height / 1.8
        self.base = None

    # ---------- pose helpers (zm_anims, generalised) ----------
    def bake_constraints_to_base(self, rest=False):
        """rest=False: freeze the authored aim pose (gunners hold their weapon in it).
        rest=True: start from the rest pose (claw monsters, whose authored pose is a mid-attack still)."""
        arm = self.arm
        bpy.context.view_layer.update()
        src_idle = bpy.data.actions.get('idle')
        if not rest and src_idle and not any(pb.constraints for pb in arm.pose.bones):
            # no aim constraints (Zombieman): the pose left in the file is a stale sim frame,
            # take the aim pose from the enemy's own idle instead
            ad = arm.animation_data_create()
            ad.action = src_idle
            if src_idle.slots:
                ad.action_slot = src_idle.slots[0]
            bpy.context.scene.frame_set(int(src_idle.frame_range[0]))
            bpy.context.view_layer.update()
            for pb in arm.pose.bones:
                m = pb.matrix_basis.copy()
                pb.location, pb.rotation_quaternion, pb.scale = m.to_translation(), m.to_quaternion(), m.to_scale()
            ad.action = None
            bpy.context.view_layer.update()
        base = {b.name: b.matrix.copy() for b in arm.pose.bones}
        for pb in arm.pose.bones:
            for c in list(pb.constraints):
                pb.constraints.remove(c)
            pb.rotation_mode = 'QUATERNION'
        if rest:
            for pb in arm.pose.bones:
                pb.rotation_quaternion = (1, 0, 0, 0); pb.location = (0, 0, 0); pb.scale = (1, 1, 1)
            bpy.context.view_layer.update()
            base = {b.name: b.matrix.copy() for b in arm.pose.bones}
        self.base = base
        self.set_pose(base)
        for n in [o.name for o in bpy.data.objects if o.name.startswith(('IK_', 'AIM'))]:
            bpy.data.objects.remove(bpy.data.objects[n])

    def set_pose(self, mats):
        P = self.arm.pose.bones
        for n in self.order:
            P[n].matrix = mats[n]
            bpy.context.view_layer.update()

    def resolve(self, spec):
        out = {}
        for n, v in spec.items():
            if n == 'root':
                off, rots = v
                out['root'] = (Vector(off) * self.k, rots)
                continue
            n = n if n in self.base else ALIAS.get(n)
            if n in self.base:
                out[n] = list(out.get(n, [])) + list(v)
        return out

    def pose_from_spec(self, spec):
        base, P, cur = self.base, self.arm.pose.bones, {}
        for n in self.order:
            pb = P[n]
            if pb.parent:
                par = pb.parent.name
                carry = cur[par] @ base[par].inverted()
                m = carry @ base[n]
                frame = carry.to_3x3()
            else:
                m = base[n].copy()
                frame = Matrix.Identity(3)
            rots = spec.get(n, [])
            if pb.parent is None and 'root' in spec:
                rots = list(spec['root'][1]) + list(rots)
            head = m.to_translation()
            for axis, deg in rots:
                ax = (frame @ axis).normalized()
                m = Matrix.Translation(head) @ Matrix.Rotation(math.radians(deg), 4, ax) @ Matrix.Translation(-head) @ m
            if pb.parent is None and 'root' in spec:
                m = Matrix.Translation(Vector(spec['root'][0])) @ m
            cur[n] = m
        self.set_pose(cur)

    def snapshot(self):
        return {pb.name: (pb.rotation_quaternion.copy(), pb.location.copy()) for pb in self.arm.pose.bones}

    def write_action(self, name, frames_snaps, cyclic=False):
        arm = self.arm
        old = bpy.data.actions.get(name)
        if old:
            bpy.data.actions.remove(old)
        act = bpy.data.actions.new(name)
        act.use_fake_user = True
        arm.animation_data.action = act
        prev, curves = {}, {}
        for f, snap in frames_snaps:
            for n, (q, loc) in snap.items():
                if n in prev and prev[n].dot(q) < 0:
                    q = -q
                prev[n] = q
                for path, vals in (('rotation_quaternion', q), ('location', loc)):
                    dp = f'pose.bones["{n}"].{path}'
                    for i, v in enumerate(vals):
                        key = (dp, i)
                        if key not in curves:
                            curves[key] = act.fcurve_ensure_for_datablock(arm, dp, index=i, group_name=n)
                        curves[key].keyframe_points.insert(f, v, options={'FAST'})
        for fc in curves.values():
            fc.update()
            if cyclic:
                fc.modifiers.new('CYCLES')
        act.frame_range = (frames_snaps[0][0], frames_snaps[-1][0])
        act.use_frame_range = True
        act.use_cyclic = cyclic
        arm.animation_data.action = None
        return act

    def body_min_z(self):
        dg = bpy.context.evaluated_depsgraph_get()
        ev = self.body.evaluated_get(dg)
        me = ev.to_mesh()
        z = min((self.body.matrix_world @ v.co).z for v in me.vertices)
        ev.to_mesh_clear()
        return z

    def make(self, name, keys, cyclic=False, ground=False, ground_from=2):
        self.arm.animation_data_create()
        self.arm.animation_data.action = None
        snaps = []
        for f, spec in keys:
            spec = self.resolve(spec)
            self.pose_from_spec(spec)
            if ground and f >= ground_from:
                dz = -self.body_min_z()
                off, rots = spec.get('root', (Vector((0, 0, 0)), []))
                spec = dict(spec, root=(Vector(off) + Vector((0, 0, dz)), rots))
                self.pose_from_spec(spec)
            snaps.append((f, self.snapshot()))
        return self.write_action(name, snaps, cyclic)

    # ---------- death_explode from Rigid Body chunks ----------
    def death_explode(self, frames=48):
        sc = bpy.context.scene
        chunks = {z: bpy.data.objects[f'RB_{z}'] for z in self.used}
        if any(o.rigid_body for o in chunks.values()):
            sc.rigidbody_world.point_cache.frame_end = max(sc.rigidbody_world.point_cache.frame_end, frames)
            bpy.ops.ptcache.bake_all(bake=True)
        zone_of = {}
        for z in self.used:
            ob = bpy.data.objects[f'{self.P}_{z}_0']
            vg = {g.index: g.name for g in ob.vertex_groups}
            for v in ob.data.vertices:
                for g in v.groups:
                    if g.weight > 0.5:
                        zone_of.setdefault(vg[g.group], z)
        sc.frame_set(1)
        c0 = {z: o.matrix_world.copy() for z, o in chunks.items()}
        R = self.arm.matrix_world
        rest = {b.name: b.matrix_local.copy() for b in self.arm.data.bones}
        track = []
        for f in range(1, frames + 1):
            sc.frame_set(f)
            d = {z: c0[z].inverted() @ o.matrix_world for z, o in chunks.items()}
            fallback = 'torso' if 'torso' in d else self.used[0]
            track.append({n: R.inverted() @ d[zone_of.get(n, fallback)] @ R @ rest[n] for n in self.order})
        snaps = []
        for i, mats in enumerate(track):
            self.set_pose(mats)
            snaps.append((i + 1, self.snapshot()))
        sc.frame_set(1)
        return self.write_action('death_explode', snaps)


def walk_spec(phase, heavy=False):
    s, c = math.sin(phase), math.cos(phase)
    a = 22 if heavy else 28
    return {
        'root': ((0, 0, -0.02 + 0.02 * abs(c)), [(Z, 4 * s)]),
        'thigh.L': [(X, -a * s)], 'shin.L': [(X, 30 * max(0, -s) + 6)], 'foot.L': [(X, 10 * s)],
        'thigh.R': [(X, a * s)], 'shin.R': [(X, 30 * max(0, s) + 6)], 'foot.R': [(X, -10 * s)],
        'spine': [(X, 3), (Z, -3 * s)], 'chest': [(Z, -4 * s), (X, 2 * abs(c))],
        'head': [(X, -3), (Z, 5 * s), (Y, 3 * c)],
    }


def claw_walk_spec(phase):
    """Monsters with free hands swing them against the legs."""
    s = math.sin(phase)
    sp = walk_spec(phase)
    sp.update({'upperarm.L': [(X, 20 * s)], 'upperarm.R': [(X, -20 * s)], 'forearm.L': [(X, -15)], 'forearm.R': [(X, -15)]})
    return sp


# ---------- attacks ----------
def gun_attacks(e, kind):
    aim = {'upperarm.R': [(X, -22)], 'forearm.R': [(X, -10)], 'upperarm.L': [(X, -18)], 'head': [(X, 10), (Z, -6)], 'chest': [(Z, 6)]}
    kick = {'chest': [(Z, 6), (X, -6)], 'upperarm.R': [(X, -30)], 'upperarm.L': [(X, -26)], 'head': [(X, 4), (Z, -6)]}
    if kind == 'shotgun':  # heavier kick, then a pump of the left hand
        kick = {'chest': [(Z, 8), (X, -12)], 'spine': [(X, -4)], 'upperarm.R': [(X, -38)], 'upperarm.L': [(X, -34)], 'head': [(X, 0), (Z, -6)]}
        pump = dict(aim, **{'forearm.L': [(X, 25)], 'upperarm.L': [(X, -8)]})
        return [e.make('attack', [(1, {}), (8, aim), (10, aim), (12, dict(aim, **kick)), (17, aim), (21, pump), (25, aim), (30, aim)])]
    if kind == 'chaingun':  # hip fire: brace, then a looping rattle
        brace = {'root': ((0, 0, -0.04), []), 'chest': [(X, -6)], 'thigh.L': [(X, -12)], 'shin.L': [(X, 14)], 'head': [(X, 6)]}
        shake = dict(brace, chest=[(X, -9), (Z, 2)], **{'upperarm.R': [(X, -4)], 'upperarm.L': [(X, -4)]})
        return [e.make('attack', [(1, {}), (10, brace)]),
                e.make('fire', [(1, brace), (3, shake), (5, brace), (7, dict(shake, chest=[(X, -9), (Z, -2)])), (9, brace)], cyclic=True)]
    return [e.make('attack', [(1, {}), (8, aim), (16, aim), (18, dict(aim, **kick)), (22, aim), (30, aim)])]


def throw_attacks(e, heavy):
    """Overhead fireball throw with the right hand (Imp, Hell Knight, Baron) and a claw swipe for melee."""
    k = 0.8 if heavy else 1.0
    wind = {'upperarm.R': [(X, -150 * k), (Y, 20)], 'forearm.R': [(X, -60)], 'chest': [(X, -10), (Z, 18)], 'spine': [(Z, 8)],
            'upperarm.L': [(X, -30), (Y, -20)], 'head': [(X, 8)], 'thigh.R': [(X, 8)], 'thigh.L': [(X, -10)], 'shin.L': [(X, 12)]}
    rel = {'upperarm.R': [(X, -55)], 'forearm.R': [(X, -5)], 'chest': [(X, 18), (Z, -16)], 'spine': [(X, 6), (Z, -8)],
           'upperarm.L': [(X, 10)], 'head': [(X, 0)], 'thigh.L': [(X, -18)], 'shin.L': [(X, 20)]}
    fin = {'upperarm.R': [(X, -35)], 'chest': [(X, 8), (Z, -6)]}
    swipe0 = {'upperarm.R': [(X, -80), (Z, 50)], 'forearm.R': [(X, -40)], 'chest': [(Z, 25)], 'head': [(X, 5)]}
    swipe1 = {'upperarm.R': [(X, -70), (Z, -40)], 'forearm.R': [(X, -10)], 'chest': [(Z, -25), (X, 12)], 'head': [(X, 10)]}
    return [e.make('attack', [(1, {}), (12, wind), (16, wind), (19, rel), (24, fin), (30, {})]),
            e.make('melee', [(1, {}), (8, swipe0), (12, swipe1), (16, swipe1), (24, {})])]


def revenant_attacks(e):
    """Shoulder rockets: brace and lean in, recoil on launch. Melee: a wide right hook."""
    brace = {'root': ((0, 0, -0.05), []), 'chest': [(X, 14)], 'head': [(X, -8)], 'upperarm.L': [(X, 10), (Y, 25)], 'upperarm.R': [(X, 10), (Y, -25)],
             'thigh.L': [(X, -15)], 'shin.L': [(X, 18)], 'thigh.R': [(X, 6)]}
    recoil = dict(brace, chest=[(X, -6)], spine=[(X, -6)], head=[(X, -14)])
    hook0 = {'upperarm.R': [(X, 25), (Z, 30)], 'forearm.R': [(X, -70)], 'chest': [(Z, 30)], 'spine': [(Z, 10)]}
    hook1 = {'upperarm.R': [(X, -85), (Z, -35)], 'forearm.R': [(X, -20)], 'chest': [(Z, -28), (X, 10)], 'spine': [(Z, -10)], 'thigh.L': [(X, -15)]}
    return [e.make('attack', [(1, {}), (10, brace), (20, brace), (22, recoil), (27, brace), (30, {})]),
            e.make('melee', [(1, {}), (7, hook0), (12, hook1), (16, hook1), (19, {})])]


def archvile_attacks(e):
    """Fire attack: both hands rise over the head and burn (long hold), then thrust at the target. Heal: arms raised high."""
    up = {'upperarm.L': [(X, -165), (Y, -15)], 'upperarm.R': [(X, -165), (Y, 15)], 'forearm.L': [(X, -20)], 'forearm.R': [(X, -20)],
          'chest': [(X, -12)], 'spine': [(X, -4)], 'head': [(X, -20)]}
    up2 = dict(up, chest=[(X, -14), (Z, 4)], head=[(X, -24), (Z, -6)])
    thrust = {'upperarm.L': [(X, -85), (Z, -15)], 'upperarm.R': [(X, -85), (Z, 15)], 'forearm.L': [(X, 0)], 'forearm.R': [(X, 0)],
              'chest': [(X, 20)], 'spine': [(X, 8)], 'head': [(X, 6)], 'thigh.L': [(X, -22)], 'shin.L': [(X, 25)]}
    # vanilla Missile: 18 tics wind-up, 48 tics of burning, A_VileAttack at tic 66, 20 tics hold
    keys = [(1, {}), (10, up)] + [(10 + 8 * i, up2 if i % 2 else up) for i in range(1, 7)] + [(62, up), (67, thrust), (82, thrust), (90, {})]
    heal = {'upperarm.L': [(X, -120), (Y, -40)], 'upperarm.R': [(X, -120), (Y, 40)], 'chest': [(X, -16)], 'head': [(X, -30)]}
    return [e.make('attack', keys), e.make('heal', [(1, {}), (8, heal), (22, heal), (30, {})])]


def pains_and_deaths(e):
    acts = []
    acts.append(e.make('pain_head', [(1, {}), (3, {'neck': [(X, -15)], 'head': [(X, -25), (Z, 12)], 'chest': [(X, -5)]}), (12, {})]))
    acts.append(e.make('pain_torso', [(1, {}), (3, {'spine': [(X, -10), (Z, 10)], 'chest': [(X, -8), (Z, 8)], 'head': [(X, 12)], 'upperarm.L': [(X, 15)]}), (12, {})]))
    acts.append(e.make('pain_legs', [(1, {}), (4, {'root': ((0, 0, -0.08), []), 'thigh.L': [(X, -25)], 'shin.L': [(X, 45)], 'chest': [(X, 10)]}), (14, {})]))
    lie_back = {'root': ((0, 0.62, -0.78), [(X, -88)]), 'thigh.L': [(X, -10), (Y, -8)], 'thigh.R': [(X, -4), (Y, 8)],
                'upperarm.L': [(X, 40), (Y, -40)], 'upperarm.R': [(X, 30), (Y, 50)], 'head': [(Z, 25)], 'shin.L': [(X, 20)]}
    acts.append(e.make('death_back', [
        (1, {}),
        (5, {'root': ((0, 0.05, 0), [(X, -10)]), 'chest': [(X, -15)], 'head': [(X, -25)], 'upperarm.L': [(X, 20)], 'upperarm.R': [(X, 15)]}),
        (14, {'root': ((0, 0.25, -0.35), [(X, -35)]), 'thigh.L': [(X, -50)], 'shin.L': [(X, 70)], 'thigh.R': [(X, -40)], 'shin.R': [(X, 60)], 'chest': [(X, -10)], 'head': [(X, -20)], 'upperarm.L': [(X, 40)], 'upperarm.R': [(X, 35)]}),
        (22, lie_back), (26, dict(lie_back, root=((0, 0.62, -0.74), [(X, -86)]))), (30, lie_back),
    ], ground=True))
    lie_front = {'root': ((0, -0.62, -0.8), [(X, 88)]), 'head': [(Z, -30), (X, -10)], 'upperarm.L': [(X, 25), (Y, 12)], 'forearm.L': [(X, -10)],
                 'upperarm.R': [(X, 20), (Y, -12)], 'forearm.R': [(X, 30)], 'hand.R': [(X, 60)], 'thigh.R': [(X, 8)]}
    acts.append(e.make('death_front', [
        (1, {}),
        (6, {'root': ((0, -0.08, -0.05), [(X, 15)]), 'chest': [(X, 15)], 'head': [(X, 15)], 'upperarm.L': [(X, -25)], 'upperarm.R': [(X, -20)]}),
        (16, {'root': ((0, -0.35, -0.4), [(X, 45)]), 'thigh.L': [(X, -30)], 'shin.L': [(X, 50)], 'chest': [(X, 10)]}),
        (24, lie_front), (28, dict(lie_front, root=((0, -0.62, -0.77), [(X, 86)]))), (32, lie_front),
    ], ground=True))
    knees = {'root': ((0, 0.0, -0.42), [(X, 8)]), 'thigh.L': [(X, -85)], 'shin.L': [(X, 150)], 'foot.L': [(X, -55)],
             'thigh.R': [(X, -80)], 'shin.R': [(X, 145)], 'foot.R': [(X, -60)], 'head': [(X, 35), (Z, 20)], 'chest': [(X, 12)],
             'upperarm.L': [(X, 45)], 'upperarm.R': [(X, 40)]}
    acts.append(e.make('death_head', [
        (1, {}), (3, {'neck': [(X, -20)], 'head': [(X, -50), (Z, 20)], 'chest': [(X, -10)], 'upperarm.L': [(X, 20)], 'upperarm.R': [(X, 25)]}),
        (12, {'root': ((0, 0.05, -0.35), [(X, -12)]), 'thigh.L': [(X, -60)], 'shin.L': [(X, 100)], 'foot.L': [(X, -30)], 'thigh.R': [(X, -55)], 'shin.R': [(X, 95)], 'foot.R': [(X, -30)],
              'head': [(X, -40), (Z, 25)], 'upperarm.L': [(X, 50), (Y, -20)], 'upperarm.R': [(X, 45), (Y, 20)]}),
        (22, lie_back), (26, dict(lie_back, root=((0, 0.62, -0.75), [(X, -86)]))), (30, lie_back),
    ], ground=True))
    acts.append(e.make('death_legs', [
        (1, {}), (5, {'root': ((0, 0, -0.18), [(X, 10)]), 'thigh.L': [(X, -40)], 'shin.L': [(X, 80)], 'thigh.R': [(X, -20)], 'shin.R': [(X, 40)], 'chest': [(X, 10)]}),
        (12, knees), (24, lie_front), (30, lie_front),
    ], ground=True))
    # blast: thrown back off the feet by an explosion, a half flip in the air, lands on the back
    # (travel comes from the engine's explosion thrust; the animation stays near the spot)
    sprawl = dict(lie_back, **{'upperarm.L': [(X, 70), (Y, -60)], 'upperarm.R': [(X, 60), (Y, 70)], 'thigh.L': [(X, -35)], 'shin.L': [(X, 40)]})
    acts.append(e.make('death_blast', [
        (1, {}),
        (3, {'root': ((0, 0.10, 0.10), [(X, -25)]), 'chest': [(X, -20)], 'head': [(X, -35)], 'upperarm.L': [(X, -60), (Y, -30)], 'upperarm.R': [(X, -60), (Y, 30)],
             'thigh.L': [(X, -30)], 'shin.L': [(X, 40)], 'thigh.R': [(X, -10)]}),
        (8, {'root': ((0, 0.45, 0.55), [(X, -70), (Y, 15)]), 'chest': [(X, -15)], 'head': [(X, -30), (Z, 20)], 'upperarm.L': [(X, -120), (Y, -40)], 'upperarm.R': [(X, -100), (Y, 45)],
             'thigh.L': [(X, -60)], 'shin.L': [(X, 70)], 'thigh.R': [(X, -35)], 'shin.R': [(X, 50)]}),
        (13, {'root': ((0, 0.65, 0.25), [(X, -105), (Y, 25)]), 'head': [(X, -20), (Z, 25)], 'upperarm.L': [(X, -40), (Y, -60)], 'upperarm.R': [(X, -30), (Y, 70)],
              'thigh.L': [(X, -50)], 'shin.L': [(X, 60)], 'thigh.R': [(X, -20)]}),
        (17, sprawl), (20, dict(sprawl, root=((0, 0.62, -0.72), [(X, -84)]))), (24, sprawl),
    ], ground=True, ground_from=16))
    acts.append(e.death_explode())
    return acts


IDLE = [
    (1, {'chest': [(X, 0)], 'head': [(Z, -6), (Y, 4)]}),
    (36, {'chest': [(X, -3)], 'spine': [(X, -1)], 'head': [(Z, 6), (Y, -3), (X, -4)], 'root': ((0, 0, 0.004), [])}),
    (71, {'chest': [(X, 0)], 'head': [(Z, -6), (Y, 4)]}),
]


BUILTIN = ('rifle', 'shotgun', 'chaingun', 'imp', 'knight', 'revenant', 'archvile')


def load_kind(kind):
    """kinds/<kind>.py next to this file (beast, orb, spider, ...)."""
    d = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'kinds')
    if d not in sys.path:
        sys.path.insert(0, d)
    mod = importlib.import_module(kind)
    return importlib.reload(mod)


def build_actions(prefix, kind):
    """kind: rifle | shotgun | chaingun | imp | knight | revenant | archvile, or a module in kinds/"""
    e = Enemy(prefix, kind)
    if kind not in BUILTIN:
        km = load_kind(kind)
        e.bake_constraints_to_base(rest=getattr(km, 'REST', True))
        e.arm.location = (0, 0, 0)
        bpy.context.view_layer.update()
        if getattr(km, 'AUTHORED', False):   # Actions keyed by hand in Blender (incl. idle): take them as they are
            acts = km.build(e)
        else:
            acts = [e.make('idle', getattr(km, 'IDLE', IDLE), cyclic=True)] + km.build(e)
        e.arm.animation_data.action = None
        e.set_pose(e.base)
        return e, acts
    gun = kind in ('rifle', 'shotgun', 'chaingun')
    e.bake_constraints_to_base(rest=not gun)  # before moving the rig: IK targets live in world space
    e.arm.location = (0, 0, 0)
    bpy.context.view_layer.update()
    acts = [e.make('idle', IDLE, cyclic=True)]
    wspec = walk_spec if gun else claw_walk_spec
    heavy = kind == 'knight'
    acts.append(e.make('walk', [(1 + i * 9, (walk_spec(i * math.pi / 2, heavy) if heavy else wspec(i * math.pi / 2))) for i in range(5)], cyclic=True))
    if gun:
        acts += gun_attacks(e, kind)
    elif kind in ('imp', 'knight'):
        acts += throw_attacks(e, heavy)
    elif kind == 'revenant':
        acts += revenant_attacks(e)
    elif kind == 'archvile':
        acts += archvile_attacks(e)
    acts += pains_and_deaths(e)
    e.arm.animation_data.action = None
    e.set_pose(e.base)
    return e, acts
