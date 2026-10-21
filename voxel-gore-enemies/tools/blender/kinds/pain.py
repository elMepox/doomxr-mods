# vg_anims kind "pain": the Pain Elemental, a heavier orb (kinds/orb.py) with two stunted arms
# (arm.L/hand.L on +X, arm.R/hand.R on -X) and no horns. Bones: pivot (moved by the spec key 'root'),
# body (pivot at the bottom of the ball: scale keys swell/squash it), face, eye, lid, jaw, tongue, arms, shards.
# Axes in the parent's frame: jaw +X opens; arm.L -Y / arm.R +Y raise the arm, -Z / +Z swing it forward;
# hand +X curls the claws in, -X opens them.
# Vanilla timing (tics = frames): See 3 tics per A_Chase; Missile 5+5+5 then A_PainAttack; Pain 6+6;
# Death 8 tics per frame, A_PainDie (souls out) on the 5th. Every zone death here leads into death_swell
# (the ball bloats and shakes) and the ZScript then plays death_explode (Cell Fracture shards as Rigid Body).
import bpy
from mathutils import Vector
from orb import R, add_scale, finish, death_explode

X, Y, Z = Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1))
REST = True


def spec(e, off=(0, 0, 0), rots=(), **bones):
    s = {k.replace('_L', '.L').replace('_R', '.R'): v for k, v in bones.items()}
    s['root'] = R(e, off, rots)
    return s


def arms(up=0, fwd=0, claw=0, up_r=None, fwd_r=None, claw_r=None):
    """Both arms: up raises, fwd swings forward, claw curls the hand (negative spreads the claws)."""
    up_r = up if up_r is None else up_r
    fwd_r = fwd if fwd_r is None else fwd_r
    claw_r = claw if claw_r is None else claw_r
    return dict(arm_L=[(Y, -up), (Z, -fwd)], arm_R=[(Y, up_r), (Z, fwd_r)], hand_L=[(X, claw)], hand_R=[(X, claw_r)])


def _idle():
    # 2 s hover: slow heavy bob, the arms hang and twitch out of step, the claws flex, one blink,
    # the jaw hangs a little open and breathes
    return [
        (1, dict(off=(0, 0, 0), rots=[], jaw=[(X, 8)], eye=[(Z, -6)], **arms(0, 0, 10, 4, 0, 4))),
        (18, dict(off=(0, 0, 0.035), rots=[(Y, 3)], jaw=[(X, 12)], eye=[(Z, -6)], **arms(10, 6, 20, 2, 0, 0))),
        (36, dict(off=(0, 0, 0), rots=[(X, 2)], jaw=[(X, 7)], eye=[(Z, 8), (X, 4)], **arms(2, 0, 4, 12, 8, 24))),
        (40, dict(off=(0, 0, -0.005), rots=[(X, 2)], jaw=[(X, 7)], eye=[(Z, 8)], lid=[(X, 70)], **arms(2, 0, 4, 12, 8, 24))),
        (44, dict(off=(0, 0, -0.01), rots=[(X, 2)], jaw=[(X, 7)], eye=[(Z, 8)], **arms(0, 0, 6, 10, 6, 18))),
        (54, dict(off=(0, 0, -0.035), rots=[(Y, -3)], jaw=[(X, 11)], eye=[(Z, 0)], **arms(-4, -4, 0, 0, 0, 6))),
        (71, dict(off=(0, 0, 0), rots=[], jaw=[(X, 8)], eye=[(Z, -6)], **arms(0, 0, 10, 4, 0, 4))),
    ]


def _raw(d):
    d = dict(d)
    off, rots = d.pop('off'), d.pop('rots')
    s = {k.replace('_L', '.L').replace('_R', '.R'): v for k, v in d.items()}
    s['root'] = (off, rots)   # vg_anims scales these few cm by height/1.8, close enough for the bob
    return s


IDLE = [(f, _raw(d)) for f, d in _idle()]


