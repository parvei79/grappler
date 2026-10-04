# Roblox-oppskrift: spill og 3D-modeller laget med kode

Hvordan vi lager Roblox-spill der Claude skriver all koden, bygger 3D-modellene i Blender og tester
spillet på Macen før Pål trykker Play. BONK-ARENA (`~/Projects/bonk-arena`) var det første spillet.
KAOS-KART (`~/Projects/kaos-kart`) er det mest komplette, og det er det du bør kopiere fra.

## Arbeidsflyten

```
tools/blender/bygg_modeller.py ──Blender uten vindu──▶ assets/<Navn>Modeller.glb ──Import (Studio, én gang)──┐
                               └─────────────────────▶ src/shared/ModelInfo.lua (størrelser, punkter)        │
src/**/*.lua ──tools/sjekk.sh (luau-analyze)──▶ tools/test_luau.py (tester + Roblox-etterligning)            │
            └──python3 tools/bygg_place.py──▶ build/<Navn>.rbxlx ◀── modellene beholdes ved ny bygging ──────┘
                                                     │
                                       åpnes i Studio (Cmd+O) ▶ Play (F5) ▶ Claude leser loggen
```

1. **Modeller:** `Blender -b --factory-startup -P tools/blender/bygg_modeller.py` bygger alt, rendrer
   kontrollbilder til `assets/previews/` og skriver `ModelInfo.lua`. **Se alltid på `_ark.png`** før du går
   videre. For sammensatte ting (en kart av flere deler) lages et montasjebilde.
2. **Sjekk:** `tools/sjekk.sh` kjører `luau-analyze` (`brew install luau`) på all koden. `.luaurc` lister
   Roblox-globalene, så bare ekte feil vises: skrivefeil i lokale navn, syntaksfeil og typefeil.
3. **Test:** `python3 tools/test_luau.py test/<x>.test.lua [--mock]` (se Testing nedenfor).
4. **Bygg:** `python3 tools/bygg_place.py` lager `build/<Navn>.rbxlx` ut fra `default.project.json`.
5. **Studio:** Åpne `.rbxlx` med **File → Open from File… (Cmd+O)**. Første gang: **Import** (Home-fanen),
   velg `.glb`, trykk *Start Import* og lagre med Cmd+S. Koden finner modellene selv og flytter dem til ServerStorage.
6. **Ny bygging** tar vare på den importerte modellen (`BEHOLD` i `bygg_place.py`). Etterpå må Pål lukke
   fanen i Studio **uten å lagre** og åpne fila på nytt. Studio oppdager ikke endringer, og lagring
   overskriver den nye koden.
7. **Feilsøking:** Studio skriver Output til `~/Library/Logs/Roblox/*_Studio_*_last.log`. Les den nyeste
   selv etter at Pål har trykket Play. Våre egne linjer starter med `[KAOS]`, `[BONK]` osv.

Filoppsettet følger Rojo (`*.server.lua`, `*.client.lua`, `*.lua`, `default.project.json`), så prosjektet kan
bytte til `rojo serve` for live-synk.

## Gjenbrukbare filer (fra kaos-kart)

| Fil | Hva |
|---|---|
| `tools/blender/rbxlib.py` | Blender-bibliotek: palett (16×16), `kasse`, `sylinder`, `kule`, `krystall`, `ring`/`bue`, `plate`, `staver`, `blad` (palmeblad), lakk-modeller, eksport, kontrollark |
| `tools/bygg_place.py` | Mini-`rojo build`: støtter `$properties` med `{"Enum": n}`, beholder importerte modeller |
| `tools/sjekk.sh` + `.luaurc` | Luau-sjekk av all kode |
| `tools/test_luau.py` + `test/shims.lua` | Kjør rene moduler med `luau` (Vector3, CFrame, Random, Color3, Enum etterlignet) |
| `test/roblox_mock.lua` | Roblox-etterligning: instanser, signaler, task-planlegger med falsk klokke, tjenester, terreng som validerer voksler, stråler, enkel fysikk, remotes mellom server og klient |
| `tools/vis_bane.py` | Tegner bane og høydekart til PNG (egen PNG-skriver, ingen avhengigheter) |
| `tools/finn_lyd.py` | Søk i Roblox sitt gratis lydbibliotek (Creator Store) |
| `src/server/Modeller.lua` | Finner importerte modeller (også om de heter «Scene»), skalerer og plasserer dem med origo |
| `src/shared/Spline.lua` | Sentripetal Catmull-Rom + jevn sampling |
| `src/shared/KartFysikk.lua` | Arkade-kjøretøy (svev, drift, miniturbo, hopp, triks, treff) som ren matematikk |

