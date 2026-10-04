class_name SaveMigration
extends RefCounted
## Přenos uložených dat po přejmenování hry (Lemmings 2026 → Paperlings).
##
## Na počítači Godot dřív ukládal do `<data>/Godot/app_userdata/Lemmings 2026`
## (v Linuxu `godot` malými písmeny). Od verze 1.0 má hra vlastní složku
## `<data>/Paperlings` (`application/config/custom_user_dir_name`). Při prvním
## spuštění se postup a nastavení zkopírují, pokud nová složka ještě žádné
## nemá; staré soubory zůstanou na místě. Android ukládá podle balíčku –
## tam se složka nemění a přenos se přeskočí. Značka zajistí, že se přenos
## nezopakuje (třeba po „Smazat postup“).

const LEGACY_NAME := "Lemmings 2026"
const FILES: Array[String] = ["progress.json", "progress.json.bak", "settings.json",
	"settings.json.bak", "settings.cfg"]
const MARKER := "prenos_dat.txt"


## Možné starší složky dat (macOS a Windows „Godot“, Linux „godot“).
static func legacy_dirs() -> Array[String]:
	var base := OS.get_data_dir()
	return [base.path_join("Godot/app_userdata").path_join(LEGACY_NAME),
		base.path_join("godot/app_userdata").path_join(LEGACY_NAME)]


## Přenos ze staré složky do `user://` (jen na počítači). Vrací počet souborů.
static func run() -> int:
	if not OS.has_feature("pc"):
		return 0
	var source := ""
	for dir in legacy_dirs():
		if DirAccess.dir_exists_absolute(dir):
			source = dir
			break
	return migrate(source, "user://")


## Zkopíruje uložená data z `from_dir` do `to_dir`, pokud cíl ještě žádná
## nemá a přenos tam ještě neproběhl. Prázdné `from_dir` jen zapíše značku.
static func migrate(from_dir: String, to_dir: String) -> int:
	var marker := to_dir.path_join(MARKER)
	if FileAccess.file_exists(marker):
		return 0
	var copied := 0
	var empty := not FileAccess.file_exists(to_dir.path_join("progress.json")) \
		and not FileAccess.file_exists(to_dir.path_join("settings.json"))
	if empty and not from_dir.is_empty() and DirAccess.dir_exists_absolute(from_dir):
		for name in FILES:
			var source := from_dir.path_join(name)
			if FileAccess.file_exists(source) \
					and DirAccess.copy_absolute(source, to_dir.path_join(name)) == OK:
				copied += 1
	var file := FileAccess.open(marker, FileAccess.WRITE)
	if file != null:
		file.store_string("Přenos dat ze staré složky „%s“ zkontrolován: %s, souborů %d.\n" % [
			LEGACY_NAME, from_dir if not from_dir.is_empty() else "nenalezena", copied])
	return copied
