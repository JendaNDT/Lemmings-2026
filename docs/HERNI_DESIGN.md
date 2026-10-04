# Lemmings 2026 – herní design dokument

Verze 1.2 · 4. 10. 2026 · stav: **schváleno autorem, realizuje se**
([kroky 1–7 hotové](ETAPA_9_OVERENI.md))

Dokument popisuje, co hra umí dnes, kde má slabá místa, navrhuje kampaň
o 20 misích (15 nových), doplněnou o 4 patrové mise v podzemí (24 misí),
a systém obtížnosti, který se dá změřit.
Je podkladem pro [etapu 9 – kampaň](PLAN_VYVOJE.md) a část etapy 10.
Technické detaily jsou v [architektuře](ARCHITEKTURA.md).

---

## 0. Shrnutí na jednu obrazovku

- **Dnes:** 6 misí, 8 dovedností, voda, láva, pasti, jednosměrné zdi,
  menu, ukládání, papírová grafika a zvuky. Technicky je hra solidní:
  deterministická simulace, 402 automatických kontrol.
- **Hlavní slabina je obsah a křivka obtížnosti.** Změřená obtížnost dnešních
  misí skáče: **30 → 44 → 30 → 54 → 27 → 61**. Mise 2–4 jsou zkušební
  obdélníky se 4–6 lumíky, mise 5 je pískoviště se stejnou mapou jako mise 1
  a chybí výuka jednotlivých dovedností. Rychlost vypouštění zatím žádná mise
  nepotřebuje.
- **Systém obtížnosti** se neodhaduje, ale **měří**: referenční řešení mise
  se odehraje v simulaci a z něj vyjde index 0–100 (rezerva, přesnost
  klepnutí, počet zásahů, pestrost, zásoba, čas, nebezpečí) a pásmo
  Seznámení / Lehká / Střední / Těžká / Mistrovská. Hráč uvidí pásmo
  a sbírá 1–3 hvězdy. Místo režimů „lehká/těžká“ dostane **pomocníky**
  (nápověda, krok o tik, zpomalení).
- **Kampaň:** 4 kapitoly × 5–6 misí = 20 misí (5 stávajících upravených
  + 15 nových), k nim v každé kapitole jedna patrová mise v podzemí
  (celkem 24) a Hřiště mimo kampaň. Křivka stoupá „pilou“: každá kapitola
  začne oddechem a skončí zkouškou.
- **Hotové v kódu:** měření obtížnosti (`LevelDifficulty`), referenční
  řešení (`ReferencePlans`), report `scripts/difficulty_report.gd`
  a test `tests/test_difficulty.gd`.
- **Rozhodnout musíš ty:** kapitola 9 dokumentu.

---

## 1. Vize a pilíře

Moderní, ručně „složená“ papírová předělávka Lemmings: krátké logické
hádanky, které se dají hrát na telefonu po pár minutách a na počítači
v delším sezení.

1. **Čitelná hádanka.** Hráč vidí, co se stane, a chápe proč. Každá mise
   má jeden hlavní nápad.
2. **Férovost.** Simulace je deterministická: stejné klepnutí ve stejném
   tiku dá vždy stejný výsledek. Každá mise má ověřené řešení.
3. **Papírové diorama.** Vzhled a zvuk podporují pocit ručně vyrobeného
   světa; nikdy nemění pravidla.
4. **Krátké sezení.** Mise trvá 1–5 minut, postup se ukládá i uprostřed mise.
5. **Postupné učení.** Nová dovednost nebo nebezpečí se nejdřív ukáže
   samostatně, teprve potom v kombinacích.

---

## 2. Co hra umí dnes

### 2.1 Herní smyčka

Lumíci vypadávají z líhně a chodí, dokud nenarazí na stěnu (otočí se),
na sráz nebo na nebezpečí. Hráč jim přiděluje dovednosti z omezené zásoby.
Mise je vyhraná, když do východu dojde aspoň požadovaný počet lumíků do
vypršení času. Dovednosti jde přidělovat i v pauze. Simulace běží
17 tiků za sekundu, zrychlení je 3×.

### 2.2 Dovednosti – čísla pro tvorbu misí

Všechny hodnoty jsou z `sim/sim_const.gd` (logické pixely, tiky).
Lumík je vysoký **10 px**, jde rychlostí **1 px za tik** (17 px/s).

| Dovednost | Co dělá | Klíčová čísla |
|---|---|---|
| Lezec | trvale leze po stěnách | 1 px za tik nahoru; pod převisem se pustí a spadne |
| Padák | trvale chrání před pádem | otevře se po 16 px, pak 1 px za tik |
| Bombič | po 5 s vybuchne, pracuje dál | 85 tiků ≈ 85 px chůze; kráter o poloměru 16 px; lumík zemře |
| Blokař | zastaví se a otáčí ostatní | pole 6 px do stran; zůstane do konce, uvolní ho jen bomba nebo odkopaná zem pod ním |
| Stavitel | staví schody | 12 cihel, každá +1 px nahoru a +2 px dopředu (24 px a 12 px celkem), 11 s; poslední 3 cihly cvakají |
| Razič | razí vodorovný tunel | 8,5 px/s; začne jen do 8 px od zdi; ocel a zeď proti šipkám ho zastaví |
| Horník | kope šikmo dolů | 2 px dopředu a 1 px dolů za 4 tiky (sklon 1 : 2); tunelem jde chodit i nahoru |
| Kopáč | kope svisle dolů | 8,5 px/s, díra 9 px; ocel ho zastaví, jednosměrné zdi ne |

Další pravidla: schod do **6 px** lumík vyjde, sestoupí **3 px**, pád
**do 60 px** přežije. Běžící dovednost jde přepsat jinou (stavitel →
razič…), blokaře ne. Lezec a padák jdou kombinovat s čímkoli. Vypouštění
1–99 znamená lumíka každých `4 + (99 − hodnota) / 2` tiků (50 → 28 tiků,
99 → 4 tiky); hráč ho může měnit, ale ne pod hodnotu mise.

### 2.3 Terén a nebezpečí

- **Hlína** (kope se), **ocel** (nekope se), **výřez** (díra v terénu).
- **Voda** – lumík se utopí. **Láva** – shoří. Cihly přes vodu i lávu
  fungují jako most.
- **Jednosměrná zeď** – razič a horník jen ve směru šipek, kopáč bez omezení.
- **Past** (masožravá rostlina) – sežere jednoho, pak se dobíjí
  (výchozí 40 tiků, nastavitelné).
- Více líhní (střídají se) a více východů engine umí, žádná mise je zatím
  nepoužívá.

### 2.4 Dnešní mise

| # | Mise | Lumíci / cíl | Dovednosti | Mapa |
|---|---|---|---|---|
| 1 | První kroky | 20 / 10 | blokař 2, stavitel 3, razič 2, kopáč 2 | navržená krajina 640 × 200 |
| 2 | Lezec a padák | 6 / 6 | lezec 6, padák 6 | 3 obdélníky |
| 3 | Šikmý tunel | 6 / 6 | horník 2 | 2 obdélníky |
| 4 | Cesta skrz zeď | 4 / 3 | blokař 1, bombič 1 | 2 obdélníky |
| 5 | Všech osm dovedností | 20 / 10 | po 20 od každé | kopie mapy mise 1 |
| 6 | Voda, láva a past | 10 / 6 | lezec, stavitel 2, razič, kopáč | navržená krajina 560 × 200 |

### 2.5 Rozhraní a platformy

