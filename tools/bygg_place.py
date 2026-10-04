#!/usr/bin/env python3
"""
Bygger en Roblox-place (.rbxlx) fra koden i src/, etter default.project.json.

    python3 tools/bygg_place.py            -> build/BonkArena.rbxlx

Dette er en liten utgave av `rojo build`, så vi slipper å installere noe. Filoppsettet følger
Rojo-reglene, så prosjektet kan bytte til `rojo serve` (live-synk til Studio) når som helst:

    Navn.server.lua -> Script        Navn.client.lua -> LocalScript
    Navn.lua        -> ModuleScript  mappe           -> Folder
    init.server.lua / init.client.lua / init.lua i en mappe gjør mappen til det skriptet.
"""
import json
import os
import sys
import uuid
import xml.etree.ElementTree as ET
from xml.sax.saxutils import escape

ROT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))


def ref():
    return 'RBX' + uuid.uuid4().hex.upper()


def cdata(tekst):
    return '<![CDATA[' + tekst.replace(']]>', ']]]]><![CDATA[>') + ']]>'


def skript_klasse(filnavn):
    for ende, klasse in (('.server.lua', 'Script'), ('.server.luau', 'Script'),
                         ('.client.lua', 'LocalScript'), ('.client.luau', 'LocalScript'),
                         ('.lua', 'ModuleScript'), ('.luau', 'ModuleScript')):
        if filnavn.endswith(ende):
            return klasse, filnavn[:-len(ende)]
    return None, None


def item(klasse, navn, kilde=None, egenskaper=None, barn=()):
    linjer = [f'<Item class="{klasse}" referent="{ref()}">', '<Properties>',
              f'<string name="Name">{escape(navn)}</string>']
    if kilde is not None:
        linjer.append(f'<ProtectedString name="Source">{cdata(kilde)}</ProtectedString>')
    for k, v in (egenskaper or {}).items():
        if isinstance(v, dict) and 'Enum' in v:      # Rojo-format: {"Enum": 4}
            linjer.append(f'<token name="{k}">{int(v["Enum"])}</token>')
        elif isinstance(v, bool):
            linjer.append(f'<bool name="{k}">{"true" if v else "false"}</bool>')
        elif isinstance(v, (int, float)):
            linjer.append(f'<double name="{k}">{v}</double>')
        else:
            linjer.append(f'<string name="{k}">{escape(str(v))}</string>')
    linjer.append('</Properties>')
    linjer += list(barn)
    linjer.append('</Item>')
    return '\n'.join(linjer)


def fra_sti(sti, navn, klasse=None):
    if os.path.isfile(sti):
        k, _ = skript_klasse(os.path.basename(sti))
        with open(sti, encoding='utf-8') as fh:
            return item(klasse or k, navn, fh.read())
    barn, init = [], None
    for fil in sorted(os.listdir(sti)):
        full = os.path.join(sti, fil)
        if fil.startswith('.'):
            continue
        k, base = skript_klasse(fil)
        if base == 'init':
            init = (k, full)
            continue
        if os.path.isdir(full):
            barn.append(fra_sti(full, fil))
        elif k:
            barn.append(fra_sti(full, base))
    if init:
        with open(init[1], encoding='utf-8') as fh:
            return item(init[0], navn, fh.read(), barn=barn)
    return item(klasse or 'Folder', navn, barn=barn)


def fra_node(navn, node):
    barn = [fra_node(k, v) for k, v in node.items() if not k.startswith('$')]
    klasse = node.get('$className', navn)
    if '$path' in node:
        sti = os.path.join(ROT, node['$path'])
        return fra_sti(sti, navn, node.get('$className'))
    return item(klasse, navn, egenskaper=node.get('$properties'), barn=barn)


# Ting som importeres i Studio og skal overleve en ny bygging: {navn i Studio: navn vi gir det}.
# Import 3D kaller modellen opp etter glTF-scenen, og Blenders standard er «Scene».
BEHOLD = {'GrapplerModeller': 'GrapplerModeller', 'Scene': 'GrapplerModeller'}


def behold_fra_gammel(sti):
    """Hent importerte modeller (og SharedStrings de bruker) fra en place som er lagret i Studio,
    så de ikke forsvinner når koden bygges på nytt."""
    if not os.path.exists(sti):
        return [], ''
    try:
        rot = ET.parse(sti).getroot()
    except ET.ParseError as e:
        print('Advarsel: kunne ikke lese', sti, e)
        return [], ''
    funnet = {}
    for tjeneste in rot.findall('Item'):
        if tjeneste.get('class') not in ('Workspace', 'ServerStorage'):
            continue
        for it in tjeneste.findall('Item'):
            navn = it.find("Properties/string[@name='Name']")
            if navn is None or navn.text not in BEHOLD or it.get('class') != 'Model':
                continue
            nytt = BEHOLD[navn.text]
            if nytt in funnet:
                continue
            navn.text = nytt
            funnet[nytt] = ET.tostring(it, encoding='unicode')
    funnet = list(funnet.items())
    delte = rot.find('SharedStrings')
    return [x for _, x in funnet], (ET.tostring(delte, encoding='unicode') if delte is not None and funnet else '')


def main():
    with open(os.path.join(ROT, 'default.project.json')) as fh:
        prosjekt = json.load(fh)
    tre = prosjekt['tree']
    ut = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROT, 'build', prosjekt['name'] + '.rbxlx')
    beholdt, delte = behold_fra_gammel(ut)
    tjenester = [fra_node(k, v) for k, v in tre.items() if not k.startswith('$')]
    if beholdt:
        tjenester = [t for t in tjenester if not t.startswith('<Item class="ServerStorage"')]
        tjenester.append(item('ServerStorage', 'ServerStorage', barn=beholdt))
        print('Beholdt fra forrige versjon:', ', '.join(sorted(set(BEHOLD.values()))))
    xml = ('<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" '
           'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
           'xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">\n'
           + '\n'.join(tjenester) + '\n' + delte + '\n</roblox>\n')
    os.makedirs(os.path.dirname(ut), exist_ok=True)
    with open(ut, 'w', encoding='utf-8') as fh:
        fh.write(xml)
    print('Skrev', os.path.relpath(ut, ROT))


if __name__ == '__main__':
    main()
