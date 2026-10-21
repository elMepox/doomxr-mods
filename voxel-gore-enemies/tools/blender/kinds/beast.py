# Demon / Spectre (kind "beast"): a hunched biped that only bites. Same method as vg_anims: rotations in the
# parent's frame on top of the rest pose. +X rotation leans a bone forward / opens the jaw, -Y is forward.
# Vanilla timing: Melee is 3 x 8 tics with A_SargAttack on the last one, so the bite snaps shut at frame 18.
import math
import vg_anims as vg
from vg_anims import X, Y, Z

REST = True
IDLE = [
    (1, {'jaw': [(X, 4)], 'head': [(Z, -5)], 'chest': [(X, 0)]}),
    (24, {'jaw': [(X, 14)], 'head': [(Z, 3), (X, -4)], 'chest': [(X, -3)], 'root': ((0, 0, 0.006), [])}),
    (48, {'jaw': [(X, 6)], 'head': [(Z, 6), (X, 2)], 'chest': [(X, -1)]}),
    (71, {'jaw': [(X, 4)], 'head': [(Z, -5)], 'chest': [(X, 0)]}),
]


def walk(phase):
    """Heavy gallop-like stride: legs from the knight walk, arms swing low, head bobs, jaw flaps."""
    s, c = math.sin(phase), math.cos(phase)
    sp = vg.walk_spec(phase, heavy=True)
    sp.update({
        'upperarm.L': [(X, 24 * s)], 'upperarm.R': [(X, -24 * s)], 'forearm.L': [(X, -20)], 'forearm.R': [(X, -20)],
        'chest': [(X, 4 + 3 * abs(c)), (Z, -5 * s)], 'head': [(X, -6 * abs(c)), (Z, 4 * s)], 'jaw': [(X, 8 + 8 * abs(s))],
    })
    return sp


def bite(e):
    wind = {'root': ((0, 0.04, -0.03), []), 'chest': [(X, -12)], 'neck': [(X, -10)], 'head': [(X, -18)], 'jaw': [(X, 45)],
            'upperarm.L': [(X, -40), (Z, 15)], 'upperarm.R': [(X, -40), (Z, -15)], 'forearm.L': [(X, -30)], 'forearm.R': [(X, -30)],
            'thigh.L': [(X, -10)], 'shin.L': [(X, 14)], 'thigh.R': [(X, -6)], 'shin.R': [(X, 8)]}
    lunge = {'root': ((0, -0.2, -0.06), [(X, 8)]), 'chest': [(X, 18)], 'neck': [(X, 8)], 'head': [(X, 4)], 'jaw': [(X, 50)],
             'upperarm.L': [(X, -70), (Z, -10)], 'upperarm.R': [(X, -70), (Z, 10)], 'forearm.L': [(X, -10)], 'forearm.R': [(X, -10)],
             'thigh.L': [(X, -38)], 'shin.L': [(X, 30)], 'thigh.R': [(X, 18)], 'shin.R': [(X, -4)]}
    snap = dict(lunge, jaw=[(X, -2)], head=[(X, 16), (Z, 10)], neck=[(X, 12)])
    shake = dict(snap, head=[(X, 16), (Z, -12)], chest=[(X, 18), (Z, 6)])
    return e.make('melee', [(1, {}), (8, wind), (14, lunge), (18, snap), (21, shake), (24, snap), (32, {})])


def build(e):
    acts = [e.make('walk', [(1 + i * 9, walk(i * math.pi / 2)) for i in range(5)], cyclic=True)]
    m = bite(e)
    acts.append(m)
    # the Demon has no ranged attack; 'attack' points to the bite so shared code that asks for it still works
    acts.append(e.make('attack', [(1, {}), (8, {'jaw': [(X, 45)], 'head': [(X, -18)]}), (18, {'jaw': [(X, -2)]}), (24, {})]))
    # pains_and_deaths first, then the beast's own pains replace the generic ones (write_action deletes the old Action)
    acts += [a for a in vg.pains_and_deaths(e) if a.name not in ('pain_head', 'pain_torso')]
    # roars in pain with the jaw wide open
    acts.append(e.make('pain_head', [(1, {}), (3, {'neck': [(X, -15)], 'head': [(X, -30), (Z, 14)], 'jaw': [(X, 45)], 'chest': [(X, -6)]}), (14, {})]))
    acts.append(e.make('pain_torso', [(1, {}), (3, {'spine': [(X, -10), (Z, 10)], 'chest': [(X, -10), (Z, 8)], 'head': [(X, -12)], 'jaw': [(X, 35)]}), (14, {})]))
    return acts
