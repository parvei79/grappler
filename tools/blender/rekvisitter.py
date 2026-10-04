"""
rekvisitter — pynt til de flytende øyene i GRAPPLER, bygget med kode i Blender.

Spillerne svinger seg med gripekrok mellom øyer i lufta. Hver øy har sitt tema:
hjemøya (grønn landsby), krystalløya, soppøya, snøøya, ørkenøya, ruinøya, jungeløya og lavaøya,
pluss felles mål å svinge seg rundt (tårn, luftskip, svevesteiner).

Brukes av hovedskriptet etter at rbxlib er importert:

    import rekvisitter
    neste_x = rekvisitter.bygg_alle(x0)

Test alene (bygger bare disse modellene og rendrer kontrollbilder):

    /Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup -P tools/blender/test_rekvisitter.py

Konvensjoner (se rbxlib): 1 enhet = 1 stud, +Z er opp, forsiden peker mot +Y og origo er bakken
midt under modellen (unntak står i docstringen til modellen). Alle fargene heter r_* og registreres
når modulen importeres, altså før palettbildet lages.

Stilen er chunky leketøy/lavpoly: myke kanter (fas), mettede farger, kantete steiner, krystaller og
trekroner (flat skyggelegging), runde sopper, snøballer og ballonger (myk skyggelegging).
"""
import math
import random

import bmesh
import bpy
from mathutils import Euler, Matrix, Vector

import rbxlib as R

TAU = 2 * math.pi

# ---------------------------------------------------------------- palett (registreres ved import)

R.farger(
    # grønt
    r_gress='#4cc04a', r_gress_mork='#2f8f3a', r_blad='#3dbb4a', r_blad_mork='#23893a',
    r_blad_lys='#8ad63c', r_mose='#6aa83a', r_gran='#1f6b46', r_gran_lys='#2b8752',
    # treverk og jord
    r_tre_lys='#e3b47c', r_tre='#b77a45', r_tre_mork='#7a4a28', r_bark='#6f4a2e', r_jord='#8a5a3a',
    # hus og mølle
    r_vegg='#fff1d6', r_tak='#d8343c', r_tak_mork='#a3222d', r_mur='#c0603f', r_vindu='#8fd8ff',
    r_skodde='#2f86d1', r_hvit='#f7f5ef', r_seil='#fff8e7',
    # metall og lys
    r_jern='#3a3f4a', r_lys='#ffd84a', r_gull='#ffc928', r_metall='#b4bac2', r_gra_mork='#5b616b',
    r_svart='#26262c',
    # sterke farger
    r_rod='#e8343f', r_gul='#ffcc1a', r_rosa='#ff6fb0', r_oransje='#ff8a1c', r_turkis='#17c3c8',
    # halm og sekk
    r_halm='#e6bb63', r_halm_mork='#c9963f', r_halm_lys='#f5d989', r_saek='#c9a77a',
    # krystaller
    r_kr_lilla='#9b5cff', r_kr_lilla_lys='#c9a2ff', r_kr_lilla_mork='#6a32c9',
    r_kr_bla='#3fa9ff', r_kr_bla_lys='#9fe6ff', r_kr_rosa='#ff5fcf', r_kr_rosa_lys='#ffb3ee',
    r_kr_stein='#5d5070',
    # sopp
    r_prikk='#fff8ec', r_stilk='#f3e6cc', r_stilk_mork='#d6c19b', r_skiver='#e7c9a5',
    # snø
    r_sno='#f4f9ff', r_sno_skygge='#cfe2f3', r_gulrot='#ff7a1a',
    # ørken
    r_kaktus='#4fae4a', r_kaktus_mork='#2f7d3a', r_torn='#fff1c4', r_sand='#f2d49b',
    r_sandstein='#e3b86c', r_sandstein_lys='#f3d89e', r_sandstein_mork='#c08f4b',
    # ruiner
    r_marmor='#efe5d0', r_marmor_skygge='#cbc2b2', r_ruinstein='#b8ad98', r_ruinstein_lys='#d4ccb9',
    r_ruinstein_mork='#8f8574', r_moai='#9a8f86', r_moai_mork='#6f665f',
    # jungel
    r_bambus='#9ccc45', r_bambus_mork='#5f9a2c',
    # lava
    r_basalt='#3d3943', r_basalt_mork='#2a272f', r_lava='#ff6a00', r_lava_gul='#ffc21a',
    # stein, tårn, luftskip
    r_stein='#a39d93', r_stein_lys='#cdc7bb', r_stein_mork='#7f786f',
    r_tak_bla='#2f6fd6', r_tak_bla_lys='#5d9bf0', r_vindu_mork='#2b3550',
)


# ---------------------------------------------------------------- hjelpere

def T(pos):
    return Matrix.Translation(Vector(pos))


def _rot(rot):
    """(x, y, z) i grader -> 4x4-matrise. None gir identitet."""
    if rot is None:
        return Matrix.Identity(4)
    return Euler([math.radians(a) for a in rot]).to_matrix().to_4x4()


def _m(pos=(0, 0, 0), rot=None, skala=None):
    """Matrise: skaler, så roter (grader), så flytt."""
    m = T(pos) @ _rot(rot)
    if skala is not None:
        m = m @ Matrix.Diagonal((skala[0], skala[1], skala[2], 1.0))
    return m


def _mot(retning):
    """Rotasjon (4x4) som snur +Z mot `retning`."""
    return Vector((0, 0, 1)).rotation_difference(Vector(retning).normalized()).to_matrix().to_4x4()


def _rz(grader):
    return Matrix.Rotation(math.radians(grader), 4, 'Z')


def _ry(grader):
    return Matrix.Rotation(math.radians(grader), 4, 'Y')


def _rx(grader):
    return Matrix.Rotation(math.radians(grader), 4, 'X')


def _flat(ob):
    """Flat skyggelegging på én del (kantete steiner, krystaller, trekroner)."""
    for p in ob.data.polygons:
        p.use_smooth = False
    return ob


def _del(bm, f, fas=0.0, segm=2, flat=False):
    """Gjør en egen bmesh om til en del av modellen (palett-UV, normaler og ev. fas via rbxlib)."""
    ob = R._ferdig(bm, f, fas, segm)
    return _flat(ob) if flat else ob


def _del_flerfarget(bm, lag, farger, flat=False):
    """Som _del, men hver flate får fargen farger[flate[lag]] (striper, soppskiver, ballonger)."""
    uv = bm.loops.layers.uv.verify()
    for fc in bm.faces:
        u = R._uv(farger[fc[lag]])
        for lp in fc.loops:
            lp[uv].uv = u
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new('del')
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = not flat
    ob = bpy.data.objects.new('del', me)
    bpy.context.scene.collection.objects.link(ob)
    me.materials.append(R.palett_materiale())
    R._DELER.append(ob)
    return ob


def loft(ringer, f, lukket=True, lokk=(True, True), rundt=False, m=None, fas=0.0, segm=2, flat=False):
    """Bind sammen ringer (lister med like mange punkter) med firkanter.

    lukket: hver ring er lukket (siste punkt bindes til første).
    lokk:   (start, slutt) lukkes med en flate. En ring med ett punkt gir en spiss (vifte).
    rundt:  siste ring bindes til første (smultring).
    m:      matrise som flytter/roterer hele delen.
    """
    bm = bmesh.new()
    vr = [[bm.verts.new(Vector(p)) for p in ring] for ring in ringer]
    par = list(zip(vr, vr[1:]))
    if rundt:
        par.append((vr[-1], vr[0]))
    for a, b in par:
        if len(a) == 1 or len(b) == 1:
            spiss, ring = (a[0], b) if len(a) == 1 else (b[0], a)
            antall = len(ring) if lukket else len(ring) - 1
            for j in range(antall):
                bm.faces.new((ring[j], ring[(j + 1) % len(ring)], spiss))
        else:
            antall = len(a) if lukket else len(a) - 1
            for j in range(antall):
                j2 = (j + 1) % len(a)
                bm.faces.new((a[j], a[j2], b[j2], b[j]))
    if not rundt:
        if lokk[0] and len(vr[0]) > 2:
            bm.faces.new(vr[0])
        if lokk[1] and len(vr[-1]) > 2:
            bm.faces.new(list(reversed(vr[-1])))
    if m is not None:
        bmesh.ops.transform(bm, matrix=m, verts=bm.verts)
    return _del(bm, f, fas, segm, flat)


def dreie(profil, f, n=16, m=None, fas=0.0, segm=2, flat=False, rundt=False, fase=0.0):
    """Dreiefigur rundt Z-aksen. profil = [(r, z), ...]. r=0 gir en spiss/lukket ende.
    rundt=True: profilen er en lukket løkke (smultringer)."""
    ringer = []
    for r, z in profil:
        if r < 1e-5:
            ringer.append([(0.0, 0.0, z)])
        else:
            ringer.append([(r * math.cos(TAU * j / n + fase), r * math.sin(TAU * j / n + fase), z)
                           for j in range(n)])
    return loft(ringer, f, lukket=True, rundt=rundt, m=m, fas=fas, segm=segm, flat=flat)


def dreie_farget(profil, f_bit, n=16, m=None, flat=False, striper=None, per=1, fase=0.0):
    """Dreiefigur med flere farger i én lukket del.
    f_bit[i]: fargen mellom profilpunkt i og i+1. None -> langsgående striper fra `striper`
    (per = antall sektorer per stripe). Lokkene får fargen til nærmeste bit."""
    navn = sorted({f for f in f_bit if f} | set(striper or []))
    idx = {f: i for i, f in enumerate(navn)}
    bm = bmesh.new()
    lag = bm.faces.layers.int.new('farge')
    ringer = []
    for r, z in profil:
        if r < 1e-5:
            ringer.append([bm.verts.new((0.0, 0.0, z))])
        else:
            ringer.append([bm.verts.new((r * math.cos(TAU * j / n + fase), r * math.sin(TAU * j / n + fase), z))
                           for j in range(n)])
    for i, (a, b) in enumerate(zip(ringer, ringer[1:])):
        for j in range(n):
            j2 = (j + 1) % n
            if len(a) == 1:
                fc = bm.faces.new((b[j2], b[j], a[0]))
            elif len(b) == 1:
                fc = bm.faces.new((a[j], a[j2], b[0]))
            else:
                fc = bm.faces.new((a[j], a[j2], b[j2], b[j]))
            f = f_bit[i] or striper[(j // per) % len(striper)]
            fc[lag] = idx[f]
    for ring, f in ((ringer[0], f_bit[0]), (ringer[-1], f_bit[-1])):
        if len(ring) > 2:
            fc = bm.faces.new(ring)
            fc[lag] = idx[f or striper[0]]
    if m is not None:
        bmesh.ops.transform(bm, matrix=m, verts=bm.verts)
    return _del_flerfarget(bm, lag, navn, flat)


def _rammer(sti, lukket=False, opp=None):
    """(punkt, tangent, side, normal) langs en sti. Uten `opp` brukes parallelltransport (ingen vridning)."""
    p = [Vector(q) for q in sti]
    k = len(p)
    tang = []
    for i in range(k):
        if lukket:
            t = (p[(i + 1) % k] - p[i]).normalized() + (p[i] - p[i - 1]).normalized()
        elif i == 0:
            t = p[1] - p[0]
        elif i == k - 1:
            t = p[-1] - p[-2]
        else:
            t = (p[i + 1] - p[i]).normalized() + (p[i] - p[i - 1]).normalized()
        tang.append(t.normalized())
    ut = []
    if opp is not None:
        for i, t in enumerate(tang):
            s = t.cross(Vector(opp)).normalized()
            ut.append((p[i], t, s, s.cross(t).normalized()))
        return ut
    ref = Vector((0, 0, 1)) if abs(tang[0].z) < 0.95 else Vector((1, 0, 0))
    s = tang[0].cross(ref).normalized()
    for i, t in enumerate(tang):
        if i:
            s = tang[i - 1].rotation_difference(t) @ s
            s = (s - t * s.dot(t)).normalized()
        ut.append((p[i], t, s, t.cross(s).normalized()))
    return ut


def ror(sti, r, f, n=8, lukket=False, lokk=True, profil=None, opp=None, m=None, fas=0.0, flat=False):
    """Rør langs en sti (stammer, armer, ranker, tau).
    r: tall eller liste med én radius per punkt. profil: egen 2D-profil [(u, v), ...] i stedet
    for sirkel (skaleres med r)."""
    rs = list(r) if isinstance(r, (list, tuple)) else [r] * len(sti)
    if profil is None:
        profil = [(math.cos(TAU * j / n), math.sin(TAU * j / n)) for j in range(n)]
    ringer = []
    for (p, _t, s, nn), rr in zip(_rammer(sti, lukket, opp), rs):
        ringer.append([p + s * (u * rr) + nn * (v * rr) for u, v in profil])
    return loft(ringer, f, lukket=True, lokk=(lokk, lokk), rundt=lukket, m=m, fas=fas, flat=flat)


def plate_m(punkter, tykk, f, m=None, fas=0.0, segm=2, flat=False):
    """Som R.plate i XZ-planet (punkter = (x, z), tykkelse langs Y), men med vilkårlig matrise."""
    bak = [(u, -tykk / 2, v) for u, v in punkter]
    foran = [(u, tykk / 2, v) for u, v in punkter]
    return loft([bak, foran], f, m=m, fas=fas, segm=segm, flat=flat)


def kasse_m(str_, f, m, fas=0.0, segm=2):
    """Kasse med størrelse str_ rundt origo, flyttet/rotert med matrisen m."""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=Vector(str_), verts=bm.verts)
    bmesh.ops.transform(bm, matrix=m, verts=bm.verts)
    return _del(bm, f, fas, segm)


def kule_m(r, f, m, skala=(1, 1, 1), u=8, v=6, flat=False):
    """Kule/ellipsoide med vilkårlig matrise (moseflekker, kronblader, blink)."""
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=u, v_segments=v, radius=r)
    bmesh.ops.scale(bm, vec=Vector(skala), verts=bm.verts)
    bmesh.ops.transform(bm, matrix=m, verts=bm.verts)
    return _del(bm, f, flat=flat)


