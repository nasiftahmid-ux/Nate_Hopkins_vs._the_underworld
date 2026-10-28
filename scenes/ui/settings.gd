extends Control

@onready var master_slider: HSlider = $Panel/VBox/Master/Slider
@onready var music_slider: HSlider = $Panel/VBox/Music/Slider
@onready var sfx_slider: HSlider = $Panel/VBox/SFX/Slider
@onready var ui_slider: HSlider = $Panel/VBox/UI/Slider
@onready var ambience_slider: HSlider = $Panel/VBox/Ambience/Slider
@onready var back_button: Button = $Panel/VBox/Back


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Connect sliders
	if master_slider:
		master_slider.value = AudioSettings.master_volume * 100.0
		master_slider.value_changed.connect(_on_master_changed)
	if music_slider:
		music_slider.value = AudioSettings.music_volume * 100.0
		music_slider.value_changed.connect(_on_music_changed)
	if sfx_slider:
		sfx_slider.value = AudioSettings.sfx_volume * 100.0
		sfx_slider.value_changed.connect(_on_sfx_changed)
	if ui_slider:
		ui_slider.value = AudioSettings.ui_volume * 100.0
		ui_slider.value_changed.connect(_on_ui_changed)
	if ambience_slider:
		ambience_slider.value = AudioSettings.ambience_volume * 100.0
		ambience_slider.value_changed.connect(_on_ambience_changed)
	
	if back_button:
		back_button.pressed.connect(_on_back_pressed)
	
	# Connect to settings changes
	AudioSettings.master_volume_changed.connect(_on_master_external)
	AudioSettings.music_volume_changed.connect(_on_music_external)
	AudioSettings.sfx_volume_changed.connect(_on_sfx_external)
	AudioSettings.ui_volume_changed.connect(_on_ui_external)
	AudioSettings.ambience_volume_changed.connect(_on_ambience_external)


func _on_master_changed(value: float) -> void:
	AudioSettings.set_master_volume(value / 100.0)


func _on_music_changed(value: float) -> void:
	AudioSettings.set_music_volume(value / 100.0)


func _on_sfx_changed(value: float) -> void:
	AudioSettings.set_sfx_volume(value / 100.0)


func _on_ui_changed(value: float) -> void:
	AudioSettings.set_ui_volume(value / 100.0)


func _on_ambience_changed(value: float) -> void:
	AudioSettings.set_ambience_volume(value / 100.0)


func _on_master_external(value: float) -> void:
	if master_slider and abs(master_slider.value - value * 100.0) > 0.1:
		master_slider.value = value * 100.0


func _on_music_external(value: float) -> void:
	if music_slider and abs(music_slider.value - value * 100.0) > 0.1:
		music_slider.value = value * 100.0


func _on_sfx_external(value: float) -> void:
	if sfx_slider and abs(sfx_slider.value - value * 100.0) > 0.1:
		sfx_slider.value = value * 100.0


func _on_ui_external(value: float) -> void:
	if ui_slider and abs(ui_slider.value - value * 100.0) > 0.1:
		ui_slider.value = value * 100.0


func _on_ambience_external(value: float) -> void:
	if ambience_slider and abs(ambience_slider.value - value * 100.0) > 0.1:
		ambience_slider.value = value * 100.0


func _on_back_pressed() -> void:
	queue_free()
