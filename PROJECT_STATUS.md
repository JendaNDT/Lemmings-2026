# Lemmings 2026 – Project Status
*Naposled aktualizováno: 02. 10. 2026*

## 🎯 Co to je
Moderní předělávka hry Lemmings (1991) s grafikou odpovídající roku 2026.
Stack: Godot 4.7, společné jádro v GDScriptu, renderer Forward+.
Výchozí zobrazení je **2.5D**: 2D simulace + prostorový terén a postavy.
První testovací sestavení je pro **macOS (Apple Silicon a Intel)**,
nově také testovací APK pro Android, do budoucna Windows.
Vývoj a kontroly probíhají v cloudu.

## ⏭️ Příští krok
**Etapa 4 – doplnění zbývajících dovedností.** Etapa 3 má hotový hratelný
2.5D prototyp prvního levelu: materiály, animace, měnitelný prostorový terén,
světlo, kamera, klikání a HUD jsou zapojené. Grafický průchod zachránil 20/20.
Původní 2D scéna zůstává pro diagnostické porovnání. Podrobnosti a omezení
jsou v [`ověření etapy 3`](docs/ETAPA_3_OVERENI.md).
Etapa 2 doplnila společné příkazy,
technický replay a regresní kontroly simulace i skutečné herní smyčky.
Současně zbývá uživatelské spuštění macOS balíčku na MacBooku; cloud
nepotvrzuje jeho nativní běh. Připravené CI pro Linux a macOS se spustí
po odeslání změn na GitHub, vzdálený běh zatím nebyl ověřen.

Kompletní pořadí dvanácti etap je v [`docs/PLAN_VYVOJE.md`](docs/PLAN_VYVOJE.md).
Výsledky: [`etapa 1`](docs/ETAPA_1_OVERENI.md),
[`etapa 2`](docs/ETAPA_2_SIMULACE.md), [`etapa 3`](docs/ETAPA_3_OVERENI.md).

## ✅ Hotovo
- Návrh architektury (`docs/ARCHITEKTURA.md`)
- Struktura projektu Godot 4.7
- Simulace s pevným krokem (17 tiků/s), deterministická, záznam příkazů pro replay
- Logická mapa terénu (hlína / ocel / cihly), kopání, stavění, vypalování mnohoúhelníků
- Stavy lumíka: chodec, pád, splácnutí, odchod východem, blokař, stavitel, razič, kopáč
- Tvorba levelů v editoru Godotu (TerrainShape, LemmingHatch, LemmingExit)
- Level 1 „První kroky“ (ověřený simulací: řešitelný, 20/20)
- Automatické kontroly mechanik, řešení levelu, JSON replaye a hlavní scény s HUD
- Jednotný záznam dovedností i vypouštění, definované pořadí během pauzy
- Replay zachová průběh, terén a události při 30/144 FPS i nepravidelných snímcích
- Přenosný `scripts/check.py`, ověřený instalátor Godotu, připravené Linux/macOS CI
- Opakovatelný zátěžový scénář: 200 lumíků po dobu 1700 tiků
- Shader terénu: hladké okraje, tráva, vrstvy hlíny, ocel, cihly, nasvícení hran
- Pozadí se shaderem (obloha, mlha, hvězdy)
- Placeholder lumíci kreslení tvary + plynulý pohyb mezi tiky
- Částicové efekty (hlína, jiskry, prach, odchod)
- HUD: dovednosti, vypouštění, pauza, zrychlení 3×, restart, okno s výsledkem
- Kamera: šipky/WASD, okraj obrazovky, tažení pravým tlačítkem, zoom kolečkem
- Cloud s ověřeným Godotem 4.7, exportními šablonami a skutečným grafickým během
- První level dokončen v samostatném Linux QA exportu přes klávesnici a myš: 20/20
- Univerzální macOS export s ad-hoc podpisem a opakovatelný exportní skript
- Exportní nastavení pro budoucí Windows; jeho nativní testy jsou odložené
- Syntaxe/styl všech GDScriptů a původní i nové testy prošly v čisté kopii projektu
- Samostatná modelínová sada 0.1.0: 24 map, 7 GLB včetně postavičky,
  16 kostí, 11 animací, 10 ikon, světla a kamera
- Skutečné náhledy z Godotu a videa animací i plastické deformace;
  zdroje Blenderu a opakovatelné generátory jsou přiložené
- Výchozí 2.5D scéna: uzavřený terén z masky, jeskyně, ocel a stavební cihly
- Obnova pouze změněných oblastí 32 × 32 buněk včetně sousedů na hranicích
- Animace řízené simulačními tiky, nástroje, hrudky a lokální vizuální promáčknutí
- Ortografická kamera, zoom, posun, přesné klikání a zvýraznění cíle
- Celý první level ověřený přes herní vstup; 20/20 a shoda s původní simulací
- Čisté automatické kontroly: 43 GDScriptů, 7 sad včetně zátěže, 124 ověření
- Android demo 0.2.1: podepsané APK pro ARM32/ARM64, Android 7.0+, bez oprávnění
- Dotyk: klepnutí, posun, přiblížení dvěma prsty; ochrana před nechtěným přidělením
- Mobilní profil OpenGL ES 3, menší stíny a rozlišení 3D, bez SSAO/MSAA
- Aktuální kontroly bez zátěžových měření: 46 GDScriptů, 6 sad, 131 ověření
- Celý level ověřený dotykovými událostmi v Compatibility rendereru: 20/20
- Android APK 0.2.1 nahrané do samostatné GitHub větve `downloads/android-0.2.1`,
  s návodem a kontrolním součtem; odkaz na stažení je v README
- Propojení Google Disku odložené; cloudový přístup nebyl dokončen ani ověřen

