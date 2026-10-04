# Lemmings 2026 – Project Status
*Naposled aktualizováno: 04. 10. 2026*

## 🎯 Co to je
Moderní předělávka hry Lemmings (1991) s grafikou odpovídající roku 2026.
Stack: Godot 4.7, společné jádro v GDScriptu.
Výchozí zobrazení je **2D origami**: papírový terén z masky simulace,
skládané postavičky s animacemi a krajina s paralaxním posunem i zoomem.
2.5D zobrazení bylo 4. 10. 2026 vyřazeno; jednoduché 2D slouží k ladění.
První testovací sestavení je pro **macOS (Apple Silicon a Intel)**,
také testovací APK pro Android, do budoucna Windows.
Vývoj a kontroly probíhají v cloudu.

## ⏭️ Příští krok
**Kampaň se staví podle schváleného [herního designu](docs/HERNI_DESIGN.md).**
Hotové: kapitoly, hvězdy, úvodní karta mise, nápověda, Hřiště,
kapitola I (15 → 14 → 18 → 23 → 32 → 38), II (33 → 36 → 42 → 51 → 55),
III (37 → 50 → 56 → 61 → 63) a **kapitola IV Bouřková hora**: Dvě líhně
66, Lávová lávka 73, Velký sestup 84, Origami finále 91. **Kampaň má
všech 20 misí**, všechny v cílových pásmech.
2.5D zobrazení je vyřazené. [Ověření](docs/ETAPA_9_OVERENI.md).

