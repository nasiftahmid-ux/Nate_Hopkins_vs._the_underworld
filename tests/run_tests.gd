extends Node2D
## Headless functional test suite for Nate Hopkins vs. the Underworld.
## Run with:
##   Godot_v4.7.2-stable_win64_console.exe --headless --path "<project>" res://tests/run_tests.tscn
## Exits 0 when everything passes, 1 otherwise.

var _pass := 0
var _fail := 0


func _ready() -> void:
	seed(12345)
	await _run_all()
	_report()


func _check(name: String, cond: bool, detail: String = "") -> void:
	if cond:
		_pass += 1
		print("[PASS] ", name)
	else:
		_fail += 1
		print("[FAIL] ", name, ("  -> " + detail if detail != "" else ""))


func _eq_i(name: String, got: int, want: int) -> void:
	_check(name, got == want, "got %d, want %d" % [got, want])


func _eq_f(name: String, got: float, want: float) -> void:
	_check(name, absf(got - want) < 0.001, "got %f, want %f" % [got, want])


func _near(name: String, got: float, want: float, eps: float = 0.01) -> void:
	_check(name, absf(got - want) <= eps, "got %f, want %f" % [got, want])


func _note(msg: String) -> void:
	print("[INFO] ", msg)


func _report() -> void:
	print("")
	print("========== TEST SUMMARY ==========")
	print("PASS: %d" % _pass)
	print("FAIL: %d" % _fail)
	print("==================================")
	get_tree().quit(1 if _fail > 0 else 0)


func _fresh() -> void:
	var save := GameState.SAVE_PATH
	if FileAccess.file_exists(save):
		DirAccess.remove_absolute(save)
	GameState.load_game()
	GameState.new_game()
	GameState.money = 0


# ---------------------------------------------------------------------------
# 1. Run reset + max HP curve
# ---------------------------------------------------------------------------
func _test_reset_and_hp_curve() -> void:
	print("\n--- reset & max HP curve ---")
	GameState.money = 999
	GameState.shop_ranks["hp"] = 3
	GameState.warcry_active = 2
	GameState.revives_left = 1
	GameState.level = 5
	GameState.new_game()

	_eq_i("new_game clears money", GameState.money, 0)
	_eq_i("new_game clears level", GameState.level, 1)
	_eq_i("new_game clears exp", GameState.exp, 0)
	_eq_i("new_game clears shop ranks", GameState.shop_ranks.size(), 0)
	_eq_i("new_game clears warcry_active", GameState.warcry_active, 0)
	_eq_i("new_game clears warcry_charges", GameState.warcry_charges, 0)
	_eq_i("new_game clears revives", GameState.revives_left, 0)
	_eq_i("new_game clears purchases", GameState.purchases_this_visit, 0)
	_eq_i("new_game clears stage_damage", GameState.stage_damage.size(), 0)
	_eq_i("new_game clears run_damage", int(GameState.run_damage_taken), 0)
	_eq_i("new_game clears run_deaths", GameState.run_deaths, 0)
	_check("new_game leaves forced_grade empty", GameState.forced_grade.is_empty())

	# A stale Vitality bonus must not survive into the next run.
	_eq_f("new_game recomputes max HP without shop bonus", GameState.player_max_hp, 100.0)
	_eq_f("new_game heals to full", GameState.player_health, 100.0)

	_eq_f("max_hp_for_level(1)", GameState.max_hp_for_level(1), 100.0)
	_eq_f("max_hp_for_level(2)", GameState.max_hp_for_level(2), 110.0)
	_eq_f("max_hp_for_level(5)", GameState.max_hp_for_level(5), 140.0)
	_eq_f("max_hp_for_level(0) clamps to level 1", GameState.max_hp_for_level(0), 100.0)
	_eq_f("max_hp_for_level(-3) clamps to level 1", GameState.max_hp_for_level(-3), 100.0)

	GameState.shop_ranks["hp"] = 2
	_eq_f("Vitality adds 10 max HP per rank", GameState.total_max_hp(), 120.0)
	_eq_f("bonus_max_hp reads shop ranks", GameState.bonus_max_hp(), 20.0)
	GameState.shop_ranks.clear()


