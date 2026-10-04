extends Node

signal money_changed(value: int)
signal exp_changed(value: int)
signal level_changed(value: int)
signal level_healed(amount: float)

const SAVE_PATH := "user://save.json"
const PERFECT_HEAL_RATIO := 0.5
const MIN_REWARD_MULT := 0.25
const BASE_MAX_HP := 100.0
const MAX_HP_PER_LEVEL := 10.0
const DEATH_RATIO_PENALTY := 0.1
const MIN_RHYTHM_WINDOW := 0.15
const MIN_RHYTHM_NOTES := 8

## How many things the player may buy on a single shop visit. One purchase per
## exit is the whole point: the run only offers five decisions, so each one has
## to hurt a little.
const SHOP_PURCHASES_PER_VISIT := 1
## Per-rank effects for the stat upgrades.
const SHOP_HP_PER_RANK := 10.0
const SHOP_HEAVY_PER_RANK := 3.0
const SHOP_COOLDOWN_PER_RANK := 0.25
const SHOP_WARCRY_PER_RANK := 6.0
const BASE_SPECIAL_COOLDOWN := 2.0

## Aphrodite's Underworld Shop catalogue. `base` is the first purchase, `scale`
## multiplies the price on every repeat, and `max_ranks` caps it (`0` = forever).
## Costs are tuned against the ~1125 coins a full run earns, so the rising curve
## absorbs most of the purse without any single visit being a dead end.
const SHOP_ITEMS: Array[Dictionary] = [
	{
		"id": "heal",
		"name": "Restore",
		"blurb": "Heal to full. Cheap, and always here when you need it.",
		"base": 50,
		"scale": 1.45,
		"max_ranks": 0,
		"blocked_at_full_health": true,
	},
	{
		"id": "warcry",
		"name": "Warcry",
		"blurb": "+6 damage on every attack, for the next stage only.",
		"base": 120,
		"scale": 1.4,
		"max_ranks": 0,
	},
	{
		"id": "cooldown",
		"name": "Swiftness",
		"blurb": "Special recovers 0.25s sooner. Down to 1.0s at four ranks.",
		"base": 180,
		"scale": 1.7,
		"max_ranks": 4,
	},
	{
		"id": "hp",
		"name": "Vitality",
		"blurb": "+10 max HP, for good.",
		"base": 200,
		"scale": 1.6,
		"max_ranks": 0,
	},
	{
		"id": "heavy",
		"name": "Wrath",
		"blurb": "+3 damage on heavy, slam and combo finisher.",
		"base": 220,
		"scale": 1.6,
		"max_ranks": 0,
	},
	{
		"id": "revive",
		"name": "Second Chance",
		"blurb": "Cheat death once per run. Her favourite. She'd never say it.",
		"base": 450,
		"scale": 1.0,
		"max_ranks": 1,
	},
]

## Combat grade is derived from how cleanly the whole run was fought. The first
## entry whose `min_ratio` the clean-combat ratio reaches wins, so the table is
## ordered best to worst. `window`/`notes`/`streak` are the difficulty knobs the
## rhythm finale applies, and `chant`/`after`/`verdict` drive the dialogue.
const GRADE_TABLE: Array[Dictionary] = [
	{
		"id": "FLAWLESS",
		"min_ratio": 0.85,
		"window": 1.35,
		"notes": 0.8,
		"streak": 4,
		"color": Color(1.0, 0.9, 0.45),
		"chant": "You cut through my champions without spilling a single drop. Ridiculous. Fine, Nate Hopkins - you have earned the gentle song.",
		"after": "Not one hesitation. Not one wasted motion. You sang the way you fought.",
		"verdict": "I don't know what you did down there, but I've never seen anyone arrive looking this good.",
	},
	{
		"id": "CLEAN",
		"min_ratio": 0.65,
		"window": 1.2,
		"notes": 0.9,
		"streak": 3,
		"color": Color(0.55, 1.0, 0.6),
		"chant": "Barely a scratch on you. You fight like a man apologizing with his fists. The song will be kind.",
		"after": "Steady hands, steady voice. Nobody in the Underworld kept a beat that cleanly.",
		"verdict": "You turned Hell into a warm-up. Dinner's on me.",
	},
	{
		"id": "BLOODIED",
		"min_ratio": 0.4,
		"window": 1.0,
		"notes": 1.0,
		"streak": 2,
		"color": Color(1.0, 0.72, 0.35),
		"chant": "You are still standing. I cannot say the same for your dignity, but I suppose that is not on my schedule.",
		"after": "Ugly hands, pretty timing. The Underworld respects that sort of stubbornness.",
		"verdict": "You're a mess, Nate. A very charming mess.",
	},
	{
		"id": "MANGLED",
		"min_ratio": 0.0,
		"window": 0.8,
		"notes": 1.15,
		"streak": 2,
		"color": Color(1.0, 0.4, 0.4),
		"chant": "You fought like something that crawled out of the Underworld with its hand still attached. Which... is the point. Sing it tight, or crawl back down.",
		"after": "You won on nothing but stubbornness and luck. It counts. Barely.",
		"verdict": "You look like a car accident. I'm saying yes anyway.",
	},
]

