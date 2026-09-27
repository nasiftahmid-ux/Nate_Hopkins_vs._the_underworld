# Nate Hopkins vs. the Underworld

A 2D side-scrolling brawler/platformer built in **Godot 4.7 (GDScript)**. Fight your way through five levels of the Underworld, punch out a rogues' gallery of tormented souls, defeat two boss "exes," and prove your worth in a final rhythm-game showdown — all wrapped in a self-aware, comedic dating-sim story.

## Story

Nate Hopkins has a track record of breaking hearts. At a party, he meets Hazel — and immediately gets dragged into the Underworld by Aphrodite herself, who isn't about to let history repeat itself. To earn his way back to the world of the living (and a shot with Hazel), Nate has to fight through five levels of hell, defeat the ghosts of his past relationships, and finally prove he can keep a beat.

## Gameplay

- **Movement & combat:** Run, jump, block, and chain a 4-hit ground combo (punch → kick → punch → uppercut), plus a heavy attack, an aerial slam, and a cooldown-gated special move.
- **Enemies:** Four enemy types with distinct behavior — a basic chaser, a fast dodging imp, a shield-blocking knight, and a ranged shooter that lobs projectiles.
- **Bosses:** A three-phase boss fight with a full attack-state machine, built around reading telegraphs and punishing recovery windows. Every phase shift is an invulnerable roar that clears the field.
  - **Phase I — 100% to 66%:** Hunting. Charge, slam, spit, and melee only. Reads like the original fight.
  - **Phase II — 66% to 33%:** The Tolling. Adds a lunging dash, a telegraphed ground-spike field, and a rapid barrage. Faster, +5 damage, +20 move speed, and can chain up to 2 attacks without a break.
  - **Phase III — 33% to 1%:** Berserk. The name turns to `THE ONE YOU HURT [ENRAGED]` and everything gets faster: an arm spiral that blankets the arena, an unblockable leaping execute that marks a landing strip, and decoy phantoms that fire while the real boss flanks. Chains of 3, shortest cooldowns in the fight.
  - **Punish windows:** Every committed attack leaves the boss open for `1.8x` damage — the fight is about spacing, not attrition.
  - **Second wind:** At 12% HP the boss roars, heals to 25%, and permanently gains damage and speed for the rest of the fight. It survives the first "kill" attempt by design.
  - **1% ending:** The boss only dies at 1% HP, clearing the arena and paying out its reward. Beating it unlocks the next fight — the second ex is tougher (more HP, +500 per previously defeated ex) and its defeat leads into the rhythm finale.
  - **Built-in fairness:** phase roars are invulnerable, the boss can't be knocked around or stood on by the player, and it can never be pushed out of the arena.
- **Rhythm finale:** After both bosses fall, prove yourself in a Guitar-Hero-style rhythm minigame — hit the right key (J / K / L) on the beat, with combo tracking and a miss-streak fail state.
- **Combat grades feed the finale:** How you fought the whole run decides how the final song treats you. Every stage (five levels plus both boss fights) records the damage you took; the total is measured against one full health bar per stage cleared, and each death costs an extra 10% of your clean-combat score. That produces a grade of **FLAWLESS**, **CLEAN**, **BLOODIED**, or **MANGLED**, which Aphrodite reads back at you before the song starts.

  | Grade | Clean score | Hit window | Notes | Misses allowed |
  |---|---|---|---|---|
  | FLAWLESS | `>= 0.85` | `1.35x` | `0.80x` | 4 |
  | CLEAN | `>= 0.65` | `1.20x` | `0.90x` | 3 |
  | BLOODIED | `>= 0.40` | `1.00x` | `1.00x` | 2 |
  | MANGLED | below | `0.80x` | `1.15x` | 2 |

  A flawless run gets a shorter, more forgiving song; a bad run gets more notes on a tighter clock with no extra slack. The grade is shown above the progress bar before the first note, Aphrodite's dialogue before the song and Hazel's reaction at the ending all react to it, so the finale is a verdict on the run rather than a fixed test. The thresholds and modifiers live in one table (`GRADE_TABLE` in `autoload/game_state.gd`) — edit them there to rebalance the whole system.
- **Progression:** Earn coins and XP from defeated enemies, level up to increase max HP, and unlock hints scattered through the levels. Progress persists between sessions (`GameState` writes to `user://save.json` on every payout) — returning to the title screen, dying, or quitting to the menu all keep your level, coins, XP, and defeated bosses. Max HP is derived from your level (`100 + 10` per level) rather than stored, so it can never drift out of sync with your level. Pressing **Start** on the title screen deliberately begins a fresh run.
- **No-damage bonus:** Every hit you take during a level scales down your rewards. The XP multiplier is `1 - damage taken / max HP` (floor `x0.25`), and a level-up restores `50%` of max HP multiplied by that same factor — so a flawless clear pays full XP and a 50% heal, while a bad run earns as little as 25% XP and a 12.5% heal. The counter resets every time a level starts, and the HUD shows the live `XP x0.00 / HEAL 0%` penalty.
- **Gamepad support:** Full PlayStation and Xbox controller support, including in-game combat and menu navigation.