def _stein_bm(sentrum, r, skala, rot, deling, ujevn, nr, bunn):
    rng = random.Random(nr)
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=deling, radius=r)
    for v in bm.verts:
        v.co *= 1 + rng.uniform(-ujevn, ujevn)
    bmesh.ops.scale(bm, vec=Vector(skala), verts=bm.verts)
    bmesh.ops.transform(bm, matrix=_m(sentrum, rot), verts=bm.verts)
    if bunn is not None:
        for v in bm.verts:
            v.co.z = max(v.co.z, bunn)
    return bm


def stein(sentrum, r, f, skala=(1, 1, 1), rot=None, deling=2, ujevn=0.15, nr=0, bunn=None, flat=True):
    """Kantete, ujevn stein/klump (ikosaeder med tilfeldig radius per hjørne).
    deling=2 gir 80 trekanter. bunn: klipp alt under denne høyden flatt (står på bakken)."""
    return _del(_stein_bm(sentrum, r, skala, rot, deling, ujevn, nr, bunn), f, flat=flat)


def _flytt_deler(fra, m):
    """Transformer alle delene fra indeks `fra` i modellen som bygges nå (vippe hatter, skalere sopper)."""
    for ob in R._DELER[fra:]:
        ob.data.transform(m)


def _gresstust(sentrum, h, f, nr, antall=4):
    """Liten dusk med gress (smale blader som peker opp og ut)."""
    rng = random.Random(nr)
    s = Vector(sentrum)
    for i in range(antall):
        a = TAU * i / antall + rng.uniform(-0.4, 0.4)
        d = (math.cos(a) * 0.45, math.sin(a) * 0.45, 1.0)
        R.blad(s, d, h * rng.uniform(0.8, 1.15), h * 0.28, f, heng=0.3, fold=0.2, tykk=0.06, segm=3)


def _moseflekk(p, normal, r, f='r_mose', skala=(1.3, 1.0, 0.32)):
    """Flat, rund flekk (mose, snø, lav) som ligger på en flate med gitt normal."""
    return kule_m(r, f, T(p) @ _mot(normal), skala=skala, u=7, v=4)


def _superellipse(hx, hy, n, p=4.0):
    ut = []
    for j in range(n):
        t = TAU * j / n
        c, s = math.cos(t), math.sin(t)
        ut.append((hx * math.copysign(abs(c) ** (2 / p), c), hy * math.copysign(abs(s) ** (2 / p), s)))
    return ut


def _torn(p, d, lengde, r, f):
    """Liten trekantet pigg (kaktustorner)."""
    m = T(p) @ _mot(d)
    loft([[(r * math.cos(TAU * j / 3), r * math.sin(TAU * j / 3), 0.0) for j in range(3)],
          [(0.0, 0.0, lengde)]], f, m=m)


def _blomst(sentrum, normal, s, f, f_midt='r_gul', antall=5):
    """Liten blomst: runde kronblader rundt en gul midt, vendt mot `normal`."""
    m0 = T(sentrum) @ _mot(normal)
    for i in range(antall):
        m = m0 @ _rz(360 * i / antall) @ T((0.45 * s, 0, 0)) @ _ry(-18)
        kule_m(0.42 * s, f, m, skala=(1.0, 0.7, 0.25), u=5, v=3)
    kule_m(0.22 * s, f_midt, m0 @ T((0, 0, 0.08 * s)), skala=(1, 1, 0.6), u=5, v=3)


# ================================================================ HJEMØYA

def _vindu(m, b, h, skodder=None, glass='r_vindu', ramme='r_hvit'):
    """Vindu i lokalt XZ-plan med forsiden mot +Y (veggflaten ligger i y=0), flyttet med m.
    Karm rundt, sprosser i kryss, bred sål nederst og ev. skodder på sidene."""
    t = 0.3
    kasse_m((b, 0.2, h), glass, m @ T((0, 0.04, 0)))
    kasse_m((b + 2 * t + 0.3, 0.55, t), ramme, m @ T((0, 0.2, -h / 2 - t / 2)))     # sål
    kasse_m((b + 2 * t, 0.4, t), ramme, m @ T((0, 0.15, h / 2 + t / 2)))
    for sx in (-1, 1):
        kasse_m((t, 0.4, h), ramme, m @ T((sx * (b / 2 + t / 2), 0.15, 0)))
    kasse_m((0.16, 0.3, h), ramme, m @ T((0, 0.12, 0)))
    kasse_m((b, 0.3, 0.16), ramme, m @ T((0, 0.12, 0)))
    if skodder:
        for sx in (-1, 1):
            cx = sx * (b / 2 + t + b * 0.27 + 0.05)
            kasse_m((b * 0.54, 0.22, h + 0.4), skodder, m @ T((cx, 0.1, 0)))
            kasse_m((b * 0.4, 0.1, 0.16), 'r_hvit', m @ T((cx, 0.25, h * 0.25)))
            kasse_m((b * 0.4, 0.1, 0.16), 'r_hvit', m @ T((cx, 0.25, -h * 0.25)))


def hus(x):
    """Koselig hytte ca. 14 bred, 12 dyp, 14 høy: kremhvite vegger med bindingsverk-hjørner,
    rødt tak med takstein-rader, murpipe, buet dør med trappestein, vinduer med karmer og
    skodder, blomsterkasse og runde gavlvinduer. Døra vender mot +Y."""
    R.ny_modell()
    B, D = 12.0, 10.0
    R.kasse((0, 0, 0.5), (13.0, 11.0, 1.0), 'r_stein', fas=0.2)
    R.kasse((0, 0, 4.0), (B, D, 6.0), 'r_vegg', fas=0.1)
    for sx in (-1, 1):
        for sy in (-1, 1):
            R.kasse((sx * B / 2, sy * D / 2, 4.0), (0.8, 0.8, 6.0), 'r_tre_mork', fas=0.1, segm=1)
    for sy in (-1, 1):
        R.kasse((0, sy * D / 2, 6.85), (B + 0.4, 0.7, 0.6), 'r_tre_mork', fas=0.08, segm=1)
    for sx in (-1, 1):
        R.kasse((sx * B / 2, 0, 6.85), (0.7, D + 0.4, 0.6), 'r_tre_mork', fas=0.08, segm=1)
    # gavl (fyller volumet under taket)
    zg, topp = 7.0, 12.4
    R.plate([(-D / 2, zg), (D / 2, zg), (0, topp)], B - 0.1, 'r_vegg', plan='YZ', midt=0)
    # tak: bunnplate + fire rader med takstein på hver side
    k = (topp - zg) / (D / 2)
    ey = D / 2 + 0.8
    E = Vector((ey, topp - k * ey))
    Tp = Vector((0.0, topp))
    d = (Tp - E).normalized()
    nrm = Vector((d.y, -d.x))
    L = (Tp - E).length
    for s in (1, -1):
        def sp(v):
            return (v.x * s, v.y)
        R.plate([sp(E), sp(Tp), sp(Tp + nrm * 0.45), sp(E + nrm * 0.45)], B + 1.8, 'r_tak_mork', plan='YZ')
        rader = 4
        for i in range(rader):
            s0 = L * i / rader - (0.35 if i == 0 else 0.3)
            s1 = L * (i + 1) / rader + 0.05
            P0 = E + d * s0 + nrm * 0.45
            P1 = E + d * s1 + nrm * 0.45
            R.plate([sp(P0 - nrm * 0.1), sp(P1), sp(P1 + nrm * 0.12), sp(P0 + nrm * 0.62)], B + 2.0,
                    'r_tak' if i % 2 == 0 else 'r_rod', plan='YZ')
    R.sylinder((-(B + 2.2) / 2, 0, topp + 0.42), ((B + 2.2) / 2, 0, topp + 0.42), 0.55, 'r_tak_mork', n=8)
    # pipe på baksiden
    px, py = 3.4, -2.4
    R.kasse((px, py, 11.6), (1.8, 1.8, 5.0), 'r_mur', fas=0.1)
    R.kasse((px, py, 12.6), (1.95, 1.95, 0.25), 'r_tak_mork')
    R.kasse((px, py, 14.2), (2.3, 2.3, 0.45), 'r_stein_mork', fas=0.08)
    R.kasse((px, py, 14.35), (1.1, 1.1, 0.3), 'r_svart')
    # dør med bue, karm, plankestriper, håndtak og trappestein
    dx = -2.8
    R.kasse((dx, 5.1, 2.8), (2.4, 0.3, 3.6), 'r_tre')
    R.sylinder((dx, 4.95, 4.6), (dx, 5.25, 4.6), 1.2, 'r_tre', n=12)
    for s in (-1, 1):
        R.kasse((dx + s * 1.36, 5.18, 2.8), (0.32, 0.45, 3.6), 'r_tre_mork')
        R.kasse((dx + s * 0.42, 5.27, 3.2), (0.09, 0.06, 4.2), 'r_tre_mork')
    R.bue((dx, 5.18, 4.6), 1.36, 0.2, 'r_tre_mork', akse=(0, 1, 0), fra=0, til=180, n1=10, n2=4)
    R.kule((dx + 0.8, 5.38, 2.9), 0.17, 'r_gull', u=6, v=4)
    R.kasse((dx, 6.0, 0.45), (3.4, 1.8, 0.9), 'r_stein_lys', fas=0.15)
    # vinduer
    _vindu(T((2.8, 5.0, 4.0)), 2.4, 2.0, skodder='r_skodde')
    _vindu(T((0.0, -5.0, 4.0)) @ _rz(180), 2.4, 2.0, skodder='r_skodde')
    for s in (-1, 1):
        _vindu(T((s * 6.0, 0.0, 4.0)) @ _rz(-90 * s), 2.4, 2.0, skodder='r_skodde')
        # rundt gavlvindu
        gx = s * (B - 0.1) / 2
        R.sylinder((gx - s * 0.1, 0, 9.4), (gx + s * 0.12, 0, 9.4), 0.85, 'r_vindu', n=12)
        R.ring((gx + s * 0.12, 0, 9.4), 0.95, 0.18, 'r_hvit', akse=(1, 0, 0), n1=12, n2=4)
        R.kasse((gx + s * 0.12, 0, 9.4), (0.14, 1.7, 0.14), 'r_hvit')
        R.kasse((gx + s * 0.12, 0, 9.4), (0.14, 0.14, 1.7), 'r_hvit')
    # blomsterkasse under frontvinduet
    R.kasse((2.8, 5.65, 2.45), (3.1, 1.0, 0.8), 'r_tre', fas=0.08)
    R.kasse((2.8, 5.65, 2.87), (2.8, 0.75, 0.1), 'r_jord')
    R.kule((2.8, 5.65, 3.0), 1.0, 'r_blad', skala=(1.35, 0.42, 0.3), u=8, v=5)
    for i, f in enumerate(('r_rod', 'r_gul', 'r_rosa', 'r_rod', 'r_gul')):
        R.kule((1.75 + i * 0.52, 5.75 + 0.12 * (i % 2), 3.3 + 0.12 * ((i + 1) % 2)), 0.26, f, u=6, v=4)
    # busker ved hjørnene foran
    R.kule((-5.9, 5.9, 0.9), 1.3, 'r_blad_mork', skala=(1.2, 1.0, 0.85), u=8, v=6)
    R.kule((-6.6, 5.0, 1.1), 1.0, 'r_blad', skala=(1.0, 1.0, 0.9), u=8, v=6)
    R.kule((6.0, 5.9, 0.8), 1.1, 'r_blad', skala=(1.2, 1.0, 0.85), u=8, v=6)
    for p, f in (((-5.4, 6.9, 1.6), 'r_rosa'), ((-6.6, 5.9, 2.0), 'r_gul'), ((6.4, 6.7, 1.45), 'r_rod')):
        R.kule(p, 0.22, f, u=6, v=4)
    return R.ferdig_modell('Hus', plass_x=x, maks_tris=4000)