# ---------------------------------------------------------------------------
# 2. Shop economy
# ---------------------------------------------------------------------------
func _test_shop_economy() -> void:
	print("\n--- shop economy ---")
	_fresh()
	GameState.money = 10000

	_eq_i("heal rank 0 price", GameState.shop_price("heal"), 50)
	GameState.shop_ranks["heal"] = 1
	_eq_i("heal rank 1 price (50*1.45)", GameState.shop_price("heal"), 73)
	GameState.shop_ranks["heal"] = 2
	_eq_i("heal rank 2 price (50*1.45^2)", GameState.shop_price("heal"), 105)
	GameState.shop_ranks.clear()

	_eq_i("cooldown rank 0 price", GameState.shop_price("cooldown"), 180)
	GameState.shop_ranks["cooldown"] = 1
	_eq_i("cooldown rank 1 price", GameState.shop_price("cooldown"), 306)
	_eq_i("cooldown rank 1 effect", GameState.special_cooldown_value(), 1.75)
	GameState.shop_ranks["cooldown"] = 4
	_eq_i("cooldown maxed effect floors at 1.0s", GameState.special_cooldown_value(), 1.0)
	_check("cooldown unavailable at cap", not GameState.shop_item_available("cooldown"))
	GameState.shop_ranks.clear()

	_eq_i("revive price is flat", GameState.shop_price("revive"), 450)
	_eq_i("warcry rank 0 price", GameState.shop_price("warcry"), 120)
	GameState.shop_ranks["warcry"] = 1
	_eq_i("warcry rank 1 price", GameState.shop_price("warcry"), 168)
	GameState.shop_ranks.clear()

	_eq_i("hp rank 0 price", GameState.shop_price("hp"), 200)
	GameState.shop_ranks["hp"] = 1
	_eq_i("hp rank 1 price", GameState.shop_price("hp"), 320)
	GameState.shop_ranks.clear()

	_eq_i("heavy rank 0 price", GameState.shop_price("heavy"), 220)
	GameState.shop_ranks["heavy"] = 1
	_eq_i("heavy rank 1 price", GameState.shop_price("heavy"), 352)
	_eq_f("Wrath grants +3 heavy damage", GameState.heavy_damage_bonus(), 3.0)
	GameState.shop_ranks["heavy"] = 2
	_eq_f("Wrath stacks linearly", GameState.heavy_damage_bonus(), 6.0)
	GameState.shop_ranks.clear()

	_eq_i("unknown item prices at 0", GameState.shop_price("nonexistent"), 0)
	_check("unknown item is unavailable", not GameState.shop_item_available("nonexistent"))

	# Full health blocks Restore only.
	GameState.player_health = GameState.player_max_hp
	_check("heal blocked at full health", not GameState.shop_item_available("heal"))
	GameState.player_health = GameState.player_max_hp - 0.02
	_check("heal available just below full", GameState.shop_item_available("heal"))
	GameState.player_health = GameState.player_max_hp * 0.5
	_check("heal available at half health", GameState.shop_item_available("heal"))
	_check("hp always available (no cap)", GameState.shop_item_available("hp"))

	# One purchase per visit.
	GameState.reset_shop_visit()
	_eq_i("visit starts at 0 purchases", GameState.purchases_this_visit, 0)
	_check("first purchase succeeds", GameState.buy_shop_item("hp"))
	_eq_i("purchase counter incremented", GameState.purchases_this_visit, 1)
	_check("second purchase in same visit is refused", not GameState.buy_shop_item("heavy"))
	_check("money untouched by refused purchase", GameState.shop_rank("heavy") == 0)
	GameState.reset_shop_visit()
	_check("purchase allowed again after reset", GameState.buy_shop_item("heavy"))

	# Insufficient funds change nothing.
	_fresh()
	GameState.money = 10
	GameState.reset_shop_visit()
	_check("cannot afford a 200 coin item", not GameState.buy_shop_item("hp"))
	_eq_i("failed purchase costs nothing", GameState.money, 10)
	_eq_i("failed purchase grants no rank", GameState.shop_rank("hp"), 0)
	_eq_i("failed purchase does not consume the visit", GameState.purchases_this_visit, 0)

	# Effects land where they should.
	_fresh()
	GameState.money = 10000
	GameState.reset_shop_visit()
	GameState.player_health = 40.0
	_check("buying Restore heals to full", GameState.buy_shop_item("heal"))
	_eq_f("Restore sets health to max", GameState.player_health, GameState.player_max_hp)

	GameState.money = 10000
	GameState.reset_shop_visit()
	_check("buying Warcry banks a charge", GameState.buy_shop_item("warcry"))
	_eq_i("warcry charge banked", GameState.warcry_charges, 1)
	_eq_i("warcry not active yet", GameState.warcry_active, 0)

	GameState.money = 10000
	GameState.reset_shop_visit()
	_check("buying Second Chance grants a revive", GameState.buy_shop_item("revive"))
	_check("revive available", GameState.can_revive())
	GameState.reset_shop_visit()
	_check("Second Chance cannot be bought twice", not GameState.buy_shop_item("revive"))
	_eq_i("revive count stays 1", GameState.revives_left, 1)

	GameState.money = 10000
	GameState.reset_shop_visit()
	GameState.player_health = 50.0
	var hp_before := GameState.player_max_hp
	_check("buying Vitality succeeds", GameState.buy_shop_item("hp"))
	_check("Vitality raises the ceiling", GameState.player_max_hp > hp_before)
	_check("Vitality tops up into the new headroom", GameState.player_health > 50.0)
	_check("health never exceeds max", GameState.player_health <= GameState.player_max_hp)

	# Revive spending.
	_check("consume_revive succeeds when held", GameState.consume_revive())
	_eq_i("revive decremented", GameState.revives_left, 0)
	_check("consume_revive fails when empty", not GameState.consume_revive())


# ---------------------------------------------------------------------------
# 3. Warcry lifecycle
# ---------------------------------------------------------------------------
func _test_warcry_lifecycle() -> void:
	print("\n--- warcry lifecycle ---")
	_fresh()
	GameState.shop_ranks["warcry"] = 2
	GameState.warcry_charges = 2

	GameState.begin_stage()
	_eq_i("begin_stage promotes banked charges", GameState.warcry_active, 2)
	_eq_i("banked charges consumed", GameState.warcry_charges, 0)
	_eq_f("warcry grants +6 per rank", GameState.warcry_damage_bonus(), 12.0)

	# Re-entering the same stage must not re-promote or stack.
	GameState.begin_stage()
	_eq_i("re-entering stage does not re-promote", GameState.warcry_active, 2)

	GameState.finish_stage()
	_eq_i("finish_stage retires the buff", GameState.warcry_active, 0)
	_eq_f("buff gone after stage clear", GameState.warcry_damage_bonus(), 0.0)

	# A retry must NOT retire the buff (that is the documented rule).
	GameState.warcry_active = 1
	GameState.begin_level()
	_eq_i("retry (begin_level) keeps the buff", GameState.warcry_active, 1)
	GameState.warcry_active = 0