var player_health := 0.0
var player_max_hp := 100.0
var damage_taken := 0.0

## Run-wide combat record. Unlike `damage_taken` (reset per stage), these persist
## until a new run starts so the finale can judge how the player actually fought.
var run_damage_taken := 0.0
var run_deaths := 0
var stage_damage: Array[float] = []
var forced_grade := ""
var _stage_open := false

var money := 0
var exp := 0
var level := 1
var defeated_exes := 0

## Aphrodite's Underworld Shop. Purchased ranks are permanent for the run; the
## scene holding the shop is `scenes/ui/shop.tscn`, which is entered from the
## level door and charges this state.
var shop_ranks := {}
var purchases_this_visit := 0
var shop_next_scene := ""
## Warcry ranks bought but not yet spent. They convert to `warcry_active` the
## next time a stage opens, so the boost lasts exactly one stage.
var warcry_charges := 0
var warcry_active := 0
var revives_left := 0

var dialogue_lines: Array[Dictionary] = []
var scene_after_dialogue := ""

var rhythm_window := 0.5
var rhythm_notes := 24
var rhythm_base_window := 0.5
var rhythm_base_notes := 24
var rhythm_followup_lines: Array[Dictionary] = []
var rhythm_followup_scene := ""
var rhythm_grade := ""
var rhythm_streak_limit := 2


func _ready() -> void:
	load_game()
	# The cheats must answer while the tree is paused, because that is exactly
	# when you want them: the death screen is up and you want to walk back out.
	# This autoload has no per-frame logic, so running it while paused is free.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_register_dev_actions()


func new_game() -> void:
	damage_taken = 0.0
	run_damage_taken = 0.0
	run_deaths = 0
	stage_damage.clear()
	forced_grade = ""
	_stage_open = false
	money = 0
	exp = 0
	level = 1
	defeated_exes = 0
	shop_ranks.clear()
	purchases_this_visit = 0
	shop_next_scene = ""
	warcry_charges = 0
	warcry_active = 0
	revives_left = 0
	# Level and shop state must already be reset before deriving max HP, or a
	# new run inherits the previous run's Vitality bonus.
	player_max_hp = total_max_hp()
	player_health = player_max_hp
	dialogue_lines = []
	scene_after_dialogue = ""
	rhythm_followup_lines = []
	rhythm_followup_scene = ""
	rhythm_window = 0.5
	rhythm_notes = 24
	rhythm_base_window = 0.5
	rhythm_base_notes = 24
	rhythm_grade = ""
	rhythm_streak_limit = 2


func max_hp_for_level(target_level: int) -> float:
	return BASE_MAX_HP + MAX_HP_PER_LEVEL * float(maxi(1, target_level) - 1)


## Max HP from levels plus whatever the shop has granted. Shop HP lives in its
## own field on purpose: `max_hp_for_level` is authoritative for the level
## curve, and folding shop bonuses into `player_max_hp` directly would let the
## next level-up or save load silently erase a purchase.
func total_max_hp() -> float:
	return max_hp_for_level(level) + bonus_max_hp()


func bonus_max_hp() -> float:
	return SHOP_HP_PER_RANK * float(shop_rank("hp"))


func shop_rank(id: String) -> int:
	return int(shop_ranks.get(id, 0))


## Damage bonus from Wrath, applied to heavy, slam and the combo finisher.
func heavy_damage_bonus() -> float:
	return SHOP_HEAVY_PER_RANK * float(shop_rank("heavy"))


func special_cooldown_value() -> float:
	return maxf(
		BASE_SPECIAL_COOLDOWN - SHOP_COOLDOWN_PER_RANK * float(shop_rank("cooldown")),
		1.0
	)


