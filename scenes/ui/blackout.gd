extends Control
# End-of-stage curtain. A cleared level routes here on its way to Aphrodite's
# shop, and a defeated boss on its way to its cutscene. It blacks out the screen,
# cuts the stage music and plays only the opening of the victory sting, then
# hands off to whatever scene GameState queued for it. Sharing one curtain keeps
# the two endings feeling like the same beat, and if the caller left a caption it
# animates on over the black ("LEVEL 3 COMPLETED").

const STING_PATH := "res://assets/audio/music/VGMA Challenge 31.ogg"
const PIXEL_FONT := "res://assets/fonts/PressStart2P-Regular.ttf"
## How much of the track is used. The sting is a short flourish, not a track.
const STING_SECONDS := 4.0
const STING_VOLUME_DB := -6.0
const FALLBACK_SCENE := "res://scenes/ui/main.tscn"

var _sting: AudioStreamPlayer

@onready var _caption: Label = get_node_or_null("Caption")
@onready var _subtitle: Label = get_node_or_null("Subtitle")


func _ready() -> void:
	_apply_pixel_theme()
	Music.stop()
	_start_sting()
	var caption: String = GameState.blackout_caption
	var subtitle: String = GameState.blackout_subtitle
	GameState.blackout_caption = ""
	GameState.blackout_subtitle = ""
	if not caption.is_empty():
		_show_caption(caption, subtitle)
	await get_tree().create_timer(STING_SECONDS).timeout
	_advance()


## Matches the menu: one theme carrying the pixel font, so the caption renders in
## the same crisp, aliased type as the rest of the game rather than a smooth one.
func _apply_pixel_theme() -> void:
	var theme := Theme.new()
	theme.default_font = load(PIXEL_FONT)
	theme.default_font_size = 28
	self.theme = theme


func _start_sting() -> void:
	var stream: AudioStream = load(STING_PATH)
	if stream == null:
		return
	# Play the track straight through; it is stopped by the timer below.
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = false
	elif stream is AudioStreamWAV:
		(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_DISABLED
	_sting = AudioStreamPlayer.new()
	_sting.bus = &"Master"
	_sting.volume_db = STING_VOLUME_DB
	_sting.stream = stream
	add_child(_sting)
	_sting.play()


## Reveals the headline the way a slide would appear: it fades up as the letters
## type themselves in, holds a beat, then fades back out before the hand-off.
func _show_caption(text: String, subtitle: String = "") -> void:
	if _caption == null:
		return
	_caption.text = text
	_caption.modulate.a = 0.0
	_caption.visible_ratio = 0.0
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(_caption, "modulate:a", 1.0, 0.4)
	tw.parallel().tween_property(_caption, "visible_ratio", 1.0, 1.0)
	tw.tween_interval(1.2)
	tw.tween_property(_caption, "modulate:a", 0.0, 0.4)
	if _subtitle and not subtitle.is_empty():
		_subtitle.text = subtitle
		_subtitle.modulate.a = 0.0
		_subtitle.visible_ratio = 0.0
		tw.parallel().tween_property(_subtitle, "modulate:a", 1.0, 0.4)
		tw.parallel().tween_property(_subtitle, "visible_ratio", 1.0, 0.9)
		tw.tween_interval(0.2)
		tw.tween_property(_subtitle, "modulate:a", 0.0, 0.4)


func _advance() -> void:
	if _sting:
		_sting.stop()
	var next: String = GameState.consume_blackout_scene()
	get_tree().change_scene_to_file(next if not next.is_empty() else FALLBACK_SCENE)
