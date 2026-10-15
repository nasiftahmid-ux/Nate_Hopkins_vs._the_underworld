extends Node
## Global sound-effect player.
##
## Godot ships no audio assets, so this is just the plumbing: drop files into
## `res://assets/audio/` using the names in `SOUND_FILES` and they play. Any
## sound whose file is missing is skipped silently (and only reported once in a
## debug build), so the game runs with the sound folder empty while the art and
## audio are still being produced.
##
## Usage:
##     Sfx.play("punch")
##     Sfx.play("death_imp", -4.0, randf_range(0.9, 1.1))

const SOUND_DIR := "res://assets/audio/"

## Logical name -> filename inside SOUND_DIR. WAV for short one-shots; OGG is
## fine too, just change the extension here.
const SOUND_FILES := {
	# Player
	"punch": "punch.wav",
	"kick": "kick.wav",
	"uppercut": "uppercut.wav",
	"land": "land.wav",
	# Enemy attacks (one per enemy)
	"attack_basic": "attack_basic.wav",
	"attack_imp": "attack_imp.wav",
	"attack_shooter": "attack_shooter.wav",
	"attack_knight": "attack_knight.wav",
	# Enemy death moans (one per enemy + the boss)
	"death_basic": "death_basic.wav",
	"death_imp": "death_imp.wav",
	"death_shooter": "death_shooter.wav",
	"death_knight": "death_knight.wav",
	"death_boss": "death_boss.wav",
}

## How many sounds can overlap before the oldest slot is recycled. Generous, so
## a burst of hits never cuts itself off.
const POOL_SIZE := 16

var _streams := {}
var _missing := {}
var _pool: Array[AudioStreamPlayer] = []
var _next := 0


func _ready() -> void:
	# Keep playing through the pause and death screens (e.g. a boss death cry
	# while the tree is paused). Playback is cheap enough to always run.
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in range(POOL_SIZE):
		var player := AudioStreamPlayer.new()
		player.bus = &"Master"
		add_child(player)
		_pool.append(player)


## Plays a named sound. `volume_db` and `pitch` are optional tweaks; callers
## vary the pitch slightly for repeated sounds so they do not machine-gun.
func play(name: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	var stream: AudioStream = _stream(name)
	if stream == null:
		return
	var player := _pool[_next]
	_next = (_next + 1) % _pool.size()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch
	player.play()


## Returns the cached stream for a name, or null when the file is absent. A
## missing file is remembered so the disk is only probed once.
func _stream(name: String) -> AudioStream:
	if _streams.has(name):
		return _streams[name]
	if _missing.has(name):
		return null
	var file: String = SOUND_FILES.get(name, "")
	if file.is_empty():
		return null
	var path := SOUND_DIR + file
	if not ResourceLoader.exists(path):
		_missing[name] = true
		if OS.is_debug_build():
			print("[Sfx] no file for '%s' (%s) - skipping" % [name, path])
		return null
	var res := load(path)
	if res is AudioStream:
		_streams[name] = res
		return res
	_missing[name] = true
	return null