def vindmolle(x):
    """Vindmølle ca. 22 høy (uten vinger): åttekantet tårn med hjørnebjelker og bånd, galleri med
    rekkverk, dør og vinduer, rød hette med knott. Akselen peker mot +Y.
    Punktet `nav` = midten av navet foran (der VindmolleVinger festes, rotasjonsakse langs Y)."""
    R.ny_modell()
    fase = TAU / 16          # flat side mot +Y
    dreie([(5.6, 0.0), (5.6, 1.4)], 'r_stein', n=8, fase=fase, fas=0.2, flat=True)
    z0, z1, ra, rb = 1.4, 15.6, 4.8, 3.3

    def rt(z):
        return ra + (rb - ra) * (z - z0) / (z1 - z0)

    for za, zb in ((1.4, 6.0), (6.0, 10.8), (10.8, 15.6)):
        dreie([(rt(za), za), (rt(zb), zb)], 'r_vegg', n=8, fase=fase, flat=True)
        dreie([(rt(zb) + 0.22, zb - 0.3), (rt(zb) + 0.22, zb + 0.3)], 'r_tre_mork', n=8, fase=fase, flat=True)
    for j in range(8):
        a = TAU * j / 8 + fase
        c, s = math.cos(a), math.sin(a)
        R.sylinder((ra * c, ra * s, z0), (rb * c, rb * s, z1), 0.2, 'r_tre_mork', n=4)
    # galleri
    zg = 5.0
    dreie([(6.0, zg - 0.4), (6.0, zg)], 'r_tre', n=12, fas=0.08)
    for j in range(12):
        a = TAU * j / 12
        c, s = math.cos(a), math.sin(a)
        R.sylinder((5.75 * c, 5.75 * s, zg), (5.75 * c, 5.75 * s, zg + 1.3), 0.09, 'r_tre_mork', n=4)
        if j % 3 == 0:
            R.sylinder((rt(3.0) * c * 0.95, rt(3.0) * s * 0.95, 3.0), (5.2 * c, 5.2 * s, zg - 0.35), 0.16,
                       'r_tre_mork', n=4)
    R.ring((0, 0, zg + 1.3), 5.75, 0.13, 'r_tre', n1=24, n2=4)
    # dør (på sokkelen) og vinduer
    yd = rt(2.5) * math.cos(TAU / 16) + 0.1
    R.kasse((0, yd, 2.9), (2.0, 0.4, 2.9), 'r_tre')
    R.sylinder((0, yd - 0.2, 4.35), (0, yd + 0.2, 4.35), 1.0, 'r_tre', n=10)
    R.bue((0, yd + 0.1, 4.35), 1.12, 0.17, 'r_tre_mork', akse=(0, 1, 0), fra=0, til=180, n1=8, n2=4)
    for s in (-1, 1):
        R.kasse((s * 1.12, yd + 0.1, 2.9), (0.3, 0.4, 2.9), 'r_tre_mork')
    R.kule((0.6, yd + 0.3, 2.9), 0.14, 'r_gull', u=6, v=4)
    for z, a in ((8.6, 90), (12.9, 90), (9.4, 210), (12.4, 330)):
        ap = rt(z) * math.cos(TAU / 16)
        m = _rz(a - 90) @ T((0, ap, z)) @ _rx(-6)
        _vindu(m, 1.2, 1.4)
    # hette med kant, knott og aksel
    dreie([(4.2, 15.3), (4.2, 15.9)], 'r_tre_mork', n=12, fas=0.08)
    dreie([(3.95, 15.85), (4.0, 16.4), (3.7, 18.4), (2.95, 20.2), (1.7, 21.3), (0.0, 21.7)], 'r_tak', n=12)
    for j in range(6):
        a = TAU * j / 6
        sti = [(r * math.cos(a), r * math.sin(a), z + 0.06) for r, z in
               ((4.05, 16.4), (3.75, 18.4), (3.0, 20.2), (1.72, 21.3), (0.3, 21.7))]
        ror(sti, 0.13, 'r_tak_mork', n=4)
    R.sylinder((0, 0, 21.6), (0, 0, 22.3), 0.16, 'r_tre_mork', n=6)
    R.kule((0, 0, 22.4), 0.38, 'r_gull', u=8, v=6)
    zn = 18.4
    R.sylinder((0, 2.6, zn), (0, 5.0, zn), 0.75, 'r_tre_mork', n=8)
    R.sylinder((0, 3.6, zn), (0, 4.1, zn), 0.95, 'r_jern', n=8)
    return R.ferdig_modell('Vindmolle', plass_x=x, punkter={'nav': (0, 5.2, zn)}, maks_tris=3000)


def vindmolle_vinger(x):
    """Fire møllevinger i XZ-planet, diameter ca. 20. ORIGO = navets midtpunkt, rotasjonsakse langs Y.
    Hver vinge: bjelke, gitter av lekter og seilduk på samme side (dreier samme vei)."""
    R.ny_modell()
    for k in range(4):
        rm = _ry(90 * k + 45)
        kasse_m((9.6, 0.55, 0.6), 'r_tre_mork', rm @ T((5.2, 0.0, 0.0)), fas=0.08)
        kasse_m((7.8, 0.32, 0.3), 'r_tre', rm @ T((6.0, 0.22, 2.75)))
        kasse_m((7.8, 0.32, 0.22), 'r_tre', rm @ T((6.0, 0.22, -0.55)))
        for u in (2.2, 3.75, 5.3, 6.85, 8.4, 9.85):
            kasse_m((0.22, 0.32, 3.55), 'r_tre', rm @ T((u, 0.22, 1.1)))
        kasse_m((7.5, 0.1, 2.55), 'r_seil', rm @ T((6.05, -0.05, 1.45)))
        kasse_m((7.5, 0.12, 0.25), 'r_rod', rm @ T((6.05, 0.0, 2.55)))
    R.sylinder((0, -0.7, 0), (0, 0.7, 0), 1.15, 'r_tre_mork', n=10)
    R.kasse((0, 0.1, 0), (1.7, 1.0, 1.7), 'r_tre', rot=(0, 45, 0), fas=0.1)
    R.kule((0, 0.75, 0), 0.7, 'r_rod', u=8, v=6)
    return R.ferdig_modell('VindmolleVinger', plass_x=x, maks_tris=1500)


def lykt(x):
    """Lyktestolpe ca. 9 høy: fot, stolpe med pyntering, krone, lanterne med gule glass og
    pyramidetak med knott. Punktet `lys` = midten av lanterna."""
    R.ny_modell()
    dreie([(1.0, 0.0), (1.0, 0.4), (0.7, 0.62), (0.42, 1.0), (0.3, 1.45), (0.0, 1.45)], 'r_jern', n=8)
    R.sylinder((0, 0, 1.3), (0, 0, 6.5), 0.2, 'r_jern', n=8)
    R.ring((0, 0, 3.4), 0.28, 0.1, 'r_jern', n1=8, n2=4)
    R.ring((0, 0, 1.6), 0.36, 0.1, 'r_gull', n1=8, n2=4)
    # tverrstang (stige-støtte) med kuler
    R.sylinder((-0.9, 0, 5.9), (0.9, 0, 5.9), 0.08, 'r_jern', n=4)
    for s in (-1, 1):
        R.kule((s * 0.95, 0, 5.9), 0.14, 'r_gull', u=6, v=4)
    dreie([(0.22, 6.3), (0.6, 6.55), (0.85, 6.7), (0.0, 6.75)], 'r_jern', n=8, fase=TAU / 16)
    # lanterne
    zl = 7.55
    R.kasse((0, 0, zl), (1.15, 1.15, 1.5), 'r_lys')
    R.kule((0, 0, zl - 0.1), 0.32, 'r_hvit', u=6, v=4)
    for sx in (-1, 1):
        for sy in (-1, 1):
            R.kasse((sx * 0.62, sy * 0.62, zl), (0.18, 0.18, 1.7), 'r_jern')
    R.kasse((0, 0, zl - 0.85), (1.45, 1.45, 0.2), 'r_jern')
    R.kasse((0, 0, zl + 0.85), (1.5, 1.5, 0.2), 'r_jern')
    dreie([(1.05, zl + 0.95), (0.12, zl + 1.6), (0.0, zl + 1.6)], 'r_jern', n=4, fase=TAU / 8, flat=True)
    R.kule((0, 0, zl + 1.72), 0.2, 'r_gull', u=6, v=4)
    return R.ferdig_modell('Lykt', plass_x=x, punkter={'lys': (0, 0, zl)}, maks_tris=800)


def dukke(x):
    """Treningsdukke av halm ca. 6 høy: kryssfot og stolpe, halmkropp med tausurring og
    frynser, armpinne med halmdusker, sekkehode med sydde kryssøyne og halmhår,
    og en rød/hvit blink-skive på brystet (mot +Y). Origo = bakken."""
    R.ny_modell()
    R.kasse((0, 0, 0.2), (3.4, 0.6, 0.4), 'r_tre_mork', fas=0.08, segm=1)
    R.kasse((0, 0, 0.2), (0.6, 3.4, 0.4), 'r_tre_mork', fas=0.08, segm=1)
    R.sylinder((0, 0, 0.3), (0, 0, 5.0), 0.24, 'r_tre', n=8)
    # halmkropp
    dreie([(0.0, 1.5), (0.8, 1.55), (1.15, 1.95), (1.25, 2.8), (1.15, 3.65), (0.9, 4.05), (0.0, 4.15)],
          'r_halm', n=12)
    for z, rr in ((2.0, 1.17), (3.6, 1.16)):
        R.ring((0, 0, z), rr, 0.1, 'r_halm_mork', n1=14, n2=4)
    for j in range(10):
        a = TAU * j / 10 + 0.2
        c, s = math.cos(a), math.sin(a)
        R.sylinder((0.85 * c, 0.85 * s, 1.75), (1.05 * c, 1.05 * s, 0.95 + 0.15 * (j % 2)), 0.24,
                   'r_halm_lys' if j % 2 else 'r_halm', r2=0.03, n=4)
    # armer
    R.sylinder((-2.5, 0, 3.4), (2.5, 0, 3.4), 0.13, 'r_tre', n=6)
    for s in (-1, 1):
        R.sylinder((s * 1.0, 0, 3.4), (s * 2.0, 0, 3.35), 0.36, 'r_halm', r2=0.3, n=8)
        R.ring((s * 1.85, 0, 3.36), 0.32, 0.07, 'r_halm_mork', akse=(1, 0, 0), n1=8, n2=4)
        for j in range(5):
            a = TAU * j / 5
            R.sylinder((s * 2.1, 0.15 * math.cos(a), 3.35 + 0.15 * math.sin(a)),
                       (s * 2.75, 0.42 * math.cos(a), 3.35 + 0.42 * math.sin(a)), 0.13, 'r_halm_lys',
                       r2=0.02, n=4)
    # hode
    R.sylinder((0, 0, 4.0), (0, 0, 4.3), 0.42, 'r_halm_mork', n=8)
    R.kule((0, 0, 4.85), 0.85, 'r_saek', skala=(1.0, 0.95, 0.92), u=10, v=7)
    R.ring((0, 0, 4.2), 0.42, 0.1, 'r_halm_mork', n1=10, n2=4)
    for j in range(7):
        a = TAU * j / 7
        c, s = math.cos(a), math.sin(a)
        R.sylinder((0.25 * c, 0.25 * s, 5.5), (0.75 * c, 0.75 * s, 6.05 + 0.1 * (j % 2)), 0.14,
                   'r_halm' if j % 2 else 'r_halm_lys', r2=0.02, n=4)
    for sx in (-0.32, 0.32):        # sydde kryssøyne
        for v in (45, -45):
            R.kasse((sx, 0.79, 5.0), (0.42, 0.1, 0.09), 'r_tre_mork', rot=(0, v, 0))
    R.kasse((0, 0.8, 4.55), (0.6, 0.1, 0.08), 'r_tre_mork', rot=(0, 0, 0))
    for sx in (-0.2, 0.0, 0.2):
        R.kasse((sx, 0.81, 4.55), (0.06, 0.1, 0.24), 'r_tre_mork')
    # blink-skive på brystet
    yb = 1.17
    for i, (rr, f) in enumerate(((0.98, 'r_rod'), (0.74, 'r_hvit'), (0.5, 'r_rod'), (0.24, 'r_gul'))):
        R.sylinder((0, yb + 0.05 * i, 2.8), (0, yb + 0.05 * i + 0.16, 2.8), rr, f, n=14 if i < 2 else 10)
    return R.ferdig_modell('Dukke', plass_x=x, maks_tris=1500)


