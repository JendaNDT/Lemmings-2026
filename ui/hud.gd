class_name Hud
extends CanvasLayer
## Herní rozhraní: horní lišta se stavem, spodní lišta s dovednostmi a ovládáním
## a okno s výsledkem. Staví se celé z kódu, aby se dalo snadno upravovat.

signal skill_selected(skill: int)
signal release_rate_step(delta: int)
signal pause_pressed
signal speed_pressed
signal restart_pressed
signal mission_selected(index: int)
signal nuke_requested
signal nuke_decided(confirmed: bool)

const TOP_BAR_HEIGHT := 56.0
const BOTTOM_BAR_HEIGHT := 144.0
const ACCENT := Color("a6ddb1")
const TEXT := Color("fff1d5")
const TEXT_DIM := Color("c4d1c5")
const SKILL_ICONS := {
	Lemming.Skill.BLOCKER: "blocker", Lemming.Skill.BUILDER: "builder",
	Lemming.Skill.BASHER: "basher", Lemming.Skill.DIGGER: "digger",
	Lemming.Skill.MINER: "miner",
}

var _sim: LevelSim
var _root: Control
var _title: Label
var _stats: Label
var _rate_value: Label
var _skills_box: HBoxContainer
var _pause_button: Button
var _speed_button: Button
var _mission_picker: OptionButton
var _nuke_button: Button
var _confirm_layer: Panel
var _result_layer: CenterContainer
var _result_title: Label
var _result_text: Label
## Lemming.Skill → { "button": Button, "count": Label }
var _skill_widgets := {}
var _visible_skills: Array[int] = []
var _selected_skill := -1


func _ready() -> void:
	_build()


func setup(sim: LevelSim) -> void:
	_sim = sim
	_result_layer.visible = false
	_title.text = sim.spec.title
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
	_speed_button.text = "%d×" % roundi(speed)
	_nuke_button.disabled = _sim.finished or _sim.nuking
	_nuke_button.text = "Odpočet…" if _sim.nuking else "Ukončit"
	for skill: int in _skill_widgets:
		(_skill_widgets[skill]["button"] as Button).disabled = \
			_sim.finished or int(_sim.skills.get(skill, 0)) <= 0


func set_missions(titles: Array[String], selected: int) -> void:
	_mission_picker.clear()
	for title in titles:
		_mission_picker.add_item(title)
	_mission_picker.select(selected)


func show_nuke_confirmation() -> void:
	_confirm_layer.show()


func close_nuke_confirmation() -> void:
	_confirm_layer.hide()


func confirmation_open() -> bool:
	return _confirm_layer.visible


func show_result(sim: LevelSim) -> void:
	_result_layer.visible = true
	if sim.is_won():
		_result_title.text = "Výborně!"
		_result_title.add_theme_color_override("font_color", ACCENT)
	else:
		_result_title.text = "Tentokrát to nevyšlo"
		_result_title.add_theme_color_override("font_color", Color(1.0, 0.55, 0.45))
	_result_text.text = "Zachráněno %d z %d lumíků (potřeba %d)." % [
		sim.saved, sim.spec.lemming_count, sim.spec.save_required
	]


# --- Stavba rozhraní --------------------------------------------------------------

func _build() -> void:
	_root = Control.new()
	_root.name = "Root"
	_root.theme = _make_theme()
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	# Horní lišta: název levelu a počítadla.
	var top := PanelContainer.new()
	_root.add_child(top)
	_place(top, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, TOP_BAR_HEIGHT)
	var top_row := HBoxContainer.new()
	top.add_child(top_row)
	_title = _label("", 22, TEXT)
	top_row.add_child(_title)
	top_row.add_child(_spacer())
	_stats = _label("", 22, TEXT)
	top_row.add_child(_stats)

	# Dva řádky udrží všech osm dovedností dostupných i na telefonu.
	var bottom := PanelContainer.new()
	_root.add_child(bottom)
	_place(bottom, 0.0, 1.0, 1.0, 1.0, 0.0, -BOTTOM_BAR_HEIGHT, 0.0, 0.0)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 6)
	bottom.add_child(rows)
	_build_controls(rows)
	_skills_box = HBoxContainer.new()
	_skills_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_skills_box.add_theme_constant_override("separation", 6)
	rows.add_child(_skills_box)

	# Okno s výsledkem uprostřed obrazovky.
	_result_layer = CenterContainer.new()
	_result_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_result_layer)
	_result_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(520, 0)
	_result_layer.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 18)
	panel.add_child(col)
	_result_title = _label("", 40, ACCENT)
	_result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_result_title)
	_result_text = _label("", 22, TEXT)
	_result_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_result_text)
	var again := _button("Hrát znovu", Vector2(0, 64))
	again.pressed.connect(func() -> void: restart_pressed.emit())
	col.add_child(again)
	_result_layer.visible = false

	_build_confirmation()