## Warcry bought but not yet applied, plus the boost live on this stage.
func warcry_damage_bonus() -> float:
	return SHOP_WARCRY_PER_RANK * float(warcry_active)


## Called when a stage opens: banked warcry ranks become a live buff for exactly
## one stage. Only promotes ranks that are still banked, so a stage restart or a
## save/load mid-stage keeps the buff the player already paid for. The buff is
## retired by `finish_stage()` when the stage is actually cleared.
func _consume_warcry() -> void:
	if warcry_charges <= 0:
		return
	warcry_active = warcry_charges
	warcry_charges = 0
	# Persist the promotion, otherwise quitting here would save a spent charge
	# with no active buff and the purchase would be lost.
	save_game()


func can_revive() -> bool:
	return revives_left > 0


## Spends a stored revive. Returns false when the player has none, so `die()`
## can fall through to the death screen.
func consume_revive() -> bool:
	if revives_left <= 0:
		return false
	revives_left -= 1
	save_game()
	return true


func shop_item(id: String) -> Dictionary:
	for entry in SHOP_ITEMS:
		if str(entry["id"]) == id:
			return entry
	return {}


func shop_price(id: String) -> int:
	var entry := shop_item(id)
	if entry.is_empty():
		return 0
	var ranks := shop_rank(id)
	return int(round(float(entry["base"]) * pow(float(entry["scale"]), float(ranks))))


## True when the item exists, is below its rank cap, and is not blocked by
## current state (an item like Restore is meaningless at full health).
func shop_item_available(id: String) -> bool:
	var entry := shop_item(id)
	if entry.is_empty():
		return false
	var cap := int(entry["max_ranks"])
	if cap > 0 and shop_rank(id) >= cap:
		return false
	if bool(entry.get("blocked_at_full_health", false)) and player_health >= player_max_hp - 0.01:
		return false
	return true


## The one decision the visit allows. Returns false and changes nothing if the
## player cannot afford the item, has already bought this visit, or the item is
## unavailable.
func buy_shop_item(id: String) -> bool:
	if purchases_this_visit >= SHOP_PURCHASES_PER_VISIT:
		return false
	if not shop_item_available(id):
		return false
	var cost := shop_price(id)
	if money < cost:
		return false

	money -= cost
	shop_ranks[id] = shop_rank(id) + 1
	purchases_this_visit += 1
	match id:
		"hp":
			# Grant the extra max HP now so the player sees the bar move, and top
			# up so the new ceiling is not immediately empty.
			player_max_hp = total_max_hp()
			player_health = minf(player_max_hp, player_health + SHOP_HP_PER_RANK)
		"warcry":
			warcry_charges += 1
		"revive":
			revives_left += 1
		"heal":
			player_health = player_max_hp

	save_game()
	money_changed.emit(money)
	return true


func reset_shop_visit() -> void:
	purchases_this_visit = 0
	save_game()


func save_game() -> void:
	var data := {
		"player_max_hp": player_max_hp,
		"money": money,
		"exp": exp,
		"level": level,
		"defeated_exes": defeated_exes,
		"run_damage_taken": run_damage_taken,
		"run_deaths": run_deaths,
		"stage_damage": stage_damage,
		"shop_ranks": shop_ranks,
		"warcry_charges": warcry_charges,
		"warcry_active": warcry_active,
		"revives_left": revives_left,
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))


func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return false
	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return false
	player_max_hp = parsed.get("player_max_hp", player_max_hp)
	money = parsed.get("money", money)
	exp = parsed.get("exp", exp)
	level = parsed.get("level", level)
	defeated_exes = parsed.get("defeated_exes", defeated_exes)
	run_damage_taken = float(parsed.get("run_damage_taken", 0.0))
	run_deaths = int(parsed.get("run_deaths", 0))
	stage_damage.clear()
	var saved_stages = parsed.get("stage_damage", [])
	if saved_stages is Array:
		for value in saved_stages:
			stage_damage.append(float(value))
	shop_ranks.clear()
	var saved_ranks = parsed.get("shop_ranks", {})
	if saved_ranks is Dictionary:
		for key in saved_ranks:
			shop_ranks[str(key)] = int(saved_ranks[key])
	warcry_charges = int(parsed.get("warcry_charges", 0))
	warcry_active = int(parsed.get("warcry_active", 0))
	revives_left = int(parsed.get("revives_left", 0))
	# Max HP is recomputed from the level curve plus shop bonuses, so a purchase
	# survives a reload instead of being clobbered by the authoritative curve.
	player_max_hp = total_max_hp()
	return true