# ================================================================ KRYSTALLØYA

KRYSTALL_FARGER = {
    'lilla': ('r_kr_lilla', 'r_kr_lilla_lys'),
    'mork': ('r_kr_lilla_mork', 'r_kr_lilla'),
    'bla': ('r_kr_bla', 'r_kr_bla_lys'),
    'rosa': ('r_kr_rosa', 'r_kr_rosa_lys'),
}


def _krystall(bunn, retning, lengde, r, farge, n=6, fase=0.0):
    """Sekskantet krystall med spiss topp. Fasettene veksler mellom mørk og lys farge,
    spissen er lys. Starter litt under `bunn` så den sitter fast i steinen."""
    f, lys = KRYSTALL_FARGER[farge]
    m = T(bunn) @ _mot(retning) @ _rz(fase)
    dreie_farget([(r * 0.75, -0.5), (r, lengde * 0.14), (r, lengde * 0.72), (0.0, lengde)],
                 [None, None, None], n=n, m=m, flat=True, striper=[f, lys])
    dreie_farget([(r * 1.004, lengde * 0.72), (0.0, lengde + 0.004)], [lys], n=n, m=m, flat=True)


def krystall(x):
    """Klynge av 7 lilla/blå/rosa krystaller ca. 8 høy på en mørk steinknoll."""
    R.ny_modell()
    stein((0, 0, 0.35), 2.3, 'r_kr_stein', skala=(1.35, 1.15, 0.45), ujevn=0.12, nr=31, bunn=0)
    stein((1.9, 1.3, 0.2), 0.8, 'r_kr_stein', skala=(1.2, 1, 0.6), nr=32, bunn=0)
    kr = [((0.0, 0.0, 0.5), (0.05, 0.05, 1), 7.6, 1.1, 'lilla'),
          ((1.3, 0.55, 0.4), (0.55, 0.25, 1), 5.0, 0.78, 'bla'),
          ((-1.3, 0.7, 0.4), (-0.6, 0.35, 1), 5.6, 0.85, 'rosa'),
          ((0.5, -1.25, 0.4), (0.2, -0.6, 1), 4.4, 0.7, 'bla'),
          ((-0.9, -1.0, 0.35), (-0.45, -0.5, 1), 3.4, 0.6, 'mork'),
          ((1.7, -0.6, 0.25), (0.95, -0.25, 0.6), 2.5, 0.5, 'rosa'),
          ((-2.0, -0.2, 0.25), (-1.0, 0.0, 0.55), 2.2, 0.45, 'lilla')]
    for i, (b, d, L, r, f) in enumerate(kr):
        _krystall(b, d, L, r, f, fase=0.4 * i)
    for i, (p, f) in enumerate((((2.4, 1.4, 0.6), 'bla'), ((-2.6, 1.1, 0.0), 'rosa'))):
        _krystall(p, (0.3 * (-1) ** i, 0.2, 1), 1.0, 0.25, f)
    return R.ferdig_modell('Krystall', plass_x=x, maks_tris=1500)


def krystall_stor(x):
    """Stor krystallformasjon ca. 22 høy: en kjempekrystall med en ring av mindre krystaller
    rundt, på en haug av mørk stein."""
    R.ny_modell()
    biter = [((0, 0, 1.2), 4.2, (1.35, 1.2, 0.5)), ((3.8, 2.0, 0.6), 2.2, (1.2, 1, 0.6)),
             ((-3.6, 2.4, 0.6), 2.0, (1.1, 1, 0.6)), ((0.6, -4.0, 0.5), 2.2, (1.2, 1, 0.55)),
             ((-4.2, -1.8, 0.4), 1.6, (1.1, 1, 0.6))]
    for i, (c, r, sk) in enumerate(biter):
        stein(c, r, 'r_kr_stein', skala=sk, ujevn=0.14, nr=50 + i, bunn=0)
    kr = [((0.0, 0.0, 1.5), (0.06, -0.04, 1), 20.6, 2.7, 'lilla'),
          ((2.6, 1.0, 1.2), (0.45, 0.18, 1), 12.5, 1.7, 'bla'),
          ((-2.4, 1.5, 1.2), (-0.45, 0.3, 1), 14.0, 1.8, 'rosa'),
          ((0.6, -2.8, 1.2), (0.1, -0.45, 1), 11.0, 1.6, 'mork'),
          ((-2.6, -1.8, 1.0), (-0.5, -0.35, 1), 8.6, 1.3, 'bla'),
          ((3.0, -1.8, 0.9), (0.6, -0.4, 1), 7.6, 1.2, 'rosa'),
          ((0.4, 3.2, 1.0), (0.1, 0.6, 1), 8.0, 1.25, 'lilla'),
          ((5.0, 2.6, 0.4), (0.9, 0.45, 0.8), 4.6, 0.8, 'lilla'),
          ((-5.0, 2.6, 0.4), (-0.9, 0.5, 0.8), 4.0, 0.75, 'bla'),
          ((-4.8, -2.4, 0.3), (-0.9, -0.4, 0.9), 3.6, 0.7, 'rosa'),
          ((1.6, -5.0, 0.3), (0.3, -0.9, 0.8), 3.4, 0.65, 'bla')]
    for i, (b, d, L, r, f) in enumerate(kr):
        _krystall(b, d, L, r, f, fase=0.5 * i)
    return R.ferdig_modell('KrystallStor', plass_x=x, maks_tris=2500)


# ================================================================ SOPPØYA

def _sopp(pos, stilk_h, stilk_r, hatt_r, hatt_h, f_hatt, prikker, nr, vipp=(0, 0), n=16, skjort=True):
    """Sopp med stilk (litt tykkere nederst), ev. skjørt, og hatt med skiver under og prikker på.
    Hatten er én lukket dreiefigur: skiver (under) og hatt (over) i hver sin farge.
    vipp = (grader om X, grader om Y) rundt foten."""
    rng = random.Random(nr)
    start = len(R._DELER)
    dreie([(stilk_r * 1.3, 0.0), (stilk_r * 1.12, stilk_h * 0.1), (stilk_r * 0.95, stilk_h * 0.45),
           (stilk_r * 0.9, stilk_h * 0.8), (stilk_r * 1.02, stilk_h), (0.0, stilk_h + 0.01)], 'r_stilk', n=12)
    if skjort:
        zs = stilk_h * 0.72
        dreie([(stilk_r * 0.9, zs + stilk_r * 0.25), (stilk_r * 1.55, zs - stilk_r * 0.3),
               (stilk_r * 1.6, zs - stilk_r * 0.42), (stilk_r * 0.92, zs - stilk_r * 0.05)], 'r_stilk_mork',
              n=12, rundt=True)
    zc = stilk_h - hatt_h * 0.15
    profil = [(0.0, zc + hatt_h * 0.18), (stilk_r * 1.05, zc + hatt_h * 0.15)]
    for th in (-14, -4, 12, 30, 48, 66, 80, 90):
        t = math.radians(th)
        profil.append((hatt_r * math.cos(t) if th < 90 else 0.0, zc + hatt_h * math.sin(t)))
    dreie_farget(profil, ['r_skiver', 'r_skiver'] + [f_hatt] * (len(profil) - 3), n=n)
    for i in range(prikker):
        a = TAU * i / max(prikker - 1, 1) * 1.0 + rng.uniform(-0.25, 0.25)
        th = math.radians(rng.uniform(18, 60) if i else 90)
        if i == 0:
            d = Vector((0.0, 0.0, 1.0))
        else:
            d = Vector((math.cos(th) * math.cos(a), math.cos(th) * math.sin(a), math.sin(th)))
        p = Vector((hatt_r * d.x, hatt_r * d.y, zc + hatt_h * d.z))
        nrm = Vector((d.x / hatt_r, d.y / hatt_r, d.z / hatt_h)).normalized()
        rr = hatt_r * rng.uniform(0.13, 0.2) * (1.15 if i == 0 else 1.0)
        kule_m(rr, 'r_prikk', T(p) @ _mot(nrm), skala=(1.0, 1.0, 0.28), u=6, v=3)
    m = T(pos) @ _rx(vipp[0]) @ _ry(vipp[1])
    _flytt_deler(start, m)


def sopp(x):
    """Kjempesopp ca. 16 høy: tykk, lys stilk med skjørt, rød hatt med hvite prikker og
    skiver under, gresstuster og en liten sopp ved foten."""
    R.ny_modell()
    dreie([(4.6, 0.0), (3.6, 0.4), (2.0, 0.7), (0.0, 0.75)], 'r_gress', n=12)
    _sopp((0, 0, 0.3), 10.6, 1.7, 7.0, 5.3, 'r_rod', 10, nr=81)
    _sopp((3.2, 2.0, 0.4), 2.0, 0.42, 1.25, 0.9, 'r_rod', 4, nr=82, vipp=(-8, 12), n=12, skjort=False)
    _gresstust((-2.4, 2.2, 0.5), 1.4, 'r_blad', nr=83)
    _gresstust((2.6, -2.4, 0.5), 1.2, 'r_blad_lys', nr=84, antall=3)
    _gresstust((-2.8, -1.8, 0.4), 1.1, 'r_gress_mork', nr=85, antall=3)
    return R.ferdig_modell('Sopp', plass_x=x, maks_tris=2500)


def sopp_liten(x):
    """Klynge av 3 små sopper ca. 5 høy: rød, oransje og lilla med hvite prikker."""
    R.ny_modell()
    dreie([(2.8, 0.0), (2.2, 0.25), (1.2, 0.42), (0.0, 0.46)], 'r_gress', n=10)
    _sopp((0.0, -0.3, 0.2), 3.1, 0.55, 1.8, 1.45, 'r_rod', 6, nr=91, vipp=(-5, 4), n=12)
    _sopp((1.5, 0.9, 0.2), 2.2, 0.42, 1.3, 1.05, 'r_oransje', 4, nr=92, vipp=(-10, 14), n=10, skjort=False)
    _sopp((-1.4, 0.8, 0.2), 1.6, 0.34, 1.0, 0.8, 'r_kr_lilla', 4, nr=93, vipp=(-12, -15), n=10,
          skjort=False)
    _gresstust((0.9, -1.5, 0.3), 0.9, 'r_blad', nr=94, antall=3)
    return R.ferdig_modell('SoppLiten', plass_x=x, maks_tris=1500)


# ================================================================ SNØØYA

def furu(x):
    """Snødekt grantre ca. 20 høyt: fem lag med taggete grønne kjegler, hvert med en snøkappe
    med dryppkant, kort stamme og en snøhaug ved foten."""
    R.ny_modell()
    rng = random.Random(10)
    dreie([(4.8, 0.0), (4.0, 0.35), (2.0, 0.65), (0.0, 0.75)], 'r_sno_skygge', n=12)
    R.sylinder((0, 0, 0), (0, 0, 4.0), 0.95, 'r_bark', r2=0.75, n=8)
    lag = [(2.4, 6.8, 6.0), (6.0, 5.7, 5.4), (9.2, 4.6, 5.0), (12.2, 3.5, 4.6), (15.0, 2.4, 4.6)]
    n = 16
    for i, (z0, Rr, h) in enumerate(lag):
        fase = i * 0.37
        ytre, indre = [], []
        for j in range(n):
            a = TAU * j / n + fase
            tagg = j % 2 == 0
            r = Rr if tagg else Rr * 0.8
            z = z0 - (0.4 if tagg else 0.0)
            ytre.append((r * math.cos(a), r * math.sin(a), z))
            indre.append((Rr * 0.45 * math.cos(a), Rr * 0.45 * math.sin(a), z0 + 0.9))
        loft([indre, ytre, [(0.0, 0.0, z0 + h)]], 'r_gran' if i % 2 == 0 else 'r_gran_lys', flat=True)

        def rg(z):
            return Rr * (1 - (z - z0) / h)

        ze = z0 + 0.42 * h
        kant, inn = [], []
        for j in range(n):
            a = TAU * j / n + fase
            drypp = j % 2 == 0
            zz = ze - (0.6 if drypp else 0.0) - rng.uniform(0.0, 0.2)
            r = rg(zz) * (1.0 if drypp else 0.9) + 0.25
            kant.append((r * math.cos(a), r * math.sin(a), zz))
            inn.append((rg(ze) * 0.55 * math.cos(a), rg(ze) * 0.55 * math.sin(a), ze + 0.5))
        loft([inn, kant, [(0.0, 0.0, z0 + h + 0.25)]], 'r_sno', flat=True)
    R.kule((0, 0, 19.75), 0.45, 'r_sno', u=8, v=5)
    return R.ferdig_modell('Furu', plass_x=x, maks_tris=2500)


