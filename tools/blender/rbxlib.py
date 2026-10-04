"""
rbxlib — gjenbrukbart Blender-bibliotek for Roblox-modeller laget med kode.

Brukes fra et byggeskript som kjøres uten vindu:

    /Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup -P tools/blender/bygg_modeller.py

Prinsipper (se docs/ROBLOX-OPPSKRIFT.md):
  * 1 Blender-enhet = 1 stud. En Roblox-figur er ca. 5 studs høy.
  * Alle modeller deler ÉN palett-tekstur (16x16 fargeruter à 16 px). Hver del får én farge ved at
    alle UV-ene legges midt i fargens rute. Én tekstur gir lik stil og lite minne i Roblox.
    Registrer fargene på modulnivå (før første modell bygges) — bildet lages ved første del.
  * Hver modell blir ett objekt (én MeshPart i Roblox). Delene slås sammen i ferdig_modell().
  * Aksene: Blender (x, y, z) -> glTF/Roblox (x, z, -y). Bygg «opp» langs +Z og «forover» langs +Y.
  * Bygg hver modell rundt sitt eget origo (typisk: bakken midt under modellen). Roblox plasserer en
    MeshPart i midten av bounding boxen, så ModelInfo får:
        str     størrelse i studs (Roblox-akser)
        midt    bounding-box-midten relativt til origo  -> del.CFrame = origoCFrame * CFrame.new(midt)
        grep    (verktøy) grep-punkt relativt til MIDTEN  -> Tool.Grip = CFrame.new(grep)
        punkter (alt annet) navngitte punkter relativt til ORIGO
  * lakk=True gir modellen et hvitt materiale uten tekstur, så MeshPart.Color kan farge den i Roblox
    (f.eks. karosseri i spillerens farge).
"""
import math
import os

import bmesh
import bpy
from mathutils import Euler, Matrix, Vector

# ---------------------------------------------------------------- palett

RUTER = 16         # 16x16 ruter = 256 farger
CELLE = 16         # piksler per rute
BILDE = RUTER * CELLE

PALETT = {}        # navn -> (indeks, hex)


def farge(navn, hexkode):
    """Registrer en farge i paletten. Kall før modellene bygges."""
    if navn in PALETT:
        if PALETT[navn][1].lower() != hexkode.lower():
            raise RuntimeError(f'Fargen {navn} er allerede registrert med en annen verdi')
        return navn
    if 'mat' in _MAT:
        raise RuntimeError(f'Fargen {navn} registreres etter at palettbildet er laget')
    if len(PALETT) >= RUTER * RUTER:
        raise RuntimeError('Paletten er full')
    PALETT[navn] = (len(PALETT), hexkode)
    return navn


def farger(**kw):
    for navn, h in kw.items():
        farge(navn, h)


