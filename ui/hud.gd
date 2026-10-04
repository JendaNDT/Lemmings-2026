class_name Hud
extends CanvasLayer
## Herní rozhraní: horní lišta se stavem, spodní lišta s dovednostmi a ovládáním,
## pauzovací menu, nastavení a okno s výsledkem. Staví se celé z kódu,
## vzhled sdílí s menu přes PaperUi.

signal skill_selected(skill: int)
signal release_rate_step(delta: int)
signal pause_pressed
signal speed_pressed
## Krok o jeden tik (jen v pauze).
signal step_pressed
signal restart_pressed
signal nuke_requested
signal nuke_decided(confirmed: bool)
signal sound_pressed
## Tlačítko Menu (otevře pauzovací menu).
signal menu_pressed
## Volba v pauzovacím menu nebo ve výsledku: "resume", "restart", "next",
## "levels", "main_menu", "demo" (ukázka řešení).
signal menu_action(action: String)

const TOP_BAR_HEIGHT := 72.0
const BOTTOM_BAR_HEIGHT := 160.0
const ACCENT := PaperUi.ACCENT
const INK := PaperUi.INK
const INK_DIM := PaperUi.INK_DIM
const TEXT := PaperUi.TEXT
const TEXT_DIM := PaperUi.TEXT_DIM
const SKILL_ICONS := {
	Lemming.Skill.CLIMBER: "climber", Lemming.Skill.FLOATER: "floater",
	Lemming.Skill.BOMBER: "bomber",
	Lemming.Skill.BLOCKER: "blocker", Lemming.Skill.BUILDER: "builder",
	Lemming.Skill.BASHER: "basher", Lemming.Skill.DIGGER: "digger",
	Lemming.Skill.MINER: "miner",
}
const SKILL_TIPS := {
	Lemming.Skill.CLIMBER: "Trvale umožní lézt po stěnách. Pod stropem se otočí a spadne.",
	Lemming.Skill.FLOATER: "Trvalý padák chrání před dlouhým pádem. Lze kombinovat s lezcem.",
	Lemming.Skill.BOMBER: "Za 5 herních sekund vybuchne. Do té doby pokračuje v práci.",
	Lemming.Skill.BLOCKER: "Zastaví se a obrací ostatní lumíky.",
	Lemming.Skill.BUILDER: "Postaví dvanáct stoupajících schodů.",
	Lemming.Skill.BASHER: "Razí vodorovný tunel. Ocel ho zastaví.",
	Lemming.Skill.MINER: "Kope šikmo dolů. Ocel ho zastaví.",
	Lemming.Skill.DIGGER: "Kope svisle dolů. Ocel ho zastaví.",
}
const SKILL_WIDTH := 132.0
const SKILL_GAP := 6.0

## Nastavení hráče (pro obrazovku nastavení v pauze); nastaví hra.
var settings: GameSettings
## Úvodní karta mise (otevírá ji hra na začátku mise).
var briefing: BriefingCard
## Velikost rozhraní (1.0 = návrhová); lišty se zvětší, herní plocha zmenší.
var ui_scale := 1.0
var _sim: LevelSim
var _root: Control
var _title: Label
var _fps_tab: PanelContainer
var _fps: Label
var _stats: Label
var _rate_value: Label
var _skills_box: HBoxContainer
var _pause_button: Button
var _step_button: Button
var _speed_button: Button
var _restart_button: Button
var _menu_button: Button
var _nuke_button: Button
var _sound_button: Button
var _confirm_layer: Panel
var _pause_layer: Panel
var _pause_subtitle: Label
var _settings_panel: SettingsPanel
var _hint_button: Button
var _hint_label: Label
var _demo_button: Button
var _can_demo := false
var _demo_running := false
var _hints := PackedStringArray()
var _hint_index := 0
var _result_layer: Control
var _result_stars: CenterContainer
var _result_title: Label
var _result_text: Label
var _result_note: Label
var _next_button: Button
var _again_button: Button
## Lemming.Skill → { "button": Button, "count": Label }
var _skill_widgets := {}
var _visible_skills: Array[int] = []
var _selected_skill := -1