## Testing uten Studio

- **Rene moduler** (bane, fysikk, AI, terrengmatte): skriv dem uten Instance og workspace, og test dem med
  `krev("shared/Bane")` i en testfil. Skriv `DATA:{json}`-linjer for å tegne/analysere resultatet.
- **Simuler spillet:** `test/kjoring.test.lua` kjører boter med den ekte kjørefysikken og bot-hjernen på en
  forenklet bakkemodell. Den fant feil i hopp-lengde, respawn-sted, bremsing og drift før noen trykket Play.
- **Hele serveren og klienten:** `--mock` laster `test/roblox_mock.lua`. `server.test.lua` kjører
  `Main.server.lua` og et helt løp, og `klient.test.lua` lar en robotspiller kjøre gjennom klientkoden.
  `server_modeller.test.lua` legger inn falske importerte modeller.
- Etterligningen er streng der det lønner seg. Ukjente metoder gir feil, og `WriteVoxels` sjekker
  tabellstørrelser. `Sound:Play()` uten `SoundId`, `SetAttribute` med ugyldig type og `SetNetworkOwner`
  på forankrede deler gir også feil. Fysikk, kollisjoner og grafikk må fortsatt testes i Studio.

## Modell-konvensjoner (Blender → Roblox)

- **1 Blender-enhet = 1 stud.** En R15-figur er ca. 5 studs høy, og en kart er ca. 9–11 lang.
- **Aksene:** Blender (x, y, z) blir Roblox (x, z, −y). Bygg «opp» langs +Z og «forover» langs +Y. Forsiden
  havner da på LookVector i Roblox.
- **Origo:** Bygg hver modell rundt sitt eget origo (bakken midt under). ModelInfo gir `str` (størrelse),
  `midt` (bbox-midten relativt til origo), `grep` (verktøy, relativt til midten) og navngitte `punkter`
  (relativt til origo). Plassering: `del.CFrame = origoCFrame * CFrame.new(midt)` (`Modeller.plasser`).
- **Palett:** 16×16 ruter à 16 px. Registrer farger på modulnivå (før første del). Én tekstur for alt.
- **Lakk:** `ferdig_modell(..., lakk=True)` gir hvitt materiale uten tekstur. I Roblox: `TextureID = ""`
  og `Color = spillerfarge`.
- **Import:** Import navngir modellen etter glTF-scenen. `eksporter_glb(sti, navn)` setter den, ellers blir
  det «Scene». Hver modell blir `<Navn>_Node` (Model) med MeshPart `<Navn>`. Størrelsene kommer inn
  1:1 i studs, og aksene stemmer.
- **Delte jobber:** En hjelpeagent kan bygge pynt i egen modul (`rekvisitter.py`, farger med prefiks `r_`).
  Hovedskriptet importerer modulen og kaller `bygg_alle(x)`.

## Roblox-feller vi har lært

- **Studio på Mac åpner ikke filer via `open -a RobloxStudio fil.rbxlx`.** Det starter bare en ny instans på
  startsiden. Bruk File → Open from File… (Cmd+O).
- **En ny place uten Lighting i fila får Technology = Compatibility, ingen skygger og omriss på.** Sett det i
  `default.project.json`: `"Lighting": {"$properties": {"Technology": {"Enum": 4}, "GlobalShadows": true, "Outlines": false}}`
  (4 = Future). `Technology` kan ikke settes fra skript.
