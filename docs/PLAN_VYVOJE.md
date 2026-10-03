# Plán vývoje Lemmings 2026 — 2D origami

Aktualizováno 3. října 2026. Aktuální výtvarný podklad je
[origami mockup](MOCKUP_ORIGAMI.md). Starší návrhy byly na přání autora
odstraněny. Dvanáct hlavních etap zůstává; etapa 3 níže zaznamenává již
provedený technický prototyp. Nový 2D renderer se teprve připraví.

## Cíl a rozsah

Herní pravidla i nové zobrazení budou 2D. Papírový terén a animované origami postavy sdílejí jednu herní vrstvu. Dekorativní kulisy mají paralaxní posun i zoom, HUD zůstává na obrazovce. Simulace a současné mechaniky se zachovají.

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
- Aplikace startuje hlavním menu (`main/app.tscn`, etapa 6) a ukládá postup i nastavení ([ověření](ETAPA_6_OVERENI.md)).
- Herní scéna je od 3. října 2D origami ([ověření](ORIGAMI_OVERENI.md)). 2.5D scéna prošla výtvarnou úpravou ve verzi 0.4.0; [technický záznam](GRAFIKA_04.md). Android má APK a dotykový profil; zvuk, nativní spuštění a výkon na cílovém zařízení dosud ověřeny nejsou.
- Příprava etapy 3: hotová první sada modelínových materiálů, modelů,
  animací zapojených do dosavadní hry. Podrobnosti v [podkladech prototypu](PODKLADY_PROTOTYPU.md).

## Pravidla implementace

- Simulace je jediným zdrojem pravdy o terénu, pohybu a výsledku levelu. Herní kolize se dál vyhodnocují podle 2D masky, nikoli podle 3D fyziky.
- Všechny platformy používají stejné GDScripty, pravidla a definice levelů. Platformní rozdíly patří do vstupu, grafických profilů, ukládání a exportních nastavení; logiku hry nekopírovat do samostatných větví pro každý systém.
- Grafická vrstva odvozuje vzhled ze simulace. Efekty, modely, světla a snímková frekvence nesmějí měnit výsledek.
- Zachovat tvorbu levelů z 2D definic v editoru; dekorace ukládat odděleně od logických pravidel.
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

## Etapa 3 — Hratelný technický prototyp (dokončený 2.5D základ)

**Stav:** dosavadní 2.5D prototyp byl implementován a ověřen v cloudu.
První level zachraňuje 20/20 přes herní vstup; geometrie odpovídá masce
společné simulace. [Technické ověření](ETAPA_3_OVERENI.md).
Origami zobrazení má vlastní [ověření](ORIGAMI_OVERENI.md).

Při nahrazení grafiky zachovat masku, inkrementální aktualizace, přesný
výběr postav, kameru, dotyk a výsledky simulace. Kopání zůstává vodorovné,
šikmo dolů a svisle dolů. Vizuální ústřižky nesmějí měnit kolize.
Nahoru vedou stavitelovy schody.

**Podmínka přenosu do nového zobrazení:** řešení levelu se shoduje se
stávající simulací, viditelné hrany odpovídají masce a posun i zoom
paralaxy zachovávají správné ovládání. Splněno v cloudu pro 2D origami,
viz [ověření](ORIGAMI_OVERENI.md); nativní zařízení zbývají.

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

**Stav (3. 10. 2026): technicky hotovo v cloudu.** Pravidla, editor
(`LemmingTrap`, druhy terénu, kontrola levelu), origami vzhled a mise 6;
[ověření etapy 5](ETAPA_5_OVERENI.md). Zvuky doplněny ([popis](ZVUK.md)); zbývá vyzkoušet
na zařízení.

## Etapa 6 — Menu, nastavení a ukládání

Přidat hlavní menu, pokračování, výběr levelů, pauzovací menu a výsledky s přechodem dál. Zavést stabilní identifikátory levelů a ukládat odemčení, výsledky a nastavení.

Ukládání musí zvládat přerušený zápis, poškozený soubor a změnu formátu. Nastavení zahrne hlasitost, zobrazení, ovládání, velikost UI a kvalitu efektů. Prověřit uvolňování scén a zdrojů při přechodech a restartech.

**Podmínka dokončení:** lze projít cestu od spuštění přes dokončení levelu až po návrat další den se zachovaným postupem.

**Stav (3. 10. 2026): technicky hotovo v cloudu.** Hlavní menu s papírovou
krajinou, výběr misí s odemykáním, nastavení (zvuk, zobrazení, ovládání,
hra), pauzovací menu, výsledek s další misí, rozehraná mise přes replay,
bezpečné ukládání; automatický průchod „spuštění → výhra → další den“
prošel. [Ověření etapy 6](ETAPA_6_OVERENI.md). Zbývá vyzkoušet na zařízení.

## Etapa 7 — Reprezentativní demo a 2D výtvarný směr

**Stav:** body 1–4 jsou implementované a ověřené v cloudu (výchozí scéna
`main/game_origami.tscn`, [ověření](ORIGAMI_OVERENI.md)). Zbývá bod 5
(zvuk, nápověda, další mise) a ověření na skutečném Macu a Androidu.

1. Vyrobit oddělené vrstvy oblohy, vzdálené krajiny, středních kulis,
   herního terénu a popředí včetně původně zakrytých částí.
2. Připravit originální postavičku a čitelné animace všech činností.
3. Vytvořit malou scénu Godotu s paralaxním posunem i zoomem; proti
   předloze posoudit vzhled při běžném měřítku i přiblížení.
4. Zapojit řezání papírového terénu, ústřižky a stavěné schody do masky.
5. Dokončit ukázkové mise, rozhraní, zvuk a nápovědu, ověřit hraní.

**Podmínka dokončení:** skutečné demo odpovídá předloze a nový hráč
pochopí ovládání. Výběr postav sedí při každém zoomu, kulisy nezakrývají
herní cestu a neodhalují chybějící obraz. Nativní výkon se měří zvlášť.

## Etapa 8 — Finální 2D grafika a zvuk

Dokončit papírové postavy, sady animací, terénní vrstvy a jejich řezy,
objekty, ikony a prostředí celé kampaně. Animace i pracovní kontakt
řídit simulačními tiky. Sjednotit přehyby, stíny a měřítko detailů.

Přidat hudbu, zvuky papíru, dovedností, nebezpečí a rozhraní. Hlídání
paměti textur, přeplňování obrazu efekty a čitelnosti platí i pro Android.
U každého podkladu evidovat původ, podmínky a exportní parametry.

**Podmínka dokončení:** všechny činnosti mají jednotný čitelný obrazový
a zvukový projev; zátěžový level splňuje změřený výkonnostní cíl.

**Stav zvuku (3. 10. 2026):** zvukové efekty všech událostí, okolní
smyčky a zvuky rozhraní jsou hotové ([zvuky](ZVUK.md)); hudbu doplní autor.

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

Základ a simulace jsou ověřené. Nyní navázat na přijatý origami mockup:
vrstvy, postavička a animace, potom malá scéna a přenos do hratelné mise.
Finální podklady celé kampaně vyrábět po posouzení skutečné scény.
Další mechaniky, menu, obsah, betatest a vydání následují podle etap.

Každý úkol má konkrétní ukázku a přiměřené kontroly. Po větší změně
aktualizovat stav a architekturu. Cloudové testy nenahrazují nativní
spuštění a měření na Macu ani Androidu; Windows se ověří před vydáním.
