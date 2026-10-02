# Lemmings 2026 – Project Status
*Naposled aktualizováno: 02. 10. 2026*

## 🎯 Co to je
Moderní předělávka hry Lemmings (1991) s grafikou odpovídající roku 2026.
Stack: Godot 4.7, GDScript, 2D renderer Forward+, shadery pro terén.

## ⏭️ Příští krok
**Otevřít projekt v Godotu 4.7, zahrát level 1 a dát vědět, co nefunguje.**
Kód prošel kontrolou syntaxe a logika byla ověřená simulací, ale přímo
v Godotu ještě nikdy neběžel. Pak M2: lezec, padák, bombič, horník.

## ✅ Hotovo
- Návrh architektury (`docs/ARCHITEKTURA.md`)
- Struktura projektu Godot 4.7
- Simulace s pevným krokem (17 tiků/s), deterministická, záznam příkazů pro replay
- Logická mapa terénu (hlína / ocel / cihly), kopání, stavění, vypalování mnohoúhelníků
- Stavy lumíka: chodec, pád, splácnutí, odchod východem, blokař, stavitel, razič, kopáč
- Tvorba levelů v editoru Godotu (TerrainShape, LemmingHatch, LemmingExit)
- Level 1 „První kroky“ (ověřený simulací: řešitelný, 20/20)
- Automatický test levelu 1 bez grafiky (`tests/test_level_01.gd`)
- Shader terénu: hladké okraje, tráva, vrstvy hlíny, ocel, cihly, nasvícení hran
- Pozadí se shaderem (obloha, mlha, hvězdy)
- Placeholder lumíci kreslení tvary + plynulý pohyb mezi tiky
- Částicové efekty (hlína, jiskry, prach, odchod)
- HUD: dovednosti, vypouštění, pauza, zrychlení 3×, restart, okno s výsledkem
- Kamera: šipky/WASD, okraj obrazovky, tažení pravým tlačítkem, zoom kolečkem

## 📝 TODO
### MVP (nutné pro v1)
- Lezec, padák, bombič (+ atomovka), horník
- Voda / láva / pasti, jednosměrné zdi
- Menu a výběr levelů, ukládání postupu
- 15–20 vlastních levelů
- Zvuky a hudba
- HD grafika lumíků (místo placeholderu)

### Backlog (později)
- Světla, glow, materiály terénu (M3)
- Paralaxní pozadí
- Replay a přetáčení času
- Výběr jen lumíků jdoucích doleva/doprava
- Minimapa
- Dotyk a gamepad, export Android / web
- Editor levelů ve hře

## 🐛 Známé bugy
- Zatím žádné známé – projekt ještě neběžel v Godotu.

## 🏗️ Klíčová rozhodnutí
*(Aby ses k tomu zase zbytečně nevracel.)*
- **Engine:** Godot 4.7 + GDScript (ne C#) – jednodušší pro vibecoding, funguje i export na web.
- **Logika × grafika:** úplně oddělené. `sim/` nesmí obsahovat grafiku, Input ani náhodu.
- **Měřítko logiky:** jako originál (lumík 10 px, 17 tiků/s). Grafika se jen zvětšuje a vyhlazuje.
- **Terén:** pixelová maska RGBA8 (R zem, G ocel, B cihly), vzhled maluje shader.
- **Stavy lumíka:** jeden soubor na stav, stavy jsou bezstavové (data drží Lemming).
- **Levely:** scény v editoru Godotu z mnohoúhelníků, ne vlastní formát.
- **Konec levelu:** když zbývají jen blokaři, level skončí (blokaři se počítají jako ztracení).
- **Klávesy:** podle fyzické pozice (funguje i na české klávesnici).
- **Grafický směr:** HD 2D s moderním světlem (doporučeno, čeká na potvrzení).
- **Právní:** vlastní obsah, žádné převzaté assety z originálu. Při zveřejnění jiný název.

## 📁 Stav souborů
- `main/game.tscn`, `main/game.gd` – hlavní scéna, herní smyčka, ovládání
- `sim/level_sim.gd` – pravidla levelu, vypouštění, východ, konec
- `sim/terrain_mask.gd` – logická mapa terénu
- `sim/states/*.gd` – stavy lumíků (jeden soubor = jeden stav)
- `sim/sim_const.gd` – všechna laditelná čísla
- `level_tools/` – nástroje pro tvorbu levelů v editoru
- `levels/level_01.tscn` – první level
- `view/terrain.gdshader` – vzhled terénu
- `view/lemmings_view.gd` – kreslení lumíků
- `ui/hud.gd` – herní rozhraní
- `tests/test_level_01.gd` – automatický test (spouští se z příkazové řádky)
