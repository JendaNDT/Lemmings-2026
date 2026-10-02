# Lemmings 2026

Moderní předělávka klasické hry Lemmings (1991) v enginu Godot.

Architektura: [`docs/ARCHITEKTURA.md`](docs/ARCHITEKTURA.md) ·
Stav projektu: [`PROJECT_STATUS.md`](PROJECT_STATUS.md) ·
Plán 2.5D: [`docs/PLAN_VYVOJE.md`](docs/PLAN_VYVOJE.md)

První testovací sestavení míří na **macOS (Apple Silicon i Intel)**. Stejné
herní jádro má nyní také testovací sestavení pro Android; Windows navážou později. Výchozí scéna
už používá **2.5D zobrazení**: prostorový terén, animované postavy a světla
nad původní 2D simulací. Původní `main/game.tscn` zůstává pro porovnání;
výchozí je `main/game_3d.tscn`.

## Testovací verze pro Android

[**Stáhnout Android APK 0.2.1 (60 MiB)**](https://github.com/JendaNDT/Lemmings-2026/raw/refs/heads/downloads/android-0.2.1/android/Lemmings-2026-Android-0.2.1.apk)

Instalátor, návod a kontrolní součet jsou v samostatné
[větvi pro stažení](https://github.com/JendaNDT/Lemmings-2026/tree/downloads/android-0.2.1).

APK `Lemmings-2026-Android-0.2.1.apk` obsahuje stejnou ukázkovou misi.
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

1. Stáhni **Godot 4.7** (standardní verze, ne .NET) z
   [godotengine.org/download](https://godotengine.org/download).
2. Spusť Godot → **Import** → vyber soubor `project.godot` z tohohle repozitáře.
3. Stiskni **F5** (nebo ▶ vpravo nahoře).

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

Kontrola zahrnuje integritu podkladů, parser a linter všech GDScriptů, čistý
import, mechaniky, řešení levelu, replay, herní smyčku s HUD, geometrii 3D
terénu, výběr myší a časování animací. Běží v dočasné
kopii, původní soubory nemění; logy ukládá do `build/checks/`. Selže také
při chybě Godotu s návratovým kódem 0, chybějícím výsledku nebo timeoutu.
Stejný postup používá připravené CI pro Linux a macOS. Součástí jsou také
testy dotykových gest, ochrany před dvojím přidělením a pauzy na pozadí.

Volba `--benchmark` navíc změří čistou simulaci 200 lumíků po dobu 1700 tiků
a 3D prezentaci s 200 postavami a souběžnou prací po dobu 240 tiků.
Jde o CPU práci bez GPU kreslení, nikoli o FPS hry. Podrobnosti a grafický
kontrolní průchod jsou v [`docs/ETAPA_3_OVERENI.md`](docs/ETAPA_3_OVERENI.md).

## Ovládání

| Akce | Ovládání |
|---|---|
| Vybrat dovednost | klik na liště dole nebo klávesy **1–8** |
| Přidělit dovednost | levý klik na lumíka |
| Posun kamery | šipky / **WASD** / myš u okraje / tažení pravým tlačítkem |
| Přiblížení | kolečko myši |
| Pauza | **mezerník** nebo **P** |
| Zrychlení 3× | **F** |
| Vypouštění pomaleji / rychleji | **−** / **=** (nebo na numerické klávesnici) |
| Restart levelu | **R** |

## Jak upravit level

Otevři `levels/level_01.tscn`. Pravidla levelu (počet lumíků, dovednosti,
čas) jsou v Inspectoru u kořenového uzlu. Terén tvoří uzly `TerrainShape`
– vyber jeden a body mnohoúhelníku můžeš tahat myší.

## Právní poznámka

Fanouškovský projekt. Značka Lemmings patří jejímu vlastníkovi (Sony).
Veškerý obsah tady je vlastní tvorba.