Hlavní menu s pokračováním, výběr misí se zámky a rekordy, nastavení
(zvuk, zobrazení, ovládání, velikost rozhraní 85–130 %, kvalita efektů),
pauzovací menu, výsledek s další misí, uložení rozehrané mise přes
replay. Ovládání myší, klávesnicí a dotykem. Testovací sestavení pro
macOS a Android, Windows později.

### 2.6 Technická struktura (krátce)

`sim/` čistá deterministická logika → `view/` papírová grafika
a `GameAudio` jen čtou → `ui/` HUD a menu posílají příkazy přes
`apply_command()`. Mise jsou scény Godotu z mnohoúhelníků, kontroluje je
`LevelValidator`. `App` spouští mise, `Progress` a `GameSettings` ukládají
přes `SaveFile`. Kampaň je seznam `Campaign.SCENES` se stabilními id.

---

## 3. Slabá místa

Seřazeno podle dopadu na hráče. **A** = řešit před rozšířením kampaně,
**B** = během kampaně, **C** = později.

### 3.1 Obsah a herní design

1. **A – Kampaň je krátká a mise 2–4 nejsou navržené.** Jsou to zkušební
   obdélníky se 4–6 lumíky. *Návrh:* kapitoly 5–6, úpravy v 5.4.
2. **A – Chybí výuka po jedné dovednosti.** Mise 1 hned chce raziče,
   stavitele i kopáče a první klepnutí má okno jen 9 tiků (0,5 s).
   *Návrh:* nové mise N1–N3 učí kopáče, stavitele a blokaře zvlášť;
   První kroky se stanou zkouškou kapitoly I.
3. **A – Nulová rezerva v raných misích.** Mise 2 a 3 chtějí 100 %,
   mise 2 a 4 spotřebují všechny dovednosti – jedna chyba = restart.
   *Návrh:* pravidla rezervy podle pásma (4.5).
4. **B – Pískoviště v řetězu odemykání.** Mise 5 je stejná mapa jako mise 1
   s 160 dovednostmi a odemyká misi 6. *Návrh:* Hřiště mimo kampaň.
5. **B – Nevyužité mechaniky.** Vypouštění, více líhní, více východů
   a časový limit zatím žádná mise nepotřebuje (referenční řešení
   spotřebují jen 20–32 % času). Padák, lezec, bombič a horník se objeví
   jen v jedné misi. *Návrh:* mise N7, N8, N11, N12, N14.
6. **B – Malá motivace hrát znovu.** Je jen rekord, žádný cíl navíc.
   *Návrh:* hvězdy (4.7).
7. **C – Čísla v názvech misí** („1 · …“). Přeřazení misí znamená
   přepsat názvy. *Návrh:* číslo dopočítat z pořadí v kampani.

### 3.2 Obtížnost

8. **A – Neplánovaná křivka.** Naměřeno 30 → 44 → 30 → 54 → 27 → 61
   (tabulka 4.6). *Návrh:* cílové indexy v 5.3, kontrola reportem.
9. **B – Přesnost bez pomůcek.** Některé zásahy mají okno 6–9 tiků
   (0,35–0,5 s). Pauza pomáhá, ale chybí krok o jeden tik a zpomalení.
   *Návrh:* pomocníci (4.8).

### 3.3 Výuka a rozhraní

10. **A – Na telefonu se hráč nedozví, co dovednost dělá.** Popisy jsou
    jen v bublinách při najetí myší (`Hud.SKILL_TIPS`); dotyk je neukáže.
    *Návrh:* úvodní karta mise s popisy a dlouhý stisk na dovednosti.
11. **A – Výběr misí se nevejde.** Mřížka se 3 sloupci bez posouvání
    unese ~6–9 karet; 20 misí se na obrazovku nevejde. *Návrh:* kapitoly
    jako záložky.
12. **B – Na začátku mise není vidět východ.** Kamera začíná přiblížená
    u líhně. *Návrh:* krátký přelet přes celou mapu a značka směru k východu.
13. **B – Dvojí „Ukončit“.** V liště spustí bomby všem, v menu zavře hru.
    *Návrh:* tlačítko v liště přejmenovat na „Odpálit vše“.
14. **B – Po prohře žádná rada.** *Návrh:* nápověda nabídnutá po 2 neúspěších.

### 3.4 Technika a distribuce

15. **A – Podpisový klíč Androidu se mění s každým cloudovým prostředím.**
    Nová verze pak nejde nainstalovat přes starou a odinstalace smaže
    postup. *Návrh:* uložit testovací klíč trvale (tajná proměnná
    prostředí), jednou provždy.
16. **B – Dvě starší zobrazení (2.5D, jednoduché 2D)** se dál udržují
    a testují (tři sady testů), APK nese ~5 MB jejich podkladů.
    *Návrh:* po tvém schválení 2.5D vyřadit.
17. **C – APK 66 MB** hlavně kvůli dvěma architekturám (32bitová ≈ 29 MB).
    *Návrh:* zvážit jen 64bitové ARM.
18. **C – Texty jen česky natvrdo v kódu.** Pokud bude někdy angličtina,
    vyplatí se překladový systém zavést před velkým množstvím textu.
19. **C – Výkon na telefonu neměřen.** Počítadlo FPS už v nastavení je.

---

## 4. Systém obtížnosti

### 4.1 Princip: měřit, ne odhadovat

Simulace je deterministická, takže obtížnost jde **změřit** na odehraném
referenčním řešení. Každá mise má v `tests/reference_plans.gd` plán
(kdy a komu přidělit co). Nástroj `LevelDifficulty.measure()` ho odehraje
na čisté simulaci a zjistí:

- **výsledek** (kolik zachránil) a **čas**,
- **zásahy** – všechny příkazy (dovednosti, změna vypouštění, odpálení),
- **okno každého zásahu**: zkouší ho posunout o 1, 2, 3… tiky dřív
  i později (ostatní zásahy zůstanou) a hledá, kdy mise přestane vycházet.
  Šířka okna říká, jak přesně musí hráč klepnout,
- **zásobu** – kolik z nabídnutých dovedností řešení spotřebuje,
- **nebezpečí** – kolik druhů (voda, láva, jednosměrné zdi, pasti),
- **„bez zásahu“** – kolik lumíků přežije, když hráč nic nedělá
  (mise nesmí jít vyhrát bez hraní).

### 4.2 Index obtížnosti 0–100

Každá složka je 0 (bez tlaku) až 1 (plný tlak), index je vážený součet:

| Složka | Váha | 0 = lehké | 1 = těžké |
|---|---|---|---|
| Rezerva záchrany | 25 | zachrání o 50 % lumíků víc, než je cíl | žádná rezerva |
| Přesnost | 25 | nejtěsnější okno ≥ 34 tiků (2 s) | okno ≤ 3 tiky |
| Zásahy | 15 | jeden zásah | 12 a víc těsných zásahů |
| Pestrost | 10 | jeden druh dovednosti | 5 a víc druhů |
| Zásoba | 10 | spotřebuje málo z nabídky | spotřebuje vše |
| Čas | 10 | do 30 % limitu | 90 % limitu a víc |
| Nebezpečí | 5 | žádné | 3 a víc druhů |

Zásahy se počítají vážené: zásah s pohodlným oknem (4 s) se počítá jako
poloviční. Rezerva a přesnost mají největší váhu, protože právě ony
rozhodují, jestli jedna chyba znamená restart.

**Proč tyto složky:** odpovídají tomu, co hráč cítí – „nesmím nikoho
ztratit“, „musím klepnout přesně“, „musím toho udělat hodně najednou“,
„nevím, kterou z mnoha dovedností“, „nemám nic navíc“, „nestíhám“.

