#!/usr/bin/env python3
"""Build doomxr-voxel-gore-enemies.pk3: ZScript + MODELDEF from source/, IQM models and palettes from models/.

Usage: python3 make_pk3.py [output.pk3]          the mod
       python3 make_pk3.py --test [output.pk3]   the test map (load it after the mod, then +map VGNH)

The models are exported from Blender files that are not in this repo, with tools/blender/vg_build.py.
"""
import os
import sys
import zipfile

HERE = os.path.dirname(os.path.abspath(__file__))
STAMP = (2026, 1, 1, 0, 0, 0)   # fixed timestamp: the same sources always give the same pk3


def add_tree(z, root, prefix=''):
    for d, dirs, files in os.walk(root):
        dirs.sort()
        for f in sorted(files):
            if f.startswith('.'):
                continue
            path = os.path.join(d, f)
            name = prefix + os.path.relpath(path, root).replace(os.sep, '/')
            info = zipfile.ZipInfo(name, STAMP)
            info.compress_type = zipfile.ZIP_DEFLATED
            with open(path, 'rb') as fh:
                z.writestr(info, fh.read())


def main():
    args = sys.argv[1:]
    test = '--test' in args
    args = [a for a in args if a != '--test']
    name = 'doomxr-voxel-gore-enemies-test.pk3' if test else 'doomxr-voxel-gore-enemies.pk3'
    out = args[0] if args else os.path.join(HERE, name)
    with zipfile.ZipFile(out, 'w', zipfile.ZIP_DEFLATED) as z:
        if test:
            add_tree(z, os.path.join(HERE, 'test'))
        else:
            add_tree(z, os.path.join(HERE, 'source'))
            add_tree(z, os.path.join(HERE, 'models'), 'models/')
    print(f'{out} ({os.path.getsize(out) / 1e6:.1f} MB)')


if __name__ == '__main__':
    main()
