# Paperlings (pracovně Lemmings 2026) – pokyny pro AI asistenta

## Kontext
- Moderní předělávka Lemmings (1991) v **Godot 4.7 + GDScript**.
  Veřejný název je **Paperlings** (zvolil autor 4. 10. 2026); „Lemmings“
  se ve hře ani ve vydání nepoužívá. Interní ID zůstávají kvůli
  aktualizacím: `SaveFile.GAME`, `level_id`. Android od rc2 používá
  `cool.jenda.paperlings` a nový release podpis: Jenda 5. 10. 2026 výslovně
  požádal o samostatnou čistou instalaci bez převzetí starého postupu.
  Dřívější testovací balíček `org.lemmings2026.demo` se tím neaktualizuje.
  Data na počítači jsou ve vlastní složce `Paperlings`; `SaveMigration`
  jednou přenese postup ze staré `app_userdata/Lemmings 2026`.
- Testovací sestavení existují pro macOS a Android, do budoucna také Windows.
  Všechny platformy sdílejí stejné herní jádro. Aktuální plán je
  v `docs/PLAN_VYVOJE.md`, herní design v `docs/HERNI_DESIGN.md`.
  Aplikace startuje `main/app.tscn` (menu), mise hraje `main/game_origami.tscn`
  (2D origami), která dědí základ `main/game.tscn`. 2.5D zobrazení bylo
  na přání autora vyřazeno (4. 10. 2026); neobnovovat ho.
- Autor (Jenda) neprogramuje – tvoří přes vibecoding. Komunikuj **česky**,
  tykej, vysvětluj jednoduše, odpovědi drž krátké (čte z mobilu).
- Po každé větší změně aktualizuj `PROJECT_STATUS.md`.
- Architektura je popsaná v `docs/ARCHITEKTURA.md` – drž se jí.

## Předávání Android sestavení
- Jenda chce každé hotové APK nahrát na svůj Google Disk a dostat odkaz.
  Toto je trvalá preference pro další sestavení; samotné nahrání do jeho
  Disku nevyžaduje opakované potvrzení. Zachovat číslované verze souborů.
- Připojení pro zápis ani cílová složka zatím nejsou nastavené. Neoznačovat
  nahrávání za funkční nebo soubor za nahraný bez ověření skutečného přenosu.
- Propojení Disku je na přání Jendy odložené. Aktuální APK předávat přes
  existující GitHub repozitář v samostatné větvi `downloads/android-<verze>`.
  Od rc2 autor požaduje Windows a nový samostatný Android s hudbou také na
  `jenda.cool/paperlings/` (web: `JendaNDT/JendaWeb`, větev `main`, automatické nasazení).
  Odkaz na soubor uvnitř cloudového pracovního prostoru mu nestačí ke stažení.
- Současně udržovat aktuální zdrojový kód na původní pracovní větvi
  `ccr-ee49bb72-jyyh2r`. Instalační APK patří pouze do větve pro stažení.
- **Vydání (od 1.0.0-rc1):** verze je jen v `project.godot`
  (`X.Y.Z` nebo `X.Y.Z-rcN`); `python scripts/release.py build` ji promítne
  do předvoleb (versionCode = M·10⁶ + m·10⁴ + p·100 + rc/99), spustí kontrolu,
  exporty a balíčky v `build/release/<verze>/`. APK jde do větve
  `downloads/android-<verze>` jako `android/Paperlings-<verze>-Android.apk`
  (+ `android/SHA256SUMS`), poznámky do `docs/vydani/<verze>.md`. Push větve
  `vydani/<verze>` na zdrojový commit spustí workflow *Vydání* (prostředí
  nesmí pushovat značky – 403): Windows a macOS sestaví CI z ověřeného Godotu
  a šablon (`scripts/install_templates.py`), přidá APK z větve, vytvoří
  značku `v<verze>` a GitHub Release (rc = předběžné vydání).

## Architektonická pravidla
- `sim/` = čistá logika: žádné uzly (Node), žádný `Input`, žádná náhoda,
  žádný reálný čas, herní pravidla používají celá čísla. Čas posouvá jen `LevelSim.tick()`.
- `view/` a `ui/` simulaci jen čtou. Příkazy posílají přes `assign_skill()`
  a `change_release_rate()` / `start_nuke()`, které vedou do jednotného `apply_command()`.
  Provedou se okamžitě mezi tiky i při pauze; pořadí v `replay_log` je závazné.
