extends Node

func _ready():
	var base := "res://assets/bosses/boss1/"
	var frames := SpriteFrames.new()
	
	add_anim(frames, base + "BOSS_1_idle_transparent.png", "idle", 5, 245, 324, 10.0, true)
	add_anim(frames, base + "BOSS_1_walk_transparent.png", "walk", 6, 316, 307, 10.0, true)
	add_anim(frames, base + "BOSS_1_melee_or_shoot_and_spit_transparent.png", "melee_shoot_spit", 5, 218, 272, 14.0, false)
	add_anim(frames, base + "BOSS_1_charge_or_lunge_transparent.png", "lunge", 4, 418, 275, 16.0, false)
	add_anim(frames, base + "BOSS_1_barrage_transparent.png", "barrage", 6, 243, 321, 12.0, false)
	add_anim(frames, base + "BOSS_1_slam_transparent.png", "slam", 7, 303, 321, 12.0, false)
	
	var err := ResourceSaver.save(frames, "res://scenes/bosses/boss1_frames.tres")
	print("saved err=", err)
	get_tree().quit()

func add_anim(frames: SpriteFrames, path: String, name: String, count: int, fw: int, fh: int, speed: float, loop: bool):
	var tex := load(path)
	if not tex:
		print("missing ", path)
		return
	if not frames.has_animation(name):
		frames.add_animation(name)
	frames.set_animation_speed(name, speed)
	frames.set_animation_loop(name, loop)
	for i in range(count):
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(i * fw, 0, fw, fh)
		frames.add_frame(name, at)
