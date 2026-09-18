extends Node

signal money_changed(value: int)
signal exp_changed(value: int)
signal level_changed(value: int)

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


func add_money(value: int) -> void:
	money += value
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


func exp_to_next_level() -> int:
	return level * 50
