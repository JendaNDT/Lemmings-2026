# Výkon Androidu – rc3 (7. 10. 2026)

Podnět: nízké FPS na tabletu označeném uživatelem „Lenovo IdeaPad 11“.
Přesný model, rozlišení ani naměřené FPS zařízení zatím nemáme. K cloudu
není připojený Android přes adb; následující čísla nejsou měřením tohoto tabletu.

## Oprava

Android měl návrhové rozlišení 1280 × 720, ale režim `canvas_items` stále
vykresloval do plného rozlišení displeje. Override
`display/window/stretch/mode.android="viewport"` skutečně omezuje interní
rozlišení. Při poměru 16:10 je výsledkem 1280 × 800; při 20:9 1600 × 720.
Zachovává poměr stran i logické souřadnice a zvětšuje výsledný obraz.
Cena za menší zátěž je měkčí obraz včetně rozhraní na displejích s vysokým
rozlišením. Desktopový profil zůstává `canvas_items`.

`PaperGrass` dříve odesílala dva polygony na každé stéblo a přestavovala je
i při pauze. Nyní odešle jeden společný indexovaný seznam trojúhelníků,
se stejnými barvami a pořadím překrývání. Geometrii obnoví při změně času,
masky nebo explicitním překreslení (například při nastavení tématu).
Kopání a stavění dál vycházejí z téže masky; pravidla ani simulační čas se nemění.

## Měření skutečného vykreslování

Godot 4.7 stable, Linux x86_64, OpenGL Compatibility, Mesa llvmpipe
(LLVM 19.1.7, 4 CPU vlákna). Softwarový renderer v cloudu; nejde o mobilní GPU.
První mise, tik 130, pauza, střední kvalita, mobilní rozhraní, okno 2560 × 1600.
Každý běh má 30 zahřívacích a 100 měřených snímků. Hudba je pro izolaci
renderu vypnutá, snímání obrázků probíhá mimo časovaný úsek.

| Varianta | Render | Kreslicí příkazy celé scény | Medián snímku (dva běhy) | p95 (dva běhy) |
|---|---|---:|---|---|
| rc2, původní tráva | 2560 × 1600 | 1197 | 217,89 / 223,21 ms | 243,94 / 249,17 ms |
| Jen menší viewport, původní tráva | 1280 × 800 | 1197 | 76,88 / 77,91 ms | 88,53 / 88,44 ms |
| rc3, viewport a společná geometrie trávy | 1280 × 800 | 84 | 69,05 / 72,01 ms | 87,98 / 88,28 ms |

Tráva v této scéně klesla z 1114 kreslicích příkazů na jeden. Změna viewportu
snížila počet vykreslovaných pixelů čtyřikrát. To je ověřená úspora práce,
nikoli příslib konkrétních FPS na zařízení. Záznamy jsou v
[`performance/android-rc3/`](performance/android-rc3/).

Opakování měření aktuálního zdrojového stromu v grafickém Godotu:

```bash
godot --path . --audio-driver Dummy --rendering-method gl_compatibility \
  --script res://scripts/benchmark_mobile.gd -- --mobile-preview
```

Volba `--native` za `--mobile-preview` změří plné rozlišení se **současnou**
trávou. Pro úplný původní stav použij základ `c0166d5` a tentýž benchmark.
Výstup `TABLET_RENDER` obsahuje profil, skutečné rozlišení, ovladač a oba běhy.
Měření spouštěj bez dalších grafických kontrol souběžně; scénář je izolovaný
render, ne zátěžový test plného davu ani měření živého kopání.

## Regrese

- Raster trávy před/po: sedm snímků (čtyři fáze větru, vykopaná oblast,
  překrytí cihlou, úplné odstranění). V každém shoda všech 819 200 bytů RGBA;
  osm kontrol včetně prázdného výsledku po odstranění terénu prošlo.
- `scripts/qa_mobile_render.gd`: 16 grafických kontrol. Skutečné rozlišení,
  poměr stran a vstup v pixelech displeje na 2560 × 1600, 1920 × 1200
  a 2400 × 1080. Tlačítko pauzy reaguje, dotyk přidělí právě jednu dovednost
  a tažení přesune kameru bez herního příkazu.
- Standardní kontrola `python scripts/check.py --benchmark` ověřuje parser,
  lint, import, podklady, herní testy včetně hudby a deterministickou simulaci.
  Prošlo 99 GDScriptů, 19 sad, 474 kontrol; log je součástí záznamů.
- APK má stejnou identitu a certifikát jako rc2, vyšší versionCode 1000003.
  Instalovat přes rc2; odinstalací by uživatel přišel o svůj postup.
  Podpis v2/v3, zarovnání na 16 KB i obsah exportu prošly kontrolou;
  z rozbaleného APK se načetly všechny čtyři hudební streamy i Android override.

Grafický regresní průchod:

```bash
godot --path . --audio-driver Dummy --rendering-method gl_compatibility \
  --script res://scripts/qa_mobile_render.gd -- --mobile-preview
```

## Ověření na tabletu

Po aktualizaci otevřít tutéž misi, zapnout **Nastavení → Zobrazení → Ukazovat
snímky za sekundu (FPS)** a porovnat začátek i větší dav za stejné kvality.
Poznamenat přesný model zařízení, FPS, misi a počet postav. Pokud se trhá
jen animace při vysokém FPS, zkusit **Pohyb postav: Plynulý**; výchozí
stop-motion je záměrná stylizace, nikoli měřítko snímkové frekvence.
