# Hudba po jednotlivých misích

Stav: 5. 10. 2026, hotovo v **1.0.0-rc2 pro Windows i Android**.
Starší balíčky 1.0.0-rc1 hudbu neobsahují. Autor výslovně zvolil nový
podpis a samostatnou Android aplikaci `cool.jenda.paperlings`: začíná
bez starého postupu. Kontrola nového podpisu zůstává zapnutá.

## Dodané nahrávky a pořadí

Čtyři soubory dodal Jenda do chatu s požadavkem střídat je po misích.
Pořadí odpovídá pořadí příloh, nikoli abecednímu řazení názvů.

| Skladba | Původní příloha | Délka | Mise kampaně |
|---|---|---|---|
| 1 | `Lemmings 1 (1).wav` | 95,2 s | 1, 5, 9, 13, 17, 21 |
| 2 | `Lemmings 1.wav` | 107,2 s | 2, 6, 10, 14, 18, 22 |
| 3 | `Lemmings 2 (1).wav` | 155,2 s | 3, 7, 11, 15, 19, 23 |
| 4 | `Lemmings 2.wav` | 162,4 s | 4, 8, 12, 16, 20, 24 |

Hřiště používá skladbu 1. V každé misi se opakuje pouze přidělená
skladba; konec nahrávky nepřepne na další skladbu. Pořadí pokračuje
i přes hranice kapitol.

## Chování ve hře

- Hudba začne při načtení mise (už na úvodní kartě). Přechod mezi
  skladbami trvá 0,7 s, překryv konce a začátku stejné skladby 1,2 s.
- Restart, ukázka řešení i přímý skok na jinou misi se stejnou skladbou
  ji nechají pokračovat. Běžná pauza, rychlosti ½× / 1× / 3×, krokování
  a návrat o pět sekund nemění hudební čas ani výšku tónu.
- Návrat do hlavního menu nebo výběru misí hudbu postupně ztiší.
  Při uspání mobilní aplikace se pozastaví oba hlasy, i během prolínání.
- **Nastavení → Zvuk → Hudba** ovládá stávající sběrnici Music,
  nula ji ztlumí. Volba se ukládá spolu s ostatním nastavením. Efekty
  zůstávají samostatné; celkové ztlumení stále vypíná všechny zvuky.
- `App` vlastní `GameMusic` přes přechody scén. Samostatná herní scéna
  v editoru si vytvoří vlastní přehrávač. Simulace není změněná.

## Soubory, původ a převod

`assets/music/` obsahuje čtyři OGG, podmínky použití, původ a převodní
skript; `assets/music.lock.json` je uzavřený seznam se SHA-256.
Godot `.import` soubory nastavují dekódování Vorbis bez tvrdé smyčky.
Její překryv obstarává `GameMusic` dvěma přehrávači. Neaktivní stream
se po prolínání uvolňuje; všechny čtyři skladby se nenačítají najednou.

Původní WAV (PCM 16 bit, stereo 48 kHz) zůstaly nezměněné a nejsou
součástí repozitáře. Vorbis q5, stereo 48 kHz zachovává jejich plnou
délku. Dvouprůchodové srovnání na −21 LUFS s cílem špičky −2 dBTP
a krátkými 25ms náběhy/dozvuky zmenšilo přibližně 99,9 MB na **9,88 MB**.
Naměřená hlasitost výsledků: −21,00 / −21,00 / −21,00 / −20,99 LUFS.
Přehrávač přidává −3 dB rezervy pro zvukové efekty a překryv.

Převod lze opakovat s původními přílohami (skript kontroluje jejich hashe):

```bash
python assets/music/source/build_music.py \
  --source-dir /cesta/k/puvodnim/wav \
  --output-dir /cesta/k/nove/sade
python scripts/check_assets.py
```

Výstupní složka převodu musí být nová. FFmpeg a jeho verze, měření,
zdrojové názvy, délky a hashe jsou v `provenance.json`. Autorství skladeb
nebylo uvedeno a není odvozováno z názvu příloh. Evidence použití pro
Paperlings je v `assets/music/LICENSE.txt`, také v herních titulcích,
licencích a exportních předvolbách. Ostatní podklady nebyly měněny.

## Ověření

- Čistý import, parser, styl a **18 sad / 473 kontrol** (97 GDScriptů).
  Headless režim stejně jako u efektů nespouští hlasy v neaktivním
  mixéru; eviduje výběr skladby. `test_music` tu ověřuje 18 podmínek.
- Stejný `test_music.gd` v grafickém Godotu s Movie Makerem:
  **26 kontrol**, navíc skutečně spuštěné hlasy, prolínání, seek ke konci,
  opakování, uspání během překryvu a uvolnění streamů. Integrace používá
  skutečnou aplikaci, HUD restart, skutečné přetočení a návrat do menu.
- `scripts/qa_music.gd`: **31sekundový záznam skutečného mixu Godotu**
  ve stereo 48 kHz, postupně všechny čtyři skladby a jejich opakování.
  Každá se vrátila do vlastního začátku. Všechny čtyři úseky i smyčky
  mají nenulový signál; RMS ukázek −27,45 až −26,32 dBFS. Výstup nemá
  oříznuté špičky. Po ztlumení a po dokončeném odchodu do menu je ticho;
  čtvrtinová hlasitost je v záznamu zřetelně nižší (RMS −38,50 dBFS).
- Exportovaný PCK obsahuje čtyři načitatelné hudební streamy se správnou
  délkou, přehrávač a podmínky použití.

Reprodukce zvukového QA (grafický Godot, Movie Maker zajišťuje skutečný
mix i bez fyzického reproduktoru; výstupní složku předem vytvořit):

```bash
godot --path . --rendering-driver opengl3 --audio-driver Dummy \
  --write-movie /tmp/music-qa/lifecycle.avi --fixed-fps 60 \
  --script res://tests/test_music.gd
godot --path . --rendering-driver opengl3 --audio-driver Dummy \
  --write-movie /tmp/music-qa/mix.avi --fixed-fps 60 \
  --script res://scripts/qa_music.gd -- --capture-dir=/tmp/music-qa
```

Scénář uloží `music-mix.wav` a `report.json` s úseky ve snímcích.
Kontrola v Linux cloudu nepotvrzuje přehrávání ani uspání na skutečném
Androidu, Windows či macOS. Prolínání tlumí spoj nahrávky; neslibuje
hudebně bezešvou smyčku nebo sladění úderů. Poslech a poměr hudby vůči
efektům na zařízení zbývá ověřit při hraní.
