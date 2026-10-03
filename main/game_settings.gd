class_name GameSettings
extends RefCounted
## Nastavení hráče: hlasitosti, zobrazení, ovládání, velikost rozhraní,
## kvalita efektů. Ukládá se přes SaveFile do `user://settings.json`.
##
## Každá hodnota má výchozí stav a povolený rozsah; neznámé nebo poškozené
## položky se nahradí výchozími, takže starší i novější soubor se vždy načte.

signal changed(key: String)

## Kvalita efektů: nízká šetří výkon slabších telefonů.
enum Quality { LOW, MEDIUM, HIGH }

const PATH := "user://settings.json"
## Dřívější soubor (jen ztlumení zvuku) – převezme se při prvním spuštění.
const LEGACY_PATH := "user://settings.cfg"
const FORMAT := 1
const VOLUME_BUSES := {"master": "Master", "sfx": "SFX", "ui": "UI", "ambient": "Ambient",
	"music": "Music"}
const UI_SCALES: Array[float] = [0.85, 1.0, 1.15, 1.3]
const SCROLL_SPEEDS: Array[float] = [0.6, 1.0, 1.6]
## Dosah klepnutí na postavu (px návrhového rozlišení): běžný a velký.
const TAP_REACHES: Array[float] = [42.0, 60.0]

## Kam se ukládá; prázdná cesta = jen v paměti (testy, samostatná scéna hry).
var path := ""
var muted := false
var volumes := {"master": 1.0, "sfx": 1.0, "ui": 1.0, "ambient": 1.0, "music": 1.0}
var fullscreen := false
var stop_motion := true
var show_fps := false
var ui_scale := 1.0
var quality := Quality.HIGH
var edge_scroll := true
var scroll_speed := 1.0
var tap_reach := TAP_REACHES[0]
var confirm_nuke := true
## Vývojová volba: všechny mise jsou hned dostupné.
var unlock_all := false
## Jak dopadlo poslední načtení (SaveFile.Status) – pro testy a ladění.
var load_status := SaveFile.Status.MISSING


func _init() -> void:
	# Telefon: střední kvalita a větší dosah klepnutí jako výchozí.
	if DeviceProfile.touch_mode():
		quality = Quality.MEDIUM
		tap_reach = TAP_REACHES[1]


## Načte nastavení ze souboru (nebo převezme starší soubor, nebo výchozí).
static func load_from(file_path: String) -> GameSettings:
	var settings := GameSettings.new()
	settings.path = file_path
	var result := SaveFile.read(file_path)
	settings.load_status = result["status"]
	if int(result["format"]) > FORMAT:
		# Soubor z novější verze hry: před přepsáním ho odložit vedle.
		SaveFile.keep_copy(file_path, ".v%d" % int(result["format"]))
	if result["status"] in [SaveFile.Status.OK, SaveFile.Status.BACKUP]:
		settings.from_dict(_migrate(result["data"], result["format"]))
	elif result["status"] == SaveFile.Status.MISSING:
		settings._import_legacy(file_path.get_base_dir().path_join(LEGACY_PATH.get_file()))
	return settings


func save() -> Error:
	if path.is_empty():
		return OK
	return SaveFile.write(path, to_dict(), FORMAT)


func to_dict() -> Dictionary:
	return {
		"audio": {"muted": muted, "volumes": volumes.duplicate()},
		"display": {"fullscreen": fullscreen, "stop_motion": stop_motion, "show_fps": show_fps,
			"ui_scale": ui_scale, "quality": int(quality)},
		"controls": {"edge_scroll": edge_scroll, "scroll_speed": scroll_speed,
			"tap_reach": tap_reach, "confirm_nuke": confirm_nuke},
		"game": {"unlock_all": unlock_all},
	}