func _ready() -> void:
	_build()
	get_viewport().size_changed.connect(_fit)
	_fit()


## Nová mise: `title` s číslem z kampaně (prázdný = název z levelu),
## `hints` pro nápovědu v pauzovacím menu (od obecné po konkrétní),
## `can_demo` = mise má uloženou ukázku řešení, `demo` = ukázka právě běží.
func setup(sim: LevelSim, title := "", hints := PackedStringArray(), can_demo := false,
		demo := false) -> void:
	_sim = sim
	_result_layer.visible = false
	_pause_layer.visible = false
	_title.text = title if not title.is_empty() else sim.spec.title
	_pause_subtitle.text = _title.text
	_hints = hints
	_hint_index = 0
	_hint_button.visible = not hints.is_empty()
	_hint_button.text = "Nápověda"
	_hint_label.visible = false
	_can_demo = can_demo
	_demo_running = demo
	_demo_button.visible = can_demo and not demo
	_restart_button.text = "Hrát sám" if demo else "Znovu"
	_restart_button.tooltip_text = "Ukončí ukázku a spustí misi znovu (R)" if demo \
		else "Začne misi znovu (R)"
	for child in _skills_box.get_children():
		child.free()
	_skill_widgets.clear()
	_visible_skills.clear()
	_selected_skill = -1
	var hotkey := 1
	for skill: int in Lemming.SKILL_ORDER:
		if int(sim.skills.get(skill, 0)) <= 0:
			continue
		_add_skill_button(skill, hotkey)
		_visible_skills.append(skill)
		hotkey += 1
	_fit()
	refresh(false, 1.0)


## Dovednosti v pořadí, v jakém jsou na liště (klávesy 1, 2, 3…).
func visible_skills() -> Array[int]:
	return _visible_skills


func select_skill(skill: int) -> void:
	_selected_skill = skill
	for s: int in _skill_widgets:
		var button: Button = _skill_widgets[s]["button"]
		button.set_pressed_no_signal(s == skill)


func refresh(paused: bool, speed: float) -> void:
	if _sim == null:
		return
	var secs := _sim.time_left_seconds()
	_stats.text = "Venku %d     Doma %d / %d     Čeká %d     Čas %d:%02d" % [
		_sim.lemmings_out(),
		_sim.saved,
		_sim.spec.save_required,
		_sim.lemmings_waiting(),
		floori(secs / 60.0),
		secs % 60,
	]
	_rate_value.text = str(_sim.release_rate)
	for s: int in _skill_widgets:
		var count_label: Label = _skill_widgets[s]["count"]
		count_label.text = str(int(_sim.skills.get(s, 0)))
	_pause_button.text = "Pokračuj" if paused else "Pauza"
	_step_button.visible = paused and not _sim.finished
	_speed_button.text = "½×" if speed < 1.0 else "%d×" % roundi(speed)
	_nuke_button.disabled = _sim.finished or _sim.nuking or _demo_running
	_nuke_button.text = "Odpočet…" if _sim.nuking else "Odpálit vše"
	for skill: int in _skill_widgets:
		(_skill_widgets[skill]["button"] as Button).disabled = \
			_sim.finished or int(_sim.skills.get(skill, 0)) <= 0
	if _fps_tab.visible:
		_fps.text = "%d FPS" % roundi(Engine.get_frames_per_second())


## Další nápověda v pauzovacím menu (postupně, poslední zůstane).
func _show_next_hint() -> void:
	if _hints.is_empty():
		return
	_hint_label.text = "Tip %d/%d: %s" % [_hint_index + 1, _hints.size(), _hints[_hint_index]]
	_hint_label.visible = true
	_hint_index = mini(_hint_index + 1, _hints.size() - 1)
	_hint_button.text = "Další tip" if _hint_index < _hints.size() - 1 else "Nápověda"


