class_name PlayInfo
extends Control
## Drobné informace při hraní: štítek nad lumíkem pod kurzorem nebo prstem
## (co dělá, kam jde, kolik lumíků je v davu a proč mu vybraná dovednost
## nejde dát) a krátká hláška, když přidělení nevyšlo. Vstup nepřijímá.

## Jak dlouho hláška zůstane (s) a jak dlouho mizí.
const NOTICE_SECONDS := 2.4
const NOTICE_FADE := 0.4
const STATE_NAMES := {
	Lemming.State.FALLER: "Padá", Lemming.State.WALKER: "Chodec",
	Lemming.State.SPLATTING: "Splácl se", Lemming.State.EXITING: "Doma",
	Lemming.State.BLOCKER: "Blokař", Lemming.State.BUILDER: "Stavitel",
	Lemming.State.SHRUGGING: "Stavitel bez cihel", Lemming.State.BASHER: "Razič",
	Lemming.State.DIGGER: "Kopáč", Lemming.State.CLIMBER: "Leze",
	Lemming.State.FLOATER: "Snáší se", Lemming.State.MINER: "Horník",
	Lemming.State.DROWNING: "Topí se", Lemming.State.BURNING: "Hoří",
}
const WORK_NAMES := {
	Lemming.State.BUILDER: "staví", Lemming.State.BASHER: "razí",
	Lemming.State.DIGGER: "kope", Lemming.State.MINER: "kope šikmo",
}

var _tag: PanelContainer
var _tag_title: Label
var _tag_reason: Label
var _notice: PanelContainer
var _notice_text: Label
var _notice_left := 0.0


func _init() -> void:
	name = "PlayInfo"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tag = PanelContainer.new()
	_tag.add_theme_stylebox_override("panel", PaperUi.paper("label", 8.0))
	_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_tag)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", -2)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tag.add_child(col)
	_tag_title = PaperUi.label("", 18, PaperUi.INK)
	col.add_child(_tag_title)
	_tag_reason = PaperUi.label("", 15, Color("8a4a2c"))
	col.add_child(_tag_reason)
	_tag.hide()
	_notice = PanelContainer.new()
	_notice.add_theme_stylebox_override("panel", PaperUi.paper("label", 12.0))
	_notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_notice)
	PaperUi.place(_notice, 0.5, 1.0, 0.5, 1.0, -300.0, -Hud.BOTTOM_BAR_HEIGHT - 66.0, 300.0,
		-Hud.BOTTOM_BAR_HEIGHT - 16.0)
	_notice_text = PaperUi.label("", 20, PaperUi.INK)
	_notice_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notice_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_notice.add_child(_notice_text)
	_notice.hide()


## Štítek nad lumíkem: `screen_at` = bod nad hlavou na obrazovce, `crowd` =
## kolik lumíků je v bodě, `reason` = proč mu vybraná dovednost nejde dát.
## Bez lumíka (null) štítek zmizí.
func show_target(lem: Lemming, screen_at: Vector2, crowd: int, reason: String) -> void:
	if lem == null:
		_tag.hide()
		return
	# Rozhraní může být zvětšené: bod obrazovky převést do vlastních souřadnic.
	var at := get_global_transform_with_canvas().affine_inverse() * screen_at
	var text := "%s %s" % [STATE_NAMES.get(lem.state, ""), "→" if lem.dir > 0 else "←"]
	if lem.can_climb:
		text += " · lezec"
	if lem.has_floater:
		text += " · padák"
	if lem.bomb_ticks >= 0:
		text += " · bomba"
	if crowd > 1:
		text += " · %d v davu" % crowd
	if _tag_title.text != text:
		_tag_title.text = text
	_tag_reason.text = reason
	_tag_reason.visible = not reason.is_empty()
	_tag.reset_size()
	var tag_size := _tag.get_combined_minimum_size()
	var limit := size - tag_size
	_tag.position = Vector2(clampf(at.x - tag_size.x * 0.5, 4.0, maxf(limit.x - 4.0, 4.0)),
		clampf(at.y - tag_size.y, Hud.TOP_BAR_HEIGHT, maxf(limit.y, Hud.TOP_BAR_HEIGHT)))
	_tag.show()


func target_visible() -> bool:
	return _tag.visible


## Krátká hláška nad lištou (proč přidělení nevyšlo); po chvíli zmizí.
func show_notice(text: String) -> void:
	if text.is_empty():
		return
	_notice_text.text = text
	_notice_left = NOTICE_SECONDS
	_notice.modulate.a = 1.0
	_notice.show()


func notice_text() -> String:
	return _notice_text.text if _notice.visible else ""


func _process(delta: float) -> void:
	if not _notice.visible:
		return
	_notice_left -= delta
	_notice.modulate.a = clampf(_notice_left / NOTICE_FADE, 0.0, 1.0)
	if _notice_left <= 0.0:
		_notice.hide()


## Text pro hráče: proč lumíkovi nejde dovednost dát (SkillRules.Refusal).
static func refusal_text(refusal: int, skill: int, lem: Lemming) -> String:
	match refusal:
		SkillRules.Refusal.NO_SKILL:
			return "%s: už nezbývá žádný." % Lemming.SKILL_NAMES[skill]
		SkillRules.Refusal.DYING:
			if lem != null and lem.state == Lemming.State.EXITING:
				return "Tenhle lumík už je doma."
			return "Tomuhle lumíkovi už nic nepomůže."
		SkillRules.Refusal.ALREADY:
			match skill:
				Lemming.Skill.CLIMBER:
					return "Tenhle lumík už umí lézt."
				Lemming.Skill.FLOATER:
					return "Tenhle lumík už má padák."
			return "Tenhle lumík už má bombu."
		SkillRules.Refusal.NOT_WORKING:
			if lem != null and lem.state == Lemming.State.BLOCKER:
				return "Blokař se už nehne – dát mu jde jen bomba, lezec nebo padák."
			if lem != null and lem.state == Lemming.State.CLIMBER:
				return "Na stěně jde dát jen padák nebo bomba."
			return "Ve vzduchu jde dát jen lezec, padák nebo bomba."
		SkillRules.Refusal.SAME_WORK:
			return "Tenhle lumík už %s." % WORK_NAMES.get(lem.state if lem != null else -1, "pracuje")
	return ""
