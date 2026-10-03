# Lemmings 2026

Moderní předělávka klasické hry Lemmings (1991) v enginu Godot.

Architektura: [`docs/ARCHITEKTURA.md`](docs/ARCHITEKTURA.md) ·
Stav projektu: [`PROJECT_STATUS.md`](PROJECT_STATUS.md) ·
Plán vývoje: [`docs/PLAN_VYVOJE.md`](docs/PLAN_VYVOJE.md)

## Výchozí zobrazení — 2D origami

Hra se nově spouští v **papírovém 2D origami stylu** podle přijatého
[mockupu](docs/MOCKUP_ORIGAMI.md): tyrkysové skládané postavičky
s okrovými čepicemi, terén z vrstev trhaného papíru, pruh zeleného drnu s trávou, papírová
líheň a východ, harmonikové schody a krajina ve čtyřech paralaxních
vrstvách s posunem i zoomem. Terén tvoří vystřižené kusy papíru s bílými
natrženými okraji a měkkými stíny, postavy se hýbou jako papírové loutky
(stop-motion, klávesa **M** přepne na plynulý pohyb). Simulace a všechny
mise jsou beze změny.

![Skutečný snímek hry v 2D origami (Linux, software OpenGL)](docs/images/origami-hra-1.png)

Krátký záznam chůze, ražení, stavění, kopání, posunu a zoomu:
[`docs/images/origami-zaznam.mp4`](docs/images/origami-zaznam.mp4).
Ověření a meze: [`docs/ORIGAMI_OVERENI.md`](docs/ORIGAMI_OVERENI.md).

Pro porovnání zůstávají dřívější scény `main/game_3d.tscn` (2.5D)
a `main/game.tscn` (jednoduché 2D).

**Nově voda, láva, pasti a jednosměrné zdi** (etapa 5) a mise
„6 · Voda, láva a past“: voda topí, láva pálí, masožravá rostlina sežere
jednoho a chvíli se dobíjí, zeď se šipkami prorazíš jen ve směru šipek.
Most z cihel přes vodu i lávu vydrží.

![Mise 6 v origami zobrazení](docs/images/etapa5-prehled.jpg)

Záznam: [`docs/images/etapa5-mise6.mp4`](docs/images/etapa5-mise6.mp4) ·
pravidla a ověření: [`docs/ETAPA_5_OVERENI.md`](docs/ETAPA_5_OVERENI.md).

## Platformy

První testovací sestavení míří na **macOS (Apple Silicon i Intel)**. Stejné
herní jádro má také testovací sestavení pro Android; Windows navážou později.
Výchozí scéna je `main/game_origami.tscn`.

## Testovací verze pro Android

