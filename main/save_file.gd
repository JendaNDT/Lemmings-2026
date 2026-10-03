class_name SaveFile
extends RefCounted
## Bezpečný zápis a čtení uložených dat (postup, nastavení).
##
## Soubor má dva řádky: hlavičku (hra, verze formátu, SHA-256 dat) a samotná
## data v JSON. Zápis jde nejdřív do `.tmp`, ten se přečte a ověří, předchozí
## platná verze se zkopíruje do `.bak` a teprve pak se `.tmp` přejmenuje
## na hlavní soubor. Přerušený zápis tak nikdy nezničí poslední platná data.
## Poškozený soubor se odloží jako `.corrupt` a načte se záloha.

## Výsledek čtení: data se načetla z hlavního souboru, ze zálohy, soubor
## neexistuje, nebo byl poškozený a nebyla ani použitelná záloha.
enum Status { OK, BACKUP, MISSING, CORRUPT }

const GAME := "lemmings-2026"


## Uloží slovník `data` ve verzi formátu `format`. Vrací OK, nebo kód chyby.
static func write(path: String, data: Dictionary, format: int) -> Error:
	var body := JSON.stringify(data, "", true)
	var header := JSON.stringify({"game": GAME, "format": format, "sha256": body.sha256_text()},
		"", true)
	var temp := path + ".tmp"
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(header + "\n" + body + "\n")
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		return write_error
	# Kontrola, že na disku je přesně to, co jsme chtěli zapsat.
	if _read_one(temp).is_empty():
		return ERR_FILE_CORRUPT
	if FileAccess.file_exists(path) and not _read_one(path).is_empty():
		DirAccess.copy_absolute(path, path + ".bak")
	var error := DirAccess.rename_absolute(temp, path)
	if error != OK and FileAccess.file_exists(path):
		# Některé systémy nepřepíšou existující soubor přejmenováním;
		# platná data jsou v té chvíli v .bak i v .tmp.
		DirAccess.remove_absolute(path)
		error = DirAccess.rename_absolute(temp, path)
	return error


## Načte data. Vrací {"status": Status, "format": int, "data": Dictionary}.
static func read(path: String) -> Dictionary:
	var main := _read_one(path)
	if not main.is_empty():
		main["status"] = Status.OK
		return main
	var had_main := FileAccess.file_exists(path)
	if had_main:
		# Poškozený soubor nemazat – odložit vedle pro případné zkoumání.
		DirAccess.copy_absolute(path, path + ".corrupt")
	var backup := _read_one(path + ".bak")
	if not backup.is_empty():
		backup["status"] = Status.BACKUP
		return backup
	return {"status": Status.CORRUPT if had_main else Status.MISSING, "format": 0, "data": {}}


## Kopie souboru vedle originálu (např. data z novější verze hry).
static func keep_copy(path: String, suffix: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.copy_absolute(path, path + suffix)


## Smaže soubor i jeho zálohy (např. „Smazat postup“).
static func erase(path: String) -> void:
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(path + suffix)


static func _read_one(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var text := FileAccess.get_file_as_string(path)
	var newline := text.find("\n")
	if newline < 0:
		return {}
	var header: Variant = _parse(text.substr(0, newline))
	var body := text.substr(newline + 1).trim_suffix("\n")
	if not header is Dictionary or str(header.get("game")) != GAME:
		return {}
	var format: Variant = header.get("format")
	if not (format is float or format is int) or str(header.get("sha256")) != body.sha256_text():
		return {}
	var data: Variant = _parse(body)
	if not data is Dictionary:
		return {}
	return {"format": int(format), "data": data}


## JSON bez hlášení chyby do logu (poškozený soubor je očekávaný stav).
static func _parse(text: String) -> Variant:
	var json := JSON.new()
	if json.parse(text) != OK:
		return null
	return json.data
