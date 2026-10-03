# Lemmings 2026 – Project Status
*Naposled aktualizováno: 03. 10. 2026*

## 🎯 Co to je
Moderní předělávka hry Lemmings (1991) s grafikou odpovídající roku 2026.
Stack: Godot 4.7, společné jádro v GDScriptu, renderer Forward+.
Výchozí zobrazení je **2.5D**: 2D simulace + prostorový terén a postavy.
První testovací sestavení je pro **macOS (Apple Silicon a Intel)**,
nově také testovací APK pro Android, do budoucna Windows.
Vývoj a kontroly probíhají v cloudu.

## ⏭️ Příští krok
**Aktuální směr: čistě 2D origami s paralaxním posunem a zoomem.** Autor
přijal [nový mockup](docs/MOCKUP_ORIGAMI.md) jako jediný výtvarný podklad
pro pokračování. Na jeho přání byly odstraněny staré koncepty, náhledy,
videa a samostatný modelínový výřez v3. Technické podklady dosavadní hry
zůstávají, aby hra fungovala do nahrazení rendereru.

Pořadí další práce: grafické vrstvy, postavička a animace, scéna Godotu.
Zatím je hotový pouze nový obrázek. Paralaxa, origami animace ani nový
renderer nejsou implementované; APK stále obsahuje dosavadní 2.5D hru.
Nynější úkol je zveřejnění návrhu a úklid, nikoli převod celé hry.

Etapa 4 je technicky dokončená: osm dovedností, tři zkušební mise a hřiště.
[Ověření etapy 4](docs/ETAPA_4_OVERENI.md),
[plán dvanácti etap](docs/PLAN_VYVOJE.md).
Mechaniky etapy 5 následují po výtvarné práci. Nativní běh a výkon na Macu
a Androidu zbývají ověřit, Windows jsou odložené na závěr.

## ✅ Hotovo
- Návrh architektury (`docs/ARCHITEKTURA.md`)
- Struktura projektu Godot 4.7
- Simulace s pevným krokem (17 tiků/s), deterministická, záznam příkazů pro replay
- Logická mapa terénu (hlína / ocel / cihly), kopání, stavění, vypalování mnohoúhelníků
- Stavy lumíka: chodec, pád, splácnutí, odchod východem, blokař, stavitel, razič, kopáč, lezec, padák a horník
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
- Původ používaných podkladů a jejich manifesty; staré galerie odstraněny
- Výchozí 2.5D scéna: uzavřený terén z masky, jeskyně, ocel a stavební cihly
- Obnova pouze změněných oblastí 32 × 32 buněk včetně sousedů na hranicích
- Animace řízené simulačními tiky, nástroje, hrudky a lokální vizuální promáčknutí
- Ortografická kamera, zoom, posun, přesné klikání a zvýraznění cíle
- Celý první level ověřený přes herní vstup; 20/20 a shoda s původní simulací
- Čisté automatické kontroly: 43 GDScriptů, 7 sad včetně zátěže, 124 ověření
- Android demo 0.2.1: podepsané APK pro ARM32/ARM64, Android 7.0+, bez oprávnění
- Dotyk: klepnutí, posun, přiblížení dvěma prsty; ochrana před nechtěným přidělením
- Mobilní profil OpenGL ES 3, menší stíny a rozlišení 3D, bez SSAO/MSAA
- Kontroly před etapou 4: 46 GDScriptů, 6 sad, 131 ověření
- Celý level ověřený dotykovými událostmi v Compatibility rendereru: 20/20
- Android APK 0.3.0 ve větvi `downloads/android-0.3.0` (starší 0.2.1 zůstává zachované),
  s návodem a kontrolním součtem; odkaz na stažení je v README
- Propojení Google Disku odložené; cloudový přístup nebyl dokončen ani ověřen

- Etapa 4: osm dovedností, kombinace trvalých vlastností, odpočty a hromadné ukončení
- Tři nové řešitelné zkušební mise (6/6, 6/6, 3/4) a hřiště se všemi schopnostmi
- Osm dovedností v mobilní liště, výběr scén, potvrzení ukončení a restart vybrané mise
- Kontrola etapy 4: 53 GDScriptů, osm sad, 184 ověření; původní mise stále 20/20
- Nové mise prošly dotykovým průchodem v Compatibility rendereru na Linuxu

- Technicky implementovaná grafika 0.4.0: nový GLB se stejnou kostrou a animacemi, oblý terén,
  dekorace svázané s maskou, prostorová krajina, Nunito a osm ikon dovedností
- Aktuální kontrola: 56 GDScriptů, osm sad, 186 ověření; první mise 20/20
  v obou rendererech, nové mise 6/6, 6/6 a 3/4 přes dotyk v Compatibility
- Android APK 0.4.0 ve větvi `downloads/android-0.4.0`, zdroje
  v původní vývojové větvi; předchozí APK jsou zachovaná

- Origami mockup uložený s přesným promptem, původem a SHA-256
- Starší grafické návrhy a oddělená studie odstraněny na přání autora
- Po úklidu: 56 GDScriptů, osm sad, 186 ověření; import a spuštění prošly
  v čisté kopii. Herní sady 50 + 13 souborů mají nezměněné kontrolní součty.

## 📝 TODO
### MVP (nutné pro v1)
- Voda / láva / pasti, jednosměrné zdi
- Menu a výběr levelů, ukládání postupu
- 15–20 vlastních levelů
- Zvuky a hudba
- Finální 2D papírové postavy, animace a prostředí celé kampaně

### Backlog (později)
- Světla, glow, materiály terénu (M3)
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
  blokaři bez běžícího odpočtu a bez dostupného bombiče. Blokaři se nezachrání; `lost` počítá skutečné smrti, zbývající postavy
  se na konci pouze zastaví. Splnění cíle samo o sobě level předčasně neukončí.
- **Klávesy:** podle fyzické pozice (funguje i na české klávesnici).
- **Grafický směr:** 2D origami; jediná předloha v `docs/MOCKUP_ORIGAMI.md`.
  Současný 2.5D renderer zůstává do nahrazení funkční, není cílovým stylem.
- **Pořadí grafické práce:** mockup → vrstvy → postavička a animace → scéna.
- **Paralaxa:** rozdílný posun a zoom dekorativních vrstev; terén a postavy
  sdílejí jednu soustavu a simulační masku. HUD je pevný.
- **Kopání:** vodorovně, šikmo dolů a svisle dolů; vzhůru vedou schody.

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
- `docs/PLAN_VYVOJE.md` – aktuální plán dvanácti etap a přechod na 2D origami
- `docs/ETAPA_1_OVERENI.md` – důkazy a omezení první fáze
- `docs/PODKLADY_PROTOTYPU.md` – závislosti dosavadní hry a jejich kontrolní součty
- `docs/ETAPA_3_OVERENI.md` – průchod 2.5D, geometrie, výkon a sestavení
- `docs/ANDROID_DEMO.md` – aktuální Android APK, dotykový profil a meze ověření
- `docs/GRAFIKA_04.md` – technický záznam dosavadní verze bez starých návrhů
