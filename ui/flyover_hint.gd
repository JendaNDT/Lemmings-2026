class_name FlyoverHint
extends Control
## Vrstva přeletu mapy: průhledná přes celou obrazovku, zachytí první klepnutí
## (přelet přeskočí a nic nepřidělí) a štítek nad lištou řekne, jak hned hrát.

signal skipped


func _init() -> void:
	name = "Flyover"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var tab := PanelContainer.new()
	tab.add_theme_stylebox_override("panel", PaperUi.paper("label", 12.0))
	tab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tab)
	PaperUi.place(tab, 0.5, 1.0, 0.5, 1.0, -260.0, -Hud.BOTTOM_BAR_HEIGHT - 66.0, 260.0,
		-Hud.BOTTOM_BAR_HEIGHT - 16.0)
	var text := "Přelet mapy · klepni a hraj" if DeviceProfile.touch_mode() \
		else "Přelet mapy · klikni nebo stiskni klávesu a hraj"
	var caption := PaperUi.label(text, 21, PaperUi.INK)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tab.add_child(caption)
	hide()


func _gui_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton or event is InputEventScreenTouch) and event.is_pressed():
		skipped.emit()
