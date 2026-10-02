# Etapa 2 — spolehlivá simulace a přenosné kontroly

Datum: 2. října 2026. Implementace a kontroly proběhly v Linux cloudu
na standardním Godotu 4.7. Společná simulace zůstává oddělená od grafiky;
současné zobrazení je 2D, následuje prototyp 2.5D v etapě 3.

## Příkazy a pauza

Veškeré hráčské změny simulace vstupují přes `LevelSim.apply_command()`.
Stávající ovládání volá obálky `assign_skill()` a `change_release_rate()`.
Příkaz se provede okamžitě mezi tiky. Během pauzy mění dovednost či
vypouštění, ale neposune čas, polohu ani průběh pracovního úkonu.

Každý přijatý příkaz má v `replay_log` tento tvar:

```json
{"tick": 34, "kind": 0, "target": 0, "value": 4}
```

- `tick`: počet již dokončených tiků; 0 je před prvním krokem.
- `kind`: `ASSIGN_SKILL` (0) nebo `RELEASE_RATE` (1).
- `target`: ID lumíka; u vypouštění vždy −1.
- `value`: dovednost z `Lemming.Skill`, nebo výsledná absolutní rychlost vypouštění.

Pořadí v poli rozhoduje i ve stejném tiku. Příklad výše přidělí stavitele
lumíkovi 0 po tiku 34 a před tikem 35. Odmítnuté příkazy ani změny bez účinku
se nezapisují a nespotřebují dovednost. Čtenář dostane hlubokou kopii logu.

Vypouštění se pohybuje od počáteční rychlosti levelu do 99. Výchozí hodnota
se omezí na 1–99. Změna ponechá již naplánovaný výstup z líhně; nový interval
se použije po něm. Po dokončení levelu se nepřijímají tiky ani příkazy.
Přidělení dovednosti také kontroluje, že lumík patří dané simulaci.

Pauza, rychlost přehrávání 1×/3× a kamera nejsou příkazy herního světa.
Ovlivňují vykreslování a počet provedených tiků. Restart vytváří novou
simulaci s prázdným záznamem.

## Technický replay

`SimReplay.new(fresh_sim, commands)` potřebuje čerstvou simulaci stejného
levelu, pravidel a původního terénu. Příkazy tiku 0 provede při vytvoření;
`step()` provede jeden tik a příkazy na jeho konci. Po celou dobu je potřeba
kontrolovat `error`, na konci také `commands_remaining()`.

Formát a pořadí příkazů se ověřují před přehráváním. Načtení logu přes JSON
je podporované: číselné hodnoty musí být konečná přesná celá čísla v povoleném
rozsahu. Nepoužitelný příkaz či příkaz za koncem levelu přehrávání zastaví
s popisem chyby. Již provedené platné příkazy se při takové chybě nevracejí.

Jde o interní nástroj pro testy. Není to ještě nabídka replayů pro hráče,
verzovaný soubor s identitou levelu ani přetáčení času. Pro dlouhodobé ukládání
řešení bude potřeba doplnit verzi simulace/formátu a otisk levelu; patří to
do navazujících etap. Starý interní tříprvkový záznam dovedností se nepřehrává.

## Výsledky kontrol

Příkaz `python scripts/check.py --benchmark` prošel v čisté kopii projektu
pod `/tmp`, se samostatně vytvořeným Python venv, novými XDG složkami a
Godotem rozbaleným přenosným instalátorem. Kontrola nepotřebovala původní
cloudové wrappery ani cestu `/workspace/.cloud-setup`. Samostatně prošlo
i nové stažení oficiálního Godotu přes síť a kontrola jeho SHA-512.

| Sada | Kontrol | Co ověřuje |
|---|---:|---|
| `test_mechanics.gd` | 61 | Pády 60/61 px, schody, blokař, stavitel, razič/kopáč, ocel, hranice východů, konec a timeout, líhně, přidělování, terén. |
| `test_replay.gd` | 15 | Pauza a pořadí, poškozené logy, JSON, řešení 20/20, shoda průběhu při 30/144 FPS a nepravidelných snímcích. |
| `test_game.gd` | 9 | Skutečná scéna, HUD, vypouštění, pauza s příkazy, zrychlení, restart a různé tempo `_process()`. |
| `test_level_01.gd` | 2 | Původní kontrola přežití bez zásahu a řešitelnosti prvního levelu. |
| `benchmark_sim.gd` (volitelný) | 1 | Úplnost zátěžového scénáře: 200 živých lumíků a 1700 tiků. |

