class_name GameAudio
extends Node2D
## Zvuky hry: události simulace → papírové efekty, okolní smyčky a rozhraní.
##
## Simulaci jen čte (události, tik, stav odpočtu, masku). Zvuky v prostoru
## stojí na místě události na obrazovce: vlevo/vpravo podle polohy, mimo záběr
## tišší. Náhodná výška tónu je místní a výsledek hry neovlivní. Hudba má
## vlastní GameMusic a sběrnici Music. Hlasitost a ztlumení
## řídí GameSettings (ukládá je), tento uzel jen přehrává.

const DATA_PATH := "res://assets/audio/sfx.json"
const AUDIO_DIR := "res://assets/audio/"
const BUSES := ["SFX", "UI", "Ambient", "Music"]
## Událost simulace → zvuk (všechny typy událostí, které simulace hlásí).
const EVENT_SOUNDS := {
	"assign": "assign", "spawn": "spawn", "dig": "dig", "bash": "bash", "mine": "mine",
	"brick": "brick", "brick_warning": "brick_warning", "steel": "steel", "splat": "splat",
	"exit": "exit", "explode": "explode", "fell_out": "fell_out", "drown": "drown",
	"drowned": "drowned", "burn": "burn", "burned": "burned", "trap": "trap",
}
## Kolik zvuků smí začít během jednoho snímku (zrychlení, hromadné odpálení).
const MAX_PER_FRAME := 6
## Dosah zvuku v prostoru (px obrazovky): dál už není slyšet.
const MAX_DISTANCE := 2200.0

## Bez obrazovky (automatické testy) se zvuky jen zaznamenají, nepřehrávají:
## mixér by po rychlém ukončení testu držel rozehrané zvuky v paměti.
var silent := DisplayServer.get_name() == "headless"
## Převod logických souřadnic do prostoru, ve kterém poslouchá obrazovka.
var to_screen: Callable
## Jména zvuků spuštěných od začátku levelu (pro testy a ladění).
var played: Array[String] = []
var _sounds := {}
var _loops := {}
var _loop_spots := {}
var _sim: LevelSim
var _rng := RandomNumberGenerator.new()
var _hatch_played := false
var _was_nuking := false
var _started_this_frame := 0
## Čas pro odstupy mezi stejnými zvuky (s): skutečný čas snímků, ne simulace.
var _clock := 0.0


func _ready() -> void:
	ensure_buses()
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	for name: String in data["sounds"]:
		var cfg: Dictionary = data["sounds"][name]
		var streams: Array[AudioStream] = []
		for path: String in cfg["files"]:
			streams.append(load(AUDIO_DIR + path))
		var players: Array[Node] = []
		for i in int(cfg["voices"]):
			var player: Node
			if cfg["positional"]:
				var spatial := AudioStreamPlayer2D.new()
				spatial.max_distance = MAX_DISTANCE
				spatial.volume_db = float(cfg["volume_db"])
				spatial.bus = cfg["bus"]
				player = spatial
			else:
				var flat := AudioStreamPlayer.new()
				flat.volume_db = float(cfg["volume_db"])
				flat.bus = cfg["bus"]
				player = flat
			player.name = "%s_%d" % [name, i]
			add_child(player)
			players.append(player)
		_sounds[name] = {"streams": streams, "players": players, "next": 0, "last": -100.0,
			"pitch": float(cfg["pitch_spread"]), "gap": float(cfg["min_interval"]),
			"positional": bool(cfg["positional"])}
	for name: String in data["loops"]:
		var cfg: Dictionary = data["loops"][name]
		var stream := load(AUDIO_DIR + cfg["file"]) as AudioStreamWAV
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = stream.data.size() / 2
		var player: Node
		if name == "wind":
			var flat := AudioStreamPlayer.new()
			flat.stream = stream
			flat.volume_db = float(cfg["volume_db"])
			flat.bus = cfg["bus"]
			player = flat
		else:
			var spatial := AudioStreamPlayer2D.new()
			spatial.stream = stream
			spatial.volume_db = float(cfg["volume_db"])
			spatial.bus = cfg["bus"]
			spatial.max_distance = MAX_DISTANCE
			player = spatial
		player.name = "loop_" + name
		add_child(player)
		_loops[name] = player


## Nový level: vynuluje stav, najde vodu a lávu pro jejich smyčky, pustí vítr.
func setup(sim: LevelSim, converter: Callable) -> void:
	_sim = sim
	to_screen = converter
	played.clear()
	_hatch_played = false
	_was_nuking = false
	for child in get_children():
		child.call("stop")
	_loop_spots = _liquid_centers(sim.mask)
	if not silent:
		(_loops["wind"] as AudioStreamPlayer).play()
	for kind: String in ["water", "lava"]:
		if _loop_spots.has(kind):
			var player := _loops[kind] as AudioStreamPlayer2D
			player.position = _screen(_loop_spots[kind])
			if not silent:
				player.play()