def build(e):
    acts = []
    k = lambda f, off=(0, 0, 0), rots=(), **b: (f, spec(e, off, rots, **b))
    # fly (See): leaning into the flight, heavier slower bob, the arms trail back and swing
    acts.append(e.make('fly', [k(1, (0, 0, 0), [(X, 8)], jaw=[(X, 10)], **arms(6, -14, 16)),
                               k(10, (0, 0, 0.045), [(X, 10), (Y, 4)], jaw=[(X, 14)], **arms(14, -22, 24, 2, -10, 10)),
                               k(19, (0, 0, 0), [(X, 8)], jaw=[(X, 10)], **arms(6, -14, 16)),
                               k(28, (0, 0, -0.045), [(X, 6), (Y, -4)], jaw=[(X, 8)], **arms(2, -10, 10, 14, -22, 24)),
                               k(36, (0, 0, 0), [(X, 8)], jaw=[(X, 10)], **arms(6, -14, 16))], cyclic=True))
    # attack (5+5+5 tics, A_PainAttack on tic 15): rears back and the arms spread, the maw stretches
    # wider than the ball, the tongue curls out of the way; it heaves forward and retches the soul out
    acts.append(e.make('attack', [k(1, jaw=[(X, 8)], **arms(0, 0, 10)),
                                  k(6, (0, 0.04, 0.02), [(X, -10)], jaw=[(X, 26)], lid=[(X, 14)], **arms(26, 10, -20)),
                                  k(12, (0, 0.07, 0.03), [(X, -16)], jaw=[(X, 58)], lid=[(X, 28)], tongue=[(X, -24)], eye=[(X, 8)],
                                    **arms(40, 18, -35)),
                                  k(15, (0, -0.09, -0.01), [(X, 10)], jaw=[(X, 64)], lid=[(X, 22)], tongue=[(X, -10)],
                                    **arms(18, 34, 30)),
                                  k(19, (0, -0.04, 0), [(X, 4)], jaw=[(X, 34)], lid=[(X, 10)], **arms(8, 14, 20)),
                                  k(24, jaw=[(X, 8)], **arms(0, 0, 10))]))
    # pains (6+6 tics), one per zone
    acts.append(e.make('pain_face', [k(1), k(3, (0, 0.07, 0.03), [(X, -18)], lid=[(X, 80)], eye=[(X, 12)], jaw=[(X, 26)], **arms(20, -10, -25)),
                                     k(12)]))
    acts.append(e.make('pain_body', [k(1), k(3, (0, -0.06, -0.03), [(X, 12), (Z, 8)], jaw=[(X, 20)], lid=[(X, 30)], **arms(18, 20, 30)),
                                     k(12)]))
    acts.append(e.make('pain_arm_l', [k(1), k(3, (-0.06, 0, 0.01), [(Y, -14), (Z, -8)], jaw=[(X, 22)], lid=[(X, 30)],
                                             **arms(55, -25, -40, 10, 10, 20)), k(7, **arms(-15, 10, 40)), k(12)]))
    acts.append(e.make('pain_arm_r', [k(1), k(3, (0.06, 0, 0.01), [(Y, 14), (Z, 8)], jaw=[(X, 22)], lid=[(X, 30)],
                                             **arms(10, 10, 20, 55, -25, -40)), k(7, **arms(10, 10, 20, -15, 10, 40)), k(12)]))
    acts.append(e.make('pain_mouth', [k(1), k(3, (0, 0.06, 0.03), [(X, -22)], jaw=[(X, 40)], tongue=[(X, 24)], lid=[(X, 22)], **arms(14, 24, 30)),
                                      k(12)]))
    # deaths: the killing hit (rocked by the zone), then death_swell; the ZScript chains death_swell -> death_explode
    acts.append(e.make('death_face', [k(1), k(3, (0, 0.08, 0.05), [(X, -26)], jaw=[(X, 40)], lid=[(X, 50)], eye=[(X, -30)], **arms(40, -10, -40)),
                                      k(8, (0, 0.04, 0.02), [(X, -14), (Y, 10)], jaw=[(X, 50)], tongue=[(X, 20)], lid=[(X, 45)], **arms(25, 5, -20))]))
    acts.append(e.make('death_hit', [k(1), k(3, (0, -0.04, 0.03), [(X, 16), (Z, 12)], jaw=[(X, 34)], lid=[(X, 50)], **arms(35, 20, -30)),
                                     k(8, (0, 0, 0.02), [(X, -8), (Y, 10)], jaw=[(X, 46)], tongue=[(X, 15)], lid=[(X, 45)], **arms(25, 5, -20))]))
    # swell (24 tics, vanilla H+I+J): the ball bloats and shudders, the maw gapes, the arms thrash, the eye bulges
    sw = [k(1, (0, 0, 0.02), [(X, -10)], jaw=[(X, 46)], lid=[(X, 45)], **arms(25, 5, -20)),
          k(5, (0.02, 0, 0.03), [(X, -14), (Y, 6)], jaw=[(X, 56)], lid=[(X, 10)], eye=[(X, 10)], tongue=[(X, 30)], **arms(50, 25, -45, 20, -15, 30)),
          k(9, (-0.02, 0, 0.04), [(X, -8), (Y, -6)], jaw=[(X, 50)], lid=[(X, 0)], eye=[(X, -8)], tongue=[(X, 20)], **arms(15, -20, 35, 55, 30, -45)),
          k(13, (0.02, 0, 0.05), [(X, -16), (Y, 8)], jaw=[(X, 62)], lid=[(X, 0)], eye=[(Z, 10)], tongue=[(X, 34)], **arms(60, 30, -50, 25, -10, 20)),
          k(17, (-0.015, 0, 0.06), [(X, -12), (Y, -8)], jaw=[(X, 58)], lid=[(X, 0)], eye=[(Z, -10)], tongue=[(X, 30)], **arms(30, -15, 30, 60, 30, -50)),
          k(21, (0.01, 0, 0.07), [(X, -18), (Y, 4)], jaw=[(X, 66)], lid=[(X, 0)], tongue=[(X, 36)], **arms(70, 35, -55)),
          k(24, (0, 0, 0.075), [(X, -20)], jaw=[(X, 68)], lid=[(X, 0)], tongue=[(X, 38)], **arms(75, 40, -60))]
    swell = e.make('death_swell', sw)
    add_scale(e, swell, [(1, (1, 1, 1)), (5, (1.06, 1.06, 1.04)), (9, (1.04, 1.04, 1.08)), (13, (1.14, 1.14, 1.1)),
                         (17, (1.12, 1.12, 1.16)), (21, (1.22, 1.22, 1.2)), (24, (1.26, 1.26, 1.24))])
    acts.append(swell)
    acts.append(death_explode(e))
    return finish(e, [bpy.data.actions['idle']] + acts)[1:]