## Převezme hodnoty ze slovníku; co chybí nebo nedává smysl, zůstane výchozí.
func from_dict(data: Dictionary) -> void:
	var audio := _section(data, "audio")
	muted = _bool(audio, "muted", muted)
	var stored := _section(audio, "volumes")
	for key: String in volumes:
		volumes[key] = clampf(_number(stored, key, volumes[key]), 0.0, 1.0)
	var display := _section(data, "display")
	fullscreen = _bool(display, "fullscreen", fullscreen)
	stop_motion = _bool(display, "stop_motion", stop_motion)
	show_fps = _bool(display, "show_fps", show_fps)
	ui_scale = _choice(_number(display, "ui_scale", ui_scale), UI_SCALES)
	quality = clampi(roundi(_number(display, "quality", quality)), Quality.LOW, Quality.HIGH)
	var controls := _section(data, "controls")
	edge_scroll = _bool(controls, "edge_scroll", edge_scroll)
	scroll_speed = _choice(_number(controls, "scroll_speed", scroll_speed), SCROLL_SPEEDS)
	tap_reach = _choice(_number(controls, "tap_reach", tap_reach), TAP_REACHES)
	confirm_nuke = _bool(controls, "confirm_nuke", confirm_nuke)
	unlock_all = _bool(_section(data, "game"), "unlock_all", unlock_all)


## Změna jedné hodnoty (z obrazovky nastavení); ohlásí ji signálem.
func set_value(key: String, value: Variant) -> void:
	match key:
		"muted": muted = bool(value)
		"fullscreen": fullscreen = bool(value)
		"stop_motion": stop_motion = bool(value)
		"show_fps": show_fps = bool(value)
		"ui_scale": ui_scale = _choice(float(value), UI_SCALES)
		"quality": quality = clampi(int(value), Quality.LOW, Quality.HIGH)
		"edge_scroll": edge_scroll = bool(value)
		"scroll_speed": scroll_speed = _choice(float(value), SCROLL_SPEEDS)
		"tap_reach": tap_reach = _choice(float(value), TAP_REACHES)
		"confirm_nuke": confirm_nuke = bool(value)
		"unlock_all": unlock_all = bool(value)
		_:
			if not key.begins_with("volume_") or not volumes.has(key.trim_prefix("volume_")):
				push_warning("Neznámé nastavení: " + key)
				return
			volumes[key.trim_prefix("volume_")] = clampf(float(value), 0.0, 1.0)
	changed.emit(key)


## Hlasitosti sběrnic a ztlumení (sběrnice založí GameAudio, chybějící vytvoří).
func apply_audio() -> void:
	GameAudio.ensure_buses()
	for key: String in VOLUME_BUSES:
		var bus := AudioServer.get_bus_index(VOLUME_BUSES[key])
		var level: float = volumes[key]
		AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(level, 0.0001)))
		AudioServer.set_bus_mute(bus, level <= 0.0 or (key == "master" and muted))


## Celá obrazovka na počítači; na telefonu je hra vždy přes celý displej.
func apply_window() -> void:
	if DeviceProfile.touch_mode() or DisplayServer.get_name() == "headless":
		return
	var want := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen \
		else DisplayServer.WINDOW_MODE_WINDOWED
	var mode := DisplayServer.window_get_mode()
	var is_full := mode in [DisplayServer.WINDOW_MODE_FULLSCREEN,
		DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]
	if is_full != fullscreen:
		DisplayServer.window_set_mode(want)


## Úpravy dat ze starších verzí formátu (zatím jen verze 1).
static func _migrate(data: Dictionary, _format: int) -> Dictionary:
	return data


func _import_legacy(legacy_path: String) -> void:
	var config := ConfigFile.new()
	if config.load(legacy_path) == OK:
		muted = bool(config.get_value("audio", "muted", false))


static func _section(data: Dictionary, key: String) -> Dictionary:
	var value: Variant = data.get(key)
	return value if value is Dictionary else {}


static func _bool(data: Dictionary, key: String, fallback: bool) -> bool:
	var value: Variant = data.get(key)
	return value if value is bool else fallback


static func _number(data: Dictionary, key: String, fallback: float) -> float:
	var value: Variant = data.get(key)
	if (value is float or value is int) and is_finite(float(value)):
		return float(value)
	return fallback


## Nejbližší povolená hodnota (uložené číslo nemusí přesně sedět).
static func _choice(value: float, allowed: Array[float]) -> float:
	var best := allowed[0]
	for option in allowed:
		if absf(option - value) < absf(best - value):
			best = option
	return best
