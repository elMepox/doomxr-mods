# vg_anims kind "authored": the Actions were keyed by hand in Blender (Lost Soul and later monsters).
# The rig lists them in its custom property vg_actions ("idle,fly,attack,..."); constraints must already be
# baked into the keys (Pose > Animation > Bake Action, visual keying), because bake_constraints_to_base
# removes them. death_explode still comes from the RB_<zone> chunks (Rigid Body baked to keyframes).
import bpy

REST = True
AUTHORED = True


def build(e):
    acts = [bpy.data.actions[n] for n in e.arm['vg_actions'].split(',') if n]
    return acts + [e.death_explode()]
