# Etapa 4 — všech osm dovedností

Společná simulace, provizorní 2.5D zobrazení a ovládání nyní podporují všech
osm dovedností. Technické dokončení této etapy neznamená finální grafiku.
Schválený modelínový mockup zůstává výtvarným cílem; současné terény,
postavy, nasvícení a pozadí jeho kvality nedosahují.

## Pravidla nových dovedností

| Dovednost | Chování |
|---|---|
| Lezec | Trvalá vlastnost. Na vysoké zdi začne stoupat, na hraně pokračuje chůzí; pod stropem se otočí a spadne. Neleze po neviditelném okraji mapy. |
| Padák | Trvalá vlastnost, kombinovatelná s lezcem i pracovní činností. Po 16 pixelech pádu otevře padák; lze jej přidělit i později během pádu. Přistání je bezpečné, propast za okrajem mapy zůstává smrtelná. |
| Horník | Každé čtyři tiky razí průchozí tunel o dva pixely dopředu a jeden dolů. Ocel zastaví celý úder, po proražení do prázdna začne padat. |
| Bombič | Odpočet 85 tiků (5 herních sekund) běží souběžně s dosavadní činností. Exploze odstraní hlínu a cihly v kruhu o poloměru 16, zachová ocel a odstraní bombiče. Ostatní postavy přímo nezabíjí; může jim odebrat půdu. |

Trvalé vlastnosti ani bomba neresetují pracovní stav nebo jeho čas.
Vlastnost nejde přidělit podruhé a bomba nejde přidělením znovu načasovat.
Odcházející a umírající postavy další dovednost nepřijímají.
Vstup do východu před výbuchem odpočet zruší. Pokud odpočet vyprší před
pohybem ve stejném tiku, má přednost výbuch.

Čekající výbuch zabrání předčasnému konci levelu. Samotní blokaři také
neukončí level, pokud ještě zbývá bombič, kterým lze situaci změnit.
Vypršení času má nadále přednost před čekajícími akcemi.

Hromadné ukončení zavře líheň a každé dva tiky zapálí další aktivní
postavu. Nespotřebovává zásobu bombičů, zachovává již běžící odpočty
a zapisuje se do stejného replaye jako dovednosti a vypouštění.
Rozhraní vyžaduje potvrzení; dialog pozastaví čas, blokuje přidělování
a při zavření obnoví předchozí stav pauzy. Pauza zastaví i bomby.

## Hratelné situace

V dolní liště je výběr pěti scén. Restart obnoví vybranou scénu.

| Mise | Ověřené řešení | Výsledek |
|---|---|---|
| První kroky | Razič, stavitel, kopáč podle původního řešení | 20/20, 1 014 tiků |
| Lezec a padák | Každé postavě před zdí přidělit obě trvalé vlastnosti | 6/6, 668 tiků |
| Šikmý tunel | První postavě přidělit horníka na x=80 | 6/6, 971 tiků |
| Cesta skrz zeď | Na x=168 zastavit první postavu blokařem a přidělit bombu | 3/4, 773 tiků |
| Všech osm dovedností | Původní terén s dvaceti kusy každé dovednosti pro volné zkoušení | Ověřena lišta, přechody a restart |

Horník používá dodaný klip `mine` a krumpáč. Lezec má provizorní úpravu
pózy chůze, padák je procedurální mesh se závěsy, odpočet je čitelný
nad postavou. Výbuch i horník vyvolají úlomky a aktualizují prostorový terén.
Diagnostické 2D zobrazení rozpoznává stejné stavy. Žádný vizuální efekt
neurčuje kolizi, čas nebo výsledek hry.

## Ověření

- `python scripts/check.py`: 53 GDScriptů, osm sad, 184 kontrol; čistý
  import a spuštění. Všech 50 přejatých podkladů nadále odpovídá manifestu.
- Nové mechanické testy ověřují oba směry, stropy, okraje, ocel, pozdní
  padák, kombinace, přesný výbuch, konec levelu a JSON replay včetně událostí.
- Test skutečné scény kontroluje osm tlačítek v rozlišení 1280 × 720,
  dialog, přechody mezi misemi, restart, vizuální padák a zastavení odpočtu.
- `scripts/qa_stage4.gd` dokončil všechny tři nové mise přes simulované
  dotyky v Compatibility i Forward+ rendereru; přijatých 12, 1 a 2 příkazy.
  Stejný nový průchod prošel také nad soubory vytaženými z APK 0.3.0.
- `scripts/qa_3d.gd -- --touch --mobile-preview` zachoval původní výsledek
  20/20; všechny tři dovednosti vybrané přes skutečný HUD.
- Snímky a protokoly jsou v `build/phase4/`; nejde o test na nativním Androidu.
- APK 0.3.0 má ověřené CRC, manifest, ARM32/ARM64, 16KiB zarovnání
  a podpis v2/v3 shodný s verzí 0.2.1. Podrobnosti jsou v `ANDROID_DEMO.md`.

Opakování grafického průchodu v prostředí s grafickým serverem:

```bash
godot --path . --rendering-method gl_compatibility --audio-driver Dummy \
  --resolution 1280x720 --script res://scripts/qa_stage4.gd \
  -- --mobile-preview --capture-dir=/tmp/lemmings-stage4
```

Přetrvává omezení softwarového ovladače llvmpipe pro V-Sync a desktopové
2D MSAA. Testy nedokládají výkon, instalaci ani běh aplikace na konkrétním
telefonu, Macu nebo Windows. Herní výběr scén zatím neukládá postup;
plné menu a ukládání zůstávají v etapě 6.
