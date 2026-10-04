# GRAPPLER — notater for Claude

Roblox-spill med gripekrok mellom flytende øyer, for Pål (og Sander). Fri lek, ingen boter, flerspiller.
Norsk i kode, kommentarer, commits og svar. Les `docs/ROBLOX-OPPSKRIFT.md` før du endrer noe.

## Før du sier «ferdig»
1. `tools/sjekk.sh`
2. `python3 tools/test_luau.py test/sving.test.lua` — alle øyene skal kunne nås fra Hjem.
3. `python3 tools/test_luau.py test/spill.test.lua --mock` — skal ende med «INGEN FEIL».
4. Endret øyene? `test/oyer.test.lua` + `tools/vis_oyer.py`, og se på bildet.
5. Endret modeller? Bygg i Blender og SE på `assets/previews/_ark.png`.

## Arkitektur
- `shared/Krok.lua` er krokfysikken (ren matematikk): krok inne/ute/fest/tilbake, bevegelse bakke/hekta/flyr.
  Klienten kjører den for sin egen figur og setter `AssemblyLinearVelocity` i Stepped mens du henger/flyr.
  Humanoid styrer når du står på bakken.
- Siktet er kamerastrålen (skulderkamera med låst mus, `client/Kamera.lua`).
- Andre ser tauet ditt via remoten `Krok` → serveren videresender `Hendelse("krok", ...)`.
- Rykk/flyspark avgjøres på serveren (`server/Kamp.lua`); offeret får `Knuff` (klienten eier fysikken),
  treningsdukker (tag «Dukke») får farten direkte.
- Øyene er voksel-terreng fra `shared/Oyer.lua` (`server/Oyterreng.lua`), pynt og broer i `server/Verden.lua`.
