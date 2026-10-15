extends Node

## Background music manager. As an autoload it survives `change_scene_to_file`,
## so a track keeps playing across scene changes until a scene stops or swaps it.
## Scenes decide when music plays; the main menu starts the menu theme itself.

const MENU_TRACK := "res://assets/audio/music/exploration.ogg"
const LEVEL_DEFAULT_TRACK := "res://assets/audio/music/Ludum Dare 30 04.ogg"
const DEFAULT_VOLUME_DB := -8.0

var _player: AudioStreamPlayer
var _current_path := ""


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.bus = &"Master"
	_player.volume_db = DEFAULT_VOLUME_DB
	add_child(_player)


## Play a looping track, replacing whatever is playing. Calling it with the
## track that is already playing does nothing (so scene changes don't restart it).
func play(path: String = MENU_TRACK) -> void:
	if path == _current_path and _player.playing:
		return
	var stream: AudioStream = load(path)
	if stream == null:
		return
	if stream is AudioStreamOggVorbis or stream is AudioStreamMP3:
		stream.loop = true
	_player.stream = stream
	_player.play()
	_current_path = path


func stop() -> void:
	_player.stop()
	_current_path = ""


func set_volume_db(db: float) -> void:
	_player.volume_db = clampf(db, -80.0, 24.0)
