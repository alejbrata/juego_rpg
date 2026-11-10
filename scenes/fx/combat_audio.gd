class_name CombatAudio
extends Node
## Iteration 1.7: combat sound effects. A small pool of players (no unbounded
## overlap on phones), light pitch variation so repeated hits do not sound
## identical, and a log of what was played for tests/diagnostics.
## Sounds are original, synthesised by tools/audio/make_combat_sfx.py.

const DIR := "res://assets/audio/sfx/"
const VOICES := 6
## Per-sound mix level (dB) and pitch jitter; anything not listed plays at 0 dB.
const MIX := {
	"swing": [-4.0, 0.06], "enemy_swing": [-3.0, 0.04],
	"hit": [-2.0, 0.07], "hit_heavy": [0.0, 0.04], "hit_hero": [-2.0, 0.07],
	"fire_cast": [-4.0, 0.03], "fire_impact": [-1.0, 0.03],
	"ice_cast": [-5.0, 0.03], "ice_impact": [-2.0, 0.03],
	"heal": [-4.0, 0.0], "protect": [-4.0, 0.0], "haste": [-4.0, 0.02], "guard": [-4.0, 0.04],
	"knockout": [-2.0, 0.0], "summon": [0.0, 0.0], "resonance_ready": [-5.0, 0.0],
	"ui_select": [-8.0, 0.03], "ui_confirm": [-6.0, 0.0], "ui_cancel": [-6.0, 0.0],
}

static var _cache := {}
var played: Array[String] = []   # names, newest last (bounded)
var _players: Array[AudioStreamPlayer] = []
var _next := 0

func _ready() -> void:
	for i in VOICES:
		var player := AudioStreamPlayer.new()
		player.name = "Voice%d" % i
		add_child(player)
		_players.append(player)

static func stream(sound: String) -> AudioStream:
	if not _cache.has(sound):
		var path := DIR + sound + ".wav"
		_cache[sound] = load(path) if ResourceLoader.exists(path) else null
	return _cache[sound]

## Plays `sound` now. Returns false if the file is missing (never errors).
func play(sound: String, volume_offset_db: float = 0.0) -> bool:
	var data := stream(sound)
	if data == null or _players.is_empty():
		return false
	var settings: Array = MIX.get(sound, [0.0, 0.0])
	# Prefer an idle voice; otherwise steal the oldest one.
	var player: AudioStreamPlayer = null
	for i in VOICES:
		var candidate := _players[(_next + i) % VOICES]
		if not candidate.playing:
			player = candidate
			break
	if player == null:
		player = _players[_next % VOICES]
	_next = (_players.find(player) + 1) % VOICES
	player.stream = data
	player.volume_db = float(settings[0]) + volume_offset_db
	player.pitch_scale = 1.0 + randf_range(-1.0, 1.0) * float(settings[1])
	player.play()
	played.append(sound)
	if played.size() > 64:
		played.remove_at(0)
	return true

## Plays after `delay` seconds unless `still_valid` (if given) returns false then.
func play_later(sound: String, delay: float, still_valid: Callable = Callable()) -> void:
	if delay <= 0.0:
		play(sound)
		return
	await get_tree().create_timer(delay).timeout
	if not still_valid.is_valid() or still_valid.call():
		play(sound)

func stop_all() -> void:
	for player in _players:
		player.stop()

func active_voices() -> int:
	var count := 0
	for player in _players:
		if player.playing:
			count += 1
	return count
