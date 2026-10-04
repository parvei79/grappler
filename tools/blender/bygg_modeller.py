"""
Alle 3D-modellene i GRAPPLER, bygget med kode.

    /Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup -P tools/blender/bygg_modeller.py
    ... -- --uten-bilder | --alle-bilder | --uten-rekvisitter

Skriver assets/GrapplerModeller.glb (importeres i Studio), assets/previews/*.png og src/shared/ModelInfo.lua.
Konvensjoner (se rbxlib.py): 1 enhet = 1 stud, +Z opp, forsiden mot +Y (= LookVector i Roblox).
KrokPistol: løpet peker mot +Y, håndtaket ned; `grep` = der hånden holder, `munning` = der tauet kommer ut.
Krok: klørne peker mot +Y, origo i midten; `ring` = der tauet er festet.
"""
import math
import os
import sys
import traceback

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy  # noqa: E402,F401
import rbxlib as R  # noqa: E402

ROT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
ARGS = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []

R.tom_scene()
R.farger(
    g_metall='#9aa3ad', g_metall_mork='#3c424b', g_svart='#1c1e22', g_rod='#e63946', g_gul='#ffcc1a',
    g_tre='#8a5a33', g_gummi='#2a2b30', g_kobber='#c87533', g_lys='#7fe7ff', g_hvit='#f2f2ee',
)

rekvisitter = None
try:
    if '--uten-rekvisitter' not in ARGS:
        import rekvisitter  # registrerer sine farger (r_*) ved import
except Exception:
    print('ADVARSEL: rekvisitter.py kunne ikke lastes — bygger uten rekvisitter')
    traceback.print_exc()
    rekvisitter = None

R.palett_materiale(lagre_png=os.path.join(ROT, 'assets', 'palett.png'))


def krokpistol(x):
    """Tegneserieaktig krokpistol: tykt løp med krokspiss, trommel med tau, håndtak med gummigrep."""
    R.ny_modell()
    # håndtak (ned langs -Z), grep midt på
    R.kasse((0, -0.2, -0.9), (0.55, 0.7, 1.7), 'g_gummi', rot=(14, 0, 0), fas=0.15)
    R.kasse((0, 0.35, -0.55), (0.18, 0.5, 0.12), 'g_metall_mork')            # avtrekker
    R.ring((0, 0.25, -0.45), 0.35, 0.07, 'g_metall_mork', akse=(1, 0, 0), n1=14, n2=5, fra=180, til=360)
    # kropp
    R.kasse((0, 0.4, 0.15), (0.8, 2.6, 0.9), 'g_rod', fas=0.2)
    R.kasse((0, 0.4, 0.62), (0.5, 1.8, 0.12), 'g_gul')                         # stripe
    # tautrommel på siden
    R.sylinder((0.42, -0.2, 0.15), (0.78, -0.2, 0.15), 0.55, 'g_metall', n=16, fas=0.05)
    R.sylinder((0.44, -0.2, 0.15), (0.76, -0.2, 0.15), 0.42, 'g_svart', n=16)
    # løp
    R.sylinder((0, 1.6, 0.3), (0, 3.0, 0.3), 0.32, 'g_metall_mork', n=14, fas=0.05)
    R.sylinder((0, 2.9, 0.3), (0, 3.25, 0.3), 0.4, 'g_metall', n=14, fas=0.05)
    # krokspissen som stikker ut av løpet
    R.sylinder((0, 3.2, 0.3), (0, 3.65, 0.3), 0.12, 'g_metall', n=8)
    for i in range(3):
        a = i * 2 * math.pi / 3
        dx, dz = math.cos(a) * 0.32, math.sin(a) * 0.32
        R.sylinder((0, 3.55, 0.3), (dx, 3.9, 0.3 + dz), 0.07, 'g_metall', r2=0.03, n=6)
    # lys på toppen
    R.kule((0, 0.9, 0.7), 0.16, 'g_lys', u=10, v=6)
    return R.ferdig_modell('KrokPistol', grep=(0, -0.25, -0.85), punkter={'munning': (0, 3.7, 0.3)}, plass_x=x)


def krok(x):
    """Gripekrok: skaft, tre krumme klør, ring bak der tauet sitter."""
    R.ny_modell()
    R.sylinder((0, -1.0, 0), (0, 1.0, 0), 0.16, 'g_metall_mork', n=10, fas=0.03)
    R.ring((0, -1.25, 0), 0.25, 0.07, 'g_metall', akse=(1, 0, 0), n1=14, n2=6)
    R.kule((0, 1.05, 0), 0.24, 'g_metall', u=12, v=8)
    for i in range(3):
        a = i * 2 * math.pi / 3
        ux, uz = math.cos(a), math.sin(a)
        pkt = [(0, 1.0, 0), (ux * 0.55, 1.45, uz * 0.55), (ux * 0.95, 1.1, uz * 0.95), (ux * 0.9, 0.55, uz * 0.9)]
        R.staver(pkt, 0.1, 'g_metall', n=6)
        R.sylinder(pkt[-1], (ux * 0.7, 0.35, uz * 0.7), 0.1, 'g_metall', r2=0.02, n=6)
    R.kasse((0, 0.1, 0), (0.42, 0.5, 0.42), 'g_rod', fas=0.06)
    return R.ferdig_modell('Krok', punkter={'ring': (0, -1.3, 0)}, plass_x=x)


print('Bygger modeller:')
krokpistol(0)
krok(6)
EGNE = list(R.MODELLER)
if rekvisitter is not None:
    try:
        rekvisitter.bygg_alle(20)
    except Exception:
        print('ADVARSEL: rekvisitter.bygg_alle feilet')
        traceback.print_exc()

R.eksporter_glb(os.path.join(ROT, 'assets', 'GrapplerModeller.glb'), 'GrapplerModeller')
R.skriv_modelinfo(os.path.join(ROT, 'src', 'shared', 'ModelInfo.lua'), 'tools/blender/bygg_modeller.py')
if '--uten-bilder' not in ARGS:
    R.render_forhandsvisning(os.path.join(ROT, 'assets', 'previews'),
                             bare=None if '--alle-bilder' in ARGS else EGNE)
print('Ferdig.')
