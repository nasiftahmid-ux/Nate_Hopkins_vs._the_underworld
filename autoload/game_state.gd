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
const DEATH_RATIO_PENALTY := 0.1
const MIN_RHYTHM_WINDOW := 0.15
const MIN_RHYTHM_NOTES := 8

## Combat grade is derived from how cleanly the whole run was fought. The first
## entry whose `min_ratio` the clean-combat ratio reaches wins, so the table is
## ordered best to worst. `window`/`notes`/`streak` are the difficulty knobs the
## rhythm finale applies, and `chant`/`after`/`verdict` drive the dialogue.
const GRADE_TABLE: Array[Dictionary] = [
	{
		"id": "FLAWLESS",
		"min_ratio": 0.85,
		"window": 1.35,
		"notes": 0.8,
		"streak": 4,
		"color": Color(1.0, 0.9, 0.45),
		"chant": "You cut through my champions without spilling a single drop. Ridiculous. Fine, Nate Hopkins - you have earned the gentle song.",
		"after": "Not one hesitation. Not one wasted motion. You sang the way you fought.",
		"verdict": "I don't know what you did down there, but I've never seen anyone arrive looking this good.",
	},
	{
		"id": "CLEAN",
		"min_ratio": 0.65,
		"window": 1.2,
		"notes": 0.9,
		"streak": 3,
		"color": Color(0.55, 1.0, 0.6),
		"chant": "Barely a scratch on you. You fight like a man apologizing with his fists. The song will be kind.",
		"after": "Steady hands, steady voice. Nobody in the Underworld kept a beat that cleanly.",
		"verdict": "You turned Hell into a warm-up. Dinner's on me.",
	},
	{
		"id": "BLOODIED",
		"min_ratio": 0.4,
		"window": 1.0,
		"notes": 1.0,
		"streak": 2,
		"color": Color(1.0, 0.72, 0.35),
		"chant": "You are still standing. I cannot say the same for your dignity, but I suppose that is not on my schedule.",
		"after": "Ugly hands, pretty timing. The Underworld respects that sort of stubbornness.",
		"verdict": "You're a mess, Nate. A very charming mess.",
	},
	{
		"id": "MANGLED",
		"min_ratio": 0.0,
		"window": 0.8,
		"notes": 1.15,
		"streak": 2,
		"color": Color(1.0, 0.4, 0.4),
		"chant": "You fought like something that crawled out of the Underworld with its hand still attached. Which... is the point. Sing it tight, or crawl back down.",
		"after": "You won on nothing but stubbornness and luck. It counts. Barely.",
		"verdict": "You look like a car accident. I'm saying yes anyway.",
	},
]

var player_health := 0.0
var player_max_hp := 100.0
var damage_taken := 0.0

## Run-wide combat record. Unlike `damage_taken` (reset per stage), these persist
## until a new run starts so the finale can judge how the player actually fought.
var run_damage_taken := 0.0
var run_deaths := 0
var stage_damage: Array[float] = []
var forced_grade := ""
var _stage_open := false

var money := 0
var exp := 0
var level := 1
var defeated_exes := 0

var dialogue_lines: Array[Dictionary] = []
var scene_after_dialogue := ""

var rhythm_window := 0.5
var rhythm_notes := 24
var rhythm_base_window := 0.5
var rhythm_base_notes := 24
var rhythm_followup_lines: Array[Dictionary] = []
var rhythm_followup_scene := ""
var rhythm_grade := ""
var rhythm_streak_limit := 2


func _ready() -> void:
	load_game()


func new_game() -> void:
	player_max_hp = max_hp_for_level(1)
	player_health = player_max_hp
	damage_taken = 0.0
	run_damage_taken = 0.0
	run_deaths = 0
	stage_damage.clear()
	forced_grade = ""
	_stage_open = false
	money = 0
	exp = 0
	level = 1
	defeated_exes = 0
	dialogue_lines = []
	scene_after_dialogue = ""
	rhythm_followup_lines = []
	rhythm_followup_scene = ""
	rhythm_window = 0.5
	rhythm_notes = 24
	rhythm_base_window = 0.5
	rhythm_base_notes = 24
	rhythm_grade = ""
	rhythm_streak_limit = 2


func max_hp_for_level(target_level: int) -> float:
	return BASE_MAX_HP + MAX_HP_PER_LEVEL * float(maxi(1, target_level) - 1)