def _uv(navn):
    if navn not in PALETT:
        raise KeyError(f'Ukjent farge: {navn}')
    i = PALETT[navn][0]
    return ((i % RUTER + 0.5) / RUTER, 1.0 - (i // RUTER + 0.5) / RUTER)


def _hex(h):
    h = h.lstrip('#')
    return [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]


_MAT = {}


def palett_materiale(lagre_png=None):
    """Lager (én gang) palett-bildet og materialet som alle modellene bruker."""
    if 'mat' in _MAT:
        return _MAT['mat']
    img = bpy.data.images.new('palett', BILDE, BILDE, alpha=False)
    px = [0.0] * (BILDE * BILDE * 4)
    for navn, (i, h) in PALETT.items():
        r, g, b = _hex(h)
        kol, rad = i % RUTER, i // RUTER
        y0 = BILDE - (rad + 1) * CELLE
        rgba = [r, g, b, 1.0] * CELLE
        for y in range(y0, y0 + CELLE):
            o = (y * BILDE + kol * CELLE) * 4
            px[o:o + CELLE * 4] = rgba
    img.pixels = px
    if lagre_png:
        os.makedirs(os.path.dirname(lagre_png), exist_ok=True)
        img.filepath_raw = lagre_png
        img.file_format = 'PNG'
        img.save()
    m = bpy.data.materials.new('Palett')
    m.use_nodes = True
    nt = m.node_tree
    p = nt.nodes['Principled BSDF']
    p.inputs['Roughness'].default_value = 0.65
    tex = nt.nodes.new('ShaderNodeTexImage')
    tex.image = img
    tex.interpolation = 'Closest'
    nt.links.new(tex.outputs['Color'], p.inputs['Base Color'])
    _MAT['mat'] = m
    return m


def lakk_materiale():
    """Hvitt materiale uten tekstur. I Roblox fargelegges delen med MeshPart.Color."""
    if 'lakk' in _MAT:
        return _MAT['lakk']
    m = bpy.data.materials.new('Lakk')
    m.use_nodes = True
    p = m.node_tree.nodes['Principled BSDF']
    p.inputs['Base Color'].default_value = (1, 1, 1, 1)
    p.inputs['Roughness'].default_value = 0.35
    _MAT['lakk'] = m
    return m


# ---------------------------------------------------------------- deler

_DELER = []        # delene til modellen som bygges nå
MODELLER = {}      # navn -> info (ferdige modeller)


def _ferdig(bm, farge_navn, fas=0.0, segm=2):
    uv = bm.loops.layers.uv.verify()
    u = _uv(farge_navn)
    for f in bm.faces:
        for lp in f.loops:
            lp[uv].uv = u
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new('del')
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = True
    ob = bpy.data.objects.new('del', me)
    bpy.context.scene.collection.objects.link(ob)
    me.materials.append(palett_materiale())
    if fas:
        mod = ob.modifiers.new('fas', 'BEVEL')
        mod.width = fas
        mod.segments = segm
        mod.limit_method = 'ANGLE'
        mod.angle_limit = math.radians(40)
    _DELER.append(ob)
    return ob


def _flytt(bm, rot=None, pos=(0, 0, 0)):
    m = Matrix.Translation(Vector(pos))
    if rot is not None:
        m = m @ (rot.to_matrix().to_4x4() if hasattr(rot, 'to_matrix') else rot)
    bmesh.ops.transform(bm, matrix=m, verts=bm.verts)


def _euler(rot):
    """rot = (x, y, z) i grader -> Matrix."""
    if rot is None:
        return None
    return Euler([math.radians(a) for a in rot]).to_matrix().to_4x4()


def kasse(sentrum, str, f, fas=0.0, rot=None, segm=2):
    """Boks med størrelse `str` (x, y, z) rundt `sentrum`. rot i grader."""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=Vector(str), verts=bm.verts)
    _flytt(bm, _euler(rot), sentrum)
    return _ferdig(bm, f, fas, segm)


def sylinder(a, b, r, f, r2=None, n=16, fas=0.0, segm=2):
    """Sylinder/kjegle fra punkt a til punkt b. r2 = radius i b-enden (kjegle)."""
    a, b = Vector(a), Vector(b)
    d = b - a
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=n,
                          radius1=r, radius2=r if r2 is None else r2, depth=d.length)
    _flytt(bm, d.to_track_quat('Z', 'Y'), (a + b) / 2)
    return _ferdig(bm, f, fas, segm)


def kule(sentrum, r, f, skala=(1, 1, 1), u=16, v=10, rot=None):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=u, v_segments=v, radius=r)
    bmesh.ops.scale(bm, vec=Vector(skala), verts=bm.verts)
    _flytt(bm, _euler(rot), sentrum)
    return _ferdig(bm, f)


def krystall(sentrum, r, f, skala=(1, 1, 1), rot=None, deling=1):
    """Kantete ikosaeder — is, steiner, gnister."""
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=deling, radius=r)
    bmesh.ops.scale(bm, vec=Vector(skala), verts=bm.verts)
    _flytt(bm, _euler(rot), sentrum)
    return _ferdig(bm, f)


def ring(sentrum, R, r, f, akse=(0, 0, 1), n1=24, n2=8, fra=0.0, til=360.0):
    """Torus med hovedradius R og rørradius r, rundt `akse`. fra/til (grader) gir en bue."""
    hel = abs(til - fra) >= 359.999
    bm = bmesh.new()
    rings = []
    antall = n1 if hel else n1 + 1
    for i in range(antall):
        a = math.radians(fra + (til - fra) * i / n1)
        rad = []
        for j in range(n2):
            b = 2 * math.pi * j / n2
            rr = R + r * math.cos(b)
            rad.append(bm.verts.new((rr * math.cos(a), rr * math.sin(a), r * math.sin(b))))
        rings.append(rad)
    for i in range(n1 if hel else n1):
        i2 = (i + 1) % antall
        for j in range(n2):
            a, b = rings[i][j], rings[i2][j]
            c, d = rings[i2][(j + 1) % n2], rings[i][(j + 1) % n2]
            bm.faces.new((a, b, c, d))
    if not hel:
        bm.faces.new(rings[0])
        bm.faces.new(list(reversed(rings[-1])))
    _flytt(bm, Vector(akse).to_track_quat('Z', 'Y'), sentrum)
    return _ferdig(bm, f)


