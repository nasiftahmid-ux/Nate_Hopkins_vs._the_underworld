extends Node
## Global sound-effect player with per-category calibration and concurrency control.
##
## Usage:
##     Sfx.play("punch")
##     Sfx.play("death_imp", -4.0, randf_range(0.9, 1.1))

const SOUND_DIR := "res://assets/audio/"

## Logical name -> filename inside SOUND_DIR.
const SOUND_FILES := {
	# Player
	"punch": "punch.wav",
	"kick": "kick.wav",
	"uppercut": "uppercut.wav",
	"land": "land.wav",
	"jump": "jump.wav",
	"step": "step.wav",
	# Enemy attacks
	"attack_basic": "attack_basic.wav",
	"attack_slash": "attack_slash.mp3",
	"attack_imp": "attack_imp.wav",
	"attack_shooter": "attack_shooter.wav",
	"attack_knight": "attack_knight.wav",
	"tear_splash": "tear_splash.mp3",
	"platform_move": "platform_move.mp3",
	# Enemy death
	"death_basic": "death_basic.wav",
	"death_imp": "death_imp.wav",
	"death_shooter": "death_shooter.wav",
	"death_knight": "death_knight.wav",
	"death_boss": "death_boss.wav",
	# Boss
	"boss_thud": "boss_thud.mp3",
	"monster_growl": "monster_growl.mp3",
}

## Sound categories for bus routing and mixing
enum Category { COMBAT_CRITICAL, COMBAT_MAJOR, COMBAT_REGULAR, MOVEMENT, ENVIRONMENT, UI, RHYTHM, AMBIENCE }

## Per-sound calibration (db) - replaces blanket boost
## Negative values = quieter, positive = louder
const SOUND_GAIN := {
	# Player combat - critical feedback
	"punch": -2.0,
	"kick": -1.0,
	"uppercut": 0.0,
	# Player movement
	"jump": -6.0,
	"land": -4.0,
	"step": -12.0,
	# Enemy attacks - regular combat
	"attack_basic": -8.0,
	"attack_slash": -8.0,
	"attack_imp": -7.0,
	"attack_shooter": -8.0,
	"attack_knight": -6.0,
	"tear_splash": -6.0,
	"platform_move": -14.0,
	# Enemy deaths
	"death_basic": -6.0,
	"death_imp": -5.0,
	"death_shooter": -5.0,
	"death_knight": -4.0,
	"death_boss": -2.0,
	# Boss - major events
	"boss_thud": -3.0,
	"monster_growl": -10.0,
}

## Category defaults if not specified
const CATEGORY_GAIN := {
	Category.COMBAT_CRITICAL: 0.0,
	Category.COMBAT_MAJOR: -2.0,
	Category.COMBAT_REGULAR: -8.0,
	Category.MOVEMENT: -10.0,
	Category.ENVIRONMENT: -14.0,
	Category.UI: -16.0,
	Category.RHYTHM: -4.0,
	Category.AMBIENCE: -12.0,
}

## Sound to category mapping
const SOUND_CATEGORY := {
	"punch": Category.COMBAT_CRITICAL,
	"kick": Category.COMBAT_CRITICAL,
	"uppercut": Category.COMBAT_CRITICAL,
	"jump": Category.MOVEMENT,
	"land": Category.MOVEMENT,
	"step": Category.MOVEMENT,
	"attack_basic": Category.COMBAT_REGULAR,
	"attack_slash": Category.COMBAT_REGULAR,
	"attack_imp": Category.COMBAT_REGULAR,
	"attack_shooter": Category.COMBAT_REGULAR,
	"attack_knight": Category.COMBAT_REGULAR,
	"tear_splash": Category.COMBAT_REGULAR,
	"platform_move": Category.ENVIRONMENT,
	"death_basic": Category.COMBAT_REGULAR,
	"death_imp": Category.COMBAT_REGULAR,
	"death_shooter": Category.COMBAT_REGULAR,
	"death_knight": Category.COMBAT_REGULAR,
	"death_boss": Category.COMBAT_MAJOR,
	"boss_thud": Category.COMBAT_MAJOR,
	"monster_growl": Category.COMBAT_REGULAR,
}

## Per-sound cooldowns (seconds) to prevent spam
const SOUND_COOLDOWN := {
	"step": 0.08,
	"land": 0.1,
	"monster_growl": 1.5,
}

## Max simultaneous instances per sound
const SOUND_POLYPHONY := {
	"step": 1,
	"land": 2,
}

