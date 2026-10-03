class_name MenuScreens
extends CanvasLayer
## Obrazovky mimo hru: hlavní menu, výběr misí a nastavení. Jen ukazují stav
## postupu a nastavení a hlásí volby signály; hru spouští App.

## Hrát misi; `resume` = obnovit rozehraný pokus z postupu.
signal play_requested(index: int, resume: bool)
signal quit_requested
## Hráč potvrdil smazání postupu.
signal reset_requested
## Zvuk kliknutí (přehraje App, menu samo zvuk nemá).
signal clicked

var settings: GameSettings
var progress: Progress
var ui_scale := 1.0
## Pro testy: karty misí v pořadí kampaně.
var cards: Array[Button] = []
var _root: Control
var _main: Control
var _levels: Control
var _settings_panel: SettingsPanel
var _continue: Button
var _continue_title: Label
var _continue_note: Label
var _summary: Label
var _grid: GridContainer


func _init(game_settings: GameSettings, player_progress: Progress) -> void:
	settings = game_settings
	progress = player_progress
	name = "Menu"


func _ready() -> void:
	_root = Control.new()
	_root.name = "Root"
	_root.theme = PaperUi.theme()
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_build_main()
	_build_levels()
	get_viewport().size_changed.connect(_fit)
	set_ui_scale(settings.ui_scale)
	show_main()


func set_ui_scale(value: float) -> void:
	ui_scale = value
	_fit()


## Která obrazovka je vidět: "main", "levels" nebo "settings".
func current_screen() -> String:
	if _settings_panel != null:
		return "settings"
	return "levels" if _levels.visible else "main"


func show_main() -> void:
	close_settings()
	refresh()
	_main.show()
	_levels.hide()


func show_levels() -> void:
	close_settings()
	refresh()
	_main.hide()
	_levels.show()


func show_settings() -> void:
	if _settings_panel != null:
		return
	_settings_panel = SettingsPanel.new(settings, true)
	_settings_panel.closed.connect(close_settings)
	_settings_panel.reset_progress_confirmed.connect(func() -> void:
		reset_requested.emit()
		refresh())
	_root.add_child(_settings_panel)


func close_settings() -> void:
	if _settings_panel != null:
		_settings_panel.queue_free()
		_settings_panel = null


## Zpět o úroveň (Esc, tlačítko Zpět). Vrací false v hlavním menu.
func back() -> bool:
	match current_screen():
		"settings":
			_settings_panel.close()
		"levels":
			show_main()
		_:
			return false
	return true


## Aktualizuje text „Pokračovat“, karty misí a souhrn podle postupu.
func refresh() -> void:
	if _continue == null:
		return
	var target := continue_target()
	var info := Campaign.mission(target["index"])
	_continue_title.text = target["label"]
	if target["resume"]:
		_continue_note.text = "Rozehráno: %s (%s)" % [info["title"],
			PaperUi.format_ticks(int(progress.suspended["tick"]))]
	else:
		_continue_note.text = info["title"]
	for i in cards.size():
		_fill_card(cards[i], i)
	_summary.text = "Splněno %d z %d misí" % [progress.completed_count(), Campaign.count()]


## Kam vede hlavní tlačítko: {"index", "resume", "label"}.
func continue_target() -> Dictionary:
	if progress.has_suspended():
		var index := Campaign.index_of(progress.suspended["mission"])
		if index >= 0:
			return {"index": index, "resume": true, "label": "Pokračovat"}
	var played := not progress.missions.is_empty()
	return {"index": progress.next_mission_index(settings.unlock_all), "resume": false,
		"label": "Pokračovat" if played else "Začít hrát"}


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo \
			and event.physical_keycode == KEY_ESCAPE and current_screen() == "levels":
		get_viewport().set_input_as_handled()
		show_main()


func _build_main() -> void:
	_main = Control.new()
	_main.name = "Main"
	_main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_main.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_main)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 14)
	_main.add_child(col)
	PaperUi.place(col, 0.5, 0.0, 0.5, 1.0, -260.0, 40.0, 260.0, -40.0)
	var banner := PanelContainer.new()
	banner.add_theme_stylebox_override("panel", PaperUi.paper("label", 18.0))
	col.add_child(banner)
	var title_col := VBoxContainer.new()
	title_col.add_theme_constant_override("separation", 0)
	banner.add_child(title_col)
	var title := PaperUi.label("Lemmings 2026", 58, PaperUi.INK)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_col.add_child(title)
	var tagline := PaperUi.label("Papírová výprava lumíků", 22, PaperUi.INK_DIM)
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_col.add_child(tagline)
	var gap := Control.new()
	gap.custom_minimum_size.y = 10
	col.add_child(gap)
	_continue = _big_button("play")
	_continue_title = _continue.get_node("Text/Title")
	_continue_note = _continue.get_node("Text/Note")
	_continue.pressed.connect(func() -> void:
		clicked.emit()
		var target := continue_target()
		play_requested.emit(target["index"], target["resume"]))
	col.add_child(_continue)
	var levels := PaperUi.button("Mise", Vector2(0, 62), "menu")
	levels.pressed.connect(func() -> void:
		clicked.emit()
		show_levels())
	col.add_child(levels)
	var options := PaperUi.button("Nastavení", Vector2(0, 62), "settings")
	options.pressed.connect(func() -> void:
		clicked.emit()
		show_settings())
	col.add_child(options)
	if not DeviceProfile.touch_mode():
		var quit := PaperUi.button("Ukončit hru", Vector2(0, 62), "back")
		quit.pressed.connect(func() -> void: quit_requested.emit())
		col.add_child(quit)
	var version := PaperUi.label("Verze %s · vývojová" % ProjectSettings.get_setting(
		"application/config/version", "0"), 17, PaperUi.TEXT)
	version.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.45))
	version.add_theme_constant_override("shadow_offset_y", 1)
	_main.add_child(version)
	PaperUi.place(version, 1.0, 1.0, 1.0, 1.0, -320.0, -40.0, -18.0, -12.0)
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT


