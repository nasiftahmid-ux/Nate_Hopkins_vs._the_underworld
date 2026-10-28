extends Control

@onready var backdrop: Control = $Backdrop
@onready var bg: TextureRect = $Backdrop/BG
@onready var bg_next: TextureRect = $Backdrop/BGNext
@onready var title: Label = $TitleGroup/Title
@onready var start_button: Button = $Center/VBox/StartButton
@onready var quit_button: Button = $Center/VBox/QuitButton

const PIXEL_FONT := "res://assets/fonts/PressStart2P-Regular.ttf"
const ACCENT := Color("ff7a2f")
const ACCENT_BRIGHT := Color("ffb265")

## Cycled through the menu backdrop like a slideshow, one per Underworld map.
const BACKDROPS: Array[String] = [
	"res://assets/level1/background.png",
	"res://assets/level2/background.png",
	"res://assets/level3/background.png",
	"res://assets/level4/background_panorama.png",
]
const SLIDE_INTERVAL := 5.0
const SLIDE_FADE := 1.2

var _bg_index := 0

func _ready() -> void:
	_apply_pixel_theme()
	Music.play_menu()
	_add_vignette()
	_add_embers()
	_animate_backdrop()
	_animate_title()
	_style_text_button(start_button, 24)
	start_button.text = "CONTINUE"
	start_button.grab_focus()
	start_button.pressed.connect(_on_continue)
	var start_over := Button.new()
	start_over.text = "START OVER"
	_style_text_button(start_over, 24)
	start_over.pressed.connect(_on_start_over)
	$Center/VBox.add_child(start_over)
	# move quit button after
	quit_button.get_parent().move_child(quit_button, quit_button.get_parent().get_child_count() - 1)
	_style_text_button(quit_button, 24)
	quit_button.pressed.connect(func() -> void: get_tree().quit())
	_run_slideshow()
	if GameState.show_completion_panel:
		GameState.show_completion_panel = false
		_show_completion_panel()


func _on_continue() -> void:
	Music.stop()
	if GameState.active_slot >= 0 and not GameState.sandbox:
		if GameState.load_slot(GameState.active_slot):
			var stage := GameState.begin_attempt()
			get_tree().change_scene_to_file(stage)
			return
	GameState.open_new_run_flow_pending = false
	get_tree().change_scene_to_file("res://scenes/ui/run_select.tscn")


func _on_start_over() -> void:
	Music.stop()
	GameState.open_new_run_flow_pending = true
	get_tree().change_scene_to_file("res://scenes/ui/run_select.tscn")


# --- Presentation -----------------------------------------------------------

## Every label and button inherits the pixel font from this theme, so all menu
## text renders in the same crisp, aliased type as the game's art.
func _apply_pixel_theme() -> void:
	var theme := Theme.new()
	theme.default_font = load(PIXEL_FONT)
	theme.default_font_size = 12
	self.theme = theme


## Crossfades the backdrop through each Underworld map on a loop.
func _run_slideshow() -> void:
	if BACKDROPS.size() < 2:
		return
	while is_inside_tree():
		await get_tree().create_timer(SLIDE_INTERVAL).timeout
		if not is_inside_tree():
			return
		_bg_index = (_bg_index + 1) % BACKDROPS.size()
		bg_next.texture = load(BACKDROPS[_bg_index])
		var tween := create_tween()
		tween.tween_property(bg_next, "modulate:a", 1.0, SLIDE_FADE)
		await tween.finished
		bg.texture = bg_next.texture
		bg_next.modulate.a = 0.0


## Darkened, blurred-ish edges so the eye falls to the title and buttons.
func _add_vignette() -> void:
	var rect := ColorRect.new()
	rect.name = "Vignette"
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;

uniform float strength : hint_range(0.0, 1.0) = 0.72;
uniform vec4 tint : source_color = vec4(0.02, 0.0, 0.05, 1.0);

void fragment() {
	vec2 c = UV - vec2(0.5);
	float d = length(c) * 1.3;
	float v = smoothstep(0.2, 0.85, d) * strength;
	COLOR = vec4(tint.rgb, v);
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	rect.material = mat
	add_child(rect)
	move_child(rect, 2)


## Slow embers drifting up from the bottom of the screen, behind the UI.
func _add_embers() -> void:
	var particles := CPUParticles2D.new()
	particles.name = "Embers"
	particles.amount = 80
	particles.lifetime = 7.0
	particles.preprocess = 7.0
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	particles.emission_rect_extents = Vector2(720.0, 4.0)
	particles.position = Vector2(640.0, 736.0)
	particles.direction = Vector2(0.0, -1.0)
	particles.spread = 16.0
	particles.gravity = Vector2(0.0, -20.0)
	particles.initial_velocity_min = 12.0
	particles.initial_velocity_max = 52.0
	particles.scale_amount_min = 0.4
	particles.scale_amount_max = 1.4
	particles.color = Color(1.0, 0.62, 0.26, 1.0)
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.2, 0.7, 1.0])
	ramp.colors = PackedColorArray([
		Color(1.0, 0.78, 0.4, 0.0),
		Color(1.0, 0.8, 0.45, 0.85),
		Color(1.0, 0.42, 0.14, 0.4),
		Color(0.9, 0.25, 0.08, 0.0),
	])
	particles.color_ramp = ramp
	particles.texture = _soft_dot()
	add_child(particles)
	move_child(particles, 3)


