# Zvuky

3. října 2026. Hra má papírové zvukové efekty, okolní zvuky krajiny
a zvuky rozhraní. Hudbu autor doplní později (má připravenou sběrnici).

- **Poslech:** [`audio/zvukova-ukazka.m4a`](audio/zvukova-ukazka.m4a) –
  všechny efekty za sebou (seznam časů níže).
- **Ve hře:** [`images/zvuk-mise6.mp4`](images/zvuk-mise6.mp4) – celá mise 6
  nahraná přímo z Godotu i se zvukem (režim Movie Maker).
- **Ztlumení:** klávesa **T** nebo tlačítko s reproduktorem vpravo v dolní
  liště. Volba se pamatuje i po novém spuštění.

## Co zní

| Čas v ukázce | Zvuk | Kdy |
|---|---|---|
| 0:00 | ťuknutí dřeva | tlačítka, zrychlení, restart, výběr mise |
| 0:01 | ťuknutí papíru | výběr dovednosti |
| 0:02 | drobné cvaknutí | změna rychlosti vypouštění |
| 0:02 / 0:03 | přetočení listu dolů / nahoru | pauza / pokračování |
| 0:04 | tlumené „bonk“ | dovednost tomuto lumíkovi přidělit nejde |
| 0:05 | vrzání pantů a klapnutí dvířek | otevření líhně |
| 0:06 | třepetání papírku | lumík vypadne z líhně |
| 0:07 | lupnutí a cinknutí | přidělení dovednosti |
| 0:08–0:10 | hlína, úder krumpáče, šikmé kopání | kopáč, razič, horník |
| 0:10 | rozložení harmonikové cihly | stavitel položí cihlu |
| 0:11 | dva tóny hracího strojku | stavitel má poslední tři cihly |
| 0:12 | kovové cinknutí | razič nebo horník narazí na ocel nebo zeď proti šipkám |
| 0:13 | vzestupná zvonkohra | lumík dojde do východu |
| 0:15 | zmačkání papíru a žuchnutí | pád z velké výšky |
| 0:16 | klesající hvízdnutí | pád pod spodní okraj mapy |
| 0:17 | papírový výbuch | bombič, hromadné ukončení |
| 0:18 / 0:20 | šplouchnutí / bublinky | lumík spadne do vody / utone |
| 0:21 / 0:22 | vzplanutí / syčení | lumík se dotkne lávy / shoří |
| 0:24 | cvaknutí čelistí a polknutí | past sežere lumíka |
| 0:25 | syčení doutnáku | spuštění hromadného ukončení |
| 0:26 / 0:28 | krátká znělka | výhra / prohra |
| 0:30 | vítr v krajině | stále, potichu |
| 0:35 | šplouchání vody | z místa vody v levelu |
| 0:39 | bublání lávy | z místa lávy v levelu |

Zvuky v herní ploše znějí z místa události: vlevo nebo vpravo podle polohy
na obrazovce a mimo záběr tišeji. Smyčky vody a lávy stojí u jejich
jezírka či jámy. Stejný zvuk se v krátkém odstupu nezopakuje a během
jednoho snímku začne nejvýš šest zvuků, takže zrychlení ani hromadné
ukončení zvuk nezahltí. Výška tónu se při každém přehrání nepatrně liší.

## Jak to je postavené

- **Podklady** `assets/audio/`: efekty `sfx/` (WAV mono 44,1 kHz) a smyčky
  `loops/` (22,05 kHz), mix `sfx.json` (hlasitost, rozptyl výšky, odstup,
  počet hlasů, sběrnice), původ `provenance.json`, licence `LICENSE.txt`.
  Vše vytváří skript `assets/audio/source/build_sfx.py` syntézou z šumu,
  filtrů a tónů s pevnými seedy – žádné nahrávky ani cizí zvuky.
  Kontrolní součty jsou v `assets/audio.lock.json` a ověřuje je
  `scripts/check_assets.py`; `build_sfx.py --check` potvrdí, že generátor
  dává bit po bitu stejné soubory.
- **Ve hře** `view/game_audio.gd` (`GameAudio`): převádí události simulace
  na zvuky, hlídá otevření líhně a spuštění odpočtu, hraje smyčky
  a zvuky rozhraní. Simulaci jen čte; náhoda výšky tónu je místní.
  Sběrnice `SFX`, `UI`, `Ambient` a `Music` vedou do `Master`, kde je
  omezovač špiček. Hlasitosti i ztlumení ukládá `GameSettings` přes `SaveFile`.
- V automatických testech bez obrazovky se zvuky jen zaznamenají
  (nepřehrávají), aby po rychlém ukončení testu nezůstaly v mixéru.

## Ověření

- `python scripts/check.py`: **74 GDScriptů, 11 sad, 327 kontrol, vše
  v pořádku**. Nová sada `tests/test_audio.gd` (23 kontrol) ověřuje, že
  každá událost simulace (17 typů, čteno přímo ze zdrojů `sim/`) má zvuk,
  že se všechny podklady načtou, omezení opakování a počtu, místo zvuku
  na obrazovce, ztlumení i jeho uložení, sběrnice a napojení na skutečnou
  origami scénu (líheň, vypadnutí, výběr, přidělení, odmítnutí, vypouštění,
  pauza, tlačítko zvuku bez herního příkazu, smyčky vody a lávy v misi 6,
  znělka na konci). Ostatní sady se zvukem dál procházejí beze změny
  výsledků simulace.
- Záznam mise 6 se zvukem vznikl přímo z Godotu (Movie Maker, 30 snímků/s,
  zvuk 48 kHz stereo) při skutečném přehrávání.

## Meze

- Zvuky jsem nemohl poslechnout; posuzoval jsem jejich průběh, spektrum
  a hlasitost a zkontroloval záznam ze hry. Jak znějí, musí posoudit autor.
- Zvuky jsou v [APK 0.5.0](ANDROID_DEMO.md); na Macu ani v telefonu zatím
  neověřené.
- Aktualizace 5. 10. 2026: hlasitosti jsou v **Nastavení → Zvuk**,
  ve vývojových zdrojích je i [čtyřskladbová hudba](HUDBA.md).
  Původní záznamy výše dokládají samotné efekty z etapy zvuku.
