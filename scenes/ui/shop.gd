extends Control
## Aphrodite's Underworld Shop. Reached from a level exit, where GameState holds
## the next scene. The whole screen exists to force one decision, so the rule is
## enforced in GameState.buy_shop_item() rather than by hiding buttons here.

@onready var purse_label: Label = $Margin/Rows/Purse
@onready var visits_label: Label = $Margin/Rows/Visits
@onready var list: VBoxContainer = $Margin/Rows/Scroll/List
@onready var leave_button: Button = $Margin/Rows/LeaveButton
@onready var speech_label: Label = $Margin/Speech

var _buttons := {}
var _opening := true


func _ready() -> void:
	# Arm the visit before anything reads it, so the greeting can never describe
	# a purchase left over from however the player got here.
	GameState.reset_shop_visit()
	speech_label.text = _greeting()
	leave_button.pressed.connect(_on_leave)
	_build_rows()
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	get_viewport().set_input_as_handled()
	_on_leave()


func _greeting() -> String:
	if GameState.money <= 0:
		return "\"Nothing to spend, nothing to say. Go on.\""
	if GameState.purchases_this_visit > 0:
		return "\"One thing per stop, Nate. Choose like it means something.\""
	return "\"You have %d coins. I can do something with those. Once.\"" % GameState.money


## Builds one row per catalogue entry straight from GameState.SHOP_ITEMS, so the
## screen cannot drift out of sync with the prices the economy is balanced on.
func _build_rows() -> void:
	for entry in GameState.SHOP_ITEMS:
		var id := str(entry["id"])
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)

		var name_label := Label.new()
		name_label.custom_minimum_size = Vector2(250, 0)
		name_label.text = str(entry["name"])
		row.add_child(name_label)

		var blurb_label := Label.new()
		blurb_label.custom_minimum_size = Vector2(330, 0)
		blurb_label.text = str(entry["blurb"])
		blurb_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		blurb_label.add_theme_font_size_override("font_size", 14)
		blurb_label.add_theme_color_override("font_color", Color(0.72, 0.7, 0.78))
		row.add_child(blurb_label)

		var rank_label := Label.new()
		rank_label.custom_minimum_size = Vector2(70, 0)
		rank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(rank_label)

		var buy_button := Button.new()
		buy_button.custom_minimum_size = Vector2(140, 40)
		buy_button.pressed.connect(_on_buy.bind(id))
		row.add_child(buy_button)

		list.add_child(row)
		_buttons[id] = {"button": buy_button, "rank": rank_label}


func _refresh() -> void:
	purse_label.text = "PURSE: %d COINS" % GameState.money
	var left := maxi(0, GameState.SHOP_PURCHASES_PER_VISIT - GameState.purchases_this_visit)
	visits_label.text = (
		"ONE PURCHASE ALLOWED THIS VISIT"
		if left > 0
		else "SPENT - APHRODITE ALLOWS NOTHING FURTHER"
	)
	visits_label.add_theme_color_override(
		"font_color", Color(0.95, 0.85, 0.5) if left > 0 else Color(0.65, 0.5, 0.5)
	)

	for id in _buttons:
		var parts: Dictionary = _buttons[id]
		var button: Button = parts["button"]
		var rank_label: Label = parts["rank"]
		var ranks := GameState.shop_rank(id)
		var cap := int(GameState.shop_item(id).get("max_ranks", 0))
		rank_label.text = ("%d / %d" % [ranks, cap]) if cap > 0 else ("x%d" % ranks if ranks > 0 else "-")

		var price := GameState.shop_price(id)
		if left <= 0:
			button.text = "DONE"
			button.disabled = true
		elif cap > 0 and ranks >= cap:
			button.text = "MAXED"
			button.disabled = true
		elif not GameState.shop_item_available(id):
			button.text = "UNAVAILABLE"
			button.disabled = true
		elif GameState.money < price:
			button.text = "NEED %d" % price
			button.disabled = true
		else:
			button.text = "BUY  %d" % price
			button.disabled = false

	# Keep focus on something actionable so controller players are never stranded.
	if _opening or not leave_button.has_focus():
		leave_button.grab_focus()
	_opening = false


func _on_buy(id: String) -> void:
	if not GameState.buy_shop_item(id):
		return
	speech_label.text = _bought_line(id)
	_refresh()


func _bought_line(id: String) -> String:
	match id:
		"revive":
			return "\"There. Now you have to be worth it.\""
		"hp":
			return "\"More to lose. Try not to.\""
		"warcry":
			return "\"Loud, brief, and gone by the next room. Go.\""
		"heal":
			return "\"Patched up. Don't make a habit of it.\""
		_:
			return "\"Better. Marginally.\""


func _on_leave() -> void:
	var next := GameState.shop_next_scene
	# Close the visit out on the way out, not just on the way in, so a stale
	# purchase count can never leak into the next stage.
	GameState.reset_shop_visit()
	GameState.shop_next_scene = ""
	if next.is_empty():
		get_tree().change_scene_to_file("res://scenes/ui/main.tscn")
	else:
		get_tree().change_scene_to_file(next)
