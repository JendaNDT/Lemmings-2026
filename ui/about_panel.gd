class_name AboutPanel
extends Control
## Obrazovka „O hře“ z hlavního menu: titulky a verze s tlačítkem „Nahlásit
## chybu“ (BugReport), návod „Jak hrát“ a licence (hra, Godot Engine a jeho
## součásti, písmo Nunito). Plné texty licencí součástí se ukazují po jedné.

signal closed

const TABS := ["O hře", "Jak hrát", "Licence"]
const AUTHOR := "Jenda"
const OFL_PATH := "res://assets/fonts/OFL.txt"
const MUSIC_TERMS_PATH := "res://assets/music/LICENSE.txt"
const TEXT_WIDTH := 780.0

var settings: GameSettings
var progress: Progress
## false = hlášení jen připraví text (testy), bez schránky a prohlížeče.
var open_browser := true
var last_report := ""
var _tab_buttons: Array[Button] = []
var _pages: Array[Control] = []
var _license_title: Label
var _license_text: Label
var _report_note: Label


func _init(game_settings: GameSettings, player_progress: Progress) -> void:
	settings = game_settings
	progress = player_progress
	name = "About"
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
	head.add_child(PaperUi.label("Paperlings %s" % BugReport.version(), 32, PaperUi.INK))
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
	for builder: Callable in [_build_about, _build_guide, _build_licenses]:
		var page := VBoxContainer.new()
		page.add_theme_constant_override("separation", 10)
		page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		builder.call(page)
		pages.add_child(page)
		_pages.append(page)
	show_tab(0)


func show_tab(index: int) -> void:
	for i in _pages.size():
		_pages[i].visible = i == index
		_tab_buttons[i].set_pressed_no_signal(i == index)


func close() -> void:
	closed.emit()


## Údaje o zařízení do schránky a formulář hlášení v prohlížeči.
func report_bug() -> String:
	var extra := {
		"Kvalita efektů": ["nízká", "střední", "vysoká"][clampi(int(settings.quality), 0, 2)],
		"Velikost rozhraní": "%d %%" % roundi(settings.ui_scale * 100.0),
		"Poslední mise": progress.last_mission if not progress.last_mission.is_empty() else "–",
		"Splněných misí": "%d z %d" % [progress.completed_count(), Campaign.count()],
	}
	last_report = BugReport.send(extra) if open_browser else BugReport.diagnostics(extra)
	_report_note.text = ("Údaje o zařízení jsou ve schránce i ve formuláři, který se otevřel "
		+ "v prohlížeči. K odeslání potřebuješ účet na GitHubu – nebo údaje pošli autorovi "
		+ "jinak (třeba e-mailem) spolu s popisem chyby.")
	_report_note.show()
	return last_report


## Plný text jedné licence součásti Godotu (klíč z Engine.get_license_info()).
func show_license(key: String) -> void:
	var texts := Engine.get_license_info()
	_license_title.text = key
	_license_text.text = str(texts.get(key, ""))
	_license_title.show()
	_license_text.show()


## Titulky (i pro README vydání).
static func credits() -> String:
	return ("Nápad, zadání a vedení: %s\n" % AUTHOR
		+ "Programování, grafika a zvuky: vytvořeno s AI asistentem Claude (Anthropic) "
		+ "podle zadání autora – vibecoding\n"
		+ "Engine: Godot Engine (godotengine.org), licence MIT\n"
		+ "Písmo: Nunito – The Nunito Project Authors, SIL Open Font License 1.1\n"
		+ "Grafika a zvukové efekty vznikly skripty projektu. "
		+ "Čtyři hudební skladby dodal Jenda pro tuto hru.")


## Licence samotné hry (rozhodnutí autora: volně ke hraní, ostatní práva vyhrazena).
static func license_summary() -> String:
	return ("Paperlings © 2026 %s. Hru můžeš zdarma stahovat, hrát a sdílet odkaz na ni. " % AUTHOR
		+ "Všechna ostatní práva vyhrazena: kód, grafiku, zvuky ani mise nelze bez svolení "
		+ "autora použít v jiných dílech. Práva k dodaným hudebním nahrávkám zůstávají "
		+ "jejich držitelům. Hra je poskytovaná tak, jak je, bez záruky.")


## Seznam součástí Godot Engine s autory a licencemi (Engine.get_copyright_info()).
static func components_text() -> String:
	var lines: Array[String] = []
	for component: Dictionary in Engine.get_copyright_info():
		for part: Dictionary in component["parts"]:
			lines.append("%s – © %s (%s)" % [component["name"],
				"; ".join(PackedStringArray(part["copyright"])), part["license"]])
	return "\n".join(lines)