## Ikona tlačítka zvuku: reproduktor s vlnkami, nebo přeškrtnutý.
func set_sound(enabled: bool) -> void:
	if _sound_button == null:
		return
	_sound_button.icon = PaperUi.icon("sound_on" if enabled else "sound_off")
	_sound_button.tooltip_text = "Zvuk je zapnutý (T)" if enabled else "Zvuk je vypnutý (T)"


func show_fps(enabled: bool) -> void:
	_fps_tab.visible = enabled


## Velikost rozhraní: lišty a dialogy se zvětší, herní plocha je pod nimi.
func set_ui_scale(value: float) -> void:
	ui_scale = value
	_fit()


## Skutečná výška horní a spodní lišty na obrazovce (pro kameru a dotyky).
func top_bar_height() -> float:
	return TOP_BAR_HEIGHT * ui_scale


func bottom_bar_height() -> float:
	return BOTTOM_BAR_HEIGHT * ui_scale


func show_nuke_confirmation() -> void:
	_confirm_layer.show()


func close_nuke_confirmation() -> void:
	_confirm_layer.hide()


func confirmation_open() -> bool:
	return _confirm_layer.visible


func show_pause_menu() -> void:
	_pause_layer.show()


func close_pause_menu() -> void:
	_pause_layer.hide()
	if _settings_panel != null:
		_settings_panel.queue_free()
		_settings_panel = null


## Je otevřené pauzovací menu nebo nastavení (hra stojí, dotyky nepatří hře).
func pause_menu_open() -> bool:
	return _pause_layer.visible


func settings_open() -> bool:
	return _settings_panel != null


func open_settings() -> void:
	if settings == null or _settings_panel != null:
		return
	_settings_panel = SettingsPanel.new(settings, false)
	_settings_panel.closed.connect(close_settings)
	_root.add_child(_settings_panel)


func close_settings() -> void:
	if _settings_panel != null:
		_settings_panel.queue_free()
		_settings_panel = null


## Okno výsledku. `info`: {"next_title", "best_saved", "best_ticks", "first_win",
## "new_best", "unlocked_next", "stars", "stars_before", "thresholds", "fails"}
## – vše volitelné (bez kampaně jen základ).
func show_result(sim: LevelSim, info := {}) -> void:
	_result_layer.visible = true
	_pause_layer.visible = false
	var won := sim.is_won()
	if info.get("demo", false):
		_show_demo_result(sim)
		return
	if won:
		_result_title.text = "Výborně!"
		_result_title.add_theme_color_override("font_color", ACCENT)
	else:
		_result_title.text = "Tentokrát to nevyšlo"
		_result_title.add_theme_color_override("font_color", PaperUi.WARN)
	_result_text.text = "Zachráněno %d z %d lumíků (potřeba %d)." % [
		sim.saved, sim.spec.lemming_count, sim.spec.save_required
	]
	var notes := PackedStringArray()
	if info.get("new_best", false):
		notes.append("Nový rekord!")
	if info.get("unlocked_next", false):
		notes.append("Odemčena další mise.")
	if int(info.get("best_saved", 0)) > 0:
		notes.append("Nejlepší výsledek: %d z %d za %s" % [int(info["best_saved"]),
			sim.spec.lemming_count, PaperUi.format_ticks(int(info.get("best_ticks", 0)))])
	var thresholds: Array = info.get("thresholds", [])
	var stars := int(info.get("stars", 0))
	for child in _result_stars.get_children():
		child.free()
	_result_stars.visible = thresholds.size() == 3
	if _result_stars.visible:
		_result_stars.add_child(PaperUi.stars_row(Campaign.stars_for(
			{"required": thresholds[0], "master": thresholds[2]}, sim.saved), 40.0))
		if stars > int(info.get("stars_before", 0)) and won:
			notes.append("Nová hvězda!")
		var next_star := -1
		for limit: int in thresholds:
			if sim.saved < limit:
				next_star = limit
				break
		if next_star > 0 and won:
			notes.append("Další hvězda za %d zachráněných." % next_star)
	if not won and int(info.get("fails", 0)) >= 2 and not _hints.is_empty():
		notes.append("Tip: " + _hints[0])
	if not won and int(info.get("fails", 0)) >= 2 and _can_demo:
		notes.append("Nevíš si rady? V pauze je Ukázka řešení.")
	if won and info.get("demo_seen", false):
		notes.append("Po ukázce řešení – hvězdy platí.")
	_result_note.text = "\n".join(notes)
	_result_note.visible = not notes.is_empty()
	var next_title: String = info.get("next_title", "")
	_next_button.visible = won and not next_title.is_empty()
	_next_button.text = "Další: " + next_title
	_again_button.text = "Hrát znovu" if won else "Zkusit znovu"


