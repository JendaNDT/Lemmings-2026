# Lemmings 2026 – architektura

Návrh, jak je hra postavená a proč. Psáno tak, aby se v tom vyznal
i neprogramátor, a zároveň aby se podle toho dalo dál stavět
(i s pomocí AI).

**Aktualizace směru:** výchozí scéna `main/game_origami.tscn` je čistě
2D papírové (origami) zobrazení nad společnou 2D simulací, s paralaxním
posunem i zoomem (oddíl 7a). 2.5D prototyp `main/game_3d.tscn` a původní
jednoduché 2D `main/game.tscn` zůstávají pro porovnání. První distribuční
test míří na macOS, později Windows a Android. Aktuální pořadí prací:
[`PLAN_VYVOJE.md`](PLAN_VYVOJE.md).

---

## 1. Shrnutí v pěti bodech

1. **Logika a grafika jsou úplně oddělené.** Logika (simulace) počítá
   s pixely jako originál z roku 1991. Grafika to jen „obkresluje“
   v moderním rozlišení a s efekty.
2. **Terén je mapa pixelů.** Každý pixel je buď prázdný, hlína, nebo ocel.
   Kopání = mazání pixelů. Hezký vzhled terénu maluje shader.
3. **Každý stav lumíka je jeden soubor.** Chodec, kopáč, stavitel…
   Nová dovednost = nový soubor, nic dalšího se nerozbije.
4. **Čas běží v pevných krocích (17× za sekundu).** Díky tomu je hra
   vždy stejná (deterministická) → půjde udělat replay, přetáčení času
   a zrychlení bez chyb. Grafika mezi kroky plynule dopočítává pohyb.
5. **Levely se kreslí přímo v editoru Godotu** pomocí mnohoúhelníků.
   Žádný vlastní editor zatím není potřeba.

---

## 2. Hlavní myšlenka: šachovnice a figurky

Představ si šachy. Pravidla říkají, kam smí kůň skočit – to je
**logika**. Jestli jsou figurky dřevěné, skleněné nebo 3D na
obrazovce – to je **grafika**. Pravidla se nemění podle toho,
jak figurky vypadají.

U nás je to stejné:

```
  OVLÁDÁNÍ (myš, klávesy, dotyk)
        │  „dej kopáče lumíkovi č. 7“
        ▼
  ┌──────────────────────────────────────┐
  │  SIMULACE   (složka sim/)             │
  │  • čistá logika, žádná grafika        │
  │  • 17 kroků za sekundu                │
  │  • jen celá čísla, žádná náhoda       │
  └──────────────────────────────────────┘
        │  stav světa + události
        │  („tady se kopalo“, „lumík spadl“)
        ▼
  ┌──────────────────────────────────────┐
  │  GRAFIKA (view/)   ZVUK   UI (ui/)    │
  │  • 60–144 snímků za sekundu           │
  │  • shadery, světla, částice           │
  │  • jen čte, nikdy nemění logiku       │
  └──────────────────────────────────────┘
```

**Proč je to důležité:**

- Grafiku můžeš kdykoli kompletně předělat (třeba i na 3D) a hra se
  bude hrát úplně stejně.
- Chyby se hledají snadno: buď je špatně pravidlo (sim/), nebo
  vykreslení (view/).
- AI, se kterou to vibecoduješ, má jasně dané hranice – když chceš
  „hezčí výbuch“, sahá jen do grafiky.

---

## 3. Simulace (složka `sim/`)

| Soubor | Co dělá |
|---|---|
| `sim_const.gd` | Všechna čísla na jednom místě (rychlosti, výšky, počty cihel…). Ladění pocitu ze hry = změna čísla tady. |
| `terrain_mask.gd` | Logická mapa terénu. Umí: je tu zem? je tu ocel? voda/láva? jednosměrná zeď? vykopej, postav cihlu. |
| `lemming.gd` | Data jednoho lumíka: pozice, směr, stav, počítadla. |
| `level_spec.gd` | Pravidla levelu: kolik lumíků, kolik zachránit, dovednosti, čas, pasti. |
| `level_sim.gd` | Srdce hry: vypouští lumíky, každý krok je posune, hlídá východ a konec levelu. |
| `states/*.gd` | Jeden soubor = jeden stav lumíka. |

### Stavy lumíka (stavový automat)

