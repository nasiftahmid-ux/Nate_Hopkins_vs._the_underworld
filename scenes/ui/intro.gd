extends Control
# Boot sequence: a black screen with the studio card, then the engine logo on
# black, then the main menu. Any key, button or click jumps ahead, so a repeat
# launch never holds the player hostage to the credits.

const PIXEL_FONT := "res://assets/fonts/PressStart2P-Regular.ttf"
const MAIN_SCENE := "res://scenes/ui/main.tscn"

## Beat lengths in seconds: black -> card in -> hold -> card out -> gap ->
## logo in -> hold -> logo out -> gap -> menu.
const BLACK_IN := 0.7
const FADE := 0.7
const CARD_HOLD := 1.9
const CARD_OUT := 0.5
const GAP := 0.4
const LOGO_HOLD := 2.1
const LOGO_OUT := 0.6

var _seq: Tween
var _blink: Tween
var _done := false

@onready var _card: Control = $CardCenter/Card
@onready var _logo: TextureRect = $LogoCenter/Logo
@onready var _hint: Label = $SkipHint


func _ready() -> void:
	_apply_pixel_theme()
	_seq = _build_sequence()
	_blink = _build_blink()
	await _seq.finished
	_advance()


func _build_sequence() -> Tween:
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_interval(BLACK_IN)
	tw.tween_property(_card, "modulate:a", 1.0, FADE)
	tw.tween_interval(CARD_HOLD)
	tw.tween_property(_card, "modulate:a", 0.0, CARD_OUT)
	tw.tween_interval(GAP)
	tw.tween_property(_logo, "modulate:a", 1.0, FADE)
	tw.tween_interval(LOGO_HOLD)
	tw.tween_property(_logo, "modulate:a", 0.0, LOGO_OUT)
	tw.tween_interval(GAP)
	return tw


## The skip hint breathes instead of sitting there, so it reads as a prompt.
func _build_blink() -> Tween:
	var tw := create_tween().set_loops()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(_hint, "modulate:a", 0.1, 0.6)
	tw.tween_property(_hint, "modulate:a", 0.85, 0.6)
	return tw


func _unhandled_input(event: InputEvent) -> void:
	if _done or not event.is_pressed() or event.is_echo():
		return
	if not (event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton):
		return
	_advance()


## Killing `_seq` on a skip is what stops the awaited `finished` above from
## resuming into a scene that is about to be freed.
func _advance() -> void:
	if _done:
		return
	_done = true
	if _seq and _seq.is_valid():
		_seq.kill()
	if _blink and _blink.is_valid():
		_blink.kill()
	get_tree().change_scene_to_file(MAIN_SCENE)


## One theme carrying the pixel font, so the card matches the menu and the rest
## of the game rather than falling back to the smooth system font.
func _apply_pixel_theme() -> void:
	var theme := Theme.new()
	theme.default_font = load(PIXEL_FONT)
	theme.default_font_size = 12
	self.theme = theme
