# GRAPPLER

Sving deg mellom flytende øyer med gripekrok! Skyt kroken mot øyer, bygninger, svevesteiner, luftskipet
eller andre spillere. Du blir dratt mot festet og kan svinge rundt med ekte momentum. Slipp når du vil,
så flyr du videre med farten og retningen du har.

- **Rykk:** treffer kroken en annen spiller (eller en treningsdukke), blir de rykket mot deg.
- **Flyspark:** fly inn i noen i full fart, så sparker du dem av gårde. Jo mer skade de har, jo lenger flyr de.
- Fri lek uten poeng. Faller du ned i skyene, kommer du tilbake på Hjem.
- Ni øyer med hvert sitt tema: Hjem (landsby med vindmølle og treningsdukker), Soppskogen, Krystallgrotta,
  Ruinene, Snøtoppen, Ørkenøya, Jungelen, Lavaøya og Tårnøya. I tillegg er det svevesteiner, hengebroer og et luftskip som sirkler.
- Laget for flere spillere: alle ser alle tau, og serveren avgjør rykk og spark.

## Kom i gang

```bash
/Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup -P tools/blender/bygg_modeller.py
tools/sjekk.sh
python3 tools/test_luau.py test/spill.test.lua --mock
python3 tools/bygg_place.py
```

Åpne `build/Grappler.rbxlx` i Studio (Cmd+O). Første gang: **Import** → `assets/GrapplerModeller.glb` →
**Start Import** → Cmd+S. Trykk **Play**.

## Styring

| | Mus og tastatur | Mobil |
|---|---|---|
| Skyt kroken / hold deg fast | Hold venstre musknapp | Hold KROK |
| Slipp og fly videre | Slipp knappen | Slipp KROK |
| Sving / styr i lufta | WASD | Styrespak |
| Trekk deg raskere inn | SPACE | – |
| Se rundt | Musa (sikte midt på skjermen) | Dra på høyre side |

Siktet er grønt når kroken når fram, rødt når du sikter på en motstander, og grått når det er for langt.

## Tester

```bash
python3 tools/test_luau.py test/oyer.test.lua --data /tmp/oyer.json && python3 tools/vis_oyer.py /tmp/oyer.json -o assets/previews/_oyer.png
python3 tools/test_luau.py test/sving.test.lua      # krokfysikken: kan alle øyene nås?
python3 tools/test_luau.py test/spill.test.lua --mock   # hele spillet med en robotspiller
```

Juster følelsen i `src/shared/Config.lua` (krokfart, inntrekk, maksfart, rykk, spark) og øyene i `src/shared/Oyer.lua`.