```
          ┌──────── spadne z okraje ────────┐
          ▼                                  │
  [PADÁ] ──dopadne──► [CHODÍ] ──dovednost──► [KOPÁČ / RAZIČ /
    │                   ▲  │                  STAVITEL / BLOKAŘ]
    │ moc vysoko        │  └── dojde k východu ──► [ODCHÁZÍ] → zachráněn
    ▼                   │
  [SPLÁCNE SE]          └── práce skončí ──┘
    → ztracen
```

Hotové stavy: chodec, padající, splácnutí, odchod východem,
blokař, stavitel (+ krčení rameny), razič, kopáč, lezec, plachtění, horník,
topení a hoření.

Lezení a padák jsou navíc trvalé vlastnosti postavy; odpočet bomby běží
souběžně s aktuálním stavem. Bombič tedy není samostatný pohybový stav.
Hromadné ukončení je třetí společný příkaz (`NUKE`); jeho průběh řídí
simulační tiky. Kombinace a priority popisuje `ETAPA_4_OVERENI.md`.

Nebezpečí (etapa 5): voda → topení, láva → hoření, past sežere jednoho
a dobíjí se (`trap_ready`, `trap_fired` v `LevelSim`). Pořadí v tiku pro
každého lumíka: bomba → stav → pád pod level → láva → voda → past → východ.
Podrobnosti v `ETAPA_5_OVERENI.md`.

### Pravidla simulace (nesmí se porušit)

- V `sim/` **nesmí** být žádné uzly (Node), `Input`, náhoda ani reálný
  čas. Jen čistá data a celá čísla.
- Čas se posouvá jen funkcí `LevelSim.tick()`.
- Dovednosti, vypouštění a hromadné ukončení vstupují přes `apply_command()`. Provedou se
  okamžitě mezi tiky, také během pauzy. Přijaté příkazy se zapisují do
  `replay_log`: `{tick, kind, target, value}`. Tik N označuje okamžik
  po dokončení N a před N+1; pořadí v poli rozhoduje i ve stejném tiku.
- `SimReplay` přehrává tento záznam na čerstvé simulaci stejného levelu.
  Ze stejného levelu a stejného logu musí vyjít stejný výsledek. Pravidla
  a meze technického replaye jsou v `ETAPA_2_SIMULACE.md`.

---

## 4. Terén: logická mapa + HD vzhled

### Dvě vrstvy

1. **Logická mapa** (`TerrainMask`) – rozlišení jako originál
   (lumík je vysoký 10 px). Podle ní se lumíci pohybují.
2. **Vzhled** (`view/terrain.gdshader`) – shader dostane mapu jako
   texturu a v plném rozlišení obrazovky domaluje:
   - hladké oblé okraje místo kostiček,
   - trávu na horních hranách,
   - vrstvy hlíny, kamínky, stínování do hloubky,
   - ocelové pláty s nýty,
   - cihly od stavitele,
   - nasvícení hran od světla.

Na Full HD je 1 logický pixel ≈ 5–6 pixelů obrazovky, na 4K ≈ 11.
Logika tedy zůstává věrná originálu, ale vypadá to moderně.

### Formát mapy

Každý pixel mapy má 4 bajty (rovnou formát textury, žádné převody):

| Kanál | Význam |
|---|---|
| R | pevný terén |
| G | ocel (nejde prokopat) |
| B | postaveno stavitelem (jen kvůli vzhledu) |
| A | druh buňky `TerrainMask.Special`: 0 nic, 1 voda, 2 láva, 3/4 jednosměrná zeď doleva/doprava |

---

## 5. Levely (složky `level_tools/` a `levels/`)

Level je obyčejná scéna Godotu:

```
Level01  (LevelDefinition – pravidla v Inspectoru)
├── Terrain
│   ├── LeftWall    (TerrainShape: Dirt)
│   ├── Mesa        (TerrainShape: Dirt)
│   ├── Cave        (TerrainShape: Erase – vyřízne jeskyni)
│   └── SteelPlate  (TerrainShape: Steel)
├── Hatch           (LemmingHatch – odsud padají lumíci)
└── Exit            (LemmingExit – sem mají dojít)
```

- **Terén kreslíš myší** nástrojem pro mnohoúhelníky (Polygon2D).
- Při startu levelu `LevelLoader` všechny tvary „vypálí“ do logické mapy.
- Pozdější tvary přemalují dřívější (jako vrstvy v grafickém editoru).