func _build_controls(rows: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	rows.add_child(row)
	_mission_picker = OptionButton.new()
	_mission_picker.custom_minimum_size = Vector2(260, 44)
	_mission_picker.focus_mode = Control.FOCUS_NONE
	_mission_picker.item_selected.connect(func(index: int) -> void: mission_selected.emit(index))
	row.add_child(_mission_picker)
	row.add_child(_spacer())
	row.add_child(_label("Vypouštění", 16, TEXT_DIM))
	var minus := _button("−", Vector2(48, 44))
	minus.pressed.connect(func() -> void: release_rate_step.emit(-1))
	row.add_child(minus)
	_rate_value = _label("50", 24, TEXT)
	_rate_value.custom_minimum_size.x = 42
	_rate_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(_rate_value)
	var plus := _button("+", Vector2(48, 44))
	plus.pressed.connect(func() -> void: release_rate_step.emit(1))
	row.add_child(plus)
	row.add_child(_spacer())
	_pause_button = _button("Pauza", Vector2(120, 44))
	_pause_button.pressed.connect(func() -> void: pause_pressed.emit())
	row.add_child(_pause_button)
	_speed_button = _button("1×", Vector2(64, 44))
	_speed_button.pressed.connect(func() -> void: speed_pressed.emit())
	row.add_child(_speed_button)
	var restart := _button("Znovu", Vector2(96, 44))
	restart.pressed.connect(func() -> void: restart_pressed.emit())
	row.add_child(restart)
	_nuke_button = _button("Ukončit", Vector2(112, 44))
	_nuke_button.tooltip_text = "Zavře líheň a spustí postupné odpočty bomb. Vyžaduje potvrzení."
	_nuke_button.pressed.connect(func() -> void: nuke_requested.emit())
	row.add_child(_nuke_button)


func _build_confirmation() -> void:
	_confirm_layer = Panel.new()
	_confirm_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := _box(Color(0, 0, 0, 0.7), Color.TRANSPARENT, 0, 0)
	_confirm_layer.add_theme_stylebox_override("panel", shade)
	_root.add_child(_confirm_layer)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_confirm_layer.add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	panel.add_child(col)
	col.add_child(_label("Ukončit pokus?", 30, TEXT))
	col.add_child(_label("Líheň se zavře a lumíkům začne odpočet bomby.\n"
		+ "Dosavadní záchrany zůstanou započítané.", 20, TEXT))
	var cancel := _button("Pokračovat ve hře", Vector2(460, 56))
	cancel.pressed.connect(func() -> void: nuke_decided.emit(false))
	col.add_child(cancel)
	var confirm := _button("Ano, spustit odpočty", Vector2(460, 56))
	confirm.pressed.connect(func() -> void: nuke_decided.emit(true))
	col.add_child(confirm)
	_confirm_layer.hide()


func _add_skill_button(skill: int, hotkey: int) -> void:
	var button := _button("", Vector2(100, 68))
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.toggle_mode = true
	button.pressed.connect(func() -> void: skill_selected.emit(skill))
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(col)
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var count := _label("0", 26, TEXT)
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var number_row := HBoxContainer.new()
	number_row.alignment = BoxContainer.ALIGNMENT_CENTER
	number_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if SKILL_ICONS.has(skill):
		var icon := TextureRect.new()
		icon.texture = load("res://assets/clay/ui/icons/%s.svg" % SKILL_ICONS[skill])
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(30, 30)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		number_row.add_child(icon)
	number_row.add_child(count)
	col.add_child(number_row)
	var caption := _label("%d · %s" % [hotkey, Lemming.SKILL_NAMES[skill]], 15, TEXT_DIM)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(caption)
	_skills_box.add_child(button)
	_skill_widgets[skill] = {"button": button, "count": count}


func _place(c: Control, al: float, at: float, ar: float, ab: float,
		ol: float, ot: float, o_r: float, ob: float) -> void:
	c.anchor_left = al
	c.anchor_top = at
	c.anchor_right = ar
	c.anchor_bottom = ab
	c.offset_left = ol
	c.offset_top = ot
	c.offset_right = o_r
	c.offset_bottom = ob


func _label(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _button(text: String, min_size: Vector2) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.focus_mode = Control.FOCUS_NONE
	return b


func _spacer() -> Control:
	var s := Control.new()
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return s


func _make_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 20
	var panel_box := _box(Color(0.05, 0.06, 0.1, 0.85), Color(1, 1, 1, 0.06), 0, 10)
	t.set_stylebox("panel", "PanelContainer", panel_box)
	t.set_stylebox("normal", "Button", _box(Color(0.12, 0.14, 0.2, 0.95), Color(1, 1, 1, 0.08), 12, 8))
	t.set_stylebox("hover", "Button", _box(Color(0.18, 0.21, 0.29, 0.95), Color(1, 1, 1, 0.22), 12, 8))
	t.set_stylebox("pressed", "Button", _box(Color(0.12, 0.3, 0.18, 0.95), ACCENT, 12, 8))
	t.set_stylebox("hover_pressed", "Button", _box(Color(0.15, 0.36, 0.22, 0.95), ACCENT, 12, 8))
	t.set_stylebox("disabled", "Button", _box(Color(0.1, 0.1, 0.12, 0.6), Color(1, 1, 1, 0.04), 12, 8))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", ACCENT)
	t.set_font_size("font_size", "Button", 22)
	return t


func _box(bg: Color, border: Color, radius: int, margin: float) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(2)
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(margin)
	s.anti_aliasing = true
	return s
