extends SceneTree
## Rozlišení (etapa 10): výběr misí a hra s osmi dovednostmi na obrazovkách
## telefonu, tabletu i počítače, s rozhraním 100 % i 130 %. Kontroluje, že
## tlačítka jsou celá na obrazovce, v liště se nepřekrývají, horní štítky
## a minimapa se nepřekrývají. Volitelně ukládá snímky.
##
##   godot --path . --rendering-driver opengl3 --script res://scripts/qa_resolutions.gd \
##     -- [--mobile-preview] [--capture-dir=build/res]

## [název, návrhový viewport, velikost okna]
const DESKTOP := [
	["16:9 počítač", Vector2i(1920, 1080), Vector2i(1600, 900)],
	["16:10 MacBook", Vector2i(1920, 1080), Vector2i(1440, 900)],
	["21:9 široký", Vector2i(1920, 1080), Vector2i(2520, 1080)],
	["4:3 starý monitor", Vector2i(1920, 1080), Vector2i(1024, 768)],
]
const MOBILE := [
	["16:9 telefon", Vector2i(1280, 720), Vector2i(1280, 720)],
	["20:9 telefon", Vector2i(1280, 720), Vector2i(1600, 720)],
	["19.5:9 telefon", Vector2i(1280, 720), Vector2i(1560, 720)],
	["16:10 tablet", Vector2i(1280, 720), Vector2i(1280, 800)],
	["4:3 tablet", Vector2i(1280, 720), Vector2i(1024, 768)],
]

var _failed := false
var _dir := ""


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):
			_dir = arg.trim_prefix("--capture-dir=")
			DirAccess.make_dir_recursive_absolute(_dir)
	var profiles: Array = MOBILE if DeviceProfile.touch_mode() else DESKTOP
	for profile: Array in profiles:
		for scale: float in [1.0, 1.3]:
			await _check_profile(profile, scale)
	print("RESOLUTIONS %s" % ("CHYBA" if _failed else "OK"))
	quit(1 if _failed else 0)


func _check_profile(profile: Array, scale: float) -> void:
	root.content_scale_size = profile[1]
	root.size = profile[2]
	await _frames(2)
	var view := root.get_visible_rect()
	var tag := "%s %dx%d %d %%" % [profile[0], profile[2].x, profile[2].y, roundi(scale * 100)]
	DirAccess.make_dir_recursive_absolute("user://qa_res")
	var app := (load("res://main/app.tscn") as PackedScene).instantiate() as App
	app.settings_path = "user://qa_res/settings.json"
	app.progress_path = "user://qa_res/progress.json"
	root.add_child(app)
	await _frames(3)
	app.settings.set_value("unlock_all", true)
	app.settings.set_value("ui_scale", scale)
	app.menu.show_levels()
	await _frames(3)
	var problems: Array[String] = []
	_check_buttons(app.menu, view, problems, "menu")
	await _capture(tag + " menu")
	app.start_playground()
	await _frames(3)
	var game := app.game
	game.set_process(false)
	var hud: Hud = game.get_node("Hud")
	hud.briefing.close()
	game.call("_end_flyover")
	for _i in 30:
		game.call("_process", 1.0 / SimConst.TICKS_PER_SECOND)
	await _frames(3)
	_check_buttons(hud, view, problems, "hra")
	var title: Control = (hud.get("_title") as Control).get_parent()
	var stats: Control = (hud.get("_stats") as Control).get_parent()
	if title.get_global_rect().intersects(stats.get_global_rect()):
		problems.append("název mise se překrývá se stavem")
	if hud.minimap.visible and hud.minimap.get_global_rect().intersects(stats.get_global_rect()):
		problems.append("minimapa zakrývá stav")
	if hud.visible_skills().size() != 8:
		problems.append("v liště není všech 8 dovedností")
	await _capture(tag + " hra")
	print("%s %s%s" % ["[OK]" if problems.is_empty() else "[CHYBA]", tag,
		"" if problems.is_empty() else ": " + ", ".join(problems)])
	_failed = _failed or not problems.is_empty()
	app.settings.set_value("ui_scale", 1.0)
	app.settings.set_value("unlock_all", false)
	app.queue_free()
	await _frames(3)


## Viditelná tlačítka celá na obrazovce; tlačítka v jednom řádku se nepřekrývají.
func _check_buttons(node: Node, view: Rect2, problems: Array[String], where: String) -> void:
	var rects: Array[Rect2] = []
	for child in node.find_children("*", "Button", true, false):
		var button := child as Button
		if not button.is_visible_in_tree():
			continue
		var rect := button.get_global_rect()
		if not view.grow(0.5).encloses(rect):
			problems.append("%s: tlačítko „%s“ přesahuje obrazovku" % [where, button.text])
		for other in rects:
			if rect.grow(-1.0).intersects(other.grow(-1.0)):
				problems.append("%s: tlačítko „%s“ se překrývá s jiným" % [where, button.text])
				break
		rects.append(rect)


func _capture(tag: String) -> void:
	if _dir.is_empty():
		return
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image != null:
		image.save_png(_dir.path_join(tag.replace(" ", "_").replace(":", "-") + ".png"))


func _frames(count: int) -> void:
	for _i in count:
		await process_frame