const POOL_SIZE := 24

var _streams := {}
var _missing := {}
var _pool: Array[AudioStreamPlayer] = []
var _next := 0
var _last_play_time := {}
var _sound_counts := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in range(POOL_SIZE):
		var player := AudioStreamPlayer.new()
		player.bus = &"SFX"
		add_child(player)
		_pool.append(player)


func _get_bus_for_category(cat: int) -> StringName:
	match cat:
		Category.UI, Category.RHYTHM:
			return &"UI"
		Category.AMBIENCE, Category.ENVIRONMENT:
			return &"Ambience"
		_:
			return &"SFX"


## Plays a named sound with optional volume and pitch overrides.
## volume_db is ADDED to calibrated gain (not absolute). pitch varies naturally.
func play(name: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	# Cooldown check
	if SOUND_COOLDOWN.has(name):
		var now := Time.get_ticks_msec() / 1000.0
		var last: float = float(_last_play_time.get(name, -999.0))
		if now - last < SOUND_COOLDOWN[name]:
			return
		_last_play_time[name] = now
	
	# Polyphony check
	if SOUND_POLYPHONY.has(name):
		var count := _count_playing_sound(name)
		if count >= int(SOUND_POLYPHONY[name]):
			return
	
	var stream: AudioStream = _stream(name)
	if stream == null:
		return
	
	var player := _get_available_player(name)
	if player == null:
		return
	
	player.stream = stream
	var cat: int = int(SOUND_CATEGORY.get(name, Category.COMBAT_REGULAR))
	var base_gain: float = float(SOUND_GAIN.get(name, CATEGORY_GAIN[cat]))
	player.volume_db = base_gain + volume_db
	player.pitch_scale = clampf(pitch, 0.5, 2.0)
	player.bus = _get_bus_for_category(cat)
	player.play()


func _get_available_player(name: String) -> AudioStreamPlayer:
	# Try to find a free player
	for i in range(_pool.size()):
		var idx := (_next + i) % _pool.size()
		var player := _pool[idx]
		if not player.playing:
			_next = (idx + 1) % _pool.size()
			return player
	
	# All busy - steal oldest (round robin already gives us oldest)
	var player := _pool[_next]
	_next = (_next + 1) % _pool.size()
	return player


func _count_playing_sound(name: String) -> int:
	var count := 0
	for player in _pool:
		if player.playing and player.stream == _streams.get(name):
			count += 1
	return count


func _stream(name: String) -> AudioStream:
	if _streams.has(name):
		return _streams[name]
	if _missing.has(name):
		return null
	var file: String = SOUND_FILES.get(name, "")
	if file.is_empty():
		if OS.is_debug_build():
			push_warning("[Sfx] Unknown sound name: %s" % name)
		return null
	var path := SOUND_DIR + file
	if not ResourceLoader.exists(path):
		_missing[name] = true
		if OS.is_debug_build():
			push_warning("[Sfx] Missing audio file for '%s' (%s)" % [name, path])
		return null
	var res := load(path)
	if res is AudioStream:
		_streams[name] = res
		return res
	_missing[name] = true
	if OS.is_debug_build():
		push_warning("[Sfx] Invalid audio resource for '%s'" % name)
	return null


func get_sound_info() -> Dictionary:
	var info := {}
	for name in SOUND_FILES.keys():
		var cat: int = int(SOUND_CATEGORY.get(name, Category.COMBAT_REGULAR))
		var cat_name := "COMBAT_REGULAR"
		match cat:
			Category.COMBAT_CRITICAL:
				cat_name = "COMBAT_CRITICAL"
			Category.COMBAT_MAJOR:
				cat_name = "COMBAT_MAJOR"
			Category.COMBAT_REGULAR:
				cat_name = "COMBAT_REGULAR"
			Category.MOVEMENT:
				cat_name = "MOVEMENT"
			Category.ENVIRONMENT:
				cat_name = "ENVIRONMENT"
			Category.UI:
				cat_name = "UI"
			Category.RHYTHM:
				cat_name = "RHYTHM"
			Category.AMBIENCE:
				cat_name = "AMBIENCE"
		info[name] = {
			"category": cat_name,
			"gain_db": float(SOUND_GAIN.get(name, CATEGORY_GAIN[cat])),
			"cooldown": float(SOUND_COOLDOWN.get(name, 0.0)),
			"polyphony": int(SOUND_POLYPHONY.get(name, -1)),
			"bus": str(_get_bus_for_category(cat))
		}
	return info
