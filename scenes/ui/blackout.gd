extends Control
# End-of-stage curtain. A cleared level routes here on its way to Aphrodite's
# shop, and a defeated boss on its way to its cutscene. It blacks out the screen,
# cuts the stage music and plays only the opening of the victory sting, then
# hands off to whatever scene GameState queued for it. Sharing one curtain keeps
# the two endings feeling like the same beat.

const STING_PATH := "res://assets/audio/music/VGMA Challenge 31.ogg"
## How much of the track is used. The sting is a short flourish, not a track.
const STING_SECONDS := 4.0
const STING_VOLUME_DB := -6.0
const FALLBACK_SCENE := "res://scenes/ui/main.tscn"

var _sting: AudioStreamPlayer


func _ready() -> void:
	Music.stop()
	_start_sting()
	await get_tree().create_timer(STING_SECONDS).timeout
	_advance()


func _start_sting() -> void:
	var stream: AudioStream = load(STING_PATH)
	if stream == null:
		return
	# Play the track straight through; it is stopped by the timer below.
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = false
	elif stream is AudioStreamWAV:
		(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_DISABLED
	_sting = AudioStreamPlayer.new()
	_sting.bus = &"Master"
	_sting.volume_db = STING_VOLUME_DB
	_sting.stream = stream
	add_child(_sting)
	_sting.play()


func _advance() -> void:
	if _sting:
		_sting.stop()
	var next: String = GameState.consume_blackout_scene()
	get_tree().change_scene_to_file(next if not next.is_empty() else FALLBACK_SCENE)
