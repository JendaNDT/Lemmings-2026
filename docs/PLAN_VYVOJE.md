# Plán vývoje Lemmings 2026 — 2.5D

Aktualizováno: 3. října 2026. Jde o plán budoucí implementace, nikoli o seznam hotových funkcí. Tato verze nahrazuje dřívější plán čistě 2D grafiky.

## Cíl a rozsah

Herní pravidla zůstanou ve 2D; zobrazení přejde na 3D terén, animované 3D postavy, světla a prostorové pozadí. Pevná ortografická kamera zachová přehlednost. Lumíci se pohybují v jedné herní rovině a rozhraní zůstane 2D.

**První hratelné sestavení je určeno pro macOS**, který má autor nyní k dispozici. Herní jádro zůstane společné pro macOS, budoucí Windows a Android. Windows zůstávají plánovanou cílovou platformou; jejich sestavení ani nativní testování nyní neblokují první etapu. **Android má testovací APK** pro telefon a tablet; nativní spuštění a výkon se ověří samostatně. Linux slouží jako cloudové vývojové a testovací prostředí, není slíbenou distribuční platformou.

Vydání 1.0 zahrne osm dovedností, 15–20 vlastních levelů, menu, nastavení, ukládání postupu, úvod do ovládání, grafiku a zvuk. Web, uživatelský replay, přetáčení času a editor ve hře patří do navazujících etap.

## Aktuální ověřený stav

- Cloud obsahuje standardní Godot 4.7 a nástroje pro kontrolu GDScriptu.
- Existuje simulace všech osmi dovedností, první level, tři další zkušební mise a hřiště, kamera a HUD.
- První level byl dokončen přes ovládání v samostatném Linux QA exportu (20/20), ověřeny shadery, kamera, rozlišení a restarty.
- Je připraven univerzální balíček pro macOS; nativní spuštění na MacBooku zbývá ověřit.
- Procházejí regresní kontroly mechanik, terénu, celého řešení a skutečné scény s HUD.
- Dovednosti i vypouštění mají společný záznam. Technický replay přes JSON opakuje průběh při různém tempu snímků; uživatelské rozhraní replaye je pozdější etapa.
- Přenosné kontroly byly ověřeny v čisté kopii s oddělenou instalací nástrojů. CI pro Linux a macOS je připravené; vzdálený výsledek CI dosud nebyl ověřen.
- Výchozí 2.5D scéna prošla první výtvarnou úpravou ve verzi 0.4.0; [skutečné snímky a ověření](GRAFIKA_04.md). Android má APK a dotykový profil; zvuk, nativní spuštění a výkon na cílovém zařízení dosud ověřeny nejsou.
- Příprava etapy 3: hotová první sada modelínových materiálů, modelů,
  animací a samostatná galerie. Podrobnosti v [podkladech prototypu](PODKLADY_PROTOTYPU.md).

## Pravidla implementace

- Simulace je jediným zdrojem pravdy o terénu, pohybu a výsledku levelu. Herní kolize se dál vyhodnocují podle 2D masky, nikoli podle 3D fyziky.
- Všechny platformy používají stejné GDScripty, pravidla a definice levelů. Platformní rozdíly patří do vstupu, grafických profilů, ukládání a exportních nastavení; logiku hry nekopírovat do samostatných větví pro každý systém.
- Grafická vrstva odvozuje vzhled ze simulace. Efekty, modely, světla a snímková frekvence nesmějí měnit výsledek.
- Zachovat tvorbu levelů z 2D definic v editoru; 3D dekorace ukládat odděleně od logických pravidel.
- Nové zobrazení přidávat souběžně s původním tak dlouho, dokud nebude ověřená shoda. Původní zobrazení může sloužit jako diagnostická pomůcka.
- Neprovádět velký přepis všech vrstev najednou. Každá etapa končí spustitelnou ukázkou a odpovídajícími kontrolami.

## Etapa 1 — Ověření základu a prvního exportu

**Stav:** cloudová část dokončena, macOS balíček připraven. Podrobnosti v [ověření etapy 1](ETAPA_1_OVERENI.md); spuštění přímo na MacBooku zůstává samostatnou kontrolou.

