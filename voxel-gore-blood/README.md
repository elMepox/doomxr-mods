# voxel-gore-blood

Blood that stays in the world, in the same voxel style as `voxel-gore-enemies`. Works with that mod or
alone with any monsters, since everything runs from one EventHandler and no monster class is replaced.

- Hits throw voxel drops that fly, splat on walls and pool on the floor, with pixel splats on the wall
  behind; heavy hits splat the ceiling, which then drips.
- Monsters below 60% health leave a trail of drops; a pool spreads under every corpse.
- Gibs throw voxel meat chunks that stay; blood drops land on the screen next to a gib or a blast.
- Colour follows the monster's `BloodColor` (red, blue, green).

Settings (CVARINFO): `vg_blood` 0 off .. 4 extreme (default 3), `vg_pools_max`, `vg_gibs_max`,
`vg_splats_max` (0 = keep forever), `vg_screenblood`.

## Build

```
python3 voxel-gore-blood/make_pk3.py    # doomxr-voxel-gore-blood.pk3
```

Load it after `doomxr-voxel-gore-enemies.pk3` when you use both.