def _paa_kule(c, r, d):
    return Vector(c) + Vector(d).normalized() * r


def snomann(x):
    """Snømann ca. 7 høy: tre snøballer, kulløyne og smil, gulrotnese, knapper, rødt skjerf
    med frynser, flosshatt med rødt bånd og kristtorn, pinnearmer (den ene vinker).
    Ansiktet vender mot +Y."""
    R.ny_modell()
    dreie([(3.0, 0.0), (2.4, 0.25), (1.2, 0.45), (0.0, 0.5)], 'r_sno_skygge', n=12)
    R.kule((0, 0, 1.6), 1.75, 'r_sno', u=14, v=9)
    mc, mr = (0, 0, 3.85), 1.28
    R.kule(mc, mr, 'r_sno', u=14, v=9)
    hc, hr = (0, 0, 5.55), 0.95
    R.kule(hc, hr, 'r_sno', u=12, v=8)
    for sx in (-1, 1):
        R.kule(_paa_kule(hc, hr, (sx * 0.36, 0.86, 0.3)), 0.13, 'r_svart', u=6, v=4)
        R.kule(_paa_kule(hc, hr * 0.98, (sx * 0.62, 0.75, -0.08)), 0.17, 'r_rosa', skala=(1, 0.5, 0.8), u=6, v=4)
    for u in (-0.42, -0.21, 0.0, 0.21, 0.42):
        R.kule(_paa_kule(hc, hr, (u, 1.0, -0.5 + 0.55 * u * u)), 0.075, 'r_svart', u=4, v=3)
    nd = Vector((0.04, 1.0, -0.06)).normalized()
    p = _paa_kule(hc, hr, (0, 1, 0.02))
    R.sylinder(p - nd * 0.2, p + nd * 1.35, 0.2, 'r_gulrot', r2=0.03, n=8)
    for z in (0.45, 0.1, -0.25):
        R.kule(_paa_kule(mc, mr, (0, 1, z)), 0.15, 'r_svart', skala=(1, 0.6, 1), u=6, v=4)
    R.kule(_paa_kule((0, 0, 1.6), 1.75, (0, 1, 0.35)), 0.17, 'r_svart', skala=(1, 0.6, 1), u=6, v=4)
    # skjerf
    R.ring((0, 0, 4.92), 0.84, 0.3, 'r_rod', n1=16, n2=6)
    for i, (dz, rx) in enumerate(((0.0, 0.0), (-0.55, 6.0))):
        cz = 4.45 + dz
        R.kasse((0.55, 0.92 + 0.08 * i, cz), (0.58, 0.2, 0.62), 'r_rod', rot=(rx + 10, 0, -15), fas=0.05)
        R.kasse((0.55, 0.95 + 0.08 * i, cz + 0.12), (0.6, 0.2, 0.14), 'r_hvit', rot=(rx + 10, 0, -15))
    for k in range(3):
        R.kasse((0.38 + k * 0.17, 1.05, 3.85 - 0.05 * k), (0.08, 0.1, 0.25), 'r_rod', rot=(12, 0, -15))
    # pinnearmer
    for s, sti in ((1, [(1.05, 0.0, 4.0), (1.9, 0.1, 4.55), (2.75, 0.15, 5.4)]),
                   (-1, [(-1.05, 0.0, 4.0), (-1.95, 0.1, 4.25), (-2.85, 0.2, 4.2)])):
        ror(sti, [0.11, 0.09, 0.06], 'r_bark', n=5)
        a = Vector(sti[-1])
        b = Vector(sti[-2])
        d = (a - b).normalized()
        for v in (-35, 35):
            q = Matrix.Rotation(math.radians(v), 3, (0, 1, 0))
            R.sylinder(a - d * 0.1, a + (q @ d) * 0.55, 0.045, 'r_bark', n=4)
    # flosshatt (vippet)
    start = len(R._DELER)
    zh = hc[2] + hr * 0.8
    R.sylinder((0, 0, zh), (0, 0, zh + 0.14), 1.0, 'r_svart', n=14)
    R.sylinder((0, 0, zh + 0.1), (0, 0, zh + 1.15), 0.66, 'r_svart', r2=0.7, n=14)
    R.sylinder((0, 0, zh + 0.12), (0, 0, zh + 0.4), 0.69, 'r_rod', n=14)
    for v in (-30, 30):
        kule_m(0.2, 'r_blad_mork', T((0.68, 0.18, zh + 0.36)) @ _rz(v + 80) @ T((0.15, 0, 0)),
               skala=(1.4, 0.6, 0.25), u=6, v=4)
    R.kule((0.72, 0.32, zh + 0.32), 0.09, 'r_rod', u=4, v=3)
    R.kule((0.72, 0.18, zh + 0.45), 0.09, 'r_rod', u=4, v=3)
    _flytt_deler(start, T((0, 0, zh)) @ _rx(-6) @ _ry(10) @ T((0, 0, -zh)))
    return R.ferdig_modell('Snomann', plass_x=x, maks_tris=2000)


# ================================================================ ØRKENØYA

def _kaktus_profil(n=16, dyp=0.84):
    return [((1.0 if j % 2 == 0 else dyp) * math.cos(TAU * j / n),
             (1.0 if j % 2 == 0 else dyp) * math.sin(TAU * j / n)) for j in range(n)]


def kaktus(x):
    """Saguaro-kaktus ca. 10 høy med riller, to armer, hvite torner og rosa blomster,
    i en sandhaug med småstein."""
    R.ny_modell()
    dreie([(2.6, 0.0), (2.1, 0.3), (1.2, 0.5), (0.0, 0.55)], 'r_sand', n=12)
    stein((1.9, 1.2, 0.2), 0.45, 'r_sandstein', nr=101, bunn=0)
    stein((-1.7, -1.4, 0.2), 0.35, 'r_sandstein_mork', nr=102, bunn=0)
    prof = _kaktus_profil()
    stamme = [(0, 0, -0.1), (0, 0, 3.0), (0, 0, 6.5), (0, 0, 8.6), (0, 0, 9.3), (0, 0, 9.75), (0, 0, 9.97)]
    rs = [1.3, 1.22, 1.18, 1.12, 0.95, 0.6, 0.18]
    ror(stamme, rs, 'r_kaktus', profil=prof)
    armer = [([(0.6, 0, 3.4), (1.8, 0, 3.5), (2.6, 0, 4.0), (2.9, 0, 4.9), (2.95, 0, 6.4), (2.95, 0, 6.95),
               (2.95, 0, 7.22)], [0.72, 0.72, 0.7, 0.66, 0.62, 0.45, 0.14]),
             ([(-0.6, 0, 5.0), (-1.6, 0.2, 5.1), (-2.3, 0.3, 5.6), (-2.5, 0.35, 6.4), (-2.55, 0.35, 7.6),
               (-2.55, 0.35, 8.05), (-2.55, 0.35, 8.28)], [0.62, 0.62, 0.6, 0.57, 0.53, 0.38, 0.12])]
    for sti, r in armer:
        ror(sti, r, 'r_kaktus', profil=prof)
    # torner langs ribbene på stammen
    for k, z in enumerate((1.2, 2.6, 4.1, 5.6, 7.1, 8.4)):
        rz = 1.22 if z < 6.5 else 1.14
        for j in range(8):
            if (j + k) % 2:
                continue
            a = TAU * j / 8
            d = Vector((math.cos(a), math.sin(a), 0.0))
            p = Vector((0, 0, z)) + d * (rz - 0.05)
            _torn(p, d + Vector((0, 0, 0.35)), 0.38, 0.06, 'r_torn')
    # mørkere striper i rillene gir dybde: smale stenger langs fire av rillene foran
    for j in (1, 3, 13, 15):
        a = TAU * j / 16 + math.pi / 2
        c, s = math.cos(a), math.sin(a)
        R.sylinder((c * 1.12, s * 1.12, 0.4), (c * 1.04, s * 1.04, 8.6), 0.07, 'r_kaktus_mork', n=4)
    _blomst((0, 0, 9.95), (0, 0, 1), 0.9, 'r_rosa')
    _blomst((2.95, 0, 7.2), (0.2, 0, 1), 0.65, 'r_rosa')
    _blomst((-2.55, 0.35, 8.25), (-0.2, 0.1, 1), 0.55, 'r_gul', f_midt='r_oransje')
    return R.ferdig_modell('Kaktus', plass_x=x, maks_tris=1500)


def pyramide(x):
    """Liten trappepyramide ca. 24 bred og 14 høy: fire avtrappede lag i sandstein med lys
    gesims, trapp med rekkverk og turkise slangehoder foran (+Y), turkis/gull-dekor og et
    tempel på toppen med mørk inngang i gullramme."""
    R.ny_modell()
    lag = [(24.0, 0.0), (19.5, 2.4), (15.0, 4.8), (10.5, 7.2)]
    hl = 2.4
    for i, (w, z0) in enumerate(lag):
        R.kasse((0, 0, z0 + hl / 2), (w, w, hl), 'r_sandstein', fas=0.2, segm=1)
        R.kasse((0, 0, z0 + hl - 0.2), (w + 0.4, w + 0.4, 0.4), 'r_sandstein_lys', fas=0.1, segm=1)
        # dekorplater på framsiden, på hver side av trappa
        for s in (-1, 1):
            px = s * (w / 4 + 1.6)
            R.kasse((px, w / 2 + 0.02, z0 + 1.0), (min(3.4, w / 2 - 3.6), 0.3, 1.1), 'r_turkis')
            R.kasse((px, w / 2 + 0.12, z0 + 1.0), (0.6, 0.2, 0.6), 'r_gull')
            R.kasse((s * w / 2 + s * 0.02, 0, z0 + 1.0), (0.3, w * 0.45, 1.1), 'r_turkis')
    ztopp = lag[-1][1] + hl
    # trapp
    trinn = 12
    y0, y1 = 12.6, 5.25
    for k in range(trinn):
        yf = y0 - k * (y0 - y1) / trinn
        zt = (k + 1) * ztopp / trinn
        R.kasse((0, (4.0 + yf) / 2, zt / 2), (5.0, yf - 4.0, zt),
                'r_sandstein_lys' if k % 2 == 0 else 'r_sandstein')
    retning = Vector((0, -(y0 + 0.4 - y1), ztopp + 0.4))
    for s in (-1, 1):
        mc = T((s * 2.95, (y0 + 0.4 + y1) / 2, (ztopp + 0.4) / 2 + 0.25))
        kasse_m((0.9, 0.9, retning.length), 'r_sandstein_mork', mc @ _mot(retning), fas=0.1)
        R.kasse((s * 2.95, y0 + 0.75, 0.65), (1.4, 1.8, 1.3), 'r_turkis', fas=0.15)
        R.kasse((s * 2.95, y0 + 1.68, 0.5), (1.0, 0.2, 0.35), 'r_gull')
        R.kule((s * 2.95 + s * 0.45, y0 + 1.25, 1.05), 0.2, 'r_gull', u=6, v=4)
    # tempel med inngang
    zt0 = ztopp
    R.kasse((0, 0, zt0 + 1.9), (8.4, 7.0, 3.8), 'r_sandstein_lys', fas=0.15)
    R.kasse((0, 0, zt0 + 3.55), (8.7, 7.3, 0.5), 'r_turkis')
    R.kasse((0, 0, zt0 + 4.05), (9.2, 7.8, 0.55), 'r_sandstein_mork', fas=0.12)
    R.kasse((0, 0, zt0 + 4.5), (5.4, 3.8, 0.45), 'r_sandstein', fas=0.1)
    R.kasse((0, 3.45, zt0 + 1.5), (3.2, 0.3, 3.0), 'r_svart')
    for s in (-1, 1):
        R.kasse((s * 1.85, 3.58, zt0 + 1.5), (0.5, 0.4, 3.0), 'r_gull')
        R.kasse((s * 3.1, 3.55, zt0 + 1.6), (0.9, 0.2, 0.9), 'r_turkis')
    R.kasse((0, 3.6, zt0 + 3.15), (4.3, 0.5, 0.55), 'r_gull', fas=0.05)
    return R.ferdig_modell('Pyramide', plass_x=x, maks_tris=2000)


# ================================================================ RUINØYA

def _riflet(r, z, n=24, dyp=0.88, dz=None):
    return [((r if j % 2 == 0 else r * dyp) * math.cos(TAU * j / n),
             (r if j % 2 == 0 else r * dyp) * math.sin(TAU * j / n),
             z + (dz[j] if dz else 0.0)) for j in range(n)]