Každá mise má v Inspectoru **Level Id** – stabilní identifikátor
(malá písmena, číslice, pomlčky, např. `voda-lava-past`). Podle něj se
ukládá postup, takže přejmenování nebo přeřazení mise výsledky hráče
nezničí. Pořadí kampaně určuje `main/campaign.gd` (`Campaign.SCENES`);
název a počty si kampaň čte přímo ze scény. Chybějící id hlásí
`LevelValidator` jako varování u kořene levelu.

Později přibude: kusy terénu jako obrázky (z alfa kanálu se vyrobí
maska), dekorace, světla a částice umístěné přímo ve scéně levelu.

---

## 6. Čas a herní smyčka (`main/game.gd`)

```
každý snímek obrazovky:
  akumulátor += uplynulý čas × rychlost (1× nebo 3×)
  dokud akumulátor ≥ 1/17 s:
      simulace.tick()
  grafika dostane „jak daleko jsme mezi tiky“ (0–1)
  → plynulý pohyb i na 144 Hz monitoru
```

Z toho zadarmo plyne:

- **Pauza** – prostě se netiká. Dovednosti jde přidělovat i v pauze.
- **Zrychlení** – víc tiků za snímek.
- **Replay** – technický `SimReplay` je hotový. Využívá ho i ukládání
  rozehrané mise (oddíl 6a); hráčské přehrávání řešení přijde později.
- **Přetáčení času** (později) – ukládat snímky stavu každých pár
  sekund a dopočítat zbytek z logu.

Smyčka zpracuje nejvýše osm tiků za snímek a zbytek akumulátoru omezí
na jeden tik. Při velké prodlevě tedy hra zpomalí vůči skutečnému času.
Determinismus se vztahuje ke stejným tikům a příkazům, nikoli ke stejným
sekundám na nástěnných hodinách.

---

## 6a. Aplikace, menu a ukládání (etapa 6)

Hlavní scéna je `main/app.tscn` (`App`). Hra (`game_origami.tscn`) se
pro každou misi z menu vytvoří znovu a po návratu do menu se celá uvolní;
restart a další mise běží uvnitř téže instance hry.

```
App (main/app.gd)
├── Backdrop   MenuBackdrop – papírová krajina za menu (bez simulace)
├── MenuAudio  GameAudio – kliknutí v menu
├── Menu       MenuScreens – hlavní menu, výběr misí, nastavení
└── Game       game_origami.tscn – jen během mise
```

| Soubor | Co dělá |
|---|---|
| `main/save_file.gd` | `SaveFile`: bezpečný zápis. Dva řádky – hlavička (hra, verze formátu, SHA-256 dat) a data v JSON. Zápis jde do `.tmp`, ten se ověří, předchozí platná verze se zkopíruje do `.bak` a teprve pak se `.tmp` přejmenuje. Poškozený soubor se odloží jako `.corrupt` a načte se záloha. |
| `main/game_settings.gd` | `GameSettings`: hlasitosti sběrnic, ztlumení, celá obrazovka, pohyb postav, FPS, velikost rozhraní, kvalita efektů, posun kamery, dosah klepnutí, potvrzení Ukončit, vývojové odemčení misí. Každá hodnota má výchozí stav a povolený rozsah. `user://settings.json`. |
| `main/progress.gd` | `Progress`: splněné mise, rekordy (víc zachráněných, při shodě kratší čas), počty pokusů, poslední mise a rozehraný pokus. `user://progress.json`. |
| `main/campaign.gd` | `Campaign`: pořadí misí a jejich údaje čtené ze scén bez vytvoření. |
| `ui/menu_screens.gd`, `ui/settings_panel.gd`, `ui/menu_backdrop.gd` | Obrazovky menu, nastavení (sdílené s pauzou ve hře) a pozadí. |
| `ui/paper_ui.gd` | `PaperUi`: společný papírový vzhled HUDu i menu. |

**Rozehraný pokus** se neukládá jako stav světa, ale jako `replay_log`
a tik. Při „Pokračovat“ ho `SimReplay` přehraje na čerstvé simulaci;
otisk stavu (počty, postavy, maska terénu) ověří, že výsledek sedí. Když
nesedí (jiná verze levelu), pokus se zahodí a mise začne znovu. Ukládá se
při odchodu z mise do menu, při přechodu aplikace na pozadí a při zavření
okna. Obnovená mise začne v pauze.

