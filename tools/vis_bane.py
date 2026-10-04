#!/usr/bin/env python3
"""
Tegner banen sett ovenfra (og høydeprofilen) til en PNG, fra DATA-linjene til test/bane.test.lua
og eventuelt et høydekart fra test/terreng.test.lua.

    python3 tools/test_luau.py test/bane.test.lua --data /tmp/bane.json
    python3 tools/test_luau.py test/terreng.test.lua --data /tmp/terreng.json      (valgfritt)
    python3 tools/vis_bane.py /tmp/bane.json [/tmp/terreng.json] [/tmp/pynt.json ...] -o assets/previews/_bane.png
    (alle JSON-filene slås sammen; pynt kommer fra test/server_modeller.test.lua --mock --data ...)

Ingen avhengigheter utover Python (egen liten PNG-skriver).
"""
import json
import math
import struct
import sys
import zlib


def skriv_png(sti, bredde, hoyde, piksler):
    rader = b''.join(b'\x00' + bytes(piksler[y * bredde * 3:(y + 1) * bredde * 3]) for y in range(hoyde))
    def bit(type_, data):
        return struct.pack('>I', len(data)) + type_ + data + struct.pack('>I', zlib.crc32(type_ + data) & 0xffffffff)
    png = b'\x89PNG\r\n\x1a\n' + bit(b'IHDR', struct.pack('>IIBBBBB', bredde, hoyde, 8, 2, 0, 0, 0))
    png += bit(b'IDAT', zlib.compress(rader, 6)) + bit(b'IEND', b'')
    with open(sti, 'wb') as fh:
        fh.write(png)


class Lerret:
    def __init__(self, b, h, farge=(20, 40, 70)):
        self.b, self.h = b, h
        self.px = bytearray(list(farge) * (b * h))

    def sett(self, x, y, f, a=1.0):
        x, y = int(x), int(y)
        if 0 <= x < self.b and 0 <= y < self.h:
            o = (y * self.b + x) * 3
            if a >= 1:
                self.px[o:o + 3] = bytes(f)
            else:
                for k in range(3):
                    self.px[o + k] = int(self.px[o + k] * (1 - a) + f[k] * a)

    def sirkel(self, cx, cy, r, f):
        for y in range(int(cy - r), int(cy + r) + 1):
            for x in range(int(cx - r), int(cx + r) + 1):
                if (x - cx) ** 2 + (y - cy) ** 2 <= r * r:
                    self.sett(x, y, f)

    def linje(self, x0, y0, x1, y1, r, f):
        n = int(max(abs(x1 - x0), abs(y1 - y0)) / max(r * 0.5, 0.5)) + 1
        for i in range(n + 1):
            t = i / n
            self.sirkel(x0 + (x1 - x0) * t, y0 + (y1 - y0) * t, r, f)

    def lagre(self, sti):
        skriv_png(sti, self.b, self.h, self.px)


TYPEFARGE = {'vei': (235, 235, 235), 'tunnel': (200, 60, 40), 'bro': (190, 130, 70),
             'rampe': (255, 170, 0), 'gap': (255, 40, 40)}
SONEFARGE = {'strand': (240, 210, 140), 'jungel': (60, 170, 70), 'vulkan': (150, 90, 70),
             'kyst': (90, 160, 200), 'lagune': (60, 210, 210)}


def terrengfarge(h, mat):
    if mat == 'vann' or h < 0:
        d = max(-30.0, h)
        return (int(30 + d), int(110 + d * 2), int(170 + d))
    tabell = {'sand': (225, 205, 150), 'gress': (80, 150, 60), 'jungel': (45, 115, 45),
              'stein': (120, 110, 105), 'basalt': (70, 62, 60), 'lava': (255, 90, 20)}
    base = tabell.get(mat, (100, 140, 80))
    k = 0.75 + min(h, 200) / 200 * 0.5
    return tuple(min(255, int(c * k)) for c in base)