def soyle(x):
    """Gresk søyle ca. 16 høy: sokkel i to trinn, profilert fot, riflet skaft med svak
    avsmalning og skrått avbrukket topp, mose og eføy, og en nedfalt skaftbit med
    steinbiter ved foten."""
    R.ny_modell()
    rng = random.Random(14)
    R.kasse((0, 0, 0.4), (4.8, 4.8, 0.8), 'r_marmor_skygge', fas=0.15, segm=1)
    R.kasse((0, 0, 1.1), (4.0, 4.0, 0.6), 'r_marmor', fas=0.12, segm=1)
    dreie([(1.95, 1.4), (2.05, 1.62), (1.82, 1.95), (1.62, 2.1)], 'r_marmor', n=16)
    n = 24
    brudd = [1.3 * math.cos(TAU * j / n - 0.9) + rng.uniform(-0.45, 0.45) for j in range(n)]
    ringer = [_riflet(1.62, 2.0), _riflet(1.6, 6.0), _riflet(1.53, 10.0), _riflet(1.47, 13.0),
              _riflet(1.45, 14.3, dz=brudd), [(0.15, 0.1, 14.2)]]
    loft(ringer, 'r_marmor', flat=True)
    # mose på bruddet og nedover
    for p, nrm, r in (((1.1, 0.75, 14.9), (0.3, 0.2, 1.0), 0.6), ((0.9, 1.2, 13.2), (0.6, 0.8, 0.1), 0.5),
                      ((-1.3, 0.9, 2.3), (-0.7, 0.5, 0.4), 0.5), ((1.7, 1.75, 1.45), (0.4, 0.4, 1.0), 0.6),
                      ((-2.2, 1.6, 0.85), (-0.5, 0.5, 0.6), 0.55), ((0.6, -1.5, 6.2), (0.3, -1.0, 0.0), 0.42)):
        _moseflekk(p, nrm, r)
    # eføy i spiral oppover skaftet
    sti = []
    for i in range(14):
        t = i / 13
        a = -0.6 + t * 4.6
        rr = 1.68 - 0.18 * t
        sti.append((rr * math.cos(a), rr * math.sin(a), 1.9 + t * 8.5))
    ror(sti, 0.07, 'r_gress_mork', n=4)
    for i in range(1, 14, 2):
        p = Vector(sti[i])
        utover = Vector((p.x, p.y, 0.0)).normalized()
        kule_m(0.28, 'r_blad' if i % 4 == 1 else 'r_blad_lys',
               T(p + utover * 0.12) @ _mot(utover + Vector((0, 0, 0.3))), skala=(1.0, 0.8, 0.22), u=6, v=4)
    # nedfalt skaftbit og steinbiter
    mfall = T((3.6, 1.9, 1.25)) @ _rz(-30) @ _ry(90)
    loft([_riflet(1.25, -0.9), _riflet(1.25, 0.9)], 'r_marmor_skygge', m=mfall, flat=True)
    stein((-3.0, -1.6, 0.3), 0.55, 'r_marmor_skygge', nr=141, bunn=0)
    stein((2.3, -2.9, 0.25), 0.45, 'r_marmor', nr=142, bunn=0)
    _gresstust((-2.6, 2.6, 0.0), 1.0, 'r_blad', nr=143, antall=3)
    return R.ferdig_modell('Soyle', plass_x=x, maks_tris=1500)


def ruinbue(x):
    """Steinbue/portal ca. 18 bred og 16 høy: to pilarer av stablede, litt skjeve steinblokker,
    halvsirkelbue av kilesteiner med fremstående sluttstein (én kilestein har sklidd litt),
    mose på toppen, hengende ranker og steinbiter ved foten. Åpningen er ca. 11 bred, 12.6 høy."""
    R.ny_modell()
    rng = random.Random(15)
    farger_ = ('r_ruinstein', 'r_ruinstein_mork', 'r_ruinstein_lys')
    zb = 7.0
    for s in (-1, 1):
        cx = s * 7.3
        R.kasse((cx, 0, 0.5), (4.3, 3.9, 1.0), 'r_ruinstein_mork', fas=0.2, segm=1)
        for i in range(4):
            jit = (rng.uniform(-0.15, 0.15), rng.uniform(-0.15, 0.15))
            R.kasse((cx + jit[0], jit[1], 1.0 + 0.75 + i * 1.5), (3.4, 3.0, 1.42), farger_[(i + (s > 0)) % 3],
                    rot=(0, 0, rng.uniform(-4, 4)), fas=0.2, segm=1)
        R.kasse((cx, 0, zb - 0.25), (3.9, 3.4, 0.5), 'r_ruinstein_lys', fas=0.12, segm=1)
    ri, ry = 5.6, 9.0
    biter = 9
    glipe = math.radians(0.9)
    for i in range(biter):
        a0 = math.pi * i / biter + glipe
        a1 = math.pi * (i + 1) / biter - glipe
        am = (a0 + a1) / 2
        slutt = i == biter // 2
        ro = ry + (0.5 if slutt else 0.0)
        pts = [(ri * math.cos(a), zb + ri * math.sin(a)) for a in (a0, am, a1)]
        pts += [(ro * math.cos(a), zb + ro * math.sin(a)) for a in (a1, am, a0)]
        if slutt:
            pts = [(ri * 0.97 * math.cos(a), zb + ri * 0.97 * math.sin(a)) for a in (a0 - 0.02, am, a1 + 0.02)]
            pts += [(ro * math.cos(a), zb + ro * math.sin(a)) for a in (a1 + 0.03, am, a0 - 0.03)]
        m = None
        if i == 6:      # kilesteinen som har sklidd
            c = Vector((7.3 * math.cos(am), 0, zb + 7.3 * math.sin(am)))
            m = T(c + Vector((0, 0, -0.25))) @ _ry(-5) @ T(-c)
        plate_m(pts, 3.5 if slutt else 3.0, 'r_ruinstein_lys' if slutt else farger_[i % 2], m=m, fas=0.15, segm=1)
    # mose på toppen av buen og pilarene
    for a in (60, 82, 100, 125):
        t = math.radians(a)
        p = Vector((9.0 * math.cos(t), 0.0, zb + 9.0 * math.sin(t)))
        _moseflekk(p, (math.cos(t), 0, math.sin(t)), 1.2, 'r_mose' if a % 20 else 'r_gress',
                   skala=(1.3, 1.25, 0.3))
    _gresstust((-0.3, 0.2, zb + 9.6), 1.3, 'r_blad', nr=151)
    _gresstust((-6.0, 0.4, zb + 6.1), 1.1, 'r_blad_lys', nr=152, antall=3)
    _moseflekk((7.3, 0.4, zb + 0.1), (0, 0, 1), 1.0)
    # ranker som henger ned fra buen
    for k, (a, lengde) in enumerate(((58, 4.2), (96, 3.0), (128, 5.2))):
        t = math.radians(a)
        x0, z0 = ri * math.cos(t), zb + ri * math.sin(t)
        sti = [(x0 + 0.3 * math.sin(i * 1.3 + k), 1.1 - 0.15 * i, z0 + 0.1 - lengde * i / 5) for i in range(6)]
        ror(sti, 0.08, 'r_gress_mork', n=4)
        for i in (1, 3, 5):
            kule_m(0.3, 'r_blad' if i % 4 == 1 else 'r_blad_lys', T(Vector(sti[i]) + Vector((0, 0.15, 0)))
                   @ _rx(70) @ _rz(40 * i), skala=(1.0, 0.75, 0.22), u=6, v=4)
    # steinbiter
    stein((-10.2, 1.8, 0.45), 0.8, 'r_ruinstein', nr=153, bunn=0)
    stein((10.0, -1.6, 0.4), 0.7, 'r_ruinstein_mork', nr=154, bunn=0)
    R.kasse((4.2, 2.6, 0.6), (1.5, 1.3, 1.2), 'r_ruinstein', rot=(8, -6, 25), fas=0.15)
    return R.ferdig_modell('Ruinbue', plass_x=x, maks_tris=2500)


def steinhode(x):
    """Stort steinhode i Påskeøya-stil ca. 12 høyt, delvis begravd i en gresshaug: langt hode med
    tung panne, lang nese, sammenknepne lepper, lange ører, hender over magen, store tegneserieøyne
    og mose på toppen. Ansiktet vender mot +Y."""
    R.ny_modell()
    dreie([(6.2, 0.0), (5.4, 0.7), (4.6, 1.1), (0.0, 1.25)], 'r_gress', n=12)
    stasjoner = [(0.0, 4.3, 3.1, 0.0), (2.4, 4.2, 3.0, 0.0), (3.3, 3.5, 2.8, 0.15), (3.9, 3.05, 2.7, 0.3),
                 (6.5, 2.95, 2.6, 0.35), (9.6, 2.9, 2.5, 0.25), (11.2, 2.75, 2.3, 0.05), (11.9, 2.2, 1.8, -0.05)]
    ringer = [[(ex, ey + yo, z) for ex, ey in _superellipse(hx, hy, 16, 3.2)] for z, hx, hy, yo in stasjoner]
    loft(ringer, 'r_moai', flat=True)
    # panne, øyehuler og øyne
    R.kasse((0, 2.95, 9.3), (5.2, 1.3, 1.05), 'r_moai', fas=0.3, segm=1)
    for sx in (-1, 1):
        R.kasse((sx * 1.2, 2.95, 8.3), (1.65, 0.6, 1.0), 'r_moai_mork')
        R.kule((sx * 1.2, 3.2, 8.3), 0.5, 'r_hvit', skala=(1.15, 0.4, 0.85), u=8, v=6)
        R.kule((sx * 1.05, 3.38, 8.25), 0.24, 'r_svart', skala=(1, 0.4, 1.1), u=6, v=4)
    # nese
    R.plate([(2.9, 8.85), (3.6, 8.85), (4.65, 6.0), (4.25, 5.55), (2.9, 5.55)], 1.5, 'r_moai', plan='YZ', fas=0.2)
    for sx in (-1, 1):
        R.kule((sx * 0.72, 3.95, 5.85), 0.45, 'r_moai', skala=(1.0, 1.1, 0.8), u=8, v=6)
    # munn og hake
    R.kasse((0, 3.3, 5.0), (2.5, 0.9, 0.42), 'r_moai_mork', fas=0.15, segm=1)
    R.kasse((0, 3.25, 4.5), (2.1, 0.8, 0.42), 'r_moai', fas=0.15, segm=1)
    R.kasse((0, 2.95, 3.75), (3.5, 1.1, 0.95), 'r_moai', fas=0.3, segm=1)
    # ører
    for sx in (-1, 1):
        R.kasse((sx * 3.0, 0.4, 7.0), (0.75, 1.35, 3.9), 'r_moai', fas=0.3, segm=1)
        R.kasse((sx * 3.33, 0.5, 7.0), (0.2, 0.7, 2.8), 'r_moai_mork')
    # armer og hender over magen
    for sx in (-1, 1):
        R.kasse((sx * 3.85, 1.6, 2.4), (0.6, 2.4, 0.7), 'r_moai_mork', rot=(0, 0, sx * 25))
        R.kasse((sx * 1.9, 3.05, 2.05), (2.6, 0.35, 0.6), 'r_moai_mork', rot=(0, sx * 8, 0))
        for k in range(3):
            R.kasse((sx * (0.45 + 0.32 * k), 3.12, 2.0 - 0.05 * k), (0.2, 0.3, 0.75), 'r_moai_mork')
    # mose og lav
    for p, nrm, r in (((0.4, -0.2, 11.95), (0, 0, 1), 1.2), ((-1.4, 0.6, 11.7), (-0.3, 0.1, 1), 0.8),
                      ((2.6, -1.4, 10.4), (0.8, -0.4, 0.3), 0.6), ((-2.7, 1.4, 4.2), (-0.8, 0.5, 0.0), 0.5)):
        _moseflekk(p, nrm, r)
    _gresstust((3.4, 3.4, 1.0), 1.2, 'r_blad', nr=161)
    _gresstust((-4.0, 2.6, 0.9), 1.0, 'r_blad_lys', nr=162, antall=3)
    stein((-4.6, 3.6, 0.7), 0.6, 'r_stein', nr=163)
    return R.ferdig_modell('Steinhode', plass_x=x, maks_tris=2000)


# ================================================================ JUNGELØYA