func result_open() -> bool:
	return _result_layer.visible


## Konec ukázky: bez hvězd a zápisu, nabídne hrát sám.
func _show_demo_result(sim: LevelSim) -> void:
	_result_title.text = "Konec ukázky"
	_result_title.add_theme_color_override("font_color", ACCENT)
	_result_text.text = "Ukázka zachránila %d z %d lumíků (potřeba %d)." % [
		sim.saved, sim.spec.lemming_count, sim.spec.save_required]
	_result_note.text = "Teď to zkus sám – hvězdy se počítají jen za vlastní hru."
	_result_note.visible = true
	for child in _result_stars.get_children():
		child.free()
	_result_stars.visible = false
	_next_button.visible = false
	_again_button.text = "Hrát sám"


# --- Stavba rozhraní --------------------------------------------------------------

func _build() -> void:
	_root = Control.new()
	_root.name = "Root"
	_root.theme = PaperUi.theme()
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	# Horní okraj: papírový štítek s názvem vlevo a proužek se stavem vpravo.
	var top_row := HBoxContainer.new()
	top_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_row.add_theme_constant_override("separation", 14)
	_root.add_child(top_row)
	PaperUi.place(top_row, 0.0, 0.0, 1.0, 0.0, 14.0, 10.0, -14.0, TOP_BAR_HEIGHT - 6.0)
	var title_tab := PanelContainer.new()
	title_tab.add_theme_stylebox_override("panel", PaperUi.paper("label", 12.0))
	top_row.add_child(title_tab)
	_title = PaperUi.label("", 26, INK)
	title_tab.add_child(_title)
	_fps_tab = PanelContainer.new()
	_fps_tab.add_theme_stylebox_override("panel", PaperUi.paper("label", 12.0))
	top_row.add_child(_fps_tab)
	_fps = PaperUi.label("", 20, INK_DIM)
	_fps_tab.add_child(_fps)
	_fps_tab.visible = false
	top_row.add_child(PaperUi.spacer())
	var stats_tab := PanelContainer.new()
	stats_tab.add_theme_stylebox_override("panel", PaperUi.paper("label", 12.0))
	top_row.add_child(stats_tab)
	_stats = PaperUi.label("", 21, INK)
	stats_tab.add_child(_stats)

	# Dva řádky udrží všech osm dovedností dostupných i na telefonu.
	var bottom := PanelContainer.new()
	_root.add_child(bottom)
	PaperUi.place(bottom, 0.0, 1.0, 1.0, 1.0, 12.0, -BOTTOM_BAR_HEIGHT, -12.0, -10.0)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 6)
	bottom.add_child(rows)
	_build_controls(rows)
	_skills_box = HBoxContainer.new()
	_skills_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_skills_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_skills_box.add_theme_constant_override("separation", int(SKILL_GAP))
	rows.add_child(_skills_box)

	_build_result()
	_build_pause_menu()
	_build_briefing()
	_build_confirmation()