**Změna formátu:** každý soubor nese verzi. Neznámé nebo poškozené položky
se nahradí výchozími; soubor z novější verze hry se před přepsáním
odloží vedle (`.v2`…). Starší `settings.cfg` (jen ztlumení) se převezme.

Hra dostane `settings` a `progress` od `App`; spuštěná samostatně (editor,
testy) má výchozí nastavení a postup jen v paměti, nic nezapisuje.
Nastavení se uplatňuje hned (signál `GameSettings.changed`), simulaci
neovlivní: kvalita efektů mění jen ozdoby `PaperWorld`, velikost rozhraní
zvětší lišty a herní plocha se posune pod ně.

---

## 7. Grafika 2.5D — implementovaný prototyp

`main/game_3d.tscn` dědí původní hlavní scénu. Sdílí herní smyčku a HUD,
ale vypíná původní 2D prezentaci. `ClayWorld` spojuje následující části:

| Část | Odpovědnost |
|---|---|
| `ClaySpace` | Jeden logický pixel = 0,1 m; +Y logiky směřuje dolů, +Y světa nahoru. |
| `ClayMesher` | Zaoblená přední plocha, zadní plocha a boky proti prázdnu, hloubka 2,4 m. |
| `ClayTerrain` | Oblasti 32 × 32, samostatně sledované revize, sdílená maska a čtyři materiály. |
| `ClayDressing` | Zeleň, rostliny, kamínky a nýty v MultiMesh; oporu kontroluje živá maska. |
| `ClayBackdrop` | Oddělená krajina, mraky a hrad za herní rovinou; sdílené meshe. |
| `ClayActor` | Importovaný GLB, orientace, interpolace a ruční hledání pózy podle simulačního času. |
| `ClayCamera` | Pevný sklon 18°, ortografický zoom a průsečík paprsku s rovinou postav. |
| `ClayFx` | Nejvýše 96 dekorativních hrudek a osm krátkých povrchových deformací. |

Maska zůstává jediným zdrojem kolizí. Její mutace zvýší celkovou revizi
a revize dotčených oblastí včetně sousedů o jednu buňku dál. Žádný renderer
změny nespotřebovává. Renderer navíc porovnává změněné buňky a obnovuje
oblasti v okolí osmi buněk kvůli zaoblení a dekoracím. Plochý vnitřek se
slučuje do obdélníků; na obvodu zůstávají jednotlivé buňky. Pole vzdálenosti
zaobluje přední hranu do hloubky 0,16 m v pásu tří buněk, rohy siluety se
posouvají nejvýše o 0,22 buňky v každé ose. Obsazení středů buněk souhlasí
s maskou; nejde již o přesnou pravoúhlou siluetu. Boky přes hranici oblasti
čtou sousední buňky, takže nevznikají vnitřní stěny. Tráva si pamatuje
původní povrch, po kopání nepřirůstá uvnitř tunelu.
UV používají souřadnice celého levelu, aby textura na švech neposkakovala.

Pracovní klipy jsou časované podle konstant raziče, kopáče a stavitele;
jejich kontaktní fáze odpovídá tiku změny masky. Pauza zastaví i pózu a efekty.
Povrchové promáčknutí mění normály/stínování, hrudky se protahují a odlétají;
nejde o měkkou fyziku terénu. Trvalý otvor je skutečně přestavěný mesh.

Původní podklady jsou v `assets/clay/`, původ a kontrolní součty
v `assets/clay.lock.json`. Nový odvozený model, ikony a Nunito jsou oddělené
v `assets/art_v2/` a `assets/art_v2.lock.json`; původní balíček se nemění.
Technický záznam dosavadní verze je v [`GRAFIKA_04.md`](GRAFIKA_04.md).
Po změnách se kontroluje geometrie, projekce, celý level i výkon; postup
je v [`ETAPA_3_OVERENI.md`](ETAPA_3_OVERENI.md).

## 7a. Grafika 2D origami — výchozí zobrazení