**Mez:** index měří *provedení*, ne *nápad*. Mise, kde jde o jedno
chytré rozhodnutí (např. zvýšit vypouštění u pasti), vyjde nízko, i když
na ni hráč musí přijít. Proto má každá mise navíc štítek **„nápad“**
(ano/ne) a nápověda takové mise bere v úvahu.

### 4.3 Pásma

| Pásmo | Index | Hráč vidí | Rezerva záchrany | Nejtěsnější okno | Čas (z limitu) |
|---|---|---|---|---|---|
| 1 Seznámení | 0–19 | ● | ≥ 30 % | ≥ 17 tiků (1 s) | ≤ 50 % |
| 2 Lehká | 20–39 | ●● | ≥ 20 % | ≥ 8 tiků (razič začíná do 8 px od zdi) | ≤ 50 % |
| 3 Střední | 40–59 | ●●● | ≥ 10 % | ≥ 6 tiků | ≤ 75 % |
| 4 Těžká | 60–79 | ●●●● | ≥ 5 % | ≥ 4 tiky | ≤ 90 % |
| 5 Mistrovská | 80–100 | ●●●●● | může být 0 | ≥ 2 tiky | bez omezení |

Rezerva se počítá z referenčního řešení: (zachráněno − cíl) / lumíci.

### 4.4 Pravidla tvorby misí

1. Nová dovednost nebo nebezpečí se poprvé objeví **samo** (pestrost ≤ 2
   druhy) a mise je nejvýš o 10 bodů těžší než nejtěžší ze dvou předchozích.
2. Uvnitř kapitoly index roste; **první mise kapitoly smí klesnout** až
   o 25 bodů pod finále předchozí kapitoly (oddech po zkoušce).
3. Finále kapitoly kombinuje vše, co kapitola naučila.
4. Mise nesmí jít vyhrát bez zásahu (sloupec „bez zásahu“ < cíl).
5. V pásmech 1–2 má chyba druhou šanci: nabídnout aspoň o 1 dovednost
   navíc u těsných zásahů, nebo mapu, kde špatný pokus nikoho nezabije.
6. Změřený index musí ležet v cílovém rozsahu mise (tolerance ±7).
   Když ne, ladí se v tomto pořadí: cíl záchrany → zásoba → čas → mapa.

### 4.5 Jak se to ověřuje

1. Mise dostane `level_id`, zařazení v `Campaign.SCENES` a referenční
   plán v `ReferencePlans`.
2. `godot --headless --path . --script res://scripts/difficulty_report.gd`
   vypíše tabulku všech misí (≈ 45 s).
3. Index musí sedět s cílem z kapitoly 5; test `test_difficulty.gd`
   hlídá, že všechny mise mají vítězný referenční plán, a drží změřené
   hodnoty jedné mise, aby si změny vzorce nikdo nevšiml pozdě.
4. Autor misi zahraje. Měření nenahrazuje lidský pocit – jen hlídá, aby
   křivka neměla nechtěné skoky.

### 4.6 Změřená obtížnost dnešních misí

Skutečný výstup `scripts/difficulty_report.gd` (4. 10. 2026):

| # | Mise | Lumíci | Cíl | Ref. | Bez zásahu | Zásahy | Druhy | Kusy | Čas | Nejtěsnější okno | Index | Pásmo |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | První kroky | 20 | 10 | 20 | 0 | 3 | 3 | 3 / 9 | 20 % | 9 | 30 | Lehká |
| 2 | Lezec a padák | 6 | 6 | 6 | 0 | 12 | 2 | 12 / 12 | 22 % | 69 | 44 | Střední |
| 3 | Šikmý tunel | 6 | 6 | 6 | 0 | 1 | 1 | 1 / 2 | 32 % | 87 | 30 | Lehká |
| 4 | Cesta skrz zeď | 4 | 3 | 3 | 0 | 2 | 2 | 2 / 2 | 25 % | 14 | 54 | Střední |
| 5 | Všech osm dovedností | 20 | 10 | 20 | 0 | 3 | 3 | 3 / 160 | 20 % | 9 | 27 | Lehká |
| 6 | Voda, láva a past | 10 | 6 | 8 | 0 | 4 | 4 | 4 / 5 | 20 % | 6 | 61 | Těžká |

Co z toho plyne:

- Mise 2 a 4 jsou „Střední“ hlavně kvůli **nulové rezervě a zásobě**,
  ne kvůli těžkému nápadu – snadno se to spraví (5.4).
- Mise 1 má nejtěsnější okno 9 tiků: razič musí začít do 8 px od sloupu.
  Pro úplně první misi je to moc; jako zkouška kapitoly I je to v pořádku.
- Mise 6 (61) je správně nejtěžší, ale skok z 27 na 61 je příliš velký.
- Žádná mise nejde vyhrát bez zásahu – to je dobře.

### 4.7 Hodnocení hvězdami

- ★ – splnit cíl mise.
- ★★ – zachránit „dobrý výsledek“: cíl + polovina rozdílu k mistrovskému.
- ★★★ – zachránit tolik jako referenční řešení (**mistrovský výsledek**;
  je tedy zaručeně dosažitelný).
- Čas hvězdy neovlivní, zůstává jako rekord.
- Hvězdy se ukazují na kartě mise vedle teček obtížnosti. Za součet hvězd
  se mohou později odemykat bonusové výzvy; kampaň se odemyká jen splněním.

### 4.8 Pomocníci místo režimů obtížnosti

Režimy „lehká/normální/těžká“ by znamenaly navrhnout každou misi třikrát
a rozbily by férové srovnání rekordů. Místo toho mise drží jednu
obtížnost a hráč si může vzít pomoc, která **nemění pravidla**:

1. **Nápověda ve třech stupních** (v pauzovacím menu; po 2 neúspěších ji
   hra nabídne sama): 1) slovní tip, 2) zvýraznění místa a dovednosti,
   3) **ukázka** – přehrání referenčního řešení jako „duch“.
2. **Krok o jeden tik** v pauze – pro těsná okna.
3. **Zpomalení 0,5×** – hlavně pro dotyk.
4. **Přetočení o 5 s** – díky determinismu stačí přehrát záznam do tiku
   o 85 dřív (v plánu je pro verzi 1.1; lze zvážit dřív).

Použití ukázky se u výsledku jen označí ikonkou, hvězdy zůstanou.

**Stav (4. 10. 2026):** hotové body 1–3. Nápověda má textové tipy a jako
poslední stupeň **Ukázku řešení** v pauzovacím menu: mise se spustí znovu
a přehraje uložený záznam referenčního řešení (`LevelDefinition.solution`),
u každého zásahu zvýrazní dovednost i lumíka a natočí na něj kameru.
Ukázka se nezapisuje do postupu; pozdější výhra platí a výsledek jen
připomene „Po ukázce řešení“ (text místo ikonky). Po dvou neúspěších
výsledek ukázku nabídne. **Krok** v pauze posune hru o jeden tik
(klávesa tečka), tlačítko rychlosti přepíná 1× → 3× → ½× (klávesa F).
**−5 s** (tlačítko v liště, Backspace) vrátí hru o 85 tiků: hra drží
záložku stavu každých 5 s (minutu zpět) a přehraje jen kousek záznamu;
pozdější příkazy se zahodí, kamera, pauza i rychlost zůstanou.