func _build_controls(rows: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	rows.add_child(row)
	_menu_button = PaperUi.button("Menu", Vector2(132, 44), "menu")
	_menu_button.tooltip_text = "Pauza a menu: nastavení, výběr misí (Esc)"
	_menu_button.pressed.connect(func() -> void: menu_pressed.emit())
	row.add_child(_menu_button)
	row.add_child(PaperUi.spacer())
	row.add_child(PaperUi.label("Vypouštění", 17, TEXT_DIM))
	var minus := PaperUi.button("−", Vector2(48, 44))
	minus.pressed.connect(func() -> void: release_rate_step.emit(-1))
	row.add_child(minus)
	_rate_value = PaperUi.label("50", 24, TEXT)
	_rate_value.custom_minimum_size.x = 42
	_rate_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(_rate_value)
	var plus := PaperUi.button("+", Vector2(48, 44))
	plus.pressed.connect(func() -> void: release_rate_step.emit(1))
	row.add_child(plus)
	row.add_child(PaperUi.spacer())
	_pause_button = PaperUi.button("Pauza", Vector2(120, 44))
	_pause_button.tooltip_text = "Zastaví čas; dovednosti jde přidělovat i v pauze (mezerník)"
	_pause_button.pressed.connect(func() -> void: pause_pressed.emit())
	row.add_child(_pause_button)
	_step_button = PaperUi.button("Krok", Vector2(76, 44))
	_step_button.tooltip_text = "Posune pozastavenou hru o jeden tik (tečka)"
	_step_button.pressed.connect(func() -> void: step_pressed.emit())
	_step_button.visible = false
	row.add_child(_step_button)
	_speed_button = PaperUi.button("1×", Vector2(64, 44))
	_speed_button.tooltip_text = "Rychlost 1× → 3× → ½× (F)"
	_speed_button.pressed.connect(func() -> void: speed_pressed.emit())
	row.add_child(_speed_button)
	_restart_button = PaperUi.button("Znovu", Vector2(96, 44))
	_restart_button.pressed.connect(func() -> void: restart_pressed.emit())
	row.add_child(_restart_button)
	_nuke_button = PaperUi.button("Odpálit vše", Vector2(140, 44))
	_nuke_button.tooltip_text = "Zavře líheň a spustí postupné odpočty bomb (N)."
	_nuke_button.pressed.connect(func() -> void: nuke_requested.emit())
	row.add_child(_nuke_button)
	_sound_button = PaperUi.button("", Vector2(56, 44), "sound_on")
	_sound_button.pressed.connect(func() -> void: sound_pressed.emit())
	row.add_child(_sound_button)
	set_sound(true)


func _build_result() -> void:
	# Okno s výsledkem uprostřed obrazovky; hra je vidět za lehkým stínem.
	_result_layer = PaperUi.overlay(0.3)
	_root.add_child(_result_layer)
	var col := PaperUi.dialog(_result_layer, 560.0, 16)
	_result_title = PaperUi.label("", 40, ACCENT)
	_result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_result_title)
	_result_stars = CenterContainer.new()
	_result_stars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_result_stars)
	_result_text = PaperUi.label("", 22, INK)
	_result_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_result_text)
	_result_note = PaperUi.label("", 19, INK_DIM)
	_result_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_result_note.custom_minimum_size.x = 500
	col.add_child(_result_note)
	_next_button = PaperUi.button("Další mise", Vector2(0, 60), "next")
	_next_button.pressed.connect(func() -> void: menu_action.emit("next"))
	col.add_child(_next_button)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	col.add_child(row)
	_again_button = PaperUi.button("Hrát znovu", Vector2(0, 56), "restart")
	_again_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_again_button.pressed.connect(func() -> void: restart_pressed.emit())
	row.add_child(_again_button)
	var levels := PaperUi.button("Mise", Vector2(0, 56), "menu")
	levels.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	levels.pressed.connect(func() -> void: menu_action.emit("levels"))
	row.add_child(levels)
	_result_layer.visible = false


