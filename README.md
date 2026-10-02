# Lemmings 2026

Moderní předělávka klasické hry Lemmings (1991) v enginu Godot.

Architektura: [`docs/ARCHITEKTURA.md`](docs/ARCHITEKTURA.md) ·
Stav projektu: [`PROJECT_STATUS.md`](PROJECT_STATUS.md)

## Jak to spustit

1. Stáhni **Godot 4.7** (standardní verze, ne .NET) z
   [godotengine.org/download](https://godotengine.org/download).
2. Spusť Godot → **Import** → vyber soubor `project.godot` z tohohle repozitáře.
3. Stiskni **F5** (nebo ▶ vpravo nahoře).

## Ovládání

| Akce | Ovládání |
|---|---|
| Vybrat dovednost | klik na liště dole nebo klávesy **1–8** |
| Přidělit dovednost | levý klik na lumíka |
| Posun kamery | šipky / **WASD** / myš u okraje / tažení pravým tlačítkem |
| Přiblížení | kolečko myši |
| Pauza | **mezerník** nebo **P** |
| Zrychlení 3× | **F** |
| Vypouštění pomaleji / rychleji | **−** / **=** (nebo na numerické klávesnici) |
| Restart levelu | **R** |

## Jak upravit level

Otevři `levels/level_01.tscn`. Pravidla levelu (počet lumíků, dovednosti,
čas) jsou v Inspectoru u kořenového uzlu. Terén tvoří uzly `TerrainShape`
– vyber jeden a body mnohoúhelníku můžeš tahat myší.

## Právní poznámka

Fanouškovský projekt. Značka Lemmings patří jejímu vlastníkovi (Sony).
Veškerý obsah tady je vlastní tvorba.