- Nový stav lumíka = nový soubor v `sim/states/` (dědí `LemmingState`)
  + zaregistrovat v `LevelSim._init()` + případně `Lemming.State` / `Lemming.Skill`
  a `LevelSim._state_for_skill()`.
- Laditelná čísla patří do `sim/sim_const.gd`.
- Voda, láva a jednosměrné zdi jsou v kanálu A masky (`TerrainMask.Special`),
  pasti v `LevelSpec.traps`; pořadí v tiku je popsané v `LevelSim`. Zobrazení je
  jen čte. Nové levely kontroluje `LevelValidator` (test všech misí).
- Komentáře a texty v UI česky. Klávesy přes `physical_keycode`.
- Nepoužívat assety ani levely z originální hry.
- `PaperCamera` je jediný převod logika ↔
  obrazovka ve 2D (terén, postavy, líheň, východ, schody i dotyk). Paralaxní
  vrstvy kameru jen čtou. Maska dál řídí kolize; její revize oblastí se
  pouze čtou. Každý renderer sleduje revize samostatně.
- Podklady mají kontrolní součty v manifestech `assets/*.lock.json`.
  Při záměrné úpravě eviduj odvození; nepřepisuj kontrolní součet jen kvůli
  umlčení nečekané změny. Písmo Nunito je v `assets/fonts/` (manifest
  `assets/fonts.lock.json`, licence OFL). Origami sada
  je v `assets/origami/` (generátor v `source/`, manifest
  `assets/origami.lock.json`). Všechny manifesty ověřuje
  `scripts/check_assets.py`; po úpravě podkladů spusť
  `python assets/origami/source/build_all.py`. Font OFL musí být distribuovaný s licencí.
  Zvuky jsou v `assets/audio/` (generátor `source/build_sfx.py`, manifest
  `assets/audio.lock.json`, mix `sfx.json`); hraje je `GameAudio`, simulaci jen čte.
  Hudba je v `assets/music/` (čtyři uživatelem dodané nahrávky, převod
  `source/build_music.py`, původ a podmínky uvnitř, manifest `assets/music.lock.json`).
  `GameMusic` v aplikaci střídá skladby podle pořadí misí modulo 4,
  prolíná smyčky i změny misí na sběrnici Music. Restart stejné skladby,
  pauza a rychlost simulace ani přetočení nesmějí měnit přehrávání.
  Headless testy jsou tiché; skutečný mix ověřuje `scripts/qa_music.gd`
  v grafickém Godotu s Movie Makerem. Podrobnosti: `docs/HUDBA.md`.
  Pracovní fázi animace řídí tiky, nikoli čas enginu.
- Hlavní scéna je `main/app.tscn` (`App`: menu, spouštění a uvolňování hry).
  Postup a nastavení zapisovat jen přes `SaveFile` (`Progress`, `GameSettings`);
  nová položka nastavení potřebuje výchozí hodnotu a rozsah v `GameSettings`.
  Nová mise potřebuje jedinečné `level_id` (po vydání neměnit) a zařazení
  do `Campaign.SCENES`. Rozehraná mise se ukládá jen jako `replay_log` + tik.
- Kampaň a obtížnost navrhuje `docs/HERNI_DESIGN.md`. Každá mise má
  referenční řešení v `tests/reference_plans.gd`; její změřený index
  (`scripts/difficulty_report.gd`, `LevelDifficulty`) musí ležet v cílovém
  rozsahu z dokumentu. Po změně pravidel nebo misí report znovu spustit.
  Mise nese `master_saved` (výsledek referenčního řešení = ★★★),
  `difficulty_index`, úvod a nápovědy; report hlídá shodu s měřením.
  Záznam řešení pro Ukázku (`solution`) po změně misí nebo plánů obnoví
  `scripts/update_solutions.gd`; `test_difficulty` hlídá shodu s plánem.
  Pád z povrchu do jeskyně musí být pod 60 px (jinak lumíci zemřou).
  Zdi, kmeny a hráze na zemi zapustit pod povrch (spodní hrana pod
  terénem), jinak pod nimi lumíci projdou škvírou.
- APK se exportuje jen přes `scripts/export_android.sh`; podpis musí
  odpovídat otisku ve `scripts/android_signing.txt` (stejný podpis pro další
  aktualizace nové aplikace). Export používá release klíč a proměnné
  `PAPERLINGS_KEYSTORE_PATH`, `PAPERLINGS_KEYSTORE_PASSWORD_FILE`,
  `PAPERLINGS_KEYSTORE_ALIAS` (výchozí `paperlings`) a `APKSIGNER_BIN`.
  Klíč ani heslo nikdy neukládat do repozitáře. Android zálohování je vypnuté;
  první instalace nového balíčku začíná bez starého postupu.