## Controls

| Action | Keys | PlayStation | Xbox |
|---|---|---|---|
| Move | `A` / `D` or Arrow Keys | Left Stick / D-pad | Left Stick / D-pad |
| Jump | `W` / `Up` / `Space` | ✕ (Cross) or D-pad Up | A or D-pad Up |
| Attack (combo) | `J` / `Z` | □ (Square) | X |
| Heavy Attack | `K` / `X` | △ (Triangle) | Y |
| Special | `L` / `C` | R1 or R2 | RB or RT |
| Block | `Q` | L1 or L2 | LB or LT |
| Pause | `Esc` | Options | Menu (Start) |

Controls are registered programmatically at startup (see `autoload/input_setup.gd`), so they're guaranteed to be consistent even if the project's Input Map is reset. Gamepads are supported for both PlayStation and Xbox pads — Godot's standard SDL layout is used, so any controller that follows either convention works, and menus are navigable with ✕/A (accept) and Options/Start (pause). Movement uses the left stick with a 0.25 deadzone, so small stick deflections are ignored, and block/special can be held on the analog triggers.

## Tech Stack

- **Engine:** [Godot 4.7](https://godotengine.org/)
- **Language:** GDScript
- **Architecture:**
  - `autoload/` — global singletons: `GameState` (persistent run data: HP, money, XP, level, per-stage and run-wide damage tracking, combat grading, dialogue/rhythm config, with JSON save/load to `user://save.json`) and `InputSetup` (keybinding registration).
  - `scenes/player/` — player movement, combat, and damage/death handling.
  - `scenes/enemies/` — enemy AI and combat behavior, all sharing the `EnemyBase` class.
  - `scenes/bosses/` — boss fight state machine, boss arena, boss projectiles, and the rhythm-game finale.
  - `scenes/items/` — pickups and environmental hazards (coins, lava, spikes, falling rocks).
  - `scenes/levels/` — level scenes built on a shared parameterized `level_base.gd`, plus moving platforms, doors, hazard scripts, and hint zones.
  - `scenes/ui/` — main menu, HUD, pause menu, and death screen.
  - `scenes/dialogue/` — a lightweight line-by-line dialogue/cutscene system.

## Running the Project

1. Install [Godot 4.7](https://godotengine.org/download) or later.
2. Clone the repository:
   ```bash
   git clone https://github.com/nasiftahmid-ux/Nate_Hopkins_vs._the_underworld.git
   ```
3. Open Godot, choose **Import**, and select the `project.godot` file in the cloned folder.
4. Press **Play** (or `F5`) to run the game.

There's also a level-select screen on the title menu for jumping straight into any level, either boss fight, or either phase of the rhythm finale for testing purposes.

## Project Status

This is an actively developed solo project. Recent work: the rhythm finale was made a verdict on the run instead of a fixed test — `GameState` now records damage per stage and across the whole run, grades the fight as FLAWLESS/CLEAN/BLOODIED/MANGLED, and applies that grade to the finale's hit window, note count, and miss tolerance, with Aphrodite calling out your performance before the song and Hazel reacting to it at the ending; the boss fight was rebuilt into a three-phase soulslike encounter — split into equal thirds with a distinct moveset per phase (lunge, spike field, and barrage at 66%; spiral, unblockable leaping execute, and decoy phantoms at 33%), `1.8x` punish windows after every committed attack, an invulnerable roar plus permanent stat boost on a second wind at 12% HP, and a 1% HP ending that clears the arena and unlocks the next fight; controller support was added — PlayStation and Xbox pads now drive every action (left stick or D-pad movement, face buttons for jump/light/heavy, shoulder buttons or analog triggers for special/block, and Start for pause), with menus wired to the same layout; a damage-based reward penalty was added — taking hits during a level scales down the XP from further kills and the HP restored on level-up, rewarding clean runs (level-up healing now also applies to the live player HP instead of only the stored value); enemy and level scripts were refactored into shared base classes (`EnemyBase` and `level_base.gd`, reducing duplicated logic across all levels); and a persistent save/load system was added (`GameState` writes progress to `user://save.json`), which now actually survives quitting — the title screen, death screen, and quit-to-menu no longer reset the run, and max HP is derived from level instead of drifting out of sync. Future focus areas include deeper content — new enemy types, more boss attacks, and level polish.

## License

No license has been specified yet — all rights reserved by default. If you'd like to use or build on this project, please reach out first.