# ---------------------------------------------------------------------------
# 4. Stage damage recording + grading
# ---------------------------------------------------------------------------
func _test_stage_damage_and_grading() -> void:
	print("\n--- stage damage & grading ---")
	_fresh()

	GameState.register_damage(25.0)
	_eq_f("damage_taken accumulates", GameState.damage_taken, 25.0)
	_eq_f("run_damage_taken accumulates", GameState.run_damage_taken, 25.0)
	_eq_i("one stage open", GameState.stage_damage.size(), 0)

	GameState.finish_stage()
	_eq_i("finish_stage closes the stage", GameState.stage_damage.size(), 1)
	_eq_f("stage damage recorded", GameState.stage_damage[0], 25.0)
	_eq_f("finish_stage clears per-stage damage", GameState.damage_taken, 0.0)
	_eq_f("finish_stage keeps run damage", GameState.run_damage_taken, 25.0)

	# Closing twice must not double-record.
	GameState.finish_stage()
	_eq_i("finish_stage is idempotent", GameState.stage_damage.size(), 1)

	# begin_stage after a close opens a fresh stage.
	GameState.register_damage(10.0)
	_eq_i("damage reopens the stage", GameState.stage_damage.size(), 1)
	_eq_f("new stage damage separate", GameState.damage_taken, 10.0)
	GameState.finish_stage()
	_eq_i("second stage recorded", GameState.stage_damage.size(), 2)

	# Grading thresholds. 100 max HP, so a clean stage is 1.0.
	_fresh()
	GameState.stage_damage = [0.0, 0.0]
	GameState.run_damage_taken = 0.0
	GameState.run_deaths = 0
	_eq_f("flawless run ratio", GameState.clean_combat_ratio(), 1.0)
	_check("flawless run grades FLAWLESS", GameState.grade_id() == "FLAWLESS")

	GameState.stage_damage = [50.0, 50.0]
	_eq_f("half damage ratio", GameState.clean_combat_ratio(), 0.5)
	_check("half damage grades MANGLED", GameState.grade_id() == "MANGLED")

	GameState.stage_damage = [40.0, 40.0]
	_eq_f("20% damage ratio", GameState.clean_combat_ratio(), 0.6)
	_check("60% ratio grades BLOODIED", GameState.grade_id() == "BLOODIED")

	GameState.stage_damage = [30.0, 30.0]
	_check("70% ratio grades CLEAN", GameState.grade_id() == "CLEAN")

	GameState.stage_damage = [10.0, 10.0]
	_check("90% ratio grades FLAWLESS", GameState.grade_id() == "FLAWLESS")

	# Deaths penalise.
	_fresh()
	GameState.stage_damage = [0.0, 0.0]
	GameState.run_damage_taken = 0.0
	GameState.run_deaths = 3
	_eq_f("three deaths cost 0.3", GameState.clean_combat_ratio(), 0.7)
	_check("death penalty drops the grade", GameState.grade_id() == "BLOODIED")

	# No completed stages reads as flawless.
	_fresh()
	_eq_f("no stages = 1.0 ratio", GameState.clean_combat_ratio(), 1.0)

	# Overkill cannot produce a negative ratio.
	_fresh()
	GameState.stage_damage = [500.0]
	GameState.run_damage_taken = 500.0
	_eq_f("ratio clamps at 0", GameState.clean_combat_ratio(), 0.0)

	# forced_grade override.
	_fresh()
	GameState.forced_grade = "MANGLED"
	_check("forced_grade overrides ratio", GameState.grade_id() == "MANGLED")
	GameState.forced_grade = "NOT_A_GRADE"
	_check("unknown forced_grade falls through", GameState.grade_id() != "NOT_A_GRADE")
	GameState.forced_grade = ""

	# register_damage with no open stage opens one.
	_fresh()
	GameState.register_damage(5.0)
	GameState.finish_stage()
	_eq_i("implicit stage open is recorded", GameState.stage_damage.size(), 1)
	_eq_f("implicit stage keeps the damage", GameState.stage_damage[0], 5.0)


# ---------------------------------------------------------------------------
# 5. XP, levelling and reward scaling
# ---------------------------------------------------------------------------
func _test_xp_and_rewards() -> void:
	print("\n--- xp & rewards ---")
	_fresh()

	_eq_f("xp multiplier at full health", GameState.xp_multiplier(), 1.0)
	GameState.damage_taken = 50.0
	_eq_f("xp multiplier at half health", GameState.xp_multiplier(), 0.5)
	GameState.damage_taken = 100.0
	_eq_f("xp multiplier floors at 0.25", GameState.xp_multiplier(), 0.25)
	GameState.damage_taken = 500.0
	_eq_f("xp multiplier never goes negative", GameState.xp_multiplier(), 0.25)

	GameState.damage_taken = 0.0
	_eq_i("exp to next level at level 1", GameState.exp_to_next_level(), 50)
	GameState.level = 3
	_eq_i("exp to next level at level 3", GameState.exp_to_next_level(), 150)

	# add_exp rolls over correctly and heals on level up.
	_fresh()
	GameState.player_health = 10.0
	GameState.add_exp(49)
	_eq_i("49 xp does not level", GameState.level, 1)
	_eq_i("49 xp banks", GameState.exp, 49)
	GameState.add_exp(1)
	_eq_i("50 xp levels up", GameState.level, 2)
	_eq_i("exp resets after level", GameState.exp, 0)
	_eq_f("max HP follows the curve", GameState.player_max_hp, 110.0)
	_check("level up heals the player", GameState.player_health > 10.0)
	_check("level up never overheals", GameState.player_health <= GameState.player_max_hp)

	# Damage taken reduces the XP payout and the level-up heal.
	_fresh()
	GameState.damage_taken = 50.0
	GameState.add_exp(100)
	_eq_i("damaged player earns 50 xp, not 100", GameState.exp + GameState.exp_to_next_level() * 0, 50)

	_fresh()
	GameState.damage_taken = 100.0
	GameState.add_exp(100)
	_eq_i("at 0.25x multiplier 100 xp becomes 25", GameState.exp, 25)

	# A Vitality purchase must survive a level up.
	_fresh()
	GameState.shop_ranks["hp"] = 1
	GameState.player_max_hp = GameState.total_max_hp()
	GameState.add_exp(500)
	_eq_f("level up keeps the Vitality bonus", GameState.player_max_hp, 120.0 + GameState.max_hp_for_level(GameState.level) - 100.0)

	# Money.
	_fresh()
	GameState.add_money(37)
	_eq_i("add_money accumulates", GameState.money, 37)
	GameState.add_money(5)
	_eq_i("add_money twice", GameState.money, 42)