func add_money(value: int) -> void:
	money += value
	save_game()
	money_changed.emit(money)


func add_exp(value: int) -> void:
	exp += maxi(1, int(round(value * xp_multiplier())))
	while exp >= exp_to_next_level():
		exp -= exp_to_next_level()
		level += 1
		player_max_hp = total_max_hp()
		var heal := player_max_hp * level_up_heal_ratio()
		player_health = minf(player_health + heal, player_max_hp)
		level_changed.emit(level)
		level_healed.emit(heal)
	exp_changed.emit(exp)
	save_game()


func begin_level() -> void:
	clear_damage_penalty()
	player_health = player_max_hp


## Called by every stage scene on entry. Closing is idempotent, so a door that
## already closed the previous stage does not record a duplicate. Warcry bought
## at the previous door goes live here, and `finish_stage()` retires it.
func begin_stage() -> void:
	clear_damage_penalty()
	_stage_open = true
	_consume_warcry()


func close_stage() -> void:
	if not _stage_open:
		return
	stage_damage.append(damage_taken)
	_stage_open = false


## Called when a stage is genuinely cleared, as opposed to retried. A retry
## (`begin_level`) must not retire the Warcry, so the buff expires here at the
## door rather than inside `close_stage`.
func finish_stage() -> void:
	clear_damage_penalty()
	warcry_active = 0
	save_game()


func clear_damage_penalty() -> void:
	close_stage()
	damage_taken = 0.0


func register_damage(amount: float) -> void:
	if not _stage_open:
		begin_stage()
	damage_taken += amount
	run_damage_taken += amount


func register_death() -> void:
	run_deaths += 1


## 1.0 means the whole run was fought without being hit, 0.0 means the player was
## carried through it. Measured as total damage against one full health bar per
## completed stage, then penalised per death.
func clean_combat_ratio() -> float:
	var stages := stage_damage.size()
	if stages <= 0:
		return 1.0
	var reference := player_max_hp * float(stages)
	if reference <= 0.0:
		return 1.0
	var ratio := 1.0 - run_damage_taken / reference
	ratio -= DEATH_RATIO_PENALTY * float(run_deaths)
	return clampf(ratio, 0.0, 1.0)


func combat_grade() -> Dictionary:
	if not forced_grade.is_empty():
		for rule in GRADE_TABLE:
			if String(rule["id"]) == forced_grade:
				return rule
	var ratio := clean_combat_ratio()
	for rule in GRADE_TABLE:
		if ratio >= float(rule["min_ratio"]):
			return rule
	return GRADE_TABLE[GRADE_TABLE.size() - 1]


func grade_id() -> String:
	return String(combat_grade()["id"])


## Applies the combat grade to the rhythm finale's difficulty. The caller must
## set the base `rhythm_window`/`rhythm_notes` first; this scales them once.
func apply_combat_grade() -> Dictionary:
	var rule := combat_grade()
	rhythm_window = maxf(rhythm_base_window * float(rule["window"]), MIN_RHYTHM_WINDOW)
	rhythm_notes = maxi(MIN_RHYTHM_NOTES, int(round(float(rhythm_base_notes) * float(rule["notes"]))))
	rhythm_streak_limit = int(rule["streak"])
	rhythm_grade = String(rule["id"])
	return rule


## The only way to set rhythm difficulty. Keeping the unscaled base around makes
## `apply_combat_grade()` idempotent, so re-entering the finale can never stack
## the modifier on top of an already-modified value.
func set_rhythm_difficulty(window_time: float, note_total: int) -> void:
	rhythm_base_window = maxf(window_time, MIN_RHYTHM_WINDOW)
	rhythm_base_notes = maxi(MIN_RHYTHM_NOTES, note_total)
	apply_combat_grade()


func grade_brief() -> String:
	var rule := combat_grade()
	return "Aphrodite reads your run: %s - %d notes, %.2fs window, %d misses allowed." % [
		String(rule["id"]), rhythm_notes, rhythm_window, rhythm_streak_limit
	]


func grade_chant() -> Dictionary:
	return {"speaker": "Aphrodite", "text": String(combat_grade()["chant"])}