**Orientace v mapě (4. 10. 2026):** po úvodní kartě **přelet mapy** –
kamera ukáže východ se štítkem „Východ“ a přeletí k líhni (asi 2,6–4,4 s,
čas mise mezitím stojí). Klepnutí, klávesa nebo Zpět přelet přeskočí;
restart, obnovená mise ani ukázka ho neopakují, vypnout jde v Nastavení →
Hra. Během hry ukazuje **šipka u okraje** směr k východu, když není
v záběru.

---

## 5. Kampaň

### 5.1 Kapitoly

| Kapitola | Téma a ladění | Učí | Pásma |
|---|---|---|---|
| I. Papírová louka | jaro, louka, první kopce | každou základní dovednost zvlášť | Seznámení → Lehká |
| II. Skalní les | jehličnany, kmeny, skály | ocel, bomby, řetězení stavitelů, vypouštění a čas | Lehká → Střední |
| III. Voda a oheň | řeka, sopka, masožravky | voda, láva, pasti, jednosměrné zdi | Lehká → Těžká |
| IV. Bouřková hora | vítr, vysoké útesy | dvě skupiny, přesnost, sestup, vše dohromady | Těžká → Mistrovská |

**Hřiště** (dnešní „Všech osm dovedností“) je mimo kampaň a otevře se
po kapitole I.

**Výpravy do podzemí:** v každé kapitole je jedna **patrová mise**
ve společném prostředí podzemí (jeskyně a důl s lucernami, krystaly
a netopýry). Mapa vede přes několik pater nad sebou shora dolů, jako
svislé úrovně původních Lemmings, a kapitola v ní použije, co právě učí.

### 5.2 Pořadí 24 misí

N = nová mise (karta v kapitole 6), U = stávající s úpravou (5.4),
P = patrová mise v podzemí (karty P1–P4 v kapitole 6).

| # | Mise | id | Druh | Učí / hlavní nápad | Cílový index |
|---|---|---|---|---|---|
| 1 | Díra v louce | `dira-v-louce` | N1 | kopáč, první klepnutí | 5–15 |
| 2 | Schody na terasu | `schody-na-terasu` | N2 | stavitel | 12–19 |
| 3 | Šikmý tunel | `sikmy-tunel` | U | horník | 15–24 |
| 4 | Hlídka u srázu | `hlidka-u-srazu` | N3 | blokař chrání dav | 18–26 |
| 5 | Důlní patra | `dulni-patra` | P1 | patra pod sebou, pád do 60 px | 22–30 (změřeno 25) |
| 6 | Lezec a padák | `lezec-a-padak` | U | trvalé vlastnosti | 26–34 |
| 7 | První kroky | `prvni-kroky` | U | zkouška: razič + stavitel + kopáč | 33–40 |
| 8 | Propadlo | `propadlo` | N5 | bomba otevře podlahu | 30–38 (změřeno 33) |
| 9 | Ocelové kořeny | `ocelove-koreny` | N4 | razič, ocel ho zastaví | 32–39 (změřeno 36) |
| 10 | Cesta skrz zeď | `cesta-skrz-zed` | U | blokař + bomba | 38–45 (změřeno 42) |
| 11 | Mraveniště | `mraveniste` | P2 | komory nad sebou, okna v oceli | 42–48 (změřeno 44) |
| 12 | Dlouhá lávka | `dlouha-lavka` | N6 | dva stavitelé v řadě, ohrádka | 45–52 (změřeno 51) |
| 13 | Mlýnský spěch | `mlynsky-spech` | N7 | zkouška: vypouštění a čas | 50–56 (změřeno 55) |
| 14 | Hladová kytka | `hladova-kytka` | N8 | past se dobíjí – hustý dav projde (nápad) | 30–38 (změřeno 37) |
| 15 | Šipky v útesu | `sipky-v-utesu` | N9 | jednosměrné zdi | 45–52 (změřeno 50) |
| 16 | Brod | `brod` | N10 | most přes vodu, uvolnění blokaře | 52–58 (změřeno 56) |
| 17 | Podzemní vodopád | `podzemni-vodopad` | P3 | terasy dolů: kytka, šipky, láva | 56–60 (změřeno 58) |
| 18 | Voda, láva a past | `voda-lava-past` | stávající | kombinace nebezpečí (změřeno 61) | 58–64 |
| 19 | Pod sopkou | `pod-sopkou` | N11 | zkouška: horník pod lávou, past, čas | 62–68 (změřeno 63) |
| 20 | Dvě líhně | `dve-lihne` | N12 | dvě skupiny současně | 63–70 (změřeno 66) |
| 21 | Hluboká šachta | `hluboka-sachta` | P4 | sestup šachtou: horník, okno v oceli, láva | 66–72 (změřeno 67) |
| 22 | Lávová lávka | `lavova-lavka` | N13 | přesnost na doraz | 72–78 (změřeno 73) |
| 23 | Velký sestup | `velky-sestup` | N14 | sestup bez padáků | 80–86 (změřeno 84) |
| 24 | Origami finále | `origami-finale` | N15 | vše dohromady | 85–92 (změřeno 91) |

### 5.3 Křivka obtížnosti (cíl)

Jeden dílek = 4 body indexu.

```
 1 Díra v louce        ██▌ 10
 2 Schody na terasu    ████ 16
 3 Šikmý tunel         █████ 20
 4 Hlídka u srázu      █████▌ 22
 5 Důlní patra ▼       ██████▎ 25
 6 Lezec a padák       ███████▌ 30
 7 První kroky ★       █████████▎ 37
 8 Propadlo            ████████▎ 33
 9 Ocelové kořeny      █████████ 36
10 Cesta skrz zeď      ██████████▌ 42
11 Mraveniště ▼        ███████████ 44
12 Dlouhá lávka        ████████████▊ 51
13 Mlýnský spěch ★     █████████████▊ 55
14 Hladová kytka       █████████▎ 37
15 Šipky v útesu       ████████████▌ 50
16 Brod                ██████████████ 56
17 Podzemní vodopád ▼  ██████████████▌ 58
18 Voda, láva a past   ███████████████▎ 61
19 Pod sopkou ★        ███████████████▊ 63
20 Dvě líhně           ████████████████▌ 66
21 Hluboká šachta ▼    ████████████████▊ 67
22 Lávová lávka        ██████████████████▎ 73
23 Velký sestup        █████████████████████ 84
24 Origami finále ★    ██████████████████████▊ 91
```
★ = zkouška kapitoly, ▼ = patrová mise v podzemí. Pila je záměrná: po
zkoušce přijde oddech.

### 5.4 Úpravy stávajících misí

| Mise | Dnes | Úprava | Proč |
|---|---|---|---|
| Šikmý tunel | 6 / 6, mapa z obdélníků | 8 lumíků, cíl 6, nakreslit krajinu | rezerva pro pásmo Lehká |
| Lezec a padák | 6 / 6, lezci 6, padáky 6 | 8 lumíků, cíl 6, lezci 10, padáky 10, krajina | nulová rezerva i zásoba (index 44 → ~30) |
| První kroky | cíl 10 / 20 | cíl 13 / 20, nápovědy | jako zkouška kapitoly I (30 → 38) |
| Cesta skrz zeď | 4 / 3, bombič 1 | 12 lumíků, cíl 9, bombič 2, krajina | 4 lumíci působí prázdně; druhá šance |
| Všech osm dovedností | mise 5 | Hřiště mimo kampaň | pískoviště nemá být v řetězu |
| Všechny | čísla v názvech | číslo z pořadí kampaně | přeřazení bez přejmenování |

`level_id` všech misí zůstávají; uložený postup se zachová. Pravidlo
odemykání se rozšíří: otevřené je vše až do nejvzdálenější splněné mise
+ 1, aby vložené nové mise nezamkly hráče, který už dál byl.

