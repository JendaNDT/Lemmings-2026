class_name BriefingCard
extends Panel
## Úvodní karta mise: cíl, dovednosti s popisem (i na telefonu), novinka,
## pásmo obtížnosti a hvězdy. Hra stojí, dokud hráč neklepne „Hrát“.

signal closed

var _col: VBoxContainer


func _init() -> void:
	name = "Briefing"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_theme_stylebox_override("panel", PaperUi.box(Color(0, 0, 0, 0.45), Color.TRANSPARENT, 0, 0))
	_col = PaperUi.dialog(self, 640.0, 10)
	hide()


## Úvodní karta mise: cíl, dovednosti s popisem, novinka, obtížnost, hvězdy.
## `data`: title, chapter, tier, goal, introduces, briefing, skills
## ([[dovednost, kusy]…]), stars, thresholds.
func open(data: Dictionary) -> void:
	for child in _col.get_children():
		child.free()
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	_col.add_child(head)
	head.add_child(PaperUi.label(data.get("title", ""), 32, PaperUi.INK))
	head.add_child(PaperUi.spacer())
	var tier: int = data.get("tier", 0)
	if tier > 0:
		var tier_box := VBoxContainer.new()
		tier_box.alignment = BoxContainer.ALIGNMENT_CENTER
		tier_box.add_child(PaperUi.tier_row(tier, 16.0))
		var tier_name := PaperUi.label(LevelDifficulty.tier_name(tier), 17, PaperUi.INK_DIM)
		tier_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tier_box.add_child(tier_name)
		head.add_child(tier_box)
	var chapter: String = data.get("chapter", "")
	if not chapter.is_empty():
		_col.add_child(PaperUi.label(chapter, 18, PaperUi.INK_DIM))
	var introduces: String = data.get("introduces", "")
	if not introduces.is_empty():
		var badge := PanelContainer.new()
		badge.add_theme_stylebox_override("panel", PaperUi.box(PaperUi.ACCENT, Color.TRANSPARENT, 8, 6))
		badge.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		badge.add_child(PaperUi.label("Nové: " + introduces, 19, PaperUi.INK))
		_col.add_child(badge)
	var text: String = data.get("briefing", "")
	if not text.is_empty():
		var intro := PaperUi.label(text, 20, PaperUi.INK)
		intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		intro.custom_minimum_size.x = 600
		_col.add_child(intro)
	_col.add_child(PaperUi.label(data.get("goal", ""), 22, PaperUi.INK))
	var skills := GridContainer.new()
	skills.columns = 2
	skills.add_theme_constant_override("h_separation", 18)
	skills.add_theme_constant_override("v_separation", 6)
	_col.add_child(skills)
	for item: Array in data.get("skills", []):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var icon := TextureRect.new()
		icon.texture = PaperUi.icon(Hud.SKILL_ICONS[item[0]])
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(34, 34)
		row.add_child(icon)
		var words := VBoxContainer.new()
		words.add_theme_constant_override("separation", -4)
		var caption := "%s × %d" % [Lemming.SKILL_NAMES[item[0]], item[1]]
		words.add_child(PaperUi.label(caption, 18, PaperUi.INK))
		var tip := PaperUi.label(Hud.SKILL_TIPS[item[0]], 16, PaperUi.INK_DIM)
		tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tip.custom_minimum_size.x = 250
		words.add_child(tip)
		row.add_child(words)
		skills.add_child(row)
	var thresholds: Array = data.get("thresholds", [])
	if thresholds.size() == 3:
		var stars_row := HBoxContainer.new()
		stars_row.add_theme_constant_override("separation", 10)
		stars_row.add_child(PaperUi.stars_row(int(data.get("stars", 0)), 24.0))
		stars_row.add_child(PaperUi.label("Hvězdy za %d / %d / %d zachráněných" % thresholds,
			17, PaperUi.INK_DIM))
		_col.add_child(stars_row)
	var play := PaperUi.button("Hrát", Vector2(0, 60), "play")
	play.pressed.connect(close)
	_col.add_child(play)
	show()


func close() -> void:
	if visible:
		hide()
		closed.emit()
