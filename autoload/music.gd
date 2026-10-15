extends Node

## Background music manager. As an autoload it survives `change_scene_to_file`,
## so a track keeps playing across scene changes until a scene stops or swaps it.
## Scenes decide when music plays; the main menu starts the menu theme itself.

const MENU_TRACK := "res://assets/audio/music/exploration.ogg"
const MENU_TRACK_LAYER := "res://assets/audio/music/_loop_1673064953929.wav"
const LEVEL_DEFAULT_TRACK := "res://assets/audio/music/Ludum Dare 30 04.ogg"
const DEFAULT_VOLUME_DB := -8.0

var _player: AudioStreamPlayer
var _player_layer: AudioStreamPlayer
var _current_path := ""
var _current_layer_path := ""


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.bus = &"Master"
	_player.volume_db = DEFAULT_VOLUME_DB
	add_child(_player)

	_player_layer = AudioStreamPlayer.new()
	_player_layer.bus = &"Master"
	_player_layer.volume_db = DEFAULT_VOLUME_DB
	add_child(_player_layer)


## Play a looping track, replacing whatever is playing. Calling it with the
## track that is already playing does nothing (so scene changes don't restart it).
## If layer_path is provided, the layer track plays simultaneously (menu layers).
func play(path: String = MENU_TRACK, layer_path: String = "") -> void:
	var should_restart := false
	if path != _current_path or not _player.playing:
		should_restart = true

	var stream: AudioStream = load(path)
	if stream == null:
		return

	if stream is AudioStreamOggVorbis or stream is AudioStreamMP3:
		stream.loop = true
	elif stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD

	_player.stream = stream
	if should_restart:
		_player.play()
	_current_path = path

	# Handle layered track (e.g., menu).
	if layer_path.is_empty():
		_player_layer.stop()
		_current_layer_path = ""
		return

	if layer_path != _current_layer_path or not _player_layer.playing:
		var lstream: AudioStream = load(layer_path)
		if lstream == null:
			_player_layer.stop()
			_current_layer_path = ""
			return
		if lstream is AudioStreamOggVorbis or lstream is AudioStreamMP3:
			lstream.loop = true
		elif lstream is AudioStreamWAV:
			lstream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		_player_layer.stream = lstream
		_player_layer.play()
		_current_layer_path = layer_path


## Play the layered menu theme (base + extra loop layer).
func play_menu() -> void:
	play(MENU_TRACK, MENU_TRACK_LAYER)


func stop() -> void:
	_player.stop()
	_player_layer.stop()
	_current_path = ""
	_current_layer_path = ""
