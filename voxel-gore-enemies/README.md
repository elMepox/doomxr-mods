# voxel-gore-enemies

Voxel-style 3D models for 17 Doom 2 monsters, with hit zones, live wounds and zone-aware deaths
(Brutal Doom style). Each monster is a skeletal IQM model built from 35 mm voxels, split into five
zone models (`_0` intact, `_1` wounded) that share one skeleton.

Replaced: Zombieman, Shotgun Guy, Chaingunner, Wolfenstein SS, Imp, Hell Knight, Baron of Hell,
Revenant, Arch-vile, Demon, Spectre, Lost Soul, Cacodemon, Pain Elemental, Mancubus, Arachnotron,
Cyberdemon. Needs `doom2.wad`; with `doom.wad` only the Doom 1 monsters change. IWADs are not included.

- **Hit zones**: head, torso, arms, legs for humanoids; eye/face, shell, sides, mouth for orbs; brain,
  chassis, leg groups and gun for the Arachnotron. Headshots and weak spots do double damage.
- **Live wounds**: a zone that takes enough damage switches to its wounded model (`A_ChangeModel`) while
  the animation keeps playing. The Arch-vile heals the wounds when it resurrects.
- **Deaths by zone and damage type**: head, legs, front or back; explosions throw the body away from the
  blast; heavy overkill bursts it into Rigid Body chunks plus flying meat. Flyers fall and land.
- **Blood**: square voxel particles on every hit (red, blue for the Cacodemon, bone and fire for the Lost
  Soul, sparks for metal parts). For blood that stays in the world, add `voxel-gore-blood`.

## Build

```
python3 voxel-gore-enemies/make_pk3.py           # doomxr-voxel-gore-enemies.pk3 (about 36 MB)
python3 voxel-gore-enemies/make_pk3.py --test    # test map: all monsters in a row, wounds, deaths, blasts
```

Desktop GZDoom: `gzdoom -iwad doom2.wad -file doomxr-voxel-gore-enemies.pk3 [doomxr-voxel-gore-blood.pk3]`.
Test scene: add `doomxr-voxel-gore-enemies-test.pk3 +map VGNH`.

## DoomXR status

Tested in GZDoom 4.14.2 on macOS (Vulkan). In DoomXR on Quest the renderer runs in GLES mode, which
does not upload model bones yet, so the monsters stand in their bind pose. The engine fix is in progress
in the DoomXR repo; until then use the mod on desktop GZDoom or wait for the fix.

## Layout

- `source/`: `ZSCRIPT.zs` (shared mixin in `zscript/vg_core.zs`, one file per monster in
  `zscript/monsters/`) and `MODELDEF.txt` (one file per monster in `modeldef/`).
- `models/<monster>/`: `<p>_anims.iqm` (skeleton and all animations), `<p>_<zone>_<0|1>.iqm`, palette
  `<p>_pal.png` (the Cyberdemon uses a texture atlas `cy_tex.png`: left half intact, right half wounded).
- `test/`: the test map source (`ZSCRIPT.txt`, `MAPINFO.txt`, `maps/VGNH.wad`).
- `tools/blender/`: the export used for the models, run inside Blender 5.2:
  `blender -b --python vg_build.py -- <monster> <prefix> <kind> <file.blend> <out_dir> <out.blend>`.
  `enemies.txt` lists every monster with its prefix and animation kind. The `.blend` files are not in
  this repo.