Celkem **87 regresních kontrol + 1 kontrola zátěže**. Parser a linter prošly
na všech **33 GDScriptech**, dále čistý import a samostatný start hlavní
scény. Replay porovnává průběžné SHA-256 otisky celého pozorovatelného stavu
každých 17 tiků, na konci přímo všechny údaje včetně pixelů terénu a po celou
dobu pořadí událostí. Obsahuje přidělení dovedností i změny vypouštění.

Pro hlavní smyčku platí limit osmi tiků za snímek a omezení nahromaděného
času na jeden tik. Velké prodlevy zpomalí skutečný běh hry. Shoda replaye
se vztahuje ke stejným simulačním tikům, nikoli ke stejné době na hodinách.

Kontrolní skript byl také ověřen na záměrných selháních: rozpozná chybu
enginu i při návratovém kódu 0, chybějící výsledek a nenulový návratový kód.
Instalátor odmítne nesprávný kontrolní součet ještě před rozbalením archivu.
Logy tohoto běhu jsou v `/workspace/artifacts/lemmings-phase-2/`.

## CI a opakování

Postup instalace a spuštění je v README. `scripts/check.py` vytváří dočasnou
kopii, nepřepisuje pracovní zdroje a logy ukládá do `build/checks/`. Ve výchozím
režimu spouští všechny `tests/test_*.gd`; nová sada se tak nemusí ručně přidávat
do seznamu. Závislosti mají připnutý gdtoolkit 4.5.0. Jeho cache má vlastní
dočasnou cestu, protože tato verze ignoruje XDG a jinak zapisuje do HOME.

`.github/workflows/checks.yml` je připraven pro Ubuntu 24.04 a macOS 14,
spouštění při push/PR a ruční vyvolání. Používá stejný skript a ukládá logy.
**Vzdálené CI dosud neběželo:** změny z této práce nebyly odeslány na GitHub.
Windows je podle dohody pozdější nativní kontrola.

## Výkon a referenční zařízení

Referenční herní zařízení je autorův MacBook; přesný model a čip zatím nejsou
potvrzené. Předběžný cíl zůstává **60 FPS při 1920×1080**, ověření rendereru
a kopání/stavění na tomto počítači náleží prototypu 2.5D. Bez konkrétního
zařízení a nativního měření nelze tento cíl označit za splněný.

Pro reprodukovatelné měření jádra vznikl scénář `200-walkers-1700-ticks-v1`:
200 lumíků, jedna líheň, rychlost 99, mapa 160×128 s rovnou zemí v y=80,
1700 tiků a odběr událostí po každém tiku. Čas se měří pouze v testovacím
skriptu, herní simulace zůstává nezávislá na reálném čase.

Jedno měření v cloudu (AMD EPYC 9V74, Linux, Godot 4.7): celkem **6058,8 ms**,
95. percentil jednoho tiku **5,639 ms**, maximum **14,655 ms**. Jde o orientační
výkon čisté simulace na sdíleném CPU, bez rendereru a bez záruky opakovatelné
latence. Není to údaj o FPS na Macu. Zatížení deformacemi 2.5D terénu se
musí doplnit, až existuje jeho renderer.

## Aktualizované sestavení

Vytvořen macOS balíček **0.1.1**, univerzální pro Apple Silicon a Intel.
Prošla integrita ZIP, kontrola verze, obou Mach-O architektur, oprávnění
spustitelného souboru a přítomnosti ad-hoc podpisu. Herní data z výsledného
ZIP byla vykreslena na Linuxu přes Forward+ a softwarový Vulkan bez chyb;
zachycený obraz obsahuje terén, lumíky i HUD.

Distribuční soubor: `/workspace/artifacts/lemmings-phase-2/Lemmings-2026-macOS-0.1.1.zip`,
vedle něj `SHA256SUMS.txt`. Jeho nativní spuštění a chování zabezpečení na Macu
zatím nebyly ověřeny. Aplikace není notarizovaná Applem; postup prvního
spuštění je v README a přiloženém `CTI_ME.txt`.
