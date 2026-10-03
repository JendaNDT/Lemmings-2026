class_name SimConst
extends RefCounted
## Herní konstanty simulace na jednom místě.
##
## Všechno je v „logických pixelech“ (stejné měřítko jako původní hra z roku 1991)
## a v „ticích“ (jeden krok logiky). Grafika si to pak zvětší a vyhladí.
## Chceš jiný pocit ze hry? Změň čísla tady – nic jiného sahat nemusíš.

## Kolik kroků logiky proběhne za sekundu při normální rychlosti (originál ~17).
const TICKS_PER_SECOND := 17
## Rychlost tlačítka „zrychlit“.
const FAST_FORWARD_MULTIPLIER := 3.0

## Výška lumíka (pro klikání, strop, tunely).
const LEMMING_HEIGHT := 10
## Nejvyšší schod, na který chodec ještě vyleze. Vyšší = zeď a otočka.
const MAX_STEP_UP := 6
## O kolik může chodec sejít dolů, aniž by začal padat.
const MAX_STEP_DOWN := 3
## Rychlost pádu (px za tik).
const FALL_SPEED := 3
## Delší pád než tohle = splácnutí.
const SAFE_FALL_DISTANCE := 60
## Padák se otevře po krátkém volném pádu a zůstane rozvinutý do přistání.
const FLOATER_OPEN_DISTANCE := 16
const FLOATER_SPEED := 1
## Horník razí průchozí tunel šikmo dolů, v obou směrech stejně.
const MINER_TICKS_PER_STEP := 4
const MINER_STEP_X := 2
const MINER_REACH := 4
## Bomba běží souběžně s činností. Hromadné ukončení zapaluje postupně.
const BOMB_TICKS := 5 * TICKS_PER_SECOND
const BOMB_RADIUS := 16
const NUKE_INTERVAL := 2

## Dosah „neviditelné zdi“ blokaře do stran a do výšky.
const BLOCKER_FIELD := 6
const BLOCKER_FIELD_HEIGHT := 10

## Stavitel: počet cihel, jak dlouho trvá jedna cihla a jak je dlouhá.
const BUILDER_BRICKS := 12
const BUILDER_TICKS_PER_BRICK := 16
## Ve kterém tiku cyklu se cihla položí (0 až BUILDER_TICKS_PER_BRICK - 1).
const BUILDER_BRICK_PHASE := 8
const BRICK_WIDTH := 6
## Kolik posledních cihel lumík „upozorňuje“ (zvuk cvaknutí).
const BUILDER_WARNING_BRICKS := 3

## Razič (kope vodorovně): dosah úderu, rychlost a jak daleko kouká dopředu.
const BASHER_REACH := 4
const BASHER_TICKS_PER_STEP := 2
const BASHER_LOOKAHEAD := 8

## Kopáč (kope dolů): poloviční šířka díry a rychlost.
const DIGGER_HALF_WIDTH := 4
const DIGGER_TICKS_PER_ROW := 2

## Délky krátkých animačních stavů (v tikách).
const SPLAT_TICKS := 16
const EXIT_TICKS := 10
const SHRUG_TICKS := 8
const DROWN_TICKS := 16
const BURN_TICKS := 14

## Past (např. masožravka): po sežrání postavy se tolik tiků „dobíjí“
## a mezitím nechá ostatní projít. Hodnotu lze přepsat u každé pasti v editoru.
const TRAP_REARM_TICKS := 40

## Za jak dlouho po startu vyleze první lumík.
const HATCH_OPEN_TICKS := 34
## Jak blízko musí být lumík k východu, aby vešel.
const EXIT_REACH_X := 2
const EXIT_REACH_Y := 8

const MIN_RELEASE_RATE := 1
const MAX_RELEASE_RATE := 99
