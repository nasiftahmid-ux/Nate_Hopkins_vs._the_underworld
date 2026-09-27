extends Node

signal money_changed(value: int)
signal exp_changed(value: int)
signal level_changed(value: int)
signal level_healed(amount: float)

const SAVE_PATH := "user://save.json"
const PERFECT_HEAL_RATIO := 0.5
const MIN_REWARD_MULT := 0.25
const BASE_MAX_HP := 100.0
const MAX_HP_PER_LEVEL := 10.0

var player_health := 0.0
var player_max_hp := 100.0
var damage_taken := 0.0

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
	player_max_hp = max_hp_for_level(1)
	player_health = player_max_hp
	damage_taken = 0.0
	money = 0
	exp = 0
	level = 1
	defeated_exes = 0
	dialogue_lines = []
	scene_after_dialogue = ""
	rhythm_followup_lines = []
	rhythm_followup_scene = ""


func max_hp_for_level(target_level: int) -> float:
	return BASE_MAX_HP + MAX_HP_PER_LEVEL * float(maxi(1, target_level) - 1)


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
	player_max_hp = max_hp_for_level(level)
	return true


func add_money(value: int) -> void:
	money += value
	save_game()
	money_changed.emit(money)


func add_exp(value: int) -> void:
	exp += maxi(1, int(round(value * xp_multiplier())))
	while exp >= exp_to_next_level():
		exp -= exp_to_next_level()
		level += 1
		player_max_hp = max_hp_for_level(level)
		var heal := player_max_hp * level_up_heal_ratio()
		player_health = minf(player_health + heal, player_max_hp)
		level_changed.emit(level)
		level_healed.emit(heal)
	exp_changed.emit(exp)
	save_game()


func begin_level() -> void:
	clear_damage_penalty()
	player_health = player_max_hp


func clear_damage_penalty() -> void:
	damage_taken = 0.0


func register_damage(amount: float) -> void:
	damage_taken += amount


func xp_multiplier() -> float:
	if player_max_hp <= 0.0:
		return 1.0
	return clampf(1.0 - damage_taken / player_max_hp, MIN_REWARD_MULT, 1.0)


func level_up_heal_ratio() -> float:
	return PERFECT_HEAL_RATIO * xp_multiplier()


func exp_to_next_level() -> int:
	return level * 50
