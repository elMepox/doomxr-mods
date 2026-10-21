# vg_anims kind "mancubus": heavy waddle, cannon volleys, the shared biped pains/deaths (vg_anims.pains_and_deaths)
# plus pains for the cannon arms. Rest pose = cannons levelled forward. 35 fps = Doom tics.
import math
from mathutils import Vector
import vg_anims

X, Y, Z = Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1))
REST = True

# slow breathing: chest heaves, the gut sways a beat later, the head scans
IDLE = [
    (1, {'chest': [(X, 0)], 'belly': [(X, 0)], 'head': [(Z, -5)]}),
    (36, {'chest': [(X, -3)], 'belly': [(X, 5)], 'head': [(Z, 5), (X, -4)], 'root': ((0, 0, 0.012), [])}),
    (71, {'chest': [(X, 0)], 'belly': [(X, 0)], 'head': [(Z, -5)]}),
]


def walk(ph):
    """Waddle: the whole mass rolls over the planted leg, the gut lags behind."""
    s, c = math.sin(ph), math.cos(ph)
    return {
        'root': ((0, 0, -0.035 + 0.035 * abs(c)), [(Y, 5 * s), (Z, 4 * s)]),
        'thigh.L': [(X, -24 * s)], 'shin.L': [(X, 30 * max(0, -s) + 4)], 'foot.L': [(X, 8 * s)],
        'thigh.R': [(X, 24 * s)], 'shin.R': [(X, 30 * max(0, s) + 4)], 'foot.R': [(X, -8 * s)],
        'spine': [(Y, -2 * s)], 'chest': [(Y, -3 * s), (Z, -4 * s)],
        'belly': [(X, 6 * abs(c) - 2), (Y, -5 * s)],
        'head': [(Y, 3 * s), (X, -3)],
        'upperarm.L': [(X, 6 * s)], 'upperarm.R': [(X, -6 * s)],
    }


RAISE = {'root': ((0, 0, -0.03), []), 'upperarm.L': [(X, -18)], 'upperarm.R': [(X, -18)], 'forearm.L': [(X, -8)], 'forearm.R': [(X, -8)],
         'chest': [(X, -6)], 'head': [(X, -14)], 'thigh.L': [(X, -8)], 'shin.L': [(X, 10)], 'thigh.R': [(X, 6)]}


def recoil(sides):
    """A cannon kicks back: the arm jumps, the chest twists away, the gut wobbles."""
    sp = {k: list(v) for k, v in RAISE.items() if k != 'root'}
    sp['root'] = ((0, 0.03, -0.04), [])
    twist = 0
    for s in sides:
        sp['upperarm.' + s] = [(X, -6)]
        sp['forearm.' + s] = [(X, 6)]
        sp['hand.' + s] = [(X, 4)]
        twist += 5 if s == 'L' else -5
    sp['chest'] = [(X, -2), (Z, twist)]
    sp['belly'] = [(X, 7)]
    sp['head'] = [(X, -8)]
    return sp


def build(e):
    acts = [e.make('walk', [(1 + i * 12, walk(i * math.pi / 2)) for i in range(5)], cyclic=True)]
    # vanilla Missile: 20 tics raise (A_FatRaise), then three volleys 20 tics apart (right, left, both)
    keys = [(1, {}), (12, RAISE), (20, RAISE)]
    for f, sides in ((21, 'R'), (41, 'L'), (61, 'LR')):
        keys += [(f, recoil(sides)), (f + 6, RAISE), (f + 19, RAISE)]
    keys[-1] = (80, {})
    acts.append(e.make('attack', keys))
    for s, sx in (('L', 1), ('R', -1)):
        hit = {'upperarm.' + s: [(X, 25), (Y, sx * -20)], 'forearm.' + s: [(X, 18)], 'chest': [(Z, sx * 10), (X, -4)], 'head': [(Z, sx * -8)]}
        acts.append(e.make('pain_arm_' + s.lower(), [(1, {}), (3, hit), (12, {})]))
    acts += vg_anims.pains_and_deaths(e)
    return acts
