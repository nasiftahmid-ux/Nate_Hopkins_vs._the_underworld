extends Node
## Centralized audio settings with persistence.
## Handles volume levels for all buses and persists to save file.

const SAVE_SECTION := "audio"
const SETTINGS_PATH := "user://settings.json"
const DEFAULT_MASTER := 1.0
const DEFAULT_MUSIC := 0.8
const DEFAULT_SFX := 1.0
const DEFAULT_UI := 1.0
const DEFAULT_AMBIENCE := 0.8

signal master_volume_changed(value: float)
signal music_volume_changed(value: float)
signal sfx_volume_changed(value: float)
signal ui_volume_changed(value: float)
signal ambience_volume_changed(value: float)

var master_volume := DEFAULT_MASTER
var music_volume := DEFAULT_MUSIC
var sfx_volume := DEFAULT_SFX
var ui_volume := DEFAULT_UI
var ambience_volume := DEFAULT_AMBIENCE

var _bus_master := 0
var _bus_music := -1
var _bus_sfx := -1
var _bus_ui := -1
var _bus_ambience := -1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_cache_buses()
	load_settings()
	_apply_all()


func _cache_buses() -> void:
	_bus_master = AudioServer.get_bus_index(&"Master")
	_bus_music = AudioServer.get_bus_index(&"Music")
	_bus_sfx = AudioServer.get_bus_index(&"SFX")
	_bus_ui = AudioServer.get_bus_index(&"UI")
	_bus_ambience = AudioServer.get_bus_index(&"Ambience")


func set_master_volume(value: float) -> void:
	master_volume = clampf(value, 0.0, 1.0)
	_apply_master()
	master_volume_changed.emit(master_volume)
	save_settings()


func set_music_volume(value: float) -> void:
	music_volume = clampf(value, 0.0, 1.0)
	_apply_bus(_bus_music, music_volume)
	music_volume_changed.emit(music_volume)
	save_settings()


func set_sfx_volume(value: float) -> void:
	sfx_volume = clampf(value, 0.0, 1.0)
	_apply_bus(_bus_sfx, sfx_volume)
	sfx_volume_changed.emit(sfx_volume)
	save_settings()


func set_ui_volume(value: float) -> void:
	ui_volume = clampf(value, 0.0, 1.0)
	_apply_bus(_bus_ui, ui_volume)
	ui_volume_changed.emit(ui_volume)
	save_settings()


func set_ambience_volume(value: float) -> void:
	ambience_volume = clampf(value, 0.0, 1.0)
	_apply_bus(_bus_ambience, ambience_volume)
	ambience_volume_changed.emit(ambience_volume)
	save_settings()


func _apply_all() -> void:
	_apply_master()
	_apply_bus(_bus_music, music_volume)
	_apply_bus(_bus_sfx, sfx_volume)
	_apply_bus(_bus_ui, ui_volume)
	_apply_bus(_bus_ambience, ambience_volume)


func _apply_master() -> void:
	if _bus_master >= 0:
		AudioServer.set_bus_volume_db(_bus_master, linear_to_db(master_volume))
		AudioServer.set_bus_mute(_bus_master, master_volume <= 0.001)


func _apply_bus(bus_idx: int, linear: float) -> void:
	if bus_idx < 0:
		return
	AudioServer.set_bus_volume_db(bus_idx, linear_to_db(linear))
	AudioServer.set_bus_mute(bus_idx, linear <= 0.001)


func linear_to_db(linear: float) -> float:
	if linear <= 0.0:
		return -80.0
	return 20.0 * log(linear) / log(10.0)


func save_settings() -> void:
	var data := {}
	if FileAccess.file_exists(SETTINGS_PATH):
		var f := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
		if f:
			var p = JSON.parse_string(f.get_as_text())
			f.close()
			if p is Dictionary:
				data = p
	data[SAVE_SECTION] = {
		"master": master_volume,
		"music": music_volume,
		"sfx": sfx_volume,
		"ui": ui_volume,
		"ambience": ambience_volume,
	}
	var out := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if out:
		out.store_string(JSON.stringify(data))
		out.close()


func load_settings() -> void:
	var data := {}
	if FileAccess.file_exists(SETTINGS_PATH):
		var f := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
		if f:
			var p = JSON.parse_string(f.get_as_text())
			f.close()
			if p is Dictionary:
				data = p
	if not data is Dictionary:
		return
	if not data.has(SAVE_SECTION):
		return
	var section = data[SAVE_SECTION]
	if not section is Dictionary:
		return
	master_volume = clampf(float(section.get("master", DEFAULT_MASTER)), 0.0, 1.0)
	music_volume = clampf(float(section.get("music", DEFAULT_MUSIC)), 0.0, 1.0)
	sfx_volume = clampf(float(section.get("sfx", DEFAULT_SFX)), 0.0, 1.0)
	ui_volume = clampf(float(section.get("ui", DEFAULT_UI)), 0.0, 1.0)
	ambience_volume = clampf(float(section.get("ambience", DEFAULT_AMBIENCE)), 0.0, 1.0)
