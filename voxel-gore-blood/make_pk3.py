#!/usr/bin/env python3
"""Build doomxr-voxel-gore-blood.pk3 from source/ (ZScript, MODELDEF, DECALDEF, CVARINFO, MAPINFO),
models/blood (voxel drops, pools, splats, chunks), graphics/ (decals) and sprites/.

Usage: python3 make_pk3.py [output.pk3]
"""
import os
import sys
import zipfile

HERE = os.path.dirname(os.path.abspath(__file__))
STAMP = (2026, 1, 1, 0, 0, 0)


def add_tree(z, root, prefix=''):
    for d, dirs, files in os.walk(root):
        dirs.sort()
        for f in sorted(files):
            if f.startswith('.'):
                continue
            path = os.path.join(d, f)
            info = zipfile.ZipInfo(prefix + os.path.relpath(path, root).replace(os.sep, '/'), STAMP)
            info.compress_type = zipfile.ZIP_DEFLATED
            with open(path, 'rb') as fh:
                z.writestr(info, fh.read())


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, 'doomxr-voxel-gore-blood.pk3')
    with zipfile.ZipFile(out, 'w', zipfile.ZIP_DEFLATED) as z:
        add_tree(z, os.path.join(HERE, 'source'))
        for sub in ('models', 'graphics', 'sprites'):
            add_tree(z, os.path.join(HERE, sub), sub + '/')
    print(f'{out} ({os.path.getsize(out) / 1e6:.1f} MB)')


if __name__ == '__main__':
    main()