`main/game_origami.tscn` dědí hlavní scénu stejně jako 2.5D varianta:
sdílí herní smyčku, HUD a příkazy. `game.gd` zná prezentaci jen přes
`presentation_path` a volá `setup()`, `update_frame()`, `highlight()`
a kameru (`screen_to_logic`, `logic_to_screen`, `pan_screen`, `zoom_at`).
`PaperWorld` skládá tyto části:

| Část | Odpovědnost |
|---|---|
| `PaperCamera` | Jediná herní transformace logika → obrazovka, zoom 1×–3,2× kolem kurzoru či středu prstů, hranice levelu, klávesy, okraj, kolečko, tažení. |
| `PaperParallax` | Čtyři vodorovně navazující vrstvy (nebe, hory, vesnice, blízký les). Posun i zoom odvozené z kamery: `měřítko = výška/1200 × zoom^exponent`. Spodní řádek se protáhne dolů, takže nevzniká prázdný okraj. Hloubka ostrosti je předem v podkladech (generátor rozmaže vzdálenější vrstvy víc), shader přidá opar. Nebe nese pohyblivé výřezy: plující mraky a mávající ptáčky (`sky.json`), řízené herním časem. |
| `PaperTerrain` | Shader `paper_terrain.gdshader` kreslí terén přímo z masky: listy trhaného papíru složené z vystřižených kusů (natržené švy, překryv, mírný náklon), bílé vláknité okraje, hladký pruh drnu s natrženým okrajem a stínem, ocel s mřížkou jako nalepený díl, harmonikové schody, světlou zadní stěnu výkopu a tmavší jeskyni (i uzavřené dutiny). Měkké stíny dávají mipmapy masky (levné rozmazání). Vodu a lávu (vlnité pruhy, plameny) a šipky jednosměrných zdí čte z textury nebezpečí sestavené z kanálu A masky; přední pruhy hladiny kreslí uzel `HazardSurface` nad postavami. |
| `GameAudio` (`view/game_audio.gd`) | Zvuky pro všechny scény: události simulace → papírové efekty v místě události na obrazovce, smyčky větru, vody a lávy, zvuky rozhraní a znělky. Simulaci jen čte; sběrnice SFX, UI, Ambient a Music (hudba později), omezovač na Master. Podrobnosti v `ZVUK.md`. |
| `PaperGrass` | Papírová tráva rostoucí vzhůru z původního povrchu (body z `PaperTerrain.exposed_surface`); stébla se kývají špičkou podle herního času, trs zmizí s vykopanou zemí nebo pod cihlou. Kreslí se za postavami. |
| `PaperProps` | Líheň (chatka na kůlech, padací dvířka), východ (domek, vlající vlajka), pasti (masožravá rostlina, čelisti podle `trap_fired`/`trap_ready`) a drobné rostlinky svázané s maskou. |
| `PaperActors` | Origami postavy z dílů atlasu; přechody 3 tiky, otočka jako „otočení papírku“. Výchozí stop-motion: póza i poloha po celých ticích, jemné deterministické chvění dílů po 2 ticích, zplácnutí při dopadu, plameny kolem hořící postavy; plynulý režim = funkce `state_ticks + alpha` (klávesa M). |
| `PaperFx` | Papírové ústřižky z událostí, rozkládání cihly, bubliny, kruhy na hladině, plovoucí klobouk, kouř a popel; průběžné efekty jednou za simulační tik (pauza je zastaví), čas efektů běží s herním časem. |
| `PaperForeground` | Nízké trsy rostlin u spodní lišty (rozostřené, blíž než herní rovina), kývají se ve větru; zprůhlední, když je za nimi postava, líheň nebo východ. Vstup nepřijímají. |
| Světlo (`paper_light.gdshader`) | Přičítací vrstva: teplá záře slunce zleva shora a jemné paprsky, pomalu se posouvají s herním časem. |
| Zrnitost (`paper_grain.gdshader`) | Násobící vrstva přes celou herní scénu pod HUDem: papírové žíhání, ztmavení rohů a chladnější strana odvrácená od slunce. |

**Přesnost terénu.** Hrana leží na izočáře 0,5 bilineárně interpolované
masky (bez mipmap; rozmazané úrovně slouží jen ke stínům a okrajům). Šum trhaného okraje je omezený na ±0,4, takže střed každé buňky
(hodnota 0 nebo 1) má vždy stejné obsazení jako simulace. Grafický QA
průchod to kontroluje na skutečném snímku v kontrolním režimu shaderu.
Statická textura si pamatuje původní povrch (drn nepřirůstá v tunelech)
a vnitřek jeskyní; revize masky se pouze čtou.

