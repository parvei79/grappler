#!/usr/bin/env python3
"""
Søk i Roblox sitt gratis lydbibliotek (Creator Store) etter lyder og musikk som kan brukes i alle spill.

    python3 tools/finn_lyd.py "go kart"                    -> verifiserte skapere
    python3 tools/finn_lyd.py "explosion" 7462895450 30    -> bare ProSoundEffects, 30 treff
    python3 tools/finn_lyd.py "surf rock" -                -> alle verifiserte (musikk fra APMOfficial m.fl.)

Gode kilder: ProSoundEffects (id 7462895450, tusenvis av SFX lastet opp av Roblox i 2022),
APMOfficial (musikk), Roblox (klassiske lyder som «Launching rocket»).
Bruk ID-en som "rbxassetid://<id>". Sjekk Studio-loggen etter Play: private/slettede lyder gir feil der.
"""
import json, sys, urllib.request, urllib.parse, re
def get(url):
    with urllib.request.urlopen(url, timeout=20) as r:
        return json.load(r)
def sok(kw, n=30, skaper=None):
    ekstra = f"&creatorTargetId={skaper}&creatorType=1" if skaper else "&includeOnlyVerifiedCreators=true"
    u = f"https://apis.roblox.com/toolbox-service/v1/marketplace/3?keyword={urllib.parse.quote(kw)}&num={n}{ekstra}"
    ids = [d['id'] for d in get(u).get('data', [])]
    ut = []
    for i in range(0, len(ids), 30):
        det = get("https://apis.roblox.com/toolbox-service/v1/items/details?assetIds=" + ",".join(map(str, ids[i:i+30])))
        for it in det.get('data', []):
            a, c = it['asset'], it['creator']
            desc = a.get('description', '')
            kat = re.search(r'Category: ([^\n]*)', desc)
            ut.append((a['id'], a['name'], c['name'], a.get('duration'), kat.group(1) if kat else '', (a.get('audioDetails') or {}).get('audioType')))
    return ut
skaper = sys.argv[2] if len(sys.argv) > 2 and sys.argv[2] != '-' else None
n = int(sys.argv[3]) if len(sys.argv) > 3 else 15
for r in sok(sys.argv[1], n, skaper):
    print(f"{r[0]:>16} | {r[3]!s:>4}s | {r[2][:14]:14} | {r[1][:62]} | {r[4][:28]} | {r[5]}")