Další kroky:
1. **Vyzkoušet APK 0.13.0 na telefonu** – aktualizuje 0.12.0 bez ztráty
   postupu: [stáhnout](https://github.com/JendaNDT/Lemmings-2026/raw/refs/heads/downloads/android-0.13.0/android/Lemmings-2026-Android-0.13.0.apk).
   Zajímá mě: jestli je přelet mapy příjemný (délka, plynulost) a šipka
   k východu užitečná, jak se ti líbí vzhled kapitol, jestli déšť a jiskry
   nezpomalují telefon a jestli obtížnost roste plynule.
   [Návod](docs/ANDROID_DEMO.md).
2. **Podpisový klíč natrvalo** – export hlídá stálý podpis, ale klíč žije
   jen v tomto cloudovém prostředí; jeho přenos mimo něj čeká na tvé
   rozhodnutí (viz Známé bugy).
3. Ladění obtížnosti podle tvého hraní (hlavně kapitola IV).

Etapa 4 je technicky dokončená: osm dovedností, tři zkušební mise a hřiště.
[Ověření etapy 4](docs/ETAPA_4_OVERENI.md), [plán dvanácti etap](docs/PLAN_VYVOJE.md).
Nativní běh a výkon na Macu a Androidu zbývají ověřit, Windows jsou odložené na závěr.

## ✅ Hotovo
- **Android APK 0.13.0** ve větvi `downloads/android-0.13.0` (versionCode
  14, stejný podpis): přelet mapy a šipka k východu. Herní soubory z APK
  prošly průchodem menu včetně přeskočení přeletu kliknutím.
- **Přelet mapy:** po úvodní kartě kamera ukáže východ se štítkem
  „Východ“ a přeletí k líhni (2,6–4,4 s, čas stojí); klepnutí, klávesa
  nebo Zpět ho přeskočí, vypnout jde v Nastavení → Hra. Za hry ukazuje
  **šipka u okraje** k východu mimo záběr (`PaperFlyover`, `PaperGuide`,
  `FlyoverHint`, test `test_flyover`).
- **Android APK 0.12.0** ve větvi `downloads/android-0.12.0` (versionCode
  13, stejný podpis): vzhled kapitol a přetočení o 5 s. Herní soubory z APK
  prošly průchodem menu a první mise každé kapitoly se spustila se svým
  vzhledem.
- **Vzhled kapitol:** II. Skalní les (skalní město, jedle, mech), III. Voda
  a oheň (sopky s kouřem, žhnoucí pukliny, jiskry), IV. Bouřková hora
  (bouřkové mraky, sněžné štíty, déšť, blesky); vlastní barvy terénu
  a trávy, světlo a počasí (`PaperTheme`, `build_themes.py`).
- **Přetočení o 5 s** (−5 s, Backspace) se záložkami stavu
  (`LevelSim.snapshot()`), test shody se hrou zahranou do daného tiku.
- **Android APK 0.11.0** ve větvi `downloads/android-0.11.0` (versionCode
  12, stejný podpis): pomocníci. Herní soubory z APK prošly průchodem
  menu i ukázkou řešení.
- **Pomocníci:** Krok o jeden tik v pauze, zpomalení ½× (rychlost
  1× → 3× → ½×) a Ukázka řešení v pauzovacím menu – přehraje uložené
  referenční řešení mise (`LevelDefinition.solution`, generuje
  `scripts/update_solutions.gd`), nezapisuje postup. Test `test_helpers`.
- **Android APK 0.10.0** ve větvi `downloads/android-0.10.0` (versionCode
  11, stejný podpis): celá kampaň, 20 misí. Herní soubory z APK prošly
  průchodem menu.
- **Etapa 9, krok 6 – kapitola IV:** mise Dvě líhně (dvě skupiny),
  Lávová lávka (tři jámy na doraz), Velký sestup (průzkumník s padákem,
  blokař, horníci oknem v ocelových lemech) a Origami finále (vše
  dohromady); Hřiště v menu přesunuto do záhlaví. Report v pořádku
  pro všech 20 misí.
- **Android APK 0.9.0** ve větvi `downloads/android-0.9.0` (versionCode 10,
  stejný podpis): kapitola III, 16 misí. Herní soubory z APK prošly
  průchodem menu.
- **Etapa 9, krok 5 – kapitola III:** mise Hladová kytka (past se dobíjí),
  Šipky v útesu (jednosměrné zdi), Brod (voda, most, blokař s bombou)
  a Pod sopkou (zkouška: horník pod lávou, kytka, čas) s referenčními
  řešeními, úvody a nápovědami; report obtížnosti v pořádku pro 16 misí.
- **Android APK 0.8.0** ve větvi `downloads/android-0.8.0` (versionCode 9,
  stejný podpis): kapitola II. Herní soubory z APK prošly průchodem menu.
- **Etapa 9, krok 4 – kapitola II:** mise Propadlo (bomba na terén),
  Ocelové kořeny (razič, ocel), Dlouhá lávka (dva stavitelé v řadě,
  ohrádka) a Mlýnský spěch (vypouštění a čas) s referenčními řešeními,
  úvody a nápovědami; report obtížnosti v pořádku pro všech 12 misí.
  Poučení: razič má okno nejvýš 8 tiků, předměty na zemi zapustit do terénu.
- **Etapa 9, kroky 1–2:** `Campaign` s kapitolami a Hřištěm, číslo mise
  z pořadí, hvězdy (★★★ = referenční řešení), tolerantní odemykání,
  `BriefingCard`, nápověda v pauze a po neúspěších, „Odpálit vše“;
  mise Díra v louce, Schody na terasu, Hlídka u srázu + úpravy Šikmého
  tunelu, Lezce a padáku, Prvních kroků a Cesty skrz zeď. Kontrola:
  76 GDScriptů, 13 sad, 380 kontrol.
- **Vyřazení 2.5D:** scéna, `view/clay_*`, `assets/clay`, 3D model a testy
  pryč; písmo v `assets/fonts/`; APK o 5 MB menší.
- **Android APK 0.7.0** ve větvi `downloads/android-0.7.0`; export ověřuje
  stálý podpis (`scripts/android_signing.txt`).
- **Herní design a systém obtížnosti:** `docs/HERNI_DESIGN.md`;
  `LevelDifficulty` (index z referenčního řešení, okna zásahů),
  `ReferencePlans` (řešení všech misí), `scripts/difficulty_report.gd`,
  test `tests/test_difficulty.gd`.
- **Android APK 0.6.0** ve větvi `downloads/android-0.6.0`: menu, nastavení,
  ukládání, origami, mise 1–6, zvuky; versionCode 7, stejný testovací podpis
  jako 0.5.0. Herní soubory z APK prošly celým průchodem menu v Linuxu.
- **Etapa 6 – menu, nastavení, ukládání:** `App` (nová hlavní scéna
  `main/app.tscn`), `MenuScreens`, `SettingsPanel`, `MenuBackdrop`,
  `PaperUi`; `SaveFile` (atomický zápis, záloha, SHA-256, verze formátu),
  `GameSettings`, `Progress`, `Campaign` se stabilními ID misí; pauzovací
  menu a výsledek v HUDu; kvalita efektů v `PaperWorld`. Kontrola:
  86 GDScriptů, 13 sad, 395 kontrol; přechody menu ↔ hra bez úniku uzlů.
- **Android APK 0.5.0** ve větvi `downloads/android-0.5.0`: origami grafika,
  mise 1–6, zvuky; versionCode 6, ARM32/ARM64, bez oprávnění. Ověřený
  podpis v2/v3, zarovnání, manifest a spuštění herních souborů z APK
  v Linuxu. Nový testovací klíč – 0.4.0 je nutné nejdřív odinstalovat.
- **Zvuky:** 29 papírových efektů (dovednosti, nebezpečí, líheň, východ,
  rozhraní, znělky) a 3 okolní smyčky z vlastního generátoru
  (`assets/audio/`), `GameAudio` s prostorovým umístěním, omezením
  opakování a ztlumením (T / tlačítko, pamatuje si ho); kontrola 74 GDScriptů,
  11 sad, 327 ověření (`test_audio` 23); záznam mise 6 se zvukem
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

- **Etapa 5 – nebezpečí:** voda (topení), láva (hoření), past (sežere
  jednoho a dobíjí se), jednosměrné zdi (razič a horník jen ve směru šipek);
  pevné pořadí v tiku, cihly přes vodu a lávu jsou suchý most
- Editor: druhy terénu Water/Lava/One Way, uzel `LemmingTrap`, kontrola
  levelu `LevelValidator` (žlutý trojúhelník u kořene levelu)
- Origami vzhled: vlnitá papírová voda, láva s plameny, šipky na zdi,
  masožravá rostlina, animace topení a hoření, uzavřené jeskyně
- Mise 6 „Voda, láva a past“ ověřená čistou simulací i přes origami scénu
  a dotyk (8/10, shoda s replayem); snímky a 19s záznam
- Kontrola: 71 GDScriptů, 10 sad, 290 ověření (`test_hazards` 48,
  `test_origami` 56); mise 1 na telefonu znovu 20/20, terén 0 neshod
- **Vzhled 3. kolo:** čitelnější postavičky (bližší výchozí pohled, světlý
  papírový okraj a stín), hloubka ostrosti krajiny a popředí, opar, teplé
  světlo s paprsky, delší stíny, tmavší tunely; plující mraky, mávající
  ptáci, papírová tráva rostoucí vzhůru a kývající se rostliny i popředí,
  hladký pruh drnu s natrženým okrajem místo lemu z lístků, padající lístky,
  nepravidelné plameny nad lávou; kontrola 72 GDScriptů, 10 sad,
  304 ověření (`test_origami` 70)
- **Vylepšení 2. kolo:** šikmé břehy jezírka a lávové jámy, odlesky,
  kruhy a bubliny ve vodě, plovoucí klobouk po utonutí; láva s třemi
  řadami plamenů, jiskrami, kůrkou, bublinami a září na hlíně; topící se
  postava se plácá dál od břehu; nové animace topení, hoření (plameny,
  kouř, popel), chůze po osmi pózách, mávání při pádu, zplácnutí při dopadu;
  stop-motion mění pózu každý tik

- **Papírovější vzhled (2. kolo):** terén z vystřižených kusů s bílými
  natrženými okraji a měkkými stíny, světlá jádra a tloušťka papíru v celé
  grafice, zrnitost a vinětace, stop-motion pohyb postav (klávesa M)
- Kontrola po 2. kole: 66 GDScriptů, 9 sad, 232 ověření (`test_origami` 46)
- **2D origami zobrazení jako výchozí scéna** (`main/game_origami.tscn`,
  `view/paper_*`): papírový terén ze shaderu nad maskou (vrstvy, drn, ocel,
  harmonikové schody, výkopy, jeskyně), origami postavy z dílů se 13 animacemi
  podle simulačních tiků, líheň a východ, rostlinky, papírové ústřižky
- Paralaxa: 4 vodorovně navazující vrstvy krajiny + popředí, rozdílný posun
  i zoom, žádné prázdné okraje; jediná herní transformace `PaperCamera`
- Papírový HUD a 8 nových ikon; dotyky ve 2D (klepnutí, posun, dva prsty)
- Podklady `assets/origami/` z vlastního opakovatelného generátoru
  (Python, pevné seedy), původ, licence, manifest 48 souborů
- Kontrola: 66 GDScriptů, 9 sad, 227 ověření; nová sada `test_origami` (41),
  včetně dalších tří misí přes origami scénu a dotyk (6/6, 6/6, 3/4)
- Grafický průchod (Linux, software OpenGL): 20/20 myší i dotykem,
  terén přesně podle masky (0 neshod), snímky a 17s záznam
- Kontrola verze přijímá i opravné vydání Godot 4.7.x stable (např. 4.7.1)

- Origami mockup uložený s přesným promptem, původem a SHA-256
- Starší grafické návrhy a oddělená studie odstraněny na přání autora
- Po úklidu: 56 GDScriptů, osm sad, 186 ověření; import a spuštění prošly
  v čisté kopii. Herní sady 50 + 13 souborů mají nezměněné kontrolní součty.

## 📝 TODO
### MVP (nutné pro v1)
- Menu a výběr levelů, ukládání postupu
- 15–20 vlastních levelů
- Hudba (zvuky jsou hotové)
- Prostředí pro další mise kampaně (nové motivy krajiny)
- Pravidelnější hřeben plamenů nad lávou při oddálení doladit podle názoru

### Backlog (později)
- Světla, glow, materiály terénu (M3)
- Replay a přetáčení času
- Výběr jen lumíků jdoucích doleva/doprava
- Minimapa
- Další ladění Androidu na zařízení, gamepad a export web
- Editor levelů ve hře

## 🐛 Známé bugy
- Testovací podpisový klíč Androidu žije jen v tomto cloudovém prostředí.
  Export teď s jiným klíčem skončí chybou (žádné tiché „nejde nainstalovat“),
  ale až prostředí zanikne, další APK půjde nainstalovat jen po odinstalaci.
  Vynesení klíče do souboru pro uložení zastavila bezpečnostní kontrola
  prostředí – čeká na rozhodnutí autora.
- Origami grafika zatím neběžela na Macu ani Androidu; výkon na skutečné
  GPU není změřený (cloud kreslí softwarově, ~0,2 s na snímek).
- Proti mockupu je generovaná krajina jednodušší a postavy jsou při
  výchozím zoomu menší; podrobně v `docs/ORIGAMI_OVERENI.md`.
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
  Je to jediné herní zobrazení; 2.5D renderer byl vyřazen (4. 10. 2026).
- **Kampaň (4. 10. 2026, autor schválil vše):** 4 kapitoly a 20 misí podle
  `docs/HERNI_DESIGN.md`, hvězdy 1–3, Hřiště mimo kampaň, navržené názvy,
  vyřazení 2.5D, trvalý podpisový klíč Androidu.
- **Origami podklady:** generované vlastními skripty (opakovatelně), z mockupu
  se nekopírují pixely. Postava = díly + klíčové pózy v JSON, ne snímky.
- **Terén ve 2D:** kreslí ho shader přímo z masky; šum hrany max. ±0,4 buňky,
  takže viditelný terén ve středech buněk vždy odpovídá kolizím.
- **Pořadí grafické práce:** mockup → vrstvy → postavička a animace → scéna.
- **Paralaxa:** rozdílný posun a zoom dekorativních vrstev; terén a postavy
  sdílejí jednu soustavu a simulační masku. HUD je pevný.
- **Kopání:** vodorovně, šikmo dolů a svisle dolů; vzhůru vedou schody.
- **Nebezpečí:** kanál A masky nese druh buňky (voda, láva, šipky). Pořadí
  v tiku: bomba → stav → pád pod level → láva → voda → past → východ.
  Cihla ve vodě či lávě je suchá; past sežere jen prvního, pak se dobíjí.

- **Platformy:** dnes testovací macOS, později Windows a Android;
  společná simulace a obsah, odlišnosti ve vstupu, grafických profilech a exportu.
- **Právní:** vlastní obsah, žádné převzaté assety z originálu. Při zveřejnění jiný název.

## 📁 Stav souborů
- `main/game_origami.tscn`, `view/paper_*.gd`, `view/paper_terrain.gdshader` – výchozí 2D origami
- `assets/origami/` (+ `source/` generátor), `assets/origami.lock.json` – origami podklady
- `scripts/qa_origami.gd` – grafický průchod, snímky, záznam a kontrola terénu
- `docs/ORIGAMI_OVERENI.md` – výsledky a meze origami zobrazení
- `main/game.tscn`, `main/game.gd` – hlavní scéna, herní smyčka, ovládání
- `assets/fonts/` – písmo Nunito s licencí OFL (`assets/fonts.lock.json`)
- `sim/level_sim.gd` – pravidla levelu, vypouštění, východ, konec
- `sim/sim_replay.gd` – kontrola a technické přehrávání příkazů
- `sim/terrain_mask.gd` – logická mapa terénu
- `sim/states/*.gd` – stavy lumíků (jeden soubor = jeden stav)
- `sim/sim_const.gd` – všechna laditelná čísla
- `level_tools/` – nástroje pro tvorbu levelů v editoru
- `levels/level_01.tscn` – první level; `levels/level_hazards.tscn` – mise 6
- `view/game_audio.gd`, `assets/audio/` (+ `source/build_sfx.py`), `docs/ZVUK.md` – zvuky
- `level_tools/lemming_trap.gd`, `level_tools/level_validator.gd` – past a kontrola levelu
- `tests/test_hazards.gd`, `docs/ETAPA_5_OVERENI.md` – ověření etapy 5
- `main/app.tscn` (`App`) – hlavní scéna: menu, spouštění a uvolňování misí
- `main/save_file.gd`, `main/game_settings.gd`, `main/progress.gd`, `main/campaign.gd` –
  bezpečné ukládání, nastavení, postup a pořadí misí
- `ui/menu_screens.gd`, `ui/settings_panel.gd`, `ui/menu_backdrop.gd`, `ui/paper_ui.gd` – menu
- `docs/HERNI_DESIGN.md`, `level_tools/level_difficulty.gd`, `tests/reference_plans.gd`,
  `scripts/difficulty_report.gd` – herní design a měření obtížnosti
- `tests/test_save.gd`, `tests/test_menu.gd`, `scripts/qa_menu.gd`,
  `docs/ETAPA_6_OVERENI.md` – ověření etapy 6
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