---

## 6. Patnáct nových misí

Legenda náčrtů: `█` hlína, `▓` ocel, `≈` voda, `^` láva, `→ ←` jednosměrná
zeď, `H` líheň, `E` východ, `T` past. Rozměry jsou výchozí hodnoty pro
stavbu; doladí se při měření. Hvězdy: ★ / ★★ / ★★★ = zachránit aspoň.

### N1 · Díra v louce

`dira-v-louce` · kapitola I, mise 1 · **Seznámení** (5–15) · nápad: ne

- **Učí:** vybrat dovednost a klepnout na lumíka; kopáč.
- **Mapa 320 × 160** · lumíci 10, cíl 7 · vypouštění 50 · čas 3:00
- **Dovednosti:** kopáč 2 · **hvězdy:** 7 / 9 / 10

```
   H
████████████████  louka 40 px
████████████████
                  jeskyně
           E
████████████████
```

- **Mapa:** louka (tloušťka 30 px) přes celou šířku, pod ní jeskyně
  s podlahou 55 px pod povrchem a východem. Líheň 25 px nad loukou.
- **Bez zásahu:** lumíci chodí sem a tam, nikdo neumře, čas vyprší.
- **Řešení:** kopáč kdekoli na louce; 30 px kopání ≈ 3,5 s. Ostatní
  propadnou dírou z povrchu až na dno jeskyně (55 px) – proto musí být
  jeskyně mělčí než 60 px pod povrchem.
- **Nápověda:** „Východ je pod zemí.“ → zvýraznit Kopáče → ukázka.

### N2 · Schody na terasu

`schody-na-terasu` · I/2 · **Seznámení** (12–19) · nápad: ne

- **Učí:** stavitel; schody stoupají o 1 px na každé 2 px.
- **Mapa 360 × 160** · lumíci 12, cíl 7 · vypouštění 50 · čas 3:00
- **Dovednosti:** stavitel 3 · **hvězdy:** 7 / 10 / 12

```
  H                    E
               █████████
████████████████████████
```

- **Mapa:** louka, vpravo terasa o 8 px výš s východem. Stupeň 8 px je
  vyšší než 6 px, lumíci se od něj otáčejí.
- **Bez zásahu:** nikdo neumře, čas vyprší.
- **Řešení:** stavitel 4–24 px před stupněm (okno ≈ 20 tiků). Začne-li moc
  brzy, schody skončí před stupněm a lumíci sejdou dolů – nikdo neumře,
  zkusí se to znovu.
- **Nápověda:** „Lumík vyjde schod jen do 6 px.“ → ukázat místo → ukázka.

### N3 · Hlídka u srázu

`hlidka-u-srazu` · I/4 · **Lehká** (18–26) · nápad: ano

- **Učí:** blokař chrání dav; blokař zůstane stát do konce mise.
- **Mapa 420 × 180** · lumíci 15, cíl 11 · vypouštění 50 · čas 3:00
- **Dovednosti:** blokař 2, kopáč 2 · **hvězdy:** 11 / 13 / 14

```
          H
█████████████████    sráz
█████████████████    ↓
  E    jeskyně
███████████████
```

- **Mapa:** plošina (tloušťka 30 px) končí vpravo srázem pod okraj mapy.
  Pod plošinou jeskyně s východem vlevo, dno 52 px pod povrchem.
  Líheň je jen 80 px od srázu.
- **Klíčová čísla:** první lumík je u srázu za ≈ 4,7 s, prokopání trvá
  ≈ 3,5 s – bez blokaře jich několik spadne.
- **Bez zásahu:** všichni spadnou ze srázu.
- **Řešení:** blokař mezi líhní a srázem, kopáč vlevo od něj; dav propadne
  do jeskyně. Blokař zůstane nahoře (proto mistrovský výsledek 14).

### N4 · Ocelové kořeny

`ocelove-koreny` · II/8 · **Lehká** (32–39, změřeno 36) · nápad: ne

- **Učí:** razič (musí začít do 8 px od překážky); ocel ho zastaví.
- **Mapa 520 × 200** · lumíci 20, cíl 13 · vypouštění 50 · čas 4:00
- **Dovednosti:** razič 2, kopáč 1, horník 1 · **hvězdy:** 13 / 17 / 20

```
  H    █      ▓
██████████████████████
██████  jeskyně     E
██████████████████████
```

- **Mapa:** hliněný kmen přehradí cestu; za ním je pod plošinou jeskyně
  s východem; druhý kmen má na úrovni chůze ocelové jádro. Vlevo od
  prvního kmene sahá hlína až ke dnu mapy.
- **Past na nepozorné:** kopáč vlevo od prvního kmene prokope dno
  a lumíci vypadnou z mapy; razič u ocelového kmene cinkne a vzdá to.
- **Řešení:** razič u prvního kmene (okno 8 tiků – razič musí začít do 8 px
  od kmene), kopáč mezi kmeny → dav spadne 50 px z povrchu do jeskyně. Horník před ocelovým kmenem je druhá cesta.

### N5 · Propadlo

`propadlo` · II/7 · **Lehká** (30–38, změřeno 33) · nápad: ano

- **Učí:** bomba ničí i podlahu; časování výbuchu (5 s ≈ 85 px chůze).
- **Mapa 360 × 180** · lumíci 10, cíl 7 · vypouštění 50 · čas 3:00
- **Dovednosti:** bombič 2, stavitel 2 · **hvězdy:** 7 / 8 / 9

```
 H
████████████████     ← podlaha 10 px
                 sráz
 jeskyně     █E
████████████████
```

- **Mapa:** tenká plošina (10 px) nad jeskyní, vpravo končí srázem.
  V jeskyni (pád 50 px z povrchu) je východ na stupni 10 px.
- **Bez zásahu:** všichni spadnou ze srázu.
- **Řešení:** bombič prvnímu lumíkovi hned po dopadu; vybuchne nad
  jeskyní a kráter (32 px) prorazí podlahu. V jeskyni stavitel před stupněm.
- **Riziko:** pozdní bomba vybuchne u srázu nebo za ním.

### N6 · Dlouhá lávka

`dlouha-lavka` · II/10 · **Střední** (45–52, změřeno 51) · nápad: ano

- **Učí:** dva stavitelé v řadě (druhého přidělit, když první pokrčí
  rameny); ohrádka drží dav, dokud není most hotový.
- **Mapa 480 × 200** · lumíci 20, cíl 15 · vypouštění 30 · čas 4:00
- **Dovednosti:** lezec 1, stavitel 3, razič 1 · **hvězdy:** 15 / 18 / 20

```
 H   █         E
█████████   ████████
█████████   ████████
   ohrádka  propast 40 px
```

- **Mapa:** líheň v ohrádce (zeď 20 px), za ní propast 40 px, za propastí
  východ. Zeď ohrádky je zapuštěná do terénu, aby pod ní nebyla škvíra.
- **Klíčová čísla:** jedny schody = 24 px, propast 40 px → dvoje schody.
  Nedokončený most = smrt pro každého, kdo po něm půjde.
- **Bez zásahu:** nikdo neumře (dav se přelévá v ohrádce).
- **Řešení:** lezec přeleze zeď; u propasti stavitel a při pokrčení ramen
  druhý (okno ≈ 8 tiků). Teprve pak razič otevře ohrádku zevnitř.

### N7 · Mlýnský spěch

`mlynsky-spech` · II/11 (zkouška) · **Střední** (50–56, změřeno 55) · nápad: ano

