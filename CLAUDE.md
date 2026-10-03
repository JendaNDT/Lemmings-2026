# Lemmings 2026 – pokyny pro AI asistenta

## Kontext
- Moderní předělávka Lemmings (1991) v **Godot 4.7 + GDScript**.
- Testovací sestavení existují pro macOS a Android, do budoucna také Windows.
  Všechny platformy sdílejí stejné herní jádro. Aktuální plán je
  v `docs/PLAN_VYVOJE.md`. Výchozí scéna je `main/game_origami.tscn`
  (2D origami); `main/game_3d.tscn` (2.5D) a původní `main/game.tscn`
  zůstávají pro porovnání.
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
  existující GitHub repozitář v samostatné větvi `downloads/android-0.4.0`.
  Odkaz na soubor uvnitř cloudového pracovního prostoru mu nestačí ke stažení.
- Současně udržovat aktuální zdrojový kód na původní pracovní větvi
  `ccr-ee49bb72-jyyh2r`. Instalační APK patří pouze do větve pro stažení.

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
- `ClaySpace` je jediný převod do 3D, `PaperCamera` jediný převod logika ↔
  obrazovka ve 2D (terén, postavy, líheň, východ, schody i dotyk). Paralaxní
  vrstvy kameru jen čtou. Maska dál řídí kolize; její revize oblastí se
  pouze čtou. Každý renderer sleduje revize samostatně.
- Podklady v `assets/clay/` mají kontrolní součty v `assets/clay.lock.json`.
  Při záměrné úpravě eviduj odvození; nepřepisuj kontrolní součet jen kvůli
  umlčení nečekané změny. Nový model, font a ikony jsou v `assets/art_v2/`
  s vlastním `assets/art_v2.lock.json`, původem a licencemi. Origami sada
  je v `assets/origami/` (generátor v `source/`, manifest
  `assets/origami.lock.json`). Všechny manifesty ověřuje
  `scripts/check_assets.py`; po úpravě podkladů spusť
  `python assets/origami/source/build_all.py`. Font OFL musí být distribuovaný s licencí.
  Zvuky jsou v `assets/audio/` (generátor `source/build_sfx.py`, manifest
  `assets/audio.lock.json`, mix `sfx.json`); hraje je `GameAudio`, simulaci jen čte.
  Hudbu doplní autor později (sběrnice Music).
  Pracovní fázi animace řídí tiky, nikoli čas enginu.
- Mobilní ovládání je v `TouchControls`, profil v `DeviceProfile` a nastavení
  `.mobile`/`.android`. Dotyk přiděluje až při uvolnění bez posunu; emulovaná
  myš nesmí ve hře vytvořit druhý příkaz. Dotyky začaté v HUDu patří pouze HUDu.

## Výtvarná reference
- Jediný aktuální návrh je **2D origami s paralaxním posunem a zoomem**:
  `docs/MOCKUP_ORIGAMI.md` a `docs/images/mockup-origami-prvni-kroky.png`.
  Autor návrh přijal a požádal odstranit všechny předchozí grafické návrhy.
- Staré koncepty, jejich snímky a samostatná studie v3 byly odstraněny.
  Neobnovovat je jako alternativní výtvarný cíl z historie Git.
- Pořadí práce: mockup, oddělené grafické vrstvy, postavička s animacemi,
  scéna Godotu. Origami renderer je implementovaný (`view/paper_*`);
  ověření a meze jsou v `docs/ORIGAMI_OVERENI.md`.
- Herní podklady `assets/clay/` a `assets/art_v2/` se zachovávají, dokud
  je používá dosavadní hra. Jejich zamčení a licence dál platí.
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
