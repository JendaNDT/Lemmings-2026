extends SceneTree
## Zapíše THIRD_PARTY_NOTICES.txt pro vydání: licence hry, Godot Engine (MIT),
## seznam jeho součástí s autory a licencemi, písmo Nunito (OFL) a plné texty
## všech použitých licencí. Stejné údaje ukazuje hra v „O hře → Licence“.
##
##   godot --headless --path . --script res://scripts/third_party_notices.gd -- CESTA


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var path: String = args[0] if not args.is_empty() else "THIRD_PARTY_NOTICES.txt"
	var parts: Array[String] = [
		"Paperlings %s – licence a součásti třetích stran" % BugReport.version(),
		"",
		AboutPanel.license_summary(),
		"",
		"== Godot Engine (licence MIT) ==",
		Engine.get_license_text().strip_edges(),
		"",
		"== Součásti Godot Engine ==",
		AboutPanel.components_text(),
		"",
		"== Písmo Nunito (SIL Open Font License 1.1) ==",
		FileAccess.get_file_as_string(AboutPanel.OFL_PATH).strip_edges(),
		"",
		"== Hudební nahrávky dodané pro hru ==",
		FileAccess.get_file_as_string(AboutPanel.MUSIC_TERMS_PATH).strip_edges(),
		"",
		"== Plné texty licencí součástí Godot Engine ==",
	]
	var texts := Engine.get_license_info()
	var keys := texts.keys()
	keys.sort()
	for key: String in keys:
		parts.append("")
		parts.append("--- %s ---" % key)
		parts.append(str(texts[key]).strip_edges())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		printerr("Nelze zapsat %s" % path)
		quit(1)
		return
	file.store_string("\n".join(parts) + "\n")
	file.close()
	print("NOTICES %s (%d licencí)" % [path, keys.size()])
	quit(0)