- **Učí:** rychlost vypouštění a časový limit.
- **Mapa 600 × 180** · lumíci 40, cíl 34 · vypouštění 20 · čas 1:50
- **Dovednosti:** razič 2, stavitel 2 · **hvězdy:** 34 / 37 / 40

```
 H       █          ▄▄▄▄ E
████████████████████████████
   hráz          stupeň k mlýnu
```

- **Klíčová čísla:** vypouštění 20 = lumík každých 43 tiků, 40 lumíků
  ≈ 100 s jen na vypuštění + 31 s cesty → bez zrychlení se poslední
  nestihnou. Na 99 vyjde lumík každé 4 tiky.
- **Bez zásahu:** nikdo neumře, nikdo nedojde.
- **Řešení:** razič prorazí hráz, stavitel postaví schody na stupeň,
  pak zvýšit vypouštění na 80–99.

### N8 · Hladová kytka

`hladova-kytka` · III/12 (oddech) · **Lehká** (30–38, změřeno 37) · nápad: ano

- **Učí:** past sežere jednoho a pak se dobíjí – hustý dav projde.
- **Mapa 440 × 160** · lumíci 20, cíl 14 · vypouštění 10 · čas 4:00
- **Dovednosti:** stavitel 2, blokař 1, bombič 1 · past s dobíjením 60 tiků
- **Hvězdy:** 14 / 16 / 18

```
 H      ▄▄▄▄▄▄   T        E
█████████████████████████████
     stupeň 8 px
```

- **Klíčová čísla:** při vypouštění 10 (každých 48 tiků) kytka sní
  každého druhého (změřeno: 10 z 20 – na cíl to nestačí). Při 99 (každé
  4 tiky) jich za jedno dobíjení projde 15; sní jen 4 (16 = ★★).
- **Bez zásahu:** dav se přelévá před stupněm, nikdo nedojde.
- **Řešení A:** stavitel na stupeň (okno 26 tiků, nedokončené schody
  jsou bezpečné), pak zvýšit vypouštění na 99 → 16. **Řešení B**
  (referenční, 18 = ★★★): stavitel, za stupněm blokař před kytkou
  (zpátky na stupeň se nevyleze, dav se nahustí), až jsou všichni u něj,
  bombič na blokaře – kytka sní jen jednoho.
- **Poznámka:** jádro mise je nápad, provedení je snadné –
  nápověda 1: „Kytka se po jídle chvíli dobíjí.“

### N9 · Šipky v útesu

`sipky-v-utesu` · III/13 · **Střední** (45–52, změřeno 50) · nápad: ne

- **Učí:** jednosměrné zdi – razič a horník jen po šipkách, kopáč vždy.
- **Mapa 520 × 200** · lumíci 20, cíl 16 · vypouštění 50 · čas 4:00
- **Dovednosti:** razič 2, horník 2, kopáč 1 · **hvězdy:** 16 / 18 / 20

```
 H   →      ←
█████████████████
███   střední   →
██████████████████
             dolní   E
██████████████████████
```

- **Mapa:** tři patra. Horní: zeď → (prorazit doprava), pak zeď ←
  (nejde razit ani horníkem). Kopáčem dolů do střední jeskyně (pád
  40 px). Vpravo je celý útes ze šipek →: razič by z něj vyšel 70 px nad
  dolním patrem (smrt), horník šikmo dolů vyjde jen 15 px nad zemí.
- **Klíčová čísla:** okno raziče 8 tiků, horníka 28 tiků (začne-li dřív,
  tunel vede pod úrovní východu).
- **Bez zásahu:** nikdo neumře, nikdo nedojde.
- **Chyba–učení:** razič u zdi ← jen cinkne.

### N10 · Brod

`brod` · III/14 · **Střední** (52–58, změřeno 56) · nápad: ne

- **Učí:** voda; most z cihel přes vodu; uvolnění blokaře bombou.
- **Mapa 480 × 180** · lumíci 15, cíl 12 · vypouštění 30 · čas 2:30
- **Dovednosti:** stavitel 3, blokař 1, bombič 1 · **hvězdy:** 12 / 13 / 14

```
 H                     E
█████████≈≈≈≈≈████████
█████████≈≈≈≈≈████████
         řeka 30 px
```

- **Bez zásahu:** všichni se utopí.
- **Řešení:** první lumík staví od břehu (dva stavitelé v řadě), druhý
  jako blokař ~35 px za ním drží dav (kráter bomby má poloměr 16 px –
  blíž by rozbil začátek mostu). Po dokončení mostu bombič na blokaře.

### N11 · Pod sopkou

`pod-sopkou` · III/16 (zkouška) · **Těžká** (62–68, změřeno 63) · nápad: ano

- **Učí:** horník pod lávou (hloubka tunelu), dav ve frontě, čas.
- **Mapa 600 × 220** · lumíci 25, cíl 20 · vypouštění 50 · čas 2:00
- **Dovednosti:** horník 2, stavitel 3 · past (dobíjení 120) · **hvězdy:** 20 / 21 / 22

```
 H      ^^^^^^   ▓
█████████████████████████
███       jeskyně   T  ▄E
█████████████████████████
```

- **Mapa:** louka končí stupněm 10 px dolů (zpátky se nevyleze – dav
  zůstane pohromadě mezi stupněm a jezerem). Lávové jezero 80 px široké,
  20 px hluboké. Pod ním jeskyně: kytka, pak jáma 12 px (zpátky ke kytce
  se nevyleze) a římsa s východem 20 px nad jámou.
- **Klíčová čísla:** tunel klesá 1 px na 2 px. Horník musí začít 46–90 px
  před jezerem (změřeno): později vede tunel lávou, dřív mine jeskyni.
  S vypouštěním 99 přijde dav ke kytce pohromadě a ta sní 3 (bez
  zrychlení 5 – jen na ★). Římsa 20 px = dva stavitelé v řadě.
- **Bez zásahu:** všichni shoří v jezeře.

### N12 · Dvě líhně

`dve-lihne` · IV/17 · **Těžká** (63–70, změřeno 66) · nápad: ne

- **Učí:** dvě skupiny najednou, dělení pozornosti.
- **Mapa 640 × 200** · lumíci 30 (dvě líhně střídavě), cíl 26 ·
  vypouštění 40 · čas 2:00
- **Dovednosti:** stavitel 4, blokař 1, bombič 1 · **hvězdy:** 26 / 28 / 29

```
  H         E          H
         ███████
███████████████ ≈≈ ███████
```

- **Mapa:** uprostřed kopec s východem. Zleva je stěna kopce 20 px –
  dva stavitelé v řadě přímo ke stěně (nedokončené schody jsou bezpečné,
  končí u stěny). Zprava je kopec nižší (stupeň 14 px, nahoru 6 px).
  Pravá skupina jde nejdřív doprava, odrazí se od skály a míří ke kanálu
  (20 px vody): lávka od samého břehu (okno 8 tiků), blokař ~40 px za
  ní drží dav, po přechodu lávky bomba.
- **Bez zásahu:** pravá skupina se utopí, levá se přelévá.
- **Stavba:** cíl 26 a čas 2:00 (při původních 22 a 4:00 index 52).
  Kopáč vypuštěn – nebyl k ničemu.

### N13 · Lávová lávka

`lavova-lavka` · IV/18 · **Těžká** (72–78, změřeno 73) · nápad: ne

- **Učí:** přesnost na doraz (pauza, krok o tik).
- **Mapa 560 × 180** · lumíci 20, cíl 18 · vypouštění 50 · čas 1:55
- **Dovednosti:** stavitel 4, blokař 1, bombič 1 · **hvězdy:** 18 / 19 / 19