- **Store kart:** `"Workspace": {"$properties": {"StreamingEnabled": false}}`, ellers kan klienten mangle deler.
- **Kjøretøy:** Usynlig rotdel med `AlignOrientation`. Sett `AssemblyLinearVelocity` hvert `Stepped` (før
  fysikken), og la stråler holde svevehøyden. Svevingen gjør at kantsteiner og skjøter ikke hekter.
  Friksjon 0 på rotdelen. Les faktisk fart tilbake for å oppdage vegger og dytt.
- **Spilleren i setet:** `Seat:Sit(hum)` fra serveren, alle figurdeler `Massless` i en kollisjonsgruppe som
  ikke kolliderer. `SetNetworkOwner(spiller)` på rotdelen etterpå. Hopp av på klienten
  (`SetStateEnabled(Jumping, false)`), og ta SPACE med `ContextActionService` (Sink).
- **Klienten eier spillerens fysikk.** Serveren kan ikke kaste eller flytte den direkte. Send `Truffet`/`Plasser`
  til eieren. Boter eies av serveren (`SetNetworkOwner(nil)`).
- **Input på alle plattformer:** `PlayerModule:GetControls():GetMoveVector()` gir WASD, piltaster, spak og
  mobil i ett. Ekstra knapper med `BindActionAtPriority(..., true, ...)` blir automatisk mobilknapper.
- **Terreng fra kode:** `WriteVoxels` i biter på 64 studs, med fyllgrad (0–1) i overflatevokselen for myk
  overflate. Over bakken og under havnivå: Water. Tunneler: `FillBlock(..., Air)` etterpå. Glatt terrenget
  mot veiens høyde (med dosering) i et belte rundt veien, så veien aldri ligger under bakken.
- **Lange løkker** (terreng) må ha `task.wait()` innimellom, ellers får skriptet tidsavbrudd.
- **Lyd:** Katalogen har tusenvis av gratis lyder fra ProSoundEffects/APM (finn dem med `tools/finn_lyd.py`).
  Innebygde lyder (`rbxasset://sounds/...`) er få: ouch, oof, impact_explosion_03, action_jump m.fl.
- **NPC-er:** `Animate`-skriptet kjører ikke på NPC-er. Spill animasjoner via Animator på serveren.
  Standard R15: sitt 2506281703, idle 507766666, walk 507777826, jump 507765000, fall 507767968, toolnone 507768375.
- **`CollisionFidelity` kan ikke settes fra skript.** Bruk en usynlig kollisjonsklosse og legg mesh oppå
  (`CanCollide = false`).
- **`Tool.Activated` fyrer også på serveren.** `RequiresHandle = false` for verktøy uten modell.
- **`Explosion` med `BlastPressure = 0` og `DestroyJointRadiusPercent = 0`** gir bare effekten.
- **Tekst:** `Enum.Font.FredokaOne` passer en tøysete stil.
- **Hoppeputer/ramper:** utgangsfart = flat avstand / T + opp (Δy / T + ½·g·T), g = 196,2.

## Sjekkliste: nytt spill

1. Ny mappe `~/Projects/<spill>`, `git init`. Kopier `tools/`, `test/shims.lua`, `test/roblox_mock.lua`,
   `.luaurc`, `.gitignore`, `default.project.json`, `src/server/Modeller.lua` og denne fila. Endre `BEHOLD`.
2. Skriv modellene (palett + noen modeller), bygg og se på kontrollarket.
3. Skriv ren logikk (bane, fysikk, regler) som moduler uten Instance, og test dem med `luau`.
4. Skriv server og klient. Kjør `tools/sjekk.sh` og testene med `--mock` til de sier INGEN FEIL.
5. `python3 tools/bygg_place.py`, la Pål åpne, importere og trykke Play, og les loggen.
6. Nye feller skrives inn her **og** i skillen `~/.claude/skills/roblox-spill/SKILL.md`.

## Hva Pål må gjøre selv

- Være logget inn i Roblox Studio (Import laster opp modellene til kontoen).
- Importere `.glb` én gang per modellsett.
- Trykke Play og teste. Claude ser loggen, men ikke skjermen.
- Publisere spillet (File → Publish to Roblox) når det skal deles. Det er kontoeierens valg.
