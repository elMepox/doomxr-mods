# vg_anims kind "spider": Arachnotron (and later the Spider Mastermind). The Actions are authored in Blender with
# IK legs (arachnotron/scripts/ar_anims.py) and baked to plain keys (Bake Action, visual keying); the rig lists them
# in its custom property vg_actions. death_explode comes from one Rigid Body chunk per bone (RB_<bone>, tagged
# vg_bone: leg segments, hull plates, brain lobes, gun), the same per-bone version as the orbs use.
import bpy
from orb import death_explode

REST = True
AUTHORED = True


def build(e):
    acts = [bpy.data.actions[n] for n in e.arm['vg_actions'].split(',') if n and n != 'death_explode']
    return acts + [death_explode(e)]
