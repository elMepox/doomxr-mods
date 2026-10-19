# DoomXR mods

Mods for [DoomXR](https://github.com/elmepox/questzdoom), the VR port of GZDoom for Meta Quest. One folder per mod,
each with its sources and a script that builds the `.pk3`. Built `.pk3` files are not committed; they are attached to
[Releases](../../releases).

| Mod | What it does |
| --- | --- |
| [model-weapons-ps1](model-weapons-ps1/) | Animated PS1-style 3D models for all nine Doom 1/2 weapons, with muzzle flashes |

Build any mod with `python3 <mod>/make_pk3.py`. Copy the result to the headset's DoomXR mods folder, or add it through
the in-game mod manager.