Graficky spustit současný první level, projít celé řešení a zkontrolovat kameru, klikání, shadery, rozhraní, zoom, různá rozlišení a opakované restarty. Opravit chyby bránící hraní. Připravit samostatnou aplikaci pro macOS (Apple Silicon a Intel) a aktualizovat stav projektu podle skutečného ověření. Linuxový export slouží k ověření zabalené hry v cloudu. Na přání autora se skutečné hraní a ověření kompatibility na Windows provede až v závěru vývoje; není podmínkou dokončení první etapy.

**Podmínka dokončení:** první level lze dokončit přes herní ovládání v samostatném testovacím sestavení v cloudu, existuje ověřený balíček aplikace pro macOS a automatické testy procházejí. Spuštění na autorově Macu je samostatná uživatelská kontrola; test v linuxovém cloudu ji nesmí vydávat za provedenou. Nativní ověření Windows zůstává výslovně odložené do etapy 11.

## Etapa 2 — Spolehlivá simulace a kontroly

**Stav:** implementováno a ověřeno na Linuxu v čisté kopii projektu. Pravidla, postup reprodukce a omezení jsou v [ověření etapy 2](ETAPA_2_SIMULACE.md).

Doplnit testy současných dovedností, bezpečných a nebezpečných pádů, oceli, východů a podmínek konce levelu. Sjednotit pořadí a záznam všech příkazů měnících simulaci, včetně vypouštění. Určit chování příkazů přidělených během pauzy a pořadí více příkazů ve stejném tiku.

Připravit přenosné spouštění kontrol a CI bez závislosti na konkrétní cestě cloudového prostředí. Zvolit referenční počítač a zátěžový scénář; předběžný cíl je 60 FPS při 1080p, dokud jej měření nezpřesní.

**Podmínka dokončení:** stejný level a příkazy dávají stejný výsledek při různém tempu vykreslování. Kontroly fungují i mimo onboardingový kontejner.

## Etapa 3 — Hratelný technický prototyp 2.5D

**Stav:** implementováno a ověřeno v cloudu. První level zachraňuje 20/20
přes herní vstup, geometrie odpovídá masce a výsledek simulace se shoduje
s původní verzí. Aktuální Mac sestavení je připravené. Podrobnosti, měření
a omezení jsou v [ověření etapy 3](ETAPA_3_OVERENI.md).

**Pořadí schválené autorem: grafické podklady → postavička a animace → hra.**
Autor vybral druhý koncept, **Modelínový svět**, a schválil celkový mockup.
První sada materiálů, modelů, rozhraní a světla i následná animační sada
jsou hotové jako samostatná galerie pro Godot; viz
[podklady prototypu](PODKLADY_PROTOTYPU.md). Součástí je pohybová studie
plastické hlíny. Hratelný 2.5D prototyp již na tuto přípravu navázal;
trvalé otvory v něm řídí maska společné simulace.
Celkový počet dvanácti etap zůstává stejný.

1. Vytvořit 3D herní scénu s pevnou ortografickou kamerou a připravenou sadou modelů, materiálů a světla. Animace napojit na stavy simulace, pracovní kontakt sladit se simulačními tiky.
2. Definovat převod logických souřadnic do 3D herní roviny. Převádět kliknutí kamery zpět na tuto rovinu a používat stávající logický výběr lumíka.
3. Z masky terénu vytvořit prostorový povrch s přední plochou a boky. Podporovat jeskyně, otvory, oddělené ostrůvky a ocel.
4. Rozdělit terén na menší části a přestavovat jen změněné části. Pohlídat společné hranice, normály a stíny, aby nevznikaly mezery nebo falešné překážky.
5. Zobrazit současné kopání, ražení a stavění přímo během hry. Hlína se při zásahu krátce promáčkne, protáhne a oddělí hrudku; trvalý otvor odpovídá masce. Dekorativní deformace nesmějí měnit schůdnost mimo simulaci. Kopání má tři klasické směry: vodorovně, šikmo dolů a svisle dolů; kopání vzhůru se nezavádí. Šikmý směr zapojit po doplnění horníka v etapě 4, výbuchy po doplnění bombiče.
6. Zachovat HUD, zoom, posun kamery a přesné označení cíle. Dekorace nesmějí zakrývat důležitou herní plochu.
7. Porovnat stav simulace s původní verzí a změřit výkon i při souběžných změnách terénu.