```
 H                                    E
██████^^^^██████^^^^██████^^^^████████
      22 px     22 px     22 px
```

- **Klíčová čísla:** jámy jsou široké 22 px – jedna lávka je přesně
  na hraně, stavitel musí začít u samého okraje (okno 6 tiků u každé
  jámy).
- **Řešení:** blokař drží dav, první lumík staví u všech tří jam,
  bomba na blokaře. Jeden stavitel navíc opraví jeden chybný pokus.
- **Stavba:** tři jámy místo dvou a čas 1:55 (se dvěma jamami index 60).
  Mistrovský výsledek 19 (blokař padne), proto ★★ i ★★★ za 19.

### N14 · Velký sestup

`velky-sestup` · IV/19 · **Mistrovská** (80–86, změřeno 84) · nápad: ano

- **Učí:** sestup bez padáků – tunely a jámy rozdělí pády na ≤ 60 px.
- **Mapa 480 × 320** (vysoká) · lumíci 25, cíl 20 · vypouštění 50 · čas 1:40
- **Dovednosti:** padák 1, blokař 1, horník 2, kopáč 1, stavitel 1 ·
  **hvězdy:** 20 / 21 / 22

```
 H
█████████▓
     ↓70 ███████▓
        ↓64 ████████
           ↓58 ███▓
              ↓66 ███≈≈██E
```

- **Mapa:** čtyři terasy, srázy 70, 64, 58 a 66 px. U prvního a čtvrtého
  srázu ocelový lem s oknem se šipkami → (16 px): horníkův tunel jím projde
  jen, když horník začne v pásu 4 px (asi 70 px před prvním a 60 px
  před čtvrtým srázem). U druhého srázu
  ocelová krusta a hliněné okno 10 px u okraje; jáma v něm má ocelové dno
  30 px pod povrchem, takže z ní je sráz už jen 34 px. Dole jezírko 20 px.
- **Řešení:** padák prvnímu (průzkumník), druhý se nahoře stane blokařem
  a drží dav. Průzkumník kope jámu u druhého srázu a dole staví lávku.
  Teprve pak horník z davu prvním oknem, třetí sráz (58) je bezpečný,
  na čtvrté terase druhý horník. Lumíci těsně za horníkem ho předběhnou
  dřív, než vznikne tunel (referenčně padnou dva) – 22 z 25.
- **Proč blokař:** dav po tunelech předběhne průzkumníka (padák je pomalý)
  a utopil by se v jezírku dřív, než je lávka.

### N15 · Origami finále

`origami-finale` · IV/20 (zkouška hry) · **Mistrovská** (85–92, změřeno 91) · nápad: ano

- **Učí:** všechno dohromady.
- **Mapa 960 × 240** · lumíci 40 (jedna líheň), cíl 34 · vypouštění 30 · čas 4:00
- **Dovednosti:** lezec 1, padák 1, stavitel 6, razič 3, kopáč 2 ·
  **hvězdy:** 34 / 35 / 36
- **Úseky:** A) ohrada a řeka 30 px – lezec přeleze ohradu, dvoje schody
  přes řeku, razič pak otevře ohradu zevnitř; B) skála se šipkami →
  (razič) a skála se šipkami ← (nejde prorazit, kopáč před ní spadne
  do chodby pod skálou); C) uzavřená chodba se dvěma kytkami (dobíjení
  150) – průzkumník ji přeleze po střeše a seskočí s padákem 70 px,
  dav pustí razič až nakonec; D) lávová jáma 22 px na doraz; E) útes
  26 px – dvoje schody (začít 50–52 px před útesem).
- **Řešení:** průzkumník (lezec + padák) připraví celou cestu, dav zatím
  čeká v ohradě a pak v úseku B. Vypouštění hned na 99. Razič otevře
  ohradu po mostě a chodbu s kytkami po schodech na útes; kytky snědí 4.
- **Past na nepozorné:** stavitel, který u útesu narazí do stěny, se
  otočí a pod lávkou spadne do lávy.
- **Stavba:** jedna líheň místo dvou a bez blokaře, bombiče a horníka –
  mise zůstala čitelná a pestrost (5 druhů) je i tak plná.

### Patrové mise v podzemí (P1–P4)

Doplněné na přání autora (4. 10. 2026): první mise byly příliš vodorovné,
původní Lemmings působily svisleji (mapa 1600 × 160 px byla vidět celá
na výšku a vedla přes několik pater). V každé kapitole je proto jedna
patrová mise ve společném prostředí **podzemí**. Pravidlo pro stavbu:
dav padá do vykopané díry od horní hrany podlahy, ne ode dna díry, takže
díra zkrátí pád jen tam, kde je pod ní vyšší místo (hromada hlušiny,
římsa, okno v oceli nad suchou zemí).

### P1 · Důlní patra

`dulni-patra` · I/5 · **Lehká** (22–30, změřeno 25) · nápad: ano

- **Učí:** patra pod sebou a pravidlo 60 px.
- **Mapa 360 × 260** · lumíci 15, cíl 12 · vypouštění 50 · čas 3:00
- **Dovednosti:** kopáč 3 · **hvězdy:** 12 / 14 / 15
- **Stavba:** tři tenké podlahy nad sebou. Přes okraj je to do dalšího
  patra vždy 67 px (smrt), pod podlahou ale leží hromady hlušiny – díra
  nad hromadou vede jen 50 px dolů.
- **Řešení:** kopáč na 2. patře nad hromadou (cestou doleva), druhý
  na 3. patře nad hromadou na dně; dav dojde k východu (15/15).
- **Past na nepozorné:** díra vedle hromady pustí dav až na dno.

### P2 · Mraveniště

`mraveniste` · II/11 · **Střední** (42–48, změřeno 44) · nápad: ano

- **Učí:** komory nad sebou, ocel pod podlahou, bomba na chodci.
- **Mapa 420 × 230** · lumíci 20, cíl 15 · vypouštění 50 · čas 3:30
- **Dovednosti:** kopáč 2, bombič 2, stavitel 2 · **hvězdy:** 15 / 17 / 19
- **Stavba:** tři komory přes celou šířku; pod podlahami je ocel
  s jediným hliněným oknem (nahoře 40 px, uprostřed 80 px). Dolní komora
  končí stupněm 12 px ke dveřím.
- **Řešení:** kopáč v okně horní komory, ve druhé bomba chodci 85 px
  před oknem (za 5 s ujde přesně k němu), dole schody na stupeň (19/20).
- **Stavba mise:** blokař s bombou nad oknem měl okno 5 tiků a razič
  špuntu 6 tiků – na kapitolu II moc přesné, proto bomba na chodci.

### P3 · Podzemní vodopád

`podzemni-vodopad` · III/17 · **Střední** (56–60, změřeno 58) · nápad: ano

- **Učí:** terasy dolů, kombinace nebezpečí kapitoly.
- **Mapa 440 × 250** · lumíci 20, cíl 14 · vypouštění 50 · čas 2:30
- **Dovednosti:** blokař 1, razič 1 · **hvězdy:** 14 / 16 / 17
- **Stavba:** čtyři terasy po stupních (bezpečné skoky 45–50 px). Na druhé
  kytka (dobíjení 60), třetí zavírá skála se šipkami doprava a z jejího
  levého okraje se padá do lávy.
- **Řešení:** vypouštění hned na 99 (kytka sní 2), razič skrz šipky,
  blokař před okrajem nad lávou (17/20).

### P4 · Hluboká šachta