[**Stáhnout Android APK 0.4.0 (60 MiB)**](https://github.com/JendaNDT/Lemmings-2026/raw/refs/heads/downloads/android-0.4.0/android/Lemmings-2026-Android-0.4.0.apk)

Instalátor, návod a kontrolní součet jsou v samostatné
[větvi pro stažení](https://github.com/JendaNDT/Lemmings-2026/tree/downloads/android-0.4.0).

APK `Lemmings-2026-Android-0.4.0.apk` obsahuje původní misi, tři ukázky nových dovedností
a hřiště se všemi osmi schopnostmi. Mise se vybírají vlevo v dolní liště.
Je určené pro telefony a tablety s Androidem 7.0+ a OpenGL ES 3.0,
včetně 32bitového a 64bitového ARM. Stáhni APK přímo na zařízení a otevři
jej; případné povolení instalace se týká aplikace, ze které soubor otevíráš.

Hraje se na šířku. Klepni na dovednost a potom na postavu, jedním prstem
posouvej scénu a dvěma prsty přibližuj. Tlačítko Zpět přepíná pauzu;
přepnutí aplikace na pozadí hru pozastaví. APK nepožaduje žádná oprávnění.

Jde o vývojové APK podepsané testovacím klíčem. Podpis, obsah a dotykový
průchod v cloudu jsou ověřené; instalace a výkon přímo na Androidu zatím ne.
Podrobnosti: [`docs/ANDROID_DEMO.md`](docs/ANDROID_DEMO.md).

Pro opakování exportu nastav v editoru Godotu Android SDK a Java SDK,
nainstaluj šablony Godotu 4.7 a spusť `bash scripts/export_android.sh`.

## Technický stav verze 0.4.0

[Ověření dosavadní hry a používané soubory](docs/GRAFIKA_04.md).
**APK 0.4.0 i dřívější Mac balíček ještě obsahují starou 2.5D grafiku.**
Origami zobrazení je zatím ve zdrojích; nové sestavení vznikne exportem.
Řešení zkušebních misí: [etapa 4](docs/ETAPA_4_OVERENI.md).

## Spuštění hotové verze na Macu

Rozbal `Lemmings-2026-macOS.zip` a otevři `Lemmings 2026.app`.
Godot nemusí být nainstalovaný. Ovládání je níže.

Jde o vývojové sestavení s ad-hoc podpisem, bez notarizace Apple. Pokud
macOS první spuštění zablokuje, potvrď otevření této konkrétní aplikace
v **Nastavení systému → Soukromí a zabezpečení → Přesto otevřít**.
Není potřeba vypínat zabezpečení systému.

Průchod celým levelem a grafika byly ověřeny v linuxovém cloudu na
samostatném exportu. Spuštění přímo na Macu zatím čeká na uživatelské
ověření. Aktuální výsledky: [`docs/ETAPA_3_OVERENI.md`](docs/ETAPA_3_OVERENI.md).

## Jak to spustit

1. Stáhni **Godot 4.7** (standardní verze, ne .NET; funguje i opravná 4.7.1) z
   [godotengine.org/download](https://godotengine.org/download).
2. Spusť Godot → **Import** → vyber soubor `project.godot` z tohohle repozitáře.
   První import papírových textur chvíli trvá.
3. Stiskni **F5** (nebo ▶ vpravo nahoře). Spustí se origami scéna.
   Starší zobrazení otevřeš přes `main/game_3d.tscn` nebo `main/game.tscn`
   a **F6** (spustit aktuální scénu).

## Vytvoření vlastního sestavení

Použij standardní Godot **4.7 stable** a exportní šablony stejné verze
(v editoru **Editor → Manage Export Templates**). Potom z kořene projektu:

```bash
bash scripts/export_desktop.sh macos
```

Výsledkem je `build/macos/Lemmings-2026-macOS.zip`. Skript lze spustit
na macOS i Linuxu; pokud Godot není v PATH, nastav `GODOT_BIN` na jeho
spustitelný soubor. Výstupní složka `build/` je ignorovaná Gitem.

Další volby jsou `windows` (budoucí distribuce) a `linux-qa` (kontroly
samostatné hry v cloudu). Všechny exportují stejné scény a GDScripty;
testy, dokumentace a vývojové skripty se do hry nebalí. Testování přímo
na Windows je plánované na závěr vývoje.

## Automatické ověření

Potřebuješ Python 3.10+ a standardní Godot 4.7. Nástroje nainstaluj
do virtuálního prostředí a spusť společnou kontrolu:

```bash
python3 -m venv build/venv
source build/venv/bin/activate
python -m pip install -r scripts/requirements-dev.txt
python scripts/check.py
```

Pokud Godot není v PATH, použij `--godot /cesta/k/Godotu` nebo proměnnou
`GODOT_BIN`. Volitelně jej stáhne `python scripts/install_godot.py`:
ověří oficiální SHA-512 a vypíše cestu k binárce pro Linux x86_64 nebo macOS.
Exportní šablony tento pomocný instalátor neinstaluje.

Kontrola zahrnuje integritu podkladů (včetně origami sady), parser a linter
všech GDScriptů, čistý import, mechaniky, řešení levelu, replay, herní smyčku
s HUD, geometrii 3D terénu, výběr myší a časování animací. Sada
`test_origami` ověřuje převod souřadnic, zoom kolem kurzoru, hranice mapy,
paralaxu bez mezer a skoků, dotyky, animace podle tiků a celou první misi
přes origami scénu (20/20, shoda s čistou simulací). Běží v dočasné kopii,
původní soubory nemění; logy ukládá do `build/checks/`. Selže také při chybě
Godotu s návratovým kódem 0, chybějícím výsledku nebo timeoutu. Stejný
postup používá připravené CI pro Linux a macOS. Verze Godotu musí být řada
4.7 stable; opravná vydání (4.7.1 …) jsou povolená, jiné verze ne.

Grafický průchod origami s ukládáním snímků (potřebuje grafický výstup,
v cloudu Xvfb):

```bash
godot --path . --rendering-driver opengl3 --script res://scripts/qa_origami.gd \
  -- --capture-dir=build/origami/desktop [--mobile] [--record=build/origami/frames] [--gallery]
```

Podklady origami se znovu vygenerují příkazem
`python assets/origami/source/build_all.py` (potřebuje NumPy, Pillow, SciPy);
`--check` jen ověří, že generátor dává stejné soubory.

Volba `--benchmark` navíc změří čistou simulaci 200 lumíků po dobu 1700 tiků
a 3D prezentaci s 200 postavami a souběžnou prací po dobu 240 tiků.
Jde o CPU práci bez GPU kreslení, nikoli o FPS hry. Podrobnosti a grafický
kontrolní průchod jsou v [`docs/ETAPA_3_OVERENI.md`](docs/ETAPA_3_OVERENI.md).

## Ovládání

| Akce | Ovládání |
|---|---|
| Vybrat dovednost | klik na liště dole nebo klávesy **1–8** |
| Přidělit dovednost | levý klik na lumíka |
| Posun kamery | šipky / **WASD** / myš u okraje / tažení pravým tlačítkem / jeden prst |
| Přiblížení | kolečko myši nebo gesto na touchpadu (kolem kurzoru) / dva prsty |
| Pauza | **mezerník** nebo **P** |
| Zrychlení 3× | **F** |
| Vypouštění pomaleji / rychleji | **−** / **=** (nebo na numerické klávesnici) |
| Restart levelu | **R** |
| Výběr zkušební mise | nabídka vlevo v dolní liště |
| Hromadné ukončení | **N** nebo **Ukončit**, poté potvrzení; **Esc** zruší dialog |
| Stop-motion ↔ plynulý pohyb postav (jen vzhled) | **M** |

## Jak upravit level

Otevři `levels/level_01.tscn`. Pravidla levelu (počet lumíků, dovednosti,
čas) jsou v Inspectoru u kořenového uzlu. Terén tvoří uzly `TerrainShape`
– vyber jeden a body mnohoúhelníku můžeš tahat myší. Druh tvaru (`Kind`)
může být hlína, ocel, výřez, voda, láva nebo jednosměrná zeď; past je uzel
`LemmingTrap` postavený na zem. Chyby v levelu hlásí žlutý trojúhelník
u kořenového uzlu (ukázka: `levels/level_hazards.tscn`).

## Právní poznámka

Fanouškovský projekt. Značka Lemmings patří jejímu vlastníkovi (Sony).
Herní modely a levely jsou vlastní tvorba. Písmo Nunito používá licenci
SIL Open Font License 1.1; její znění je v `assets/art_v2/ui/OFL.txt`.
