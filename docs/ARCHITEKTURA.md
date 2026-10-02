# Lemmings 2026 – architektura

Návrh, jak je hra postavená a proč. Psáno tak, aby se v tom vyznal
i neprogramátor, a zároveň aby se podle toho dalo dál stavět
(i s pomocí AI).

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
| `terrain_mask.gd` | Logická mapa terénu. Umí: je tu zem? je tu ocel? vykopej, postav cihlu. |
| `lemming.gd` | Data jednoho lumíka: pozice, směr, stav, počítadla. |
| `level_spec.gd` | Pravidla levelu: kolik lumíků, kolik zachránit, dovednosti, čas. |
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
blokař, stavitel (+ krčení rameny), razič, kopáč.

Plánované: lezec, padák, bombič (+ atomovka), horník, utopení,
pasti.

### Pravidla simulace (nesmí se porušit)

- V `sim/` **nesmí** být žádné uzly (Node), `Input`, náhoda ani reálný
  čas. Jen čistá data a celá čísla.
- Svět se posouvá jen funkcí `LevelSim.tick()`.
- Hráčovy příkazy se zapisují do `replay_log` (tik + lumík + dovednost).
  Ze stejného levelu a stejného logu musí vždy vyjít stejný výsledek.

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
| A | rezerva (voda, láva, jednosměrné zdi…) |

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
- **Replay** (později) – přehrát `replay_log` od začátku.
- **Přetáčení času** (později) – ukládat snímky stavu každých pár
  sekund a dopočítat zbytek z logu.

---

## 7. Grafika 2026 – plán

Doporučený směr: **HD 2D s moderním osvětlením** (jako hry typu
Ori, Trine, Dead Cells). Je to nejlepší poměr „wow efekt / práce“
a Godot to umí výborně.

| Oblast | Co uděláme |
|---|---|
| Terén | Sady materiálů (hlína, skála, krystaly, led, kov), normálové mapy z masky → dynamické světlo, mech a kořeny na hranách. |
| Světlo | `PointLight2D` (lucerny, krystaly, východ), barevné ladění scény, glow/bloom (HDR 2D). |
| Lumíci | HD animace: buď 3D model vyrenderovaný do sprite sheetu, nebo 2D kostra (Skeleton2D). Výrazy obličeje, squash & stretch. |
| Částice | Hlína, jiskry z oceli, prach, padáky, exploze, kouř. Otřesy kamery. |
| Prostředí | Paralaxní pozadí ve více vrstvách, mlha, počasí, voda a láva se shaderem a odrazy. |
| UI | Moderní lišta dovedností, minimapa, ovládání dotykem i gamepadem. |

**Alternativa 2.5D:** simulace zůstane 2D, ale terén se vykreslí jako
3D těleso vytažené z masky a lumíci jako 3D modely. Díky oddělení
logiky je to možné i později – jen vyměníme složku `view/`.

---

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
main/                hlavní scéna a herní smyčka
sim/                 logika hry (žádná grafika!)
  states/            jeden soubor = jeden stav lumíka
level_tools/         nástroje pro stavbu levelů v editoru
levels/              samotné levely (scény)
view/                grafika: terén, lumíci, efekty, kamera, shadery
ui/                  rozhraní (HUD, menu)
tests/               automatické testy simulace (běží bez grafiky)
docs/                dokumentace
```

Plánované: `audio/` (zvuky a hudba), `assets/` (textury, modely).

Protože simulace nepotřebuje grafiku, jde celý level „odehrát“
v testu za pár sekund (`tests/test_level_01.gd`). Tak se hlídá,
že změna pravidel nerozbila staré levely.

---

## 10. Plán vývoje (milníky)

| # | Milník | Obsah |
|---|---|---|
| M1 | **Jádro** ✅ | Simulace, 4 dovednosti, testovací level, HUD, shader terénu. |
| M2 | Všechny mechaniky | Lezec, padák, bombič + atomovka, horník; voda, láva, pasti; jednosměrné zdi. |
| M3 | Grafika 2026 | Materiály terénu, světla, glow, HD lumíci, částice, paralaxa. |
| M4 | Obsah | Menu, výběr levelů, ukládání postupu, 15–20 levelů, zvuk a hudba. |
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