**Podmínka dokončení:** první level lze celý odehrát ve 2.5D, viditelné hrany odpovídají logické masce a při kopání či stavění nevznikají rušivé záseky. Dokud tento prototyp neprojde, nezačíná hromadná výroba finálních assetů.

## Etapa 4 — Všech osm dovedností

**Stav:** technicky dokončeno, včetně tří zkušebních misí, hřiště se všemi
dovednostmi a ovládání. Výsledky a meze jsou v [ověření etapy 4](ETAPA_4_OVERENI.md).

Postupně doplnit lezce, padák, horníka, bombiče a hromadné ukončení. Lezení a padák reprezentovat jako trvalé vlastnosti; odpočet bomby musí fungovat souběžně s činností lumíka. Určit platné kombinace a okamžiky přidělení.

Upravit vyhodnocení konce levelu tak, aby zohledňovalo čekající výbuchy a jiné akce schopné změnit výsledek. Každou mechaniku ihned propojit s provizorním 3D zobrazením a případnou změnou terénu.

**Podmínka dokončení:** všech osm dovedností má testy a ukázkovou situaci; kombinace vlastností fungují a původní první level zůstává řešitelný.

## Etapa 5 — Nebezpečí a objekty levelů

Doplnit vodu, lávu, pasti a jednosměrné stěny. Definovat zásahy, obnovu pastí, prioritu souběžných událostí a reakce jednotlivých stavů lumíka. Uchovávat logická pravidla odděleně od animací a materiálů objektů.

Připravit pohodlné nastavování objektů v editoru a validaci chybějících východů, neplatných počtů a nevhodně umístěných objektů.

**Podmínka dokončení:** level s těmito prvky lze sestavit bez doprogramování konkrétní scény. Jejich nebezpečné oblasti jsou vizuálně srozumitelné.

## Etapa 6 — Menu, nastavení a ukládání

Přidat hlavní menu, pokračování, výběr levelů, pauzovací menu a výsledky s přechodem dál. Zavést stabilní identifikátory levelů a ukládat odemčení, výsledky a nastavení.

Ukládání musí zvládat přerušený zápis, poškozený soubor a změnu formátu. Nastavení zahrne hlasitost, zobrazení, ovládání, velikost UI a kvalitu efektů. Prověřit uvolňování scén a zdrojů při přechodech a restartech.

**Podmínka dokončení:** lze projít cestu od spuštění přes dokončení levelu až po návrat další den se zachovaným postupem.

## Etapa 7 — Reprezentativní demo a výtvarný směr

**Výtvarná revize:** autor označil původní grafiku za nevyhovující a
schválil přesun práce na skutečné scéně dopředu. Ve verzi 0.4.0 jsou
zapojené oblé hrany terénu včetně kopání, výraznější postava, nové světlo,
prostorové pozadí a rozhraní. Podrobnosti: [grafika 0.4.0](GRAFIKA_04.md).
Jde o první výtvarnou úpravu; tato etapa jako celek ještě není dokončená
(chybí mimo jiné zvuk a první uživatelské hraní nového provedení).

Rozpracovat již zvolený modelínový styl z etapy 3 do reprezentativní kvality.

Vytvořit tři krátké levely: úvod, kombinaci dovedností a náročnější hlavolam. Na nich dokončit ukázku zamýšlené grafiky, jednu reprezentativní postavu, rozhraní, zvuk a nápovědu.

Vybrat způsob výroby 3D postav a animací, měřítko modelů, materiály, světla a pravidla pro rozpoznatelnost dovedností. Provést první uživatelské hraní bez slovního vysvětlování.

**Podmínka dokončení:** demo ukazuje cílový vzhled a nový hráč pochopí cíl, ovládání a důvody neúspěchu. Výroba dalších assetů má ověřený postup.

## Etapa 8 — Finální 3D grafika a zvuk

Dokončit modely, kostry a animace všech stavů. Napojit je na logické události a interpolaci pohybu, aby nebyly zdrojem herního času. Připravit terénní materiály, prostředí, osvětlení, stíny, částice a prostorové pozadí.

Přidat hudbu, zvuky dovedností, nebezpečí a rozhraní. Omezit souběh zvuků, náročná světla a částice; umožnit omezení výrazných efektů. Evidovat původ a licenci assetů.

**Podmínka dokončení:** všechny herní činnosti mají čitelný, jednotný obrazový a zvukový projev. Zátěžový level splňuje dohodnutý výkonnostní cíl.

