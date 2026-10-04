class_name SettingsPanel
extends Control
## Obrazovka nastavení (z hlavního menu i z pauzy ve hře). Mění GameSettings
## přes set_value(); hra a menu změny uplatní hned, uloží se při zavření.

signal closed
## Jen z hlavního menu: hráč potvrdil smazání postupu.
signal reset_progress_confirmed

const TABS := ["Zvuk", "Zobrazení", "Ovládání", "Hra"]
const VOLUME_ROWS := [["master", "Celková hlasitost"], ["sfx", "Efekty"],
	["ui", "Rozhraní"], ["ambient", "Okolí (vítr, voda, láva)"], ["music", "Hudba (připravuje se)"]]

var settings: GameSettings
## Nabídnout „Smazat postup“ (jen v hlavním menu, ne uprostřed mise).
var allow_reset := false
## Pro testy: ovládací prvky podle klíče nastavení.
var controls := {}
var _tab_buttons: Array[Button] = []
var _pages: Array[Control] = []
var _confirm: Control


func _init(game_settings: GameSettings, with_reset := false) -> void:
	settings = game_settings
	allow_reset = with_reset
	name = "Settings"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP


func _ready() -> void:
	add_child(PaperUi.overlay(0.55))
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", PaperUi.paper("dialog", 26.0))
	center.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	panel.add_child(col)
	var head := HBoxContainer.new()
	col.add_child(head)
	head.add_child(PaperUi.label("Nastavení", 32, PaperUi.INK))
	head.add_child(PaperUi.spacer())
	var done := PaperUi.button("Hotovo", Vector2(150, 52), "check")
	done.pressed.connect(close)
	head.add_child(done)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	col.add_child(tabs)
	var group := ButtonGroup.new()
	for i in TABS.size():
		var tab := PaperUi.button(TABS[i], Vector2(150, 48))
		tab.toggle_mode = true
		tab.button_group = group
		tab.pressed.connect(show_tab.bind(i))
		tabs.add_child(tab)
		_tab_buttons.append(tab)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(820, 340)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	var pages := VBoxContainer.new()
	pages.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(pages)
	for builder: Callable in [_build_audio, _build_display, _build_controls, _build_game]:
		var page := VBoxContainer.new()
		page.add_theme_constant_override("separation", 12)
		page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		builder.call(page)
		pages.add_child(page)
		_pages.append(page)
	_build_reset_confirmation()
	show_tab(0)


func show_tab(index: int) -> void:
	for i in _pages.size():
		_pages[i].visible = i == index
		_tab_buttons[i].set_pressed_no_signal(i == index)


func close() -> void:
	settings.save()
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventKey and event.pressed and not event.echo \
			and event.physical_keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		if _confirm.visible:
			_confirm.hide()
		else:
			close()


func _build_audio(page: VBoxContainer) -> void:
	for row: Array in VOLUME_ROWS:
		var key: String = row[0]
		var slider := HSlider.new()
		slider.min_value = 0
		slider.max_value = 100
		slider.step = 5
		slider.value = roundf(float(settings.volumes[key]) * 100.0)
		slider.custom_minimum_size = Vector2(300, 40)
		slider.focus_mode = Control.FOCUS_NONE
		var value := PaperUi.label("%d %%" % slider.value, 20, PaperUi.INK)
		value.custom_minimum_size.x = 70
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		slider.value_changed.connect(func(v: float) -> void:
			value.text = "%d %%" % v
			settings.set_value("volume_" + key, v / 100.0))
		var holder := HBoxContainer.new()
		holder.add_child(slider)
		holder.add_child(value)
		_row(page, row[1], holder)
		controls["volume_" + key] = slider
	var mute := "Ztlumit vše" if DeviceProfile.touch_mode() else "Ztlumit vše (klávesa T)"
	_toggle(page, "muted", mute)


func _build_display(page: VBoxContainer) -> void:
	if not DeviceProfile.touch_mode():
		_toggle(page, "fullscreen", "Celá obrazovka")
	_choices(page, "stop_motion", "Pohyb postav", [true, false], ["Stop-motion", "Plynulý"])
	_choices(page, "ui_scale", "Velikost rozhraní", GameSettings.UI_SCALES,
		["85 %", "100 %", "115 %", "130 %"])
	_choices(page, "quality", "Kvalita efektů",
		[GameSettings.Quality.LOW, GameSettings.Quality.MEDIUM, GameSettings.Quality.HIGH],
		["Nízká", "Střední", "Vysoká"])
	page.add_child(_hint("Nízká vypne zrnitost papíru, světlo, opar, popředí a mraky; "
		+ "šetří výkon slabších telefonů. Hra se hraje stejně."))
	_toggle(page, "minimap", "Minimapa v rohu (klepnutím přesuneš pohled)")
	_toggle(page, "show_fps", "Ukazovat snímky za sekundu (FPS)")