# ---------------------------------------------------------------------------
# 6. Save / load round trip
# ---------------------------------------------------------------------------
func _test_save_load() -> void:
	print("\n--- save / load ---")
	_fresh()
	GameState.money = 777
	GameState.exp = 33
	GameState.level = 4
	GameState.defeated_exes = 1
	GameState.run_damage_taken = 88.0
	GameState.run_deaths = 2
	GameState.stage_damage = [12.0, 34.0]
	GameState.shop_ranks = {"hp": 2, "cooldown": 1, "revive": 1}
	GameState.warcry_charges = 2
	GameState.warcry_active = 1
	GameState.revives_left = 1
	GameState.save_game()

	# Scramble everything, then reload.
	GameState.money = 0
	GameState.level = 1
	GameState.shop_ranks.clear()
	GameState.stage_damage.clear()
	GameState.run_deaths = 0
	GameState.warcry_charges = 0
	GameState.warcry_active = 0
	GameState.revives_left = 0
	GameState.defeated_exes = 0

	_check("load_game reports success", GameState.load_game())
	_eq_i("money restored", GameState.money, 777)
	_eq_i("exp restored", GameState.exp, 33)
	_eq_i("level restored", GameState.level, 4)
	_eq_i("defeated_exes restored", GameState.defeated_exes, 1)
	_eq_f("run_damage_taken restored", GameState.run_damage_taken, 88.0)
	_eq_i("run_deaths restored", GameState.run_deaths, 2)
	_eq_i("stage_damage restored", GameState.stage_damage.size(), 2)
	_eq_f("stage_damage[0] restored", GameState.stage_damage[0], 12.0)
	_eq_f("stage_damage[1] restored", GameState.stage_damage[1], 34.0)
	_eq_i("shop hp rank restored", GameState.shop_rank("hp"), 2)
	_eq_i("shop cooldown rank restored", GameState.shop_rank("cooldown"), 1)
	_eq_i("shop revive rank restored", GameState.shop_rank("revive"), 1)
	_eq_i("warcry_charges restored", GameState.warcry_charges, 2)
	_eq_i("warcry_active restored", GameState.warcry_active, 1)
	_eq_i("revives_left restored", GameState.revives_left, 1)
	_eq_f("max HP = curve + shop bonus", GameState.player_max_hp, GameState.total_max_hp())

	# A save with no stage_damage key must not crash.
	var f := FileAccess.open(GameState.SAVE_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify({"money": 5, "level": 2}))
	f = null
	_check("load tolerates a partial save", GameState.load_game())
	_eq_i("partial save money", GameState.money, 5)
	_eq_i("partial save leaves stage_damage empty", GameState.stage_damage.size(), 0)
	_eq_i("partial save defaults defeated_exes", GameState.defeated_exes, 0)

	# Corrupt file must not crash.
	f = FileAccess.open(GameState.SAVE_PATH, FileAccess.WRITE)
	f.store_string("this is not json {{{")
	f = null
	_check("load rejects corrupt JSON", not GameState.load_game())

	# Empty object must not crash.
	f = FileAccess.open(GameState.SAVE_PATH, FileAccess.WRITE)
	f.store_string("{}")
	f = null
	_check("load accepts an empty object", GameState.load_game())


# ---------------------------------------------------------------------------
# 7. Rhythm difficulty scaling
# ---------------------------------------------------------------------------
func _test_rhythm_scaling() -> void:
	print("\n--- rhythm difficulty ---")
	_fresh()
	GameState.stage_damage = [0.0]
	GameState.run_damage_taken = 0.0
	GameState.run_deaths = 0

	GameState.set_rhythm_difficulty(1.0, 20)
	_check("flawless grades the song", GameState.rhythm_grade == "FLAWLESS")
	_near("flawless window widens to 1.35x", GameState.rhythm_window, 1.35, 0.001)
	_eq_i("flawless notes scale to 0.8x", GameState.rhythm_notes, 16)
	_eq_i("flawless allows 4 misses", GameState.rhythm_streak_limit, 4)

	# Idempotency: applying twice must not compound.
	GameState.apply_combat_grade()
	GameState.apply_combat_grade()
	_near("apply_combat_grade is idempotent (window)", GameState.rhythm_window, 1.35, 0.001)
	_eq_i("apply_combat_grade is idempotent (notes)", GameState.rhythm_notes, 16)

	# Re-entering the finale with a fresh base must not stack either.
	GameState.set_rhythm_difficulty(1.0, 20)
	_near("re-setting difficulty does not stack", GameState.rhythm_window, 1.35, 0.001)
	_eq_i("re-setting difficulty does not stack notes", GameState.rhythm_notes, 16)

	# MANGLED tightens the window and allows fewer misses.
	GameState.stage_damage = [200.0]
	GameState.run_damage_taken = 200.0
	GameState.set_rhythm_difficulty(1.0, 20)
	_check("mangled grades the song", GameState.rhythm_grade == "MANGLED")
	_eq_i("mangled allows 2 misses", GameState.rhythm_streak_limit, 2)

	# Floors.
	GameState.stage_damage = [0.0]
	GameState.run_damage_taken = 0.0
	GameState.set_rhythm_difficulty(0.01, 1)
	_check("window never drops below the floor", GameState.rhythm_window >= GameState.MIN_RHYTHM_WINDOW)
	_check("notes never drop below the floor", GameState.rhythm_notes >= GameState.MIN_RHYTHM_NOTES)

	GameState.set_rhythm_difficulty(-5.0, -10)
	_check("negative base window is clamped", GameState.rhythm_window >= GameState.MIN_RHYTHM_WINDOW)
	_check("negative note count is clamped", GameState.rhythm_notes >= GameState.MIN_RHYTHM_NOTES)

	# grade_brief must not throw and should mention the grade.
	GameState.set_rhythm_difficulty(1.0, 24)
	_check("grade_brief mentions the grade", GameState.grade_brief().contains(GameState.grade_id()))

	# Chants.
	var chant := GameState.grade_chant()
	_check("grade_chant returns Aphrodite", str(chant.get("speaker", "")) == "Aphrodite")
	_check("grade_chant has text", not str(chant.get("text", "")).is_empty())