- Mobilní ovládání je v `TouchControls`, profil v `DeviceProfile` a nastavení
  `.mobile`/`.android`. Dotyk přiděluje až při uvolnění bez posunu; emulovaná
  myš nesmí ve hře vytvořit druhý příkaz. Dotyky začaté v HUDu patří pouze HUDu.
- Přelet mapy (`PaperFlyover`, vrstva `FlyoverHint`) a ukazatele k východu
  (`PaperGuide`) jsou jen vzhled: simulace během přeletu stojí, kamera
  zůstává jediným převodem a první klepnutí přelet jen přeskočí.
- Licence hry (rozhodnutí autora): volně ke hraní, ostatní práva vyhrazena
  (`LICENSE.txt`, `AboutPanel.license_summary()`). Titulky uvádějí autora
  „Jenda“. Nová součást třetí strany musí do `LICENSE.txt` a „O hře → Licence“.
  Návod pro hráče je v `docs/NAVOD.md`, hlášení chyb přes `BugReport`.
- Proč dovednost nejde dát, rozhoduje jen `SkillRules.refusal()` (sim);
  `can_assign()` je zkratka. Texty hlášek jsou v `PlayInfo`. Minimapa
  (`Minimap`) simulaci jen čte, kameru přesouvá hra; dotyk začatý na ní
  nepatří herní ploše. Po změně kampaně nebo HUD spustit
  `scripts/soak.gd` a `scripts/qa_resolutions.gd`.

## Výtvarná reference
- Kapitoly mají vlastní vzhled (`PaperTheme`, krajiny z
  `assets/origami/source/build_themes.py` v `layers/<téma>/`); jen dekorace,
  louka kapitoly I a menu zůstávají. Počasí řídí herní čas, ne simulace.
  Patrové mise (jedna v každé kapitole) mají prostředí podzemí přes
  `LevelDefinition.scenery`; téma se nastaví před `setup()` terénu.
  V patrových misích dav padá do díry od horní hrany podlahy – kratší
  pád zajistí jen vyšší místo pod dírou (hromada, římsa).
- Jediný aktuální návrh je **2D origami s paralaxním posunem a zoomem**:
  `docs/MOCKUP_ORIGAMI.md` a `docs/images/mockup-origami-prvni-kroky.png`.
  Autor návrh přijal a požádal odstranit všechny předchozí grafické návrhy.
- Staré koncepty, jejich snímky a samostatná studie v3 byly odstraněny.
  Neobnovovat je jako alternativní výtvarný cíl z historie Git.
- Pořadí práce: mockup, oddělené grafické vrstvy, postavička s animacemi,
  scéna Godotu. Origami renderer je implementovaný (`view/paper_*`);
  ověření a meze jsou v `docs/ORIGAMI_OVERENI.md`.
- Simulace zůstává společná. Herní vrstva sdílí jeden převod souřadnic,
  dekorativní paralaxa nesmí měnit kolize ani výběr postav. HUD je pevný.
- Technické testy nejsou dokladem výtvarné kvality. Generovaný koncept
  nikdy nepředávat jako důkaz změny skutečné hry.

## Ověření změn
V připraveném cloudu je Godot 4.7. V nové shell relaci nejprve:

```bash
source /workspace/.cloud-setup/lemmings-2026/activate.sh
```

Přenosné ověření z kořene repozitáře:

```bash
python scripts/check.py
```

Skript kontroluje i nové nesledované GDScripty, izoluje import a cache,
spouští všechny `tests/test_*.gd` a hlídá chyby v logu i návratové kódy.
Logy jsou v `build/checks/`. Pro měření simulace přidej `--benchmark`.
Mimo připravený cloud nainstaluj standardní Godot 4.7 a Python závislosti
ze `scripts/requirements-dev.txt` (postup v README).
Export: `bash scripts/export_desktop.sh macos`. Headless testy nepotvrzují
vykreslování ani spuštění na macOS/Windows. Výsledky jsou
v `docs/ETAPA_1_OVERENI.md` a `docs/ETAPA_2_SIMULACE.md`.

Pozor na typování: `:=` nejde použít na hodnotu typu Variant
(např. `dict.get()`, `max()`), používej `maxi/maxf/absi/lerpf…`
nebo explicitní typ.
