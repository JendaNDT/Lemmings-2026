extends SimTest
## Vydání (etapa 11): obrazovka „O hře“ z hlavního menu – titulky, návod,
## licence (hra, Godot, součásti, písmo) a hlášení chyby s údaji o zařízení.

const DIR := "user://test_about"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.content_scale_size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute(DIR)
	var app := (load("res://main/app.tscn") as PackedScene).instantiate() as App
	app.settings_path = DIR.path_join("settings.json")
	app.progress_path = DIR.path_join("progress.json")
	root.add_child(app)
	await _frames(3)
	var menu := app.menu
	var about_button: Button = null
	for child in menu.find_children("*", "Button", true, false):
		if (child as Button).text == "O hře":
			about_button = child
	check(about_button != null and about_button.is_visible_in_tree(),
		"hlavní menu má tlačítko „O hře“")
	about_button.pressed.emit()
	await _frames(2)
	var panel: AboutPanel = menu.find_child("About", true, false)
	check(menu.current_screen() == "about" and panel != null, "„O hře“ se otevře nad menu")
	_test_texts(panel)
	_test_report(panel, app)
	var closed := menu.back()
	check(closed and menu.current_screen() == "main" and panel.is_queued_for_deletion(),
		"Zpět „O hře“ zavře")
	app.free()
	await _frames(2)
	for name in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR.path_join(name))
	finish()


func _test_texts(panel: AboutPanel) -> void:
	check(AboutPanel.credits().contains("Jenda") and AboutPanel.credits().contains("Godot")
		and AboutPanel.credits().contains("Nunito"), "titulky: autor, engine a písmo")
	check(AboutPanel.license_summary().contains("Všechna ostatní práva vyhrazena")
		and AboutPanel.license_summary().contains("zdarma"),
		"licence hry: volně ke hraní, ostatní práva vyhrazena")
	var texts: Array[String] = []
	for label in panel.find_children("*", "Label", true, false):
		texts.append((label as Label).text)
	var all := "\n".join(texts)
	check(all.contains("Godot Engine contributors") and all.contains("SIL OPEN FONT LICENSE")
		and all.contains("FreeType") and all.contains("není nijak spojená"),
		"licence: Godot (MIT), písmo OFL, součásti enginu a vymezení vůči Lemmings")
	var guide := AboutPanel.guide()
	var skills := 0
	for name: String in Lemming.SKILL_NAMES.values():
		skills += int(str(guide[3][1]).contains(name))
	check(guide.size() >= 6 and skills == 8 and str(guide[1][1]).contains("Backspace")
		and str(guide[2][1]).contains("minimapu"), "návod: cíl, ovládání, všech 8 dovedností")
	panel.show_tab(2)
	panel.show_license("Expat")
	check(all.length() < 60000 and _visible_text(panel).contains("Permission is hereby granted"),
		"plný text licence součásti se ukáže po klepnutí (po jedné)")


func _test_report(panel: AboutPanel, app: App) -> void:
	panel.open_browser = false
	var text := panel.report_bug()
	var home := OS.get_environment("HOME")
	check(text.begins_with("Paperlings " + BugReport.version()) and text.contains("Systém:")
		and text.contains("Grafika:") and text.contains("Splněných misí: 0 z %d" % Campaign.count())
		and (home.is_empty() or not text.contains(home)),
		"hlášení: verze, systém, grafika a postup – bez cest a osobních údajů")
	var url := BugReport.issue_url(text)
	check(url.begins_with(BugReport.REPO_URL + "/issues/new?template=chyba.yml&diagnostika=")
		and not url.contains(" ") and url.uri_decode().ends_with(text),
		"odkaz na formulář chyby má údaje předvyplněné")
	check(app.settings.load_status != SaveFile.Status.CORRUPT, "hlášení nic neuloží ani nezmění")


func _visible_text(node: Node) -> String:
	var parts: Array[String] = []
	for label in node.find_children("*", "Label", true, false):
		if (label as Label).is_visible_in_tree():
			parts.append((label as Label).text)
	return "\n".join(parts)


func _frames(count: int) -> void:
	for _i in count:
		await process_frame