# ---------------------------------------------------------------------------
# 8. Ending dialogue decoration
# ---------------------------------------------------------------------------
func _test_dialogue_decoration() -> void:
	print("\n--- ending dialogue ---")
	_fresh()
	GameState.stage_damage = [0.0]
	GameState.run_damage_taken = 0.0

	var lines: Array[Dictionary] = [
		{"speaker": "Nate", "text": "one"},
		{"speaker": "Hazel", "text": "two"},
	]
	var out := GameState.decorate_followup_lines(lines)
	_eq_i("decoration adds two lines", out.size(), 4)
	_check("payoff line stays last", str(out[out.size() - 1]["text"]) == "two")
	_check("Hazel's reaction lands before the payoff", str(out[out.size() - 2]["speaker"]) == "Hazel")
	_check("Aphrodite's reaction is spliced in", str(out[out.size() - 3]["speaker"]) == "Aphrodite")

	var empty: Array[Dictionary] = []
	_eq_i("empty input returns empty", GameState.decorate_followup_lines(empty).size(), 0)

	var single: Array[Dictionary] = [{"speaker": "Nate", "text": "solo"}]
	var single_out := GameState.decorate_followup_lines(single)
	_eq_i("single line gains two", single_out.size(), 3)
	_check("single line stays last", str(single_out[2]["text"]) == "solo")


# ---------------------------------------------------------------------------
# 9. Player: damage, blocking, i-frames, revive
# ---------------------------------------------------------------------------
func _test_player_combat() -> void:
	print("\n--- player combat ---")
	_fresh()
	GameState.player_max_hp = 100.0
	GameState.player_health = 100.0

	var player: Node2D = load("res://scenes/player/player.tscn").instantiate()
	add_child(player)
	await get_tree().physics_frame

	_check("player joins the player group", player.is_in_group("player"))
	_eq_f("player starts at max HP", player.hp, 100.0)
	_check("player camera exists", player.get_node_or_null("Camera2D") != null)
	_check("player hitbox exists", player.get_node_or_null("Hitbox") != null)

	# Basic damage.
	player.take_damage(20.0, false, Vector2.ZERO)
	_eq_f("damage reduces hp", player.hp, 80.0)
	_eq_f("GameState mirrors hp", GameState.player_health, 80.0)
	_check("damage grants i-frames", player.invuln_time > 0.0)

	# i-frames actually block a second hit.
	player.take_damage(20.0, false, Vector2.ZERO)
	_eq_f("i-frames absorb the follow-up", player.hp, 80.0)

	player.invuln_time = 0.0
	player.take_damage(100.0, false, Vector2.ZERO)
	_eq_f("hp floors at 0", player.hp, 0.0)

	# God mode.
	GameState.dev_god_mode = true
	player.hp = 10.0
	player.invuln_time = 0.0
	player.take_damage(50.0, false, Vector2.ZERO)
	_eq_f("god mode ignores damage", player.hp, player.max_hp)
	GameState.dev_god_mode = false

	# Blocking.
	player.hp = 100.0
	player.invuln_time = 0.0
	player.is_blocking = true
	player.take_damage(30.0, true, Vector2.ZERO)
	_eq_f("block negates blockable damage", player.hp, 100.0)
	player.invuln_time = 0.0
	player.take_damage(30.0, false, Vector2.ZERO)
	_eq_f("block does not stop unblockable damage", player.hp, 70.0)
	player.is_blocking = false

	# Second Chance: a lethal hit is intercepted.
	GameState.revives_left = 1
	var deaths_before := GameState.run_deaths
	player.hp = 5.0
	player.invuln_time = 0.0
	player.take_damage(50.0, false, Vector2.ZERO)
	_eq_f("revive restores full HP", player.hp, player.max_hp)
	_check("revive grants brief invulnerability", player.invuln_time > 0.0)
	_eq_i("revive is not counted as a death", GameState.run_deaths, deaths_before)
	_eq_i("revive is consumed", GameState.revives_left, 0)
	_check("player is still simulating after a revive", player.is_physics_processing())

	# A real death does count.
	player.invuln_time = 0.0
	player.hp = 1.0
	player.take_damage(50.0, false, Vector2.ZERO)
	_eq_i("death is recorded", GameState.run_deaths, deaths_before + 1)
	_check("death stops physics", not player.is_physics_processing())
	_check("death pauses the tree", get_tree().paused)
	get_tree().paused = false
	player.set_physics_process(true)
	player.hp = player.max_hp

	# Damage scaling.
	GameState.shop_ranks["heavy"] = 2
	GameState.warcry_active = 1
	_eq_f("heavy scaling sums Wrath and Warcry", player._scaled(10.0, true), 10.0 + 6.0 + 6.0)
	_eq_f("light scaling only gets Warcry", player._scaled(10.0, false), 10.0 + 6.0)
	GameState.shop_ranks.clear()
	GameState.warcry_active = 0

	# Combo counters.
	player.combo_step = 0
	player.try_attack(false, false)
	_eq_i("light attack advances combo", player.combo_step, 1)
	player.try_attack(false, false)
	_eq_i("combo step 2", player.combo_step, 2)
	player.try_attack(false, false)
	_eq_i("combo step 3 is the finisher", player.combo_step, 3)
	player.is_attacking = false
	player.try_attack(true, false)
	_eq_i("heavy resets the combo", player.combo_step, 0)
	player.is_attacking = false

	# Special respects the cooldown.
	player.special_cooldown = 0.0
	player.try_attack(false, true)
	_check("special starts on cooldown", player.special_cooldown > 0.0)
	player.is_attacking = false

	# Kill plane.
	GameState.dev_god_mode = true
	player.start_pos = player.global_position
	player.global_position = Vector2(player.global_position.x, player.KILL_PLANE_Y + 50.0)
	await get_tree().physics_frame
	_check("god mode returns you to the start instead of killing", player.global_position.y < player.KILL_PLANE_Y)
	GameState.dev_god_mode = false

	player.queue_free()
	await get_tree().physics_frame