## Návod: [nadpis, text] po oddílech.
static func guide() -> Array:
	var skills: Array[String] = []
	for skill: int in Lemming.SKILL_ORDER:
		skills.append("%s – %s" % [Lemming.SKILL_NAMES[skill], Hud.SKILL_TIPS[skill]])
	return [
		["Cíl", "Z líhně vycházejí postavičky a slepě kráčí vpřed. Přiděluj jim dovednosti "
			+ "tak, aby jich do východu došlo aspoň tolik, kolik mise žádá. Za víc "
			+ "zachráněných dostaneš víc hvězd (až tři). Každá dovednost má omezený počet kusů."],
		["Ovládání na počítači", SettingsPanel.MOUSE_HINT],
		["Ovládání na telefonu a tabletu", SettingsPanel.TOUCH_HINT],
		["Dovednosti", "\n".join(skills)],
		["Pomocníci", "−5 s vrátí hru o pět sekund. V pauze posune Krok hru o jeden tik, "
			+ "rychlost přepíná 1× → 3× → ½×. Pauza (Menu) má nápovědu k misi a Ukázku řešení. "
			+ "Rychlost vypouštění měníš tlačítky − a +. Odpálit vše ukončí marný pokus."],
		["Tipy", "Pád z velké výšky postavičku zabije – padák ji ochrání. Blokař se už "
			+ "nehne, uvolní ho jen bomba. Ocel nejde prokopat ani vyhodit. Voda a láva "
			+ "jsou smrtelné, pasti chytí jednu postavičku po druhé. Když dovednost nejde dát, "
			+ "hláška nad lištou řekne proč."],
		["Hudba", "Čtyři skladby se střídají po misích a v každé misi se opakují. "
			+ "Hlasitost změníš v Nastavení → Zvuk → Hudba. Pauza, rychlost ani −5 s "
			+ "hudbu neposouvají; na pozadí telefonu se pozastaví."],
		["Známá omezení", "Hra je nová – když narazíš na chybu, nahlas ji "
			+ "v záložce O hře. Postup se ukládá v zařízení a přenese se při aktualizaci."],
	]


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventKey and event.pressed and not event.echo \
			and event.physical_keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		close()


func _build_about(page: VBoxContainer) -> void:
	_text(page, "Papírová logická hra: proveď zástup origami postaviček nástrahami "
		+ "k východu. 24 misí ve čtyřech kapitolách a Hřiště.", 20, PaperUi.INK)
	_heading(page, "Titulky")
	_text(page, credits())
	_heading(page, "Inspirace")
	_text(page, "Inspirováno klasickou hrou Lemmings (1991, DMA Design). Paperlings s ní ani "
		+ "s jejími vlastníky není nijak spojená a nepoužívá z ní žádné obrázky, zvuky, "
		+ "písma ani mise.")
	_heading(page, "Našel jsi chybu?")
	var report := PaperUi.button("Nahlásit chybu", Vector2(240, 52))
	report.pressed.connect(func() -> void: report_bug())
	page.add_child(report)
	_report_note = _text(page, "")
	_report_note.hide()


func _build_guide(page: VBoxContainer) -> void:
	for section: Array in guide():
		_heading(page, section[0])
		_text(page, section[1])


func _build_licenses(page: VBoxContainer) -> void:
	_heading(page, "Paperlings")
	_text(page, license_summary())
	_heading(page, "Godot Engine (licence MIT)")
	_text(page, Engine.get_license_text())
	_heading(page, "Písmo Nunito (SIL Open Font License 1.1)")
	_text(page, FileAccess.get_file_as_string(OFL_PATH).strip_edges())
	_heading(page, "Hudební nahrávky dodané pro hru")
	_text(page, FileAccess.get_file_as_string(MUSIC_TERMS_PATH).strip_edges())
	_heading(page, "Součásti Godot Engine")
	_text(page, components_text(), 15)
	_heading(page, "Plné texty licencí součástí")
	var flow := HFlowContainer.new()
	flow.custom_minimum_size.x = TEXT_WIDTH
	flow.add_theme_constant_override("h_separation", 6)
	flow.add_theme_constant_override("v_separation", 6)
	var keys := Engine.get_license_info().keys()
	keys.sort()
	for key: String in keys:
		var button := PaperUi.button(key, Vector2(0, 40))
		button.add_theme_font_size_override("font_size", 15)
		button.pressed.connect(show_license.bind(key))
		flow.add_child(button)
	page.add_child(flow)
	_license_title = _heading(page, "")
	_license_text = _text(page, "", 15)
	_license_title.hide()
	_license_text.hide()


func _heading(page: VBoxContainer, text: String) -> Label:
	var label := PaperUi.label(text, 22, PaperUi.INK)
	page.add_child(label)
	return label


func _text(page: VBoxContainer, text: String, font_size := 17,
		color := PaperUi.INK_DIM) -> Label:
	var label := PaperUi.label(text, font_size, color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = TEXT_WIDTH
	page.add_child(label)
	return label
