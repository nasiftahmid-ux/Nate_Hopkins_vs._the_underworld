extends Node

signal money_changed(value: int)
signal exp_changed(value: int)
signal level_changed(value: int)

const SAVE_PATH := "user://save.json"

var player_health := 0.0
var player_max_hp := 100.0

var money := 0
var exp := 0
var level := 1
var defeated_exes := 0

var dialogue_lines: Array[Dictionary] = []
var scene_after_dialogue := ""

var rhythm_window := 0.5
var rhythm_notes := 24
var rhythm_followup_lines: Array[Dictionary] = []
var rhythm_followup_scene := ""


func _ready() -> void:
	load_game()


func new_game() -> void:
	player_health = player_max_hp
	money = 0
	exp = 0
	level = 1
	defeated_exes = 0
	dialogue_lines = []
	scene_after_dialogue = ""
	rhythm_followup_lines = []
	rhythm_followup_scene = ""


func save_game() -> void:
	var data := {
		"player_max_hp": player_max_hp,
		"money": money,
		"exp": exp,
		"level": level,
		"defeated_exes": defeated_exes,
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))


func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return false
	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return false
	player_max_hp = parsed.get("player_max_hp", player_max_hp)
	money = parsed.get("money", money)
	exp = parsed.get("exp", exp)
	level = parsed.get("level", level)
	defeated_exes = parsed.get("defeated_exes", defeated_exes)
	return true


func add_money(value: int) -> void:
	money += value
	save_game()
	money_changed.emit(money)


func add_exp(value: int) -> void:
	exp += value
	while exp >= exp_to_next_level():
		exp -= exp_to_next_level()
		level += 1
		player_max_hp += 10.0
		player_health = player_max_hp
		level_changed.emit(level)
	exp_changed.emit(exp)
	save_game()


func exp_to_next_level() -> int:
	return level * 50