def bue(sentrum, R, r, f, akse=(0, 1, 0), fra=0.0, til=180.0, n1=16, n2=8):
    """Bue (del av en torus). Standard: halvsirkel som står opp (portaler, buer, bøyler)."""
    return ring(sentrum, R, r, f, akse=akse, n1=n1, n2=n2, fra=fra, til=til)


def plate(punkter, tykk, f, plan='XZ', midt=0.0, fas=0.0):
    """Ekstruder en 2D-form. plan='XZ': punktene er (x, z), tykkelsen går langs y rundt `midt`.
    plan='XY': punktene er (x, y), tykkelsen langs z. plan='YZ': (y, z), tykkelse langs x."""
    def p3(u, v, w):
        if plan == 'XZ':
            return (u, w, v)
        if plan == 'XY':
            return (u, v, w)
        return (w, u, v)
    bm = bmesh.new()
    vs = [bm.verts.new(p3(u, v, midt - tykk / 2)) for u, v in punkter]
    fc = bm.faces.new(vs)
    ext = bmesh.ops.extrude_face_region(bm, geom=[fc])
    topp = [e for e in ext['geom'] if isinstance(e, bmesh.types.BMVert)]
    akse = {'XZ': (0, tykk, 0), 'XY': (0, 0, tykk), 'YZ': (tykk, 0, 0)}[plan]
    bmesh.ops.translate(bm, verts=topp, vec=akse)
    return _ferdig(bm, f, fas)


def staver(punkter, r, f, n=8):
    """Rør gjennom en liste med punkter (lunte, tau, ledning, stammer)."""
    out = []
    for a, b in zip(punkter, punkter[1:]):
        out.append(sylinder(a, b, r, f, n=n))
        out.append(kule(b, r, f, u=n, v=6))
    return out


def blad(start, retning, lengde, bredde, f, heng=0.35, fold=0.18, tykk=0.08, segm=8, tagget=False, vri=0.0):
    """Blad langs en buet midtribbe: palmeblader, jungelblader, flagg som henger.

    retning: retningen bladet vokser (normaliseres). heng: hvor mye tuppen synker (andel av lengden).
    fold: V-form (andel av bredden). tagget=True gir sagtenner (palmeblad). vri: rotasjon om ribben (grader).
    """
    d = Vector(retning).normalized()
    opp = Vector((0, 0, 1))
    side = d.cross(opp)
    if side.length < 1e-4:
        side = Vector((1, 0, 0))
    side.normalize()
    normal = side.cross(d).normalized()
    if vri:
        q = Matrix.Rotation(math.radians(vri), 3, d)
        side, normal = q @ side, q @ normal
    bm = bmesh.new()
    rader = []
    for i in range(segm + 1):
        s = i / segm
        p = Vector(start) + d * (s * lengde) - opp * (heng * lengde * s * s)
        w = bredde * max(math.sin(math.pi * s), 0.0) ** 0.7
        if tagget and 0 < i < segm and i % 2 == 1:
            w *= 0.6
        w = max(w, 0.03)
        midt = p + normal * (fold * w)
        venstre, hoyre = p - side * (w / 2), p + side * (w / 2)
        rad = [bm.verts.new(v) for v in (venstre, midt, hoyre)]
        rad += [bm.verts.new(v - normal * tykk) for v in (venstre, midt, hoyre)]
        rader.append(rad)
    for a, b in zip(rader, rader[1:]):
        bm.faces.new((a[0], a[1], b[1], b[0]))
        bm.faces.new((a[1], a[2], b[2], b[1]))
        bm.faces.new((b[3], b[4], a[4], a[3]))
        bm.faces.new((b[4], b[5], a[5], a[4]))
        bm.faces.new((a[3], a[0], b[0], b[3]))
        bm.faces.new((a[2], a[5], b[5], b[2]))
    forst, sist = rader[0], rader[-1]
    bm.faces.new((forst[0], forst[1], forst[2], forst[5], forst[4], forst[3]))
    bm.faces.new((sist[3], sist[4], sist[5], sist[2], sist[1], sist[0]))
    return _ferdig(bm, f)


