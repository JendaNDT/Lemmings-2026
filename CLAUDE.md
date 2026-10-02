# Lemmings 2026 – pokyny pro AI asistenta

## Kontext
- Moderní předělávka Lemmings (1991) v **Godot 4.7 + GDScript**.
- Autor (Jenda) neprogramuje – tvoří přes vibecoding. Komunikuj **česky**,
  tykej, vysvětluj jednoduše, odpovědi drž krátké (čte z mobilu).
- Po každé větší změně aktualizuj `PROJECT_STATUS.md`.
- Architektura je popsaná v `docs/ARCHITEKTURA.md` – drž se jí.

## Architektonická pravidla
- `sim/` = čistá logika: žádné uzly (Node), žádný `Input`, žádná náhoda,
  žádný reálný čas, jen celá čísla. Svět se mění jen přes `LevelSim.tick()`.
- `view/` a `ui/` simulaci jen čtou (a posílají příkazy přes `LevelSim.assign_skill`).
- Nový stav lumíka = nový soubor v `sim/states/` (dědí `LemmingState`)
  + zaregistrovat v `LevelSim._init()` + případně `Lemming.State` / `Lemming.Skill`
  a `LevelSim._state_for_skill()`.
- Laditelná čísla patří do `sim/sim_const.gd`.
- Komentáře a texty v UI česky. Klávesy přes `physical_keycode`.
- Nepoužívat assety ani levely z originální hry.

## Ověření změn
Godot se v cloudovém kontejneru nedá stáhnout, proto minimálně:
```
pip install "gdtoolkit==4.*"
gdparse $(git ls-files '*.gd')
gdlint $(git ls-files '*.gd')
```
Když je Godot k dispozici, spusť i test simulace:
`godot --headless --path . --script res://tests/test_level_01.gd`

Pozor na typování: `:=` nejde použít na hodnotu typu Variant
(např. `dict.get()`, `max()`), používej `maxi/maxf/absi/lerpf…`
nebo explicitní typ.