## 📝 TODO
### MVP (nutné pro v1)
- Lezec, padák, bombič (+ atomovka), horník
- Voda / láva / pasti, jednosměrné zdi
- Menu a výběr levelů, ukládání postupu
- 15–20 vlastních levelů
- Zvuky a hudba
- Finální výtvarné zpracování 3D postav a prostředí celé kampaně

### Backlog (později)
- Světla, glow, materiály terénu (M3)
- Paralaxní pozadí
- Replay a přetáčení času
- Výběr jen lumíků jdoucích doleva/doprava
- Minimapa
- Další ladění Androidu na zařízení, gamepad a export web
- Editor levelů ve hře

## 🐛 Známé bugy
- Při průchodu prvního levelu v grafickém cloudovém běhu nebyla nalezena
  chyba bránící hraní. Nejde o vyčerpávající kontrolu všech mechanik.
- Nativní spuštění na macOS čeká na uživatelské ověření; Windows až na
  závěr vývoje. Android APK je připravené, instalace a výkon na zařízení
  nebo emulátoru zatím ověřené nejsou.
- Mac balíček není notarizovaný Applem; první spuštění může vyžadovat
  potvrzení konkrétní aplikace v nastavení zabezpečení.
- Zátěž 200 postav se souběžnou prací dosahuje v cloudu přibližně 35 ms
  CPU práce na 95. percentilu. Pro tuto zátěž zatím není doložen cíl 60 FPS;
  běžný první level je výrazně lehčí. Nativní GPU výkon zbývá změřit.

## 🏗️ Klíčová rozhodnutí
*(Aby ses k tomu zase zbytečně nevracel.)*
- **Engine:** Godot 4.7 + GDScript (ne C#) – jednodušší pro vibecoding, funguje i export na web.
- **Logika × grafika:** úplně oddělené. `sim/` nesmí obsahovat grafiku, Input ani náhodu.
- **Měřítko logiky:** jako originál (lumík 10 px, 17 tiků/s). Grafika se jen zvětšuje a vyhlazuje.
- **Terén:** pixelová maska RGBA8 (R zem, G ocel, B cihly), vzhled maluje shader.
- **Stavy lumíka:** jeden soubor na stav, stavy jsou bezstavové (data drží Lemming).
- **Levely:** scény v editoru Godotu z mnohoúhelníků, ne vlastní formát.
- **Konec levelu:** při vypršení času nebo pokud po vypuštění všech zbývají jen
  blokaři. Blokaři se nezachrání; `lost` počítá skutečné smrti, zbývající postavy
  se na konci pouze zastaví. Splnění cíle samo o sobě level předčasně neukončí.
- **Klávesy:** podle fyzické pozice (funguje i na české klávesnici).
- **Grafický směr:** schválené 2.5D – prostorový terén a postavy,
  pevná ortografická kamera, 2D herní rovina a HUD. Technický prototyp je hotový.
- **Výtvarný styl:** autor vybral Modelínový svět, druhou variantu konceptu.
  Matné modelované povrchy, oblé tvary a výrazné barvy; reference a další
  grafické podklady jsou popsané v `docs/VYTVARNY_SMER.md`.
- **Pořadí grafické práce:** podklady → postavička a animace → zapojení do hry.
  Všechny tři kroky jsou pro technický prototyp hotové; finální kampaň naváže později.
- **Modelínová hmota:** lokální promáčknutí, protažení a odtržení hrudky.
  Změny schůdnosti musí řídit simulace. Kopání pouze vodorovně, šikmo dolů
  a svisle dolů; vzhůru vedou stavitelovy schody.
- **Platformy:** dnes testovací macOS, později Windows a Android;
  společná simulace a obsah, odlišnosti ve vstupu, grafických profilech a exportu.
- **Právní:** vlastní obsah, žádné převzaté assety z originálu. Při zveřejnění jiný název.

## 📁 Stav souborů
- `main/game.tscn`, `main/game.gd` – hlavní scéna, herní smyčka, ovládání
- `main/game_3d.tscn`, `view/clay_*.gd` – výchozí 2.5D scéna a její prezentace
- `assets/clay/`, `assets/clay.lock.json` – podklady a ověření integrity
- `sim/level_sim.gd` – pravidla levelu, vypouštění, východ, konec
- `sim/sim_replay.gd` – kontrola a technické přehrávání příkazů
- `sim/terrain_mask.gd` – logická mapa terénu
- `sim/states/*.gd` – stavy lumíků (jeden soubor = jeden stav)
- `sim/sim_const.gd` – všechna laditelná čísla
- `level_tools/` – nástroje pro tvorbu levelů v editoru
- `levels/level_01.tscn` – první level
- `view/terrain.gdshader` – vzhled terénu
- `view/lemmings_view.gd` – kreslení lumíků
- `ui/hud.gd` – herní rozhraní
- `tests/test_*.gd`, `tests/benchmark_sim.gd` – regresní kontroly a zátěž simulace
- `scripts/check.py`, `.github/workflows/checks.yml` – stejné kontroly lokálně a v CI
- `export_presets.cfg`, `scripts/export_desktop.sh` – macOS, Linux QA a budoucí Windows
- `docs/PLAN_VYVOJE.md` – aktuální plán dvanácti etap se směrem 2.5D
- `docs/ETAPA_1_OVERENI.md` – důkazy a omezení první fáze
- `docs/PODKLADY_PROTOTYPU.md` – obsah a ověření samostatné grafické sady
- `docs/ETAPA_3_OVERENI.md` – průchod 2.5D, geometrie, výkon a sestavení
- `docs/ANDROID_DEMO.md` – první Android APK, dotykový profil a meze ověření