# ---------------------------------------------------------------- modell

def tom_scene():
    """Fjern standardkuben, kameraet og lyset fra --factory-startup."""
    for ob in list(bpy.data.objects):
        bpy.data.objects.remove(ob, do_unlink=True)


def ny_modell():
    _DELER.clear()


def ferdig_modell(navn, grep=None, punkter=None, plass_x=0.0, maks_tris=10000, lakk=False):
    """Slå sammen delene til ett objekt, sentrer det og lagre info til ModelInfo.

    grep:    punkt (Blender-koordinater) der hånden holder. Lagres relativt til MIDTEN (Tool.Grip).
    punkter: dict med navngitte punkter (Blender-koordinater). Lagres relativt til ORIGO.
    lakk:    hvitt materiale uten tekstur, så Roblox kan farge delen (MeshPart.Color).
    """
    if not _DELER:
        raise RuntimeError(f'{navn}: ingen deler')
    bpy.ops.object.select_all(action='DESELECT')
    for ob in _DELER:
        ob.select_set(True)
    bpy.context.view_layer.objects.active = _DELER[0]
    bpy.ops.object.convert(target='MESH')
    if len(_DELER) > 1:
        bpy.ops.object.join()
    ob = bpy.context.view_layer.objects.active
    ob.name = navn
    me = ob.data
    me.name = navn
    if hasattr(me, 'use_auto_smooth'):        # Blender 4.0
        me.use_auto_smooth = True
        me.auto_smooth_angle = math.radians(40)
    if lakk:
        me.materials.clear()
        me.materials.append(lakk_materiale())
        for p in me.polygons:
            p.material_index = 0

    lo = Vector((min(v.co[i] for v in me.vertices) for i in range(3)))
    hi = Vector((max(v.co[i] for v in me.vertices) for i in range(3)))
    midt = (lo + hi) / 2
    me.transform(Matrix.Translation(-midt))
    ob.location = (plass_x, 0, 0)

    def rbx(v):  # Blender -> Roblox-akser
        return (round(v[0], 4), round(v[2], 4), round(-v[1], 4))

    dim = hi - lo
    tris = sum(len(p.vertices) - 2 for p in me.polygons)
    info = {'str': (round(dim.x, 4), round(dim.z, 4), round(dim.y, 4)), 'tris': tris, 'midt': rbx(midt)}
    if grep is not None:
        info['grep'] = rbx(Vector(grep) - midt)
    for k, p in (punkter or {}).items():
        info[k] = rbx(Vector(p))
    if tris > maks_tris:
        print(f'ADVARSEL: {navn} har {tris} trekanter (maks {maks_tris})')
    MODELLER[navn] = {'obj': ob, **info}
    _DELER.clear()
    print(f'  {navn:16s} {tris:6d} tris  str={info["str"]}')
    return ob


def skriv_modelinfo(sti, kilde):
    def v3(t):
        return f'Vector3.new({t[0]}, {t[1]}, {t[2]})'
    linjer = [f'-- GENERERT av {kilde}. Ikke rediger for hånd — kjør byggeskriptet på nytt.',
              '-- str = størrelse (studs), midt = bbox-midten relativt til modellens origo,',
              '-- grep = relativt til midten, andre punkter = relativt til origo. Alt i Roblox-akser.',
              'return {']
    for navn, info in MODELLER.items():
        felt = [f'str = {v3(info["str"])}', f'midt = {v3(info["midt"])}', f'tris = {info["tris"]}']
        felt += [f'{k} = {v3(v)}' for k, v in info.items() if k not in ('obj', 'str', 'tris', 'midt')]
        linjer.append(f'\t{navn} = {{ {", ".join(felt)} }},')
    linjer.append('}')
    with open(sti, 'w') as fh:
        fh.write('\n'.join(linjer) + '\n')


def eksporter_glb(sti, navn):
    """`navn` blir navnet på modellen i Roblox etter Import (glTF-scenens navn)."""
    bpy.context.scene.name = navn
    bpy.ops.object.select_all(action='DESELECT')
    for info in MODELLER.values():
        info['obj'].select_set(True)
    os.makedirs(os.path.dirname(sti), exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=sti, export_format='GLB', use_selection=True,
                              export_apply=True, export_yup=True, export_texcoords=True,
                              export_normals=True, export_materials='EXPORT')


