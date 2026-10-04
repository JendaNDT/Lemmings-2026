class_name PaperUi
extends RefCounted
## Společný papírový vzhled rozhraní (HUD, menu, nastavení): téma, panely
## z assets/origami/ui a drobné pomocníky pro stavbu prvků z kódu.

## Papírová paleta z origami mockupu: inkoust na slonovině, petrolejová lišta.
const ACCENT := Color("e9a84e")
const INK := Color("15333a")
const INK_DIM := Color("4d6268")
const TEXT := Color("f4e8d2")
const TEXT_DIM := Color("c9d6cf")
const WARN := Color(1.0, 0.55, 0.45)
const UI_DIR := "res://assets/origami/ui/"
const FONT := preload("res://assets/fonts/Nunito.ttf")

static var _margins := {}
static var _theme: Theme


static func theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	var font := FontVariation.new()
	font.base_font = FONT
	font.variation_opentype = {0x77676874: 750.0}  # OpenType tag „wght“.
	t.default_font = font
	t.default_font_size = 20
	t.set_stylebox("panel", "PanelContainer", paper("toolbar", 12.0))
	t.set_stylebox("normal", "Button", paper("tile", 6.0))
	t.set_stylebox("hover", "Button", paper("tile_hover", 6.0))
	t.set_stylebox("pressed", "Button", paper("tile_selected", 6.0))
	t.set_stylebox("hover_pressed", "Button", paper("tile_selected", 6.0))
	t.set_stylebox("disabled", "Button", paper("tile_disabled", 6.0))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", INK)
	t.set_color("font_hover_color", "Button", INK)
	t.set_color("font_pressed_color", "Button", INK)
	t.set_color("font_hover_pressed_color", "Button", INK)
	t.set_color("font_disabled_color", "Button", Color(INK, 0.45))
	t.set_color("icon_normal_color", "Button", INK)
	t.set_color("icon_hover_color", "Button", INK)
	t.set_color("icon_pressed_color", "Button", INK)
	t.set_color("icon_disabled_color", "Button", Color(INK, 0.45))
	t.set_font_size("font_size", "Button", 22)
	for style in ["normal", "hover", "pressed", "disabled", "focus"]:
		t.set_stylebox(style, "OptionButton", t.get_stylebox(style, "Button"))
	for item in ["font_color", "font_hover_color", "font_pressed_color", "font_disabled_color"]:
		t.set_color(item, "OptionButton", t.get_color(item, "Button"))
	t.set_stylebox("panel", "PopupMenu", paper("dialog", 14.0))
	t.set_stylebox("hover", "PopupMenu", box(Color(ACCENT, 0.6), Color.TRANSPARENT, 6, 4))
	t.set_color("font_color", "PopupMenu", INK)
	t.set_color("font_hover_color", "PopupMenu", INK)
	t.set_color("font_color", "TooltipLabel", INK)
	t.set_stylebox("panel", "TooltipPanel", paper("label", 10.0))
	# Posuvníky hlasitosti: inkoustová dráha a jantarový úchyt.
	var track := box(Color(INK, 0.22), Color.TRANSPARENT, 6, 0)
	track.content_margin_top = 6
	track.content_margin_bottom = 6
	t.set_stylebox("slider", "HSlider", track)
	var fill := box(ACCENT, Color.TRANSPARENT, 6, 0)
	fill.content_margin_top = 6
	fill.content_margin_bottom = 6
	t.set_stylebox("grabber_area", "HSlider", fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", fill)
	t.set_icon("grabber", "HSlider", _grabber(INK))
	t.set_icon("grabber_highlight", "HSlider", _grabber(Color("2a5a62")))
	t.set_stylebox("panel", "ScrollContainer", StyleBoxEmpty.new())
	_theme = t
	return t


## Papírový panel z assets/origami/ui (9 dílů); stín přesahuje mimo plochu prvku.
static func paper(name: String, content: float) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = load(UI_DIR + name + ".png")
	var margin: float = _ui_margins().get(name, 20.0)
	style.set_texture_margin_all(margin)
	style.set_expand_margin_all(12.0)
	style.set_content_margin_all(content)
	return style


static func icon(name: String) -> Texture2D:
	return load(UI_DIR + "icons/%s.svg" % name)


static func place(c: Control, al: float, at: float, ar: float, ab: float,
		ol: float, ot: float, o_r: float, ob: float) -> void:
	c.anchor_left = al
	c.anchor_top = at
	c.anchor_right = ar
	c.anchor_bottom = ab
	c.offset_left = ol
	c.offset_top = ot
	c.offset_right = o_r
	c.offset_bottom = ob


static func label(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func button(text: String, min_size: Vector2, icon_name := "") -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.focus_mode = Control.FOCUS_NONE
	if not icon_name.is_empty():
		b.icon = icon(icon_name)
		b.expand_icon = text.is_empty()
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER if text.is_empty() \
			else HORIZONTAL_ALIGNMENT_LEFT
		if not text.is_empty():
			b.add_theme_constant_override("icon_max_width", 34)
	return b


static func spacer() -> Control:
	var s := Control.new()
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return s


## Tmavé překrytí přes celou plochu se středem pro dialog (pohltí kliknutí).
static func overlay(dim := 0.62) -> Panel:
	var layer := Panel.new()
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_theme_stylebox_override("panel", box(Color(0, 0, 0, dim), Color.TRANSPARENT, 0, 0))
	return layer


## Papírový dialog uprostřed rodiče; vrací sloupec pro obsah.
static func dialog(parent: Control, min_width := 460.0, separation := 14) -> VBoxContainer:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(min_width, 0)
	panel.add_theme_stylebox_override("panel", paper("dialog", 30.0))
	center.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", separation)
	panel.add_child(col)
	return col


static func box(bg: Color, border: Color, radius: int, margin: float) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(2)
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(margin)
	s.anti_aliasing = true
	s.shadow_color = Color(0.02, 0.04, 0.05, 0.18)
	s.shadow_size = 4
	s.shadow_offset = Vector2(0, 2)
	return s


## Řada ikon „plná / prázdná“ – hvězdy hodnocení nebo tečky obtížnosti.
static func icon_row(full: String, empty: String, filled: int, total: int,
		size: float) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(size * 0.12))
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in total:
		var mark := TextureRect.new()
		mark.texture = icon(full if i < filled else empty)
		mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		mark.custom_minimum_size = Vector2(size, size)
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(mark)
	return row


static func stars_row(stars: int, size := 26.0) -> HBoxContainer:
	return icon_row("star", "star_empty", stars, 3, size)


## Tečky pásma obtížnosti (1–5).
static func tier_row(tier: int, size := 14.0) -> HBoxContainer:
	return icon_row("dot", "dot_empty", tier, LevelDifficulty.TIERS.size(), size)


## Herní čas jako m:ss z počtu tiků.
static func format_ticks(ticks: int) -> String:
	var secs := ticks / SimConst.TICKS_PER_SECOND
	return "%d:%02d" % [secs / 60, secs % 60]


static func _grabber(color: Color) -> ImageTexture:
	var size := 26
	var image := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(size, size) * 0.5 - Vector2(0.5, 0.5)
	for y in size:
		for x in size:
			# Inkoustový terčík se světlým papírovým okrajem.
			var d := Vector2(x, y).distance_to(center)
			var a := clampf(size * 0.5 - 1.0 - d, 0.0, 1.0)
			var rim := clampf(d - (size * 0.5 - 5.0), 0.0, 1.0)
			image.set_pixel(x, y, Color(color.lerp(TEXT, rim), a))
	return ImageTexture.create_from_image(image)


static func _ui_margins() -> Dictionary:
	if _margins.is_empty():
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(UI_DIR + "ui.json"))
		for key in data:
			_margins[key] = float(data[key]["margin"])
	return _margins