func _soft_dot() -> GradientTexture2D:
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 1))
	grad.set_color(1, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.width = 16
	tex.height = 16
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	return tex


## Gentle breathing zoom on the backdrop so the menu never sits perfectly still.
func _animate_backdrop() -> void:
	backdrop.pivot_offset = get_viewport_rect().size * 0.5
	var tween := create_tween().set_loops()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(backdrop, "scale", Vector2(1.06, 1.06), 9.0).from(Vector2.ONE)
	tween.tween_property(backdrop, "scale", Vector2.ONE, 9.0)


## Warm, slow pulse on the title so it reads like firelight.
func _animate_title() -> void:
	var tween := create_tween().set_loops()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(title, "modulate", Color(1.0, 0.88, 0.72, 1.0), 2.4).from(Color.WHITE)
	tween.tween_property(title, "modulate", Color.WHITE, 2.4)


func _make_style(bg_color: Color, border: Color, border_w: int, radius: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg_color
	box.border_color = border
	box.set_border_width_all(border_w)
	box.set_corner_radius_all(radius)
	box.content_margin_left = 22.0
	box.content_margin_right = 22.0
	box.content_margin_top = 8.0
	box.content_margin_bottom = 8.0
	return box


func _style_button(btn: Button, font_size: int) -> void:
	btn.add_theme_stylebox_override("normal", _make_style(Color(0.10, 0.08, 0.15, 0.82), ACCENT.darkened(0.2), 2, 10))
	btn.add_theme_stylebox_override("hover", _make_style(Color(0.24, 0.12, 0.09, 0.95), ACCENT_BRIGHT, 2, 10))
	btn.add_theme_stylebox_override("pressed", _make_style(Color(0.32, 0.14, 0.06, 1.0), ACCENT_BRIGHT, 3, 10))
	btn.add_theme_stylebox_override("focus", _make_style(Color(0.18, 0.10, 0.12, 0.9), ACCENT_BRIGHT, 3, 10))
	btn.add_theme_stylebox_override("disabled", _make_style(Color(0.08, 0.08, 0.10, 0.6), Color(0.3, 0.3, 0.35), 2, 10))
	btn.add_theme_color_override("font_color", Color(0.97, 0.93, 0.86))
	btn.add_theme_color_override("font_hover_color", ACCENT_BRIGHT)
	btn.add_theme_color_override("font_focus_color", Color(1.0, 0.86, 0.56))
	btn.add_theme_color_override("font_pressed_color", Color.WHITE)
	btn.add_theme_font_size_override("font_size", font_size)


## Boxless main-menu buttons: plain pixel text that brightens on hover/focus.
func _style_text_button(btn: Button, font_size: int) -> void:
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		btn.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	btn.add_theme_font_size_override("font_size", font_size)
	btn.add_theme_color_override("font_color", Color(0.88, 0.86, 0.84))
	btn.add_theme_color_override("font_hover_color", ACCENT_BRIGHT)
	btn.add_theme_color_override("font_focus_color", Color(1.0, 0.86, 0.56))
	btn.add_theme_color_override("font_pressed_color", Color(1.0, 0.45, 0.32))
	_focus_marker(btn)


## Swaps the label to "> TEXT" while focused, for a text-only menu feel.
func _focus_marker(btn: Button) -> void:
	var base := btn.text
	btn.focus_entered.connect(func() -> void: btn.text = "> " + base)
	btn.focus_exited.connect(func() -> void: btn.text = base)


func _show_completion_panel() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	add_child(panel)
	var vbox := VBoxContainer.new()
	panel.add_child(vbox)
	var lbl := Label.new()
	lbl.text = "CARE FOR ANOTHER UNDERWORLD RUN? SEE WHAT YOU COULD HAVE DONE BETTER."
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(lbl)
	var score_lbl := Label.new()
	score_lbl.text = "FINAL SCORE: %d  BEST: %d  GRADE: %s" % [GameState.calculate_run_score(), GameState.best_score, GameState.grade_id()]
	vbox.add_child(score_lbl)
	var btns := HBoxContainer.new()
	vbox.add_child(btns)
	var yes := Button.new()
	yes.text = "YES"
	yes.pressed.connect(func():
		panel.queue_free()
		GameState.open_new_run_flow_pending = true
		get_tree().change_scene_to_file("res://scenes/ui/run_select.tscn")
	)
	btns.add_child(yes)
	var no := Button.new()
	no.text = "NO"
	no.pressed.connect(func(): panel.queue_free())
	btns.add_child(no)
	no.grab_focus()
