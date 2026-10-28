extends Control

var _title: Label
var _cards: Array = []
var _status: Label
var _new_run_btn: Button
var _back_btn: Button
var _erase_mode := false
var _delete_only := false
var _pending_erase_slot := -1
var _name_panel: PanelContainer
var _name_edit: LineEdit
var _name_target_slot := -1
var _warning_panel: PanelContainer
var _warning_label: Label

func _ready() -> void:
	_build_ui()
	_refresh_cards()
	if GameState.open_new_run_flow_pending:
		GameState.open_new_run_flow_pending = false
		open_new_run_flow()


func open_new_run_flow() -> void:
	_erase_mode = false
	_status.text = "CHOOSE YOUR UNDERWORLD RUN"
	_refresh_cards()


func _build_ui() -> void:
	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(vbox)

	_title = Label.new()
	_title.text = "CHOOSE YOUR UNDERWORLD RUN"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 24)
	vbox.add_child(_title)

	_status = Label.new()
	_status.text = "CHOOSE YOUR UNDERWORLD RUN"
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_status)

	for i in range(GameState.SLOT_COUNT):
		var card := Button.new()
		card.custom_minimum_size = Vector2(700, 70)
		card.pressed.connect(_on_slot_pressed.bind(i))
		_cards.append(card)
		vbox.add_child(card)

	_new_run_btn = Button.new()
	_new_run_btn.text = "NEW UNDERWORLD RUN"
	_new_run_btn.pressed.connect(_on_new_run_pressed)
	vbox.add_child(_new_run_btn)

	var del_btn := Button.new()
	del_btn.text = "DELETE RUN"
	del_btn.pressed.connect(_on_delete_pressed)
	vbox.add_child(del_btn)

	_back_btn = Button.new()
	_back_btn.text = "BACK"
	_back_btn.pressed.connect(_on_back)
	vbox.add_child(_back_btn)

	_build_name_panel()
	_build_warning_panel()


func _card_text(i: int) -> String:
	var s := GameState.slot_summary(i)
	match s["state"]:
		"empty":
			return "SLOT %d: EMPTY - NEW UNDERWORLD RUN" % (i + 1)
		"corrupted":
			return "SLOT %d: CORRUPTED" % (i + 1)
		"completed":
			return "SLOT %d: %s  COMPLETED  BEST: %d" % [i + 1, s["name"], s["best_score"]]
		_:
			var moves: Array = s["moves"]
			var mv := ""
			for m in moves:
				mv += str(m) + " "
			return "SLOT %d: %s  Next: %s  Moves: %s Best: %d  Last: %s" % [i + 1, s["name"], s["next_stage_label"], mv.strip_edges(), s["best_score"], s["last_played"]]


func _refresh_cards() -> void:
	for i in range(GameState.SLOT_COUNT):
		var btn: Button = _cards[i]
		btn.text = _card_text(i)


func _on_slot_pressed(i: int) -> void:
	if _erase_mode:
		_pending_erase_slot = i
		_show_warning(i)
		return
	var s := GameState.slot_summary(i)
	match s["state"]:
		"empty", "corrupted":
			_name_target_slot = i
			_show_name_entry()
		"completed":
			pass
		_:
			GameState.active_slot = i
			GameState.sandbox = false
			if GameState.load_slot(i):
				var stage := GameState.begin_attempt()
				get_tree().change_scene_to_file(stage)


func _on_delete_pressed() -> void:
	_erase_mode = true
	_delete_only = true
	_status.text = "CHOOSE A RUN TO DELETE"
	_refresh_cards()


func _on_new_run_pressed() -> void:
	_delete_only = false
	var first_empty := -1
	for i in range(GameState.SLOT_COUNT):
		if GameState.slot_summary(i)["state"] == "empty":
			first_empty = i
			break
	if first_empty >= 0:
		_name_target_slot = first_empty
		_show_name_entry()
	else:
		_erase_mode = true
		_status.text = "CHOOSE A RUN TO ERASE AND REPLACE"
		_refresh_cards()


func _show_name_entry() -> void:
	_name_panel.visible = true
	_name_edit.text = "NATE"
	_name_edit.grab_focus()