**Paralaxa a vstup.** Výběr postav i převod dotyku používá jen
`PaperCamera`; vrstvy kamery nemění. Vzdálenější vrstvy se posouvají
i zvětšují méně (exponenty 0,04 / 0,12 / 0,3 / 0,5), herní rovina 1, popředí
mírně více. HUD je samostatná CanvasLayer.

**Animace.** Generátor `assets/origami/source/build_character.py` zapisuje
atlas, kostru a klíčové pózy (`worker_rig.json`); stejný výpočet kloubů
má i náhled. Kontakt nástroje je na tiku změny masky: stavitel
`BUILDER_BRICK_PHASE`, razič, horník a kopáč na začátku cyklu dělitelného
krokem kopání. Pauza zastaví pózu, zrychlení ji zrychlí.

Podklady jsou v `assets/origami/` s původem, licencí a manifestem
`assets/origami.lock.json`. Výsledky ověření jsou v
[`ORIGAMI_OVERENI.md`](ORIGAMI_OVERENI.md).

## 8. Moderní vylepšení hratelnosti

- Zrychlení a pauza (hotovo), přidělování v pauze (hotovo).
- Zvýraznění lumíka pod kurzorem + chytrý výběr (hotovo).
- Přetáčení času o pár sekund zpět, okamžitý restart.
- Replay vlastního řešení, sdílení řešení.
- Výběr jen lumíků jdoucích doleva/doprava (jako v NeoLemmixu).
- Minimapa, přiblížení/oddálení.
- Dotyk (mobil, tablet) a gamepad.
- Editor levelů ve hře (až bude hra hotová).

---

## 9. Struktura složek

```
project.godot        nastavení projektu
main/                aplikace (App), herní smyčka, nastavení, postup, ukládání
sim/                 logika hry (žádná grafika!)
  states/            jeden soubor = jeden stav lumíka
level_tools/         nástroje pro stavbu levelů v editoru
levels/              samotné levely (scény)
view/                grafika: terén, lumíci, efekty, kamera, shadery
                     (paper_* = 2D origami, clay_* = 2.5D prototyp)
ui/                  rozhraní: HUD, menu, nastavení, společný papírový vzhled
tests/               automatické testy simulace (běží bez grafiky)
docs/                dokumentace
```

Podklady (textury, modely, zvuky) jsou v `assets/` se zámky kontrolních součtů.

Protože simulace nepotřebuje grafiku, jde celý level „odehrát“
v testu za pár sekund (`tests/test_level_01.gd`). Tak se hlídá,
že změna pravidel nerozbila staré levely.

---

## 10. Plán vývoje (milníky)

Původní stručné milníky níže rozpracovává a nahrazuje aktuální
[plán dvanácti etap](PLAN_VYVOJE.md), který zahrnuje 2.5D prototyp
a první sestavení pro Mac. Tabulka zachycuje původní rámec.

| # | Milník | Obsah |
|---|---|---|
| M1 | **Jádro** ✅ | Simulace, 4 dovednosti, testovací level, HUD, shader terénu. |
| M2 | Všechny mechaniky | Lezec, padák, bombič + atomovka, horník; voda, láva, pasti; jednosměrné zdi. |
| M3 | Grafika 2026 | Materiály terénu, světla, glow, HD lumíci, částice, paralaxa. |
| M4 | Obsah | Menu, výběr levelů, ukládání postupu ✅, zvuk ✅; 15–20 levelů, hudba. |
| M5 | Vyladění | Replay, přetáčení, dotyk a gamepad, export PC / Android / web. |

---

## 11. Právní poznámka

Značka a hra **Lemmings** (jméno, grafika, hudba, původní levely)
patří firmě Sony. Herní mechaniky se chránit nedají, konkrétní
obsah ano. Proto:

- Pro osobní projekt a učení je to v pohodě.
- Pokud bys chtěl hru někdy zveřejnit: **vlastní název**, vlastní
  grafika, hudba a levely. Neopisovat původní levely 1:1.

Všechno v tomhle repozitáři je vlastní tvorba (kód, tvary, barvy,
level), nic není převzaté z originálu.