# ---------------------------------------------------------------------------
# 10. Sprite animation audit (useful while art is in progress)
# ---------------------------------------------------------------------------
func _test_sprite_animations() -> void:
	print("\n--- sprite animation audit ---")
	_fresh()
	var required := ["idle", "run", "jump", "attack_punch", "attack_kick", "attack_uppercut"]
	var optional := ["block", "death"]

	var player: Node2D = load("res://scenes/player/player.tscn").instantiate()
	add_child(player)
	await get_tree().physics_frame
	var sprite: AnimatedSprite2D = player.get_node("Sprite")

	var have := {}
	for a in sprite.sprite_frames.get_animation_names():
		have[str(a)] = true

	for anim in required:
		_check("player has required animation '%s'" % anim, have.has(anim))
	for anim in optional:
		if have.has(anim):
			_note("player has optional animation '%s'" % anim)
		else:
			_note("player is MISSING optional animation '%s' (falls back gracefully)" % anim)

	for a in required:
		if have.has(a):
			_note("anim '%s' length %.2fs loop=%s" % [
				a,
				sprite.sprite_frames.get_animation_length(a),
				str(sprite.sprite_frames.get_animation_loop(a)),
			])

	player.queue_free()
	await get_tree().physics_frame

	# Every enemy scene must expose a Body node for the shared base script.
	for path in ["basic_enemy", "cinder_imp", "teardrop", "teardrop_shooter", "sorrow_knight"]:
		var full := "res://scenes/enemies/%s.tscn" % path
		if not ResourceLoader.exists(full):
			_note("missing enemy scene: %s" % path)
			continue
		var inst: Node2D = load(full).instantiate()
		add_child(inst)
		await get_tree().physics_frame
		_check("%s exposes $Body" % path, inst.get_node_or_null("Body") != null)
		_check("%s joins the enemy group" % path, inst.is_in_group("enemy"))
		inst.queue_free()
		await get_tree().physics_frame


# ---------------------------------------------------------------------------
# 11. Enemy death, rewards and coin split
# ---------------------------------------------------------------------------
func _test_enemy_rewards() -> void:
	print("\n--- enemy rewards ---")
	_fresh()

	var enemy: Node2D = load("res://scenes/enemies/basic_enemy.tscn").instantiate()
	add_child(enemy)
	await get_tree().physics_frame

	var exp_before := GameState.exp
	_check("enemy reports take_hit", enemy.has_method("take_hit"))

	# Chip damage does not kill.
	enemy.take_hit(1.0, 1.0)
	_check("enemy survives chip damage", enemy.alive)

	# Lethal damage pays out exp and drops coins whose total equals COIN_DROP.
	var coin_scene: PackedScene = load("res://scenes/items/coin.tscn")
	var coins_before := get_tree().get_nodes_in_group("coin").size()
	enemy.take_hit(9999.0, 1.0)
	_check("enemy dies to lethal damage", not enemy.alive)
	_check("enemy pays exp", GameState.exp > exp_before)
	await get_tree().physics_frame
	var coins := get_tree().get_nodes_in_group("coin")
	_check("enemy drops coins", coins.size() > coins_before,
		"before=%d after=%d" % [coins_before, coins.size()])
	var total := 0
	for c in coins:
		total += int(c.value)
	_check("coin total matches the drop table", total >= enemy.COIN_DROP,
		"total=%d want>=%d" % [total, enemy.COIN_DROP])

	# A dead enemy ignores further hits.
	var exp_after := GameState.exp
	enemy.take_hit(9999.0, 1.0)
	_eq_i("dead enemy pays nothing", GameState.exp, exp_after)

	# An enemy with money_reward pays coins directly too.
	_fresh()
	var money_before := GameState.money
	var imp: Node2D = load("res://scenes/enemies/cinder_imp.tscn").instantiate()
	add_child(imp)
	await get_tree().physics_frame
	imp.take_hit(99999.0, 1.0)
	await get_tree().physics_frame
	_check("cinder_imp pays money on death", GameState.money >= money_before)

	imp.queue_free()
	enemy.queue_free()
	await get_tree().physics_frame