def bambus(x):
    """Klynge med seks grønne bambusstenger ca. 14 høy, med mørke ledd og smale blader i
    toppene og ved de øverste leddene, i en liten jordhaug."""
    R.ny_modell()
    rng = random.Random(17)
    dreie([(3.0, 0.0), (2.5, 0.3), (1.1, 0.55), (0.0, 0.6)], 'r_jord', n=10)
    staver_ = [((0.0, 0.0), 14.0, (0.03, 0.0)), ((1.3, 0.6), 12.4, (0.1, 0.05)),
               ((-1.1, 0.9), 11.2, (-0.1, 0.07)), ((0.5, -1.3), 13.0, (0.04, -0.1)),
               ((-1.4, -0.8), 9.4, (-0.12, -0.07)), ((1.8, -0.7), 8.0, (0.14, -0.05))]
    blad_f = ('r_blad', 'r_blad_lys', 'r_blad_mork')
    for i, ((bx, by), h, (tx, ty)) in enumerate(staver_):
        base = Vector((bx, by, 0.0))
        topp = Vector((bx + tx * h, by + ty * h, h))
        d = (topp - base).normalized()
        r = 0.42 - 0.04 * (i % 3)
        R.sylinder(base, topp, r, 'r_bambus', r2=r * 0.8, n=6)
        k = 1
        while k * 2.3 < h - 0.6:
            t = k * 2.3 / h
            p = base.lerp(topp, t)
            R.sylinder(p - d * 0.12, p + d * 0.12, r * 1.18 * (1 - 0.2 * t), 'r_bambus_mork', n=6)
            k += 1
        for j in range(4 if h > 10 else 3):
            a = TAU * j / 4 + rng.uniform(-0.5, 0.5) + i
            start = base.lerp(topp, rng.uniform(0.7, 0.98))
            R.blad(start, (math.cos(a), math.sin(a), rng.uniform(0.15, 0.6)), rng.uniform(2.2, 3.0), 0.75,
                   blad_f[(i + j) % 3], heng=0.35, fold=0.2, tykk=0.06, segm=3)
    _gresstust((2.0, 1.6, 0.2), 1.0, 'r_blad_lys', nr=171, antall=3)
    return R.ferdig_modell('Bambus', plass_x=x, maks_tris=2000)


def bregne(x):
    """Stor tropisk bregne ca. 5 høy: en rosett av taggete, buede blader (ytre krans som henger
    utover, indre som står opp) og to sammenrullede unge skudd, i en liten jordhaug."""
    R.ny_modell()
    rng = random.Random(18)
    dreie([(1.6, 0.0), (1.3, 0.3), (0.6, 0.55), (0.0, 0.6)], 'r_jord', n=8)
    f = ('r_blad', 'r_blad_mork', 'r_blad_lys')
    for k in range(7):
        a = TAU * k / 7 + rng.uniform(-0.15, 0.15)
        d = (math.cos(a), math.sin(a), 1.25)
        R.blad((math.cos(a) * 0.3, math.sin(a) * 0.3, 0.5), d, rng.uniform(4.6, 5.2), 1.6, f[k % 3],
               heng=0.5, fold=0.25, tykk=0.08, segm=8, tagget=True, vri=rng.uniform(-10, 10))
    for k in range(4):
        a = TAU * (k + 0.5) / 4 + 0.3
        d = (math.cos(a) * 0.4, math.sin(a) * 0.4, 1.0)
        R.blad((0, 0, 0.5), d, 5.4, 1.3, ('r_blad_lys', 'r_blad')[k % 2], heng=0.22, fold=0.25, tykk=0.08,
               segm=8, tagget=True)
    for (px, py, a) in ((0.25, 0.2, 0.4), (-0.25, -0.15, 3.5)):
        topp = Vector((px * 3, py * 3, 4.1 + 0.4 * (px > 0)))
        R.sylinder((px, py, 0.5), topp, 0.09, 'r_blad_lys', n=4)
        akse = (math.cos(a + math.pi / 2), math.sin(a + math.pi / 2), 0)
        c = topp + Vector((math.cos(a) * 0.35, math.sin(a) * 0.35, 0.0))
        R.ring(c, 0.35, 0.11, 'r_blad_lys', akse=akse, n1=10, n2=4, fra=0, til=300)
    return R.ferdig_modell('Bregne', plass_x=x, maks_tris=1500)


# ================================================================ LAVAØYA

def _splittet_stein(bm0, kutt, glipe, f, flat=True):
    """Del en stein (bmesh) i biter med plan gjennom den, og flytt bitene litt fra hverandre så
    glødende lava inni synes i sprekkene. kutt = [(punkt, normal, løft)], løft = flytt opp i
    stedet for til siden (vannrett kutt). Lager én del per bit."""
    import itertools
    for fortegn in itertools.product((-1, 1), repeat=len(kutt)):
        bm = bm0.copy()
        flytt = Vector((0, 0, 0))
        for (co, no, loft_), sg in zip(kutt, fortegn):
            no = Vector(no).normalized() * sg
            bmesh.ops.bisect_plane(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:], plane_co=Vector(co),
                                   plane_no=no, clear_inner=True)
            kant = [e for e in bm.edges if e.is_boundary]
            if kant:
                bmesh.ops.holes_fill(bm, edges=kant, sides=len(kant))
            if loft_:
                flytt += Vector((0, 0, glipe * 1.3 if sg > 0 else 0))
            else:
                flytt += Vector((no.x, no.y, 0)) * glipe
        if len(bm.faces) < 4:
            bm.free()
            continue
        bmesh.ops.translate(bm, verts=bm.verts, vec=flytt)
        _del(bm, f, flat=flat)
    bm0.free()


def vulkanstein(x):
    """Svart basaltstein ca. 6 høy med glødende oransje sprekker: steinen er kuttet i åtte biter
    som er dyttet litt fra hverandre rundt en lavakjerne, pluss glødende småbiter ved foten."""
    R.ny_modell()
    bm = _stein_bm((0, 0, 2.5), 3.0, (1.2, 1.0, 0.9), (0, 0, 20), 2, 0.18, 191, 0.0)
    kutt = [((0.2, 0.0, 0.0), (math.cos(0.35), math.sin(0.35), 0.0), False),
            ((0.0, -0.1, 0.0), (math.cos(2.0), math.sin(2.0), 0.0), False),
            ((0.0, 0.0, 3.1), (0.15, -0.1, 1.0), True)]
    _splittet_stein(bm, kutt, 0.42, 'r_basalt')
    stein((0, 0, 2.6), 2.9, 'r_lava', skala=(1.15, 1.0, 0.92), ujevn=0.08, nr=192, bunn=0.0)
    for i, (p, r, f) in enumerate((((3.6, 1.6, 0.3), 0.55, 'r_basalt_mork'), ((-3.4, -1.2, 0.3), 0.6, 'r_basalt'),
                                   ((2.0, -3.0, 0.2), 0.4, 'r_lava'), ((-2.4, 2.6, 0.2), 0.35, 'r_lava_gul'),
                                   ((1.0, 3.3, 0.2), 0.45, 'r_basalt_mork'))):
        stein(p, r, f, nr=194 + i, bunn=0.0, deling=1)
    return R.ferdig_modell('Vulkanstein', plass_x=x, maks_tris=1000)


# ================================================================ FELLES

def _smalt_vindu(m, h=2.0, b=0.9):
    """Smalt buevindu (skyteskår) i lokalt XZ-plan med forsiden mot +Y, flyttet med m."""
    kasse_m((b + 0.6, 0.3, h + 0.5), 'r_stein_mork', m @ T((0, 0.0, 0.05)))
    kasse_m((b, 0.4, h), 'r_vindu_mork', m @ T((0, 0.1, 0)))
    bm_m = m @ T((0, 0.1, h / 2)) @ _rx(90)
    R.sylinder(bm_m @ Vector((0, 0, -0.2)), bm_m @ Vector((0, 0, 0.2)), b / 2, 'r_vindu_mork', n=6)
    kasse_m((b + 0.9, 0.5, 0.3), 'r_stein_lys', m @ T((0, 0.15, -h / 2 - 0.15)))


def taarn(x):
    """Høyt, smalt steintårn ca. 70 høyt og 14 bredt: sokkel med portal og dør (mot +Y),
    skaft med bånd og utstikkende steiner, tre balkonger med rekkverk og buet døråpning,
    skyteskår, krone og et spisst blått tak med ribber, gullkule og vaiende flagg."""
    R.ny_modell()
    rng = random.Random(20)
    n = 16
    dreie([(6.4, 0.0), (6.4, 1.2), (5.9, 1.5), (5.2, 1.5)], 'r_stein_mork', n=n, flat=True)
    dreie([(5.4, 1.5), (5.0, 3.0), (4.8, 4.0)], 'r_stein', n=n, flat=True)
    za, zt = 4.0, 59.0
    ra, rb = 4.8, 4.3

    def rt(z):
        return ra + (rb - ra) * (z - za) / (zt - za)

    dreie([(ra, za), (rb, zt)], 'r_stein_lys', n=n, flat=True)
    balkonger = (18.0, 36.0, 54.0)
    for z in (10.0, 27.0, 45.0):
        dreie([(rt(z) + 0.18, z - 0.35), (rt(z) + 0.18, z + 0.35)], 'r_stein', n=n, flat=True)
    # utstikkende steiner for tekstur
    for i in range(24):
        z = rng.uniform(5.0, 58.0)
        if any(abs(z - b) < 2.6 for b in balkonger):
            continue
        a = rng.uniform(0, 360)
        rr = rt(z)
        R.kasse((rr * math.cos(math.radians(a)), rr * math.sin(math.radians(a)), z),
                (0.5, rng.uniform(1.0, 1.8), rng.uniform(0.6, 0.9)), ('r_stein', 'r_stein_mork')[i % 2],
                rot=(0, 0, a))
    # portal og dør
    R.kasse((0, 4.5, 3.4), (4.6, 1.8, 6.0), 'r_stein', fas=0.2)
    R.kasse((0, 5.45, 3.6), (2.8, 0.2, 3.9), 'r_tre')
    R.sylinder((0, 5.35, 5.55), (0, 5.55, 5.55), 1.4, 'r_tre', n=12)
    R.bue((0, 5.5, 5.55), 1.6, 0.25, 'r_stein_mork', akse=(0, 1, 0), fra=0, til=180, n1=10, n2=4)
    for s in (-1, 1):
        R.kasse((s * 1.6, 5.5, 3.6), (0.45, 0.4, 3.9), 'r_stein_mork')
    R.kasse((0, 5.62, 3.8), (2.4, 0.08, 0.25), 'r_jern')
    R.kasse((0, 5.62, 2.2), (2.4, 0.08, 0.25), 'r_jern')
    R.kule((0.8, 5.65, 3.2), 0.18, 'r_gull', u=6, v=4)
    R.kasse((0, 6.2, 0.75), (4.0, 1.6, 1.5), 'r_stein_lys', fas=0.15)
    # skyteskår
    for z, a0 in ((10.0 + 3.5, 45), (27.0 + 3.5, 0), (45.0 + 3.5, 45), (58.0 - 1.5, 0)):
        for k in range(4):
            a = a0 + 90 * k + (0 if z > 56 else 0)
            m = _rz(a) @ T((0, rt(z) - 0.1, z))
            _smalt_vindu(m)
    # balkonger
    for bi, zb in enumerate(balkonger):
        dreie([(rt(zb - 2.4) + 0.05, zb - 2.4), (6.3, zb - 0.6), (6.3, zb - 0.4)], 'r_stein', n=n, flat=True)
        dreie([(7.0, zb - 0.55), (7.0, zb + 0.3)], 'r_tre', n=n, fas=0.12, flat=True)
        for k in range(12):
            a = TAU * (k + 0.5) / 12
            c, s = math.cos(a), math.sin(a)
            R.sylinder((6.6 * c, 6.6 * s, zb + 0.3), (6.6 * c, 6.6 * s, zb + 1.9), 0.13, 'r_tre_mork', n=4)
        R.ring((0, 0, zb + 1.9), 6.6, 0.18, 'r_rod', n1=24, n2=4)
        R.ring((0, 0, zb + 1.1), 6.6, 0.1, 'r_tre_mork', n1=24, n2=3)
        a = 180 * bi + 90
        m = _rz(a - 90) @ T((0, rt(zb) - 0.1, zb + 1.9))
        kasse_m((2.2, 0.5, 3.2), 'r_vindu_mork', m @ T((0, 0.1, 0)))
        R.sylinder(m @ Vector((0, -0.15, 1.6)), m @ Vector((0, 0.35, 1.6)), 1.1, 'r_vindu_mork', n=10)
        bue_m = m @ T((0, 0.3, 1.6))
        for k in range(7):
            v0 = math.pi * k / 7
            v1 = math.pi * (k + 1) / 7
            vm = (v0 + v1) / 2
            kasse_m((0.7, 0.4, 0.45), 'r_stein_mork', bue_m @ T((1.35 * math.cos(vm), 0, 1.35 * math.sin(vm)))
                    @ _ry(-math.degrees(vm) + 90))
        for s in (-1, 1):
            kasse_m((0.45, 0.4, 3.2), 'r_stein_mork', m @ T((s * 1.35, 0.3, 0)))
    # krone og tak
    dreie([(rb, zt - 1.0), (5.5, zt + 0.4), (5.5, zt + 1.6), (4.8, zt + 1.6)], 'r_stein', n=n, flat=True)
    for k in range(12):
        a = TAU * (k + 0.5) / 12
        R.kasse((5.3 * math.cos(a), 5.3 * math.sin(a), zt - 0.1), (0.6, 0.6, 0.9), 'r_stein_mork',
                rot=(0, 0, math.degrees(a)))
    profil = [(6.5, zt + 1.4), (6.2, zt + 1.6), (5.2, zt + 2.6), (3.4, zt + 5.0), (1.6, zt + 7.4),
              (0.0, zt + 9.2)]
    dreie(profil, 'r_tak_bla', n=n, flat=True)
    for k in range(8):
        a = TAU * k / 8 + TAU / 32
        sti = [((r + 0.08) * math.cos(a), (r + 0.08) * math.sin(a), z + 0.05) for r, z in profil[1:-1]]
        sti.append((0.2 * math.cos(a), 0.2 * math.sin(a), zt + 8.95))
        ror(sti, 0.2, 'r_tak_bla_lys', n=4)
    # takvindu (kvist) mot +Y
    R.kasse((0, 4.4, zt + 3.4), (1.8, 1.8, 2.0), 'r_stein_lys', fas=0.08)
    R.kasse((0, 5.32, zt + 3.3), (1.0, 0.1, 1.2), 'r_vindu_mork')
    R.plate([(3.3, zt + 4.3), (5.6, zt + 4.3), (4.45, zt + 5.4)], 2.2, 'r_tak_bla', plan='YZ', fas=0.06)
    # gullkule, stang og flagg
    ztp = zt + 9.0
    R.kule((0, 0, ztp + 0.35), 0.55, 'r_gull', u=10, v=6)
    R.sylinder((0, 0, ztp + 0.6), (0, 0, 70.0), 0.12, 'r_jern', n=6)
    R.kule((0, 0, 70.05), 0.2, 'r_gull', u=6, v=4)
    Lf, Hf, zf = 4.4, 2.2, 67.4

    def fp(u, v):
        k = u / Lf
        return Vector((0.15 + u, 0.45 * math.sin(TAU * u / 3.2 + 0.4) * k ** 0.8, zf + v - 0.3 * k * k))

    dy = Vector((0, 0.05, 0))
    for (v0, v1, f) in ((0.0, Hf / 3, 'r_rod'), (Hf / 3, 2 * Hf / 3, 'r_gul'), (2 * Hf / 3, Hf, 'r_rod')):
        ringer = []
        for a in range(7):
            u = Lf * a / 6
            p0, p1 = fp(u, v0), fp(u, v1)
            ringer.append([p0 + dy, p1 + dy, p1 - dy, p0 - dy])
        loft(ringer, f)
    return R.ferdig_modell('Taarn', plass_x=x, maks_tris=6000)