func _build_controls(page: VBoxContainer) -> void:
	if not DeviceProfile.touch_mode():
		_toggle(page, "edge_scroll", "Posun kamery myší u okraje obrazovky")
	_choices(page, "scroll_speed", "Rychlost posunu kamery", GameSettings.SCROLL_SPEEDS,
		["Pomalá", "Běžná", "Rychlá"])
	_choices(page, "tap_reach", "Dosah klepnutí na postavu", GameSettings.TAP_REACHES,
		["Běžný", "Velký"])
	_toggle(page, "confirm_nuke", "Ptát se před „Odpálit vše“")
	if DeviceProfile.touch_mode():
		page.add_child(_hint("Klepni na dovednost a pak na postavu – dokud prst držíš, "
			+ "štítek ukáže, koho zasáhneš. Jedním prstem posouváš krajinu, dvěma přibližuješ. "
			+ "Tlačítko Zpět otevře menu."))
	else:
		page.add_child(_hint("Myš: levé tlačítko přidělí dovednost, pravé nebo prostřední "
			+ "táhne kamerou, kolečko přibližuje. Klávesy: 1–8 dovednosti, mezerník pauza, "
			+ "tečka krok o tik, Backspace −5 s, F rychlost, R znovu, N odpálit vše, T zvuk, "
			+ "M pohyb postav, Esc menu."))


func _build_game(page: VBoxContainer) -> void:
	_toggle(page, "flyover", "Přelet mapy na začátku mise")
	_toggle(page, "unlock_all", "Všechny mise odemčené (vývojová verze)")
	if allow_reset:
		var reset := PaperUi.button("Smazat postup…", Vector2(260, 52))
		reset.pressed.connect(func() -> void: _confirm.show())
		_row(page, "Splněné mise a rekordy", reset)
		controls["reset"] = reset
	page.add_child(_hint("Postup a nastavení se ukládají automaticky. Rozehranou misi "
		+ "nabídne hlavní menu v „Pokračovat“."))


func _row(page: VBoxContainer, caption: String, control: Control) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var text := PaperUi.label(caption, 21, PaperUi.INK)
	text.custom_minimum_size.x = 250
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	row.add_child(control)
	page.add_child(row)


func _toggle(page: VBoxContainer, key: String, caption: String) -> void:
	var button := PaperUi.button("", Vector2(150, 48))
	button.toggle_mode = true
	var refresh := func() -> void:
		button.text = "Zapnuto" if button.button_pressed else "Vypnuto"
	button.set_pressed_no_signal(bool(settings.get(key)))
	refresh.call()
	button.toggled.connect(func(on: bool) -> void:
		refresh.call()
		settings.set_value(key, on))
	_row(page, caption, button)
	controls[key] = button


func _choices(page: VBoxContainer, key: String, caption: String, values: Array,
		names: Array) -> void:
	var holder := HBoxContainer.new()
	holder.add_theme_constant_override("separation", 6)
	var group := ButtonGroup.new()
	var current: Variant = settings.get(key)
	var buttons: Array[Button] = []
	for i in values.size():
		var button := PaperUi.button(names[i], Vector2(112, 48))
		button.add_theme_font_size_override("font_size", 19)
		button.toggle_mode = true
		button.button_group = group
		button.set_pressed_no_signal(_same(values[i], current))
		var value: Variant = values[i]
		button.pressed.connect(func() -> void: settings.set_value(key, value))
		holder.add_child(button)
		buttons.append(button)
	_row(page, caption, holder)
	controls[key] = buttons


func _hint(text: String) -> Label:
	var hint := PaperUi.label(text, 17, PaperUi.INK_DIM)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size.x = 760
	return hint


func _build_reset_confirmation() -> void:
	_confirm = PaperUi.overlay(0.5)
	add_child(_confirm)
	var col := PaperUi.dialog(_confirm, 460.0)
	col.add_child(PaperUi.label("Smazat postup?", 30, PaperUi.INK))
	col.add_child(PaperUi.label("Zapomenou se splněné mise, rekordy\na rozehraná mise. "
		+ "Nastavení zůstane.", 20, PaperUi.INK))
	var keep := PaperUi.button("Ne, ponechat", Vector2(400, 56))
	keep.pressed.connect(func() -> void: _confirm.hide())
	col.add_child(keep)
	var erase := PaperUi.button("Ano, smazat postup", Vector2(400, 56))
	erase.pressed.connect(func() -> void:
		_confirm.hide()
		reset_progress_confirmed.emit())
	col.add_child(erase)
	_confirm.hide()


static func _same(a: Variant, b: Variant) -> bool:
	if (a is float or a is int) and (b is float or b is int):
		return absf(float(a) - float(b)) < 0.001
	return a == b
