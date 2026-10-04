"""
Testskript for rekvisittene i GRAPPLER: bygger BARE modellene i rekvisitter.py og rendrer
kontrollbilder. Eksporterer ingenting (hovedskriptet gjør det).

    /Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup -P tools/blender/test_rekvisitter.py

Valg (etter `--`):
    --bare Hus,Lykt          bygg og render bare disse
    --retning 0,1,0.3        kameraretning (standard som rbxlib: 1,1.6,0.9)
    --ut <mappe>             annen mappe for bildene (standard: assets/previews_rekvisitter)
    --oppl 512               oppløsning per bilde
    --uten-bilder            bare bygg og skriv tabellen
"""
import os
import sys

HER = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HER)
import bpy  # noqa: E402
import rbxlib as R  # noqa: E402

ROT = os.path.abspath(os.path.join(HER, '..', '..'))
ARGS = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []


def valg(navn, std=None):
    if navn in ARGS:
        return ARGS[ARGS.index(navn) + 1]
    return std


R.tom_scene()
import rekvisitter as RK  # noqa: E402  (registrerer r_*-fargene)

bare = valg('--bare')
bare = bare.split(',') if bare else None
retning = tuple(float(t) for t in valg('--retning', '1,1.6,0.9').split(','))
mappe = valg('--ut', os.path.join(ROT, 'assets', 'previews_rekvisitter'))
oppl = int(valg('--oppl', '512'))

r_farger = [n for n in R.PALETT if n.startswith('r_')]
print(f'Farger fra rekvisitter: {len(r_farger)}')

print('Bygger rekvisitter:')
neste = RK.bygg(bare, 0.0)
print(f'Neste ledige x: {neste:.1f}')

# ---------------------------------------------------------------- sjekk
GRENSER = {'Hus': 4000, 'Vindmolle': 3000, 'VindmolleVinger': 1500, 'Lykt': 800, 'Dukke': 1500,
           'Krystall': 1500, 'KrystallStor': 2500, 'Sopp': 2500, 'SoppLiten': 1500, 'Furu': 2500,
           'Snomann': 2000, 'Kaktus': 1500, 'Pyramide': 2000, 'Soyle': 1500, 'Ruinbue': 2500,
           'Steinhode': 2000, 'Bambus': 2000, 'Bregne': 1500, 'Vulkanstein': 1000, 'Taarn': 6000,
           'Luftskip': 8000, 'Svevestein': 1000}
feil = []
for n in (bare or RK.NAVN):
    if n not in R.MODELLER:
        feil.append(f'mangler modell {n}')
print('\nModell             tris  maks   str (Roblox x, y, z)          punkter')
for n, info in R.MODELLER.items():
    pk = {k: v for k, v in info.items() if k not in ('obj', 'str', 'tris', 'midt')}
    print(f'  {n:16s} {info["tris"]:5d} {GRENSER.get(n, 0):5d}   {str(info["str"]):28s} {pk}')
    if info['tris'] > GRENSER.get(n, 10 ** 9):
        feil.append(f'{n} har {info["tris"]} trekanter (maks {GRENSER[n]})')
forventet = {'Vindmolle': ['nav'], 'Lykt': ['lys']}
for n, punkter in forventet.items():
    if n in R.MODELLER:
        for p in punkter:
            if p not in R.MODELLER[n]:
                feil.append(f'{n} mangler punkt {p}')
print('\n' + ('FEIL: ' + '; '.join(feil) if feil else 'Alle modellnavn, punkter og trekantbudsjett stemmer.'))

if '--uten-bilder' not in ARGS:
    bpy.context.view_layer.update()
    R.render_forhandsvisning(mappe, oppl=oppl, retning=retning, filnavn='_ark.png')
    print(f'Kontrollbilder: {mappe}')
print('Ferdig.')