## Etapa 9 — Kampaň s 15–20 levely

Postupovat od výuky jednotlivých pravidel ke kombinacím a výzvám. Každý level nejprve ověřit s jednoduchým vzhledem, potom dokončit dekorace. Vyvážit počty dovedností, potřebné záchrany a časové limity.

U každého levelu uchovávat alespoň jedno strojově přehratelné ověřené řešení. Po změnách simulace kontrolovat, zda zůstává řešitelný. Průběžně sledovat problematická místa při uživatelském hraní.

**Podmínka dokončení:** lze dokončit celou kampaň, všechny levely mají ověřené řešení a obtížnost nemá nechtěné skoky.

## Etapa 10 — Pohodlí a betatest

Doladit výběr v davu, zvýraznění cíle, vysvětlení nedostupných dovedností, zkratky a rychlé opakování pokusu. Podle testování doplnit výběr podle směru a minimapu.

Prověřit dlouhé hraní, opakované přechody a restarty, různá rozlišení, ukládání a aktualizaci ze staršího sestavení. Měřit paměť i snímkové časy, zejména při přestavbě terénu a větším počtu postav. Grafické testy vyžadují skutečné vykreslování; samotné headless testy je nenahrazují.

**Podmínka dokončení:** nejsou známé chyby způsobující pád, ztrátu postupu nebo nemožnost dokončit level; hra splňuje dohodnutou výkonnost a čitelnost.

## Etapa 11 — Vydání 1.0

Dokončit vlastní veřejný název, ikonu, titulky, licence, návod a známá omezení. Připravit opakovatelné exporty, verzování a distribuci. Na skutečných Windows bez vývojových nástrojů provést dosud odložené ověření spuštění, grafických ovladačů, ovládání, celé kampaně, ukládání a aktualizací. Zjištěné problémy s kompatibilitou opravit před vydáním.

Uchovat vydaná sestavení a odpovídající zdrojovou verzi. Připravit způsob hlášení chyb a ověřit zachování postupu při aktualizaci.

**Podmínka dokončení:** nový hráč dokáže hru stáhnout, spustit, dokončit a aktualizovat bez ztráty postupu.

## Etapa 12 — Navazující rozšíření

První testovací Android APK ukázkové mise bylo na přání autora připraveno
už po etapě 3. Zahrnuje dotyk a základní grafický profil; nativní ověření,
optimalizace a produkční distribuce nadále patří do níže uvedeného rozšíření.
Podrobnosti: [Android demo](ANDROID_DEMO.md).

- **1.1:** uživatelský replay a přetáčení času. Verze záznamu, snímky celého stavu včetně terénu a objektů, obnova a přepočítání příkazů, limity paměti.
- **1.2:** další levely, prostředí a objekty.
- **Android:** zamýšlená další platforma; dotykové ovládání, čitelnost na telefonu a tabletu, vhodný renderer, spotřeba paměti a energie, výkon na zařízení a distribuce. Gamepad lze řešit samostatně.
- **Web:** samostatně ověřit podporovaný renderer, shadery, velikost stahování a ukládání v prohlížeči. Současný desktopový renderer nelze automaticky považovat za přenositelný na web.
- **Později:** editor levelů ve hře a jejich sdílení, včetně validace formátu a kompatibility.

## Pořadí a průběžné dokončování

Nejdřív ověřit základ a simulaci, připravit grafické podklady, následně postavičku s animacemi a potom hratelný 2.5D terén. Navázat mechanikami a objekty, dokončit menu a malé demo. Finální assety celé kampaně vyrábět až po ověření prototypu a výtvarného směru. Uzavřít betatestem a vydáním.

Každý dílčí úkol má určit změněné vrstvy, konkrétní ukázku výsledku a kontroly odpovídající riziku. Po větší implementační změně aktualizovat stav projektu a relevantní architekturu. Termíny a rozpočet zpřesnit po technickém prototypu a prvním dokončeném 3D assetu; do té doby nejsou ověřené podklady pro spolehlivý odhad.

**Nejbližší vývojový úkol:** posoudit novou grafiku 0.4.0 při hraní na cílovém
zařízení a podle výsledku doladit vzhled a výkon. Mechanicky navazuje etapa 5,
nebezpečí a objekty. Cloudové testy nepotvrzují nativní běh na Macu ani Androidu.