## Splices the grade's reaction into the ending dialogue, just before the payoff
## line so the payoff still lands last.
func decorate_followup_lines(lines: Array[Dictionary]) -> Array[Dictionary]:
	if lines.is_empty():
		return lines
	var rule := combat_grade()
	var out: Array[Dictionary] = []
	for i in range(lines.size()):
		if i == lines.size() - 1:
			out.append({"speaker": "Aphrodite", "text": String(rule["after"])})
			out.append({"speaker": "Hazel", "text": String(rule["verdict"])})
		out.append(lines[i])
	return out


func xp_multiplier() -> float:
	if player_max_hp <= 0.0:
		return 1.0
	return clampf(1.0 - damage_taken / player_max_hp, MIN_REWARD_MULT, 1.0)


func level_up_heal_ratio() -> float:
	return PERFECT_HEAL_RATIO * xp_multiplier()


func exp_to_next_level() -> int:
	return level * 50


## ---------------------------------------------------------------------------
## Developer cheats
## ---------------------------------------------------------------------------
##
## `cheat` is the one entry point, so the engine command line needs a single
## form. Bare `cheat` cannot work in that console: it evaluates an expression
## and prints the result, it never invokes a value, so a bare identifier can
## only ever echo something back. The working form is a call:
##
##     GameState.cheat()             toggle unlimited health
##     GameState.cheat("health")     the same, spelled out
##     GameState.cheat("health off") turn it back off
##     GameState.cheat("money")      refill the purse, for shop testing
##
## F9 toggles unlimited health too, and unlike the command line it also works
## in an exported build, which is where balance actually needs checking.

## When true, the player takes no damage and the kill plane cannot kill them.
## Deliberately absent from `save_game()`: god mode belongs to the session that
## asked for it, and must never follow a player into a real run.
var dev_god_mode := false

## Only honoured in a debug build, so a stray keypress cannot enable a cheat in
## a shipped copy. Returns false in an exported release build.
static func dev_cheats_available() -> bool:
	return OS.is_debug_build()


## F9 mirrors the command line for testing in an exported build, where the
## engine console does not exist at all.
const DEV_CHEAT_ACTION := &"dev_cheat"
## Enough to buy anything in the shop several times over, for price testing.
const DEV_MONEY_REFILL := 5000


func _register_dev_actions() -> void:
	if not dev_cheats_available():
		return
	if not InputMap.has_action(DEV_CHEAT_ACTION):
		InputMap.add_action(DEV_CHEAT_ACTION)
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_F9
	InputMap.action_add_event(DEV_CHEAT_ACTION, ev)


func _unhandled_input(event: InputEvent) -> void:
	if not dev_cheats_available():
		return
	if event.is_action_pressed(DEV_CHEAT_ACTION):
		cheat("health")
		get_viewport().set_input_as_handled()


## Handles every dev command. An unknown argument reports the usage instead of
## failing silently, because a typo in a debug console is otherwise invisible.
func cheat(arg: String = "") -> String:
	var request := arg.strip_edges().to_lower()
	if not dev_cheats_available():
		return "Cheats are disabled in this build."
	match request:
		"", "god", "godmode", "health", "hp":
			dev_god_mode = not dev_god_mode
			_apply_dev_health()
			return "Unlimited health %s." % ("ON" if dev_god_mode else "off")
		"health off", "god off", "hp off", "off":
			dev_god_mode = false
			_apply_dev_health()
			return "Unlimited health off."
		"money", "cash", "coins":
			money = DEV_MONEY_REFILL
			save_game()
			return "Purse refilled to %d coins." % money
		"status":
			return "god mode %s, %d coins, level %d, %.0f/%.0f HP." % [
				"on" if dev_god_mode else "off", money, level,
				player_health, player_max_hp,
			]
		_:
			return "Unknown cheat '%s'. Try: health, money, status." % arg


func _apply_dev_health() -> void:
	var player := _dev_player()
	if player == null:
		# No player in the tree (menus, shop). Flag is still set, and the next
		# player to spawn picks it up via `dev_god_mode`.
		return
	if dev_god_mode:
		player.hp = player.max_hp
	else:
		player.hp = minf(player.hp, player.max_hp)
	player.invuln_time = 0.0
	GameState.player_health = player.hp
	player.hp_changed.emit(player.hp, player.max_hp)


func _dev_player() -> Node2D:
	if not is_inside_tree():
		return null
	return get_tree().get_first_node_in_group("player") as Node2D
