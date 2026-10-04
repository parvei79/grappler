#!/usr/bin/env python3
"""
Tegner øyene ovenfra og fra siden (sør) til en PNG, fra DATA-linjene til test/oyer.test.lua.

    python3 tools/test_luau.py test/oyer.test.lua --data /tmp/oyer.json
    python3 tools/vis_oyer.py /tmp/oyer.json -o assets/previews/_oyer.png
"""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from vis_bane import Lerret  # noqa: E402

FARGE = {'hjem': (90, 170, 70), 'sopp': (200, 140, 220), 'krystall': (150, 120, 255), 'ruin': (200, 190, 160),
         'sno': (240, 245, 255), 'orken': (235, 205, 140), 'jungel': (40, 130, 50), 'lava': (90, 60, 55),
         'taarn': (150, 150, 160), 'stein': (130, 125, 120)}


def main():
    data = json.load(open(sys.argv[1]))
    ut = sys.argv[sys.argv.index('-o') + 1] if '-o' in sys.argv else 'oyer.png'
    B, H = 1000, 1000 + 360
    c = Lerret(B, H, (150, 195, 235))
    x0, x1, z0, z1 = -500, 500, -500, 500
    s = B / (x1 - x0)
    for d in data:
        if d['k'] == 'c':
            f = FARGE.get(d['tema'], (255, 0, 255))
            k = 0.7 + min(max(d['t'], 0), 200) / 200 * 0.5
            f = tuple(min(255, int(v * k)) for v in f)
            px, pz = (d['x'] - x0) * s, (d['z'] - z0) * s
            for yy in range(int(pz), int(pz + 4 * s) + 1):
                for xx in range(int(px), int(px + 4 * s) + 1):
                    c.sett(xx, yy, f)
    for d in data:
        if d['k'] == 'bro':
            c.linje((d['ax'] - x0) * s, (d['az'] - z0) * s, (d['bx'] - x0) * s, (d['bz'] - z0) * s, 1.5, (120, 80, 40))
    # sidebilde: x mot y, sett fra sør
    y0 = 1000 + 340
    ys = 1.2
    for d in data:
        if d['k'] == 'c':
            f = FARGE.get(d['tema'], (255, 0, 255))
            px = (d['x'] - x0) * s
            for yy in range(int(y0 - d['t'] * ys), int(y0 - d['b'] * ys)):
                c.sett(px, yy, f, 0.25)
    c.lagre(ut)
    print('Skrev', ut)


if __name__ == '__main__':
    main()