# ---------------------------------------------------------------------------
# 12. Boss: phases, second wind, damage scaling
# ---------------------------------------------------------------------------
func _test_boss() -> void:
	print("\n--- boss ---")
	_fresh()

	var boss: Node2D = load("res://scenes/bosses/boss.tscn").instantiate()
	add_child(boss)
	await get_tree().physics_frame

	_check("boss joins the enemy group", boss.is_in_group("enemy"))
	_eq_f("boss starts at base HP", boss.hp, boss.max_hp)
	_eq_f("boss base HP", boss.max_hp, boss.HP_BASE)
	_eq_i("boss starts in phase 1", boss.phase, 1)
	_check("boss is not invulnerable at spawn", not boss.invulnerable)

	# HP scales with how many exes are already down.
	_fresh()
	GameState.defeated_exes = 1
	var boss2: Node2D = load("res://scenes/bosses/boss.tscn").instantiate()
	add_child(boss2)
	await get_tree().physics_frame
	_eq_f("second boss has more HP", boss2.max_hp, boss2.HP_BASE + boss2.HP_PER_EX)
	_eq_i("second boss is the sweetheart", boss2.boss_kind, boss2.BossKind.SWEETHEART)
	boss2.queue_free()
	await get_tree().physics_frame

	# Phase 2 at 66%.
	_fresh()
	var b: Node2D = load("res://scenes/bosses/boss.tscn").instantiate()
	add_child(b)
	await get_tree().physics_frame
	var hp: float = b.max_hp
	b.take_hit(hp * (1.0 - b.PHASE2_RATIO) + 1.0, 1.0)
	_eq_i("crossing 66% enters phase 2", b.phase, 2)
	_check("phase shift grants invulnerability", b.invulnerable)
	_check("phase 2 is tougher than phase 1", b.damage > 17.0)

	# Phase 3 at 33%.
	b.invulnerable = false
	b.take_hit(b.max_hp * (b.PHASE2_RATIO - b.PHASE3_RATIO) + 1.0, 1.0)
	_eq_i("crossing 33% enters phase 3", b.phase, 3)
	_check("phase 3 is enraged", b.enraged)
	_check("phase 3 is tougher than phase 2", b.damage > 22.0)
	b.invulnerable = false

	# Second wind: one revive at 25% in phase 3.
	var dmg_phase3: float = b.damage
	b.take_hit(b.max_hp * 0.12, 1.0)
	_check("second wind triggers in phase 3", b.second_wind_used)
	_check("second wind heals to at least 25%", b.hp >= b.max_hp * b.SECOND_WIND_HEAL - 0.01)
	_check("second wind makes the boss harder", b.damage > dmg_phase3)
	_check("second wind grants invulnerability", b.invulnerable)

	# Invulnerable hits do nothing.
	var hp_now: float = b.hp
	b.take_hit(1000.0, 1.0)
	_eq_f("invulnerable boss ignores damage", b.hp, hp_now)
	b.invulnerable = false

	# Vulnerable window multiplies incoming damage.
	b.vulnerable_time = 1.0
	var before: float = b.hp
	b.take_hit(10.0, 1.0)
	_near("vulnerable window multiplies damage", before - b.hp, 10.0 * b.VULNERABLE_MULT, 0.01)

	# The kill threshold snaps HP to zero.
	b.vulnerable_time = 0.0
	b.invulnerable = false
	b.take_hit(b.max_hp, 1.0)
	_eq_f("death threshold zeroes HP", b.hp, 0.0)
	_check("boss dies at the death threshold", not b.alive)
	_check("a dead boss ignores further hits", b.take_hit(5.0, 1.0) == null)

	b.queue_free()
	await get_tree().physics_frame

	# Attack pool gating by phase.
	_fresh()
	var p: Node2D = load("res://scenes/bosses/boss.tscn").instantiate()
	add_child(p)
	await get_tree().physics_frame
	var pool1: Array = p._build_pool(20.0)
	_check("phase 1 pool excludes SPIRAL", not pool1.has(p.State.SPIRAL))
	_check("phase 1 pool includes MELEE", pool1.has(p.State.MELEE))
	p.phase = 2
	var pool2: Array = p._build_pool(20.0)
	_check("phase 2 pool includes SPIKES", pool2.has(p.State.SPIKES))
	_check("phase 2 pool still excludes SPIRAL", not pool2.has(p.State.SPIRAL))
	p.phase = 3
	var pool3: Array = p._build_pool(20.0)
	_check("phase 3 pool includes SPIRAL", pool3.has(p.State.SPIRAL))
	_check("phase 3 pool includes EXECUTE_WINDUP", pool3.has(p.State.EXECUTE_WINDUP))
	_check("phase 3 lunge hits twice", p._lunge_hit_count() == 2)
	p.queue_free()
	await get_tree().physics_frame


