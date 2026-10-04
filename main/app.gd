class_name App
extends Node
## Kořen aplikace: načte nastavení a postup, ukazuje menu a spouští mise.
##
## Hra (main/game_origami.tscn) se pro každou misi z menu vytvoří znovu
## a po návratu do menu se celá uvolní, takže přechody nehromadí uzly
## ani zdroje. Restart a další mise běží uvnitř téže instance hry.

const GAME_SCENE := preload("res://main/game_origami.tscn")

var settings: GameSettings
var progress: Progress
## Kam se ukládá (testy je přesměrují do vlastní složky).
var settings_path := GameSettings.PATH
var progress_path := Progress.PATH
var menu: MenuScreens
var backdrop: MenuBackdrop
var game: Node
var _audio: GameAudio


func _ready() -> void:
	settings = GameSettings.load_from(settings_path)
	progress = Progress.load_from(progress_path)
	settings.changed.connect(_on_setting_changed)
	backdrop = MenuBackdrop.new()
	backdrop.name = "Backdrop"
	add_child(backdrop)
	_audio = GameAudio.new()
	_audio.name = "MenuAudio"
	add_child(_audio)
	menu = MenuScreens.new(settings, progress)
	menu.play_requested.connect(start_mission)
	menu.playground_requested.connect(start_playground)
	menu.quit_requested.connect(_quit)
	menu.reset_requested.connect(_reset_progress)
	menu.clicked.connect(func() -> void: _audio.play_ui("click"))
	add_child(menu)
	_apply_settings()


## Spustí misi z kampaně (index), případně obnoví její rozehraný pokus.
func start_mission(index: int, resume := false) -> void:
	if index < 0 or index >= Campaign.count():
		return
	_start(Campaign.SCENES[index], resume)


## Hřiště mimo kampaň (otevře se po kapitole I).
func start_playground() -> void:
	if progress.playground_unlocked(settings.unlock_all):
		_start(Campaign.PLAYGROUND, false)


func _start(scene: PackedScene, resume: bool) -> void:
	if game != null:
		return
	game = GAME_SCENE.instantiate()
	game.set("level_scene", scene)
	game.set("show_briefing", true)
	game.set("settings", settings)
	game.set("progress", progress)
	game.set("resume_suspended", resume)
	game.connect("leave_requested", _on_leave)
	menu.close_settings()
	menu.visible = false
	backdrop.visible = false
	backdrop.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(game)


## Hra skončila návratem do menu ("main_menu" nebo "levels").
func _on_leave(target: String) -> void:
	if game == null:
		return
	game.queue_free()
	game = null
	backdrop.visible = true
	backdrop.process_mode = Node.PROCESS_MODE_INHERIT
	menu.visible = true
	_apply_settings()
	if target == "levels":
		menu.show_levels()
	else:
		menu.show_main()


func _unhandled_input(event: InputEvent) -> void:
	if game == null and event is InputEventKey and event.pressed and not event.echo \
			and event.physical_keycode == KEY_ESCAPE:
		if menu.back():
			get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and game == null:
		# Zpět na Androidu: o úroveň výš, z hlavního menu ukončí aplikaci.
		if not menu.back():
			_quit()
	elif what in [NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_APPLICATION_PAUSED]:
		settings.save()


func _on_setting_changed(_key: String) -> void:
	if game == null:
		_apply_settings()


func _apply_settings() -> void:
	settings.apply_audio()
	settings.apply_window()
	menu.set_ui_scale(settings.ui_scale)
	backdrop.set_quality(settings.quality)


func _reset_progress() -> void:
	progress.reset()
	progress.save()
	menu.refresh()


func _quit() -> void:
	settings.save()
	get_tree().quit()