func _build_name_panel() -> void:
	_name_panel = PanelContainer.new()
	_name_panel.visible = false
	add_child(_name_panel)
	var vbox := VBoxContainer.new()
	_name_panel.add_child(vbox)
	var lbl := Label.new()
	lbl.text = "ENTER NAME (max 12)"
	vbox.add_child(lbl)
	_name_edit = LineEdit.new()
	_name_edit.max_length = 12
	_name_edit.placeholder_text = "Nate"
	vbox.add_child(_name_edit)
	var btns := HBoxContainer.new()
	vbox.add_child(btns)
	var ok := Button.new()
	ok.text = "OK"
	ok.pressed.connect(_confirm_name)
	btns.add_child(ok)
	var cancel := Button.new()
	cancel.text = "CANCEL"
	cancel.pressed.connect(_cancel_name)
	btns.add_child(cancel)
	_name_edit.text_submitted.connect(func(_t): _confirm_name())


func _confirm_name() -> void:
	var slot := _name_target_slot
	if slot < 0:
		return
	var raw := _name_edit.text
	if raw.strip_edges().is_empty():
		raw = "Nate"
	GameState.create_slot(slot, raw)
	GameState.active_slot = slot
	GameState.sandbox = false
	GameState.load_slot(slot)
	_name_panel.visible = false
	_erase_mode = false
	_name_target_slot = -1
	_status.text = "CHOOSE YOUR UNDERWORLD RUN"
	_refresh_cards()
	# play intro cutscene S1 then begin attempt and load level 1
	var stage := GameState.begin_attempt()
	GameState.dialogue_lines = GameState.story_lines("S1_INTRO") if GameState.should_play_story("S1_INTRO") else []
	GameState.scene_after_dialogue = stage
	if GameState.dialogue_lines.is_empty():
		get_tree().change_scene_to_file(stage)
	else:
		get_tree().change_scene_to_file("res://scenes/dialogue/dialogue.tscn")


func _cancel_name() -> void:
	_name_panel.visible = false
	_name_target_slot = -1
	_erase_mode = false
	_status.text = "CHOOSE YOUR UNDERWORLD RUN"
	_refresh_cards()


func _show_warning(i: int) -> void:
	_warning_panel.visible = true
	var s := GameState.slot_summary(i)
	var moves: Array = s["moves"]
	var mv := ""
	for m in moves:
		mv += str(m) + " "
	_warning_label.text = "ERASE %s? This permanently deletes this Underworld Run (%s, moves: %s). This cannot be undone." % [s["name"], s["next_stage_label"], mv.strip_edges()]


func _build_warning_panel() -> void:
	_warning_panel = PanelContainer.new()
	_warning_panel.visible = false
	add_child(_warning_panel)
	var vbox := VBoxContainer.new()
	_warning_panel.add_child(vbox)
	_warning_label = Label.new()
	_warning_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_warning_label)
	var btns := HBoxContainer.new()
	vbox.add_child(btns)
	var cancel := Button.new()
	cancel.text = "CANCEL"
	cancel.pressed.connect(_cancel_warning)
	btns.add_child(cancel)
	cancel.grab_focus()
	var erase := Button.new()
	erase.text = "ERASE"
	erase.pressed.connect(_confirm_erase)
	btns.add_child(erase)


func _cancel_warning() -> void:
	_warning_panel.visible = false
	_pending_erase_slot = -1
	_erase_mode = false
	_delete_only = false
	_status.text = "CHOOSE YOUR UNDERWORLD RUN"
	_refresh_cards()


func _confirm_erase() -> void:
	var slot := _pending_erase_slot
	if slot < 0:
		return
	GameState.erase_slot(slot)
	_pending_erase_slot = -1
	_warning_panel.visible = false
	_erase_mode = false
	if _delete_only:
		_delete_only = false
		_status.text = "CHOOSE YOUR UNDERWORLD RUN"
		_refresh_cards()
		return
	_delete_only = false
	_status.text = "CHOOSE YOUR UNDERWORLD RUN"
	_refresh_cards()
	_name_target_slot = slot
	_show_name_entry()


func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/main.tscn")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if _name_panel.visible:
			_cancel_name()
		elif _warning_panel.visible:
			_cancel_warning()
		elif _erase_mode:
			_erase_mode = false
			_status.text = "CHOOSE YOUR UNDERWORLD RUN"
			_refresh_cards()
		else:
			_on_back()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		GameState.save_slot()