func save_game() -> void:
	var data := {
		"player_max_hp": player_max_hp,
		"money": money,
		"exp": exp,
		"level": level,
		"defeated_exes": defeated_exes,
		"run_damage_taken": run_damage_taken,
		"run_deaths": run_deaths,
		"stage_damage": stage_damage,
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
	run_damage_taken = float(parsed.get("run_damage_taken", 0.0))
	run_deaths = int(parsed.get("run_deaths", 0))
	stage_damage.clear()
	var saved_stages = parsed.get("stage_damage", [])
	if saved_stages is Array:
		for value in saved_stages:
			stage_damage.append(float(value))
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


## Called by every stage scene on entry. Closing is idempotent, so a door that
## already closed the previous stage does not record a duplicate.
func begin_stage() -> void:
	clear_damage_penalty()
	_stage_open = true


func close_stage() -> void:
	if not _stage_open:
		return
	stage_damage.append(damage_taken)
	_stage_open = false


func clear_damage_penalty() -> void:
	close_stage()
	damage_taken = 0.0


func register_damage(amount: float) -> void:
	if not _stage_open:
		begin_stage()
	damage_taken += amount
	run_damage_taken += amount


func register_death() -> void:
	run_deaths += 1


## 1.0 means the whole run was fought without being hit, 0.0 means the player was
## carried through it. Measured as total damage against one full health bar per
## completed stage, then penalised per death.
func clean_combat_ratio() -> float:
	var stages := stage_damage.size()
	if stages <= 0:
		return 1.0
	var reference := player_max_hp * float(stages)
	if reference <= 0.0:
		return 1.0
	var ratio := 1.0 - run_damage_taken / reference
	ratio -= DEATH_RATIO_PENALTY * float(run_deaths)
	return clampf(ratio, 0.0, 1.0)


func combat_grade() -> Dictionary:
	if not forced_grade.is_empty():
		for rule in GRADE_TABLE:
			if String(rule["id"]) == forced_grade:
				return rule
	var ratio := clean_combat_ratio()
	for rule in GRADE_TABLE:
		if ratio >= float(rule["min_ratio"]):
			return rule
	return GRADE_TABLE[GRADE_TABLE.size() - 1]


func grade_id() -> String:
	return String(combat_grade()["id"])


## Applies the combat grade to the rhythm finale's difficulty. The caller must
## set the base `rhythm_window`/`rhythm_notes` first; this scales them once.
func apply_combat_grade() -> Dictionary:
	var rule := combat_grade()
	rhythm_window = maxf(rhythm_base_window * float(rule["window"]), MIN_RHYTHM_WINDOW)
	rhythm_notes = maxi(MIN_RHYTHM_NOTES, int(round(float(rhythm_base_notes) * float(rule["notes"]))))
	rhythm_streak_limit = int(rule["streak"])
	rhythm_grade = String(rule["id"])
	return rule


## The only way to set rhythm difficulty. Keeping the unscaled base around makes
## `apply_combat_grade()` idempotent, so re-entering the finale can never stack
## the modifier on top of an already-modified value.
func set_rhythm_difficulty(window_time: float, note_total: int) -> void:
	rhythm_base_window = maxf(window_time, MIN_RHYTHM_WINDOW)
	rhythm_base_notes = maxi(MIN_RHYTHM_NOTES, note_total)
	apply_combat_grade()


func grade_brief() -> String:
	var rule := combat_grade()
	return "Aphrodite reads your run: %s - %d notes, %.2fs window, %d misses allowed." % [
		String(rule["id"]), rhythm_notes, rhythm_window, rhythm_streak_limit
	]


func grade_chant() -> Dictionary:
	return {"speaker": "Aphrodite", "text": String(combat_grade()["chant"])}


## Splices the grade's reaction into the ending dialogue, just before the payoff
## line so the payoff still lands last.
func decorate_followup_lines(lines: Array[Dictionary]) -> Array[Dictionary]:
	if lines.is_empty():
		return lines
	var rule := combat_grade()
	var out: Array[Dictionary] = []
	for i in range(lines.size()):
		if i == lines.size() - 1:
			out.append({"speaker": "Aphrodite", "text": String(rule["after"])})
			out.append({"speaker": "Hazel", "text": String(rule["verdict"])})
		out.append(lines[i])
	return out


func xp_multiplier() -> float:
	if player_max_hp <= 0.0:
		return 1.0
	return clampf(1.0 - damage_taken / player_max_hp, MIN_REWARD_MULT, 1.0)


func level_up_heal_ratio() -> float:
	return PERFECT_HEAL_RATIO * xp_multiplier()


func exp_to_next_level() -> int:
	return level * 50
