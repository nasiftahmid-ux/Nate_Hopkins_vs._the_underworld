extends Control

@onready var backdrop: Control = $Backdrop
@onready var bg: TextureRect = $Backdrop/BG
@onready var bg_next: TextureRect = $Backdrop/BGNext
@onready var title: Label = $TitleGroup/Title
@onready var start_button: Button = $Center/VBox/StartButton
@onready var quit_button: Button = $Center/VBox/QuitButton
@onready var level_row: HBoxContainer = $DevPanel/LevelRow

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

var level_select: Array[Dictionary] = [
	{"label": "L1", "scene": "res://scenes/levels/level1.tscn"},
	{"label": "L2", "scene": "res://scenes/levels/level2.tscn"},
	{"label": "L3", "scene": "res://scenes/levels/level3.tscn"},
	{"label": "L4", "scene": "res://scenes/levels/level4.tscn"},
	{"label": "L5", "scene": "res://scenes/levels/level5.tscn"},
	{"label": "BOSS 1", "scene": "res://scenes/bosses/boss_arena.tscn", "exes": 0},
	{"label": "BOSS 2", "scene": "res://scenes/bosses/boss_arena.tscn", "exes": 1},
	{"label": "RHYTHM", "scene": "res://scenes/bosses/final_rhythm.tscn", "rhythm": 2},
]


func _ready() -> void:
	_apply_pixel_theme()
	Music.play_menu()
	_add_vignette()
	_add_embers()
	_animate_backdrop()
	_animate_title()
	_style_text_button(start_button, 24)
	_style_text_button(quit_button, 24)
	start_button.grab_focus()
	start_button.pressed.connect(_on_start)
	quit_button.pressed.connect(func() -> void: get_tree().quit())
	_build_level_select()
	_run_slideshow()


func _build_level_select() -> void:
	for entry in level_select:
		var button := Button.new()
		button.text = entry["label"]
		button.custom_minimum_size = Vector2(0, 30)
		_style_dev_button(button)
		button.pressed.connect(_on_level_selected.bind(entry))
		level_row.add_child(button)


func _on_level_selected(entry: Dictionary) -> void:
	Music.stop()
	if entry.has("rhythm"):
		_setup_rhythm(entry["rhythm"])
	elif entry.has("exes"):
		GameState.defeated_exes = entry["exes"]
	GameState.sandbox = true
	GameState.active_slot = -1
	GameState.begin_level()
	GameState.apply_unlocks_for_stage(entry["scene"])
	get_tree().change_scene_to_file(entry["scene"])


func _setup_rhythm(phase: int) -> void:
	GameState.defeated_exes = phase
	GameState.forced_grade = ""
	if phase == 1:
		GameState.set_rhythm_difficulty(1.0, 20)
		GameState.rhythm_followup_lines = []
		GameState.rhythm_followup_scene = "res://scenes/levels/level5.tscn"
	else:
		GameState.set_rhythm_difficulty(1.0, 30)
		GameState.rhythm_followup_lines = [
			{"speaker": "Aphrodite", "text": "Hmph. I'll say nothing. I hope you've learned your lesson, mortal."},
			{"speaker": "Aphrodite", "text": "There will be no next time... or my brother Mischief will be there to help you."},
			{"speaker": "Narrator", "text": "Nate falls into the middle of a classroom. Hazel is there."},
			{"speaker": "Hazel", "text": "Where did you go? What happened to you?"},
			{"speaker": "Nate", "text": "Well... it's a long story. But I think I deserved what happened to me."},
			{"speaker": "Hazel", "text": "Are you okay? You should get checked up. Let me take you."},
			{"speaker": "Nate", "text": "Hazel, wait. I need to tell you something."},
			{"speaker": "Hazel", "text": "What?"},
			{"speaker": "Nate", "text": "Do you wanna go out with me?"},
			{"speaker": "Hazel", "text": "......"},
		]
		GameState.rhythm_followup_scene = "res://scenes/ui/main.tscn"


func _on_start() -> void:
	Music.stop()
	get_tree().change_scene_to_file("res://scenes/ui/run_select.tscn")
		{"speaker": "Narrator", "text": "On the balcony of a mansion, a boy stands alone."},
		{"speaker": "Narrator", "text": "Nate Hopkins has just finished his freshman year at university."},
		{"speaker": "Narrator", "text": "The whole class is throwing a party before they become sophomores."},
		{"speaker": "Narrator", "text": "As he heads inside, a flash catches his eye. A beauty has just walked past him."},
		{"speaker": "Narrator", "text": "A boy... or maybe a man now. Never interested in this sort of thing. Yet he felt interested."},
		{"speaker": "Nate", "text": "Hey! T! Who's that girl over there?"},
		{"speaker": "Tracy", "text": "Her? Forget about it."},
		{"speaker": "Nate", "text": "Why? Why?!"},
		{"speaker": "Tracy", "text": "You never showed interest in anyone I introduced you to. You're still sulking over that ex of yours."},
		{"speaker": "Nate", "text": "Hey, c'mon. Help your homeboy out."},
		{"speaker": "Tracy", "text": "No. Go for it yourself. You're on your own."},
		{"speaker": "Narrator", "text": "Nate walks up to her and tries a little small talk."},
		{"speaker": "Nate", "text": "Hi, I'm Nate."},
		{"speaker": "Hazel", "text": "Hi. I'm Hazel."},
		{"speaker": "Nate", "text": "Nice name."},
		{"speaker": "Hazel", "text": "Oh, thanks. My dad gave it to me. Hazel A. Frey."},
		{"speaker": "Nate", "text": "What does the A stand for?"},
		{"speaker": "Hazel", "text": "My mom's name. Anasta..."},
		{"speaker": "", "text": "BIG EXPLOSION. Aphrodite appears out of nowhere."},
		{"speaker": "Aphrodite", "text": "Nate Hopkins!"},
		{"speaker": "Nate", "text": "Do I know you? How did you just explode out of nowhere?"},
		{"speaker": "Aphrodite", "text": "Spare me your silly chat, mortal. You cursed love, and love is me."},
		{"speaker": "Aphrodite", "text": "I will not let you bring a curse on my name again with another poor sweetheart. You're coming with me."},
		{"speaker": "Aphrodite", "text": "Brother, lock him up."},
		{"speaker": "Narrator", "text": "Hades sighs. He was right behind her."},
	]
	GameState.scene_after_dialogue = "res://scenes/levels/level1.tscn"
	get_tree().change_scene_to_file("res://scenes/dialogue/dialogue.tscn")


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


func _style_dev_button(btn: Button) -> void:
	_style_button(btn, 10)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var box: StyleBoxFlat = btn.get_theme_stylebox(state)
		box.content_margin_left = 12.0
		box.content_margin_right = 12.0
		box.content_margin_top = 3.0
		box.content_margin_bottom = 3.0
		box.set_corner_radius_all(6)