func _build_pause_menu() -> void:
	_pause_layer = PaperUi.overlay(0.5)
	_root.add_child(_pause_layer)
	var col := PaperUi.dialog(_pause_layer, 460.0, 12)
	var title := PaperUi.label("Pozastaveno", 34, INK)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	_pause_subtitle = PaperUi.label("", 19, INK_DIM)
	_pause_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_pause_subtitle)
	for item: Array in [["Pokračovat", "resume", "play"], ["Začít znovu", "restart", "restart"],
			["Nastavení", "settings", "settings"], ["Výběr misí", "levels", "menu"],
			["Hlavní menu", "main_menu", "back"]]:
		var button := PaperUi.button(item[0], Vector2(400, 56), item[2])
		var action: String = item[1]
		if action == "settings":
			button.pressed.connect(open_settings)
		else:
			button.pressed.connect(func() -> void: menu_action.emit(action))
		col.add_child(button)
	_hint_button = PaperUi.button("Nápověda", Vector2(400, 50))
	_hint_button.pressed.connect(_show_next_hint)
	col.add_child(_hint_button)
	_hint_label = PaperUi.label("", 18, INK)
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint_label.custom_minimum_size.x = 400
	_hint_label.visible = false
	col.add_child(_hint_label)
	_hint_button.visible = false
	_demo_button = PaperUi.button("Ukázka řešení", Vector2(400, 50), "play")
	_demo_button.tooltip_text = "Spustí misi znovu a přehraje její řešení. Hvězdy zůstávají."
	_demo_button.pressed.connect(func() -> void: menu_action.emit("demo"))
	_demo_button.visible = false
	col.add_child(_demo_button)
	_pause_layer.hide()


func _build_briefing() -> void:
	briefing = BriefingCard.new()
	_root.add_child(briefing)


func _build_confirmation() -> void:
	_confirm_layer = PaperUi.overlay(0.7)
	_root.add_child(_confirm_layer)
	var col := PaperUi.dialog(_confirm_layer, 0.0)
	col.add_child(PaperUi.label("Odpálit všechny?", 30, INK))
	col.add_child(PaperUi.label("Líheň se zavře a lumíkům začne odpočet bomby.\n"
		+ "Dosavadní záchrany zůstanou započítané.", 20, INK))
	var cancel := PaperUi.button("Pokračovat ve hře", Vector2(460, 56))
	cancel.pressed.connect(func() -> void: nuke_decided.emit(false))
	col.add_child(cancel)
	var confirm := PaperUi.button("Ano, spustit odpočty", Vector2(460, 56))
	confirm.pressed.connect(func() -> void: nuke_decided.emit(true))
	col.add_child(confirm)
	_confirm_layer.hide()


func _add_skill_button(skill: int, hotkey: int) -> void:
	# Slonovinová papírová dlaždice: velká ikona, počet v rohu, popisek dole.
	var button := PaperUi.button("", Vector2(SKILL_WIDTH, 80))
	button.tooltip_text = SKILL_TIPS[skill]
	button.toggle_mode = true
	button.pressed.connect(func() -> void: skill_selected.emit(skill))
	var icon := TextureRect.new()
	icon.texture = PaperUi.icon(SKILL_ICONS[skill])
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(icon)
	PaperUi.place(icon, 0.5, 0.0, 0.5, 0.0, -30.0, 4.0, 26.0, 54.0)
	var count := PaperUi.label("0", 22, INK)
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	button.add_child(count)
	PaperUi.place(count, 1.0, 0.0, 1.0, 0.0, -44.0, 22.0, -10.0, 52.0)
	var caption := PaperUi.label("%d · %s" % [hotkey, Lemming.SKILL_NAMES[skill]], 15, INK_DIM)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.clip_text = true
	button.add_child(caption)
	PaperUi.place(caption, 0.0, 1.0, 1.0, 1.0, 2.0, -26.0, -2.0, -4.0)
	_skills_box.add_child(button)
	_skill_widgets[skill] = {"button": button, "count": count}


## Rozhraní pokryje obrazovku i při jiné velikosti; dovednosti se při nedostatku
## místa zúží, aby se jich osm vešlo vedle sebe.
func _fit() -> void:
	if _root == null:
		return
	var vp := get_viewport().get_visible_rect().size
	_root.scale = Vector2(ui_scale, ui_scale)
	_root.position = Vector2.ZERO
	_root.size = vp / ui_scale
	var count := _skill_widgets.size()
	if count > 0:
		var room := _root.size.x - 48.0 - SKILL_GAP * (count - 1)
		var width := clampf(floorf(room / count), 96.0, SKILL_WIDTH)
		for skill: int in _skill_widgets:
			(_skill_widgets[skill]["button"] as Button).custom_minimum_size.x = width