def main():
    filer = [a for a in sys.argv[1:] if not a.startswith('-')]
    ut = sys.argv[sys.argv.index('-o') + 1] if '-o' in sys.argv else 'bane.png'
    filer = [f for f in filer if f != ut]
    data = []
    for f in filer:
        data += json.load(open(f))
    terreng = [d for d in data if d.get('k') == 'h']
    P = [d for d in data if d['k'] == 'p']
    K = [d for d in data if d['k'] == 'k']
    kasser = [d['i'] for d in data if d['k'] == 'kasse']
    boost = [d['i'] for d in data if d['k'] == 'boost']

    xmin, xmax, zmin, zmax = -760, 760, -760, 760
    B = 1100
    skala = B / (xmax - xmin)
    H_profil = 220
    c = Lerret(B, B + H_profil)

    def til(x, z):
        return (x - xmin) * skala, (z - zmin) * skala

    # høydekart
    for t in terreng:
        if t.get('k') != 'h':
            continue
        steg = t['steg']
        for rad in t['rader']:
            z = rad['z']
            for n, (h, mat) in enumerate(rad['v']):
                x = rad['x0'] + n * steg
                f = terrengfarge(h, mat)
                x0, y0 = til(x, z)
                for yy in range(int(y0), int(y0 + steg * skala) + 1):
                    for xx in range(int(x0), int(x0 + steg * skala) + 1):
                        c.sett(xx, yy, f)
    # banen
    for i, p in enumerate(P):
        q = P[(i + 1) % len(P)]
        x0, y0 = til(p['x'], p['z'])
        x1, y1 = til(q['x'], q['z'])
        bredde = p['b'] * skala / 2
        c.linje(x0, y0, x1, y1, max(bredde, 1.5), (40, 40, 45))
    for i, p in enumerate(P):
        q = P[(i + 1) % len(P)]
        x0, y0 = til(p['x'], p['z'])
        x1, y1 = til(q['x'], q['z'])
        c.linje(x0, y0, x1, y1, 1.5, TYPEFARGE.get(p['t'], (255, 0, 255)))
        if i % 25 == 0:
            c.sirkel(x0, y0, 2.5, SONEFARGE.get(p['s'], (255, 0, 255)))
    for k in K:
        x, y = til(k['x'], k['z'])
        c.sirkel(x, y, 4, (255, 255, 0))
    for i in kasser:
        p = P[i - 1]
        x, y = til(p['x'], p['z'])
        c.sirkel(x, y, 5, (255, 200, 0))
    for i in boost:
        p = P[i - 1]
        x, y = til(p['x'], p['z'])
        c.sirkel(x, y, 5, (0, 220, 255))
    PYNTFARGE = {'Palme': (40, 220, 60), 'PalmeLiten': (120, 230, 90), 'Jungeltre': (20, 120, 30),
                 'Busk': (230, 80, 160), 'Stein': (160, 160, 160), 'StorStein': (90, 90, 95)}
    for d in data:
        if d['k'] == 'pynt':
            x, y = til(d['x'], d['z'])
            c.sirkel(x, y, 2.2, PYNTFARGE.get(d['n'], (255, 255, 0)))
    s = P[0]
    x, y = til(s['x'], s['z'])
    c.sirkel(x, y, 7, (255, 255, 255))
    # høydeprofil
    lengde = P[-1]['d'] + 8
    ymax = max(p['y'] for p in P) + 10
    for i, p in enumerate(P):
        xx = p['d'] / lengde * (B - 20) + 10
        hh = p['y'] / ymax * (H_profil - 30)
        f = TYPEFARGE.get(p['t'], (255, 0, 255))
        for yy in range(int(B + H_profil - 10 - hh), B + H_profil - 10):
            c.sett(xx, yy, f, 0.8)
    c.lagre(ut)
    print('Skrev', ut)


if __name__ == '__main__':
    main()