`hluboka-sachta` · IV/21 · **Těžká** (66–72, změřeno 67) · nápad: ano

- **Učí:** sestup šachtou, přesnost v řadě zásahů.
- **Mapa 420 × 320** · lumíci 25, cíl 19 · vypouštění 50 · čas 1:30
- **Dovednosti:** horník 1, kopáč 1, blokař 1 · **hvězdy:** 19 / 20 / 21
- **Stavba:** čtyři římsy střídavě vlevo a vpravo. Z druhé vede bezpečně
  jen šikmý tunel skalním pilířem, třetí má ocelovou podlahu s hliněným
  oknem 18 px nad suchou římsou, čtvrtá lávu 8 px od místa dopadu
  a kytku (dobíjení 150) před východem.
- **Řešení:** vypouštění na 99, horník na pilíři, kopáč v okně a týž
  lumík hned po dopadu blokařem před lávou (21/25).
- **Zařazení:** při cíli 76–80 by mise musela mít okna pod 5 tiků;
  proto stojí jako druhá v kapitole IV mezi Dvěma líhněmi a Lávovou lávkou.

---

## 7. Rozhraní a výuka pro kampaň

1. **Úvodní karta mise:** název, „Zachraň 11 z 15“, dovednosti s popisy
   (i na telefonu), štítek „Nové: Blokař“, tečky obtížnosti, hvězdy.
2. **Přelet mapy** na začátku a značka směru k východu, když je mimo
   záběr (hotovo, 4.8).
3. **Výběr misí po kapitolách** (záložky I–IV, 5–6 karet), tečky
   obtížnosti, hvězdy, součet hvězd kapitoly; Hřiště jako zvláštní karta.
4. **Nápověda** v pauzovacím menu a nabídka po 2 neúspěších (4.8).
5. **Dlouhý stisk na dovednost** ukáže popis (dotyk).
6. **„Odpálit vše“** místo „Ukončit“ v liště.
7. **Výsledek** ukáže hvězdy, co chybělo do další hvězdy a tlačítko
   nápovědy při prohře.

---

## 8. Plán realizace

Navazuje na [etapu 9](PLAN_VYVOJE.md) (kampaň) a část etapy 10 (pohodlí).
Každý krok končí kontrolou, reportem obtížnosti a APK k vyzkoušení.

1. **Systémy kampaně** – kapitoly v `Campaign`, číslování z pořadí,
   Hřiště mimo řetěz, tolerantní odemykání, hvězdy (prahy v
   `LevelDefinition`, ★★★ = výsledek referenčního řešení), úvodní karta,
   výběr po kapitolách, přejmenování „Odpálit vše“.
2. **Kapitola I** – N1, N2, N3 + úpravy Šikmého tunelu, Lezce a padáku
   a Prvních kroků. Nápovědy v datech mise.
3. **Pomocníci** – nápověda (texty, zvýraznění, ukázka z referenčního
   záznamu), krok o tik, zpomalení.
4. **Kapitola II** – N4–N7, úprava Cesty skrz zeď.
5. **Kapitola III** – N8–N11.
6. **Kapitola IV** – N12–N15.
7. **Patrové mise v podzemí** – P1–P4, jedna v každé kapitole.
8. **Ladění křivky** podle tvého hraní a reportu.

Každá nová mise: scéna s `level_id` → `LevelValidator` bez nálezu →
plán v `ReferencePlans` → report v cílovém rozsahu → test řešení →
dekorace → tvoje hraní.

---

## 9. Rozhodnutí autora (4. 10. 2026)

Autor schválil všech šest bodů: strukturu kampaně a přesun Prvních kroků
na konec kapitoly I, hvězdy, Hřiště mimo kampaň, názvy misí a kapitol,
vyřazení 2.5D zobrazení a trvalé uložení podpisového klíče Androidu.

**Stav realizace:** kroky 1 (systémy kampaně), 2 (kapitola I),
3 (pomocníci), 4 (kapitola II), 5 (kapitola III), 6 (kapitola IV)
a 7 (patrové mise) jsou hotové – kampaň má 24 misí,
2.5D je vyřazené, export hlídá stálý podpis
([ověření](ETAPA_9_OVERENI.md)). Změřené indexy kapitoly I: 15, 14, 18,
23, 32, 38. Při stavbě se upravily rozměry N1 a N3 (mělčí jeskyně – pád
z povrchu musí být pod 60 px) a cíl Prvních kroků na 13 z 20.

Kapitola II změřeno: 33, 36, 42, 51, 55. Propadlo a Ocelové kořeny se
prohodily (razič má okno nejvýš 8 tiků, kořeny jsou proto o kousek těžší),
pravidlo pásma Lehká je okno ≥ 8 tiků. Ocelové kořeny mají cíl 13,
Dlouhá lávka propast 40 px a cíl 15, Mlýnský spěch limit 1:50 (při 2:00
by cíl 34 šel splnit i bez zvýšení vypouštění).

Kapitola III změřeno: 37, 50, 56, 61, 63. Referenční řešení Hladové
kytky je blokař s bombou (18 z 20); zrychlené vypouštění dá 16 (★★),
proto má mise čas 4:00 (při 3:00 index 39, nad pásmem). Brod má cíl 12, čas 2:30
a 3 stavitele (při původních číslech index 48, pod pásmem). Pod sopkou
má čas 2:00 a kytku s dobíjením 120 (při 50 by snědla 5–6 a mistrovský
výsledek by splynul s cílem); stupeň na louce a jáma v jeskyni drží dav
pohromadě.

Krok 7 – patrové mise v podzemí (P1–P4) – je hotový: změřeno 25, 44, 58
a 67, kampaň má 24 misí. Každá je v prostředí podzemí (vlastní krajina
jeskyně a dolu, `LevelDefinition.scenery`), uzavřený prostor ukazuje
krajinu jeskyně místo hnědé stěny dutiny.

Kapitola IV změřeno: 66, 73, 84, 91. Dvě líhně mají cíl 26 a čas 2:00,
Lávová lávka tři jámy po 22 px a čas 1:55, Velký sestup blokaře, který
drží dav nahoře, a Origami finále jednu líheň. Hřiště se v menu přesunulo
do záhlaví, aby se vešly čtyři záložky kapitol.

---

## Příloha A – rychlý přehled čísel

| Veličina | Hodnota |
|---|---|
| Tiky za sekundu | 17 (zrychlení 3×) |
| Chůze | 1 px/tik |
| Výška lumíka | 10 px |
| Schod nahoru / dolů | 6 / 3 px |
| Bezpečný pád | 60 px |
| Líheň se otevře | po 34 tikách |
| Vypouštění 50 / 99 | lumík každých 28 / 4 tiků |
| Stavitel | 12 cihel, +1 px nahoru a +2 px dopředu, 16 tiků na cihlu |
| Razič / kopáč | 1 px za 2 tiky; razič začne do 8 px od zdi |
| Horník | 2 px dopředu, 1 px dolů za 4 tiky |
| Bomba | 85 tiků, poloměr 16 px |
| Blokař | pole 6 px |
| Východ | dosah ±2 px, 8 px nahoru |
| Past | dobíjení 40 tiků (výchozí) |

## Příloha B – měření obtížnosti

```bash
godot --headless --path . --script res://scripts/difficulty_report.gd \
  -- --out=build/difficulty.json
```

Vypíše tabulku z kapitoly 4.6 a uloží všechny složky indexu do JSON.
Vzorec a pásma jsou v `level_tools/level_difficulty.gd`, referenční řešení
v `tests/reference_plans.gd`, kontrola v `tests/test_difficulty.gd`.
