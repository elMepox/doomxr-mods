# model-weapons-ps1

Animated PS1-style low-poly models (128-284 triangles, one baked 128/256 px atlas each) for all nine Doom 1/2 weapons,
fist and chainsaw included. Each weapon is an MD3 with one frame per sprite frame; a second MODELDEF block puts a
low-poly muzzle flash on the flash layer.

Build: `python3 make_pk3.py [output.pk3]` writes `doomxr-model-weapons-ps1.pk3`.

`models/` holds the MD3/PNG files, in centimetres with the grip at the origin. They are exported from a Blender file
(not in this repo) by the `ps1_doom_export.py` script. How the engine draws hand-held models is described in
`docs/hand-held-models.md` of the DoomXR repo.