def luftskip(x):
    """Luftskip ca. 60 langt langs Y (baugen mot +Y): stor ballong med røde og hvite
    langsgående striper, gull nesekappe og bånd, fire halefinner med gule ror, gondol med
    vindusrader, motorgondoler med propeller bak og en stor propell bak på gondolen.
    ORIGO = midten av gondolens gulv."""
    R.ny_modell()
    zc, Rm = 15.8, 9.0
    yb, yf = -27.0, 29.0

    def rad(y):
        t = (y - yb) / (yf - yb)
        tm = 0.55
        if t >= tm:
            u = (t - tm) / (1 - tm)
            return Rm * max(0.0, 1 - u ** 2.2) ** 0.5
        u = (tm - t) / tm
        return Rm * max(0.0, 1 - u ** 1.8) ** 0.62

    ts = [0.0, 0.025, 0.07, 0.14, 0.24, 0.36, 0.48, 0.6, 0.72, 0.82, 0.9, 0.95, 0.975, 1.0]
    profil = []
    for t in ts:
        y = yb + (yf - yb) * t
        profil.append((rad(y) if 0 < t < 1 else 0.0, y))
    f_bit = ['r_gra_mork'] + [None] * (len(profil) - 4) + ['r_gull', 'r_gull']
    mb = T((0, 0, zc)) @ _rx(-90)
    dreie_farget(profil, f_bit, n=32, m=mb, striper=['r_rod', 'r_hvit'], per=2)
    for y in (13.0, -9.0):
        R.ring((0, y, zc), rad(y) + 0.05, 0.3, 'r_gull', akse=(0, 1, 0), n1=32, n2=4)
    # halefinner (plan som inneholder Y-aksen), roterte 90 grader om Y
    finne = [(-14.5, 2.5), (-25.0, 1.0), (-28.3, 11.0), (-22.5, 11.6)]
    ror_ = [(-25.0, 1.0), (-26.6, 1.0), (-30.0, 10.6), (-28.3, 11.0)]
    for k in range(4):
        mk = T((0, 0, zc)) @ _ry(90 * k) @ _rz(90)
        plate_m(finne, 0.6, 'r_rod', m=mk, fas=0.1)
        plate_m(ror_, 0.5, 'r_gul', m=mk, fas=0.08)
    # pylon fra gondoltaket opp i ballongen, og stag
    R.kasse((0, 0.0, 6.0), (1.4, 9.0, 2.6), 'r_gra_mork', fas=0.15, segm=1)
    for sx in (-1, 1):
        for sy in (-1, 1):
            R.sylinder((sx * 2.6, sy * 6.5, 5.0), (sx * 3.6, sy * 8.5, 7.9), 0.13, 'r_jern', n=4)
    # gondol (plan: avrundet rektangel), treskrog, kremhvit kabin med vindusrader, mørkt tak
    hx, hy = 3.4, 10.0

    def g(sk, z, sky=None):
        return [(ex, ey, z) for ex, ey in _superellipse(hx * sk, hy * (sky or sk), 24, 4.0)]

    loft([g(0.55, -1.2, 0.8), g(0.92, 0.0, 0.97), g(1.0, 1.4)], 'r_tre')
    loft([g(1.0, 1.4), g(1.0, 4.6)], 'r_vegg')
    loft([g(1.07, 4.55), g(1.07, 4.9), g(0.86, 5.25)], 'r_tre_mork')
    loft([g(1.03, 1.25), g(1.03, 1.65)], 'r_gull')
    for sx in (-1, 1):
        for wy in (-6.0, -3.6, -1.2, 1.2, 3.6, 6.0):
            R.kasse((sx * 3.42, wy, 3.05), (0.25, 1.5, 1.5), 'r_vindu')
            R.kasse((sx * 3.36, wy, 3.05), (0.2, 1.9, 1.9), 'r_tre_mork')
    for wx in (-1.4, 0.0, 1.4):
        R.kasse((wx, 9.9, 3.15), (1.15, 0.25, 1.5), 'r_vindu', rot=(0, 0, -wx * 16))
    # motorgondoler med propeller bak
    for sx in (-1, 1):
        c = Vector((sx * 7.0, -4.0, 4.8))
        R.sylinder((sx * 3.2, -4.0, 3.6), c + Vector((-sx * 0.7, 0, 0)), 0.3, 'r_gra_mork', n=6)
        dreie([(0.0, -2.1), (0.8, -1.7), (1.1, -0.4), (1.05, 0.9), (0.6, 1.8), (0.0, 2.0)], 'r_metall', n=10,
              m=T(c) @ _rx(-90))
        R.ring(c + Vector((0, 0.7, 0)), 1.1, 0.14, 'r_rod', akse=(0, 1, 0), n1=10, n2=4)
        _propell(c + Vector((0, -2.2, 0)), 2.2, 3)
    R.sylinder((0, -9.6, 2.5), (0, -11.3, 2.5), 0.35, 'r_gra_mork', n=6)
    _propell(Vector((0, -11.4, 2.5)), 2.4, 4)
    return R.ferdig_modell('Luftskip', plass_x=x, maks_tris=8000)


def _propell(nav, r, blader):
    """Propell i XZ-planet (aksel langs Y) med rød navkapsel."""
    nav = Vector(nav)
    R.kule(nav + Vector((0, -0.25, 0)), 0.42, 'r_rod', skala=(1, 1.3, 1), u=8, v=6)
    for k in range(blader):
        m = T(nav) @ _ry(360 * k / blader + 20) @ T((r / 2 + 0.2, 0, 0)) @ _rx(20)
        kasse_m((r, 0.12, 0.5), 'r_tre_lys', m, fas=0.04)


def svevestein(x):
    """Liten flytende stein ca. 10 bred og 9 høy: gresstopp med dryppkant, jordlag og en ujevn,
    kantete stein som smalner til en spiss under, med noen utstikkende steiner, gresstuster
    og en blomst. ORIGO = midten av toppflaten."""
    R.ny_modell()
    rng = random.Random(9)
    n = 12
    rj = [5.0 * rng.uniform(0.86, 1.06) for _ in range(n)]

    def ring(sk, z, jit=0.0, dz=None):
        ut = []
        for j in range(n):
            a = TAU * j / n
            r = rj[j] * sk * (1 + rng.uniform(-jit, jit))
            ut.append((r * math.cos(a), r * math.sin(a), z + (dz[j] if dz else 0.0)))
        return ut

    drypp = [-(0.6 if j % 2 else 0.15) - rng.uniform(0.0, 0.2) for j in range(n)]
    loft([[(0.0, 0.0, 0.0)], ring(1.0, -0.1), ring(1.05, -0.4, dz=drypp),
          ring(0.97, -0.35, dz=[d * 0.5 for d in drypp])], 'r_gress', flat=True)
    loft([ring(0.98, -0.3), ring(0.95, -1.5, 0.03)], 'r_jord', flat=True)
    r1 = ring(0.96, -1.35, 0.05)
    r2 = ring(0.8, -3.0, 0.1)
    r3 = ring(0.58, -5.0, 0.12)
    loft([r1, r2, r3], 'r_stein', flat=True)
    loft([r3, ring(0.32, -6.9, 0.15), [(0.3, -0.2, -8.6)]], 'r_stein_mork', flat=True)
    for i, (p, r, f) in enumerate((((3.5, 1.4, -2.6), 1.3, 'r_stein_mork'), ((-2.6, -2.6, -3.4), 1.2, 'r_stein'),
                                   ((-3.2, 2.0, -1.9), 0.9, 'r_stein'), ((1.2, -3.0, -5.2), 0.8, 'r_stein_mork'))):
        stein(p, r, f, skala=(1.0, 1.0, 1.2), nr=221 + i, deling=1, ujevn=0.1)
    _gresstust((1.6, 1.2, 0.0), 1.0, 'r_blad', nr=225)
    _gresstust((-2.0, -0.8, 0.0), 0.8, 'r_blad_lys', nr=226, antall=3)
    _blomst((-0.8, 2.2, 0.35), (0, 0, 1), 0.6, 'r_rosa')
    R.sylinder((-0.8, 2.2, -0.05), (-0.8, 2.2, 0.32), 0.05, 'r_blad_mork', n=4)
    stein((2.6, -1.6, 0.05), 0.4, 'r_stein_lys', nr=227)
    return R.ferdig_modell('Svevestein', plass_x=x, maks_tris=1000)


# ---------------------------------------------------------------- bygg

MODELLER = [
    ('Hus', hus), ('Vindmolle', vindmolle), ('VindmolleVinger', vindmolle_vinger), ('Lykt', lykt),
    ('Dukke', dukke), ('Krystall', krystall), ('KrystallStor', krystall_stor), ('Sopp', sopp),
    ('SoppLiten', sopp_liten), ('Furu', furu), ('Snomann', snomann), ('Kaktus', kaktus),
    ('Pyramide', pyramide), ('Soyle', soyle), ('Ruinbue', ruinbue), ('Steinhode', steinhode),
    ('Bambus', bambus), ('Bregne', bregne), ('Vulkanstein', vulkanstein), ('Taarn', taarn),
    ('Luftskip', luftskip), ('Svevestein', svevestein),
]
NAVN = [n for n, _ in MODELLER]


def bygg(navn=None, x0=0.0, mellomrom=10.0):
    """Bygg modellene i `navn` (standard: alle) side om side langs X. Returnerer neste ledige x."""
    x = x0
    for n, fn in MODELLER:
        if navn is not None and n not in navn:
            continue
        ob = fn(x)
        bredde = R.MODELLER[n]['str'][0]
        ob.location.x = x + bredde / 2
        x += bredde + mellomrom
    return x


def bygg_alle(x0=0.0):
    """Bygg alle rekvisittene med plass_x økende fra x0. Returnerer neste ledige x."""
    return bygg(None, x0)