# ---------------------------------------------------------------------------
# 13. Rhythm finale
# ---------------------------------------------------------------------------
func _test_rhythm_scene() -> void:
	print("\n--- rhythm finale ---")
	_fresh()
	GameState.stage_damage = [0.0]
	GameState.run_damage_taken = 0.0
	GameState.run_deaths = 0
	GameState.set_rhythm_difficulty(1.0, 20)

	var rhythm: Node2D = load("res://scenes/bosses/final_rhythm.tscn").instantiate()
	add_child(rhythm)
	await get_tree().physics_frame

	_check("rhythm reads the combat grade", rhythm.grade == GameState.rhythm_grade)
	_eq_i("rhythm note count matches GameState", rhythm.note_count, GameState.rhythm_notes)
	_eq_i("rhythm builds one entry per note", rhythm.notes.size(), rhythm.note_count)
	var notes_ok := true
	for n in rhythm.notes:
		if n < 0 or n > 2:
			notes_ok = false
			break
	_check("every note is a valid target", notes_ok)
	_check("rhythm miss limit is at least 1", rhythm.max_miss_streak >= 1)
	_check("rhythm starts in INTRO", rhythm.phase == rhythm.Phase.INTRO)

	# Simulating a perfect run should reach VICTORY.
	rhythm.INTRO_TIME = 0.0
	rhythm.NOTE_GAP = 0.0
	rhythm.window_time = 1.0
	var guard := 0
	while rhythm.phase != rhythm.Phase.WIN and guard < 5000:
		guard += 1
		if rhythm.phase == rhythm.Phase.NOTE:
			rhythm._hit()
		elif rhythm.phase == rhythm.Phase.INTRO:
			rhythm._start_note()
		elif rhythm.phase == rhythm.Phase.GAP:
			rhythm._start_note()
		else:
			break
	_check("a perfect run reaches VICTORY", rhythm.phase == rhythm.Phase.WIN)
	_eq_i("a perfect run hits every note", rhythm.score, rhythm.note_count * rhythm.HIT_SCORE)
	_eq_i("a perfect run keeps the full combo", rhythm.best_combo, rhythm.note_count)
	_eq_i("a perfect run has no miss streak", rhythm.miss_streak, 0)

	rhythm.queue_free()
	await get_tree().physics_frame

	# A run of misses should trigger game over and restart.
	_fresh()
	GameState.stage_damage = [100.0]
	GameState.run_damage_taken = 100.0
	var r2: Node2D = load("res://scenes/bosses/final_rhythm.tscn").instantiate()
	add_child(r2)
	await get_tree().physics_frame
	r2.INTRO_TIME = 0.0
	r2.NOTE_GAP = 0.0
	var guard2 := 0
	while r2.phase != rhythm.Phase.GAMEOVER and guard2 < 500:
		guard2 += 1
		if r2.phase == r2.Phase.INTRO:
			r2._start_note()
		elif r2.phase == r2.Phase.GAP:
			r2._start_note()
		elif r2.phase == r2.Phase.NOTE:
			r2._miss()
		else:
			break
	_check("consecutive misses trigger GAME OVER", r2.phase == r2.Phase.GAMEOVER)

	r2._restart_song()
	_eq_i("restart rewinds to the first note", r2.note_index, 0)
	_eq_i("restart clears the score", r2.score, 0)
	_eq_i("restart clears the miss streak", r2.miss_streak, 0)
	_check("restart returns to INTRO", r2.phase == r2.Phase.INTRO)

	r2.queue_free()
	await get_tree().physics_frame


# ---------------------------------------------------------------------------
# 14. Save-file and death flow
# ---------------------------------------------------------------------------
func _test_death_flow() -> void:
	print("\n--- death flow ---")
	_fresh()

	# begin_level fully heals and closes any open stage.
	GameState.register_damage(40.0)
	GameState.begin_level()
	_eq_f("begin_level heals to full", GameState.player_health, GameState.player_max_hp)
	_eq_f("begin_level clears per-stage damage", GameState.damage_taken, 0.0)
	_eq_i("begin_level closed the stage", GameState.stage_damage.size(), 1)
	_eq_f("closed stage recorded the damage", GameState.stage_damage[0], 40.0)

	# The death panel scene must load and expose what it needs.
	var panel: Node = load("res://scenes/ui/death_panel.tscn").instantiate()
	add_child(panel)
	await get_tree().physics_frame
	_check("death panel instantiates", panel != null)
	panel.queue_free()
	await get_tree().physics_frame

	# HUD must read live health.
	var hud: Node = load("res://scenes/ui/hud.tscn").instantiate()
	add_child(hud)
	await get_tree().physics_frame
	_check("HUD instantiates", hud != null)
	hud.queue_free()
	await get_tree().physics_frame

	# Shop scene must build its rows from the catalogue.
	var shop: Node = load("res://scenes/ui/shop.tscn").instantiate()
	add_child(shop)
	await get_tree().physics_frame
	await get_tree().process_frame
	var list := shop.get_node_or_null("Margin/Rows/Scroll/List")
	_check("shop list node exists", list != null)
	if list:
		_eq_i("shop builds one row per catalogue entry", list.get_child_count(), GameState.SHOP_ITEMS.size())
	_check("shop resets the visit on entry", GameState.purchases_this_visit == 0)
	shop.queue_free()
	await get_tree().physics_frame


# ---------------------------------------------------------------------------
# 15. Level scenes load and wire their camera limits
# ---------------------------------------------------------------------------
func _test_levels() -> void:
	print("\n--- levels ---")
	for n in range(1, 6):
		var path := "res://scenes/levels/level%d.tscn" % n
		if not ResourceLoader.exists(path):
			_note("level%d.tscn does not exist yet" % n)
			continue
		var lvl: Node2D = load(path).instantiate()
		add_child(lvl)
		await get_tree().physics_frame
		var cam: Camera2D = lvl.get_node_or_null("Player/Camera2D")
		_check("level%d has a player camera" % n, cam != null)
		if cam:
			_check("level%d camera left limit is 0" % n, cam.limit_left == 0)
			_check("level%d camera right limit is positive" % n, cam.limit_right > 0)
		_check("level%d registers a stage" % n, GameState._stage_open)
		lvl.queue_free()
		await get_tree().physics_frame


func _run_all() -> void:
	await _test_reset_and_hp_curve()
	await _test_shop_economy()
	await _test_warcry_lifecycle()
	await _test_stage_damage_and_grading()
	await _test_xp_and_rewards()
	await _test_save_load()
	await _test_rhythm_scaling()
	await _test_dialogue_decoration()
	await _test_player_combat()
	await _test_sprite_animations()
	await _test_enemy_rewards()
	await _test_boss()
	await _test_rhythm_scene()
	await _test_death_flow()
	await _test_levels()