# ---------------------------------------------------------------- forhåndsvisning

def _scene_for_render(oppl):
    sc = bpy.context.scene
    sc.render.engine = 'BLENDER_EEVEE'
    sc.render.resolution_x = sc.render.resolution_y = oppl
    sc.render.film_transparent = False
    sc.view_settings.view_transform = 'Standard'   # samme farger som i Roblox
    if hasattr(sc.eevee, 'use_soft_shadows'):
        sc.eevee.use_soft_shadows = True
    if hasattr(sc.eevee, 'use_gtao'):
        sc.eevee.use_gtao = True
    w = sc.world or bpy.data.worlds.new('verden')
    sc.world = w
    w.use_nodes = True
    bg = w.node_tree.nodes['Background']
    bg.inputs['Color'].default_value = (0.55, 0.62, 0.72, 1)
    bg.inputs['Strength'].default_value = 0.9
    if 'sol' not in bpy.data.objects:
        ld = bpy.data.lights.new('sol', 'SUN')
        ld.energy = 3.2
        ld.angle = math.radians(8)
        sol = bpy.data.objects.new('sol', ld)
        sol.rotation_euler = (math.radians(50), math.radians(10), math.radians(-35))
        sc.collection.objects.link(sol)
    if 'kamera' not in bpy.data.objects:
        cd = bpy.data.cameras.new('kamera')
        cd.type = 'ORTHO'
        cam = bpy.data.objects.new('kamera', cd)
        sc.collection.objects.link(cam)
        sc.camera = cam
    return sc, bpy.data.objects['kamera']


def _sikt(cam, lo, hi, retning):
    midt = (lo + hi) / 2
    st = (hi - lo).length
    d = Vector(retning).normalized()
    cam.location = midt + d * (st * 3 + 10)
    cam.rotation_euler = (-d).to_track_quat('-Z', 'Y').to_euler()
    cam.data.ortho_scale = st * 1.15
    cam.data.clip_end = st * 10 + 100


def _bbox(obs):
    pts = [o.matrix_world @ Vector(c) for o in obs for c in o.bound_box]
    return (Vector((min(p[i] for p in pts) for i in range(3))),
            Vector((max(p[i] for p in pts) for i in range(3))))


def _kontrollark(mappe, navn, oppl, kolonner=5, filnavn='_ark.png'):
    """Alle enkeltbildene i ett rutenett, så de kan sjekkes med ett blikk."""
    import numpy as np
    rader = (len(navn) + kolonner - 1) // kolonner
    ark = np.ones((rader * oppl, kolonner * oppl, 4), dtype=np.float32)
    for i, n in enumerate(navn):
        img = bpy.data.images.load(os.path.join(mappe, f'{n}.png'))
        px = np.array(img.pixels[:], dtype=np.float32).reshape(oppl, oppl, 4)
        r, k = rader - 1 - i // kolonner, i % kolonner
        ark[r * oppl:(r + 1) * oppl, k * oppl:(k + 1) * oppl] = px
        bpy.data.images.remove(img)
    out = bpy.data.images.new('ark', kolonner * oppl, rader * oppl)
    out.pixels = ark.ravel()
    out.filepath_raw = os.path.join(mappe, filnavn)
    out.file_format = 'PNG'
    out.save()


def render_forhandsvisning(mappe, oppl=512, retning=(1.0, 1.6, 0.9), bare=None, filnavn='_ark.png'):
    """Ett bilde per modell + et kontrollark. Brukes til å SE på modellene før eksport.
    bare: liste med modellnavn (standard: alle)."""
    sc, cam = _scene_for_render(oppl)
    os.makedirs(mappe, exist_ok=True)
    bpy.context.view_layer.update()
    alle = [i['obj'] for i in MODELLER.values()]
    navn = [n for n in MODELLER if bare is None or n in bare]
    for n in navn:
        info = MODELLER[n]
        for o in alle:
            o.hide_render = o is not info['obj']
        lo, hi = _bbox([info['obj']])
        _sikt(cam, lo, hi, retning)
        sc.render.filepath = os.path.join(mappe, f'{n}.png')
        bpy.ops.render.render(write_still=True)
    _kontrollark(mappe, navn, oppl, filnavn=filnavn)
    for o in alle:
        o.hide_render = False