func _big_button(icon_name: String) -> Button:
	var button := PaperUi.button("", Vector2(0, 92))
	var icon := TextureRect.new()
	icon.texture = PaperUi.icon(icon_name)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(icon)
	PaperUi.place(icon, 0.0, 0.5, 0.0, 0.5, 22.0, -24.0, 70.0, 24.0)
	var text := VBoxContainer.new()
	text.name = "Text"
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.add_theme_constant_override("separation", -2)
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(text)
	PaperUi.place(text, 0.0, 0.0, 1.0, 1.0, 88.0, 6.0, -16.0, -6.0)
	var title := PaperUi.label("", 30, PaperUi.INK)
	title.name = "Title"
	text.add_child(title)
	var note := PaperUi.label("", 18, PaperUi.INK_DIM)
	note.name = "Note"
	note.clip_text = true
	text.add_child(note)
	return button


func _build_levels() -> void:
	_levels = Control.new()
	_levels.name = "Levels"
	_levels.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_levels.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_levels)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_levels.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", PaperUi.paper("toolbar", 24.0))
	center.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 16)
	panel.add_child(col)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 16)
	col.add_child(head)
	var back := PaperUi.button("Zpět", Vector2(140, 52), "back")
	back.pressed.connect(func() -> void:
		clicked.emit()
		show_main())
	head.add_child(back)
	head.add_child(PaperUi.label("Mise", 34, PaperUi.TEXT))
	head.add_child(PaperUi.spacer())
	_summary = PaperUi.label("", 20, PaperUi.TEXT_DIM)
	head.add_child(_summary)
	_grid = GridContainer.new()
	_grid.columns = 3
	_grid.add_theme_constant_override("h_separation", 14)
	_grid.add_theme_constant_override("v_separation", 14)
	col.add_child(_grid)
	for i in Campaign.count():
		var card := _make_card(i)
		_grid.add_child(card)
		cards.append(card)


func _make_card(index: int) -> Button:
	var card := PaperUi.button("", Vector2(300, 150))
	card.pressed.connect(func() -> void:
		clicked.emit()
		var resume: bool = progress.has_suspended() \
			and progress.suspended["mission"] == Campaign.mission(index)["id"]
		play_requested.emit(index, resume))
	var col := VBoxContainer.new()
	col.name = "Text"
	col.add_theme_constant_override("separation", 4)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(col)
	PaperUi.place(col, 0.0, 0.0, 1.0, 1.0, 18.0, 14.0, -18.0, -12.0)
	var title := PaperUi.label("", 23, PaperUi.INK)
	title.name = "Title"
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(title)
	var status := PaperUi.label("", 18, PaperUi.INK_DIM)
	status.name = "Status"
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(status)
	var badge := TextureRect.new()
	badge.name = "Badge"
	badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(badge)
	PaperUi.place(badge, 1.0, 1.0, 1.0, 1.0, -52.0, -50.0, -14.0, -12.0)
	return card


func _fill_card(card: Button, index: int) -> void:
	var info := Campaign.mission(index)
	var id: String = info["id"]
	var entry := progress.entry(id)
	var unlocked := progress.is_unlocked(index, settings.unlock_all)
	card.disabled = not unlocked
	(card.get_node("Text/Title") as Label).text = info["title"]
	var status := card.get_node("Text/Status") as Label
	var badge := card.get_node("Badge") as TextureRect
	if not unlocked:
		status.text = "Zamčeno – nejdřív splň předchozí misi."
		badge.texture = PaperUi.icon("lock")
	elif entry["completed"]:
		status.text = "Splněno · nejlépe %d z %d (%s)" % [int(entry["best_saved"]),
			int(info["lemmings"]), PaperUi.format_ticks(int(entry["best_ticks"]))]
		badge.texture = PaperUi.icon("check")
	else:
		status.text = "Zachraň %d z %d" % [int(info["required"]), int(info["lemmings"])]
		badge.texture = null
	if progress.has_suspended() and progress.suspended["mission"] == id:
		status.text += "\nRozehráno – pokračuje se"


func _fit() -> void:
	if _root == null:
		return
	var vp := get_viewport().get_visible_rect().size
	_root.scale = Vector2(ui_scale, ui_scale)
	_root.size = vp / ui_scale
