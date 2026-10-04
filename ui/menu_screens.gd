class_name MenuScreens
extends CanvasLayer
## Obrazovky mimo hru: hlavní menu, výběr misí a nastavení. Jen ukazují stav
## postupu a nastavení a hlásí volby signály; hru spouští App.

## Hrát misi; `resume` = obnovit rozehraný pokus z postupu.
signal play_requested(index: int, resume: bool)
## Hrát Hřiště (pískoviště mimo kampaň).
signal playground_requested
signal quit_requested
## Hráč potvrdil smazání postupu.
signal reset_requested
## Zvuk kliknutí (přehraje App, menu samo zvuk nemá).
signal clicked

## Výška karty mise a nejmenší výška, když se tři řady karet nevejdou
## (telefon se zvětšeným rozhraním); okolí mřížky na obrazovce misí.
const CARD_HEIGHT := 150.0
const CARD_MIN_HEIGHT := 104.0
const CARD_GAP := 14.0
const LEVELS_CHROME := 196.0

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
var _chapter := 0
var _chapter_tabs: Array[Button] = []
var _playground_button: Button


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
	# Otevřít kapitolu, ve které hráč právě je.
	_chapter = maxi(0, Campaign.chapter_of(continue_target()["index"]))
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
	var title := Campaign.display_title(Campaign.mission(target["index"])["id"])
	_continue_title.text = target["label"]
	if target["resume"]:
		_continue_note.text = "Rozehráno: %s (%s)" % [title,
			PaperUi.format_ticks(int(progress.suspended["tick"]))]
	else:
		_continue_note.text = title
	for i in cards.size():
		_fill_card(cards[i], i)
		cards[i].visible = Campaign.chapter_of(i) == _chapter
	var total := 0
	for c in Campaign.CHAPTERS.size():
		var stars := progress.chapter_stars(c)
		total += stars[0]
		_chapter_tabs[c].text = "%s · %d/%d" % [Campaign.chapter_title(c), stars[0], stars[1]]
		_chapter_tabs[c].set_pressed_no_signal(c == _chapter)
	_summary.text = "Hvězdy %d / %d" % [total, Campaign.count() * 3]
	_playground_button.disabled = not progress.playground_unlocked(settings.unlock_all)
	_playground_button.tooltip_text = "Hřiště se otevře po splnění kapitoly I." \
		if _playground_button.disabled else "Pískoviště se všemi dovednostmi."


func show_chapter(chapter: int) -> void:
	_chapter = clampi(chapter, 0, Campaign.CHAPTERS.size() - 1)
	refresh()


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
	_playground_button = PaperUi.button("Hřiště", Vector2(150, 52), "play")
	_playground_button.add_theme_font_size_override("font_size", 18)
	_playground_button.pressed.connect(func() -> void:
		clicked.emit()
		playground_requested.emit())
	head.add_child(_playground_button)
	# Kapitoly jako záložky (Hřiště je v záhlaví, aby se vešly všechny čtyři).
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	col.add_child(tabs)
	var group := ButtonGroup.new()
	for c in Campaign.CHAPTERS.size():
		var tab := PaperUi.button(Campaign.chapter_title(c), Vector2(0, 48))
		tab.add_theme_font_size_override("font_size", 18)
		tab.toggle_mode = true
		tab.button_group = group
		tab.pressed.connect(func() -> void:
			clicked.emit()
			show_chapter(c))
		tabs.add_child(tab)
		_chapter_tabs.append(tab)
	_grid = GridContainer.new()
	_grid.columns = 3
	# Stejná šířka i pro kapitolu s jedinou misí (3 karty + mezery).
	_grid.custom_minimum_size = Vector2(3 * 300 + 2 * 14, 0)
	_grid.add_theme_constant_override("h_separation", int(CARD_GAP))
	_grid.add_theme_constant_override("v_separation", int(CARD_GAP))
	col.add_child(_grid)
	for i in Campaign.count():
		var card := _make_card(i)
		_grid.add_child(card)
		cards.append(card)


func _make_card(index: int) -> Button:
	var card := PaperUi.button("", Vector2(300, CARD_HEIGHT))
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
	var status := PaperUi.label("", 17, PaperUi.INK_DIM)
	status.name = "Status"
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(status)
	# Dole hvězdy a tečky obtížnosti (vyplní _fill_card).
	var marks := HBoxContainer.new()
	marks.name = "Marks"
	marks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(marks)
	PaperUi.place(marks, 0.0, 1.0, 1.0, 1.0, 18.0, -40.0, -62.0, -12.0)
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
	(card.get_node("Text/Title") as Label).text = Campaign.display_title(id)
	var status := card.get_node("Text/Status") as Label
	var badge := card.get_node("Badge") as TextureRect
	var marks := card.get_node("Marks") as HBoxContainer
	for child in marks.get_children():
		child.free()
	if unlocked:
		marks.add_child(PaperUi.stars_row(progress.stars(index), 22.0))
		marks.add_child(PaperUi.spacer())
		marks.add_child(PaperUi.tier_row(LevelDifficulty.tier(int(info["difficulty"])), 11.0))
	if not unlocked:
		status.text = "Zamčeno – nejdřív splň předchozí misi."
		badge.texture = PaperUi.icon("lock")
		return
	if entry["completed"]:
		status.text = "Nejlépe %d z %d (%s)" % [int(entry["best_saved"]),
			int(info["lemmings"]), PaperUi.format_ticks(int(entry["best_ticks"]))]
		badge.texture = PaperUi.icon("check")
	else:
		status.text = "Zachraň %d z %d" % [int(info["required"]), int(info["lemmings"])]
		badge.texture = null
	if progress.has_suspended() and progress.suspended["mission"] == id:
		status.text += " · rozehráno"


func _fit() -> void:
	if _root == null:
		return
	var vp := get_viewport().get_visible_rect().size
	_root.scale = Vector2(ui_scale, ui_scale)
	_root.size = vp / ui_scale
	_fit_cards()


## Karty se na nízké obrazovce zmenší, aby se vešly řady nejdelší kapitoly;
## hvězdy a tečky se pak posunou níž.
func _fit_cards() -> void:
	var longest := 1
	for chapter: Array in Campaign.CHAPTERS:
		longest = maxi(longest, int(chapter[3]))
	var rows := ceili(longest / 3.0)
	var room := (_root.size.y - LEVELS_CHROME - CARD_GAP * (rows - 1)) / rows
	var height := clampf(room, CARD_MIN_HEIGHT, CARD_HEIGHT)
	var compact := height < CARD_HEIGHT - 20.0
	for card in cards:
		card.custom_minimum_size.y = height
		var marks := card.get_node("Marks") as Control
		marks.offset_top = -34.0 if compact else -40.0
		marks.offset_bottom = -8.0 if compact else -12.0
		var badge := card.get_node("Badge") as Control
		badge.offset_top = -44.0 if compact else -50.0
		badge.offset_bottom = -8.0 if compact else -12.0
