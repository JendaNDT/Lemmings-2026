class_name GameMusic
extends Node
## Jedna skladba pro každou misi, čtyři skladby cyklicky podle pořadí kampaně.
## Dva přehrávače střídají skladby i jejich opakování s krátkým prolínáním.
## Hudba používá skutečný čas zvuku; rychlost, pauza a přetáčení simulace
## ji neposouvají. Na pozadí mobilní aplikace se pozastaví oba přehrávače.

signal track_started(slot: int)

const TRACKS: Array[String] = [
	"res://assets/music/track_01.ogg",
	"res://assets/music/track_02.ogg",
	"res://assets/music/track_03.ogg",
	"res://assets/music/track_04.ogg",
]
const CHANGE_FADE := 0.7
const LOOP_FADE := 1.2
const GAIN_DB := -3.0
const SILENCE_DB := -80.0

## Právě zvolená skladba; −1 = návrat do menu / žádná hudba.
var current_slot := -1
# Stejně jako GameAudio: headless testy nemají zvukový mixér, který by
# uvolňoval zastavené streamy. Skutečný mix se ověřuje grafickým QA během.
var silent := DisplayServer.get_name() == "headless"
var _players: Array[AudioStreamPlayer] = []
var _active := 0
var _weights := [0.0, 0.0]
var _from := [0.0, 0.0]
var _to := [0.0, 0.0]
var _fade_time := 0.0
var _fade_length := 0.0
var _suspended := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameAudio.ensure_buses()
	for i in 2:
		var player := AudioStreamPlayer.new()
		player.name = "Voice%d" % i
		player.bus = "Music"
		player.volume_db = SILENCE_DB
		player.finished.connect(_on_finished.bind(i))
		add_child(player)
		_players.append(player)


func _exit_tree() -> void:
	for player in _players:
		player.stop()
		player.stream = null
	_players.clear()


static func slot_for_mission(mission_id: String) -> int:
	# Hřiště a scény mimo kampaň používají první skladbu.
	return maxi(0, Campaign.index_of(mission_id)) % TRACKS.size()


func play_mission(mission_id: String) -> void:
	var slot := slot_for_mission(mission_id)
	if current_slot == slot and (silent or _players[_active].playing):
		# Restart nebo ukázka stejné mise: hudba pokračuje bez skoku.
		return
	current_slot = slot
	if silent:
		track_started.emit(slot)
		return
	_start_slot(slot, CHANGE_FADE)


func stop_music() -> void:
	current_slot = -1
	_begin_fade([0.0, 0.0], CHANGE_FADE)


func _start_slot(slot: int, fade_length: float) -> void:
	var stream := load(TRACKS[slot]) as AudioStreamOggVorbis
	if stream == null:
		push_error("Nelze načíst hudbu: %s" % TRACKS[slot])
		return
	# Opakování obstarává překryv dvou hlasů, nikoli tvrdá smyčka importéru.
	stream.loop = false
	_active = 1 - _active
	var player := _players[_active]
	player.stop()
	_weights[_active] = 0.0
	player.volume_db = SILENCE_DB
	player.stream = stream
	player.pitch_scale = 1.0
	player.play()
	player.stream_paused = _suspended
	var target := [0.0, 0.0]
	target[_active] = 1.0
	_begin_fade(target, fade_length)
	track_started.emit(slot)


func _begin_fade(target: Array, duration: float) -> void:
	_from = _weights.duplicate()
	_to = target
	_fade_time = 0.0
	_fade_length = duration


func _process(delta: float) -> void:
	if _suspended or _players.is_empty():
		return
	if _fade_length > 0.0:
		_fade_time += delta
		var t := clampf(_fade_time / _fade_length, 0.0, 1.0)
		var smooth := t * t * (3.0 - 2.0 * t)
		for i in 2:
			_weights[i] = lerpf(_from[i], _to[i], smooth)
			_players[i].volume_db = GAIN_DB + linear_to_db(maxf(_weights[i], 0.0001))
		if t >= 1.0:
			_fade_length = 0.0
			for i in 2:
				if _to[i] == 0.0:
					_players[i].stop()
					_players[i].stream = null
	if current_slot < 0 or _fade_length > 0.0:
		return
	var player := _players[_active]
	if player.playing and player.stream != null:
		var remaining := player.stream.get_length() - player.get_playback_position()
		if remaining <= LOOP_FADE:
			_start_slot(current_slot, minf(LOOP_FADE, maxf(remaining, 0.05)))


func _on_finished(index: int) -> void:
	# Záchrana při dlouhém snímku: na konci se hudba nikdy natrvalo nezastaví.
	if index == _active and current_slot >= 0 and not _suspended:
		_start_slot(current_slot, CHANGE_FADE)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED:
		_suspend(true)
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		_suspend(false)


func _suspend(value: bool) -> void:
	_suspended = value
	for player in _players:
		player.stream_paused = value