## Zvuky k událostem simulace z tohoto snímku a průběžné stavy (dvířka, odpočet).
## `delta` je délka snímku v sekundách (pro odstupy mezi stejnými zvuky).
func update(events: Array[Dictionary], delta := 0.0) -> void:
	_started_this_frame = 0
	_clock += delta
	if _sim == null:
		return
	if not _hatch_played and _sim.tick_count >= SimConst.HATCH_OPEN_TICKS - 14 \
			and not _sim.spec.hatches.is_empty():
		_hatch_played = true
		play("hatch", Vector2(_sim.spec.hatches[0]) + Vector2(0, -6))
	if _sim.nuking and not _was_nuking:
		play("nuke")
	_was_nuking = _sim.nuking
	for event in events:
		var sound: String = EVENT_SOUNDS.get(event["type"], "")
		if sound != "":
			play(sound, Vector2(float(event["x"]) + 0.5, float(event["y"]) - 4.0))
	for kind: String in _loop_spots:
		(_loops[kind] as AudioStreamPlayer2D).position = _screen(_loop_spots[kind])


## Spustí zvuk; `at` je místo v logických souřadnicích (u zvuků v prostoru).
## Vrací false, když ho omezení odstupu nebo počtu za snímek přeskočí.
func play(sound: String, at := Vector2.INF) -> bool:
	if not _sounds.has(sound):
		push_warning("Neznámý zvuk: " + sound)
		return false
	var entry: Dictionary = _sounds[sound]
	if _clock - float(entry["last"]) < float(entry["gap"]) or _started_this_frame >= MAX_PER_FRAME:
		return false
	entry["last"] = _clock
	_started_this_frame += 1
	var players: Array = entry["players"]
	var player = players[int(entry["next"])]
	entry["next"] = (int(entry["next"]) + 1) % players.size()
	var streams: Array = entry["streams"]
	player.stream = streams[_rng.randi() % streams.size()]
	var spread := float(entry["pitch"])
	player.pitch_scale = 1.0 + _rng.randf_range(-spread, spread)
	if entry["positional"]:
		(player as AudioStreamPlayer2D).position = _screen(at)
	if not silent:
		player.play()
	played.append(sound)
	return true


## Zvuk rozhraní (stejné jako play bez místa).
func play_ui(sound: String) -> void:
	play(sound)


func _exit_tree() -> void:
	# Zastavit přehrávání, ať po zavření scény nezůstanou zvuky v mixéru.
	for child in get_children():
		child.call("stop")


func _screen(at: Vector2) -> Vector2:
	if at == Vector2.INF or not to_screen.is_valid():
		return get_viewport_rect().size * 0.5
	return to_screen.call(at)


## Sběrnice efektů, rozhraní, okolí a (budoucí) hudby, všechny do Master.
## Na Master je omezovač špiček, aby souběh mnoha zvuků nepraskal.
## Hlasitosti a ztlumení nastavuje GameSettings.apply_audio().
static func ensure_buses() -> void:
	var master := AudioServer.get_bus_index("Master")
	var has_limiter := false
	for i in AudioServer.get_bus_effect_count(master):
		has_limiter = has_limiter or AudioServer.get_bus_effect(master, i) is AudioEffectHardLimiter
	if not has_limiter:
		var limiter := AudioEffectHardLimiter.new()
		limiter.ceiling_db = -0.5
		AudioServer.add_bus_effect(master, limiter)
	for bus: String in BUSES:
		if AudioServer.get_bus_index(bus) >= 0:
			continue
		AudioServer.add_bus()
		var index := AudioServer.bus_count - 1
		AudioServer.set_bus_name(index, bus)
		AudioServer.set_bus_send(index, "Master")


## Těžiště vody a lávy v levelu (logické px) – odtud zní jejich smyčka.
static func _liquid_centers(mask: TerrainMask) -> Dictionary:
	var sums := {}
	var data := mask.data
	var bpp := TerrainMask.BYTES_PER_PIXEL
	for i in mask.width * mask.height:
		var kind := data[i * bpp + 3]
		if kind == TerrainMask.Special.NONE or kind > TerrainMask.Special.LAVA or data[i * bpp] != 0:
			continue
		var key := "water" if kind == TerrainMask.Special.WATER else "lava"
		var acc: Vector3 = sums.get(key, Vector3.ZERO)
		sums[key] = acc + Vector3(i % mask.width, i / mask.width, 1)
	var out := {}
	for key: String in sums:
		var acc: Vector3 = sums[key]
		out[key] = Vector2(acc.x / acc.z, acc.y / acc.z)
	return out
