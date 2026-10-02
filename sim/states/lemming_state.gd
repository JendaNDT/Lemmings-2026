class_name LemmingState
extends RefCounted
## Základ pro jeden stav lumíka (chodec, kopáč, stavitel…).
##
## Každý stav = jeden soubor. Stav si sám nic nepamatuje, všechna data drží
## Lemming – proto stačí jedna sdílená instance stavu pro všechny lumíky.
## Nová dovednost = nový soubor + zaregistrovat ho v LevelSim._init().


## Zavolá se jednou, když lumík do stavu vstoupí.
func enter(_lem: Lemming, _sim: LevelSim) -> void:
	pass


## Zavolá se každý tik, dokud je lumík v tomhle stavu.
func tick(_lem: Lemming, _sim: LevelSim) -> void:
	pass
