extends Node2D

enum Phase { INTRO, NOTE, GAP, GAMEOVER, WIN }

const NOTE_GAP := 1.0
const INTRO_TIME := 1.6
const MAX_MISS_STREAK := 2
const HIT_SCORE := 100

const TARGET_ACTIONS := ["attack", "heavy_attack", "special"]
const TARGET_LABELS := ["J", "K", "L"]
const TARGET_COLORS := [
	Color(0.85, 0.95, 1.0),
	Color(1.0, 0.85, 0.4),
	Color(1.0, 0.45, 0.85),
]

var notes: Array[int] = []
var note_count := 24
var window_time := 1.0
var note_index := 0
var phase := Phase.INTRO
var phase_time := 0.0
var combo := 0
var miss_streak := 0
var best_combo := 0
var score := 0
var finished := false

@onready var prompt: Label = $UI/PromptLabel
@onready var prompt_panel: ColorRect = $UI/PromptPanel
@onready var window_bar: ProgressBar = $UI/WindowBar
@onready var combo_label: Label = $UI/ComboLabel
@onready var miss_label: Label = $UI/MissLabel
@onready var progress_bar: ProgressBar = $UI/Progress
@onready var feedback: Label = $UI/FeedbackLabel
@onready var intro_label: Label = $UI/IntroLabel
@onready var title_label: Label = $UI/TitleLabel
@onready var boss_box: ColorRect = $UI/BossBox
@onready var boss_label: Label = $UI/BossLabel


func _ready() -> void:
	note_count = GameState.rhythm_notes if GameState.rhythm_notes > 0 else 24
	window_time = GameState.rhythm_window if GameState.rhythm_window > 0.0 else 1.0
	for i in range(note_count):
		notes.append(randi_range(0, 2))
	var boss_phase := maxi(GameState.defeated_exes, 1)
	title_label.text = "FINAL BOSS: RHYTHM OF THE UNDERWORLD - PHASE %d" % boss_phase
	if boss_phase >= 2:
		boss_label.text = "THE FIRST LOVE"
		boss_box.color = Color(0.95, 0.55, 0.75, 1)
	else:
		boss_label.text = "THE ONE YOU HURT"
		boss_box.color = Color(0.85, 0.5, 0.95, 1)
	$UI/FeedbackTimer.timeout.connect(func() -> void: feedback.visible = false)
	_begin_intro()


func _physics_process(delta: float) -> void:
	phase_time += delta
	match phase:
		Phase.INTRO:
			if phase_time >= INTRO_TIME:
				_start_note()
		Phase.NOTE:
			_update_note()
		Phase.GAP:
			if phase_time >= NOTE_GAP:
				_start_note()
		Phase.GAMEOVER:
			if phase_time >= 2.2:
				_restart_song()
		Phase.WIN:
			if phase_time >= 2.0 and not finished:
				finished = true
				_go_to_ending()


func _begin_intro() -> void:
	phase = Phase.INTRO
	phase_time = 0.0
	intro_label.text = "GET READY"
	intro_label.visible = true
	prompt.text = ""
	prompt_panel.color = Color(0.2, 0.2, 0.3)
	window_bar.value = 100.0
	feedback.visible = false
	_update_hud()


func _start_note() -> void:
	intro_label.visible = false
	prompt.text = TARGET_LABELS[notes[note_index]]
	prompt_panel.color = TARGET_COLORS[notes[note_index]].darkened(0.25)
	phase = Phase.NOTE
	phase_time = 0.0
	window_bar.value = 100.0
	progress_bar.value = float(note_index) / float(maxi(note_count - 1, 1)) * 100.0


func _update_note() -> void:
	window_bar.value = maxf(window_time - phase_time, 0.0) / window_time * 100.0
	var pressed := -1
	for i in range(TARGET_ACTIONS.size()):
		if Input.is_action_just_pressed(TARGET_ACTIONS[i]):
			pressed = i
			break
	if pressed >= 0:
		if pressed == notes[note_index]:
			_hit()
		else:
			_miss()
	elif phase_time >= window_time:
		_miss()


func _hit() -> void:
	combo += 1
	best_combo = maxi(best_combo, combo)
	miss_streak = 0
	score += HIT_SCORE
	window_bar.value = 0.0
	prompt_panel.color = Color(0.2, 0.5, 0.3)
	_show_feedback("HIT!", Color(0.4, 1.0, 0.5))
	_update_hud()
	_advance()


func _miss() -> void:
	combo = 0
	miss_streak += 1
	window_bar.value = 0.0
	prompt_panel.color = Color(0.55, 0.15, 0.2)
	_show_feedback("MISS", Color(1.0, 0.35, 0.35))
	_update_hud()
	if miss_streak >= MAX_MISS_STREAK:
		intro_label.text = "GAME OVER\nTWO MISSES IN A ROW..."
		intro_label.visible = true
		prompt.text = ""
		phase = Phase.GAMEOVER
		phase_time = 0.0
	else:
		_advance()


func _advance() -> void:
	if note_index >= note_count - 1:
		intro_label.text = "VICTORY!"
		intro_label.visible = true
		prompt.text = ""
		phase = Phase.WIN
		phase_time = 0.0
		_show_feedback("", Color.WHITE)
	else:
		note_index += 1
		progress_bar.value = float(note_index) / float(maxi(note_count - 1, 1)) * 100.0
		phase = Phase.GAP
		phase_time = 0.0


func _restart_song() -> void:
	note_index = 0
	combo = 0
	miss_streak = 0
	best_combo = 0
	score = 0
	progress_bar.value = 0.0
	_begin_intro()


func _show_feedback(text_str: String, color: Color) -> void:
	feedback.text = text_str
	feedback.modulate = color
	feedback.visible = true
	$UI/FeedbackTimer.start()


func _update_hud() -> void:
	combo_label.text = "Combo: %d" % combo
	miss_label.text = "Miss streak: %d / %d" % [miss_streak, MAX_MISS_STREAK]


func _go_to_ending() -> void:
	var followup_lines := GameState.rhythm_followup_lines
	var followup_scene := GameState.rhythm_followup_scene
	if followup_scene.is_empty():
		get_tree().change_scene_to_file("res://scenes/ui/main.tscn")
	elif followup_lines.is_empty():
		get_tree().change_scene_to_file(followup_scene)
	else:
		GameState.dialogue_lines = followup_lines
		GameState.scene_after_dialogue = followup_scene
		get_tree().change_scene_to_file("res://scenes/dialogue/dialogue.tscn")
